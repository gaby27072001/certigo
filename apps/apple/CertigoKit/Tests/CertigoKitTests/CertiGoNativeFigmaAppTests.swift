import BrandAssets
import CertigoCortex
import CertigoData
import CertigoDomain
import Foundation
import Prism
import Testing

@Suite("PR #150 — Native Figma App Video Layout, Mimo Reset, 8-Step Onboarding & Parallel Tracks Deduplication", .serialized)
struct CertiGoNativeFigmaAppTests {

    @Test("selectRoute resets selectedMimoFilter to .allUnits so all 3 units (15 winding nodes) appear after switching certifications")
    func selectRouteResetsSelectedMimoFilterToAllUnits() {
        var appState = CertiGoNativeAppState()
        appState.selectedMimoFilter = .miniLabs
        #expect(appState.filteredUnitsForMimoRail.flatMap(\.lessons).count == 4)

        appState.selectRoute("PCA")
        #expect(appState.activeRouteCode == "PCA")
        #expect(appState.selectedMimoFilter == .allUnits)
        #expect(appState.filteredUnitsForMimoRail.count == 3)
        #expect(appState.filteredUnitsForMimoRail.flatMap(\.lessons).count == 15)
    }

    @Test("10-step native onboarding flow advances from step 0 to step 9 (without duplicate Step 1 auth screen), supports back navigation, and dismisses cleanly on completion or close")
    func onboardingEightStepNavigationAndDismissal() {
        var appState = CertiGoNativeAppState()
        #expect(CertiGoNativeAppState.onboardingStepCount == 10)

        appState.startOnboardingFlow()
        #expect(appState.isPresentingOnboardingFlow == true)
        #expect(appState.onboardingStepIndex == 0)

        for expectedNextStep in 1..<CertiGoNativeAppState.onboardingStepCount {
            appState.advanceOnboardingStep()
            #expect(appState.onboardingStepIndex == expectedNextStep)
            #expect(appState.isPresentingOnboardingFlow == true)
        }

        appState.goBackOnboardingStep()
        #expect(appState.onboardingStepIndex == 8)
        appState.advanceOnboardingStep()
        #expect(appState.onboardingStepIndex == 9)

        // Advancing from step 9 (final step) completes and dismisses the onboarding flow
        appState.advanceOnboardingStep()
        #expect(appState.isPresentingOnboardingFlow == false)

        // Restarting and explicitly dismissing mid-flow resets presentation
        appState.startOnboardingFlow()
        appState.advanceOnboardingStep()
        #expect(appState.onboardingStepIndex == 1)
        appState.dismissOnboardingFlow()
        #expect(appState.isPresentingOnboardingFlow == false)
    }

    @Test("TestFlight Build 10 & Figma Page 17: Direct Apple/Google/Email auth without Microsoft CIAM popup, minimalist 6A/6B/6C/7/8 screens, 2/10 stamps, and Duolingo haptics")
    @MainActor
    func testFlightBuild10DirectAuthSplitRhythmWidgetStepAndSpeedComparison() async throws {
        // 1. Direct Apple / Google / Email auth never uses Microsoft CIAM web session
        #expect(CertiGoNativeSystemOAuthCoordinator.usesMicrosoftCIAMWebSession(for: .apple) == false)
        #expect(CertiGoNativeSystemOAuthCoordinator.usesMicrosoftCIAMWebSession(for: .google) == false)
        #expect(CertiGoNativeSystemOAuthCoordinator.usesMicrosoftCIAMWebSession(for: .email) == false)
        #expect(CertiGoNativeSystemOAuthCoordinator.usesMicrosoftCIAMWebSession(for: .microsoft) == true)

        let suiteName = "CertiGoAuthStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = CertiGoNativeAuthSessionStore(defaults: defaults)
        let savedApple = CertiGoPersistedAuthSession(
            userId: "apple-user-001",
            displayName: "Gabriel Chambaud",
            email: "gabriel.chambaud@icloud.com",
            accessToken: "apple.identity.jwt",
            providerRawValue: CertiGoAuthProviderKind.apple.rawValue
        )
        store.saveSession(savedApple)
        #expect(store.loadSession(for: .apple) == savedApple)
        store.clearAllSessions()
        #expect(store.loadSession(for: .apple) == nil)

        // 2. Étape 6A (Step 6): 4 daily goal options with 2-word subtitles and right-side badges
        let rhythmOptions = CertiGoNativeAppState.onboardingDailyRhythmOptions
        #expect(rhythmOptions.map(\.minutes) == [5, 10, 15, 20])
        #expect(rhythmOptions[0].subtitle == "Départ léger")
        #expect(rhythmOptions[0].subBadge == "🌱 Doux")
        #expect(rhythmOptions[1].subtitle == "Rythme idéal")
        #expect(rhythmOptions[1].subBadge == "⭐ Recommandé")
        #expect(rhythmOptions[1].isRecommended == true)
        #expect(rhythmOptions[2].subtitle == "Progression accélérée")
        #expect(rhythmOptions[2].subBadge == "🚀 Soutenu")
        #expect(rhythmOptions[3].subtitle == "Préparation intensive")
        #expect(rhythmOptions[3].subBadge == "🔥 Intensif")

        // 3. Étape 6B (Step 7): 4 training moments (08:00, 12:30, 18:00, 20:30), time stepper, notification scheduler, and Duolingo haptics
        CertiGoHapticsEngine.resetTestCounters()
        let anchors = CertiGoNativeAppState.onboardingRoutineAnchors
        #expect(anchors.count == 4)
        #expect(anchors.map(\.defaultTime) == ["08:00", "12:30", "18:00", "20:30"])
        var appState = CertiGoNativeAppState()
        appState.selectOnboardingDailyRhythm(15)
        #expect(appState.onboardingDailyRhythmMinutes == 15)
        #expect(CertiGoHapticsEngine.lastTriggeredHapticToken == .selection)

        appState.selectOnboardingRoutineAnchor(2)
        #expect(appState.onboardingRoutineAnchorIndex == 2)
        #expect(appState.onboardingReminderTimeText == "18:00")
        appState.adjustOnboardingReminderTime(byMinutes: 30)
        #expect(appState.onboardingReminderTimeText == "18:30")
        appState.adjustOnboardingReminderTime(byMinutes: -60)
        #expect(appState.onboardingReminderTimeText == "17:30")
        #expect(CertiGoDailyNotificationScheduler.parseHourAndMinute(from: "20:30") == (20, 30))

        appState.onboardingStepIndex = 7
        appState.activateDailyReminderAndAdvance()
        #expect(appState.hasScheduledOnboardingDailyReminder == true)
        #expect(appState.settingsPushRemindersOn == true)
        #expect(appState.onboardingStepIndex == 8)

        // 4. Étape 6C (Step 8): 3 single-line bold installation steps with zero grey subtext
        let widgetSteps = CertiGoNativeAppState.onboardingWidgetInstallSteps
        #expect(widgetSteps.map(\.number) == [1, 2, 3])
        #expect(widgetSteps[0].title == "Appuie longuement sur ton écran d'accueil")
        #expect(widgetSteps[1].title == "Touche « Modifier » ou « + » en haut à gauche")
        #expect(widgetSteps[2].title == "Cherche « CertiGo » et place ton widget")
        #expect(widgetSteps.allSatisfy { $0.detail.isEmpty })

        // 5. Étape 7 (Step 9): ~11 weeks vs 3 weeks · 3,4× plus efficace 🏆 + 3 compact single-line 50pt pills (🎯, 🧠, 🎁)
        let bars = CertiGoNativeAppState.onboardingSpeedComparisonBars
        #expect(bars.count == 2)
        #expect(bars[0].durationText == "~11 semaines")
        #expect(bars[0].percentValue == 29)
        #expect(bars[1].durationText == "3 semaines · 3,4× plus efficace 🏆")
        #expect(bars[1].percentValue == 100)
        #expect(bars[1].badgeText == "⚡ 3,4×")

        let pillars = CertiGoNativeAppState.onboardingSpeedPillars
        #expect(pillars.count == 3)
        #expect(pillars[0].icon == "🎯")
        #expect(pillars[0].title == "100 % ciblé sur les pièges d'examen")
        #expect(pillars[1].icon == "🧠")
        #expect(pillars[1].title == "Rappel actif & répétition espacée")
        #expect(pillars[2].icon == "🎁")
        #expect(pillars[2].title == "20 % du Chapitre 1 déjà crédités !")
        #expect(pillars.allSatisfy { $0.detail.isEmpty })

        // 6. Étape 8 (Step 10): Sauvegarde tes 20 % d'avance (Chapitre 1 : 2 / 10 tampons validés (20 %)) + Duolingo haptics on completion
        #expect(CertiGoNativeAppState.onboardingEndowedMilestonesCompleted == 2)
        #expect(CertiGoNativeAppState.onboardingEndowedMilestonesTotal == 10)
        #expect(CertiGoNativeAppState.onboardingEndowedProgressPercent == 20)
        #expect(CertiGoNativeAppState.onboardingEndowedProgressBannerText == "Chapitre 1 : 2 / 10 tampons validés (20 %)")

        appState.completeOnboardingFlow(awardWelcomeBonus: true, startGuidedTour: false)
        #expect(CertiGoHapticsEngine.lastTriggeredHapticToken == .declic)
        #expect(CertiGoHapticsEngine.totalTriggeredHapticsCount >= 5)
    }

    @Test("deduplicatedParallelTrackCodes preserves order, returns 3 distinct certifications, and resolves distinct profile titles")
    func deduplicatedParallelTracksHelperAndDistinctProfileTitles() {
        var appState = CertiGoNativeAppState()
        appState.activeRouteCode = "AZ-104"

        let deduplicatedDefault = appState.deduplicatedParallelTrackCodes(
            preferred: ["AZ-104", "AZ-104", "SAA-C03"]
        )
        #expect(deduplicatedDefault == ["AZ-104", "SAA-C03", "PCA"])
        #expect(Set(deduplicatedDefault).count == 3)

        let titles = deduplicatedDefault.map {
            CertiGoNativeRichCatalog.profileCertificationDetail(forCode: $0).title
        }
        #expect(Set(titles).count == 3)
        #expect(titles[0].contains("AZ-104"))
        #expect(titles[1].contains("SAA-C03"))
        #expect(titles[2].contains("PCA"))

        appState.selectRoute("CKA")
        let deduplicatedCustom = appState.deduplicatedParallelTrackCodes(
            preferred: ["AI-102", "CKA", "CCA-F", "AZ-104"]
        )
        #expect(deduplicatedCustom == ["CKA", "AI-102", "CCA-F"])
        let customTitles = deduplicatedCustom.map {
            CertiGoNativeRichCatalog.profileCertificationDetail(forCode: $0).title
        }
        #expect(Set(customTitles).count == 3)
    }

    @Test("addSuggestedFriend and addNewFriendFromSearch add real colleagues to friends & leaderboard in real time (zero fake pre-populated suggestions) and openFriendProfile populates CertiGoSocialProfilePreview")
    func socialAddSuggestedFriendAndOpenProfilePreview() {
        var appState = CertiGoNativeAppState()
        #expect(CertiGoNativeRichCatalog.defaultFriends.isEmpty)
        #expect(CertiGoNativeRichCatalog.defaultSuggestedFriends.isEmpty)
        #expect(appState.friends.isEmpty)
        #expect(appState.suggestedFriends.isEmpty)

        let customSuggestion = CertiGoSuggestedFriend(
            id: "sf-real-1",
            displayName: "Camille D.",
            handle: "@camille_az",
            initials: "CD",
            routeCode: "AZ-104",
            activeTrackText: "AZ-104 · Architecte Azure",
            streakDays: 0,
            avatarHex: "#0078d4"
        )
        appState.suggestedFriends = [customSuggestion]
        appState.addSuggestedFriend("sf-real-1")
        #expect(appState.suggestedFriends[0].isAdded == true)
        #expect(appState.friends.count == 1)
        #expect(appState.friends[0].displayName == "Camille D.")
        #expect(appState.friends[0].handle == "@camille_az")
        #expect(appState.leaderboardMembers.count == 2)
        #expect(appState.lastAddedFriendConfirmation?.contains("Camille D.") == true)

        appState.openFriendProfile(for: appState.friends[0])
        #expect(appState.selectedFriendProfile != nil)
        #expect(appState.selectedFriendProfile?.displayName == "Camille D.")
        #expect(appState.selectedFriendProfile?.handle == "@camille_az")
        #expect(appState.selectedFriendProfile?.xpPoints == 0)
        #expect(appState.selectedFriendProfile?.isSaluted == true)

        appState.toggleSalutSelectedProfile()
        #expect(appState.selectedFriendProfile?.isSaluted == false)
        #expect(appState.friends[0].isSaluted == false)
    }

    @Test("Gamification shop purchases deduct gems and apply streak freeze, heart refill, and double XP boost")
    func gamificationShopPurchasesWithGems() {
        var appState = CertiGoNativeAppState()
        #expect(appState.gemsCount == 0)
        appState.gemsCount = 480
        #expect(appState.streakFreezeCount == 2)
        #expect(appState.isDoubleXPBoostActive == false)

        appState.heartsCount = 2
        #expect(appState.purchaseStreakFreezeWithGems() == true)
        #expect(appState.gemsCount == 280)
        #expect(appState.streakFreezeCount == 3)

        #expect(appState.refillHeartsWithGems() == true)
        #expect(appState.gemsCount == 130)
        #expect(appState.heartsCount == 5)

        #expect(appState.activateDoubleXPWithGems() == true)
        #expect(appState.gemsCount == 30)
        #expect(appState.isDoubleXPBoostActive == true)

        // Insufficient gems should fail without mutating state
        #expect(appState.purchaseStreakFreezeWithGems() == false)
        #expect(appState.gemsCount == 30)
    }

