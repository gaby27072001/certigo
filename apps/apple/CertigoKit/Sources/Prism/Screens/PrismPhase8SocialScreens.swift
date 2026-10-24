import BrandAssets
import CertigoDomain
import Foundation

// MARK: - 1. Social Privacy, Moderation & Deferred v1 Guard (§10, §15 NS-12)

public enum SocialVisibilityScope: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case rhythm
    case milestones
    case dailySituations
    case passport

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .rhythm:
            "Rythme hebdomadaire"
        case .milestones:
            "Jalons de maîtrise"
        case .dailySituations:
            "Situations du jour"
        case .passport:
            "Passeport de compétences"
        }
    }
}

public struct SocialPrivacySettingsModel: Codable, Equatable, Hashable, Sendable {
    public var pseudonym: String
    public var isPrivateByDefault: Bool
    public var visibleScopes: Set<SocialVisibilityScope>
    public var progressionLeaguesOptIn: Bool
    public var employerAggregatedOptIn: Bool
    public var isMinorAccount: Bool

    /// §10 invariants: never import contacts by default, never share location, never expose failures, never open free-text chat.
    public var allowsContactImport: Bool { false }
    public var sharesLocation: Bool { false }
    public var exposesFailuresToOthers: Bool { false }
    public var allowsFreeTextChat: Bool { false }
    public var requiresExplicitSquadConsent: Bool { true }

    public init(
        pseudonym: String = "Apprenant-Az7",
        isPrivateByDefault: Bool = true,
        visibleScopes: Set<SocialVisibilityScope> = [],
        progressionLeaguesOptIn: Bool = false,
        employerAggregatedOptIn: Bool = false,
        isMinorAccount: Bool = false
    ) {
        let cleaned = pseudonym.trimmingCharacters(in: .whitespacesAndNewlines)
        self.pseudonym = cleaned.isEmpty ? "Apprenant-Anonyme" : cleaned
        self.isPrivateByDefault = isPrivateByDefault
        self.visibleScopes = isMinorAccount ? [] : visibleScopes
        self.progressionLeaguesOptIn = isMinorAccount ? false : progressionLeaguesOptIn
        self.employerAggregatedOptIn = isMinorAccount ? false : employerAggregatedOptIn
        self.isMinorAccount = isMinorAccount
    }

    public var effectiveLeaguesOptIn: Bool {
        !isMinorAccount && progressionLeaguesOptIn
    }

    public var canShareExternalInviteLink: Bool {
        !isMinorAccount
    }

    public func isScopeVisible(_ scope: SocialVisibilityScope) -> Bool {
        guard !isMinorAccount, !isPrivateByDefault else { return false }
        return visibleScopes.contains(scope)
    }

    public mutating func toggleScope(_ scope: SocialVisibilityScope) {
        guard !isMinorAccount else { return }
        if visibleScopes.contains(scope) {
            visibleScopes.remove(scope)
        } else {
            isPrivateByDefault = false
            visibleScopes.insert(scope)
        }
    }
}

public enum SocialReportReason: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case inappropriatePseudonym
    case unwantedChallenge
    case suspiciousActivity

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .inappropriatePseudonym:
            "Pseudonyme inapproprié"
        case .unwantedChallenge:
            "Sollicitation répétée"
        case .suspiciousActivity:
            "Activité suspecte"
        }
    }
}

public struct SocialReportRecord: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let peerId: String
    public let reason: SocialReportReason

    public init(id: String, peerId: String, reason: SocialReportReason) {
        self.id = id
        self.peerId = peerId
        self.reason = reason
    }
}

public struct SocialModerationState: Codable, Equatable, Hashable, Sendable {
    public private(set) var blockedPeerIds: Set<String>
    public private(set) var hiddenPeerIds: Set<String>
    public private(set) var reports: [SocialReportRecord]

    public init(
        blockedPeerIds: Set<String> = [],
        hiddenPeerIds: Set<String> = [],
        reports: [SocialReportRecord] = []
    ) {
        self.blockedPeerIds = blockedPeerIds
        self.hiddenPeerIds = hiddenPeerIds
        self.reports = reports
    }

    public mutating func blockPeer(_ peerId: String) {
        blockedPeerIds.insert(peerId)
        hiddenPeerIds.insert(peerId)
    }

    public mutating func unblockPeer(_ peerId: String) {
        blockedPeerIds.remove(peerId)
    }

    public mutating func hidePeer(_ peerId: String) {
        hiddenPeerIds.insert(peerId)
    }

    public mutating func unhidePeer(_ peerId: String) {
        hiddenPeerIds.remove(peerId)
    }

    public mutating func reportPeer(_ peerId: String, reason: SocialReportReason) {
        let record = SocialReportRecord(
            id: "report-\(peerId)-\(reason.rawValue)",
            peerId: peerId,
            reason: reason
        )
        if !reports.contains(record) {
            reports.append(record)
        }
        hiddenPeerIds.insert(peerId)
    }

    public func isPeerVisible(_ peerId: String) -> Bool {
        !blockedPeerIds.contains(peerId) && !hiddenPeerIds.contains(peerId)
    }
}

public enum SocialDeferredFeaturesPolicy {
    /// §10 MUST NOT in v1: free-text chat, live study rooms, real-time duels, public activity feed.
    public static let freeTextChatEnabled: Bool = false
    public static let liveStudyRoomsEnabled: Bool = false
    public static let realTimeDuelsEnabled: Bool = false
    public static let publicActivityFeedEnabled: Bool = false

    public static let deferredSurfaceIdentifiers: Set<String> = [
        "free_text_chat",
        "live_study_rooms",
        "realtime_duels",
        "public_activity_feed",
        "address_book_import"
    ]

    public static func isDeferredInV1(_ surfaceIdentifier: String) -> Bool {
        deferredSurfaceIdentifiers.contains(surfaceIdentifier)
    }
}

// MARK: - 2. Daily Situation History (S-31, §6.1, §10, §14)

