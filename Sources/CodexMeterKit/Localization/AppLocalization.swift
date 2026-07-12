import Foundation
import Observation
import SwiftUI

private final class NotificationObservation: @unchecked Sendable {
  private let notificationCenter: NotificationCenter
  private let token: NSObjectProtocol

  init(notificationCenter: NotificationCenter, token: NSObjectProtocol) {
    self.notificationCenter = notificationCenter
    self.token = token
  }

  deinit {
    notificationCenter.removeObserver(token)
  }
}

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
  case system
  case english = "en"
  case simplifiedChinese = "zh-Hans"

  public var id: String { rawValue }

  func localizedTitle(using localizer: AppLocalizer) -> String {
    switch self {
    case .system: localizer.string(.languageSystem)
    case .english: localizer.string(.languageEnglish)
    case .simplifiedChinese: localizer.string(.languageSimplifiedChinese)
    }
  }
}

enum SupportedAppLanguage: String, CaseIterable, Sendable {
  case english = "en"
  case simplifiedChinese = "zh-Hans"

  var locale: Locale {
    Locale(identifier: rawValue)
  }

  var resourceDirectoryName: String {
    rawValue.lowercased()
  }

  static func resolve(preferredLanguages: [String]) -> SupportedAppLanguage {
    for identifier in preferredLanguages {
      let normalized = identifier.replacingOccurrences(of: "_", with: "-").lowercased()
      if normalized == "zh" || normalized.hasPrefix("zh-") {
        return .simplifiedChinese
      }
      if normalized == "en" || normalized.hasPrefix("en-") {
        return .english
      }
    }
    return .english
  }
}

@MainActor
@Observable
public final class LanguageController: NSObject {
  public static let preferenceKey = "CodexMeter.language"

  public var language: AppLanguage {
    didSet {
      defaults.set(language.rawValue, forKey: Self.preferenceKey)
    }
  }

  public private(set) var systemLanguageRevision = 0

  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let preferredLanguages: () -> [String]
  @ObservationIgnored private let notificationCenter: NotificationCenter
  @ObservationIgnored private var localeObservation: NotificationObservation?

  public init(
    defaults: UserDefaults = .standard,
    preferredLanguages: @escaping () -> [String] = { Locale.preferredLanguages },
    notificationCenter: NotificationCenter = .default
  ) {
    self.defaults = defaults
    self.preferredLanguages = preferredLanguages
    self.notificationCenter = notificationCenter
    language = defaults.string(forKey: Self.preferenceKey)
      .flatMap(AppLanguage.init(rawValue:)) ?? .system
    super.init()

    let token = notificationCenter.addObserver(
      forName: NSLocale.currentLocaleDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.systemLocaleDidChange()
      }
    }
    localeObservation = NotificationObservation(
      notificationCenter: notificationCenter,
      token: token
    )
  }

  public var resolvedLocale: Locale {
    resolvedLanguage.locale
  }

  var localizer: AppLocalizer {
    AppLocalizer(language: resolvedLanguage)
  }

  private var resolvedLanguage: SupportedAppLanguage {
    _ = systemLanguageRevision
    switch language {
    case .system:
      return SupportedAppLanguage.resolve(preferredLanguages: preferredLanguages())
    case .english:
      return .english
    case .simplifiedChinese:
      return .simplifiedChinese
    }
  }

  private func systemLocaleDidChange() {
    guard language == .system else { return }
    systemLanguageRevision &+= 1
  }
}

private struct CodexMeterLanguageModifier: ViewModifier {
  let controller: LanguageController

  func body(content: Content) -> some View {
    content
      .environment(controller)
      .environment(\.locale, controller.resolvedLocale)
  }
}

public extension View {
  func codexMeterLanguage(_ controller: LanguageController) -> some View {
    modifier(CodexMeterLanguageModifier(controller: controller))
  }
}

enum L10nKey: String, CaseIterable, Sendable {
  case languageSection = "language.section"
  case languagePicker = "language.picker"
  case languageSystem = "language.system"
  case languageEnglish = "language.english"
  case languageSimplifiedChinese = "language.simplified_chinese"

  case modeFloating = "mode.floating"
  case modeDesktop = "mode.desktop"
  case modeHidden = "mode.hidden"
  case modeFloatingDescription = "mode.floating.description"
  case modeDesktopDescription = "mode.desktop.description"
  case modeHiddenDescription = "mode.hidden.description"

  case settingsDisplaySection = "settings.display.section"
  case settingsWidgetMode = "settings.widget_mode"
  case settingsSyncSection = "settings.sync.section"
  case settingsRefreshInterval = "settings.refresh_interval"
  case interval15Seconds = "interval.15_seconds"
  case interval30Seconds = "interval.30_seconds"
  case interval1Minute = "interval.1_minute"
  case interval2Minutes = "interval.2_minutes"
  case interval5Minutes = "interval.5_minutes"
  case settingsDataSource = "settings.data_source"
  case settingsWaitingForCodex = "settings.waiting_for_codex"
  case settingsLocalAppServer = "settings.local_app_server"
  case commonRefreshNow = "common.refresh_now"
  case settingsLastSyncedFormat = "settings.last_synced_format"
  case settingsStartupSection = "settings.startup.section"
  case settingsLaunchAtLogin = "settings.launch_at_login"
  case settingsOpenLoginItems = "settings.open_login_items"
  case settingsPrivacySection = "settings.privacy.section"
  case settingsPrivacyDescription = "settings.privacy.description"

  case commonRefreshing = "common.refreshing"
  case commonSettings = "common.settings"
  case commonSettingsEllipsis = "common.settings_ellipsis"
  case commonNoData = "common.no_data"

