import Darwin
import Foundation
import XCTest

@testable import CodexMeterKit

final class CodexAppServerClientLifecycleTests: XCTestCase {
  func testSmallResponsesArriveWhileFakeServerStaysRunning() async throws {
    let client = makeClient(script: Self.fakeServerScript)
    do {
      let snapshot = try await client.fetchUsage()

      XCTAssertEqual(snapshot.primary?.remainingPercent, 83)
      XCTAssertEqual(snapshot.primary?.windowDurationMinutes, 300)
      XCTAssertEqual(snapshot.lifetimeTokens, 123)
      await client.shutdown()
    } catch {
      await client.shutdown()
      throw error
    }
  }

  func testShutdownDuringInitializationCanImmediatelyStartANewGeneration() async throws {
    let client = makeClient(script: Self.delayedFakeServerScript)
    do {
      for iteration in 0..<10 {
        let interruptedFetch = Task { try await client.fetchUsage() }
        try await Task.sleep(for: .milliseconds(5))
        await client.shutdown()

        if case .success = await interruptedFetch.result {
          XCTFail("Interrupted fetch unexpectedly succeeded at iteration \(iteration)")
        }

        let restartedSnapshot = try await client.fetchUsage()
        XCTAssertEqual(
          restartedSnapshot.primary?.remainingPercent,
          83,
          "Iteration \(iteration)"
        )
        await client.shutdown()
      }
    } catch {
      await client.shutdown()
      throw error
    }
  }

  func testClosedServerInputBecomesARecoverableClientError() async {
    let client = makeClient(script: Self.closeInputAfterInitializeScript)

    do {
      _ = try await client.fetchUsage()
      XCTFail("Expected the fake server's closed stdin to fail the request")
    } catch {
      let underlyingError = (error as NSError).userInfo[NSUnderlyingErrorKey] as? NSError
      XCTAssertEqual(underlyingError?.domain, NSPOSIXErrorDomain)
      XCTAssertEqual(underlyingError?.code, Int(EPIPE))
    }
    await client.shutdown()
  }

  private func makeClient(script: String) -> CodexAppServerClient {
    CodexAppServerClient(
      locator: CodexBinaryLocator(candidates: ["/usr/bin/python3"]),
      processArguments: ["-u", "-c", script],
      timeout: .seconds(2),
      now: { Date(timeIntervalSince1970: 2_000_000_000) },
      timeZone: { TimeZone(secondsFromGMT: 0)! }
    )
  }

  private static let fakeServerScript = #"""
import json
import sys

for raw in sys.stdin:
    message = json.loads(raw)
    if "id" not in message:
        continue
    method = message.get("method")
    if method == "initialize":
        result = {
            "codexHome": "/tmp/codex",
            "platformFamily": "unix",
            "platformOs": "macos"
        }
    elif method == "account/rateLimits/read":
        result = {
            "rateLimits": {
                "primary": {
                    "usedPercent": 17,
                    "windowDurationMins": 300,
                    "resetsAt": 2000003600
                },
                "secondary": None,
                "planType": "test"
            }
        }
    elif method == "account/usage/read":
        result = {
            "summary": {"lifetimeTokens": 123},
            "dailyUsageBuckets": []
        }
    else:
        result = {}
    print(json.dumps({"id": message["id"], "result": result}), flush=True)
"""#

  private static let delayedFakeServerScript = #"""
import json
import sys
import time

for raw in sys.stdin:
    message = json.loads(raw)
    if "id" not in message:
        continue
    method = message.get("method")
    if method == "initialize":
        time.sleep(0.05)
        result = {
            "codexHome": "/tmp/codex",
            "platformFamily": "unix",
            "platformOs": "macos"
        }
    elif method == "account/rateLimits/read":
        result = {
            "rateLimits": {
                "primary": {
                    "usedPercent": 17,
                    "windowDurationMins": 300,
                    "resetsAt": 2000003600
                },
                "secondary": None,
                "planType": "test"
            }
        }
    elif method == "account/usage/read":
        result = {
            "summary": {"lifetimeTokens": 123},
            "dailyUsageBuckets": []
        }
    else:
        result = {}
    print(json.dumps({"id": message["id"], "result": result}), flush=True)
"""#

  private static let closeInputAfterInitializeScript = #"""
import json
import os
import sys
import time

message = json.loads(sys.stdin.readline())
os.close(0)
time.sleep(0.05)
result = {
    "codexHome": "/tmp/codex",
    "platformFamily": "unix",
    "platformOs": "macos"
}
print(json.dumps({"id": message["id"], "result": result}), flush=True)
time.sleep(1)
"""#
}
