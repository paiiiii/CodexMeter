import AppKit
import SwiftUI

public struct WidgetView: View {
  private let store: UsageStore
  private let coordinator: WidgetWindowCoordinator

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(LanguageController.self) private var languageController

  public init(store: UsageStore, coordinator: WidgetWindowCoordinator) {
    self.store = store
    self.coordinator = coordinator
  }

  public var body: some View {
    Group {
      if contentPolicy.isMinimal {
        minimalWidget
          .transition(.scale(scale: 0.88).combined(with: .opacity))
      } else {
        fullWidget
          .transition(.scale(scale: 0.96).combined(with: .opacity))
      }
    }
    .animation(
      CodexMeterDesign.Motion.smooth(
        CodexMeterDesign.Motion.standard,
        reduceMotion: reduceMotion
      ),
      value: coordinator.layoutMode
    )
  }

  private var fullWidget: some View {
    CodexMeterSurface {
      ZStack {
        AmbientSignal()

        VStack(spacing: 0) {
          header
          mainMetrics
            .padding(.top, CodexMeterDesign.Spacing.small)
          weeklyQuota
            .padding(.top, CodexMeterDesign.Spacing.small)
          controls
            .padding(.top, CodexMeterDesign.Spacing.small)
        }
        .padding(CodexMeterDesign.Metrics.contentInset)
      }
    }
    .padding(CodexMeterDesign.Metrics.outerInset)
    .contentShape(
      RoundedRectangle(
        cornerRadius: CodexMeterDesign.Radius.surface,
        style: .continuous
      )
    )
    .accessibilityElement(children: .contain)
    .accessibilityLabel(localizer.string(.widgetUsageAccessibility))
  }

  private var minimalWidget: some View {
    ZStack {
      CodexMeterCircularGlassBackdrop()
        .padding(CodexMeterDesign.Metrics.quotaStroke / 2)

      QuotaRing(window: store.snapshot?.primary)
    }
    .frame(
      width: CodexMeterDesign.Metrics.minimalQuotaRing,
      height: CodexMeterDesign.Metrics.minimalQuotaRing
    )
    .frame(
      width: CodexMeterDesign.Metrics.minimalWidgetSize.width,
      height: CodexMeterDesign.Metrics.minimalWidgetSize.height
    )
    .contentShape(Circle())
    .help(localizer.string(.widgetMinimalHelp))
    .contextMenu {
      Button(localizer.string(.widgetRestoreFullView)) {
        coordinator.setLayoutMode(.full)
      }
    }
    .accessibilityAction(named: Text(localizer.string(.widgetRestoreFullView))) {
      coordinator.setLayoutMode(.full)
    }
  }

  private var header: some View {
    HStack(spacing: CodexMeterDesign.Spacing.small) {
      CodexMeterBrandMark()
        .frame(
          width: CodexMeterDesign.Metrics.brandGlyph,
          height: CodexMeterDesign.Metrics.brandGlyph
        )

      Text("CODEXMETER")
        .font(CodexMeterDesign.Typography.brand)
        .tracking(1.15)

      Spacer(minLength: 8)

      LiveStatusView(store: store)

      Button {
        Task { await store.refresh() }
      } label: {
        Image(systemName: "arrow.clockwise")
          .font(.system(size: 11, weight: .semibold))
          .rotationEffect(.degrees(store.isRefreshing && !reduceMotion ? 360 : 0))
          .animation(
            store.isRefreshing && !reduceMotion
              ? .linear(duration: CodexMeterDesign.Motion.refresh)
                .repeatForever(autoreverses: false)
              : .default,
            value: store.isRefreshing
          )
          .frame(
            width: CodexMeterDesign.Metrics.iconControl,
            height: CodexMeterDesign.Metrics.iconControl
          )
          .contentShape(
            RoundedRectangle(
              cornerRadius: CodexMeterDesign.Radius.control,
              style: .continuous
            )
          )
          .codexMeterControlBackground()
      }
      .buttonStyle(.plain)
      .disabled(store.isRefreshing)
      .help(localizer.string(.commonRefreshNow))
      .accessibilityLabel(localizer.string(.widgetRefreshAccessibility))

      Button {
        coordinator.setLayoutMode(.minimal)
      } label: {
        Image(systemName: "arrow.down.right.and.arrow.up.left")
          .font(.system(size: 10, weight: .semibold))
          .frame(
            width: CodexMeterDesign.Metrics.iconControl,
            height: CodexMeterDesign.Metrics.iconControl
          )
          .contentShape(
            RoundedRectangle(
              cornerRadius: CodexMeterDesign.Radius.control,
              style: .continuous
            )
          )
          .codexMeterControlBackground()
      }
      .buttonStyle(.plain)
      .help(localizer.string(.widgetUseMinimalView))
      .accessibilityLabel(localizer.string(.widgetUseMinimalView))
    }
    .frame(height: CodexMeterDesign.Metrics.controlHeight)
  }

