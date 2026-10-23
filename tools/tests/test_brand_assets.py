import hashlib
import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "apps/apple/CertigoKit/Sources/BrandAssets/Resources/brand-manifest.json"
XCASSETS_DIR = ROOT / "apps/apple/CertigoKit/Sources/BrandAssets/Resources/BrandAssets.xcassets"
REGISTRY_YAML = ROOT / "content/brands/registry.yaml"


class BrandAssetsPhase2BTests(unittest.TestCase):
    def test_manifest_and_xcassets_sha256_integrity_and_budget(self) -> None:
        self.assertTrue(MANIFEST_PATH.is_file())
        self.assertTrue(REGISTRY_YAML.is_file())
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        self.assertEqual(len(manifest["products"]), 132)
        self.assertEqual(len(manifest["icons"]), 80)

        imagesets = list(XCASSETS_DIR.glob("*.imageset"))
        self.assertEqual(len(imagesets), len(manifest["icons"]))

        total_bytes = sum(f.stat().st_size for f in XCASSETS_DIR.rglob("*") if f.is_file())
        self.assertLessEqual(total_bytes, 2 * 1024 * 1024, "BrandAssets exceeds 2 MB budget")

        for icon in manifest["icons"]:
            iset = XCASSETS_DIR / f"{icon['iconId']}.imageset"
            self.assertTrue(iset.is_dir())
            contents = json.loads((iset / "Contents.json").read_text(encoding="utf-8"))
            self.assertEqual(contents["properties"]["template-rendering-intent"], "original")
            self.assertTrue(contents["properties"]["preserves-vector-representation"])

            svg_path = iset / icon["storedFilename"]
            self.assertTrue(svg_path.is_file())
            actual_sha = hashlib.sha256(svg_path.read_bytes()).hexdigest()
            self.assertEqual(actual_sha, icon["sha256"], f"SHA-256 mismatch for {icon['iconId']}")
            self.assertTrue((ROOT / icon["termsSnapshot"]).is_file())

    def test_schemas_support_additive_products_and_registry_covers_all_entries(self) -> None:
        for schema_rel in ["content/schema/lesson.schema.json", "content/schema/track.schema.json"]:
            schema = json.loads((ROOT / schema_rel).read_text(encoding="utf-8"))
            self.assertIn("products", schema["properties"])

        reg_text = REGISTRY_YAML.read_text(encoding="utf-8")
        self.assertIn("vendors:", reg_text)
        self.assertIn("products:", reg_text)
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        for prod in manifest["products"]:
            self.assertIn(f"- id: {prod['id']}", reg_text)
            if prod["status"] == "approved":
                self.assertIsNotNone(prod["icon"])
            else:
                self.assertTrue(prod["fallbackReason"])
                self.assertEqual(prod["decisionRef"], "DR-010")

    def test_legal_notices_and_brand_components_exist(self) -> None:
        self.assertTrue((ROOT / "THIRD_PARTY_NOTICES.md").is_file())
        self.assertTrue((ROOT / "docs/legal/BRAND_ASSETS_CHANGELOG.md").is_file())
        notices = (ROOT / "THIRD_PARTY_NOTICES.md").read_text(encoding="utf-8")
        self.assertIn("CertiGo est une application indépendante", notices)
        self.assertIn("Primer Octicons", notices)

        for fname in [
            "BrandIcon.swift",
            "BrandLabel.swift",
            "BrandFallbackMark.swift",
            "BrandNoticesView.swift",
        ]:
            self.assertTrue(
                (ROOT / "apps/apple/CertigoKit/Sources/Prism/Brand" / fname).is_file(),
                f"Missing {fname}",
            )


if __name__ == "__main__":
    unittest.main()
