"""Bounded public-metadata checks. Never discovers apps, SDK caches or credentials."""

import argparse
import json
import plistlib
import re
import xml.etree.ElementTree as ET
from pathlib import Path


DEV_BUNDLE = "com.certigo.native.dev"
TEST_BUNDLE = "com.certigo.native.noauth-tests"
PROBE_BUNDLE = "com.certigo.protection-probe"
PROBE_TEST_BUNDLE = PROBE_BUNDLE + ".tests"
PROBE_SELECTORS = {
    "RuntimeDiskProtectionTests/testFoundationProtectionSetterReadsBackExactPolicyOnEmptyFile()",
    "RuntimeDiskProtectionTests/testProtectedDescriptorWriteRetainsFirstUnlockPolicyAndRemovesEmptyWitness()",
}
DEV_SCHEME = "msauth.com.certigo.native.dev"
EXPECTED_PINS = {
    "microsoft-authentication-library-for-objc": (
        "2.16.0", "8dfe5bf41fe10e6d2afed62a72c4232adbef20f4"
    ),
    "swift-crypto": ("5.0.1", "1c80d3aff53fedc445b60692980cb4f19a618657"),
    "swift-asn1": ("1.7.3", "3b6410f7dee09eb33cdd26260c5fd47fda19b0e2"),
}
PIN_LOCATIONS = {
    "microsoft-authentication-library-for-objc":
        "https://github.com/AzureAD/microsoft-authentication-library-for-objc.git",
    "swift-crypto": "https://github.com/apple/swift-crypto.git",
    "swift-asn1": "https://github.com/apple/swift-asn1.git",
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def callback_schemes(info):
    return {
        scheme.lower()
        for entry in info.get("CFBundleURLTypes", [])
        for scheme in entry.get("CFBundleURLSchemes", [])
    }


def validate_dev_plist(info, *, built):
    if built:
        require(info.get("CFBundleIdentifier") == DEV_BUNDLE, "Wrong built DEV identity")
    require(callback_schemes(info) == {DEV_SCHEME}, "Unexpected DEV callback declarations")


def validate_test_plist(info):
    require(info.get("CFBundleIdentifier") == TEST_BUNDLE, "Wrong built test identity")
    require(not callback_schemes(info), "No-auth tests must not declare callbacks")


def validate_probe_plist(info, *, test):
    expected = PROBE_TEST_BUNDLE if test else PROBE_BUNDLE
    require(info.get("CFBundleIdentifier") == expected, "Wrong built probe identity")
    require(not info.get("CFBundleURLTypes"), "Probe must not declare callback registrations")


def validate_pins(document):
    pins = document.get("pins", [])
    require(len(pins) == len(EXPECTED_PINS), "Unexpected pin count")
    seen = set()
    for pin in pins:
        identity = pin.get("identity")
        require(identity in EXPECTED_PINS and identity not in seen, "Unexpected/duplicate pin")
        seen.add(identity)
        version, revision = EXPECTED_PINS[identity]
        state = pin.get("state", {})
        require(
            state.get("version") == version and state.get("revision") == revision,
            "Resolved pin differs from approved exact revision",
        )
        require(pin.get("kind") == "remoteSourceControl", "Unexpected pin kind")
        require(pin.get("location") == PIN_LOCATIONS[identity], "Unexpected pin source")


def project_object(project, identifier):
    match = re.search(
        rf"^\t\t{identifier} = (\{{.*?\}});(?=\r?$|\s*\n)", project, re.M | re.S,
    )
    require(match is not None, "Missing required project object")
    return match.group(1)


def validate_probe(project, scheme, host_source):
    identifiers = re.findall(r"^\t\t([0-9A-F]{24}) = ", project, re.M)
    require(len(identifiers) == len(set(identifiers)), "Duplicate project object identifier")
    require(set(re.findall(r"\b[0-9A-F]{24}\b", project)) <= set(identifiers),
            "Project contains an unresolved object reference")
    for suffix, bundle in (("180", PROBE_BUNDLE), ("181", PROBE_BUNDLE),
                           ("182", PROBE_TEST_BUNDLE), ("183", PROBE_TEST_BUNDLE)):
        settings = project_object(project, "0" * 21 + suffix)
        require(f'PRODUCT_BUNDLE_IDENTIFIER = "{bundle}";' in settings, "Wrong probe identity")
        require("CODE_SIGNING_ALLOWED = NO;" in settings, "Probe signing must remain off")
        require(not any(key in settings for key in (
            "DEVELOPMENT_TEAM", "PROVISIONING_PROFILE", "CODE_SIGN_ENTITLEMENTS",
            "\n\t\t\t\tINFOPLIST_FILE =", "CFBundleURL", "SystemCapabilities",
        )), "Probe must not introduce team/profile/entitlement/callback configuration")
        if suffix in ("182", "183"):
            require(
                'TEST_HOST = "$(BUILT_PRODUCTS_DIR)/CertigoProtectionProbe.app/CertigoProtectionProbe";'
                in settings and 'BUNDLE_LOADER = "$(TEST_HOST)";' in settings,
                "Probe tests must use only their dedicated host",
            )
        else:
            require("TEST_HOST" not in settings, "Probe app must not be a test bundle")
    expected = {
        "150": "packageProductDependencies = ();",
        "151": "packageProductDependencies = (000000000000000000000141);",
        "130": "files = (000000000000000000000101);",
        "131": "files = ();",
        "133": "files = (000000000000000000000102);",
        "134": "files = (000000000000000000000103);",
        "141": "productName = CertigoData;",
        "153": "target = 000000000000000000000150;",
        "152": "remoteGlobalIDString = 000000000000000000000150;",
        "102": "fileRef = 000000000000000000000017;",
        "101": "fileRef = 000000000000000000000111;",
        "111": "path = ProtectionProbe/CertigoProtectionProbeApp.swift;",
    }
    for suffix, declaration in expected.items():
        require(declaration in project_object(project, "0" * 21 + suffix),
                "Probe dependency/source binding changed")
    require("dependencies = (000000000000000000000153);" in
            project_object(project, "000000000000000000000151"),
            "Probe tests must depend only on their dedicated host")
    require(
        "buildPhases = (000000000000000000000130, 000000000000000000000131, 000000000000000000000132);"
        in project_object(project, "000000000000000000000150"),
        "Wrong probe host build phases",
    )
    require(
        "buildPhases = (000000000000000000000133, 000000000000000000000134, 000000000000000000000135);"
        in project_object(project, "000000000000000000000151"),
        "Wrong probe test build phases",
    )
    require("import SwiftUI" in host_source, "Missing minimal native host")
    require(not any(word in host_source for word in (
        "MSAL", "CertigoData", "CredentialVault", "NativeModel", "URLSession", "Keychain",
    )), "Probe host must not compose authentication, storage or network code")
    tree = ET.fromstring(scheme)
    references = tree.findall("./TestAction/Testables/TestableReference")
    require(len(references) == 1 and references[0].get("skipped") == "NO",
            "Probe must have one enabled test bundle")
    buildable = references[0].find("BuildableReference")
    require(buildable is not None and buildable.get("BlueprintIdentifier")
            == "000000000000000000000151", "Wrong probe test target")
    selectors = references[0].findall("./SelectedTests/Test")
    require(len(selectors) == 2 and {node.get("Identifier") for node in selectors}
            == PROBE_SELECTORS, "Probe must select exactly the existing paired tests")


def validate_source(root):
    native = root / "apps" / "apple" / "CertigoNative"
    project = (native / "CertigoNative.xcodeproj" / "project.pbxproj").read_text()
    require(
        project.count(f"PRODUCT_BUNDLE_IDENTIFIER = {DEV_BUNDLE};") == 2,
        "DEV application source identity changed",
    )
    # Bounded object extraction, not a general-purpose OpenStep plist parser.
    for identifier in ("000000000000000000000084", "000000000000000000000085"):
        match = re.search(
            rf"{identifier} = \{{\s*isa = XCBuildConfiguration;\s*buildSettings = \{{(.*?)\}};",
            project, re.S,
        )
        require(match is not None, "Missing no-auth test build configuration")
        settings = match.group(1)
        require(f"PRODUCT_BUNDLE_IDENTIFIER = {TEST_BUNDLE};" in settings, "Wrong test source identity")
        require("CODE_SIGNING_ALLOWED = NO;" in settings, "No-auth signing policy changed")
        require(
            not any(key in settings for key in ("TEST_HOST", "BUNDLE_LOADER", "CODE_SIGN_ENTITLEMENTS")),
            "No-auth tests must remain unhosted and without entitlement additions",
        )
    validate_dev_plist(plistlib.loads((native / "DevelopmentInfo.plist").read_bytes()), built=False)
    flutter = plistlib.loads((root / "apps" / "mobile" / "ios" / "Runner" / "Info.plist").read_bytes())
    require(DEV_SCHEME not in callback_schemes(flutter), "Flutter/native source scheme collision")
    flutter_project = (
        root / "apps" / "mobile" / "ios" / "Runner.xcodeproj" / "project.pbxproj"
    ).read_text()
    require(
        "PRODUCT_BUNDLE_IDENTIFIER = com.certigo.mobileapp;" in flutter_project,
        "Expected Flutter source bundle identity missing",
    )
    validate_pins(json.loads(
        (native / "CertigoNative.xcodeproj" / "project.xcworkspace" / "xcshareddata"
         / "swiftpm" / "Package.resolved").read_text()
    ))
    validate_probe(
        project,
        (native / "CertigoNative.xcodeproj" / "xcshareddata" / "xcschemes"
         / "CertigoProtectionProbe.xcscheme").read_text(),
        (native / "ProtectionProbe" / "CertigoProtectionProbeApp.swift").read_text(),
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--built-dev-plist", type=Path)
    parser.add_argument("--built-test-plist", type=Path)
    parser.add_argument("--resolved-lock", type=Path)
    parser.add_argument("--built-probe-plist", type=Path)
    parser.add_argument("--built-probe-test-plist", type=Path)
    args = parser.parse_args()
    validate_source(Path(__file__).resolve().parents[1])
    if args.built_dev_plist:
        validate_dev_plist(plistlib.loads(args.built_dev_plist.read_bytes()), built=True)
    if args.built_test_plist:
        validate_test_plist(plistlib.loads(args.built_test_plist.read_bytes()))
    if args.resolved_lock:
        validate_pins(json.loads(args.resolved_lock.read_text()))
    if args.built_probe_plist:
        validate_probe_plist(plistlib.loads(args.built_probe_plist.read_bytes()), test=False)
    if args.built_probe_test_plist:
        validate_probe_plist(plistlib.loads(args.built_probe_test_plist.read_bytes()), test=True)
    print("Public source metadata checked; supplied built artifacts only if explicitly requested.")
    print("No SDK initialization/cache, installed-app collision or runtime authentication proof.")


if __name__ == "__main__":
    main()