  case menuShowWidget = "menu.show_widget"
  case menuSwitchAlwaysOnTop = "menu.switch_always_on_top"
  case menuBringForward = "menu.bring_forward"
  case menuRefreshFailedCached = "menu.refresh_failed_cached"
  case menuSyncedFormat = "menu.synced_format"
  case menuQuit = "menu.quit"
  case menuBarRefreshFailedAccessibility = "menubar.refresh_failed_accessibility"
  case menuBarNotSyncedAccessibility = "menubar.not_synced_accessibility"
  case menuBarPrimaryRemainingFormat = "menubar.primary_remaining_format"
  case menuBarPrimaryUnavailable = "menubar.primary_unavailable"
  case menuBarTodayTokensFormat = "menubar.today_tokens_format"
  case menuBarTodayUnavailable = "menubar.today_unavailable"
  case menuBarSummaryFormat = "menubar.summary_format"

  case widgetUsageAccessibility = "widget.usage_accessibility"
  case widgetRefreshAccessibility = "widget.refresh_accessibility"
  case widgetTodayTokens = "widget.today_tokens"
  case widgetReadingLocalCodex = "widget.reading_local_codex"
  case widgetWaitingForCodexData = "widget.waiting_for_codex_data"
  case widgetTodayUnavailable = "widget.today_unavailable"
  case widgetOpenSettings = "widget.open_settings"
  case widgetStatusSyncing = "widget.status.syncing"
  case widgetStatusOffline = "widget.status.offline"
  case widgetStatusLive = "widget.status.live"
  case widgetStatusConnecting = "widget.status.connecting"
  case widgetDataSourceHelp = "widget.data_source_help"
  case widgetConnectionStatusAccessibility = "widget.connection_status_accessibility"

  case quotaPrimary = "quota.primary"
  case quotaPrimaryLimit = "quota.primary_limit"
  case quotaSecondaryLimit = "quota.secondary_limit"
  case quotaRemainingFormat = "quota.remaining_format"
  case quotaShortFallbackFormat = "quota.short_fallback_format"
  case quotaDaysOne = "quota.days.one"
  case quotaDaysOther = "quota.days.other"
  case quotaHoursOne = "quota.hours.one"
  case quotaHoursOther = "quota.hours.other"
  case quotaMinutesOne = "quota.minutes.one"
  case quotaMinutesOther = "quota.minutes.other"
  case quotaShortDaysFormat = "quota.short_days_format"
  case quotaShortHoursFormat = "quota.short_hours_format"
  case quotaShortMinutesFormat = "quota.short_minutes_format"
  case quotaAccessibilityFormat = "quota.accessibility_format"

  case resetWaitingForSync = "reset.waiting_for_sync"
  case resetSoon = "reset.soon"
  case resetMinutesOne = "reset.minutes.one"
  case resetMinutesOther = "reset.minutes.other"
  case resetHoursOneMinutesOne = "reset.hours.one_minutes.one"
  case resetHoursOneMinutesOther = "reset.hours.one_minutes.other"
  case resetHoursOtherMinutesOne = "reset.hours.other_minutes.one"
  case resetHoursOtherMinutesOther = "reset.hours.other_minutes.other"
  case resetDaysOneHoursOne = "reset.days.one_hours.one"
  case resetDaysOneHoursOther = "reset.days.one_hours.other"
  case resetDaysOtherHoursOne = "reset.days.other_hours.one"
  case resetDaysOtherHoursOther = "reset.days.other_hours.other"
  case resetCompactClockFormat = "reset.compact_clock_format"
  case resetCompactDaysFormat = "reset.compact_days_format"

  case errorBinaryNotFound = "error.binary_not_found"
  case errorLaunchFailedFormat = "error.launch_failed_format"
  case errorConnectionClosedFormat = "error.connection_closed_format"
  case errorInvalidMessage = "error.invalid_message"
  case errorRPCFormat = "error.rpc_format"
  case errorRequestTimedOut = "error.request_timed_out"
  case errorUnknownRPC = "error.unknown_rpc"

  case loginRegisteredRequiresApproval = "login.registered_requires_approval"
  case loginApprovalRequired = "login.approval_required"
  case loginBundleUnavailable = "login.bundle_unavailable"
  case loginUnknownStatus = "login.unknown_status"
}

struct AppLocalizer: Sendable {
  let language: SupportedAppLanguage

  var locale: Locale { language.locale }

  func string(_ key: L10nKey) -> String {
    localizedBundle.localizedString(forKey: key.rawValue, value: key.rawValue, table: nil)
  }

  func format(_ key: L10nKey, _ arguments: CVarArg...) -> String {
    String(format: string(key), locale: locale, arguments: arguments)
  }

  func percent(_ value: Int) -> String {
    (Double(value) / 100).formatted(
      .percent
        .precision(.fractionLength(0))
        .locale(locale)
    )
  }

  func decimal(_ value: Int64) -> String {
    value.formatted(
      .number
        .grouping(.automatic)
        .locale(locale)
    )
  }

  func time(_ date: Date, includesSeconds: Bool) -> String {
    if includesSeconds {
      return date.formatted(
        .dateTime
          .hour()
          .minute()
          .second()
          .locale(locale)
      )
    }
    return date.formatted(
      .dateTime
        .hour()
        .minute()
        .locale(locale)
    )
  }

  private var localizedBundle: Bundle {
    guard
      let url = CodexMeterResources.bundle.url(
        forResource: language.resourceDirectoryName,
        withExtension: "lproj"
      ),
      let bundle = Bundle(url: url)
    else {
      return CodexMeterResources.bundle
    }
    return bundle
  }
}
