import Foundation

public actor CodexAppServerClient: UsageProviding {
  private struct PendingRequest {
    let continuation: CheckedContinuation<Data, Error>
    let timeoutTask: Task<Void, Never>
  }

  private let locator: CodexBinaryLocator
  private let timeout: Duration
  private let now: @Sendable () -> Date
  private let timeZone: @Sendable () -> TimeZone

  private var process: Process?
  private var inputHandle: FileHandle?
  private var outputPipe: Pipe?
  private var errorPipe: Pipe?
  private var stdoutReaderTask: Task<Void, Never>?
  private var stderrReaderTask: Task<Void, Never>?
  private var generation: UUID?
  private var observedTerminationStatus: Int32?
  private var stdoutDidEnd = false
  private var isInitialized = false
  private var nextRequestID = 1
  private var pending: [Int: PendingRequest] = [:]
  private var framer = JSONLineFramer()
  private var fetchTask: Task<UsageSnapshot, Error>?
  private var fetchID: UUID?

  public init() {
    locator = CodexBinaryLocator()
    timeout = .seconds(20)
    now = Date.init
    timeZone = { .autoupdatingCurrent }
  }

  init(
    locator: CodexBinaryLocator,
    timeout: Duration = .seconds(20),
    now: @escaping @Sendable () -> Date = Date.init,
    timeZone: @escaping @Sendable () -> TimeZone = { .autoupdatingCurrent }
  ) {
    self.locator = locator
    self.timeout = timeout
    self.now = now
    self.timeZone = timeZone
  }

  public func fetchUsage() async throws -> UsageSnapshot {
    if let fetchTask {
      return try await fetchTask.value
    }

    let id = UUID()
    let task = Task { try await self.performFetch() }
    fetchID = id
    fetchTask = task

    do {
      let snapshot = try await task.value
      clearFetchTask(id: id)
      return snapshot
    } catch {
      clearFetchTask(id: id)
      throw error
    }
  }

  public func shutdown() async {
    fetchTask?.cancel()
    fetchTask = nil
    fetchID = nil
    stopProcess(resumingPendingWith: CancellationError())
  }

  private func performFetch() async throws -> UsageSnapshot {
    do {
      try await ensureStarted()

      async let rateLimits: RateLimitsResult = requestDecoded(
        method: "account/rateLimits/read"
      )
      async let usage: AccountUsageResult = requestDecoded(
        method: "account/usage/read"
      )

      return try await UsageResponseMapper.makeSnapshot(
        rateLimits: rateLimits,
        usage: usage,
        now: now(),
        timeZone: timeZone()
      )
    } catch {
      stopProcess(resumingPendingWith: error)
      throw error
    }
  }

  private func clearFetchTask(id: UUID) {
    guard fetchID == id else { return }
    fetchTask = nil
    fetchID = nil
  }

  private func ensureStarted() async throws {
    if process?.isRunning == true, isInitialized {
      return
    }

    stopProcess(resumingPendingWith: CancellationError())
    try startProcess()

    let _: InitializeResult = try await requestDecoded(
      method: "initialize",
      params: [
        "clientInfo": [
          "name": "codex-meter",
          "title": "CodexMeter",
          "version": "0.2.0",
        ],
        "capabilities": [
          "experimentalApi": true,
          "optOutNotificationMethods": [
            "thread/started",
            "thread/tokenUsage/updated",
            "fs/changed",
          ],
        ],
      ]
    )
    try sendNotification(method: "initialized")
    isInitialized = true
  }

  private func startProcess() throws {
    let executable = try locator.locate()
    let newGeneration = UUID()
    let process = Process()
    let inputPipe = Pipe()
    let outputPipe = Pipe()
    let errorPipe = Pipe()

    process.executableURL = executable
    process.arguments = [
      "app-server",
      "--listen",
      "stdio://",
      "-c",
      "model_reasoning_effort=\"xhigh\"",
    ]
    process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
    var environment = ProcessInfo.processInfo.environment
    environment["NO_COLOR"] = "1"
    environment["TERM"] = "dumb"
    process.environment = environment
    process.standardInput = inputPipe
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    process.terminationHandler = { [weak self] terminatedProcess in
      let status = terminatedProcess.terminationStatus
      Task { await self?.recordTermination(generation: newGeneration, status: status) }
    }

    do {
      try process.run()
    } catch {
      throw CodexAppServerError.launchFailed(error.localizedDescription)
    }

    self.process = process
    inputHandle = inputPipe.fileHandleForWriting
    self.outputPipe = outputPipe
    self.errorPipe = errorPipe
    generation = newGeneration
    observedTerminationStatus = nil
    stdoutDidEnd = false
    isInitialized = false
    framer = JSONLineFramer()

    let stdout = outputPipe.fileHandleForReading
    stdoutReaderTask = Task.detached(priority: .utility) { [weak self] in
      while !Task.isCancelled {
        let data = stdout.availableData
        guard !data.isEmpty else { break }
        await self?.receive(data, generation: newGeneration)
      }
      await self?.stdoutEnded(generation: newGeneration)
    }

    let stderr = errorPipe.fileHandleForReading
    stderrReaderTask = Task.detached(priority: .utility) {
      while !Task.isCancelled {
        guard !stderr.availableData.isEmpty else { break }
      }
    }
  }

  private func requestDecoded<Response: Decodable & Sendable>(
    method: String,
    params: Any? = nil
  ) async throws -> Response {
    let data = try await requestWithTimeout(method: method, params: params)
    do {
      return try JSONDecoder().decode(Response.self, from: data)
    } catch {
      throw CodexAppServerError.invalidMessage
    }
  }

  private func requestWithTimeout(method: String, params: Any?) async throws -> Data {
    try await request(method: method, params: params)
  }

  private func request(method: String, params: Any?) async throws -> Data {
    let requestID = nextRequestID
    nextRequestID += 1

    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        let timeoutTask = Task { [weak self, timeout] in
          do {
            try await Task.sleep(for: timeout)
          } catch {
            return
          }
          await self?.timeoutRequest(requestID)
        }
        pending[requestID] = PendingRequest(
          continuation: continuation,
          timeoutTask: timeoutTask
        )
        do {
          var message: [String: Any] = [
            "id": requestID,
            "method": method,
          ]
          if let params {
            message["params"] = params
          }
          try send(message)
        } catch {
          pending.removeValue(forKey: requestID)?.timeoutTask.cancel()
          continuation.resume(throwing: error)
        }
      }
    } onCancel: {
      Task { await self.cancelRequest(requestID) }
    }
  }

  private func cancelRequest(_ requestID: Int) {
    guard let request = pending.removeValue(forKey: requestID) else { return }
    request.timeoutTask.cancel()
    request.continuation.resume(throwing: CancellationError())
  }

  private func timeoutRequest(_ requestID: Int) {
    guard let request = pending.removeValue(forKey: requestID) else { return }
    request.continuation.resume(throwing: CodexAppServerError.requestTimedOut)
  }

  private func sendNotification(method: String) throws {
    try send(["method": method])
  }

  private func send(_ object: [String: Any]) throws {
    guard let inputHandle, process?.isRunning == true else {
      throw CodexAppServerError.connectionClosed(process?.terminationStatus ?? -1)
    }
    var data = try JSONSerialization.data(withJSONObject: object)
    data.append(0x0A)
    try inputHandle.write(contentsOf: data)
  }

  private func receive(_ data: Data, generation: UUID) {
    guard self.generation == generation else { return }
    for line in framer.append(data) {
      handle(line)
    }
  }

  private func handle(_ line: Data) {
    guard
      let object = try? JSONSerialization.jsonObject(with: line),
      let dictionary = object as? [String: Any],
      let id = (dictionary["id"] as? NSNumber)?.intValue,
      let request = pending.removeValue(forKey: id)
    else {
      return
    }
    request.timeoutTask.cancel()

    if let error = dictionary["error"] as? [String: Any] {
      let message = error["message"] as? String ?? "未知 RPC 错误"
      request.continuation.resume(throwing: CodexAppServerError.rpc(message))
      return
    }

    guard let result = dictionary["result"] else {
      request.continuation.resume(throwing: CodexAppServerError.invalidMessage)
      return
    }

    do {
      let data = try JSONSerialization.data(withJSONObject: result, options: .fragmentsAllowed)
      request.continuation.resume(returning: data)
    } catch {
      request.continuation.resume(throwing: CodexAppServerError.invalidMessage)
    }
  }

  private func recordTermination(generation: UUID, status: Int32) {
    guard self.generation == generation else { return }
    observedTerminationStatus = status
    if stdoutDidEnd {
      stopProcess(resumingPendingWith: CodexAppServerError.connectionClosed(status))
    }
  }

  private func stdoutEnded(generation: UUID) {
    guard self.generation == generation else { return }
    stdoutDidEnd = true
    if let status = observedTerminationStatus {
      stopProcess(resumingPendingWith: CodexAppServerError.connectionClosed(status))
    } else if process?.isRunning == false {
      stopProcess(
        resumingPendingWith: CodexAppServerError.connectionClosed(
          process?.terminationStatus ?? -1
        )
      )
    }
  }

  private func stopProcess(resumingPendingWith error: any Error) {
    let stdoutTask = stdoutReaderTask
    let stderrTask = stderrReaderTask
    let outputReadHandle = outputPipe?.fileHandleForReading
    let errorReadHandle = errorPipe?.fileHandleForReading
    try? inputHandle?.close()
    try? outputReadHandle?.close()
    try? errorReadHandle?.close()

    let activeProcess = process
    activeProcess?.terminationHandler = nil
    process = nil
    inputHandle = nil
    outputPipe = nil
    errorPipe = nil
    stdoutReaderTask = nil
    stderrReaderTask = nil
    generation = nil
    observedTerminationStatus = nil
    stdoutDidEnd = false
    isInitialized = false
    framer = JSONLineFramer()

    stdoutTask?.cancel()
    stderrTask?.cancel()

    let requests = pending.values
    pending.removeAll()
    for request in requests {
      request.timeoutTask.cancel()
      request.continuation.resume(throwing: error)
    }

    if activeProcess?.isRunning == true {
      activeProcess?.terminate()
    }
  }
}
