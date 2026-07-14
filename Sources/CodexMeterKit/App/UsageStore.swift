import Foundation
import Observation

struct UsagePollingPolicy: Equatable, Sendable {
  static let defaultInterval: TimeInterval = 30
  static let minimumInterval: TimeInterval = 15
  static let maximumInterval: TimeInterval = 300
  static let hiddenInterval: TimeInterval = 300
  static let maximumFailureExponent = 5

  static func normalized(_ interval: TimeInterval) -> TimeInterval {
    min(max(interval, minimumInterval), maximumInterval)
  }

  static func delay(
    requestedInterval: TimeInterval,
    isWidgetVisible: Bool,
    consecutiveFailures: Int = 0
  ) -> TimeInterval {
    let visibleDelay = normalized(requestedInterval)
    let failureExponent = min(max(consecutiveFailures, 0), maximumFailureExponent)
    let backedOffDelay = min(
      visibleDelay * pow(2, Double(failureExponent)),
      maximumInterval
    )
    return isWidgetVisible ? backedOffDelay : max(backedOffDelay, hiddenInterval)
  }

  static func tolerance(for delay: TimeInterval) -> TimeInterval {
    min(max(delay * 0.1, 1), 15)
  }
}

@MainActor
@Observable
public final class UsageStore {
  private struct RefreshOperation {
    let id: UUID
    let task: Task<UsageSnapshot, any Error>
  }

  public private(set) var snapshot: UsageSnapshot?
  public private(set) var isRefreshing = false
  public private(set) var isWidgetVisible = true

  public var lastErrorDescription: String? {
    guard let lastError else { return nil }
    if let error = lastError as? CodexAppServerError {
      return error.localizedDescription(using: languageController.localizer)
    }
    return lastError.localizedDescription
  }

  public var refreshInterval: TimeInterval {
    didSet {
      refreshInterval = UsagePollingPolicy.normalized(refreshInterval)
      defaults.set(refreshInterval, forKey: Keys.refreshInterval)
      restartPollingIfNeeded()
    }
  }

  private enum Keys {
    static let refreshInterval = "CodexMeter.refreshInterval"
  }

  private let provider: any UsageProviding
  private let languageController: LanguageController
  private let defaults: UserDefaults
  private var lastError: (any Error)?
  private var pollingTask: Task<Void, Never>?
  private var refreshOperation: RefreshOperation?
  private var hasStarted = false
  private var consecutiveFailures = 0

  public init(
    provider: any UsageProviding,
    languageController: LanguageController,
    defaults: UserDefaults = .standard
  ) {
    self.provider = provider
    self.languageController = languageController
    self.defaults = defaults
    let storedInterval = defaults.double(forKey: Keys.refreshInterval)
    refreshInterval =
      storedInterval == 0
      ? UsagePollingPolicy.defaultInterval
      : UsagePollingPolicy.normalized(storedInterval)
  }

  public func start() {
    guard !hasStarted else { return }
    hasStarted = true
    startPolling(refreshImmediately: true)
  }

  public func stop() {
    hasStarted = false
    pollingTask?.cancel()
    pollingTask = nil
    refreshOperation?.task.cancel()
    refreshOperation = nil
    isRefreshing = false
  }

  public func shutdown() async {
    stop()
    await provider.shutdown()
  }

  public func setWidgetVisible(_ isVisible: Bool) {
    guard isWidgetVisible != isVisible else { return }
    isWidgetVisible = isVisible
    restartPollingIfNeeded(refreshImmediately: isVisible || snapshot == nil)
  }

  public func refresh() async {
    await performRefresh(reschedulePollingAfterCompletion: true)
  }

  private func performRefresh(reschedulePollingAfterCompletion: Bool) async {
    let operation: RefreshOperation
    if let refreshOperation {
      operation = refreshOperation
    } else {
      let id = UUID()
      let task = Task { try await provider.fetchUsage() }
      operation = RefreshOperation(id: id, task: task)
      refreshOperation = operation
      isRefreshing = true
    }

    await finishRefresh(
      operation,
      reschedulePollingAfterCompletion: reschedulePollingAfterCompletion
    )
  }

  private func finishRefresh(
    _ operation: RefreshOperation,
    reschedulePollingAfterCompletion: Bool
  ) async {
    let shouldReschedule: Bool
    do {
      let nextSnapshot = try await operation.task.value
      completeRefresh(operationID: operation.id, result: .success(nextSnapshot))
      shouldReschedule = true
    } catch is CancellationError {
      completeRefresh(operationID: operation.id, result: nil)
      shouldReschedule = false
    } catch {
      completeRefresh(operationID: operation.id, result: .failure(error))
      shouldReschedule = true
    }

    if reschedulePollingAfterCompletion, shouldReschedule, hasStarted {
      restartPollingIfNeeded(refreshImmediately: false)
    }
  }

  private func completeRefresh(
    operationID: UUID,
    result: Result<UsageSnapshot, any Error>?
  ) {
    guard refreshOperation?.id == operationID else { return }
    refreshOperation = nil
    isRefreshing = false

    switch result {
    case .success(let nextSnapshot):
      snapshot = nextSnapshot
      lastError = nil
      consecutiveFailures = 0
    case .failure(let error):
      lastError = error
      consecutiveFailures = min(
        consecutiveFailures + 1,
        UsagePollingPolicy.maximumFailureExponent
      )
    case nil:
      break
    }
  }

  private func restartPollingIfNeeded(refreshImmediately: Bool? = nil) {
    guard hasStarted else { return }
    pollingTask?.cancel()
    startPolling(
      refreshImmediately: refreshImmediately ?? (snapshot == nil),
      initialOperation: refreshOperation
    )
  }

  private func startPolling(
    refreshImmediately: Bool,
    initialOperation: RefreshOperation? = nil
  ) {
    pollingTask = Task(priority: .utility) { [weak self] in
      guard let self else { return }
      if let initialOperation {
        await finishRefresh(
          initialOperation,
          reschedulePollingAfterCompletion: false
        )
        do {
          try await sleepUntilNextRefresh()
        } catch {
          return
        }
      } else if !refreshImmediately {
        do {
          try await sleepUntilNextRefresh()
        } catch {
          return
        }
      }
      while !Task.isCancelled {
        await performRefresh(reschedulePollingAfterCompletion: false)
        do {
          try await sleepUntilNextRefresh()
        } catch {
          return
        }
      }
    }
  }

  private func sleepUntilNextRefresh() async throws {
    let delay = UsagePollingPolicy.delay(
      requestedInterval: refreshInterval,
      isWidgetVisible: isWidgetVisible,
      consecutiveFailures: consecutiveFailures
    )
    try await Task.sleep(
      for: .seconds(delay),
      tolerance: .seconds(UsagePollingPolicy.tolerance(for: delay))
    )
  }
}
