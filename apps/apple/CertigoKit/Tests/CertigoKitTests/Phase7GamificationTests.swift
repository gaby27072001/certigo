import BrandAssets
import CertigoDomain
import Foundation
import Prism
import Testing

@Suite struct Phase7GamificationTests {
    @Test func weeklyRhythmEnforcesGoalBoundsRestDaysPauseAndFreeCatchUp() {
        var planner = WeeklyRhythmPlannerModel(
            targetDaysPerWeek: 5,
            completedDaysThisWeek: 2,
            bestRhythmWeeks: 4,
            completedCatchUpRecalls: 2,
            days: [
                PrismRhythmDayItem(id: "mon", shortDayLabel: "L", state: .completed),
                PrismRhythmDayItem(id: "tue", shortDayLabel: "M", state: .completed),
            ]
        )
        #expect(planner.restDaysPerWeek == 2)
        #expect(!planner.canRedeemFreeCatchUp)

        planner.completedCatchUpRecalls = 3
        #expect(planner.canRedeemFreeCatchUp)
        let redeemed = planner.applyFreeCatchUpIfEligible()
        #expect(redeemed)
        #expect(planner.completedDaysThisWeek == 3)
        #expect(planner.completedCatchUpRecalls == 0)

        planner.configurePause(weeks: 6)
        #expect(planner.pauseWeeksRemaining == WeeklyRhythmPlannerModel.maxPauseWeeks)
        #expect(planner.isPaused)
    }

    @Test func welcomeBackContainsZeroGuiltCopyAndSuggestsExpressSession() {
        let banner = WelcomeBackBannerModel(awayDaysCount: 5)
        #expect(!banner.containsGuiltOrLossCopy)
        #expect(banner.suggestedLength == .express)
    }

    @Test func res02ZeroGuiltWelcomeBackModelEnforcesCaringMascotPreservedConceptsAndFreeCatchUp() {
        var model = CertiGoZeroGuiltWelcomeBackModel()
        #expect(model.screenCode == "RES-02")
        #expect(model.mascotPose == .emotionOopsCaring)
        #expect(model.hasGuiltInducingCopy == false)
        #expect(model.containsGuiltOrLossCopy == false)
        #expect(model.sellsPaidStreakFreeze == false)
        #expect(model.preservedAnchoredConceptsCount == 28)
        #expect(model.suggestedExpressMinutes == 5)
        #expect(model.freeCatchUpRecallsCount == 3)
        #expect(model.suggestedLength == .express)
        #expect(!model.canRedeemFreeCatchUpDay)

        model.recordCompletedCatchUpRecall()
        model.recordCompletedCatchUpRecall()
        model.recordCompletedCatchUpRecall()
        #expect(model.canRedeemFreeCatchUpDay)
        #expect(model.redeemFreeCatchUpDayIfEligible() == true)
        #expect(model.completedCatchUpRecallsCount == 0)
        #expect(!model.legacyBannerModel.containsGuiltOrLossCopy)
    }

    @Test func missionsCapAtThreeWithSquadMissionAndMilestonesCiteLearningRules() {
        let missions = (1...5).map { idx in
            WeeklyMissionItem(
                id: "m-\(idx)",
                title: "Mission \(idx)",
                skillFocus: "Sécurité réseau",
                learningRuleCitation: "Pratique délibérée ciblée",
                isCooperativeSquadMission: idx == 1,
                currentCount: 1,
                targetCount: 3
            )
        }
        let board = WeeklyMissionBoardModel(weekLabel: "Semaine 43", missions: missions)
        #expect(board.missions.count == WeeklyMissionBoardModel.maxMissionsPerWeek)
        #expect(board.cooperativeSquadMissionsCount == 1)

        for kind in MasteryMilestoneKind.allCases {
            #expect(!kind.learningRuleCitation.isEmpty)
        }

        let event = CooperativeEventBannerModel(
            id: "ev-1",
            title: "Semaine de l'ancrage Cloud",
            subtitle: "Objectif coopératif communautaire",
            region: .cloud,
            communityAnchoredCount: 420,
            communityTargetCount: 1000
        )
        #expect(!event.hasBattlePassOrPaidTier)
    }

    @Test func surfacePolicyRemovesGemsShopAndXPLeaguesWhilePreservingDR005StreakDefault() {
        let policy = GamificationSurfacePolicy()
        #expect(!policy.showsGemsOrShopInUI)
        #expect(!policy.showsPaidStreakFreezeInUI)
        #expect(!policy.showsPublicTenTierXPLeaguesInUI)
        #expect(!policy.showsGenericXPOrCrownsInUI)
        #expect(!policy.showsMonthlyBattlePassInUI)
        #expect(policy.showsDailyStreakAndAtRiskIconByDefault)
    }
}
