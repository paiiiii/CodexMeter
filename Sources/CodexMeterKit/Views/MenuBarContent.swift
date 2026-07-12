import AppKit
import SwiftUI

public struct MenuBarContent: View {
  private let store: UsageStore
  private let coordinator: WidgetWindowCoordinator

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
          mode.title,
          systemImage: coordinator.mode == mode ? "checkmark" : mode.systemImage
        )
      }
    }

    Divider()

    Button {
      Task { await store.refresh() }
    } label: {
      Label(store.isRefreshing ? "正在刷新…" : "立即刷新", systemImage: "arrow.clockwise")
    }
    .disabled(store.isRefreshing)

    if let error = store.lastErrorDescription {
      Text("刷新失败 · 正在显示上次数据")
        .help(error)
    } else if let fetchedAt = store.snapshot?.fetchedAt {
      Text("已同步 · \(fetchedAt.formatted(date: .omitted, time: .shortened))")
    }

    SettingsLink {
      Label("设置…", systemImage: "gearshape")
    }

    Divider()

    Button("退出 CodexMeter") {
      NSApplication.shared.terminate(nil)
    }
    .keyboardShortcut("q")
  }

  private var primaryActionTitle: String {
    switch coordinator.mode {
    case .hidden: "显示小组件"
    case .desktop: "切换到始终置顶"
    case .floating: "将小组件置于前方"
    }
  }
}

public struct MenuBarLabel: View {
  private let store: UsageStore

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
      return "刷新失败，当前显示上次同步数据"
    }
    guard let snapshot = store.snapshot else { return "尚未同步" }
    let quota =
      snapshot.primary.map { "主要额度剩余 \($0.remainingPercent) 百分比" }
      ?? "主要额度暂不可用"
    let tokens =
      snapshot.todayTokens.map { "今日使用 \($0) Token" }
      ?? "今日 Token 暂不可用"
    return "\(quota)，\(tokens)"
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
