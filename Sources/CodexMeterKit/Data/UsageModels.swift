import Foundation

public struct QuotaWindow: Equatable, Sendable {
  public let usedPercent: Int
  public let windowDurationMinutes: Int?
  public let resetsAt: Date?

  public init(
    usedPercent: Int,
    windowDurationMinutes: Int?,
    resetsAt: Date?
  ) {
    self.usedPercent = usedPercent
    self.windowDurationMinutes = windowDurationMinutes
    self.resetsAt = resetsAt
  }

  public var remainingPercent: Int {
    min(max(100 - usedPercent, 0), 100)
  }
}

public struct UsageSnapshot: Equatable, Sendable {
  public let fetchedAt: Date
  public let planType: String?
  public let primary: QuotaWindow?
  public let secondary: QuotaWindow?
  public let todayTokens: Int64?
  public let lifetimeTokens: Int64?

  public init(
    fetchedAt: Date,
    planType: String?,
    primary: QuotaWindow?,
    secondary: QuotaWindow?,
    todayTokens: Int64?,
    lifetimeTokens: Int64?
  ) {
    self.fetchedAt = fetchedAt
    self.planType = planType
    self.primary = primary
    self.secondary = secondary
    self.todayTokens = todayTokens
    self.lifetimeTokens = lifetimeTokens
  }
}

public protocol UsageProviding: Sendable {
  func fetchUsage() async throws -> UsageSnapshot
  func shutdown() async
}

extension UsageProviding {
  public func shutdown() async {}
}
