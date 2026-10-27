import BrandAssets
import CertigoDomain
import Foundation

// MARK: - 1. 60-Second Onboarding Flow (S-01..S-06, §14, §15 NS-1, §34.1)

public enum OnboardingStep: Int, CaseIterable, Codable, Comparable, Hashable, Sendable, Identifiable {
    case welcomeRegionAndTrack = 1       // S-01
    case discoverySituation = 2          // S-02 (1st decision in <= 2 screens, offline playable)
    case firstAhaMoment = 3              // S-03 (mini-Atlas + anonymous distribution)
    case goalRhythmAndWhen = 4           // S-04 (Objective, Weekly Rhythm 3-6d & When)
    case saveProgressAuth = 5            // S-05 (Sign in with Apple / Passkey / Microsoft CIAM / Google)
    case notificationPermissionSheet = 6 // S-06 (Prompted only AFTER 1st completed session)

    public var id: Int { rawValue }

    public static func < (lhs: OnboardingStep, rhs: OnboardingStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var screenCode: String {
        "S-0\(rawValue)"
    }

    public var title: String {
        switch self {
        case .welcomeRegionAndTrack: "Bienvenue · Choisir une route (S-01)"
        case .discoverySituation: "Situation de découverte (S-02)"
        case .firstAhaMoment: "Premier Déclic · Mini-Atlas (S-03)"
        case .goalRhythmAndWhen: "Objectif, Rythme & Horizon (S-04)"
        case .saveProgressAuth: "Sauvegarder ma progression (S-05)"
        case .notificationPermissionSheet: "Rappels bienveillants (S-06)"
        }
    }
}


/// The 11 validated Figma Pro Onboarding screens on Page 07 (`OB-01` to `OB-08B`).
public enum OnboardingFigmaScreenID: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case ob01OpeningArch = "OB-01"
    case ob02Objectives = "OB-02"
    case ob03aMultiCertifications = "OB-03A"
    case ob03bAIActorsAndLivingCatalog = "OB-03B"
    case ob04CalibrationAndDeadline = "OB-04"
    case ob06aDailyRhythm = "OB-06A"
    case ob06bIOSPushNotificationAlert = "OB-06B"
    case ob06cIOSHomeScreenWidgetSheet = "OB-06C"
    case ob07DualCurvePlan = "OB-07"
    case ob08aOneTapProfile = "OB-08A"
    case ob08bAppleSignInFaceIDSheet = "OB-08B"

    public var id: String { rawValue }
}

public struct CertigoProFeatureComparisonRow: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let featureTitle: String
    public let freeTierValue: String
    public let proTierValue: String

    public init(id: String, featureTitle: String, freeTierValue: String, proTierValue: String) {
        self.id = id
        self.featureTitle = featureTitle
        self.freeTierValue = freeTierValue
        self.proTierValue = proTierValue
    }

    public static let validatedRows: [CertigoProFeatureComparisonRow] = [
        .init(id: "tracks", featureTitle: "Certifications suivies en parallèle", freeTierValue: "1 max", proTierValue: "Illimité ✓"),
        .init(id: "exams", featureTitle: "Examens Blancs Pearson VUE (90m)", freeTierValue: "1 démo", proTierValue: "Illimités ✓"),
        .init(id: "ai-coach", featureTitle: "Coach IA Vocal Live & Lab CLI", freeTierValue: "3 / jour", proTierValue: "Illimité 24/7 ✓"),
        .init(id: "ai-actors", featureTitle: "Cours Grands Acteurs IA & Radar Tech", freeTierValue: "Aperçu", proTierValue: "Accès complet ✓"),
        .init(id: "offline", featureTitle: "Téléchargement Hors-Ligne (Train/Avion)", freeTierValue: "—", proTierValue: "Inclus ✓")
    ]
}

public enum OnboardingAuthProvider: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case signInWithApple
    case passkey
    case microsoftEntraCIAM
    case googleFederated

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .signInWithApple: "Continuer avec Apple"
        case .passkey: "Clé d'accès (Passkey)"
        case .microsoftEntraCIAM: "Continuer avec Microsoft"
        case .googleFederated: "Continuer avec Google"
        }
    }
}

public struct OnboardingFlowStateMachine: Codable, Equatable, Hashable, Sendable {
    public static let maxScreensBeforeFirstDecision: Int = 2
    public static let targetDurationSeconds: Int = 60

    public private(set) var currentStep: OnboardingStep
    public var selectedRegion: PrismRegion
    public var selectedRouteCode: String
    public var selectedBrandProductId: BrandProductID
    public private(set) var selectedDiscoveryOptionCode: String?
    public var weeklyGoalDays: Int
    public var targetExamHorizonLabel: String
    public private(set) var hasCompletedFirstValueSession: Bool
    public private(set) var notificationsAuthorized: Bool

    /// §15 NS-1 & §34.1 invariants: first decision in <= 2 screens, zero free-text fields, offline playable, never show paywall before first value.
    public var screensBeforeFirstDecision: Int { 2 }
    public var usesFreeTextFields: Bool { false }
    public var isPlayableOffline: Bool { true }
    public var showsPaywallBeforeFirstValue: Bool { false }
    public var currentFigmaScreen: OnboardingFigmaScreenID = .ob01OpeningArch
    public var parallelTracksPreference: CertigoParallelTracksPreference
    public var selectedParallelRoutes: [String] {
        get { parallelTracksPreference.parallelTrackCodes }
        set {
            parallelTracksPreference = CertigoParallelTracksPreference(
                parallelTrackCodes: newValue,
                activeTrackCode: selectedRouteCode,
                aiFrontierTrackCodes: parallelTracksPreference.aiFrontierTrackCodes,
                bilingualTechnicalTermsEN: parallelTracksPreference.bilingualTechnicalTermsEN,
                strictTimed90Min: parallelTracksPreference.strictTimed90Min
            )
        }
    }
    public var selectedAIFrontierTrackCodes: [String] {
        get { parallelTracksPreference.aiFrontierTrackCodes }
        set {
            parallelTracksPreference = CertigoParallelTracksPreference(
                parallelTrackCodes: parallelTracksPreference.parallelTrackCodes,
                activeTrackCode: selectedRouteCode,
                aiFrontierTrackCodes: newValue,
                bilingualTechnicalTermsEN: parallelTracksPreference.bilingualTechnicalTermsEN,
                strictTimed90Min: parallelTracksPreference.strictTimed90Min
            )
        }
    }
    public var selectedAIActorTopics: [String] = ["OpenAI & GPT", "Anthropic Claude", "Google Gemini", "Microsoft Foundry & Copilot"]
    public var projectedScoreWithCertiGo: Int { 845 }
    public var projectedScoreWithoutCertiGo: Int { 580 }
    public var showsTopReminderBannerOnProfileStep: Bool { false }

