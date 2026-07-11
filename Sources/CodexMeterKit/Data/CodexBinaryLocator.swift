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
  case requestTimedOut

  public var errorDescription: String? {
    switch self {
    case .binaryNotFound:
      "找不到 Codex。请安装并登录 Codex/ChatGPT 桌面应用，或设置 CODEX_METER_CODEX_PATH。"
    case .launchFailed(let reason):
      "无法启动本机 Codex app-server：\(reason)"
    case .connectionClosed(let status):
      "Codex app-server 已退出（状态 \(status)）。"
    case .invalidMessage:
      "Codex app-server 返回了无法识别的数据。"
    case .rpc(let message):
      "Codex app-server：\(message)"
    case .requestTimedOut:
      "Codex 用量请求超时，请检查网络和登录状态。"
    }
  }
}
