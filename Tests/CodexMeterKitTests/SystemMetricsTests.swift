import Foundation
import XCTest

@testable import CodexMeterKit

private struct StubSystemMetricsProvider: SystemMetricsProviding {
  final class State: @unchecked Sendable {
    var snapshots: [SystemMetricsSnapshot?]
    var sampleCount = 0

    init(snapshots: [SystemMetricsSnapshot?]) {
      self.snapshots = snapshots
    }
  }

  let state: State

  init(snapshots: [SystemMetricsSnapshot?]) {
    state = State(snapshots: snapshots)
  }

  func sample() -> SystemMetricsSnapshot? {
    defer { state.sampleCount += 1 }
    guard state.sampleCount < state.snapshots.count else {
      return state.snapshots.last ?? nil
    }
    return state.snapshots[state.sampleCount]
  }
}

private func makeSnapshot(
  memoryUsed: UInt64 = 8_589_934_592,
  memoryTotal: UInt64 = 17_179_869_184,
  swapUsed: UInt64 = 0,
  swapTotal: UInt64 = 0,
  diskUsed: UInt64 = 300_000_000_000,
  diskTotal: UInt64 = 500_000_000_000
) -> SystemMetricsSnapshot {
  SystemMetricsSnapshot(
    sampledAt: Date(timeIntervalSince1970: 1_000_000),
    memoryUsedBytes: memoryUsed,
    memoryTotalBytes: memoryTotal,
    swapUsedBytes: swapUsed,
    swapTotalBytes: swapTotal,
    diskUsedBytes: diskUsed,
    diskTotalBytes: diskTotal
  )
}

final class SystemMetricsTests: XCTestCase {
  private let english = AppLocalizer(language: .english)
  private let chinese = AppLocalizer(language: .simplifiedChinese)

  func testSnapshotDerivesClampedPercentagesAndFreeSpace() {
    let snapshot = makeSnapshot(
      memoryUsed: 12_884_901_888,
      swapUsed: 2_147_483_648,
      swapTotal: 4_294_967_296
    )
    XCTAssertEqual(snapshot.memoryUsedPercent, 75)
    XCTAssertEqual(snapshot.swapUsedPercent, 50)
    XCTAssertEqual(snapshot.diskUsedPercent, 60)
    XCTAssertEqual(snapshot.diskFreeBytes, 200_000_000_000)

    let idle = makeSnapshot()
    XCTAssertNil(idle.swapUsedPercent)

    let empty = makeSnapshot(memoryTotal: 0, diskTotal: 0)
    XCTAssertEqual(empty.memoryUsedPercent, 0)
    XCTAssertEqual(empty.diskUsedPercent, 0)
    XCTAssertEqual(empty.diskFreeBytes, 0)

    let overflowing = makeSnapshot(memoryUsed: 20_000_000_000)
    XCTAssertEqual(overflowing.memoryUsedPercent, 100)
  }

  func testSystemLoadSeverityBoundaries() {
    let expectations: [(Int?, SystemLoadSeverity)] = [
      (nil, .nominal),
      (0, .nominal),
      (74, .nominal),
      (75, .elevated),
      (89, .elevated),
      (90, .critical),
      (100, .critical),
    ]
    for (usedPercent, expected) in expectations {
      XCTAssertEqual(
        SystemLoadSeverity.classify(usedPercent: usedPercent),
        expected,
        "Unexpected severity for \(String(describing: usedPercent))"
      )
    }

    XCTAssertEqual(SystemLoadSeverity.classifySwap(usedBytes: nil), .nominal)
    XCTAssertEqual(SystemLoadSeverity.classifySwap(usedBytes: 0), .nominal)
    XCTAssertEqual(
      SystemLoadSeverity.classifySwap(usedBytes: 1_073_741_823),
      .nominal
    )
    XCTAssertEqual(
      SystemLoadSeverity.classifySwap(usedBytes: 1_073_741_824),
      .elevated
    )
    XCTAssertEqual(
      SystemLoadSeverity.classifySwap(usedBytes: 4_294_967_296),
      .critical
    )
  }

