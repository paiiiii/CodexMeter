import AppKit

@MainActor
public final class CodexMeterAppDelegate: NSObject, NSApplicationDelegate {
  public let store: UsageStore
  public let loginItemController: LoginItemController
  public lazy var windowCoordinator = WidgetWindowCoordinator(store: store)
  private var isTerminating = false

  public override init() {
    store = UsageStore(provider: CodexAppServerClient())
    loginItemController = LoginItemController()
    super.init()
  }

  public func applicationDidFinishLaunching(_ notification: Notification) {
    NSApplication.shared.setActivationPolicy(.accessory)
    windowCoordinator.start()
    store.start()
  }

  public func applicationWillTerminate(_ notification: Notification) {
    store.stop()
  }

  public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    guard !isTerminating else { return .terminateLater }
    isTerminating = true
    store.stop()
    Task {
      await store.shutdown()
      sender.reply(toApplicationShouldTerminate: true)
    }
    return .terminateLater
  }

  public func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    windowCoordinator.showLastVisibleMode()
    return true
  }

  public func applicationShouldTerminateAfterLastWindowClosed(
    _ sender: NSApplication
  ) -> Bool {
    false
  }
}
