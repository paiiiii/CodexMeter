import SwiftUI

public struct SettingsView: View {
  private let store: UsageStore
  private let coordinator: WidgetWindowCoordinator
  private let loginItemController: LoginItemController

  @Environment(LanguageController.self) private var languageController

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
      Section(localizer.string(.languageSection)) {
        Picker(localizer.string(.languagePicker), selection: languageBinding) {
          ForEach(AppLanguage.allCases) { language in
            Text(language.localizedTitle(using: localizer))
              .tag(language)
          }
        }
      }

      Section(localizer.string(.settingsDisplaySection)) {
        Picker(localizer.string(.settingsWidgetMode), selection: modeBinding) {
          ForEach(WidgetPresentationMode.allCases) { mode in
            Label(mode.localizedTitle(using: localizer), systemImage: mode.systemImage)
              .tag(mode)
          }
        }
        .pickerStyle(.segmented)

        Text(modeDescription)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section(localizer.string(.settingsSyncSection)) {
        Picker(localizer.string(.settingsRefreshInterval), selection: refreshIntervalBinding) {
          Text(localizer.string(.interval15Seconds)).tag(TimeInterval(15))
          Text(localizer.string(.interval30Seconds)).tag(TimeInterval(30))
          Text(localizer.string(.interval1Minute)).tag(TimeInterval(60))
          Text(localizer.string(.interval2Minutes)).tag(TimeInterval(120))
          Text(localizer.string(.interval5Minutes)).tag(TimeInterval(300))
        }

        LabeledContent(localizer.string(.settingsDataSource)) {
          VStack(alignment: .trailing, spacing: CodexMeterDesign.Spacing.compact) {
            HStack(spacing: CodexMeterDesign.Spacing.compact) {
              Circle()
                .fill(connectionSignal.color)
                .frame(
                  width: CodexMeterDesign.Metrics.statusDot,
                  height: CodexMeterDesign.Metrics.statusDot
                )
              Text(connectionStatusTitle)
                .font(CodexMeterDesign.Typography.body)
            }

            Text(
              localizer.string(
                store.snapshot == nil ? .settingsWaitingForCodex : .settingsLocalAppServer
              )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
          }
          .accessibilityElement(children: .combine)
        }

        HStack {
          Button(localizer.string(.commonRefreshNow)) {
            Task { await store.refresh() }
          }
          .disabled(store.isRefreshing)

          if store.isRefreshing {
            ProgressView()
              .controlSize(.small)
          }

          Spacer()

          if let fetchedAt = store.snapshot?.fetchedAt {
            Text(
              localizer.format(
                .settingsLastSyncedFormat,
                localizer.time(fetchedAt, includesSeconds: true)
              )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
          }
        }

        if let error = store.lastErrorDescription {
          HStack(alignment: .top, spacing: CodexMeterDesign.Spacing.small) {
            Image(systemName: "exclamationmark.circle.fill")
              .foregroundStyle(connectionSignal.color)
            Text(error)
              .font(.caption)
              .textSelection(.enabled)
          }
          .padding(CodexMeterDesign.Spacing.small)
          .background(
            connectionSignal.color.opacity(0.08),
            in: RoundedRectangle(
              cornerRadius: CodexMeterDesign.Radius.control,
              style: .continuous
            )
          )
          .accessibilityElement(children: .combine)
        }
      }

      Section(localizer.string(.settingsStartupSection)) {
        Toggle(localizer.string(.settingsLaunchAtLogin), isOn: loginItemBinding)

        if let error = loginItemController.errorDescription {
          VStack(alignment: .leading, spacing: 5) {
            Text(error)
              .font(.caption)
              .foregroundStyle(.orange)
            Button(localizer.string(.settingsOpenLoginItems)) {
              loginItemController.openLoginItemSettings()
            }
            .buttonStyle(.link)
          }
        }
      }

      Section(localizer.string(.settingsPrivacySection)) {
        Text(localizer.string(.settingsPrivacyDescription))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .tint(CodexMeterDesign.ColorToken.signal)
    .frame(
      minWidth: 500,
      idealWidth: 520,
      minHeight: 520,
      idealHeight: 560
    )
    .onAppear {
      loginItemController.refresh()
    }
  }

  private var localizer: AppLocalizer {
    languageController.localizer
  }

  private var connectionSignal: ConnectionSignal {
    ConnectionSignal.resolve(
      isRefreshing: store.isRefreshing,
      hasSnapshot: store.snapshot != nil,
      hasError: store.lastErrorDescription != nil
    )
  }

  private var connectionStatusTitle: String {
    switch connectionSignal {
    case .connecting: localizer.string(.widgetStatusConnecting)
    case .syncing: localizer.string(.widgetStatusSyncing)
    case .live: localizer.string(.widgetStatusLive)
    case .cached: localizer.string(.widgetStatusCached)
    case .offline: localizer.string(.widgetStatusOffline)
    }
  }

  private var languageBinding: Binding<AppLanguage> {
    Binding(
      get: { languageController.language },
      set: { languageController.language = $0 }
    )
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
      localizer.string(.modeFloatingDescription)
    case .desktop:
      localizer.string(.modeDesktopDescription)
    case .hidden:
      localizer.string(.modeHiddenDescription)
    }
  }
}
