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
        #expect(ReviewCardWidgetQueueModel.widgetCode == "W-3")
        #expect(widgetQueue.optionCodes == ["A", "B", "C"])
        #expect(widgetQueue.options.count == 3)
        #expect(widgetQueue.queuesResponseWithoutOpeningApp == true)
        #expect(widgetQueue.storesAnswerKeyInWidgetContainer == false)
        #expect(widgetQueue.rendersThirdPartyBrandLogoInWidgetExtension == false)
        #expect(widgetQueue.answerKeyCountInWidgetContainer == 0)
        #expect(widgetQueue.thirdPartyLogoCountInWidgetExtension == 0)

        widgetQueue.enqueueAnswerFromWidget(optionCode: "B")
        #expect(widgetQueue.queuedResponses.count == 1)
        #expect(widgetQueue.queuedResponses.first?.selectedOptionCode == "B")

        // Ignore unknown options not in A/B/C
        widgetQueue.enqueueAnswerFromWidget(optionCode: "Z")
        #expect(widgetQueue.queuedResponses.count == 1)
    }

    @Test("Page 11 Figma Pro iOS 18 Widgets (W-1, W-Radar, W-2, W-3) enforce content and §22A.7 security/brand invariants")
    func page11WidgetsContentAndBrandInvariants() {
        #expect(CertigoWidgetSurfaceKind.allCases.map(\.code) == ["W-1", "W-Radar", "W-2", "W-3"])

        let w1 = TodayProgressWidgetSurfaceModel()
        #expect(TodayProgressWidgetSurfaceModel.widgetCode == "W-1")
        #expect(w1.streakDays == 12)
        #expect(w1.streakBadgeText == "🔥 12j")
        #expect(w1.dailyGoalStatusText == "10/10 min ✓")
        #expect(w1.parallelActiveTracksBadge == "AZ-104 + 2")
        #expect(w1.storesAnswerKeyInWidgetContainer == false)
        #expect(w1.rendersThirdPartyBrandLogoInWidgetExtension == false)

        let wRadar = AIRadarLiveWidgetSurfaceModel()
        #expect(AIRadarLiveWidgetSurfaceModel.widgetCode == "W-Radar")
        #expect(wRadar.headline == "Nouveau cours IA : Claude 4 & Agents MCP")
        #expect(wRadar.region == .ai)
        #expect(wRadar.storesAnswerKeyInWidgetContainer == false)
        #expect(wRadar.rendersThirdPartyBrandLogoInWidgetExtension == false)

        let w2 = DailySituationWidgetSurfaceModel()
        #expect(DailySituationWidgetSurfaceModel.widgetCode == "W-2")
        #expect(w2.title == "Protection d'un coffre Key Vault critique")
        #expect(w2.rewardText == "+25 XP")
        #expect(w2.summaryText == "Protection d'un coffre Key Vault critique · +25 XP")
        #expect(w2.storesAnswerKeyInWidgetContainer == false)
        #expect(w2.rendersThirdPartyBrandLogoInWidgetExtension == false)
    }

    @Test("LA-1..LA-3 Live Activities, CC-1 Control Center, and AI-1 App Intents / Spotlight follow Page 11 Figma Pro and §22A.7 brand rules")
    func liveActivitiesControlCenterAndSpotlightInvariants() {
        let activities = CertigoLiveActivityState.validatedPage11Activities
        #expect(activities.count == 3)

        let la1 = CertigoLiveActivityState(kind: .mockExamSession)
        #expect(la1.kind.code == "LA-1")
        #expect(la1.completedItems == 14)
        #expect(la1.totalItems == 50)
        #expect(la1.timerLabel == "⏱️ 64:18")
        #expect(la1.progressSubtitle == "Question 14/50")
        #expect(la1.statusDetailLabel == "Seuil 700/1000")
        #expect(la1.dynamicIslandSummary == "⏱️ 64:18 · Question 14/50 · Seuil 700/1000")
        #expect(la1.rendersThirdPartyBrandLogoInLiveActivity == false)
        #expect(la1.thirdPartyLogoCountInLiveActivity == 0)

        let la2 = CertigoLiveActivityState(kind: .deepDiveSession)
        #expect(la2.kind.code == "LA-2")
        #expect(la2.completedItems == 4)
        #expect(la2.totalItems == 6)
        #expect(la2.progressSubtitle == "4/6 étapes")
        #expect(la2.statusDetailLabel == "Série protégée")
        #expect(la2.dynamicIslandSummary == "4/6 étapes · Série protégée")
        #expect(la2.rendersThirdPartyBrandLogoInLiveActivity == false)

        let la3 = CertigoLiveActivityState(kind: .examDayCompanion)
        #expect(la3.kind.code == "LA-3")
        #expect(la3.isCalmModeActive == true)
        #expect(la3.isUntimedMode == true)
        #expect(la3.showsAnxietyInducingNewQuestions == false)
        #expect(la3.progressSubtitle == "3 Fiches Mémo Clés")
        #expect(la3.statusDetailLabel == "Zéro nouvelle question anxiogène")
        #expect(la3.dynamicIslandSummary == "3 Fiches Mémo Clés · Zéro nouvelle question anxiogène")
        #expect(la3.rendersThirdPartyBrandLogoInLiveActivity == false)

        let control = ExpressSessionControlWidgetModel()
        #expect(ExpressSessionControlWidgetModel.controlCode == "CC-1")
        #expect(ExpressSessionControlWidgetModel.targetDurationMinutes == 5)
        #expect(control.title == "Express 5 min")
        #expect(control.deepLinkURL == "certigo://session/express?duration=5")
        #expect(control.rendersThirdPartyBrandLogoInControlCenter == false)

        #expect(CertigoAppIntentKind.allCases.count == 4)
        for entity in CertigoSpotlightConceptEntity.defaultEntities {
            #expect(entity.includesThirdPartyBrandLogoInSpotlight == false)
        }
    }
}
