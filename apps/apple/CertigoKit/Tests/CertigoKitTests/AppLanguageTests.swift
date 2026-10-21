import CertigoDomain
import Foundation
import XCTest

final class AppLanguageTests: XCTestCase {
  func testExactlyEightCanonicalLanguagesAndAutonyms() throws {
    let expected: [(AppLanguage, String, String)] = [
      (.french, "fr", "Français"), (.english, "en", "English"),
      (.hindi, "hi", "हिन्दी"), (.chineseSimplified, "zh-Hans", "简体中文"),
      (.korean, "ko", "한국어"), (.spanish, "es", "Español"),
      (.italian, "it", "Italiano"), (.german, "de", "Deutsch"),
    ]
    XCTAssertEqual(AppLanguage.allCases, expected.map(\.0))
    for (language, code, name) in expected {
      XCTAssertEqual(language.rawValue, code)
      XCTAssertEqual(language.nativeDisplayName, name)
      XCTAssertEqual(language.locale.identifier, code)
      XCTAssertEqual(
        try JSONDecoder().decode(
          AppLanguage.self, from: JSONEncoder().encode(language)), language)
      for displayLanguage in AppLanguage.allCases {
        XCTAssertFalse(language.localizedDisplayName(in: displayLanguage).isEmpty)
      }
    }
    XCTAssertNotEqual(
      AppLanguage.german.localizedDisplayName(in: .french),
      AppLanguage.german.localizedDisplayName(in: .english))
  }

  func testPreferredLanguageResolutionHonorsRegionsScriptsAndPriority() {
    let variants: [(String, AppLanguage)] = [
      ("fr-FR", .french), ("fr-CA", .french), ("en-US", .english),
      ("en-GB", .english), ("hi-IN", .hindi), ("zh-CN", .chineseSimplified),
      ("zh-Hans", .chineseSimplified), ("zh-Hans-CN", .chineseSimplified),
      ("zh-SG", .chineseSimplified), ("ko-KR", .korean), ("es-ES", .spanish),
      ("es-419", .spanish), ("it-IT", .italian), ("de-DE", .german),
      ("FR_fr", .french), ("ZH_hans_CN", .chineseSimplified),
    ]
    for (identifier, expected) in variants {
      XCTAssertEqual(
        AppLanguage.resolved(fromPreferredLanguages: [identifier]), expected, identifier)
    }
    for language in AppLanguage.allCases {
      XCTAssertEqual(
        AppLanguage.resolved(fromPreferredLanguages: [language.rawValue]), language)
    }
    XCTAssertEqual(
      .resolved(fromPreferredLanguages: ["ja-JP", "de-DE", "fr-FR"]), AppLanguage.german)
    XCTAssertEqual(.resolved(fromPreferredLanguages: ["es-419", "en-US"]), AppLanguage.spanish)
    XCTAssertEqual(.resolved(fromPreferredLanguages: []), AppLanguage.english)
    XCTAssertEqual(.resolved(fromPreferredLanguages: ["", "ja-JP", "ar"]), AppLanguage.english)
    XCTAssertEqual(.resolved(fromPreferredLanguages: ["zh-Hant", "fr"]), AppLanguage.french)
    XCTAssertEqual(
      .resolved(fromPreferredLanguages: ["zh-TW", "zh-HK", "zh-MO"]), AppLanguage.english)
    XCTAssertEqual(.resolved(fromPreferredLanguages: ["zh-Hans-TW"]), AppLanguage.chineseSimplified)
  }

  func testPreferencePersistsEveryChoiceAndResolvesWithoutRestart() throws {
    let suite = "Certigo.AppLanguageTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    XCTAssertEqual(AppLanguagePreference.storageKey, "certigo" + ".app.interface-language.v1")
    XCTAssertEqual(AppLanguagePreference.load(from: defaults), .system)
    for language in AppLanguage.allCases {
      let preference = AppLanguagePreference.explicit(language)
      preference.save(to: defaults)
      XCTAssertEqual(defaults.string(forKey: AppLanguagePreference.storageKey), language.rawValue)
      let reloaded = AppLanguagePreference.load(from: try XCTUnwrap(UserDefaults(suiteName: suite)))
      XCTAssertEqual(reloaded, preference)
      XCTAssertEqual(reloaded.effectiveLanguage(fromPreferredLanguages: ["ja"]), language)
      XCTAssertEqual(
        try JSONDecoder().decode(
          AppLanguagePreference.self, from: JSONEncoder().encode(preference)), preference)
    }
    AppLanguagePreference.system.save(to: defaults)
    let preference = AppLanguagePreference.load(from: defaults)
    XCTAssertEqual(preference, .system)
    XCTAssertEqual(preference.effectiveLanguage(fromPreferredLanguages: ["hi-IN"]), .hindi)
    XCTAssertEqual(preference.effectiveLanguage(fromPreferredLanguages: ["ko-KR"]), .korean)
    XCTAssertEqual(preference.effectiveLanguage(fromPreferredLanguages: ["ja-JP"]), .english)
    XCTAssertEqual(AppLanguagePreference(rawValue: "system"), .system)
    XCTAssertNil(AppLanguagePreference(rawValue: "unsupported"))
    defaults.set("unsupported", forKey: AppLanguagePreference.storageKey)
    XCTAssertEqual(AppLanguagePreference.load(from: defaults), .system)
    XCTAssertEqual(
      try JSONDecoder().decode(
        AppLanguagePreference.self, from: JSONEncoder().encode(AppLanguagePreference.system)),
      .system)
    XCTAssertThrowsError(
      try JSONDecoder().decode(AppLanguagePreference.self, from: Data("\"unsupported\"".utf8)))
  }

