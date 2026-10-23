import BrandAssets
import CertigoDomain
import Foundation

// MARK: - 1. Today Screen Model (S-10, §7, §14, §15 NS-2, §29)

public struct TodaySessionAtomSummary: Codable, Equatable, Hashable, Sendable {
    public let dueRecallsCount: Int
    public let newConceptsCount: Int
    public let recommendedConceptTitle: String
    public let recommendedProduct: BrandProductID

    public init(
        dueRecallsCount: Int,
        newConceptsCount: Int,
        recommendedConceptTitle: String,
        recommendedProduct: BrandProductID = .microsoftAzure
    ) {
        self.dueRecallsCount = max(0, dueRecallsCount)
        self.newConceptsCount = max(0, newConceptsCount)
        self.recommendedConceptTitle = recommendedConceptTitle
        self.recommendedProduct = recommendedProduct
    }

    public var compositionSummaryText: String {
        "\(dueRecallsCount) rappels · \(newConceptsCount) nouveau concept"
    }
}

public struct TodayDailySituationSummary: Codable, Equatable, Hashable, Sendable {
    public let situationId: String
    public let title: String
    public let product: BrandProductID
    public let isCompletedToday: Bool

    public init(
        situationId: String,
        title: String,
        product: BrandProductID,
        isCompletedToday: Bool = false
    ) {
        self.situationId = situationId
        self.title = title
        self.product = product
        self.isCompletedToday = isCompletedToday
    }
}

public enum TodayScreenState: Equatable, Sendable {
    case loading(elapsedSeconds: Double)
    case empty(PrismEmptyStateModel)
    case error(PrismErrorStateModel)
    case content
}

public struct TodayScreenModel: Equatable, Sendable {
    public let state: TodayScreenState
    public let suggestedLength: PrismSessionLength
    public var selectedLength: PrismSessionLength
    public let composition: TodaySessionAtomSummary
    public let activeRouteCode: String?
    public let activeRouteTitle: String?
    public let dailySituation: TodayDailySituationSummary
    public let rhythm: PrismRhythmWeekModel
    public let memoryAnchoredCount: Int
    public let memoryDueSoonCount: Int
    public let interruptedSession: InterruptedSessionAccessory?
    public let offlineBanner: PrismOfflineBannerModel?
    public let isGuestMode: Bool
    public let isWelcomeBackState: Bool
    public let tomorrowPreviewText: String

    public init(
        state: TodayScreenState = .content,
        suggestedLength: PrismSessionLength = .standard,
        selectedLength: PrismSessionLength? = nil,
        composition: TodaySessionAtomSummary,
        activeRouteCode: String? = "AZ-900",
        activeRouteTitle: String? = "Microsoft Azure Fundamentals",
        dailySituation: TodayDailySituationSummary,
        rhythm: PrismRhythmWeekModel,
        memoryAnchoredCount: Int = 12,
        memoryDueSoonCount: Int = 4,
        interruptedSession: InterruptedSessionAccessory? = nil,
        offlineBanner: PrismOfflineBannerModel? = nil,
        isGuestMode: Bool = false,
        isWelcomeBackState: Bool = false,
        tomorrowPreviewText: String = "Demain : 4 rappels planifiés pour consolider ton ancrage."
    ) {
        self.state = state
        self.suggestedLength = suggestedLength
        self.selectedLength = selectedLength ?? suggestedLength
        self.composition = composition
        self.activeRouteCode = activeRouteCode
        self.activeRouteTitle = activeRouteTitle
        self.dailySituation = dailySituation
        self.rhythm = rhythm
        self.memoryAnchoredCount = max(0, memoryAnchoredCount)
        self.memoryDueSoonCount = max(0, memoryDueSoonCount)
        self.interruptedSession = interruptedSession
        self.offlineBanner = offlineBanner
        self.isGuestMode = isGuestMode
        self.isWelcomeBackState = isWelcomeBackState
        self.tomorrowPreviewText = tomorrowPreviewText
    }

