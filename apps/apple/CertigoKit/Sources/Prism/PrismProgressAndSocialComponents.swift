import Foundation
#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
#endif

// MARK: - 1. MasteryGlyph & PrismMasteryState (§8, §21, §28)

public enum PrismMasteryState: String, CaseIterable, Codable, Sendable, Equatable, Hashable {
    case undiscovered
    case discovered
    case practicing
    case anchored
    case mastered

    public var label: String {
        switch self {
        case .undiscovered:
            return "À découvrir"
        case .discovered:
            return "Découvert"
        case .practicing:
            return "En pratique"
        case .anchored:
            return "Ancré"
        case .mastered:
            return "Maîtrisé"
        }
    }

    public var symbolName: String {
        switch self {
        case .undiscovered:
            return "circle.dashed"
        case .discovered:
            return "sparkle"
        case .practicing:
            return "arrow.triangle.2.circlepath"
        case .anchored:
            return "checkmark.seal"
        case .mastered:
            return "checkmark.seal.fill"
        }
    }

    public var rank: Int {
        switch self {
        case .undiscovered: return 0
        case .discovered: return 1
        case .practicing: return 2
        case .anchored: return 3
        case .mastered: return 4
        }
    }

    public var isAnchoredOrMastered: Bool {
        self == .anchored || self == .mastered
    }

    public var accessibilityDescription: String {
        "État de maîtrise : \(label)"
    }
}

// MARK: - 2. DepthLadderView & PrismDepthRung (§8)

public struct PrismDepthRung: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: Int
    public let level: Int
    public let title: String
    public let isReached: Bool

    public init(level: Int, title: String, isReached: Bool) {
        let clamped = min(max(level, 1), 5)
        self.id = clamped
        self.level = clamped
        self.title = title
        self.isReached = isReached
    }
}

public struct PrismDepthLadderModel: Codable, Sendable, Equatable, Hashable {
    public static let rungCount: Int = 5
    public static let offPhoneRecommendationText: String = "Pratiquer hors téléphone"

    public let conceptTitle: String
    public let currentLevel: Int
    public let rungs: [PrismDepthRung]
    public let practiceOffPhoneRecommended: Bool

    public init(
        conceptTitle: String,
        currentLevel: Int,
        rungs: [PrismDepthRung]? = nil,
        practiceOffPhoneRecommended: Bool = false
    ) {
        let clampedCurrent = min(max(currentLevel, 0), Self.rungCount)
        self.conceptTitle = conceptTitle
        self.currentLevel = clampedCurrent
        self.practiceOffPhoneRecommended = practiceOffPhoneRecommended
        if let rungs, rungs.count == Self.rungCount {
            self.rungs = rungs
        } else {
            let defaultTitles = [
                "Reconnaître le concept",
                "Expliquer avec ses mots",
                "Distinguer les cas proches",
                "Choisir en situation",
                "Transférer hors contexte"
            ]
            self.rungs = defaultTitles.enumerated().map { index, title in
                let level = index + 1
                return PrismDepthRung(level: level, title: title, isReached: level <= clampedCurrent)
            }
        }
    }

    public var accessibilityLabel: String {
        let base = "\(conceptTitle), échelon \(currentLevel) sur \(Self.rungCount)"
        if practiceOffPhoneRecommended {
            return "\(base). \(Self.offPhoneRecommendationText)"
        }
        return base
    }
}

// MARK: - 3. MemoryForecastChart & PrismMemoryForecastPoint (§8, §28)

public enum PrismMemoryRetentionBand: String, CaseIterable, Codable, Sendable, Equatable, Hashable {
    case solid
    case reviveSoon
    case fading

    public var wordLabel: String {
        switch self {
        case .solid:
            return "solide"
        case .reviveSoon:
            return "à raviver bientôt"
        case .fading:
            return "s'estompe"
        }
    }

    public var patternSymbol: String {
        switch self {
        case .solid:
            return "circle.fill"
        case .reviveSoon:
            return "diamond.fill"
        case .fading:
            return "triangle.fill"
        }
    }

    public var patternGlyph: String {
        switch self {
        case .solid:
            return "●"
        case .reviveSoon:
            return "◆"
        case .fading:
            return "▲"
        }
    }

    public static func from(retention: Double) -> PrismMemoryRetentionBand {
        if retention >= 0.75 {
            return .solid
        } else if retention >= 0.50 {
            return .reviveSoon
        } else {
            return .fading
        }
    }
}

public struct PrismMemoryForecastPoint: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: Int
    public let dayOffset: Int
    public let dayLabel: String
    public let retention: Double
    public let band: PrismMemoryRetentionBand

    public init(dayOffset: Int, dayLabel: String, retention: Double) {
        let clamped = min(max(retention, 0.0), 1.0)
        self.id = dayOffset
        self.dayOffset = dayOffset
        self.dayLabel = dayLabel
        self.retention = clamped
        self.band = PrismMemoryRetentionBand.from(retention: clamped)
    }

    public var accessibilitySummary: String {
        "\(dayLabel) : rétention \(band.wordLabel)"
    }
}

// MARK: - 4. ReadinessBandView & PrismReadinessBand (§8, §15 NS-10)

public enum PrismReadinessBand: String, CaseIterable, Codable, Sendable, Equatable, Hashable {
    case insufficientEvidence
    case notYet
    case onTrack
    case readyToTry
    case veryReady

    public var title: String {
        switch self {
        case .insufficientEvidence:
            return "Preuves insuffisantes"
        case .notYet:
            return "Pas encore prêt"
        case .onTrack:
            return "En bonne voie"
        case .readyToTry:
            return "Prêt à tenter"
        case .veryReady:
            return "Très prêt"
        }
    }

    public var symbolName: String {
        switch self {
        case .insufficientEvidence:
            return "questionmark.circle"
        case .notYet:
            return "hourglass"
        case .onTrack:
            return "chart.line.uptrend.xyaxis"
        case .readyToTry:
            return "checkmark.circle"
        case .veryReady:
            return "star.circle.fill"
        }
    }
}

