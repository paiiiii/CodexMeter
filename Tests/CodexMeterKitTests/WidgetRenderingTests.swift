import AppKit
import SwiftUI
import XCTest

@testable import CodexMeterKit

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
    let englishImage = try await renderWidget(language: .english, colorScheme: .light)
    let chineseImage = try await renderWidget(
      language: .simplifiedChinese,
      colorScheme: .dark
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

  private func writePNG(_ image: CGImage, to url: URL) throws {
    let representation = NSBitmapImageRep(cgImage: image)
    let data = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
    try data.write(to: url, options: .atomic)
  }

  private func renderWidget(
    language: AppLanguage,
    colorScheme: ColorScheme
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
          usedPercent: 45,
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
      defaults: defaults
    )

    let view = WidgetView(store: store, coordinator: coordinator)
      .frame(
        width: CodexMeterDesign.Metrics.widgetSize.width,
        height: CodexMeterDesign.Metrics.widgetSize.height
      )
      .codexMeterLanguage(languageController)
      .environment(\.colorScheme, colorScheme)
      .environment(\.codexMeterForceOpaqueSurface, true)

    let renderer = ImageRenderer(content: view)
    renderer.scale = 2
    return try XCTUnwrap(renderer.cgImage)
  }
}
