"""Validate the offline wheel builder with Python's standard library and Git only."""

import hashlib
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from build_parser_wheel import UPSTREAM_SHA256, build, checked_bytes


WHEEL_SHA256 = "8e50661d796af4bc738294db0be82766db625b9490ff6fd59aa11363e437bc0f"


class WheelTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.upstream = Path(os.environ["CHECKOV_UPSTREAM_WHEEL"])
        checked_bytes(cls.upstream, UPSTREAM_SHA256)

    def test_wheel_build_is_reproducible_and_keeps_license(self):
        with tempfile.TemporaryDirectory() as temporary:
            first = build(self.upstream, Path(temporary) / "first")
            second = build(self.upstream, Path(temporary) / "second")
            self.assertEqual(first.read_bytes(), second.read_bytes())
            self.assertEqual(hashlib.sha256(first.read_bytes()).hexdigest(), WHEEL_SHA256)
            with zipfile.ZipFile(self.upstream) as upstream, zipfile.ZipFile(first) as archive:
                licenses = [name for name in archive.namelist() if name.endswith("/LICENSE")]
                originals = [name for name in upstream.namelist() if name.endswith("/LICENSE")]
                self.assertEqual(len(licenses), 1)
                self.assertEqual(len(originals), 1)
                self.assertEqual(archive.read(licenses[0]), upstream.read(originals[0]))

    def test_global_line_endings_and_attributes_do_not_change_output(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            attributes = root / "attributes"
            attributes.write_text("* text eol=crlf\n", encoding="utf-8")
            config = root / "gitconfig"
            for setting in ("true", "false"):
                with self.subTest(autocrlf=setting):
                    config.write_text(
                        f"[core]\n autocrlf = {setting}\n eol = crlf\n"
                        f' attributesFile = "{attributes.as_posix()}"\n',
                        encoding="utf-8",
                    )
                    with patch.dict(os.environ, {"GIT_CONFIG_GLOBAL": str(config)}):
                        wheel = build(self.upstream, root / setting)
                    self.assertEqual(hashlib.sha256(wheel.read_bytes()).hexdigest(), WHEEL_SHA256)

    def test_modified_upstream_wheel_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            modified = Path(temporary) / self.upstream.name
            modified.write_bytes(self.upstream.read_bytes() + b"modified")
            with self.assertRaisesRegex(ValueError, "Unexpected SHA-256"):
                build(modified, Path(temporary) / "output")


if __name__ == "__main__":
    unittest.main(verbosity=2)