public struct PrismReadinessModel: Codable, Sendable, Equatable, Hashable {
    public let band: PrismReadinessBand
    public let isCalibrated: Bool
    public let rawProbability: Double?
    public let uncertaintyLow: Double
    public let uncertaintyHigh: Double
    public let evidenceCount: Int
    public let recommendedActions: [String]

    public init(
        band: PrismReadinessBand,
        isCalibrated: Bool,
        rawProbability: Double? = nil,
        uncertaintyLow: Double = 0.0,
        uncertaintyHigh: Double = 0.0,
        evidenceCount: Int,
        recommendedActions: [String]
    ) {
        self.band = band
        self.isCalibrated = isCalibrated
        self.rawProbability = rawProbability
        self.uncertaintyLow = min(max(uncertaintyLow, 0.0), 1.0)
        self.uncertaintyHigh = min(max(uncertaintyHigh, self.uncertaintyLow), 1.0)
        self.evidenceCount = max(0, evidenceCount)
        self.recommendedActions = Array(recommendedActions.prefix(3))
    }

    /// Critical rule §8 / NS-10: never display an uncalibrated percentage.
    public var formattedProbability: String? {
        guard isCalibrated, band != .insufficientEvidence, let rawProbability else {
            return nil
        }
        let percentage = Int((min(max(rawProbability, 0.0), 1.0) * 100.0).rounded())
        return "\(percentage) %"
    }

    public var evidenceSummaryText: String {
        "\(evidenceCount) preuves vérifiées"
    }

    public var uncertaintySummaryText: String {
        guard isCalibrated, band != .insufficientEvidence else {
            return "Intervalle non calibré — accumulez davantage de preuves"
        }
        let lowPct = Int((uncertaintyLow * 100.0).rounded())
        let highPct = Int((uncertaintyHigh * 100.0).rounded())
        return "Intervalle estimé : \(lowPct) % – \(highPct) %"
    }
}

// MARK: - 5. ObjectiveCoverageList & PrismObjectiveCoverageItem (§8)

public struct PrismObjectiveCoverageItem: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: String
    public let objectiveCode: String
    public let title: String
    public let region: PrismRegion
    public let masteryState: PrismMasteryState
    public let verifiedEvidenceCount: Int
    public let targetEvidenceCount: Int

    public init(
        id: String,
        objectiveCode: String,
        title: String,
        region: PrismRegion,
        masteryState: PrismMasteryState,
        verifiedEvidenceCount: Int,
        targetEvidenceCount: Int
    ) {
        self.id = id
        self.objectiveCode = objectiveCode
        self.title = title
        self.region = region
        self.masteryState = masteryState
        self.verifiedEvidenceCount = max(0, verifiedEvidenceCount)
        self.targetEvidenceCount = max(1, targetEvidenceCount)
    }

    public var evidenceProgressLabel: String {
        "\(verifiedEvidenceCount)/\(targetEvidenceCount) preuves"
    }
}

// MARK: - 6. RhythmWeekView & PrismRhythmWeekModel (§7, §9, DR-005)

public enum PrismRhythmDayState: String, CaseIterable, Codable, Sendable, Equatable, Hashable {
    case completed
    case restDay
    case planned
    case missedGrace
    case paused

    public var label: String {
        switch self {
        case .completed:
            return "Séance complétée"
        case .restDay:
            return "Repos prévu"
        case .planned:
            return "Planifié"
        case .missedGrace:
            return "Journée souple"
        case .paused:
            return "Pause"
        }
    }

    public var symbolName: String {
        switch self {
        case .completed:
            return "checkmark.circle.fill"
        case .restDay:
            return "moon.zzz.fill"
        case .planned:
            return "circle.dotted"
        case .missedGrace:
            return "leaf.fill"
        case .paused:
            return "pause.circle.fill"
        }
    }
}

public struct PrismRhythmDayItem: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: String
    public let shortDayLabel: String
    public let state: PrismRhythmDayState

    public init(id: String, shortDayLabel: String, state: PrismRhythmDayState) {
        self.id = id
        self.shortDayLabel = shortDayLabel
        self.state = state
    }
}

public struct PrismRhythmWeekModel: Codable, Sendable, Equatable, Hashable {
    public let weeklyGoalDays: Int
    public let days: [PrismRhythmDayItem]
    public let bestRhythmWeeks: Int
    public let dailyStreakOptIn: Bool
    public let dailyStreakDays: Int?

    public init(
        weeklyGoalDays: Int,
        days: [PrismRhythmDayItem],
        bestRhythmWeeks: Int,
        dailyStreakOptIn: Bool = false,
        dailyStreakDays: Int? = nil
    ) {
        self.weeklyGoalDays = min(max(weeklyGoalDays, 3), 6)
        self.days = Array(days.prefix(7))
        self.bestRhythmWeeks = max(0, bestRhythmWeeks)
        self.dailyStreakOptIn = dailyStreakOptIn
        self.dailyStreakDays = dailyStreakDays
    }

    public var completedDaysCount: Int {
        days.filter { $0.state == .completed }.count
    }

    public var visibleDailyStreakDays: Int? {
        guard dailyStreakOptIn, let dailyStreakDays, dailyStreakDays > 0 else {
            return nil
        }
        return dailyStreakDays
    }

    public var goalSummaryText: String {
        "\(completedDaysCount)/\(weeklyGoalDays) j cette semaine"
    }

    public var bestRhythmSummaryText: String {
        "Meilleur rythme : \(bestRhythmWeeks) sem."
    }
}

// MARK: - 7. AtlasCanvas, AtlasList & PrismAtlasNode (§8, §15 NS-8, §19, §30)

