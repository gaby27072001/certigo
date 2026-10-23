import BrandAssets
import CertigoDomain
import Foundation

// MARK: - 1. Complete End-to-End Prism App Shell Coordinator Model (§12, §13, §14, Phases 1..11)

public struct PrismAppShellCoordinatorModel: Equatable, Sendable {
    public var todayModel: TodayScreenModel
    public var atlasModel: AtlasScreenModel
    public var searchModel: GlobalSearchScreenModel
    public var rhythmPlanner: WeeklyRhythmPlannerModel
    public var dailySituationMachine: DailySituationStateMachine
    public var mockExamMachine: MockExamStateMachine
    public var sessionPlayerMachine: SessionPlayerStateMachine
    public var catalogExplorer: CatalogExplorerModel
    public var memoryDetail: MemoryDetailScreenModel
    public var conceptDetail: ConceptDetailScreenModel
    public var routeReadiness: RouteReadinessScreenModel
    public var calibrationHistory: CalibrationHistoryScreenModel

    public init(
        todayModel: TodayScreenModel = Self.defaultTodayModel(),
        atlasModel: AtlasScreenModel = Self.defaultAtlasModel(),
        searchModel: GlobalSearchScreenModel = Self.defaultSearchModel(),
        rhythmPlanner: WeeklyRhythmPlannerModel = Self.defaultRhythmPlanner(),
        dailySituationMachine: DailySituationStateMachine = Self.defaultDailySituationMachine(),
        mockExamMachine: MockExamStateMachine = Self.defaultMockExamMachine(),
        sessionPlayerMachine: SessionPlayerStateMachine = Self.defaultSessionPlayerMachine(),
        catalogExplorer: CatalogExplorerModel = Self.defaultCatalogExplorer(),
        memoryDetail: MemoryDetailScreenModel = Self.defaultMemoryDetail(),
        conceptDetail: ConceptDetailScreenModel = Self.defaultConceptDetail(),
        routeReadiness: RouteReadinessScreenModel = Self.defaultRouteReadiness(),
        calibrationHistory: CalibrationHistoryScreenModel = Self.defaultCalibrationHistory()
    ) {
        self.todayModel = todayModel
        self.atlasModel = atlasModel
        self.searchModel = searchModel
        self.rhythmPlanner = rhythmPlanner
        self.dailySituationMachine = dailySituationMachine
        self.mockExamMachine = mockExamMachine
        self.sessionPlayerMachine = sessionPlayerMachine
        self.catalogExplorer = catalogExplorer
        self.memoryDetail = memoryDetail
        self.conceptDetail = conceptDetail
        self.routeReadiness = routeReadiness
        self.calibrationHistory = calibrationHistory
    }

    public static func defaultRhythmWeek() -> PrismRhythmWeekModel {
        PrismRhythmWeekModel(
            weeklyGoalDays: 4,
            days: [
                PrismRhythmDayItem(id: "mon", shortDayLabel: "L", state: .completed),
                PrismRhythmDayItem(id: "tue", shortDayLabel: "M", state: .completed),
                PrismRhythmDayItem(id: "wed", shortDayLabel: "M", state: .restDay),
                PrismRhythmDayItem(id: "thu", shortDayLabel: "J", state: .planned),
                PrismRhythmDayItem(id: "fri", shortDayLabel: "V", state: .planned),
                PrismRhythmDayItem(id: "sat", shortDayLabel: "S", state: .restDay),
                PrismRhythmDayItem(id: "sun", shortDayLabel: "D", state: .restDay)
            ],
            bestRhythmWeeks: 6,
            dailyStreakOptIn: true,
            dailyStreakDays: 5
        )
    }

    public static func defaultRhythmPlanner() -> WeeklyRhythmPlannerModel {
        WeeklyRhythmPlannerModel(
            targetDaysPerWeek: 4,
            completedDaysThisWeek: 2,
            bestRhythmWeeks: 6,
            pauseWeeksRemaining: 0,
            completedCatchUpRecalls: 3,
            dailyStreakDays: 5,
            dailyStreakEnabled: true,
            days: defaultRhythmWeek().days
        )
    }