public struct DailySituationHistoryEntry: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let dateLabel: String
    public let routeCode: String
    public let brandProductId: BrandProductID
    public let conceptTitle: String
    public let distribution: PrismCommunityDistributionModel

    public init(
        id: String,
        dateLabel: String,
        routeCode: String,
        brandProductId: BrandProductID,
        conceptTitle: String,
        distribution: PrismCommunityDistributionModel
    ) {
        self.id = id
        self.dateLabel = dateLabel
        self.routeCode = routeCode
        self.brandProductId = brandProductId
        self.conceptTitle = conceptTitle
        self.distribution = distribution
    }

    public var hasAnswered: Bool {
        distribution.hasAnswered
    }

    /// Spoiler-free share card payload (S-95, §22A.7) available only after answering.
    public var spoilerFreeSharePayload: PrismShareCardPayload? {
        guard hasAnswered else { return nil }
        return PrismShareCardPayload(
            id: "share-s31-\(id)",
            title: "Situation du jour · \(routeCode)",
            region: .azure,
            synthesis: "\(dateLabel) · \(conceptTitle)",
            milestoneBadge: "Situation validée"
        )
    }

    public static let defaultSampleEntries: [DailySituationHistoryEntry] = [
        DailySituationHistoryEntry(
            id: "sit-2026-10-23",
            dateLabel: "23 oct. 2026",
            routeCode: "AZ-104",
            brandProductId: BrandProductID("microsoft-entra-id"),
            conceptTitle: "Isolation Private Endpoint et DNS privé",
            distribution: PrismCommunityDistributionModel(
                situationTitle: "Situation du 23 oct. · Isolation réseau",
                hasAnswered: true,
                buckets: [
                    PrismDistributionBucket(
                        id: "b1",
                        optionCode: "A",
                        optionSummary: "Zone DNS privée liée au VNet",
                        percentage: 64,
                        isLearnerSelection: true,
                        isBestOption: true
                    ),
                    PrismDistributionBucket(
                        id: "b2",
                        optionCode: "B",
                        optionSummary: "Point de terminaison de service public",
                        percentage: 24,
                        isLearnerSelection: false,
                        isBestOption: false
                    ),
                    PrismDistributionBucket(
                        id: "b3",
                        optionCode: "C",
                        optionSummary: "Redirection NSG sans DNS",
                        percentage: 12,
                        isLearnerSelection: false,
                        isBestOption: false
                    )
                ]
            )
        ),
        DailySituationHistoryEntry(
            id: "sit-2026-10-22",
            dateLabel: "22 oct. 2026",
            routeCode: "AI-102",
            brandProductId: BrandProductID("azure-ai-search"),
            conceptTitle: "Indexation hybride vectorielle et reclassement sémantique",
            distribution: PrismCommunityDistributionModel(
                situationTitle: "Situation du 22 oct. · Recherche hybride",
                hasAnswered: false,
                buckets: [
                    PrismDistributionBucket(
                        id: "b4",
                        optionCode: "A",
                        optionSummary: "RRF + classifieur sémantique L2",
                        percentage: 71,
                        isLearnerSelection: false,
                        isBestOption: true
                    )
                ]
            )
        )
    ]
}

// MARK: - 3. Cooperative Squads 3-8 & Create/Join Draft (S-61, S-62, §10)

public struct SquadKudosEvent: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let targetMemberId: String
    public let preset: PrismKudosPreset

    public init(id: String, targetMemberId: String, preset: PrismKudosPreset) {
        self.id = id
        self.targetMemberId = targetMemberId
        self.preset = preset
    }
}

public struct SquadWorkspaceModel: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public var goalModel: PrismSquadGoalModel
    public let routeCode: String
    public let brandProductId: BrandProductID
    public let targetExamMonth: String?
    public let inviteCode: String
    public let hasExplicitMemberConsent: Bool
    public private(set) var sentKudos: [SquadKudosEvent]

    /// §10: Never show member failures in Squads.
    public var memberFailuresVisible: Bool { false }

    public init(
        id: String = "squad-az104-oct",
        goalModel: PrismSquadGoalModel = Self.defaultGoalModel,
        routeCode: String = "AZ-104",
        brandProductId: BrandProductID = BrandProductID("microsoft-entra-id"),
        targetExamMonth: String? = "Novembre 2026",
        inviteCode: String = "SQD-7429",
        hasExplicitMemberConsent: Bool = true,
        sentKudos: [SquadKudosEvent] = []
    ) {
        self.id = id
        self.goalModel = goalModel
        self.routeCode = routeCode
        self.brandProductId = brandProductId
        self.targetExamMonth = targetExamMonth
        self.inviteCode = inviteCode
        self.hasExplicitMemberConsent = hasExplicitMemberConsent
        self.sentKudos = sentKudos
    }

    public mutating func sendPredefinedKudos(_ preset: PrismKudosPreset, toMemberId memberId: String) {
        guard goalModel.members.contains(where: { $0.id == memberId }) else { return }
        let event = SquadKudosEvent(
            id: "kudos-\(memberId)-\(preset.rawValue)",
            targetMemberId: memberId,
            preset: preset
        )
        if !sentKudos.contains(event) {
            sentKudos.append(event)
        }
    }

    public static let defaultGoalModel = PrismSquadGoalModel(
        squadName: "Escouade Architecture Cloud",
        weeklyTargetSessions: 12,
        members: [
            PrismSquadMemberContribution(
                id: "m-1",
                monogram: PrismAvatarMonogramModel(initials: "AL", region: .azure),
                pseudonym: "Alizée-Cloud",
                sessionsCompleted: 3
            ),
            PrismSquadMemberContribution(
                id: "m-2",
                monogram: PrismAvatarMonogramModel(initials: "KM", region: .security),
                pseudonym: "Karim-Sec",
                sessionsCompleted: 3
            ),
            PrismSquadMemberContribution(
                id: "m-3",
                monogram: PrismAvatarMonogramModel(initials: "SR", region: .ai),
                pseudonym: "Sora-AI",
                sessionsCompleted: 2
            ),
            PrismSquadMemberContribution(
                id: "m-4",
                monogram: PrismAvatarMonogramModel(initials: "GC", region: .azure),
                pseudonym: "Apprenant-Az7",
                sessionsCompleted: 2
            )
        ],
        isAnonymizedByDefault: true
    )
}

