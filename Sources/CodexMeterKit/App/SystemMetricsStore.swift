import Foundation
import Observation

struct SystemMetricsPollingPolicy: Equatable, Sendable {
  static let visibleInterval: TimeInterval = 5
  static let hiddenInterval: TimeInterval = 120

  static func interval(isWidgetVisible: Bool) -> TimeInterval {
    isWidgetVisible ? visibleInterval : hiddenInterval
  }

  static func tolerance(for delay: TimeInterval) -> TimeInterval {
    min(max(delay * 0.2, 1), 15)
  }
}

/// Polls local machine pressure for the quota ring. Sampling is a pair of cheap
/// kernel calls, so the store keeps the last good reading instead of clearing it
/// when a sample fails, and it slows down whenever the widget is hidden.
@MainActor
@Observable
public final class SystemMetricsStore {
  public private(set) var snapshot: SystemMetricsSnapshot?
  public private(set) var isWidgetVisible = true

  @ObservationIgnored private let provider: any SystemMetricsProviding
  @ObservationIgnored private var pollingTask: Task<Void, Never>?
  @ObservationIgnored private var hasStarted = false

  public init(provider: any SystemMetricsProviding = DarwinSystemMetricsProvider()) {
    self.provider = provider
    snapshot = provider.sample()
  }

  public func start() {
    guard !hasStarted else { return }
    hasStarted = true
    refresh()
    startPolling()
  }

  public func stop() {
    hasStarted = false
    pollingTask?.cancel()
    pollingTask = nil
  }

  public func setWidgetVisible(_ isVisible: Bool) {
    guard isWidgetVisible != isVisible else { return }
    isWidgetVisible = isVisible
    guard hasStarted else { return }
    pollingTask?.cancel()
    if isVisible { refresh() }
    startPolling()
  }

  public func refresh() {
    guard let next = provider.sample() else { return }
    snapshot = next
  }

  private func startPolling() {
    pollingTask = Task(priority: .utility) { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        let delay = SystemMetricsPollingPolicy.interval(
          isWidgetVisible: isWidgetVisible
        )
        do {
          try await Task.sleep(
            for: .seconds(delay),
            tolerance: .seconds(SystemMetricsPollingPolicy.tolerance(for: delay))
          )
        } catch {
          return
        }
        guard !Task.isCancelled else { return }
        refresh()
      }
    }
  }
}
