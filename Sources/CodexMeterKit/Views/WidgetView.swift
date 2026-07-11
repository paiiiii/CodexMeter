import AppKit
import SwiftUI

public struct WidgetView: View {
  private let store: UsageStore
  private let coordinator: WidgetWindowCoordinator

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @State private var isHovering = false

  public init(store: UsageStore, coordinator: WidgetWindowCoordinator) {
    self.store = store
    self.coordinator = coordinator
  }

  public var body: some View {
    WidgetSurface(reduceTransparency: reduceTransparency) {
      ZStack {
        AmbientGlow()

        VStack(spacing: 0) {
          header
          mainMetrics
            .padding(.top, 8)
          weeklyQuota
            .padding(.top, 8)
          controls
            .padding(.top, 8)
        }
        .padding(14)
      }
    }
    .padding(5)
    .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    .onHover { hovering in
      guard !reduceMotion else {
        isHovering = hovering
        return
      }
      withAnimation(.smooth(duration: 0.22)) {
        isHovering = hovering
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Codex 使用情况")
  }

  private var header: some View {
    HStack(spacing: 8) {
      ZStack {
        Circle()
          .fill(.primary.opacity(0.1))
        Image(systemName: "circle.hexagongrid.fill")
          .font(.system(size: 11, weight: .semibold))
      }
      .frame(width: 24, height: 24)

      Text("CODEXMETER")
        .font(.system(size: 10, weight: .semibold, design: .rounded))
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
              ? .linear(duration: 0.9).repeatForever(autoreverses: false)
              : .default,
            value: store.isRefreshing
          )
          .frame(width: 24, height: 24)
          .contentShape(Circle())
      }
      .buttonStyle(.plain)
      .disabled(store.isRefreshing)
      .help("立即刷新")
      .accessibilityLabel("立即刷新 Codex 用量")
    }
    .frame(height: 24)
  }

  private var mainMetrics: some View {
    HStack(spacing: 18) {
      QuotaRing(window: store.snapshot?.primary)
        .frame(width: 88, height: 88)

      VStack(alignment: .leading, spacing: 2) {
        Text(MetricFormatter.compactTokens(store.snapshot?.todayTokens))
          .font(.system(size: 31, weight: .medium, design: .rounded))
          .monospacedDigit()
          .lineLimit(1)
          .minimumScaleFactor(0.72)
          .contentTransition(
            .numericText(value: Double(store.snapshot?.todayTokens ?? 0))
          )

        Text("今日 TOKEN")
          .font(.system(size: 9, weight: .semibold, design: .rounded))
          .tracking(1.2)
          .foregroundStyle(.secondary)

        if let tokens = store.snapshot?.todayTokens {
          Text(MetricFormatter.exactTokens(tokens))
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.top, 5)
            .contentTransition(.numericText(value: Double(tokens)))
        } else {
          Text(
            store.snapshot == nil
              ? (store.isRefreshing ? "正在读取本地 Codex…" : "等待 Codex 数据")
              : "今日 Token 暂不可用"
          )
          .font(.system(size: 10))
          .foregroundStyle(.secondary)
          .padding(.top, 5)
          .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("今日 Token")
      .accessibilityValue(
        store.snapshot?.todayTokens.map(MetricFormatter.exactTokens) ?? "尚无数据"
      )
    }
    .frame(height: 88)
    .animation(.smooth(duration: reduceMotion ? 0 : 0.38), value: store.snapshot)
  }

  private var weeklyQuota: some View {
    QuotaBar(window: store.snapshot?.secondary)
      .frame(height: 28)
  }

  private var controls: some View {
    HStack(spacing: 4) {
      ForEach(WidgetPresentationMode.allCases) { mode in
        ModeButton(
          mode: mode,
          isSelected: coordinator.mode == mode,
          showsTitle: isHovering
        ) {
          coordinator.setMode(mode)
        }
      }

      Spacer(minLength: 2)

      SettingsLink {
        Image(systemName: "slider.horizontal.3")
          .font(.system(size: 11, weight: .semibold))
          .frame(width: 28, height: 26)
          .background(.primary.opacity(isHovering ? 0.09 : 0.05), in: Circle())
      }
      .buttonStyle(.plain)
      .help("设置")
      .accessibilityLabel("打开设置")
    }
    .frame(height: 26)
    .opacity(isHovering ? 1 : 0.9)
  }
}

private struct WidgetSurface<Content: View>: View {
  let reduceTransparency: Bool
  @ViewBuilder let content: Content

