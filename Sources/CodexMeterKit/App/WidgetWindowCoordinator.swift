import AppKit
import Observation
import QuartzCore
import SwiftUI

private final class CodexMeterPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}

struct WidgetWindowGeometry {
  static func size(for layoutMode: WidgetLayoutMode) -> NSSize {
    CodexMeterDesign.Metrics.widgetSize(for: layoutMode)
  }

  static func frameAnchoredTopRight(
    from currentFrame: NSRect,
    targetSize: NSSize
  ) -> NSRect {
    NSRect(
      x: currentFrame.maxX - targetSize.width,
      y: currentFrame.maxY - targetSize.height,
      width: targetSize.width,
      height: targetSize.height
    )
  }

  static func clampedFrame(
    _ frame: NSRect,
    to visibleFrame: NSRect,
    inset: CGFloat = 10
  ) -> NSRect {
    let bounds = visibleFrame.insetBy(dx: inset, dy: inset)
    var origin = frame.origin
    origin.x = min(max(origin.x, bounds.minX), bounds.maxX - frame.width)
    origin.y = min(max(origin.y, bounds.minY), bounds.maxY - frame.height)
    return NSRect(origin: origin, size: frame.size)
  }
}

struct WidgetMorphGeometry {
  static let fullQuotaCenterTopLeading = CGPoint(x: 63, y: 99)
  static let minimalQuotaCenterTopLeading = CGPoint(x: 55, y: 55)

  static func progress(for size: CGSize) -> CGFloat {
    let range =
      CodexMeterDesign.Metrics.widgetSize.width
      - CodexMeterDesign.Metrics.minimalWidgetSize.width
    guard range > 0 else { return 1 }
    return min(
      max(
        (size.width - CodexMeterDesign.Metrics.minimalWidgetSize.width) / range,
        0
      ),
      1
    )
  }

  static func quotaCenterTopLeading(progress: CGFloat) -> CGPoint {
    interpolate(
      from: minimalQuotaCenterTopLeading,
      to: fullQuotaCenterTopLeading,
      progress: progress
    )
  }

  static func quotaCenterBottomLeading(progress: CGFloat) -> CGPoint {
    let minimalSize = CodexMeterDesign.Metrics.minimalWidgetSize
    let fullSize = CodexMeterDesign.Metrics.widgetSize
    return interpolate(
      from: CGPoint(
        x: minimalQuotaCenterTopLeading.x,
        y: minimalSize.height - minimalQuotaCenterTopLeading.y
      ),
      to: CGPoint(
        x: fullQuotaCenterTopLeading.x,
        y: fullSize.height - fullQuotaCenterTopLeading.y
      ),
      progress: progress
    )
  }

  static func framePreservingQuotaCenter(
    from currentFrame: NSRect,
    targetSize: NSSize
  ) -> NSRect {
    let currentCenter = quotaCenterBottomLeading(
      progress: progress(for: currentFrame.size)
    )
    let screenCenter = CGPoint(
      x: currentFrame.minX + currentCenter.x,
      y: currentFrame.minY + currentCenter.y
    )
    let targetCenter = quotaCenterBottomLeading(
      progress: progress(for: targetSize)
    )
    return NSRect(
      x: screenCenter.x - targetCenter.x,
      y: screenCenter.y - targetCenter.y,
      width: targetSize.width,
      height: targetSize.height
    )
  }

  static func surfaceRect(progress: CGFloat) -> CGRect {
    let fullSize = CodexMeterDesign.Metrics.widgetSize
    let fullRect = CGRect(
      x: CodexMeterDesign.Metrics.outerInset,
      y: CodexMeterDesign.Metrics.outerInset,
      width: fullSize.width - CodexMeterDesign.Metrics.outerInset * 2,
      height: fullSize.height - CodexMeterDesign.Metrics.outerInset * 2
    )
    let minimalGlassDiameter = CodexMeterDesign.Metrics.minimalGlassDiameter
    let minimalRect = CGRect(
      x: minimalQuotaCenterTopLeading.x - minimalGlassDiameter / 2,
      y: minimalQuotaCenterTopLeading.y - minimalGlassDiameter / 2,
      width: minimalGlassDiameter,
      height: minimalGlassDiameter
    )
    return interpolate(from: minimalRect, to: fullRect, progress: progress)
  }