public struct PrismAtlasNode: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: String
    public let code: String
    public let title: String
    public let region: PrismRegion
    public let masteryState: PrismMasteryState
    public let normalizedX: Double
    public let normalizedY: Double
    public let connectedNodeIDs: [String]

    public init(
        id: String,
        code: String,
        title: String,
        region: PrismRegion,
        masteryState: PrismMasteryState,
        normalizedX: Double,
        normalizedY: Double,
        connectedNodeIDs: [String] = []
    ) {
        self.id = id
        self.code = code
        self.title = title
        self.region = region
        self.masteryState = masteryState
        self.normalizedX = min(max(normalizedX, 0.0), 1.0)
        self.normalizedY = min(max(normalizedY, 0.0), 1.0)
        self.connectedNodeIDs = connectedNodeIDs
    }

    public var accessibilityLabel: String {
        "\(code) \(title), \(region.displayName), \(masteryState.label)"
    }
}

public enum PrismAtlasLayout {
    public static let maxVisibleNodes: Int = 500

    public static func shouldDefaultToList(voiceOverRunning: Bool) -> Bool {
        voiceOverRunning
    }

    public static func filteredNodes(
        _ nodes: [PrismAtlasNode],
        region: PrismRegion? = nil,
        mastery: PrismMasteryState? = nil
    ) -> [PrismAtlasNode] {
        let filtered = nodes.filter { node in
            let matchesRegion = region == nil || node.region == region
            let matchesMastery = mastery == nil || node.masteryState == mastery
            return matchesRegion && matchesMastery
        }
        return Array(filtered.prefix(maxVisibleNodes))
    }
}

// MARK: - 8 & 9. RegionChip & RouteBadge (§22A.2, §33)

public struct PrismRouteBadgeModel: Identifiable, Codable, Sendable, Equatable, Hashable {
    public var id: String { examCode }
    public let examCode: String
    public let officialTitle: String
    public let region: PrismRegion

    public init(examCode: String, officialTitle: String, region: PrismRegion) {
        self.examCode = examCode
        self.officialTitle = officialTitle
        self.region = region
    }

    public var formattedLabel: String {
        "\(examCode) · \(officialTitle)"
    }
}

// MARK: - 10. PassportCard & PrismPassportSummary (§8, §19)

public struct PrismExternalVerificationLink: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: String
    public let providerName: String
    public let label: String
    public let urlString: String

    public init(id: String, providerName: String, label: String, urlString: String) {
        self.id = id
        self.providerName = providerName
        self.label = label
        self.urlString = urlString
    }
}

public struct PrismPassportSummary: Codable, Sendable, Equatable, Hashable {
    public let holderPseudonym: String
    public let holderInitials: String
    public let primaryRegion: PrismRegion
    public let anchoredConceptsCount: Int
    public let masteredConceptsCount: Int
    public let completedRhythmWeeks: Int
    public let routes: [PrismRouteBadgeModel]
    public let verificationLinks: [PrismExternalVerificationLink]

    public init(
        holderPseudonym: String,
        holderInitials: String,
        primaryRegion: PrismRegion,
        anchoredConceptsCount: Int,
        masteredConceptsCount: Int,
        completedRhythmWeeks: Int,
        routes: [PrismRouteBadgeModel],
        verificationLinks: [PrismExternalVerificationLink]
    ) {
        self.holderPseudonym = holderPseudonym
        self.holderInitials = String(holderInitials.prefix(2)).uppercased()
        self.primaryRegion = primaryRegion
        self.anchoredConceptsCount = max(0, anchoredConceptsCount)
        self.masteredConceptsCount = max(0, masteredConceptsCount)
        self.completedRhythmWeeks = max(0, completedRhythmWeeks)
        self.routes = routes
        self.verificationLinks = verificationLinks
    }
}

// MARK: - 11. AvatarMonogram (§10, §19)

public struct PrismAvatarMonogramModel: Codable, Sendable, Equatable, Hashable {
    public let initials: String
    public let region: PrismRegion
    public let isPrivatePseudonym: Bool

    public init(initials: String, region: PrismRegion, isPrivatePseudonym: Bool = true) {
        let cleaned = initials.trimmingCharacters(in: .whitespacesAndNewlines)
        self.initials = cleaned.isEmpty ? "?" : String(cleaned.prefix(2)).uppercased()
        self.region = region
        self.isPrivatePseudonym = isPrivatePseudonym
    }
}

// MARK: - 12. KudosButton (§10)

public enum PrismKudosPreset: String, CaseIterable, Codable, Sendable, Equatable, Hashable {
    case solidRhythm
    case niceAnchor
    case clearReasoning
    case keepGoing

    public var label: String {
        switch self {
        case .solidRhythm:
            return "Rythme solide"
        case .niceAnchor:
            return "Bel ancrage"
        case .clearReasoning:
            return "Raisonnement clair"
        case .keepGoing:
            return "Continue ainsi"
        }
    }

    public var symbolName: String {
        switch self {
        case .solidRhythm:
            return "hands.clap.fill"
        case .niceAnchor:
            return "checkmark.seal.fill"
        case .clearReasoning:
            return "lightbulb.fill"
        case .keepGoing:
            return "sparkles"
        }
    }
}

// MARK: - 13. SquadGoalView & PrismSquadGoalModel (§10, §15 NS-12)

public struct PrismSquadMemberContribution: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: String
    public let monogram: PrismAvatarMonogramModel
    public let pseudonym: String
    public let sessionsCompleted: Int

    public init(
        id: String,
        monogram: PrismAvatarMonogramModel,
        pseudonym: String,
        sessionsCompleted: Int
    ) {
        self.id = id
        self.monogram = monogram
        self.pseudonym = pseudonym
        self.sessionsCompleted = max(0, sessionsCompleted)
    }
}

public struct PrismSquadGoalModel: Codable, Sendable, Equatable, Hashable {
    public static let minMembers: Int = 3
    public static let maxMembers: Int = 8

    public let squadName: String
    public let weeklyTargetSessions: Int
    public let members: [PrismSquadMemberContribution]
    public let isAnonymizedByDefault: Bool

    public init(
        squadName: String,
        weeklyTargetSessions: Int,
        members: [PrismSquadMemberContribution],
        isAnonymizedByDefault: Bool = true
    ) {
        self.squadName = squadName
        self.weeklyTargetSessions = max(1, weeklyTargetSessions)
        self.members = Array(members.prefix(Self.maxMembers))
        self.isAnonymizedByDefault = isAnonymizedByDefault
    }

