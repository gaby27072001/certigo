import plistlib
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "apps" / "apple" / "CertigoNative" / "Resources" / "PrivacyInfo.xcprivacy"
PROJECT = ROOT / "apps" / "apple" / "CertigoNative" / "CertigoNative.xcodeproj" / "project.pbxproj"


class NativePrivacyManifestTests(unittest.TestCase):
    def test_manifest_is_a_plist_with_only_source_supported_reasons(self):
        with MANIFEST.open("rb") as file:
            manifest = plistlib.load(file)

        declared = {
            entry["NSPrivacyAccessedAPIType"]: set(entry["NSPrivacyAccessedAPITypeReasons"])
            for entry in manifest["NSPrivacyAccessedAPITypes"]
        }
        self.assertEqual(set(manifest), {"NSPrivacyAccessedAPITypes"})
        self.assertEqual(
            declared,
            {
                "NSPrivacyAccessedAPICategoryFileTimestamp": {"C617.1"},
                "NSPrivacyAccessedAPICategoryUserDefaults": {"CA92.1"},
            },
        )
        self.assertNotIn("NSPrivacyCollectedDataTypes", manifest)
        self.assertNotIn("NSPrivacyTracking", manifest)

    def test_declared_categories_have_production_source_evidence(self):
        app_sources = ROOT / "apps" / "apple" / "CertigoNative" / "Sources"
        kit_sources = ROOT / "apps" / "apple" / "CertigoKit" / "Sources" / "CertigoData"
        app_text = "\n".join(path.read_text(encoding="utf-8") for path in app_sources.glob("*.swift"))
        runtime_disk = (kit_sources / "RuntimeDisk.swift").read_text(encoding="utf-8")
        submission_store = (kit_sources / "SubmissionStore.swift").read_text(encoding="utf-8")

        self.assertIn("@AppStorage(", app_text)
        self.assertIn("defaults: UserDefaults = .standard", app_text)
        self.assertRegex(runtime_disk, r"(?<![A-Za-z0-9_])stat\(")
        for api in ("lstat(", "fstat(", "fstatat(", "st_size", "st_ino", "st_nlink"):
            self.assertIn(api, runtime_disk)
        self.assertIn("attributesOfItem(atPath:", submission_store)
        self.assertIn("attributes[.size]", submission_store)

    def test_manifest_is_referenced_by_the_app_resources_phase(self):
        project = PROJECT.read_text(encoding="utf-8")
        build_file_id = "000000000000000000000009"
        file_reference_id = "000000000000000000000017"
        self.assertRegex(
            project,
            re.compile(
                rf"{build_file_id} /\* PrivacyInfo\.xcprivacy in Resources \*/ = "
                rf"\{{isa = PBXBuildFile; fileRef = {file_reference_id} "
                rf"/\* PrivacyInfo\.xcprivacy \*/;"
            ),
        )
        self.assertRegex(
            project,
            re.compile(
                rf"{file_reference_id} /\* PrivacyInfo\.xcprivacy \*/ = "
                r"\{isa = PBXFileReference; lastKnownFileType = text\.xml;"
            ),
        )
        resources_group = project.split("/* Resources */ = {", 1)[1].split("};", 1)[0]
        self.assertIn(f"{file_reference_id} /* PrivacyInfo.xcprivacy */", resources_group)
        self.assertIn(
            f"{build_file_id} /* PrivacyInfo.xcprivacy in Resources */,",
            project[project.index("/* Begin PBXResourcesBuildPhase section */") :],
        )


if __name__ == "__main__":
    unittest.main()