  static func surfaceCornerRadius(progress: CGFloat) -> CGFloat {
    interpolate(
      from: CodexMeterDesign.Metrics.minimalGlassDiameter / 2,
      to: CodexMeterDesign.Radius.surface,
      progress: progress
    )
  }

  private static func interpolate(
    from start: CGFloat,
    to end: CGFloat,
    progress: CGFloat
  ) -> CGFloat {
    start + (end - start) * min(max(progress, 0), 1)
  }

  private static func interpolate(
    from start: CGPoint,
    to end: CGPoint,
    progress: CGFloat
  ) -> CGPoint {
    CGPoint(
      x: interpolate(from: start.x, to: end.x, progress: progress),
      y: interpolate(from: start.y, to: end.y, progress: progress)
    )
  }

  private static func interpolate(
    from start: CGRect,
    to end: CGRect,
    progress: CGFloat
  ) -> CGRect {
    CGRect(
      x: interpolate(from: start.minX, to: end.minX, progress: progress),
      y: interpolate(from: start.minY, to: end.minY, progress: progress),
      width: interpolate(from: start.width, to: end.width, progress: progress),
      height: interpolate(from: start.height, to: end.height, progress: progress)
    )
  }
}

struct WidgetPanelShadowPolicy {
  static func shouldShowSystemShadow(
    mode: WidgetPresentationMode,
    layoutMode: WidgetLayoutMode,
    isLayoutTransitioning: Bool
  ) -> Bool {
    WindowModePolicy.policy(for: mode).hasShadow
      && layoutMode == .full
      && !isLayoutTransitioning
  }
}

@MainActor
@Observable
public final class WidgetWindowCoordinator: NSObject, NSWindowDelegate {
  public private(set) var mode: WidgetPresentationMode
  public private(set) var layoutMode: WidgetLayoutMode
  public private(set) var isLayoutTransitioning = false
  public private(set) var isWidgetPresented: Bool

  private enum Keys {
    static let mode = "CodexMeter.presentationMode"
    static let lastVisibleMode = "CodexMeter.lastVisibleMode"
    static let layoutMode = "CodexMeter.layoutMode"
    static let frameName = NSWindow.FrameAutosaveName("CodexMeter.widgetFrame")
  }

  private let store: UsageStore
  private let languageController: LanguageController
  private let defaults: UserDefaults
  private var lastVisibleMode: WidgetPresentationMode
  private var hasStarted = false
  private var transitionID = UUID()
  private var layoutTransitionID = UUID()

  @ObservationIgnored
  private var panelStorage: CodexMeterPanel?

