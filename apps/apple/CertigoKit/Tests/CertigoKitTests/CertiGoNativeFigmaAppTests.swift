import BrandAssets
import CertigoCortex
import CertigoData
import CertigoDomain
import Foundation
import Prism
import Testing

@Suite("PR #150 — Native Figma App Video Layout, Mimo Reset, 8-Step Onboarding & Parallel Tracks Deduplication")
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

    @Test("8-step native onboarding flow advances from step 0 to step 7, supports back navigation, and dismisses cleanly on completion or close")
    func onboardingEightStepNavigationAndDismissal() {
        var appState = CertiGoNativeAppState()
        #expect(CertiGoNativeAppState.onboardingStepCount == 8)

        appState.startOnboardingFlow()
        #expect(appState.isPresentingOnboardingFlow == true)
        #expect(appState.onboardingStepIndex == 0)

        for expectedNextStep in 1..<CertiGoNativeAppState.onboardingStepCount {
            appState.advanceOnboardingStep()
            #expect(appState.onboardingStepIndex == expectedNextStep)
            #expect(appState.isPresentingOnboardingFlow == true)
        }

        appState.goBackOnboardingStep()
        #expect(appState.onboardingStepIndex == 6)
        appState.advanceOnboardingStep()
        #expect(appState.onboardingStepIndex == 7)

        // Advancing from step 7 (8/8) completes and dismisses the onboarding flow
        appState.advanceOnboardingStep()
        #expect(appState.isPresentingOnboardingFlow == false)

        // Restarting and explicitly dismissing mid-flow resets presentation
        appState.startOnboardingFlow()
        appState.advanceOnboardingStep()
        #expect(appState.onboardingStepIndex == 1)
        appState.dismissOnboardingFlow()
        #expect(appState.isPresentingOnboardingFlow == false)
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

    @Test("addSuggestedFriend adds the suggested colleague to friends in real time and openFriendProfile populates CertiGoSocialProfilePreview")
    func socialAddSuggestedFriendAndOpenProfilePreview() {
        var appState = CertiGoNativeAppState()
        let initialFriendsCount = appState.friends.count
        #expect(appState.suggestedFriends.count == 5)
        #expect(appState.suggestedFriends[0].displayName == "Camille D.")
        #expect(appState.suggestedFriends[0].isAdded == false)

        appState.addSuggestedFriend("sf-1")
        #expect(appState.suggestedFriends[0].isAdded == true)
        #expect(appState.friends.count == initialFriendsCount + 1)
        #expect(appState.friends[0].displayName == "Camille D.")
        #expect(appState.friends[0].handle == "@camille_az")
        #expect(appState.lastAddedFriendConfirmation?.contains("Camille D.") == true)

        appState.openFriendProfile(for: appState.friends[0])
        #expect(appState.selectedFriendProfile != nil)
        #expect(appState.selectedFriendProfile?.displayName == "Camille D.")
        #expect(appState.selectedFriendProfile?.handle == "@camille_az")
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

        // Connect Microsoft Entra ID & complete onboarding -> awards +50 welcome gems
        appState.connectMicrosoftEntraAccount()
        #expect(appState.isAccountConnected == true)
        #expect(appState.connectedAuthProvider == "Microsoft Entra ID")
        appState.completeOnboardingFlow(awardWelcomeBonus: true)
        #expect(appState.hasCompletedOnboarding == true)
        #expect(appState.gemsCount == 50)

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
        #expect(meAtZeroXP?.rank == 12)
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
        #expect(appState.gemsCount == 50)
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

    @Test("Chantier 6: Social leaderboard sorts by XP with 0 XP at rank 12, Free vs Pro tier badge, GH-300 6 domains, exam provider metadata, and Domain Sprint returns to .examens")
    func socialLeaderboardSortingFreeVsProGH300DomainsAndDomainSprintRouting() {
        var appState = CertiGoNativeAppState()

        // 1. Leaderboard sorted by XP descending: Sarah L. (1390) is #1, Thomas M. (1260) is #2, Inès K. (1185) is #3, and Toi (0 XP) is #12
        #expect(appState.leaderboardMembers.count == 12)
        #expect(appState.leaderboardMembers[0].displayName == "Sarah L.")
        #expect(appState.leaderboardMembers[0].rank == 1)
        #expect(appState.leaderboardMembers[1].displayName == "Thomas M.")
        #expect(appState.leaderboardMembers[1].rank == 2)
        #expect(appState.leaderboardMembers[2].displayName == "Inès K.")
        #expect(appState.leaderboardMembers[2].rank == 3)
        #expect(appState.leaderboardMembers[11].isCurrentUser == true)
        #expect(appState.leaderboardMembers[11].xpPoints == 0)
        #expect(appState.leaderboardMembers[11].rank == 12)

        // Earning 1500 XP promotes current user to rank 1
        appState.userXPPoints = 1500
        appState.syncCurrentUserLeaderboardEntry()
        #expect(appState.leaderboardMembers[0].isCurrentUser == true)
        #expect(appState.leaderboardMembers[0].rank == 1)
        #expect(appState.leaderboardMembers[1].displayName == "Sarah L.")
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

        // Step 0 (OB_01) -> Step 1 (1/7 Auth) -> interactive auth advances to Step 2 (2/7 Goals)
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
        #expect(appState.onboardingStepIndex == 2)

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

        // Verify phone contacts sync & 1-tap friend addition
        appState.syncPhoneContacts()
        #expect(appState.hasSyncedPhoneContacts == true)
        #expect(!appState.phoneContactsMatchedOnApp.isEmpty)
        #expect(!appState.phoneContactsToInvite.isEmpty)
        let firstContactId = appState.phoneContactsMatchedOnApp[0].id
        appState.addMatchedPhoneContact(firstContactId)
        #expect(appState.phoneContactsMatchedOnApp[0].isAddedOrInvited == true)
        #expect(appState.friends.count == 1)
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
}
