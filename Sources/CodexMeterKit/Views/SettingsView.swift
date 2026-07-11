import SwiftUI

public struct SettingsView: View {
  private let store: UsageStore
  private let coordinator: WidgetWindowCoordinator
  private let loginItemController: LoginItemController

  public init(
    store: UsageStore,
    coordinator: WidgetWindowCoordinator,
    loginItemController: LoginItemController
  ) {
    self.store = store
    self.coordinator = coordinator
    self.loginItemController = loginItemController
  }

  public var body: some View {
    Form {
      Section("显示") {
        Picker("小组件模式", selection: modeBinding) {
          ForEach(WidgetPresentationMode.allCases) { mode in
            Label(mode.title, systemImage: mode.systemImage)
              .tag(mode)
          }
        }
        .pickerStyle(.segmented)

        Text(modeDescription)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section("同步") {
        Picker("刷新频率", selection: refreshIntervalBinding) {
          Text("15 秒").tag(TimeInterval(15))
          Text("30 秒").tag(TimeInterval(30))
          Text("1 分钟").tag(TimeInterval(60))
          Text("2 分钟").tag(TimeInterval(120))
          Text("5 分钟").tag(TimeInterval(300))
        }

        LabeledContent("数据源") {
          HStack(spacing: 6) {
            Circle()
              .fill(store.lastErrorDescription == nil && store.snapshot != nil ? .green : .orange)
              .frame(width: 7, height: 7)
            Text(store.snapshot == nil ? "等待 Codex" : "本机 Codex app-server")
          }
        }

        HStack {
          Button("立即刷新") {
            Task { await store.refresh() }
          }
          .disabled(store.isRefreshing)

          if store.isRefreshing {
            ProgressView()
              .controlSize(.small)
          }

          Spacer()

          if let fetchedAt = store.snapshot?.fetchedAt {
            Text("上次同步 \(fetchedAt.formatted(date: .omitted, time: .standard))")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        if let error = store.lastErrorDescription {
          Text(error)
            .font(.caption)
            .foregroundStyle(.orange)
            .textSelection(.enabled)
        }
      }

      Section("启动") {
        Toggle("登录时自动启动", isOn: loginItemBinding)

        if let error = loginItemController.errorDescription {
          VStack(alignment: .leading, spacing: 5) {
            Text(error)
              .font(.caption)
              .foregroundStyle(.orange)
            Button("打开登录项设置") {
              loginItemController.openLoginItemSettings()
            }
            .buttonStyle(.link)
          }
        }
      }

      Section("隐私") {
        Text(
          "CodexMeter 只与本机 Codex 进程通信，不读取 auth.json，也不会上传或保存你的凭证。额度和 Token 数据由 Codex 官方本地 app-server 返回。"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .frame(width: 500, height: 440)
    .onAppear {
      loginItemController.refresh()
    }
  }

  private var modeBinding: Binding<WidgetPresentationMode> {
    Binding(
      get: { coordinator.mode },
      set: { coordinator.setMode($0) }
    )
  }

  private var refreshIntervalBinding: Binding<TimeInterval> {
    Binding(
      get: { store.refreshInterval },
      set: { store.refreshInterval = $0 }
    )
  }

  private var loginItemBinding: Binding<Bool> {
    Binding(
      get: { loginItemController.isEnabled },
      set: { loginItemController.setEnabled($0) }
    )
  }

  private var modeDescription: String {
    switch coordinator.mode {
    case .floating:
      "跨桌面空间显示，并保持在普通窗口上方。"
    case .desktop:
      "固定在普通窗口后方，像桌面插件一样显示。"
    case .hidden:
      "隐藏小组件；可随时从菜单栏恢复。"
    }
  }
}
