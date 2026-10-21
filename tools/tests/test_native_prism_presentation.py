"""Source contracts only: these checks do not render or type-check SwiftUI."""

from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
SOURCES = ROOT / "apps/apple/CertigoNative/Sources"


class NativePrismPresentationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = (SOURCES / "CertigoNativeApp.swift").read_text(encoding="utf-8")
        cls.pilot = (SOURCES / "NativeEditorialPilotView.swift").read_text(encoding="utf-8")

    def test_native_palette_uses_the_existing_prism_spectrum(self):
        flutter = (ROOT / "packages/prism_ui/lib/src/tokens/prism_colors.dart").read_text(
            encoding="utf-8"
        )
        for native, dart in (("ink", "spectrumInk"), ("glow", "spectrumGlow")):
            expected = re.search(rf"{dart} = <Color>\[(.*?)\];", flutter, re.S)[1]
            actual = re.search(rf"let {native}: \[UInt32\] = \[(.*?)\]", self.app, re.S)[1]
            self.assertEqual(
                re.findall(r"0xFF([A-F0-9]{6})", expected),
                re.findall(r"0x([A-F0-9]{6})", actual),
            )
        self.assertIn("traits.accessibilityContrast == .high", self.app)
        self.assertIn("traits.userInterfaceStyle == .dark", self.app)

    def test_material_is_gated_and_reading_stays_opaque(self):
        primary = self.app.split("struct NativePrimaryButton:", 1)[1].split(
            "struct NativeChoiceButtonStyle:", 1
        )[0]
        self.assertIn("accessibilityReduceTransparency", primary)
        self.assertIn("#available(iOS 26.0, *), !reduceTransparency", primary)
        self.assertIn(".glassProminent", primary)
        self.assertIn(".borderedProminent", primary)
        card = self.app.split("struct NativeReadingCard<", 1)[1].split(
            "struct NativePrimaryButton:", 1
        )[0]
        self.assertIn("NativePrism.surface", card)
        self.assertNotIn("Material", card)
        self.assertNotIn("glass", card.lower())
        self.assertNotIn(".lineLimit(", self.pilot)

    def test_real_actions_and_confirmation_boundaries_remain_wired(self):
        root = self.app.split("private struct NativeRoot:", 1)[1]
        for action in (
            "model.select(option, question: question)", "model.submit()", "model.retry(saved)",
            "model.refreshHistory()", "model.loadMoreHistory()", "model.reconnectHistory()",
            "model.chooseActiveTrack(track)", "model.restoreDownloadedActivity()",
        ):
            self.assertIn(action, root)
        self.assertIn(".disabled(!model.canSubmit)", root)
        self.assertIn(".disabled(model.outcome != nil || model.busy)", root)
        self.assertIn("? .isSelected : []", root)
        self.assertIn("case .pendingCorrection:", root)
        self.assertIn("case .corrected(let result):", root)
        self.assertIn("No score or XP is confirmed yet.", root)
        self.assertIn("confirmedOnDevice", root)
        self.assertIn("NavigationSplitView", root)
        self.assertIn("compactColumn = .detail", root)

    def test_editorial_actions_use_the_existing_model(self):
        for action in (
            "model.loadEditorialPilot()", "model.accessEditorialPilotLesson(lesson.id)",
            "model.markEditorialPilotLessonRead(lesson.id)",
        ):
            self.assertIn(action, self.pilot)
        self.assertIn(".disabled(model.busy || !accessRecorded)", self.pilot)
        self.assertIn("NativePrimaryButton", self.pilot)


if __name__ == "__main__":
    unittest.main()