public struct CreateOrJoinSquadDraft: Codable, Equatable, Hashable, Sendable {
    public var squadName: String
    public var routeCode: String
    public var targetExamMonth: String
    public var joinInviteCode: String
    public var explicitConsentChecked: Bool
    public var anonymizeContributionsByDefault: Bool

    public init(
        squadName: String = "",
        routeCode: String = "AZ-104",
        targetExamMonth: String = "Novembre 2026",
        joinInviteCode: String = "",
        explicitConsentChecked: Bool = false,
        anonymizeContributionsByDefault: Bool = true
    ) {
        self.squadName = squadName
        self.routeCode = routeCode
        self.targetExamMonth = targetExamMonth
        self.joinInviteCode = joinInviteCode
        self.explicitConsentChecked = explicitConsentChecked
        self.anonymizeContributionsByDefault = anonymizeContributionsByDefault
    }

    public var canCreateSquad: Bool {
        explicitConsentChecked && !squadName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var canJoinWithCode: Bool {
        explicitConsentChecked && joinInviteCode.trimmingCharacters(in: .whitespacesAndNewlines).count >= 4
    }
}

// MARK: - 4. Friends, Friend Profile & Private Invite (S-63, S-64, S-67, §10)

public struct SocialFriendProfile: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let pseudonym: String
    public let monogram: PrismAvatarMonogramModel
    public let routeCode: String
    public let brandProductId: BrandProductID
    public let visibleRhythmSummary: String?
    public let visibleMilestones: [String]
    public let sharesPassport: Bool

    /// §10: Failures are never exposed on a friend profile.
    public var visibleFailureCount: Int { 0 }

    public init(
        id: String,
        pseudonym: String,
        monogram: PrismAvatarMonogramModel,
        routeCode: String,
        brandProductId: BrandProductID,
        visibleRhythmSummary: String?,
        visibleMilestones: [String] = [],
        sharesPassport: Bool = false
    ) {
        self.id = id
        self.pseudonym = pseudonym
        self.monogram = monogram
        self.routeCode = routeCode
        self.brandProductId = brandProductId
        self.visibleRhythmSummary = visibleRhythmSummary
        self.visibleMilestones = visibleMilestones
        self.sharesPassport = sharesPassport
    }

    public static let defaultFriends: [SocialFriendProfile] = [
        SocialFriendProfile(
            id: "friend-alizee",
            pseudonym: "Alizée-Cloud",
            monogram: PrismAvatarMonogramModel(initials: "AL", region: .azure),
            routeCode: "AZ-104",
            brandProductId: BrandProductID("microsoft-entra-id"),
            visibleRhythmSummary: "4/4 j cette semaine · Rythme régulier",
            visibleMilestones: ["Premier concept maîtrisé", "Première région couverte"],
            sharesPassport: true
        ),
        SocialFriendProfile(
            id: "friend-karim",
            pseudonym: "Karim-Sec",
            monogram: PrismAvatarMonogramModel(initials: "KM", region: .security),
            routeCode: "SC-300",
            brandProductId: BrandProductID("microsoft-defender-for-cloud"),
            visibleRhythmSummary: nil,
            visibleMilestones: [],
            sharesPassport: false
        )
    ]
}

public struct FriendInvitePayload: Codable, Equatable, Hashable, Sendable {
    public let inviteCode: String
    public let deepLinkURL: String
    public let qrPayload: String

    /// §10: Zero contact book import by default.
    public var importsAddressBookContacts: Bool { false }

    public init(inviteCode: String = "PRISM-8420") {
        let normalized = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.inviteCode = normalized.isEmpty ? "PRISM-0000" : normalized
        self.deepLinkURL = "certigo://ensemble/invite/\(self.inviteCode)"
        self.qrPayload = "CERTIGO:INVITE:\(self.inviteCode)"
    }
}

// MARK: - 5. Asynchronous 5-Item Untimed Challenge (S-65, §10)

public struct AsyncChallengeStateMachine: Codable, Equatable, Hashable, Sendable {
    public static let requiredItemCount: Int = PrismChallengeModel.requiredItemCount

    public let challengeId: String
    public let title: String
    public let opponentPseudonym: String
    public let learnerGlickoRating: Int
    public let opponentGlickoRating: Int
    public let route: PrismRouteBadgeModel
    public let brandProductId: BrandProductID
    public private(set) var recordedScores: [PrismChallengeItemScore]

    /// §10: Asynchronous challenges never have a timer and never expose the opponent per-item failures.
    public var hasTimer: Bool { false }
    public var showsOpponentItemFailures: Bool { false }

    public init(
        challengeId: String = "challenge-az104-5items",
        title: String = "Défi 5 situations · Réseau & Identité",
        opponentPseudonym: String = "Alizée-Cloud",
        learnerGlickoRating: Int = 1520,
        opponentGlickoRating: Int = 1535,
        route: PrismRouteBadgeModel = PrismRouteBadgeModel(
            examCode: "AZ-104",
            officialTitle: "Azure Administrator",
            region: .azure
        ),
        brandProductId: BrandProductID = BrandProductID("microsoft-entra-id"),
        recordedScores: [PrismChallengeItemScore] = []
    ) {
        self.challengeId = challengeId
        self.title = title
        self.opponentPseudonym = opponentPseudonym
        self.learnerGlickoRating = learnerGlickoRating
        self.opponentGlickoRating = opponentGlickoRating
        self.route = route
        self.brandProductId = brandProductId
        self.recordedScores = Array(recordedScores.prefix(Self.requiredItemCount))
    }

    public var currentItemIndex: Int {
        min(recordedScores.count + 1, Self.requiredItemCount)
    }

    public var isCompleted: Bool {
        recordedScores.count >= Self.requiredItemCount
    }

    public mutating func submitItemEvaluation(accuracy: Double, calibration: Double) {
        guard !isCompleted else { return }
        let nextNumber = recordedScores.count + 1
        recordedScores.append(
            PrismChallengeItemScore(
                itemNumber: nextNumber,
                accuracy: accuracy,
                calibration: calibration
            )
        )
    }

