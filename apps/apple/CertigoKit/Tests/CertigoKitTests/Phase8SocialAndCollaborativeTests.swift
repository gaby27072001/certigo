import BrandAssets
import CertigoDomain
import Foundation
import Prism
import Testing

@Suite("Phase 8 — Social, Collaborative & Competitive (§10, S-31, S-60..S-67, NS-12)")
struct Phase8SocialAndCollaborativeTests {

    @Test("NS-12: Profile is private by default and leagues are disabled by default")
    func privateByDefaultAndLeaguesOff() {
        let privacy = SocialPrivacySettingsModel()
        #expect(privacy.isPrivateByDefault == true)
        #expect(privacy.progressionLeaguesOptIn == false)
        #expect(privacy.effectiveLeaguesOptIn == false)
        #expect(privacy.allowsContactImport == false)
        #expect(privacy.sharesLocation == false)
        #expect(privacy.exposesFailuresToOthers == false)
        #expect(privacy.allowsFreeTextChat == false)
        #expect(privacy.requiresExplicitSquadConsent == true)
        for scope in SocialVisibilityScope.allCases {
            #expect(privacy.isScopeVisible(scope) == false)
        }
    }

    @Test("Minor mode (Declared Age Range) disables leagues, invite links, and visibility scopes")
    func minorModeEnforcesSafetyRestrictions() {
        var minorPrivacy = SocialPrivacySettingsModel(
            pseudonym: "Jeune-Az",
            isPrivateByDefault: false,
            visibleScopes: Set(SocialVisibilityScope.allCases),
            progressionLeaguesOptIn: true,
            employerAggregatedOptIn: true,
            isMinorAccount: true
        )
        #expect(minorPrivacy.effectiveLeaguesOptIn == false)
        #expect(minorPrivacy.canShareExternalInviteLink == false)
        #expect(minorPrivacy.employerAggregatedOptIn == false)
        minorPrivacy.toggleScope(.rhythm)
        for scope in SocialVisibilityScope.allCases {
            #expect(minorPrivacy.isScopeVisible(scope) == false)
        }
    }

    @Test("Moderation state blocks, hides, and records predefined reports without free text")
    func moderationBlocksHidesAndReports() {
        var moderation = SocialModerationState()
        #expect(moderation.isPeerVisible("friend-alizee") == true)

        moderation.hidePeer("friend-alizee")
        #expect(moderation.isPeerVisible("friend-alizee") == false)
        moderation.unhidePeer("friend-alizee")
        #expect(moderation.isPeerVisible("friend-alizee") == true)

        moderation.blockPeer("friend-karim")
        #expect(moderation.isPeerVisible("friend-karim") == false)

        moderation.reportPeer("friend-alizee", reason: .unwantedChallenge)
        #expect(moderation.reports.count == 1)
        #expect(moderation.reports.first?.reason == .unwantedChallenge)
        #expect(moderation.isPeerVisible("friend-alizee") == false)
    }

    @Test("Deferred v1 social features are strictly disabled (§10 MUST NOT)")
    func deferredV1FeaturesAreDisabled() {
        #expect(SocialDeferredFeaturesPolicy.freeTextChatEnabled == false)
        #expect(SocialDeferredFeaturesPolicy.liveStudyRoomsEnabled == false)
        #expect(SocialDeferredFeaturesPolicy.realTimeDuelsEnabled == false)
        #expect(SocialDeferredFeaturesPolicy.publicActivityFeedEnabled == false)
        #expect(SocialDeferredFeaturesPolicy.isDeferredInV1("free_text_chat") == true)
        #expect(SocialDeferredFeaturesPolicy.isDeferredInV1("live_study_rooms") == true)
        #expect(SocialDeferredFeaturesPolicy.isDeferredInV1("realtime_duels") == true)
        #expect(SocialDeferredFeaturesPolicy.isDeferredInV1("public_activity_feed") == true)
    }

