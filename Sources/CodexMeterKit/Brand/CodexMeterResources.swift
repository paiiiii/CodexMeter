import Foundation

enum CodexMeterResources {
  static var markURL: URL? {
    Bundle.module.url(forResource: "CodexMeterMark", withExtension: "png")
  }
}
