import unittest
import plistlib
from copy import deepcopy
from datetime import datetime, timedelta, timezone
from pathlib import Path

from validate_apple_noauth import (
    DEV_BUNDLE, DEV_SCHEME, EXPECTED_PINS, PIN_LOCATIONS, TEST_BUNDLE,
    validate_dev_plist, validate_pins, validate_test_plist,
    validate_probe,
    validate_probe_plist, probe_bundles,
    validate_probe_signing,
    validate_probe_entitlements,
    normalized_project, parse_project,
)

LOT_SUFFIX = "ab" * 16
PROBE_BUNDLE, PROBE_TEST_BUNDLE = probe_bundles(LOT_SUFFIX)


class AppleNoAuthMetadataTests(unittest.TestCase):
    def test_app_embeds_linked_msal_product_and_searches_frameworks_in_both_configurations(self):
        native = Path(__file__).resolve().parents[1] / "apps" / "apple" / "CertigoNative"
        objects = parse_project(
            (native / "CertigoNative.xcodeproj" / "project.pbxproj").read_text()
        )["objects"]
        app = objects["000000000000000000000050"]
        embed = objects["000000000000000000000036"]
        self.assertIn("000000000000000000000036", app["buildPhases"])
        self.assertEqual(embed["isa"], "PBXCopyFilesBuildPhase")
        self.assertEqual(embed["dstSubfolderSpec"], "10")
        self.assertEqual(embed["dstPath"], "")
        self.assertEqual(embed["runOnlyForDeploymentPostprocessing"], "0")
        self.assertEqual(embed["files"], ["00000000000000000000000C"])
        linked = objects["000000000000000000000007"]
        copied = objects["00000000000000000000000C"]
        self.assertEqual(copied["productRef"], linked["productRef"])
        self.assertIn(copied["productRef"], app["packageProductDependencies"])
        self.assertEqual(
            copied["settings"]["ATTRIBUTES"], ["CodeSignOnCopy", "RemoveHeadersOnCopy"]
        )
        for identifier in ("000000000000000000000082", "000000000000000000000083"):
            settings = objects[identifier]["buildSettings"]
            self.assertEqual(settings["LD_RUNPATH_SEARCH_PATHS"],
                             ["$(inherited)", "@executable_path/Frameworks"])
            self.assertEqual(settings["CODE_SIGNING_ALLOWED"], "NO")

    def signing(self):
        now = datetime(2026, 10, 13, tzinfo=timezone.utc)
        team, prefix = "A" * 10, "B" * 10
        app = prefix + "." + PROBE_BUNDLE
        signed = {
            "application-identifier": app, "com.apple.developer.team-identifier": team,
            "get-task-allow": True, "keychain-access-groups": [app],
        }
        profile = {
            "TeamIdentifier": [team], "ApplicationIdentifierPrefix": [prefix],
            "ProvisionedDevices": ["synthetic-selected-device"],
            "CreationDate": now - timedelta(days=1), "ExpirationDate": now + timedelta(days=1),
            "DeveloperCertificates": [b"synthetic-not-a-certificate"],
            "Entitlements": {
                "application-identifier": prefix + ".*",
                "com.apple.developer.team-identifier": team,
                "get-task-allow": True, "keychain-access-groups": [prefix + ".*"],
            },
        }
        selections = dict(bundle=PROBE_BUNDLE, team=team, prefix=prefix,
                          device="synthetic-selected-device", now=now, lot_suffix=LOT_SUFFIX)
        return signed, profile, selections

    def test_signing_metadata_accepts_only_exact_signed_identity_and_bounded_profile_grant(self):
        signed, profile, selections = self.signing()
        validate_probe_signing(signed, profile, **selections)
        # Decoded provisioning plists represent dates without a timezone.
        decoded = plistlib.loads(plistlib.dumps({
            **profile, "CreationDate": profile["CreationDate"].replace(tzinfo=None),
            "ExpirationDate": profile["ExpirationDate"].replace(tzinfo=None),
        }))
        validate_probe_signing(signed, decoded, **selections)
        # A metadata-only check intentionally does not validate synthetic certificate bytes.
        profile["Entitlements"]["application-identifier"] = signed["application-identifier"]
        profile["Entitlements"]["keychain-access-groups"] = signed["keychain-access-groups"]
        validate_probe_signing(signed, profile, **selections)

    def test_hosted_test_signature_identity_is_separate_without_assuming_an_embedded_profile(self):
        signed, _, selections = self.signing()
        application = selections["prefix"] + "." + PROBE_TEST_BUNDLE
        signed["application-identifier"] = application
        signed["keychain-access-groups"] = [application]
        validate_probe_entitlements(
            signed, bundle=PROBE_TEST_BUNDLE, team=selections["team"],
            prefix=selections["prefix"], lot_suffix=LOT_SUFFIX,
        )
        del signed["application-identifier"]
        with self.assertRaises(ValueError):
            validate_probe_entitlements(
                signed, bundle=PROBE_TEST_BUNDLE, team=selections["team"],
                prefix=selections["prefix"], lot_suffix=LOT_SUFFIX,
            )

    def test_signing_metadata_rejects_wrong_team_identity_or_extra_permissions(self):
        signed, profile, selections = self.signing()
        for key, value in (
            ("application-identifier", "B" * 10 + ".com.certigo.native.dev"),
            ("com.apple.developer.team-identifier", "C" * 10),
            ("get-task-allow", False),
            ("get-task-allow", 1),
            ("keychain-access-groups", ["com.microsoft.adalcache"]),
            ("com.apple.security.application-groups", ["group.synthetic"]),
            ("aps-environment", "development"),
            ("com.apple.developer.default-data-protection", "NSFileProtectionNone"),
        ):
            changed = deepcopy(signed)
            changed[key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                validate_probe_signing(changed, profile, **selections)

    def test_profile_rejects_unselected_devices_invalid_dates_and_unexpected_grants(self):
        signed, profile, selections = self.signing()
        for key, value in (
            ("TeamIdentifier", ["C" * 10]),
            ("ApplicationIdentifierPrefix", ["C" * 10]),
            ("ProvisionedDevices", ["synthetic-different-device"]),
            ("ExpirationDate", selections["now"]),
            ("CreationDate", selections["now"] + timedelta(days=1)),
            ("DeveloperCertificates", []),
            ("ProvisionsAllDevices", True),
        ):
            changed = deepcopy(profile)
            changed[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate_probe_signing(signed, changed, **selections)
        for key, value in (
            ("application-identifier", "*"),
            ("keychain-access-groups", ["C" * 10 + ".*"]),
            ("com.apple.security.application-groups", ["group.synthetic"]),
        ):
            changed = deepcopy(profile)
            changed["Entitlements"][key] = value
            with self.subTest(grant=key), self.assertRaises(ValueError):
                validate_probe_signing(signed, changed, **selections)

    def probe(self):
        native = Path(__file__).resolve().parents[1] / "apps" / "apple" / "CertigoNative"
        return (
            normalized_project((native / "CertigoNative.xcodeproj" / "project.pbxproj").read_text()),
            (native / "CertigoNative.xcodeproj" / "xcshareddata" / "xcschemes"
             / "CertigoProtectionProbe.xcscheme").read_text(),
            (native / "ProtectionProbe" / "CertigoProtectionProbeApp.swift").read_text(),
        )

    def test_probe_source_requires_unsigned_distinct_host_and_two_paired_tests(self):
        project, scheme, source = self.probe()
        validate_probe(project, scheme, source)
        for changed in (
            project.replace('"$(PROBE_TEST_BUNDLE_IDENTIFIER)"', '"com.certigo.native.dev"'),
            project.replace("CertigoProtectionProbe.app/CertigoProtectionProbe",
                            "CertigoNative.app/CertigoNative"),
            project.replace("productName = CertigoData;", "productName = MSAL;"),
            project.replace('PRODUCT_BUNDLE_IDENTIFIER = "$(PROBE_HOST_BUNDLE_IDENTIFIER)";',
                            'DEVELOPMENT_TEAM = example; PRODUCT_BUNDLE_IDENTIFIER = "$(PROBE_HOST_BUNDLE_IDENTIFIER)";'),
            project.replace(" verify-build", " verify"),
            project.replace('$(PROBE_CODE_SIGNING_ALLOWED)', 'YES'),
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

    def test_project_parser_preserves_strings_and_rejects_duplicate_or_malformed_data(self):
        document = '/* comment */ { key = "https://example.invalid/a"; list = (one, "two",); }'
        self.assertEqual(parse_project(document), {
            "key": "https://example.invalid/a", "list": ["one", "two"],
        })
        self.assertEqual(parse_project(normalized_project(document)), parse_project(document))
        for invalid in (
            "{ key = one; key = two; }", "{ key = one }", "{ key = (one two); }",
            "{ key = one; } trailing", "{ key = one; /* unterminated",
            "{ key = one; @bad = two; }", "{ key = " * 14 + "value" + "; }" * 14,
            " " * 128_001,
        ):
            with self.subTest(invalid=invalid[:60]), self.assertRaises(ValueError):
                parse_project(invalid)

    def test_canonical_project_keeps_binding_and_unsigned_defaults_fail_closed(self):
        native = Path(__file__).resolve().parents[1] / "apps" / "apple" / "CertigoNative"
        raw = (native / "CertigoNative.xcodeproj" / "project.pbxproj").read_text()
        _, scheme, host = self.probe()
        validate_probe(raw, scheme, host)
        mutations = (
            ('productName = CertigoData;', 'productName = MSAL;'),
            ('PRODUCT_BUNDLE_IDENTIFIER = "$(PROBE_TEST_BUNDLE_IDENTIFIER)";',
             'PRODUCT_BUNDLE_IDENTIFIER = com.certigo.native.dev;'),
            ('CODE_SIGNING_ALLOWED = "$(PROBE_CODE_SIGNING_ALLOWED)";', 'CODE_SIGNING_ALLOWED = YES;'),
            ('baseConfigurationReference = 000000000000000000000114',
             'baseConfigurationReference = 000000000000000000011'),
            ('CertigoProtectionProbe.app/CertigoProtectionProbe', 'CertigoNative.app/CertigoNative'),
            ('verify-build', 'verify'),
            ('remoteGlobalIDString = 000000000000000000000150;',
             'remoteGlobalIDString = 000000000000000000000050;'),
        )
        for before, after in mutations:
            self.assertIn(before, raw)
            with self.subTest(before=before), self.assertRaises(ValueError):
                validate_probe(raw.replace(before, after), scheme, host)

    def test_probe_artifacts_require_exact_separate_identities_without_callbacks(self):
        validate_probe_plist({"CFBundleIdentifier": PROBE_BUNDLE}, test=False, lot_suffix=LOT_SUFFIX)
        validate_probe_plist({"CFBundleIdentifier": PROBE_TEST_BUNDLE}, test=True, lot_suffix=LOT_SUFFIX)
        with self.assertRaises(ValueError):
            validate_probe_plist({"CFBundleIdentifier": DEV_BUNDLE}, test=False, lot_suffix=LOT_SUFFIX)
        with self.assertRaises(ValueError):
            validate_probe_plist({
                "CFBundleIdentifier": PROBE_TEST_BUNDLE,
                "CFBundleURLTypes": [{"CFBundleURLSchemes": ["certigo"]}],
            }, test=True, lot_suffix=LOT_SUFFIX)

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
