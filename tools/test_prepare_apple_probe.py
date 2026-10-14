import contextlib
import io
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import prepare_apple_probe as lot
from validate_apple_noauth import (
    DEV_BUNDLE, PROBE_BUNDLE, probe_bundles, validate_probe_plist, validate_probe_entitlements,
)


class PrivateProbeLotTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / lot.LOCAL).parent.mkdir(parents=True)
        self.source = "a" * 40
        self.team = "B" * 10
        self.device = "synthetic-device-only"

    def prepare(self):
        with patch.object(lot, "check_source"), patch.object(lot.secrets, "token_hex",
                                                           return_value="ab" * 16) as random:
            manifest, checksum = lot.prepare(self.root, self.source, self.team, self.device)
            random.assert_called_once_with(16)
        return manifest, checksum

    def verify(self, checksum=None, active=False):
        with patch.object(lot, "check_source"):
            return lot.verify(self.root, checksum, active)

    def test_unsigned_lot_binds_source_ids_private_selections_and_exact_tests(self):
        manifest, checksum = self.prepare()
        checked, actual = self.verify(checksum)
        self.assertEqual((checked, actual), (manifest, checksum))
        self.assertEqual(manifest["source"], self.source)
        self.assertEqual(manifest["team"], self.team)
        self.assertEqual(manifest["device"], self.device)
        self.assertEqual(len(manifest["selectors"]), 2)
        self.assertFalse((self.root / lot.LOCAL / "Execution.xcconfig").exists())
        self.assertNotIn(b"YES", (self.root / lot.LOCAL / "ProbeLot.xcconfig").read_bytes())
        with self.assertRaises(ValueError):
            self.verify(checksum, active=True)

    def test_existing_or_partial_lot_never_generates_another_suffix(self):
        self.prepare()
        with patch.object(lot, "check_source"), patch.object(lot.secrets, "token_hex") as random:
            with self.assertRaises(FileExistsError):
                lot.prepare(self.root, self.source, self.team, self.device)
            random.assert_not_called()

    def test_invalid_suffixes_and_old_or_other_lot_identities_stop(self):
        for suffix in (None, "", "AB" * 16, "ab" * 15, "ab" * 17, "../" + "a" * 29,
                       "$(OTHER)", "a" * 31 + "\n"):
            with self.subTest(suffix=suffix), self.assertRaises(ValueError):
                probe_bundles(suffix)
        suffix = "ab" * 16
        host, tests = probe_bundles(suffix)
        validate_probe_plist({"CFBundleIdentifier": host}, test=False, lot_suffix=suffix)
        validate_probe_plist({"CFBundleIdentifier": tests}, test=True, lot_suffix=suffix)
        for bundle in (PROBE_BUNDLE, DEV_BUNDLE, host + ".tests", probe_bundles("cd" * 16)[0]):
            with self.subTest(bundle=bundle), self.assertRaises(ValueError):
                validate_probe_plist({"CFBundleIdentifier": bundle}, test=False, lot_suffix=suffix)
        for bundle in (host, tests):
            application = "C" * 10 + "." + bundle
            validate_probe_entitlements(
                {"application-identifier": application, "get-task-allow": True,
                 "com.apple.developer.team-identifier": self.team},
                bundle=bundle, team=self.team, prefix="C" * 10, lot_suffix=suffix,
            )
            with self.assertRaises(ValueError):
                validate_probe_entitlements(
                    {}, bundle=bundle, team=self.team, prefix="C" * 10, lot_suffix="cd" * 16,
                )

    def test_edited_config_or_manifest_or_wrong_approval_stop(self):
        manifest, checksum = self.prepare()
        directory = self.root / lot.LOCAL
        with self.assertRaises(ValueError):
            self.verify("0" * 64)
        config = directory / "ProbeLot.xcconfig"
        original = config.read_bytes()
        config.write_bytes(original.replace(b"ab" * 16, b"cd" * 16))
        with self.assertRaises(ValueError):
            self.verify(checksum)
        config.write_bytes(original)
        manifest["selectors"].pop()
        (directory / "manifest.json").write_bytes(lot.canonical(manifest))
        with self.assertRaises(ValueError):
            self.verify(checksum)
        # Even a recomputed local checksum does not change the separately approved checksum.
        (directory / "manifest.sha256").write_text(lot.digest(lot.canonical(manifest)) + "\n")
        with self.assertRaises(ValueError):
            self.verify(checksum)

    def test_enabled_build_requires_exact_approved_digest_and_execution_config(self):
        manifest, checksum = self.prepare()
        directory = self.root / lot.LOCAL
        lot.write_new(directory / "Execution.xcconfig", lot.execution(self.team))
        with self.assertRaises(ValueError):
            self.verify(checksum, active=True)
        lot.write_new(directory / "approved.sha256", (checksum + "\n").encode())
        self.assertEqual(self.verify(checksum, active=True)[0], manifest)
        with self.assertRaises(FileExistsError):
            lot.write_new(directory / "Execution.xcconfig", b"replacement")
        (directory / "Execution.xcconfig").write_bytes(lot.execution("C" * 10))
        with self.assertRaises(ValueError):
            self.verify(checksum, active=True)

    def test_exact_clean_source_and_source_validator_are_required(self):
        with patch.object(lot, "git", side_effect=[self.source, ""]), \
                patch.object(lot, "validate_source") as validate:
            lot.check_source(self.root, self.source)
            validate.assert_called_once_with(self.root)
        for answers in ([self.source, " M tracked"], ["b" * 40]):
            with patch.object(lot, "git", side_effect=answers), self.assertRaises(ValueError):
                lot.check_source(self.root, self.source)
        with patch.object(lot, "git", return_value=self.source), self.assertRaises(ValueError):
            lot.check_source(self.root, "main")

    def test_effective_build_settings_cannot_swap_host_test_or_team(self):
        manifest, _ = self.prepare()
        environment = {
            "PROBE_LOT_SUFFIX": manifest["suffix"], "TARGET_NAME": "CertigoProtectionProbe",
            "PRODUCT_BUNDLE_IDENTIFIER": manifest["host"],
            "PROBE_HOST_BUNDLE_IDENTIFIER": manifest["host"],
            "PROBE_TEST_BUNDLE_IDENTIFIER": manifest["tests"],
            "DEVELOPMENT_TEAM": manifest["team"], "CODE_SIGNING_ALLOWED": "YES",
        }
        lot.verify_build(manifest, environment)
        for key, value in (
            ("PROBE_LOT_SUFFIX", ""), ("PROBE_LOT_SUFFIX", "cd" * 16),
            ("TARGET_NAME", "CertigoNative"), ("DEVELOPMENT_TEAM", "C" * 10),
            ("PRODUCT_BUNDLE_IDENTIFIER", manifest["tests"]),
            ("PROBE_HOST_BUNDLE_IDENTIFIER", PROBE_BUNDLE),
            ("PROBE_TEST_BUNDLE_IDENTIFIER", manifest["host"]),
            ("CODE_SIGNING_ALLOWED", "NO"),
        ):
            with self.subTest(key=key), self.assertRaises(ValueError):
                lot.verify_build(manifest, {**environment, key: value})
        lot.verify_build(manifest, {
            **environment, "TARGET_NAME": "CertigoProtectionProbeTests",
            "PRODUCT_BUNDLE_IDENTIFIER": manifest["tests"],
        })

    def test_invalid_private_selections_stop_before_creation_or_random_generation(self):
        for team, device in (
            ("", self.device), ("Personal Team", self.device),
            ("b" * 10, self.device), (self.team, ""), (self.team, "$(INJECT)"),
        ):
            with patch.object(lot, "check_source"), patch.object(lot.secrets, "token_hex") as random:
                with self.subTest(team=team, device=device), self.assertRaises(ValueError):
                    lot.prepare(self.root, self.source, team, device)
                random.assert_not_called()
                self.assertFalse((self.root / lot.LOCAL).exists())

    def test_prepare_enable_and_build_cli_bind_a_real_clean_synthetic_git_checkout(self):
        def git(*args):
            return subprocess.check_output(
                ["git", "-C", str(self.root), *args], stderr=subprocess.PIPE,
            ).decode().strip()

        git("init", "--quiet")
        (self.root / ".gitignore").write_text(str(lot.LOCAL).replace("\\", "/") + "/\n")
        git("add", ".gitignore")
        git("-c", "user.name=Synthetic fixture", "-c", "user.email=fixture@example.invalid",
            "commit", "--quiet", "-m", "Synthetic fixture")
        source = git("rev-parse", "HEAD")
        output = io.StringIO()

        def cli(*args):
            with patch("sys.argv", ["prepare_apple_probe.py", *args]), \
                    patch.object(lot, "__file__", str(self.root / "tools" / "prepare_apple_probe.py")), \
                    patch.object(lot, "validate_source"), contextlib.redirect_stdout(output):
                lot.main()

        with patch.object(lot.getpass, "getpass", side_effect=[self.team, self.device]), \
                patch.object(lot.secrets, "token_hex", return_value="ab" * 16):
            cli("prepare", "--source-sha", source)
        directory = self.root / lot.LOCAL
        manifest = json.loads((directory / "manifest.json").read_bytes())
        checksum = (directory / "manifest.sha256").read_text().strip()
        with self.assertRaises(ValueError):
            cli("enable", "--approved-manifest-sha256", "0" * 64,
                "--accept-standard-ios-and-collision-risk")
        self.assertFalse((directory / "Execution.xcconfig").exists())
        cli("enable", "--approved-manifest-sha256", checksum,
            "--accept-standard-ios-and-collision-risk")
        with patch.dict(os.environ, {
            "TARGET_NAME": "CertigoProtectionProbe",
            "PROBE_LOT_SUFFIX": manifest["suffix"],
            "PROBE_HOST_BUNDLE_IDENTIFIER": manifest["host"],
            "PROBE_TEST_BUNDLE_IDENTIFIER": manifest["tests"],
            "PRODUCT_BUNDLE_IDENTIFIER": manifest["host"],
            "CODE_SIGNING_ALLOWED": "YES", "DEVELOPMENT_TEAM": self.team,
        }):
            cli("verify-build")
        self.assertNotIn(self.team, output.getvalue())
        self.assertNotIn(self.device, output.getvalue())
        self.assertEqual(git("status", "--porcelain"), "")
        (self.root / ".gitignore").write_text("# changed source\n")
        with self.assertRaises(ValueError):
            cli("verify")

    @unittest.skipUnless(os.name == "posix", "POSIX private permissions/symlinks")
    def test_symlinked_or_nonprivate_files_and_lot_directory_stop(self):
        _, checksum = self.prepare()
        directory = self.root / lot.LOCAL
        config = directory / "ProbeLot.xcconfig"
        config.chmod(0o644)
        with self.assertRaises(ValueError):
            self.verify(checksum)
        config.chmod(0o600)
        target = directory / "synthetic-link-target"
        config.rename(target)
        config.symlink_to(target)
        with self.assertRaises(ValueError):
            self.verify(checksum)


if __name__ == "__main__":
    unittest.main()