    /// §7 & §15 NS-2: Single primary action on Today ("Reprendre la séance" or "Commencer la séance").
    public var primaryActionTitle: String {
        if interruptedSession != nil {
            return "Reprendre la séance"
        }
        return "Commencer la séance"
    }

    public var activeRouteProductID: BrandProductID {
        BrandRegistry.productID(forTrackCode: activeRouteCode ?? "AZ-900")
    }

    /// §15 NS-2: VoiceOver summary per card so the learner hears the complete session context at once.
    public var sessionCardVoiceOverSummary: String {
        "\(primaryActionTitle), durée \(selectedLength.defaultMinutes) minutes, \(composition.compositionSummaryText), sujet \(composition.recommendedConceptTitle)"
    }
}

// MARK: - 2. Catalog Explorer Model (S-46, §14, §22A.5)

public struct CatalogRouteItem: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let code: String
    public let officialTitle: String
    public let region: PrismRegion
    public let product: BrandProductID
    public let availablePracticeCount: Int
    public let isConfirmedActiveGoal: Bool

    public init(
        id: String,
        code: String,
        officialTitle: String,
        region: PrismRegion,
        product: BrandProductID? = nil,
        availablePracticeCount: Int = 12,
        isConfirmedActiveGoal: Bool = false
    ) {
        self.id = id
        self.code = code
        self.officialTitle = officialTitle
        self.region = region
        self.product = product ?? BrandRegistry.productID(forTrackCode: code)
        self.availablePracticeCount = max(0, availablePracticeCount)
        self.isConfirmedActiveGoal = isConfirmedActiveGoal
    }
}

public struct CatalogExplorerModel: Equatable, Sendable {
    public let routes: [CatalogRouteItem]
    public var selectedRegion: PrismRegion?
    public var searchQuery: String
    public var onlyWithAvailableExercises: Bool

    public init(
        routes: [CatalogRouteItem],
        selectedRegion: PrismRegion? = nil,
        searchQuery: String = "",
        onlyWithAvailableExercises: Bool = false
    ) {
        self.routes = routes
        self.selectedRegion = selectedRegion
        self.searchQuery = searchQuery
        self.onlyWithAvailableExercises = onlyWithAvailableExercises
    }

    public var filteredRoutes: [CatalogRouteItem] {
        routes.filter { item in
            if let selectedRegion, item.region != selectedRegion {
                return false
            }
            if onlyWithAvailableExercises && item.availablePracticeCount == 0 {
                return false
            }
            let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !trimmed.isEmpty else { return true }
            return item.code.lowercased().contains(trimmed)
                || item.officialTitle.lowercased().contains(trimmed)
        }
    }
}

// MARK: - 3. Ensemble Minimal Model (S-60, §10, §15 NS-12)

public struct EnsembleMinimalModel: Codable, Equatable, Hashable, Sendable {
    public let isProfilePrivateByDefault: Bool
    public let areLeaguesOptedInByDefault: Bool
    public let pseudonym: String
    public let squadGoal: PrismSquadGoalModel?
    public let friendsCount: Int

    public init(
        isProfilePrivateByDefault: Bool = true,
        areLeaguesOptedInByDefault: Bool = false,
        pseudonym: String = "Apprenant",
        squadGoal: PrismSquadGoalModel? = nil,
        friendsCount: Int = 0
    ) {
        self.isProfilePrivateByDefault = isProfilePrivateByDefault
        self.areLeaguesOptedInByDefault = areLeaguesOptedInByDefault
        self.pseudonym = pseudonym
        self.squadGoal = squadGoal
        self.friendsCount = max(0, friendsCount)
    }
}

// MARK: - 4. Profile Skeleton Model (S-70, S-74…S-84, §14)

