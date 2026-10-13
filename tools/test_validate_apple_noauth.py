import unittest
from pathlib import Path

from validate_apple_noauth import (
    DEV_BUNDLE, DEV_SCHEME, EXPECTED_PINS, PIN_LOCATIONS, TEST_BUNDLE,
    validate_dev_plist, validate_pins, validate_test_plist,
    validate_probe,
    validate_probe_plist, PROBE_BUNDLE, PROBE_TEST_BUNDLE,
)


class AppleNoAuthMetadataTests(unittest.TestCase):
    def probe(self):
        native = Path(__file__).resolve().parents[1] / "apps" / "apple" / "CertigoNative"
        return (
            (native / "CertigoNative.xcodeproj" / "project.pbxproj").read_text(),
            (native / "CertigoNative.xcodeproj" / "xcshareddata" / "xcschemes"
             / "CertigoProtectionProbe.xcscheme").read_text(),
            (native / "ProtectionProbe" / "CertigoProtectionProbeApp.swift").read_text(),
        )

    def test_probe_source_requires_unsigned_distinct_host_and_two_paired_tests(self):
        project, scheme, source = self.probe()
        validate_probe(project, scheme, source)
        for changed in (
            project.replace('"com.certigo.protection-probe.tests"', '"com.certigo.native.dev"'),
            project.replace("CertigoProtectionProbe.app/CertigoProtectionProbe",
                            "CertigoNative.app/CertigoNative"),
            project.replace("productName = CertigoData; };\n\t\t000000000000000000000152",
                            "productName = MSAL; };\n\t\t000000000000000000000152"),
            project.replace('PRODUCT_BUNDLE_IDENTIFIER = "com.certigo.protection-probe";',
                            'DEVELOPMENT_TEAM = example; PRODUCT_BUNDLE_IDENTIFIER = "com.certigo.protection-probe";'),
        ):
            with self.assertRaises(ValueError):
                validate_probe(changed, scheme, source)
        with self.assertRaises(ValueError):
            validate_probe(project, scheme.replace('skipped="NO"', 'skipped="YES"'), source)
        with self.assertRaises(ValueError):
            validate_probe(project, scheme, source + "\nimport MSAL\n")
        with self.assertRaises(ValueError):
            validate_probe(project, scheme.replace(
                "testFoundationProtectionSetterReadsBackExactPolicyOnEmptyFile",
                "testProtectionAttributeRepresentationsFailClosed"), source)

    def test_probe_artifacts_require_exact_separate_identities_without_callbacks(self):
        validate_probe_plist({"CFBundleIdentifier": PROBE_BUNDLE}, test=False)
        validate_probe_plist({"CFBundleIdentifier": PROBE_TEST_BUNDLE}, test=True)
        with self.assertRaises(ValueError):
            validate_probe_plist({"CFBundleIdentifier": DEV_BUNDLE}, test=False)
        with self.assertRaises(ValueError):
            validate_probe_plist({
                "CFBundleIdentifier": PROBE_TEST_BUNDLE,
                "CFBundleURLTypes": [{"CFBundleURLSchemes": ["certigo"]}],
            }, test=True)

    def pins(self):
        return {"pins": [
            {"identity": key, "kind": "remoteSourceControl",
             "location": PIN_LOCATIONS[key],
             "state": {"version": value[0], "revision": value[1]}}
            for key, value in EXPECTED_PINS.items()
        ]}

    def test_exact_pins_pass_but_changed_or_duplicate_pins_fail(self):
        validate_pins(self.pins())
        changed = self.pins()
        changed["pins"][0]["state"]["revision"] = "0" * 40
        with self.assertRaises(ValueError):
            validate_pins(changed)
        duplicate = self.pins()
        duplicate["pins"][1] = duplicate["pins"][0]
        with self.assertRaises(ValueError):
            validate_pins(duplicate)

    def test_built_dev_identity_and_scheme_are_both_required(self):
        info = {"CFBundleIdentifier": DEV_BUNDLE, "CFBundleURLTypes": [
            {"CFBundleURLSchemes": [DEV_SCHEME]}
        ]}
        validate_dev_plist(info, built=True)
        info["CFBundleIdentifier"] = TEST_BUNDLE
        with self.assertRaises(ValueError):
            validate_dev_plist(info, built=True)

    def test_wrong_upstream_pin_location_is_rejected_even_with_the_expected_revision(self):
        document = self.pins()
        document["pins"][0]["location"] = "https://example.invalid/not-msal.git"
        with self.assertRaises(ValueError):
            validate_pins(document)

    def test_unexpected_dev_callback_is_not_silently_accepted(self):
        with self.assertRaises(ValueError):
            validate_dev_plist({"CFBundleURLTypes": [
                {"CFBundleURLSchemes": [DEV_SCHEME, "certigo"]}
            ]}, built=False)

    def test_test_bundle_never_accepts_dev_identity_or_callback(self):
        validate_test_plist({"CFBundleIdentifier": TEST_BUNDLE})
        with self.assertRaises(ValueError):
            validate_test_plist({"CFBundleIdentifier": DEV_BUNDLE})
        with self.assertRaises(ValueError):
            validate_test_plist({"CFBundleIdentifier": TEST_BUNDLE, "CFBundleURLTypes": [
                {"CFBundleURLSchemes": [DEV_SCHEME]}
            ]})


if __name__ == "__main__":
    unittest.main()