    @Test("Fresh new-user state starts with 0 streak, 0 gems, 0 steps, 0 XP, 0 friends, 0 AI threads, 0 exams, and Unit 1 at 0% with only Lesson 1 active")
    func freshNewUserStateAndResetToFreshNewUser() {
        var appState = CertiGoNativeAppState()
        #expect(appState.streakDays == 0)
        #expect(appState.gemsCount == 0)
        #expect(appState.heartsCount == 5)
        #expect(appState.completedStepsTotal == 0)
        #expect(appState.userXPPoints == 0)
        #expect(appState.completedExamsCount == 0)
        #expect(appState.lastComputedExamScoreOutOf1000 == 0)
        #expect(appState.selectedExamChoiceByQuestionNumber.isEmpty)
        #expect(appState.flaggedExamQuestionNumbers.isEmpty)
        #expect(appState.currentExamQuestionIndex == 0)
        #expect(appState.friends.isEmpty)
        #expect(appState.aiThreads.isEmpty)
        #expect(appState.savedAIMemos.isEmpty)
        #expect(appState.routeProgressPercent(forRouteCode: "AZ-104") == 0)
        #expect(appState.domainMasteryPercent(forRouteCode: "AZ-104", domainIndex: 0) == 0)

        let units = appState.currentUnits
        #expect(units.count == 3)
        #expect(units[0].progressPercent == 0)
        #expect(units[1].progressPercent == 0)
        #expect(units[2].progressPercent == 0)
        #expect(units[0].lessons[0].state == .active)
        #expect(units[0].lessons[1].state == .locked)
        #expect(units[0].lessons[2].state == .locked)
        #expect(units[0].lessons[3].state == .miniLab)
        #expect(units[0].lessons[4].state == .locked)

        // Connect Microsoft Entra ID & complete onboarding -> zero fake welcome gems (starts at 0 gems, 0 XP, 0 streak)
        appState.connectMicrosoftEntraAccount()
        #expect(appState.isAccountConnected == true)
        #expect(appState.connectedAuthProvider == "Microsoft Entra ID")
        appState.completeOnboardingFlow(awardWelcomeBonus: true)
        #expect(appState.hasCompletedOnboarding == true)
        #expect(appState.gemsCount == 0)
        #expect(appState.userXPPoints == 0)
        #expect(appState.streakDays == 0)
        #expect(appState.authDraftDisplayName.isEmpty)
        #expect(appState.authDraftEmail.isEmpty)
        #expect(appState.authDraftPassword.isEmpty)

        // Reset to fresh new user -> clears everything back to 0 and re-opens onboarding
        appState.resetToFreshNewUser()
        #expect(appState.streakDays == 0)
        #expect(appState.gemsCount == 0)
        #expect(appState.completedStepsTotal == 0)
        #expect(appState.userXPPoints == 0)
        #expect(appState.isAccountConnected == false)
        #expect(appState.isPresentingOnboardingFlow == true)
    }

    @Test("PDE, AZ-900, SAA-C03, AI-102, CKA, GH-300, and AZ-104 lessons and mock exams return distinct track-specific questions")
    func distinctPerCertificationAndPerLessonQuestionBanksAndExams() {
        let pdeU1S1 = CertiGoNativeLessonSessionEngine.defaultExercises(forRouteCode: "PDE", lessonId: "PDE-u1-s1")
        let pdeU1S2 = CertiGoNativeLessonSessionEngine.defaultExercises(forRouteCode: "PDE", lessonId: "PDE-u1-s2")
        let pdeU2S1 = CertiGoNativeLessonSessionEngine.defaultExercises(forRouteCode: "PDE", lessonId: "PDE-u2-s1")
        let az900U1S1 = CertiGoNativeLessonSessionEngine.defaultExercises(forRouteCode: "AZ-900", lessonId: "AZ-900-u1-s1")
        let az900U1S2 = CertiGoNativeLessonSessionEngine.defaultExercises(forRouteCode: "AZ-900", lessonId: "AZ-900-u1-s2")
        let saaU1S1 = CertiGoNativeLessonSessionEngine.defaultExercises(forRouteCode: "SAA-C03", lessonId: "SAA-C03-u1-s1")
        let ai102 = CertiGoNativeLessonSessionEngine.defaultExercises(forRouteCode: "AI-102", lessonId: "AI-102-u1-s1")
        let cka = CertiGoNativeLessonSessionEngine.defaultExercises(forRouteCode: "CKA", lessonId: "CKA-u1-s1")
        let gh300 = CertiGoNativeLessonSessionEngine.defaultExercises(forRouteCode: "GH-300", lessonId: "GH-300-u1-s1")
        let az104U1 = CertiGoNativeLessonSessionEngine.defaultExercises(forRouteCode: "AZ-104", lessonId: "AZ-104-u1-s1")
        let az104U2 = CertiGoNativeLessonSessionEngine.defaultExercises(forRouteCode: "AZ-104", lessonId: "AZ-104-u2-s1")
        let az104U3 = CertiGoNativeLessonSessionEngine.defaultExercises(forRouteCode: "AZ-104", lessonId: "AZ-104-u3-s1")

        #expect(pdeU1S1[0].prompt.contains("Pub/Sub"))
        #expect(pdeU1S2[0].prompt.contains("BigQuery"))
        #expect(pdeU2S1[0].prompt != pdeU1S1[0].prompt)
        #expect(az900U1S1[0].prompt.contains("Pay-as-you-go"))
        #expect(az900U1S2[0].prompt != az900U1S1[0].prompt)
        #expect(saaU1S1[0].prompt.contains("Amazon EC2"))
        #expect(ai102[0].prompt.contains("Azure AI Search"))
        #expect(cka[0].prompt.contains("ServiceAccount"))
        #expect(gh300[0].prompt.contains("GitHub Copilot"))
        #expect(az104U1[0].prompt != az104U2[0].prompt)
        #expect(az104U2[0].prompt != az104U3[0].prompt)

        // Verify mock exam questions are distinct across certifications
        let examPDE = CertiGoNativeRichCatalog.buildExamQuestions(forRouteCode: "PDE")
        let examAZ900 = CertiGoNativeRichCatalog.buildExamQuestions(forRouteCode: "AZ-900")
        let examSAA = CertiGoNativeRichCatalog.buildExamQuestions(forRouteCode: "SAA-C03")
        let examAI102 = CertiGoNativeRichCatalog.buildExamQuestions(forRouteCode: "AI-102")
        let examCKA = CertiGoNativeRichCatalog.buildExamQuestions(forRouteCode: "CKA")
        let examAZ104 = CertiGoNativeRichCatalog.buildExamQuestions(forRouteCode: "AZ-104")

        #expect(examPDE.count == 12)
        #expect(examAZ900.count == 12)
        #expect(examSAA.count == 12)
        #expect(examAI102.count == 12)
        #expect(examCKA.count == 12)
        #expect(examAZ104.count == 12)

        let firstStems: Set<String> = [
            examPDE[0].stem,
            examAZ900[0].stem,
            examSAA[0].stem,
            examAI102[0].stem,
            examCKA[0].stem,
            examAZ104[0].stem
        ]
        #expect(firstStems.count == 6)
    }

    @Test("All SVG files in Prism.xcassets and BrandAssets.xcassets have explicit numeric width/height (no em units) and all exercise service assets exist")
    func allSVGFilesHaveNumericDimensionsAndAllExerciseAssetsExist() throws {
        var root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: root.appendingPathComponent("AGENTS.md").path) {
            let parent = root.deletingLastPathComponent()
            guard parent != root else { throw CocoaError(.fileNoSuchFile) }
            root = parent
        }
        let prismAssets = root.appendingPathComponent("apps/apple/CertigoKit/Sources/Prism/Resources/Prism.xcassets")
        let brandAssets = root.appendingPathComponent("apps/apple/CertigoKit/Sources/BrandAssets/Resources/BrandAssets.xcassets")

        for xcRoot in [prismAssets, brandAssets] {
            let enumerator = FileManager.default.enumerator(at: xcRoot, includingPropertiesForKeys: nil)
            while let fileURL = enumerator?.nextObject() as? URL {
                guard fileURL.pathExtension.lowercased() == "svg" else { continue }
                let svgText = try String(contentsOf: fileURL, encoding: .utf8)
                #expect(!svgText.contains("width=\"1em\""), "Found em width in \(fileURL.lastPathComponent)")
                #expect(!svgText.contains("height=\"1em\""), "Found em height in \(fileURL.lastPathComponent)")
            }
        }

