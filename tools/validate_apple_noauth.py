"""Bounded public-metadata checks. Never discovers apps, SDK caches or credentials."""

import argparse
import json
import plistlib
import re
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path


DEV_BUNDLE = "com.certigo.native.dev"
TEST_BUNDLE = "com.certigo.native.noauth-tests"
PROBE_BUNDLE = "com.certigo.protection-probe"
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


def probe_bundles(lot_suffix):
    require(isinstance(lot_suffix, str) and re.fullmatch(r"[0-9a-f]{32}", lot_suffix) is not None,
            "Probe lot requires exactly 32 lowercase hex characters")
    host = PROBE_BUNDLE + ".lot-" + lot_suffix
    return host, host + ".tests"


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


def validate_probe_plist(info, *, test, lot_suffix):
    host, tests = probe_bundles(lot_suffix)
    expected = tests if test else host
    require(info.get("CFBundleIdentifier") == expected, "Wrong built probe identity")
    require(not info.get("CFBundleURLTypes"), "Probe must not declare callback registrations")


def validate_probe_entitlements(entitlements, *, bundle, team, prefix, lot_suffix):
    expected = probe_bundles(lot_suffix)
    require(bundle in expected, "Unexpected probe signing target")
    require(all(isinstance(value, str) and value for value in (team, prefix)),
            "Explicit selected team and App ID prefix are required")
    require(re.fullmatch(r"[A-Z0-9]{10}", team) is not None
            and re.fullmatch(r"[A-Z0-9]{10}", prefix) is not None,
            "Invalid selected team or App ID prefix format")
    require(isinstance(entitlements, dict), "Signed entitlements must be a dictionary")
    allowed = {"application-identifier", "com.apple.developer.team-identifier",
               "get-task-allow", "keychain-access-groups"}
    require(set(entitlements) <= allowed, "Unexpected signed probe permission")
    application = prefix + "." + bundle
    require(entitlements.get("application-identifier") == application,
            "Wrong signed probe application identity")
    require(entitlements.get("com.apple.developer.team-identifier") == team,
            "Wrong signed probe team")
    require(entitlements.get("get-task-allow") is True,
            "Probe requires a development signature")
    groups = entitlements.get("keychain-access-groups")
    require(groups is None or groups == [application],
            "Probe must not gain an explicit shared Keychain group")
    return application, groups, allowed


def validate_probe_signing(entitlements, profile, *, bundle, team, prefix, device, now, lot_suffix):
    """Check supplied decoded artifact metadata, not signature/CMS authenticity."""
    application, groups, allowed = validate_probe_entitlements(
        entitlements, bundle=bundle, team=team, prefix=prefix, lot_suffix=lot_suffix,
    )
    require(isinstance(device, str) and device, "Explicit selected device required")
    require(isinstance(profile, dict), "Decoded profile must be a dictionary")
    require(profile.get("TeamIdentifier") == [team], "Wrong profile team")
    require(profile.get("ApplicationIdentifierPrefix") == [prefix], "Wrong profile App ID prefix")
    require(profile.get("ProvisionsAllDevices") is not True, "Unexpected all-device profile")
    devices = profile.get("ProvisionedDevices")
    require(isinstance(devices, list) and device in devices, "Selected device not provisioned")
    require(all(isinstance(value, str) and value for value in devices),
            "Invalid profile device metadata")
    created, expires = profile.get("CreationDate"), profile.get("ExpirationDate")
    require(isinstance(created, datetime) and isinstance(expires, datetime),
            "Missing profile validity interval")
    def utc(value):
        return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)
    require(utc(created) <= utc(now) < utc(expires), "Profile is not currently valid")
    certificates = profile.get("DeveloperCertificates")
    require(isinstance(certificates, list) and certificates
            and all(isinstance(value, bytes) and value for value in certificates),
            "Missing profile development certificates")
    granted = profile.get("Entitlements")
    require(isinstance(granted, dict) and set(granted) <= allowed,
            "Unexpected profile permission requires manual review")
    require(granted.get("com.apple.developer.team-identifier") == team
            and granted.get("get-task-allow") is True, "Wrong development profile grant")
    require(granted.get("application-identifier") in (application, prefix + ".*"),
            "Profile does not grant the selected application identity")
    grants = granted.get("keychain-access-groups")
    require(grants is None or grants in ([application], [prefix + ".*"]),
            "Unexpected profile Keychain grant")
    require(groups is None or grants is not None, "Signed Keychain group absent from profile grant")


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


