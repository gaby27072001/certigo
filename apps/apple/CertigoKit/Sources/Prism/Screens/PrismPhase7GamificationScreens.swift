import BrandAssets
import CertigoDomain
import Foundation

// MARK: - 1. Weekly Rhythm Planner & Free Catch-Up (S-12, S-75, §7, §9, DR-005)

public struct WeeklyRhythmPlannerModel: Codable, Equatable, Hashable, Sendable {
    public static let minGoalDaysPerWeek: Int = 3
    public static let maxGoalDaysPerWeek: Int = 6
    public static let minimumRestDaysPerWeek: Int = 2
    public static let maxPauseWeeks: Int = 4
    public static let freeCatchUpRequiredRecalls: Int = 3
    public static let learningRuleCitation =
        "Effet d'espacement distribué (Distributed Practice & Consolidation) : 3 à 6 jours actifs avec repos intégré et rattrapage gratuit par 3 rappels différés."

    public var targetDaysPerWeek: Int
    public var completedDaysThisWeek: Int
    public var bestRhythmWeeks: Int
    public var pauseWeeksRemaining: Int
    public var completedCatchUpRecalls: Int
    public var dailyStreakDays: Int
    public var dailyStreakEnabled: Bool
    public var days: [PrismRhythmDayItem]

    public init(
        targetDaysPerWeek: Int = 4,
        completedDaysThisWeek: Int = 2,
        bestRhythmWeeks: Int = 5,
        pauseWeeksRemaining: Int = 0,
        completedCatchUpRecalls: Int = 0,
        dailyStreakDays: Int = 5,
        dailyStreakEnabled: Bool = true,
        days: [PrismRhythmDayItem]
    ) {
        self.targetDaysPerWeek = min(max(targetDaysPerWeek, Self.minGoalDaysPerWeek), Self.maxGoalDaysPerWeek)
        self.completedDaysThisWeek = min(max(completedDaysThisWeek, 0), 7)
        self.bestRhythmWeeks = max(0, bestRhythmWeeks)
        self.pauseWeeksRemaining = min(max(pauseWeeksRemaining, 0), Self.maxPauseWeeks)
        self.completedCatchUpRecalls = max(0, completedCatchUpRecalls)
        self.dailyStreakDays = max(0, dailyStreakDays)
        self.dailyStreakEnabled = dailyStreakEnabled
        self.days = days
    }

    public var restDaysPerWeek: Int {
        max(Self.minimumRestDaysPerWeek, 7 - targetDaysPerWeek)
    }

    public var isPaused: Bool {
        pauseWeeksRemaining > 0
    }

    public var canRedeemFreeCatchUp: Bool {
        completedCatchUpRecalls >= Self.freeCatchUpRequiredRecalls
    }

    /// §9: Free catch-up is earned by completing 3 delayed recalls (never paid with gems/currency).
    public mutating func applyFreeCatchUpIfEligible() -> Bool {
        guard canRedeemFreeCatchUp else { return false }
        completedCatchUpRecalls -= Self.freeCatchUpRequiredRecalls
        completedDaysThisWeek = min(7, completedDaysThisWeek + 1)
        return true
    }

    public mutating func configurePause(weeks: Int) {
        pauseWeeksRemaining = min(max(weeks, 0), Self.maxPauseWeeks)
    }

    public var rhythmWeekViewModel: PrismRhythmWeekModel {
        PrismRhythmWeekModel(
            weeklyGoalDays: targetDaysPerWeek,
            days: days,
            bestRhythmWeeks: bestRhythmWeeks,
            dailyStreakOptIn: dailyStreakEnabled,
            dailyStreakDays: dailyStreakEnabled ? dailyStreakDays : nil
        )
    }
}

public struct WelcomeBackBannerModel: Codable, Equatable, Hashable, Sendable {
    public let awayDaysCount: Int
    public let headline: String
    public let supportiveMessage: String
    public let suggestedLength: PrismSessionLength

    public init(
        awayDaysCount: Int,
        headline: String = "Bon retour parmi nous",
        supportiveMessage: String = "Ton Atlas t'attend : reprends en douceur avec une séance Express de 5 minutes.",
        suggestedLength: PrismSessionLength = .express
    ) {
        self.awayDaysCount = max(1, awayDaysCount)
        self.headline = headline
        self.supportiveMessage = supportiveMessage
        self.suggestedLength = suggestedLength
    }