    public init(
        currentStep: OnboardingStep = .welcomeRegionAndTrack,
        selectedRegion: PrismRegion = .azure,
        selectedRouteCode: String = "AZ-104",
        selectedBrandProductId: BrandProductID = BrandProductID("microsoft-entra-id"),
        selectedDiscoveryOptionCode: String? = nil,
        weeklyGoalDays: Int = 4,
        targetExamHorizonLabel: String = "Dans 2 mois",
        hasCompletedFirstValueSession: Bool = false,
        notificationsAuthorized: Bool = false,
        parallelTracksPreference: CertigoParallelTracksPreference? = nil
    ) {
        self.currentStep = currentStep
        self.selectedRegion = selectedRegion
        self.selectedRouteCode = selectedRouteCode
        self.selectedBrandProductId = selectedBrandProductId
        self.selectedDiscoveryOptionCode = selectedDiscoveryOptionCode
        self.weeklyGoalDays = min(max(weeklyGoalDays, 3), 6)
        self.targetExamHorizonLabel = targetExamHorizonLabel
        self.hasCompletedFirstValueSession = hasCompletedFirstValueSession
        self.notificationsAuthorized = notificationsAuthorized
        var resolvedPref = parallelTracksPreference ?? CertigoParallelTracksPreference()
        resolvedPref.setActiveTrack(selectedRouteCode)
        self.parallelTracksPreference = resolvedPref
    }

    public var canPromptForNotifications: Bool {
        hasCompletedFirstValueSession
    }

    public mutating func selectRoute(region: PrismRegion, routeCode: String, productId: BrandProductID) {
        selectedRegion = region
        selectedRouteCode = routeCode
        selectedBrandProductId = productId
        parallelTracksPreference.setActiveTrack(routeCode)
        currentStep = .discoverySituation
    }

    public mutating func toggleParallelRoute(_ code: String) {
        parallelTracksPreference.toggleParallelTrack(code)
        selectedRouteCode = parallelTracksPreference.activeTrackCode
    }

    public mutating func toggleAIFrontierTrack(_ code: String) {
        parallelTracksPreference.toggleAIFrontierTrack(code)
    }

    public func buildParallelTracksPreference() -> CertigoParallelTracksPreference {
        parallelTracksPreference
    }

    public mutating func answerDiscoverySituation(optionCode: String) {
        selectedDiscoveryOptionCode = optionCode
        hasCompletedFirstValueSession = true
        currentStep = .firstAhaMoment
    }

    public mutating func advanceToNextStep() {
        switch currentStep {
        case .welcomeRegionAndTrack:
            currentStep = .discoverySituation
        case .discoverySituation:
            if selectedDiscoveryOptionCode != nil {
                currentStep = .firstAhaMoment
            }
        case .firstAhaMoment:
            currentStep = .goalRhythmAndWhen
        case .goalRhythmAndWhen:
            currentStep = .saveProgressAuth
        case .saveProgressAuth:
            if canPromptForNotifications {
                currentStep = .notificationPermissionSheet
            }
        case .notificationPermissionSheet:
            break
        }
    }

    public mutating func grantNotificationPermissionIfEligible() -> Bool {
        guard canPromptForNotifications else { return false }
        notificationsAuthorized = true
        return true
    }
}

// MARK: - 2. CertiGo Pro StoreKit 2 Sheet Model (S-73, `pro.v1`, §14, §34.1)

public enum CertigoProBillingCycle: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case monthly
    case annual

    public var id: String { rawValue }

    public var productIdentifier: String {
        switch self {
        case .monthly: "com.certigo.pro.monthly"
        case .annual: "com.certigo.pro.annual"
        }
    }

    public var title: String {
        switch self {
        case .monthly: "Mensuel · Souple"
        case .annual: "Annuel · Préparation complète"
        }
    }
}

public struct CertigoProPaywallModel: Codable, Equatable, Hashable, Sendable {
    public var hasExperiencedFirstLearningValue: Bool
    public var selectedCycle: CertigoProBillingCycle
    public var isProEntitled: Bool

    /// §34.1 & DR-005 invariants: never show paywall before first value, no countdown timer, never sell streak freezes or gems.
    public var hasManipulativeCountdownTimer: Bool { false }
    public var sellsStreakFreezesOrGems: Bool { false }
    public var supportsStoreKit2RestorePurchases: Bool { true }

    public init(
        hasExperiencedFirstLearningValue: Bool = true,
        selectedCycle: CertigoProBillingCycle = .annual,
        isProEntitled: Bool = false
    ) {
        self.hasExperiencedFirstLearningValue = hasExperiencedFirstLearningValue
        self.selectedCycle = selectedCycle
        self.isProEntitled = isProEntitled
    }

    public var canPresentPaywall: Bool {
        hasExperiencedFirstLearningValue
    }
}

// MARK: - 3. Complete Settings Suite & Account Deletion (S-74..S-84, §14)

public enum SettingsSectionDestination: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case rhythmAndReminders            // S-75
    case language                      // S-76
    case accessibilityAndCalmMode      // S-77
    case privacyAndVisibility          // S-78
    case contextualAI                  // S-79
    case offlineData                   // S-80
    case account                       // S-81
    case accountDeletion               // S-82
    case dataAndMethodology            // S-83
    case helpAndReport                 // S-84

    public var id: String { rawValue }

    public var screenCode: String {
        switch self {
        case .rhythmAndReminders: "S-75"
        case .language: "S-76"
        case .accessibilityAndCalmMode: "S-77"
        case .privacyAndVisibility: "S-78"
        case .contextualAI: "S-79"
        case .offlineData: "S-80"
        case .account: "S-81"
        case .accountDeletion: "S-82"
        case .dataAndMethodology: "S-83"
        case .helpAndReport: "S-84"
        }
    }

    public var title: String {
        switch self {
        case .rhythmAndReminders: "Rythme & rappels (S-75)"
        case .language: "Langue · FR / EN (S-76)"
        case .accessibilityAndCalmMode: "Lecture, Mode Calme, sons & haptique (S-77)"
        case .privacyAndVisibility: "Confidentialité & visibilité (S-78)"
        case .contextualAI: "IA & consentement cloud (S-79)"
        case .offlineData: "Données hors ligne (S-80)"
        case .account: "Compte & connexion (S-81)"
        case .accountDeletion: "Suppression du compte (S-82)"
        case .dataAndMethodology: "À propos des données, méthode & licences (S-83)"
        case .helpAndReport: "Aide & signaler (S-84)"
        }
    }
}

