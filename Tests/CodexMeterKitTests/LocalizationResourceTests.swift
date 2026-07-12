import Foundation
import XCTest

@testable import CodexMeterKit

final class LocalizationResourceTests: XCTestCase {
  func testEnglishAndSimplifiedChineseResourcesContainEveryKey() throws {
    let bundle = CodexMeterResources.bundle
    XCTAssertEqual(bundle.developmentLocalization, "en")
    XCTAssertTrue(bundle.localizations.contains("en"))
    XCTAssertTrue(bundle.localizations.map { $0.lowercased() }.contains("zh-hans"))
    XCTAssertNotNil(bundle.url(forResource: "en", withExtension: "lproj"))
    XCTAssertNotNil(bundle.url(forResource: "zh-hans", withExtension: "lproj"))

    for language in SupportedAppLanguage.allCases {
      let localizer = AppLocalizer(language: language)
      for key in L10nKey.allCases {
        let value = localizer.string(key)
        XCTAssertFalse(value.isEmpty, "Empty \(language.rawValue) value for \(key.rawValue)")
        XCTAssertNotEqual(
          value,
          key.rawValue,
          "Missing \(language.rawValue) value for \(key.rawValue)"
        )
      }
    }
  }

  func testCoreCopyAndModeTitlesDifferByLanguage() {
    let english = AppLocalizer(language: .english)
    let chinese = AppLocalizer(language: .simplifiedChinese)

    XCTAssertEqual(english.string(.languageSystem), "System Default")
    XCTAssertEqual(chinese.string(.languageSystem), "跟随系统")
    XCTAssertEqual(english.string(.widgetStatusLive), "Live")
    XCTAssertEqual(chinese.string(.widgetStatusLive), "实时")
    XCTAssertEqual(
      WidgetPresentationMode.floating.localizedTitle(using: english),
      "Always on Top"
    )
    XCTAssertEqual(
      WidgetPresentationMode.floating.localizedTitle(using: chinese),
      "始终置顶"
    )
  }

  func testFormatPlaceholdersMatchAcrossSupportedLanguages() throws {
    let english = AppLocalizer(language: .english)
    let chinese = AppLocalizer(language: .simplifiedChinese)
    let expression = try NSRegularExpression(pattern: #"%\d*[@d]"#)

    for key in L10nKey.allCases {
      let englishPlaceholders = placeholders(
        in: english.string(key),
        matching: expression
      )
      let chinesePlaceholders = placeholders(
        in: chinese.string(key),
        matching: expression
      )
      XCTAssertEqual(
        englishPlaceholders.sorted(),
        chinesePlaceholders.sorted(),
        "Placeholder mismatch for \(key.rawValue)"
      )
    }
  }

  func testCodexErrorsLocalizeWithoutChangingTheUnderlyingError() {
    let english = AppLocalizer(language: .english)
    let chinese = AppLocalizer(language: .simplifiedChinese)
    let error = CodexAppServerError.connectionClosed(17)

    XCTAssertEqual(
      error.localizedDescription(using: english),
      "The Codex app-server exited with status 17."
    )
    XCTAssertEqual(
      error.localizedDescription(using: chinese),
      "Codex app-server 已退出（状态 17）。"
    )
    XCTAssertEqual(
      CodexAppServerError.unknownRPC.localizedDescription(using: english),
      "Codex app-server: Unknown RPC error"
    )
  }

  private func placeholders(
    in value: String,
    matching expression: NSRegularExpression
  ) -> [String] {
    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    return expression.matches(in: value, range: range).compactMap { match in
      Range(match.range, in: value).map { String(value[$0]) }
    }
  }
}

private actor FailingUsageProvider: UsageProviding {
  func fetchUsage() async throws -> UsageSnapshot {
    throw CodexAppServerError.binaryNotFound
  }
}

@MainActor
final class LocalizedErrorStateTests: XCTestCase {
  func testExistingUsageErrorRelocalizesImmediately() async {
    let suiteName = "CodexMeterTests.Error.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let languageController = LanguageController(
      defaults: defaults,
      preferredLanguages: { ["en-US"] },
      notificationCenter: NotificationCenter()
    )
    let store = UsageStore(
      provider: FailingUsageProvider(),
      languageController: languageController,
      defaults: defaults
    )

    await store.refresh()
    XCTAssertEqual(
      store.lastErrorDescription,
      "Codex could not be found. Install and sign in to the Codex or ChatGPT desktop app, or set CODEX_METER_CODEX_PATH."
    )

    languageController.language = .simplifiedChinese
    XCTAssertEqual(
      store.lastErrorDescription,
      "找不到 Codex。请安装并登录 Codex/ChatGPT 桌面应用，或设置 CODEX_METER_CODEX_PATH。"
    )
  }
}