def parse_project(project):
    """Bounded OpenStep subset used by this project, never a permissive text scrub."""
    require(len(project) <= 128_000, "Project exceeds parser bound")
    pattern = re.compile(
        r'\s+|/\*.*?\*/|//[^\n]*|"(?:\\.|[^"\\])*"|[{}()=;,]|[A-Za-z0-9_./$<>-]+',
        re.S,
    )
    tokens = []
    position = 0
    while position < len(project):
        match = pattern.match(project, position)
        require(match is not None, "Unsupported project syntax")
        token = match.group()
        position = match.end()
        if not token.isspace() and not token.startswith(("/*", "//")):
            tokens.append(token)
    require(len(tokens) <= 16_000, "Project token bound exceeded")
    index = 0

    def take(expected):
        nonlocal index
        require(index < len(tokens) and tokens[index] == expected, "Malformed project structure")
        index += 1

    def value(depth=0):
        nonlocal index
        require(depth <= 12 and index < len(tokens), "Project nesting/truncation rejected")
        token = tokens[index]
        index += 1
        if token == "{":
            result = {}
            while index < len(tokens) and tokens[index] != "}":
                key = value(depth + 1)
                require(isinstance(key, str) and key not in result, "Duplicate/invalid project key")
                take("=")
                result[key] = value(depth + 1)
                take(";")
            take("}")
            return result
        if token == "(":
            result = []
            while index < len(tokens) and tokens[index] != ")":
                result.append(value(depth + 1))
                if index < len(tokens) and tokens[index] == ",":
                    take(",")
                else:
                    require(index < len(tokens) and tokens[index] == ")", "Missing list separator")
            take(")")
            return result
        require(token not in "{}()=;,", "Unexpected project punctuation")
        if token.startswith('"'):
            return json.loads(token)
        return token

    result = value()
    require(index == len(tokens) and isinstance(result, dict), "Trailing/invalid project data")
    return result


def normalized_project(project):
    document = parse_project(project)

    def render(value, depth):
        if isinstance(value, dict):
            return "{\n" + "".join(
                "\t" * (depth + 1) + key + " = " + render(child, depth + 1) + ";\n"
                for key, child in value.items()
            ) + "\t" * depth + "}"
        if isinstance(value, list):
            return "(" + ", ".join(render(child, depth) for child in value) + ")"
        if re.fullmatch(r"[A-Za-z0-9_./<>-]+", value) is None:
            return json.dumps(value)
        return value

    return render(document, 0) + "\n"