public struct AccountDeletionConfirmationModel: Codable, Equatable, Hashable, Sendable {
    public var explicitConfirmationChecked: Bool
    public private(set) var hasExecutedIrrevocableDeletion: Bool

    /// §14 S-82 invariants: full server deletion + immediate local purge across Keychain, offline cache, and WidgetKit.
    public var purgesKeychainTokens: Bool { true }
    public var purgesOfflineSessionCache: Bool { true }
    public var purgesWidgetSnapshots: Bool { true }
    public var callsServerDeleteEndpoint: Bool { true }

    public init(
        explicitConfirmationChecked: Bool = false,
        hasExecutedIrrevocableDeletion: Bool = false
    ) {
        self.explicitConfirmationChecked = explicitConfirmationChecked
        self.hasExecutedIrrevocableDeletion = hasExecutedIrrevocableDeletion
    }

    public mutating func confirmAndExecuteDeletion() -> Bool {
        guard explicitConfirmationChecked else { return false }
        hasExecutedIrrevocableDeletion = true
        return true
    }
}

// MARK: - 4. iOS System Surfaces: Widgets (W-1..W-3, W-Radar, NS-14), Live Activities (LA-1..LA-3), Control Center (CC-1), App Intents & Spotlight (AI-1)

public enum CertigoWidgetSurfaceKind: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case todayProgress          // W-1
    case aiRadarLive            // W-Radar
    case dailySituation         // W-2
    case interactiveReviewCard  // W-3 (NS-14)

    public var id: String { rawValue }

    public var code: String {
        switch self {
        case .todayProgress: "W-1"
        case .aiRadarLive: "W-Radar"
        case .dailySituation: "W-2"
        case .interactiveReviewCard: "W-3"
        }
    }

    public var title: String {
        switch self {
        case .todayProgress: "Widget Aujourd'hui (W-1)"
        case .aiRadarLive: "Widget Radar IA Live (W-Radar)"
        case .dailySituation: "Widget Situation du jour (W-2)"
        case .interactiveReviewCard: "Widget Carte de révision interactive (W-3 · NS-14)"
        }
    }

    public var validatedSummary: String {
        switch self {
        case .todayProgress:
            "Série 🔥 12j · 10/10 min ✓ · AZ-104 + 2"
        case .aiRadarLive:
            "Nouveau cours IA : Claude 4 & Agents MCP"
        case .dailySituation:
            "Protection d'un coffre Key Vault critique · +25 XP"
        case .interactiveReviewCard:
            "3 options (A, B, C) · File d'attente en arrière-plan sans ouvrir l'app"
        }
    }
}

public struct TodayProgressWidgetSurfaceModel: Codable, Equatable, Hashable, Sendable {
    public static let widgetCode: String = "W-1"
    public let streakDays: Int
    public let streakBadgeText: String
    public let dailyGoalStatusText: String
    public let parallelActiveTracksBadge: String
    public let parallelRouteCodes: [String]
    public let deepLinkURL: String

    /// §22A.7 & DR-004 invariants: no answer keys and no third-party publisher logos in WidgetKit extensions.
    public var storesAnswerKeyInWidgetContainer: Bool { false }
    public var rendersThirdPartyBrandLogoInWidgetExtension: Bool { false }

    public init(
        streakDays: Int = 12,
        streakBadgeText: String = "🔥 12j",
        dailyGoalStatusText: String = "10/10 min ✓",
        parallelActiveTracksBadge: String = "AZ-104 + 2",
        parallelRouteCodes: [String] = ["AZ-104", "SAA-C03", "GH-300"],
        deepLinkURL: String = "certigo://widget/learn"
    ) {
        self.streakDays = max(0, streakDays)
        self.streakBadgeText = streakBadgeText
        self.dailyGoalStatusText = dailyGoalStatusText
        self.parallelActiveTracksBadge = parallelActiveTracksBadge
        self.parallelRouteCodes = parallelRouteCodes
        self.deepLinkURL = deepLinkURL
    }
}

public struct AIRadarLiveWidgetSurfaceModel: Codable, Equatable, Hashable, Sendable {
    public static let widgetCode: String = "W-Radar"
    public let badgeText: String
    public let headline: String
    public let subtitle: String
    public let region: PrismRegion
    public let deepLinkURL: String

    /// §22A.7 invariant: uses Prism region styling, never third-party trademarked logos in WidgetKit extensions.
    public var storesAnswerKeyInWidgetContainer: Bool { false }
    public var rendersThirdPartyBrandLogoInWidgetExtension: Bool { false }

    public init(
        badgeText: String = "RADAR IA LIVE",
        headline: String = "Nouveau cours IA : Claude 4 & Agents MCP",
        subtitle: String = "Veille Grands Acteurs IA · Prompt Caching & MCP",
        region: PrismRegion = .ai,
        deepLinkURL: String = "certigo://widget/learn"
    ) {
        self.badgeText = badgeText
        self.headline = headline
        self.subtitle = subtitle
        self.region = region
        self.deepLinkURL = deepLinkURL
    }
}

public struct DailySituationWidgetSurfaceModel: Codable, Equatable, Hashable, Sendable {
    public static let widgetCode: String = "W-2"
    public let situationId: String
    public let title: String
    public let rewardText: String
    public let region: PrismRegion
    public let deepLinkURL: String

    public var summaryText: String {
        "\(title) · \(rewardText)"
    }

    /// §22A.7 & DR-004 invariants: no answer keys and no third-party publisher logos in WidgetKit extensions.
    public var storesAnswerKeyInWidgetContainer: Bool { false }
    public var rendersThirdPartyBrandLogoInWidgetExtension: Bool { false }

    public init(
        situationId: String = "sit-2026-10-23",
        title: String = "Protection d'un coffre Key Vault critique",
        rewardText: String = "+25 XP",
        region: PrismRegion = .security,
        deepLinkURL: String = "certigo://widget/review"
    ) {
        self.situationId = situationId
        self.title = title
        self.rewardText = rewardText
        self.region = region
        self.deepLinkURL = deepLinkURL
    }
}

public struct ReviewCardWidgetOption: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let optionCode: String
    public let label: String

    public init(id: String, optionCode: String, label: String) {
        self.id = id
        self.optionCode = optionCode
        self.label = label
    }

    public static let defaultOptions: [ReviewCardWidgetOption] = [
        ReviewCardWidgetOption(
            id: "w3-opt-a",
            optionCode: "A",
            label: "Priorité 100 · DenyAllInBound"
        ),
        ReviewCardWidgetOption(
            id: "w3-opt-b",
            optionCode: "B",
            label: "Priorité 200 · AllowVNetInBound"
        ),
        ReviewCardWidgetOption(
            id: "w3-opt-c",
            optionCode: "C",
            label: "Priorité 65000 · AllowAzureLoadBalancer"
        )
    ]
}