  func testPollingSlowsDownWhileTheWidgetIsHidden() {
    XCTAssertEqual(SystemMetricsPollingPolicy.interval(isWidgetVisible: true), 5)
    XCTAssertEqual(SystemMetricsPollingPolicy.interval(isWidgetVisible: false), 120)
    XCTAssertGreaterThan(
      SystemMetricsPollingPolicy.hiddenInterval,
      SystemMetricsPollingPolicy.visibleInterval
    )
    XCTAssertEqual(SystemMetricsPollingPolicy.tolerance(for: 5), 1)
    XCTAssertEqual(SystemMetricsPollingPolicy.tolerance(for: 120), 15)
  }

  @MainActor
  func testStoreSamplesOnInitAndKeepsTheLastReadingWhenSamplingFails() {
    let first = makeSnapshot(memoryUsed: 4_294_967_296)
    let second = makeSnapshot(memoryUsed: 8_589_934_592)
    let provider = StubSystemMetricsProvider(snapshots: [first, nil, second])
    let store = SystemMetricsStore(provider: provider)

    XCTAssertEqual(store.snapshot, first)

    store.refresh()
    XCTAssertEqual(store.snapshot, first, "A failed sample must not blank the ring")

    store.refresh()
    XCTAssertEqual(store.snapshot, second)
  }

  @MainActor
  func testHidingTheWidgetPausesPollingAndShowingItRefreshesImmediately() {
    let provider = StubSystemMetricsProvider(snapshots: [makeSnapshot()])
    let store = SystemMetricsStore(provider: provider)
    XCTAssertTrue(store.isWidgetVisible)
    XCTAssertEqual(provider.state.sampleCount, 1)

    store.setWidgetVisible(false)
    XCTAssertFalse(store.isWidgetVisible)
    XCTAssertEqual(
      provider.state.sampleCount,
      1,
      "A stopped store must not sample while hidden"
    )

    store.start()
    XCTAssertEqual(provider.state.sampleCount, 2)
    store.setWidgetVisible(true)
    XCTAssertEqual(provider.state.sampleCount, 3)
    store.stop()
  }

  func testLiveDarwinSampleReportsPlausibleLocalValues() throws {
    let snapshot = try XCTUnwrap(DarwinSystemMetricsProvider().sample())

    XCTAssertEqual(
      snapshot.memoryTotalBytes,
      ProcessInfo.processInfo.physicalMemory
    )
    XCTAssertGreaterThan(snapshot.memoryUsedBytes, 0)
    XCTAssertLessThanOrEqual(snapshot.memoryUsedBytes, snapshot.memoryTotalBytes)
    XCTAssertGreaterThanOrEqual(snapshot.memoryUsedPercent, 1)

    XCTAssertGreaterThan(snapshot.diskTotalBytes, 0)
    XCTAssertLessThanOrEqual(snapshot.diskUsedBytes, snapshot.diskTotalBytes)
    XCTAssertLessThanOrEqual(snapshot.swapUsedBytes, snapshot.swapTotalBytes)
  }

