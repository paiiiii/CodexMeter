import AppKit
import XCTest

@testable import CodexMeterKit

private actor LayoutTestProvider: UsageProviding {
  func fetchUsage() async throws -> UsageSnapshot {
    UsageSnapshot(
      fetchedAt: .now,
      planType: nil,
      primary: nil,
      secondary: nil,
      todayTokens: nil,
      lifetimeTokens: nil
    )
  }
}

final class WidgetLayoutModeTests: XCTestCase {
  private let english = AppLocalizer(language: .english)
  private let chinese = AppLocalizer(language: .simplifiedChinese)

  func testLayoutMetricsAndContentPolicy() {
    XCTAssertEqual(
      WidgetWindowGeometry.size(for: .full),
      NSSize(width: 348, height: 238)
    )
    XCTAssertEqual(
      WidgetWindowGeometry.size(for: .minimal),
      NSSize(width: 110, height: 110)
    )

    let full = WidgetContentPolicy.policy(for: .full)
    XCTAssertTrue(full.showsHeader)
    XCTAssertTrue(full.showsPrimaryQuota)
    XCTAssertTrue(full.showsTokenUsage)
    XCTAssertTrue(full.showsSecondaryQuota)
    XCTAssertTrue(full.showsControls)
    XCTAssertFalse(full.isMinimal)

    let minimal = WidgetContentPolicy.policy(for: .minimal)
    XCTAssertTrue(minimal.isMinimal)
    XCTAssertFalse(minimal.showsHeader)
    XCTAssertTrue(minimal.showsPrimaryQuota)
    XCTAssertFalse(minimal.showsTokenUsage)
    XCTAssertFalse(minimal.showsSecondaryQuota)
    XCTAssertFalse(minimal.showsControls)
  }

  func testFrameResizeKeepsTopRightAnchorAndClampsToScreen() {
    let fullFrame = NSRect(x: 900, y: 500, width: 348, height: 238)
    let minimalFrame = WidgetWindowGeometry.frameAnchoredTopRight(
      from: fullFrame,
      targetSize: WidgetWindowGeometry.size(for: .minimal)
    )

    XCTAssertEqual(minimalFrame.maxX, fullFrame.maxX)
    XCTAssertEqual(minimalFrame.maxY, fullFrame.maxY)
    XCTAssertEqual(minimalFrame.size, NSSize(width: 110, height: 110))

    let restoredFrame = WidgetWindowGeometry.frameAnchoredTopRight(
      from: minimalFrame,
      targetSize: WidgetWindowGeometry.size(for: .full)
    )
    XCTAssertEqual(restoredFrame, fullFrame)

    let visibleFrame = NSRect(x: 0, y: 0, width: 1_000, height: 700)
    let offscreen = NSRect(x: 960, y: 660, width: 110, height: 110)
    let clamped = WidgetWindowGeometry.clampedFrame(offscreen, to: visibleFrame)
    XCTAssertEqual(clamped.maxX, visibleFrame.maxX - 10)
    XCTAssertEqual(clamped.maxY, visibleFrame.maxY - 10)
  }

  func testLayoutTitlesAndActionsAreLocalized() {
    XCTAssertEqual(WidgetLayoutMode.full.localizedTitle(using: english), "Full")
    XCTAssertEqual(WidgetLayoutMode.minimal.localizedTitle(using: english), "Minimal")
    XCTAssertEqual(WidgetLayoutMode.full.localizedTitle(using: chinese), "完整")
    XCTAssertEqual(WidgetLayoutMode.minimal.localizedTitle(using: chinese), "最小化")
    XCTAssertEqual(english.string(.menuUseMinimalLayout), "Use Minimal View")
    XCTAssertEqual(chinese.string(.menuUseFullLayout), "恢复完整视图")
  }

  @MainActor
  func testLayoutAndPresentationPersistIndependently() throws {
    let suiteName = "CodexMeterTests.LayoutMode.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let languageController = LanguageController(
      defaults: defaults,
      notificationCenter: NotificationCenter()
    )
    let store = UsageStore(
      provider: LayoutTestProvider(),
      languageController: languageController,
      defaults: defaults
    )
    let coordinator = WidgetWindowCoordinator(
      store: store,
      languageController: languageController,
      defaults: defaults
    )

    XCTAssertEqual(coordinator.layoutMode, .full)
    coordinator.setLayoutMode(.minimal)
    coordinator.setMode(.desktop)

    let restored = WidgetWindowCoordinator(
      store: store,
      languageController: languageController,
      defaults: defaults
    )
    XCTAssertEqual(restored.layoutMode, .minimal)
    XCTAssertEqual(restored.mode, .desktop)

    restored.setMode(.hidden)
    restored.showLastVisibleMode()
    XCTAssertEqual(restored.mode, .desktop)
    XCTAssertEqual(restored.layoutMode, .minimal)
  }

  @MainActor
  func testInvalidStoredLayoutFallsBackToFull() throws {
    let suiteName = "CodexMeterTests.LayoutFallback.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set("unsupported", forKey: "CodexMeter.layoutMode")

    let languageController = LanguageController(
      defaults: defaults,
      notificationCenter: NotificationCenter()
    )
    let store = UsageStore(
      provider: LayoutTestProvider(),
      languageController: languageController,
      defaults: defaults
    )
    let coordinator = WidgetWindowCoordinator(
      store: store,
      languageController: languageController,
      defaults: defaults
    )

    XCTAssertEqual(coordinator.layoutMode, .full)
  }
}
