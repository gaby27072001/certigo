import unittest

from validate_apple_noauth import (
    DEV_BUNDLE, DEV_SCHEME, EXPECTED_PINS, PIN_LOCATIONS, TEST_BUNDLE,
    validate_dev_plist, validate_pins, validate_test_plist,
)


class AppleNoAuthMetadataTests(unittest.TestCase):
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
