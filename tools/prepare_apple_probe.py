"""Prepare one private Xcode probe lot. Never signs, installs, launches or queries devices."""

import argparse
import getpass
import hashlib
import json
import os
import re
import secrets
import subprocess
from pathlib import Path

from validate_apple_noauth import PROBE_SELECTORS, probe_bundles, require, validate_source

LOCAL = Path("apps/apple/CertigoNative/ProtectionProbe/LocalLot")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def canonical(value):
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args], stderr=subprocess.PIPE).decode().strip()


def check_source(root, source):
    require(re.fullmatch(r"[0-9a-f]{40}", source) is not None, "Exact source SHA required")
    require(git(root, "rev-parse", "HEAD") == source, "Checkout differs from lot source")
    require(not git(root, "status", "--porcelain", "--untracked-files=normal"),
            "Source changes must be resolved before preparing/building a lot")
    validate_source(root)


def configuration(suffix):
    probe_bundles(suffix)
    return (
        f"PROBE_LOT_SUFFIX = {suffix}\n"
        "PROBE_HOST_BUNDLE_IDENTIFIER = com.certigo.protection-probe.lot-$(PROBE_LOT_SUFFIX)\n"
        "PROBE_TEST_BUNDLE_IDENTIFIER = $(PROBE_HOST_BUNDLE_IDENTIFIER).tests\n"
        '#include? "Execution.xcconfig"\n'
    ).encode()


def execution(team):
    require(isinstance(team, str) and re.fullmatch(r"[A-Z0-9]{10}", team) is not None,
            "Selected development team must have its exact 10-character identifier")
    return f"PROBE_CODE_SIGNING_ALLOWED = YES\nCODE_SIGN_STYLE = Automatic\nDEVELOPMENT_TEAM = {team}\n".encode()


def write_new(path, data):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0), 0o600)
    with os.fdopen(fd, "wb") as stream:
        stream.write(data)
        stream.flush()
        os.fsync(stream.fileno())


def private_read(path):
    require(path.is_file() and not path.is_symlink(), "Missing or symlinked private lot file")
    if os.name == "posix":
        info = path.stat()
        require(info.st_uid == os.getuid() and info.st_mode & 0o077 == 0,
                "Private lot file must be owner-only")
    require(path.stat().st_size < 32_768, "Private lot file exceeds bound")
    return path.read_bytes()


def prepare(root, source, team, device):
    check_source(root, source)
    execution(team)
    require(isinstance(device, str) and re.fullmatch(r"[A-Za-z0-9-]{8,80}", device) is not None,
            "Explicit user-selected device identifier required, without querying devices")
    directory = root / LOCAL
    # Existence is a stop, including an incomplete previous attempt. Never regenerate on retry.
    directory.mkdir(mode=0o700)
    suffix = secrets.token_hex(16)
    host, tests = probe_bundles(suffix)
    config = configuration(suffix)
    manifest = {
        "schema": "certigo.private-probe-lot/v1", "source": source, "suffix": suffix,
        "host": host, "tests": tests, "team": team, "device": device,
        "selectors": sorted(PROBE_SELECTORS), "configuration_sha256": digest(config),
        "execution_sha256": digest(execution(team)),
    }
    raw = canonical(manifest)
    write_new(directory / "manifest.json", raw)
    write_new(directory / "manifest.sha256", (digest(raw) + "\n").encode())
    write_new(directory / "ProbeLot.xcconfig", config)
    return manifest, digest(raw)


def verify(root, expected_digest=None, active=False):
    directory = root / LOCAL
    require(directory.is_dir() and not directory.is_symlink(), "Prepare a private lot first")
    if os.name == "posix":
        require(directory.stat().st_uid == os.getuid() and directory.stat().st_mode & 0o077 == 0,
                "Private lot directory must be owner-only")
    raw = private_read(directory / "manifest.json")
    recorded = private_read(directory / "manifest.sha256").decode().strip()
    require(digest(raw) == recorded and (expected_digest is None or recorded == expected_digest),
            "Lot digest differs from the separately reviewed manifest")
    manifest = json.loads(raw)
    require(set(manifest) == {
        "schema", "source", "suffix", "host", "tests", "team", "device", "selectors",
        "configuration_sha256", "execution_sha256",
    } and manifest["schema"] == "certigo.private-probe-lot/v1", "Unexpected lot manifest")
    check_source(root, manifest["source"])
    host, tests = probe_bundles(manifest["suffix"])
    require((manifest["host"], manifest["tests"]) == (host, tests)
            and manifest["selectors"] == sorted(PROBE_SELECTORS), "Lot identity/test binding changed")
    require(isinstance(manifest["device"], str)
            and re.fullmatch(r"[A-Za-z0-9-]{8,80}", manifest["device"]) is not None,
            "Invalid selected device binding")
    config = configuration(manifest["suffix"])
    require(private_read(directory / "ProbeLot.xcconfig") == config
            and digest(config) == manifest["configuration_sha256"], "Lot configuration changed")
    activation = execution(manifest["team"])
    require(digest(activation) == manifest["execution_sha256"], "Signing configuration changed")
    path = directory / "Execution.xcconfig"
    if active or path.exists() or path.is_symlink():
        require(private_read(path) == activation, "Execution configuration missing or changed")
        require(private_read(directory / "approved.sha256").decode().strip() == recorded,
                "Lot differs from the manifest approved before enabling signing")
    return manifest, recorded


def verify_build(manifest, environment):
    targets = {"CertigoProtectionProbe": manifest["host"],
               "CertigoProtectionProbeTests": manifest["tests"]}
    require(environment.get("TARGET_NAME") in targets, "Unexpected probe build target")
    require(environment.get("PROBE_LOT_SUFFIX") == manifest["suffix"]
            and environment.get("PRODUCT_BUNDLE_IDENTIFIER") == targets[environment["TARGET_NAME"]]
            and environment.get("PROBE_HOST_BUNDLE_IDENTIFIER") == manifest["host"]
            and environment.get("PROBE_TEST_BUNDLE_IDENTIFIER") == manifest["tests"]
            and environment.get("DEVELOPMENT_TEAM") == manifest["team"]
            and environment.get("CODE_SIGNING_ALLOWED") == "YES",
            "Effective build identity differs from approved private lot")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    create = sub.add_parser("prepare")
    create.add_argument("--source-sha", required=True)
    sub.add_parser("verify")
    activate = sub.add_parser("enable")
    activate.add_argument("--approved-manifest-sha256", required=True)
    activate.add_argument("--accept-standard-ios-and-collision-risk", action="store_true", required=True)
    sub.add_parser("verify-build")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    if args.command == "prepare":
        manifest, checksum = prepare(
            root, args.source_sha,
            getpass.getpass("Selected Xcode development team ID (private): ").strip(),
            getpass.getpass("Selected iPhone device ID (private; no discovery): ").strip(),
        )
        print("Prepared unsigned lot. Do not test until this exact manifest is approved.")
    else:
        manifest, checksum = verify(
            root, getattr(args, "approved_manifest_sha256", None),
            active=args.command == "verify-build",
        )
        if args.command == "enable":
            write_new(root / LOCAL / "approved.sha256", (checksum + "\n").encode())
            write_new(root / LOCAL / "Execution.xcconfig", execution(manifest["team"]))
            print("Signing configuration enabled for the approved lot; no build/install performed.")
        if args.command == "verify-build":
            verify_build(manifest, os.environ)
    # Never print team/device identifiers or profile/account data.
    print("HOST=" + manifest["host"])
    print("TEST=" + manifest["tests"])
    print("MANIFEST_SHA256=" + checksum)


if __name__ == "__main__":
    main()
