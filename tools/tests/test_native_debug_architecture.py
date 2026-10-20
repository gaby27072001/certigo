import re
import unittest
from pathlib import Path


PROJECT = (
    Path(__file__).resolve().parents[2]
    / "apps/apple/CertigoNative/CertigoNative.xcodeproj/project.pbxproj"
)


def settings(project, identifier):
    matches = re.findall(
        rf"{identifier} /\* (?:Debug|Release) \*/ = \{{\s*"
        r"isa = XCBuildConfiguration;\s*buildSettings = \{(.*?)\n\t\t\t\};",
        project,
        re.DOTALL,
    )
    if len(matches) != 1:
        raise ValueError(f"Expected one build configuration {identifier}")
    return matches[0]


class NativeDebugArchitectureTests(unittest.TestCase):
    def setUp(self):
        self.project = PROJECT.read_text(encoding="utf-8")

    def test_debug_uses_destination_active_architecture_at_project_scope(self):
        debug = settings(self.project, "000000000000000000000080")
        self.assertEqual(re.findall(r"\bONLY_ACTIVE_ARCH\s*=\s*([^;]+);", debug), ["YES"])

    def test_app_target_inherits_debug_setting_and_release_remains_unrestricted(self):
        target_debug = settings(self.project, "000000000000000000000082")
        self.assertNotIn("ONLY_ACTIVE_ARCH", target_debug)
        for identifier in ("000000000000000000000081", "000000000000000000000083"):
            with self.subTest(configuration=identifier):
                self.assertNotIn("ONLY_ACTIVE_ARCH", settings(self.project, identifier))
        self.assertIn(
            'SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";',
            target_debug,
        )

    def test_no_hardcoded_or_excluded_architecture_replaces_active_destination(self):
        self.assertNotRegex(
            self.project,
            r"(?m)^\s*(?:ARCHS|VALID_ARCHS|EXCLUDED_ARCHS)(?:\[[^\]]+\])?\s*=",
        )
        self.assertEqual(self.project.count("ONLY_ACTIVE_ARCH"), 1)


if __name__ == "__main__":
    unittest.main()
