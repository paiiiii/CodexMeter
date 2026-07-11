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
    XCTAssertEqual(MetricFormatter.resetCountdown(until: now, now: now), "即将重置")
    XCTAssertEqual(
      MetricFormatter.resetCountdown(until: now.addingTimeInterval(-60), now: now),
      "即将重置"
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

  func testCompactResetCountdownFormatting() {
    let now = Date(timeIntervalSince1970: 1_000_000)

    XCTAssertEqual(MetricFormatter.compactResetCountdown(until: nil, now: now), "等待同步")
    XCTAssertEqual(
      MetricFormatter.compactResetCountdown(until: now.addingTimeInterval(90), now: now),
      "重置 00:01"
    )
    XCTAssertEqual(
      MetricFormatter.compactResetCountdown(until: now.addingTimeInterval(7_320), now: now),
      "重置 02:02"
    )
    XCTAssertEqual(
      MetricFormatter.compactResetCountdown(until: now.addingTimeInterval(93_600), now: now),
      "重置 1天02时"
    )
    XCTAssertEqual(MetricFormatter.compactResetCountdown(until: now, now: now), "即将重置")
  }

  func testQuotaAccessibilityIncludesLiveResetState() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    let active = QuotaWindow(
      usedPercent: 25,
      windowDurationMinutes: 300,
      resetsAt: now.addingTimeInterval(3_660)
    )
    let passed = QuotaWindow(
      usedPercent: 25,
      windowDurationMinutes: 300,
      resetsAt: now.addingTimeInterval(-1)
    )
    let pendingSync = QuotaWindow(
      usedPercent: 25,
      windowDurationMinutes: 300,
      resetsAt: nil
    )

    XCTAssertEqual(
      MetricFormatter.quotaAccessibilityValue(for: active, now: now),
      "剩余 75 百分比，1时 1分后重置"
    )
    XCTAssertEqual(
      MetricFormatter.quotaAccessibilityValue(for: passed, now: now),
      "剩余 75 百分比，即将重置"
    )
    XCTAssertEqual(
      MetricFormatter.quotaAccessibilityValue(for: pendingSync, now: now),
      "剩余 75 百分比，等待同步"
    )
    XCTAssertEqual(
      MetricFormatter.quotaAccessibilityValue(for: nil, now: now),
      "尚无数据"
    )
  }
}