    public var challengeModel: PrismChallengeModel {
        PrismChallengeModel(
            id: challengeId,
            title: title,
            route: route,
            itemScores: recordedScores,
            isCompleted: isCompleted
        )
    }
}

// MARK: - 6. Opt-In Glicko-2 Progression Leagues (S-66, §10, §15 NS-12)

public struct LeagueStandingEntry: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let rank: Int
    public let pseudonym: String
    public let monogram: PrismAvatarMonogramModel
    public let glickoRating: Int
    public let cappedMasteryPoints: Int
    public let isCurrentLearner: Bool

    public init(
        id: String,
        rank: Int,
        pseudonym: String,
        monogram: PrismAvatarMonogramModel,
        glickoRating: Int,
        cappedMasteryPoints: Int,
        isCurrentLearner: Bool = false
    ) {
        self.id = id
        self.rank = max(1, rank)
        self.pseudonym = pseudonym
        self.monogram = monogram
        self.glickoRating = glickoRating
        self.cappedMasteryPoints = max(0, cappedMasteryPoints)
        self.isCurrentLearner = isCurrentLearner
    }
}

public struct ProgressionLeagueModel: Codable, Equatable, Hashable, Sendable {
    public static let noDemotionProtectedWeeks: Int = 4
    public static let maxGraceWeeks: Int = 2
    public static let neighborsWindowRadius: Int = 3
    public static let dailyMasteryPointsCap: Int = 120

    public var isOptedIn: Bool
    public let routeCode: String
    public let brandProductId: BrandProductID
    public let learnerGlickoRating: Int
    public let learnerGlickoDeviation: Int
    public let weeksInLeague: Int
    public let graceWeeksRemaining: Int
    public private(set) var dailyMasteryPointsEarned: Int
    public let fullCohortStandings: [LeagueStandingEntry]

    public init(
        isOptedIn: Bool = false,
        routeCode: String = "AZ-104",
        brandProductId: BrandProductID = BrandProductID("microsoft-entra-id"),
        learnerGlickoRating: Int = 1520,
        learnerGlickoDeviation: Int = 65,
        weeksInLeague: Int = 2,
        graceWeeksRemaining: Int = 2,
        dailyMasteryPointsEarned: Int = 85,
        fullCohortStandings: [LeagueStandingEntry] = Self.defaultStandings
    ) {
        self.isOptedIn = isOptedIn
        self.routeCode = routeCode
        self.brandProductId = brandProductId
        self.learnerGlickoRating = learnerGlickoRating
        self.learnerGlickoDeviation = max(30, learnerGlickoDeviation)
        self.weeksInLeague = max(1, weeksInLeague)
        self.graceWeeksRemaining = min(max(graceWeeksRemaining, 0), Self.maxGraceWeeks)
        self.dailyMasteryPointsEarned = min(max(dailyMasteryPointsEarned, 0), Self.dailyMasteryPointsCap)
        self.fullCohortStandings = fullCohortStandings
    }

    /// §10: No demotion during the first 4 weeks or while grace weeks remain.
    public var isProtectedFromDemotion: Bool {
        weeksInLeague <= Self.noDemotionProtectedWeeks || graceWeeksRemaining > 0
    }

    public mutating func recordMasteryPoints(_ points: Int) {
        guard points > 0 else { return }
        dailyMasteryPointsEarned = min(Self.dailyMasteryPointsCap, dailyMasteryPointsEarned + points)
    }

    /// §10: Displays only ±3 neighbors around the current learner (maximum 7 entries).
    public var visibleNeighborStandings: [LeagueStandingEntry] {
        guard isOptedIn, !fullCohortStandings.isEmpty else { return [] }
        guard let learnerIndex = fullCohortStandings.firstIndex(where: { $0.isCurrentLearner }) else {
            return Array(fullCohortStandings.prefix(Self.neighborsWindowRadius * 2 + 1))
        }
        let lowerBound = max(0, learnerIndex - Self.neighborsWindowRadius)
        let upperBound = min(fullCohortStandings.count - 1, learnerIndex + Self.neighborsWindowRadius)
        return Array(fullCohortStandings[lowerBound...upperBound])
    }

    public static let defaultStandings: [LeagueStandingEntry] = [
        LeagueStandingEntry(id: "l-1", rank: 1, pseudonym: "Nadia-Net", monogram: PrismAvatarMonogramModel(initials: "NN", region: .devops), glickoRating: 1590, cappedMasteryPoints: 410),
        LeagueStandingEntry(id: "l-2", rank: 2, pseudonym: "Hugo-Sec", monogram: PrismAvatarMonogramModel(initials: "HS", region: .security), glickoRating: 1575, cappedMasteryPoints: 390),
        LeagueStandingEntry(id: "l-3", rank: 3, pseudonym: "Alizée-Cloud", monogram: PrismAvatarMonogramModel(initials: "AL", region: .azure), glickoRating: 1555, cappedMasteryPoints: 365),
        LeagueStandingEntry(id: "l-4", rank: 4, pseudonym: "Karim-Sec", monogram: PrismAvatarMonogramModel(initials: "KM", region: .security), glickoRating: 1540, cappedMasteryPoints: 350),
        LeagueStandingEntry(id: "l-5", rank: 5, pseudonym: "Sora-AI", monogram: PrismAvatarMonogramModel(initials: "SR", region: .ai), glickoRating: 1530, cappedMasteryPoints: 335),
        LeagueStandingEntry(id: "l-6", rank: 6, pseudonym: "Apprenant-Az7", monogram: PrismAvatarMonogramModel(initials: "GC", region: .azure), glickoRating: 1520, cappedMasteryPoints: 320, isCurrentLearner: true),
        LeagueStandingEntry(id: "l-7", rank: 7, pseudonym: "Léo-Data", monogram: PrismAvatarMonogramModel(initials: "LD", region: .data), glickoRating: 1510, cappedMasteryPoints: 305),
        LeagueStandingEntry(id: "l-8", rank: 8, pseudonym: "Maya-Dev", monogram: PrismAvatarMonogramModel(initials: "MD", region: .azure), glickoRating: 1495, cappedMasteryPoints: 290),
        LeagueStandingEntry(id: "l-9", rank: 9, pseudonym: "Yanis-Ops", monogram: PrismAvatarMonogramModel(initials: "YO", region: .devops), glickoRating: 1485, cappedMasteryPoints: 275),
        LeagueStandingEntry(id: "l-10", rank: 10, pseudonym: "Chloé-AI", monogram: PrismAvatarMonogramModel(initials: "CA", region: .ai), glickoRating: 1470, cappedMasteryPoints: 260)
    ]
}

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

