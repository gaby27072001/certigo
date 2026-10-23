from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
ROUTER_PATH = ROOT / "apps/apple/CertigoKit/Sources/Prism/Navigation/AppRouter.swift"
SCREENS_PATH = ROOT / "apps/apple/CertigoKit/Sources/Prism/Screens/PrismHomeTodayScreens.swift"


class Phase3HomeTodayTests(unittest.TestCase):
    def test_single_router_file_declares_tabs_routes_covers_sheets_and_deep_links(self) -> None:
        self.assertTrue(ROUTER_PATH.is_file())
        text = ROUTER_PATH.read_text(encoding="utf-8")
        for symbol in [
            "public enum AppTab:",
            "public enum AppRoute:",
            "public enum AppFullScreenCoverRoute:",
            "public enum AppSheetRoute:",
            "public struct InterruptedSessionAccessory:",
            "public final class AppRouterState:",
            "public typealias Router = AppRouterState",
            'if host == "auth"',
            'if host == "widget"',
        ]:
            self.assertIn(symbol, text, f"Missing {symbol} in AppRouter.swift")

    def test_phase3_screens_use_brand_label_and_prism_components(self) -> None:
        self.assertTrue(SCREENS_PATH.is_file())
        text = SCREENS_PATH.read_text(encoding="utf-8")
        for symbol in [
            "public struct TodayScreenModel:",
            "public struct TodayRootScreen: View",
            "public struct CatalogExplorerScreen: View",
            "public struct AtlasListMinimalScreen: View",
            "public struct EnsembleMinimalScreen: View",
            "public struct ProfileSkeletonScreen: View",
            "BrandLabel(",
            "SessionLengthPicker(",
            "RhythmWeekView(",
            "PrismOfflineBanner(",
            "PrismSkeleton(",
            "PrismEmptyState(",
            "PrismErrorState(",
        ]:
            self.assertIn(symbol, text, f"Missing {symbol} in PrismHomeTodayScreens.swift")


if __name__ == "__main__":
    unittest.main()
