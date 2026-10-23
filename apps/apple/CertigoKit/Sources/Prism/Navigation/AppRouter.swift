import BrandAssets
import CertigoDomain
import Foundation
import Observation

// MARK: - 1. AppTab (§12, §13)

public enum AppTab: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case today
    case atlas
    case ensemble
    case profile
    case search

    public var id: String { rawValue }

    /// Single-word French tab label (§13: "libellés d'un mot").
    public var title: String {
        switch self {
        case .today: "Aujourd'hui"
        case .atlas: "Atlas"
        case .ensemble: "Ensemble"
        case .profile: "Profil"
        case .search: "Recherche"
        }
    }

    public var isSingleWordLabel: Bool {
        !title.contains(" ")
    }

    public var unselectedSymbolName: String {
        switch self {
        case .today: "sun.max"
        case .atlas: "map"
        case .ensemble: "person.2"
        case .profile: "person.crop.circle"
        case .search: "magnifyingglass"
        }
    }

    /// Filled symbol variant when selected (§13, §22).
    public var selectedSymbolName: String {
        switch self {
        case .today: "sun.max.fill"
        case .atlas: "map.fill"
        case .ensemble: "person.2.fill"
        case .profile: "person.crop.circle.fill"
        case .search: "magnifyingglass"
        }
    }

    public func symbolName(isSelected: Bool) -> String {
        isSelected ? selectedSymbolName : unselectedSymbolName
    }

    /// §7 & §13: Badge is allowed ONLY for "Examen aujourd'hui" on Today/Atlas, never for streak loss.
    public func badgeText(isExamToday: Bool) -> String? {
        guard isExamToday, self == .today else { return nil }
        return "Examen aujourd'hui"
    }
}

// MARK: - 2. Centralized Routes (§13, §14)

public enum AppRoute: Codable, Hashable, Sendable {
    // Today (S-11)
    case memoryDetail
    // Daily Situation (S-31)
    case dailySituationHistory
    // Atlas & Objectives (S-41 … S-49)
    case regionDetail(PrismRegion)
    case territoryDetail(id: String)
    case conceptDetail(id: String)
    case misconceptionsMap
    case catalogExplorer
    case routeObjective(trackCode: String)
    case examObjectiveDetail(domainId: String)
    case readinessDetail(trackCode: String)
    // Ensemble (S-61 … S-66)
    case squadDetail(id: String)
    case friendsList
    case friendProfile(id: String)
    case progressionLeagues
    // Profile & Settings (S-71 … S-84)
    case passport
    case historyAndCalibration
    case settings
    case settingsRhythmAndReminders
    case settingsLanguage
    case settingsAccessibilityAndCalmMode
    case settingsPrivacyAndVisibility
    case settingsAI
    case settingsOfflineData
    case settingsAccount
    case settingsAccountDeletion
    case settingsDataAndMethodology
    case settingsBrandNotices
}

public enum AppFullScreenCoverRoute: Codable, Hashable, Sendable, Identifiable {
    case onboarding
    case sessionPlayer(length: PrismSessionLength, resumeSessionId: String?)
    case dailySituation
    case mockExam(trackCode: String)
    case asyncChallenge(id: String)

    public var id: String {
        switch self {
        case .onboarding:
            "cover.onboarding"
        case .sessionPlayer(let length, let resumeId):
            "cover.session.\(length.rawValue).\(resumeId ?? "new")"
        case .dailySituation:
            "cover.dailySituation"
        case .mockExam(let code):
            "cover.mockExam.\(code)"
        case .asyncChallenge(let id):
            "cover.challenge.\(id)"
        }
    }
}

public enum AppSheetRoute: Hashable, Sendable, Identifiable {
    case contextualAI(conceptId: String)
    case conceptSheet(id: String)
    case compareConcepts(leftId: String, rightId: String)
    case reportExamOutcome(trackCode: String)
    case createOrJoinSquad
    case inviteFriend
    case certigoPro
    case shareCard(PrismShareCardPayload)

    public var id: String {
        switch self {
        case .contextualAI(let id): "sheet.ai.\(id)"
        case .conceptSheet(let id): "sheet.concept.\(id)"
        case .compareConcepts(let l, let r): "sheet.compare.\(l).\(r)"
        case .reportExamOutcome(let code): "sheet.outcome.\(code)"
        case .createOrJoinSquad: "sheet.squad"
        case .inviteFriend: "sheet.invite"
        case .certigoPro: "sheet.pro"
        case .shareCard(let payload): "sheet.share.\(payload.id)"
        }
    }
}

