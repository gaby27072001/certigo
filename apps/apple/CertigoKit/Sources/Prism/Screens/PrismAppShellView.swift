import BrandAssets
@_exported import CertigoData
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
    public var contextualAISession: ContextualAISessionState
    public var latestTutorExplanation: TutorExplanation?
    public var parallelTracksPreference: CertigoParallelTracksPreference

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
        calibrationHistory: CalibrationHistoryScreenModel = Self.defaultCalibrationHistory(),
        contextualAISession: ContextualAISessionState = ContextualAISessionState(),
        latestTutorExplanation: TutorExplanation? = nil,
        parallelTracksPreference: CertigoParallelTracksPreference = CertigoParallelTracksPreference()
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
        self.contextualAISession = contextualAISession
        self.latestTutorExplanation = latestTutorExplanation
        self.parallelTracksPreference = parallelTracksPreference
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
        let tIam = AtlasTerritorySummary(
            id: "t-iam",
            title: "Identité, gouvernance Entra ID & RBAC",
            region: .security,
            totalConceptsCount: 12,
            anchoredOrMasteredCount: 9,
            averageDepthRung: 3.8
        )
        let tNet = AtlasTerritorySummary(
            id: "t-net",
            title: "Réseaux virtuels, Private Link & DNS hybride",
            region: .network,
            totalConceptsCount: 14,
            anchoredOrMasteredCount: 10,
            averageDepthRung: 3.5
        )
        let tAi = AtlasTerritorySummary(
            id: "t-ai",
            title: "Architecture IA, Foundry & RAG vectoriel",
            region: .ai,
            totalConceptsCount: 10,
            anchoredOrMasteredCount: 7,
            averageDepthRung: 3.4
        )
        let nodes = [
            PrismAtlasNode(
                id: "az104-pe-dns",
                code: "AZ-PE",
                title: "Private Endpoint & DNS privé",
                region: .network,
                masteryState: .anchored,
                normalizedX: 0.25,
                normalizedY: 0.35
            ),
            PrismAtlasNode(
                id: "az104-nsg",
                code: "AZ-NSG",
                title: "Groupes de sécurité réseau (NSG)",
                region: .security,
                masteryState: .mastered,
                normalizedX: 0.55,
                normalizedY: 0.45
            ),
            PrismAtlasNode(
                id: "sc300-pim",
                code: "ENTRA-PIM",
                title: "Privileged Identity Management (Just-In-Time)",
                region: .security,
                masteryState: .anchored,
                normalizedX: 0.72,
                normalizedY: 0.30
            ),
            PrismAtlasNode(
                id: "ai102-rag",
                code: "AI-RAG",
                title: "Recherche hybride vectorielle & reclassement sémantique",
                region: .ai,
                masteryState: .practicing,
                normalizedX: 0.40,
                normalizedY: 0.70
            )
        ]
        return AtlasScreenModel(
            isVoiceOverRunning: false,
            regions: [
                AtlasRegionSummary(region: .security, territories: [tIam]),
                AtlasRegionSummary(region: .network, territories: [tNet]),
                AtlasRegionSummary(region: .ai, territories: [tAi])
            ],
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
                    id: "az-900",
                    code: "AZ-900",
                    officialTitle: "Microsoft Azure Fundamentals",
                    region: .cloud
                ),
                CatalogRouteItem(
                    id: "ai-102",
                    code: "AI-102",
                    officialTitle: "Microsoft Azure AI Engineer Associate",
                    region: .ai
                ),
                CatalogRouteItem(
                    id: "gh-300",
                    code: "GH-300",
                    officialTitle: "GitHub Copilot Certification",
                    region: .devops
                ),
                CatalogRouteItem(
                    id: "sc-300",
                    code: "SC-300",
                    officialTitle: "Microsoft Identity and Access Administrator",
                    region: .security
                ),
                CatalogRouteItem(
                    id: "dp-600",
                    code: "DP-600",
                    officialTitle: "Microsoft Fabric Analytics Engineer",
                    region: .data
                ),
                CatalogRouteItem(
                    id: "az-305",
                    code: "AZ-305",
                    officialTitle: "Designing Microsoft Azure Infrastructure Solutions",
                    region: .network
                ),
                CatalogRouteItem(
                    id: "aws-saa",
                    code: "SAA-C03",
                    officialTitle: "AWS Certified Solutions Architect – Associate",
                    region: .cloud
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

    // MARK: - Live CertigoDomain / CertigoData Synchronization Bridge

    public mutating func applyPersistedPreferences(_ prefs: CertigoParallelTracksPreference) {
        applyParallelTracksPreference(prefs)
    }

    public func withPersistedPreferencesLoaded(
        from store: CertigoParallelTracksPreferenceStore = .shared
    ) -> PrismAppShellCoordinatorModel {
        var next = self
        next.applyPersistedPreferences(store.loadOrDefault())
        return next
    }

    public mutating func synchronize(
        profile: Profile? = nil,
        catalog: Catalog? = nil,
        tracks: [Track]? = nil,
        learningPath: LearningPath? = nil,
        lesson: Lesson? = nil,
        readinessSnapshot: ReadinessSnapshot? = nil,
        mockExam: MockExam? = nil,
        tutorExplanation: TutorExplanation? = nil,
        parallelTracksPreference: CertigoParallelTracksPreference? = nil,
        preferenceStore: CertigoParallelTracksPreferenceStore? = nil
    ) {
        self = synchronized(
            profile: profile,
            catalog: catalog,
            tracks: tracks,
            learningPath: learningPath,
            lesson: lesson,
            readinessSnapshot: readinessSnapshot,
            mockExam: mockExam,
            tutorExplanation: tutorExplanation,
            parallelTracksPreference: parallelTracksPreference,
            preferenceStore: preferenceStore
        )
    }

    public func synchronized(
        profile: Profile? = nil,
        catalog: Catalog? = nil,
        tracks: [Track]? = nil,
        learningPath: LearningPath? = nil,
        lesson: Lesson? = nil,
        readinessSnapshot: ReadinessSnapshot? = nil,
        mockExam: MockExam? = nil,
        tutorExplanation: TutorExplanation? = nil,
        parallelTracksPreference: CertigoParallelTracksPreference? = nil,
        preferenceStore: CertigoParallelTracksPreferenceStore? = nil
    ) -> PrismAppShellCoordinatorModel {
        var next = self
        if let parallelTracksPreference {
            next.applyPersistedPreferences(parallelTracksPreference)
        } else if let preferenceStore {
            next.applyPersistedPreferences(preferenceStore.loadOrDefault())
        }
        let availableTracks = catalog?.tracks ?? tracks ?? []
        let candidateTrackId: String? = profile?.activeTrackId
            ?? learningPath?.trackId
            ?? readinessSnapshot?.trackId
            ?? lesson?.trackId
            ?? mockExam?.trackId
            ?? parallelTracksPreference?.activeTrackCode
            ?? next.parallelTracksPreference.activeTrackCode

        let matchedTrack = availableTracks.first { track in
            guard let candidateTrackId else { return false }
            return track.id.caseInsensitiveCompare(candidateTrackId) == .orderedSame
                || track.code.caseInsensitiveCompare(candidateTrackId) == .orderedSame
        }

        let resolvedRouteCode: String = {
            if let matchedTrack {
                return matchedTrack.code
            }
            if let mockExam, candidateTrackId == nil || candidateTrackId == mockExam.trackId {
                return mockExam.trackCode
            }
            if let candidateTrackId, !candidateTrackId.isEmpty {
                return Self.normalizedRouteCode(from: candidateTrackId)
            }
            return next.todayModel.activeRouteCode ?? "AZ-104"
        }()

        let resolvedRouteTitle: String = {
            if let matchedTrack {
                return matchedTrack.title
            }
            if let learningPath, !learningPath.trackName.isEmpty {
                return learningPath.trackName
            }
            if let mockExam, !mockExam.trackTitle.isEmpty {
                return mockExam.trackTitle
            }
            return next.todayModel.activeRouteTitle ?? "Microsoft Azure Administrator"
        }()

        let activeRegion = Self.region(forTrackCode: resolvedRouteCode, title: resolvedRouteTitle)
        let activeProduct = BrandRegistry.productID(forTrackCode: resolvedRouteCode)
        next.parallelTracksPreference.setActiveTrack(resolvedRouteCode)
        let passportRouteBadges: [PrismRouteBadgeModel] = next.parallelTracksPreference.parallelTrackCodes.map { code in
            if code.caseInsensitiveCompare(resolvedRouteCode) == .orderedSame {
                return PrismRouteBadgeModel(
                    examCode: resolvedRouteCode,
                    officialTitle: resolvedRouteTitle,
                    region: activeRegion
                )
            }
            if let matched = availableTracks.first(where: { $0.code.caseInsensitiveCompare(code) == .orderedSame }) {
                return PrismRouteBadgeModel(
                    examCode: matched.code,
                    officialTitle: matched.title,
                    region: Self.region(forTrackCode: matched.code, title: matched.title)
                )
            }
            let descriptor = CertiGoMultiTrackAndAIContentCatalog.track(forCode: code)
            return PrismRouteBadgeModel(
                examCode: descriptor.code,
                officialTitle: descriptor.officialTitle,
                region: descriptor.region
            )
        }

        // 1. Synchronize Catalog & Global Search routes
        if !availableTracks.isEmpty {
            let routeItems = availableTracks.map { track in
                CatalogRouteItem(
                    id: track.id,
                    code: track.code,
                    officialTitle: track.title,
                    region: Self.region(forTrackCode: track.code, title: track.title),
                    product: BrandRegistry.productID(forTrackCode: track.code),
                    availablePracticeCount: track.learningAvailable ? 12 : 0,
                    isConfirmedActiveGoal: track.code.caseInsensitiveCompare(resolvedRouteCode) == .orderedSame
                        || (candidateTrackId != nil && track.id.caseInsensitiveCompare(candidateTrackId!) == .orderedSame)
                )
            }
            next.catalogExplorer = CatalogExplorerModel(
                routes: routeItems,
                selectedRegion: next.catalogExplorer.selectedRegion,
                searchQuery: next.catalogExplorer.searchQuery,
                onlyWithAvailableExercises: next.catalogExplorer.onlyWithAvailableExercises
            )
        } else if candidateTrackId != nil || mockExam != nil {
            next.catalogExplorer.routes = next.catalogExplorer.routes.map { route in
                var copy = route
                copy.isConfirmedActiveGoal = route.code.caseInsensitiveCompare(resolvedRouteCode) == .orderedSame
                return copy
            }
        }

        // 2. Synchronize Profile (streak, rhythm, passport holder & active route)
        if let profile {
            let streak = max(0, profile.streakDays ?? next.rhythmPlanner.dailyStreakDays)
            next.rhythmPlanner = WeeklyRhythmPlannerModel(
                targetDaysPerWeek: next.rhythmPlanner.targetDaysPerWeek,
                completedDaysThisWeek: next.rhythmPlanner.completedDaysThisWeek,
                bestRhythmWeeks: next.rhythmPlanner.bestRhythmWeeks,
                pauseWeeksRemaining: next.rhythmPlanner.pauseWeeksRemaining,
                completedCatchUpRecalls: next.rhythmPlanner.completedCatchUpRecalls,
                dailyStreakDays: streak,
                dailyStreakEnabled: profile.streakDays != nil ? true : next.rhythmPlanner.dailyStreakEnabled,
                days: next.rhythmPlanner.days
            )
            next.todayModel.rhythm = PrismRhythmWeekModel(
                weeklyGoalDays: next.rhythmPlanner.targetDaysPerWeek,
                days: next.rhythmPlanner.days,
                bestRhythmWeeks: next.rhythmPlanner.bestRhythmWeeks,
                dailyStreakOptIn: next.rhythmPlanner.dailyStreakEnabled,
                dailyStreakDays: streak
            )
            next.todayModel.activeRouteCode = resolvedRouteCode
            next.todayModel.activeRouteTitle = resolvedRouteTitle

            let initials = Self.initials(from: profile.displayName)
            let existingPassport = next.calibrationHistory.passport
            let updatedRouteBadge = PrismRouteBadgeModel(
                examCode: resolvedRouteCode,
                officialTitle: resolvedRouteTitle,
                region: activeRegion
            )
            let updatedPassport = PrismPassportSummary(
                holderPseudonym: profile.displayName,
                holderInitials: initials,
                primaryRegion: activeRegion,
                anchoredConceptsCount: existingPassport.anchoredConceptsCount,
                masteredConceptsCount: existingPassport.masteredConceptsCount,
                completedRhythmWeeks: existingPassport.completedRhythmWeeks,
                routes: passportRouteBadges.isEmpty ? [updatedRouteBadge] : passportRouteBadges,
                verificationLinks: existingPassport.verificationLinks
            )
            next.calibrationHistory = CalibrationHistoryScreenModel(
                passport: updatedPassport,
                samples: next.calibrationHistory.samples,
                recentSessionsCount: next.calibrationHistory.recentSessionsCount
            )
        }

        // 3. Synchronize LearningPath (Today, Atlas, MemoryDetail, Search concepts, Passport counts)
        if let learningPath {
            let allLessons = learningPath.units.flatMap(\.lessons)
            let anchoredLessons = allLessons.filter { $0.status == .completed || $0.status == .mastered }
            let masteredLessons = allLessons.filter { $0.status == .mastered }
            let openLessons = allLessons.filter { $0.status == .available || $0.status == .inProgress }
            let recommendedLesson = allLessons.first(where: { $0.status == .inProgress })
                ?? allLessons.first(where: { $0.status == .available })
                ?? allLessons.first

            next.todayModel = TodayScreenModel(
                state: .content,
                suggestedLength: next.todayModel.suggestedLength,
                selectedLength: next.todayModel.selectedLength,
                composition: TodaySessionAtomSummary(
                    dueRecallsCount: max(1, anchoredLessons.count),
                    newConceptsCount: max(1, openLessons.count),
                    recommendedConceptTitle: recommendedLesson?.title
                        ?? learningPath.units.first?.title
                        ?? next.todayModel.composition.recommendedConceptTitle,
                    recommendedProduct: activeProduct
                ),
                activeRouteCode: resolvedRouteCode,
                activeRouteTitle: resolvedRouteTitle,
                dailySituation: next.todayModel.dailySituation,
                rhythm: next.todayModel.rhythm,
                memoryAnchoredCount: anchoredLessons.count,
                memoryDueSoonCount: openLessons.count,
                interruptedSession: next.todayModel.interruptedSession,
                offlineBanner: next.todayModel.offlineBanner,
                isGuestMode: next.todayModel.isGuestMode,
                isWelcomeBackState: next.todayModel.isWelcomeBackState,
                tomorrowPreviewText: next.todayModel.tomorrowPreviewText
            )

            let territories: [AtlasTerritorySummary] = learningPath.units.map { unit in
                let total = max(1, unit.lessons.count)
                let anchored = unit.lessons.filter { $0.status == .completed || $0.status == .mastered }.count
                let region = Self.region(forTrackCode: resolvedRouteCode, title: unit.title)
                let avgRung = anchored > 0 ? 3.8 : 2.4
                return AtlasTerritorySummary(
                    id: unit.id,
                    title: unit.title,
                    region: region,
                    totalConceptsCount: total,
                    anchoredOrMasteredCount: anchored,
                    averageDepthRung: avgRung
                )
            }

            let groupedByRegion = Dictionary(grouping: territories, by: \.region)
            let regionSummaries = PrismRegion.allCases.compactMap { region -> AtlasRegionSummary? in
                guard let list = groupedByRegion[region], !list.isEmpty else { return nil }
                return AtlasRegionSummary(region: region, territories: list)
            }

            let atlasNodes: [PrismAtlasNode] = allLessons.enumerated().map { index, pathLesson in
                let count = max(1, allLessons.count)
                let normX = min(max(0.2 + (Double(index % 4) * 0.2), 0.1), 0.9)
                let normY = min(max(0.2 + (Double(index) / Double(count)) * 0.65, 0.1), 0.9)
                return PrismAtlasNode(
                    id: pathLesson.id,
                    code: "\(resolvedRouteCode)-\(index + 1)",
                    title: pathLesson.title,
                    region: Self.region(forTrackCode: resolvedRouteCode, title: pathLesson.title),
                    masteryState: Self.masteryState(for: pathLesson.status),
                    normalizedX: normX,
                    normalizedY: normY
                )
            }

            if !regionSummaries.isEmpty || !atlasNodes.isEmpty {
                next.atlasModel = AtlasScreenModel(
                    mode: next.atlasModel.mode,
                    selectedRegion: next.atlasModel.selectedRegion,
                    selectedState: next.atlasModel.selectedState,
                    regions: regionSummaries.isEmpty ? next.atlasModel.regions : regionSummaries,
                    nodes: atlasNodes.isEmpty ? next.atlasModel.nodes : atlasNodes
                )
            }

            if !allLessons.isEmpty {
                let memoryItems = allLessons.enumerated().map { index, pathLesson in
                    let retention = Double(pathLesson.masteryPct ?? (pathLesson.status == .mastered ? 92 : 68)) / 100.0
                    return MemoryConceptItem(
                        id: pathLesson.id,
                        conceptTitle: pathLesson.title,
                        product: activeProduct,
                        masteryState: Self.masteryState(for: pathLesson.status),
                        predictedRetention: retention,
                        lastReviewedDaysAgo: index + 1
                    )
                }
                next.memoryDetail = MemoryDetailScreenModel(
                    forecastPoints: next.memoryDetail.forecastPoints,
                    items: memoryItems
                )
            }

            let existingPassport = next.calibrationHistory.passport
            let fallbackRouteBadge = PrismRouteBadgeModel(
                examCode: resolvedRouteCode,
                officialTitle: resolvedRouteTitle,
                region: activeRegion
            )
            next.calibrationHistory = CalibrationHistoryScreenModel(
                passport: PrismPassportSummary(
                    holderPseudonym: existingPassport.holderPseudonym,
                    holderInitials: existingPassport.holderInitials,
                    primaryRegion: activeRegion,
                    anchoredConceptsCount: max(anchoredLessons.count, existingPassport.anchoredConceptsCount),
                    masteredConceptsCount: max(masteredLessons.count, existingPassport.masteredConceptsCount),
                    completedRhythmWeeks: existingPassport.completedRhythmWeeks,
                    routes: passportRouteBadges.isEmpty ? [fallbackRouteBadge] : passportRouteBadges,
                    verificationLinks: existingPassport.verificationLinks
                ),
                samples: next.calibrationHistory.samples,
                recentSessionsCount: next.calibrationHistory.recentSessionsCount
            )

            if readinessSnapshot == nil {
                let derivedDomains = (learningPath.domains ?? []).map { dom in
                    DomainReadinessSummary(
                        domainId: dom.id,
                        weight: dom.weight,
                        coverage: Double(min(max(dom.score, 0), 100)) / 100.0,
                        mastery: Double(min(max(dom.score, 0), 100)) / 100.0,
                        score: dom.score
                    )
                }
                let derivedSnapshot = ReadinessSnapshot(
                    trackId: learningPath.trackId,
                    score: learningPath.readinessScore,
                    trend7d: learningPath.readinessTrend7d ?? 0,
                    domains: derivedDomains
                )
                next.routeReadiness = Self.makeRouteReadinessModel(
                    snapshot: derivedSnapshot,
                    routeCode: resolvedRouteCode,
                    officialTitle: resolvedRouteTitle,
                    domainNamesById: Dictionary(uniqueKeysWithValues: (learningPath.domains ?? []).map { ($0.id, $0.name) }),
                    fallback: next.routeReadiness
                )
            }
        }

        // 4. Synchronize Lesson into SessionPlayerStateMachine & ConceptDetail
        if let lesson {
            var cards: [PrismSessionCardAtom] = []
            var skipItems: [String: PrismSessionItemModel] = [:]
            let firstQuestionId = lesson.questions.first?.id

            for (index, block) in lesson.blocks.enumerated() {
                if let question = block.check {
                    let options = question.options.enumerated().map { optIdx, opt in
                        return PrismChoiceOption(
                            id: opt.id,
                            badge: Self.optionBadge(at: optIdx),
                            text: opt.label,
                            explanation: opt.label
                        )
                    }
                    let sessionItem = PrismSessionItemModel(
                        id: question.id,
                        conceptId: question.conceptId,
                        product: activeProduct,
                        rung: 3,
                        difficulty: 2,
                        stem: question.stem,
                        captureConfidence: true,
                        payload: .choice(options: options, allowsMultipleSelection: false)
                    )
                    cards.append(.item(sessionItem))
                    skipItems[question.id] = sessionItem
                } else {
                    let cardId = "\(lesson.id)-block-\(index)"
                    let conceptId = lesson.questions.first?.conceptId ?? lesson.id
                    let cardTitle = block.title ?? lesson.title
                    let bodyText = block.body ?? block.code ?? lesson.title
                    let kind: PrismLearningCardKind
                    switch block.type {
                    case "hook":
                        kind = .openingQuestion(prompt: bodyText, contextNote: cardTitle)
                    case "example":
                        let example = PrismWorkedExample(
                            id: "\(cardId)-we",
                            title: cardTitle,
                            problemContext: bodyText,
                            steps: [
                                PrismWorkedStep(
                                    id: "\(cardId)-s1",
                                    stepNumber: 1,
                                    subgoalTitle: cardTitle,
                                    detail: bodyText
                                )
                            ],
                            conclusion: bodyText,
                            isSkippable: firstQuestionId != nil
                        )
                        kind = .workedExample(example, skipVerificationItemId: firstQuestionId)
                    case "code":
                        let codeSource = block.code ?? bodyText
                        let lines = codeSource.split(separator: "\n", omittingEmptySubsequences: false)
                            .enumerated()
                            .map { lineIdx, line in
                                PrismArtifactLine(lineNumber: lineIdx + 1, text: String(line))
                            }
                        let doc = PrismArtifactDocument(
                            id: "\(cardId)-code",
                            title: cardTitle,
                            language: "cli",
                            lines: lines.isEmpty ? [PrismArtifactLine(lineNumber: 1, text: codeSource)] : lines
                        )
                        kind = .artifactStudy(doc, takeaway: bodyText)
                    default:
                        kind = .explanation(
                            PrismExplanationSpec(
                                id: "\(cardId)-exp",
                                title: cardTitle,
                                body: bodyText,
                                keyPoints: [bodyText]
                            )
                        )
                    }
                    cards.append(
                        .learning(
                            PrismLearningCardModel(
                                id: cardId,
                                conceptId: conceptId,
                                title: cardTitle,
                                product: activeProduct,
                                kind: kind
                            )
                        )
                    )
                }
            }

            if !cards.isEmpty {
                let plan = PrismSessionPlan(
                    id: "plan-\(lesson.id)",
                    length: next.todayModel.selectedLength,
                    cards: cards,
                    skipVerificationItems: skipItems
                )
                next.sessionPlayerMachine = SessionPlayerStateMachine(plan: plan)
            }

            let primaryConceptId = lesson.questions.first?.conceptId ?? lesson.id
            let summaryText = lesson.blocks.compactMap(\.body).first ?? lesson.title
            next.conceptDetail = ConceptDetailScreenModel(
                id: primaryConceptId,
                code: resolvedRouteCode,
                title: lesson.title,
                summary: summaryText,
                product: activeProduct,
                region: activeRegion,
                masteryState: next.conceptDetail.masteryState,
                depthLadder: PrismDepthLadderModel(
                    conceptTitle: lesson.title,
                    currentLevel: next.conceptDetail.depthLadder.currentLevel,
                    practiceOffPhoneRecommended: true
                ),
                predictedRetention: next.conceptDetail.predictedRetention,
                forecastPoints: next.conceptDetail.forecastPoints,
                activeMisconception: next.conceptDetail.activeMisconception
            )
        }

        // 5. Synchronize ReadinessSnapshot into RouteReadinessScreenModel
        if let readinessSnapshot {
            let domainNames = Dictionary(
                uniqueKeysWithValues: (learningPath?.domains ?? []).map { ($0.id, $0.name) }
            )
            next.routeReadiness = Self.makeRouteReadinessModel(
                snapshot: readinessSnapshot,
                routeCode: resolvedRouteCode,
                officialTitle: resolvedRouteTitle,
                domainNamesById: domainNames,
                fallback: next.routeReadiness
            )
        }

        // 6. Synchronize MockExam into MockExamStateMachine
        if let mockExam {
            let domainTitles = Dictionary(
                uniqueKeysWithValues: mockExam.blueprint.map { ($0.domainId, $0.name) }
            )
            let examProduct = BrandRegistry.productID(forTrackCode: mockExam.trackCode)
            let questions: [MockExamQuestionRecord] = mockExam.items.map { item in
                let options = item.options.enumerated().map { optIdx, opt in
                    return PrismChoiceOption(
                        id: opt.id,
                        badge: Self.optionBadge(at: optIdx),
                        text: opt.label,
                        explanation: opt.label
                    )
                }
                let sessionItem = PrismSessionItemModel(
                    id: item.itemId,
                    conceptId: item.lessonId,
                    product: examProduct,
                    stem: item.stem,
                    captureConfidence: true,
                    isMockExamMode: true,
                    payload: .choice(options: options, allowsMultipleSelection: false)
                )
                return MockExamQuestionRecord(
                    item: sessionItem,
                    domainId: item.domainId,
                    domainTitle: domainTitles[item.domainId] ?? item.domainId
                )
            }
            let durationMinutes = max(5, mockExam.timeLimitSeconds / 60)
            next.mockExamMachine = MockExamStateMachine(
                examId: mockExam.examId,
                routeCode: mockExam.trackCode,
                routeTitle: mockExam.trackTitle,
                baseDurationMinutes: durationMinutes,
                timePolicy: next.mockExamMachine.timePolicy,
                questions: questions.isEmpty ? next.mockExamMachine.questions : questions
            )
        } else {
            next.mockExamMachine = MockExamStateMachine(
                examId: "exam-\(resolvedRouteCode.lowercased())",
                routeCode: resolvedRouteCode,
                routeTitle: resolvedRouteTitle,
                baseDurationMinutes: next.parallelTracksPreference.strictTimed90Min ? 90 : 40,
                timePolicy: next.parallelTracksPreference.strictTimed90Min ? .standardTimed : .untimed,
                questions: next.mockExamMachine.questions
            )
        }

        // 7. Synchronize TutorExplanation into ContextualAISessionState & ConceptDetail
        if let tutorExplanation {
            next.latestTutorExplanation = tutorExplanation
            let excerptParts = [tutorExplanation.headline] + tutorExplanation.points + [tutorExplanation.recommendation]
            let excerptText = excerptParts
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " • ")
            let snippet = AIGroundedSnippet(
                id: "tutor-\(tutorExplanation.itemId)",
                cardTitle: tutorExplanation.headline,
                verifiedDateLabel: tutorExplanation.source,
                excerpt: excerptText.isEmpty ? tutorExplanation.headline : excerptText,
                officialDocURL: "https://learn.microsoft.com/"
            )
            next.contextualAISession = ContextualAISessionState(
                conceptId: tutorExplanation.conceptId,
                brandProductId: activeProduct,
                routeCode: resolvedRouteCode,
                snippet: snippet,
                hintLadder: next.contextualAISession.hintLadder,
                whyTurnCount: next.contextualAISession.whyTurnCount,
                showOptionalAnalogy: next.contextualAISession.showOptionalAnalogy,
                feedbackSignal: next.contextualAISession.feedbackSignal,
                router: next.contextualAISession.router
            )
            let misconception = tutorExplanation.personalization.topConfusedOption
                ?? (tutorExplanation.personalization.recurringStruggle ? tutorExplanation.recommendation : next.conceptDetail.activeMisconception)
            next.conceptDetail = ConceptDetailScreenModel(
                id: tutorExplanation.conceptId,
                code: resolvedRouteCode,
                title: tutorExplanation.headline,
                summary: tutorExplanation.points.first ?? tutorExplanation.recommendation,
                product: activeProduct,
                region: activeRegion,
                masteryState: tutorExplanation.correct ? .anchored : .practicing,
                depthLadder: next.conceptDetail.depthLadder,
                predictedRetention: Double(min(max(tutorExplanation.personalization.accuracyPct, 0), 100)) / 100.0,
                forecastPoints: next.conceptDetail.forecastPoints,
                activeMisconception: misconception
            )
        }

        // 8. Rebuild GlobalSearchScreenModel catalog when routes, path, or lesson change
        if !availableTracks.isEmpty || learningPath != nil || lesson != nil {
            var searchItems: [GlobalSearchResultItem] = []
            for node in next.atlasModel.nodes {
                searchItems.append(
                    GlobalSearchResultItem(
                        id: node.id,
                        kind: .concept,
                        title: node.title,
                        subtitle: node.code,
                        product: activeProduct,
                        region: node.region
                    )
                )
            }
            for route in next.catalogExplorer.routes {
                searchItems.append(
                    GlobalSearchResultItem(
                        id: route.code,
                        kind: .route,
                        title: "\(route.code) · \(route.officialTitle)",
                        subtitle: route.isConfirmedActiveGoal ? "Route de certification active" : "Route du catalogue",
                        product: route.product,
                        region: route.region
                    )
                )
            }
            if !searchItems.isEmpty {
                next.searchModel = GlobalSearchScreenModel(
                    query: next.searchModel.query,
                    catalog: searchItems
                )
            }
        }

        if let preferenceStore {
            try? preferenceStore.save(next.parallelTracksPreference)
        }

        return next
    }

    private static func normalizedRouteCode(from rawTrackId: String) -> String {
        let trimmed = rawTrackId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "AZ-104" }
        return trimmed.uppercased()
    }

    private static func optionBadge(at index: Int) -> String {
        let letters = ["A", "B", "C", "D", "E", "F", "G", "H"]
        return letters[max(0, index) % letters.count]
    }

    private static func initials(from displayName: String) -> String {
        let parts = displayName
            .split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "_" })
            .filter { !$0.isEmpty }
        if parts.count >= 2,
           let first = parts.first?.first,
           let second = parts.dropFirst().first?.first
        {
            return "\(first)\(second)".uppercased()
        }
        let cleaned = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "CG" : String(cleaned.prefix(2)).uppercased()
    }

    private static func masteryState(for status: NodeStatus) -> PrismMasteryState {
        switch status {
        case .locked:
            return .undiscovered
        case .available:
            return .discovered
        case .inProgress:
            return .practicing
        case .completed:
            return .anchored
        case .mastered:
            return .mastered
        }
    }

    private static func region(forTrackCode code: String, title: String = "") -> PrismRegion {
        let upper = code.uppercased()
        let lowerTitle = title.lowercased()
        if upper.hasPrefix("AI-") || lowerTitle.contains("ia") || lowerTitle.contains("foundry") || lowerTitle.contains("openai") {
            return .ai
        }
        if upper.hasPrefix("SC-") || lowerTitle.contains("sécurité") || lowerTitle.contains("identit") || lowerTitle.contains("entra") || lowerTitle.contains("security") {
            return .security
        }
        if upper.hasPrefix("DP-") || lowerTitle.contains("fabric") || lowerTitle.contains("data") || lowerTitle.contains("données") {
            return .data
        }
        if upper.hasPrefix("GH-") || upper == "AZ-400" || lowerTitle.contains("copilot") || lowerTitle.contains("devops") || lowerTitle.contains("github") {
            return .devops
        }
        if upper == "AZ-700" || lowerTitle.contains("réseau") || lowerTitle.contains("vnet") || lowerTitle.contains("dns") || lowerTitle.contains("network") {
            return .network
        }
        if upper.hasPrefix("CK") || lowerTitle.contains("kubernetes") {
            return .systems
        }
        return .cloud
    }

    private static func makeRouteReadinessModel(
        snapshot: ReadinessSnapshot,
        routeCode: String,
        officialTitle: String,
        domainNamesById: [String: String],
        fallback: RouteReadinessScreenModel
    ) -> RouteReadinessScreenModel {
        let clampedScore = min(max(snapshot.score, 0), 100)
        let band: PrismReadinessBand = {
            if snapshot.domains.isEmpty && clampedScore == 0 {
                return .insufficientEvidence
            }
            if clampedScore >= 85 { return .veryReady }
            if clampedScore >= 70 { return .readyToTry }
            if clampedScore >= 50 { return .onTrack }
            return .notYet
        }()

        let coverageItems: [PrismObjectiveCoverageItem] = snapshot.domains.enumerated().map { idx, dom in
            let title = domainNamesById[dom.domainId] ?? dom.domainId
            let stage = (try? MasteryStage.resolved(coverage: dom.coverage, mastery: dom.mastery, score: dom.score)) ?? .learning
            let mastery: PrismMasteryState = {
                switch stage {
                case .notStarted: return .undiscovered
                case .learning: return .discovered
                case .practicing: return .practicing
                case .mastered: return .anchored
                case .examReady: return .mastered
                }
            }()
            let verifiedCount = max(0, Int((min(max(dom.coverage, 0.0), 1.0) * 10.0).rounded()))
            return PrismObjectiveCoverageItem(
                id: dom.domainId,
                objectiveCode: "D\(idx + 1)",
                title: title,
                region: Self.region(forTrackCode: routeCode, title: title),
                masteryState: mastery,
                verifiedEvidenceCount: verifiedCount,
                targetEvidenceCount: 10
            )
        }

        let rawProb = Double(clampedScore) / 100.0
        let totalEvidence = max(
            snapshot.domains.count * 4,
            coverageItems.reduce(0) { $0 + $1.verifiedEvidenceCount }
        )
        let weakestDomains = coverageItems
            .sorted { $0.verifiedEvidenceCount < $1.verifiedEvidenceCount }
            .prefix(2)
            .map { "Renforcer \($0.title)" }

        let readiness = PrismReadinessModel(
            band: band,
            isCalibrated: totalEvidence > 0 && band != .insufficientEvidence,
            rawProbability: rawProb,
            uncertaintyLow: max(0.0, rawProb - 0.08),
            uncertaintyHigh: min(1.0, rawProb + 0.08),
            evidenceCount: totalEvidence,
            recommendedActions: weakestDomains.isEmpty ? fallback.readiness.recommendedActions : Array(weakestDomains)
        )

        return RouteReadinessScreenModel(
            routeCode: routeCode,
            officialTitle: officialTitle,
            product: BrandRegistry.productID(forTrackCode: routeCode),
            region: Self.region(forTrackCode: routeCode, title: officialTitle),
            isConfirmedOnServer: true,
            readiness: readiness,
            objectiveCoverage: coverageItems.isEmpty ? fallback.objectiveCoverage : coverageItems,
            historyWeeksCount: max(3, fallback.historyWeeksCount),
            estimatedReadyDateRange: fallback.estimatedReadyDateRange
        )
    }

    public var motionSpecsCatalog: [CertiGoMotionPresetSpec] {
        CertiGoMotionSpecCatalog.allSpecs
    }

    public func resolvedMotion(
        for preset: CertiGoAnimationPresetID,
        reduceMotion: Bool
    ) -> PrismResolvedMotion {
        preset.resolved(reduceMotion: reduceMotion)
    }
}

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