    public var totalCompletedSessions: Int {
        members.reduce(0) { $0 + $1.sessionsCompleted }
    }

    public var progressFraction: Double {
        min(max(Double(totalCompletedSessions) / Double(weeklyTargetSessions), 0.0), 1.0)
    }

    public var hasValidMemberCount: Bool {
        (Self.minMembers...Self.maxMembers).contains(members.count)
    }

    public func displayedName(for member: PrismSquadMemberContribution) -> String {
        isAnonymizedByDefault ? member.monogram.initials : member.pseudonym
    }
}

// MARK: - 14. ChallengeCard & PrismChallengeModel (§10)

public struct PrismChallengeItemScore: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: Int
    public let itemNumber: Int
    public let accuracy: Double
    public let calibration: Double

    public init(itemNumber: Int, accuracy: Double, calibration: Double) {
        self.id = itemNumber
        self.itemNumber = itemNumber
        self.accuracy = min(max(accuracy, 0.0), 1.0)
        self.calibration = min(max(calibration, 0.0), 1.0)
    }

    public var combinedScore: Double {
        accuracy * calibration
    }
}

public struct PrismChallengeModel: Identifiable, Codable, Sendable, Equatable, Hashable {
    public static let requiredItemCount: Int = 5

    public let id: String
    public let title: String
    public let route: PrismRouteBadgeModel
    public let itemScores: [PrismChallengeItemScore]
    public let isCompleted: Bool
    /// §10: Asynchronous 5-item challenge never uses a timer.
    public var hasTimer: Bool { false }
    public var itemCount: Int { Self.requiredItemCount }

    public init(
        id: String,
        title: String,
        route: PrismRouteBadgeModel,
        itemScores: [PrismChallengeItemScore],
        isCompleted: Bool
    ) {
        self.id = id
        self.title = title
        self.route = route
        self.itemScores = Array(itemScores.prefix(Self.requiredItemCount))
        self.isCompleted = isCompleted
    }

    public var totalScorePercentage: Int {
        guard !itemScores.isEmpty else { return 0 }
        let sum = itemScores.reduce(0.0) { $0 + $1.combinedScore }
        let mean = sum / Double(Self.requiredItemCount)
        return Int((mean * 100.0).rounded())
    }

    public var scoreFormulaLabel: String {
        "5 situations · Score = justesse × calibration · Sans chronomètre"
    }
}

// MARK: - 15. CommunityDistributionChart & PrismDistributionBucket (§6.1, §10, §15 NS-7)

public struct PrismDistributionBucket: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: String
    public let optionCode: String
    public let optionSummary: String
    public let percentage: Int
    public let isLearnerSelection: Bool
    public let isBestOption: Bool

    public init(
        id: String,
        optionCode: String,
        optionSummary: String,
        percentage: Int,
        isLearnerSelection: Bool,
        isBestOption: Bool
    ) {
        self.id = id
        self.optionCode = optionCode
        self.optionSummary = optionSummary
        self.percentage = min(max(percentage, 0), 100)
        self.isLearnerSelection = isLearnerSelection
        self.isBestOption = isBestOption
    }
}

public struct PrismCommunityDistributionModel: Codable, Sendable, Equatable, Hashable {
    public let situationTitle: String
    public let hasAnswered: Bool
    private let buckets: [PrismDistributionBucket]

    public init(
        situationTitle: String,
        hasAnswered: Bool,
        buckets: [PrismDistributionBucket]
    ) {
        self.situationTitle = situationTitle
        self.hasAnswered = hasAnswered
        self.buckets = buckets
    }

    /// Critical rule §6.1 / NS-7: never reveal community stats before the learner has answered.
    public var isVisible: Bool {
        hasAnswered
    }

    public var visibleBuckets: [PrismDistributionBucket] {
        hasAnswered ? buckets : []
    }

    public var lockedMessage: String {
        "Répondez d'abord à la Situation du jour pour découvrir la distribution de la communauté."
    }
}

// MARK: - SwiftUI Views (Apple platforms)

#if canImport(SwiftUI) && canImport(UIKit)

public struct MasteryGlyph: View {
    public let state: PrismMasteryState
    @Environment(\.colorScheme) private var colorScheme

    public init(state: PrismMasteryState) {
        self.state = state
    }

    private var resolvedScheme: PrismColorScheme {
        colorScheme == .dark ? .dark : .light
    }

    private var foregroundToken: PrismSemanticColor {
        switch state {
        case .undiscovered:
            return PrismColor.inkMuted
        case .discovered:
            return PrismColor.info
        case .practicing:
            return PrismColor.focus
        case .anchored:
            return PrismColor.success
        case .mastered:
            return PrismColor.mastery
        }
    }

    private var surfaceToken: PrismSemanticColor {
        switch state {
        case .undiscovered:
            return PrismColor.surfaceElevated
        case .discovered:
            return PrismColor.infoSoft
        case .practicing:
            return PrismColor.focusSoft
        case .anchored:
            return PrismColor.successSoft
        case .mastered:
            return PrismColor.masterySoft
        }
    }

    public var body: some View {
        HStack(spacing: PrismSpacing.xs) {
            Image(systemName: state.symbolName)
                .foregroundStyle(foregroundToken.color(in: resolvedScheme))
            Text(verbatim: state.label)
                .prismTextStyle(.caption)
                .foregroundStyle(PrismColor.inkPrimary.color(in: resolvedScheme))
        }
        .padding(.horizontal, PrismSpacing.sm)
        .padding(.vertical, PrismSpacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.pill)
                .fill(surfaceToken.color(in: resolvedScheme))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: state.accessibilityDescription))
    }
}

public struct DepthLadderView: View {
    public let model: PrismDepthLadderModel
    @Environment(\.colorScheme) private var colorScheme

    public init(model: PrismDepthLadderModel) {
        self.model = model
    }

