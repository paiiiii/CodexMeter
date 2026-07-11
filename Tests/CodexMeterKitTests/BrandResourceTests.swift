import AppKit
import XCTest

@testable import CodexMeterKit

final class BrandResourceTests: XCTestCase {
  func testBrandMarkIsATransparentDecodablePNG() throws {
    let url = try XCTUnwrap(CodexMeterResources.markURL)
    let data = try Data(contentsOf: url)
    let representation = try XCTUnwrap(NSBitmapImageRep(data: data))

    XCTAssertEqual(representation.pixelsWide, 128)
    XCTAssertEqual(representation.pixelsHigh, 128)
    XCTAssertTrue(representation.hasAlpha)
    XCTAssertLessThan(try XCTUnwrap(representation.colorAt(x: 0, y: 0)).alphaComponent, 0.05)
  }
}