// MARK: - 2. Unified 5-Tab Prism App Shell View (§12, §13, §14, Phases 1..11)

public struct PrismAppShellView: View {
    @State private var router: AppRouterState
    @State private var coordinator: PrismAppShellCoordinatorModel
    public let flags: FeatureFlags
    public let preferenceStore: CertigoParallelTracksPreferenceStore

    public init(
        router: AppRouterState = AppRouterState(),
        coordinator: PrismAppShellCoordinatorModel = PrismAppShellCoordinatorModel()
            .withPersistedPreferencesLoaded(from: .shared),
        flags: FeatureFlags = FeatureFlags(),
        preferenceStore: CertigoParallelTracksPreferenceStore = .shared
    ) {
        self._router = State(initialValue: router)
        self._coordinator = State(initialValue: coordinator)
        self.flags = flags
        self.preferenceStore = preferenceStore
    }

    public var body: some View {
        CertiGoFigmaInteractiveAppView(
            initialScreenNodeId: "37:375",
            coordinator: $coordinator,
            router: $router,
            flags: flags,
            preferenceStore: preferenceStore
        )
    }
}

// MARK: - 3. Brand/Cert Switcher Tray (`PrismCourseSwitcherTrayView`)

public struct PrismCourseSwitcherTrayView: View {
    public struct BrandFilterSpec: Identifiable, Equatable, Sendable {
        public let id: String
        public let label: String
        public let product: BrandProductID