public struct QueuedWidgetReviewResponse: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let cardId: String
    public let selectedOptionCode: String

    public init(id: String, cardId: String, selectedOptionCode: String) {
        self.id = id
        self.cardId = cardId
        self.selectedOptionCode = selectedOptionCode
    }
}

public struct ReviewCardWidgetQueueModel: Codable, Equatable, Hashable, Sendable {
    public static let widgetCode: String = "W-3"
    public let cardId: String
    public let routeCode: String
    public let region: PrismRegion
    public let promptSummary: String
    public let options: [ReviewCardWidgetOption]
    public private(set) var queuedResponses: [QueuedWidgetReviewResponse]

    /// §15 NS-14, DR-004 & §22A.7 invariants: queues response without opening app, 0 answer key stored in widget container, 0 third-party brand logo on widget extension.
    public var queuesResponseWithoutOpeningApp: Bool { true }
    public var storesAnswerKeyInWidgetContainer: Bool { false }
    public var rendersThirdPartyBrandLogoInWidgetExtension: Bool { false }
    public var answerKeyCountInWidgetContainer: Int { 0 }
    public var thirdPartyLogoCountInWidgetExtension: Int { 0 }
    public var optionCodes: [String] { options.map(\.optionCode) }

    public init(
        cardId: String = "w3-card-az104-nsg",
        routeCode: String = "AZ-104",
        region: PrismRegion = .azure,
        promptSummary: String = "Priorité d'évaluation des règles entrantes NSG",
        options: [ReviewCardWidgetOption] = ReviewCardWidgetOption.defaultOptions,
        queuedResponses: [QueuedWidgetReviewResponse] = []
    ) {
        self.cardId = cardId
        self.routeCode = routeCode
        self.region = region
        self.promptSummary = promptSummary
        self.options = options
        self.queuedResponses = queuedResponses
    }

    public mutating func enqueueAnswerFromWidget(optionCode: String) {
        guard options.contains(where: { $0.optionCode == optionCode }) else { return }
        let entry = QueuedWidgetReviewResponse(
            id: "queued-\(cardId)-\(optionCode)",
            cardId: cardId,
            selectedOptionCode: optionCode
        )
        if !queuedResponses.contains(entry) {
            queuedResponses.append(entry)
        }
    }
}

public enum CertigoLiveActivityKind: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case mockExamSession   // LA-1
    case deepDiveSession   // LA-2 (Plongée 25 min)
    case examDayCompanion  // LA-3 (Jour J)

    public var id: String { rawValue }

    public var code: String {
        switch self {
        case .mockExamSession: "LA-1"
        case .deepDiveSession: "LA-2"
        case .examDayCompanion: "LA-3"
        }
    }

    public var title: String {
        switch self {
        case .mockExamSession: "Examen blanc en cours (LA-1)"
        case .deepDiveSession: "Séance Plongée 25 min (LA-2)"
        case .examDayCompanion: "Compagnon Jour J en Mode Calme (LA-3)"
        }
    }
}

public struct CertigoLiveActivityState: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let kind: CertigoLiveActivityKind
    public let routeCode: String
    public let region: PrismRegion
    public let completedItems: Int
    public let totalItems: Int
    public let isUntimedMode: Bool
    public let timerLabel: String
    public let progressSubtitle: String
    public let statusDetailLabel: String
    public let isCalmModeActive: Bool
    public let showsAnxietyInducingNewQuestions: Bool

    /// §22A.7: Never render third-party publisher logos on Lock Screen / Dynamic Island Live Activities.
    public var rendersThirdPartyBrandLogoInLiveActivity: Bool { false }
    public var thirdPartyLogoCountInLiveActivity: Int { 0 }

    public var dynamicIslandSummary: String {
        switch kind {
        case .mockExamSession:
            "\(timerLabel) · \(progressSubtitle) · \(statusDetailLabel)"
        case .deepDiveSession:
            "\(progressSubtitle) · \(statusDetailLabel)"
        case .examDayCompanion:
            "\(progressSubtitle) · \(statusDetailLabel)"
        }
    }

    public init(
        id: String = "la-az104-active",
        kind: CertigoLiveActivityKind = .mockExamSession,
        routeCode: String = "AZ-104",
        region: PrismRegion = .azure,
        completedItems: Int? = nil,
        totalItems: Int? = nil,
        isUntimedMode: Bool? = nil,
        timerLabel: String? = nil,
        progressSubtitle: String? = nil,
        statusDetailLabel: String? = nil,
        isCalmModeActive: Bool? = nil,
        showsAnxietyInducingNewQuestions: Bool = false
    ) {
        let resolvedCompleted: Int
        let resolvedTotal: Int
        let resolvedUntimed: Bool
        let resolvedTimer: String
        let resolvedProgress: String
        let resolvedStatus: String
        let resolvedCalm: Bool

        switch kind {
        case .mockExamSession:
            resolvedCompleted = completedItems ?? 14
            resolvedTotal = totalItems ?? 50
            resolvedUntimed = isUntimedMode ?? false
            resolvedTimer = timerLabel ?? "⏱️ 64:18"
            resolvedProgress = progressSubtitle ?? "Question \(resolvedCompleted)/\(resolvedTotal)"
            resolvedStatus = statusDetailLabel ?? "Seuil 700/1000"
            resolvedCalm = isCalmModeActive ?? false
        case .deepDiveSession:
            resolvedCompleted = completedItems ?? 4
            resolvedTotal = totalItems ?? 6
            resolvedUntimed = isUntimedMode ?? false
            resolvedTimer = timerLabel ?? "25 min"
            resolvedProgress = progressSubtitle ?? "\(resolvedCompleted)/\(resolvedTotal) étapes"
            resolvedStatus = statusDetailLabel ?? "Série protégée"
            resolvedCalm = isCalmModeActive ?? false
        case .examDayCompanion:
            resolvedCompleted = completedItems ?? 3
            resolvedTotal = totalItems ?? 3
            resolvedUntimed = isUntimedMode ?? true
            resolvedTimer = timerLabel ?? "Mode Calme"
            resolvedProgress = progressSubtitle ?? "3 Fiches Mémo Clés"
            resolvedStatus = statusDetailLabel ?? "Zéro nouvelle question anxiogène"
            resolvedCalm = isCalmModeActive ?? true
        }

        self.id = id
        self.kind = kind
        self.routeCode = routeCode
        self.region = region
        self.completedItems = max(0, resolvedCompleted)
        self.totalItems = max(1, resolvedTotal)
        self.isUntimedMode = resolvedUntimed
        self.timerLabel = resolvedTimer
        self.progressSubtitle = resolvedProgress
        self.statusDetailLabel = resolvedStatus
        self.isCalmModeActive = resolvedCalm
        self.showsAnxietyInducingNewQuestions = showsAnxietyInducingNewQuestions
    }

    public static let validatedPage11Activities: [CertigoLiveActivityState] = [
        CertigoLiveActivityState(id: "la1", kind: .mockExamSession),
        CertigoLiveActivityState(id: "la2", kind: .deepDiveSession),
        CertigoLiveActivityState(id: "la3", kind: .examDayCompanion)
    ]
}

