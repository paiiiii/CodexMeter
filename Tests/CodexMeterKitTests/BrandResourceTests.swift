import AppKit
import XCTest

@testable import CodexMeterKit

final class BrandResourceTests: XCTestCase {
  func testBrandMarksAreTransparentDecodablePNGs() throws {
    try assertTransparentPNG(
      at: CodexMeterResources.markURL,
      width: 128,
      height: 128
    )
    try assertTransparentPNG(
      at: CodexMeterResources.menuBarMarkURL,
      width: 64,
      height: 64
    )
  }

  func testMenuBarBrandImageUsesAnIndependentTemplateInstance() throws {
    let widgetImage = try XCTUnwrap(CodexMeterResources.brandImage(forMenuBar: false))
    let menuBarImage = try XCTUnwrap(CodexMeterResources.brandImage(forMenuBar: true))
    let secondWidgetImage = try XCTUnwrap(CodexMeterResources.brandImage(forMenuBar: false))

    XCTAssertFalse(widgetImage.isTemplate)
    XCTAssertTrue(menuBarImage.isTemplate)
    XCTAssertFalse(secondWidgetImage.isTemplate)
    XCTAssertFalse(widgetImage === menuBarImage)
    XCTAssertFalse(menuBarImage === secondWidgetImage)
  }

  func testWidgetAndMenuBarImagesShareCompactGlyphPixels() throws {
    let widgetImage = try XCTUnwrap(CodexMeterResources.brandImage(forMenuBar: false))
    let menuBarImage = try XCTUnwrap(CodexMeterResources.brandImage(forMenuBar: true))
    let widgetRepresentation = try XCTUnwrap(widgetImage.tiffRepresentation)
    let menuBarRepresentation = try XCTUnwrap(menuBarImage.tiffRepresentation)

    XCTAssertEqual(widgetImage.size, NSSize(width: 64, height: 64))
    XCTAssertEqual(menuBarImage.size, widgetImage.size)
    XCTAssertEqual(widgetRepresentation, menuBarRepresentation)
    XCTAssertFalse(widgetImage.isTemplate)
    XCTAssertTrue(menuBarImage.isTemplate)
  }

  func testMenuBarBrandMarkFillsItsSmallOpticalCanvas() throws {
    let url = try XCTUnwrap(CodexMeterResources.menuBarMarkURL)
    let representation = try XCTUnwrap(NSBitmapImageRep(data: try Data(contentsOf: url)))
    var visibleX: [Int] = []
    var visibleY: [Int] = []

    for y in 0..<representation.pixelsHigh {
      for x in 0..<representation.pixelsWide
      where (representation.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.03 {
        visibleX.append(x)
        visibleY.append(y)
      }
    }

    let width = try XCTUnwrap(visibleX.max()) - (try XCTUnwrap(visibleX.min())) + 1
    let height = try XCTUnwrap(visibleY.max()) - (try XCTUnwrap(visibleY.min())) + 1
    XCTAssertGreaterThanOrEqual(width, 50)
    XCTAssertGreaterThanOrEqual(height, 50)
  }

  private func assertTransparentPNG(at url: URL?, width: Int, height: Int) throws {
    let url = try XCTUnwrap(url)
    let data = try Data(contentsOf: url)
    let representation = try XCTUnwrap(NSBitmapImageRep(data: data))

    XCTAssertEqual(representation.pixelsWide, width)
    XCTAssertEqual(representation.pixelsHigh, height)
    XCTAssertTrue(representation.hasAlpha)
    XCTAssertLessThan(try XCTUnwrap(representation.colorAt(x: 0, y: 0)).alphaComponent, 0.05)
  }
}