        public init(id: String, label: String, product: BrandProductID) {
            self.id = id
            self.label = label
            self.product = product
        }
    }

    public struct CourseItemSpec: Identifiable, Equatable, Sendable {
        public var id: String { code }
        public let code: String
        public let title: String
        public let brandId: String
        public let progressText: String
        public let product: BrandProductID

        public init(
            code: String,
            title: String,
            brandId: String,
            progressText: String,
            product: BrandProductID
        ) {
            self.code = code
            self.title = title
            self.brandId = brandId
            self.progressText = progressText
            self.product = product
        }
    }

    public let activeRouteCode: String
    public let parallelTracksPreference: CertigoParallelTracksPreference
    @Binding public var selectedBrandFilter: String
    public let flags: FeatureFlags
    public let onSelectCourse: (String, String) -> Void
    public let onToggleParallelTrack: (String) -> Void
    public let onToggleAIFrontierTrack: (String) -> Void
    public let onOpenFullCatalog: () -> Void
    public let onDismiss: () -> Void

    public init(
        activeRouteCode: String = "AZ-104",
        parallelTracksPreference: CertigoParallelTracksPreference = CertigoParallelTracksPreference(),
        selectedBrandFilter: Binding<String>,
        flags: FeatureFlags = FeatureFlags(),
        onSelectCourse: @escaping (String, String) -> Void = { _, _ in },
        onToggleParallelTrack: @escaping (String) -> Void = { _ in },
        onToggleAIFrontierTrack: @escaping (String) -> Void = { _ in },
        onOpenFullCatalog: @escaping () -> Void = {},
        onDismiss: @escaping () -> Void = {}
    ) {
        self.activeRouteCode = activeRouteCode
        self.parallelTracksPreference = parallelTracksPreference
        self._selectedBrandFilter = selectedBrandFilter
        self.flags = flags
        self.onSelectCourse = onSelectCourse
        self.onToggleParallelTrack = onToggleParallelTrack
        self.onToggleAIFrontierTrack = onToggleAIFrontierTrack
        self.onOpenFullCatalog = onOpenFullCatalog
        self.onDismiss = onDismiss
    }

