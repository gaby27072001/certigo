import pathlib
import unittest

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
PHASE8_SCREENS = REPO_ROOT / "apps/apple/CertigoKit/Sources/Prism/Screens/PrismPhase8SocialScreens.swift"
PHASE8_SWIFT_TESTS = REPO_ROOT / "apps/apple/CertigoKit/Tests/CertigoKitTests/Phase8SocialAndCollaborativeTests.swift"
PHASE8_REPORT = REPO_ROOT / "docs/transformation/phase-8/REPORT.md"
DEBUG_GALLERY = REPO_ROOT / "apps/apple/CertigoNative/Sources/PrismDebugGalleryView.swift"


class Phase8SocialCollaborativeTests(unittest.TestCase):
    def test_phase8_files_exist(self) -> None:
        for path in (PHASE8_SCREENS, PHASE8_SWIFT_TESTS, PHASE8_REPORT, DEBUG_GALLERY):
            self.assertTrue(path.is_file(), f"Missing Phase 8 file: {path}")

    def test_phase8_screens_enforce_social_model_and_privacy_invariants(self) -> None:
        content = PHASE8_SCREENS.read_text(encoding="utf-8")
        required_symbols = [
            "public enum SocialVisibilityScope",
            "public struct SocialPrivacySettingsModel",
            "public enum SocialReportReason",
            "public struct SocialModerationState",
            "public enum SocialDeferredFeaturesPolicy",
            "public struct DailySituationHistoryEntry",
            "public struct SquadWorkspaceModel",
            "public struct CreateOrJoinSquadDraft",
            "public struct SocialFriendProfile",
            "public struct FriendInvitePayload",
            "public struct AsyncChallengeStateMachine",
            "public struct ProgressionLeagueModel",
            "public struct DailySituationHistoryScreen",
            "public struct SquadDetailScreen",
            "public struct CreateOrJoinSquadSheetScreen",
            "public struct FriendsListScreen",
            "public struct FriendProfileScreen",
            "public struct InviteFriendSheetScreen",
            "public struct AsyncChallengeCoverScreen",
            "public struct ProgressionLeaguesScreen",
            "public enum CertiGoSocialHubSegment",
            "public struct CertiGoSocialPodiumEntry",
            "public struct CertiGoSocialFriendActivityItem",
            "public struct CertiGoSocialHubModel",
            "public struct CertiGoPodium3DView",
            "public struct CertiGoFriendsActivityView",
            "public struct CertiGoSocialHubCompleteView",
            "public struct EnsembleCompleteScreen",
        ]
        for symbol in required_symbols:
            self.assertIn(symbol, content, f"Missing symbol in PrismPhase8SocialScreens.swift: {symbol}")
        self.assertIn("public static let noDemotionProtectedWeeks: Int = 4", content)
        self.assertIn("public static let maxGraceWeeks: Int = 2", content)
        self.assertIn("public static let neighborsWindowRadius: Int = 3", content)
        self.assertIn("sendOneTapSaluerKudos(toFriendId:", content)
        self.assertIn("CertiGoOfficialCrestView(", content)
        self.assertIn("BrandLabel(", content)

    def test_phase8_registered_in_debug_gallery_and_report_complete(self) -> None:
        gallery = DEBUG_GALLERY.read_text(encoding="utf-8")
        self.assertIn("Phase 8 · Social, Squads, Challenges & Glicko-2 Leagues", gallery)
        report = PHASE8_REPORT.read_text(encoding="utf-8")
        for gate in (
            "### 1. BUILD",
            "### 2. TEST",
            "### 3. VISUAL VALIDATION",
            "### 4. ACCESSIBILITY VALIDATION",
            "### 5. PERFORMANCE CHECK",
            "### 6. ANALYTICS & FEATURE FLAGS",
            "### 7. SELF-REVIEW",
        ):
            self.assertIn(gate, report)


if __name__ == "__main__":
    unittest.main()
