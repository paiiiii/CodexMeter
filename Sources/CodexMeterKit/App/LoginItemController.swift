import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
public final class LoginItemController {
  public private(set) var isEnabled = false
  public private(set) var status = SMAppService.Status.notRegistered

  public var errorDescription: String? {
    issue?.localizedDescription(using: languageController.localizer)
  }

  private let languageController: LanguageController
  private var issue: LoginItemIssue?

  public init(languageController: LanguageController) {
    self.languageController = languageController
    refresh()
  }

  public func refresh() {
    updateStatus()
    issue =
      status == .requiresApproval
      ? .registeredRequiresApproval
      : nil
  }

  public func setEnabled(_ enabled: Bool) {
    updateStatus()
    do {
      if enabled {
        switch status {
        case .notRegistered:
          try SMAppService.mainApp.register()
        case .requiresApproval:
          issue = .approvalRequired
          return
        case .enabled:
          return
        case .notFound:
          issue = .bundleUnavailable
          return
        @unknown default:
          issue = .unknownStatus
          return
        }
      } else if status != .notRegistered {
        try SMAppService.mainApp.unregister()
      }
      refresh()
    } catch {
      updateStatus()
      issue = .system(error.localizedDescription)
    }
  }

  public func openLoginItemSettings() {
    SMAppService.openSystemSettingsLoginItems()
  }

  private func updateStatus() {
    status = SMAppService.mainApp.status
    isEnabled = status == .enabled || status == .requiresApproval
  }
}

private enum LoginItemIssue {
  case registeredRequiresApproval
  case approvalRequired
  case bundleUnavailable
  case unknownStatus
  case system(String)

  func localizedDescription(using localizer: AppLocalizer) -> String {
    switch self {
    case .registeredRequiresApproval:
      localizer.string(.loginRegisteredRequiresApproval)
    case .approvalRequired:
      localizer.string(.loginApprovalRequired)
    case .bundleUnavailable:
      localizer.string(.loginBundleUnavailable)
    case .unknownStatus:
      localizer.string(.loginUnknownStatus)
    case .system(let message):
      message
    }
  }
}