  /// A `lazy var` re-runs its initializer when it is read re-entrantly, and
  /// restoring the saved frame makes AppKit post screen-change notifications to
  /// this delegate, which reads the panel back. Publishing the panel before
  /// configuring it — and attaching the delegate only once configuration is
  /// finished — keeps such a callback from building a second panel, which
  /// recursed until the main thread ran out of stack.
  private var panel: CodexMeterPanel {
    if let panelStorage { return panelStorage }
    let panel = CodexMeterPanel(
      contentRect: NSRect(origin: .zero, size: widgetSize),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panelStorage = panel
    configure(panel)
    return panel
  }

  public init(
    store: UsageStore,
    languageController: LanguageController,
    defaults: UserDefaults = .standard
  ) {
    self.store = store
    self.languageController = languageController
    self.defaults = defaults

    let savedMode =
      defaults.string(forKey: Keys.mode)
      .flatMap(WidgetPresentationMode.init(rawValue:)) ?? .floating
    mode = savedMode
    isWidgetPresented = savedMode != .hidden

    layoutMode =
      defaults.string(forKey: Keys.layoutMode)
      .flatMap(WidgetLayoutMode.init(rawValue:)) ?? .full

    let savedVisibleMode = defaults.string(forKey: Keys.lastVisibleMode)
      .flatMap(WidgetPresentationMode.init(rawValue:))
    lastVisibleMode = savedVisibleMode == .desktop ? .desktop : .floating
    super.init()
  }

  public func start() {
    guard !hasStarted else { return }
    hasStarted = true
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenConfigurationDidChange),
      name: NSApplication.didChangeScreenParametersNotification,
      object: nil
    )
    apply(mode, animated: false)
  }

  public func setMode(_ newMode: WidgetPresentationMode) {
    guard mode != newMode else {
      if hasStarted, newMode != .hidden, !panel.isVisible {
        apply(newMode, animated: true)
      }
      return
    }

    mode = newMode
    defaults.set(newMode.rawValue, forKey: Keys.mode)
    if newMode != .hidden {
      lastVisibleMode = newMode
      defaults.set(newMode.rawValue, forKey: Keys.lastVisibleMode)
    }
    guard hasStarted else { return }
    apply(newMode, animated: true)
  }

  public func setLayoutMode(_ newLayoutMode: WidgetLayoutMode) {
    guard layoutMode != newLayoutMode, !isLayoutTransitioning else { return }
    layoutMode = newLayoutMode
    defaults.set(newLayoutMode.rawValue, forKey: Keys.layoutMode)
    guard hasStarted else { return }
    resizePanel(animated: true)
  }

  public func toggleLayoutMode() {
    setLayoutMode(layoutMode == .minimal ? .full : .minimal)
  }

  var widgetSize: NSSize {
    WidgetWindowGeometry.size(for: layoutMode)
  }

  public func showLastVisibleMode() {
    setMode(lastVisibleMode)
  }

  public func toggleVisibility() {
    if mode == .hidden || !panel.isVisible {
      showLastVisibleMode()
    } else {
      setMode(.hidden)
    }
  }

  public func bringForward() {
    guard mode != .hidden else {
      showLastVisibleMode()
      return
    }
    if mode == .desktop {
      setMode(.floating)
      return
    }
    panel.orderFrontRegardless()
  }

  private func configure(_ panel: CodexMeterPanel) {
    let initialSize = widgetSize
    panel.title = "CodexMeter"
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.isReleasedWhenClosed = false
    panel.hidesOnDeactivate = false
    panel.becomesKeyOnlyIfNeeded = true
    panel.isMovableByWindowBackground = true
    panel.tabbingMode = .disallowed
    panel.animationBehavior = .none
    panel.contentView = NSHostingView(
      rootView: WidgetView(store: store, coordinator: self)
        .codexMeterLanguage(languageController)
    )
    panel.contentView?.wantsLayer = true
    panel.contentView?.layer?.backgroundColor = .clear
    panel.contentView?.layerContentsRedrawPolicy = .duringViewResize

    let restored = panel.setFrameUsingName(Keys.frameName)
    if restored {
      panel.setFrame(
        WidgetWindowGeometry.frameAnchoredTopRight(
          from: panel.frame,
          targetSize: initialSize
        ),
        display: false
      )
    }
    panel.setFrameAutosaveName(Keys.frameName)
    if !restored {
      positionAtTopRight(panel)
    }
    clampToVisibleScreen(panel)
    panel.delegate = self
  }

  private func apply(_ mode: WidgetPresentationMode, animated: Bool) {
    settleLayoutTransitionIfNeeded()
    let policy = WindowModePolicy.policy(for: mode)
    let currentTransitionID = UUID()
    transitionID = currentTransitionID
    store.setWidgetVisible(policy.isVisible)
    let shouldAnimate = animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

    if !policy.isVisible {
      guard shouldAnimate, panel.isVisible else {
        panel.orderOut(nil)
        panel.alphaValue = 1
        isWidgetPresented = false
        return
      }
      NSAnimationContext.runAnimationGroup { context in
        context.duration = CodexMeterDesign.Motion.immediate
        context.timingFunction = CAMediaTimingFunction(name: .easeIn)
        panel.animator().alphaValue = 0
      } completionHandler: { [weak self] in
        Task { @MainActor [weak self] in
          guard let self, self.transitionID == currentTransitionID else { return }
          self.panel.orderOut(nil)
          self.panel.alphaValue = 1
          self.isWidgetPresented = false
        }
      }
      return
    }

    isWidgetPresented = true
    panel.orderOut(nil)
    panel.level = policy.level
    panel.collectionBehavior = policy.collectionBehavior
    panel.isFloatingPanel = policy.isFloatingPanel
    updatePanelShadow()
    panel.setFrame(
      WidgetWindowGeometry.frameAnchoredTopRight(
        from: panel.frame,
        targetSize: widgetSize
      ),
      display: true
    )
    clampToVisibleScreen(panel)

    panel.alphaValue = shouldAnimate ? 0 : 1
    panel.orderFrontRegardless()

    guard shouldAnimate else { return }
    NSAnimationContext.runAnimationGroup { context in
      context.duration = CodexMeterDesign.Motion.standard
      context.timingFunction = CAMediaTimingFunction(name: .easeOut)
      panel.animator().alphaValue = 1
    }
  }

  private func resizePanel(animated: Bool) {
    let clampedFrame = layoutTargetFrame()
    let shouldAnimate =
      animated
      && panel.isVisible
      && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    guard shouldAnimate else {
      panel.setFrame(clampedFrame, display: true)
      isLayoutTransitioning = false
      panel.isMovableByWindowBackground = true
      updatePanelShadow()
      return
    }

    let currentLayoutTransitionID = UUID()
    layoutTransitionID = currentLayoutTransitionID
    isLayoutTransitioning = true
    panel.isMovableByWindowBackground = false
    panel.hasShadow = false

    NSAnimationContext.runAnimationGroup { context in
      context.duration = CodexMeterDesign.Motion.layoutMorph
      context.timingFunction = CAMediaTimingFunction(
        controlPoints: 0.22,
        1,
        0.36,
        1
      )
      context.allowsImplicitAnimation = true
      panel.animator().setFrame(clampedFrame, display: true)
    } completionHandler: { [weak self] in
      Task { @MainActor [weak self] in
        guard
          let self,
          self.layoutTransitionID == currentLayoutTransitionID
        else { return }
        self.panel.setFrame(clampedFrame, display: true)
        self.isLayoutTransitioning = false
        self.panel.isMovableByWindowBackground = true
        self.updatePanelShadow()
      }
    }
  }

  private func layoutTargetFrame() -> NSRect {
    let targetFrame = WidgetMorphGeometry.framePreservingQuotaCenter(
      from: panel.frame,
      targetSize: widgetSize
    )
    let screen =
      panel.screen
      ?? NSScreen.screens.first(where: { $0.frame.intersects(panel.frame) })
      ?? NSScreen.main
    return screen.map {
      WidgetWindowGeometry.clampedFrame(targetFrame, to: $0.visibleFrame)
    } ?? targetFrame
  }

  private func settleLayoutTransitionIfNeeded() {
    guard isLayoutTransitioning else { return }
    layoutTransitionID = UUID()
    panel.setFrame(layoutTargetFrame(), display: true)
    isLayoutTransitioning = false
    panel.isMovableByWindowBackground = true
    updatePanelShadow()
  }

  private func updatePanelShadow() {
    let shouldShowSystemShadow = WidgetPanelShadowPolicy.shouldShowSystemShadow(
      mode: mode,
      layoutMode: layoutMode,
      isLayoutTransitioning: isLayoutTransitioning
    )
    guard panel.hasShadow != shouldShowSystemShadow else { return }
    panel.hasShadow = shouldShowSystemShadow
    if shouldShowSystemShadow {
      panel.invalidateShadow()
    }
  }

  private func positionAtTopRight(_ panel: NSWindow) {
    guard let visibleFrame = NSScreen.main?.visibleFrame else { return }
    let origin = NSPoint(
      x: visibleFrame.maxX - panel.frame.width - 24,
      y: visibleFrame.maxY - panel.frame.height - 24
    )
    panel.setFrameOrigin(origin)
  }

  private func clampToVisibleScreen(_ panel: NSWindow) {
    let screen =
      panel.screen
      ?? NSScreen.screens.first(where: { $0.frame.intersects(panel.frame) })
      ?? NSScreen.main
    guard let visibleFrame = screen?.visibleFrame else { return }

    panel.setFrame(
      WidgetWindowGeometry.clampedFrame(panel.frame, to: visibleFrame),
      display: false
    )
  }

  @objc private func screenConfigurationDidChange() {
    settleLayoutTransitionIfNeeded()
    clampToVisibleScreen(panel)
  }

  public func windowDidChangeScreen(_ notification: Notification) {
    clampToVisibleScreen(panel)
  }
}