// MARK: - 7. Daily Situation History Screen (S-31)

public struct DailySituationHistoryScreen: View {
    public let entries: [DailySituationHistoryEntry]
    public let onShareEntry: (PrismShareCardPayload) -> Void

    public init(
        entries: [DailySituationHistoryEntry] = DailySituationHistoryEntry.defaultSampleEntries,
        onShareEntry: @escaping (PrismShareCardPayload) -> Void = { _ in }
    ) {
        self.entries = entries
        self.onShareEntry = onShareEntry
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                PrismSection(title: "Historique des Situations (S-31)") {
                    VStack(alignment: .leading, spacing: PrismSpacing.m) {
                        ForEach(entries) { entry in
                            PrismCard(variant: .standard) {
                                VStack(alignment: .leading, spacing: PrismSpacing.s) {
                                    PrismAdaptiveStack(spacing: PrismSpacing.s) {
                                        BrandLabel(
                                            product: entry.brandProductId,
                                            context: .learningContent,
                                            examCode: entry.routeCode
                                        )
                                        PrismBadge(
                                            configuration: PrismBadgeConfiguration(
                                                text: entry.dateLabel,
                                                semantics: entry.hasAnswered ? .positive : .neutral
                                            )
                                        )
                                    }
                                    PrismText(text: entry.conceptTitle, style: .headline)
                                    CommunityDistributionChart(model: entry.distribution)
                                    if let sharePayload = entry.spoilerFreeSharePayload {
                                        Button {
                                            onShareEntry(sharePayload)
                                        } label: {
                                            Text(verbatim: "Partager sans divulgâcher (S-95)")
                                        }
                                        .buttonStyle(PrismButtonStyle(variant: .secondary))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(PrismSpacing.l)
        }
        .background(PrismColor.canvas)
        .navigationTitle(Text(verbatim: "Situations du jour"))
    }
}

// MARK: - 8. Squad Detail (S-61) & Create/Join Squad Sheet (S-62)

public struct SquadDetailScreen: View {
    @State private var workspace: SquadWorkspaceModel
    public let onInviteToSquad: () -> Void

    public init(
        workspace: SquadWorkspaceModel = SquadWorkspaceModel(),
        onInviteToSquad: @escaping () -> Void = {}
    ) {
        self._workspace = State(initialValue: workspace)
        self.onInviteToSquad = onInviteToSquad
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                PrismCard(variant: .standard) {
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        PrismAdaptiveStack(spacing: PrismSpacing.s) {
                            BrandLabel(
                                product: workspace.brandProductId,
                                context: .learningContent,
                                examCode: workspace.routeCode
                            )
                            PrismBadge(
                                configuration: PrismBadgeConfiguration(
                                    text: workspace.goalModel.isAnonymizedByDefault ? "Contributions anonymisées" : "Pseudonymes visibles",
                                    semantics: .accent
                                )
                            )
                        }
                        SquadGoalView(model: workspace.goalModel)
                        if let examMonth = workspace.targetExamMonth {
                            PrismText(
                                text: "Objectif commun : \(workspace.routeCode) · \(examMonth)",
                                style: .footnote,
                                role: .textSecondary
                            )
                        }
                        PrismText(
                            text: "Aucun échec individuel n'est affiché aux membres de la Squad (§10).",
                            style: .caption1,
                            role: .textSecondary
                        )
                    }
                }

                PrismSection(title: "Encouragements en 1 geste (§10)") {
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        ForEach(workspace.goalModel.members) { member in
                            PrismCard(variant: .standard) {
                                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                                    HStack(spacing: PrismSpacing.s) {
                                        AvatarMonogram(model: member.monogram)
                                        PrismText(
                                            text: workspace.goalModel.displayedName(for: member),
                                            style: .headline
                                        )
                                        Spacer()
                                        PrismBadge(
                                            configuration: PrismBadgeConfiguration(
                                                text: "\(member.sessionsCompleted) séances",
                                                semantics: .neutral
                                            )
                                        )
                                    }
                                    HStack(spacing: PrismSpacing.xs) {
                                        ForEach(PrismKudosPreset.allCases, id: \.rawValue) { preset in
                                            Button {
                                                workspace.sendPredefinedKudos(preset, toMemberId: member.id)
                                            } label: {
                                                Text(verbatim: preset.label)
                                            }
                                            .buttonStyle(PrismButtonStyle(variant: .secondary))
                                        }
                                    }
                                }
                            }
                        }
                        Button {
                            onInviteToSquad()
                        } label: {
                            Text(verbatim: "Inviter par lien ou code (\(workspace.inviteCode))")
                        }
                        .buttonStyle(PrismButtonStyle(variant: .secondary))
                    }
                }
            }
            .padding(PrismSpacing.l)
        }
        .background(PrismColor.canvas)
        .navigationTitle(Text(verbatim: "Squad coopérative"))
    }
}

public struct CreateOrJoinSquadSheetScreen: View {
    @State private var draft: CreateOrJoinSquadDraft
    public let onConfirmSquad: (CreateOrJoinSquadDraft) -> Void

