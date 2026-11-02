import BrandAssets
import CertigoCortex
import CertigoData
import CertigoDomain
import Foundation
import Prism
import Testing

@Suite("Neuro-Behavioral Retention Engine (A1..F3), CoreHaptics Engine & Page 17 Minimalist Pills")
struct CertiGoRetentionNeuroEngineTests {

    @Test("A1 — Schultz Positive Prediction Error (EPR > 0): single fluid feedback phase on error, exam trap badge percentage, and ordered A..D choice badges")
    func a1SchultzPredictionErrorSingleFluidFeedbackAndOrderedBadges() {
        var appState = CertiGoNativeAppState()
        appState.startLessonSession(forLessonId: "AZ-104-u1-s1", skipDeclic15: true, enableAdaptiveReplay: true)

        let ex = appState.lessonSession.currentExercise
        #expect(ex.options.map(\.badge) == ["A", "B", "C", "D"])

        let fallPct = CertiGoSchultzPredictionErrorEngine.examTrapCandidateFallRatePercent(
            forExerciseId: ex.id,
            difficulty: ex.difficulty
        )
        #expect(fallPct >= 64 && fallPct <= 86)

        let fullBadge = CertiGoSchultzPredictionErrorEngine.examTrapBadgeText(
            forExerciseId: ex.id,
            difficulty: ex.difficulty
        )
        #expect(fullBadge.contains("🎯 Piège d'examen démasqué"))
        #expect(fullBadge.contains("\(fallPct) %"))

        let compactPill = CertiGoSchultzPredictionErrorEngine.compactExamTrapPillText(
            forExerciseId: ex.id,
            difficulty: ex.difficulty
        )
        #expect(compactPill == "🎯 Piège d'examen (\(fallPct) %)")

        // Answering wrong stays in .checked(isCorrect: false) (no forced modal sheet over the red banner)
        if let wrongOpt = ex.options.first(where: { !$0.isCorrect }) {
            appState.lessonSession.selectOption(wrongOpt.id)
        }
        let isCorrect = appState.lessonSession.verifyCurrentAnswer()
        #expect(isCorrect == false)
        #expect(appState.lessonSession.attemptPhase == .checked(isCorrect: false))

        // Shuffled or reversed options always normalize to vertical A, B, C, D order
        let reversed = Array(ex.options.reversed())
        let normalized = CertiGoSchultzPredictionErrorEngine.normalizeOrderedChoiceBadges(reversed)
        #expect(normalized.map(\.badge) == ["A", "B", "C", "D"])
    }

