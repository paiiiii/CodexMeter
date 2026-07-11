import CodexMeterKit
import SwiftUI

@main
@MainActor
struct CodexMeterApplication: App {
  @NSApplicationDelegateAdaptor(CodexMeterAppDelegate.self)
  private var appDelegate

  var body: some Scene {
    MenuBarExtra {
      MenuBarContent(
        store: appDelegate.store,
        coordinator: appDelegate.windowCoordinator
      )
    } label: {
      MenuBarLabel(store: appDelegate.store)
    }
    .menuBarExtraStyle(.menu)

    Settings {
      SettingsView(
        store: appDelegate.store,
        coordinator: appDelegate.windowCoordinator,
        loginItemController: appDelegate.loginItemController
      )
    }
  }
}
