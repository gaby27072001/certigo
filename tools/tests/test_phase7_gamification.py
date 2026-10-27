from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
PHASE7_SCREENS = ROOT / "apps/apple/CertigoKit/Sources/Prism/Screens/PrismPhase7GamificationScreens.swift"
SPECS_DOC = ROOT / "docs/transformation/specs/gamification-learning-rules.md"


class Phase7GamificationTests(unittest.TestCase):
    def test_gamification_screens_and_learning_rules_spec_exist(self) -> None:
        self.assertTrue(PHASE7_SCREENS.is_file())
        self.assertTrue(SPECS_DOC.is_file())
        text = PHASE7_SCREENS.read_text(encoding="utf-8")
        for symbol in [
            "public struct WeeklyRhythmPlannerModel:",
            "public struct WelcomeBackBannerModel:",
            "public enum MasteryMilestoneKind:",
            "public struct WeeklyMissionBoardModel:",
            "public struct CooperativeEventBannerModel:",
            "public struct GamificationSurfacePolicy:",
            "public struct CertiGoZeroGuiltWelcomeBackModel:",
            "public struct WelcomeBackCardView: View",
            "public struct CertiGoZeroGuiltWelcomeBackView: View",
            "public struct WeeklyRhythmSettingsScreen: View",
            "public struct MasteryMilestonesAndMissionsScreen: View",
        ]:
            self.assertIn(symbol, text, f"Missing {symbol} in PrismPhase7GamificationScreens.swift")

        spec_text = SPECS_DOC.read_text(encoding="utf-8")
        for flag in ["rhythm.v1", "rhythm.dailyStreakOptIn", "celebrations.v1", "missions.v1", "events.v1"]:
            self.assertIn(flag, spec_text)


if __name__ == "__main__":
    unittest.main()
