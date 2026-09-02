#!/usr/bin/env python3
"""Generate Apple and Android domain-association files from verified identifiers."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


TEAM_ID_PATTERN = re.compile(r"^[A-Z0-9]{10}$")
BUNDLE_ID_PATTERN = re.compile(r"^[A-Za-z0-9]+(?:[.-][A-Za-z0-9]+)+$")
DOMAIN_PATTERN = re.compile(
    r"^(?=.{1,253}$)(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+"
    r"[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$"
)
FINGERPRINT_PATTERN = re.compile(r"^(?:[0-9A-Fa-f]{2}:){31}[0-9A-Fa-f]{2}$")
CANONICAL_DOMAIN = "certigo-app.com"


def validate_team_id(value: str) -> str:
    if not TEAM_ID_PATTERN.fullmatch(value):
        raise ValueError("Apple Team ID must contain exactly 10 uppercase letters or digits.")
    return value


def validate_bundle_id(value: str) -> str:
    if not BUNDLE_ID_PATTERN.fullmatch(value):
        raise ValueError("Bundle/package ID is not valid.")
    return value


def validate_domain(value: str) -> str:
    normalized = value.lower().rstrip(".")
    if not DOMAIN_PATTERN.fullmatch(normalized):
        raise ValueError("Domain must be a hostname without scheme, port, or path.")
    return normalized


def validate_confirmed_domain(value: str) -> str:
    normalized = validate_domain(value)
    if normalized.endswith(".invalid"):
        raise ValueError("A confirmed domain must not use the inert .invalid suffix.")
    if normalized != CANONICAL_DOMAIN:
        raise ValueError(f"Association files must target the canonical {CANONICAL_DOMAIN} host.")
    return normalized


def normalize_fingerprint(value: str) -> str:
    if not FINGERPRINT_PATTERN.fullmatch(value):
        raise ValueError(
            "Android fingerprint must be a colon-separated SHA-256 certificate fingerprint."
        )
    return value.upper()


def normalize_path_prefix(value: str) -> str:
    if value in ("", "/"):
        return ""
    if not value.startswith("/") or value.endswith("/") or ".." in value.split("/"):
        raise ValueError("Path prefix must start with '/', omit the trailing '/', and contain no '..'.")
    if any(not segment for segment in value.split("/")[1:]):
        raise ValueError("Path prefix must not contain empty segments.")
    return value


def association_payloads(
    *,
    apple_team_id: str,
    bundle_id: str,
    android_fingerprints: list[str],
    path_prefix: str = "",
) -> tuple[dict[str, object], list[dict[str, object]]]:
    team_id = validate_team_id(apple_team_id)
    app_id = validate_bundle_id(bundle_id)
    fingerprints = [normalize_fingerprint(value) for value in android_fingerprints]
    if not fingerprints:
        raise ValueError("At least one verified Android SHA-256 fingerprint is required.")
    prefix = normalize_path_prefix(path_prefix)

    components = [
        {"/": f"{prefix}/learn/*/*", "comment": "Authenticated lesson route"},
        {"/": f"{prefix}/assignments/*", "comment": "Authenticated assignment route"},
        {"/": f"{prefix}/achievements/*", "comment": "Authenticated achievement route"},
        {"/": f"{prefix}/account-deletion", "comment": "Public account-deletion route"},
    ]
    apple = {
        "applinks": {
            "details": [
                {
                    "appIDs": [f"{team_id}.{app_id}"],
                    "components": components,
                }
            ]
        }
    }
    android = [
        {
            "relation": ["delegate_permission/common.handle_all_urls"],
            "target": {
                "namespace": "android_app",
                "package_name": app_id,
                "sha256_cert_fingerprints": fingerprints,
            },
        }
    ]
    return apple, android


def write_associations(
    *,
    output_dir: Path,
    confirmed_domain: str,
    apple_team_id: str,
    bundle_id: str,
    android_fingerprints: list[str],
    path_prefix: str = "",
) -> tuple[Path, Path]:
    normalized_domain = validate_confirmed_domain(confirmed_domain)
    apple, android = association_payloads(
        apple_team_id=apple_team_id,
        bundle_id=bundle_id,
        android_fingerprints=android_fingerprints,
        path_prefix=path_prefix,
    )
    well_known = output_dir / normalized_domain / ".well-known"
    well_known.mkdir(parents=True, exist_ok=True)
    apple_path = well_known / "apple-app-site-association"
    android_path = well_known / "assetlinks.json"
    apple_path.write_text(json.dumps(apple, indent=2) + "\n", encoding="utf-8")
    android_path.write_text(json.dumps(android, indent=2) + "\n", encoding="utf-8")
    return apple_path, android_path


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--confirmed-domain",
        required=True,
        help=f"Ownership-verified association hostname; must be {CANONICAL_DOMAIN}.",
    )
    parser.add_argument("--apple-team-id", required=True, help="Verified 10-character Apple Team ID.")
    parser.add_argument(
        "--bundle-id",
        default="com.certigo.mobileapp",
        help="Apple bundle ID and Android package name.",
    )
    parser.add_argument(
        "--android-sha256",
        required=True,
        action="append",
        help="Verified Android app-signing SHA-256 fingerprint; repeat for multiple certificates.",
    )
    parser.add_argument(
        "--path-prefix",
        default="",
        help="Optional verified deployment path prefix.",
    )
    parser.add_argument("--output-dir", type=Path, required=True)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    try:
        apple_path, android_path = write_associations(
            output_dir=args.output_dir,
            confirmed_domain=args.confirmed_domain,
            apple_team_id=args.apple_team_id,
            bundle_id=args.bundle_id,
            android_fingerprints=args.android_sha256,
            path_prefix=args.path_prefix,
        )
    except ValueError as error:
        raise SystemExit(str(error)) from error
    print(apple_path)
    print(android_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