    private var resolvedScheme: PrismColorScheme {
        colorScheme == .dark ? .dark : .light
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.sm) {
            HStack(spacing: PrismSpacing.sm) {
                Text(verbatim: model.conceptTitle)
                    .prismTextStyle(.headline)
                    .foregroundStyle(PrismColor.inkPrimary.color(in: resolvedScheme))
                Spacer()
                Text(verbatim: "\(model.currentLevel)/\(PrismDepthLadderModel.rungCount)")
                    .prismTextStyle(.numericMono)
                    .foregroundStyle(PrismColor.inkSecondary.color(in: resolvedScheme))
            }

            ForEach(model.rungs) { rung in
                HStack(spacing: PrismSpacing.sm) {
                    Image(systemName: rung.isReached ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(
                            (rung.isReached ? PrismColor.mastery : PrismColor.inkMuted)
                                .color(in: resolvedScheme)
                        )
                    Text(verbatim: "\(rung.level). \(rung.title)")
                        .prismTextStyle(.callout)
                        .foregroundStyle(
                            (rung.isReached ? PrismColor.inkPrimary : PrismColor.inkSecondary)
                                .color(in: resolvedScheme)
                        )
                    Spacer()
                }
            }

            if model.practiceOffPhoneRecommended {
                HStack(spacing: PrismSpacing.xs) {
                    Image(systemName: "hand.raised.fingers.spread.fill")
                        .foregroundStyle(PrismColor.engage.color(in: resolvedScheme))
                    Text(verbatim: PrismDepthLadderModel.offPhoneRecommendationText)
                        .prismTextStyle(.caption)
                        .foregroundStyle(PrismColor.inkPrimary.color(in: resolvedScheme))
                }
                .padding(PrismSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.sm)
                        .fill(PrismColor.engageSoft.color(in: resolvedScheme))
                )
            }
        }
        .padding(PrismSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.md)
                .fill(PrismColor.surfaceElevated.color(in: resolvedScheme))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: model.accessibilityLabel))
    }
}

public struct MemoryForecastChart: View {
    public let points: [PrismMemoryForecastPoint]
    @Environment(\.colorScheme) private var colorScheme

    public init(points: [PrismMemoryForecastPoint]) {
        self.points = Array(points.prefix(7))
    }

    private var resolvedScheme: PrismColorScheme {
        colorScheme == .dark ? .dark : .light
    }

    private func token(for band: PrismMemoryRetentionBand) -> PrismSemanticColor {
        switch band {
        case .solid:
            return PrismColor.success
        case .reviveSoon:
            return PrismColor.warning
        case .fading:
            return PrismColor.danger
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.sm) {
            Text(verbatim: "Prévision de mémoire (7 jours)")
                .prismTextStyle(.headline)
                .foregroundStyle(PrismColor.inkPrimary.color(in: resolvedScheme))

            ForEach(points) { point in
                HStack(spacing: PrismSpacing.sm) {
                    Text(verbatim: point.dayLabel)
                        .prismTextStyle(.caption)
                        .foregroundStyle(PrismColor.inkSecondary.color(in: resolvedScheme))
                    Image(systemName: point.band.patternSymbol)
                        .foregroundStyle(token(for: point.band).color(in: resolvedScheme))
                    Text(verbatim: "\(point.band.patternGlyph) \(point.band.wordLabel)")
                        .prismTextStyle(.callout)
                        .foregroundStyle(PrismColor.inkPrimary.color(in: resolvedScheme))
                    Spacer()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(verbatim: point.accessibilitySummary))
            }
        }
        .padding(PrismSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.md)
                .fill(PrismColor.surfaceElevated.color(in: resolvedScheme))
        )
    }
}

public struct ReadinessBandView: View {
    public let model: PrismReadinessModel
    @Environment(\.colorScheme) private var colorScheme

    public init(model: PrismReadinessModel) {
        self.model = model
    }

    private var resolvedScheme: PrismColorScheme {
        colorScheme == .dark ? .dark : .light
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.sm) {
            HStack(spacing: PrismSpacing.sm) {
                Image(systemName: model.band.symbolName)
                    .foregroundStyle(PrismColor.focus.color(in: resolvedScheme))
                Text(verbatim: model.band.title)
                    .prismTextStyle(.title3)
                    .foregroundStyle(PrismColor.inkPrimary.color(in: resolvedScheme))
                Spacer()
                if let formattedProbability = model.formattedProbability {
                    Text(verbatim: formattedProbability)
                        .prismTextStyle(.numericMono)
                        .foregroundStyle(PrismColor.mastery.color(in: resolvedScheme))
                }
            }

            Text(verbatim: model.uncertaintySummaryText)
                .prismTextStyle(.caption)
                .foregroundStyle(PrismColor.inkSecondary.color(in: resolvedScheme))

            Text(verbatim: model.evidenceSummaryText)
                .prismTextStyle(.callout)
                .foregroundStyle(PrismColor.inkPrimary.color(in: resolvedScheme))

            if !model.recommendedActions.isEmpty {
                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                    Text(verbatim: "3 actions recommandées")
                        .prismTextStyle(.caption)
                        .foregroundStyle(PrismColor.inkSecondary.color(in: resolvedScheme))
                    ForEach(Array(model.recommendedActions.enumerated()), id: \.offset) { idx, action in
                        Text(verbatim: "\(idx + 1). \(action)")
                            .prismTextStyle(.callout)
                            .foregroundStyle(PrismColor.inkPrimary.color(in: resolvedScheme))
                    }
                }
            }
        }
        .padding(PrismSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.md)
                .fill(PrismColor.surfaceElevated.color(in: resolvedScheme))
        )
    }
}

public struct ObjectiveCoverageList: View {
    public let items: [PrismObjectiveCoverageItem]
    @Environment(\.colorScheme) private var colorScheme

    public init(items: [PrismObjectiveCoverageItem]) {
        self.items = items
    }

