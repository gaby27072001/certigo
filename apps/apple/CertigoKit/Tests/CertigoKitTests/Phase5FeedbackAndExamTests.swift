import BrandAssets
import CertigoDomain
import Foundation
import Prism
import Testing

@Suite struct Phase5FeedbackAndExamTests {
    @Test func singleStepFeedbackResolvesConfidentErrorAIUnavailableAndExpandableOptions() {
        let optA = PrismChoiceOption(
            id: "a",
            badge: "A",
            text: "Stocker la clé dans appsettings.json",
            explanation: "Expose le secret en clair dans le dépôt.",
            isCorrect: false
        )
        let optB = PrismChoiceOption(
            id: "b",
            badge: "B",
            text: "Utiliser Managed Identity + Azure Key Vault",
            explanation: "Aucun secret n'est stocké dans le code.",
            isCorrect: true
        )
        let optC = PrismChoiceOption(
            id: "c",
            badge: "C",
            text: "Passer la clé en paramètre d'URL",
            explanation: "Expose le secret dans les journaux HTTP.",
            isCorrect: false
        )

        var confidentError = SessionFeedbackResolution(
            itemId: "item-1",
            isCorrect: false,
            confidence: .sure,
            aiAvailable: true,
            chosenOption: optA,
            correctOption: optB,
            allOptions: [optA, optB, optC],
            authorExplanation: "Toujours privilégier Managed Identity.",
            misconceptionTitle: "Confondre configuration applicative et coffre de secrets",
            misconceptionCorrection: "Les fichiers de configuration ne chiffrent pas le cycle de vie des secrets.",
            takeaway: "Zéro secret dans le code : identité managée vers Key Vault."
        )
        #expect(confidentError.variant == .confidentError)
        #expect(confidentError.hapticToken == .incorrectSoft)
        #expect(confidentError.primaryDisplayedOptions.map(\.id) == ["a", "b"])

        confidentError.areAllOptionsExpanded = true
        #expect(confidentError.primaryDisplayedOptions.map(\.id) == ["a", "b", "c"])

        let aiFallback = SessionFeedbackResolution(
            itemId: "item-1",
            isCorrect: false,
            confidence: .rather,
            aiAvailable: false,
            chosenOption: optA,
            correctOption: optB,
            allOptions: [optA, optB, optC],
            authorExplanation: "Explication déterministe de l'auteur.",
            takeaway: "Toujours un repli auteur."
        )
        #expect(aiFallback.variant == .aiUnavailable)
        #expect(aiFallback.feedbackState.resolvedExplanation == "Explication déterministe de l'auteur.")
        #expect(!aiFallback.feedbackState.showsExplainDifferentlyButton)
    }

    @Test func dailySituationHidesCommunityStatsBeforeAnswerAndProducesSpoilerFreeShareCard() {
        let optA = PrismChoiceOption(
            id: "a",
            badge: "A",
            text: "Activer la suppression réversible (Soft Delete) + Purge Protection",
            explanation: "Protège contre la suppression accidentelle ou malveillante.",
            isCorrect: true
        )
        let optB = PrismChoiceOption(
            id: "b",
            badge: "B",
            text: "Exporter les clés en clair sur un partage SMB",
            explanation: "Crée un risque critique d'exfiltration.",
            isCorrect: false
        )
        let buckets = [
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
                optionSummary: "Partage SMB",
                percentage: 22,
                isLearnerSelection: false,
                isBestOption: false
            ),
        ]
        var daily = DailySituationStateMachine(
            situationId: "sit-2026-10-23",
            dateLabel: "23 oct.",
            title: "Protection d'un coffre Key Vault critique",
            product: .microsoftAzure,
            region: .security,
            contextNarrative: "Un administrateur veut empêcher toute purge immédiate d'un coffre de production.",
            artifact: PrismArtifactDocument(
                title: "kv.bicep",
                language: "bicep",
                lines: [PrismArtifactLine(lineNumber: 1, text: "enableSoftDelete: true")]
            ),
            options: [optA, optB],
            serverDistributionBuckets: buckets
        )

        // NS-7: Zero community stats before answering
        #expect(!daily.communityDistribution.isVisible)
        #expect(daily.communityDistribution.visibleBuckets.isEmpty)