    private var brandFilters: [BrandFilterSpec] {
        [
            .init(id: "all", label: "Toutes (39)", product: .azureVirtualNetwork),
            .init(id: "microsoft", label: "Microsoft", product: .azureVirtualNetwork),
            .init(id: "aws", label: "AWS", product: BrandProductID("aws-vpc")),
            .init(id: "gcp", label: "Google", product: BrandProductID("gcp-compute-engine")),
            .init(id: "github", label: "GitHub", product: BrandProductID("github-copilot")),
            .init(id: "cncf", label: "CNCF", product: BrandProductID("kubernetes"))
        ]
    }

    private var courses: [CourseItemSpec] {
        let all: [CourseItemSpec] = [
            .init(code: "AZ-104", title: "Administrateur Microsoft Azure", brandId: "microsoft", progressText: "Unité 3 · 68 % prêt", product: .azureVirtualNetwork),
            .init(code: "AI-102", title: "Azure AI Engineer & Foundry", brandId: "microsoft", progressText: "Unité 2 · 42 % prêt", product: BrandProductID("azure-openai")),
            .init(code: "AZ-305", title: "Solutions Architect Expert", brandId: "microsoft", progressText: "Unité 4 · 54 % prêt", product: .azureVirtualMachines),
            .init(code: "SAA-C03", title: "AWS Solutions Architect Assoc.", brandId: "aws", progressText: "Unité 1 · 20 % prêt", product: BrandProductID("aws-vpc")),
            .init(code: "ACE", title: "Google Associate Cloud Engineer", brandId: "gcp", progressText: "Nouveau parcours", product: BrandProductID("gcp-compute-engine")),
            .init(code: "GH-300", title: "GitHub Copilot Certification", brandId: "github", progressText: "Unité 2 · 75 % prêt", product: BrandProductID("github-copilot")),
            .init(code: "CKA", title: "Certified Kubernetes Admin", brandId: "cncf", progressText: "Unité 1 · 35 % prêt", product: BrandProductID("kubernetes"))
        ]
        if selectedBrandFilter == "all" { return all }
        return all.filter { $0.brandId == selectedBrandFilter }
    }

