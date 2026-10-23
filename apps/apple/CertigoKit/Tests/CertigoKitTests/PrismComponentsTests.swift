import Foundation
import Prism
import Testing

@Suite struct PrismComponentsTests {
    @Test func foundationGlyphsAndConfigurationsCoverEveryRegionAndState() {
        #expect(PrismGlyph.allCases.count == 16)
        for region in PrismRegion.allCases {
            let glyph = PrismGlyph.region(region)
            #expect(glyph.assetName == "certigo.region.\(region.rawValue)")
            #expect(!glyph.sfSymbolFallback.isEmpty)
        }
        for state in PrismConceptStateGlyph.allCases {
            let glyph = PrismGlyph.conceptState(state)
            #expect(glyph.assetName == "certigo.concept.\(state.rawValue)")
            #expect(!glyph.sfSymbolFallback.isEmpty)
        }
        let primaryMetrics = PrismButtonMetrics(variant: .primary, isLoading: false, isEnabled: true)
        #expect(primaryMetrics.minHeight == PrismSize.primaryButtonHeight)
        let inlineMetrics = PrismButtonMetrics(variant: .inline, isLoading: true, isEnabled: true)
        #expect(inlineMetrics.minHeight == PrismSize.minTouch)
        #expect(!inlineMetrics.isInteractive)

        let cardHero = PrismCardConfiguration(variant: .hero)
        #expect(cardHero.cornerRadius == PrismRadius.xl)
        #expect(cardHero.surfaceRole == .surfaceRaised)

        let bar = PrismProgressBarConfiguration(progress: 1.4, label: "Série")
        #expect(bar.clampedProgress == 1.0)
        #expect(bar.accessibilityPercentageText == "100 %")
    }

    @Test func learningComponentsRespectPedagogicalAndAccessibilityRules() {
        let options = SessionLengthOption.allOptions(suggestedLength: .standard)
        #expect(options.count == 3)
        #expect(options.filter(\.isSuggested).map(\.length) == [.standard])

        let delayedQuestion = PrismQuestionSpec(
            id: "q1",
            prompt: "Quel service gère les identités ?",
            revealOptionsDelayMs: 1200
        )
        #expect(!delayedQuestion.shouldRevealImmediately(reduceMotion: false))
        #expect(delayedQuestion.shouldRevealImmediately(reduceMotion: true))

        let lines = (1...35).map { PrismArtifactLine(lineNumber: $0, text: "line \($0)") }
        let doc = PrismArtifactDocument(title: "main.bicep", language: "bicep", lines: lines)
        #expect(doc.requiresCollapse)
        #expect(doc.visibleLines(isExpanded: false).count == PrismArtifactDocument.maxCollapsedLines)
        #expect(doc.visibleLines(isExpanded: true).count == 35)

        let selected = PrismArtifactDocument.toggleLineSelection(
            lineNumber: 12, in: [], allowsMultipleSelection: false
        )
        #expect(selected == [12])

        let items = [
            PrismOrderItem(id: "a", text: "az login"),
            PrismOrderItem(id: "b", text: "az account set"),
            PrismOrderItem(id: "c", text: "az group create"),
        ]
        let moved = PrismOrderItem.moveUp(items, at: 1)
        #expect(moved.map(\.id) == ["b", "a", "c"])

        let step1 = HintStep(id: "h1", level: 1, title: "Indice 1", hintText: "Regarde le plan réseau.")
        let step2 = HintStep(id: "h2", level: 2, title: "Indice 2", hintText: "Vérifie le NSG.")
        let ladder = PrismHintLadder(
            steps: [step1, step2],
            unlockedLevel: 0,
            hasAttemptedQuestion: false
        )
        #expect(!ladder.canUnlockNext)
        let afterAttempt = PrismHintLadder(
            steps: [step1, step2],
            unlockedLevel: 1,
            hasAttemptedQuestion: true
        )
        #expect(afterAttempt.isUnlocked(step1))
        #expect(!afterAttempt.isUnlocked(step2))
        #expect(afterAttempt.canUnlockNext)
    }

