import Foundation
import XCTest

@testable import CodexMeterKit

final class MetricFormatterTests: XCTestCase {
  private let english = AppLocalizer(language: .english)
  private let chinese = AppLocalizer(language: .simplifiedChinese)

  func testCompactTokenFormattingUsesSelectedLocale() {
    for localizer in [english, chinese] {
      XCTAssertEqual(MetricFormatter.compactTokens(nil, localizer: localizer), "—")
      XCTAssertEqual(MetricFormatter.compactTokens(999, localizer: localizer), "999")
      XCTAssertEqual(MetricFormatter.compactTokens(1_500, localizer: localizer), "1.5K")
      XCTAssertEqual(MetricFormatter.compactTokens(55_009_052, localizer: localizer), "55.0M")
      XCTAssertEqual(
        MetricFormatter.compactTokens(1_250_000_000, localizer: localizer),
        "1.2B"
      )
      XCTAssertEqual(
        MetricFormatter.exactTokens(55_009_052, localizer: localizer),
        "55,009,052"
      )
    }
  }

  func testResetCountdownFormattingInEnglishAndChinese() {
    let now = Date(timeIntervalSince1970: 1_000_000)

    XCTAssertEqual(
      MetricFormatter.resetCountdown(until: nil, now: now, localizer: english),
      "Waiting for sync"
    )
    XCTAssertEqual(
      MetricFormatter.resetCountdown(
        until: now.addingTimeInterval(90),
        now: now,
        localizer: english
      ),
      "Resets in 1 minute"
    )
    XCTAssertEqual(
      MetricFormatter.resetCountdown(
        until: now.addingTimeInterval(7_320),
        now: now,
        localizer: english
      ),
      "Resets in 2 hours 2 minutes"
    )
    XCTAssertEqual(
      MetricFormatter.resetCountdown(
        until: now.addingTimeInterval(93_600),
        now: now,
        localizer: english
      ),
      "Resets in 1 day 2 hours"
    )
    XCTAssertEqual(
      MetricFormatter.resetCountdown(until: now, now: now, localizer: english),
      "Resetting soon"
    )

    XCTAssertEqual(
      MetricFormatter.resetCountdown(until: nil, now: now, localizer: chinese),
      "等待同步"
    )
    XCTAssertEqual(
      MetricFormatter.resetCountdown(
        until: now.addingTimeInterval(90),
        now: now,
        localizer: chinese
      ),
      "1分后重置"
    )
    XCTAssertEqual(
      MetricFormatter.resetCountdown(
        until: now.addingTimeInterval(7_320),
        now: now,
        localizer: chinese
      ),
      "2时 2分后重置"
    )
    XCTAssertEqual(
      MetricFormatter.resetCountdown(
        until: now.addingTimeInterval(93_600),
        now: now,
        localizer: chinese
      ),
      "1天 2时后重置"
    )
    XCTAssertEqual(
      MetricFormatter.resetCountdown(
        until: now.addingTimeInterval(-60),
        now: now,
        localizer: chinese
      ),
      "即将重置"
    )
  }

  func testEnglishResetCountdownPluralForms() {
    let now = Date(timeIntervalSince1970: 1_000_000)

    XCTAssertEqual(
      MetricFormatter.resetCountdown(
        until: now.addingTimeInterval(3_660),
        now: now,
        localizer: english
      ),
      "Resets in 1 hour 1 minute"
    )
    XCTAssertEqual(
      MetricFormatter.resetCountdown(
        until: now.addingTimeInterval(7_260),
        now: now,
        localizer: english
      ),
      "Resets in 2 hours 1 minute"
    )
    XCTAssertEqual(
      MetricFormatter.resetCountdown(
        until: now.addingTimeInterval(176_400),
        now: now,
        localizer: english
      ),
      "Resets in 2 days 1 hour"
    )
  }

  func testQuotaLabelsFollowServerWindowDurationInBothLanguages() {
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

    XCTAssertEqual(
      MetricFormatter.quotaLabel(
        for: fifteenMinutes,
        fallback: .quotaPrimaryLimit,
        localizer: english
      ),
      "15-minute limit"
    )
    XCTAssertEqual(
      MetricFormatter.quotaLabel(
        for: fiveHours,
        fallback: .quotaPrimaryLimit,
        localizer: english
      ),
      "5-hour limit"
    )
    XCTAssertEqual(
      MetricFormatter.quotaLabel(
        for: sevenDays,
        fallback: .quotaSecondaryLimit,
        localizer: english
      ),
      "7-day limit"
    )
    XCTAssertEqual(
      MetricFormatter.quotaLabel(
        for: nil,
        fallback: .quotaPrimaryLimit,
        localizer: english
      ),
      "Primary limit"
    )

    XCTAssertEqual(
      MetricFormatter.quotaLabel(
        for: fifteenMinutes,
        fallback: .quotaPrimaryLimit,
        localizer: chinese
      ),
      "15 分钟额度"
    )
    XCTAssertEqual(
      MetricFormatter.quotaLabel(
        for: sevenDays,
        fallback: .quotaSecondaryLimit,
        localizer: chinese
      ),
      "7 天额度"
    )
  }

  func testCompactResetCountdownFormattingInBothLanguages() {
    let now = Date(timeIntervalSince1970: 1_000_000)

    XCTAssertEqual(
      MetricFormatter.compactResetCountdown(until: nil, now: now, localizer: english),
      "Waiting for sync"
    )
    XCTAssertEqual(
      MetricFormatter.compactResetCountdown(
        until: now.addingTimeInterval(90),
        now: now,
        localizer: english
      ),
      "Reset 00:01"
    )
    XCTAssertEqual(
      MetricFormatter.compactResetCountdown(
        until: now.addingTimeInterval(93_600),
        now: now,
        localizer: english
      ),
      "Reset 1d02h"
    )
    XCTAssertEqual(
      MetricFormatter.compactResetCountdown(
        until: now.addingTimeInterval(7_320),
        now: now,
        localizer: chinese
      ),
      "重置 02:02"
    )
    XCTAssertEqual(
      MetricFormatter.compactResetCountdown(
        until: now.addingTimeInterval(93_600),
        now: now,
        localizer: chinese
      ),
      "重置 1天02时"
    )
  }

  func testQuotaAccessibilityIncludesLiveResetStateInBothLanguages() {
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
      MetricFormatter.quotaAccessibilityValue(
        for: active,
        now: now,
        localizer: english
      ),
      "75% remaining, Resets in 1 hour 1 minute"
    )
    XCTAssertEqual(
      MetricFormatter.quotaAccessibilityValue(
        for: passed,
        now: now,
        localizer: english
      ),
      "75% remaining, Resetting soon"
    )
    XCTAssertEqual(
      MetricFormatter.quotaAccessibilityValue(
        for: pendingSync,
        now: now,
        localizer: chinese
      ),
      "剩余 75%，等待同步"
    )
    XCTAssertEqual(
      MetricFormatter.quotaAccessibilityValue(
        for: nil,
        now: now,
        localizer: chinese
      ),
      "尚无数据"
    )
  }
}