    public static func defaultTodayModel() -> TodayScreenModel {
        TodayScreenModel(
            suggestedLength: .standard,
            composition: TodaySessionAtomSummary(
                dueRecallsCount: 6,
                newConceptsCount: 1,
                recommendedConceptTitle: "Isoler un sous-réseau Azure avec un NSG",
                recommendedProduct: .azureVirtualNetwork
            ),
            activeRouteCode: "AZ-104",
            activeRouteTitle: "Microsoft Azure Administrator",
            dailySituation: TodayDailySituationSummary(
                situationId: "sit-2026-10-23",
                title: "Protection d'un coffre Key Vault critique",
                product: BrandProductID("azure-key-vault")
            ),
            rhythm: defaultRhythmWeek()
        )
    }

    public static func defaultAtlasModel() -> AtlasScreenModel {
        let territory = AtlasTerritorySummary(
            id: "t-iam",
            title: "Identité, gouvernance & RBAC",
            region: .security,
            totalConceptsCount: 12,
            anchoredOrMasteredCount: 8,
            averageDepthRung: 3.5
        )
        let nodes = [
            PrismAtlasNode(
                id: "az104-pe-dns",
                code: "AZ-PE",
                title: "Private Endpoint & DNS privé",
                region: .network,
                masteryState: .anchored,
                normalizedX: 0.35,
                normalizedY: 0.42
            ),
            PrismAtlasNode(
                id: "az104-nsg",
                code: "AZ-NSG",
                title: "Groupes de sécurité réseau (NSG)",
                region: .security,
                masteryState: .mastered,
                normalizedX: 0.65,
                normalizedY: 0.58
            )
        ]
        return AtlasScreenModel(
            isVoiceOverRunning: false,
            regions: [AtlasRegionSummary(region: .security, territories: [territory])],
            nodes: nodes
        )
    }

    public static func defaultSearchModel() -> GlobalSearchScreenModel {
        GlobalSearchScreenModel(
            catalog: [
                GlobalSearchResultItem(
                    id: "az104-pe-dns",
                    kind: .concept,
                    title: "Private Endpoint & DNS privé",
                    subtitle: "Liaison VNet et zone privatelink",
                    product: .azureVirtualNetwork,
                    region: .network
                ),
                GlobalSearchResultItem(
                    id: "AZ-104",
                    kind: .route,
                    title: "AZ-104 · Microsoft Azure Administrator",
                    subtitle: "Route de certification active",
                    product: .microsoftAzure,
                    region: .cloud
                )
            ]
        )
    }

    public static func defaultDailySituationMachine() -> DailySituationStateMachine {
        let optA = PrismChoiceOption(
            id: "a",
            badge: "A",
            text: "Activer Soft Delete + Purge Protection sur le Key Vault",
            explanation: "Empêche toute suppression définitive immédiate des clés et secrets.",
            isCorrect: true
        )
        let optB = PrismChoiceOption(
            id: "b",
            badge: "B",
            text: "Sauvegarder les secrets dans un fichier JSON public",
            explanation: "Crée un risque critique d'exfiltration.",
            isCorrect: false
        )
        return DailySituationStateMachine(
            situationId: "sit-2026-10-23",
            dateLabel: "23 oct. 2026",
            title: "Protection d'un coffre Key Vault critique",
            product: BrandProductID("azure-key-vault"),
            region: .security,
            contextNarrative: "Un administrateur souhaite empêcher toute purge immédiate d'un coffre de production.",
            artifact: PrismArtifactDocument(
                title: "keyvault.bicep",
                language: "bicep",
                lines: [
                    PrismArtifactLine(lineNumber: 1, text: "enableSoftDelete: true"),
                    PrismArtifactLine(lineNumber: 2, text: "enablePurgeProtection: true")
                ]
            ),
            options: [optA, optB],
            serverDistributionBuckets: [
                PrismDistributionBucket(
                    id: "b-a",
                    optionCode: "A",
                    optionSummary: "Soft Delete + Purge Protection",
                    percentage: 78,
                    isLearnerSelection: true,
                    isBestOption: true
                ),
                PrismDistributionBucket(
                    id: "b-b",
                    optionCode: "B",
                    optionSummary: "Export JSON non protégé",
                    percentage: 22,
                    isLearnerSelection: false,
                    isBestOption: false
                )
            ]
        )
    }

