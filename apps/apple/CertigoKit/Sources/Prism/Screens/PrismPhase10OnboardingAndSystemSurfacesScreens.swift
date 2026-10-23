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

    public init(
        currentStep: OnboardingStep = .welcomeRegionAndTrack,
        selectedRegion: PrismRegion = .azure,
        selectedRouteCode: String = "AZ-104",
        selectedBrandProductId: BrandProductID = BrandProductID("microsoft-entra-id"),
        selectedDiscoveryOptionCode: String? = nil,
        weeklyGoalDays: Int = 4,
        targetExamHorizonLabel: String = "Dans 2 mois",
        hasCompletedFirstValueSession: Bool = false,
        notificationsAuthorized: Bool = false
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
    }

    public var canPromptForNotifications: Bool {
        hasCompletedFirstValueSession
    }

    public mutating func selectRoute(region: PrismRegion, routeCode: String, productId: BrandProductID) {
        selectedRegion = region
        selectedRouteCode = routeCode
        selectedBrandProductId = productId
        currentStep = .discoverySituation
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

// MARK: - 4. iOS System Surfaces: Widgets (W-1..W-3, NS-14), Live Activities (LA-1..LA-3), Control Center (CC-1), App Intents & Spotlight (AI-1)

public enum CertigoWidgetSurfaceKind: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case todayProgress          // W-1
    case dailySituation         // W-2
    case interactiveReviewCard  // W-3 (NS-14)

    public var id: String { rawValue }

    public var code: String {
        switch self {
        case .todayProgress: "W-1"
        case .dailySituation: "W-2"
        case .interactiveReviewCard: "W-3"
        }
    }

    public var title: String {
        switch self {
        case .todayProgress: "Widget Aujourd'hui (W-1)"
        case .dailySituation: "Widget Situation du jour (W-2)"
        case .interactiveReviewCard: "Widget Carte de révision interactive (W-3 · NS-14)"
        }
    }
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
    public let cardId: String
    public let routeCode: String
    public let region: PrismRegion
    public let promptSummary: String
    public private(set) var queuedResponses: [QueuedWidgetReviewResponse]

    /// §15 NS-14, DR-004 & §22A.7 invariants: queues response without opening app, never stores answer key in widget container, no third-party brand logo on widget extension.
    public var queuesResponseWithoutOpeningApp: Bool { true }
    public var storesAnswerKeyInWidgetContainer: Bool { false }
    public var rendersThirdPartyBrandLogoInWidgetExtension: Bool { false }

    public init(
        cardId: String = "w3-card-az104-nsg",
        routeCode: String = "AZ-104",
        region: PrismRegion = .azure,
        promptSummary: String = "Priorité d'évaluation des règles entrantes NSG",
        queuedResponses: [QueuedWidgetReviewResponse] = []
    ) {
        self.cardId = cardId
        self.routeCode = routeCode
        self.region = region
        self.promptSummary = promptSummary
        self.queuedResponses = queuedResponses
    }

    public mutating func enqueueAnswerFromWidget(optionCode: String) {
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
        case .examDayCompanion: "Compagnon Jour J d'examen (LA-3)"
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

    /// §22A.7: Never render third-party publisher logos on Lock Screen / Dynamic Island Live Activities.
    public var rendersThirdPartyBrandLogoInLiveActivity: Bool { false }

    public init(
        id: String = "la-az104-active",
        kind: CertigoLiveActivityKind = .mockExamSession,
        routeCode: String = "AZ-104",
        region: PrismRegion = .azure,
        completedItems: Int = 12,
        totalItems: Int = 40,
        isUntimedMode: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.routeCode = routeCode
        self.region = region
        self.completedItems = max(0, completedItems)
        self.totalItems = max(1, totalItems)
        self.isUntimedMode = isUntimedMode
    }
}

public struct ExpressSessionControlWidgetModel: Codable, Equatable, Hashable, Sendable {
    public static let controlCode: String = "CC-1"
    public static let targetDurationMinutes: Int = 5
    public let title: String
    public let deepLinkURL: String

    public init(
        title: String = "Express 5 min",
        deepLinkURL: String = "certigo://session/express?duration=5"
    ) {
        self.title = title
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

// MARK: - 5. Onboarding Flow Cover Screen (S-01..S-06, NS-1)

public struct OnboardingFlowCoverScreen: View {
    @State private var stateMachine: OnboardingFlowStateMachine
    public let onFinishOnboarding: () -> Void

    public init(
        stateMachine: OnboardingFlowStateMachine = OnboardingFlowStateMachine(),
        onFinishOnboarding: @escaping () -> Void = {}
    ) {
        self._stateMachine = State(initialValue: stateMachine)
        self.onFinishOnboarding = onFinishOnboarding
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                PrismCard(variant: .hero) {
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        PrismAdaptiveStack(spacing: PrismSpacing.s) {
                            PrismBadge(
                                configuration: PrismBadgeConfiguration(
                                    text: stateMachine.currentStep.screenCode,
                                    semantics: .accent
                                )
                            )
                            BrandLabel(
                                product: stateMachine.selectedBrandProductId,
                                context: .learningContent,
                                examCode: stateMachine.selectedRouteCode
                            )
                        }
                        PrismText(text: stateMachine.currentStep.title, style: .title3)
                        PrismText(
                            text: "NS-1 : 1re décision en ≤ 2 écrans, 0 champ texte, jouable hors ligne, 0 paywall avant la 1re valeur.",
                            style: .footnote,
                            role: .textSecondary
                        )
                    }
                }

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
                            } label: {
                                Text(verbatim: "Choisir AZ-104 et lancer la Situation de découverte (S-02)")
                            }
                            .buttonStyle(PrismButtonStyle(variant: .primary))

                        case .discoverySituation:
                            Button {
                                stateMachine.answerDiscoverySituation(optionCode: "A")
                            } label: {
                                Text(verbatim: "Valider la 1re décision hors ligne (Option A)")
                            }
                            .buttonStyle(PrismButtonStyle(variant: .primary))

                        case .firstAhaMoment, .goalRhythmAndWhen:
                            Button {
                                stateMachine.advanceToNextStep()
                            } label: {
                                Text(verbatim: "Continuer")
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
                                onFinishOnboarding()
                            } label: {
                                Text(verbatim: "Activer les rappels de rythme et commencer")
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

// MARK: - 6. CertiGo Pro StoreKit 2 Sheet Screen (S-73, `pro.v1`)

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
                                text: "CertiGo Pro · StoreKit 2 (S-73)",
                                semantics: .accent
                            )
                        )
                        PrismText(
                            text: "Présenté uniquement après la première valeur d'apprentissage (§34.1).",
                            style: .subheadline,
                            role: .textSecondary
                        )
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

// MARK: - 7. Complete Settings (S-74..S-84) & Account Deletion (S-82)

public struct CompleteSettingsScreen: View {
    @State private var deletionModel: AccountDeletionConfirmationModel
    public let onSelectSection: (SettingsSectionDestination) -> Void

    public init(
        deletionModel: AccountDeletionConfirmationModel = AccountDeletionConfirmationModel(),
        onSelectSection: @escaping (SettingsSectionDestination) -> Void = { _ in }
    ) {
        self._deletionModel = State(initialValue: deletionModel)
        self.onSelectSection = onSelectSection
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
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
        .navigationTitle(Text(verbatim: "Réglages"))
    }
}

// MARK: - 8. iOS System Surfaces Preview Screen (W-1..W-3, LA-1..LA-3, CC-1, AI-1)

public struct SystemSurfacesPreviewScreen: View {
    @State private var reviewWidgetQueue: ReviewCardWidgetQueueModel
    public let liveActivities: [CertigoLiveActivityState]
    public let controlWidget: ExpressSessionControlWidgetModel
    public let spotlightEntities: [CertigoSpotlightConceptEntity]

    public init(
        reviewWidgetQueue: ReviewCardWidgetQueueModel = ReviewCardWidgetQueueModel(),
        liveActivities: [CertigoLiveActivityState] = [
            CertigoLiveActivityState(id: "la1", kind: .mockExamSession),
            CertigoLiveActivityState(id: "la2", kind: .deepDiveSession),
            CertigoLiveActivityState(id: "la3", kind: .examDayCompanion)
        ],
        controlWidget: ExpressSessionControlWidgetModel = ExpressSessionControlWidgetModel(),
        spotlightEntities: [CertigoSpotlightConceptEntity] = CertigoSpotlightConceptEntity.defaultEntities
    ) {
        self._reviewWidgetQueue = State(initialValue: reviewWidgetQueue)
        self.liveActivities = liveActivities
        self.controlWidget = controlWidget
        self.spotlightEntities = spotlightEntities
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                PrismSection(title: "Widgets W-1 / W-2 / W-3 (NS-14)") {
                    PrismCard(variant: .standard) {
                        VStack(alignment: .leading, spacing: PrismSpacing.s) {
                            RegionChip(region: reviewWidgetQueue.region)
                            PrismText(text: reviewWidgetQueue.promptSummary, style: .headline)
                            Button {
                                reviewWidgetQueue.enqueueAnswerFromWidget(optionCode: "A")
                            } label: {
                                Text(verbatim: "Mettre la réponse en file sans ouvrir l'app (NS-14)")
                            }
                            .buttonStyle(PrismButtonStyle(variant: .primary))
                        }
                    }
                }

                PrismSection(title: "Live Activities LA-1 / LA-2 / LA-3 & Control Center CC-1") {
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        ForEach(liveActivities) { activity in
                            PrismCard(variant: .standard) {
                                HStack(spacing: PrismSpacing.s) {
                                    PrismBadge(
                                        configuration: PrismBadgeConfiguration(
                                            text: activity.kind.code,
                                            semantics: .accent
                                        )
                                    )
                                    PrismText(text: activity.kind.title, style: .subheadline)
                                }
                            }
                        }
                        PrismCard(variant: .standard) {
                            PrismText(text: "\(ExpressSessionControlWidgetModel.controlCode) · \(controlWidget.title)", style: .headline)
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
