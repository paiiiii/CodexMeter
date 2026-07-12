import Foundation
import XCTest

@testable import CodexMeterKit

@MainActor
final class LanguagePreferenceTests: XCTestCase {
  func testDefaultsToSystemAndInvalidStoredValueFallsBackToSystem() {
    let (defaults, suiteName) = makeDefaults()
    defer { defaults.removePersistentDomain(forName: suiteName) }

    var controller = LanguageController(
      defaults: defaults,
      preferredLanguages: { ["en-US"] },
      notificationCenter: NotificationCenter()
    )
    XCTAssertEqual(controller.language, .system)
    XCTAssertEqual(controller.resolvedLocale.language.languageCode?.identifier, "en")

    defaults.set("unsupported", forKey: LanguageController.preferenceKey)
    controller = LanguageController(
      defaults: defaults,
      preferredLanguages: { ["en-US"] },
      notificationCenter: NotificationCenter()
    )
    XCTAssertEqual(controller.language, .system)
  }

  func testEveryPreferencePersistsAndRestores() {
    for language in AppLanguage.allCases {
      let (defaults, suiteName) = makeDefaults()
      defer { defaults.removePersistentDomain(forName: suiteName) }

      let controller = LanguageController(
        defaults: defaults,
        notificationCenter: NotificationCenter()
      )
      controller.language = language

      let restored = LanguageController(
        defaults: defaults,
        notificationCenter: NotificationCenter()
      )
      XCTAssertEqual(restored.language, language)
    }
  }

  func testManualLanguageOverridesSystemPreferenceImmediately() {
    let (defaults, suiteName) = makeDefaults()
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let controller = LanguageController(
      defaults: defaults,
      preferredLanguages: { ["zh-Hans-CN"] },
      notificationCenter: NotificationCenter()
    )
    XCTAssertEqual(controller.resolvedLocale.language.languageCode?.identifier, "zh")

    controller.language = .english
    XCTAssertEqual(controller.resolvedLocale.language.languageCode?.identifier, "en")

    controller.language = .simplifiedChinese
    XCTAssertEqual(controller.resolvedLocale.language.languageCode?.identifier, "zh")
  }

  func testSystemPreferenceResolvesSupportedLanguagesAndFallsBackToEnglish() {
    XCTAssertEqual(
      SupportedAppLanguage.resolve(preferredLanguages: ["zh-Hans-CN"]),
      .simplifiedChinese
    )
    XCTAssertEqual(
      SupportedAppLanguage.resolve(preferredLanguages: ["zh_CN"]),
      .simplifiedChinese
    )
    XCTAssertEqual(
      SupportedAppLanguage.resolve(preferredLanguages: ["zh-Hant-TW"]),
      .simplifiedChinese
    )
    XCTAssertEqual(
      SupportedAppLanguage.resolve(preferredLanguages: ["fr-FR", "en-GB"]),
      .english
    )
    XCTAssertEqual(
      SupportedAppLanguage.resolve(preferredLanguages: ["fr-FR"]),
      .english
    )
  }

  func testSystemLanguageNotificationReevaluatesWithoutRestart() async {
    let (defaults, suiteName) = makeDefaults()
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let center = NotificationCenter()
    var preferredLanguages = ["en-US"]
    let controller = LanguageController(
      defaults: defaults,
      preferredLanguages: { preferredLanguages },
      notificationCenter: center
    )
    XCTAssertEqual(controller.localizer.language, .english)

    preferredLanguages = ["zh-Hans-CN"]
    await Task.detached {
      center.post(name: NSLocale.currentLocaleDidChangeNotification, object: nil)
    }.value
    for _ in 0..<10 where controller.systemLanguageRevision == 0 {
      await Task.yield()
    }

    XCTAssertEqual(controller.localizer.language, .simplifiedChinese)
    XCTAssertEqual(controller.systemLanguageRevision, 1)
  }

  private func makeDefaults() -> (UserDefaults, String) {
    let suiteName = "CodexMeterTests.Language.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return (defaults, suiteName)
  }
}
