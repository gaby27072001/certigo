import pathlib
import unittest

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
PHASE10_SCREENS = REPO_ROOT / "apps/apple/CertigoKit/Sources/Prism/Screens/PrismPhase10OnboardingAndSystemSurfacesScreens.swift"
PHASE10_SWIFT_TESTS = REPO_ROOT / "apps/apple/CertigoKit/Tests/CertigoKitTests/Phase10OnboardingAndSystemSurfacesTests.swift"
PHASE10_REPORT = REPO_ROOT / "docs/transformation/phase-10/REPORT.md"
DEBUG_GALLERY = REPO_ROOT / "apps/apple/CertigoNative/Sources/PrismDebugGalleryView.swift"


class Phase10OnboardingAndSystemSurfacesTests(unittest.TestCase):
    def test_phase10_files_exist(self) -> None:
        for path in (PHASE10_SCREENS, PHASE10_SWIFT_TESTS, PHASE10_REPORT, DEBUG_GALLERY):
            self.assertTrue(path.is_file(), f"Missing Phase 10 file: {path}")

    def test_phase10_screens_enforce_ns1_ns14_pro_and_settings(self) -> None:
        content = PHASE10_SCREENS.read_text(encoding="utf-8")
        required_symbols = [
            "public enum OnboardingStep",
            "public struct OnboardingFlowStateMachine",
            "public struct CertigoProPaywallModel",
            "public enum SettingsSectionDestination",
            "public struct AccountDeletionConfirmationModel",
            "public enum CertigoWidgetSurfaceKind",
            "public struct TodayProgressWidgetSurfaceModel",
            "public struct AIRadarLiveWidgetSurfaceModel",
            "public struct DailySituationWidgetSurfaceModel",
            "public struct ReviewCardWidgetOption",
            "public struct ReviewCardWidgetQueueModel",
            "public enum CertigoLiveActivityKind",
            "public struct CertigoLiveActivityState",
            "public struct ExpressSessionControlWidgetModel",
            "public enum CertigoAppIntentKind",
            "public struct CertigoSpotlightConceptEntity",
            "public struct OnboardingFlowCoverScreen",
            "public struct CertigoProSheetScreen",
            "public struct CompleteSettingsScreen",
            "public struct SystemSurfacesPreviewScreen",
        ]
        for symbol in required_symbols:
            self.assertIn(symbol, content, f"Missing symbol in Phase 10 screens: {symbol}")
        self.assertIn("public static let maxScreensBeforeFirstDecision: Int = 2", content)
        self.assertIn("BrandLabel(", content)

    def test_phase10_registered_in_debug_gallery_and_report_complete(self) -> None:
        gallery = DEBUG_GALLERY.read_text(encoding="utf-8")
        self.assertIn("Phase 10 · Onboarding 60s, Pro StoreKit 2, Settings & iOS Surfaces", gallery)
        report = PHASE10_REPORT.read_text(encoding="utf-8")
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
