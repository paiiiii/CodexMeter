import SwiftUI

/// CodexMeter's native macOS design language: Signal & Silence.
///
/// Values here are semantic on purpose. Views should consume these roles instead
/// of introducing one-off measurements, colors, or animation timings.
enum CodexMeterDesign {
  enum Spacing {
    static let compact: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xLarge: CGFloat = 24
  }

  enum Radius {
    static let control: CGFloat = 10
    static let panel: CGFloat = 14
    static let surface: CGFloat = 24
  }

  enum Metrics {
    static let widgetSize = CGSize(width: 348, height: 238)
    static let minimalWidgetSize = CGSize(width: 110, height: 110)
    static let outerInset: CGFloat = 5
    static let contentInset: CGFloat = 16
    static let brandGlyph: CGFloat = 20
    static let menuBarBrandGlyph: CGFloat = 20
    static let quotaRing: CGFloat = 84
    static let minimalQuotaRing: CGFloat = 84
    static let quotaStroke: CGFloat = 6
    static let minimalGlassDiameter = minimalQuotaRing - quotaStroke
    /// Widest line the ring center can hold without touching the quota stroke.
    static let ringContentWidth: CGFloat = 46
    static let ringStatLabelWidth: CGFloat = 18
    static let ringStatValueWidth: CGFloat = 25
    static let controlHeight: CGFloat = 28
    static let iconControl: CGFloat = 28
    static let modeControlWidth: CGFloat = 68
    static let settingsControlWidth: CGFloat = 78
    static let statusDot: CGFloat = 6

    static func widgetSize(for layoutMode: WidgetLayoutMode) -> CGSize {
      switch layoutMode {
      case .full: widgetSize
      case .minimal: minimalWidgetSize
      }
    }
  }

  enum Typography {
    static let brand = Font.system(size: 10, weight: .semibold, design: .rounded)
    static let heroMetric = Font.system(size: 30, weight: .medium, design: .rounded)
    static let quotaMetric = Font.system(size: 15, weight: .semibold, design: .rounded)
    static let quotaWindowTag = Font.system(size: 7, weight: .semibold, design: .rounded)
    static let systemStatLabel = Font.system(size: 7.5, weight: .semibold, design: .rounded)
    static let systemStatValue = Font.system(size: 8.5, weight: .semibold, design: .rounded)
    static let sectionLabel = Font.system(size: 10, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 11, weight: .medium)
    static let metadata = Font.system(size: 10, weight: .medium, design: .monospaced)
    static let control = Font.system(size: 10, weight: .medium)
  }

  enum ColorToken {
    /// The single brand signal, sampled from the CodexMeter glyph.
    static let signal = Color(red: 0.42, green: 0.67, blue: 0.53)
    static let caution = Color.orange
    static let critical = Color.red
    static let track = Color.primary.opacity(0.09)
    static let softFill = Color.primary.opacity(0.055)
    static let selectedFill = Color.primary.opacity(0.12)
    static let border = Color.primary.opacity(0.12)
    static let divider = Color.primary.opacity(0.10)
  }

  enum Motion {
    static let immediate: TimeInterval = 0.16
    static let standard: TimeInterval = 0.24
    static let layoutMorph: TimeInterval = 0.38
    static let data: TimeInterval = 0.42
    static let refresh: TimeInterval = 0.85

    static func duration(_ value: TimeInterval, reduceMotion: Bool) -> TimeInterval {
      reduceMotion ? 0 : value
    }

    static func smooth(_ value: TimeInterval, reduceMotion: Bool) -> Animation {
      .timingCurve(
        0.22,
        1,
        0.36,
        1,
        duration: duration(value, reduceMotion: reduceMotion)
      )
    }
  }
}

enum QuotaSeverity: String, CaseIterable, Sendable {
  case unavailable
  case healthy
  case caution
  case critical

  static func classify(remainingPercent: Int?) -> QuotaSeverity {
    guard let remainingPercent else { return .unavailable }
    switch remainingPercent {
    case ...20: return .critical
    case ...50: return .caution
    default: return .healthy
    }
  }

  var color: Color {
    switch self {
    case .unavailable: .secondary
    case .healthy: CodexMeterDesign.ColorToken.signal
    case .caution: CodexMeterDesign.ColorToken.caution
    case .critical: CodexMeterDesign.ColorToken.critical
    }
  }
}

/// Pressure on a local system resource, where a higher reading is worse. Quotas
/// use `QuotaSeverity`, which classifies what is left instead of what is used.
enum SystemLoadSeverity: String, CaseIterable, Sendable {
  case nominal
  case elevated
  case critical

  static let elevatedPercent = 75
  static let criticalPercent = 90
  static let elevatedSwapBytes: UInt64 = 1_073_741_824
  static let criticalSwapBytes: UInt64 = 4_294_967_296

  static func classify(usedPercent: Int?) -> SystemLoadSeverity {
    guard let usedPercent else { return .nominal }
    switch usedPercent {
    case criticalPercent...: return .critical
    case elevatedPercent...: return .elevated
    default: return .nominal
    }
  }

  static func classifySwap(usedBytes: UInt64?) -> SystemLoadSeverity {
    guard let usedBytes else { return .nominal }
    switch usedBytes {
    case criticalSwapBytes...: return .critical
    case elevatedSwapBytes...: return .elevated
    default: return .nominal
    }
  }

  /// Silence until it matters: a nominal reading stays in the neutral text tone.
  var color: Color {
    switch self {
    case .nominal: .primary
    case .elevated: CodexMeterDesign.ColorToken.caution
    case .critical: CodexMeterDesign.ColorToken.critical
    }
  }
}

enum ConnectionSignal: String, CaseIterable, Sendable {
  case connecting
  case syncing
  case live
  case cached
  case offline

  static func resolve(
    isRefreshing: Bool,
    hasSnapshot: Bool,
    hasError: Bool
  ) -> ConnectionSignal {
    if isRefreshing { return .syncing }
    if hasError { return hasSnapshot ? .cached : .offline }
    if hasSnapshot { return .live }
    return .connecting
  }

  var color: Color {
    switch self {
    case .live: CodexMeterDesign.ColorToken.signal
    case .cached: CodexMeterDesign.ColorToken.caution
    case .offline: CodexMeterDesign.ColorToken.critical
    case .connecting, .syncing: .secondary
    }
  }

  var isLive: Bool { self == .live }
}