  func testEveryCopyKeyIsPresentInEveryLanguageAndStatusRemainsDistinct() {
    for language in AppLanguage.allCases {
      let copy = AppInterfaceCopy(language: language)
      XCTAssertEqual(copy, AppInterfaceCopy(language: language))
      for key in AppInterfaceCopy.Key.allCases {
        XCTAssertFalse(
          copy[key].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          "\(language.rawValue): \(key)")
      }
      XCTAssertNotEqual(copy.pending, copy.confirmed)
      XCTAssertNotEqual(copy[.practiceAvailable], copy[.practiceUnavailable])
      XCTAssertNotEqual(copy[.practiceUnavailableNote], copy[.practiceUnavailable])
      XCTAssertNotEqual(copy[.pendingCorrection], copy.confirmed)
      XCTAssertEqual(copy.learn, copy[.learn])
      XCTAssertEqual(copy.coach, copy[.coach])
      XCTAssertEqual(copy.social, copy[.social])
      XCTAssertEqual(copy.profile, copy[.profile])
      XCTAssertEqual(copy.myLearning, copy[.myLearning])
      XCTAssertEqual(copy.explore, copy[.explore])
      XCTAssertEqual(copy.friends, copy[.friends])
      XCTAssertEqual(copy.teams, copy[.teams])
      XCTAssertEqual(copy.appLanguage, copy[.appLanguage])
      XCTAssertEqual(copy.systemDefault, copy[.systemDefault])
      XCTAssertEqual(copy.signInWithMicrosoft, copy[.signInWithMicrosoft])
      XCTAssertEqual(copy.exploreDemo, copy[.exploreDemo])
      XCTAssertEqual(copy.resume, copy[.resume])
      XCTAssertEqual(copy.startSession, copy[.startSession])
      XCTAssertEqual(copy.practiceAgain, copy[.practiceAgain])
      XCTAssertEqual(copy.submitAnswer, copy[.submitAnswer])
      XCTAssertEqual(copy.retry, copy[.retry])
      XCTAssertEqual(copy.loading, copy[.loading])
      XCTAssertEqual(copy.progressAndHistory, copy[.progressAndHistory])
      XCTAssertEqual(copy.settings, copy[.settings])
      XCTAssertEqual(copy.accountDeletion, copy[.accountDeletion])
      XCTAssertEqual(copy.pending, copy[.pending])
      XCTAssertEqual(copy.confirmed, copy[.confirmed])
    }
    XCTAssertEqual(AppInterfaceCopy(language: .english).learn, "Learn")
    XCTAssertEqual(AppInterfaceCopy(language: .french).learn, "Apprendre")
  }

  func testContentNoteExplicitlySeparatesInterfaceFromUntranslatedSource() {
    let expectations: [(AppLanguage, String, String, String)] = [
      (
        .french, "questions de certification", "pilote éditorial",
        "n’est pas traduit automatiquement"
      ),
      (.english, "certification questions", "editorial pilot", "not automatically translated"),
      (.hindi, "प्रमाणन प्रश्नों", "संपादकीय पायलट", "स्वचालित अनुवाद नहीं होता"),
      (.chineseSimplified, "认证题目", "编辑试点", "不会自动翻译"),
      (.korean, "인증 시험 문제", "편집 파일럿", "자동 번역되지 않습니다"),
      (.spanish, "preguntas de certificación", "piloto editorial", "no se traduce automáticamente"),
      (
        .italian, "domande di certificazione", "pilota editoriale",
        "non viene tradotto automaticamente"
      ),
      (.german, "Zertifizierungsfragen", "Pilotprojekts", "nicht automatisch übersetzt"),
    ]
    XCTAssertEqual(expectations.count, AppLanguage.allCases.count)
    for (language, certification, pilot, noTranslation) in expectations {
      let copy = AppInterfaceCopy(language: language)
      XCTAssertEqual(copy.contentLanguageNote, copy[.contentLanguageNote])
      XCTAssertTrue(copy.contentLanguageNote.contains(certification), language.rawValue)
      XCTAssertTrue(copy.contentLanguageNote.contains(pilot), language.rawValue)
      XCTAssertTrue(copy.contentLanguageNote.contains(noTranslation), language.rawValue)
    }
  }
}