    @Test("A2 — Variable Reward Vault (Schultz & Eyal): Master Stroke < 8s detection and surprise end-of-session rewards")
    func a2VariableRewardVaultMasterStrokeAndSurpriseRewards() {
        // 1. Master Stroke (< 8s on first attempt for difficulty >= 0.50)
        #expect(
            CertiGoVariableRewardVault.isMasterStroke(
                isCorrect: true,
                isFirstAttemptOnQuestion: true,
                latencyMs: 4_200,
                difficulty: 0.65
            ) == true
        )
        // Too slow (>= 8s) or wrong answer is not a Master Stroke
        #expect(
            CertiGoVariableRewardVault.isMasterStroke(
                isCorrect: true,
                isFirstAttemptOnQuestion: true,
                latencyMs: 9_100,
                difficulty: 0.65
            ) == false
        )
        #expect(
            CertiGoVariableRewardVault.isMasterStroke(
                isCorrect: false,
                isFirstAttemptOnQuestion: true,
                latencyMs: 3_000,
                difficulty: 0.70
            ) == false
        )

        var vault = CertiGoVariableRewardVault()
        let triggered = vault.registerExerciseAttempt(
            isCorrect: true,
            isFirstAttemptOnQuestion: true,
            latencyMs: 3_500,
            difficulty: 0.75
        )
        #expect(triggered == true)
        #expect(vault.masterStrokeCount == 1)
        #expect(vault.currentSessionHadMasterStroke == true)

        let r1 = vault.awardSurpriseRewardAtSessionEnd(
            routeCode: "AZ-104",
            lessonId: "AZ-104-u1-s1",
            lessonTitle: "Gouvernance ARM",
            sessionIndex: 1
        )
        #expect(r1.kind == .masterStrokeDoubleBoost)
        #expect(vault.lastAwardedReward == r1)
        #expect(vault.unlockedRewards.count == 1)

        // Verify all 3 variable reward kinds can be unlocked across sessions
        var seenKinds: Set<CertiGoVariableRewardKind> = [r1.kind]
        for idx in 0..<6 {
            let reward = vault.awardSurpriseRewardAtSessionEnd(
                routeCode: "SAA-C03",
                lessonId: "SAA-C03-u1-s\(idx + 1)",
                lessonTitle: "Architecture VPC",
                sessionIndex: idx
            )
            seenKinds.insert(reward.kind)
        }
        #expect(seenKinds.contains(.examinerTrapCard))
        #expect(seenKinds.contains(.masterStrokeDoubleBoost))
        #expect(seenKinds.contains(.goldenArchitectureCard))
    }

    @Test("B1 — Visual Architecture Diagram Engine (Berridge Liking): 3 connected visual bricks per certification family")
    func b1VisualArchitectureDiagramThreeConnectedBricksAcrossTracks() {
        let azureDiag = CertiGoVisualArchitectureDiagramSpec.diagram(forRouteCode: "AZ-104")
        #expect(azureDiag.bricks.count == 3)
        #expect(azureDiag.compactFlowChain.contains("Management Group"))
        #expect(azureDiag.compactFlowChain.contains("CanNotDelete"))

        let awsDiag = CertiGoVisualArchitectureDiagramSpec.diagram(forRouteCode: "SAA-C03")
        #expect(awsDiag.bricks.count == 3)
        #expect(awsDiag.compactFlowChain.contains("[🌐 VPC] ➔ [🛡️ Security Group] ➔ [⚡ EC2 / S3]"))

        let k8sDiag = CertiGoVisualArchitectureDiagramSpec.diagram(forRouteCode: "CKA")
        #expect(k8sDiag.bricks.count == 3)
        #expect(k8sDiag.compactFlowChain.contains("[🧭 API Server] ➔ [🔐 RBAC RoleBinding] ➔ [📦 Pod / ServiceAccount]"))

        let gcpDiag = CertiGoVisualArchitectureDiagramSpec.diagram(forRouteCode: "PDE")
        #expect(gcpDiag.bricks.count == 3)
        #expect(gcpDiag.compactFlowChain.contains("BigQuery"))

        let aiDiag = CertiGoVisualArchitectureDiagramSpec.diagram(forRouteCode: "AI-102")
        #expect(aiDiag.bricks.count == 3)
        #expect(aiDiag.compactFlowChain.contains("Content Safety"))
    }

    @Test("B2 — Readable CLI Terminal Output & Offline AI Coach Instant Synthesis for all suggestion chips")
    func b2ReadableCLITerminalOutputAndOfflineAICoachSynthesis() {
        let azExercises = CertiGoNativeLessonSessionEngine.defaultExercises(
            forRouteCode: "AZ-104",
            lessonId: "AZ-104-u1-s1"
        )
        guard let cliEx = azExercises.first(where: { $0.formatCode == "Q_TYPE_04" }) else {
            Issue.record("Expected Q_TYPE_04 CLI exercise in AZ-104")
            return
        }
        let cmdLine = CertiGoCLITerminalOutputBuilder.fullCommandLine(for: cliEx, userInput: "lock")
        #expect(cmdLine.contains("CanNotDelete"))
        let successOut = CertiGoCLITerminalOutputBuilder.successOutputText(for: cliEx)
        #expect(successOut.contains("✓ Output : Commande exécutée avec succès"))

        // Offline AI Coach synthesis for all 4 suggestion chips
        var appState = CertiGoNativeAppState()
        appState.isLiveAIModelConnected = false
        appState.selectRoute("CKA")

        for topicKey in ["rbac-vs-policy", "oral-interview", "last-3-errors", "cli-example"] {
            appState.openAITopic(topicKey)
            guard let turn = appState.chatTurns.last else {
                Issue.record("Expected offline synthesis turn for \(topicKey)")
                continue
            }
            #expect(turn.aiHeadline.contains("Réponse Synthèse Locale du Coach CertiGo"))
            #expect(!turn.aiBullet1.isEmpty)
            #expect(!turn.aiBullet2.isEmpty)
            #expect(!turn.examKeyRule1.isEmpty)
            #expect(!turn.examKeyRule2.isEmpty)
            #expect(turn.closingTip.contains("Synthèse locale hors-ligne certifiée"))
        }
        #expect(appState.chatTurns.count == 4)
    }

    @Test("C1 & C2 — 1-Tap Daily Sprint Launch & Graybiel Striatal Action-Chunking Opening/Closing Brackets")
    func c1AndC2OneTapSprintAndStriatalActionChunkingBrackets() {
        var appState = CertiGoNativeAppState()
        #expect(appState.bracketRitual.openingBracketCount == 0)
        #expect(appState.bracketRitual.closingBracketCount == 0)

        appState.startOneTapDailySprint()
        #expect(appState.isPresentingLessonSession == true)
        #expect(appState.bracketRitual.isOpeningBracketActive == true)
        #expect(appState.bracketRitual.openingBracketCount == 1)
        #expect(appState.bracketRitual.openingBannerText.contains("Parenthèse d'ouverture"))

        appState.completeActiveLessonSessionAndUnlockNextNode()
        #expect(appState.isPresentingLessonSession == false)
        #expect(appState.bracketRitual.isClosingBracketActive == true)
        #expect(appState.bracketRitual.closingBracketCount == 1)
        #expect(appState.bracketRitual.closingBannerText.contains("Parenthèse de clôture"))
    }

    @Test("D1 — Fogg Facilitator: 90-second Rescue Sprint (3 Flash Cards), evening detection, and 3 Fogg local notifications")
    func d1FoggRescue90sThreeFlashCardsAndThreeLocalNotifications() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let evening21h = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 21, minute: 15))!
        let afternoon14h = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 14, minute: 0))!

        #expect(CertiGoFoggFacilitatorEngine.isEveningRescueWindow(at: evening21h, calendar: calendar) == true)
        #expect(CertiGoFoggFacilitatorEngine.isEveningRescueWindow(at: afternoon14h, calendar: calendar) == false)

        var appState = CertiGoNativeAppState()
        appState.selectRoute("AZ-104")
        appState.startRescue90SecondsSession(now: evening21h)

        #expect(appState.isPresentingLessonSession == true)
        #expect(appState.lessonSession.isRescue90sSprint == true)
        #expect(appState.lessonSession.isShowingDeclicCard15 == false)
        #expect(appState.lessonSession.exercises.count == 3)
        #expect(appState.lessonSession.exercises[0].domainBadge.contains("CARTE FLASH 1/3"))

        // Verify the 3 Fogg local notifications (Signal, Facilitateur 90s at 21:00, Étincelle +20 XP after 48h)
        let notifs = appState.scheduledFoggNotifications
        #expect(notifs.count == 3)
        #expect(notifs.map(\.kind) == [.signal, .facilitator90s, .spark48hBonus])
        #expect(notifs[1].scheduledTimeText == "21:00")
        #expect(notifs[2].scheduledTimeText == "+48h")
    }

    @Test("E1 & E2 — Nunes & Drèze Endowed Progress (Never 0%: 20% Unit 1, 10% unlocked units, 10 Hull stamps) + Eyal Day-One Notebook Pin & Next-Sprint Prioritization")
    func e1AndE2EndowedProgressHullStampsAndDayOneNotebookPrioritization() {
        // E1: Endowed progress & 10 Hull stamps
        let unit1Pct = CertiGoEndowedProgressEngine.endowedProgressPercent(
            forUnitNumber: 1,
            rawPercent: 0,
            isUnlocked: true,
            hasCompletedOnboarding: true
        )
        #expect(unit1Pct == 20)
        let unit1Stamps = CertiGoEndowedProgressEngine.buildTenHullStamps(
            forUnitNumber: 1,
            effectivePercent: unit1Pct
        )
        #expect(unit1Stamps.count == 10)
        #expect(unit1Stamps.filter(\.isStamped).count == 2)
        #expect(unit1Stamps.filter(\.isEndowedBonus).count == 2)

        let unit2UnlockedPct = CertiGoEndowedProgressEngine.endowedProgressPercent(
            forUnitNumber: 2,
            rawPercent: 0,
            isUnlocked: true,
            hasCompletedOnboarding: true
        )
        #expect(unit2UnlockedPct == 10)
        let unit2Stamps = CertiGoEndowedProgressEngine.buildTenHullStamps(
            forUnitNumber: 2,
            effectivePercent: unit2UnlockedPct
        )
        #expect(unit2Stamps.filter(\.isStamped).count == 1)

        var appState = CertiGoNativeAppState()
        appState.completeOnboardingFlow(awardWelcomeBonus: true, startGuidedTour: false)
        #expect(appState.currentUnits[0].progressPercent == 20)

        // E2: Pin trap to Day-One Notebook and verify next-sprint prioritization
        appState.startLessonSession(forLessonId: "AZ-900-u1-s1", skipDeclic15: true)
        appState.lessonSession.currentExerciseIndex = 2
        let pinnedConceptId = appState.lessonSession.currentExercise.conceptId
        let entry = appState.pinCurrentLessonTrapToDayOneNotebook()
        #expect(appState.isCurrentLessonPinnedInDayOneNotebook == true)
        #expect(appState.dayOneNotebook.entries.first?.id == entry.id)

        // Next sprint prioritizes the pinned concept at index 0
        appState.startLessonSession(forLessonId: "AZ-900-u1-s1", skipDeclic15: true)
        #expect(appState.lessonSession.exercises.first?.conceptId == pinnedConceptId)
    }

    @Test("F1, F2, F3 — Unified Domain Mastery, Real Domain Sprint Filtering, Kubernetes Logo, XP-Sorted Podium + Cooperative Cohort, and Healthy Stopping Point")
    func f1F2F3DomainFilteringKubernetesLogoCohortAndHealthyStoppingPoint() {
        var appState = CertiGoNativeAppState()
        appState.selectRoute("CKA")

        // F1: Kubernetes & CNCF brand logo resolves to BrandLogos/brand-kubernetes (never Cisco)
        #expect(CertiGoOfficialAssetCatalog.brandLogoAssetName(forVendorId: "kubernetes") == "BrandLogos/brand-kubernetes")
        #expect(CertiGoOfficialAssetCatalog.brandLogoAssetName(forVendorId: "Kubernetes & CNCF") == "BrandLogos/brand-kubernetes")
        #expect(CertiGoOfficialAssetCatalog.brandLogoAssetName(forVendorId: "cncf") == "BrandLogos/brand-kubernetes")

        // F1: Real domain filtering produces distinct domain-targeted questions and returns to .examens
        appState.startDomainSprintSession(forDomainIndex: 0)
        let dom0Ids = appState.lessonSession.exercises.map(\.id)
        #expect(dom0Ids.count == 5)
        #expect(dom0Ids.allSatisfy { $0.hasPrefix("cka-dom1-") })
        #expect(!dom0Ids.contains("az-104-qtype01"))
        #expect(appState.returnTabAfterLessonSession == .examens)

        appState.startDomainSprintSession(forDomainIndex: 2)
        let dom2Ids = appState.lessonSession.exercises.map(\.id)
        #expect(dom2Ids.count == 5)
        #expect(dom2Ids != dom0Ids)

        // F2: Leaderboard sorted by XP descending + Cooperative Cohort increments on completion
        #expect(appState.leaderboardMembers.first?.displayName == "Sarah L.")
        #expect(appState.leaderboardMembers.last?.isCurrentUser == true)
        let initialCohortCount = appState.cooperativeCohortChallenge.validatedConceptsCount
        #expect(initialCohortCount == 845)
        appState.lessonSession.correctAnswersCount = 4
        appState.completeActiveLessonSessionAndUnlockNextNode()
        #expect(appState.cooperativeCohortChallenge.validatedConceptsCount == initialCohortCount + 4)
        #expect(appState.selectedTab == .examens)

        // F3: Healthy Stopping Point reached after completing daily session
        #expect(CertiGoHealthyStoppingPointEngine.isDailyGoalReached(completedStepsToday: appState.completedStepsTotal) == true)
        #expect(CertiGoHealthyStoppingPointEngine.benevolentStoppingBannerBody.contains("Objectif quotidien atteint"))
    }

    @Test("CertiGoHapticsEngine records and schedules Duolingo-style CoreHaptics pulse patterns across all 7 interaction types")
    func hapticsEngineCoreHapticsSchedulesAndEventRecording() {
        let engine = CertiGoHapticsEngine.shared
        engine.isEnabled = true
        engine.resetRecordedEvents()

        engine.playButtonPress()
        engine.playButtonRelease()
        engine.playOptionSelection()
        engine.playCorrectAnswer()
        engine.playWrongAnswer()
        engine.playStampSealed()
        engine.playLessonCompleteFanfare()

        #expect(
            engine.recordedEvents == [
                .buttonPress,
                .buttonRelease,
                .optionSelection,
                .correctAnswer,
                .wrongAnswer,
                .stampSealed,
                .lessonCompleteFanfare
            ]
        )

        // Verify multi-pulse CoreHaptics schedules
        #expect(CertiGoHapticsEngine.pulseSchedule(for: .correctAnswer).count == 2)
        #expect(CertiGoHapticsEngine.pulseSchedule(for: .wrongAnswer).count == 2)
        #expect(CertiGoHapticsEngine.pulseSchedule(for: .stampSealed).count == 2)
        #expect(CertiGoHapticsEngine.pulseSchedule(for: .lessonCompleteFanfare).map(\.relativeTimeSeconds) == [0.0, 0.07, 0.14, 0.24])

        // Disabling haptics suppresses recording/playback
        engine.resetRecordedEvents()
        engine.isEnabled = false
        engine.playButtonPress()
        #expect(engine.recordedEvents.isEmpty)
        engine.isEnabled = true
    }
}
