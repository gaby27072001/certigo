"""Bounded public-metadata checks. Never discovers apps, SDK caches or credentials."""

import argparse
import json
import plistlib
import re
from pathlib import Path


DEV_BUNDLE = "com.certigo.native.dev"
TEST_BUNDLE = "com.certigo.native.noauth-tests"
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--built-dev-plist", type=Path)
    parser.add_argument("--built-test-plist", type=Path)
    parser.add_argument("--resolved-lock", type=Path)
    args = parser.parse_args()
    validate_source(Path(__file__).resolve().parents[1])
    if args.built_dev_plist:
        validate_dev_plist(plistlib.loads(args.built_dev_plist.read_bytes()), built=True)
    if args.built_test_plist:
        validate_test_plist(plistlib.loads(args.built_test_plist.read_bytes()))
    if args.resolved_lock:
        validate_pins(json.loads(args.resolved_lock.read_text()))
    print("Public source metadata checked; supplied built artifacts only if explicitly requested.")
    print("No SDK initialization/cache, installed-app collision or runtime authentication proof.")


if __name__ == "__main__":
    main()
