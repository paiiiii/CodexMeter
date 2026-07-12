import XCTest

@testable import CodexMeterKit

final class DesignSystemTests: XCTestCase {
  private let english = AppLocalizer(language: .english)
  private let chinese = AppLocalizer(language: .simplifiedChinese)

  func testQuotaSeverityBoundariesAndUnavailableState() {
    let expectations: [(Int?, QuotaSeverity)] = [
      (nil, .unavailable),
      (-1, .critical),
      (0, .critical),
      (20, .critical),
      (21, .caution),
      (50, .caution),
      (51, .healthy),
      (100, .healthy),
      (101, .healthy),
    ]

    for (remainingPercent, expectedSeverity) in expectations {
      XCTAssertEqual(
        QuotaSeverity.classify(remainingPercent: remainingPercent),
        expectedSeverity,
        "Unexpected severity for \(String(describing: remainingPercent))"
      )
    }
  }

  func testConnectionSignalResolutionPriority() {
    XCTAssertEqual(
      ConnectionSignal.resolve(isRefreshing: true, hasSnapshot: true, hasError: true),
      .syncing
    )
    XCTAssertEqual(
      ConnectionSignal.resolve(isRefreshing: false, hasSnapshot: true, hasError: true),
      .cached
    )
    XCTAssertEqual(
      ConnectionSignal.resolve(isRefreshing: false, hasSnapshot: false, hasError: true),
      .offline
    )
    XCTAssertEqual(
      ConnectionSignal.resolve(isRefreshing: false, hasSnapshot: true, hasError: false),
      .live
    )
    XCTAssertEqual(
      ConnectionSignal.resolve(isRefreshing: false, hasSnapshot: false, hasError: false),
      .connecting
    )
  }

  func testMotionTokensAreOrderedAndHonorReducedMotion() {
    XCTAssertGreaterThan(CodexMeterDesign.Motion.immediate, 0)
    XCTAssertLessThan(CodexMeterDesign.Motion.immediate, CodexMeterDesign.Motion.standard)
    XCTAssertLessThan(CodexMeterDesign.Motion.standard, CodexMeterDesign.Motion.data)
    XCTAssertLessThan(CodexMeterDesign.Motion.data, CodexMeterDesign.Motion.refresh)
    XCTAssertLessThan(CodexMeterDesign.Motion.refresh, CodexMeterDesign.Motion.pulse)

    XCTAssertEqual(
      CodexMeterDesign.Motion.duration(CodexMeterDesign.Motion.data, reduceMotion: false),
      CodexMeterDesign.Motion.data
    )
    XCTAssertEqual(
      CodexMeterDesign.Motion.duration(CodexMeterDesign.Motion.data, reduceMotion: true),
      0
    )
    XCTAssertTrue(CodexMeterDesign.Motion.allowsContinuousEffects(reduceMotion: false))
    XCTAssertFalse(CodexMeterDesign.Motion.allowsContinuousEffects(reduceMotion: true))
  }

  func testSpacingRadiusAndMetricTokensKeepTheirHierarchy() {
    let spacing = [
      CodexMeterDesign.Spacing.compact,
      CodexMeterDesign.Spacing.small,
      CodexMeterDesign.Spacing.medium,
      CodexMeterDesign.Spacing.large,
      CodexMeterDesign.Spacing.xLarge,
    ]
    XCTAssertEqual(spacing, spacing.sorted())
    XCTAssertEqual(Set(spacing).count, spacing.count)
    XCTAssertTrue(spacing.allSatisfy { $0 > 0 })

    XCTAssertLessThan(CodexMeterDesign.Radius.control, CodexMeterDesign.Radius.panel)
    XCTAssertLessThan(CodexMeterDesign.Radius.panel, CodexMeterDesign.Radius.surface)

    XCTAssertEqual(
      CodexMeterDesign.Metrics.widgetSize,
      CGSize(width: 348, height: 238)
    )
    XCTAssertGreaterThan(
      CodexMeterDesign.Metrics.widgetSize.width,
      CodexMeterDesign.Metrics.widgetSize.height
    )
    XCTAssertGreaterThan(
      CodexMeterDesign.Metrics.quotaRing,
      CodexMeterDesign.Metrics.brandGlyph
    )
    XCTAssertGreaterThan(
      CodexMeterDesign.Metrics.quotaRing,
      CodexMeterDesign.Metrics.controlHeight
    )
    XCTAssertEqual(
      CodexMeterDesign.Metrics.iconControl,
      CodexMeterDesign.Metrics.controlHeight
    )
    XCTAssertLessThan(
      CodexMeterDesign.Metrics.quotaStroke,
      CodexMeterDesign.Metrics.quotaRing / 2
    )
    XCTAssertLessThan(
      CodexMeterDesign.Metrics.outerInset,
      CodexMeterDesign.Metrics.contentInset
    )
  }

  func testCompactModeTitlesAndCachedStateAreLocalized() {
    XCTAssertEqual(
      WidgetPresentationMode.floating.localizedCompactTitle(using: english),
      "Top"
    )
    XCTAssertEqual(
      WidgetPresentationMode.desktop.localizedCompactTitle(using: english),
      "Desktop"
    )
    XCTAssertEqual(
      WidgetPresentationMode.hidden.localizedCompactTitle(using: english),
      "Hide"
    )
    XCTAssertEqual(
      WidgetPresentationMode.floating.localizedCompactTitle(using: chinese),
      "置顶"
    )
    XCTAssertEqual(
      WidgetPresentationMode.desktop.localizedCompactTitle(using: chinese),
      "桌面"
    )
    XCTAssertEqual(
      WidgetPresentationMode.hidden.localizedCompactTitle(using: chinese),
      "隐藏"
    )
    XCTAssertEqual(english.string(.widgetStatusCached), "Cached")
    XCTAssertEqual(chinese.string(.widgetStatusCached), "缓存")
  }
}
