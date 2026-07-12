import AppKit
import SwiftUI

struct CodexMeterBrandMark: View {
  enum Style {
    case widget
    case menuBar
  }

  private let image: NSImage?
  private let isTemplate: Bool

  init(style: Style = .widget) {
    let wantsTemplate = style == .menuBar
    isTemplate = wantsTemplate
    image = CodexMeterResources.brandImage(forMenuBar: wantsTemplate)
  }

  var body: some View {
    Group {
      if let image {
        Image(nsImage: image)
          .renderingMode(isTemplate ? .template : .original)
          .resizable()
          .interpolation(.high)
          .scaledToFit()
      } else {
        Image(systemName: "gauge.with.dots.needle.0percent")
          .font(.system(size: isTemplate ? 12 : 14, weight: .semibold))
      }
    }
    .accessibilityHidden(true)
  }
}
