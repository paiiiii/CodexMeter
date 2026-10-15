import Darwin
import Foundation

/// A single reading of local machine pressure: physical memory, swap, and the
/// startup volume. Every value is measured on this Mac and never leaves it.
public struct SystemMetricsSnapshot: Equatable, Sendable {
  public let sampledAt: Date
  public let memoryUsedBytes: UInt64
  public let memoryTotalBytes: UInt64
  public let swapUsedBytes: UInt64
  public let swapTotalBytes: UInt64
  public let diskUsedBytes: UInt64
  public let diskTotalBytes: UInt64

  public init(
    sampledAt: Date,
    memoryUsedBytes: UInt64,
    memoryTotalBytes: UInt64,
    swapUsedBytes: UInt64,
    swapTotalBytes: UInt64,
    diskUsedBytes: UInt64,
    diskTotalBytes: UInt64
  ) {
    self.sampledAt = sampledAt
    self.memoryUsedBytes = memoryUsedBytes
    self.memoryTotalBytes = memoryTotalBytes
    self.swapUsedBytes = swapUsedBytes
    self.swapTotalBytes = swapTotalBytes
    self.diskUsedBytes = diskUsedBytes
    self.diskTotalBytes = diskTotalBytes
  }

  public var memoryUsedPercent: Int {
    Self.percent(memoryUsedBytes, of: memoryTotalBytes)
  }

  public var diskUsedPercent: Int {
    Self.percent(diskUsedBytes, of: diskTotalBytes)
  }

  public var diskFreeBytes: UInt64 {
    diskTotalBytes > diskUsedBytes ? diskTotalBytes - diskUsedBytes : 0
  }

  /// `nil` while macOS has not created any swap file, which is the healthy case.
  public var swapUsedPercent: Int? {
    guard swapTotalBytes > 0 else { return nil }
    return Self.percent(swapUsedBytes, of: swapTotalBytes)
  }

  static func percent(_ value: UInt64, of total: UInt64) -> Int {
    guard total > 0 else { return 0 }
    let ratio = Double(value) / Double(total) * 100
    return min(max(Int(ratio.rounded()), 0), 100)
  }
}

public protocol SystemMetricsProviding: Sendable {
  /// Returns `nil` when the kernel refuses a reading so callers can keep the
  /// previous snapshot instead of blanking the widget.
  func sample() -> SystemMetricsSnapshot?
}

/// Reads memory, swap, and volume pressure from the local kernel only.
public struct DarwinSystemMetricsProvider: SystemMetricsProviding {
  private let volumeURL: URL
  private let clock: @Sendable () -> Date

  public init(
    volumeURL: URL = URL(fileURLWithPath: "/", isDirectory: true),
    clock: @escaping @Sendable () -> Date = { .now }
  ) {
    self.volumeURL = volumeURL
    self.clock = clock
  }

  public func sample() -> SystemMetricsSnapshot? {
    guard let memory = Self.memoryUsage() else { return nil }
    let swap = Self.swapUsage() ?? (used: 0, total: 0)
    let disk = Self.volumeUsage(at: volumeURL) ?? (used: 0, total: 0)
    return SystemMetricsSnapshot(
      sampledAt: clock(),
      memoryUsedBytes: memory.used,
      memoryTotalBytes: memory.total,
      swapUsedBytes: swap.used,
      swapTotalBytes: swap.total,
      diskUsedBytes: disk.used,
      diskTotalBytes: disk.total
    )
  }

  /// Mirrors Activity Monitor's "Memory Used": app memory, wired, and compressed.
  static func memoryUsage() -> (used: UInt64, total: UInt64)? {
    let total = ProcessInfo.processInfo.physicalMemory
    guard total > 0 else { return nil }

    var statistics = vm_statistics64_data_t()
    var count = mach_msg_type_number_t(
      MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
    )
    let host = mach_host_self()
    defer { mach_port_deallocate(mach_task_self_, host) }

    let status = withUnsafeMutablePointer(to: &statistics) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
        host_statistics64(host, HOST_VM_INFO64, rebound, &count)
      }
    }
    guard status == KERN_SUCCESS else { return nil }

    var pageSize = vm_size_t()
    guard host_page_size(host, &pageSize) == KERN_SUCCESS, pageSize > 0 else {
      return nil
    }

    let appPages =
      statistics.internal_page_count >= statistics.purgeable_count
      ? statistics.internal_page_count - statistics.purgeable_count
      : 0
    let usedPages =
      UInt64(appPages)
      + UInt64(statistics.wire_count)
      + UInt64(statistics.compressor_page_count)
    let used = usedPages.multipliedReportingOverflow(by: UInt64(pageSize))
    guard !used.overflow else { return nil }
    return (min(used.partialValue, total), total)
  }

  static func swapUsage() -> (used: UInt64, total: UInt64)? {
    var usage = xsw_usage()
    var size = MemoryLayout<xsw_usage>.size
    guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else { return nil }
    return (usage.xsu_used, usage.xsu_total)
  }

  static func volumeUsage(at url: URL) -> (used: UInt64, total: UInt64)? {
    let keys: Set<URLResourceKey> = [
      .volumeTotalCapacityKey,
      .volumeAvailableCapacityForImportantUsageKey,
      .volumeAvailableCapacityKey,
    ]
    guard
      let values = try? url.resourceValues(forKeys: keys),
      let totalCapacity = values.volumeTotalCapacity,
      totalCapacity > 0
    else { return nil }

    let available: Int64
    if let important = values.volumeAvailableCapacityForImportantUsage, important > 0 {
      available = important
    } else if let plain = values.volumeAvailableCapacity {
      available = Int64(plain)
    } else {
      return nil
    }

    let total = UInt64(totalCapacity)
    let free = min(UInt64(max(available, 0)), total)
    return (total - free, total)
  }
}
