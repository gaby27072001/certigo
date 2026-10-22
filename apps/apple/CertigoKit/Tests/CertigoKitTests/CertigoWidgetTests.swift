import CertigoData
import CertigoDomain
import Foundation
import XCTest

final class CertigoWidgetTests: XCTestCase {
  private func date(_ value: String) throws -> Date {
    try XCTUnwrap(ISO8601DateFormatter().date(from: value))
  }

  private func snapshot(
    at now: Date,
    earned: Int? = 0,
    goal: Int? = 20,
    streak: Int? = 3,
    risk: Bool = false
  ) throws -> CertigoWidgetSnapshot {
    try CertigoWidgetSnapshot(
      updatedAt: now,
      validUntil: now.addingTimeInterval(60 * 60),
      studyDay: "2026-01-02",
      studyDayUtcOffsetMinutes: 0,
      totalXP: 120,
      streakDays: streak,
      dailyGoalXP: goal,
      dailyXPEarned: earned,
      activeTrackCode: "AZ-900",
      activeTrackTitle: "Azure Fundamentals",
      serverStreakRisk: risk,
      studyPlanDailyMinutes: 10,
      targetExamDate: nil,
      language: .english
    )
  }

  func testPhaseUsesOnlyFreshConfirmedSignalsAndServerRiskTakesPriority() throws {
    let now = try date("2026-01-02T10:00:00Z")
    XCTAssertEqual(try snapshot(at: now).phase(at: now), .readyToStart)
    XCTAssertEqual(try snapshot(at: now, earned: 5).phase(at: now), .inProgress)
    XCTAssertEqual(try snapshot(at: now, earned: 20).phase(at: now), .goalCompleted)
    XCTAssertEqual(
      try snapshot(at: now, earned: 20, risk: true).phase(at: now), .streakAtRisk)
    XCTAssertNil(try snapshot(at: now).phase(at: now.addingTimeInterval(60 * 60)))
    XCTAssertNil(
      try snapshot(at: now).phase(at: try date("2026-01-03T00:00:00Z")))
  }

  func testDailyGoalProgressIsBoundedAndUnknownRemainsUnknown() throws {
    let now = try date("2026-01-02T10:00:00Z")
    XCTAssertEqual(try snapshot(at: now, earned: 10).dailyGoalProgress, 0.5)
    XCTAssertEqual(try snapshot(at: now, earned: 30).dailyGoalProgress, 1)
    XCTAssertNil(try snapshot(at: now, earned: nil).dailyGoalProgress)
    XCTAssertNil(try snapshot(at: now, goal: nil).dailyGoalProgress)
  }

  func testSnapshotRejectsInvalidDateBoundsAndUnpairedTrack() throws {
    let now = try date("2026-01-02T10:00:00Z")
    XCTAssertThrowsError(
      try CertigoWidgetSnapshot(
        updatedAt: now,
        validUntil: now.addingTimeInterval(37 * 60 * 60),
        studyDay: "2026-01-02",
        studyDayUtcOffsetMinutes: 0,
        totalXP: 1,
        streakDays: nil,
        dailyGoalXP: nil,
        dailyXPEarned: nil,
        activeTrackCode: "AZ-900",
        activeTrackTitle: nil,
        serverStreakRisk: false,
        studyPlanDailyMinutes: nil,
        targetExamDate: nil,
        language: .english
      )
    )
    XCTAssertThrowsError(
      try CertigoWidgetSnapshot(
        updatedAt: now,
        validUntil: now.addingTimeInterval(60 * 60),
        studyDay: "2026-01-03",
        studyDayUtcOffsetMinutes: 0,
        totalXP: 1,
        streakDays: nil,
        dailyGoalXP: nil,
        dailyXPEarned: nil,
        activeTrackCode: nil,
        activeTrackTitle: nil,
        serverStreakRisk: false,
        studyPlanDailyMinutes: nil,
        targetExamDate: nil,
        language: .english
      )
    )
  }

