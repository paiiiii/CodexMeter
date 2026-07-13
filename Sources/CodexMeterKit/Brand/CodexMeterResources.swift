import AppKit

enum CodexMeterResources {
  static var bundle: Bundle { .module }

  static var markURL: URL? {
    bundle.url(forResource: "CodexMeterMark", withExtension: "png")
  }

  static var menuBarMarkURL: URL? {
    bundle.url(forResource: "CodexMeterMenuBarMark", withExtension: "png")
  }

  static func brandImage(forMenuBar: Bool) -> NSImage? {
    // The compact transparent glyph belongs inside the widget and menu bar.
    // The full mark is reserved for the app icon and distribution artwork.
    let url = menuBarMarkURL
    guard let url, let image = NSImage(contentsOf: url) else { return nil }
    image.isTemplate = forMenuBar
    if forMenuBar {
      // MenuBarExtra can consult the NSImage's intrinsic point size before
      // applying SwiftUI layout. Keep the template's native size compact so
      // the 64 px source never expands to fill the full menu-bar height.
      image.size = NSSize(
        width: CodexMeterDesign.Metrics.menuBarBrandGlyph,
        height: CodexMeterDesign.Metrics.menuBarBrandGlyph
      )
    }
    return image
  }
}
