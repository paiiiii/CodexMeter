public enum WidgetLayoutMode: String, CaseIterable, Identifiable, Sendable {
  case full
  case minimal

  public var id: String { rawValue }

  func localizedTitle(using localizer: AppLocalizer) -> String {
    switch self {
    case .full: localizer.string(.layoutFull)
    case .minimal: localizer.string(.layoutMinimal)
    }
  }

  func localizedDescription(using localizer: AppLocalizer) -> String {
    switch self {
    case .full: localizer.string(.layoutFullDescription)
    case .minimal: localizer.string(.layoutMinimalDescription)
    }
  }

  var systemImage: String {
    switch self {
    case .full: "rectangle"
    case .minimal: "circle"
    }
  }
}

struct WidgetContentPolicy: Equatable, Sendable {
  let showsHeader: Bool
  let showsPrimaryQuota: Bool
  let showsTokenUsage: Bool
  let showsSecondaryQuota: Bool
  let showsControls: Bool

  var isMinimal: Bool {
    showsPrimaryQuota
      && !showsHeader
      && !showsTokenUsage
      && !showsSecondaryQuota
      && !showsControls
  }

  static func policy(for layoutMode: WidgetLayoutMode) -> WidgetContentPolicy {
    switch layoutMode {
    case .full:
      WidgetContentPolicy(
        showsHeader: true,
        showsPrimaryQuota: true,
        showsTokenUsage: true,
        showsSecondaryQuota: true,
        showsControls: true
      )
    case .minimal:
      WidgetContentPolicy(
        showsHeader: false,
        showsPrimaryQuota: true,
        showsTokenUsage: false,
        showsSecondaryQuota: false,
        showsControls: false
      )
    }
  }
}