  func testRouteAcceptsOnlyAllowlistedWidgetDestinations() throws {
    XCTAssertEqual(
      CertigoWidgetRoute(url: try XCTUnwrap(URL(string: "certigo://widget/learn"))), .learn)
    XCTAssertEqual(
      CertigoWidgetRoute(url: try XCTUnwrap(URL(string: "certigo://widget/review"))), .review)
    XCTAssertNil(CertigoWidgetRoute(url: try XCTUnwrap(URL(string: "certigo://widget/account"))))
    XCTAssertNil(
      CertigoWidgetRoute(url: try XCTUnwrap(URL(string: "certigo://widget/learn?token=x"))))
    XCTAssertNil(
      CertigoWidgetRoute(url: try XCTUnwrap(URL(string: "https://certigo.example/widget/learn"))))
    XCTAssertNil(
      CertigoWidgetRoute(url: try XCTUnwrap(URL(string: "certigo://widget/%6cearn"))))
  }

  func testSnapshotFactoryUsesOnlyCurrentServerRiskAndOmitsAccountIdentity() throws {
    let now = try date("2026-01-02T18:00:00Z")
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let profile = try decoder.decode(
      Profile.self,
      from: Data(
        """
        {
          "id": "private-account-id",
          "displayName": "Private learner",
          "xp": 240,
          "activeTrackId": "microsoft:azure-fundamentals",
          "streakDays": 4,
          "dailyGoalXp": 30,
          "dailyXpEarned": 18
        }
        """.utf8
      )
    )
    let track = try decoder.decode(
      Track.self,
      from: Data(
        """
        {
          "id": "microsoft:azure-fundamentals",
          "code": "AZ-900",
          "title": "Azure Fundamentals",
          "summary": "A track summary",
          "learningAvailable": true,
          "languages": ["en"]
        }
        """.utf8
      )
    )
    let plan = try decoder.decode(
      NotificationPlan.self,
      from: Data(
        """
        {
          "localDate": "2026-01-02",
          "notifications": [{
            "kind": "StreakDanger",
            "priority": "high",
            "scheduledUtc": "2026-01-02T20:00:00Z",
            "localHour": 20,
            "mascot": "owl",
            "title": "Study today",
            "body": "One practice session",
            "deeplink": "certigo://widget/learn",
            "dedupeKey": "streak-2026-01-02"
          }]
        }
        """.utf8
      )
    )
    let settings = NotificationSettings(
      enabled: true, utcOffsetMinutes: 0, quietHoursStart: 22, quietHoursEnd: 7,
      preferredHour: 18, maxPerDay: 2, streakAlerts: true, questAlerts: false,
      leagueAlerts: false
    )
    let studyPlan = try CertigoStudyPlanPreference(dailyMinutesGoal: 15)
    let snapshot = try CertigoWidgetSnapshot.make(
      profile: profile,
      tracks: [track],
      notificationPlan: plan,
      notificationSettings: settings,
      studyPlan: studyPlan,
      language: .french,
      now: now,
      deviceTimeZone: try XCTUnwrap(TimeZone(secondsFromGMT: 0))
    )

    XCTAssertEqual(snapshot.activeTrackCode, "AZ-900")
    XCTAssertEqual(snapshot.activeTrackTitle, "Azure Fundamentals")
    XCTAssertEqual(snapshot.studyPlanDailyMinutes, 15)
    XCTAssertEqual(snapshot.phase(at: now), .streakAtRisk)
    let serialized = String(decoding: try JSONEncoder().encode(snapshot), as: UTF8.self)
    XCTAssertFalse(serialized.contains("private-account-id"))
    XCTAssertFalse(serialized.contains("Private learner"))
    XCTAssertFalse(serialized.contains("dueReviews"))

    let stalePlan = try decoder.decode(
      NotificationPlan.self,
      from: Data(
        """
        {
          "localDate": "2026-01-01",
          "notifications": [{
            "kind": "StreakDanger",
            "priority": "high",
            "scheduledUtc": "2026-01-02T20:00:00Z",
            "localHour": 20,
            "mascot": "owl",
            "title": "Study today",
            "body": "One practice session",
            "deeplink": "certigo://widget/learn",
            "dedupeKey": "streak-2026-01-01"
          }]
        }
        """.utf8
      )
    )
    let staleRisk = try CertigoWidgetSnapshot.make(
      profile: profile,
      tracks: [track],
      notificationPlan: stalePlan,
      notificationSettings: settings,
      studyPlan: nil,
      language: .english,
      now: now,
      deviceTimeZone: try XCTUnwrap(TimeZone(secondsFromGMT: 0))
    )
    XCTAssertFalse(staleRisk.serverStreakRisk)
    XCTAssertEqual(staleRisk.phase(at: now), .inProgress)
  }