    /// §7 & §16.7: Never use loss/guilt language in Welcome Back state.
    public var containsGuiltOrLossCopy: Bool {
        let lower = "\(headline) \(supportiveMessage)".lowercased()
        let forbidden = ["perdu", "cassé", "éteinte", "dommage", "coupable", "retard"]
        return forbidden.contains { lower.contains($0) }
    }
}

// MARK: - 2. Mastery Milestones (§9, `celebrations.v1`)

public enum MasteryMilestoneKind: String, Codable, CaseIterable, Equatable, Hashable, Sendable, Identifiable {
    case firstMasteredConcept
    case completeTerritory
    case mockExamEightyPercent
    case tenMisconceptionsResolved
    case labHandoffReached

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .firstMasteredConcept: "Premier concept Maîtrisé"
        case .completeTerritory: "Territoire complet ancré"
        case .mockExamEightyPercent: "Examen blanc ≥ 80 %"
        case .tenMisconceptionsResolved: "10 fausses idées corrigées"
        case .labHandoffReached: "Passage au lab pratique"
        }
    }

    public var learningRuleCitation: String {
        switch self {
        case .firstMasteredConcept:
            "Rétroaction de compétence : valide la maîtrise vérifiée d'un concept sur les 5 échelons."
        case .completeTerritory:
            "Structuration de schéma cognitif : cohérence complète d'un domaine technique."
        case .mockExamEightyPercent:
            "Transfert en conditions d'épreuve et calibration métacognitive."
        case .tenMisconceptionsResolved:
            "Changement conceptuel : remplacement durable des modèles mentaux erronés."
        case .labHandoffReached:
            "Transfert procédural hors téléphone dans un environnement réel."
        }
    }

    public var celebrationLevel: PrismCelebrationLevel {
        switch self {
        case .firstMasteredConcept, .tenMisconceptionsResolved:
            .refraction
        case .completeTerritory, .mockExamEightyPercent, .labHandoffReached:
            .milestone
        }
    }
}

public struct MasteryMilestoneItem: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id: String { kind.rawValue }
    public let kind: MasteryMilestoneKind
    public let isUnlocked: Bool
    public let progressCurrent: Int
    public let progressTarget: Int

    public init(
        kind: MasteryMilestoneKind,
        isUnlocked: Bool,
        progressCurrent: Int,
        progressTarget: Int
    ) {
        self.kind = kind
        self.isUnlocked = isUnlocked
        self.progressTarget = max(1, progressTarget)
        self.progressCurrent = min(max(0, progressCurrent), max(1, progressTarget))
    }

    public var progressRatio: Double {
        Double(progressCurrent) / Double(progressTarget)
    }
}

// MARK: - 3. Weekly Missions (`<= 3`, 1 Cooperative Squad Mission — §9, `missions.v1`)

public struct WeeklyMissionItem: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let skillFocus: String
    public let learningRuleCitation: String
    public let isCooperativeSquadMission: Bool
    public let currentCount: Int
    public let targetCount: Int

    public init(
        id: String,
        title: String,
        skillFocus: String,
        learningRuleCitation: String,
        isCooperativeSquadMission: Bool = false,
        currentCount: Int,
        targetCount: Int
    ) {
        self.id = id
        self.title = title
        self.skillFocus = skillFocus
        self.learningRuleCitation = learningRuleCitation
        self.isCooperativeSquadMission = isCooperativeSquadMission
        self.targetCount = max(1, targetCount)
        self.currentCount = min(max(0, currentCount), max(1, targetCount))
    }

    public var isCompleted: Bool {
        currentCount >= targetCount
    }

    public var progressRatio: Double {
        Double(currentCount) / Double(targetCount)
    }
}

public struct WeeklyMissionBoardModel: Codable, Equatable, Hashable, Sendable {
    public static let maxMissionsPerWeek: Int = 3

    public let weekLabel: String
    public let missions: [WeeklyMissionItem]

    public init(weekLabel: String, missions: [WeeklyMissionItem]) {
        self.weekLabel = weekLabel
        self.missions = Array(missions.prefix(Self.maxMissionsPerWeek))
    }

    public var cooperativeSquadMissionsCount: Int {
        missions.filter(\.isCooperativeSquadMission).count
    }
}

// MARK: - 4. Cooperative Seasonal Highlights (`<= 4 / year`, no battle pass — §9, `events.v1`)