    @Test func progressAndSocialComponentsEnforceHonestReadinessAndPrivacyDefaults() {
        let uncalibrated = PrismReadinessModel(
            band: .onTrack,
            isCalibrated: false,
            rawProbability: 0.78,
            uncertaintyLow: 0.55,
            uncertaintyHigh: 0.77,
            evidenceCount: 18,
            recommendedActions: ["Renforcer Entra ID", "Pratiquer RBAC", "Réviser Key Vault"]
        )
        #expect(uncalibrated.formattedProbability == nil)

        let calibrated = PrismReadinessModel(
            band: .readyToTry,
            isCalibrated: true,
            rawProbability: 0.84,
            uncertaintyLow: 0.78,
            uncertaintyHigh: 0.88,
            evidenceCount: 64,
            recommendedActions: ["Faire un examen blanc"]
        )
        #expect(calibrated.formattedProbability == "84 %")

        #expect(PrismAtlasLayout.shouldDefaultToList(voiceOverRunning: true))
        #expect(!PrismAtlasLayout.shouldDefaultToList(voiceOverRunning: false))

        let bucket = PrismDistributionBucket(
            id: "a",
            optionCode: "A",
            optionSummary: "Utiliser une identité managée",
            percentage: 62,
            isLearnerSelection: true,
            isBestOption: true
        )
        let beforeAnswer = PrismCommunityDistributionModel(
            situationTitle: "Accès Key Vault sans secret",
            hasAnswered: false,
            buckets: [bucket]
        )
        #expect(!beforeAnswer.isVisible)
        #expect(beforeAnswer.visibleBuckets.isEmpty)

        let afterAnswer = PrismCommunityDistributionModel(
            situationTitle: "Accès Key Vault sans secret",
            hasAnswered: true,
            buckets: [bucket]
        )
        #expect(afterAnswer.isVisible)
        #expect(afterAnswer.visibleBuckets.count == 1)

        let challenge = PrismChallengeModel(
            id: "ch-1",
            title: "Défi Architecture",
            route: PrismRouteBadgeModel(
                examCode: "AZ-104",
                officialTitle: "Administrator Associate",
                region: .cloud
            ),
            itemScores: (1...5).map { PrismChallengeItemScore(itemNumber: $0, accuracy: 1.0, calibration: 0.9) },
            isCompleted: true
        )
        #expect(!challenge.hasTimer)
        #expect(challenge.itemCount == 5)
    }

    @Test func stateAndAccessibilityComponentsEnforceCalmModeSpoilerFreeAndAXLayout() {
        let errorState = PrismErrorStateModel(
            title: "Connexion interrompue",
            explanation: "Le serveur n'a pas répondu à temps.",
            technicalCode: "HTTP_504"
        )
        #expect(errorState.reassuranceMessage.contains("sécurité"))
        #expect(errorState.isTechnicalCodeHiddenByDefault)

        let skeletonFast = PrismSkeletonModel(rows: 3, learningTip: "Astuce FSRS", elapsedSeconds: 0.4)
        #expect(!skeletonFast.shouldDisplayLearningTip)
        let skeletonSlow = PrismSkeletonModel(rows: 3, learningTip: "Astuce FSRS", elapsedSeconds: 1.5)
        #expect(skeletonSlow.shouldDisplayLearningTip)

        let celebration = PrismCelebrationConfig(
            level: .milestone,
            calmMode: true,
            reduceMotion: true,
            region: .security,
            title: "Territoire maîtrisé",
            subtitle: "Identité et gouvernance"
        )
        #expect(celebration.resolvedLevel == PrismCelebrationLevel.pulse)
        #expect(celebration.motionSpec.opacityOnly)
        #expect(celebration.motionSpec.duration <= 0.3)

        let cleanShare = PrismShareCardPayload(
            title: "Situation du jour",
            region: .security,
            synthesis: "Déclic validé en 1 essai"
        )
        #expect(cleanShare.isSpoilerFree)

        let leakyShare = PrismShareCardPayload(
            title: "Situation du jour",
            region: .security,
            synthesis: "Bonne réponse validée",
            correctAnswerCandidate: "Option B"
        )
        #expect(!leakyShare.isSpoilerFree)

        #expect(PrismAdaptiveStackPolicy.resolvedAxis(isAccessibilityCategory: false) == .horizontal)
        #expect(PrismAdaptiveStackPolicy.resolvedAxis(isAccessibilityCategory: true) == .vertical)
    }
}
