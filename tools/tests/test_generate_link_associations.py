from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "generate_link_associations.py"
SPEC = importlib.util.spec_from_file_location("generate_link_associations", MODULE_PATH)
assert SPEC and SPEC.loader
generator = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = generator
SPEC.loader.exec_module(generator)


def fingerprint(byte: str = "AB") -> str:
    return ":".join([byte] * 32)


class GenerateLinkAssociationsTests(unittest.TestCase):
    def test_writes_both_files_with_verified_inputs(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            apple_path, android_path = generator.write_associations(
                output_dir=Path(temporary),
                domain="certigo.app",
                apple_team_id="ABCDEFGHIJ",
                bundle_id="com.certigo.mobileapp",
                android_fingerprints=[fingerprint()],
            )

            apple = json.loads(apple_path.read_text(encoding="utf-8"))
            android = json.loads(android_path.read_text(encoding="utf-8"))

            self.assertEqual(
                apple["applinks"]["details"][0]["appIDs"],
                ["ABCDEFGHIJ.com.certigo.mobileapp"],
            )
            self.assertEqual(
                apple["applinks"]["details"][0]["components"][0]["/"],
                "/learn/*/*",
            )
            self.assertEqual(
                android[0]["target"]["package_name"],
                "com.certigo.mobileapp",
            )
            self.assertEqual(
                android[0]["target"]["sha256_cert_fingerprints"],
                [fingerprint()],
            )
            self.assertEqual(apple_path.name, "apple-app-site-association")
            self.assertEqual(android_path.name, "assetlinks.json")

    def test_pages_prefix_is_applied_to_apple_routes(self) -> None:
        apple, _ = generator.association_payloads(
            apple_team_id="ABCDEFGHIJ",
            bundle_id="com.certigo.mobileapp",
            android_fingerprints=[fingerprint("CD")],
            path_prefix="/Certigo",
        )

        paths = [
            component["/"]
            for component in apple["applinks"]["details"][0]["components"]
        ]
        self.assertEqual(
            paths,
            [
                "/Certigo/learn/*/*",
                "/Certigo/assignments/*",
                "/Certigo/achievements/*",
                "/Certigo/account-deletion",
            ],
        )

    def test_rejects_unverified_or_malformed_identifiers(self) -> None:
        with self.assertRaisesRegex(ValueError, "Team ID"):
            generator.association_payloads(
                apple_team_id="<APPLE_TEAM_ID>",
                bundle_id="com.certigo.mobileapp",
                android_fingerprints=[fingerprint()],
            )
        with self.assertRaisesRegex(ValueError, "SHA-256"):
            generator.association_payloads(
                apple_team_id="ABCDEFGHIJ",
                bundle_id="com.certigo.mobileapp",
                android_fingerprints=["not-a-fingerprint"],
            )
        with self.assertRaisesRegex(ValueError, "hostname"):
            generator.write_associations(
                output_dir=Path("."),
                domain="https://certigo.app",
                apple_team_id="ABCDEFGHIJ",
                bundle_id="com.certigo.mobileapp",
                android_fingerprints=[fingerprint()],
            )


if __name__ == "__main__":
    unittest.main()