public struct CooperativeEventBannerModel: Codable, Equatable, Hashable, Sendable, Identifiable {
    public static let maxEventsPerYear: Int = 4

    public let id: String
    public let title: String
    public let subtitle: String
    public let region: PrismRegion
    public let communityAnchoredCount: Int
    public let communityTargetCount: Int

    public init(
        id: String,
        title: String,
        subtitle: String,
        region: PrismRegion,
        communityAnchoredCount: Int,
        communityTargetCount: Int
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.region = region
        self.communityTargetCount = max(1, communityTargetCount)
        self.communityAnchoredCount = min(max(0, communityAnchoredCount), max(1, communityTargetCount))
    }

    /// §9: Never includes a battle pass, paid tier, or currency.
    public var hasBattlePassOrPaidTier: Bool {
        false
    }
}

// MARK: - 5. Legacy Volume Gamification Removal Policy (§9, §33 REMOVE, DR-005)

public struct GamificationSurfacePolicy: Equatable, Sendable {
    public let flags: FeatureFlags

    public init(flags: FeatureFlags = FeatureFlags()) {
        self.flags = flags
    }

    public var showsGemsOrShopInUI: Bool { false }
    public var showsPaidStreakFreezeInUI: Bool { false }
    public var showsPublicTenTierXPLeaguesInUI: Bool { false }
    public var showsGenericXPOrCrownsInUI: Bool { false }
    public var showsMonthlyBattlePassInUI: Bool { false }

    /// Preserved per owner decision DR-005 (`rhythm.dailyStreakOptIn` is `true` by default).
    public var showsDailyStreakAndAtRiskIconByDefault: Bool {
        flags.isEnabled(.dailyStreakOptIn)
    }
}

// MARK: - 6. SwiftUI Views (Phase 7 Gamification Screens)

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct WelcomeBackCardView: View {
    public let model: WelcomeBackBannerModel
    public let onStartExpressSession: () -> Void

    public init(
        model: WelcomeBackBannerModel,
        onStartExpressSession: @escaping () -> Void = {}
    ) {
        self.model = model
        self.onStartExpressSession = onStartExpressSession
    }

    public var body: some View {
        PrismCard(variant: .hero) {
            VStack(alignment: .leading, spacing: PrismSpacing.m) {
                PrismBadge(
                    configuration: PrismBadgeConfiguration(
                        text: "Bon retour",
                        semantics: .positive
                    )
                )
                PrismText(text: model.headline, style: .title3)
                PrismText(text: model.supportiveMessage, style: .body, role: .textSecondary)
                Button {
                    onStartExpressSession()
                } label: {
                    Text(verbatim: "Lancer une séance Express (5 min)")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrismButtonStyle(variant: .primary))
            }
        }
    }
}

public struct WeeklyRhythmSettingsScreen: View {
    @Binding public var model: WeeklyRhythmPlannerModel

    public init(model: Binding<WeeklyRhythmPlannerModel>) {
        self._model = model
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                RhythmWeekView(model: model.rhythmWeekViewModel)

                PrismCard(variant: .standard) {
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        PrismText(
                            text: "Objectif hebdomadaire : \(model.targetDaysPerWeek) j/sem (\(model.restDaysPerWeek) j de repos inclus)",
                            style: .headline
                        )
                        HStack(spacing: PrismSpacing.s) {
                            ForEach(WeeklyRhythmPlannerModel.minGoalDaysPerWeek...WeeklyRhythmPlannerModel.maxGoalDaysPerWeek, id: \.self) { daysCount in
                                PrismChip(
                                    configuration: PrismChipConfiguration(
                                        title: "\(daysCount) j",
                                        isSelected: model.targetDaysPerWeek == daysCount
                                    )
                                ) {
                                    model.targetDaysPerWeek = daysCount
                                }
                            }
                        }
                    }
                }

