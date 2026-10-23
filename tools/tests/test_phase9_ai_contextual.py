import pathlib
import unittest

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
PHASE9_SCREENS = REPO_ROOT / "apps/apple/CertigoKit/Sources/Prism/Screens/PrismPhase9AIContextualScreens.swift"
PHASE9_SWIFT_TESTS = REPO_ROOT / "apps/apple/CertigoKit/Tests/CertigoKitTests/Phase9AIContextualTests.swift"
PHASE9_REPORT = REPO_ROOT / "docs/transformation/phase-9/REPORT.md"
DEBUG_GALLERY = REPO_ROOT / "apps/apple/CertigoNative/Sources/PrismDebugGalleryView.swift"


class Phase9AIContextualTests(unittest.TestCase):
    def test_phase9_files_exist(self) -> None:
        for path in (PHASE9_SCREENS, PHASE9_SWIFT_TESTS, PHASE9_REPORT, DEBUG_GALLERY):
            self.assertTrue(path.is_file(), f"Missing Phase 9 file: {path}")

    def test_phase9_screens_enforce_ai_model_and_five_level_router(self) -> None:
        content = PHASE9_SCREENS.read_text(encoding="utf-8")
        required_symbols = [
            "public enum AIRoutingTier",
            "public struct AIGroundedSnippet",
            "public enum AISecretRedactor",
            "public struct AIRouterConfiguration",
            "public struct AIRoutedResponse",
            "public struct AIRouter",
            "public enum ContextualAIEntryPoint",
            "public struct ContextualAISessionState",
            "public struct ConceptComparisonPairModel",
            "public struct LearnerMisconceptionEntry",
            "public struct ExplainBackRubricEvaluator",
            "public enum AIEvaluationHarness",
            "public struct ContextualAISheetScreen",
            "public struct CompareConceptsSheetScreen",
            "public struct MisconceptionsMapScreen",
            "public struct ExplainBackExerciseCardView",
        ]
        for symbol in required_symbols:
            self.assertIn(symbol, content, f"Missing symbol in PrismPhase9AIContextualScreens.swift: {symbol}")
        self.assertIn("public static let onDeviceContextTokenBudget: Int = 4096", content)
        self.assertIn("public static let p95TimeoutMilliseconds: Int = 2500", content)
        self.assertIn("public static let maxWhyTurns: Int = 2", content)
        self.assertIn("BrandLabel(", content)

    def test_phase9_registered_in_debug_gallery_and_report_complete(self) -> None:
        gallery = DEBUG_GALLERY.read_text(encoding="utf-8")
        self.assertIn("Phase 9 · Contextual AI, S-24, S-44, S-45 & 5-Tier AIRouter", gallery)
        report = PHASE9_REPORT.read_text(encoding="utf-8")
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
