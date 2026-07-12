import AppKit

public enum WidgetPresentationMode: String, CaseIterable, Identifiable, Sendable {
  case floating
  case desktop
  case hidden

  public var id: String { rawValue }

  func localizedTitle(using localizer: AppLocalizer) -> String {
    switch self {
    case .floating: localizer.string(.modeFloating)
    case .desktop: localizer.string(.modeDesktop)
    case .hidden: localizer.string(.modeHidden)
    }
  }

  public var systemImage: String {
    switch self {
    case .floating: "pin.fill"
    case .desktop: "macwindow.on.rectangle"
    case .hidden: "eye.slash.fill"
    }
  }
}

public struct WindowModePolicy {
  public let level: NSWindow.Level
  public let collectionBehavior: NSWindow.CollectionBehavior
  public let isFloatingPanel: Bool
  public let isVisible: Bool
  public let hasShadow: Bool

  public static func policy(for mode: WidgetPresentationMode) -> WindowModePolicy {
    switch mode {
    case .floating:
      WindowModePolicy(
        level: .floating,
        collectionBehavior: [
          .canJoinAllSpaces,
          .canJoinAllApplications,
          .transient,
          .ignoresCycle,
        ],
        isFloatingPanel: true,
        isVisible: true,
        hasShadow: true
      )
    case .desktop:
      WindowModePolicy(
        level: NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue - 1),
        collectionBehavior: [
          .canJoinAllSpaces,
          .stationary,
          .ignoresCycle,
          .fullScreenNone,
        ],
        isFloatingPanel: false,
        isVisible: true,
        hasShadow: false
      )
    case .hidden:
      WindowModePolicy(
        level: .normal,
        collectionBehavior: [.ignoresCycle],
        isFloatingPanel: false,
        isVisible: false,
        hasShadow: false
      )
    }
  }
}