  var body: some View {
    if reduceTransparency {
      content
        .background(
          Color(nsColor: .windowBackgroundColor),
          in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay(border)
    } else if #available(macOS 26.0, *) {
      content
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .overlay(border)
    } else {
      content
        .background(
          .ultraThinMaterial,
          in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay(border)
    }
  }

  private var border: some View {
    RoundedRectangle(cornerRadius: 28, style: .continuous)
      .strokeBorder(.primary.opacity(0.11), lineWidth: 0.6)
  }
}

private struct AmbientGlow: View {
  var body: some View {
    ZStack {
      Circle()
        .fill(Color.mint.opacity(0.09))
        .frame(width: 150, height: 150)
        .blur(radius: 34)
        .offset(x: -120, y: -86)
      Circle()
        .fill(Color.indigo.opacity(0.06))
        .frame(width: 130, height: 130)
        .blur(radius: 38)
        .offset(x: 132, y: 95)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .allowsHitTesting(false)
    .clipped()
  }
}

private struct LiveStatusView: View {
  let store: UsageStore

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isPulsing = false

  private var status: (title: String, color: Color) {
    if store.isRefreshing {
      return ("同步中", .secondary)
    }
    if store.lastErrorDescription != nil {
      return ("离线", .orange)
    }
    if store.snapshot != nil {
      return ("实时", .mint)
    }
    return ("连接中", .secondary)
  }

  var body: some View {
    HStack(spacing: 5) {
      Circle()
        .fill(status.color)
        .frame(width: 6, height: 6)
        .scaleEffect(isPulsing && !reduceMotion && store.snapshot != nil ? 1.22 : 0.9)
        .shadow(color: status.color.opacity(0.5), radius: 3)
      Text(status.title)
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 8)
    .frame(height: 22)
    .background(.primary.opacity(0.055), in: Capsule())
    .help(store.lastErrorDescription ?? "数据来自本机 Codex app-server")
    .onAppear {
      guard !reduceMotion else { return }
      withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
        isPulsing = true
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("连接状态")
    .accessibilityValue(status.title)
  }
}

private struct QuotaRing: View {
  let window: QuotaWindow?

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var remaining: Int { window?.remainingPercent ?? 0 }
  private var progress: Double { Double(remaining) / 100 }

  private var accent: Color {
    guard window != nil else { return .secondary }
    switch remaining {
    case 51...100: return .primary
    case 21...50: return .orange
    default: return .red
    }
  }

