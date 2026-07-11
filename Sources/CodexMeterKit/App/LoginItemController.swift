import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
public final class LoginItemController {
  public private(set) var isEnabled = false
  public private(set) var errorDescription: String?
  public private(set) var status = SMAppService.Status.notRegistered

  public init() {
    refresh()
  }

  public func refresh() {
    updateStatus()
    errorDescription =
      status == .requiresApproval
      ? "CodexMeter 已注册，但仍需要你在“系统设置 → 登录项”中批准。"
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
          errorDescription = "请在系统设置的登录项中批准 CodexMeter。"
          return
        case .enabled:
          return
        case .notFound:
          throw LoginItemError.appBundleUnavailable
        @unknown default:
          throw LoginItemError.unknownStatus
        }
      } else if status != .notRegistered {
        try SMAppService.mainApp.unregister()
      }
      refresh()
    } catch {
      updateStatus()
      errorDescription = error.localizedDescription
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

private enum LoginItemError: LocalizedError {
  case appBundleUnavailable
  case unknownStatus

  var errorDescription: String? {
    switch self {
    case .appBundleUnavailable:
      "当前应用包无法注册为登录项，请先把 CodexMeter 安装到稳定位置。"
    case .unknownStatus:
      "无法读取登录项状态，请在系统设置中检查。"
    }
  }
}
