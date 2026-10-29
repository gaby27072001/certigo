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
        #expect(appState.gemsCount == 480)
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