        let routesAndLessons: [(String, String)] = [
            ("PDE", "PDE-u1-s1"), ("PDE", "PDE-u1-s2"), ("PDE", "PDE-u2-s1"),
            ("AZ-900", "AZ-900-u1-s1"), ("AZ-900", "AZ-900-u1-s2"), ("AZ-900", "AZ-900-u2-s1"),
            ("SAA-C03", "SAA-C03-u1-s1"), ("SAA-C03", "SAA-C03-u2-s1"),
            ("AI-102", "AI-102-u1-s1"), ("CKA", "CKA-u1-s1"), ("GH-300", "GH-300-u1-s1"),
            ("AZ-104", "AZ-104-u1-s1"), ("AZ-104", "AZ-104-u2-s1"), ("AZ-104", "AZ-104-u3-s1")
        ]
        for (route, lessonId) in routesAndLessons {
            let exercises = CertiGoNativeLessonSessionEngine.defaultExercises(forRouteCode: route, lessonId: lessonId)
            for ex in exercises {
                for opt in ex.options {
                    if let assetName = opt.assetName {
                        let assetDir = prismAssets.appendingPathComponent("\(assetName).imageset")
                        #expect(
                            FileManager.default.fileExists(atPath: assetDir.path),
                            "Missing imageset \(assetName) in \(route) \(lessonId)"
                        )
                    }
                }
            }
        }
    }

    @Test("Adaptive Engine 1: Flawless user gets shorter session, prunes redundant questions once mastery >= threshold, and finishes cleanly")
    func testAdaptiveEngineFlawlessUserGetsShorterSessionAndPrunesRedundantQuestions() {
        var (sessionState, learnerState) = CertiGoAdaptiveSessionEngine.buildInitialSession(
            routeCode: "AZ-104",
            lessonId: "AZ-104-u1-s1",
            sessionSeed: 1
        )
        let initialQueueCount = sessionState.queue.count
        #expect(initialQueueCount == 8)

        // Pre-boost mastery near threshold so fast correct answers reach >= 0.75 on the first pass of 4 concepts
        for cid in sessionState.conceptIds {
            learnerState[cid]?.mastery = 0.55
        }

        var answeredCount = 0
        while CertiGoAdaptiveSessionEngine.nextQuestion(sessionState: sessionState, learnerState: learnerState) != nil {
            CertiGoAdaptiveSessionEngine.recordAnswer(
                sessionState: &sessionState,
                learnerState: &learnerState,
                isCorrect: true,
                latencyMs: 2_200,
                usedHint: false
            )
            answeredCount += 1
        }

        // Because every first answer crossed masteryThreshold (0.55 + 0.26 = 0.81 >= 0.75), the 4 redundant Round-2 questions were pruned!
        #expect(answeredCount == 4)
        #expect(answeredCount < initialQueueCount)
        for cid in sessionState.conceptIds {
            #expect((learnerState[cid]?.mastery ?? 0) >= sessionState.masteryThreshold)
        }
    }

    @Test("Adaptive Engine 2: Errors re-insert a variant of the same concept 3 to 5 positions later with isReviewReplay=true and replay at end of session")
    func testAdaptiveEngineWithErrorsReinsertsVariant3To5PositionsLaterAndReplaysAtEnd() {
        var (sessionState, learnerState) = CertiGoAdaptiveSessionEngine.buildInitialSession(
            routeCode: "PDE",
            lessonId: "PDE-u1-s1",
            sessionSeed: 1
        )
        guard let firstQ = CertiGoAdaptiveSessionEngine.nextQuestion(sessionState: sessionState, learnerState: learnerState) else {
            Issue.record("Expected initial question")
            return
        }
        let missedConceptId = firstQ.conceptId

        // Make an error on Question 1
        CertiGoAdaptiveSessionEngine.recordAnswer(
            sessionState: &sessionState,
            learnerState: &learnerState,
            isCorrect: false,
            latencyMs: 8_500,
            usedHint: false
        )

        #expect(sessionState.conceptsToReviewAtEnd.contains(missedConceptId))
        #expect(sessionState.retryBudgetByConcept[missedConceptId] == 1)
        #expect((learnerState[missedConceptId]?.errorCount ?? 0) == 1)

        // Verify a variant of the SAME concept with isReviewReplay == true was inserted 3..4 positions later in the queue
        let replayIndices = sessionState.queue.indices.filter {
            sessionState.queue[$0].conceptId == missedConceptId && sessionState.queue[$0].isReviewReplay
        }
        #expect(!replayIndices.isEmpty)
        if let firstReplayIdx = replayIndices.first {
            #expect(firstReplayIdx >= 3 && firstReplayIdx <= 4)
            #expect(sessionState.queue[firstReplayIdx].id != firstQ.id)
        }

        // Finish the rest of the queue with correct answers and verify the end-of-session review is also replayed
        var sawReviewReplay = false
        while let nextQ = CertiGoAdaptiveSessionEngine.nextQuestion(sessionState: sessionState, learnerState: learnerState) {
            if nextQ.isReviewReplay {
                sawReviewReplay = true
            }
            CertiGoAdaptiveSessionEngine.recordAnswer(
                sessionState: &sessionState,
                learnerState: &learnerState,
                isCorrect: true,
                latencyMs: 2_500,
                usedHint: false
            )
        }
        #expect(sawReviewReplay == true)
        #expect(sessionState.endOfQueueReviewReplayed.contains(missedConceptId))
    }

    @Test("Adaptive Engine 3: maxQuestions = 25 ceiling guarantees session termination even on repeated errors")
    func testAdaptiveEngineMaxQuestionsCeilingGuaranteesTermination() {
        var (sessionState, learnerState) = CertiGoAdaptiveSessionEngine.buildInitialSession(
            routeCode: "SAA-C03",
            lessonId: "SAA-C03-u1-s1",
            sessionSeed: 7,
            maxQuestions: 25
        )

        var iterations = 0
        while CertiGoAdaptiveSessionEngine.nextQuestion(sessionState: sessionState, learnerState: learnerState) != nil {
            CertiGoAdaptiveSessionEngine.recordAnswer(
                sessionState: &sessionState,
                learnerState: &learnerState,
                isCorrect: false,
                latencyMs: 9_000,
                usedHint: true
            )
            iterations += 1
            if iterations > 30 {
                break
            }
        }

        #expect(iterations <= 25)
        #expect(sessionState.questionsAsked <= 25)
        #expect(CertiGoAdaptiveSessionEngine.nextQuestion(sessionState: sessionState, learnerState: learnerState) == nil)
    }

    @Test("Zelda Hearts 4: Making 5 errors drops heartsCount to 0, triggers isSessionFailedOutOfHearts, and blocks unlocking the next step")
    func testZeldaHearts5ErrorsBlocksStepCompletionAndUnlock() {
        var appState = CertiGoNativeAppState()
        appState.startLessonSession(forLessonId: "AZ-104-u1-s1", skipDeclic15: true, enableAdaptiveReplay: true)
        #expect(appState.lessonSession.heartsCount == 5)
        #expect(appState.lessonSession.isSessionFailedOutOfHearts == false)

        // Make 5 wrong answers across the session
        for expectedRemainingHearts in (0...4).reversed() {
            let ex = appState.lessonSession.currentExercise
            if ex.formatCode == "Q_TYPE_04" {
                appState.lessonSession.cliInputText = "wrong-cli"
            } else if ex.formatCode == "Q_TYPE_05" {
                appState.lessonSession.toggleWordBankBrick(ex.wordBankAllBricks.last ?? "delete")
            } else if let wrongOpt = ex.options.first(where: { !$0.isCorrect }) {
                appState.lessonSession.selectOption(wrongOpt.id)
            }
            let result = appState.lessonSession.verifyCurrentAnswer()
            #expect(result == false)
            #expect(appState.lessonSession.heartsCount == expectedRemainingHearts)
            #expect(appState.lessonSession.lastLostHeartIndex == expectedRemainingHearts)
            appState.lessonSession.advanceToNextExerciseOrFinish()
        }

        #expect(appState.lessonSession.heartsCount == 0)
        #expect(appState.lessonSession.isSessionFailedOutOfHearts == true)
        #expect(appState.lessonSession.hasTriggeredOutOfHeartsFailure == true)
        #expect(appState.lessonSession.isSessionCompleted == false)

        // Attempting to complete the session when out of hearts must NOT unlock Lesson 2 or award gems/XP
        appState.completeActiveLessonSessionAndUnlockNextNode()
        let lessonsAfterFailure = appState.currentUnits[0].lessons
        #expect(lessonsAfterFailure[0].state == .active)
        #expect(lessonsAfterFailure[1].state == .locked)
        #expect(appState.completedStepsTotal == 0)
        #expect(appState.gemsCount == 0)
        #expect(appState.userXPPoints == 0)

        // Restarting the failed lesson restores 5 fresh hearts
        appState.restartFailedLessonSessionWithFullHearts()
        #expect(appState.lessonSession.heartsCount == 5)
        #expect(appState.lessonSession.isSessionFailedOutOfHearts == false)
        #expect(appState.lessonSession.hasTriggeredOutOfHeartsFailure == false)
    }

    @Test("Adaptive Engine 5: Pure nextQuestion(sessionState:learnerState:) function and different user seeds produce distinct question orders")
    func testPureNextQuestionFunctionAndDifferentUserSeedsProduceDifferentOrders() {
        let (sessionA, learnerA) = CertiGoAdaptiveSessionEngine.buildInitialSession(
            routeCode: "AZ-104",
            lessonId: "AZ-104-u1-s1",
            sessionSeed: 1
        )
        let (sessionB, learnerB) = CertiGoAdaptiveSessionEngine.buildInitialSession(
            routeCode: "AZ-104",
            lessonId: "AZ-104-u1-s1",
            sessionSeed: 42
        )

        // Pure function returns identical output when called repeatedly without state mutation
        let firstCall = CertiGoAdaptiveSessionEngine.nextQuestion(sessionState: sessionA, learnerState: learnerA)
        let secondCall = CertiGoAdaptiveSessionEngine.nextQuestion(sessionState: sessionA, learnerState: learnerA)
        #expect(firstCall != nil)
        #expect(firstCall == secondCall)

        // Different seeds produce different initial question orders
        let idsA = sessionA.queue.map(\.id)
        let idsB = sessionB.queue.map(\.id)
        #expect(idsA != idsB)
        #expect(CertiGoAdaptiveSessionEngine.nextQuestion(sessionState: sessionB, learnerState: learnerB) != nil)
    }

    @Test("Saving an AI chat turn appends it to savedAIMemos and marks isSavedToMemo")
    func saveAIChatTurnToSavedMemos() {
        var appState = CertiGoNativeAppState()
        appState.isLiveAIModelConnected = true
        appState.openAITopic("rbac-vs-policy")
        #expect(appState.chatTurns.count == 1)
        #expect(appState.chatTurns[0].isSavedToMemo == false)
        #expect(appState.savedAIMemos.isEmpty)

        appState.saveChatTurnToMemo(at: 0)
        #expect(appState.chatTurns[0].isSavedToMemo == true)
        #expect(appState.savedAIMemos.count == 1)
        #expect(appState.savedAIMemos[0].id == appState.chatTurns[0].id)

        appState.removeSavedAIMemo(id: appState.chatTurns[0].id)
        #expect(appState.savedAIMemos.isEmpty)
        #expect(appState.chatTurns[0].isSavedToMemo == false)
    }

    @Test("CertiGoErrorCode registry provides 12 numbered CG-ERR-xxxx codes and disconnected AI triggers CG-ERR-1001 without fake answers")
    func honestDisconnectedAIErrorAndCompleteErrorRegistry() {
        #expect(CertiGoErrorCode.allCases.count == 12)
        let uniqueCodes = Set(CertiGoErrorCode.allCases.map(\.code))
        #expect(uniqueCodes.count == 12)

        for err in CertiGoErrorCode.allCases {
            #expect(err.code.hasPrefix("CG-ERR-"))
            #expect(!err.category.isEmpty)
            #expect(!err.severityLabel.isEmpty)
            #expect(!err.title.isEmpty)
            #expect(!err.userMessage.isEmpty)
            #expect(!err.technicalDetail.isEmpty)
            #expect(!err.recommendedAction.isEmpty)
        }

        var appState = CertiGoNativeAppState()
        #expect(appState.isLiveAIModelConnected == true)
        #expect(appState.activeDiagnosticError == nil)

        // Explicitly switch to offline mode to test honest disconnected error handling
        appState.isLiveAIModelConnected = false
        appState.sendAIMessage("Test")
        #expect(appState.chatTurns.isEmpty)
        #expect(appState.activeDiagnosticError == .aiModelNotConnected1001)
        #expect(appState.errorLogHistory.contains(.aiModelNotConnected1001))

        appState.openAITopic("last-3-errors")
        #expect(appState.chatTurns.count == 1)
        #expect(appState.chatTurns[0].closingTip.contains("Synthèse locale hors-ligne certifiée"))
        #expect(appState.activeDiagnosticError == .examReportAIDisconnected1003)
    }

    @Test("Updating profile name, handle, and target exam date updates initials, leaderboard entry, and closes editor sheet")
    func updateProfileNameHandleAndTargetExamDate() {
        var appState = CertiGoNativeAppState()
        appState.showEditProfileSheet = true

        appState.updateProfile(
            displayName: "Alexandre Martin",
            handle: "alex_azure",
            targetExamDate: "15 Déc. 2026",
            avatarHex: "#7c3aed"
        )

        #expect(appState.userDisplayName == "Alexandre Martin")
        #expect(appState.userHandle == "@alex_azure")
        #expect(appState.targetExamDateText == "15 Déc. 2026")
        #expect(appState.userAvatarHex == "#7c3aed")
        #expect(appState.userInitials == "AM")
        #expect(appState.showEditProfileSheet == false)
        let meAtZeroXP = appState.leaderboardMembers.first(where: \.isCurrentUser)
        #expect(meAtZeroXP?.rank == 1)
        #expect(meAtZeroXP?.displayName == "Toi (Alexandre)")
        #expect(meAtZeroXP?.initials == "AM")
    }

    @Test("FigMetrics and its static constants are public and no private enum/extension FigMetrics remains for Xcode 27 SwiftEmitModule")
    func figMetricsPublicVisibilityForXcode27SwiftEmitModule() throws {
        #expect(FigMetrics.zero == 0)
        #expect(FigMetrics.eleven == 11)
        #expect(FigMetrics.thirteen == 13)
        #expect(FigMetrics.fourteen == 14)
        #expect(FigMetrics.fifteenOrSixteen == 15)
        #expect(FigMetrics.radarSize == 190)

        var root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: root.appendingPathComponent("AGENTS.md").path) {
            let parent = root.deletingLastPathComponent()
            guard parent != root else { throw CocoaError(.fileNoSuchFile) }
            root = parent
        }
        let figmaAppFile = root.appendingPathComponent(
            "apps/apple/CertigoKit/Sources/Prism/Screens/CertiGoNativeFigmaApp.swift"
        )
        let source = try String(contentsOf: figmaAppFile, encoding: .utf8)
        #expect(!source.contains("private enum FigMetrics"))
        #expect(!source.contains("private extension FigMetrics"))
        #expect(source.contains("public enum FigMetrics"))
        #expect(source.contains("public static let fourteen: CGFloat = 14"))
    }

    @Test("Chantier 1: All SVG paths in Prism.xcassets and BrandAssets.xcassets have de-minified arc flags for CoreSVG and Kubernetes uses BrandLogos/brand-kubernetes")
    func svgCoreSVGDeMinifiedArcFlagsAndKubernetesBrandLogo() throws {
        var root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: root.appendingPathComponent("AGENTS.md").path) {
            let parent = root.deletingLastPathComponent()
            guard parent != root else { throw CocoaError(.fileNoSuchFile) }
            root = parent
        }
        let badgeFiles = [
            "Certifications/ms-official-associate-badge.imageset/ms-official-associate-badge.svg",
            "Certifications/ms-official-fundamentals-badge.imageset/ms-official-fundamentals-badge.svg",
            "Certifications/ms-official-expert-badge.imageset/ms-official-expert-badge.svg",
            "Certifications/ms-official-specialty-badge.imageset/ms-official-specialty-badge.svg"
        ]
        let prismAssets = root.appendingPathComponent("apps/apple/CertigoKit/Sources/Prism/Resources/Prism.xcassets")
        for relPath in badgeFiles {
            let url = prismAssets.appendingPathComponent(relPath)
            let svg = try String(contentsOf: url, encoding: .utf8)
            #expect(!svg.contains("0 00-"), "Found minified arc flag 00- in \(relPath)")
            #expect(!svg.contains("0 01-"), "Found minified arc flag 01- in \(relPath)")
            #expect(!svg.contains("-.16-.05"), "Found glued negative decimals in \(relPath)")
            #expect(svg.contains("a 16.44 16.44 0 0 0 -10.75 -6.69"))
        }

        #expect(CertiGoOfficialAssetCatalog.brandLogoAssetName(forVendorId: "kubernetes") == "BrandLogos/brand-kubernetes")
        #expect(CertiGoOfficialAssetCatalog.brandLogoAssetName(forVendorId: "cisco") == "BrandLogos/brand-cisco")
        #expect(CertiGoFigmaLiveRuntimeState.popoverCards(forVendor: "kubernetes").map(\.code) == ["CKA", "CKAD", "TF-003"])
        #expect(CertiGoFigmaLiveRuntimeState.popoverCards(forVendor: "cisco").map(\.code) == ["CCNA", "CKA", "TF-003"])
    }

    @Test("Chantier 4: Completing 7-step Onboarding launches the 5-step Interactive Guided App Tour across all 5 tabs and returns to .parcours")
    func onboardingPage07AndFiveStepGuidedAppTourNavigation() {
        var appState = CertiGoNativeAppState()
        #expect(appState.onboardingSelectedGoalIds == ["certifs", "ai-radar"])
        appState.toggleOnboardingGoal("career")
        #expect(appState.onboardingSelectedGoalIds.contains("career"))

        #expect(appState.onboardingSelectedAIRadarIds == ["ai-actors", "ai-agents-mcp"])
        appState.toggleOnboardingAIRadar("cloud-weekly")
        #expect(appState.onboardingSelectedAIRadarIds.contains("cloud-weekly"))

        appState.completeOnboardingFlow(awardWelcomeBonus: true, startGuidedTour: true)
        #expect(appState.hasCompletedOnboarding == true)
        #expect(appState.gemsCount == 0)
        #expect(appState.isPresentingGuidedAppTour == true)
        #expect(appState.guidedTourStepIndex == 0)
        #expect(appState.selectedTab == .parcours)

        let expectedTabs: [CertiGoNativeTab] = [.examens, .hubIA, .social, .moi]
        for (idx, expectedTab) in expectedTabs.enumerated() {
            appState.advanceGuidedTourStep()
            #expect(appState.isPresentingGuidedAppTour == true)
            #expect(appState.guidedTourStepIndex == idx + 1)
            #expect(appState.selectedTab == expectedTab)
        }

        // Advancing from step 5/5 (index 4 on .moi) completes the guided tour and returns to .parcours
        appState.advanceGuidedTourStep()
        #expect(appState.isPresentingGuidedAppTour == false)
        #expect(appState.selectedTab == .parcours)
    }

    @Test("Chantier 5: Wrong answer stays in .checked phase until user taps Explain, CONTINUER from explanation advances directly, and replay options keep A, B, C, D order with rephrased prompt")
    func manualErrorExplanationOrderedOptionBadgesAndRephrasedReplayPrompt() {
        var appState = CertiGoNativeAppState()
        appState.startLessonSession(forLessonId: "AZ-104-u1-s1", skipDeclic15: true, enableAdaptiveReplay: true)
        let firstEx = appState.lessonSession.currentExercise
        #expect(firstEx.options.map(\.badge) == ["A", "B", "C", "D"])

        // Select a wrong option and verify -> must enter .checked(isCorrect: false) and NEVER .explainingError automatically
        if let wrongOpt = firstEx.options.first(where: { !$0.isCorrect }) {
            appState.lessonSession.selectOption(wrongOpt.id)
        }
        let isCorrect = appState.lessonSession.verifyCurrentAnswer()
        #expect(isCorrect == false)
        #expect(appState.lessonSession.attemptPhase == .checked(isCorrect: false))

        // Explicitly opening explanation sheet 05 and tapping CONTINUER advances directly to question 2
        appState.lessonSession.openErrorExplanationSheet05()
        #expect(appState.lessonSession.attemptPhase == .explainingError)
        appState.lessonSession.advanceToNextExerciseOrFinish()
        #expect(appState.lessonSession.currentExerciseIndex == 1)
        #expect(appState.lessonSession.attemptPhase == .answering)

        // Check the inserted replay exercise has A, B, C, D badges in top-to-bottom order and a rephrased prompt
        if let replayEx = appState.lessonSession.exercises.first(where: \.isReviewReplay) {
            #expect(replayEx.options.map(\.badge) == ["A", "B", "C", "D"])
            #expect(replayEx.prompt != firstEx.prompt)
        } else {
            Issue.record("Expected replay exercise to be inserted")
        }

        // Also verify candidate pool variants always keep A, B, C, D badges in order
        let pool = CertiGoAdaptiveSessionEngine.buildCandidatePool(
            from: CertiGoNativeLessonSessionEngine.defaultExercises(forRouteCode: "AZ-104", lessonId: "AZ-104-u1-s1"),
            routeCode: "AZ-104",
            lessonId: "AZ-104-u1-s1"
        )
        for candidate in pool where candidate.exercise.options.count == 4 {
            let badges = candidate.exercise.options.map(\.badge)
            if Set(badges).isSubset(of: ["A", "B", "C", "D"]) {
                #expect(badges == ["A", "B", "C", "D"])
            }
        }
    }

    @Test("Chantier 6: Social leaderboard starts with only current user (zero fake data), syncs real added friends, Free vs Pro tier badge, GH-300 6 domains, exam provider metadata, and Domain Sprint returns to .examens")
    func socialLeaderboardSortingFreeVsProGH300DomainsAndDomainSprintRouting() {
        var appState = CertiGoNativeAppState()

        // 1. Leaderboard starts with only the real current user at rank 1 with 0 XP (zero fake profiles)
        #expect(CertiGoNativeRichCatalog.defaultLeaderboardMembers.count == 1)
        #expect(appState.leaderboardMembers.count == 1)
        #expect(appState.leaderboardMembers[0].isCurrentUser == true)
        #expect(appState.leaderboardMembers[0].xpPoints == 0)
        #expect(appState.leaderboardMembers[0].rank == 1)

        // Adding a real friend adds them to the leaderboard; earning XP keeps current user #1
        appState.friendSearchQuery = "@thomas"
        appState.addNewFriendFromSearch()
        #expect(appState.friends.count == 1)
        #expect(appState.leaderboardMembers.count == 2)

        appState.userXPPoints = 150
        appState.syncCurrentUserLeaderboardEntry()
        #expect(appState.leaderboardMembers[0].isCurrentUser == true)
        #expect(appState.leaderboardMembers[0].rank == 1)
        #expect(appState.leaderboardMembers[1].displayName == "Thomas")
        #expect(appState.leaderboardMembers[1].rank == 2)

        // 2. Free vs Pro membership tier
        #expect(appState.isProMember == false)

        // 3. GH-300 has 6 official domains and CKA/GCP/Microsoft have official exam provider metadata
        let gh300Detail = CertiGoNativeRichCatalog.profileCertificationDetail(forCode: "GH-300")
        #expect(gh300Detail.domains.count == 6)
        #expect(CertiGoNativeRichCatalog.examDomains(forRouteCode: "GH-300").count == 6)
        #expect(CertiGoNativeRichCatalog.examProviderMetadata(forRouteCode: "CKA").summaryLine == "Linux Foundation / PSI · 66/100 · 120 min")
        #expect(CertiGoNativeRichCatalog.examProviderMetadata(forRouteCode: "PCA").providerName == "Kryterion")
        #expect(CertiGoNativeRichCatalog.examProviderMetadata(forRouteCode: "AZ-104").providerName == "Pearson VUE")

        // 4. Starting a Domain Sprint from Examens remembers returnTabAfterLessonSession == .examens
        appState.selectedTab = .examens
        appState.startDomainSprintSession(forDomainIndex: 1)
        #expect(appState.isPresentingLessonSession == true)
        #expect(appState.returnTabAfterLessonSession == .examens)
        #expect(appState.lessonSession.exercises.count == 5)
    }

    @Test("CertiGoStructuredPromptView.splitScenarioAndQuestion separates scenario and final question cleanly and strips raw backticks")
    func structuredPromptViewSplitsScenarioAndQuestionAndStripsBackticks() {
        // 1. Explicit newline separation + backtick stripping
        let newlineSplit = CertiGoStructuredPromptView.splitScenarioAndQuestion(
            "Un microservice exécuté avec le ServiceAccount `payment-sa` dans le namespace `finance` doit lire les `Secrets`.\nQuelle combinaison d'objets RBAC déployez-vous ?"
        )
        #expect(
            newlineSplit.scenario
                == "Un microservice exécuté avec le ServiceAccount payment-sa dans le namespace finance doit lire les Secrets."
        )
        #expect(newlineSplit.question == "Quelle combinaison d'objets RBAC déployez-vous ?")
        #expect(newlineSplit.scenario?.contains("`") == false)
        #expect(!newlineSplit.question.contains("`"))

        // 2. Automatic multi-sentence boundary split before final interrogative/directive sentence
        let autoSplit = CertiGoStructuredPromptView.splitScenarioAndQuestion(
            "Vous désactivez les clés API (`disableLocalAuth = true`) sur Azure OpenAI. Quel rôle RBAC minimal attribuez-vous à la Managed Identity de votre application ?"
        )
        #expect(autoSplit.scenario == "Vous désactivez les clés API (disableLocalAuth = true) sur Azure OpenAI.")
        #expect(
            autoSplit.question
                == "Quel rôle RBAC minimal attribuez-vous à la Managed Identity de votre application ?"
        )

        // 3. Single-sentence question without scenario
        let singleQuestion = CertiGoStructuredPromptView.splitScenarioAndQuestion(
            "Quelle sonde retire temporairement un pod des Endpoints d'un Service Kubernetes sans redémarrer le conteneur ?"
        )
        #expect(singleQuestion.scenario == nil)
        #expect(
            singleQuestion.question
                == "Quelle sonde retire temporairement un pod des Endpoints d'un Service Kubernetes sans redémarrer le conteneur ?"
        )

        // 4. Verify all exercise prompts across all tracks split cleanly and contain no raw backticks
        let tracks = ["AZ-104", "AZ-900", "SAA-C03", "PDE", "AI-102", "CKA", "GH-300"]
        for track in tracks {
            let exercises = CertiGoNativeLessonSessionEngine.defaultExercises(
                forRouteCode: track,
                lessonId: "\(track)-u1-s1"
            )
            for ex in exercises {
                #expect(!ex.prompt.contains("`"), "Found raw backtick in \(ex.id) prompt")
                let parts = CertiGoStructuredPromptView.splitScenarioAndQuestion(ex.prompt)
                #expect(parts.scenario != nil && !(parts.scenario ?? "").isEmpty, "Expected scenario in \(ex.id)")
                #expect(!parts.question.isEmpty, "Expected final question in \(ex.id)")
                for opt in ex.options {
                    #expect(!opt.title.contains("`"), "Found raw backtick in option \(opt.id) of \(ex.id)")
                }
            }
        }
    }

    @Test("Live AI Tutor: isLiveAIModelConnected is true by default, activeDiagnosticError is nil, and buildPersonalLearnerContext updates dynamically on right/wrong answers")
    func liveAIPersonalLearnerContextAndTrackMappings() {
        var appState = CertiGoNativeAppState()
        #expect(appState.isLiveAIModelConnected == true)
        #expect(appState.activeDiagnosticError == nil)
        #expect(appState.errorLogHistory.isEmpty)
        #expect(appState.personalLearnerUserId.hasPrefix("usr-"))

        // Configure user onboarding profile
        appState.userDisplayName = "Gabriel Chambaud"
        appState.onboardingExperienceLevelIndex = 2 // Avancé
        appState.onboardingDailyRhythmMinutes = 20
        appState.targetExamDateText = "Dans 30 jours"
        appState.selectRoute("SAA-C03")

        let initialContext = appState.buildPersonalLearnerContext()
        #expect(initialContext.userId == appState.personalLearnerUserId)
        #expect(initialContext.displayName == "Gabriel Chambaud")
        #expect(initialContext.experienceLevelLabel == "Avancé")
        #expect(initialContext.dailyRhythmMinutes == 20)
        #expect(initialContext.targetExamHorizon == "Dans 30 jours")
        #expect(initialContext.activeRouteCode == "SAA-C03")
        #expect(initialContext.totalVerifiedQuestions == 0)
        #expect(initialContext.recentMistakesSummary.isEmpty)

        // Start a lesson session and make a wrong answer on Exercise 1
        appState.startLessonSession(forLessonId: "SAA-C03-u1-s1", skipDeclic15: true, enableAdaptiveReplay: true)
        let ex1 = appState.lessonSession.currentExercise
        if let wrongOption = ex1.options.first(where: { !$0.isCorrect }) {
            appState.lessonSession.selectOption(wrongOption.id)
        }
        #expect(appState.lessonSession.verifyCurrentAnswer() == false)

        let afterMistakeContext = appState.buildPersonalLearnerContext()
        #expect(afterMistakeContext.totalVerifiedQuestions == 1)
        #expect(afterMistakeContext.accuracyPercent == 0)
        #expect(afterMistakeContext.recentMistakesSummary.count == 1)
        #expect(afterMistakeContext.recentMistakesSummary[0].contains(ex1.conceptTitle))
        #expect(afterMistakeContext.weakConceptsSummary.contains(where: { $0.contains("1 erreur") }))

        let promptPayload = afterMistakeContext.formattedPromptContext(
            userQuestionOrChoice: "Pourquoi mon groupe Auto Scaling recrée-t-il l'instance EC2 ?"
        )
        #expect(promptPayload.contains("Gabriel Chambaud"))
        #expect(promptPayload.contains("Avancé"))
        #expect(promptPayload.contains("20 min/j"))
        #expect(promptPayload.contains("SAA-C03"))
        #expect(promptPayload.contains("Pourquoi mon groupe Auto Scaling"))

        // Advance and answer Exercise 2 correctly with pre-boosted mastery so concept crosses >= 0.75
        appState.lessonSession.advanceToNextExerciseOrFinish()
        let ex2 = appState.lessonSession.currentExercise
        if let currentConceptId = appState.lessonSession.adaptiveSessionState.queue.first?.conceptId {
            appState.lessonSession.adaptiveLearnerState[currentConceptId]?.mastery = 0.60
        }
        if let rightOption = ex2.options.first(where: \.isCorrect) {
            appState.lessonSession.selectOption(rightOption.id)
        }
        #expect(appState.lessonSession.verifyCurrentAnswer(latencyMs: 1_800) == true)

        let afterCorrectContext = appState.buildPersonalLearnerContext()
        #expect(afterCorrectContext.totalVerifiedQuestions == 2)
        #expect(afterCorrectContext.accuracyPercent == 50)
        #expect(!afterCorrectContext.strongConceptsSummary.isEmpty)

        // Verify live backend track mapping across all supported certifications
        #expect(CertiGoLiveAITutorService.backendTrackTarget(forRouteCode: "AZ-104").trackId == "microsoft.az-104.track.main")
        #expect(CertiGoLiveAITutorService.backendTrackTarget(forRouteCode: "AZ-900").trackId == "microsoft.az-900.track.main")
        #expect(CertiGoLiveAITutorService.backendTrackTarget(forRouteCode: "AI-102").trackId == "microsoft.ai-103.track.main")
        #expect(CertiGoLiveAITutorService.backendTrackTarget(forRouteCode: "AI-901").trackId == "microsoft.ai-901.track.main")
        #expect(CertiGoLiveAITutorService.backendTrackTarget(forRouteCode: "GH-300").trackId == "microsoft.gh-300.track.main")
        #expect(CertiGoLiveAITutorService.backendTrackTarget(forRouteCode: "CCA-F").trackId == "microsoft.gh-300.track.main")
        #expect(CertiGoLiveAITutorService.backendTrackTarget(forRouteCode: "SAA-C03").trackId == "aws.saa-c03.track.main")
        #expect(CertiGoLiveAITutorService.backendTrackTarget(forRouteCode: "CLF-C02").trackId == "aws.clf-c02.track.main")
        #expect(CertiGoLiveAITutorService.backendTrackTarget(forRouteCode: "AIF-C01").trackId == "aws.aif-c01.track.main")
        #expect(CertiGoLiveAITutorService.backendTrackTarget(forRouteCode: "PDE").trackId == "gcp.data-engineer.track.main")
        #expect(CertiGoLiveAITutorService.backendTrackTarget(forRouteCode: "PCA").trackId == "gcp.cloud-architect.track.main")
        #expect(CertiGoLiveAITutorService.backendTrackTarget(forRouteCode: "ACE").trackId == "gcp.cloud-engineer.track.main")
        #expect(CertiGoLiveAITutorService.backendTrackTarget(forRouteCode: "CKA").trackId == "microsoft.az-104.track.main")

        // Verify applying a live gpt-5.4-mini response updates the chat turn and personalization summary
        appState.sendAIMessage("Explique la différence entre RBAC et Azure Policy")
        #expect(appState.chatTurns.count == 1)
        let turnId = appState.chatTurns[0].id
        #expect(appState.chatTurns[0].isStreamingOrLoading == true)

        let simulatedLiveResponse = CertiGoLiveAITutorResponse(
            itemId: "microsoft.az-104.section-1.az104-scenario-2026-02.001",
            conceptId: "microsoft.az-104.concept.az104-scenario-2026-02",
            correct: false,
            headline: "Azure Policy contrôle la conformité des ressources tandis que RBAC gère les identités",
            points: [
                "Azure RBAC attribue des permissions aux utilisateurs, groupes et Managed Identities.",
                "Azure Policy applique des garde-fous sur les propriétés des ressources ARM même pour un Owner.",
                "Une affectation Policy au Management Group est héritée par tous les abonnements enfants."
            ],
            encouragement: "Excellente progression sur la gouvernance Azure !",
            recommendation: "Révise le lab sur les verrous CanNotDelete et l'effet Deny.",
            citedConceptIds: ["microsoft.az-104.concept.az104-scenario-2026-02"],
            source: "ai",
            personalization: .init(
                attempts: 3,
                errors: 1,
                accuracyPct: 67,
                recurringStruggle: false,
                masteredBefore: true,
                trend: "improving",
                topConfusedOption: nil
            )
        )
        appState.applyLiveAITutorResponse(simulatedLiveResponse, toTurnWithId: turnId)
        #expect(appState.chatTurns[0].isStreamingOrLoading == false)
        #expect(appState.chatTurns[0].isLiveAIResponse == true)
        #expect(appState.chatTurns[0].aiHeadline == simulatedLiveResponse.headline)
        #expect(appState.chatTurns[0].extraPoints.count == 1)
        #expect(appState.chatTurns[0].liveSourceBadge?.contains("GABRIEL") == true)
        #expect(appState.chatTurns[0].personalizationSummary?.contains("en progression") == true)
    }

    @Test("All 15 path lesson nodes across certifications resolve official vector service assets in Prism.xcassets, progressive 3-slide micro-lessons vs Express Quiz, freeform AI chat, and persistent local database")
    func officialServiceLogosThreeSlideLessonsFreeformAIChatAndLocalDatabasePersistence() throws {
        var root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: root.appendingPathComponent("AGENTS.md").path) {
            let parent = root.deletingLastPathComponent()
            guard parent != root else { throw CocoaError(.fileNoSuchFile) }
            root = parent
        }
        let prismAssets = root.appendingPathComponent("apps/apple/CertigoKit/Sources/Prism/Resources/Prism.xcassets")

        // 1. Verify all 15 steps across every certification have valid official service vector assets in Prism.xcassets
        let certifications = ["AZ-104", "AZ-900", "AI-102", "SAA-C03", "CLF-C02", "AIF-C01", "PDE", "PCA", "ACE", "CKA", "CCNA", "TF-003", "GH-300", "CCA-F"]
        for code in certifications {
            let units = CertiGoNativeRichCatalog.buildThreeUnits(forRouteCode: code)
            let lessons = units.flatMap(\.lessons)
            #expect(lessons.count == 15)
            for lesson in lessons {
                #expect(!lesson.serviceAssetName.isEmpty)
                let assetDir = prismAssets.appendingPathComponent("\(lesson.serviceAssetName).imageset")
                #expect(
                    FileManager.default.fileExists(atPath: assetDir.path),
                    "Missing service imageset \(lesson.serviceAssetName) for \(lesson.id)"
                )
            }
            // Verify step 0..2 are progressive lessons (isQuizOnlyChapter == false) and step 4 is Express Quiz (isQuizOnlyChapter == true)
            #expect(lessons[0].isQuizOnlyChapter == false)
            #expect(lessons[1].isQuizOnlyChapter == false)
            #expect(lessons[2].isQuizOnlyChapter == false)
            #expect(lessons[3].isQuizOnlyChapter == true)
            #expect(lessons[4].isQuizOnlyChapter == true)
            #expect(lessons[4].chapterFormatBadgeText.contains("Quiz Express"))
        }

        // 2. Verify progressive 3-slide micro-lesson navigation (1/3 -> 2/3 -> 3/3 -> questions) vs Express Quiz starting directly on questions
        var appState = CertiGoNativeAppState()
        appState.startLessonSession(forLessonId: "AZ-104-u1-s1")
        #expect(appState.lessonSession.isShowingDeclicCard15 == true)
        #expect(appState.lessonSession.lessonSlides.count == 3)
        #expect(appState.lessonSession.lessonSlideIndex == 0)

        appState.lessonSession.advanceLessonSlideOrStartExercises()
        #expect(appState.lessonSession.lessonSlideIndex == 1)
        #expect(appState.lessonSession.isShowingDeclicCard15 == true)

        appState.lessonSession.previousLessonSlide()
        #expect(appState.lessonSession.lessonSlideIndex == 0)

        appState.lessonSession.advanceLessonSlideOrStartExercises()
        appState.lessonSession.advanceLessonSlideOrStartExercises()
        #expect(appState.lessonSession.lessonSlideIndex == 2)
        #expect(appState.lessonSession.isShowingDeclicCard15 == true)

        appState.lessonSession.advanceLessonSlideOrStartExercises()
        #expect(appState.lessonSession.isShowingDeclicCard15 == false)

        // Starting an Express Quiz chapter (stepIndexInUnit == 4) skips slides automatically
        appState.startLessonSession(forLessonId: "AZ-104-u1-s5")
        #expect(appState.lessonSession.isShowingDeclicCard15 == false)

        // 3. Freeform CertiGo AI chat answers general questions (e.g. Paris weather) and updates naturalReplyText
        let context = appState.buildPersonalLearnerContext()
        let weatherFallback = CertiGoLiveAITutorService.composeSmartFreeformFallback(
            context: context,
            message: "Quel temps fait-il à Paris aujourd'hui ?"
        )
        #expect(weatherFallback.reply.contains("Paris"))
        #expect(!weatherFallback.suggestions.isEmpty)

        appState.sendAIMessage("Quel temps fait-il à Paris ?")
        let weatherTurnId = appState.chatTurns.last!.id
        appState.applyFreeformAIChatResponse(
            reply: weatherFallback.reply,
            suggestions: weatherFallback.suggestions,
            toTurnWithId: weatherTurnId
        )
        #expect(appState.chatTurns.last?.isStreamingOrLoading == false)
        #expect(appState.chatTurns.last?.naturalReplyText.contains("Paris") == true)
        #expect(appState.chatTurns.last?.followUpSuggestions == weatherFallback.suggestions)

        // 4. Persistent Local Database (CertiGoLocalDatabaseStore) saves & restores user progress and completed lessons
        let tempFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("certigo-test-db-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempFileURL) }
        let customStore = CertiGoLocalDatabaseStore(fileURL: tempFileURL)
        customStore.clear()

        appState.userDisplayName = "Gabriel Chambaud"
        appState.userHandle = "@gabriel"
        appState.isProMember = true
        appState.streakDays = 7
        appState.gemsCount = 240
        appState.userXPPoints = 450
        appState.completedStepsTotal = 2
        appState.startLessonSession(forLessonId: "AZ-104-u1-s1", skipDeclic15: true)
        appState.completeActiveLessonSessionAndUnlockNextNode()
        appState.saveToLocalDatabase(store: customStore)

        let restoredState = CertiGoNativeAppState(restoreFromDisk: true, databaseStore: customStore)
        #expect(restoredState.userDisplayName == "Gabriel Chambaud")
        #expect(restoredState.userHandle == "@gabriel")
        #expect(restoredState.isProMember == true)
        #expect(restoredState.streakDays == 7)
        #expect(restoredState.gemsCount == 255)
        #expect(restoredState.routeCompletedLessonsCount(forRouteCode: "AZ-104") == 1)
        #expect(restoredState.currentUnits[0].lessons[0].state == .completed)
        #expect(restoredState.currentUnits[0].lessons[1].state == .active)

        // Resetting clears the persisted database and re-opens OB_01
        var mutableRestored = restoredState
        mutableRestored.resetToFreshNewUser(store: customStore)
        #expect(customStore.load() == nil)
        #expect(mutableRestored.streakDays == 0)
        #expect(mutableRestored.gemsCount == 0)
        #expect(mutableRestored.isPresentingOnboardingFlow == true)
    }

    @Test("Onboarding v3 starts with zero pre-selected certifications, places Auth at step 1/7 before questionnaire, and filters certifications by vendor, category, and difficulty rank")
    func onboardingAuthFirstZeroPreselectedCertsAndCatalogFiltering() {
        #expect(CertiGoNativeAppState.onboardingCompletedDefaultsKey == "certigo.native.hasCompletedOnboarding.v3")

        var appState = CertiGoNativeAppState()
        #expect(appState.onboardingSelectedCertifications.isEmpty)
        #expect(appState.trackedCertificationCodes.isEmpty)
        #expect(appState.onboardingVendorFilter == "all")
        #expect(appState.onboardingCategoryFilter == "all")

        // Step 0 (OB_01) -> Step 1 (Goals) -> interactive auth completes onboarding directly onto Parcours
        appState.startOnboardingFlow()
        #expect(appState.onboardingStepIndex == 0)
        appState.advanceOnboardingStep()
        #expect(appState.onboardingStepIndex == 1)

        appState.openInteractiveAuthSheet(for: .microsoft, fromExistingAccountButton: false)
        #expect(appState.activeAuthProviderSheet == .microsoft)
        appState.applyAuthenticatedSession(
            displayName: "Gabriel Chambaud",
            email: "gabriel.chambaud@microsoft.com",
            provider: .microsoft,
            accessToken: "jwt.test.token",
            userId: "usr-gabriel-ms"
        )
        #expect(appState.isAccountConnected == true)
        #expect(appState.connectedAuthProvider == "Microsoft Entra ID")
        #expect(appState.activeAuthProviderSheet == nil)
        #expect(appState.hasCompletedOnboarding == true)
        #expect(appState.isPresentingOnboardingFlow == false)

        // Verify CertiGoTrackThemePalette returns distinct dominant themes per track
        #expect(CertiGoTrackThemePalette.palette(forRouteCode: "HARVEY-LEGAL").primaryHex == "#18181b")
        #expect(CertiGoTrackThemePalette.palette(forRouteCode: "OPENAI-PRO").primaryHex == "#10a37f")
        #expect(CertiGoTrackThemePalette.palette(forRouteCode: "ANTHROPIC-CLAUDE").primaryHex == "#d97757")
        #expect(CertiGoTrackThemePalette.palette(forRouteCode: "MS-365-COPILOT").primaryHex == "#4f46e5")
        #expect(CertiGoTrackThemePalette.palette(forRouteCode: "SAA-C03").primaryHex == "#ea580c")
        #expect(CertiGoTrackThemePalette.palette(forRouteCode: "GH-300").primaryHex == "#24292f")
        #expect(CertiGoTrackThemePalette.palette(forRouteCode: "CKA").primaryHex == "#2563eb")
        #expect(CertiGoTrackThemePalette.palette(forRouteCode: "ACE").primaryHex == "#1a73e8")
        #expect(CertiGoTrackThemePalette.palette(forRouteCode: "AZ-104").primaryHex == "#0078d4")

        // Row 1 vendor tabs start with 'Tout' ("all") on the far left
        #expect(CertiGoNativeAppState.onboardingVendorFilterTabs.first?.id == "all")
        #expect(CertiGoNativeAppState.onboardingVendorFilterTabs.first?.name == "Tout")
        #expect(CertiGoNativeAppState.onboardingCategoryFilterTabs.map(\.id) == ["all", "cloud", "security", "data", "ai", "infra"])

        // Filter by Microsoft -> only Microsoft certifications, sorted by difficulty (AZ-900 before AZ-104 before AZ-305)
        appState.onboardingVendorFilter = "microsoft"
        appState.onboardingCategoryFilter = "all"
        let msItems = appState.filteredOnboardingCatalogItems
        #expect(!msItems.isEmpty)
        #expect(msItems.allSatisfy { $0.vendorId == "microsoft" })
        let az900Idx = msItems.firstIndex(where: { $0.code == "AZ-900" })
        let az104Idx = msItems.firstIndex(where: { $0.code == "AZ-104" })
        let az305Idx = msItems.firstIndex(where: { $0.code == "AZ-305" })
        #expect(az900Idx != nil && az104Idx != nil && az305Idx != nil)
        if let i1 = az900Idx, let i2 = az104Idx, let i3 = az305Idx {
            #expect(i1 < i2)
            #expect(i2 < i3)
        }

        // Combine Microsoft + Cloud -> AZ-900, AZ-104, AZ-305
        appState.onboardingCategoryFilter = "cloud"
        let msCloudCodes = appState.filteredOnboardingCatalogItems.map(\.code)
        #expect(msCloudCodes == ["AZ-900", "AZ-104", "AZ-305"])

        // Combine Microsoft + IA -> AI-900, AI-102
        appState.onboardingCategoryFilter = "ai"
        let msAICodes = appState.filteredOnboardingCatalogItems.map(\.code)
        #expect(msAICodes == ["AI-900", "AI-102"])

        // Filter by AWS, Google, GitHub, Kubernetes, Cisco
        appState.onboardingCategoryFilter = "all"
        for vendor in ["aws", "google", "github", "kubernetes", "cisco"] {
            appState.onboardingVendorFilter = vendor
            let items = appState.filteredOnboardingCatalogItems
            #expect(!items.isEmpty)
            #expect(items.allSatisfy { $0.vendorId == vendor })
        }

        // Filter by each category across all vendors
        appState.onboardingVendorFilter = "all"
        for category in ["cloud", "security", "data", "ai", "infra"] {
            appState.onboardingCategoryFilter = category
            let items = appState.filteredOnboardingCatalogItems
            #expect(!items.isEmpty)
            #expect(items.allSatisfy { $0.categoryId == category })
        }
    }

    @Test("Coach IA sanitizeAIMarkdown strips all #, ###, **, ****, backticks and aiDrawer06D supports individual and full thread deletion with persistence")
    func coachIASanitizeMarkdownAndThreadDeletion() {
        let rawMarkdown = """
        ### Architecture Zero-Trust Azure
        #### 1. Points critiques
        ****Attention**** : un verrou **CanNotDelete** bloque même un ***Owner*** sur `Microsoft.KeyVault/vaults`.
        - Activer Private Endpoint
        * Lier la zone DNS privée
        """
        let sanitized = CertiGoNativeAppState.sanitizeAIMarkdown(rawMarkdown)
        #expect(!sanitized.contains("#"))
        #expect(!sanitized.contains("**"))
        #expect(!sanitized.contains("****"))
        #expect(!sanitized.contains("`"))
        #expect(sanitized.contains("Architecture Zero-Trust Azure"))
        #expect(sanitized.contains("Attention : un verrou CanNotDelete bloque même un Owner sur Microsoft.KeyVault/vaults."))
        #expect(sanitized.contains("• Activer Private Endpoint"))
        #expect(sanitized.contains("• Lier la zone DNS privée"))

        let tempFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("certigo-test-threads-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempFileURL) }
        let customStore = CertiGoLocalDatabaseStore(fileURL: tempFileURL)
        customStore.clear()

        var appState = CertiGoNativeAppState(restoreFromDisk: false, databaseStore: customStore)
        appState.sendAIMessage("Première discussion sur RBAC")
        appState.sendAIMessage("Deuxième discussion sur Private Endpoint")
        #expect(appState.aiThreads.count == 2)

        let firstThreadId = appState.aiThreads[0].id
        appState.deleteAIThread(id: firstThreadId)
        #expect(appState.aiThreads.count == 1)
        #expect(!appState.aiThreads.contains(where: { $0.id == firstThreadId }))

        appState.clearAllAIThreads()
        #expect(appState.aiThreads.isEmpty)
        #expect(appState.chatTurns.isEmpty)

        // Verify phone contacts sync never injects fake fallback contacts when address book is empty/unauthorised
        appState.syncPhoneContacts()
        #expect(appState.hasSyncedPhoneContacts == true)
        #expect(appState.phoneContactsMatchedOnApp.isEmpty)
        appState.phoneContactsMatchedOnApp = [
            CertiGoPhoneContactItem(
                id: "cn-real-1",
                fullName: "Maxime Laurent",
                initials: "ML",
                phoneOrHandle: "@maxime_cloud",
                activeRouteCode: "AZ-104",
                isOnCertiGo: true
            )
        ]
        appState.addMatchedPhoneContact("cn-real-1")
        #expect(appState.phoneContactsMatchedOnApp[0].isAddedOrInvited == true)
        #expect(appState.friends.count == 1)
        #expect(appState.friends[0].streakDays == 0)
    }

    @Test("CertiGoNativeSystemOAuthCoordinator builds live CIAM OAuth 2.0 + PKCE URLs with exact domain_hint (apple, Google, live.com), decodes JWT claims, and opens email auth sheet")
    func systemOAuthCoordinatorAuthorizeURLsJWTDecodingAndEmailSheet() throws {
        let verifier = CertiGoNativeSystemOAuthCoordinator.generateCodeVerifier()
        #expect(verifier.count >= 43 && verifier.count <= 64)
        let challenge = CertiGoNativeSystemOAuthCoordinator.generateCodeChallenge(for: verifier)
        #expect(!challenge.isEmpty)
        #expect(!challenge.contains("="))

        // RFC 7636 Appendix B test vector for S256
        let rfcVerifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        let rfcChallenge = CertiGoNativeSystemOAuthCoordinator.generateCodeChallenge(for: rfcVerifier)
        #expect(rfcChallenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")

        // 1. Apple OAuth 2.0 + PKCE URL (`domain_hint=apple`)
        let appleURL = try #require(
            CertiGoNativeSystemOAuthCoordinator.buildAuthorizeURL(for: .apple, codeChallenge: challenge)
        )
        #expect(appleURL.absoluteString.contains("certigoapp.ciamlogin.com"))
        #expect(appleURL.absoluteString.contains("domain_hint=apple"))
        #expect(appleURL.absoluteString.contains("code_challenge_method=S256"))
        #expect(appleURL.absoluteString.contains("prompt=login"))

        // 2. Google OAuth 2.0 + PKCE URL (`domain_hint=Google` with uppercase G)
        let googleURL = try #require(
            CertiGoNativeSystemOAuthCoordinator.buildAuthorizeURL(for: .google, codeChallenge: challenge)
        )
        #expect(googleURL.absoluteString.contains("certigoapp.ciamlogin.com"))
        #expect(googleURL.absoluteString.contains("domain_hint=Google"))

        // 3. Microsoft OAuth 2.0 + PKCE URL (`domain_hint=live.com`)
        let microsoftURL = try #require(
            CertiGoNativeSystemOAuthCoordinator.buildAuthorizeURL(for: .microsoft, codeChallenge: challenge)
        )
        #expect(microsoftURL.absoluteString.contains("certigoapp.ciamlogin.com"))
        #expect(microsoftURL.absoluteString.contains("domain_hint=live.com"))

        // 4. JWT claims decoding (`name`, `email`, `oid` / `sub`)
        let headerJSON = #"{"alg":"RS256","typ":"JWT"}"#
        let payloadJSON = #"{"name":"Gabriel Chambaud","email":"gabriel.chambaud@gmail.com","oid":"oid-789-gabriel","sub":"sub-123-gabriel"}"#
        let encodeSegment: (String) -> String = { raw in
            Data(raw.utf8).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        let sampleJWT = "\(encodeSegment(headerJSON)).\(encodeSegment(payloadJSON)).sig"
        let claims = CertiGoNativeSystemOAuthCoordinator.decodeJWTClaims(sampleJWT)
        #expect(claims.name == "Gabriel Chambaud")
        #expect(claims.displayName == "Gabriel Chambaud")
        #expect(claims.email == "gabriel.chambaud@gmail.com")
        #expect(claims.oid == "oid-789-gabriel")
        #expect(claims.sub == "sub-123-gabriel")
        #expect(claims.userId == "oid-789-gabriel")
        #expect(claims["name"] == "Gabriel Chambaud")
        #expect(claims["email"] == "gabriel.chambaud@gmail.com")
        #expect(claims["oid"] == "oid-789-gabriel")
        #expect(claims["sub"] == "sub-123-gabriel")

        // 5. `openInteractiveAuthSheet(for: .email)` opens the sheet for `.email`
        var appState = CertiGoNativeAppState()
        appState.openInteractiveAuthSheet(for: .email)
        #expect(appState.activeAuthProviderSheet == .email)
    }

    @Test("Chapter 1 (u1-s1) Global Overview, Beginner mode adaptation (no CLI wall + auto plain language), and iOS On/Off Plain-Language Switch across exercises and exams")
    func chapter1GlobalOverviewBeginnerModeAndPlainLanguageToggle() {
        // 1. Verify togglePlainLanguageMode() on CertiGoNativeLessonSessionEngine and CertiGoNativeAppState
        var engine = CertiGoNativeLessonSessionEngine(routeCode: "AZ-104", lessonId: "AZ-104-u1-s1")
        #expect(engine.isPlainLanguageModeEnabled == false)
        engine.togglePlainLanguageMode()
        #expect(engine.isPlainLanguageModeEnabled == true)
        engine.togglePlainLanguageMode()
        #expect(engine.isPlainLanguageModeEnabled == false)

        // 2. Verify all exercises across tracks have non-empty plainLanguagePrompt != prompt, plainLanguageTitle on options, and non-empty jargonGlossaryBridge
        let routesAndLessons: [(String, String)] = [
            ("AZ-104", "AZ-104-u1-s1"), ("AZ-104", "AZ-104-u1-s2"), ("AZ-104", "AZ-104-u2-s1"), ("AZ-104", "AZ-104-u3-s1"),
            ("AZ-900", "AZ-900-u1-s1"), ("AZ-900", "AZ-900-u1-s2"),
            ("SAA-C03", "SAA-C03-u1-s1"), ("SAA-C03", "SAA-C03-u2-s1"),
            ("PDE", "PDE-u1-s1"), ("PDE", "PDE-u1-s2"),
            ("AI-102", "AI-102-u1-s1"), ("CKA", "CKA-u1-s1"), ("GH-300", "GH-300-u1-s1")
        ]
        for (route, lessonId) in routesAndLessons {
            let exercises = CertiGoNativeLessonSessionEngine.defaultExercises(forRouteCode: route, lessonId: lessonId)
            #expect(!exercises.isEmpty)
            for ex in exercises {
                #expect(!ex.plainLanguagePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Empty plainLanguagePrompt in \(ex.id)")
                #expect(ex.plainLanguagePrompt != ex.prompt, "Expected distinct plainLanguagePrompt in \(ex.id)")
                #expect(!ex.jargonGlossaryBridge.isEmpty, "Expected non-empty jargonGlossaryBridge in \(ex.id)")
                for bridgeItem in ex.jargonGlossaryBridge {
                    #expect(!bridgeItem.term.isEmpty)
                    #expect(!bridgeItem.simpleMeaning.isEmpty)
                }
                for opt in ex.options {
                    #expect(!opt.plainLanguageTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Empty plainLanguageTitle in \(ex.id) \(opt.id)")
                }
            }
        }

        // 3. Verify mock exam questions also provide plainLanguageStem, plainLanguageText on each choice, and jargonGlossaryBridge
        for route in ["AZ-104", "AZ-900", "SAA-C03", "PDE", "AI-102", "CKA", "GH-300"] {
            let examQuestions = CertiGoNativeRichCatalog.buildExamQuestions(forRouteCode: route)
            for q in examQuestions {
                #expect(!q.plainLanguageStem.isEmpty)
                #expect(q.plainLanguageStem != q.stem)
                #expect(!q.jargonGlossaryBridge.isEmpty)
                for choice in q.choices {
                    #expect(!choice.plainLanguageText.isEmpty)
                }
            }
        }

        // 4. Verify Beginner mode (onboardingExperienceLevelIndex == 0) starts Chapter 1 (u1-s1) with Global Overview slides, plain-language mode enabled, and no raw CLI exercises
        var appState = CertiGoNativeAppState()
        appState.onboardingExperienceLevelIndex = 0 // Débutant
        appState.selectRoute("AZ-104")
        appState.startLessonSession(forLessonId: "AZ-104-u1-s1")

        #expect(appState.lessonSession.isPlainLanguageModeEnabled == true)
        #expect(appState.isPlainLanguageModeEnabled == true)
        #expect(appState.lessonSession.lessonSlides.count == 3)
        #expect(appState.lessonSession.lessonSlides[0].stepBadge.contains("VUE D'ENSEMBLE"))
        #expect(appState.lessonSession.lessonSlides[1].stepBadge.contains("LA GRANDE IMAGE"))
        #expect(appState.lessonSession.lessonSlides[2].stepBadge.contains("MOTS-CLÉS"))
        #expect(appState.lessonSession.exercises.allSatisfy { $0.formatCode != "Q_TYPE_04" && $0.formatCode != "Q_TYPE_05" })

        // User can toggle between Plain Language and Exam Style at any time
        appState.togglePlainLanguageMode()
        #expect(appState.lessonSession.isPlainLanguageModeEnabled == false)
        #expect(appState.isPlainLanguageModeEnabled == false)
        appState.togglePlainLanguageMode()
        #expect(appState.lessonSession.isPlainLanguageModeEnabled == true)
        #expect(appState.isPlainLanguageModeEnabled == true)

        // 5. Verify Social defaults to Mes Amis (selectedSocialSubTab == 1) and Cooperative Friends Quest has 0 fake partner when friends.isEmpty
        let freshSocialState = CertiGoNativeAppState()
        #expect(freshSocialState.selectedSocialSubTab == 1)
        #expect(freshSocialState.hasClappedQuestPartner == false)
        var mutableSocial = freshSocialState
        mutableSocial.clapQuestPartnerSarah()
        #expect(mutableSocial.showAddFriendSheet == true)
        #expect(mutableSocial.hasClappedQuestPartner == false)
        #expect(mutableSocial.gemsCount == 0)

        mutableSocial.friendSearchQuery = "@alex"
        mutableSocial.addNewFriendFromSearch()
        mutableSocial.clapQuestPartnerSarah()
        #expect(mutableSocial.hasClappedQuestPartner == true)
        #expect(mutableSocial.lastAddedFriendConfirmation == "✓ Encouragement envoyé à Alex !")
        #expect(mutableSocial.gemsCount == 0)

        // 6. Verify Recommendations 1, 3 (PRO-only), 4, 5, 6, and 7:
        // Rec 1: Implementation Intention ("Plan Si – Alors") with 4 routine anchors
        #expect(CertiGoNativeAppState.onboardingRoutineAnchors.count == 4)
        var recState = CertiGoNativeAppState()
        recState.onboardingRoutineAnchorIndex = 0
        recState.onboardingDailyRhythmMinutes = 10
        #expect(recState.onboardingIfThenCommitmentText == "Si je suis après mon café du matin, alors je fais ma session de 10 min sur CertiGo.")
        recState.onboardingRoutineAnchorIndex = 3
        recState.onboardingDailyRhythmMinutes = 20
        #expect(recState.onboardingIfThenCommitmentText == "Si je suis le soir au calme, alors je fais ma session de 20 min sur CertiGo.")

        // Rec 3: PRO-only Shield repair (rejected for free users, restores hearts & preserves lesson index for PRO members)
        recState.isProMember = false
        recState.startLessonSession(forLessonId: "AZ-104-u1-s1", skipDeclic15: true)
        recState.lessonSession.currentExerciseIndex = 2
        recState.lessonSession.heartsCount = 0
        recState.lessonSession.hasTriggeredOutOfHeartsFailure = true
        #expect(recState.repairHeartsWithProShieldAndContinue() == false)
        #expect(recState.lessonSession.heartsCount == 0)

        recState.isProMember = true
        #expect(recState.repairHeartsWithProShieldAndContinue() == true)
        #expect(recState.lessonSession.heartsCount == 5)
        #expect(recState.lessonSession.hasTriggeredOutOfHeartsFailure == false)
        #expect(recState.lessonSession.currentExerciseIndex == 2)

        // Rec 4: 4-tier cognitive scaffolding & interleaved confusable pair card
        #expect(CertiGoScaffoldingTier.allCases.count == 4)
        #expect(CertiGoScaffoldingTier.tier(forMastery: 0.30, difficulty: 0.35) == .tier1Intuition)
        #expect(CertiGoScaffoldingTier.tier(forMastery: 0.50, difficulty: 0.50) == .tier2Association)
        #expect(CertiGoScaffoldingTier.tier(forMastery: 0.68, difficulty: 0.65) == .tier3Scenario)
        #expect(CertiGoScaffoldingTier.tier(forMastery: 0.85, difficulty: 0.82) == .tier4ExamAndCLI)
        let duelAZ = CertiGoAdaptiveSessionEngine.buildInterleavedConfusablePairCard(forRouteCode: "AZ-104")
        #expect(duelAZ.title.contains("RBAC"))
        #expect(!duelAZ.exercise.options.isEmpty)

        // Rec 5 & 6: Kind comeback (+20 XP) & attainable weekly benchmark
        #expect(CertiGoNativeAppState.certifiedCandidatesWeeklyBenchmarkText.contains("4 sessions de 10 min par semaine"))
        let xpBefore = recState.userXPPoints
        recState.triggerKindComebackSession()
        #expect(recState.hasClaimedKindComebackBonus == true)
        #expect(recState.userXPPoints == xpBefore + 20)
        #expect(recState.streakDays >= 1)

        // Rec 7: Session Challenge Mode Selector (0 = Découverte simple sans CLI, 1 = Défi Examen + CLI)
        recState.selectedSessionChallengeMode = 0
        recState.startLessonSession(forLessonId: "AZ-104-u1-s1", skipDeclic15: true)
        #expect(recState.lessonSession.isPlainLanguageModeEnabled == true)
        #expect(recState.lessonSession.exercises.allSatisfy { $0.formatCode != "Q_TYPE_04" && $0.formatCode != "Q_TYPE_05" })

        recState.selectedSessionChallengeMode = 1
        recState.startLessonSession(forLessonId: "AZ-104-u1-s1", skipDeclic15: true)
        #expect(recState.lessonSession.isPlainLanguageModeEnabled == false)
        #expect(recState.lessonSession.exercises.contains(where: { $0.formatCode == "Q_TYPE_04" }))
    }

    @Test("CertiGoMascotVault vector anatomy invariants, 8 contextual outfits, Light #07.1 / Dark #07.2 / Prestige #07.10 themes, and CertiGoDynamicAppIconManager")
    @MainActor
    func mascotVaultVectorAnatomyEightContextualOutfitsAndDynamicAppIconManager() async throws {
        // 1. Verify all 8 contextual outfits and their vector anatomy invariants
        let expectedRawValues = [
            "happy_active",
            "sad_missing",
            "morning_pajama",
            "coffee_boost",
            "suit_boss",
            "airplane_offline",
            "streak_fire",
            "prestige_pro"
        ]
        #expect(CertiGoMascotVault.allOutfits.map(\.rawValue) == expectedRawValues)
        #expect(CertiGoMascotVault.allThemes.map(\.codeLabel) == ["#07.1", "#07.2", "#07.10"])

        for outfit in CertiGoMascotVault.allOutfits {
            let spec = CertiGoMascotVault.geometrySpec(for: outfit)
            #expect(spec.outfit == outfit)
            // Eyebrows cleanly above the eyes (never overlapping eyes)
            #expect(spec.eyebrowBottomY < spec.eyeTopY)
            #expect(spec.eyebrowClearanceAboveEye >= 0.05)
            // Centered chest emblem / outfit with clear margin inside the shield contour (no legacy V-bar touching border)
            #expect(spec.hasLegacyVBarTouchingShieldBorder == false)
            #expect(spec.chestPlastronMaxRadiusRatio <= 0.64)
            #expect(spec.chestPlastronMarginToShieldBorder >= 0.20)
            // 100% symmetric orange feet
            #expect(spec.areFeetSymmetric == true)
            #expect(abs((spec.leftFootCenterX + spec.rightFootCenterX) - 1.0) < 0.0001)
            // Clean eyes with single specular highlight and no star overlap
            #expect(spec.hasOverlappingStarAndHighlight == false)
            #expect(spec.specularHighlightCountPerEye == 1)
            // Well-proportioned centered golden beak
            #expect(spec.beakCenterX == 0.50)
            #expect(spec.beakWidthRatio > 0.10)
        }

        // 2. Verify automatic contextual evaluation across all 8 states
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let afternoonDate = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 15, minute: 0))!
        let morningDate = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 7, minute: 30))!
        let coffeeDate = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 10, minute: 15))!

        // Default Happy Active (#07.1 Light & #07.2 Dark)
        let activeCtx = CertiGoMascotContextInput(
            lastActiveDate: afternoonDate.addingTimeInterval(-3600),
            now: afternoonDate,
            hasCompletedFirstSessionToday: true
        )
        #expect(CertiGoMascotContextEvaluator.recommendedOutfit(for: activeCtx, calendar: calendar) == .happyActive)
        #expect(CertiGoMascotContextEvaluator.resolvedTheme(for: .happyActive, context: activeCtx) == .light)

        var darkCtx = activeCtx
        darkCtx.isDarkSystemAppearance = true
        #expect(CertiGoMascotContextEvaluator.resolvedTheme(for: .happyActive, context: darkCtx) == .dark)

        // Sad Missing (> 48h inactivity)
        let sadCtx = CertiGoMascotContextInput(
            lastActiveDate: afternoonDate.addingTimeInterval(-49 * 3600),
            now: afternoonDate
        )
        #expect(CertiGoMascotContextEvaluator.recommendedOutfit(for: sadCtx, calendar: calendar) == .sadMissing)

        // Morning Pajama + Nightcap + Coffee (06:00..09:30 before first session)
        let morningCtx = CertiGoMascotContextInput(
            lastActiveDate: morningDate.addingTimeInterval(-10 * 3600),
            now: morningDate,
            hasCompletedFirstSessionToday: false
        )
        #expect(CertiGoMascotContextEvaluator.recommendedOutfit(for: morningCtx, calendar: calendar) == .morningPajama)

        // Coffee Boost (09:30..14:00 or quick sprint)
        let coffeeCtx = CertiGoMascotContextInput(
            lastActiveDate: coffeeDate.addingTimeInterval(-4 * 3600),
            now: coffeeDate,
            hasCompletedFirstSessionToday: false
        )
        #expect(CertiGoMascotContextEvaluator.recommendedOutfit(for: coffeeCtx, calendar: calendar) == .coffeeBoost)

        // Suit Boss (Exam Prep mode)
        let examCtx = CertiGoMascotContextInput(
            lastActiveDate: afternoonDate.addingTimeInterval(-1800),
            now: afternoonDate,
            isExamPrepMode: true
        )
        #expect(CertiGoMascotContextEvaluator.recommendedOutfit(for: examCtx, calendar: calendar) == .suitBoss)

        // Airplane Offline (NWPathMonitor offline detection)
        let airplaneCtx = CertiGoMascotContextInput(
            isOfflineOrAirplaneMode: true,
            lastActiveDate: afternoonDate.addingTimeInterval(-1800),
            now: afternoonDate
        )
        #expect(CertiGoMascotContextEvaluator.recommendedOutfit(for: airplaneCtx, calendar: calendar) == .airplaneOffline)

        // Streak Fire (streak >= 3 days)
        let streakCtx = CertiGoMascotContextInput(
            lastActiveDate: afternoonDate.addingTimeInterval(-1800),
            now: afternoonDate,
            hasCompletedFirstSessionToday: true,
            streakDays: 5
        )
        #expect(CertiGoMascotContextEvaluator.recommendedOutfit(for: streakCtx, calendar: calendar) == .streakFire)

        // Prestige PRO (#07.10 Gold & Black)
        let proCtx = CertiGoMascotContextInput(
            lastActiveDate: afternoonDate.addingTimeInterval(-1800),
            now: afternoonDate,
            hasCompletedFirstSessionToday: true,
            streakDays: 1,
            isProMember: true
        )
        #expect(CertiGoMascotContextEvaluator.recommendedOutfit(for: proCtx, calendar: calendar) == .prestigePro)
        #expect(CertiGoMascotContextEvaluator.resolvedTheme(for: .prestigePro, context: proCtx) == .prestigeGoldBlack)

        // 3. Verify CertiGoDynamicAppIconManager with mock alternate icon driver & CertiGoNativeAppState integration
        @MainActor
        final class MockIconDriver: CertiGoAlternateIconDriver {
            var supportsAlternateIcons: Bool = true
            var currentAlternateIconName: String? = nil
            var appliedNames: [String?] = []

            func setAlternateIconName(_ name: String?) async throws {
                currentAlternateIconName = name
                appliedNames.append(name)
            }
        }

        let suiteName = "CertiGoMascotVaultTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let driver = MockIconDriver()
        let manager = CertiGoDynamicAppIconManager(
            defaults: defaults,
            preferencesKey: "mascot-vault-test-prefs",
            driver: driver,
            initialContext: activeCtx
        )

        let resolved = await manager.evaluateAndApply(context: airplaneCtx, calendar: calendar)
        #expect(resolved == .airplaneOffline)
        #expect(driver.currentAlternateIconName == "CertiGoMascotAirplaneOffline")

        await manager.selectManualOutfit(.prestigePro)
        #expect(manager.activeOutfit == .prestigePro)
        #expect(manager.activeTheme == .prestigeGoldBlack)
        #expect(driver.currentAlternateIconName == "CertiGoMascotPrestigePro")

        // Verify CertiGoNativeAppState Mascot Vault sheet state
        var appState = CertiGoNativeAppState()
        appState.openMascotVaultSheet()
        #expect(appState.showMascotVaultSheet == true)
        appState.toggleMascotSimulationSignal("airplane")
        #expect(appState.effectiveMascotOutfit == .airplaneOffline)
        appState.selectMascotOutfit(.suitBoss)
        #expect(appState.effectiveMascotOutfit == .suitBoss)
        appState.selectMascotTheme(.dark)
        #expect(appState.effectiveMascotTheme == .dark)
    }

    @Test("All user-visible brand strings in CertigoNative and CertigoKit use CertiGo with an uppercase G and never Certigo with a lowercase g")
    func noUserFacingUIStringInCertigoNativeContainsLowercaseGCertigo() throws {
        var root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: root.appendingPathComponent("AGENTS.md").path) {
            let parent = root.deletingLastPathComponent()
            guard parent != root else { throw CocoaError(.fileNoSuchFile) }
            root = parent
        }

        // 1. Verify CFBundleDisplayName in Info.plist files and project.pbxproj
        let distPlist = try String(
            contentsOf: root.appendingPathComponent("apps/apple/CertigoNative/DistributionInfo.plist"),
            encoding: .utf8
        )
        let devPlist = try String(
            contentsOf: root.appendingPathComponent("apps/apple/CertigoNative/DevelopmentInfo.plist"),
            encoding: .utf8
        )
        let widgetPlist = try String(
            contentsOf: root.appendingPathComponent("apps/apple/CertigoNative/WidgetExtension/Info.plist"),
            encoding: .utf8
        )
        let pbxproj = try String(
            contentsOf: root.appendingPathComponent("apps/apple/CertigoNative/CertigoNative.xcodeproj/project.pbxproj"),
            encoding: .utf8
        )
        #expect(distPlist.contains("<string>CertiGo</string>"))
        #expect(!distPlist.contains("<string>Certigo</string>"))
        #expect(devPlist.contains("<string>CertiGo</string>"))
        #expect(widgetPlist.contains("<string>CertiGo Widgets</string>"))
        #expect(!widgetPlist.contains("<string>Certigo Widgets</string>"))
        #expect(pbxproj.contains("INFOPLIST_KEY_CFBundleDisplayName = CertiGo;"))
        #expect(!pbxproj.contains("INFOPLIST_KEY_CFBundleDisplayName = Certigo;"))
        #expect(!pbxproj.contains("INFOPLIST_KEY_CFBundleDisplayName = \"Certigo Dev\";"))

        // 2. Verify no user-facing string literal in CertigoNative/Sources, CertigoNative/WidgetExtension, or CertigoKit/Sources contains standalone "Certigo" (with lowercase g)
        let stringWithLowercaseG = try NSRegularExpression(
            pattern: #""[^"\n]*\bCertigo(?![A-Za-z0-9_])[^"\n]*""#
        )
        let allowedTechnicalFragments = [
            "X-Certigo-",
            "Certigo-Widgets"
        ]
        for relativeDir in ["apps/apple/CertigoNative/Sources", "apps/apple/CertigoNative/WidgetExtension", "apps/apple/CertigoKit/Sources"] {
            let dirURL = root.appendingPathComponent(relativeDir)
            let enumerator = try #require(
                FileManager.default.enumerator(at: dirURL, includingPropertiesForKeys: nil)
            )
            for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
                let source = try String(contentsOf: fileURL, encoding: .utf8)
                let range = NSRange(source.startIndex..., in: source)
                for match in stringWithLowercaseG.matches(in: source, range: range) {
                    guard let matchRange = Range(match.range, in: source) else { continue }
                    let literal = String(source[matchRange])
                    let isTechnical = allowedTechnicalFragments.contains { literal.contains($0) }
                    #expect(isTechnical, "Found lowercase-g 'Certigo' in user-facing string in \(fileURL.lastPathComponent): \(literal)")
                }
            }
        }
    }

    @Test("Design System v3 (Build 12): 8pt/4pt Grid, Concentric Radii, True iOS 26 Liquid Glass Droplet, Lowered Bottom Bar, Lifted UNITÉ 1 without Sprint Bar, 4-Size Typography, and Unified 56pt Tab Headers")
    func designSystemV3GridConcentricLiquidGlassParcoursAndBuild12() throws {
        // 1. Rule 1: Strict 8pt / 4pt grid tokens
        #expect(PrismSize.primaryButtonHeight == 52)
        #expect(Int(PrismSize.primaryButtonHeight) % 4 == 0)
        #expect(PrismSize.bottomBarHeight == 64)
        #expect(Int(PrismSize.bottomBarHeight) % 8 == 0)
        #expect(PrismSize.tabItemHeight == 52)
        #expect(Int(PrismSize.tabItemHeight) % 4 == 0)
        #expect(FigMetrics.bottomBarCompactHeight == 60)
        #expect(Int(FigMetrics.bottomBarCompactHeight) % 4 == 0)
        #expect(FigMetrics.bottomBarBottomOffset == 14)

        // 2. Rule 2: Apple HIG Concentric Radii Law (R_interne = max(8, R_externe - padding))
        #expect(PrismRadius.bottomBar == 32)
        #expect(PrismRadius.concentric(outer: 32, padding: 6) == 26)
        #expect(PrismRadius.bottomBarDroplet == 26)
        #expect(PrismRadius.concentric(outer: 24, padding: 12) == 12)
        #expect(PrismRadius.unitBanner == 24)

        // 3. Rule 3: True iOS 26 Liquid Glass Water Droplet (`CertiGoTrueLiquidGlassDropletView`) + User Intensity Slider (0% .. 100%)
        let azTheme = CertiGoTrackThemePalette.palette(forRouteCode: "AZ-104")
        let restingDroplet = CertiGoTrueLiquidGlassDropletView(
            trackTheme: azTheme,
            width: 68,
            height: FigMetrics.fortyEight,
            isDragging: false
        )
        #expect(CertiGoTrueLiquidGlassDropletView.concentricCornerRadius == 26)
        #expect(CertiGoTrueLiquidGlassDropletView.centerRefractionWhiteOpacity == 0.88)
        #expect(CertiGoTrueLiquidGlassDropletView.middleSoftTintOpacity == 0.75)
        #expect(CertiGoTrueLiquidGlassDropletView.edgeTintOpacity == 0.22)
        #expect(CertiGoTrueLiquidGlassDropletView.topMeniscusWhiteOpacity == 0.98)
        #expect(CertiGoTrueLiquidGlassDropletView.topMeniscusFadeStop == 0.38)
        #expect(CertiGoTrueLiquidGlassDropletView.topMeniscusInset == 1.5)
        #expect(CertiGoTrueLiquidGlassDropletView.bottomCausticRingOpacity == 0.45)
        #expect(CertiGoTrueLiquidGlassDropletView.bottomCausticWhiteOpacity == 0.65)
        #expect(CertiGoTrueLiquidGlassDropletView.rimLightLineWidth == 1.6)
        #expect(CertiGoTrueLiquidGlassDropletView.meniscusOuterTintOpacity == 0.42)
        #expect(CertiGoTrueLiquidGlassDropletView.causticShadowTintOpacity == 0.28)
        #expect(restingDroplet.effectiveScaleX == 1.0)
        #expect(restingDroplet.effectiveScaleY == 1.0)

        let draggingDroplet = CertiGoTrueLiquidGlassDropletView(
            trackTheme: azTheme,
            width: 68,
            height: FigMetrics.fortyEight,
            isDragging: true
        )
        #expect(draggingDroplet.effectiveScaleX == 1.10)
        #expect(draggingDroplet.effectiveScaleY == 1.04)

        let halfDroplet = CertiGoTrueLiquidGlassDropletView(
            trackTheme: azTheme,
            width: 68,
            height: FigMetrics.fortyEight,
            isDragging: true,
            intensityPercent: 50
        )
        #expect(abs(halfDroplet.effectiveScaleX - 1.05) < 0.0001)
        #expect(abs(halfDroplet.effectiveScaleY - 1.02) < 0.0001)

        let zeroDroplet = CertiGoTrueLiquidGlassDropletView(
            trackTheme: azTheme,
            width: 68,
            height: FigMetrics.fortyEight,
            isDragging: true,
            intensityPercent: 0
        )
        #expect(zeroDroplet.effectiveScaleX == 1.0)
        #expect(zeroDroplet.effectiveScaleY == 1.0)

        // Verify settingsLiquidGlassIntensityPercent (0, 50, 75, 100) and v13 real data purge persistence
        let tempFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("certigo-test-v13-glass-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempFileURL) }
        let customStore = CertiGoLocalDatabaseStore(fileURL: tempFileURL)
        customStore.clear()

        var glassState = CertiGoNativeAppState(restoreFromDisk: false, databaseStore: customStore)
        #expect(CertiGoNativeAppState.defaultLiquidGlassIntensityPercent == 75)
        #expect(CertiGoNativeAppState.liquidGlassIntensityPresets == [0, 25, 50, 75, 100])
        glassState.setLiquidGlassIntensityPercent(0)
        #expect(glassState.settingsLiquidGlassIntensityPercent == 0)
        #expect(glassState.liquidGlassIntensityFraction == 0.0)
        glassState.setLiquidGlassIntensityPercent(50)
        #expect(glassState.settingsLiquidGlassIntensityPercent == 50)
        #expect(glassState.liquidGlassIntensityFraction == 0.5)
        glassState.setLiquidGlassIntensityPercent(100)
        #expect(glassState.settingsLiquidGlassIntensityPercent == 100)
        #expect(glassState.liquidGlassIntensityFraction == 1.0)
        glassState.saveToLocalDatabase(store: customStore)

        let restoredGlassState = CertiGoNativeAppState(restoreFromDisk: true, databaseStore: customStore)
        #expect(restoredGlassState.settingsLiquidGlassIntensityPercent == 100)

        // Verify v13 real_data_purge_done sanitizes legacy fake 50 gems when completedStepsTotal == 0
        let legacyFakeDB = CertiGoPersistedUserDatabase(
            streakDays: 3,
            gemsCount: 50,
            userXPPoints: 120,
            completedStepsTotal: 0,
            completedExamsCount: 0
        )
        let sanitizedDB = CertiGoLocalDatabaseStore.sanitizeRealDataOnly(legacyFakeDB)
        #expect(sanitizedDB.gemsCount == 0)
        #expect(sanitizedDB.userXPPoints == 0)
        #expect(sanitizedDB.streakDays == 0)
        #expect(CertiGoLocalDatabaseStore.realDataPurgeV13DefaultsKey == "certigo.v13.real_data_purge_done")

        // 4. Rule 4 & Rule 8: 4-size typographic scale (24 / 17 / 15 / 12 pt) & unified 56pt tab header
        #expect(FigMetrics.typeHeroTitle == 24)
        #expect(FigMetrics.typeCardTitle == 17)
        #expect(FigMetrics.typeBody == 15)
        #expect(FigMetrics.typeBadge == 12)
        #expect(FigMetrics.unifiedTabHeaderHeight == 56)

        // 5. Rule 7 & Build 13: Verify CertiGoOneTapSprintBarView and CertiGoTopProgressiveVignetteView are removed from parcoursTab01View, UNITÉ 1 starts at .padding(.top, FigMetrics.sixtyEight), and archive_testflight_mac.sh defaults to Build 13
        var root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: root.appendingPathComponent("AGENTS.md").path) {
            let parent = root.deletingLastPathComponent()
            guard parent != root else { throw CocoaError(.fileNoSuchFile) }
            root = parent
        }
        let figmaAppSource = try String(
            contentsOf: root.appendingPathComponent("apps/apple/CertigoKit/Sources/Prism/Screens/CertiGoNativeFigmaApp.swift"),
            encoding: .utf8
        )
        #expect(!figmaAppSource.contains("CertiGoOneTapSprintBarView("))
        #expect(!figmaAppSource.contains("CertiGoTopProgressiveVignetteView()"))
        #expect(figmaAppSource.contains("CertiGoTrueLiquidGlassDropletView("))
        #expect(figmaAppSource.contains(".padding(.top, FigMetrics.sixtyEight)"))
        #expect(figmaAppSource.contains(".offset(y: FigMetrics.bottomBarBottomOffset)"))
        #expect(figmaAppSource.contains("settings28-liquid-glass-slider"))

        let archiveScript = try String(
            contentsOf: root.appendingPathComponent("tools/archive_testflight_mac.sh"),
            encoding: .utf8
        )
        #expect(archiveScript.contains("build=${CERTIGO_DISTRIBUTION_BUILD:-13}"))
    }
}
