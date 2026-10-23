from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
PHASE5_SCREENS = ROOT / "apps/apple/CertigoKit/Sources/Prism/Screens/PrismPhase5FeedbackAndExamScreens.swift"


class Phase5FeedbackAndExamTests(unittest.TestCase):
    def test_phase5_feedback_results_daily_situation_and_mock_exam_exist(self) -> None:
        self.assertTrue(PHASE5_SCREENS.is_file())
        text = PHASE5_SCREENS.read_text(encoding="utf-8")
        for symbol in [
            "public struct SessionFeedbackResolution:",
            "public struct SessionResultsModel:",
            "public struct DailySituationStateMachine:",
            "public enum MockExamTimePolicy:",
            "public struct MockExamStateMachine:",
            "public struct SessionFeedbackPanelScreen: View",
            "public struct SessionResultsScreen: View",
            "public struct DailySituationScreen: View",
            "public struct MockExamIntroScreen: View",
            "public struct MockExamDebriefScreen: View",
        ]:
            self.assertIn(symbol, text, f"Missing {symbol} in PrismPhase5FeedbackAndExamScreens.swift")


if __name__ == "__main__":
    unittest.main()
