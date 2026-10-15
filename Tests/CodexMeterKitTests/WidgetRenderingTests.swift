import AppKit
import SwiftUI
import XCTest

@testable import CodexMeterKit

/// Design QA images must not drift with whatever this Mac happens to be doing,
/// so the rendered widget reads a fixed system sample.
private struct FixedSystemMetricsProvider: SystemMetricsProviding {
  let snapshot: SystemMetricsSnapshot

  func sample() -> SystemMetricsSnapshot? { snapshot }
}

private actor DesignSnapshotProvider: UsageProviding {
  let snapshot: UsageSnapshot

  init(snapshot: UsageSnapshot) {
    self.snapshot = snapshot
  }

  func fetchUsage() async throws -> UsageSnapshot {
    snapshot
  }
}

@MainActor
final class WidgetRenderingTests: XCTestCase {
  func testOpaqueWidgetRendersAtItsTokenizedCanvasSize() async throws {
    let englishImage = try await renderWidget(
      language: .english,
      colorScheme: .light,
      layoutMode: .full
    )
    let chineseImage = try await renderWidget(
      language: .simplifiedChinese,
      colorScheme: .dark,
      layoutMode: .full
    )

    try assertCanvas(englishImage)
    try assertCanvas(chineseImage)

    guard
      let directory = ProcessInfo.processInfo.environment[
        "CODEX_METER_WIDGET_SNAPSHOT_DIR"
      ]
    else { return }

    try FileManager.default.createDirectory(
      atPath: directory,
      withIntermediateDirectories: true
    )
    try writePNG(
      englishImage,
      to: URL(fileURLWithPath: directory).appendingPathComponent("widget-en-light.png")
    )
    try writePNG(
      chineseImage,
      to: URL(fileURLWithPath: directory).appendingPathComponent("widget-zh-dark.png")
    )
  }

  func testMinimalWidgetRendersItsGlassRingOnATransparentCanvas() async throws {
    let englishImage = try await renderWidget(
      language: .english,
      colorScheme: .light,
      layoutMode: .minimal,
      primaryUsedPercent: 5
    )
    let chineseImage = try await renderWidget(
      language: .simplifiedChinese,
      colorScheme: .dark,
      layoutMode: .minimal,
      primaryUsedPercent: 5
    )

    try assertMinimalCanvas(englishImage)
    try assertMinimalCanvas(chineseImage)

    guard
      let directory = ProcessInfo.processInfo.environment[
        "CODEX_METER_WIDGET_SNAPSHOT_DIR"
      ]
    else { return }

    try FileManager.default.createDirectory(
      atPath: directory,
      withIntermediateDirectories: true
    )
    try writePNG(
      englishImage,
      to: URL(fileURLWithPath: directory)
        .appendingPathComponent("widget-minimal-en-light.png")
    )
    try writePNG(
      chineseImage,
      to: URL(fileURLWithPath: directory)
        .appendingPathComponent("widget-minimal-zh-dark.png")
    )
  }

  func testMinimalWidgetKeepsItsWidestSystemValuesInsideTheRing() async throws {
    let englishImage = try await renderWidget(
      language: .english,
      colorScheme: .light,
      layoutMode: .minimal,
      primaryUsedPercent: 0,
      system: .designQAStressFixture
    )
    let chineseImage = try await renderWidget(
      language: .simplifiedChinese,
      colorScheme: .dark,
      layoutMode: .minimal,
      primaryUsedPercent: 0,
      system: .designQAStressFixture
    )

    try assertMinimalCanvas(englishImage)
    try assertMinimalCanvas(chineseImage)

    guard
      let directory = ProcessInfo.processInfo.environment[
        "CODEX_METER_WIDGET_SNAPSHOT_DIR"
      ]
    else { return }

    try FileManager.default.createDirectory(
      atPath: directory,
      withIntermediateDirectories: true
    )
    try writePNG(
      englishImage,
      to: URL(fileURLWithPath: directory)
        .appendingPathComponent("widget-minimal-stress-en-light.png")
    )
    try writePNG(
      chineseImage,
      to: URL(fileURLWithPath: directory)
        .appendingPathComponent("widget-minimal-stress-zh-dark.png")
    )
  }

  func testWidgetMorphMidpointRendersAContractingSurface() async throws {
    let midpointSize = CGSize(width: 229, height: 174)
    let image = try await renderWidget(
      language: .english,
      colorScheme: .light,
      layoutMode: .full,
      primaryUsedPercent: 12,
      renderSize: midpointSize
    )

    XCTAssertEqual(image.width, Int(midpointSize.width * 2))
    XCTAssertEqual(image.height, Int(midpointSize.height * 2))
    let bitmap = NSBitmapImageRep(cgImage: image)
    XCTAssertLessThan(
      try XCTUnwrap(bitmap.colorAt(x: 0, y: 0)).alphaComponent,
      0.05
    )
    XCTAssertGreaterThan(
      try XCTUnwrap(
        bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)
      ).alphaComponent,
      0.95
    )

