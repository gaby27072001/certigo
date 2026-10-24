import BrandAssets
import CertigoDomain
import Foundation
import Prism
import Testing

@Suite struct Phase3NavigationAndTodayTests {
    @Test func tabsEnforceSingleWordLabelsFilledSelectionAndExamTodayBadgeOnly() {
        #expect(AppTab.allCases.count == 5)
        for tab in AppTab.allCases {
            #expect(tab.isSingleWordLabel)
            #expect(!tab.unselectedSymbolName.isEmpty)
            #expect(!tab.selectedSymbolName.isEmpty)
            #expect(tab.badgeText(isExamToday: false) == nil)
        }
        #expect(AppTab.today.badgeText(isExamToday: true) == "Examen aujourd'hui")
        #expect(AppTab.atlas.badgeText(isExamToday: true) == nil)
        #expect(AppTab.ensemble.badgeText(isExamToday: true) == nil)
    }

    @Test func routerManagesPerTabStacksSceneStorageAndDismissalConfirmation() throws {
        let router = AppRouterState()
        #expect(router.isTabBarVisible)

        router.push(.catalogExplorer, in: .atlas)
        #expect(router.selectedTab == .atlas)
        #expect(router.path(for: .atlas) == [.catalogExplorer])
        #expect(router.path(for: .today).isEmpty)

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        router.interruptedSession = InterruptedSessionAccessory(
            sessionId: "sess-42",
            length: .standard,
            currentCardIndex: 2,
            totalCards: 8,
            savedAt: now
        )
        let data = try router.encodeRestorationData()

        let restored = AppRouterState()
        try restored.restore(from: data, now: now.addingTimeInterval(3600))
        #expect(restored.selectedTab == .atlas)
        #expect(restored.path(for: .atlas) == [.catalogExplorer])
        #expect(restored.interruptedSession?.sessionId == "sess-42")
        #expect(restored.interruptedSession?.accessoryTitle == "Séance en cours · Carte 3/8")

        // After 25h (> 24h expiry for standard), interrupted session expires automatically
        let expired = AppRouterState()
        try expired.restore(from: data, now: now.addingTimeInterval(25 * 3600))
        #expect(expired.interruptedSession == nil)

        // DeepDive (Plongée) remains valid up to 7 days
        let deepDive = InterruptedSessionAccessory(
            sessionId: "sess-deep",
            length: .deepDive,
            currentCardIndex: 5,
            totalCards: 15,
            savedAt: now
        )
        #expect(deepDive.isValid(at: now.addingTimeInterval(6 * 24 * 3600)))
        #expect(!deepDive.isValid(at: now.addingTimeInterval(8 * 24 * 3600)))

        // Full-screen cover dismissal rule (§13)
        router.presentCover(.sessionPlayer(length: .express, resumeSessionId: nil))
        #expect(!router.isTabBarVisible)
        router.requestDismissCover(hasUnsavedInputInProgress: true)
        #expect(router.isShowingUnsavedInputConfirmation)
        #expect(router.activeCover != nil)

        router.requestDismissCover(hasUnsavedInputInProgress: false)
        #expect(!router.isShowingUnsavedInputConfirmation)
        #expect(router.activeCover == nil)
        #expect(router.isTabBarVisible)
    }

    @Test func routerPreservesAuthCallbackWidgetDeepLinkAndUniversalLessonLinks() throws {
        let router = AppRouterState()

        let authURL = try #require(URL(string: "certigo://auth?code=abc"))
        #expect(router.handleDeepLink(authURL) == .handledByAuthCallback(authURL))

        let widgetURL = try #require(URL(string: "certigo://widget/learn"))
        #expect(router.handleDeepLink(widgetURL) == .navigatedToSession(.express))
        #expect(router.selectedTab == .today)
        #expect(router.activeCover == .sessionPlayer(length: .express, resumeSessionId: nil))

        let situationURL = try #require(URL(string: "certigo://situation/daily"))
        #expect(router.handleDeepLink(situationURL) == .navigatedToDailySituation)
        #expect(router.activeCover == .dailySituation)

        let explorerURL = try #require(URL(string: "certigo://atlas/explorer"))
        #expect(router.handleDeepLink(explorerURL) == .navigatedToTab(.atlas, route: .catalogExplorer))
        #expect(router.selectedTab == .atlas)
    }

    @Test func todayScreenModelSatisfiesGivenWhenThenAndStateRequirements() {
        let rhythm = PrismRhythmWeekModel(
            weeklyGoalDays: 4,
            days: [
                PrismRhythmDayItem(id: "mon", shortDayLabel: "L", state: .completed),
                PrismRhythmDayItem(id: "tue", shortDayLabel: "M", state: .completed),
                PrismRhythmDayItem(id: "wed", shortDayLabel: "M", state: .planned),
            ],
            bestRhythmWeeks: 6,
            dailyStreakOptIn: true,
            dailyStreakDays: 5
        )
        let today = TodayScreenModel(
            suggestedLength: .standard,
            composition: TodaySessionAtomSummary(
                dueRecallsCount: 6,
                newConceptsCount: 1,
                recommendedConceptTitle: "Isoler un sous-réseau Azure avec un NSG",
                recommendedProduct: .azureVirtualNetwork
            ),
            activeRouteCode: "AZ-104",
            activeRouteTitle: "Microsoft Azure Administrator",
            dailySituation: TodayDailySituationSummary(
                situationId: "sit-2026-10-23",
                title: "Diagnostic de latence sur Azure Load Balancer",
                product: .azureLoadBalancer
            ),
            rhythm: rhythm
        )

        // §35.2 Given an user with 6 due reviews, when Today opens, then the Session card displays "6 rappels"
        #expect(today.composition.compositionSummaryText.contains("6 rappels"))
        #expect(today.primaryActionTitle == "Commencer la séance")
        #expect(today.selectedLength == .standard)
        #expect(today.sessionCardVoiceOverSummary.contains("6 rappels"))

        // With an interrupted session, primary CTA becomes "Reprendre la séance"
        let resumable = TodayScreenModel(
            suggestedLength: .standard,
            composition: today.composition,
            dailySituation: today.dailySituation,
            rhythm: rhythm,
            interruptedSession: InterruptedSessionAccessory(
                sessionId: "s-1",
                length: .express,
                currentCardIndex: 1,
                totalCards: 4,
                savedAt: Date()
            )
        )
        #expect(resumable.primaryActionTitle == "Reprendre la séance")

        // CatalogExplorer filtering & BrandProductID mapping
        var explorer = CatalogExplorerModel(
            routes: [
                CatalogRouteItem(
                    id: "az-900",
                    code: "AZ-900",
                    officialTitle: "Microsoft Azure Fundamentals",
                    region: .cloud,
                    isConfirmedActiveGoal: true
                ),
                CatalogRouteItem(
                    id: "ai-103",
                    code: "AI-103",
                    officialTitle: "Microsoft Foundry Engineer",
                    region: .ai
                ),
            ]
        )
        #expect(explorer.filteredRoutes.count == 2)
        explorer.selectedRegion = .ai
        #expect(explorer.filteredRoutes.map(\.code) == ["AI-103"])
        #expect(explorer.filteredRoutes.first?.product == .microsoftFoundry)

        // NS-12 Ensemble private & leagues disabled by default
        let ensemble = EnsembleMinimalModel()
        #expect(ensemble.isProfilePrivateByDefault)
        #expect(!ensemble.areLeaguesOptedInByDefault)
    }
}