  private var mainMetrics: some View {
    HStack(spacing: CodexMeterDesign.Spacing.large) {
      QuotaRing(window: store.snapshot?.primary)
        .frame(
          width: CodexMeterDesign.Metrics.quotaRing,
          height: CodexMeterDesign.Metrics.quotaRing
        )

      Rectangle()
        .fill(CodexMeterDesign.ColorToken.divider)
        .frame(width: 1, height: 64)

      VStack(alignment: .leading, spacing: CodexMeterDesign.Spacing.compact) {
        Text(localizer.string(.widgetTodayTokens))
          .font(CodexMeterDesign.Typography.sectionLabel)
          .tracking(1.1)
          .foregroundStyle(.secondary)

        Text(
          MetricFormatter.compactTokens(
            store.snapshot?.todayTokens,
            localizer: localizer
          )
        )
        .font(CodexMeterDesign.Typography.heroMetric)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .contentTransition(
          .numericText(value: Double(store.snapshot?.todayTokens ?? 0))
        )

        if let tokens = store.snapshot?.todayTokens {
          Text(MetricFormatter.exactTokens(tokens, localizer: localizer))
            .font(CodexMeterDesign.Typography.metadata)
            .foregroundStyle(.secondary)
            .contentTransition(.numericText(value: Double(tokens)))
        } else {
          Text(
            store.snapshot == nil
              ? localizer.string(
                store.isRefreshing ? .widgetReadingLocalCodex : .widgetWaitingForCodexData
              )
              : localizer.string(.widgetTodayUnavailable)
          )
          .font(CodexMeterDesign.Typography.metadata)
          .foregroundStyle(.secondary)
          .lineLimit(1)
        }

        PrimaryResetCountdown(date: store.snapshot?.primary?.resetsAt)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(localizer.string(.widgetTodayTokens))
      .accessibilityValue(
        store.snapshot?.todayTokens.map {
          MetricFormatter.exactTokens($0, localizer: localizer)
        } ?? localizer.string(.commonNoData)
      )
    }
    .frame(height: CodexMeterDesign.Metrics.quotaRing)
    .animation(
      CodexMeterDesign.Motion.smooth(
        CodexMeterDesign.Motion.data,
        reduceMotion: reduceMotion
      ),
      value: store.snapshot
    )
  }

  private var weeklyQuota: some View {
    CodexMeterInsetSurface {
      QuotaBar(window: store.snapshot?.secondary)
        .padding(.horizontal, CodexMeterDesign.Spacing.small)
        .padding(.vertical, 6)
    }
    .frame(height: 32)
  }

  private var controls: some View {
    HStack(spacing: 4) {
      ForEach(WidgetPresentationMode.allCases) { mode in
        ModeButton(
          mode: mode,
          isSelected: coordinator.mode == mode
        ) {
          coordinator.setMode(mode)
        }
      }

      Spacer(minLength: 2)

      SettingsLink {
        HStack(spacing: CodexMeterDesign.Spacing.compact) {
          Image(systemName: "slider.horizontal.3")
            .font(.system(size: 10, weight: .semibold))
          Text(localizer.string(.commonSettings))
            .font(CodexMeterDesign.Typography.control)
        }
        .frame(
          width: CodexMeterDesign.Metrics.settingsControlWidth,
          height: CodexMeterDesign.Metrics.controlHeight
        )
        .codexMeterControlBackground()
      }
      .buttonStyle(.plain)
      .help(localizer.string(.commonSettings))
      .accessibilityLabel(localizer.string(.widgetOpenSettings))
    }
    .frame(height: CodexMeterDesign.Metrics.controlHeight)
  }

  private var localizer: AppLocalizer {
    languageController.localizer
  }

  private var contentPolicy: WidgetContentPolicy {
    WidgetContentPolicy.policy(for: coordinator.layoutMode)
  }
}

private struct AmbientSignal: View {
  var body: some View {
    Circle()
      .fill(CodexMeterDesign.ColorToken.signal.opacity(0.075))
      .frame(width: 152, height: 152)
      .blur(radius: 38)
      .offset(x: -122, y: -88)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .allowsHitTesting(false)
      .clipShape(
        RoundedRectangle(
          cornerRadius: CodexMeterDesign.Radius.surface,
          style: .continuous
        )
      )
  }
}

private struct LiveStatusView: View {
  let store: UsageStore

