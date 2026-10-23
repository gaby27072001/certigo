"""Prepare one private Xcode probe lot. Never signs, installs, launches or queries devices."""

import argparse
import getpass
import hashlib
import json
import os
import re
import secrets
import stat
import subprocess
from pathlib import Path

from validate_apple_noauth import PROBE_SELECTORS, probe_bundles, require, validate_source

LOCAL = Path("apps/apple/CertigoNative/ProtectionProbe/LocalLot")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def private_fingerprint(data, salt):
    require(isinstance(salt, str) and re.fullmatch(r"[0-9a-f]{32}", salt) is not None,
            "Invalid private fingerprint salt")
    return hashlib.scrypt(data, salt=bytes.fromhex(salt), n=2**14, r=8, p=1,
                          maxmem=64 * 1024 * 1024, dklen=32).hex()


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


def validate_manifest(raw):
    def unique_pairs(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, "Duplicate private manifest key")
            result[key] = value
        return result

    try:
        manifest = json.loads(raw, object_pairs_hook=unique_pairs)
    except (UnicodeError, json.JSONDecodeError, RecursionError):
        raise ValueError("Malformed private lot manifest") from None
    legacy = isinstance(manifest, dict) and manifest.get("schema") == "certigo.private-probe-lot/v1"
    current = isinstance(manifest, dict) and manifest.get("schema") == "certigo.private-probe-lot/v2"
    legacy_fields = {
        "schema", "source", "suffix", "host", "tests", "team", "device", "selectors",
        "configuration_sha256", "execution_sha256",
    }
    current_fields = (legacy_fields - {"execution_sha256"}) | {
        "fingerprint_salt", "execution_fingerprint",
    }
    require(isinstance(manifest, dict)
            and ((legacy and set(manifest) == legacy_fields)
                 or (current and set(manifest) == current_fields)),
            "Unexpected lot manifest")
    require(isinstance(manifest["source"], str)
            and re.fullmatch(r"[0-9a-f]{40}", manifest["source"]) is not None,
            "Invalid private manifest source")
    host, tests = probe_bundles(manifest["suffix"])
    require((manifest["host"], manifest["tests"]) == (host, tests)
            and manifest["selectors"] == sorted(PROBE_SELECTORS), "Lot identity/test binding changed")
    require(isinstance(manifest["device"], str)
            and re.fullmatch(r"[A-Za-z0-9-]{8,80}", manifest["device"]) is not None,
            "Invalid selected device binding")
    execution_fingerprint = (
        digest(execution(manifest["team"])) if legacy else
        private_fingerprint(execution(manifest["team"]), manifest["fingerprint_salt"])
    )
    execution_field = "execution_sha256" if legacy else "execution_fingerprint"
    require(manifest["configuration_sha256"] == digest(configuration(manifest["suffix"]))
            and manifest[execution_field] == execution_fingerprint,
            "Private manifest configuration binding changed")
    return manifest


def identities_from(path):
    """Read only a specifically selected previous lot; no account/device discovery."""
    require(os.name == "posix", "Private identity reuse requires macOS/POSIX permission checks")
    require(path.is_absolute() and path.name == "manifest.json"
            and path.parent.name == "LocalLot" and ".." not in path.parts,
            "Select the exact absolute private LocalLot/manifest.json path")
    try:
        for directory in (path.parent, *path.parent.parents):
            info = directory.lstat()
            if stat.S_ISLNK(info.st_mode):
                require(directory == Path("/tmp") and directory.resolve() == Path("/private/tmp"),
                        "Symlinked private manifest ancestor rejected")
                info = directory.stat()
            require(stat.S_ISDIR(info.st_mode), "Invalid private manifest ancestor")
            if directory == path.parent:
                require(info.st_uid == os.getuid() and info.st_mode & 0o077 == 0,
                        "Previous lot directory must be owner-only")
            else:
                require(info.st_mode & 0o022 == 0 or (
                    directory in (Path("/tmp"), Path("/private/tmp"))
                    and info.st_mode & stat.S_ISVTX != 0
                ), "Writable private manifest ancestor rejected")
        selected = path.parent.lstat()
        directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            info = os.fstat(directory)
            require((info.st_dev, info.st_ino) == (selected.st_dev, selected.st_ino)
                    and info.st_uid == os.getuid() and info.st_mode & 0o077 == 0,
                    "Previous lot directory must be owner-only")

            def read(name):
                handle = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK,
                                 dir_fd=directory)
                with os.fdopen(handle, "rb") as stream:
                    info = os.fstat(stream.fileno())
                    require(stat.S_ISREG(info.st_mode) and info.st_nlink == 1
                            and info.st_uid == os.getuid() and info.st_mode & 0o077 == 0,
                            "Previous lot files must be private regular single-link files")
                    require(0 < info.st_size < 32_768, "Previous lot file exceeds read bound")
                    data = stream.read(32_768)
                    require(len(data) < 32_768, "Previous lot file exceeds read bound")
                    return data

            raw = read("manifest.json")
            manifest = validate_manifest(raw)
            checksum_name = (
                "manifest.sha256" if manifest["schema"] == "certigo.private-probe-lot/v1" else
                "manifest.fingerprint"
            )
            recorded = read(checksum_name)
        finally:
            os.close(directory)
        fingerprint = (
            digest(raw) if manifest["schema"] == "certigo.private-probe-lot/v1" else
            private_fingerprint(raw, manifest["fingerprint_salt"])
        )
        require(recorded == (fingerprint + "\n").encode(), "Previous manifest checksum mismatch")
    except OSError:
        raise ValueError("Cannot safely read the selected previous private manifest") from None
    return manifest["team"], manifest["device"]


