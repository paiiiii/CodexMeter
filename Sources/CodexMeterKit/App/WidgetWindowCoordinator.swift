import AppKit
import Observation
import QuartzCore
import SwiftUI

private final class CodexMeterPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}

@MainActor
@Observable
public final class WidgetWindowCoordinator: NSObject, NSWindowDelegate {
  public private(set) var mode: WidgetPresentationMode

  private enum Keys {
    static let mode = "CodexMeter.presentationMode"
    static let lastVisibleMode = "CodexMeter.lastVisibleMode"
    static let frameName = NSWindow.FrameAutosaveName("CodexMeter.widgetFrame")
  }

  private static let widgetSize = CodexMeterDesign.Metrics.widgetSize

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
      if newMode != .hidden, !panel.isVisible {
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
    apply(newMode, animated: true)
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
    let panel = CodexMeterPanel(
      contentRect: NSRect(origin: .zero, size: Self.widgetSize),
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
        .frame(width: Self.widgetSize.width, height: Self.widgetSize.height)
        .codexMeterLanguage(languageController)
    )
    panel.contentView?.wantsLayer = true
    panel.contentView?.layer?.backgroundColor = .clear

    let restored = panel.setFrameUsingName(Keys.frameName)
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

  private func positionAtTopRight(_ panel: NSWindow) {
    guard let visibleFrame = NSScreen.main?.visibleFrame else { return }
    let origin = NSPoint(
      x: visibleFrame.maxX - Self.widgetSize.width - 24,
      y: visibleFrame.maxY - Self.widgetSize.height - 24
    )
    panel.setFrameOrigin(origin)
  }

  private func clampToVisibleScreen(_ panel: NSWindow) {
    let screen =
      panel.screen
      ?? NSScreen.screens.first(where: { $0.frame.intersects(panel.frame) })
      ?? NSScreen.main
    guard let visibleFrame = screen?.visibleFrame else { return }

    let insetFrame = visibleFrame.insetBy(dx: 10, dy: 10)
    var origin = panel.frame.origin
    origin.x = min(max(origin.x, insetFrame.minX), insetFrame.maxX - panel.frame.width)
    origin.y = min(max(origin.y, insetFrame.minY), insetFrame.maxY - panel.frame.height)
    panel.setFrameOrigin(origin)
  }

  @objc private func screenConfigurationDidChange() {
    clampToVisibleScreen(panel)
  }

  public func windowDidChangeScreen(_ notification: Notification) {
    clampToVisibleScreen(panel)
  }
}
