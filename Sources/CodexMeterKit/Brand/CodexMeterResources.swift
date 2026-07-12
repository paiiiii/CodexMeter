import AppKit

enum CodexMeterResources {
  static var markURL: URL? {
    Bundle.module.url(forResource: "CodexMeterMark", withExtension: "png")
  }

  static var menuBarMarkURL: URL? {
    Bundle.module.url(forResource: "CodexMeterMenuBarMark", withExtension: "png")
  }

  static func brandImage(forMenuBar: Bool) -> NSImage? {
    let url = forMenuBar ? menuBarMarkURL : markURL
    guard let url, let image = NSImage(contentsOf: url) else { return nil }
    image.isTemplate = forMenuBar
    return image
  }
}
