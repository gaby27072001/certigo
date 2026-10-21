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

    def test_catalog_uses_real_metadata_and_local_search(self):
        root = self.app.split("private struct NativeRoot:", 1)[1]
        for marker in (
            ".searchable(text: $query", "$catalogFilter.query",
            'Picker("Code family"', '"Available practice only"',
            "visibleTracks.count", '"No matching certifications"',
            '"Clear filters"', "catalogFilter.clear()", "catalogFilter.includes(",
            "Code families are not provider metadata",
        ):
            self.assertIn(marker, self.app)
        self.assertIn("onChange(of: model.profile?.id", root)
        self.assertIn("Language and format filters are unavailable", root)
        self.assertNotIn("Task { await model.search", root)

    def test_learning_intentions_and_denominators_stay_distinct(self):
        root = self.app.split("private struct NativeRoot:", 1)[1]
        for marker in (
            '"Next session"', '"Learning plan"', '"Review & Practice"', '"Goal overview"',
            '"Activity & coverage"', '"Confirmed session results"',
            '"Readiness · last loaded from server"', "coverage.totalActivities",
            "coverage.totalUnits", "lesson.questions.count",
            "not a calibrated probability", "Unknown is not zero",
            "Locked by the server", "not connected in this client",
        ):
            self.assertIn(marker, root)
        self.assertIn('Button("Read again"', root)
        self.assertIn("title: destination.practiceTitle", root)
        self.assertIn('case .corrected(let result):', root)
        self.assertIn('reader.scrollTo("session-reading-start"', root)
        self.assertIn("No chat, AI generation", root)
        self.assertIn("No sharing controls are active here", root)
        self.assertIn('reader.scrollTo("editorial-practice"', self.pilot)

    def test_choice_style_is_shared_not_nested_in_the_primary_button(self):
        primary = self.app.split("struct NativePrimaryButton:", 1)[1].split(
            "struct NativeChoiceButtonStyle:", 1
        )[0]
        # Both structs must be siblings for the unqualified choice-style call sites.
        self.assertEqual(primary.count("{"), primary.count("}"))
        root = self.app.split("private struct NativeRoot:", 1)[1].split(
            "struct NativeLessonAudioControls:", 1
        )[0]
        styles = set(re.findall(r"\.buttonStyle\((\w+Style)\(", root))
        self.assertIn("NativeChoiceButtonStyle", styles)
        for style in styles:
            declaration = re.search(
                rf"^([ ]*)(?:(?:private|fileprivate) )?struct {style}:", self.app, re.M
            )
            self.assertIsNotNone(declaration, style)
            # swift-format indents the file-level SwiftUI conditional by four spaces.
            self.assertEqual(declaration[1], "    ", f"{style} must be file-level")
        self.assertIn("style: .continuous", self.app)
        self.assertIn(".symbolRenderingMode(.hierarchical)", self.app)

    def test_editorial_chrome_is_english_without_translating_content(self):
        for marker in (
            '"Content language", value: "French (France)"',
            '"Read lesson aloud"', '"Mark as read"', '"Sources & limits"',
            '"Read again"', '"Revisit formative practice"', '"History not confirmed"',
            "Text(lesson.hook)", "Text(lesson.practice.prompt)",
            "Text(lesson.practice.feedback)", "Text(source.supports)",
            "Text(source.limits)",
        ):
            self.assertIn(marker, self.pilot)
        for old_label in ('"Marquer comme lue"', '"Écouter la leçon"', '"Fermer"'):
            self.assertNotIn(old_label, self.pilot)

    def test_resuming_an_activity_never_reloads_it(self):
        resume = self.app.split("private func resumeCurrentActivity(", 1)[1].split(
            "private func requestPath(", 1
        )[0]
        self.assertNotIn("Task", resume)
        self.assertNotIn("await", resume)
        self.assertIn("resumeTrackID = lesson.trackId", resume)
        self.assertIn("selectedLesson = lesson.id", resume)
        self.assertIn("self.resumeTrackID = nil", self.app)


if __name__ == "__main__":
    unittest.main()