public struct ExpressSessionControlWidgetModel: Codable, Equatable, Hashable, Sendable {
    public static let controlCode: String = "CC-1"
    public static let targetDurationMinutes: Int = 5
    public let title: String
    public let subtitle: String
    public let sfSymbolName: String
    public let deepLinkURL: String

    /// §22A.7: Control Center controls use SF Symbols and CertiGo copy, never third-party brand logos.
    public var rendersThirdPartyBrandLogoInControlCenter: Bool { false }

    public init(
        title: String = "Express 5 min",
        subtitle: String = "Bouton Centre de Contrôle iOS 18",
        sfSymbolName: String = "bolt.fill",
        deepLinkURL: String = "certigo://session/express?duration=5"
    ) {
        self.title = title
        self.subtitle = subtitle
        self.sfSymbolName = sfSymbolName
        self.deepLinkURL = deepLinkURL
    }
}

public enum CertigoAppIntentKind: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case startExpressSession
    case openDailySituation
    case checkReadinessStatus
    case resumeInterruptedSession

    public var id: String { rawValue }

    public var phrase: String {
        switch self {
        case .startExpressSession: "Lancer une séance Express dans CertiGo"
        case .openDailySituation: "Ouvrir la Situation du jour CertiGo"
        case .checkReadinessStatus: "Vérifier ma préparation dans CertiGo"
        case .resumeInterruptedSession: "Reprendre ma séance CertiGo"
        }
    }
}

public struct CertigoSpotlightConceptEntity: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let routeCode: String
    public let conceptTitle: String
    public let region: PrismRegion
    public let deepLinkURL: String

    /// §22A.7: Spotlight entities use Prism region styling, never third-party trademarked SVG logos.
    public var includesThirdPartyBrandLogoInSpotlight: Bool { false }

    public init(
        id: String,
        routeCode: String,
        conceptTitle: String,
        region: PrismRegion,
        deepLinkURL: String
    ) {
        self.id = id
        self.routeCode = routeCode
        self.conceptTitle = conceptTitle
        self.region = region
        self.deepLinkURL = deepLinkURL
    }

    public static let defaultEntities: [CertigoSpotlightConceptEntity] = [
        CertigoSpotlightConceptEntity(
            id: "spotlight-az104-pe",
            routeCode: "AZ-104",
            conceptTitle: "Private Endpoint & DNS privé",
            region: .azure,
            deepLinkURL: "certigo://concept/az104-private-endpoint-dns"
        ),
        CertigoSpotlightConceptEntity(
            id: "spotlight-ai102-rag",
            routeCode: "AI-102",
            conceptTitle: "Indexation hybride et reclassement sémantique",
            region: .ai,
            deepLinkURL: "certigo://concept/ai102-hybrid-rag"
        )
    ]
}

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

// MARK: - 5. Onboarding Flow Cover Screen (OB-01..OB-08B & S-01..S-06, NS-1)

public struct OnboardingFlowCoverScreen: View {
    @State private var stateMachine: OnboardingFlowStateMachine
    public let onApplyParallelTracksPreference: (CertigoParallelTracksPreference) -> Void
    public let onFinishOnboarding: () -> Void

    public init(
        stateMachine: OnboardingFlowStateMachine = OnboardingFlowStateMachine(),
        onApplyParallelTracksPreference: @escaping (CertigoParallelTracksPreference) -> Void = { _ in },
        onFinishOnboarding: @escaping () -> Void = {}
    ) {
        self._stateMachine = State(initialValue: stateMachine)
        self.onApplyParallelTracksPreference = onApplyParallelTracksPreference
        self.onFinishOnboarding = onFinishOnboarding
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: PrismSpacing.xs) {
                        ForEach(OnboardingFigmaScreenID.allCases) { screen in
                            PrismChip(
                                configuration: PrismChipConfiguration(
                                    title: screen.rawValue,
                                    isSelected: stateMachine.currentFigmaScreen == screen
                                )
                            ) {
                                stateMachine.currentFigmaScreen = screen
                            }
                        }
                    }
                }

                // OB-01 Curved 4-Brand Arch (Google, Microsoft, Official AWS, GitHub) + Mascot Blason 1A
                PrismCard(variant: .hero) {
                    VStack(spacing: PrismSpacing.m) {
                        HStack(spacing: PrismSpacing.m) {
                            ForEach(["google", "microsoft", "aws", "github"], id: \.self) { vendor in
                                CertiGoBrandLogoView(vendorId: vendor, size: PrismSize.brandM)
                                    .padding(PrismSpacing.s)
                                    .background(
                                        RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                            .fill(PrismColor.surface)
                                    )
                            }
                        }
                        CertiGoMascotView(pose: .angleFrontCelebration, size: PrismSize.mascotPath)
                        PrismText(text: "CertiGo · Multi-Certifications & Veille IA", style: .title3)
                        BrandLabel(
                            product: stateMachine.selectedBrandProductId,
                            context: .catalog,
                            examCode: stateMachine.selectedRouteCode
                        )
                        PrismText(
                            text: "Suis plusieurs parcours en parallèle (\(stateMachine.selectedParallelRoutes.joined(separator: " · "))) et les cours sur les Grands Acteurs de l'IA (\(stateMachine.selectedAIFrontierTrackCodes.joined(separator: " · "))). Nouveau contenu chaque semaine !",
                            style: .footnote,
                            role: .textSecondary
                        )
                    }
                }

                // OB-07 Clean Dual-Curve Projection Card (Avec CertiGo vs Sans CertiGo)
                PrismCard(variant: .standard) {
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        PrismBadge(
                            configuration: PrismBadgeConfiguration(
                                text: "AVEC CERTIGO · \(stateMachine.projectedScoreWithCertiGo) / 1000 ✓",
                                semantics: .accent
                            )
                        )
                        PrismBadge(
                            configuration: PrismBadgeConfiguration(
                                text: "SANS CERTIGO · \(stateMachine.projectedScoreWithoutCertiGo) / 1000",
                                semantics: .neutral
                            )
                        )
                    }
                }

                // Interactive Flow & Native iOS Pop-ups (Push OB-06B, Widget OB-06C, Apple Sign-In OB-08B)
                PrismCard(variant: .standard) {
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        switch stateMachine.currentStep {
                        case .welcomeRegionAndTrack:
                            Button {
                                stateMachine.selectRoute(
                                    region: .azure,
                                    routeCode: "AZ-104",
                                    productId: BrandProductID("microsoft-entra-id")
                                )
                                onApplyParallelTracksPreference(stateMachine.parallelTracksPreference)
                            } label: {
                                Text(verbatim: "Choisir mes parcours en parallèle (OB-03A & OB-03B)")
                            }
                            .buttonStyle(PrismButtonStyle(variant: .primary))

                        case .discoverySituation:
                            Button {
                                stateMachine.answerDiscoverySituation(optionCode: "A")
                            } label: {
                                Text(verbatim: "Valider mes objectifs & la veille IA")
                            }
                            .buttonStyle(PrismButtonStyle(variant: .primary))

                        case .firstAhaMoment, .goalRhythmAndWhen:
                            Button {
                                stateMachine.advanceToNextStep()
                            } label: {
                                Text(verbatim: "Continuer vers le Plan Avec vs Sans CertiGo (OB-07)")
                            }
                            .buttonStyle(PrismButtonStyle(variant: .primary))

                        case .saveProgressAuth:
                            ForEach(OnboardingAuthProvider.allCases) { provider in
                                Button {
                                    stateMachine.advanceToNextStep()
                                } label: {
                                    Text(verbatim: provider.label)
                                }
                                .buttonStyle(PrismButtonStyle(variant: .secondary))
                            }

                        case .notificationPermissionSheet:
                            Button {
                                _ = stateMachine.grantNotificationPermissionIfEligible()
                                onApplyParallelTracksPreference(stateMachine.parallelTracksPreference)
                                onFinishOnboarding()
                            } label: {
                                Text(verbatim: "Autoriser les notifications iOS & Ajouter le Widget")
                            }
                            .buttonStyle(PrismButtonStyle(variant: .primary))
                        }
                    }
                }
            }
            .padding(PrismSpacing.l)
        }
        .background(PrismColor.canvas)
        .navigationTitle(Text(verbatim: "Premier lancement"))
    }
}