public struct ProfileSkeletonModel: Codable, Equatable, Hashable, Sendable {
    public let displayName: String
    public let activeRouteCode: String?
    public let passport: PrismPassportSummary
    public let dailyStreakDays: Int?
    public let calmModeEnabled: Bool
    public let hapticsEnabled: Bool
    public let soundsEnabled: Bool
    public let cloudAIEnabled: Bool

    public init(
        displayName: String,
        activeRouteCode: String? = "AZ-900",
        passport: PrismPassportSummary,
        dailyStreakDays: Int? = 5,
        calmModeEnabled: Bool = false,
        hapticsEnabled: Bool = true,
        soundsEnabled: Bool = true,
        cloudAIEnabled: Bool = false
    ) {
        self.displayName = displayName
        self.activeRouteCode = activeRouteCode
        self.passport = passport
        self.dailyStreakDays = dailyStreakDays
        self.calmModeEnabled = calmModeEnabled
        self.hapticsEnabled = hapticsEnabled
        self.soundsEnabled = soundsEnabled
        self.cloudAIEnabled = cloudAIEnabled
    }
}

// MARK: - 5. SwiftUI Screens (Apple platforms)

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct TodayRootScreen: View {
    @Binding public var model: TodayScreenModel
    public let flags: FeatureFlags
    public let onStartSession: (PrismSessionLength, String?) -> Void
    public let onOpenDailySituation: () -> Void
    public let onOpenMemoryDetail: () -> Void
    public let onOpenRouteObjective: (String) -> Void
    public let onOpenCatalogExplorer: () -> Void
    public let onRetry: () -> Void

    public init(
        model: Binding<TodayScreenModel>,
        flags: FeatureFlags = FeatureFlags(),
        onStartSession: @escaping (PrismSessionLength, String?) -> Void = { _, _ in },
        onOpenDailySituation: @escaping () -> Void = {},
        onOpenMemoryDetail: @escaping () -> Void = {},
        onOpenRouteObjective: @escaping (String) -> Void = { _ in },
        onOpenCatalogExplorer: @escaping () -> Void = {},
        onRetry: @escaping () -> Void = {}
    ) {
        self._model = model
        self.flags = flags
        self.onStartSession = onStartSession
        self.onOpenDailySituation = onOpenDailySituation
        self.onOpenMemoryDetail = onOpenMemoryDetail
        self.onOpenRouteObjective = onOpenRouteObjective
        self.onOpenCatalogExplorer = onOpenCatalogExplorer
        self.onRetry = onRetry
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                if let offlineBanner = model.offlineBanner {
                    PrismOfflineBanner(model: offlineBanner)
                }

                if model.isGuestMode {
                    PrismToast(
                        model: .guestSaveInvitation(),
                        onAction: {},
                        onDismiss: {}
                    )
                }

                switch model.state {
                case .loading(let elapsed):
                    PrismSkeleton(
                        model: PrismSkeletonModel(
                            rows: 4,
                            learningTip: "Une révision espacée de 72 h double l'ancrage à long terme.",
                            elapsedSeconds: elapsed
                        )
                    )
                case .empty(let emptyModel):
                    PrismEmptyState(model: emptyModel, onAction: onOpenCatalogExplorer)
                case .error(let errorModel):
                    PrismErrorState(model: errorModel, onRetry: onRetry)
                case .content:
                    contentCards
                }
            }
            .padding(PrismSpacing.l)
        }
        .background(PrismColor.canvas)
        .navigationTitle(Text(verbatim: "Aujourd'hui"))
    }

    @ViewBuilder
    private var contentCards: some View {
        if model.isWelcomeBackState {
            PrismCard(variant: .standard) {
                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                    PrismText(text: "Bon retour", style: .headline)
                    PrismText(
                        text: "Reprends tranquillement par une séance Express de 5 minutes.",
                        style: .subheadline,
                        role: .textSecondary
                    )
                }
            }
        }

        // 1. Hero Session Card (Single Primary Action — §7, §15 NS-2)
        PrismCard(variant: .hero) {
            VStack(alignment: .leading, spacing: PrismSpacing.m) {
                BrandLabel(
                    product: model.composition.recommendedProduct,
                    context: .learningContent,
                    size: .small,
                    flags: flags
                )

                PrismText(text: model.composition.recommendedConceptTitle, style: .title2)
                PrismText(
                    text: model.composition.compositionSummaryText,
                    style: .subheadline,
                    role: .textSecondary
                )

                SessionLengthPicker(
                    selectedLength: $model.selectedLength,
                    suggestedLength: model.suggestedLength
                )

                Button {
                    onStartSession(model.selectedLength, model.interruptedSession?.sessionId)
                } label: {
                    Text(verbatim: model.primaryActionTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrismButtonStyle(variant: .primary))
                .accessibilityIdentifier("today-primary-session-cta")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: model.sessionCardVoiceOverSummary))

        // 2. Daily Situation Card (§5.5, §14 S-30)
        PrismCard(variant: .situation) {
            VStack(alignment: .leading, spacing: PrismSpacing.s) {
                PrismAdaptiveStack(spacing: PrismSpacing.s) {
                    PrismBadge(
                        configuration: PrismBadgeConfiguration(
                            text: model.dailySituation.isCompletedToday ? "Accomplie" : "Situation du jour",
                            semantics: model.dailySituation.isCompletedToday ? .positive : .accent
                        )
                    )
                    BrandLabel(
                        product: model.dailySituation.product,
                        context: .learningContent,
                        size: .small,
                        flags: flags
                    )
                }
                PrismText(text: model.dailySituation.title, style: .headline)
                Button {
                    onOpenDailySituation()
                } label: {
                    Text(verbatim: model.dailySituation.isCompletedToday ? "Voir la distribution" : "Relever la Situation")
                }
                .buttonStyle(PrismButtonStyle(variant: .secondary))
            }
        }

        // 3. Weekly Rhythm Card (§7, §9)
        RhythmWeekView(model: model.rhythm)

        // 4. Memory Summary Card (S-11, §8)
        PrismCard(variant: .standard) {
            PrismRow(
                configuration: PrismRowConfiguration(
                    title: "Mémoire · \(model.memoryAnchoredCount) concepts ancrés",
                    subtitle: "\(model.memoryDueSoonCount) à raviver bientôt",
                    showsChevron: true
                ),
                action: onOpenMemoryDetail
            )
        }

        // 5. Active Objective Card with BrandLabel (§22A.5, §34.1 line 814)
        PrismCard(variant: .standard) {
            VStack(alignment: .leading, spacing: PrismSpacing.s) {
                PrismText(text: "Objectif actif", style: .CaptionHeadlineBridge.style, role: .textSecondary)
                if let code = model.activeRouteCode {
                    BrandLabel(
                        product: model.activeRouteProductID,
                        context: .catalog,
                        examCode: code,
                        size: .medium,
                        flags: flags
                    )
                    Button {
                        onOpenRouteObjective(code)
                    } label: {
                        Text(verbatim: "Voir ma préparation · \(code)")
                    }
                    .buttonStyle(PrismButtonStyle(variant: .tertiary))
                } else {
                    Button {
                        onOpenCatalogExplorer()
                    } label: {
                        Text(verbatim: "Choisir un objectif dans l'Atlas")
                    }
                    .buttonStyle(PrismButtonStyle(variant: .secondary))
                }
            }
        }

        // 6. Tomorrow Preview (§7)
        PrismText(text: model.tomorrowPreviewText, style: .footnote, role: .textSecondary)
    }
}