  func testRingValuesStayShortAndLocalized() {
    for localizer in [english, chinese] {
      XCTAssertEqual(MetricFormatter.compactBytes(nil, localizer: localizer), "—")
      XCTAssertEqual(MetricFormatter.compactBytes(0, localizer: localizer), "0")
      XCTAssertEqual(
        MetricFormatter.compactBytes(1_048_575, localizer: localizer),
        "0"
      )
      XCTAssertEqual(
        MetricFormatter.compactBytes(536_870_912, localizer: localizer),
        "512M"
      )
      XCTAssertEqual(
        MetricFormatter.compactBytes(1_288_490_189, localizer: localizer),
        "1.2G"
      )
      XCTAssertEqual(
        MetricFormatter.compactBytes(12_884_901_888, localizer: localizer),
        "12G"
      )
      XCTAssertEqual(MetricFormatter.ringPercent(nil, localizer: localizer), "—")

      for bytes: UInt64 in [0, 999, 1_048_576, 9_999_999_999, 2_199_023_255_552] {
        XCTAssertLessThanOrEqual(
          MetricFormatter.compactBytes(bytes, localizer: localizer).count,
          4,
          "\(bytes) does not fit the ring"
        )
      }
    }

    XCTAssertEqual(MetricFormatter.ringPercent(74, localizer: english), "74%")
    XCTAssertEqual(english.string(.systemMemoryTag), "MEM")
    XCTAssertEqual(chinese.string(.systemDiskTag), "磁盘")
  }

  func testTightQuotaLabelCollapsesTheWindowLength() {
    XCTAssertNil(MetricFormatter.tightQuotaLabel(for: nil, localizer: english))
    XCTAssertNil(
      MetricFormatter.tightQuotaLabel(
        for: QuotaWindow(usedPercent: 10, windowDurationMinutes: nil, resetsAt: nil),
        localizer: english
      )
    )
    XCTAssertEqual(
      MetricFormatter.tightQuotaLabel(
        for: QuotaWindow(usedPercent: 10, windowDurationMinutes: 300, resetsAt: nil),
        localizer: english
      ),
      "5H"
    )
    XCTAssertEqual(
      MetricFormatter.tightQuotaLabel(
        for: QuotaWindow(usedPercent: 10, windowDurationMinutes: 10_080, resetsAt: nil),
        localizer: chinese
      ),
      "7D"
    )
    XCTAssertEqual(
      MetricFormatter.tightQuotaLabel(
        for: QuotaWindow(usedPercent: 10, windowDurationMinutes: 45, resetsAt: nil),
        localizer: english
      ),
      "45M"
    )
  }

  func testRingAccessibilityValueCarriesQuotaAndSystemReadings() {
    let value = MetricFormatter.ringAccessibilityValue(
      window: QuotaWindow(
        usedPercent: 40,
        windowDurationMinutes: 300,
        resetsAt: Date(timeIntervalSince1970: 1_003_600)
      ),
      system: makeSnapshot(),
      localizer: english
    )
    XCTAssertTrue(value.contains("60% remaining"), value)
    XCTAssertTrue(value.contains("Memory 50%"), value)
    XCTAssertTrue(value.hasSuffix("disk 60%"), value)
  }

  func testSystemHelpAndAccessibilityValueAreLocalized() {
    XCTAssertEqual(
      MetricFormatter.systemHelp(for: nil, localizer: english),
      "System metrics unavailable"
    )
    XCTAssertEqual(
      MetricFormatter.systemAccessibilityValue(for: nil, localizer: chinese),
      "系统信息不可用"
    )

    let idleHelp = MetricFormatter.systemHelp(
      for: makeSnapshot(),
      localizer: english
    )
    XCTAssertEqual(idleHelp.split(separator: "\n").count, 3)
    XCTAssertTrue(idleHelp.contains("Swap · not in use"))
    XCTAssertTrue(idleHelp.contains("Memory"))
    XCTAssertTrue(idleHelp.contains("Disk"))

    let busyHelp = MetricFormatter.systemHelp(
      for: makeSnapshot(swapUsed: 2_147_483_648, swapTotal: 4_294_967_296),
      localizer: chinese
    )
    XCTAssertTrue(busyHelp.contains("交换 · 已用"))
    XCTAssertFalse(busyHelp.contains("未使用"))

    let value = MetricFormatter.systemAccessibilityValue(
      for: makeSnapshot(),
      localizer: english
    )
    XCTAssertTrue(value.hasPrefix("Memory 50%"))
    XCTAssertTrue(value.hasSuffix("disk 60%"))
  }
}