  func testCopyExistsForEverySupportedLanguageAndPhase() {
    for language in AppLanguage.allCases {
      let copy = CertigoWidgetCopy(language: language)
      for phase in CertigoWidgetPhase.allCases {
        XCTAssertFalse(copy.title(for: phase).isEmpty)
        XCTAssertFalse(copy.phaseName(phase).isEmpty)
      }
      XCTAssertFalse(copy.continueLearning.isEmpty)
      XCTAssertFalse(copy.streakLabel.isEmpty)
      XCTAssertFalse(copy.dailyGoalAccessibility(progress: 0.5).isEmpty)
      XCTAssertFalse(copy.dailyGoalAccessibility(progress: nil).isEmpty)
      XCTAssertFalse(copy.openCertigo.isEmpty)
      XCTAssertFalse(copy.noGoal.isEmpty)
      XCTAssertFalse(copy.galleryTitle.isEmpty)
      XCTAssertFalse(copy.simulatedLabel.isEmpty)
      XCTAssertFalse(copy.liveLabel.isEmpty)
      XCTAssertFalse(copy.sharingNotConfigured.isEmpty)
      XCTAssertFalse(copy.previewMode.isEmpty)
      XCTAssertFalse(copy.widgetGalleryNote.isEmpty)
      XCTAssertFalse(copy.widgetDataUnreadable.isEmpty)
      XCTAssertFalse(copy.widgetStorageError.isEmpty)
      XCTAssertFalse(copy.smallFamily.isEmpty)
      XCTAssertFalse(copy.mediumFamily.isEmpty)
      XCTAssertFalse(copy.circularFamily.isEmpty)
      XCTAssertFalse(copy.rectangularFamily.isEmpty)
    }
  }

  func testStoreWritesReadsClearsAndRejectsCorruptOrStaleSnapshots() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("CertigoWidget-\(UUID().uuidString)", isDirectory: true)
    defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: root)) }
    let file = root.appendingPathComponent("snapshot.json")
    let store = try CertigoWidgetStore(fileURL: file)
    let now = try date("2026-01-02T10:00:00Z")
    let value = try snapshot(at: now)

    try store.write(value, now: now)
    XCTAssertEqual(try store.read(now: now), value)
    try store.clear()
    XCTAssertNil(try store.read(now: now))

    try Data("not json".utf8).write(to: file)
    XCTAssertThrowsError(try store.read(now: now)) {
      XCTAssertEqual($0 as? CertigoWidgetStoreError, .corruptSnapshot)
    }

    try store.write(value, now: now)
    XCTAssertThrowsError(try store.read(now: now.addingTimeInterval(60 * 60))) {
      XCTAssertEqual($0 as? CertigoWidgetStoreError, .staleSnapshot)
    }
  }

  func testSharedOnlyStoreFailsClosedWhenAppGroupIsUnavailable() throws {
    let store = CertigoWidgetStore(
      appGroupIdentifier: "group.com.certigo.unprovisioned.\(UUID().uuidString)",
      sharedContainerOnly: true
    )
    XCTAssertEqual(store.location, .unavailable)
    XCTAssertThrowsError(try store.read()) {
      XCTAssertEqual($0 as? CertigoWidgetStoreError, .appGroupUnavailable)
    }
  }
}