private enum CaptionHeadlineBridge {
    static let style: PrismTextStyle = .caption
}

extension PrismTextStyle {
    fileprivate static var CaptionHeadlineBridge: CaptionHeadlineBridge.Type {
        Prism.CaptionHeadlineBridge.self
    }
}

// MARK: - Catalog Explorer Screen (S-46, §14, §22A.5)

public struct CatalogExplorerScreen: View {
    @Binding public var model: CatalogExplorerModel
    public let flags: FeatureFlags
    public let onSelectGoal: (CatalogRouteItem) -> Void

    public init(
        model: Binding<CatalogExplorerModel>,
        flags: FeatureFlags = FeatureFlags(),
        onSelectGoal: @escaping (CatalogRouteItem) -> Void = { _ in }
    ) {
        self._model = model
        self.flags = flags
        self.onSelectGoal = onSelectGoal
    }

    public var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: PrismSpacing.s) {
                        PrismChip(
                            configuration: PrismChipConfiguration(
                                title: "Toutes les régions",
                                isSelected: model.selectedRegion == nil
                            )
                        ) {
                            model.selectedRegion = nil
                        }
                        ForEach(PrismRegion.allCases, id: \.rawValue) { region in
                            PrismChip(
                                configuration: PrismChipConfiguration(
                                    title: region.displayName,
                                    isSelected: model.selectedRegion == region
                                )
                            ) {
                                model.selectedRegion = region
                            }
                        }
                    }
                }
            }

            Section {
                ForEach(model.filteredRoutes) { route in
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        BrandLabel(
                            product: route.product,
                            context: .catalog,
                            examCode: route.code,
                            size: .medium,
                            flags: flags
                        )
                        PrismText(text: route.officialTitle, style: .body)
                        PrismAdaptiveStack(spacing: PrismSpacing.s) {
                            RegionChip(region: route.region)
                            if route.isConfirmedActiveGoal {
                                PrismBadge(
                                    configuration: PrismBadgeConfiguration(
                                        text: "Objectif actif confirmé",
                                        semantics: .positive
                                    )
                                )
                            } else {
                                Button {
                                    onSelectGoal(route)
                                } label: {
                                    Text(verbatim: "Choisir comme objectif actif")
                                }
                                .buttonStyle(PrismButtonStyle(variant: .tertiary))
                            }
                        }
                    }
                    .padding(.vertical, PrismSpacing.xs)
                }
            } header: {
                Text(verbatim: "Routes de certification (\(model.filteredRoutes.count))")
            }
        }
        .searchable(text: $model.searchQuery)
        .navigationTitle(Text(verbatim: "Explorer"))
    }
}

