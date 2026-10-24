import BrandAssets
import CertigoDomain
import Foundation
import Prism
import Testing

@Suite("Phase 10 — Onboarding 60s (NS-1), Pro StoreKit 2 (S-73), Settings (S-74..S-84) & iOS System Surfaces (NS-14)")
struct Phase10OnboardingAndSystemSurfacesTests {

    @Test("NS-1 Onboarding reaches 1st decision in <= 2 screens, uses zero text fields, works offline, and gates notifications after 1st session")
    func onboardingNS1Invariants() {
        var flow = OnboardingFlowStateMachine()
        #expect(flow.screensBeforeFirstDecision <= 2)
        #expect(flow.usesFreeTextFields == false)
        #expect(flow.isPlayableOffline == true)
        #expect(flow.showsPaywallBeforeFirstValue == false)
        #expect(flow.canPromptForNotifications == false)
        #expect(flow.grantNotificationPermissionIfEligible() == false)

        flow.selectRoute(region: .azure, routeCode: "AZ-104", productId: BrandProductID("microsoft-entra-id"))
        #expect(flow.currentStep == .discoverySituation)

        flow.answerDiscoverySituation(optionCode: "A")
        #expect(flow.currentStep == .firstAhaMoment)
        #expect(flow.hasCompletedFirstValueSession == true)
        #expect(flow.canPromptForNotifications == true)

        flow.advanceToNextStep()
        #expect(flow.currentStep == .goalRhythmAndWhen)
        flow.advanceToNextStep()
        #expect(flow.currentStep == .saveProgressAuth)
        flow.advanceToNextStep()
        #expect(flow.currentStep == .notificationPermissionSheet)
        #expect(flow.grantNotificationPermissionIfEligible() == true)
    }

    @Test("S-73 CertiGo Pro StoreKit 2 paywall is blocked before first value and never sells streak freezes or gems")
    func certigoProPaywallGatingAndEthics() {
        let beforeValue = CertigoProPaywallModel(hasExperiencedFirstLearningValue: false)
        #expect(beforeValue.canPresentPaywall == false)
        #expect(beforeValue.hasManipulativeCountdownTimer == false)
        #expect(beforeValue.sellsStreakFreezesOrGems == false)
        #expect(beforeValue.supportsStoreKit2RestorePurchases == true)

        let afterValue = CertigoProPaywallModel(hasExperiencedFirstLearningValue: true)
        #expect(afterValue.canPresentPaywall == true)
    }

    @Test("S-75..S-84 Settings and S-82 Account Deletion require explicit confirmation and purge all local/widget surfaces")
    func settingsAndAccountDeletionInvariants() {
        #expect(SettingsSectionDestination.allCases.count == 10)
        var deletion = AccountDeletionConfirmationModel()
        #expect(deletion.purgesKeychainTokens == true)
        #expect(deletion.purgesOfflineSessionCache == true)
        #expect(deletion.purgesWidgetSnapshots == true)
        #expect(deletion.callsServerDeleteEndpoint == true)
        #expect(deletion.confirmAndExecuteDeletion() == false)

        deletion.explicitConfirmationChecked = true
        #expect(deletion.confirmAndExecuteDeletion() == true)
        #expect(deletion.hasExecutedIrrevocableDeletion == true)
    }

    @Test("NS-14 Review Card Widget (W-3) queues responses without opening app and omits answer keys and third-party brand logos")
    func reviewCardWidgetNS14Invariants() {
        var widgetQueue = ReviewCardWidgetQueueModel()
        #expect(widgetQueue.queuesResponseWithoutOpeningApp == true)
        #expect(widgetQueue.storesAnswerKeyInWidgetContainer == false)
        #expect(widgetQueue.rendersThirdPartyBrandLogoInWidgetExtension == false)

        widgetQueue.enqueueAnswerFromWidget(optionCode: "B")
        #expect(widgetQueue.queuedResponses.count == 1)
        #expect(widgetQueue.queuedResponses.first?.selectedOptionCode == "B")
    }

    @Test("LA-1..LA-3 Live Activities, CC-1 Control Center, and AI-1 App Intents / Spotlight follow §22A.7 brand rules")
    func liveActivitiesControlCenterAndSpotlightInvariants() {
        let liveActivity = CertigoLiveActivityState(kind: .mockExamSession)
        #expect(liveActivity.rendersThirdPartyBrandLogoInLiveActivity == false)

        let control = ExpressSessionControlWidgetModel()
        #expect(ExpressSessionControlWidgetModel.controlCode == "CC-1")
        #expect(ExpressSessionControlWidgetModel.targetDurationMinutes == 5)
        #expect(control.deepLinkURL == "certigo://session/express?duration=5")

        #expect(CertigoAppIntentKind.allCases.count == 4)
        for entity in CertigoSpotlightConceptEntity.defaultEntities {
            #expect(entity.includesThirdPartyBrandLogoInSpotlight == false)
        }
    }
}