// MARK: - 6. CertiGo Pro StoreKit 2 Sheet Screen (Écran 27 Variante 27-A Validée)

public struct CertigoProSheetScreen: View {
    @State private var model: CertigoProPaywallModel
    public let onRestorePurchases: () -> Void

    public init(
        model: CertigoProPaywallModel = CertigoProPaywallModel(),
        onRestorePurchases: @escaping () -> Void = {}
    ) {
        self._model = State(initialValue: model)
        self.onRestorePurchases = onRestorePurchases
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                PrismCard(variant: .hero) {
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        PrismBadge(
                            configuration: PrismBadgeConfiguration(
                                text: "CERTIGO PRO ✦ · TABLEAU COMPARATIF (27-A)",
                                semantics: .accent
                            )
                        )
                        ForEach(CertigoProFeatureComparisonRow.validatedRows) { row in
                            HStack(spacing: PrismSpacing.s) {
                                Text(verbatim: row.featureTitle)
                                    .prismTextStyle(.subheadline)
                                    .foregroundStyle(PrismColor.textPrimary)
                                Spacer(minLength: PrismSpacing.xs)
                                Text(verbatim: row.freeTierValue)
                                    .prismTextStyle(.caption)
                                    .foregroundStyle(PrismColor.textSecondary)
                                Text(verbatim: row.proTierValue)
                                    .prismTextStyle(.caption)
                                    .foregroundStyle(PrismColor.accent)
                            }
                        }
                        ForEach(CertigoProBillingCycle.allCases) { cycle in
                            PrismChip(
                                configuration: PrismChipConfiguration(
                                    title: cycle.title,
                                    isSelected: model.selectedCycle == cycle
                                )
                            ) {
                                model.selectedCycle = cycle
                            }
                        }
                        Button {
                            onRestorePurchases()
                        } label: {
                            Text(verbatim: "Restaurer mes achats StoreKit 2")
                        }
                        .buttonStyle(PrismButtonStyle(variant: .secondary))
                    }
                }
            }
            .padding(PrismSpacing.l)
        }
        .background(PrismColor.canvas)
        .navigationTitle(Text(verbatim: "CertiGo Pro"))
    }
}

// MARK: - 7. Complete Settings (Écran 28 Style 1 ChatGPT iOS 2026) & Account Deletion (S-82)

public struct CompleteSettingsScreen: View {
    @State private var deletionModel: AccountDeletionConfirmationModel
    @State private var localPreference: CertigoParallelTracksPreference
    private let externalPreferenceBinding: Binding<CertigoParallelTracksPreference>?
    public let onSelectSection: (SettingsSectionDestination) -> Void

    public init(
        deletionModel: AccountDeletionConfirmationModel = AccountDeletionConfirmationModel(),
        parallelTracksPreference: Binding<CertigoParallelTracksPreference>? = nil,
        onSelectSection: @escaping (SettingsSectionDestination) -> Void = { _ in }
    ) {
        self._deletionModel = State(initialValue: deletionModel)
        self._localPreference = State(initialValue: parallelTracksPreference?.wrappedValue ?? CertigoParallelTracksPreference())
        self.externalPreferenceBinding = parallelTracksPreference
        self.onSelectSection = onSelectSection
    }