// MARK: - Atlas List Minimal Screen (S-40 Phase 3, §14, §15 NS-8)

public struct AtlasListMinimalScreen: View {
    public let nodes: [PrismAtlasNode]
    @State private var selectedRegion: PrismRegion?
    @State private var selectedState: PrismMasteryState?
    public let onOpenCatalogExplorer: () -> Void
    public let onSelectConcept: (PrismAtlasNode) -> Void

    public init(
        nodes: [PrismAtlasNode],
        onOpenCatalogExplorer: @escaping () -> Void = {},
        onSelectConcept: @escaping (PrismAtlasNode) -> Void = { _ in }
    ) {
        self.nodes = nodes
        self.onOpenCatalogExplorer = onOpenCatalogExplorer
        self.onSelectConcept = onSelectConcept
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                PrismCard(variant: .standard) {
                    PrismRow(
                        configuration: PrismRowConfiguration(
                            title: "Catalogue des certifications (Explorer)",
                            subtitle: "Parcourir les routes et choisir ton objectif actif",
                            showsChevron: true
                        ),
                        action: onOpenCatalogExplorer
                    )
                }

                AtlasList(
                    nodes: nodes,
                    selectedRegion: selectedRegion,
                    selectedState: selectedState,
                    onSelectNode: onSelectConcept
                )
            }
            .padding(PrismSpacing.l)
        }
        .background(PrismColor.canvas)
        .navigationTitle(Text(verbatim: "Atlas"))
    }
}

// MARK: - Ensemble Minimal Screen (S-60 Phase 3, §10, §15 NS-12)