    public static func defaultMockExamMachine() -> MockExamStateMachine {
        let q1 = MockExamQuestionRecord(
            item: PrismSessionItemModel(
                id: "mex-1",
                conceptId: "az.rbac",
                product: .microsoftEntraID,
                stem: "Quel rôle accorde la gestion des accès sans accès aux données ?",
                captureConfidence: true,
                isMockExamMode: true,
                payload: .choice(
                    options: [
                        PrismChoiceOption(id: "a", badge: "A", text: "User Access Administrator", explanation: "Gère les attributions de rôles."),
                        PrismChoiceOption(id: "b", badge: "B", text: "Contributor", explanation: "Gère les ressources mais pas les accès.")
                    ],
                    allowsMultipleSelection: false
                )
            ),
            domainId: "dom-identity",
            domainTitle: "Identité et gouvernance"
        )
        return MockExamStateMachine(
            examId: "exam-az104",
            routeCode: "AZ-104",
            routeTitle: "Microsoft Azure Administrator",
            baseDurationMinutes: 40,
            timePolicy: .extendedTime,
            questions: [q1]
        )
    }

    public static func defaultSessionPlayerMachine() -> SessionPlayerStateMachine {
        let workedExample = PrismWorkedExample(
            id: "we-1",
            title: "Configurer un Private Endpoint Azure Storage",
            problemContext: "Isoler un compte de stockage derrière un VNet.",
            steps: [
                PrismWorkedStep(id: "s1", stepNumber: 1, subgoalTitle: "Désactiver l'accès public", detail: "Passer publicNetworkAccess à Disabled."),
                PrismWorkedStep(id: "s2", stepNumber: 2, subgoalTitle: "Lier la zone DNS privée", detail: "Créer le lien VNet privatelink.blob.core.windows.net.")
            ],
            conclusion: "Le trafic passe désormais exclusivement par le réseau privé.",
            isSkippable: true
        )
        let learnCard = PrismLearningCardModel(
            id: "lc-1",
            conceptId: "az104-pe-dns",
            title: "Private Endpoint & DNS privé",
            product: .azureStorage,
            kind: .workedExample(workedExample, skipVerificationItemId: "item-1")
        )
        let itemCard = PrismSessionItemModel(
            id: "item-1",
            conceptId: "az104-pe-dns",
            product: .azureStorage,
            rung: 3,
            difficulty: 2,
            stem: "Quelle zone DNS privée résout un Blob Storage Private Endpoint ?",
            captureConfidence: true,
            payload: .choice(
                options: [
                    PrismChoiceOption(id: "a", badge: "A", text: "privatelink.blob.core.windows.net", explanation: "Zone DNS privée officielle de Blob Storage.", isCorrect: true),
                    PrismChoiceOption(id: "b", badge: "B", text: "public.blob.core.windows.net", explanation: "Sous-domaine invalide.", isCorrect: false)
                ],
                allowsMultipleSelection: false
            )
        )
        let plan = PrismSessionPlan(
            id: "plan-az104-default",
            length: .standard,
            cards: [.learning(learnCard), .item(itemCard)],
            skipVerificationItems: ["item-1": itemCard]
        )
        return SessionPlayerStateMachine(plan: plan)
    }

    public static func defaultCatalogExplorer() -> CatalogExplorerModel {
        CatalogExplorerModel(
            routes: [
                CatalogRouteItem(
                    id: "az-104",
                    code: "AZ-104",
                    officialTitle: "Microsoft Azure Administrator",
                    region: .cloud,
                    isConfirmedActiveGoal: true
                ),
                CatalogRouteItem(
                    id: "ai-102",
                    code: "AI-102",
                    officialTitle: "Azure AI Engineer Associate",
                    region: .ai
                ),
                CatalogRouteItem(
                    id: "sc-300",
                    code: "SC-300",
                    officialTitle: "Microsoft Identity and Access Administrator",
                    region: .security
                )
            ]
        )
    }

    public static func defaultMemoryDetail() -> MemoryDetailScreenModel {
        MemoryDetailScreenModel(
            forecastPoints: [
                PrismMemoryForecastPoint(dayOffset: 0, dayLabel: "Auj.", retention: 0.94),
                PrismMemoryForecastPoint(dayOffset: 3, dayLabel: "J+3", retention: 0.78),
                PrismMemoryForecastPoint(dayOffset: 7, dayLabel: "J+7", retention: 0.64)
            ],
            items: [
                MemoryConceptItem(
                    id: "az104-pe-dns",
                    conceptTitle: "Private Endpoint & DNS privé",
                    product: .azureVirtualNetwork,
                    masteryState: .anchored,
                    predictedRetention: 0.68,
                    lastReviewedDaysAgo: 4
                )
            ]
        )
    }

