import BrandAssets
import CertigoDomain
import Foundation
import Prism
import Testing

@Suite("Phase 11 — Accessibility AX5, Performance Budgets §30, Analytics Taxonomy §31 & Hardening (§28–34)")
struct Phase11HardeningTests {

    @Test("§28 Accessibility audit verifies all 13 dimensions and all 9 App Store Nutrition Labels")
    func accessibilityAuditAndAppStoreNutritionLabels() {
        let summary = AccessibilityAuditSummary()
        #expect(summary.passesAllAccessibilityGates == true)
        #expect(summary.verifiedDimensions.count == 13)
        #expect(summary.eligibleNutritionLabels.count == 9)
        #expect(summary.minimumTapTargetPt >= 44.0)
        #expect(summary.calmModeMaxCelebrationLevel == 1)
    }

    @Test("§30 Performance budget gate enforces cold launch, transition, feedback, Atlas 60fps/500 nodes, memory, size, and energy")
    func performanceBudgetsMeetSection30Thresholds() {
        let nominal = PerformanceBudgetSnapshot()
        #expect(nominal.meetsAllSection30Budgets == true)

        let regressed = PerformanceBudgetSnapshot(coldLaunchMs: 520, activeRestingTimersOrLoops: 1)
        #expect(regressed.meetsAllSection30Budgets == false)
    }

    @Test("§31 Normative analytics taxonomy uses strict snake_case and emits critical journey events in Debug")
    func normativeAnalyticsTaxonomyAndCriticalJourneys() {
        #expect(NormativeAnalyticsEventName.allCases.count == 53)
        for event in NormativeAnalyticsEventName.allCases {
            #expect(event.isSnakeCase == true)
        }
        let journeys = CriticalJourneyDescriptor.allEightJourneys
        #expect(journeys.count == 8)
        for journey in journeys {
            #expect(journey.passesAccessibilityAudit == true)
        }
    }

    @Test("§34.1 Legacy path retirement requires >= 14 days ON in production with 0 incident")
    func legacyPathRetirementGovernance() {
        let tooEarly = LegacyPathCleanupGovernance(flag: FeatureFlag.allCases[0], daysEnabledInProduction: 10, recordedIncidents: 0)
        #expect(tooEarly.isEligibleForLegacyPathDeletion == false)

        let withIncident = LegacyPathCleanupGovernance(flag: FeatureFlag.allCases[0], daysEnabledInProduction: 21, recordedIncidents: 1)
        #expect(withIncident.isEligibleForLegacyPathDeletion == false)

        let ready = LegacyPathCleanupGovernance(flag: FeatureFlag.allCases[0], daysEnabledInProduction: 14, recordedIncidents: 0)
        #expect(ready.isEligibleForLegacyPathDeletion == true)
    }

    @Test("Page 12 RES-01 offline pack manager enforces 142 MB multi-track packs, DR-004 queue, and reader memo mascot")
    func res01OfflinePackManagerEnforces142MBAndDR004Invariants() {
        var manager = CertiGoOfflinePackManagerModel()
        #expect(manager.screenCode == "RES-01")
        #expect(manager.mascotPose == .poseReaderMemo)
        #expect(manager.storesAnswerKeysOffline == false)
        #expect(manager.maxPrecomposedSessionsPerTrack == 2)
        #expect(manager.conformsToDR004OfflinePolicy == true)
        #expect(manager.packs.count == 3)
        #expect(manager.packs.map(\.sizeMB) == [68, 52, 22])
        #expect(manager.totalDownloadedSizeMB == 142)
        #expect(manager.totalDownloadedSizeLabel == "142 Mo")
        #expect(manager.totalPlayableOfflineSessionsCount == 6)

        manager.enqueueOfflineSubmission(clientAttemptId: "attempt-az104-offline-1")
        #expect(manager.queuedSubmissionsCount == 2)
        manager.enqueueOfflineSubmission(clientAttemptId: "attempt-ai-frontier-offline-3")
        #expect(manager.queuedSubmissionsCount == 3)
        #expect(manager.lastSyncConfirmationMessage == PrismOfflineSessionCache.offlineQueuedMessage)

        let flushed = manager.synchronizeQueuedSubmissionsOnReconnect()
        #expect(flushed == 3)
        #expect(manager.queuedSubmissionsCount == 0)
        #expect(manager.isAirplaneOrTrainOfflineMode == false)

        manager.togglePackDownload(id: "offline-pack-ai-frontier")
        #expect(manager.totalDownloadedSizeMB == 120)
    }

