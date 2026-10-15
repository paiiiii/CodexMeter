import Foundation
import XCTest

@testable import CodexMeterKit

final class CodexBinaryLocatorTests: XCTestCase {
  func testFindsCurrentDesktopBundlesWithoutAShellPATH() throws {
    for application in ["Codex", "ChatGPT"] {
      let path = "/Applications/\(application).app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"
      let locator = CodexBinaryLocator(
        environment: ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"],
        isExecutable: { $0 == path }
      )

      XCTAssertEqual(try locator.locate().path, path)
    }
  }

  func testBundledNativeBinaryTakesPriorityOverNpmAndPATHLaunchers() throws {
    let bundledPath = "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"
    let npmPath = ("~/.local/bin/codex" as NSString).expandingTildeInPath
    let locator = CodexBinaryLocator(
      environment: ["PATH": "/opt/homebrew/bin:/usr/bin:/bin"],
      isExecutable: {
        [bundledPath, npmPath, "/opt/homebrew/bin/codex"].contains($0)
      }
    )

    XCTAssertEqual(try locator.locate().path, bundledPath)
  }

  func testFindsDesktopAppsInstalledInUserApplications() throws {
    for application in ["Codex", "ChatGPT"] {
      let path = (
        "~/Applications/\(application).app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"
        as NSString
      ).expandingTildeInPath
      let locator = CodexBinaryLocator(environment: [:], isExecutable: { $0 == path })

      XCTAssertEqual(try locator.locate().path, path)
    }
  }

  func testOlderDesktopBundleLayoutRemainsSupported() throws {
    for application in ["Codex", "ChatGPT"] {
      let path = "/Applications/\(application).app/Contents/Resources/codex"
      let locator = CodexBinaryLocator(environment: [:], isExecutable: { $0 == path })

      XCTAssertEqual(try locator.locate().path, path)
    }
  }

  func testExplicitOverrideStillTakesPriorityOverBundledBinary() throws {
    let customPath = "/custom/codex"
    let bundledPath = "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"
    let locator = CodexBinaryLocator(
      environment: ["CODEX_METER_CODEX_PATH": customPath],
      isExecutable: { [customPath, bundledPath].contains($0) }
    )

    XCTAssertEqual(try locator.locate().path, customPath)
  }
}
