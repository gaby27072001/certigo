import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
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
        for tag in ("TestAction", "ProfileAction"):
            original.find(tag).set("shouldUseLaunchSchemeArgsEnv", "NO")
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

    def test_refuses_unknown_or_ambiguous_shared_action_before_writing(self):
        original = self.shared.read_bytes()
        for data in (
            original.replace(b'<LaunchAction\n      buildConfiguration = "Debug"', b'<LaunchAction\n      buildConfiguration = "Unknown"'),
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

    def test_release_run_and_optional_profile_name_preserve_identity_and_other_settings(self):
        tree = ET.fromstring(self.shared.read_bytes())
        launch = tree.find("LaunchAction")
        launch.set("buildConfiguration", "Release")
        profile_ref = tree.find("ProfileAction/BuildableProductRunnable/BuildableReference")
        del profile_ref.attrib["BlueprintName"]
        profile_attributes = dict(profile_ref.attrib)
        environment = ET.SubElement(launch, "EnvironmentVariables")
        ET.SubElement(environment, "EnvironmentVariable", key="EXISTING", value="keep", isEnabled="YES")
        arguments = ET.SubElement(launch, "CommandLineArguments")
        ET.SubElement(arguments, "CommandLineArgument", argument="--keep", isEnabled="YES")
        self.shared.write_bytes(ET.tostring(tree))
        before = self.shared.read_bytes()
        project_file = self.project / "project.pbxproj"
        project_file.write_bytes(b"existing local signing settings")
        target = self.create()
        local = ET.fromstring(target.read_bytes())
        self.assertEqual("Debug", local.find("LaunchAction").get("buildConfiguration"))
        self.assertEqual(before, self.shared.read_bytes())
        self.assertEqual(b"existing local signing settings", project_file.read_bytes())
        self.assertEqual(profile_attributes, local.find(
            "ProfileAction/BuildableProductRunnable/BuildableReference"
        ).attrib)
        self.assertEqual("Release", local.find("ProfileAction").get("buildConfiguration"))
        for tag in ("TestAction", "ProfileAction"):
            action = local.find(tag)
            self.assertEqual("NO", action.get("shouldUseLaunchSchemeArgsEnv"))
            self.assertEqual(
                {"EXISTING": "keep"},
                {node.get("key"): node.get("value") for node in action.findall(
                    "EnvironmentVariables/EnvironmentVariable"
                )},
            )
            self.assertEqual("--keep", action.find(
                "CommandLineArguments/CommandLineArgument"
            ).get("argument"))
        self.assertEqual(self.values, {
            node.get("key"): node.get("value")
            for node in local.findall("LaunchAction/EnvironmentVariables/EnvironmentVariable")
            if node.get("key", "").startswith("CERTIGO_CIAM_")
        })
        with self.assertRaises(FileExistsError):
            self.create()

    def test_profile_reference_must_match_run_even_when_name_is_absent(self):
        original = self.shared.read_bytes()
        for key, value in (
            ("BlueprintIdentifier", "different-target"),
            ("BuildableName", "Other.app"),
            ("ReferencedContainer", "container:Other.xcodeproj"),
            ("BlueprintName", "Other"),
        ):
            with self.subTest(key=key):
                tree = ET.fromstring(original)
                ref = tree.find("ProfileAction/BuildableProductRunnable/BuildableReference")
                del ref.attrib["BlueprintName"]
                ref.set(key, value)
                self.shared.write_bytes(ET.tostring(tree))
                with self.assertRaises(ValueError):
                    self.create()
        tree = ET.fromstring(original)
        runner = tree.find("ProfileAction/BuildableProductRunnable")
        runner.remove(runner.find("BuildableReference"))
        self.shared.write_bytes(ET.tostring(tree))
        with self.assertRaises(ValueError):
            self.create()
        self.assertFalse((self.project / "xcuserdata").exists())

    def test_publish_is_complete_and_never_overwrites_a_concurrent_file(self):
        real_link = os.link
        def concurrent_link(source, target):
            self.assertIn(b"CERTIGO_CIAM_ENABLED", Path(source).read_bytes())
            Path(target).write_bytes(b"CONCURRENT USER EDITS")
            real_link(source, target)
        with patch.object(scheme.os, "link", side_effect=concurrent_link):
            with self.assertRaises(FileExistsError):
                self.create()
        destination = self.project / "xcuserdata/fixture.xcuserdatad/xcschemes"
        self.assertEqual(
            b"CONCURRENT USER EDITS", (destination / "CertigoNative Local.xcscheme").read_bytes()
        )
        self.assertEqual([], list(destination.glob(".certigo-ciam-*.tmp")))

    def test_preserves_explicit_noninherited_profile_settings(self):
        tree = ET.fromstring(self.shared.read_bytes())
        profile = tree.find("ProfileAction")
        profile.set("shouldUseLaunchSchemeArgsEnv", "NO")
        environment = ET.SubElement(profile, "EnvironmentVariables")
        ET.SubElement(environment, "EnvironmentVariable", key="PROFILE_ONLY", value="keep")
        self.shared.write_bytes(ET.tostring(tree))
        before = self.shared.read_bytes()
        target = self.create()
        actual = ET.fromstring(target.read_bytes()).find("ProfileAction")
        ET.indent(profile, space="   ")
        ET.indent(actual, space="   ")
        self.assertEqual(ET.tostring(profile), ET.tostring(actual))
        self.assertEqual(before, self.shared.read_bytes())

    def test_rejects_ambiguous_inheritance_and_existing_ciam_outside_run(self):
        original = self.shared.read_bytes()
        for tag in ("TestAction", "ProfileAction"):
            for key, inherit in (("UNRELATED", "YES"), ("CERTIGO_CIAM_ENABLED", "NO")):
                with self.subTest(tag=tag, key=key):
                    tree = ET.fromstring(original)
                    action = tree.find(tag)
                    action.set("shouldUseLaunchSchemeArgsEnv", inherit)
                    environment = ET.SubElement(action, "EnvironmentVariables")
                    ET.SubElement(environment, "EnvironmentVariable", key=key, value="true")
                    self.shared.write_bytes(ET.tostring(tree))
                    with self.assertRaises(ValueError):
                        self.create()
        self.assertFalse((self.project / "xcuserdata").exists())

    def test_io_failure_or_source_change_leaves_no_partial_scheme(self):
        for change_source in (False, True):
            with self.subTest(change_source=change_source):
                before = self.shared.read_bytes()
                def sync(fd):
                    if change_source:
                        self.shared.write_bytes(before + b"\n")
                    else:
                        raise OSError("fixture write failure")
                with patch.object(scheme.os, "fsync", side_effect=sync):
                    with self.assertRaises(ValueError if change_source else OSError):
                        self.create()
                destination = self.project / "xcuserdata/fixture.xcuserdatad/xcschemes"
                self.assertEqual([], list(destination.iterdir()))
                self.assertEqual(
                    before + b"\n" if change_source else before, self.shared.read_bytes()
                )


if __name__ == "__main__":
    unittest.main()