// MARK: - 3. Interrupted Session Accessory (§6.2, §13)

public struct InterruptedSessionAccessory: Codable, Equatable, Hashable, Sendable {
    public let sessionId: String
    public let length: PrismSessionLength
    public let currentCardIndex: Int
    public let totalCards: Int
    public let savedAt: Date

    public init(
        sessionId: String,
        length: PrismSessionLength,
        currentCardIndex: Int,
        totalCards: Int,
        savedAt: Date
    ) {
        self.sessionId = sessionId
        self.length = length
        self.currentCardIndex = max(0, currentCardIndex)
        self.totalCards = max(1, totalCards)
        self.savedAt = savedAt
    }

    /// §6.2: "Reprendre" is valid 24h for Express/Standard and 7 days for DeepDive (Plongée).
    public var expirationInterval: TimeInterval {
        switch length {
        case .express, .standard:
            24 * 60 * 60
        case .deepDive:
            7 * 24 * 60 * 60
        }
    }

    public func isValid(at now: Date) -> Bool {
        let elapsed = now.timeIntervalSince(savedAt)
        return elapsed >= 0 && elapsed <= expirationInterval
    }

    public var accessoryTitle: String {
        "Séance en cours · Carte \(currentCardIndex + 1)/\(totalCards)"
    }
}

// MARK: - 4. Deep Link Outcome (§13, §27)

public enum DeepLinkOutcome: Equatable, Sendable {
    case handledByAuthCallback(URL)
    case navigatedToSession(PrismSessionLength)
    case navigatedToDailySituation
    case navigatedToTab(AppTab, route: AppRoute?)
    case ignoredUnsupported(URL)
}

// MARK: - 5. Router State Machine (§13)

private struct RouterPersistenceSnapshot: Codable {
    let selectedTab: AppTab
    let paths: [AppTab: [AppRoute]]
    let interruptedSession: InterruptedSessionAccessory?
}

@Observable
public final class AppRouterState: @unchecked Sendable {
    public var selectedTab: AppTab
    public var paths: [AppTab: [AppRoute]]
    public var activeCover: AppFullScreenCoverRoute?
    public var activeSheet: AppSheetRoute?
    public var interruptedSession: InterruptedSessionAccessory?
    public var isShowingUnsavedInputConfirmation: Bool

    public init(
        selectedTab: AppTab = .today,
        paths: [AppTab: [AppRoute]] = [:],
        activeCover: AppFullScreenCoverRoute? = nil,
        activeSheet: AppSheetRoute? = nil,
        interruptedSession: InterruptedSessionAccessory? = nil
    ) {
        self.selectedTab = selectedTab
        var initialPaths: [AppTab: [AppRoute]] = [:]
        for tab in AppTab.allCases {
            initialPaths[tab] = paths[tab] ?? []
        }
        self.paths = initialPaths
        self.activeCover = activeCover
        self.activeSheet = activeSheet
        self.interruptedSession = interruptedSession
        self.isShowingUnsavedInputConfirmation = false
    }

    /// §13: Tab bar is never hidden outside full-screen covers.
    public var isTabBarVisible: Bool {
        activeCover == nil
    }

    public func path(for tab: AppTab) -> [AppRoute] {
        paths[tab] ?? []
    }

    public func push(_ route: AppRoute, in tab: AppTab? = nil) {
        let targetTab = tab ?? selectedTab
        selectedTab = targetTab
        var current = paths[targetTab] ?? []
        current.append(route)
        paths[targetTab] = current
    }

    public func pop(in tab: AppTab? = nil) {
        let targetTab = tab ?? selectedTab
        guard var current = paths[targetTab], !current.isEmpty else { return }
        current.removeLast()
        paths[targetTab] = current
    }

    public func popToRoot(in tab: AppTab? = nil) {
        let targetTab = tab ?? selectedTab
        paths[targetTab] = []
    }

    public func presentCover(_ cover: AppFullScreenCoverRoute) {
        activeCover = cover
        isShowingUnsavedInputConfirmation = false
    }