    public init(
        draft: CreateOrJoinSquadDraft = CreateOrJoinSquadDraft(),
        onConfirmSquad: @escaping (CreateOrJoinSquadDraft) -> Void = { _ in }
    ) {
        self._draft = State(initialValue: draft)
        self.onConfirmSquad = onConfirmSquad
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                PrismSection(title: "Créer ou rejoindre une Squad (S-62)") {
                    PrismCard(variant: .standard) {
                        VStack(alignment: .leading, spacing: PrismSpacing.s) {
                            PrismText(
                                text: "Route : \(draft.routeCode) · Mois cible : \(draft.targetExamMonth)",
                                style: .subheadline
                            )
                            Toggle(isOn: $draft.explicitConsentChecked) {
                                Text(verbatim: "J'accepte explicitement de rejoindre ou créer cette Squad coopérative")
                            }
                            Toggle(isOn: $draft.anonymizeContributionsByDefault) {
                                Text(verbatim: "Garder mes contributions anonymisées par défaut (initiales uniquement)")
                            }
                            Button {
                                draft.squadName = "Squad \(draft.routeCode)"
                                if draft.canCreateSquad {
                                    onConfirmSquad(draft)
                                }
                            } label: {
                                Text(verbatim: "Créer une Squad coopérative")
                            }
                            .buttonStyle(PrismButtonStyle(variant: .primary))
                            .disabled(!draft.explicitConsentChecked)
                        }
                    }
                }
            }
            .padding(PrismSpacing.l)
        }
        .background(PrismColor.canvas)
    }
}

// MARK: - 9. Friends List (S-63), Friend Profile (S-64) & Invite Sheet (S-67)

public struct FriendsListScreen: View {
    public let friends: [SocialFriendProfile]
    public let moderation: SocialModerationState
    public let onSelectFriend: (SocialFriendProfile) -> Void
    public let onOpenInviteSheet: () -> Void

    public init(
        friends: [SocialFriendProfile] = SocialFriendProfile.defaultFriends,
        moderation: SocialModerationState = SocialModerationState(),
        onSelectFriend: @escaping (SocialFriendProfile) -> Void = { _ in },
        onOpenInviteSheet: @escaping () -> Void = {}
    ) {
        self.friends = friends
        self.moderation = moderation
        self.onSelectFriend = onSelectFriend
        self.onOpenInviteSheet = onOpenInviteSheet
    }

    public var visibleFriends: [SocialFriendProfile] {
        friends.filter { moderation.isPeerVisible($0.id) }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                PrismSection(title: "Amis (S-63)") {
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        ForEach(visibleFriends) { friend in
                            PrismCard(variant: .standard) {
                                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                                    HStack(spacing: PrismSpacing.s) {
                                        AvatarMonogram(model: friend.monogram)
                                        VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                                            PrismText(text: friend.pseudonym, style: .headline)
                                            BrandLabel(
                                                product: friend.brandProductId,
                                                context: .learningContent,
                                                examCode: friend.routeCode
                                            )
                                        }
                                        Spacer()
                                        Button {
                                            onSelectFriend(friend)
                                        } label: {
                                            Text(verbatim: "Voir le profil")
                                        }
                                        .buttonStyle(PrismButtonStyle(variant: .secondary))
                                    }
                                    if let rhythm = friend.visibleRhythmSummary {
                                        PrismText(text: rhythm, style: .footnote, role: .textSecondary)
                                    } else {
                                        PrismText(
                                            text: "Rythme gardé privé par cet apprenant",
                                            style: .footnote,
                                            role: .textSecondary
                                        )
                                    }
                                }
                            }
                        }
                        Button {
                            onOpenInviteSheet()
                        } label: {
                            Text(verbatim: "Inviter un ami par lien / code / QR (S-67)")
                        }
                        .buttonStyle(PrismButtonStyle(variant: .primary))
                    }
                }
            }
            .padding(PrismSpacing.l)
        }
        .background(PrismColor.canvas)
        .navigationTitle(Text(verbatim: "Amis"))
    }
}

public struct FriendProfileScreen: View {
    public let friend: SocialFriendProfile
    @State private var moderation: SocialModerationState
    public let onStartChallenge: (String) -> Void

    public init(
        friend: SocialFriendProfile = SocialFriendProfile.defaultFriends[0],
        moderation: SocialModerationState = SocialModerationState(),
        onStartChallenge: @escaping (String) -> Void = { _ in }
    ) {
        self.friend = friend
        self._moderation = State(initialValue: moderation)
        self.onStartChallenge = onStartChallenge
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                PrismCard(variant: .standard) {
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        HStack(spacing: PrismSpacing.s) {
                            AvatarMonogram(model: friend.monogram)
                            VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                                PrismText(text: friend.pseudonym, style: .title3)
                                BrandLabel(
                                    product: friend.brandProductId,
                                    context: .learningContent,
                                    examCode: friend.routeCode
                                )
                            }
                            Spacer()
                            PrismBadge(
                                configuration: PrismBadgeConfiguration(
                                    text: "0 échec exposé",
                                    semantics: .positive
                                )
                            )
                        }
                        if let rhythm = friend.visibleRhythmSummary {
                            PrismText(text: rhythm, style: .subheadline)
                        } else {
                            PrismText(
                                text: "Rythme hebdomadaire non partagé.",
                                style: .subheadline,
                                role: .textSecondary
                            )
                        }
                        if !friend.visibleMilestones.isEmpty {
                            ForEach(friend.visibleMilestones, id: \.self) { milestone in
                                PrismBadge(
                                    configuration: PrismBadgeConfiguration(
                                        text: milestone,
                                        semantics: .accent
                                    )
                                )
                            }
                        }
                        Button {
                            onStartChallenge("challenge-\(friend.id)")
                        } label: {
                            Text(verbatim: "Lancer un défi 5 situations sans chronomètre (S-65)")
                        }
                        .buttonStyle(PrismButtonStyle(variant: .primary))
                    }
                }

                PrismSection(title: "Sécurité & modération (§10)") {
                    PrismCard(variant: .standard) {
                        HStack(spacing: PrismSpacing.s) {
                            Button {
                                moderation.hidePeer(friend.id)
                            } label: {
                                Text(verbatim: "Masquer")
                            }
                            .buttonStyle(PrismButtonStyle(variant: .secondary))

                            Button {
                                moderation.blockPeer(friend.id)
                            } label: {
                                Text(verbatim: "Bloquer")
                            }
                            .buttonStyle(PrismButtonStyle(variant: .secondary))

                            Button {
                                moderation.reportPeer(friend.id, reason: .unwantedChallenge)
                            } label: {
                                Text(verbatim: "Signaler")
                            }
                            .buttonStyle(PrismButtonStyle(variant: .secondary))
                        }
                    }
                }
            }
            .padding(PrismSpacing.l)
        }
        .background(PrismColor.canvas)
        .navigationTitle(Text(verbatim: "Profil ami"))
    }
}