  @Environment(LanguageController.self) private var languageController

  private var signal: ConnectionSignal {
    ConnectionSignal.resolve(
      isRefreshing: store.isRefreshing,
      hasSnapshot: store.snapshot != nil,
      hasError: store.lastErrorDescription != nil
    )
  }

  var body: some View {
    CodexMeterStatusPill(
      title: statusTitle,
      signal: signal,
      accessibilityLabel: localizer.string(.widgetConnectionStatusAccessibility),
      help: store.lastErrorDescription ?? localizer.string(.widgetDataSourceHelp)
    )
  }

  private var statusTitle: String {
    switch signal {
    case .connecting: localizer.string(.widgetStatusConnecting)
    case .syncing: localizer.string(.widgetStatusSyncing)
    case .live: localizer.string(.widgetStatusLive)
    case .cached: localizer.string(.widgetStatusCached)
    case .offline: localizer.string(.widgetStatusOffline)
    }
  }

  private var localizer: AppLocalizer {
    languageController.localizer
  }
}

private struct QuotaRing: View {
  let window: QuotaWindow?

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(LanguageController.self) private var languageController

  private var remaining: Int { window?.remainingPercent ?? 0 }
  private var progress: Double { Double(remaining) / 100 }
  private var severity: QuotaSeverity {
    QuotaSeverity.classify(remainingPercent: window?.remainingPercent)
  }

  var body: some View {
    ZStack {
      Circle()
        .stroke(
          CodexMeterDesign.ColorToken.track,
          lineWidth: CodexMeterDesign.Metrics.quotaStroke
        )

      Circle()
        .trim(from: 0, to: window == nil ? 0 : max(progress, 0.012))
        .stroke(
          severity.color,
          style: StrokeStyle(
            lineWidth: CodexMeterDesign.Metrics.quotaStroke,
            lineCap: .round
          )
        )
        .rotationEffect(.degrees(-90))

      VStack(spacing: CodexMeterDesign.Spacing.compact) {
        Text(window == nil ? "—" : localizer.percent(remaining))
          .font(CodexMeterDesign.Typography.quotaMetric)
          .monospacedDigit()
          .contentTransition(.numericText(value: Double(remaining)))

        Text(
          MetricFormatter.shortQuotaLabel(
            for: window,
            fallback: .quotaPrimary,
            localizer: localizer
          )
        )
        .font(CodexMeterDesign.Typography.sectionLabel)
        .tracking(0.7)
        .foregroundStyle(.secondary)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      MetricFormatter.quotaLabel(
        for: window,
        fallback: .quotaPrimaryLimit,
        localizer: localizer
      )
    )
    .accessibilityValue(
      MetricFormatter.quotaAccessibilityValue(
        for: window,
        localizer: localizer
      )
    )
    .animation(
      CodexMeterDesign.Motion.smooth(
        CodexMeterDesign.Motion.data,
        reduceMotion: reduceMotion
      ),
      value: remaining
    )
  }

  private var localizer: AppLocalizer {
    languageController.localizer
  }
}

private struct QuotaBar: View {
  let window: QuotaWindow?

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(LanguageController.self) private var languageController

  private var remaining: Int { window?.remainingPercent ?? 0 }
  private var progress: Double { Double(remaining) / 100 }
  private var severity: QuotaSeverity {
    QuotaSeverity.classify(remainingPercent: window?.remainingPercent)
  }