def validate_probe(project, scheme, host_source):
    project = normalized_project(project)
    identifiers = re.findall(r"^\t\t([0-9A-F]{24}) = ", project, re.M)
    require(len(identifiers) == len(set(identifiers)), "Duplicate project object identifier")
    require(set(re.findall(r"\b[0-9A-F]{24}\b", project)) <= set(identifiers),
            "Project contains an unresolved object reference")
    for suffix, bundle in (("180", "$(PROBE_HOST_BUNDLE_IDENTIFIER)"),
                           ("181", "$(PROBE_HOST_BUNDLE_IDENTIFIER)"),
                           ("182", "$(PROBE_TEST_BUNDLE_IDENTIFIER)"),
                           ("183", "$(PROBE_TEST_BUNDLE_IDENTIFIER)")):
        settings = project_object(project, "0" * 21 + suffix)
        require(f'PRODUCT_BUNDLE_IDENTIFIER = "{bundle}";' in settings, "Wrong probe identity")
        require('CODE_SIGNING_ALLOWED = "$(PROBE_CODE_SIGNING_ALLOWED)";' in settings
                and "baseConfigurationReference = 000000000000000000000114;" in settings,
                "Probe requires unsigned-default lot configuration")
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
        "114": "path = ProtectionProbe/ProbeLot.xcconfig;",
    }
    for suffix, declaration in expected.items():
        require(declaration in project_object(project, "0" * 21 + suffix),
                "Probe dependency/source binding changed")
    require("dependencies = (000000000000000000000153);" in
            project_object(project, "000000000000000000000151"),
            "Probe tests must depend only on their dedicated host")
    require(
        "buildPhases = (000000000000000000000136, 000000000000000000000130, 000000000000000000000131, 000000000000000000000132);"
        in project_object(project, "000000000000000000000150"),
        "Wrong probe host build phases",
    )
    require(
        "buildPhases = (000000000000000000000137, 000000000000000000000133, 000000000000000000000134, 000000000000000000000135);"
        in project_object(project, "000000000000000000000151"),
        "Wrong probe test build phases",
    )
    for suffix in ("136", "137"):
        phase = project_object(project, "0" * 21 + suffix)
        require("isa = PBXShellScriptBuildPhase;" in phase and "alwaysOutOfDate = 1;" in phase
                and r'python3 -B \"$PROJECT_DIR/../../../tools/prepare_apple_probe.py\" verify-build\n' in phase,
                "Probe requires its approved-lot build guard")
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
    project = normalized_project((native / "CertigoNative.xcodeproj" / "project.pbxproj").read_text())
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
    config = (native / "ProtectionProbe" / "ProbeLot.xcconfig").read_text()
    require(config == (
        "// No usable identity or signing without an explicitly prepared private lot.\n"
        "PROBE_LOT_SUFFIX =\nPROBE_HOST_BUNDLE_IDENTIFIER =\n"
        "PROBE_TEST_BUNDLE_IDENTIFIER =\nPROBE_CODE_SIGNING_ALLOWED = NO\n"
        '#include? "LocalLot/ProbeLot.xcconfig"\n'
    ), "Default probe configuration must have no usable identity and signing off")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--built-dev-plist", type=Path)
    parser.add_argument("--built-test-plist", type=Path)
    parser.add_argument("--resolved-lock", type=Path)
    parser.add_argument("--built-probe-plist", type=Path)
    parser.add_argument("--built-probe-test-plist", type=Path)
    parser.add_argument("--probe-entitlements", type=Path)
    parser.add_argument("--probe-profile", type=Path)
    parser.add_argument("--probe-test-entitlements", type=Path)
    parser.add_argument("--probe-test-profile", type=Path)
    parser.add_argument("--expected-team")
    parser.add_argument("--expected-app-id-prefix")
    parser.add_argument("--expected-device")
    parser.add_argument("--probe-lot-suffix")
    args = parser.parse_args()
    validate_source(Path(__file__).resolve().parents[1])
    if args.built_dev_plist:
        validate_dev_plist(plistlib.loads(args.built_dev_plist.read_bytes()), built=True)
    if args.built_test_plist:
        validate_test_plist(plistlib.loads(args.built_test_plist.read_bytes()))
    if args.resolved_lock:
        validate_pins(json.loads(args.resolved_lock.read_text()))
    if args.built_probe_plist:
        probe_bundles(args.probe_lot_suffix)
        validate_probe_plist(plistlib.loads(args.built_probe_plist.read_bytes()),
                            test=False, lot_suffix=args.probe_lot_suffix)
    if args.built_probe_test_plist:
        probe_bundles(args.probe_lot_suffix)
        validate_probe_plist(plistlib.loads(args.built_probe_test_plist.read_bytes()),
                            test=True, lot_suffix=args.probe_lot_suffix)
    signing_inputs = (
        args.probe_entitlements, args.probe_profile, args.probe_test_entitlements,
        args.expected_team, args.expected_app_id_prefix, args.expected_device,
        args.built_probe_plist, args.built_probe_test_plist,
    )
    if any(signing_inputs[:6]) or args.probe_test_profile:
        require(all(signing_inputs), "Supply both built plists, both signing artifacts and selections")
        host_bundle, test_bundle = probe_bundles(args.probe_lot_suffix)
        validate_probe_signing(
            plistlib.loads(args.probe_entitlements.read_bytes()),
            plistlib.loads(args.probe_profile.read_bytes()), bundle=host_bundle,
            team=args.expected_team, prefix=args.expected_app_id_prefix,
            device=args.expected_device, now=datetime.now(timezone.utc), lot_suffix=args.probe_lot_suffix,
        )
        test_entitlements = plistlib.loads(args.probe_test_entitlements.read_bytes())
        validate_probe_entitlements(
            test_entitlements, bundle=test_bundle, team=args.expected_team,
            prefix=args.expected_app_id_prefix, lot_suffix=args.probe_lot_suffix,
        )
        # Hosted test bundles may not embed their own profile; never invent one.
        if args.probe_test_profile:
            validate_probe_signing(
                test_entitlements, plistlib.loads(args.probe_test_profile.read_bytes()),
                bundle=test_bundle, team=args.expected_team,
                prefix=args.expected_app_id_prefix, device=args.expected_device,
                now=datetime.now(timezone.utc), lot_suffix=args.probe_lot_suffix,
            )
        print("Supplied signing metadata matched; standard Xcode/iOS enforcement remains required.")
    print("Public source metadata checked; supplied built artifacts only if explicitly requested.")
    print("No SDK initialization/cache, installed-app collision or runtime authentication proof.")


if __name__ == "__main__":
    main()
