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

@MainActor
@Observable
public final class WidgetWindowCoordinator: NSObject, NSWindowDelegate {
  public private(set) var mode: WidgetPresentationMode
  public private(set) var layoutMode: WidgetLayoutMode

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

  @ObservationIgnored
  private lazy var panel: CodexMeterPanel = makePanel()

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
    guard layoutMode != newLayoutMode else { return }
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

  private func makePanel() -> CodexMeterPanel {
    let initialSize = widgetSize
    let panel = CodexMeterPanel(
      contentRect: NSRect(origin: .zero, size: initialSize),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.delegate = self
    panel.title = "CodexMeter"
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.isReleasedWhenClosed = false
    panel.hidesOnDeactivate = false
    panel.becomesKeyOnlyIfNeeded = true
    panel.isMovableByWindowBackground = true
    panel.acceptsMouseMovedEvents = true
    panel.tabbingMode = .disallowed
    panel.animationBehavior = .none
    panel.contentView = NSHostingView(
      rootView: WidgetView(store: store, coordinator: self)
        .codexMeterLanguage(languageController)
    )
    panel.contentView?.wantsLayer = true
    panel.contentView?.layer?.backgroundColor = .clear

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
    return panel
  }

  private func apply(_ mode: WidgetPresentationMode, animated: Bool) {
    let policy = WindowModePolicy.policy(for: mode)
    let currentTransitionID = UUID()
    transitionID = currentTransitionID
    store.setWidgetVisible(policy.isVisible)
    let shouldAnimate = animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

    if !policy.isVisible {
      guard shouldAnimate, panel.isVisible else {
        panel.orderOut(nil)
        panel.alphaValue = 1
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
        }
      }
      return
    }

    panel.orderOut(nil)
    panel.level = policy.level
    panel.collectionBehavior = policy.collectionBehavior
    panel.isFloatingPanel = policy.isFloatingPanel
    panel.hasShadow = policy.hasShadow
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
    let targetFrame = WidgetWindowGeometry.frameAnchoredTopRight(
      from: panel.frame,
      targetSize: widgetSize
    )
    let screen =
      panel.screen
      ?? NSScreen.screens.first(where: { $0.frame.intersects(panel.frame) })
      ?? NSScreen.main
    let clampedFrame = screen.map {
      WidgetWindowGeometry.clampedFrame(targetFrame, to: $0.visibleFrame)
    } ?? targetFrame
    let shouldAnimate =
      animated
      && panel.isVisible
      && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    panel.setFrame(clampedFrame, display: true, animate: shouldAnimate)
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
    clampToVisibleScreen(panel)
  }

  public func windowDidChangeScreen(_ notification: Notification) {
    clampToVisibleScreen(panel)
  }
}
