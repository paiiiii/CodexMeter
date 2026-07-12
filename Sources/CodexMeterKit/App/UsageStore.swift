import Foundation
import Observation

@MainActor
@Observable
public final class UsageStore {
  public private(set) var snapshot: UsageSnapshot?
  public private(set) var isRefreshing = false
  public private(set) var isWidgetVisible = true

  public var lastErrorDescription: String? {
    guard let lastError else { return nil }
    if let error = lastError as? CodexAppServerError {
      return error.localizedDescription(using: languageController.localizer)
    }
    return lastError.localizedDescription
  }

  public var refreshInterval: TimeInterval {
    didSet {
      refreshInterval = min(max(refreshInterval, 15), 300)
      defaults.set(refreshInterval, forKey: Keys.refreshInterval)
      restartPollingIfNeeded()
    }
  }

  private enum Keys {
    static let refreshInterval = "CodexMeter.refreshInterval"
  }

  private let provider: any UsageProviding
  private let languageController: LanguageController
  private let defaults: UserDefaults
  private var lastError: (any Error)?
  private var pollingTask: Task<Void, Never>?
  private var hasStarted = false

  public init(
    provider: any UsageProviding,
    languageController: LanguageController,
    defaults: UserDefaults = .standard
  ) {
    self.provider = provider
    self.languageController = languageController
    self.defaults = defaults
    let storedInterval = defaults.double(forKey: Keys.refreshInterval)
    refreshInterval = storedInterval == 0 ? 30 : min(max(storedInterval, 15), 300)
  }

  public func start() {
    guard !hasStarted else { return }
    hasStarted = true
    startPolling()
  }

  public func stop() {
    hasStarted = false
    pollingTask?.cancel()
    pollingTask = nil
  }

  public func shutdown() async {
    stop()
    await provider.shutdown()
  }

  public func setWidgetVisible(_ isVisible: Bool) {
    guard isWidgetVisible != isVisible else { return }
    isWidgetVisible = isVisible
    restartPollingIfNeeded()
  }

  public func refresh() async {
    guard !isRefreshing else { return }
    isRefreshing = true
    defer { isRefreshing = false }

    do {
      let nextSnapshot = try await provider.fetchUsage()
      guard !Task.isCancelled else { return }
      snapshot = nextSnapshot
      lastError = nil
    } catch is CancellationError {
      return
    } catch {
      lastError = error
    }
  }

  private func restartPollingIfNeeded() {
    guard hasStarted else { return }
    pollingTask?.cancel()
    startPolling()
  }

  private func startPolling() {
    pollingTask = Task { [weak self] in
      guard let self else { return }
      while !Task.isCancelled {
        await refresh()
        let delay = isWidgetVisible ? refreshInterval : max(refreshInterval, 300)
        do {
          try await Task.sleep(for: .seconds(delay))
        } catch {
          return
        }
      }
    }
  }
}