    @Test("Unified PrismAppShellCoordinatorModel initializes all 5 tabs, covers, and sheets cleanly")
    func prismAppShellCoordinatorInitializesAllSurfaces() {
        let coordinator = PrismAppShellCoordinatorModel()
        #expect(coordinator.todayModel.activeRouteCode == "AZ-104")
        #expect(coordinator.atlasModel.visibleFilteredNodes.count >= 2)
        #expect(coordinator.searchModel.filteredResults.count == 2)
        #expect(coordinator.sessionPlayerMachine.plan.cards.count == 2)
        #expect(coordinator.mockExamMachine.routeCode == "AZ-104")
    }

    @Test("PrismAppShellCoordinatorModel.synchronized bridges live Profile, Catalog, LearningPath, Lesson, ReadinessSnapshot, MockExam, and TutorExplanation")
    func prismAppShellCoordinatorSynchronizesLiveCertigoDomainAndData() {
        let profile = Profile(
            id: "user-live-1",
            displayName: "Gabriel Chambaud",
            xp: 2450,
            activeTrackId: "ai-102",
            level: 7,
            streakDays: 14,
            dailyGoalXp: 50,
            dailyXpEarned: 40,
            gems: 320
        )
        let catalog = Catalog(
            tracks: [
                Track(
                    id: "ai-102",
                    code: "AI-102",
                    title: "Microsoft Azure AI Engineer Associate",
                    summary: "Foundry, RAG & Agents",
                    learningAvailable: true
                ),
                Track(
                    id: "az-104",
                    code: "AZ-104",
                    title: "Microsoft Azure Administrator",
                    summary: "Identity, Network & Storage",
                    learningAvailable: true
                )
            ]
        )
        let learningPath = LearningPath(
            trackId: "ai-102",
            trackName: "Microsoft Azure AI Engineer Associate",
            readinessScore: 76,
            units: [
                PathUnit(
                    id: "u-rag",
                    title: "Architecture IA & Recherche Hybride",
                    lessons: [
                        PathLesson(
                            id: "l-rag-1",
                            title: "Indexation vectorielle Azure AI Search",
                            status: .mastered,
                            estMinutes: 10,
                            masteryPct: 92
                        ),
                        PathLesson(
                            id: "l-rag-2",
                            title: "Orchestration Foundry Agent Service",
                            status: .inProgress,
                            estMinutes: 12,
                            masteryPct: 64
                        )
                    ],
                    domainId: "dom-ai",
                    status: "inProgress"
                )
            ],
            domains: [
                DomainProgress(id: "dom-ai", name: "Concevoir des solutions IA génératives", weight: 1.0, score: 76)
            ],
            readinessTrend7d: 8
        )
        let lesson = Lesson(
            id: "l-rag-2",
            trackId: "ai-102",
            title: "Orchestration Foundry Agent Service",
            blocks: [
                LessonBlock(
                    type: "example",
                    title: "Connecter un agent Foundry à Azure AI Search",
                    body: "Configurer l'outil de recherche hybride avec reclassement sémantique."
                ),
                LessonBlock(
                    type: "check",
                    check: QuizItem(
                        id: "q-rag-1",
                        conceptId: "ai102.foundry.rag",
                        type: "mcq",
                        stem: "Quel composant assure le reclassement sémantique dans Azure AI Search ?",
                        options: [
                            QuizOption(id: "opt-a", label: "Semantic Ranker L2"),
                            QuizOption(id: "opt-b", label: "Blob Lifecycle Policy")
                        ]
                    )
                )
            ]
        )
        let readinessSnapshot = ReadinessSnapshot(
            trackId: "ai-102",
            score: 82,
            trend7d: 9,
            domains: [
                DomainReadinessSummary(
                    domainId: "dom-ai",
                    weight: 1.0,
                    coverage: 0.9,
                    mastery: 1.0,
                    score: 82
                )
            ]
        )
        let mockExam = MockExam(
            examId: "exam-ai102-live",
            trackId: "ai-102",
            trackCode: "AI-102",
            trackTitle: "Microsoft Azure AI Engineer Associate",
            timeLimitSeconds: 2700,
            passingScore: 700,
            blueprint: [
                MockExamBlueprintDomain(domainId: "dom-ai", name: "Solutions IA & Foundry", weight: 1.0, itemCount: 1)
            ],
            items: [
                MockExamItem(
                    itemId: "mex-ai-1",
                    lessonId: "l-rag-2",
                    domainId: "dom-ai",
                    type: "mcq",
                    stem: "Quelle stratégie minimise les hallucinations d'un agent RAG ?",
                    options: [
                        QuizOption(id: "a", label: "Ancrage hybride vectoriel + citations"),
                        QuizOption(id: "b", label: "Température à 2.0 sans contexte")
                    ]
                )
            ]
        )
        let tutorExplanation = TutorExplanation(
            itemId: "q-rag-1",
            conceptId: "ai102.foundry.rag",
            correct: true,
            headline: "Reclassement sémantique L2 sur Azure AI Search",
            points: ["Combine BM25 + vecteurs HNSW avec RRF puis applique le modèle sémantique L2."],
            encouragement: "Excellente maîtrise de l'architecture RAG.",
            recommendation: "Pratique la configuration du profil sémantique dans Foundry.",
            citedConceptIds: ["ai102.foundry.rag"],
            source: "27 oct. 2026",
            personalization: TutorPersonalization(
                attempts: 3,
                errors: 1,
                accuracyPct: 88,
                recurringStruggle: false,
                masteredBefore: true,
                trend: "improving",
                topConfusedOption: "Confondre RRF et Semantic Ranker"
            )
        )

        let synced = PrismAppShellCoordinatorModel().synchronized(
            profile: profile,
            catalog: catalog,
            learningPath: learningPath,
            lesson: lesson,
            readinessSnapshot: readinessSnapshot,
            mockExam: mockExam,
            tutorExplanation: tutorExplanation
        )

        #expect(synced.todayModel.activeRouteCode == "AI-102")
        #expect(synced.todayModel.activeRouteTitle == "Microsoft Azure AI Engineer Associate")
        #expect(synced.todayModel.rhythm.dailyStreakDays == 14)
        #expect(synced.todayModel.composition.recommendedConceptTitle == "Orchestration Foundry Agent Service")
        #expect(synced.catalogExplorer.routes.count == 2)
        #expect(synced.catalogExplorer.routes.first(where: { $0.code == "AI-102" })?.isConfirmedActiveGoal == true)
        #expect(synced.atlasModel.nodes.count == 2)
        #expect(synced.memoryDetail.items.count == 2)
        #expect(synced.sessionPlayerMachine.plan.id == "plan-l-rag-2")
        #expect(synced.sessionPlayerMachine.plan.cards.count == 2)
        #expect(synced.routeReadiness.routeCode == "AI-102")
        #expect(synced.routeReadiness.readiness.band == .readyToTry)
        #expect(synced.routeReadiness.objectiveCoverage.first?.verifiedEvidenceCount == 9)
        #expect(synced.mockExamMachine.examId == "exam-ai102-live")
        #expect(synced.mockExamMachine.routeCode == "AI-102")
        #expect(synced.mockExamMachine.questions.count == 1)
        #expect(synced.latestTutorExplanation == tutorExplanation)
        #expect(synced.contextualAISession.conceptId == "ai102.foundry.rag")
        #expect(synced.conceptDetail.id == "ai102.foundry.rag")
        #expect(synced.conceptDetail.activeMisconception == "Confondre RRF et Semantic Ranker")
        #expect(synced.calibrationHistory.passport.holderPseudonym == "Gabriel Chambaud")
        #expect(synced.calibrationHistory.passport.holderInitials == "GC")
    }
}