    public func presentSheet(_ sheet: AppSheetRoute) {
        activeSheet = sheet
    }

    public func dismissSheet() {
        activeSheet = nil
    }

    /// §13: Closing a full-screen session = "Terminer et sauvegarder" immediately unless an answer is mid-entry.
    public func requestDismissCover(hasUnsavedInputInProgress: Bool = false) {
        if hasUnsavedInputInProgress {
            isShowingUnsavedInputConfirmation = true
        } else {
            isShowingUnsavedInputConfirmation = false
            activeCover = nil
        }
    }

    public func confirmForceDismissCover() {
        isShowingUnsavedInputConfirmation = false
        activeCover = nil
    }

    public func activeInterruptedSession(at now: Date) -> InterruptedSessionAccessory? {
        guard let interruptedSession, interruptedSession.isValid(at: now) else {
            return nil
        }
        return interruptedSession
    }

    // MARK: SceneStorage Serialization (§13)

    public func encodeRestorationData() throws -> Data {
        let snapshot = RouterPersistenceSnapshot(
            selectedTab: selectedTab,
            paths: paths,
            interruptedSession: interruptedSession
        )
        return try JSONEncoder().encode(snapshot)
    }

    public func restore(from data: Data, now: Date = Date()) throws {
        let snapshot = try JSONDecoder().decode(RouterPersistenceSnapshot.self, from: data)
        selectedTab = snapshot.selectedTab
        for tab in AppTab.allCases {
            paths[tab] = snapshot.paths[tab] ?? []
        }
        if let session = snapshot.interruptedSession, session.isValid(at: now) {
            interruptedSession = session
        } else {
            interruptedSession = nil
        }
    }

    // MARK: Deep Link Routing (§13: preserves certigo://auth and certigo://widget/learn)

    @discardableResult
    public func handleDeepLink(_ url: URL) -> DeepLinkOutcome {
        guard let scheme = url.scheme?.lowercased() else {
            return .ignoredUnsupported(url)
        }

        if scheme == "certigo" {
            let host = url.host?.lowercased() ?? ""
            let pathComponents = url.pathComponents.filter { $0 != "/" }

            // Preserve existing MSAL / CIAM callback route: certigo://auth
            if host == "auth" {
                return .handledByAuthCallback(url)
            }

            // Preserve existing WidgetKit route: certigo://widget/learn
            if host == "widget", pathComponents.first?.lowercased() == "learn" {
                selectedTab = .today
                presentCover(.sessionPlayer(length: .express, resumeSessionId: interruptedSession?.sessionId))
                return .navigatedToSession(.express)
            }

            if host == "today" {
                selectedTab = .today
                popToRoot(in: .today)
                return .navigatedToTab(.today, route: nil)
            }

            if host == "session" {
                selectedTab = .today
                let lengthRaw = pathComponents.first?.lowercased() ?? "standard"
                let length = PrismSessionLength(rawValue: lengthRaw) ?? .standard
                presentCover(.sessionPlayer(length: length, resumeSessionId: nil))
                return .navigatedToSession(length)
            }

            if host == "situation" {
                selectedTab = .today
                presentCover(.dailySituation)
                return .navigatedToDailySituation
            }

            if host == "atlas" {
                selectedTab = .atlas
                if let first = pathComponents.first, first == "explorer" {
                    push(.catalogExplorer, in: .atlas)
                    return .navigatedToTab(.atlas, route: .catalogExplorer)
                }
                if pathComponents.count >= 2, pathComponents[0] == "concept" {
                    let route = AppRoute.conceptDetail(id: pathComponents[1])
                    push(route, in: .atlas)
                    return .navigatedToTab(.atlas, route: route)
                }
                return .navigatedToTab(.atlas, route: nil)
            }

            if host == "ensemble" {
                selectedTab = .ensemble
                return .navigatedToTab(.ensemble, route: nil)
            }

            if host == "profile" {
                selectedTab = .profile
                return .navigatedToTab(.profile, route: nil)
            }
        }

        if let pilotLink = EditorialPilotLessonLink(url: url) {
            selectedTab = .today
            let route = AppRoute.conceptDetail(id: pilotLink.lessonID)
            push(route, in: .today)
            return .navigatedToTab(.today, route: route)
        }

        return .ignoredUnsupported(url)
    }
}

public typealias Router = AppRouterState
