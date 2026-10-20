import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import unittest
import xml.etree.ElementTree as ET

from test_native_source_membership import objects_of_type


ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "apps/apple/CertigoNative"
PROJECT = APP / "CertigoNative.xcodeproj"
GUARD = ROOT / "tools/validate_native_distribution.sh"


class NativeDistributionTests(unittest.TestCase):
    def test_openstep_graph_references_and_configuration_lists(self):
        text = (PROJECT / "project.pbxproj").read_text()
        definitions = re.findall(r"(?m)^\s*([A-F0-9]{24})(?: /\*.*?\*/)? = \{", text)
        self.assertEqual(len(definitions), len(set(definitions)))
        self.assertEqual(set(re.findall(r"\b[A-F0-9]{24}\b", text)), set(definitions))
        configs = objects_of_type(text, "XCBuildConfiguration")
        lists = objects_of_type(text, "XCConfigurationList")
        for identifier, expected in (
            ("000000000000000000000070", "000000000000000000000084"),
            ("000000000000000000000071", "000000000000000000000085"),
        ):
            refs = re.findall(r"\b[A-F0-9]{24}\b", lists[identifier])
            self.assertEqual(len(refs), 3)
            self.assertIn(expected, refs)
            self.assertTrue(set(refs) <= configs.keys())
        # Ignore strings/comments when checking OpenStep container balance.
        structural = re.sub(r'/\*.*?\*/|//[^\n]*|"(?:\\.|[^"\\])*"', "", text, flags=re.S)
        stack = []
        for token in re.findall(r"[{}()]", structural):
            if token in "{(":
                stack.append(token)
            else:
                self.assertTrue(stack)
                self.assertEqual(stack.pop(), {"}": "{", ")": "("}[token])
        self.assertEqual(stack, [])

    def test_distribution_is_explicit_unsigned_optimized_and_not_debug(self):
        text = (PROJECT / "project.pbxproj").read_text()
        config = objects_of_type(text, "XCBuildConfiguration")["000000000000000000000085"]
        for setting in (
            "PRODUCT_BUNDLE_IDENTIFIER = com.certigo.mobileapp;",
            "INFOPLIST_KEY_CFBundleDisplayName = Certigo;",
            "INFOPLIST_FILE = DistributionInfo.plist;",
            'MARKETING_VERSION = "$(CERTIGO_DISTRIBUTION_VERSION)";',
            'CURRENT_PROJECT_VERSION = "$(CERTIGO_DISTRIBUTION_BUILD)";',
            "CODE_SIGNING_ALLOWED = NO;",
            'SWIFT_OPTIMIZATION_LEVEL = "-O";',
            "SWIFT_ACTIVE_COMPILATION_CONDITIONS = CERTIGO_PRODUCTION_DISTRIBUTION;",
        ):
            self.assertIn(setting, config)
        self.assertNotIn("DEBUG", config)
        for forbidden in ("DEVELOPMENT_TEAM", "PROVISIONING_PROFILE", "CODE_SIGN_ENTITLEMENTS",
                          "CODE_SIGN_IDENTITY"):
            self.assertNotIn(forbidden, config)
        with (APP / "DistributionInfo.plist").open("rb") as file:
            self.assertEqual(
                plistlib.load(file)["CFBundleURLTypes"][0]["CFBundleURLSchemes"],
                ["msauth.com.certigo.mobileapp"],
            )
        with (APP / "DevelopmentInfo.plist").open("rb") as file:
            self.assertEqual(
                plistlib.load(file)["CFBundleURLTypes"][0]["CFBundleURLSchemes"],
                ["msauth.com.certigo.native.dev"],
            )

    def test_development_configurations_keep_their_identity_and_version(self):
        configs = objects_of_type(
            (PROJECT / "project.pbxproj").read_text(), "XCBuildConfiguration"
        )
        for identifier in ("000000000000000000000082", "000000000000000000000083"):
            config = configs[identifier]
            for setting in (
                "PRODUCT_BUNDLE_IDENTIFIER = com.certigo.native.dev;",
                "INFOPLIST_FILE = DevelopmentInfo.plist;",
                "MARKETING_VERSION = 0.1.0;",
                "CURRENT_PROJECT_VERSION = 1;",
                "CODE_SIGNING_ALLOWED = NO;",
            ):
                self.assertIn(setting, config)
        original = ET.parse(PROJECT / "xcshareddata/xcschemes/CertigoNative.xcscheme")
        self.assertEqual(original.find("LaunchAction").get("buildConfiguration"), "Debug")
        self.assertEqual(original.find("ArchiveAction").get("buildConfiguration"), "Release")

    def test_archive_and_direct_build_both_validate_before_compilation(self):
        tree = ET.parse(PROJECT / "xcshareddata/xcschemes/CertigoNative Distribution.xcscheme")
        archive = tree.find("ArchiveAction")
        self.assertEqual(archive.get("buildConfiguration"), "Distribution")
        action = archive.find("PreActions/ExecutionAction/ActionContent")
        self.assertIn("validate_native_distribution.sh", action.get("scriptText"))
        self.assertEqual(
            action.find("EnvironmentBuildable/BuildableReference").get("BlueprintIdentifier"),
            "000000000000000000000050",
        )
        text = (PROJECT / "project.pbxproj").read_text()
        target = objects_of_type(text, "PBXNativeTarget")["000000000000000000000050"]
        phases = re.search(r"buildPhases = \((.*?)\);", target, re.S)[1]
        self.assertLess(phases.index("000000000000000000000033"),
                        phases.index("000000000000000000000030"))
        phase = objects_of_type(text, "PBXShellScriptBuildPhase")["000000000000000000000033"]
        self.assertIn("validate_native_distribution.sh", phase)
        self.assertIn('alwaysOutOfDate = 1;', phase)
        self.assertIn('\\"$CONFIGURATION\\" = Distribution', phase)
        guard = (ROOT / "apps/apple/CertigoKit/Sources/CertigoData/CIAMConfigurationEnvironment.swift").read_text()
        self.assertIn("guard isDevelopmentBuild else", guard)
        self.assertIn("throw CIAMConfigurationEnvironmentError.releaseOptInNotAllowed", guard)

    def test_version_guard_rejects_missing_malformed_and_separate_overrides(self):
        shell = shutil.which("bash")
        if shell is None:
            self.fail("bash is required to execute the distribution guard tests")
        environment = {k: v for k, v in os.environ.items() if k not in (
            "CERTIGO_DISTRIBUTION_VERSION", "CERTIGO_DISTRIBUTION_BUILD",
            "MARKETING_VERSION", "CURRENT_PROJECT_VERSION",
        )}
        valid = dict(CERTIGO_DISTRIBUTION_VERSION="1.2.3", CERTIGO_DISTRIBUTION_BUILD="123",
                     MARKETING_VERSION="1.2.3", CURRENT_PROJECT_VERSION="123")
        cases = [
            {}, valid | {"CERTIGO_DISTRIBUTION_VERSION": ""},
            valid | {"CERTIGO_DISTRIBUTION_BUILD": ""},
            valid | {"CERTIGO_DISTRIBUTION_VERSION": "1.2.3-beta"},
            valid | {"CERTIGO_DISTRIBUTION_VERSION": "1.2.3\n4.5.6"},
            valid | {"CERTIGO_DISTRIBUTION_VERSION": "$(VERSION)"},
            valid | {"CERTIGO_DISTRIBUTION_BUILD": "0"},
            valid | {"CERTIGO_DISTRIBUTION_BUILD": "0123"},
            valid | {"CERTIGO_DISTRIBUTION_BUILD": "10000"},
            valid | {"CERTIGO_DISTRIBUTION_BUILD": "123\n456"},
            valid | {"MARKETING_VERSION": "9.9.9"},
            valid | {"CURRENT_PROJECT_VERSION": "124"},
        ]
        for values in cases + [valid]:
            with self.subTest(values=values):
                result = subprocess.run([shell, str(GUARD)], env=environment | values,
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode == 0, values == valid, result.stderr)
                if values != valid:
                    self.assertIn("error:", result.stderr)


if __name__ == "__main__":
    unittest.main()