    private var resolvedScheme: PrismColorScheme {
        colorScheme == .dark ? .dark : .light
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.sm) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                    HStack(spacing: PrismSpacing.sm) {
                        RegionChip(region: item.region)
                        Text(verbatim: item.objectiveCode)
                            .prismTextStyle(.codeMono)
                            .foregroundStyle(PrismColor.inkSecondary.color(in: resolvedScheme))
                        Spacer()
                        MasteryGlyph(state: item.masteryState)
                    }
                    Text(verbatim: item.title)
                        .prismTextStyle(.callout)
                        .foregroundStyle(PrismColor.inkPrimary.color(in: resolvedScheme))
                    Text(verbatim: item.evidenceProgressLabel)
                        .prismTextStyle(.caption)
                        .foregroundStyle(PrismColor.inkSecondary.color(in: resolvedScheme))
                }
                .padding(PrismSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.sm)
                        .fill(PrismColor.surfaceElevated.color(in: resolvedScheme))
                )
            }
        }
    }
}

public struct RhythmWeekView: View {
    public let model: PrismRhythmWeekModel
    @Environment(\.colorScheme) private var colorScheme

    public init(model: PrismRhythmWeekModel) {
        self.model = model
    }

    private var resolvedScheme: PrismColorScheme {
        colorScheme == .dark ? .dark : .light
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.sm) {
            HStack(spacing: PrismSpacing.sm) {
                Text(verbatim: model.goalSummaryText)
                    .prismTextStyle(.headline)
                    .foregroundStyle(PrismColor.inkPrimary.color(in: resolvedScheme))
                Spacer()
                Text(verbatim: model.bestRhythmSummaryText)
                    .prismTextStyle(.caption)
                    .foregroundStyle(PrismColor.inkSecondary.color(in: resolvedScheme))
            }

            HStack(spacing: PrismSpacing.sm) {
                ForEach(model.days) { day in
                    VStack(spacing: PrismSpacing.xxs) {
                        Image(systemName: day.state.symbolName)
                            .foregroundStyle(PrismColor.focus.color(in: resolvedScheme))
                        Text(verbatim: day.shortDayLabel)
                            .prismTextStyle(.caption)
                            .foregroundStyle(PrismColor.inkSecondary.color(in: resolvedScheme))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text(verbatim: "\(day.shortDayLabel) : \(day.state.label)"))
                }
            }

            if let streak = model.visibleDailyStreakDays {
                Text(verbatim: "Série quotidienne (optionnelle) : \(streak) j")
                    .prismTextStyle(.caption)
                    .foregroundStyle(PrismColor.engage.color(in: resolvedScheme))
            }
        }
        .padding(PrismSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.md)
                .fill(PrismColor.surfaceElevated.color(in: resolvedScheme))
        )
    }
}

public struct RegionChip: View {
    public let region: PrismRegion
    @Environment(\.colorScheme) private var colorScheme

    public init(region: PrismRegion) {
        self.region = region
    }

    private var resolvedScheme: PrismColorScheme {
        colorScheme == .dark ? .dark : .light
    }

    public var body: some View {
        HStack(spacing: PrismSpacing.xxs) {
            Image(systemName: "hexagon.fill")
                .foregroundStyle(region.accent.color(in: resolvedScheme))
            Text(verbatim: region.displayName)
                .prismTextStyle(.caption)
                .foregroundStyle(PrismColor.inkPrimary.color(in: resolvedScheme))
        }
        .padding(.horizontal, PrismSpacing.sm)
        .padding(.vertical, PrismSpacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.pill)
                .fill(region.soft.color(in: resolvedScheme))
        )
    }
}

public struct RouteBadge: View {
    public let model: PrismRouteBadgeModel
    @Environment(\.colorScheme) private var colorScheme

    public init(model: PrismRouteBadgeModel) {
        self.model = model
    }

    private var resolvedScheme: PrismColorScheme {
        colorScheme == .dark ? .dark : .light
    }

    public var body: some View {
        HStack(spacing: PrismSpacing.xs) {
            RegionChip(region: model.region)
            Text(verbatim: model.formattedLabel)
                .prismTextStyle(.callout)
                .foregroundStyle(PrismColor.inkPrimary.color(in: resolvedScheme))
        }
        .padding(PrismSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.sm)
                .fill(PrismColor.surfaceElevated.color(in: resolvedScheme))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: model.formattedLabel))
    }
}

public struct AtlasList: View {
    public let nodes: [PrismAtlasNode]
    public let selectedRegion: PrismRegion?
    public let selectedMastery: PrismMasteryState?
    public let onSelectNode: (PrismAtlasNode) -> Void
    @Environment(\.colorScheme) private var colorScheme

    public init(
        nodes: [PrismAtlasNode],
        selectedRegion: PrismRegion? = nil,
        selectedMastery: PrismMasteryState? = nil,
        onSelectNode: @escaping (PrismAtlasNode) -> Void = { _ in }
    ) {
        self.nodes = PrismAtlasLayout.filteredNodes(nodes, region: selectedRegion, mastery: selectedMastery)
        self.selectedRegion = selectedRegion
        self.selectedMastery = selectedMastery
        self.onSelectNode = onSelectNode
    }

    public init(
        nodes: [PrismAtlasNode],
        selectedRegion: PrismRegion? = nil,
        selectedState: PrismMasteryState?,
        onSelectNode: @escaping (PrismAtlasNode) -> Void = { _ in }
    ) {
        self.init(
            nodes: nodes,
            selectedRegion: selectedRegion,
            selectedMastery: selectedState,
            onSelectNode: onSelectNode
        )
    }

    private var resolvedScheme: PrismColorScheme {
        colorScheme == .dark ? .dark : .light
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.sm) {
            ForEach(nodes) { node in
                Button {
                    onSelectNode(node)
                } label: {
                    HStack(spacing: PrismSpacing.sm) {
                        RegionChip(region: node.region)
                        VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                            Text(verbatim: node.code)
                                .prismTextStyle(.codeMono)
                                .foregroundStyle(PrismColor.inkSecondary.color(in: resolvedScheme))
                            Text(verbatim: node.title)
                                .prismTextStyle(.callout)
                                .foregroundStyle(PrismColor.inkPrimary.color(in: resolvedScheme))
                        }
                        Spacer()
                        MasteryGlyph(state: node.masteryState)
                    }
                    .padding(PrismSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.sm)
                            .fill(PrismColor.surfaceElevated.color(in: resolvedScheme))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: node.accessibilityLabel))
            }
        }
    }
}

