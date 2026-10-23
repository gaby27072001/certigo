import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
SESSION_SCREENS = ROOT / "apps/apple/CertigoKit/Sources/Prism/Screens/PrismSessionPlayerScreens.swift"
LESSON_SCHEMA = ROOT / "content/schema/lesson.schema.json"


class Phase4LearningExperienceTests(unittest.TestCase):
    def test_session_player_and_all_p1_formats_exist(self) -> None:
        self.assertTrue(SESSION_SCREENS.is_file())
        text = SESSION_SCREENS.read_text(encoding="utf-8")
        for symbol in [
            "public enum PrismItemFormatPayload:",
            "case choice(",
            "case situation(",
            "case predict(",
            "case spotTheIssue(",
            "case ordering(",
            "case commandComposer(",
            "case unsupported(",
            "public struct PrismSessionItemModel:",
            "public struct PrismLearningCardModel:",
            "public struct PrismSessionPlan:",
            "public struct PrismSessionBookmark:",
            "public struct PrismOfflineSessionCache:",
            "public struct SessionPlayerStateMachine:",
            "public struct LearningCardView: View",
            "public struct SessionItemCardView: View",
            "public struct SessionPlayerScreen: View",
        ]:
            self.assertIn(symbol, text, f"Missing {symbol} in PrismSessionPlayerScreens.swift")

    def test_lesson_schema_includes_additive_phase4_fields(self) -> None:
        schema = json.loads(LESSON_SCHEMA.read_text(encoding="utf-8"))
        block_props = schema["$defs"]["block"]["properties"]
        self.assertIn("skippable", block_props)
        self.assertIn("skipVerificationItemId", block_props)
        self.assertIn("diagram", block_props)

        item_props = schema["$defs"]["item"]["properties"]
        for field in [
            "format",
            "artifact",
            "revealOptionsDelayMs",
            "captureConfidence",
            "misconceptionTags",
            "rung",
            "sources",
        ]:
            self.assertIn(field, item_props, f"Missing {field} in lesson.schema.json item properties")


if __name__ == "__main__":
    unittest.main()