def prepare(root, source, team, device):
    check_source(root, source)
    execution(team)
    require(isinstance(device, str) and re.fullmatch(r"[A-Za-z0-9-]{8,80}", device) is not None,
            "Explicit user-selected device identifier required, without querying devices")
    directory = root / LOCAL
    # Existence is a stop, including an incomplete previous attempt. Never regenerate on retry.
    directory.mkdir(mode=0o700)
    suffix = secrets.token_hex(16)
    fingerprint_salt = secrets.token_hex(16)
    host, tests = probe_bundles(suffix)
    config = configuration(suffix)
    manifest = {
        "schema": "certigo.private-probe-lot/v2", "source": source, "suffix": suffix,
        "host": host, "tests": tests, "team": team, "device": device,
        "selectors": sorted(PROBE_SELECTORS), "configuration_sha256": digest(config),
        "fingerprint_salt": fingerprint_salt,
        "execution_fingerprint": private_fingerprint(execution(team), fingerprint_salt),
    }
    raw = canonical(manifest)
    write_new(directory / "manifest.json", raw)
    checksum = private_fingerprint(raw, fingerprint_salt)
    write_new(directory / "manifest.fingerprint", (checksum + "\n").encode())
    write_new(directory / "ProbeLot.xcconfig", config)
    return manifest, checksum


def verify(root, expected_fingerprint=None, active=False):
    directory = root / LOCAL
    require(directory.is_dir() and not directory.is_symlink(), "Prepare a private lot first")
    if os.name == "posix":
        require(directory.stat().st_uid == os.getuid() and directory.stat().st_mode & 0o077 == 0,
                "Private lot directory must be owner-only")
    raw = private_read(directory / "manifest.json")
    manifest = validate_manifest(raw)
    checksum_name = (
        "manifest.sha256" if manifest["schema"] == "certigo.private-probe-lot/v1" else
        "manifest.fingerprint"
    )
    recorded = private_read(directory / checksum_name).decode().strip()
    fingerprint = (
        digest(raw) if manifest["schema"] == "certigo.private-probe-lot/v1" else
        private_fingerprint(raw, manifest["fingerprint_salt"])
    )
    require(fingerprint == recorded and (expected_fingerprint is None or recorded == expected_fingerprint),
            "Lot digest differs from the separately reviewed manifest")
    check_source(root, manifest["source"])
    config = configuration(manifest["suffix"])
    require(private_read(directory / "ProbeLot.xcconfig") == config, "Lot configuration changed")
    activation = execution(manifest["team"])
    path = directory / "Execution.xcconfig"
    if active or path.exists() or path.is_symlink():
        require(private_read(path) == activation, "Execution configuration missing or changed")
        approval_name = (
            "approved.sha256" if manifest["schema"] == "certigo.private-probe-lot/v1" else
            "approved.fingerprint"
        )
        require(private_read(directory / approval_name).decode().strip() == recorded,
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
    create.add_argument("--identities-from", type=Path,
                        help="Reuse only team/device from an explicitly selected private manifest")
    sub.add_parser("verify")
    activate = sub.add_parser("enable")
    activate.add_argument("--approved-manifest-fingerprint", "--approved-manifest-sha256",
                          dest="approved_manifest_fingerprint", required=True)
    activate.add_argument("--accept-standard-ios-and-collision-risk", action="store_true", required=True)
    sub.add_parser("verify-build")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    if args.command == "prepare":
        if args.identities_from is not None:
            team, device = identities_from(args.identities_from)
        else:
            team = getpass.getpass("Selected Xcode development team ID (private): ").strip()
            device = getpass.getpass("Selected iPhone device ID (private; no discovery): ").strip()
        manifest, checksum = prepare(
            root, args.source_sha, team, device,
        )
        print("Prepared unsigned lot. Do not test until this exact manifest is approved.")
    else:
        manifest, checksum = verify(
            root, getattr(args, "approved_manifest_fingerprint", None),
            active=args.command == "verify-build",
        )
        if args.command == "enable":
            approval_name = (
                "approved.sha256" if manifest["schema"] == "certigo.private-probe-lot/v1" else
                "approved.fingerprint"
            )
            write_new(root / LOCAL / approval_name, (checksum + "\n").encode())
            write_new(root / LOCAL / "Execution.xcconfig", execution(manifest["team"]))
            print("Signing configuration enabled for the approved lot; no build/install performed.")
        if args.command == "verify-build":
            verify_build(manifest, os.environ)
    # Never print team/device identifiers or profile/account data.
    print("HOST=" + manifest["host"])
    print("TEST=" + manifest["tests"])
    print("MANIFEST_FINGERPRINT=" + checksum)


if __name__ == "__main__":
    main()
