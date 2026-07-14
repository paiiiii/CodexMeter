import XCTest

@testable import CodexMeterKit

private actor ControlledEnergyProvider: UsageProviding {
  private var continuation: CheckedContinuation<UsageSnapshot, Never>?
  private(set) var fetchCount = 0

  func fetchUsage() async throws -> UsageSnapshot {
    fetchCount += 1
    return await withCheckedContinuation { continuation in
      self.continuation = continuation
    }
  }

  func resolve(with snapshot: UsageSnapshot) {
    continuation?.resume(returning: snapshot)
    continuation = nil
  }
}

private actor FailingEnergyProvider: UsageProviding {
  private(set) var fetchCount = 0

  func fetchUsage() async throws -> UsageSnapshot {
    fetchCount += 1
    throw URLError(.notConnectedToInternet)
  }
}

final class EnergyEfficiencyTests: XCTestCase {
  func testPollingIntervalsAreClampedAndHiddenPollingBacksOff() {
    XCTAssertEqual(UsagePollingPolicy.normalized(1), 15)
    XCTAssertEqual(UsagePollingPolicy.normalized(30), 30)
    XCTAssertEqual(UsagePollingPolicy.normalized(900), 300)

    XCTAssertEqual(
      UsagePollingPolicy.delay(requestedInterval: 30, isWidgetVisible: true),
      30
    )
    XCTAssertEqual(
      UsagePollingPolicy.delay(requestedInterval: 30, isWidgetVisible: false),
      300
    )

    XCTAssertEqual(
      UsagePollingPolicy.delay(
        requestedInterval: 30,
        isWidgetVisible: true,
        consecutiveFailures: 1
      ),
      60
    )
    XCTAssertEqual(
      UsagePollingPolicy.delay(
        requestedInterval: 30,
        isWidgetVisible: true,
        consecutiveFailures: 2
      ),
      120
    )
    XCTAssertEqual(
      UsagePollingPolicy.delay(
        requestedInterval: 30,
        isWidgetVisible: true,
        consecutiveFailures: 99
      ),
      300
    )
    XCTAssertEqual(
      UsagePollingPolicy.delay(
        requestedInterval: 15,
        isWidgetVisible: true,
        consecutiveFailures: UsagePollingPolicy.maximumFailureExponent
      ),
      300
    )
  }

  func testPollingToleranceAllowsWakeupCoalescing() {
    XCTAssertEqual(UsagePollingPolicy.tolerance(for: 15), 1.5)
    XCTAssertEqual(UsagePollingPolicy.tolerance(for: 30), 3)
    XCTAssertEqual(UsagePollingPolicy.tolerance(for: 300), 15)
  }

  @MainActor
  func testVisibilityRestartsCoalesceWithAnInFlightRefresh() async throws {
    let suiteName = "CodexMeterTests.EnergyPolling.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let provider = ControlledEnergyProvider()
    let languageController = LanguageController(
      defaults: defaults,
      notificationCenter: NotificationCenter()
    )
    let store = UsageStore(
      provider: provider,
      languageController: languageController,
      defaults: defaults
    )
    store.start()
    defer { store.stop() }

    try await waitUntil { await provider.fetchCount == 1 }
    XCTAssertTrue(store.isRefreshing)

    store.setWidgetVisible(false)
    store.setWidgetVisible(true)
    let fetchCountDuringRestart = await provider.fetchCount
    XCTAssertEqual(fetchCountDuringRestart, 1)

    let expected = UsageSnapshot(
      fetchedAt: .now,
      planType: "plus",
      primary: QuotaWindow(
        usedPercent: 25,
        windowDurationMinutes: 300,
        resetsAt: .now.addingTimeInterval(3_600)
      ),
      secondary: nil,
      todayTokens: 42,
      lifetimeTokens: nil
    )
    await provider.resolve(with: expected)

    try await waitUntil { !store.isRefreshing && store.snapshot != nil }
    XCTAssertEqual(store.snapshot, expected)
    let finalFetchCount = await provider.fetchCount
    XCTAssertEqual(finalFetchCount, 1)
  }

  @MainActor
  func testManualFailureRestartsBackoffWithoutImmediateRetry() async throws {
    let suiteName = "CodexMeterTests.EnergyBackoff.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let provider = FailingEnergyProvider()
    let languageController = LanguageController(
      defaults: defaults,
      notificationCenter: NotificationCenter()
    )
    let store = UsageStore(
      provider: provider,
      languageController: languageController,
      defaults: defaults
    )
    store.start()
    defer { store.stop() }

    try await waitUntil {
      await provider.fetchCount == 1 && !store.isRefreshing
    }

    await store.refresh()
    try await Task.sleep(for: .milliseconds(50))

    let fetchCount = await provider.fetchCount
    XCTAssertEqual(fetchCount, 2)
    XCTAssertFalse(store.isRefreshing)
  }

  @MainActor
  private func waitUntil(
    attempts: Int = 100,
    condition: @MainActor @escaping () async -> Bool
  ) async throws {
    for _ in 0..<attempts {
      if await condition() { return }
      try await Task.sleep(for: .milliseconds(10))
    }
    XCTFail("Timed out waiting for asynchronous polling state")
  }
}