  var body: some View {
    TimelineView(.periodic(from: .now, by: 60)) { context in
      ZStack {
        Circle()
          .stroke(.primary.opacity(0.08), lineWidth: 7)
        Circle()
          .trim(from: 0, to: window == nil ? 0 : max(progress, 0.012))
          .stroke(
            AngularGradient(
              colors: [accent.opacity(0.55), accent, .white.opacity(0.9)],
              center: .center
            ),
            style: StrokeStyle(lineWidth: 7, lineCap: .round)
          )
          .rotationEffect(.degrees(-90))
          .shadow(color: accent.opacity(0.18), radius: 5)

        VStack(spacing: 0) {
          Text(window == nil ? "—" : "\(remaining)%")
            .font(.system(size: 23, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(remaining)))
          Text(MetricFormatter.shortQuotaLabel(for: window, fallback: "主要"))
            .font(.system(size: 8, weight: .semibold, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(.secondary)
          Text(MetricFormatter.compactResetCountdown(until: window?.resetsAt, now: context.date))
            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .frame(maxWidth: 70)
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(MetricFormatter.quotaLabel(for: window, fallback: "主要额度"))
      .accessibilityValue(
        MetricFormatter.quotaAccessibilityValue(for: window, now: context.date)
      )
    }
    .animation(.smooth(duration: reduceMotion ? 0 : 0.48), value: remaining)
  }
}

private struct QuotaBar: View {
  let window: QuotaWindow?

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var remaining: Int { window?.remainingPercent ?? 0 }
  private var progress: Double { Double(remaining) / 100 }

  var body: some View {
    VStack(spacing: 5) {
      HStack(spacing: 6) {
        Text(MetricFormatter.quotaLabel(for: window, fallback: "次要额度"))
          .font(.system(size: 10, weight: .medium))
        Text(window == nil ? "—" : "剩余 \(remaining)%")
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
            .fill(.primary.opacity(0.075))
          Capsule()
            .fill(
              LinearGradient(
                colors: [.primary.opacity(0.48), .primary.opacity(0.9)],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .frame(width: proxy.size.width * (window == nil ? 0 : progress))
        }
      }
      .frame(height: 4)
    }
    .animation(.smooth(duration: reduceMotion ? 0 : 0.48), value: remaining)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(MetricFormatter.quotaLabel(for: window, fallback: "次要额度"))
    .accessibilityValue(MetricFormatter.quotaAccessibilityValue(for: window))
  }
}

private struct ResetCountdownView: View {
  let date: Date?

  var body: some View {
    TimelineView(.periodic(from: .now, by: 60)) { context in
      Text(MetricFormatter.resetCountdown(until: date, now: context.date))
        .font(.system(size: 9, weight: .medium, design: .monospaced))
        .monospacedDigit()
    }
  }
}

private struct ModeButton: View {
  let mode: WidgetPresentationMode
  let isSelected: Bool
  let showsTitle: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 5) {
        Image(systemName: mode.systemImage)
          .font(.system(size: 10, weight: .semibold))
        if showsTitle {
          Text(mode.title)
            .font(.system(size: 10, weight: .medium))
            .transition(.opacity.combined(with: .move(edge: .leading)))
        }
      }
      .padding(.horizontal, showsTitle ? 8 : 7)
      .frame(height: 26)
      .foregroundStyle(isSelected ? .primary : .secondary)
      .background(
        .primary.opacity(isSelected ? 0.12 : 0.045),
        in: Capsule()
      )
      .overlay {
        if isSelected {
          Capsule().strokeBorder(.primary.opacity(0.12), lineWidth: 0.5)
        }
      }
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .help(mode.title)
    .accessibilityLabel(mode.title)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

enum MetricFormatter {
  static func quotaLabel(for window: QuotaWindow?, fallback: String) -> String {
    guard let minutes = window?.windowDurationMinutes, minutes > 0 else {
      return fallback
    }
    if minutes.isMultiple(of: 1_440) {
      return "\(minutes / 1_440) 天额度"
    }
    if minutes.isMultiple(of: 60) {
      return "\(minutes / 60) 小时额度"
    }
    return "\(minutes) 分钟额度"
  }

  static func shortQuotaLabel(for window: QuotaWindow?, fallback: String) -> String {
    guard let minutes = window?.windowDurationMinutes, minutes > 0 else {
      return "\(fallback)剩余"
    }
    if minutes.isMultiple(of: 1_440) {
      return "\(minutes / 1_440)D 剩余"
    }
    if minutes.isMultiple(of: 60) {
      return "\(minutes / 60)H 剩余"
    }
    return "\(minutes)M 剩余"
  }

  static func quotaAccessibilityValue(for window: QuotaWindow?, now: Date = .now) -> String {
    guard let window else { return "尚无数据" }
    let countdown = resetCountdown(until: window.resetsAt, now: now)
    return "剩余 \(window.remainingPercent) 百分比，\(countdown)"
  }

  static func compactTokens(_ value: Int64?) -> String {
    guard let value else { return "—" }
    let magnitude = Double(value)
    switch magnitude {
    case 1_000_000_000...:
      return scaled(magnitude / 1_000_000_000, suffix: "B")
    case 1_000_000...:
      return scaled(magnitude / 1_000_000, suffix: "M")
    case 1_000...:
      return scaled(magnitude / 1_000, suffix: "K")
    default:
      return value.formatted()
    }
  }

  static func exactTokens(_ value: Int64) -> String {
    value.formatted(.number.grouping(.automatic))
  }

  static func resetCountdown(until date: Date?, now: Date) -> String {
    guard let date else { return "等待同步" }
    let seconds = max(0, Int(date.timeIntervalSince(now)))
    guard seconds > 0 else { return "即将重置" }

    let days = seconds / 86_400
    let hours = (seconds % 86_400) / 3_600
    let minutes = (seconds % 3_600) / 60
    if days > 0 { return "\(days)天 \(hours)时后重置" }
    if hours > 0 { return "\(hours)时 \(minutes)分后重置" }
    return "\(max(minutes, 1))分后重置"
  }

  static func compactResetCountdown(until date: Date?, now: Date) -> String {
    guard let date else { return "等待同步" }
    let seconds = max(0, Int(date.timeIntervalSince(now)))
    guard seconds > 0 else { return "即将重置" }

    let days = seconds / 86_400
    let hours = (seconds % 86_400) / 3_600
    let minutes = max((seconds % 3_600) / 60, hours == 0 ? 1 : 0)
    if days > 0 { return String(format: "重置 %d天%02d时", days, hours) }
    return String(format: "重置 %02d:%02d", hours, minutes)
  }

  private static func scaled(_ value: Double, suffix: String) -> String {
    if value >= 100 {
      return value.formatted(.number.precision(.fractionLength(0))) + suffix
    }
    return value.formatted(.number.precision(.fractionLength(1))) + suffix
  }
}