    public var body: some View {
        ZStack(alignment: .top) {
            PrismColor.textPrimary.opacity(0.32)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(alignment: .leading, spacing: PrismSpacing.m) {
                Text(verbatim: "CHOISIR UNE MARQUE (LOGOS DÉTOURÉS)")
                    .prismTextStyle(.caption)
                    .foregroundStyle(PrismColor.textSecondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: PrismSpacing.s) {
                        ForEach(brandFilters) { brand in
                            let isSelected = selectedBrandFilter == brand.id
                            Button {
                                selectedBrandFilter = brand.id
                            } label: {
                                VStack(spacing: PrismSpacing.xxs) {
                                    CertiGoBrandLogoView(
                                        vendorId: brand.id == "all" ? "azure" : brand.id,
                                        size: PrismSize.brandS
                                    )
                                    Text(verbatim: brand.label)
                                        .prismTextStyle(.caption)
                                        .foregroundStyle(isSelected ? PrismColor.accent : PrismColor.textPrimary)
                                }
                                .frame(minWidth: PrismSize.brandFilterWidth)
                                .padding(.vertical, PrismSpacing.s)
                                .padding(.horizontal, PrismSpacing.s)
                                .background(
                                    RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                        .fill(isSelected ? PrismColor.accent.opacity(0.12) : PrismColor.canvas)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                        .strokeBorder(
                                            isSelected ? PrismColor.accent : PrismColor.separator,
                                            lineWidth: isSelected ? PrismBorder.strong : PrismBorder.regular
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Text(verbatim: "PARCOURS EN PARALLÈLE (\(parallelTracksPreference.parallelTrackCodes.count)) & VEILLE IA (\(parallelTracksPreference.aiFrontierTrackCodes.count))")
                    .prismTextStyle(.caption)
                    .foregroundStyle(PrismColor.textSecondary)

                ForEach(courses) { course in
                    let isActive = course.code == activeRouteCode
                    let isTrackedInParallel = parallelTracksPreference.isTrackingParallelCertification(course.code)
                    HStack(spacing: PrismSpacing.m) {
                        Button {
                            onSelectCourse(course.code, course.title)
                        } label: {
                            HStack(spacing: PrismSpacing.m) {
                                CertiGoOfficialCrestView(
                                    routeCode: course.code,
                                    size: PrismSize.brandM
                                )
                                VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                                    Text(verbatim: course.code)
                                        .prismTextStyle(.caption)
                                        .foregroundStyle(PrismColor.accent)
                                    Text(verbatim: course.title)
                                        .prismTextStyle(.subheadline)
                                        .foregroundStyle(PrismColor.textPrimary)
                                    Text(verbatim: course.progressText)
                                        .prismTextStyle(.caption)
                                        .foregroundStyle(PrismColor.textSecondary)
                                }
                                Spacer(minLength: PrismSpacing.xs)
                                if isActive {
                                    PrismBadge(
                                        configuration: PrismBadgeConfiguration(
                                            text: "Actif",
                                            semantics: .accent
                                        )
                                    )
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        Button {
                            onToggleParallelTrack(course.code)
                        } label: {
                            Image(systemName: isTrackedInParallel ? "checkmark.circle.fill" : "plus.circle")
                                .prismTextStyle(.title3)
                                .foregroundStyle(isTrackedInParallel ? PrismColor.positive : PrismColor.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(PrismSpacing.m)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                            .fill(isActive ? PrismColor.accent.opacity(0.1) : PrismColor.canvas)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                            .strokeBorder(
                                isActive ? PrismColor.accent : PrismColor.separator,
                                lineWidth: isActive ? PrismBorder.strong : PrismBorder.regular
                            )
                    )
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: PrismSpacing.xs) {
                        ForEach(CertigoParallelTracksPreference.defaultAIFrontierTrackCodes, id: \.self) { aiCode in
                            let isFollowed = parallelTracksPreference.isTrackingAIFrontier(aiCode)
                            PrismChip(
                                configuration: PrismChipConfiguration(
                                    title: aiCode,
                                    isSelected: isFollowed
                                )
                            ) {
                                onToggleAIFrontierTrack(aiCode)
                            }
                        }
                    }
                }

                Button {
                    onOpenFullCatalog()
                } label: {
                    Text(verbatim: "+ Explorer les 39 certifications du catalogue")
                        .prismTextStyle(.subheadline)
                        .foregroundStyle(PrismColor.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, PrismSpacing.s)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                .fill(PrismColor.canvas)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(PrismSpacing.l)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                    .fill(PrismColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                    .strokeBorder(PrismColor.separator, lineWidth: PrismBorder.standard)
            )
            .padding(.horizontal, PrismSpacing.m)
            .padding(.top, PrismSpacing.xs)
        }
    }
}
#endif
