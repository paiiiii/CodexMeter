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
    let url = forMenuBar ? menuBarMarkURL : markURL
    guard let url, let image = NSImage(contentsOf: url) else { return nil }
    image.isTemplate = forMenuBar
    return image
  }
}
