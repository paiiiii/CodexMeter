import Foundation
import XCTest

@testable import CodexMeterKit

final class MetricFormatterTests: XCTestCase {
  func testCompactTokenFormatting() {
    XCTAssertEqual(MetricFormatter.compactTokens(nil), "—")
    XCTAssertEqual(MetricFormatter.compactTokens(999), "999")
    XCTAssertEqual(MetricFormatter.compactTokens(1_500), "1.5K")
    XCTAssertEqual(MetricFormatter.compactTokens(55_009_052), "55.0M")
    XCTAssertEqual(MetricFormatter.compactTokens(1_250_000_000), "1.2B")
  }

  func testResetCountdownFormatting() {
    let now = Date(timeIntervalSince1970: 1_000_000)

    XCTAssertEqual(MetricFormatter.resetCountdown(until: nil, now: now), "等待同步")
    XCTAssertEqual(
      MetricFormatter.resetCountdown(until: now.addingTimeInterval(90), now: now),
      "1分后重置"
    )
    XCTAssertEqual(
      MetricFormatter.resetCountdown(until: now.addingTimeInterval(7_320), now: now),
      "2时 2分后重置"
    )
    XCTAssertEqual(
      MetricFormatter.resetCountdown(until: now.addingTimeInterval(93_600), now: now),
      "1天 2时后重置"
    )
  }

  func testQuotaLabelsFollowServerWindowDuration() {
    let fifteenMinutes = QuotaWindow(
      usedPercent: 10,
      windowDurationMinutes: 15,
      resetsAt: nil
    )
    let fiveHours = QuotaWindow(
      usedPercent: 10,
      windowDurationMinutes: 300,
      resetsAt: nil
    )
    let sevenDays = QuotaWindow(
      usedPercent: 10,
      windowDurationMinutes: 10_080,
      resetsAt: nil
    )

    XCTAssertEqual(MetricFormatter.quotaLabel(for: fifteenMinutes, fallback: "主要额度"), "15 分钟额度")
    XCTAssertEqual(MetricFormatter.shortQuotaLabel(for: fifteenMinutes, fallback: "主要"), "15M 剩余")
    XCTAssertEqual(MetricFormatter.quotaLabel(for: fiveHours, fallback: "主要额度"), "5 小时额度")
    XCTAssertEqual(MetricFormatter.shortQuotaLabel(for: fiveHours, fallback: "主要"), "5H 剩余")
    XCTAssertEqual(MetricFormatter.quotaLabel(for: sevenDays, fallback: "次要额度"), "7 天额度")
    XCTAssertEqual(MetricFormatter.quotaLabel(for: nil, fallback: "主要额度"), "主要额度")
  }
}
