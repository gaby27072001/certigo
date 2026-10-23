import CertigoData
import CertigoDomain
import Foundation
import XCTest

final class AppIconSelectionTests: XCTestCase {
  func testAutomaticSelectionUsesConfirmedWidgetPhaseAndStreak() {
    let automatic = CertigoAppIconPreferences()
    XCTAssertEqual(automatic.variant(for: .readyToStart, streakDays: 0), .standard)
    XCTAssertEqual(automatic.variant(for: .inProgress, streakDays: 4), .streakFire)
    XCTAssertEqual(automatic.variant(for: .streakAtRisk, streakDays: 4), .streakAtRisk)
    XCTAssertEqual(automatic.variant(for: .goalCompleted, streakDays: 6), .streakFire)
    XCTAssertEqual(automatic.variant(for: .goalCompleted, streakDays: 7), .masteryGold)
    XCTAssertEqual(automatic.variant(for: nil, streakDays: nil), .standard)
  }

  func testManualSelectionDoesNotFollowAutomaticSignals() {
    let manual = CertigoAppIconPreferences(mode: .manual, manualVariant: .masteryGold)
    XCTAssertEqual(manual.variant(for: .streakAtRisk, streakDays: 1), .masteryGold)
  }

  func testAlternateIconApplicationRequiresSupportForegroundAndAChangedName() {
    XCTAssertTrue(
      CertigoAppIconVariant.streakFire.shouldApply(
        supportsAlternateIcons: true,
        applicationIsActive: true,
        currentAlternateIconName: nil
      )
    )
    XCTAssertFalse(
      CertigoAppIconVariant.streakFire.shouldApply(
        supportsAlternateIcons: false,
        applicationIsActive: true,
        currentAlternateIconName: nil
      )
    )
    XCTAssertFalse(
      CertigoAppIconVariant.streakFire.shouldApply(
        supportsAlternateIcons: true,
        applicationIsActive: false,
        currentAlternateIconName: nil
      )
    )
    XCTAssertFalse(
      CertigoAppIconVariant.streakFire.shouldApply(
        supportsAlternateIcons: true,
        applicationIsActive: true,
        currentAlternateIconName: "CertigoIconStreakFire"
      )
    )
    XCTAssertTrue(
      CertigoAppIconVariant.standard.shouldApply(
        supportsAlternateIcons: true,
        applicationIsActive: true,
        currentAlternateIconName: "CertigoIconStreakFire"
      )
    )
  }

  func testPreferenceStorePersistsAndPurgesSelection() throws {
    let suiteName = "CertigoAppIconPreferenceStoreTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = CertigoAppIconPreferenceStore(
      defaults: defaults,
      key: "app-icon-preferences"
    )
    let selection = CertigoAppIconPreferences(mode: .manual, manualVariant: .streakFire)

    try store.save(selection)
    XCTAssertEqual(try store.load(), selection)
    store.reset()
    XCTAssertNil(try store.load())
  }
}