                PrismCard(variant: .standard) {
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        PrismText(text: "Rattrapage gratuit par rappels différés", style: .headline)
                        PrismText(
                            text: "\(model.completedCatchUpRecalls) / \(WeeklyRhythmPlannerModel.freeCatchUpRequiredRecalls) rappels différés réussis",
                            style: .subheadline,
                            role: .textSecondary
                        )
                        Button {
                            _ = model.applyFreeCatchUpIfEligible()
                        } label: {
                            Text(verbatim: "Valider un jour par rattrapage gratuit")
                        }
                        .buttonStyle(PrismButtonStyle(variant: .secondary))
                        .disabled(!model.canRedeemFreeCatchUp)
                    }
                }

                PrismCard(variant: .standard) {
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        PrismText(text: "Pause bienveillante (jusqu'à 4 semaines)", style: .headline)
                        PrismText(
                            text: model.isPaused
                                ? "Pause active : \(model.pauseWeeksRemaining) semaine(s) restante(s)"
                                : "Aucune pause active",
                            style: .subheadline,
                            role: .textSecondary
                        )
                        HStack(spacing: PrismSpacing.s) {
                            ForEach(0...WeeklyRhythmPlannerModel.maxPauseWeeks, id: \.self) { weeks in
                                PrismChip(
                                    configuration: PrismChipConfiguration(
                                        title: weeks == 0 ? "Actif" : "\(weeks) sem.",
                                        isSelected: model.pauseWeeksRemaining == weeks
                                    )
                                ) {
                                    model.configurePause(weeks: weeks)
                                }
                            }
                        }
                    }
                }
            }
            .padding(PrismSpacing.l)
        }
        .background(PrismColor.canvas)
        .navigationTitle(Text(verbatim: "Rythme & rappels"))
    }
}

public struct MasteryMilestonesAndMissionsScreen: View {
    public let missionBoard: WeeklyMissionBoardModel
    public let milestones: [MasteryMilestoneItem]
    public let activeEvent: CooperativeEventBannerModel?

    public init(
        missionBoard: WeeklyMissionBoardModel,
        milestones: [MasteryMilestoneItem],
        activeEvent: CooperativeEventBannerModel? = nil
    ) {
        self.missionBoard = missionBoard
        self.milestones = milestones
        self.activeEvent = activeEvent
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                if let event = activeEvent {
                    PrismCard(variant: .hero) {
                        VStack(alignment: .leading, spacing: PrismSpacing.s) {
                            RegionChip(region: event.region)
                            PrismText(text: event.title, style: .headline)
                            PrismText(text: event.subtitle, style: .subheadline, role: .textSecondary)
                            PrismProgressBar(
                                configuration: PrismProgressBarConfiguration(
                                    progress: Double(event.communityAnchoredCount) / Double(event.communityTargetCount),
                                    label: event.title
                                )
                            )
                        }
                    }
                }

                PrismSection(title: "Missions de la semaine (\(missionBoard.missions.count)/\(WeeklyMissionBoardModel.maxMissionsPerWeek))") {
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        ForEach(missionBoard.missions) { mission in
                            PrismCard(variant: .standard) {
                                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                                    if mission.isCooperativeSquadMission {
                                        PrismBadge(
                                            configuration: PrismBadgeConfiguration(
                                                text: "Coopérative · Squad",
                                                semantics: .accent
                                            )
                                        )
                                    }
                                    PrismText(text: mission.title, style: .headline)
                                    PrismText(text: mission.skillFocus, style: .footnote, role: .textSecondary)
                                    PrismProgressBar(
                                        configuration: PrismProgressBarConfiguration(
                                            progress: mission.progressRatio,
                                            label: mission.title
                                        )
                                    )
                                }
                            }
                        }
                    }
                }

                PrismSection(title: "Jalons de maîtrise") {
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        ForEach(milestones) { milestone in
                            PrismCard(variant: .standard) {
                                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                                    PrismAdaptiveStack(spacing: PrismSpacing.s) {
                                        PrismText(text: milestone.kind.title, style: .headline)
                                        PrismBadge(
                                            configuration: PrismBadgeConfiguration(
                                                text: milestone.isUnlocked ? "Accompli" : "\(milestone.progressCurrent)/\(milestone.progressTarget)",
                                                semantics: milestone.isUnlocked ? .positive : .neutral
                                            )
                                        )
                                    }
                                    PrismText(
                                        text: milestone.kind.learningRuleCitation,
                                        style: .footnote,
                                        role: .textSecondary
                                    )
                                    PrismProgressBar(
                                        configuration: PrismProgressBarConfiguration(
                                            progress: milestone.progressRatio,
                                            label: milestone.kind.title
                                        )
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .padding(PrismSpacing.l)
        }
        .background(PrismColor.canvas)
        .navigationTitle(Text(verbatim: "Rythme & jalons"))
    }
}
#endif
