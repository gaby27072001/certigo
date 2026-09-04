#!/usr/bin/env python3
"""Compare the newest published certigo-content release descriptor with the pinned reference.

`docs/active-content-reference.json` records which content release Certigo has adopted.
Nothing used to re-read it, so the pin silently rotted. This check closes that loop against
what was actually *published* — the release descriptor written to immutable storage by
certigo-content's `publish-content-azure` workflow — rather than against what merely sits in
a Git branch. Content-addressed manifest identities make the comparison exact.

Scope, stated precisely because the two are not the same thing: this answers "has the pin
drifted from the most recently *published* release?", not "does the pin match what users are
being *served*?". The active-release pointer lives in the Cosmos `content-control` container
and is what a rollback moves; ADR-020 is explicit that rollback changes only that pointer and
never moves, rewrites or aliases a blob. So after a rollback to an earlier release, the newest
descriptor by upload time is no longer the serving one. Blob is the only source that exists
today, so it is what this reads — but it must not be described as the serving release.

The descriptor is `certigo.content.release/v1`, whose `releaseId` is the SHA-256 of its own
canonical body, so a corrupted or hand-edited descriptor is rejected before it is trusted.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from project_state import (  # noqa: E402
    ACTIVE_CONTENT_REFERENCE_FILE,
    ProjectStateError,
    load_active_content_reference,
)

RELEASE_SCHEMA = "certigo.content.release/v1"
RELEASE_ALGORITHM = "sha256"
RELEASE_CANONICALIZATION = "json-sorted-keys-compact-utf8"
RELEASE_BODY_FIELDS = (
    "schema",
    "algorithm",
    "canonicalization",
    "publicManifestId",
    "privateManifestId",
)
RELEASE_FIELDS = (*RELEASE_BODY_FIELDS, "releaseId")
_MANIFEST_ID = "sha256:"


def _canonical_release_id(descriptor: dict[str, object]) -> str:
    body = {field: descriptor[field] for field in RELEASE_BODY_FIELDS}
    canonical = json.dumps(
        body, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")
    return f"sha256:{hashlib.sha256(canonical).hexdigest()}"


def load_release_descriptor(path: Path) -> dict[str, object]:
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise ProjectStateError(f"Cannot read release descriptor {path}: {exc}") from exc
    try:
        descriptor = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ProjectStateError(f"{path}: invalid JSON: {exc}") from exc
    if not isinstance(descriptor, dict):
        raise ProjectStateError(f"{path}: expected a JSON object.")
    if set(descriptor) != set(RELEASE_FIELDS):
        raise ProjectStateError(
            f"{path}: expected fields {sorted(RELEASE_FIELDS)}, "
            f"found {sorted(descriptor)}."
        )
    if descriptor["schema"] != RELEASE_SCHEMA:
        raise ProjectStateError(
            f"{path}.schema: expected {RELEASE_SCHEMA}, found {descriptor['schema']!r}."
        )
    if descriptor["algorithm"] != RELEASE_ALGORITHM:
        raise ProjectStateError(f"{path}.algorithm: expected {RELEASE_ALGORITHM}.")
    if descriptor["canonicalization"] != RELEASE_CANONICALIZATION:
        raise ProjectStateError(
            f"{path}.canonicalization: expected {RELEASE_CANONICALIZATION}."
        )
    for field in ("publicManifestId", "privateManifestId", "releaseId"):
        value = descriptor[field]
        if (
            not isinstance(value, str)
            or not value.startswith(_MANIFEST_ID)
            or len(value) != len(_MANIFEST_ID) + 64
            or any(character not in "0123456789abcdef" for character in value[7:])
        ):
            raise ProjectStateError(
                f"{path}.{field}: expected sha256:<64 lowercase hex>."
            )
    canonical_release_id = _canonical_release_id(descriptor)
    if descriptor["releaseId"] != canonical_release_id:
        raise ProjectStateError(
            f"{path}.releaseId: canonical body hashes to {canonical_release_id}, "
            f"descriptor claims {descriptor['releaseId']}."
        )
    return descriptor


def compare(root: Path, descriptor_path: Path) -> list[str]:
    reference = load_active_content_reference(root)
    descriptor = load_release_descriptor(descriptor_path)
    drift: list[str] = []
    for channel, published, pinned in (
        ("public", descriptor["publicManifestId"], reference.public.manifest_id),
        ("private", descriptor["privateManifestId"], reference.private.manifest_id),
    ):
        if published != pinned:
            drift.append(f"{channel}: published {published}, pinned {pinned}")
    return drift


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        metavar="PATH",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="repository workspace to inspect (defaults to this script's repository)",
    )
    parser.add_argument(
        "--release-descriptor",
        metavar="PATH",
        type=Path,
        required=True,
        help="published certigo.content.release/v1 descriptor to compare against",
    )
    args = parser.parse_args(argv)
    try:
        root = args.root.resolve(strict=True)
        drift = compare(root, args.release_descriptor)
    except (OSError, ProjectStateError) as exc:
        print(f"published-content-release: {exc}", file=sys.stderr)
        return 1
    if drift:
        details = "; ".join(drift)
        print(
            f"published-content-release: {ACTIVE_CONTENT_REFERENCE_FILE} does not match the "
            f"newest published content release ({details}). Follow docs/GOVERNANCE.md: check out "
            "the certigo-content revision that produced the published manifests, run "
            "`npm ci --ignore-scripts` then `npm run package`, report the revision, the "
            "timestamp and both manifests into the reference, and re-run "
            "`python tools/project_state.py --validate-active-content <checkout>`. Note that this "
            "compares against the most recently published release, not the serving one: after a "
            "rollback the active pointer in Cosmos points at an earlier release while the newest "
            "descriptor stays newest, so confirm which release is actually active before "
            "repinning.",
            file=sys.stderr,
        )
        return 1
    print(
        "Pinned content reference matches the newest published release "
        f"{descriptor_release_id(args.release_descriptor)}."
    )
    return 0


def descriptor_release_id(path: Path) -> str:
    return str(json.loads(path.read_bytes())["releaseId"])


if __name__ == "__main__":
    sys.exit(main())
