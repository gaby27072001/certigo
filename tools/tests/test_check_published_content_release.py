from __future__ import annotations

import importlib.util
import json
import os
import shutil
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = (
    Path(__file__).resolve().parents[1] / "check_published_content_release.py"
)
REPO_ROOT = Path(
    os.environ.get("CERTIGO_WORKSPACE", MODULE_PATH.parents[1])
).resolve()
SPEC = importlib.util.spec_from_file_location(
    "check_published_content_release", MODULE_PATH
)
assert SPEC and SPEC.loader
checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = checker
SPEC.loader.exec_module(checker)

REFERENCE = Path("docs/active-content-reference.json")


class CheckPublishedContentReleaseTest(unittest.TestCase):
    def setUp(self) -> None:
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root, True)
        target = self.root / REFERENCE
        target.parent.mkdir(parents=True, exist_ok=True)
        self.reference = json.loads((REPO_ROOT / REFERENCE).read_text(encoding="utf-8"))
        target.write_text(
            json.dumps(self.reference, indent=2) + "\n", encoding="utf-8", newline="\n"
        )

    def descriptor(self, **overrides: object) -> Path:
        body = {
            "schema": checker.RELEASE_SCHEMA,
            "algorithm": checker.RELEASE_ALGORITHM,
            "canonicalization": checker.RELEASE_CANONICALIZATION,
            "publicManifestId": self.reference["manifests"]["public"]["manifestId"],
            "privateManifestId": self.reference["manifests"]["private"]["manifestId"],
        }
        body.update({k: v for k, v in overrides.items() if k != "releaseId"})
        descriptor = {**body, "releaseId": checker._canonical_release_id(body)}
        if "releaseId" in overrides:
            descriptor["releaseId"] = overrides["releaseId"]
        path = self.root / "release.json"
        path.write_text(
            json.dumps(descriptor, indent=2) + "\n", encoding="utf-8", newline="\n"
        )
        return path

    def run_main(self, path: Path) -> int:
        return checker.main(
            ["--root", str(self.root), "--release-descriptor", str(path)]
        )

    def test_accepts_a_release_matching_the_pin(self) -> None:
        self.assertEqual(self.run_main(self.descriptor()), 0)

    def test_detects_public_channel_drift(self) -> None:
        drifted = "sha256:" + "a" * 64
        self.assertEqual(self.run_main(self.descriptor(publicManifestId=drifted)), 1)

    def test_detects_private_channel_drift(self) -> None:
        drifted = "sha256:" + "b" * 64
        self.assertEqual(self.run_main(self.descriptor(privateManifestId=drifted)), 1)

    def test_rejects_a_descriptor_whose_release_id_is_not_its_own_digest(self) -> None:
        forged = "sha256:" + "c" * 64
        self.assertEqual(self.run_main(self.descriptor(releaseId=forged)), 1)

    def test_rejects_an_unexpected_release_schema(self) -> None:
        self.assertEqual(
            self.run_main(self.descriptor(schema="certigo.content.release/v2")), 1
        )

    def test_rejects_extra_descriptor_fields(self) -> None:
        path = self.descriptor()
        descriptor = json.loads(path.read_text(encoding="utf-8"))
        descriptor["publishedAt"] = "2026-09-04T00:00:00Z"
        path.write_text(
            json.dumps(descriptor, indent=2) + "\n", encoding="utf-8", newline="\n"
        )
        self.assertEqual(self.run_main(path), 1)

    def test_rejects_a_missing_descriptor(self) -> None:
        self.assertEqual(self.run_main(self.root / "absent.json"), 1)

    def test_rejects_a_malformed_manifest_identity(self) -> None:
        self.assertEqual(
            self.run_main(self.descriptor(publicManifestId="sha256:NOTHEX")), 1
        )


if __name__ == "__main__":
    unittest.main()
