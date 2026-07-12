import AppKit
import SwiftUI

public struct MenuBarContent: View {
  private let store: UsageStore
  private let coordinator: WidgetWindowCoordinator

  @Environment(LanguageController.self) private var languageController

  public init(store: UsageStore, coordinator: WidgetWindowCoordinator) {
    self.store = store
    self.coordinator = coordinator
  }

  public var body: some View {
    Button(primaryActionTitle) {
      if coordinator.mode == .hidden {
        coordinator.showLastVisibleMode()
      } else {
        coordinator.bringForward()
      }
    }

    Divider()

    ForEach(WidgetPresentationMode.allCases) { mode in
      Button {
        coordinator.setMode(mode)
      } label: {
        Label(
          mode.localizedTitle(using: localizer),
          systemImage: coordinator.mode == mode ? "checkmark" : mode.systemImage
        )
      }
    }

    Divider()

    Button {
      Task { await store.refresh() }
    } label: {
      Label(
        localizer.string(store.isRefreshing ? .commonRefreshing : .commonRefreshNow),
        systemImage: "arrow.clockwise"
      )
    }
    .disabled(store.isRefreshing)

    if let error = store.lastErrorDescription {
      Text(localizer.string(.menuRefreshFailedCached))
        .help(error)
    } else if let fetchedAt = store.snapshot?.fetchedAt {
      Text(
        localizer.format(
          .menuSyncedFormat,
          localizer.time(fetchedAt, includesSeconds: false)
        )
      )
    }

    SettingsLink {
      Label(localizer.string(.commonSettingsEllipsis), systemImage: "gearshape")
    }

    Divider()

    Button(localizer.string(.menuQuit)) {
      NSApplication.shared.terminate(nil)
    }
    .keyboardShortcut("q")
  }

  private var primaryActionTitle: String {
    switch coordinator.mode {
    case .hidden: localizer.string(.menuShowWidget)
    case .desktop: localizer.string(.menuSwitchAlwaysOnTop)
    case .floating: localizer.string(.menuBringForward)
    }
  }

  private var localizer: AppLocalizer {
    languageController.localizer
  }
}

public struct MenuBarLabel: View {
  private let store: UsageStore

  @Environment(LanguageController.self) private var languageController

  public init(store: UsageStore) {
    self.store = store
  }

  public var body: some View {
    MenuBarBadge(
      hasError: store.lastErrorDescription != nil,
      remainingPercent: store.snapshot?.primary?.remainingPercent
    )
    .accessibilityLabel("CodexMeter")
    .accessibilityValue(menuBarAccessibilityValue)
  }

  private var menuBarAccessibilityValue: String {
    if store.lastErrorDescription != nil {
      return localizer.string(.menuBarRefreshFailedAccessibility)
    }
    guard let snapshot = store.snapshot else {
      return localizer.string(.menuBarNotSyncedAccessibility)
    }
    let quota =
      snapshot.primary.map {
        localizer.format(
          .menuBarPrimaryRemainingFormat,
          localizer.percent($0.remainingPercent)
        )
      }
      ?? localizer.string(.menuBarPrimaryUnavailable)
    let tokens =
      snapshot.todayTokens.map {
        localizer.format(.menuBarTodayTokensFormat, localizer.decimal($0))
      }
      ?? localizer.string(.menuBarTodayUnavailable)
    return localizer.format(.menuBarSummaryFormat, quota, tokens)
  }

  private var localizer: AppLocalizer {
    languageController.localizer
  }
}

struct MenuBarBadge: View {
  let hasError: Bool
  let remainingPercent: Int?

  var body: some View {
    HStack(spacing: 3) {
      if hasError {
        Image(systemName: "exclamationmark.triangle.fill")
        Text("!")
      } else {
        CodexMeterBrandMark(style: .menuBar)
          .frame(
            width: MenuBarBadgeMetrics.brandMarkSize,
            height: MenuBarBadgeMetrics.brandMarkSize
          )
          .foregroundStyle(.primary)

        if let remaining = remainingPercent {
          Text("\(remaining)%")
            .monospacedDigit()
        }
      }
    }
  }
}

enum MenuBarBadgeMetrics {
  static let brandMarkSize: CGFloat = 10
}