        daily.selectedOptionId = "a"
        daily.selectedConfidence = .sure
        let submitted = daily.submitAnswer(
            correctOptionId: "a",
            authorExplanation: "Soft Delete + Purge Protection garantit la rétention minimale.",
            takeaway: "Activer Purge Protection sur tout Key Vault de production."
        )
        #expect(submitted)
        #expect(daily.communityDistribution.isVisible)
        #expect(daily.communityDistribution.visibleBuckets.count == 2)

        // NS-7: Spoiler-free share card (no question stem, no answer text, no third-party brand icon)
        let shareCard = daily.makeSpoilerFreeShareCard(streakDays: 7)
        #expect(shareCard.isSpoilerFree)
        #expect(shareCard.spoilerViolations.isEmpty)
    }

    @Test func mockExamEnforcesTimePoliciesNoFeedbackDuringExamAndMandatoryConfidence() {
        #expect(MockExamTimePolicy.standardTimed.allocatedSeconds(baseMinutes: 40) == 2400)
        #expect(MockExamTimePolicy.extendedTime.allocatedSeconds(baseMinutes: 40) == 3600)
        #expect(MockExamTimePolicy.untimed.allocatedSeconds(baseMinutes: 40) == nil)

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
                        PrismChoiceOption(id: "b", badge: "B", text: "Contributor", explanation: "Gère les ressources mais pas les accès."),
                    ],
                    allowsMultipleSelection: false
                )
            ),
            domainId: "dom-identity",
            domainTitle: "Identité et gouvernance"
        )

        var exam = MockExamStateMachine(
            examId: "exam-az104",
            routeCode: "AZ-104",
            routeTitle: "Microsoft Azure Administrator",
            baseDurationMinutes: 40,
            timePolicy: .extendedTime,
            questions: [q1]
        )
        #expect(!exam.showsImmediateFeedbackDuringExam)
        #expect(exam.allocatedSeconds == 3600)

        exam.startExam(policy: .untimed)
        #expect(exam.allocatedSeconds == nil)

        // Cannot advance without selecting both an option and a confidence level (§6.2)
        exam.recordCurrentSelection(optionIds: ["a"], confidence: nil)
        let readiness = PrismReadinessModel(
            band: .readyToTry,
            isCalibrated: false,
            rawProbability: 0.82,
            uncertaintyLow: 0.70,
            uncertaintyHigh: 0.88,
            evidenceCount: 30,
            recommendedActions: ["Consolider le réseau hybride"]
        )
        let coverage = [
            PrismObjectiveCoverageItem(
                id: "dom-identity",
                objectiveCode: "D1",
                title: "Identité et gouvernance",
                region: .security,
                masteryState: .anchored,
                verifiedEvidenceCount: 12,
                targetEvidenceCount: 15
            )
        ]
        let prematureAdvance = exam.advanceOrFinish(
            serverReadiness: readiness,
            serverCoverage: coverage,
            calibrationSummaryText: "Bonne calibration"
        )
        #expect(!prematureAdvance)
        #expect(exam.debrief == nil)

        exam.recordCurrentSelection(optionIds: ["a"], confidence: .sure)
        let finished = exam.advanceOrFinish(
            serverReadiness: readiness,
            serverCoverage: coverage,
            calibrationSummaryText: "Excellente calibration : tes réponses sûres sont exactes."
        )
        #expect(finished)
        #expect(exam.debrief != nil)
        #expect(exam.debrief?.readiness.formattedProbability == nil)
    }

    @Test func pearsonVueBarometerCarouselScreen24ExposesThreeCardsPaginationDotsAndOfficialDomainScores() {
        var carousel = CertiGoExamBarometerCarouselModel()

        #expect(carousel.cardsCount == 3)
        #expect(carousel.isPassed)
        #expect(carousel.surplusPoints == 85)
        #expect(carousel.selectedCardIndex == .graduatedBarometer)
        #expect(carousel.paginationDotsText == "● ○ ○")

        // Carte 1 : Baromètre gradué officiel
        #expect(carousel.card1GraduatedScaleText == "0 ── Seuil 700 ── 785 / 1000 ✓ ── 1000")
        #expect(carousel.card1VerdictBadgeText == "ADMIS · SEUIL 700 DÉPASSÉ ✓")

        // Carte 2 : Rythme chrono & Calibration de confiance
        carousel.advanceToNextCard()
        #expect(carousel.selectedCardIndex == .paceAndConfidenceCalibration)
        #expect(carousel.paginationDotsText == "○ ● ○")
        #expect(carousel.card2PaceAndCalibrationText == "18s/question · 91 % de précision sur les réponses sûres")

        // Carte 3 : Analyse des erreurs & Relance ciblée avec le Coach IA
        carousel.advanceToNextCard()
        #expect(carousel.selectedCardIndex == .errorAnalysisAndAICoachRelaunch)
        #expect(carousel.paginationDotsText == "○ ○ ●")
        #expect(carousel.card3ErrorAnalysisTitle == "Analyse des erreurs & Relance ciblée avec le Coach IA")

        carousel.triggerCoachAIRelaunch()
        #expect(carousel.coachAIRelaunchTriggeredCount == 1)

        // Cycle back to Carte 1 and check previous navigation
        carousel.advanceToNextCard()
        #expect(carousel.selectedCardIndex == .graduatedBarometer)
        carousel.returnToPreviousCard()
        #expect(carousel.selectedCardIndex == .errorAnalysisAndAICoachRelaunch)

        // Official domain score rows for the bottom white card
        #expect(carousel.officialDomainScores.count == 5)
        #expect(carousel.officialDomainScores.map(\.percentage) == [92, 84, 78, 58, 76])
        #expect(carousel.officialDomainScores.filter { !$0.isPassingDomain }.map(\.domainCode) == ["D4"])
    }

    @Test func mockExamCockpitScreen23SupportsQuestionFlaggingAndSlidingNavigatorWindow() {
        let questions = (1...50).map { number in
            MockExamQuestionRecord(
                item: PrismSessionItemModel(
                    id: "mex-q\(number)",
                    conceptId: "az.q\(number)",
                    product: .azureVirtualNetwork,
                    stem: "Question d'examen \(number)",
                    captureConfidence: true,
                    isMockExamMode: true,
                    payload: .choice(
                        options: [
                            PrismChoiceOption(id: "a", badge: "A", text: "Option A", explanation: "Explication A"),
                            PrismChoiceOption(id: "b", badge: "B", text: "Option B", explanation: "Explication B"),
                        ],
                        allowsMultipleSelection: false
                    )
                ),
                domainId: "dom-network",
                domainTitle: "Réseaux virtuels"
            )
        }

        var exam = MockExamStateMachine(
            examId: "exam-cockpit-23",
            routeCode: "AZ-104",
            routeTitle: "Microsoft Azure Administrator",
            baseDurationMinutes: 90,
            timePolicy: .standardTimed,
            questions: questions
        )
        exam.startExam()

        // Navigate to Question 12 (1-based) and record an answer (✓)
        exam.selectQuestionNumber(12)
        #expect(exam.currentQuestionIndex == 11)
        exam.recordCurrentSelection(optionIds: ["a"], confidence: .sure)

        // Navigate to Question 13 (1-based) and flag it (🏳)
        exam.selectQuestionNumber(13)
        #expect(exam.currentQuestionIndex == 12)
        #expect(!exam.isQuestionFlagged("mex-q13"))
        exam.toggleFlagOnCurrentQuestion()
        #expect(exam.isQuestionFlagged("mex-q13"))
        #expect(exam.isCurrentQuestionFlagged)
        #expect(exam.flaggedQuestionIds == ["mex-q13"])

        // Toggle off and back on to verify idempotent toggling
        exam.toggleFlagOnCurrentQuestion()
        #expect(!exam.isQuestionFlagged("mex-q13"))
        exam.toggleFlagOnCurrentQuestion()
        #expect(exam.isQuestionFlagged("mex-q13"))

        // Navigate to Question 14 (1-based) — active item in [14/50]
        exam.selectQuestionNumber(14)
        #expect(exam.currentQuestionIndex == 13)
        #expect(exam.cockpitNavigatorWindow == [12, 13, 14, 15, 16])
        #expect(exam.cockpitNavigatorBannerText == "12 ✓ · 13 🏳 · [14/50] · 15 · 16")
    }
}
