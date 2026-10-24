import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
PRISM_DIR = ROOT / "apps/apple/CertigoKit/Sources/Prism"
XCASSETS_DIR = PRISM_DIR / "Resources/Prism.xcassets"


class PrismPhase2ComponentsTests(unittest.TestCase):
    def test_all_four_phase2_component_families_exist_and_expose_normative_components(self) -> None:
        expected_files = {
            "PrismFoundationComponents.swift": [
                "struct PrismText:",
                "struct PrismIcon:",
                "struct PrismButtonStyle:",
                "struct PrismCard<",
                "struct PrismSection<",
                "struct PrismRow",
                "struct PrismChip:",
                "struct PrismBadge:",
                "struct PrismProgressBar:",
                "struct PrismProgressRing:",
                "struct PrismSegmentedControl<",
            ],
            "PrismLearningComponents.swift": [
                "struct SessionProgressHeader:",
                "struct SessionLengthPicker:",
                "struct QuestionCard:",
                "struct ExplanationCard:",
                "struct WorkedExampleView:",
                "struct DiagramView:",
                "struct ArtifactView:",
                "struct ChoiceList:",
                "struct ConfidencePicker:",
                "struct TokenComposer:",
                "struct OrderList:",
                "struct SlotBoard:",
                "struct EstimateSlider:",
                "struct ExplainInput:",
                "struct FeedbackPanel:",
                "struct ResponsibilityMatrix:",
                "struct TakeawayLine:",
                "struct HintLadderView:",
            ],
            "PrismProgressAndSocialComponents.swift": [
                "struct MasteryGlyph:",
                "struct DepthLadderView:",
                "struct MemoryForecastChart:",
                "struct ReadinessBandView:",
                "struct ObjectiveCoverageList:",
                "struct RhythmWeekView:",
                "struct AtlasCanvas:",
                "struct AtlasList:",
                "struct RegionChip:",
                "struct RouteBadge:",
                "struct PassportCard:",
                "struct AvatarMonogram:",
                "struct KudosButton:",
                "struct SquadGoalView:",
                "struct ChallengeCard:",
                "struct CommunityDistributionChart:",
            ],
            "PrismStateAndA11yComponents.swift": [
                "struct PrismEmptyState:",
                "struct PrismErrorState:",
                "struct PrismOfflineBanner:",
                "struct PrismSkeleton:",
                "struct PrismToast:",
                "struct PrismCelebration:",
                "enum ShareCardRenderer",
                "struct PrismAdaptiveStack<",
            ],
        }
        for filename, markers in expected_files.items():
            path = PRISM_DIR / filename
            self.assertTrue(path.is_file(), f"Missing {filename}")
            text = path.read_text(encoding="utf-8")
            for marker in markers:
                self.assertIn(marker, text, f"Missing {marker} in {filename}")
            self.assertIn("#Preview", text, f"Missing #Preview in {filename}")

    def test_custom_certigo_symbolsets_exist_in_prism_xcassets(self) -> None:
        expected_symbols = [
            "certigo.region.cloud",
            "certigo.region.ai",
            "certigo.region.data",
            "certigo.region.security",
            "certigo.region.network",
            "certigo.region.devops",
            "certigo.region.code",
            "certigo.region.systems",
            "certigo.concept.undiscovered",
            "certigo.concept.discovered",
            "certigo.concept.practicing",
            "certigo.concept.anchored",
            "certigo.concept.mastered",
            "certigo.misconception",
            "certigo.declic",
            "certigo.route",
        ]
        for sym in expected_symbols:
            sdir = XCASSETS_DIR / f"{sym}.symbolset"
            self.assertTrue(sdir.is_dir(), f"Missing {sdir}")
            contents = json.loads((sdir / "Contents.json").read_text(encoding="utf-8"))
            self.assertEqual(contents["symbols"][0]["filename"], f"{sym}.svg")
            self.assertTrue((sdir / f"{sym}.svg").is_file())


if __name__ == "__main__":
    unittest.main()