    public static func defaultConceptDetail() -> ConceptDetailScreenModel {
        ConceptDetailScreenModel(
            id: "az104-pe-dns",
            code: "AZ-PE",
            title: "Private Endpoint & DNS privé",
            summary: "Projette une interface réseau privée dans le VNet avec résolution DNS privatelink liée au VNet.",
            product: .azureVirtualNetwork,
            region: .network,
            masteryState: .anchored,
            depthLadder: PrismDepthLadderModel(
                conceptTitle: "Private Endpoint & DNS privé",
                currentLevel: 3,
                practiceOffPhoneRecommended: true
            ),
            predictedRetention: 0.82,
            forecastPoints: [
                PrismMemoryForecastPoint(dayOffset: 0, dayLabel: "Auj.", retention: 0.94),
                PrismMemoryForecastPoint(dayOffset: 3, dayLabel: "J+3", retention: 0.82)
            ],
            activeMisconception: "Oublier le Virtual Network Link sur la zone DNS privée privatelink."
        )
    }

    public static func defaultRouteReadiness() -> RouteReadinessScreenModel {
        RouteReadinessScreenModel(
            routeCode: "AZ-104",
            officialTitle: "Microsoft Azure Administrator",
            readiness: PrismReadinessModel(
                band: .readyToTry,
                isCalibrated: false,
                rawProbability: 0.78,
                uncertaintyLow: 0.65,
                uncertaintyHigh: 0.85,
                evidenceCount: 18,
                recommendedActions: ["Ancrer Private Endpoint DNS", "Pratiquer Azure Policy vs RBAC"]
            ),
            objectiveCoverage: [
                PrismObjectiveCoverageItem(
                    id: "dom-1",
                    objectiveCode: "D1",
                    title: "Gérer les identités et la gouvernance Entra ID",
                    region: .security,
                    masteryState: .anchored,
                    verifiedEvidenceCount: 10,
                    targetEvidenceCount: 12
                )
            ],
            historyWeeksCount: 3,
            estimatedReadyDateRange: "Entre le 10 et le 20 novembre"
        )
    }

    public static func defaultCalibrationHistory() -> CalibrationHistoryScreenModel {
        CalibrationHistoryScreenModel(
            passport: PrismPassportSummary(
                holderPseudonym: "Apprenant-Az7",
                holderInitials: "GC",
                primaryRegion: .cloud,
                anchoredConceptsCount: 28,
                masteredConceptsCount: 14,
                completedRhythmWeeks: 6,
                routes: [
                    PrismRouteBadgeModel(examCode: "AZ-104", officialTitle: "Microsoft Azure Administrator", region: .cloud)
                ],
                verificationLinks: [
                    PrismExternalVerificationLink(
                        id: "ms-learn-1",
                        providerName: "Microsoft Learn",
                        label: "Vérifier sur Microsoft Learn",
                        urlString: "https://learn.microsoft.com/credentials/"
                    )
                ]
            ),
            samples: [
                CalibrationSamplePoint(id: "s1", confidence: .sure, wasCorrect: true),
                CalibrationSamplePoint(id: "s2", confidence: .rather, wasCorrect: true)
            ],
            recentSessionsCount: 12
        )
    }
}

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

// MARK: - 2. Unified 5-Tab Prism App Shell View (§12, §13, §14, Phases 1..11)

public struct PrismAppShellView: View {
    @State private var router: AppRouterState
    @State private var coordinator: PrismAppShellCoordinatorModel
    public let flags: FeatureFlags

    public init(
        router: AppRouterState = AppRouterState(),
        coordinator: PrismAppShellCoordinatorModel = PrismAppShellCoordinatorModel(),
        flags: FeatureFlags = FeatureFlags()
    ) {
        self._router = State(initialValue: router)
        self._coordinator = State(initialValue: coordinator)
        self.flags = flags
    }

    private func pathBinding(for tab: AppTab) -> Binding<[AppRoute]> {
        Binding(
            get: { router.paths[tab] ?? [] },
            set: { router.paths[tab] = $0 }
        )
    }