    @Test("S-31 Daily Situation History gates community distribution and spoiler-free share card")
    func dailySituationHistoryGatingAndShareCard() {
        let entries = DailySituationHistoryEntry.defaultSampleEntries
        #expect(entries.count == 2)

        let answered = entries[0]
        #expect(answered.hasAnswered == true)
        #expect(answered.distribution.isVisible == true)
        let shareCard = answered.spoilerFreeSharePayload
        #expect(shareCard != nil)
        #expect(shareCard?.spoilerViolations.isEmpty == true)

        let unanswered = entries[1]
        #expect(unanswered.hasAnswered == false)
        #expect(unanswered.distribution.isVisible == false)
        #expect(unanswered.spoilerFreeSharePayload == nil)
    }

    @Test("S-61 & S-62 Squad workspace enforces 3-8 members, anonymized defaults, 1-tap kudos, and explicit consent")
    func squadWorkspaceAndConsentInvariants() {
        var workspace = SquadWorkspaceModel()
        #expect(workspace.goalModel.hasValidMemberCount == true)
        #expect(workspace.goalModel.isAnonymizedByDefault == true)
        #expect(workspace.memberFailuresVisible == false)
        #expect(workspace.hasExplicitMemberConsent == true)

        let firstMember = workspace.goalModel.members[0]
        #expect(workspace.goalModel.displayedName(for: firstMember) == "AL")

        workspace.sendPredefinedKudos(.solidRhythm, toMemberId: firstMember.id)
        #expect(workspace.sentKudos.count == 1)
        #expect(workspace.sentKudos.first?.preset == .solidRhythm)

        var draft = CreateOrJoinSquadDraft(squadName: "Squad Cloud", explicitConsentChecked: false)
        #expect(draft.canCreateSquad == false)
        draft.explicitConsentChecked = true
        #expect(draft.canCreateSquad == true)
    }

    @Test("S-63, S-64 & S-67 Friends and Invite payload never import contacts or expose failures")
    func friendsAndInviteInvariants() {
        for friend in SocialFriendProfile.defaultFriends {
            #expect(friend.visibleFailureCount == 0)
        }
        let invite = FriendInvitePayload(inviteCode: "az104")
        #expect(invite.importsAddressBookContacts == false)
        #expect(invite.inviteCode == "AZ104")
        #expect(invite.deepLinkURL == "certigo://ensemble/invite/AZ104")
    }

    @Test("S-65 Async 5-item challenge is untimed and computes accuracy x calibration")
    func asyncChallengeUntimedFiveItems() {
        var challenge = AsyncChallengeStateMachine()
        #expect(challenge.hasTimer == false)
        #expect(challenge.showsOpponentItemFailures == false)
        #expect(challenge.isCompleted == false)

        for _ in 0..<5 {
            challenge.submitItemEvaluation(accuracy: 1.0, calibration: 0.8)
        }
        #expect(challenge.isCompleted == true)
        #expect(challenge.challengeModel.totalScorePercentage == 80)
    }

    @Test("S-66 Glicko-2 progression league is opt-in, caps daily points, protects 4 weeks, and shows ±3 neighbors")
    func glicko2LeagueInvariants() {
        var league = ProgressionLeagueModel()
        #expect(league.isOptedIn == false)
        #expect(league.isProtectedFromDemotion == true)
        #expect(league.visibleNeighborStandings.isEmpty == true)

        league.isOptedIn = true
        let neighbors = league.visibleNeighborStandings
        #expect(neighbors.count == 7)
        #expect(neighbors.first?.rank == 3)
        #expect(neighbors.last?.rank == 9)
        #expect(neighbors.contains(where: { $0.isCurrentLearner && $0.rank == 6 }) == true)

        league.recordMasteryPoints(100)
        #expect(league.dailyMasteryPointsEarned == ProgressionLeagueModel.dailyMasteryPointsCap)
    }
}