  var body: some View {
    VStack(spacing: CodexMeterDesign.Spacing.compact) {
      HStack(spacing: CodexMeterDesign.Spacing.compact) {
        Text(
          MetricFormatter.quotaLabel(
            for: window,
            fallback: .quotaSecondaryLimit,
            localizer: localizer
          )
        )
        .font(CodexMeterDesign.Typography.control)
        Text(
          window == nil
            ? "—"
            : localizer.format(.quotaRemainingFormat, localizer.percent(remaining))
        )
        .font(.system(size: 10, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .contentTransition(.numericText(value: Double(remaining)))

        Spacer()

        ResetCountdownView(date: window?.resetsAt)
      }
      .foregroundStyle(.secondary)

      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule()
            .fill(CodexMeterDesign.ColorToken.track)
          Capsule()
            .fill(severity.color)
            .frame(width: proxy.size.width * (window == nil ? 0 : progress))
        }
      }
      .frame(height: 3)
    }
    .animation(
      CodexMeterDesign.Motion.smooth(
        CodexMeterDesign.Motion.data,
        reduceMotion: reduceMotion
      ),
      value: remaining
    )
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      MetricFormatter.quotaLabel(
        for: window,
        fallback: .quotaSecondaryLimit,
        localizer: localizer
      )
    )
    .accessibilityValue(
      MetricFormatter.quotaAccessibilityValue(for: window, localizer: localizer)
    )
  }

  private var localizer: AppLocalizer {
    languageController.localizer
  }
}

private struct ResetCountdownView: View {
  let date: Date?

  @Environment(LanguageController.self) private var languageController

  var body: some View {
    TimelineView(.periodic(from: .now, by: 60)) { context in
      Text(
        MetricFormatter.compactResetCountdown(
          until: date,
          now: context.date,
          localizer: languageController.localizer
        )
      )
      .font(CodexMeterDesign.Typography.metadata)
      .monospacedDigit()
    }
  }
}

private struct PrimaryResetCountdown: View {
  let date: Date?

  @Environment(LanguageController.self) private var languageController

  var body: some View {
    TimelineView(.periodic(from: .now, by: 60)) { context in
      HStack(spacing: CodexMeterDesign.Spacing.compact) {
        Image(systemName: "clock")
          .font(.system(size: 9, weight: .semibold))
        Text(
          MetricFormatter.resetCountdown(
            until: date,
            now: context.date,
            localizer: localizer
          )
        )
        .font(CodexMeterDesign.Typography.metadata)
        .monospacedDigit()
        .lineLimit(1)
      }
      .foregroundStyle(.secondary)
      .accessibilityElement(children: .combine)
    }
  }

  private var localizer: AppLocalizer {
    languageController.localizer
  }
}

private struct ModeButton: View {
  let mode: WidgetPresentationMode
  let isSelected: Bool
  let action: () -> Void

  @Environment(LanguageController.self) private var languageController

  var body: some View {
    Button(action: action) {
      HStack(spacing: CodexMeterDesign.Spacing.compact) {
        Image(systemName: mode.systemImage)
          .font(.system(size: 10, weight: .semibold))
        Text(mode.localizedCompactTitle(using: localizer))
          .font(CodexMeterDesign.Typography.control)
          .lineLimit(1)
      }
      .frame(
        width: CodexMeterDesign.Metrics.modeControlWidth,
        height: CodexMeterDesign.Metrics.controlHeight
      )
      .foregroundStyle(isSelected ? .primary : .secondary)
      .codexMeterControlBackground(isSelected: isSelected)
      .contentShape(
        RoundedRectangle(
          cornerRadius: CodexMeterDesign.Radius.control,
          style: .continuous
        )
      )
    }
    .buttonStyle(.plain)
    .help(mode.localizedTitle(using: localizer))
    .accessibilityLabel(mode.localizedTitle(using: localizer))
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private var localizer: AppLocalizer {
    languageController.localizer
  }
}

enum MetricFormatter {
  static func quotaLabel(
    for window: QuotaWindow?,
    fallback: L10nKey,
    localizer: AppLocalizer
  ) -> String {
    guard let minutes = window?.windowDurationMinutes, minutes > 0 else {
      return localizer.string(fallback)
    }
    if minutes.isMultiple(of: 1_440) {
      let days = minutes / 1_440
      return localizer.format(days == 1 ? .quotaDaysOne : .quotaDaysOther, days)
    }
    if minutes.isMultiple(of: 60) {
      let hours = minutes / 60
      return localizer.format(hours == 1 ? .quotaHoursOne : .quotaHoursOther, hours)
    }
    return localizer.format(minutes == 1 ? .quotaMinutesOne : .quotaMinutesOther, minutes)
  }

