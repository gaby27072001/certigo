import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("native_ciam_scheme", ROOT / "tools/native_ciam_scheme.py")
scheme = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(scheme)
SHARED = ROOT / "apps/apple/CertigoNative/CertigoNative.xcodeproj/xcshareddata/xcschemes/CertigoNative.xcscheme"


class NativeCIAMSchemeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        subprocess.run(["git", "init", "--quiet", str(self.root)], check=True)
        subprocess.run(["git", "config", "core.autocrlf", "false"], cwd=self.root, check=True)
        (self.root / ".gitignore").write_text("xcuserdata/\n", encoding="utf-8")
        self.project = self.root / "CertigoNative.xcodeproj"
        self.shared = self.project / "xcshareddata/xcschemes/CertigoNative.xcscheme"
        self.shared.parent.mkdir(parents=True)
        self.shared.write_bytes(SHARED.read_bytes())
        self.values = {key: "fixture" for key in scheme.KEYS}
        self.values.update({
            "CERTIGO_CIAM_ENABLED": "true",
            "CERTIGO_CIAM_AUTHORITY_KIND": "standard",
            "CERTIGO_CIAM_REDIRECT_URI": "msauth.com.certigo.native.dev://auth",
        })
        self.config = self.root / "config.json"
        self.write_config()

    def write_config(self):
        self.config.write_text(json.dumps(self.values), encoding="utf-8")

    def create(self):
        return scheme.create_scheme(self.project, scheme.load_values(self.config), "fixture")

    def test_creates_only_ignored_local_run_environment_preserving_shared_and_other_actions(self):
        before = self.shared.read_bytes()
        target = self.create()
        self.assertEqual(self.shared.read_bytes(), before)
        original, local = ET.fromstring(before), ET.fromstring(target.read_bytes())
        env = local.find("LaunchAction/EnvironmentVariables")
        self.assertEqual({e.get("key"): e.get("value") for e in env}, self.values)
        self.assertTrue(all(e.get("isEnabled") == "YES" for e in env))
        local.find("LaunchAction").remove(env)
        ET.indent(original, space="   ")
        ET.indent(local, space="   ")
        self.assertEqual(ET.tostring(original), ET.tostring(local))
        visible = subprocess.check_output(
            ["git", "ls-files", "--others", "--exclude-standard"], cwd=self.root
        ).decode()
        self.assertNotIn("CertigoNative Local", visible)
        if os.name != "nt":
            self.assertEqual(target.stat().st_mode & 0o777, 0o600)

    def test_never_overwrites_existing_local_scheme(self):
        target = self.create()
        target.write_bytes(b"USER EDITS")
        with self.assertRaises(FileExistsError):
            self.create()
        self.assertEqual(target.read_bytes(), b"USER EDITS")

    def test_rejects_missing_extra_secret_duplicate_and_nonliteral_values(self):
        for key, value in (
            ("CLIENT_SECRET", "must-not-be-saved"),
            ("CERTIGO_CIAM_API_SCOPE", "api://fixture/user\\_impersonation"),
            ("CERTIGO_CIAM_CLIENT_ID", "$(SECRET)"),
            ("CERTIGO_CIAM_CLIENT_ID", "two words"),
            ("CERTIGO_CIAM_ENABLED", True),
            ("CERTIGO_CIAM_ENABLED", "false"),
            ("CERTIGO_CIAM_AUTHORITY_KIND", "unknown"),
            ("CERTIGO_CIAM_REDIRECT_URI", "msauth.com.certigo.native.dev://auth/"),
        ):
            with self.subTest(key=key, value=value):
                self.config.write_text(json.dumps(self.values | {key: value}), encoding="utf-8")
                with self.assertRaises(ValueError):
                    scheme.load_values(self.config)
        self.config.write_text('{"CERTIGO_CIAM_ENABLED":"true","CERTIGO_CIAM_ENABLED":"true"}')
        with self.assertRaises(ValueError):
            scheme.load_values(self.config)
        self.config.write_text("{}")
        with self.assertRaises(ValueError):
            scheme.load_values(self.config)
        self.assertFalse((self.project / "xcuserdata").exists())

    def test_refuses_non_debug_or_ambiguous_shared_action_before_writing(self):
        original = self.shared.read_bytes()
        for data in (
            original.replace(b'<LaunchAction\n      buildConfiguration = "Debug"', b'<LaunchAction\n      buildConfiguration = "Release"'),
            b"<Scheme><LaunchAction/><LaunchAction/></Scheme>",
            b'<!DOCTYPE Scheme><Scheme/>',
        ):
            self.shared.write_bytes(data)
            with self.assertRaises(ValueError):
                self.create()
        self.assertFalse((self.project / "xcuserdata").exists())

    def test_refuses_unignored_or_tracked_destination(self):
        (self.root / ".gitignore").write_text("")
        with self.assertRaises(ValueError):
            self.create()
        self.assertFalse((self.project / "xcuserdata").exists())
        (self.root / ".gitignore").write_text("xcuserdata/\n")
        target = self.create()
        subprocess.run(["git", "add", "--force", str(target)], cwd=self.root, check=True)
        with self.assertRaises(ValueError):
            self.create()

    def test_repository_ignores_only_named_local_scheme_not_other_user_data(self):
        project = ROOT / "apps/apple/CertigoNative/CertigoNative.xcodeproj"
        base = project / "xcuserdata/fixture.xcuserdatad"
        for suffix, expected in (
            ("xcschemes/CertigoNative Local.xcscheme", 0),
            ("xcschemes/Other.xcscheme", 1),
            ("UserInterfaceState.xcuserstate", 1),
        ):
            with self.subTest(path=suffix):
                result = subprocess.run(
                    ["git", "check-ignore", "--quiet", "--", str(base / suffix)],
                    cwd=ROOT, capture_output=True,
                )
                self.assertEqual(result.returncode, expected)

    def test_refuses_path_traversal_username(self):
        with self.assertRaises(ValueError):
            scheme.create_scheme(self.project, self.values, "../other")
        self.assertFalse((self.project / "xcuserdata").exists())

    @unittest.skipIf(os.name == "nt", "Unix symlink creation does not require elevated permissions")
    def test_refuses_symlinked_user_directory_or_existing_file(self):
        outside = self.root / "outside"
        outside.mkdir()
        (self.project / "xcuserdata").symlink_to(outside, target_is_directory=True)
        with self.assertRaises(ValueError):
            self.create()
        self.assertEqual(list(outside.iterdir()), [])
        (self.project / "xcuserdata").unlink()
        destination = self.project / "xcuserdata/fixture.xcuserdatad/xcschemes"
        destination.mkdir(parents=True)
        (destination / "CertigoNative Local.xcscheme").symlink_to(outside / "absent")
        with self.assertRaises(FileExistsError):
            self.create()
        self.assertFalse((outside / "absent").exists())

    def test_cli_failure_does_not_disclose_input_values(self):
        self.config.write_text('{"sensitive": "must-not-appear"', encoding="utf-8")
        result = subprocess.run(
            [
                os.sys.executable, "-P", str(ROOT / "tools/native_ciam_scheme.py"),
                "--config", str(self.config), "--project", str(self.project),
            ],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("STOP:", result.stderr)
        self.assertNotIn("must-not-appear", result.stderr + result.stdout)

    def test_preserves_unrelated_shared_environment_and_rejects_shared_ciam(self):
        tree = ET.fromstring(self.shared.read_bytes())
        environment = ET.SubElement(tree.find("LaunchAction"), "EnvironmentVariables")
        ET.SubElement(environment, "EnvironmentVariable", key="UNRELATED", value="1", isEnabled="NO")
        self.shared.write_bytes(ET.tostring(tree))
        target = self.create()
        self.assertEqual(
            ET.fromstring(target.read_bytes()).find(
                "LaunchAction/EnvironmentVariables/EnvironmentVariable"
            ).attrib,
            {"key": "UNRELATED", "value": "1", "isEnabled": "NO"},
        )
        ET.SubElement(environment, "EnvironmentVariable", key="CERTIGO_CIAM_ENABLED", value="false")
        self.shared.write_bytes(ET.tostring(tree))
        with self.assertRaises(ValueError):
            self.create()


if __name__ == "__main__":
    unittest.main()
