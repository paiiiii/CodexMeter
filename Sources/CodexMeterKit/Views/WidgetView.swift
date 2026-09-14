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
    GeometryReader { geometry in
      let progress = WidgetMorphGeometry.progress(for: geometry.size)
      let quotaCenter = WidgetMorphGeometry.quotaCenterTopLeading(
        progress: progress
      )

      ZStack(alignment: .topLeading) {
        CodexMeterMorphingGlassSurface(
          progress: progress,
          showsSoftShadow: coordinator.mode == .floating
        )

        if contentPolicy.shouldMountFullContent(
          isLayoutTransitioning: coordinator.isLayoutTransitioning,
          isWidgetPresented: coordinator.isWidgetPresented
        ) {
          fullContent
            .frame(
              width: CodexMeterDesign.Metrics.widgetSize.width,
              height: CodexMeterDesign.Metrics.widgetSize.height,
              alignment: .topLeading
            )
            .scaleEffect(
              0.72 + 0.28 * progress,
              anchor: fullQuotaAnchor
            )
            .opacity(fullContentOpacity(progress: progress))
            .mask(WidgetMorphShape(progress: progress))
            .allowsHitTesting(
              progress > 0.995 && !coordinator.isLayoutTransitioning
            )
            .accessibilityHidden(progress < 0.995)
        }

        QuotaRing(
          window: store.snapshot?.primary,
          system: coordinator.systemStore.snapshot
        )
        .frame(
          width: CodexMeterDesign.Metrics.quotaRing,
          height: CodexMeterDesign.Metrics.quotaRing
        )
        .contentShape(Circle())
        .onTapGesture(count: 2) {
          coordinator.toggleLayoutMode()
        }
        .help(quotaRingHelp)
        .contextMenu {
          Button(layoutToggleTitle) {
            coordinator.toggleLayoutMode()
          }
        }
        .accessibilityAction(named: Text(layoutToggleTitle)) {
          coordinator.toggleLayoutMode()
        }
        .position(quotaCenter)
        .allowsHitTesting(!coordinator.isLayoutTransitioning)
      }
      .frame(
        width: geometry.size.width,
        height: geometry.size.height,
        alignment: .topLeading
      )
      .clipped()
    }
  }

  private var fullContent: some View {
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
    .frame(
      width:
        CodexMeterDesign.Metrics.widgetSize.width
        - CodexMeterDesign.Metrics.outerInset * 2,
      height:
        CodexMeterDesign.Metrics.widgetSize.height
        - CodexMeterDesign.Metrics.outerInset * 2
    )
    .offset(
      x: CodexMeterDesign.Metrics.outerInset,
      y: CodexMeterDesign.Metrics.outerInset
    )
    .accessibilityElement(children: .contain)
    .accessibilityLabel(localizer.string(.widgetUsageAccessibility))
  }

  private var contentPolicy: WidgetContentPolicy {
    WidgetContentPolicy.policy(for: coordinator.layoutMode)
  }

  private var quotaRingHelp: String {
    [
      MetricFormatter.systemHelp(
        for: coordinator.systemStore.snapshot,
        localizer: localizer
      ),
      localizer.string(.widgetQuotaRingToggleHelp),
    ]
    .joined(separator: "\n")
  }

  private var layoutToggleTitle: String {
    localizer.string(
      coordinator.layoutMode == .minimal
        ? .widgetRestoreFullView
        : .widgetUseMinimalView
    )
  }

  private var fullQuotaAnchor: UnitPoint {
    UnitPoint(
      x:
        WidgetMorphGeometry.fullQuotaCenterTopLeading.x
        / CodexMeterDesign.Metrics.widgetSize.width,
      y:
        WidgetMorphGeometry.fullQuotaCenterTopLeading.y
        / CodexMeterDesign.Metrics.widgetSize.height
    )
  }

  private func fullContentOpacity(progress: CGFloat) -> Double {
    let normalized = min(max((progress - 0.42) / 0.48, 0), 1)
    return Double(normalized * normalized * (3 - 2 * normalized))
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
              : nil,
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
      Color.clear
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
      value: store.snapshot?.todayTokens
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
  let system: SystemMetricsSnapshot?

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(LanguageController.self) private var languageController

  private var remaining: Int { window?.remainingPercent ?? 0 }
  private var progress: Double { Double(remaining) / 100 }
  private var severity: QuotaSeverity {
    QuotaSeverity.classify(remainingPercent: window?.remainingPercent)
  }

  var body: some View {
    ZStack {
      ZStack {
        if window == nil {
          Circle()
            .stroke(
              CodexMeterDesign.ColorToken.track,
              lineWidth: CodexMeterDesign.Metrics.quotaStroke
            )
        } else {
          let progressEnd = max(progress, 0.012)

          Circle()
            .trim(from: progressEnd, to: 1)
            .stroke(
              CodexMeterDesign.ColorToken.track,
              style: StrokeStyle(
                lineWidth: CodexMeterDesign.Metrics.quotaStroke,
                lineCap: .round
              )
            )
            .rotationEffect(.degrees(-90))

          Circle()
            .trim(from: 0, to: progressEnd)
            .stroke(
              severity.color,
              style: StrokeStyle(
                lineWidth: CodexMeterDesign.Metrics.quotaStroke,
                lineCap: .round
              )
            )
            .rotationEffect(.degrees(-90))
        }
      }
      .compositingGroup()

      VStack(spacing: 1) {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
          Text(window == nil ? "—" : localizer.percent(remaining))
            .font(CodexMeterDesign.Typography.quotaMetric)
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(remaining)))

          if let tag = MetricFormatter.tightQuotaLabel(
            for: window,
            localizer: localizer
          ) {
            Text(tag)
              .font(CodexMeterDesign.Typography.quotaWindowTag)
              .tracking(0.3)
              .foregroundStyle(.secondary)
          }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)

        Rectangle()
          .fill(CodexMeterDesign.ColorToken.divider)
          .frame(width: 24, height: 0.5)
          .padding(.vertical, 0.5)

        SystemStatRow(
          tag: localizer.string(.systemMemoryTag),
          value: MetricFormatter.ringPercent(
            system?.memoryUsedPercent,
            localizer: localizer
          ),
          severity: SystemLoadSeverity.classify(usedPercent: system?.memoryUsedPercent)
        )

        SystemStatRow(
          tag: localizer.string(.systemSwapTag),
          value: MetricFormatter.compactBytes(
            system?.swapUsedBytes,
            localizer: localizer
          ),
          severity: SystemLoadSeverity.classifySwap(usedBytes: system?.swapUsedBytes)
        )

        SystemStatRow(
          tag: localizer.string(.systemDiskTag),
          value: MetricFormatter.ringPercent(
            system?.diskUsedPercent,
            localizer: localizer
          ),
          severity: SystemLoadSeverity.classify(usedPercent: system?.diskUsedPercent)
        )
      }
      .frame(width: CodexMeterDesign.Metrics.ringContentWidth)
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
      MetricFormatter.ringAccessibilityValue(
        window: window,
        system: system,
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

/// One `LABEL   VALUE` line inside the quota ring. The label stays quiet and the
/// value carries the color, so a healthy machine reads as a single calm column.
///
/// System readings move on every sample, so they are never animated: a transition
/// here would leave the settled widget in perpetual motion.
private struct SystemStatRow: View {
  let tag: String
  let value: String
  let severity: SystemLoadSeverity

  var body: some View {
    HStack(spacing: 3) {
      Text(tag)
        .font(CodexMeterDesign.Typography.systemStatLabel)
        .foregroundStyle(.secondary)
        .frame(
          width: CodexMeterDesign.Metrics.ringStatLabelWidth,
          alignment: .leading
        )

      Text(value)
        .font(CodexMeterDesign.Typography.systemStatValue)
        .monospacedDigit()
        .foregroundStyle(severity.color)
        .frame(
          width: CodexMeterDesign.Metrics.ringStatValueWidth,
          alignment: .trailing
        )
    }
    .lineLimit(1)
    .minimumScaleFactor(0.7)
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
    Group {
      if let date {
        TimelineView(.periodic(from: .now, by: 60)) { context in
          label(date: date, now: context.date)
        }
      } else {
        label(date: nil, now: .now)
      }
    }
  }

  private func label(date: Date?, now: Date) -> some View {
    Text(
      MetricFormatter.compactResetCountdown(
        until: date,
        now: now,
        localizer: languageController.localizer
      )
    )
    .font(CodexMeterDesign.Typography.metadata)
    .monospacedDigit()
  }
}

private struct PrimaryResetCountdown: View {
  let date: Date?

  @Environment(LanguageController.self) private var languageController

  var body: some View {
    Group {
      if let date {
        TimelineView(.periodic(from: .now, by: 60)) { context in
          label(date: date, now: context.date)
        }
      } else {
        label(date: nil, now: .now)
      }
    }
  }

  private func label(date: Date?, now: Date) -> some View {
    HStack(spacing: CodexMeterDesign.Spacing.compact) {
      Image(systemName: "clock")
        .font(.system(size: 9, weight: .semibold))
      Text(
        MetricFormatter.resetCountdown(
          until: date,
          now: now,
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

  /// The shortest readable window tag ("5H") for the crowded ring center.
  /// Returns `nil` when Codex has not reported a window length yet.
  static func tightQuotaLabel(
    for window: QuotaWindow?,
    localizer: AppLocalizer
  ) -> String? {
    guard let minutes = window?.windowDurationMinutes, minutes > 0 else {
      return nil
    }
    if minutes.isMultiple(of: 1_440) {
      return localizer.format(.quotaTightDaysFormat, minutes / 1_440)
    }
    if minutes.isMultiple(of: 60) {
      return localizer.format(.quotaTightHoursFormat, minutes / 60)
    }
    return localizer.format(.quotaTightMinutesFormat, minutes)
  }

  static func ringPercent(_ value: Int?, localizer: AppLocalizer) -> String {
    guard let value else { return "—" }
    return localizer.percent(value)
  }

  /// Four characters at most, so a stat row never crowds the ring stroke.
  static func compactBytes(_ value: UInt64?, localizer: AppLocalizer) -> String {
    guard let value else { return "—" }
    let units: [(scale: UInt64, suffix: String)] = [
      (1_099_511_627_776, "T"),
      (1_073_741_824, "G"),
      (1_048_576, "M"),
    ]
    for unit in units where value >= unit.scale {
      let scaled = Double(value) / Double(unit.scale)
      return scaled.formatted(
        .number
          .precision(.fractionLength(scaled < 10 ? 1 : 0))
          .locale(localizer.locale)
      ) + unit.suffix
    }
    return "0"
  }

  static func detailedBytes(
    _ value: UInt64,
    style: ByteCountFormatStyle.Style,
    localizer: AppLocalizer
  ) -> String {
    Int64(clamping: value).formatted(
      .byteCount(style: style).locale(localizer.locale)
    )
  }

  static func systemHelp(
    for snapshot: SystemMetricsSnapshot?,
    localizer: AppLocalizer
  ) -> String {
    guard let snapshot else { return localizer.string(.systemUnavailable) }
    let memory = localizer.format(
      .systemMemoryHelpFormat,
      detailedBytes(snapshot.memoryUsedBytes, style: .memory, localizer: localizer),
      detailedBytes(snapshot.memoryTotalBytes, style: .memory, localizer: localizer)
    )
    let swap =
      snapshot.swapUsedBytes == 0
      ? localizer.string(.systemSwapIdleHelp)
      : localizer.format(
        .systemSwapHelpFormat,
        detailedBytes(snapshot.swapUsedBytes, style: .memory, localizer: localizer)
      )
    let disk = localizer.format(
      .systemDiskHelpFormat,
      detailedBytes(snapshot.diskUsedBytes, style: .file, localizer: localizer),
      detailedBytes(snapshot.diskTotalBytes, style: .file, localizer: localizer),
      detailedBytes(snapshot.diskFreeBytes, style: .file, localizer: localizer)
    )
    return [memory, swap, disk].joined(separator: "\n")
  }

  /// The ring is one accessibility element, so its value carries the quota and
  /// the system readings joined by the shared localized summary separator.
  static func ringAccessibilityValue(
    window: QuotaWindow?,
    system: SystemMetricsSnapshot?,
    localizer: AppLocalizer
  ) -> String {
    localizer.format(
      .menuBarSummaryFormat,
      quotaAccessibilityValue(for: window, localizer: localizer),
      systemAccessibilityValue(for: system, localizer: localizer)
    )
  }

  static func systemAccessibilityValue(
    for snapshot: SystemMetricsSnapshot?,
    localizer: AppLocalizer
  ) -> String {
    guard let snapshot else { return localizer.string(.systemUnavailable) }
    return localizer.format(
      .systemAccessibilityFormat,
      localizer.percent(snapshot.memoryUsedPercent),
      detailedBytes(snapshot.swapUsedBytes, style: .memory, localizer: localizer),
      localizer.percent(snapshot.diskUsedPercent)
    )
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