public struct AtlasCanvas: View {
    public let nodes: [PrismAtlasNode]
    public let onSelectNode: (PrismAtlasNode) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    public init(
        nodes: [PrismAtlasNode],
        onSelectNode: @escaping (PrismAtlasNode) -> Void = { _ in }
    ) {
        self.nodes = PrismAtlasLayout.filteredNodes(nodes)
        self.onSelectNode = onSelectNode
    }

    private var resolvedScheme: PrismColorScheme {
        colorScheme == .dark ? .dark : .light
    }

    public var body: some View {
        if PrismAtlasLayout.shouldDefaultToList(voiceOverRunning: voiceOverEnabled) {
            AtlasList(nodes: nodes, onSelectNode: onSelectNode)
        } else {
            VStack(alignment: .leading, spacing: PrismSpacing.m) {
                HStack(spacing: PrismSpacing.s) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .foregroundStyle(PrismColor.accent)
                    Text(verbatim: "Constellation des concepts (\(nodes.count) nœuds actifs)")
                        .prismTextStyle(.subheadline)
                        .foregroundStyle(PrismColor.inkPrimary.color(in: resolvedScheme))
                    Spacer()
                }

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: PrismSpacing.s), GridItem(.flexible(), spacing: PrismSpacing.s)],
                    spacing: PrismSpacing.s
                ) {
                    ForEach(nodes) { node in
                        Button {
                            onSelectNode(node)
                        } label: {
                            VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                                HStack(spacing: PrismSpacing.xs) {
                                    RegionChip(region: node.region)
                                    Spacer()
                                }
                                Text(verbatim: node.code)
                                    .prismTextStyle(.codeSmall)
                                    .foregroundStyle(PrismColor.inkSecondary.color(in: resolvedScheme))
                                Text(verbatim: node.title)
                                    .prismTextStyle(.subheadline)
                                    .foregroundStyle(PrismColor.inkPrimary.color(in: resolvedScheme))
                                    .multilineTextAlignment(.leading)
                                MasteryGlyph(state: node.masteryState)
                            }
                            .padding(PrismSpacing.m)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                    .fill(PrismColor.surface.color(in: resolvedScheme))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                    .strokeBorder(node.region.accent.color(in: resolvedScheme), lineWidth: PrismBorder.regular)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: node.accessibilityLabel))
                    }
                }
            }
        }
    }
}

public struct PassportCard: View {
    public let summary: PrismPassportSummary
    @Environment(\.colorScheme) private var colorScheme

    public init(summary: PrismPassportSummary) {
        self.summary = summary
    }

    private var resolvedScheme: PrismColorScheme {
        colorScheme == .dark ? .dark : .light
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.md) {
            HStack(spacing: PrismSpacing.sm) {
                AvatarMonogram(
                    model: PrismAvatarMonogramModel(
                        initials: summary.holderInitials,
                        region: summary.primaryRegion
                    )
                )
                VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                    Text(verbatim: summary.holderPseudonym)
                        .prismTextStyle(.headline)
                        .foregroundStyle(PrismColor.inkPrimary.color(in: resolvedScheme))
                    Text(verbatim: "Passeport de compétences vérifiées")
                        .prismTextStyle(.caption)
                        .foregroundStyle(PrismColor.inkSecondary.color(in: resolvedScheme))
                }
                Spacer()
            }

            HStack(spacing: PrismSpacing.md) {
                Text(verbatim: "\(summary.anchoredConceptsCount) ancrés")
                    .prismTextStyle(.callout)
                    .foregroundStyle(PrismColor.inkPrimary.color(in: resolvedScheme))
                Text(verbatim: "\(summary.masteredConceptsCount) maîtrisés")
                    .prismTextStyle(.callout)
                    .foregroundStyle(PrismColor.mastery.color(in: resolvedScheme))
                Text(verbatim: "\(summary.completedRhythmWeeks) sem. rythme")
                    .prismTextStyle(.callout)
                    .foregroundStyle(PrismColor.inkSecondary.color(in: resolvedScheme))
            }

            ForEach(summary.routes) { route in
                RouteBadge(model: route)
            }

            ForEach(summary.verificationLinks) { link in
                Text(verbatim: "\(link.providerName) · \(link.label) (\(link.urlString))")
                    .prismTextStyle(.caption)
                    .foregroundStyle(PrismColor.focus.color(in: resolvedScheme))
            }
        }
        .padding(PrismSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.lg)
                .fill(PrismColor.surfaceElevated.color(in: resolvedScheme))
        )
    }
}

public struct AvatarMonogram: View {
    public let model: PrismAvatarMonogramModel
    @Environment(\.colorScheme) private var colorScheme

    public init(model: PrismAvatarMonogramModel) {
        self.model = model
    }

    private var resolvedScheme: PrismColorScheme {
        colorScheme == .dark ? .dark : .light
    }

    public var body: some View {
        Text(verbatim: model.initials)
            .prismTextStyle(.headline)
            .foregroundStyle(model.region.accent.color(in: resolvedScheme))
            .frame(width: PrismSize.minTapTarget, height: PrismSize.minTapTarget)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.pill)
                    .fill(model.region.soft.color(in: resolvedScheme))
            )
            .accessibilityLabel(Text(verbatim: "Monogramme \(model.initials)"))
    }
}

public struct KudosButton: View {
    public let preset: PrismKudosPreset
    public let isSent: Bool
    public let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    public init(preset: PrismKudosPreset, isSent: Bool = false, action: @escaping () -> Void = {}) {
        self.preset = preset
        self.isSent = isSent
        self.action = action
    }

