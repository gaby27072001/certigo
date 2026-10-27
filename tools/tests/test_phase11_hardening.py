import pathlib
import unittest

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
PHASE11_SCREENS = REPO_ROOT / "apps/apple/CertigoKit/Sources/Prism/Screens/PrismPhase11HardeningScreens.swift"
PHASE11_SWIFT_TESTS = REPO_ROOT / "apps/apple/CertigoKit/Tests/CertigoKitTests/Phase11HardeningTests.swift"
PHASE11_REPORT = REPO_ROOT / "docs/transformation/phase-11/REPORT.md"
ANALYTICS_DOC = REPO_ROOT / "docs/transformation/analytics.md"
DEBUG_GALLERY = REPO_ROOT / "apps/apple/CertigoNative/Sources/PrismDebugGalleryView.swift"


class Phase11HardeningTests(unittest.TestCase):
    def test_phase11_files_and_all_phase_reports_exist(self) -> None:
        for path in (PHASE11_SCREENS, PHASE11_SWIFT_TESTS, PHASE11_REPORT, ANALYTICS_DOC, DEBUG_GALLERY):
            self.assertTrue(path.is_file(), f"Missing Phase 11 file: {path}")
        for phase in ("phase-1", "phase-2", "phase-2b", "phase-3", "phase-4", "phase-5", "phase-6", "phase-7", "phase-8", "phase-9", "phase-10", "phase-11"):
            report_path = REPO_ROOT / "docs/transformation" / phase / "REPORT.md"
            self.assertTrue(report_path.is_file(), f"Missing phase report: {report_path}")

    def test_phase11_enforces_accessibility_performance_and_analytics(self) -> None:
        content = PHASE11_SCREENS.read_text(encoding="utf-8")
        for symbol in (
            "public enum AccessibilityDimension",
            "public enum AppStoreAccessibilityNutritionLabel",
            "public struct AccessibilityAuditSummary",
            "public struct PerformanceBudgetSnapshot",
            "public enum NormativeAnalyticsEventName",
            "public struct CriticalJourneyDescriptor",
            "public struct LegacyPathCleanupGovernance",
            "public struct CertiGoOfflinePackEntry",
            "public struct CertiGoOfflinePackManagerModel",
            "public struct Phase11HardeningDashboardScreen",
            "public struct CertiGoOfflineResilienceScreen",
        ):
            self.assertIn(symbol, content)
        analytics_text = ANALYTICS_DOC.read_text(encoding="utf-8")
        for event_name in ("app_opened", "session_started", "daily_situation_completed", "ai_requested", "widget_interaction"):
            self.assertIn(event_name, analytics_text)

    def test_phase11_registered_in_debug_gallery_and_report_complete(self) -> None:
        gallery = DEBUG_GALLERY.read_text(encoding="utf-8")
        self.assertIn("Phase 11 · Accessibility AX5, Budgets §30 & App Store Labels", gallery)
        report = PHASE11_REPORT.read_text(encoding="utf-8")
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
