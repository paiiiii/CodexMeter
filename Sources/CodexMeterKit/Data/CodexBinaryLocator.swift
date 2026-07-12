import Foundation

public struct CodexBinaryLocator: Sendable {
  public typealias ExecutableCheck = @Sendable (String) -> Bool

  private let explicitCandidates: [String]?
  private let environment: [String: String]
  private let isExecutable: ExecutableCheck

  public init(
    candidates: [String]? = nil,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    isExecutable: @escaping ExecutableCheck = {
      FileManager.default.isExecutableFile(atPath: $0)
    }
  ) {
    explicitCandidates = candidates
    self.environment = environment
    self.isExecutable = isExecutable
  }

  public func locate() throws -> URL {
    for candidate in candidates() {
      let expanded = (candidate as NSString).expandingTildeInPath
      if isExecutable(expanded) {
        return URL(fileURLWithPath: expanded)
      }
    }
    throw CodexAppServerError.binaryNotFound
  }

  private func candidates() -> [String] {
    if let explicitCandidates {
      return explicitCandidates
    }

    var values: [String] = []
    if let override = environment["CODEX_METER_CODEX_PATH"], !override.isEmpty {
      values.append(override)
    }

    values.append(contentsOf: [
      "/Applications/Codex.app/Contents/Resources/codex",
      "/Applications/ChatGPT.app/Contents/Resources/codex",
      "~/.local/bin/codex",
      "/opt/homebrew/bin/codex",
      "/usr/local/bin/codex",
      "/usr/bin/codex",
    ])

    if let path = environment["PATH"] {
      values.append(contentsOf: path.split(separator: ":").map { "\($0)/codex" })
    }

    var seen = Set<String>()
    return values.filter { seen.insert($0).inserted }
  }
}

public enum CodexAppServerError: LocalizedError, Equatable, Sendable {
  case binaryNotFound
  case launchFailed(String)
  case connectionClosed(Int32)
  case invalidMessage
  case rpc(String)
  case unknownRPC
  case requestTimedOut

  public var errorDescription: String? {
    localizedDescription(using: AppLocalizer(language: .english))
  }

  func localizedDescription(using localizer: AppLocalizer) -> String {
    switch self {
    case .binaryNotFound:
      localizer.string(.errorBinaryNotFound)
    case .launchFailed(let reason):
      localizer.format(.errorLaunchFailedFormat, reason)
    case .connectionClosed(let status):
      localizer.format(.errorConnectionClosedFormat, status)
    case .invalidMessage:
      localizer.string(.errorInvalidMessage)
    case .rpc(let message):
      localizer.format(.errorRPCFormat, message)
    case .unknownRPC:
      localizer.format(.errorRPCFormat, localizer.string(.errorUnknownRPC))
    case .requestTimedOut:
      localizer.string(.errorRequestTimedOut)
    }
  }
}
