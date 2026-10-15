import AppKit

@MainActor
public final class CodexMeterAppDelegate: NSObject, NSApplicationDelegate {
  public let languageController: LanguageController
  public let store: UsageStore
  public let loginItemController: LoginItemController
  public lazy var windowCoordinator = WidgetWindowCoordinator(
    store: store,
    languageController: languageController
  )
  private var isTerminating = false

  public override init() {
    languageController = LanguageController()
    store = UsageStore(
      provider: CodexAppServerClient(),
      languageController: languageController
    )
    loginItemController = LoginItemController(languageController: languageController)
    super.init()
  }

  public func applicationDidFinishLaunching(_ notification: Notification) {
    NSApplication.shared.setActivationPolicy(.accessory)
    windowCoordinator.start()
    store.start()
  }

  public func applicationWillTerminate(_ notification: Notification) {
    store.stop()
    windowCoordinator.stop()
  }

  public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    guard !isTerminating else { return .terminateLater }
    isTerminating = true
    store.stop()
    windowCoordinator.stop()
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
