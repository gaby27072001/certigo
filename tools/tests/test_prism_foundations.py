import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
PRISM = ROOT / "apps/apple/CertigoKit/Sources/Prism"


class PrismFoundationsTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("swiftc"), "Swift is required for Release API verification")
    def test_release_compiler_rejects_debug_override_api(self):
        with tempfile.TemporaryDirectory() as directory:
            probe = Path(directory) / "main.swift"
            probe.write_text(
                "var flags = FeatureFlags()\nflags.setDebugOverride(true, for: .prism)\n"
            )
            result = subprocess.run(
                [
                    "swiftc", "-swift-version", "6", "-warnings-as-errors",
                    str(ROOT / "apps/apple/CertigoKit/Sources/CertigoDomain/FeatureFlags.swift"),
                    str(probe), "-o", str(Path(directory) / "release-probe"),
                ],
                capture_output=True, text=True, timeout=90,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("has no member 'setDebugOverride'", result.stderr)

    def test_catalog_matches_every_swift_role_and_all_four_appearances(self):
        spec = importlib.util.spec_from_file_location(
            "generate_prism_assets", ROOT / "tools/generate_prism_assets.py"
        )
        generator = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(generator)
        expected = dict(generator.palettes())
        self.assertEqual(len(expected), 30)
        catalog = PRISM / "Resources/Prism.xcassets"
        self.assertEqual({path.stem for path in catalog.glob("*.colorset")}, set(expected))
        for role, values in expected.items():
            actual = json.loads((catalog / f"{role}.colorset/Contents.json").read_text())
            self.assertEqual(actual, generator.contents(role, values), role)

    def test_gallery_and_its_only_entry_are_debug_only(self):
        sources = ROOT / "apps/apple/CertigoNative/Sources"
        gallery = (sources / "PrismDebugGalleryView.swift").read_text(encoding="utf-8")
        self.assertTrue(gallery.startswith("#if DEBUG && canImport(SwiftUI)"))
        self.assertTrue(gallery.rstrip().endswith("#endif"))
        app = (sources / "CertigoNativeApp.swift").read_text(encoding="utf-8")
        self.assertRegex(
            app, r"#if DEBUG\s+\.modifier\(PrismDebugGalleryLauncher\(\)\)\s+#endif"
        )
        self.assertIn("flags.applyRemoteJSON", gallery)
        self.assertIn("flags.saveDebugOverrides", gallery)
        self.assertIn("configurationError = true", gallery)
        for component in (
            "CertiGoSpeechBubbleHeaderView(",
            "CertiGoOfficialCrestView(",
            "CertiGoBrandLogoView(",
            "CertiGoMascotView(",
            "CertiGoMascotPose.allCases",
            "CertiGoOfficialAssetCatalog.certificationAssetName",
        ):
            self.assertIn(component, gallery, component)

    def test_prism_catalog_exposes_900_namespaced_official_assets_and_xcode_links_prism(self):
        catalog = PRISM / "Resources/Prism.xcassets"
        expected_folders = {
            "AWSServices": 287,
            "AzureServices": 291,
            "BrandLogos": 32,
            "Certifications": 52,
            "GCPServices": 214,
            "Mascots": 24,
        }
        total = 0
        for folder, expected_count in expected_folders.items():
            folder_dir = catalog / folder
            self.assertTrue(folder_dir.is_dir(), folder)
            folder_meta = json.loads((folder_dir / "Contents.json").read_text(encoding="utf-8"))
            self.assertTrue(folder_meta.get("properties", {}).get("provides-namespace"), folder)
            imagesets = list(folder_dir.glob("*.imageset"))
            self.assertEqual(len(imagesets), expected_count, folder)
            total += len(imagesets)
        self.assertEqual(total, 900)
        pbxproj = (
            ROOT / "apps/apple/CertigoNative/CertigoNative.xcodeproj/project.pbxproj"
        ).read_text(encoding="utf-8")
        self.assertIn("000000000000000000000101 /* Prism in Frameworks */", pbxproj)
        self.assertIn("000000000000000000000102 /* Prism */", pbxproj)
        self.assertIn("000000000000000000000103 /* PrismDebugGalleryView.swift in Sources */", pbxproj)

    def test_extracted_shared_types_are_visible_across_files(self):
        source = (
            ROOT / "apps/apple/CertigoNative/Sources/NativeSharedComponents.swift"
        ).read_text()
        for name in (
            "NativeShowcaseTile", "NativeDeveloperToolbar",
            "NativePracticeBadge", "NativeCatalogSearch",
        ):
            self.assertRegex(source, rf"(?m)^    struct {name}\b")

    def test_debug_overrides_are_not_release_api(self):
        source = (ROOT / "apps/apple/CertigoKit/Sources/CertigoDomain/FeatureFlags.swift").read_text()
        block = source.split("public mutating func setDebugOverride", 1)[0]
        self.assertGreater(block.rfind("#if DEBUG"), block.rfind("#endif"))
        self.assertIn("guard !remoteDisabled.contains(flag)", source)
        harness = (PRISM / "PrismSnapshotHarness.swift").read_text()
        self.assertIn("ImageRenderer(", harness)
        self.assertIn("CGContext(", harness)
        self.assertIn("public func matches", harness)
        package = (ROOT / "apps/apple/CertigoKit/Package.swift").read_text()
        self.assertNotIn("SnapshotTesting", package)
        self.assertIn('.testTarget(\n            name: "ArchitectureTests"', package)

    def test_architecture_baseline_has_only_documented_legacy_files(self):
        baseline = json.loads(
            (ROOT / "apps/apple/CertigoKit/Tests/ArchitectureTests/LegacyExceptions.json").read_text()
        )
        self.assertTrue(baseline)
        legacy = {
            "CertigoWidgetPresentation.swift", "NativeDemoViews.swift", "NativeEditorialPilotView.swift",
            "NativeEntryViews.swift", "NativeLessonAudioViews.swift", "NativeRootView.swift",
            "NativeSharedComponents.swift", "NativeStudyAndExamViews.swift", "NativeWidgetGalleryView.swift",
        }
        for key, count in baseline.items():
            path, rule, _ = key.split("|", 2)
            self.assertTrue(path.startswith("apps/apple/CertigoNative/Sources/"))
            self.assertIn(Path(path).name, legacy)
            self.assertGreater(count, 0)
            self.assertIn(rule, {"color", "type", "layout", "motion", "haptic", "literal", "print"})
