from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
PHASE6_SCREENS = ROOT / "apps/apple/CertigoKit/Sources/Prism/Screens/PrismPhase6AtlasAndReadinessScreens.swift"


class Phase6AtlasAndReadinessTests(unittest.TestCase):
    def test_phase6_atlas_concept_readiness_passport_and_search_screens_exist(self) -> None:
        self.assertTrue(PHASE6_SCREENS.is_file())
        text = PHASE6_SCREENS.read_text(encoding="utf-8")
        for symbol in [
            "public struct MemoryDetailScreenModel:",
            "public enum AtlasPresentationMode:",
            "public struct AtlasScreenModel:",
            "public struct ConceptDetailScreenModel:",
            "public struct RouteReadinessScreenModel:",
            "public struct ExamOutcomeReportDraft:",
            "public struct CalibrationHistoryScreenModel:",
            "public struct GlobalSearchScreenModel:",
            "public struct MemoryDetailScreen: View",
            "public struct AtlasCompleteScreen: View",
            "public struct ConceptDetailScreen: View",
            "public struct RouteReadinessScreen: View",
            "public struct PassportAndCalibrationScreen: View",
            "public struct GlobalSearchScreen: View",
        ]:
            self.assertIn(symbol, text, f"Missing {symbol} in PrismPhase6AtlasAndReadinessScreens.swift")


if __name__ == "__main__":
    unittest.main()