    public var body: some View {
        TabView(selection: $router.selectedTab) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack(path: pathBinding(for: tab)) {
                    rootScreen(for: tab)
                        .navigationDestination(for: AppRoute.self) { route in
                            destinationScreen(for: route)
                        }
                }
                .tabItem {
                    Label(
                        tab.title,
                        systemImage: tab.symbolName(isSelected: router.selectedTab == tab)
                    )
                }
                .tag(tab)
            }
        }
        .fullScreenCover(item: $router.activeCover) { cover in
            NavigationStack {
                coverScreen(for: cover)
            }
        }
        .sheet(item: $router.activeSheet) { sheet in
            NavigationStack {
                sheetScreen(for: sheet)
            }
        }
    }

    @ViewBuilder
    private func rootScreen(for tab: AppTab) -> some View {
        switch tab {
        case .today:
            TodayRootScreen(
                model: $coordinator.todayModel,
                flags: flags,
                onStartSession: { length, resumeId in
                    router.presentCover(.sessionPlayer(length: length, resumeSessionId: resumeId))
                },
                onOpenDailySituation: {
                    router.presentCover(.dailySituation)
                },
                onOpenMemoryDetail: {
                    router.push(.memoryDetail, in: .today)
                },
                onOpenRouteObjective: { code in
                    router.push(.routeObjective(trackCode: code), in: .today)
                },
                onOpenCatalogExplorer: {
                    router.push(.catalogExplorer, in: .today)
                }
            )

        case .atlas:
            AtlasCompleteScreen(
                model: $coordinator.atlasModel,
                onSelectRegion: { summary in
                    router.push(.regionDetail(summary.region), in: .atlas)
                },
                onSelectNode: { node in
                    router.push(.conceptDetail(id: node.id), in: .atlas)
                },
                onOpenExplorer: {
                    router.push(.catalogExplorer, in: .atlas)
                }
            )

        case .ensemble:
            EnsembleCompleteScreen(
                onNavigate: { route in
                    router.push(route, in: .ensemble)
                },
                onOpenSheet: { sheet in
                    router.presentSheet(sheet)
                },
                onOpenCover: { cover in
                    router.presentCover(cover)
                }
            )

        case .profile:
            CompleteSettingsScreen(
                onSelectSection: { section in
                    switch section {
                    case .rhythmAndReminders:
                        router.push(.settingsRhythmAndReminders, in: .profile)
                    case .language:
                        router.push(.settingsLanguage, in: .profile)
                    case .accessibilityAndCalmMode:
                        router.push(.settingsAccessibilityAndCalmMode, in: .profile)
                    case .privacyAndVisibility:
                        router.push(.settingsPrivacyAndVisibility, in: .profile)
                    case .contextualAI:
                        router.push(.settingsAI, in: .profile)
                    case .offlineData:
                        router.push(.settingsOfflineData, in: .profile)
                    case .account:
                        router.push(.settingsAccount, in: .profile)
                    case .accountDeletion:
                        router.push(.settingsAccountDeletion, in: .profile)
                    case .dataAndMethodology:
                        router.push(.settingsDataAndMethodology, in: .profile)
                    case .helpAndReport:
                        router.push(.settingsBrandNotices, in: .profile)
                    }
                }
            )

        case .search:
            GlobalSearchScreen(
                model: $coordinator.searchModel,
                flags: flags,
                onSelectResult: { result in
                    switch result.kind {
                    case .concept:
                        router.push(.conceptDetail(id: result.id), in: .search)
                    case .route:
                        router.push(.routeObjective(trackCode: result.id), in: .search)
                    case .situation:
                        router.presentCover(.dailySituation)
                    }
                }
            )
        }
    }

    @ViewBuilder
    private func destinationScreen(for route: AppRoute) -> some View {
        switch route {
        case .memoryDetail:
            MemoryDetailScreen(
                model: coordinator.memoryDetail,
                flags: flags,
                onSelectConcept: { item in
                    router.push(.conceptDetail(id: item.id))
                }
            )
        case .dailySituationHistory:
            DailySituationHistoryScreen(
                onShareEntry: { payload in
                    router.presentSheet(.shareCard(payload))
                }
            )
        case .regionDetail, .territoryDetail:
            AtlasCompleteScreen(
                model: $coordinator.atlasModel,
                onSelectNode: { node in
                    router.push(.conceptDetail(id: node.id))
                },
                onOpenExplorer: {
                    router.push(.catalogExplorer)
                }
            )
        case .conceptDetail:
            ConceptDetailScreen(
                model: coordinator.conceptDetail,
                flags: flags,
                onPracticeOneMinute: {
                    router.presentCover(.sessionPlayer(length: .express, resumeSessionId: nil))
                }
            )
        case .misconceptionsMap:
            MisconceptionsMapScreen(
                onSelectComparison: { pair in
                    router.presentSheet(.compareConcepts(leftId: pair.leftTitle, rightId: pair.rightTitle))
                }
            )
        case .catalogExplorer:
            CatalogExplorerScreen(
                model: $coordinator.catalogExplorer,
                flags: flags,
                onSelectRoute: { item in
                    router.push(.routeObjective(trackCode: item.code))
                }
            )
        case .routeObjective, .examObjectiveDetail, .readinessDetail:
            RouteReadinessScreen(
                model: coordinator.routeReadiness,
                flags: flags,
                onStartMockExam: {
                    router.presentCover(.mockExam(trackCode: coordinator.routeReadiness.routeCode))
                },
                onReportExamOutcome: {
                    router.presentSheet(.reportExamOutcome(trackCode: coordinator.routeReadiness.routeCode))
                }
            )
        case .squadDetail:
            SquadDetailScreen(
                onInviteToSquad: {
                    router.presentSheet(.createOrJoinSquad)
                }
            )
        case .friendsList:
            FriendsListScreen(
                onSelectFriend: { friend in
                    router.push(.friendProfile(id: friend.id))
                },
                onOpenInviteSheet: {
                    router.presentSheet(.inviteFriend)
                }
            )
        case .friendProfile:
            FriendProfileScreen(
                onStartChallenge: { challengeId in
                    router.presentCover(.asyncChallenge(id: challengeId))
                }
            )
        case .progressionLeagues:
            ProgressionLeaguesScreen()
        case .passport, .historyAndCalibration:
            PassportAndCalibrationScreen(model: coordinator.calibrationHistory)
        case .settings:
            CompleteSettingsScreen()
        case .settingsRhythmAndReminders:
            WeeklyRhythmSettingsScreen(model: $coordinator.rhythmPlanner)
        case .settingsLanguage, .settingsAccessibilityAndCalmMode, .settingsOfflineData, .settingsAccount, .settingsDataAndMethodology:
            Phase11HardeningDashboardScreen()
        case .settingsPrivacyAndVisibility:
            EnsembleCompleteScreen()
        case .settingsAI:
            ContextualAISheetScreen()
        case .settingsAccountDeletion:
            CompleteSettingsScreen()
        case .settingsBrandNotices:
            BrandNoticesView()
        }
    }

    @ViewBuilder
    private func coverScreen(for cover: AppFullScreenCoverRoute) -> some View {
        switch cover {
        case .onboarding:
            OnboardingFlowCoverScreen(
                onFinishOnboarding: {
                    router.confirmForceDismissCover()
                }
            )
        case .sessionPlayer:
            SessionPlayerScreen(
                stateMachine: $coordinator.sessionPlayerMachine,
                flags: flags,
                onCloseRequested: { hasUnsavedInput in
                    router.requestDismissCover(hasUnsavedInputInProgress: hasUnsavedInput)
                }
            )
        case .dailySituation:
            DailySituationScreen(
                machine: $coordinator.dailySituationMachine,
                flags: flags,
                onShare: { payload in
                    router.presentSheet(.shareCard(payload))
                },
                onClose: {
                    router.confirmForceDismissCover()
                }
            )
        case .mockExam:
            MockExamIntroScreen(
                machine: $coordinator.mockExamMachine,
                flags: flags,
                onStart: {
                    router.confirmForceDismissCover()
                }
            )
        case .asyncChallenge:
            AsyncChallengeCoverScreen(
                onDismiss: {
                    router.confirmForceDismissCover()
                }
            )
        }
    }

    @ViewBuilder
    private func sheetScreen(for sheet: AppSheetRoute) -> some View {
        switch sheet {
        case .contextualAI:
            ContextualAISheetScreen(
                onOpenCompareSheet: { left, right in
                    router.presentSheet(.compareConcepts(leftId: left, rightId: right))
                }
            )
        case .conceptSheet:
            ConceptDetailScreen(
                model: coordinator.conceptDetail,
                flags: flags,
                onPracticeOneMinute: {
                    router.dismissSheet()
                    router.presentCover(.sessionPlayer(length: .express, resumeSessionId: nil))
                }
            )
        case .compareConcepts:
            CompareConceptsSheetScreen()
        case .reportExamOutcome:
            RouteReadinessScreen(model: coordinator.routeReadiness, flags: flags)
        case .createOrJoinSquad:
            CreateOrJoinSquadSheetScreen(
                onConfirmSquad: { _ in
                    router.dismissSheet()
                }
            )
        case .inviteFriend:
            InviteFriendSheetScreen()
        case .certigoPro:
            CertigoProSheetScreen()
        case .shareCard(let payload):
            ShareCardRenderer(payload: payload)
        }
    }
}
#endif
