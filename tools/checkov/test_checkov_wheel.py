"""Standard-library tests for the offline conditional-adapter wheel builder."""

import hashlib
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import build_checkov_wheel as builder


WHEEL_SHA256 = "6309f6782d64568ee03648bb8ec7b6e5b0839ccde4f335c4f1cba8f7486e8c69"
CHANGED_SOURCES = {builder.SOURCE, *(entry[0] for entry in builder.RULE_FIXES.values())}


def copy_patches(root, newline=b"\n"):
    for name in ("conditional", *builder.RULE_FIXES):
        original = Path(builder.__file__).with_name(f"checkov-3.2.495-{name}.patch")
        canonical = original.read_bytes().replace(b"\r\n", b"\n")
        (root / original.name).write_bytes(canonical.replace(b"\n", newline))


class WheelTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.upstream = Path(os.environ["CHECKOV_ADAPTER_UPSTREAM_WHEEL"])
        builder.checked_bytes(cls.upstream, builder.UPSTREAM_SHA256)

    def test_only_reviewed_adapter_and_distribution_metadata_change(self):
        with tempfile.TemporaryDirectory() as temporary:
            result = builder.build(self.upstream, Path(temporary))
            self.assertEqual(hashlib.sha256(result.read_bytes()).hexdigest(), WHEEL_SHA256)
            with zipfile.ZipFile(self.upstream) as original, zipfile.ZipFile(result) as modified:
                for name in original.namelist():
                    if name.endswith("/") or name in CHANGED_SOURCES | {builder.OLD_INFO + "RECORD", builder.OLD_INFO + "METADATA"}:
                        continue
                    new_name = name.replace(builder.OLD_INFO, builder.NEW_INFO, 1)
                    self.assertEqual(original.read(name), modified.read(new_name), name)
                self.assertEqual(
                    hashlib.sha256(modified.read(builder.SOURCE)).hexdigest(),
                    builder.PATCHED_SOURCE_SHA256,
                )
                for relative, _, _, digest in builder.RULE_FIXES.values():
                    self.assertEqual(hashlib.sha256(modified.read(relative)).hexdigest(), digest)
                expected = {
                    name.replace(builder.OLD_INFO, builder.NEW_INFO, 1)
                    for name in original.namelist() if not name.endswith("/")
                } | {builder.NEW_INFO + "CERTIGO-PATCH-NOTICE"}
                self.assertEqual(set(modified.namelist()), expected)

    def test_autocrlf_and_patch_checkout_line_endings_keep_exact_wheel(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            attributes = root / "attributes"
            attributes.write_text("* text eol=crlf\n", encoding="utf-8")
            config = root / "gitconfig"
            for setting in ("true", "false"):
                config.write_text(
                    f'[core]\n autocrlf = {setting}\n eol = crlf\n attributesFile = "{attributes.as_posix()}"\n',
                    encoding="utf-8",
                )
                for newline in (b"\n", b"\r\n"):
                    with self.subTest(autocrlf=setting, patch_newline=newline):
                        copy_patches(root, newline)
                        with patch.dict(os.environ, {"GIT_CONFIG_GLOBAL": str(config)}), patch.object(
                            builder, "__file__", str(root / "build_checkov_wheel.py")
                        ):
                            result = builder.build(self.upstream, root / "output")
                        self.assertEqual(hashlib.sha256(result.read_bytes()).hexdigest(), WHEEL_SHA256)

    def test_modified_wheel_and_patch_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            modified = root / self.upstream.name
            modified.write_bytes(self.upstream.read_bytes() + b"modified")
            with self.assertRaisesRegex(ValueError, "Unexpected SHA-256"):
                builder.build(modified, root / "output")
            for name in ("conditional", *builder.RULE_FIXES):
                copy_patches(root)
                source = root / f"checkov-3.2.495-{name}.patch"
                source.write_bytes(source.read_bytes() + b"modified")
                with patch.object(builder, "__file__", str(root / "build_checkov_wheel.py")):
                    with self.assertRaisesRegex(ValueError, "Unexpected canonical LF patch SHA-256"):
                        builder.build(self.upstream, root / "output")


if __name__ == "__main__":
    unittest.main(verbosity=2)