public struct EnsembleMinimalScreen: View {
    public let model: EnsembleMinimalModel
    public let onOpenSquadSheet: () -> Void
    public let onOpenInviteSheet: () -> Void

    public init(
        model: EnsembleMinimalModel = EnsembleMinimalModel(),
        onOpenSquadSheet: @escaping () -> Void = {},
        onOpenInviteSheet: @escaping () -> Void = {}
    ) {
        self.model = model
        self.onOpenSquadSheet = onOpenSquadSheet
        self.onOpenInviteSheet = onOpenInviteSheet
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                PrismCard(variant: .standard) {
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        PrismBadge(
                            configuration: PrismBadgeConfiguration(
                                text: model.isProfilePrivateByDefault ? "Privé par défaut" : "Partagé",
                                semantics: .positive
                            )
                        )
                        PrismText(text: "Pseudonyme : \(model.pseudonym)", style: .headline)
                        PrismText(
                            text: "Aucune donnée ni échec n'est visible par autrui sans ton choix explicite.",
                            style: .footnote,
                            role: .textSecondary
                        )
                    }
                }

                if let squad = model.squadGoal {
                    SquadGoalView(model: squad)
                } else {
                    PrismCard(variant: .standard) {
                        VStack(alignment: .leading, spacing: PrismSpacing.s) {
                            PrismText(text: "Squad coopérative (3 à 8 apprenants)", style: .headline)
                            PrismText(
                                text: "Progressez ensemble sur un objectif hebdomadaire commun, sans classement anxiogène.",
                                style: .subheadline,
                                role: .textSecondary
                            )
                            Button {
                                onOpenSquadSheet()
                            } label: {
                                Text(verbatim: "Créer ou rejoindre une Squad")
                            }
                            .buttonStyle(PrismButtonStyle(variant: .secondary))
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

// MARK: - Profile Skeleton Screen (S-70, S-74…S-84 Phase 3, §14)

public struct ProfileSkeletonScreen: View {
    public let model: ProfileSkeletonModel
    public let flags: FeatureFlags
    public let onNavigate: (AppRoute) -> Void

    public init(
        model: ProfileSkeletonModel,
        flags: FeatureFlags = FeatureFlags(),
        onNavigate: @escaping (AppRoute) -> Void = { _ in }
    ) {
        self.model = model
        self.flags = flags
        self.onNavigate = onNavigate
    }

    public var body: some View {
        List {
            Section {
                PassportCard(summary: model.passport)
                if flags.isEnabled(.dailyStreakOptIn), let streak = model.dailyStreakDays {
                    PrismRow(
                        configuration: PrismRowConfiguration(
                            title: "Série quotidienne : \(streak) jours",
                            subtitle: "Option activée (DR-005)"
                        )
                    )
                }
            } header: {
                Text(verbatim: model.displayName)
            }

            Section {
                Button {
                    onNavigate(.settingsRhythmAndReminders)
                } label: {
                    Text(verbatim: "Rythme & rappels")
                }
                Button {
                    onNavigate(.settingsLanguage)
                } label: {
                    Text(verbatim: "Langue d'interface (8 langues)")
                }
                Button {
                    onNavigate(.settingsAccessibilityAndCalmMode)
                } label: {
                    Text(verbatim: "Lecture, accessibilité & Mode Calme")
                }
                Button {
                    onNavigate(.settingsPrivacyAndVisibility)
                } label: {
                    Text(verbatim: "Confidentialité & visibilité")
                }
                Button {
                    onNavigate(.settingsBrandNotices)
                } label: {
                    Text(verbatim: "Marques et mentions légales")
                }
                Button {
                    onNavigate(.settingsAccountDeletion)
                } label: {
                    Text(verbatim: "Suppression du compte")
                        .foregroundStyle(PrismColor.negative)
                }
            } header: {
                Text(verbatim: "Réglages")
            }
        }
        .navigationTitle(Text(verbatim: "Profil"))
    }
}
#endif