public struct InviteFriendSheetScreen: View {
    public let payload: FriendInvitePayload
    public let privacy: SocialPrivacySettingsModel

    public init(
        payload: FriendInvitePayload = FriendInvitePayload(),
        privacy: SocialPrivacySettingsModel = SocialPrivacySettingsModel()
    ) {
        self.payload = payload
        self.privacy = privacy
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                PrismSection(title: "Inviter un apprenant (S-67)") {
                    PrismCard(variant: .standard) {
                        VStack(alignment: .leading, spacing: PrismSpacing.s) {
                            if privacy.canShareExternalInviteLink {
                                PrismBadge(
                                    configuration: PrismBadgeConfiguration(
                                        text: "Code : \(payload.inviteCode)",
                                        semantics: .accent
                                    )
                                )
                                PrismText(text: payload.deepLinkURL, style: .callout)
                                PrismText(
                                    text: "QR : \(payload.qrPayload) · Aucun import de carnet d'adresses (§10)",
                                    style: .footnote,
                                    role: .textSecondary
                                )
                            } else {
                                PrismBadge(
                                    configuration: PrismBadgeConfiguration(
                                        text: "Mode mineur actif",
                                        semantics: .warning
                                    )
                                )
                                PrismText(
                                    text: "Le partage de liens externes est désactivé en mode mineur (Declared Age Range).",
                                    style: .subheadline,
                                    role: .textSecondary
                                )
                            }
                        }
                    }
                }
            }
            .padding(PrismSpacing.l)
        }
        .background(PrismColor.canvas)
    }
}

// MARK: - 10. Async Challenge Cover (S-65) & Glicko-2 Leagues Screen (S-66)

public struct AsyncChallengeCoverScreen: View {
    @State private var stateMachine: AsyncChallengeStateMachine
    public let onDismiss: () -> Void

    public init(
        stateMachine: AsyncChallengeStateMachine = AsyncChallengeStateMachine(),
        onDismiss: @escaping () -> Void = {}
    ) {
        self._stateMachine = State(initialValue: stateMachine)
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                PrismSection(title: "Défi asynchrone (S-65)") {
                    PrismCard(variant: .standard) {
                        VStack(alignment: .leading, spacing: PrismSpacing.s) {
                            PrismAdaptiveStack(spacing: PrismSpacing.s) {
                                BrandLabel(
                                    product: stateMachine.brandProductId,
                                    context: .learningContent,
                                    examCode: stateMachine.route.examCode
                                )
                                PrismBadge(
                                    configuration: PrismBadgeConfiguration(
                                        text: "Sans chronomètre",
                                        semantics: .positive
                                    )
                                )
                            }
                            ChallengeCard(model: stateMachine.challengeModel)
                            PrismText(
                                text: "Adversaire : \(stateMachine.opponentPseudonym) (cote Glicko-2 appariée : \(stateMachine.opponentGlickoRating))",
                                style: .footnote,
                                role: .textSecondary
                            )
                            if !stateMachine.isCompleted {
                                Button {
                                    stateMachine.submitItemEvaluation(accuracy: 1.0, calibration: 0.9)
                                } label: {
                                    Text(verbatim: "Valider la situation \(stateMachine.currentItemIndex)/\(AsyncChallengeStateMachine.requiredItemCount)")
                                }
                                .buttonStyle(PrismButtonStyle(variant: .primary))
                            } else {
                                Button {
                                    onDismiss()
                                } label: {
                                    Text(verbatim: "Terminer le défi")
                                }
                                .buttonStyle(PrismButtonStyle(variant: .secondary))
                            }
                        }
                    }
                }
            }
            .padding(PrismSpacing.l)
        }
        .background(PrismColor.canvas)
    }
}

public struct ProgressionLeaguesScreen: View {
    @State private var model: ProgressionLeagueModel

