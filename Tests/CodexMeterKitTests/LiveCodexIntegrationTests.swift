import Foundation
import XCTest

@testable import CodexMeterKit

final class LiveCodexIntegrationTests: XCTestCase {
  func testLiveAccountUsageRoundTrip() async throws {
    guard ProcessInfo.processInfo.environment["CODEX_METER_LIVE_TESTS"] == "1" else {
      throw XCTSkip("Set CODEX_METER_LIVE_TESTS=1 to exercise the installed Codex app-server.")
    }

    let client = CodexAppServerClient()
    do {
      async let firstFetch = client.fetchUsage()
      async let secondFetch = client.fetchUsage()
      let (snapshot, coalescedSnapshot) = try await (firstFetch, secondFetch)
      XCTAssertTrue((0...100).contains(snapshot.primary?.remainingPercent ?? -1))
      XCTAssertTrue((snapshot.todayTokens ?? -1) >= 0)
      XCTAssertLessThanOrEqual(snapshot.fetchedAt.timeIntervalSinceNow, 1)
      XCTAssertEqual(snapshot, coalescedSnapshot)

      let refreshedSnapshot = try await client.fetchUsage()
      XCTAssertGreaterThanOrEqual(refreshedSnapshot.fetchedAt, snapshot.fetchedAt)
      await client.shutdown()
    } catch {
      await client.shutdown()
      throw error
    }
  }

  func testRepeatedLiveStartupAndShutdown() async throws {
    guard ProcessInfo.processInfo.environment["CODEX_METER_LIVE_TESTS"] == "1" else {
      throw XCTSkip("Set CODEX_METER_LIVE_TESTS=1 to exercise the installed Codex app-server.")
    }

    let client = CodexAppServerClient()
    do {
      for _ in 0..<10 {
        let snapshot = try await client.fetchUsage()
        XCTAssertTrue((0...100).contains(snapshot.primary?.remainingPercent ?? -1))
        await client.shutdown()
      }
    } catch {
      await client.shutdown()
      throw error
    }
  }
}
