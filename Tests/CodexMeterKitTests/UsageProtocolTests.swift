import Foundation
import XCTest

@testable import CodexMeterKit

final class UsageProtocolTests: XCTestCase {
  func testMapsMainCodexQuotaAndTodayBucket() throws {
    let rateJSON = #"""
      {
        "rateLimits": {
          "primary": { "usedPercent": 90, "windowDurationMins": 10, "resetsAt": 1 },
          "secondary": null,
          "planType": "unknown"
        },
        "rateLimitsByLimitId": {
          "codex": {
            "primary": { "usedPercent": 6, "windowDurationMins": 300, "resetsAt": 1783812440 },
            "secondary": { "usedPercent": 21, "windowDurationMins": 10080, "resetsAt": 1784399240 },
            "planType": "prolite"
          }
        }
      }
      """#
    let usageJSON = #"""
      {
        "summary": { "lifetimeTokens": 1023442992 },
        "dailyUsageBuckets": [
          { "startDate": "2026-07-10", "tokens": 100 },
          { "startDate": "2026-07-11", "tokens": 55009052 }
        ]
      }
      """#

    let decoder = JSONDecoder()
    let rateLimits = try decoder.decode(RateLimitsResult.self, from: Data(rateJSON.utf8))
    let usage = try decoder.decode(AccountUsageResult.self, from: Data(usageJSON.utf8))
    let now = try XCTUnwrap(
      ISO8601DateFormatter().date(from: "2026-07-11T18:30:00Z")
    )

    let snapshot = UsageResponseMapper.makeSnapshot(
      rateLimits: rateLimits,
      usage: usage,
      now: now,
      timeZone: try XCTUnwrap(TimeZone(secondsFromGMT: 0))
    )

    XCTAssertEqual(snapshot.planType, "prolite")
    XCTAssertEqual(snapshot.primary?.usedPercent, 6)
    XCTAssertEqual(snapshot.primary?.remainingPercent, 94)
    XCTAssertEqual(snapshot.primary?.windowDurationMinutes, 300)
    XCTAssertEqual(snapshot.secondary?.remainingPercent, 79)
    XCTAssertEqual(snapshot.todayTokens, 55_009_052)
    XCTAssertEqual(snapshot.lifetimeTokens, 1_023_442_992)
  }

  func testMissingTodayBucketStaysUnavailableInsteadOfInventingZero() throws {
    let rateJSON = #"""
      { "rateLimits": { "primary": null, "secondary": null, "planType": null } }
      """#
    let usageJSON = #"""
      { "summary": {}, "dailyUsageBuckets": [] }
      """#
    let decoder = JSONDecoder()
    let rateLimits = try decoder.decode(RateLimitsResult.self, from: Data(rateJSON.utf8))
    let usage = try decoder.decode(AccountUsageResult.self, from: Data(usageJSON.utf8))

    let snapshot = UsageResponseMapper.makeSnapshot(
      rateLimits: rateLimits,
      usage: usage,
      now: Date(timeIntervalSince1970: 0),
      timeZone: try XCTUnwrap(TimeZone(secondsFromGMT: 0))
    )

    XCTAssertNil(snapshot.todayTokens)
    XCTAssertNil(snapshot.primary)
  }

  func testRemainingPercentIsClamped() {
    XCTAssertEqual(
      QuotaWindow(usedPercent: -10, windowDurationMinutes: nil, resetsAt: nil)
        .remainingPercent,
      100
    )
    XCTAssertEqual(
      QuotaWindow(usedPercent: 130, windowDurationMinutes: nil, resetsAt: nil)
        .remainingPercent,
      0
    )
  }

  func testJSONLineFramerHandlesSplitAndMultipleMessages() throws {
    var framer = JSONLineFramer()

    XCTAssertTrue(try framer.append(Data("{\"id\":1,\"res".utf8)).isEmpty)
    let lines = try framer.append(
      Data("ult\":{}}\n{\"id\":2,\"result\":{}}\r\n".utf8)
    )

    XCTAssertEqual(lines.count, 2)
    XCTAssertEqual(String(decoding: lines[0], as: UTF8.self), "{\"id\":1,\"result\":{}}")
    XCTAssertEqual(String(decoding: lines[1], as: UTF8.self), "{\"id\":2,\"result\":{}}")
  }

  func testJSONLineFramerRejectsAnUnboundedMessage() throws {
    var framer = JSONLineFramer(maximumFrameSize: 8)

    XCTAssertThrowsError(try framer.append(Data("123456789".utf8))) { error in
      XCTAssertEqual(error as? CodexAppServerError, .invalidMessage)
    }
    XCTAssertEqual(try framer.append(Data("{}\n".utf8)), [Data("{}".utf8)])
  }

  func testBinaryLocatorUsesFirstExecutableCandidate() throws {
    let locator = CodexBinaryLocator(
      candidates: ["/missing/codex", "/working/codex"],
      environment: [:],
      isExecutable: { $0 == "/working/codex" }
    )

    XCTAssertEqual(try locator.locate().path, "/working/codex")
  }

  func testBinaryLocatorReportsActionableError() {
    let locator = CodexBinaryLocator(
      candidates: ["/missing/codex"],
      environment: [:],
      isExecutable: { _ in false }
    )

    XCTAssertThrowsError(try locator.locate()) { error in
      XCTAssertEqual(error as? CodexAppServerError, .binaryNotFound)
      XCTAssertTrue(error.localizedDescription.contains("Codex"))
    }
  }
}