    guard
      let directory = ProcessInfo.processInfo.environment[
        "CODEX_METER_WIDGET_SNAPSHOT_DIR"
      ]
    else { return }
    try FileManager.default.createDirectory(
      atPath: directory,
      withIntermediateDirectories: true
    )
    try writePNG(
      image,
      to: URL(fileURLWithPath: directory)
        .appendingPathComponent("widget-morph-midpoint-en-light.png")
    )
  }

  private func assertCanvas(_ image: CGImage) throws {
    XCTAssertEqual(
      image.width,
      Int(CodexMeterDesign.Metrics.widgetSize.width * 2)
    )
    XCTAssertEqual(
      image.height,
      Int(CodexMeterDesign.Metrics.widgetSize.height * 2)
    )

    let bitmap = try XCTUnwrap(NSBitmapImageRep(cgImage: image))
    let center = try XCTUnwrap(
      bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)
    )
    XCTAssertGreaterThan(center.alphaComponent, 0.95)
  }

  private func assertMinimalCanvas(_ image: CGImage) throws {
    XCTAssertEqual(
      image.width,
      Int(CodexMeterDesign.Metrics.minimalWidgetSize.width * 2)
    )
    XCTAssertEqual(
      image.height,
      Int(CodexMeterDesign.Metrics.minimalWidgetSize.height * 2)
    )

    let bitmap = try XCTUnwrap(NSBitmapImageRep(cgImage: image))
    let corners = [
      bitmap.colorAt(x: 0, y: 0),
      bitmap.colorAt(x: bitmap.pixelsWide - 1, y: 0),
      bitmap.colorAt(x: 0, y: bitmap.pixelsHigh - 1),
      bitmap.colorAt(x: bitmap.pixelsWide - 1, y: bitmap.pixelsHigh - 1),
    ]
    for corner in corners {
      XCTAssertLessThan(try XCTUnwrap(corner).alphaComponent, 0.05)
    }

    let center = try XCTUnwrap(
      bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)
    )
    XCTAssertGreaterThan(center.alphaComponent, 0.95)

    var visiblePixelCount = 0
    for y in 0..<bitmap.pixelsHigh {
      for x in 0..<bitmap.pixelsWide
      where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.1 {
        visiblePixelCount += 1
      }
    }
    XCTAssertGreaterThan(visiblePixelCount, 2_000)
  }

  private func writePNG(_ image: CGImage, to url: URL) throws {
    let representation = NSBitmapImageRep(cgImage: image)
    let data = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
    try data.write(to: url, options: .atomic)
  }

  private func renderWidget(
    language: AppLanguage,
    colorScheme: ColorScheme,
    layoutMode: WidgetLayoutMode,
    primaryUsedPercent: Int = 45,
    system: SystemMetricsSnapshot = .designQAFixture,
    renderSize: CGSize? = nil
  ) async throws -> CGImage {
    let suiteName = "CodexMeterTests.Rendering.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let languageController = LanguageController(
      defaults: defaults,
      preferredLanguages: { ["en-US"] },
      notificationCenter: NotificationCenter()
    )
    languageController.language = language

    let now = Date.now
    let provider = DesignSnapshotProvider(
      snapshot: UsageSnapshot(
        fetchedAt: now,
        planType: "plus",
        primary: QuotaWindow(
          usedPercent: primaryUsedPercent,
          windowDurationMinutes: 300,
          resetsAt: now.addingTimeInterval(4 * 3_600 + 17 * 60)
        ),
        secondary: QuotaWindow(
          usedPercent: 38,
          windowDurationMinutes: 10_080,
          resetsAt: now.addingTimeInterval(5 * 86_400)
        ),
        todayTokens: 55_000_123,
        lifetimeTokens: nil
      )
    )
    let store = UsageStore(
      provider: provider,
      languageController: languageController,
      defaults: defaults
    )
    await store.refresh()
    let coordinator = WidgetWindowCoordinator(
      store: store,
      languageController: languageController,
      defaults: defaults,
      systemMetricsProvider: FixedSystemMetricsProvider(snapshot: system)
    )
    coordinator.setLayoutMode(layoutMode)

    let widgetSize = renderSize ?? CodexMeterDesign.Metrics.widgetSize(for: layoutMode)

    let view = WidgetView(store: store, coordinator: coordinator)
      .frame(
        width: widgetSize.width,
        height: widgetSize.height
      )
      .codexMeterLanguage(languageController)
      .environment(\.colorScheme, colorScheme)
      .environment(\.codexMeterForceOpaqueSurface, true)

    let renderer = ImageRenderer(content: view)
    renderer.scale = 2
    return try XCTUnwrap(renderer.cgImage)
  }
}


extension SystemMetricsSnapshot {
  /// A calm but non-trivial machine: two thirds of memory in use, no swap, and a
  /// comfortably filled startup volume.
  static let designQAFixture = SystemMetricsSnapshot(
    sampledAt: Date(timeIntervalSince1970: 1_000_000),
    memoryUsedBytes: 22_548_578_304,
    memoryTotalBytes: 34_359_738_368,
    swapUsedBytes: 0,
    swapTotalBytes: 0,
    diskUsedBytes: 578_000_000_000,
    diskTotalBytes: 994_662_584_320
  )

  /// The widest string every stat row can produce, for crop-safety review.
  static let designQAStressFixture = SystemMetricsSnapshot(
    sampledAt: Date(timeIntervalSince1970: 1_000_000),
    memoryUsedBytes: 137_438_953_472,
    memoryTotalBytes: 137_438_953_472,
    swapUsedBytes: 13_314_398_617,
    swapTotalBytes: 16_106_127_360,
    diskUsedBytes: 3_995_035_832_320,
    diskTotalBytes: 3_995_035_832_320
  )
}