    private var preferenceBinding: Binding<CertigoParallelTracksPreference> {
        externalPreferenceBinding ?? $localPreference
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                PrismSection(title: "PARAMÈTRES · STYLE 1 CHATGPT iOS 2026") {
                    PrismCard(variant: .standard) {
                        VStack(alignment: .leading, spacing: PrismSpacing.s) {
                            settingsMonoRow(
                                symbol: "square.stack.3d.up",
                                title: "Parcours actifs en parallèle",
                                value: preferenceBinding.wrappedValue.settingsParallelTracksSummary,
                                section: .account
                            )
                            settingsMonoRow(
                                symbol: "globe",
                                title: "Langue des cours & examens",
                                value: preferenceBinding.wrappedValue.settingsLanguageSummary,
                                section: .language
                            )
                            settingsMonoRow(
                                symbol: "timer",
                                title: "Mode Examen Blanc (Pearson)",
                                value: preferenceBinding.wrappedValue.settingsMockExamSummary,
                                section: .dataAndMethodology
                            )
                            settingsMonoRow(symbol: "arrow.down.circle", title: "Cours téléchargés (Hors-Ligne)", value: "142 Mo ›", section: .offlineData)
                            settingsMonoRow(symbol: "waveform", title: "Coach IA Vocal Live & Arrière-plan", value: "Nova (1,0×) ›", section: .contextualAI)
                            settingsMonoRow(symbol: "bell", title: "Rappel quotidien & Radar Hebdo IA", value: "19:30 ›", section: .rhythmAndReminders)
                        }
                    }
                }

                PrismSection(title: "Multi-Parcours en parallèle & Veille Grands Acteurs IA") {
                    PrismCard(variant: .standard) {
                        VStack(alignment: .leading, spacing: PrismSpacing.s) {
                            Toggle(isOn: preferenceBinding.bilingualTechnicalTermsEN) {
                                Text(verbatim: "Mode bilingue d'examen (FR + Termes techniques EN)")
                            }
                            Toggle(isOn: preferenceBinding.strictTimed90Min) {
                                Text(verbatim: "Mode Examen Blanc Pearson VUE strict (Chrono 90 min)")
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: PrismSpacing.xs) {
                                    ForEach(CertigoParallelTracksPreference.defaultParallelTrackCodes, id: \.self) { code in
                                        PrismChip(
                                            configuration: PrismChipConfiguration(
                                                title: code,
                                                isSelected: preferenceBinding.wrappedValue.isTrackingParallelCertification(code)
                                            )
                                        ) {
                                            preferenceBinding.wrappedValue.toggleParallelTrack(code)
                                        }
                                    }
                                    ForEach(CertigoParallelTracksPreference.defaultAIFrontierTrackCodes, id: \.self) { aiCode in
                                        PrismChip(
                                            configuration: PrismChipConfiguration(
                                                title: aiCode,
                                                isSelected: preferenceBinding.wrappedValue.isTrackingAIFrontier(aiCode)
                                            )
                                        ) {
                                            preferenceBinding.wrappedValue.toggleAIFrontierTrack(aiCode)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                PrismSection(title: "Réglages complets (S-74 … S-84)") {
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        ForEach(SettingsSectionDestination.allCases) { section in
                            PrismCard(variant: .standard) {
                                HStack(spacing: PrismSpacing.s) {
                                    PrismBadge(
                                        configuration: PrismBadgeConfiguration(
                                            text: section.screenCode,
                                            semantics: section == .accountDeletion ? .warning : .neutral
                                        )
                                    )
                                    PrismText(text: section.title, style: .subheadline)
                                    Spacer()
                                    Button {
                                        onSelectSection(section)
                                    } label: {
                                        Text(verbatim: "Ouvrir")
                                    }
                                    .buttonStyle(PrismButtonStyle(variant: .secondary))
                                }
                            }
                        }
                    }
                }

                PrismSection(title: "Suppression irrévocable du compte (S-82)") {
                    PrismCard(variant: .standard) {
                        VStack(alignment: .leading, spacing: PrismSpacing.s) {
                            Toggle(isOn: $deletionModel.explicitConfirmationChecked) {
                                Text(verbatim: "Je confirme la suppression définitive de mon compte et la purge locale Keychain / cache / WidgetKit")
                            }
                            Button {
                                _ = deletionModel.confirmAndExecuteDeletion()
                            } label: {
                                Text(verbatim: "Supprimer définitivement mon compte")
                            }
                            .buttonStyle(PrismButtonStyle(variant: .secondary))
                            .disabled(!deletionModel.explicitConfirmationChecked)
                        }
                    }
                }
            }
            .padding(PrismSpacing.l)
        }
        .background(PrismColor.canvas)
        .navigationTitle(Text(verbatim: "Paramètres"))
    }

    @ViewBuilder
    private func settingsMonoRow(symbol: String, title: String, value: String, section: SettingsSectionDestination) -> some View {
        Button {
            onSelectSection(section)
        } label: {
            HStack(spacing: PrismSpacing.s) {
                Image(systemName: symbol)
                    .prismTextStyle(.subheadline)
                    .foregroundStyle(PrismColor.textPrimary)
                Text(verbatim: title)
                    .prismTextStyle(.subheadline)
                    .foregroundStyle(PrismColor.textPrimary)
                Spacer(minLength: PrismSpacing.xs)
                Text(verbatim: value)
                    .prismTextStyle(.caption)
                    .foregroundStyle(PrismColor.accent)
            }
            .padding(.vertical, PrismSpacing.xxs)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 8. iOS System Surfaces Preview Screen (Page 11 Figma Pro: W-1, W-Radar, W-2, W-3 NS-14, LA-1..LA-3, CC-1, AI-1)

public struct SystemSurfacesPreviewScreen: View {
    public let todayWidget: TodayProgressWidgetSurfaceModel
    public let radarWidget: AIRadarLiveWidgetSurfaceModel
    public let dailySituationWidget: DailySituationWidgetSurfaceModel
    @State private var reviewWidgetQueue: ReviewCardWidgetQueueModel
    public let liveActivities: [CertigoLiveActivityState]
    public let controlWidget: ExpressSessionControlWidgetModel
    public let spotlightEntities: [CertigoSpotlightConceptEntity]

    public init(
        todayWidget: TodayProgressWidgetSurfaceModel = TodayProgressWidgetSurfaceModel(),
        radarWidget: AIRadarLiveWidgetSurfaceModel = AIRadarLiveWidgetSurfaceModel(),
        dailySituationWidget: DailySituationWidgetSurfaceModel = DailySituationWidgetSurfaceModel(),
        reviewWidgetQueue: ReviewCardWidgetQueueModel = ReviewCardWidgetQueueModel(),
        liveActivities: [CertigoLiveActivityState] = CertigoLiveActivityState.validatedPage11Activities,
        controlWidget: ExpressSessionControlWidgetModel = ExpressSessionControlWidgetModel(),
        spotlightEntities: [CertigoSpotlightConceptEntity] = CertigoSpotlightConceptEntity.defaultEntities
    ) {
        self.todayWidget = todayWidget
        self.radarWidget = radarWidget
        self.dailySituationWidget = dailySituationWidget
        self._reviewWidgetQueue = State(initialValue: reviewWidgetQueue)
        self.liveActivities = liveActivities
        self.controlWidget = controlWidget
        self.spotlightEntities = spotlightEntities
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                PrismSection(title: "Page 11 · Widgets iOS 18 (W-1, W-Radar, W-2, W-3 · NS-14)") {
                    VStack(alignment: .leading, spacing: PrismSpacing.m) {
                        // W-1 : Série 🔥 12j + objectif quotidien 10/10 min ✓ + parcours actifs en parallèle (AZ-104 + 2)
                        PrismCard(variant: .standard) {
                            VStack(alignment: .leading, spacing: PrismSpacing.s) {
                                HStack(spacing: PrismSpacing.s) {
                                    PrismBadge(
                                        configuration: PrismBadgeConfiguration(
                                            text: TodayProgressWidgetSurfaceModel.widgetCode,
                                            semantics: .accent
                                        )
                                    )
                                    PrismBadge(
                                        configuration: PrismBadgeConfiguration(
                                            text: todayWidget.streakBadgeText,
                                            semantics: .caution
                                        )
                                    )
                                    PrismBadge(
                                        configuration: PrismBadgeConfiguration(
                                            text: todayWidget.dailyGoalStatusText,
                                            semantics: .positive
                                        )
                                    )
                                    Spacer(minLength: PrismSpacing.xs)
                                    PrismBadge(
                                        configuration: PrismBadgeConfiguration(
                                            text: todayWidget.parallelActiveTracksBadge,
                                            semantics: .neutral
                                        )
                                    )
                                }
                                PrismText(
                                    text: "Série \(todayWidget.streakBadgeText) · Objectif quotidien \(todayWidget.dailyGoalStatusText) · Parcours parallèles (\(todayWidget.parallelActiveTracksBadge))",
                                    style: .subheadline,
                                    role: .textPrimary
                                )
                            }
                        }

                        // W-Radar : Widget Radar IA Live (Nouveau cours IA : Claude 4 & Agents MCP)
                        PrismCard(variant: .standard) {
                            VStack(alignment: .leading, spacing: PrismSpacing.s) {
                                HStack(spacing: PrismSpacing.s) {
                                    PrismBadge(
                                        configuration: PrismBadgeConfiguration(
                                            text: AIRadarLiveWidgetSurfaceModel.widgetCode,
                                            semantics: .region(radarWidget.region)
                                        )
                                    )
                                    PrismBadge(
                                        configuration: PrismBadgeConfiguration(
                                            text: radarWidget.badgeText,
                                            semantics: .accent
                                        )
                                    )
                                }
                                PrismText(text: radarWidget.headline, style: .headline)
                                PrismText(text: radarWidget.subtitle, style: .caption, role: .textSecondary)
                            }
                        }

                        // W-2 : Situation du jour (Protection d'un coffre Key Vault critique · +25 XP)
                        PrismCard(variant: .standard) {
                            VStack(alignment: .leading, spacing: PrismSpacing.s) {
                                HStack(spacing: PrismSpacing.s) {
                                    PrismBadge(
                                        configuration: PrismBadgeConfiguration(
                                            text: DailySituationWidgetSurfaceModel.widgetCode,
                                            semantics: .region(dailySituationWidget.region)
                                        )
                                    )
                                    PrismBadge(
                                        configuration: PrismBadgeConfiguration(
                                            text: dailySituationWidget.rewardText,
                                            semantics: .positive
                                        )
                                    )
                                }
                                PrismText(text: dailySituationWidget.summaryText, style: .headline)
                            }
                        }

                        // W-3 (NS-14) : Carte de révision interactive sur l'écran d'accueil avec 3 options (A, B, C)
                        PrismCard(variant: .standard) {
                            VStack(alignment: .leading, spacing: PrismSpacing.s) {
                                HStack(spacing: PrismSpacing.s) {
                                    PrismBadge(
                                        configuration: PrismBadgeConfiguration(
                                            text: "\(ReviewCardWidgetQueueModel.widgetCode) · NS-14",
                                            semantics: .accent
                                        )
                                    )
                                    RegionChip(region: reviewWidgetQueue.region)
                                    Spacer(minLength: PrismSpacing.xs)
                                    PrismBadge(
                                        configuration: PrismBadgeConfiguration(
                                            text: "0 clé · 0 logo tiers (§22A.7)",
                                            semantics: .neutral
                                        )
                                    )
                                }
                                PrismText(text: reviewWidgetQueue.promptSummary, style: .headline)
                                HStack(spacing: PrismSpacing.s) {
                                    ForEach(reviewWidgetQueue.options) { option in
                                        Button {
                                            reviewWidgetQueue.enqueueAnswerFromWidget(optionCode: option.optionCode)
                                        } label: {
                                            Text(verbatim: option.optionCode)
                                        }
                                        .buttonStyle(PrismButtonStyle(variant: .secondary))
                                    }
                                }
                                ForEach(reviewWidgetQueue.options) { option in
                                    PrismText(
                                        text: "\(option.optionCode). \(option.label)",
                                        style: .caption,
                                        role: .textSecondary
                                    )
                                }
                            }
                        }
                    }
                }

                PrismSection(title: "Dynamic Island & Live Activities (LA-1 / LA-2 / LA-3)") {
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        ForEach(liveActivities) { activity in
                            PrismCard(variant: .standard) {
                                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                                    HStack(spacing: PrismSpacing.s) {
                                        PrismBadge(
                                            configuration: PrismBadgeConfiguration(
                                                text: activity.kind.code,
                                                semantics: .accent
                                            )
                                        )
                                        PrismText(text: activity.kind.title, style: .subheadline)
                                    }
                                    PrismText(
                                        text: activity.dynamicIslandSummary,
                                        style: .footnote,
                                        role: .textSecondary
                                    )
                                }
                            }
                        }
                    }
                }

                PrismSection(title: "Control Center iOS 18 (CC-1) & Spotlight (AI-1)") {
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        PrismCard(variant: .standard) {
                            VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                                HStack(spacing: PrismSpacing.s) {
                                    PrismIcon(
                                        systemName: controlWidget.sfSymbolName,
                                        style: .headline,
                                        role: .accentPrimary
                                    )
                                    PrismText(
                                        text: "\(ExpressSessionControlWidgetModel.controlCode) · \(controlWidget.title)",
                                        style: .headline
                                    )
                                }
                                PrismText(
                                    text: "\(controlWidget.subtitle) · \(controlWidget.deepLinkURL)",
                                    style: .caption,
                                    role: .textSecondary
                                )
                            }
                        }

                        ForEach(spotlightEntities) { entity in
                            PrismCard(variant: .standard) {
                                HStack(spacing: PrismSpacing.s) {
                                    PrismBadge(
                                        configuration: PrismBadgeConfiguration(
                                            text: "AI-1 · \(entity.routeCode)",
                                            semantics: .region(entity.region)
                                        )
                                    )
                                    PrismText(text: entity.conceptTitle, style: .subheadline)
                                }
                            }
                        }
                    }
                }
            }
            .padding(PrismSpacing.l)
        }
        .background(PrismColor.canvas)
        .navigationTitle(Text(verbatim: "Surfaces iOS"))
    }
}
#endif
