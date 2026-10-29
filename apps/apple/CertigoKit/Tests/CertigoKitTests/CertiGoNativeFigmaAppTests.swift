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
        #expect(appState.isLiveAIModelConnected == false)
        appState.activeDiagnosticError = nil
        appState.sendAIMessage("Test")
        #expect(appState.chatTurns.isEmpty)
        #expect(appState.activeDiagnosticError == .aiModelNotConnected1001)
        #expect(appState.errorLogHistory.contains(.aiModelNotConnected1001))

        appState.openAITopic("last-3-errors")
        #expect(appState.chatTurns.isEmpty)
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
        #expect(appState.leaderboardMembers[0].displayName == "Toi (Alexandre)")
        #expect(appState.leaderboardMembers[0].initials == "AM")
    }
}