    private var resolvedScheme: PrismColorScheme {
        colorScheme == .dark ? .dark : .light
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: PrismSpacing.xs) {
                Image(systemName: preset.symbolName)
                    .foregroundStyle(
                        (isSent ? PrismColor.mastery : PrismColor.engage)
                            .color(in: resolvedScheme)
                    )
                Text(verbatim: preset.label)
                    .prismTextStyle(.callout)
                    .foregroundStyle(PrismColor.inkPrimary.color(in: resolvedScheme))
            }
            .padding(.horizontal, PrismSpacing.md)
            .padding(.vertical, PrismSpacing.sm)
            .frame(minHeight: PrismSize.minTapTarget)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.pill)
                    .fill(
                        (isSent ? PrismColor.masterySoft : PrismColor.engageSoft)
                            .color(in: resolvedScheme)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

public struct SquadGoalView: View {
    public let model: PrismSquadGoalModel
    @Environment(\.colorScheme) private var colorScheme

    public init(model: PrismSquadGoalModel) {
        self.model = model
    }

    private var resolvedScheme: PrismColorScheme {
        colorScheme == .dark ? .dark : .light
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.sm) {
            HStack(spacing: PrismSpacing.sm) {
                Text(verbatim: model.squadName)
                    .prismTextStyle(.headline)
                    .foregroundStyle(PrismColor.inkPrimary.color(in: resolvedScheme))
                Spacer()
                Text(verbatim: "\(model.totalCompletedSessions)/\(model.weeklyTargetSessions) séances")
                    .prismTextStyle(.numericMono)
                    .foregroundStyle(PrismColor.inkSecondary.color(in: resolvedScheme))
            }

            HStack(spacing: PrismSpacing.sm) {
                ForEach(model.members) { member in
                    VStack(spacing: PrismSpacing.xxs) {
                        AvatarMonogram(model: member.monogram)
                        Text(verbatim: model.displayedName(for: member))
                            .prismTextStyle(.caption)
                            .foregroundStyle(PrismColor.inkSecondary.color(in: resolvedScheme))
                    }
                }
            }
        }
        .padding(PrismSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.md)
                .fill(PrismColor.surfaceElevated.color(in: resolvedScheme))
        )
    }
}

public struct ChallengeCard: View {
    public let model: PrismChallengeModel
    @Environment(\.colorScheme) private var colorScheme

    public init(model: PrismChallengeModel) {
        self.model = model
    }

    private var resolvedScheme: PrismColorScheme {
        colorScheme == .dark ? .dark : .light
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.sm) {
            RouteBadge(model: model.route)
            Text(verbatim: model.title)
                .prismTextStyle(.headline)
                .foregroundStyle(PrismColor.inkPrimary.color(in: resolvedScheme))
            Text(verbatim: model.scoreFormulaLabel)
                .prismTextStyle(.caption)
                .foregroundStyle(PrismColor.inkSecondary.color(in: resolvedScheme))
            if model.isCompleted {
                Text(verbatim: "Score calibré : \(model.totalScorePercentage) %")
                    .prismTextStyle(.numericMono)
                    .foregroundStyle(PrismColor.mastery.color(in: resolvedScheme))
            }
        }
        .padding(PrismSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.md)
                .fill(PrismColor.surfaceElevated.color(in: resolvedScheme))
        )
    }
}

public struct CommunityDistributionChart: View {
    public let model: PrismCommunityDistributionModel
    @Environment(\.colorScheme) private var colorScheme

    public init(model: PrismCommunityDistributionModel) {
        self.model = model
    }

    private var resolvedScheme: PrismColorScheme {
        colorScheme == .dark ? .dark : .light
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.sm) {
            Text(verbatim: model.situationTitle)
                .prismTextStyle(.headline)
                .foregroundStyle(PrismColor.inkPrimary.color(in: resolvedScheme))

            if model.isVisible {
                ForEach(model.visibleBuckets) { bucket in
                    HStack(spacing: PrismSpacing.sm) {
                        Text(verbatim: "\(bucket.optionCode) · \(bucket.optionSummary)")
                            .prismTextStyle(.callout)
                            .foregroundStyle(PrismColor.inkPrimary.color(in: resolvedScheme))
                        Spacer()
                        Text(verbatim: "\(bucket.percentage) %")
                            .prismTextStyle(.numericMono)
                            .foregroundStyle(
                                (bucket.isBestOption ? PrismColor.success : PrismColor.inkSecondary)
                                    .color(in: resolvedScheme)
                            )
                    }
                }
            } else {
                Text(verbatim: model.lockedMessage)
                    .prismTextStyle(.callout)
                    .foregroundStyle(PrismColor.inkSecondary.color(in: resolvedScheme))
            }
        }
        .padding(PrismSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.md)
                .fill(PrismColor.surfaceElevated.color(in: resolvedScheme))
        )
    }
}

#Preview("Progress & Social — Nominal / Vide / AX3 / Sombre") {
    ScrollView {
        VStack(alignment: .leading, spacing: PrismSpacing.md) {
            MasteryGlyph(state: .anchored)
            DepthLadderView(
                model: PrismDepthLadderModel(
                    conceptTitle: "Identité fédérée Entra ID",
                    currentLevel: 4,
                    practiceOffPhoneRecommended: true
                )
            )
            ReadinessBandView(
                model: PrismReadinessModel(
                    band: .insufficientEvidence,
                    isCalibrated: false,
                    rawProbability: 0.82,
                    evidenceCount: 3,
                    recommendedActions: ["Ancrer RBAC", "Valider les réseaux virtuels", "Réviser le SLA"]
                )
            )
            CommunityDistributionChart(
                model: PrismCommunityDistributionModel(
                    situationTitle: "Situation du jour — AZ-104",
                    hasAnswered: false,
                    buckets: [
                        PrismDistributionBucket(
                            id: "a",
                            optionCode: "A",
                            optionSummary: "Private Endpoint",
                            percentage: 68,
                            isLearnerSelection: true,
                            isBestOption: true
                        )
                    ]
                )
            )
        }
        .padding(PrismSpacing.md)
    }
}
#endif
