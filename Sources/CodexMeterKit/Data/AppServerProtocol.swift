import Foundation

struct RateLimitsResult: Decodable, Sendable {
  let rateLimits: RateLimitSnapshotDTO
  let rateLimitsByLimitId: [String: RateLimitSnapshotDTO]?
}

struct RateLimitSnapshotDTO: Decodable, Sendable {
  let primary: RateLimitWindowDTO?
  let secondary: RateLimitWindowDTO?
  let planType: String?
}

struct RateLimitWindowDTO: Decodable, Sendable {
  let usedPercent: Int
  let windowDurationMins: Int?
  let resetsAt: Int64?
}

struct AccountUsageResult: Decodable, Sendable {
  let summary: AccountUsageSummaryDTO
  let dailyUsageBuckets: [DailyUsageBucketDTO]?
}

struct AccountUsageSummaryDTO: Decodable, Sendable {
  let lifetimeTokens: Int64?
}

struct DailyUsageBucketDTO: Decodable, Sendable {
  let startDate: String
  let tokens: Int64
}

struct InitializeResult: Decodable, Sendable {
  let codexHome: String
  let platformFamily: String
  let platformOs: String
}

enum UsageResponseMapper {
  static func makeSnapshot(
    rateLimits: RateLimitsResult,
    usage: AccountUsageResult,
    now: Date,
    timeZone: TimeZone = .current
  ) -> UsageSnapshot {
    let preferredRateLimit =
      rateLimits.rateLimitsByLimitId?["codex"]
      ?? rateLimits.rateLimits

    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = timeZone
    let components = calendar.dateComponents([.year, .month, .day], from: now)
    let todayKey = String(
      format: "%04d-%02d-%02d",
      components.year ?? 0,
      components.month ?? 0,
      components.day ?? 0
    )
    let todayTokens = usage.dailyUsageBuckets?
      .first(where: { $0.startDate == todayKey })?
      .tokens

    return UsageSnapshot(
      fetchedAt: now,
      planType: preferredRateLimit.planType,
      primary: makeWindow(preferredRateLimit.primary),
      secondary: makeWindow(preferredRateLimit.secondary),
      todayTokens: todayTokens,
      lifetimeTokens: usage.summary.lifetimeTokens
    )
  }

  private static func makeWindow(_ value: RateLimitWindowDTO?) -> QuotaWindow? {
    guard let value else { return nil }
    return QuotaWindow(
      usedPercent: value.usedPercent,
      windowDurationMinutes: value.windowDurationMins,
      resetsAt: value.resetsAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
    )
  }
}

struct JSONLineFramer: Sendable {
  private let maximumFrameSize: Int
  private var buffer = Data()

  init(maximumFrameSize: Int = 4 * 1_024 * 1_024) {
    precondition(maximumFrameSize > 0)
    self.maximumFrameSize = maximumFrameSize
  }

  mutating func append(_ data: Data) throws -> [Data] {
    buffer.append(data)
    var lines: [Data] = []

    while let newline = buffer.firstIndex(of: 0x0A) {
      var line = Data(buffer[..<newline])
      buffer.removeSubrange(...newline)
      guard line.count <= maximumFrameSize else {
        buffer.removeAll(keepingCapacity: false)
        throw CodexAppServerError.invalidMessage
      }
      if line.last == 0x0D {
        line.removeLast()
      }
      if !line.isEmpty {
        lines.append(line)
      }
    }

    guard buffer.count <= maximumFrameSize else {
      buffer.removeAll(keepingCapacity: false)
      throw CodexAppServerError.invalidMessage
    }

    return lines
  }
}
