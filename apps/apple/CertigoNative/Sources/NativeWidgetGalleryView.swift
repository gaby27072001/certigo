#if canImport(SwiftUI) && canImport(WidgetKit)
import CertigoData
import CertigoDomain
import Observation
import SwiftUI
import WidgetKit

struct NativeWidgetGalleryView: View {
  let liveSnapshot: CertigoWidgetSnapshot?
  let storeLocation: CertigoWidgetStoreLocation
  let storeError: CertigoWidgetStoreError?
  let language: AppLanguage

  @State private var selectedPhase: CertigoWidgetPhase = .readyToStart
  @State private var selectedFamily: WidgetFamily = .systemSmall
  @State private var showsSimulation = true

  private var copy: CertigoWidgetCopy { CertigoWidgetCopy(language: language) }

  private var previewEntry: CertigoWidgetEntry {
    if showsSimulation {
      return Self.simulatedEntry(for: selectedPhase, language: language)
    }
    guard let liveSnapshot, liveSnapshot.phase(at: .now) != nil else {
      return CertigoWidgetEntry(
        date: .now, snapshot: nil,
        status: storeLocation == .unavailable ? .sharedContainerUnavailable : .empty)
    }
    return CertigoWidgetEntry(date: .now, snapshot: liveSnapshot, status: .available)
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Picker(copy.previewMode, selection: $showsSimulation) {
            Text(copy.simulatedLabel).tag(true)
            Text(copy.liveLabel).tag(false)
          }
          .pickerStyle(.segmented)

          if showsSimulation {
            Text(copy.simulatedLabel)
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
          } else if storeLocation != .appGroup {
            Label(copy.sharingNotConfigured, systemImage: "info.circle")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }

          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(CertigoWidgetPhase.allCases, id: \.self) { phase in
              Button {
                selectedPhase = phase
              } label: {
                HStack(spacing: 7) {
                  Circle()
                    .fill(phase == selectedPhase ? NativeWidgetGalleryPalette.accent : .clear)
                    .frame(width: 9, height: 9)
                    .overlay(Circle().stroke(.secondary.opacity(0.5), lineWidth: 1))
                  Text(copy.phaseName(phase))
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
                .background(
                  phase == selectedPhase
                    ? NativeWidgetGalleryPalette.accent.opacity(0.12)
                    : Color.secondary.opacity(0.07),
                  in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )
              }
              .buttonStyle(.plain)
              .accessibilityAddTraits(phase == selectedPhase ? .isSelected : [])
            }
          }

          ScrollView(.horizontal) {
            HStack(spacing: 8) {
              familyButton(.systemSmall, title: copy.smallFamily)
              familyButton(.systemMedium, title: copy.mediumFamily)
              familyButton(.accessoryCircular, title: copy.circularFamily)
              familyButton(.accessoryRectangular, title: copy.rectangularFamily)
            }
          }
          .scrollIndicators(.hidden)

          CertigoWidgetCardView(entry: previewEntry, family: selectedFamily)
            .frame(
              width: previewWidth,
              height: selectedFamily == .systemSmall ? 170 : 112
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("certigo-widget-preview")

          if let storeError {
            Label(errorDescription(storeError), systemImage: "exclamationmark.triangle")
              .font(.footnote)
              .foregroundStyle(.orange)
          }

          Text(copy.widgetGalleryNote)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(20)
      }
      .navigationTitle(copy.galleryTitle)
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  private var previewWidth: CGFloat {
    selectedFamily == .systemSmall || selectedFamily == .accessoryCircular ? 170 : 340
  }

  private func familyButton(_ family: WidgetFamily, title: String) -> some View {
    Button {
      selectedFamily = family
    } label: {
      Text(title)
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(
          selectedFamily == family
            ? NativeWidgetGalleryPalette.accent.opacity(0.15)
            : Color.secondary.opacity(0.08),
          in: Capsule()
        )
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selectedFamily == family ? .isSelected : [])
  }

  private func errorDescription(_ error: CertigoWidgetStoreError) -> String {
    switch error {
    case .appGroupUnavailable: copy.sharingNotConfigured
    case .staleSnapshot: copy.openCertigo
    case .corruptSnapshot: copy.widgetDataUnreadable
    case .oversizedSnapshot, .invalidPath, .storageUnavailable, .protectionPolicy:
      copy.widgetStorageError
    }
  }

  private static func simulatedEntry(
    for phase: CertigoWidgetPhase, language: AppLanguage, now: Date = .now
  ) -> CertigoWidgetEntry {
    let offset = TimeZone.autoupdatingCurrent.secondsFromGMT(for: now) / 60
    guard let timeZone = TimeZone(secondsFromGMT: offset) else {
      return CertigoWidgetEntry(date: now, snapshot: nil, status: .unreadable)
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    guard let day = CertigoWidgetSnapshot.studyDayKey(at: now, utcOffsetMinutes: offset),
      let validUntil = calendar.date(
        byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
    else {
      return CertigoWidgetEntry(date: now, snapshot: nil, status: .unreadable)
    }
    let earned: Int
    let risk: Bool
    switch phase {
    case .readyToStart: earned = 0; risk = false
    case .inProgress: earned = 18; risk = false
    case .streakAtRisk: earned = 0; risk = true
    case .goalCompleted: earned = 30; risk = false
    }
    guard let snapshot = try? CertigoWidgetSnapshot(
      updatedAt: now,
      validUntil: validUntil,
      studyDay: day,
      studyDayUtcOffsetMinutes: offset,
      totalXP: 240,
      streakDays: 4,
      dailyGoalXP: 30,
      dailyXPEarned: earned,
      activeTrackCode: "DEMO",
      activeTrackTitle: "Certigo preview",
      serverStreakRisk: risk,
      studyPlanDailyMinutes: 10,
      targetExamDate: nil,
      language: language
    ) else {
      return CertigoWidgetEntry(date: now, snapshot: nil, status: .unreadable)
    }
    return CertigoWidgetEntry(date: now, snapshot: snapshot, status: .available)
  }
}

private enum NativeWidgetGalleryPalette {
  static let accent = Color(red: 0.12, green: 0.48, blue: 0.91)
}

@MainActor @Observable
final class NativeWidgetSnapshotController {
  private(set) var snapshot: CertigoWidgetSnapshot?
  private(set) var error: CertigoWidgetStoreError?

  let store: CertigoWidgetStore
  private let reloadTimelines: () -> Void

  init(
    store: CertigoWidgetStore = CertigoWidgetStore(),
    reloadTimelines: @escaping () -> Void = { WidgetCenter.shared.reloadAllTimelines() }
  ) {
    self.store = store
    self.reloadTimelines = reloadTimelines
  }

  func refresh(
    profile: Profile?,
    tracks: [Track],
    notificationPlan: NotificationPlan?,
    notificationSettings: NotificationSettings?,
    studyPlan: CertigoStudyPlanPreference?,
    language: AppLanguage,
    now: Date
  ) {
    guard let profile else {
      clear()
      return
    }
    do {
      let value = try CertigoWidgetSnapshot.make(
        profile: profile,
        tracks: tracks,
        notificationPlan: notificationPlan,
        notificationSettings: notificationSettings,
        studyPlan: studyPlan,
        language: language,
        now: now
      )
      try store.write(value, now: now)
      snapshot = value
      error = nil
    } catch let storeError as CertigoWidgetStoreError {
      clearAfterRefreshFailure(reporting: storeError)
    } catch let snapshotError as CertigoWidgetSnapshotError {
      clearAfterRefreshFailure(
        reporting: snapshotError == .stale ? .staleSnapshot : .corruptSnapshot)
    } catch {
      clearAfterRefreshFailure(reporting: .storageUnavailable)
    }
    reloadTimelines()
  }

  private func clearAfterRefreshFailure(reporting failure: CertigoWidgetStoreError) {
    snapshot = nil
    do {
      try store.clear()
      error = failure
    } catch let clearError as CertigoWidgetStoreError {
      error = clearError
    } catch {
      error = .storageUnavailable
    }
  }

  func clear() {
    snapshot = nil
    do {
      try store.clear()
      error = nil
    } catch let storeError as CertigoWidgetStoreError {
      error = storeError
    } catch {
      error = .storageUnavailable
    }
    reloadTimelines()
  }
}

struct NativeWidgetSnapshotKey: Equatable {
  let profileID: String?
  let totalXP: Int?
  let streakDays: Int?
  let dailyGoalXP: Int?
  let dailyXPEarned: Int?
  let activeTrackID: String?
  let activeTrackCode: String?
  let activeTrackTitle: String?
  let notificationDate: String?
  let notificationItems: [String]
  let notificationOffset: Int?
  let studyMinutes: Int?
  let targetExamDate: Date?
  let language: AppLanguage

  init(
    profile: Profile?,
    tracks: [Track],
    notificationPlan: NotificationPlan?,
    notificationSettings: NotificationSettings?,
    studyPlan: CertigoStudyPlanPreference?,
    language: AppLanguage
  ) {
    let activeTrack = profile?.activeTrackId.flatMap { activeID in
      tracks.first { $0.id.caseInsensitiveCompare(activeID) == .orderedSame }
    }
    self.profileID = profile?.id
    self.totalXP = profile?.xp
    self.streakDays = profile?.streakDays
    self.dailyGoalXP = profile?.dailyGoalXp
    self.dailyXPEarned = profile?.dailyXpEarned
    self.activeTrackID = profile?.activeTrackId
    self.activeTrackCode = activeTrack?.code
    self.activeTrackTitle = activeTrack?.title
    self.notificationDate = notificationPlan?.localDate
    self.notificationItems = notificationPlan?.notifications.map {
      "\($0.kind):\($0.scheduledUtc.timeIntervalSince1970)"
    }.sorted() ?? []
    self.notificationOffset = notificationSettings?.utcOffsetMinutes
    self.studyMinutes = studyPlan?.dailyMinutesGoal
    self.targetExamDate = studyPlan?.targetExamDate
    self.language = language
  }
}
#endif
