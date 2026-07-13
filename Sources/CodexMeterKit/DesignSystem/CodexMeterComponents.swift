import SwiftUI

private struct CodexMeterForceOpaqueSurfaceKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  var codexMeterForceOpaqueSurface: Bool {
    get { self[CodexMeterForceOpaqueSurfaceKey.self] }
    set { self[CodexMeterForceOpaqueSurfaceKey.self] = newValue }
  }
}

struct CodexMeterSurface<Content: View>: View {
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.codexMeterForceOpaqueSurface) private var forceOpaqueSurface
  @Environment(\.colorSchemeContrast) private var colorSchemeContrast

  private let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    Group {
      if reduceTransparency || forceOpaqueSurface {
        content
          .background(
            Color(nsColor: .windowBackgroundColor),
            in: RoundedRectangle(
              cornerRadius: CodexMeterDesign.Radius.surface,
              style: .continuous
            )
          )
      } else if #available(macOS 26.0, *) {
        content.glassEffect(
          .regular,
          in: .rect(cornerRadius: CodexMeterDesign.Radius.surface)
        )
      } else {
        content
          .background(
            .ultraThinMaterial,
            in: RoundedRectangle(
              cornerRadius: CodexMeterDesign.Radius.surface,
              style: .continuous
            )
          )
      }
    }
    .overlay {
      RoundedRectangle(
        cornerRadius: CodexMeterDesign.Radius.surface,
        style: .continuous
      )
      .strokeBorder(
        Color.primary.opacity(colorSchemeContrast == .increased ? 0.24 : 0.12),
        lineWidth: colorSchemeContrast == .increased ? 1 : 0.6
      )
    }
  }
}

struct CodexMeterInsetSurface<Content: View>: View {
  @Environment(\.colorSchemeContrast) private var colorSchemeContrast

  private let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    content
      .background(
        CodexMeterDesign.ColorToken.softFill,
        in: RoundedRectangle(
          cornerRadius: CodexMeterDesign.Radius.panel,
          style: .continuous
        )
      )
      .overlay {
        RoundedRectangle(
          cornerRadius: CodexMeterDesign.Radius.panel,
          style: .continuous
        )
        .strokeBorder(
          Color.primary.opacity(colorSchemeContrast == .increased ? 0.20 : 0.07),
          lineWidth: colorSchemeContrast == .increased ? 1 : 0.5
        )
      }
  }
}

struct CodexMeterCircularGlassBackdrop: View {
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.codexMeterForceOpaqueSurface) private var forceOpaqueSurface
  @Environment(\.colorSchemeContrast) private var colorSchemeContrast

  var body: some View {
    Group {
      if reduceTransparency || forceOpaqueSurface {
        Circle()
          .fill(Color(nsColor: .windowBackgroundColor))
      } else if #available(macOS 26.0, *) {
        Circle()
          .fill(.clear)
          .glassEffect(.regular, in: .circle)
      } else {
        Circle()
          .fill(.ultraThinMaterial)
      }
    }
    .overlay {
      Circle()
        .strokeBorder(
          Color.primary.opacity(colorSchemeContrast == .increased ? 0.20 : 0.08),
          lineWidth: colorSchemeContrast == .increased ? 1 : 0.5
        )
    }
  }
}

struct CodexMeterStatusPill: View {
  let title: String
  let signal: ConnectionSignal
  let accessibilityLabel: String
  let help: String

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isPulsing = false

  var body: some View {
    HStack(spacing: CodexMeterDesign.Spacing.compact) {
      Circle()
        .fill(signal.color)
        .frame(
          width: CodexMeterDesign.Metrics.statusDot,
          height: CodexMeterDesign.Metrics.statusDot
        )
        .scaleEffect(isPulsing && signal.isLive ? 1.18 : 0.92)

      Text(title)
        .font(CodexMeterDesign.Typography.control)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, CodexMeterDesign.Spacing.small)
    .frame(height: 22)
    .background(CodexMeterDesign.ColorToken.softFill, in: Capsule())
    .help(help)
    .task(id: signal) {
      isPulsing = false
      guard signal.isLive,
        CodexMeterDesign.Motion.allowsContinuousEffects(reduceMotion: reduceMotion)
      else { return }
      withAnimation(
        .easeInOut(duration: CodexMeterDesign.Motion.pulse)
          .repeatForever(autoreverses: true)
      ) {
        isPulsing = true
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityValue(title)
  }
}

struct CodexMeterControlBackground: ViewModifier {
  let isSelected: Bool
  @Environment(\.colorSchemeContrast) private var colorSchemeContrast

  func body(content: Content) -> some View {
    content
      .background(
        isSelected
          ? CodexMeterDesign.ColorToken.selectedFill
          : CodexMeterDesign.ColorToken.softFill,
        in: RoundedRectangle(
          cornerRadius: CodexMeterDesign.Radius.control,
          style: .continuous
        )
      )
      .overlay {
        RoundedRectangle(
          cornerRadius: CodexMeterDesign.Radius.control,
          style: .continuous
        )
        .strokeBorder(
          isSelected
            ? Color.primary.opacity(colorSchemeContrast == .increased ? 0.28 : 0.12)
            : .clear,
          lineWidth: colorSchemeContrast == .increased ? 1 : 0.5
        )
      }
  }
}

extension View {
  func codexMeterControlBackground(isSelected: Bool = false) -> some View {
    modifier(CodexMeterControlBackground(isSelected: isSelected))
  }
}
