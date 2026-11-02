from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from PIL import Image

from tools.appstore_connect.generate_appstore_screenshots import (
    RESOLUTIONS,
    SLIDE_THEMES,
    generate_all,
    render_marketing_slide,
)

ROOT = Path(__file__).resolve().parents[2]
FASTLANE_METADATA = ROOT / "apps/apple/fastlane/metadata"
SCREENSHOT_MANIFEST = ROOT / "apps/apple/fastlane/screenshots/manifest.json"


class AppStoreConnectAssetsTests(unittest.TestCase):
    def test_fastlane_metadata_files_respect_apple_limits(self) -> None:
        for locale in ("fr-FR", "en-US"):
            loc_dir = FASTLANE_METADATA / locale
            self.assertTrue(loc_dir.is_dir(), f"Missing locale dir {loc_dir}")

            name = (loc_dir / "name.txt").read_text(encoding="utf-8").strip()
            subtitle = (loc_dir / "subtitle.txt").read_text(encoding="utf-8").strip()
            promo = (loc_dir / "promotional_text.txt").read_text(encoding="utf-8").strip()
            keywords = (loc_dir / "keywords.txt").read_text(encoding="utf-8").strip()
            desc = (loc_dir / "description.txt").read_text(encoding="utf-8").strip()
            support_url = (loc_dir / "support_url.txt").read_text(encoding="utf-8").strip()
            marketing_url = (loc_dir / "marketing_url.txt").read_text(encoding="utf-8").strip()
            privacy_url = (loc_dir / "privacy_url.txt").read_text(encoding="utf-8").strip()

            self.assertEqual(name, "CertiGo")
            self.assertLessEqual(len(subtitle), 30, f"{locale} subtitle exceeds 30 chars")
            self.assertLessEqual(len(promo), 170, f"{locale} promotional_text exceeds 170 chars")
            self.assertLessEqual(len(keywords), 100, f"{locale} keywords exceeds 100 chars")
            self.assertNotIn(", ", keywords, f"{locale} keywords must not have spaces after commas")
            self.assertGreater(len(desc), 400)
            self.assertLessEqual(len(desc), 4000)
            self.assertIn("Core Haptics", desc)
            self.assertTrue(support_url.startswith("https://"))
            self.assertTrue(marketing_url.startswith("https://"))
            self.assertTrue(privacy_url.startswith("https://"))

    def test_minimalist_slide_copy_has_short_headlines(self) -> None:
        self.assertEqual(len(SLIDE_THEMES), 6)
        for slide in SLIDE_THEMES:
            for lang in ("fr", "en"):
                words = slide[lang]["title"].replace("\n", " ").split()
                self.assertLessEqual(
                    len(words),
                    6,
                    f"Slide {slide['slug']} ({lang}) headline must stay minimalist: {words}",
                )

    def test_render_marketing_slide_is_24bit_rgb_without_alpha(self) -> None:
        img = render_marketing_slide(0, "fr-FR", 1320, 2868)
        self.assertEqual(img.mode, "RGB")
        self.assertEqual(img.size, (1320, 2868))

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            summary = generate_all(tmp_path, resolutions=["iphone_69_1320x2868", "ipad_13_2064x2752"])
            self.assertEqual(len(summary["fr-FR"]["iphone_69_1320x2868"]), 6)
            self.assertEqual(len(summary["en-US"]["ipad_13_2064x2752"]), 6)
            sample = tmp_path / "fr-FR" / "iphone_69_1320x2868" / summary["fr-FR"]["iphone_69_1320x2868"][0]["filename"]
            with Image.open(sample) as saved:
                self.assertEqual(saved.mode, "RGB")
                self.assertEqual(saved.size, (1320, 2868))

    def test_screenshot_manifest_is_valid(self) -> None:
        self.assertTrue(SCREENSHOT_MANIFEST.is_file())
        manifest = json.loads(SCREENSHOT_MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(set(manifest.keys()), {"fr-FR", "en-US"})
        self.assertEqual(set(manifest["fr-FR"].keys()), set(RESOLUTIONS.keys()))
        self.assertEqual(len(manifest["fr-FR"]["iphone_69_1320x2868"]), 6)


if __name__ == "__main__":
    unittest.main()
