import AppKit
import XCTest

@testable import CodexMeterKit

final class WindowModePolicyTests: XCTestCase {
  func testFloatingPolicyStaysAboveNormalWindowsAndAcrossSpaces() {
    let policy = WindowModePolicy.policy(for: .floating)

    XCTAssertEqual(policy.level.rawValue, NSWindow.Level.floating.rawValue)
    XCTAssertTrue(policy.isFloatingPanel)
    XCTAssertTrue(policy.isVisible)
    XCTAssertTrue(policy.hasShadow)
    XCTAssertTrue(policy.collectionBehavior.contains(.canJoinAllSpaces))
    XCTAssertTrue(policy.collectionBehavior.contains(.canJoinAllApplications))
    XCTAssertTrue(policy.collectionBehavior.contains(.transient))
    XCTAssertTrue(policy.collectionBehavior.contains(.ignoresCycle))
    assertNoMutuallyExclusiveBehaviors(in: policy.collectionBehavior)
  }

  func testDesktopPolicySitsBehindNormalWindowsAndRemainsStationary() {
    let policy = WindowModePolicy.policy(for: .desktop)

    XCTAssertEqual(policy.level.rawValue, NSWindow.Level.normal.rawValue - 1)
    XCTAssertFalse(policy.isFloatingPanel)
    XCTAssertTrue(policy.isVisible)
    XCTAssertFalse(policy.hasShadow)
    XCTAssertTrue(policy.collectionBehavior.contains(.canJoinAllSpaces))
    XCTAssertTrue(policy.collectionBehavior.contains(.stationary))
    XCTAssertTrue(policy.collectionBehavior.contains(.fullScreenNone))
    assertNoMutuallyExclusiveBehaviors(in: policy.collectionBehavior)
  }

  func testHiddenPolicyOrdersWindowOut() {
    let policy = WindowModePolicy.policy(for: .hidden)

    XCTAssertFalse(policy.isVisible)
    XCTAssertFalse(policy.isFloatingPanel)
    XCTAssertFalse(policy.hasShadow)
  }

  private func assertNoMutuallyExclusiveBehaviors(
    in behavior: NSWindow.CollectionBehavior,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let missionControlGroup: [NSWindow.CollectionBehavior] = [.managed, .transient, .stationary]
    let fullScreenGroup: [NSWindow.CollectionBehavior] = [
      .fullScreenPrimary,
      .fullScreenAuxiliary,
      .fullScreenNone,
    ]
    let stageManagerGroup: [NSWindow.CollectionBehavior] = [
      .primary,
      .auxiliary,
      .canJoinAllApplications,
    ]

    XCTAssertLessThanOrEqual(
      missionControlGroup.filter(behavior.contains).count,
      1,
      file: file,
      line: line
    )
    XCTAssertLessThanOrEqual(
      fullScreenGroup.filter(behavior.contains).count,
      1,
      file: file,
      line: line
    )
    XCTAssertLessThanOrEqual(
      stageManagerGroup.filter(behavior.contains).count,
      1,
      file: file,
      line: line
    )
  }
}
