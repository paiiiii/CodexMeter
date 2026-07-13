import AppKit
import SwiftUI
import XCTest

@testable import CodexMeterKit

@MainActor
final class MenuBarBadgeTests: XCTestCase {
  func testMenuBarBadgeRendersAtNativeStatusBarScale() throws {
    let badge =
      MenuBarBadge(hasError: false, remainingPercent: 5)
      .foregroundStyle(.black)
      .padding(.horizontal, 4)
      .frame(height: 22)
      .background(Color(red: 0.95, green: 0.70, blue: 0.30))
      .fixedSize()
    let renderer = ImageRenderer(content: badge)
    renderer.scale = 2
    let image = try XCTUnwrap(renderer.cgImage)

    XCTAssertGreaterThan(image.width, 50)
    XCTAssertLessThan(image.width, 120)
    XCTAssertEqual(image.height, 44)

    if let outputPath = ProcessInfo.processInfo.environment["CODEX_METER_BADGE_SNAPSHOT"] {
      let representation = NSBitmapImageRep(cgImage: image)
      let data = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
      try data.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
    }
  }

  func testMenuBarBrandMarkMatchesNeighboringStatusItemFootprint() throws {
    let mark =
      CodexMeterBrandMark(style: .menuBar)
      .foregroundStyle(.black)
      .frame(
        width: MenuBarBadgeMetrics.brandMarkSize,
        height: MenuBarBadgeMetrics.brandMarkSize
      )
    let renderer = ImageRenderer(content: mark)
    renderer.scale = 2
    let image = try XCTUnwrap(renderer.cgImage)

    XCTAssertEqual(MenuBarBadgeMetrics.brandMarkSize, 20)
    XCTAssertEqual(image.width, 40)
    XCTAssertEqual(image.height, 40)

    let bitmap = NSBitmapImageRep(cgImage: image)
    var visibleX: [Int] = []
    var visibleY: [Int] = []
    for y in 0..<bitmap.pixelsHigh {
      for x in 0..<bitmap.pixelsWide
      where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.03 {
        visibleX.append(x)
        visibleY.append(y)
      }
    }
    let opticalWidth = try XCTUnwrap(visibleX.max()) - (try XCTUnwrap(visibleX.min())) + 1
    let opticalHeight = try XCTUnwrap(visibleY.max()) - (try XCTUnwrap(visibleY.min())) + 1
    XCTAssertGreaterThanOrEqual(opticalWidth, 30)
    XCTAssertLessThanOrEqual(opticalWidth, 36)
    XCTAssertGreaterThanOrEqual(opticalHeight, 30)
    XCTAssertLessThanOrEqual(opticalHeight, 36)
  }
}