    public init(model: ProgressionLeagueModel = ProgressionLeagueModel()) {
        self._model = State(initialValue: model)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                PrismSection(title: "Ligues de progression (S-66)") {
                    PrismCard(variant: .standard) {
                        VStack(alignment: .leading, spacing: PrismSpacing.s) {
                            PrismAdaptiveStack(spacing: PrismSpacing.s) {
                                BrandLabel(
                                    product: model.brandProductId,
                                    context: .learningContent,
                                    examCode: model.routeCode
                                )
                                PrismBadge(
                                    configuration: PrismBadgeConfiguration(
                                        text: model.isOptedIn ? "Opt-in actif" : "Désactivé par défaut (NS-12)",
                                        semantics: model.isOptedIn ? .positive : .neutral
                                    )
                                )
                            }
                            Toggle(isOn: $model.isOptedIn) {
                                Text(verbatim: "Participer à la ligue de progression sur \(model.routeCode)")
                            }
                            if model.isProtectedFromDemotion {
                                PrismBadge(
                                    configuration: PrismBadgeConfiguration(
                                        text: "Protection active : aucune relégation (sem. \(model.weeksInLeague)/\(ProgressionLeagueModel.noDemotionProtectedWeeks), grâce \(model.graceWeeksRemaining) sem.)",
                                        semantics: .accent
                                    )
                                )
                            }
                            PrismText(
                                text: "Plafond quotidien : \(model.dailyMasteryPointsEarned)/\(ProgressionLeagueModel.dailyMasteryPointsCap) pts de maîtrise calibrée",
                                style: .footnote,
                                role: .textSecondary
                            )
                        }
                    }
                }

                if model.isOptedIn {
                    PrismSection(title: "Voisinage de progression (±3 voisins)") {
                        PrismCard(variant: .standard) {
                            VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                                ForEach(model.visibleNeighborStandings) { entry in
                                    HStack(spacing: PrismSpacing.s) {
                                        PrismBadge(
                                            configuration: PrismBadgeConfiguration(
                                                text: "#\(entry.rank)",
                                                semantics: entry.isCurrentLearner ? .positive : .neutral
                                            )
                                        )
                                        AvatarMonogram(model: entry.monogram)
                                        PrismText(
                                            text: entry.pseudonym,
                                            style: entry.isCurrentLearner ? .headline : .subheadline
                                        )
                                        Spacer()
                                        PrismText(
                                            text: "\(entry.cappedMasteryPoints) pts",
                                            style: .footnote,
                                            role: .textSecondary
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(PrismSpacing.l)
        }
        .background(PrismColor.canvas)
        .navigationTitle(Text(verbatim: "Ligues de progression"))
    }
}

// MARK: - 11. Complete Ensemble Hub Screen (S-60 Phase 8, §10, §15 NS-12)

public struct EnsembleCompleteScreen: View {
    @State private var privacy: SocialPrivacySettingsModel
    public let squadWorkspace: SquadWorkspaceModel
    public let challengeState: AsyncChallengeStateMachine
    public let leagueModel: ProgressionLeagueModel
    public let situationHistory: [DailySituationHistoryEntry]
    public let onNavigate: (AppRoute) -> Void
    public let onOpenSheet: (AppSheetRoute) -> Void
    public let onOpenCover: (AppFullScreenCoverRoute) -> Void

    public init(
        privacy: SocialPrivacySettingsModel = SocialPrivacySettingsModel(),
        squadWorkspace: SquadWorkspaceModel = SquadWorkspaceModel(),
        challengeState: AsyncChallengeStateMachine = AsyncChallengeStateMachine(),
        leagueModel: ProgressionLeagueModel = ProgressionLeagueModel(),
        situationHistory: [DailySituationHistoryEntry] = DailySituationHistoryEntry.defaultSampleEntries,
        onNavigate: @escaping (AppRoute) -> Void = { _ in },
        onOpenSheet: @escaping (AppSheetRoute) -> Void = { _ in },
        onOpenCover: @escaping (AppFullScreenCoverRoute) -> Void = { _ in }
    ) {
        self._privacy = State(initialValue: privacy)
        self.squadWorkspace = squadWorkspace
        self.challengeState = challengeState
        self.leagueModel = leagueModel
        self.situationHistory = situationHistory
        self.onNavigate = onNavigate
        self.onOpenSheet = onOpenSheet
        self.onOpenCover = onOpenCover
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                PrismCard(variant: .standard) {
                    VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                        PrismAdaptiveStack(spacing: PrismSpacing.s) {
                            PrismBadge(
                                configuration: PrismBadgeConfiguration(
                                    text: privacy.isPrivateByDefault ? "Privé par défaut" : "Visibilité personnalisée",
                                    semantics: .positive
                                )
                            )
                            PrismBadge(
                                configuration: PrismBadgeConfiguration(
                                    text: privacy.effectiveLeaguesOptIn ? "Ligues actives" : "Ligues en option",
                                    semantics: .neutral
                                )
                            )
                        }
                        PrismText(text: "Pseudonyme : \(privacy.pseudonym)", style: .headline)
                        PrismText(
                            text: "Tes progrès restent privés par défaut. Seuls les jalons que tu choisis de partager sont visibles.",
                            style: .footnote,
                            role: .textSecondary
                        )
                    }
                }

                PrismSection(title: "Squad coopérative") {
                    PrismCard(variant: .hero) {
                        VStack(alignment: .leading, spacing: PrismSpacing.m) {
                            PrismAdaptiveStack(spacing: PrismSpacing.s) {
                                BrandLabel(
                                    product: squadWorkspace.brandProductId,
                                    context: .learningContent,
                                    examCode: squadWorkspace.routeCode
                                )
                                PrismBadge(
                                    configuration: PrismBadgeConfiguration(
                                        text: squadWorkspace.goalModel.isAnonymizedByDefault ? "Contributions anonymisées" : "Pseudonymes visibles",
                                        semantics: .accent
                                    )
                                )
                            }
                            SquadGoalView(model: squadWorkspace.goalModel)
                            if let examMonth = squadWorkspace.targetExamMonth {
                                PrismText(
                                    text: "Objectif commun : \(squadWorkspace.routeCode) · \(examMonth)",
                                    style: .footnote,
                                    role: .textSecondary
                                )
                            }
                            PrismAdaptiveStack(spacing: PrismSpacing.s) {
                                Button {
                                    onNavigate(.squadDetail(id: squadWorkspace.id))
                                } label: {
                                    Text(verbatim: "Encourager ma Squad")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(PrismButtonStyle(variant: .primary))

                                Button {
                                    onOpenSheet(.createOrJoinSquad)
                                } label: {
                                    Text(verbatim: "Inviter (\(squadWorkspace.inviteCode))")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(PrismButtonStyle(variant: .secondary))
                            }
                        }
                    }
                }

                PrismSection(title: "Défis asynchrones & Communauté") {
                    PrismCard(variant: .standard) {
                        VStack(alignment: .leading, spacing: PrismSpacing.m) {
                            ChallengeCard(model: challengeState.challengeModel)
                            Button {
                                onOpenCover(.asyncChallenge(id: challengeState.challengeId))
                            } label: {
                                Text(verbatim: "Relever le défi 5 situations")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrismButtonStyle(variant: .primary))

                            PrismRow(
                                configuration: PrismRowConfiguration(
                                    title: "Amis & invitations par code / QR",
                                    subtitle: "2 amis actifs · 0 import de carnet d'adresses",
                                    showsChevron: true
                                ),
                                action: { onNavigate(.friendsList) }
                            )
                            PrismRow(
                                configuration: PrismRowConfiguration(
                                    title: "Ligues de progression Glicko-2",
                                    subtitle: "Opt-in par route · ±3 voisins · 4 sem. sans relégation",
                                    showsChevron: true
                                ),
                                action: { onNavigate(.progressionLeagues) }
                            )
                            PrismRow(
                                configuration: PrismRowConfiguration(
                                    title: "Historique des Situations du jour",
                                    subtitle: "Distributions anonymes et cartes de partage",
                                    showsChevron: true
                                ),
                                action: { onNavigate(.dailySituationHistory) }
                            )
                        }
                    }
                }
            }
            .padding(PrismSpacing.l)
        }
        .background(PrismColor.canvas)
        .navigationTitle(Text(verbatim: "Ensemble"))
    }
}
#endif
