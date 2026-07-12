import AppKit
import SwiftUI
import XCTest

@testable import CodexMeterKit

@MainActor
final class MenuBarBadgeTests: XCTestCase {
  func testMenuBarBadgeRendersAtNativeStatusBarScale() throws {
    let badge =
      MenuBarBadge(hasError: false, remainingPercent: 19)
      .foregroundStyle(.black)
      .padding(.horizontal, 4)
      .frame(height: 22)
      .background(Color(red: 0.95, green: 0.70, blue: 0.30))
      .fixedSize()
    let renderer = ImageRenderer(content: badge)
    renderer.scale = 2
    let image = try XCTUnwrap(renderer.cgImage)

    XCTAssertGreaterThan(image.width, 60)
    XCTAssertEqual(image.height, 44)

    if let outputPath = ProcessInfo.processInfo.environment["CODEX_METER_BADGE_SNAPSHOT"] {
      let representation = NSBitmapImageRep(cgImage: image)
      let data = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
      try data.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
    }
  }
}