  static func shortQuotaLabel(
    for window: QuotaWindow?,
    fallback: L10nKey,
    localizer: AppLocalizer
  ) -> String {
    guard let minutes = window?.windowDurationMinutes, minutes > 0 else {
      return localizer.format(.quotaShortFallbackFormat, localizer.string(fallback))
    }
    if minutes.isMultiple(of: 1_440) {
      return localizer.format(.quotaShortDaysFormat, minutes / 1_440)
    }
    if minutes.isMultiple(of: 60) {
      return localizer.format(.quotaShortHoursFormat, minutes / 60)
    }
    return localizer.format(.quotaShortMinutesFormat, minutes)
  }

  static func quotaAccessibilityValue(
    for window: QuotaWindow?,
    now: Date = .now,
    localizer: AppLocalizer
  ) -> String {
    guard let window else { return localizer.string(.commonNoData) }
    let countdown = resetCountdown(
      until: window.resetsAt,
      now: now,
      localizer: localizer
    )
    return localizer.format(
      .quotaAccessibilityFormat,
      localizer.percent(window.remainingPercent),
      countdown
    )
  }

  static func compactTokens(_ value: Int64?, localizer: AppLocalizer) -> String {
    guard let value else { return "—" }
    let magnitude = Double(value)
    switch magnitude {
    case 1_000_000_000...:
      return scaled(magnitude / 1_000_000_000, suffix: "B", localizer: localizer)
    case 1_000_000...:
      return scaled(magnitude / 1_000_000, suffix: "M", localizer: localizer)
    case 1_000...:
      return scaled(magnitude / 1_000, suffix: "K", localizer: localizer)
    default:
      return localizer.decimal(value)
    }
  }

  static func exactTokens(_ value: Int64, localizer: AppLocalizer) -> String {
    localizer.decimal(value)
  }

  static func resetCountdown(
    until date: Date?,
    now: Date,
    localizer: AppLocalizer
  ) -> String {
    guard let date else { return localizer.string(.resetWaitingForSync) }
    let seconds = max(0, Int(date.timeIntervalSince(now)))
    guard seconds > 0 else { return localizer.string(.resetSoon) }

    let days = seconds / 86_400
    let hours = (seconds % 86_400) / 3_600
    let minutes = (seconds % 3_600) / 60
    if days > 0 {
      let key: L10nKey
      switch (days == 1, hours == 1) {
      case (true, true): key = .resetDaysOneHoursOne
      case (true, false): key = .resetDaysOneHoursOther
      case (false, true): key = .resetDaysOtherHoursOne
      case (false, false): key = .resetDaysOtherHoursOther
      }
      return localizer.format(key, days, hours)
    }
    if hours > 0 {
      let key: L10nKey
      switch (hours == 1, minutes == 1) {
      case (true, true): key = .resetHoursOneMinutesOne
      case (true, false): key = .resetHoursOneMinutesOther
      case (false, true): key = .resetHoursOtherMinutesOne
      case (false, false): key = .resetHoursOtherMinutesOther
      }
      return localizer.format(key, hours, minutes)
    }
    let visibleMinutes = max(minutes, 1)
    return localizer.format(
      visibleMinutes == 1 ? .resetMinutesOne : .resetMinutesOther,
      visibleMinutes
    )
  }

  static func compactResetCountdown(
    until date: Date?,
    now: Date,
    localizer: AppLocalizer
  ) -> String {
    guard let date else { return localizer.string(.resetWaitingForSync) }
    let seconds = max(0, Int(date.timeIntervalSince(now)))
    guard seconds > 0 else { return localizer.string(.resetSoon) }

    let days = seconds / 86_400
    let hours = (seconds % 86_400) / 3_600
    let minutes = max((seconds % 3_600) / 60, hours == 0 ? 1 : 0)
    if days > 0 {
      return localizer.format(.resetCompactDaysFormat, days, hours)
    }
    return localizer.format(.resetCompactClockFormat, hours, minutes)
  }

  private static func scaled(
    _ value: Double,
    suffix: String,
    localizer: AppLocalizer
  ) -> String {
    if value >= 100 {
      return value.formatted(
        .number
          .precision(.fractionLength(0))
          .locale(localizer.locale)
      ) + suffix
    }
    return value.formatted(
      .number
        .precision(.fractionLength(1))
        .locale(localizer.locale)
    ) + suffix
  }
}
