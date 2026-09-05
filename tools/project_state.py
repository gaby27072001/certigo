#!/usr/bin/env python3
"""Generate the observable project facts embedded in docs/ETAT_DU_PROJET.md."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import NamedTuple


START_MARKER = "<!-- GENERATED:PROJECT-STATE:START -->"
END_MARKER = "<!-- GENERATED:PROJECT-STATE:END -->"
DEFAULT_DOCUMENT = Path("docs/ETAT_DU_PROJET.md")
REFERENCE_FILE = Path("docs/project-state-reference.json")
ACTIVE_CONTENT_REFERENCE_FILE = Path("docs/active-content-reference.json")
CONTENT_PACKAGE_CONTRACT_FILES = (
    Path("contracts/content-package-v2.json"),
    Path("contracts/content-package-v1.json"),
)


def _content_package_contract_path(root: Path) -> Path:
    """Resolve the canonical content-package contract inside ``root``.

    The newest envelope wins so a migration can add it without disturbing the
    superseded file, which the previous release's validator still reads.
    """
    for relative in CONTENT_PACKAGE_CONTRACT_FILES:
        if (root / relative).is_file():
            return relative
    raise ValueError(
        "No content-package contract found; expected one of "
        f"{[path.as_posix() for path in CONTENT_PACKAGE_CONTRACT_FILES]}."
    )


_REPO_ROOT = Path(__file__).resolve().parents[1]
CONTENT_PACKAGE_CONTRACT_FILE = _content_package_contract_path(_REPO_ROOT)
OBSERVABLE_PATHS = (
    ".github/workflows",
    "codemagic.yaml",
    "README.md",
    "package.json",
    "content",
    "backend/src/Certigo.Domain/Content/ContentModels.cs",
    "backend/tests",
    "apps/mobile/test",
    "apps/mobile/integration_test",
    ":(glob)packages/*/test/**",
    "docs/active-content-reference.json",
    "tools/project_state.py",
    "tools/tests",
)
OBSERVABLE_HASH_PREFIX = b"certigo-project-state-observable-v1\0"
_CONTENT_PACKAGE_SOURCE = json.loads(
    (_REPO_ROOT / CONTENT_PACKAGE_CONTRACT_FILE).read_text(encoding="utf-8")
)
_PACKAGE_CONTRACT = _CONTENT_PACKAGE_SOURCE["packageContract"]
PACKAGE_MANIFEST_SCHEMA = _PACKAGE_CONTRACT["schema"]
PACKAGE_MANIFEST_ALGORITHM = _PACKAGE_CONTRACT["algorithm"]
PACKAGE_MANIFEST_SERIALIZATION = _PACKAGE_CONTRACT["serialization"]
PACKAGE_MANIFEST_BODY_FIELDS = tuple(_PACKAGE_CONTRACT["canonicalBodyFields"])
PACKAGE_MANIFEST_DIGEST_FIELDS = tuple(_PACKAGE_CONTRACT["excludedDigestFields"])


class _ArtifactPathRule(NamedTuple):
    prefix: str
    pattern: re.Pattern[str]
    resource_types: frozenset[str]


class _ManifestShape(NamedTuple):
    """One accepted package-manifest schema and the entry/path rules it implies."""

    schema: str
    required_fields: frozenset[str]
    optional_fields: frozenset[str]
    channels: dict[str, tuple[_ArtifactPathRule, ...]]


_LEGACY_MANIFEST_SHAPES = [
    {
        "schema": "certigo.content.package-manifest/v1",
        "requiredEntryFields": ["hash", "id", "path", "size"],
        "optionalEntryFields": [],
        "channels": {
            "public": [
                {"prefix": "questions", "segmentCounts": [2], "resourceTypes": []}
            ],
            "answerKey": [
                {"prefix": "solutions", "segmentCounts": [2], "resourceTypes": []}
            ],
        },
    }
]


def _compile_channel_rules(
    channels: dict[str, object], segment: str, suffix: str, schema: str
) -> dict[str, tuple[_ArtifactPathRule, ...]]:
    """Turn a declared per-channel path enumeration into anchored matchers.

    Each rule pins one artifact prefix to an explicit set of segment counts and
    an explicit set of resourceType values, so an unknown prefix, an unexpected
    nesting depth, or a resourceType that does not belong to its prefix all stay
    hard errors instead of being absorbed by a wildcard.
    """
    compiled: dict[str, tuple[_ArtifactPathRule, ...]] = {}
    for channel, rules in channels.items():
        channel_rules: list[_ArtifactPathRule] = []
        for rule in rules:
            prefix = rule["prefix"]
            counts = sorted(rule["segmentCounts"])
            # A count below 2 would render as a `{-1}` quantifier, which Python
            # treats as a literal rather than an error, yielding a pattern that
            # silently matches nothing. Refuse it at load time instead.
            if not counts or counts[0] < 2:
                raise ValueError(
                    f"{CONTENT_PACKAGE_CONTRACT_FILE}: {schema} {channel}/{prefix} "
                    "segmentCounts must be a non-empty list of integers >= 2."
                )
            # `.`/`..` segments are refused outright so a manifest can never
            # describe a path that escapes its artifact root.
            alternatives = "|".join(
                f"{re.escape(prefix)}/(?:(?!\\.{{1,2}}/){segment}/){{{count - 2}}}"
                f"{segment}{re.escape(suffix)}"
                for count in counts
            )
            channel_rules.append(
                _ArtifactPathRule(
                    prefix,
                    re.compile(alternatives),
                    frozenset(rule["resourceTypes"]),
                )
            )
        compiled[channel] = tuple(channel_rules)
    return compiled


def _compile_manifest_shapes(source: dict[str, object]) -> dict[str, _ManifestShape]:
    segment = source.get("segmentPattern", "[A-Za-z0-9._-]+")
    suffix = source.get("fileSuffix", ".json")
    shapes: dict[str, _ManifestShape] = {}
    for shape in source.get("manifestShapes", _LEGACY_MANIFEST_SHAPES):
        schema = shape["schema"]
        required = frozenset(shape["requiredEntryFields"])
        optional = frozenset(shape["optionalEntryFields"])
        if required & optional:
            raise ValueError(
                f"{CONTENT_PACKAGE_CONTRACT_FILE}: {schema} declares "
                f"{sorted(required & optional)} as both required and optional."
            )
        shapes[schema] = _ManifestShape(
            schema,
            required,
            optional,
            _compile_channel_rules(shape["channels"], segment, suffix, schema),
        )
    return shapes


PACKAGE_MANIFEST_SHAPES = _compile_manifest_shapes(_CONTENT_PACKAGE_SOURCE)
PACKAGE_MANIFEST_SCHEMAS = frozenset(PACKAGE_MANIFEST_SHAPES)
if PACKAGE_MANIFEST_SCHEMA not in PACKAGE_MANIFEST_SHAPES:
    raise ValueError(
        f"{CONTENT_PACKAGE_CONTRACT_FILE}: the active packageContract schema "
        f"{PACKAGE_MANIFEST_SCHEMA} has no declared manifest shape."
    )
FORBIDDEN_DOMAIN_PATTERN = re.compile(
    rb"(?i)(?<![a-z0-9])(?:[a-z0-9-]+\.)*certigo\.app(?=$|[^a-z0-9-])"
)
ALLOWED_DOMAIN_AUDIT_PATH = Path("docs/UNIVERSAL_APP_LINKS.md")


class ProjectStateError(ValueError):
    """Raised when a canonical source is absent, ambiguous, or inconsistent."""


@dataclass(frozen=True)
class ActiveManifestReference:
    path: str
    channel: str
    artifact: str
    manifest_id: str
    file_count: int
    file_sha256: str


@dataclass(frozen=True)
class ActiveContentReference:
    repository: str
    branch: str
    revision: str
    date: str
    committed_at: str
    public: ActiveManifestReference
    private: ActiveManifestReference


@dataclass(frozen=True)
class ProjectState:
    reference_date: str
    reference_commit: str
    flutter_primary: str
    dotnet: str
    node: str
    active_content: ActiveContentReference
    workflows: tuple[str, ...]
    dotnet_test_projects: int
    dotnet_test_files: int
    dart_test_roots: int
    dart_test_files: int
    python_test_roots: int
    python_test_files: int
    tracks: int
    lessons: int
    pedagogical_types: tuple[str, ...]


def _read(root: Path, relative: str | Path) -> str:
    path = _path_within(root, relative)
    try:
        return path.read_text(encoding="utf-8")
    except OSError as exc:
        raise ProjectStateError(f"Cannot read canonical source {relative}: {exc}") from exc


def _read_bytes(root: Path, relative: str | Path) -> bytes:
    path = _path_within(root, relative)
    try:
        return path.read_bytes()
    except OSError as exc:
        raise ProjectStateError(f"Cannot read canonical source {relative}: {exc}") from exc


def _path_within(root: Path, relative: str | Path) -> Path:
    relative_path = Path(relative)
    if relative_path.is_absolute():
        raise ProjectStateError(f"Canonical source path must be relative: {relative}.")
    try:
        canonical_root = root.resolve(strict=True)
        candidate = (canonical_root / relative_path).resolve(strict=True)
    except OSError as exc:
        raise ProjectStateError(f"Cannot resolve canonical source {relative}: {exc}") from exc
    if not candidate.is_relative_to(canonical_root):
        raise ProjectStateError(f"Canonical source escapes its repository root: {relative}.")
    return candidate


def _one(pattern: str, text: str, source: str, flags: int = 0) -> str:
    matches = re.findall(pattern, text, flags)
    if len(matches) != 1:
        raise ProjectStateError(
            f"{source}: expected exactly one match for {pattern!r}, found {len(matches)}."
        )
    value = matches[0]
    if isinstance(value, tuple):
        value = value[0]
    return value


def _git(root: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            ["git", *args],
            cwd=root,
            check=check,
            capture_output=True,
            text=True,
        )
    except OSError as exc:
        raise ProjectStateError(f"Cannot execute git: {exc}") from exc
    except subprocess.CalledProcessError as exc:
        detail = exc.stderr.strip() or exc.stdout.strip() or f"exit {exc.returncode}"
        raise ProjectStateError(f"git {' '.join(args)} failed: {detail}") from exc


def validate_forbidden_domain_references(root: Path) -> None:
    """Reject tracked or unignored references to the uncontrolled legacy domain."""

    listed = _git(
        root,
        "ls-files",
        "-z",
        "--cached",
        "--others",
        "--exclude-standard",
    )
    violations: list[str] = []
    for value in listed.stdout.split("\0"):
        if not value:
            continue
        relative = Path(value)
        content = _read_bytes(root, relative)
        if b"\0" in content[:8000]:
            continue
        lines = content.splitlines()
        for line_number, line in enumerate(lines, start=1):
            if not FORBIDDEN_DOMAIN_PATTERN.search(line):
                continue
            context = b" ".join(lines[line_number - 1 : line_number + 1]).lower()
            allowed_audit_mention = (
                relative == ALLOWED_DOMAIN_AUDIT_PATH
                and b"tiers" in context
                and b"interdit" in context
            )
            if not allowed_audit_mention:
                violations.append(f"{relative.as_posix()}:{line_number}")
    if violations:
        domain = "certigo" + ".app"
        raise ProjectStateError(
            f"Uncontrolled domain {domain} is forbidden in repository sources: "
            + ", ".join(violations)
        )


def _observable_files(root: Path) -> tuple[Path, ...]:
    listed = _git(
        root,
        "ls-files",
        "-z",
        "--cached",
        "--others",
        "--exclude-standard",
        "--",
        *OBSERVABLE_PATHS,
    )
    paths = {
        Path(value)
        for value in listed.stdout.split("\0")
        if value and Path(value) != REFERENCE_FILE
    }
    return tuple(sorted(paths, key=lambda path: path.as_posix()))


def _git_text_attributes(
    root: Path, paths: tuple[Path, ...]
) -> dict[Path, dict[str, str]]:
    input_bytes = b"".join(
        path.as_posix().encode("utf-8") + b"\0" for path in paths
    )
    try:
        result = subprocess.run(
            ["git", "check-attr", "-z", "--stdin", "text", "eol"],
            cwd=root,
            check=True,
            capture_output=True,
            input=input_bytes,
        )
    except OSError as exc:
        raise ProjectStateError(f"Cannot execute git: {exc}") from exc
    except subprocess.CalledProcessError as exc:
        detail = exc.stderr.decode("utf-8", errors="replace").strip()
        raise ProjectStateError(f"git check-attr failed: {detail}") from exc

    fields = result.stdout.split(b"\0")
    if fields and fields[-1] == b"":
        fields.pop()
    if len(fields) % 3 != 0:
        raise ProjectStateError("git check-attr returned malformed NUL-delimited output.")

    attributes: dict[Path, dict[str, str]] = {path: {} for path in paths}
    for index in range(0, len(fields), 3):
        relative = Path(fields[index].decode("utf-8"))
        attribute = fields[index + 1].decode("utf-8")
        value = fields[index + 2].decode("utf-8")
        if relative not in attributes:
            raise ProjectStateError(
                f"git check-attr returned unexpected path {relative.as_posix()}."
            )
        attributes[relative][attribute] = value
    return attributes


def observable_sha256(root: Path) -> str:
    """Hash observable paths and Git-canonical content with length framing."""

    digest = hashlib.sha256()
    digest.update(OBSERVABLE_HASH_PREFIX)
    observable_files = _observable_files(root)
    attributes = _git_text_attributes(root, observable_files)
    for relative in observable_files:
        path_bytes = relative.as_posix().encode("utf-8")
        content = _read_bytes(root, relative)
        path_attributes = attributes[relative]
        text_attribute = path_attributes.get("text")
        is_text = text_attribute == "set" or (
            text_attribute == "auto" and b"\0" not in content[:8000]
        )
        if (
            is_text and path_attributes.get("eol") == "lf"
        ):
            content = content.replace(b"\r\n", b"\n")
        digest.update(len(path_bytes).to_bytes(8, "big"))
        digest.update(path_bytes)
        digest.update(len(content).to_bytes(8, "big"))
        digest.update(content)
    return f"sha256:{digest.hexdigest()}"


def load_reference(root: Path) -> tuple[str, str]:
    try:
        value = json.loads(_read(root, REFERENCE_FILE))
    except json.JSONDecodeError as exc:
        raise ProjectStateError(f"{REFERENCE_FILE}: invalid JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise ProjectStateError(f"{REFERENCE_FILE}: expected a JSON object.")
    commit = value.get("commit")
    if not isinstance(commit, str) or not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ProjectStateError(f"{REFERENCE_FILE}: commit must be a full 40-character SHA.")
    reference_date = value.get("date")
    if not isinstance(reference_date, str) or not re.fullmatch(
        r"\d{4}-\d{2}-\d{2}", reference_date
    ):
        raise ProjectStateError(
            f"{REFERENCE_FILE}: date must use YYYY-MM-DD."
        )
    expected_sha256 = value.get("observableSha256")
    if not isinstance(expected_sha256, str) or not re.fullmatch(
        r"sha256:[0-9a-f]{64}", expected_sha256
    ):
        raise ProjectStateError(
            f"{REFERENCE_FILE}: observableSha256 must be a sha256:<64 lowercase hex> value."
        )
    actual_sha256 = observable_sha256(root)
    if actual_sha256 != expected_sha256:
        raise ProjectStateError(
            "Observable sources differ from the captured source snapshot "
            f"{expected_sha256} (current {actual_sha256}). Commit the source changes, then run "
            "`python tools/project_state.py --refresh-reference`."
        )
    return reference_date, commit


def refresh_reference(root: Path) -> None:
    status = _git(
        root,
        "status",
        "--porcelain",
        "--untracked-files=all",
        "--",
        *OBSERVABLE_PATHS,
    )
    if status.stdout.strip():
        raise ProjectStateError(
            "Observable sources must be committed before refreshing the reference."
        )
    commit = _git(
        root, "log", "-1", "--format=%H", "--", *OBSERVABLE_PATHS
    ).stdout.strip()
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ProjectStateError("No committed observable source snapshot was found.")
    reference_date = _git(
        root, "show", "-s", "--format=%cs", commit
    ).stdout.strip()
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", reference_date):
        raise ProjectStateError(
            f"git returned an invalid reference date {reference_date!r} for {commit}."
        )
    value = {
        "commit": commit,
        "date": reference_date,
        "observableSha256": observable_sha256(root),
        "semantics": (
            "Captured source commit/date plus SHA-256 of stable-sorted observable UTF-8 path "
            "names and Git-canonical file bytes after declared text/eol normalization, framed "
            "by unsigned 64-bit big-endian path/content lengths. The generated document and "
            "this excluded reference are committed separately, avoiding self-reference while "
            "remaining valid after an equivalent squash or root commit."
        ),
    }
    path = root / REFERENCE_FILE
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8", newline="\n")


def _exact_keys(value: dict[str, object], expected: set[str], source: str) -> None:
    actual = set(value)
    if actual != expected:
        raise ProjectStateError(
            f"{source}: expected fields {sorted(expected)}, found {sorted(actual)}."
        )


def _manifest_reference(
    value: object, source: str, expected_channel: str, expected_artifact: str
) -> ActiveManifestReference:
    if not isinstance(value, dict):
        raise ProjectStateError(f"{source}: expected a JSON object.")
    _exact_keys(
        value,
        {"path", "channel", "artifact", "manifestId", "fileCount", "fileSha256"},
        source,
    )
    path = value["path"]
    channel = value["channel"]
    artifact = value["artifact"]
    manifest_id = value["manifestId"]
    file_count = value["fileCount"]
    file_sha256 = value["fileSha256"]
    if not isinstance(path, str) or not re.fullmatch(
        r"(?:(?!\.{1,2}/)[A-Za-z0-9._-]+/)+manifest\.json", path
    ):
        raise ProjectStateError(f"{source}.path: expected a manifest.json path.")
    if channel != expected_channel or artifact != expected_artifact:
        raise ProjectStateError(
            f"{source}: expected channel/artifact {expected_channel}/{expected_artifact}."
        )
    if not isinstance(manifest_id, str) or not re.fullmatch(
        r"sha256:[0-9a-f]{64}", manifest_id
    ):
        raise ProjectStateError(f"{source}.manifestId: expected sha256:<64 lowercase hex>.")
    if isinstance(file_count, bool) or not isinstance(file_count, int) or file_count < 0:
        raise ProjectStateError(f"{source}.fileCount: expected a non-negative integer.")
    if not isinstance(file_sha256, str) or not re.fullmatch(
        r"[0-9a-f]{64}", file_sha256
    ):
        raise ProjectStateError(f"{source}.fileSha256: expected 64 lowercase hex characters.")
    return ActiveManifestReference(
        path, channel, artifact, manifest_id, file_count, file_sha256
    )


def load_active_content_reference(root: Path) -> ActiveContentReference:
    try:
        value = json.loads(_read(root, ACTIVE_CONTENT_REFERENCE_FILE))
    except json.JSONDecodeError as exc:
        raise ProjectStateError(
            f"{ACTIVE_CONTENT_REFERENCE_FILE}: invalid JSON: {exc}"
        ) from exc
    if not isinstance(value, dict):
        raise ProjectStateError(f"{ACTIVE_CONTENT_REFERENCE_FILE}: expected a JSON object.")
    _exact_keys(
        value,
        {
            "schema",
            "repository",
            "branch",
            "revision",
            "date",
            "committedAt",
            "packageContract",
            "manifests",
        },
        str(ACTIVE_CONTENT_REFERENCE_FILE),
    )
    if value["schema"] != _CONTENT_PACKAGE_SOURCE["activeReferenceSchema"]:
        raise ProjectStateError(
            f"{ACTIVE_CONTENT_REFERENCE_FILE}.schema: unsupported reference schema."
        )
    repository = value["repository"]
    branch = value["branch"]
    revision = value["revision"]
    date = value["date"]
    committed_at = value["committedAt"]
    if not isinstance(repository, str) or not re.fullmatch(r"[^/]+/[^/]+", repository):
        raise ProjectStateError(
            f"{ACTIVE_CONTENT_REFERENCE_FILE}.repository: expected owner/repository."
        )
    if branch != "main":
        raise ProjectStateError(f"{ACTIVE_CONTENT_REFERENCE_FILE}.branch: expected main.")
    if not isinstance(revision, str) or not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise ProjectStateError(
            f"{ACTIVE_CONTENT_REFERENCE_FILE}.revision: expected a full commit SHA."
        )
    if not isinstance(date, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", date):
        raise ProjectStateError(
            f"{ACTIVE_CONTENT_REFERENCE_FILE}.date: expected YYYY-MM-DD."
        )
    if not isinstance(committed_at, str) or not re.fullmatch(
        r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", committed_at
    ):
        raise ProjectStateError(
            f"{ACTIVE_CONTENT_REFERENCE_FILE}.committedAt: expected UTC YYYY-MM-DDTHH:MM:SSZ."
        )
    if committed_at[:10] != date:
        raise ProjectStateError(
            f"{ACTIVE_CONTENT_REFERENCE_FILE}: date must match committedAt."
        )

    contract = value["packageContract"]
    if not isinstance(contract, dict):
        raise ProjectStateError(
            f"{ACTIVE_CONTENT_REFERENCE_FILE}.packageContract: expected an object."
        )
    _exact_keys(
        contract,
        {
            "schema",
            "algorithm",
            "serialization",
            "canonicalBodyFields",
            "excludedDigestFields",
        },
        f"{ACTIVE_CONTENT_REFERENCE_FILE}.packageContract",
    )
    expected_contract = {
        "schema": PACKAGE_MANIFEST_SCHEMA,
        "algorithm": PACKAGE_MANIFEST_ALGORITHM,
        "serialization": PACKAGE_MANIFEST_SERIALIZATION,
        "canonicalBodyFields": list(PACKAGE_MANIFEST_BODY_FIELDS),
        "excludedDigestFields": list(PACKAGE_MANIFEST_DIGEST_FIELDS),
    }
    # Every accepted schema shares one digest contract, so only `schema` may
    # differ. A reference pinned to a superseded-but-accepted schema is allowed
    # during a migration; anything else is still rejected outright.
    accepted_contracts = [
        {**expected_contract, "schema": schema} for schema in sorted(PACKAGE_MANIFEST_SCHEMAS)
    ]
    if contract not in accepted_contracts:
        raise ProjectStateError(
            f"{ACTIVE_CONTENT_REFERENCE_FILE}.packageContract: contract does not match "
            f"any accepted package manifest schema {sorted(PACKAGE_MANIFEST_SCHEMAS)}."
        )

    manifests = value["manifests"]
    if not isinstance(manifests, dict):
        raise ProjectStateError(
            f"{ACTIVE_CONTENT_REFERENCE_FILE}.manifests: expected an object."
        )
    _exact_keys(manifests, {"public", "private"}, f"{ACTIVE_CONTENT_REFERENCE_FILE}.manifests")
    public = _manifest_reference(
        manifests["public"],
        f"{ACTIVE_CONTENT_REFERENCE_FILE}.manifests.public",
        "public",
        "public",
    )
    private = _manifest_reference(
        manifests["private"],
        f"{ACTIVE_CONTENT_REFERENCE_FILE}.manifests.private",
        "answerKey",
        "private",
    )
    return ActiveContentReference(
        repository, branch, revision, date, committed_at, public, private
    )


def _canonical_manifest_id(manifest: dict[str, object]) -> str:
    body = {field: manifest[field] for field in PACKAGE_MANIFEST_BODY_FIELDS}
    try:
        canonical = json.dumps(
            body,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
    except (TypeError, ValueError) as exc:
        raise ProjectStateError(f"Manifest body is not canonical JSON data: {exc}") from exc
    return f"sha256:{hashlib.sha256(canonical).hexdigest()}"


def _validate_manifest(
    active_root: Path, reference: ActiveManifestReference
) -> None:
    source = reference.path
    raw = _read_bytes(active_root, source)
    actual_file_sha256 = hashlib.sha256(raw).hexdigest()
    if actual_file_sha256 != reference.file_sha256:
        raise ProjectStateError(
            f"{source}: file SHA-256 {actual_file_sha256} does not match "
            f"{reference.file_sha256}."
        )
    try:
        manifest = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ProjectStateError(f"{source}: invalid JSON: {exc}") from exc
    if not isinstance(manifest, dict):
        raise ProjectStateError(f"{source}: expected a JSON object.")
    expected_fields = set(PACKAGE_MANIFEST_BODY_FIELDS + PACKAGE_MANIFEST_DIGEST_FIELDS)
    _exact_keys(manifest, expected_fields, source)
    if manifest["schema"] not in PACKAGE_MANIFEST_SHAPES:
        raise ProjectStateError(f"{source}.schema: unexpected package manifest schema.")
    shape = PACKAGE_MANIFEST_SHAPES[manifest["schema"]]
    if manifest["algorithm"] != PACKAGE_MANIFEST_ALGORITHM:
        raise ProjectStateError(f"{source}.algorithm: expected sha256.")
    if manifest["serialization"] != PACKAGE_MANIFEST_SERIALIZATION:
        raise ProjectStateError(
            f"{source}.serialization: unexpected canonical serialization."
        )
    if manifest["channel"] != reference.channel or manifest["artifact"] != reference.artifact:
        raise ProjectStateError(
            f"{source}: expected channel/artifact "
            f"{reference.channel}/{reference.artifact}."
        )
    files = manifest["files"]
    file_count = manifest["fileCount"]
    if not isinstance(files, list):
        raise ProjectStateError(f"{source}.files: expected an array.")
    if (
        isinstance(file_count, bool)
        or not isinstance(file_count, int)
        or file_count != len(files)
        or file_count != reference.file_count
    ):
        raise ProjectStateError(
            f"{source}.fileCount: expected {reference.file_count} and len(files) equality."
        )
    channel_rules = shape.channels.get(reference.channel)
    if not channel_rules:
        raise ProjectStateError(
            f"{source}.channel: {shape.schema} declares no artifact paths for "
            f"{reference.channel!r}."
        )
    manifest_paths: list[str] = []
    for index, file_entry in enumerate(files):
        entry_source = f"{source}.files[{index}]"
        if not isinstance(file_entry, dict):
            raise ProjectStateError(f"{entry_source}: expected an object.")
        present = set(file_entry)
        if (present - shape.optional_fields) != shape.required_fields:
            raise ProjectStateError(
                f"{entry_source}: expected required fields "
                f"{sorted(shape.required_fields)} plus optional "
                f"{sorted(shape.optional_fields)}, found {sorted(present)}."
            )
        item_id = file_entry["id"]
        item_path = file_entry["path"]
        item_hash = file_entry["hash"]
        item_size = file_entry["size"]
        if not isinstance(item_id, str) or not item_id or "/" in item_id:
            raise ProjectStateError(f"{entry_source}.id: expected a non-empty item id.")
        if not isinstance(item_path, str):
            raise ProjectStateError(
                f"{entry_source}.path: unexpected path for {reference.channel}."
            )
        matched = next(
            (rule for rule in channel_rules if rule.pattern.fullmatch(item_path)),
            None,
        )
        if matched is None:
            raise ProjectStateError(
                f"{entry_source}.path: unexpected path for {reference.channel}."
            )
        if matched.resource_types:
            resource_type = file_entry["resourceType"]
            if resource_type not in matched.resource_types:
                raise ProjectStateError(
                    f"{entry_source}.resourceType: expected one of "
                    f"{sorted(matched.resource_types)} under {matched.prefix}/, "
                    f"found {resource_type!r}."
                )
        for optional in sorted(shape.optional_fields & present):
            value = file_entry[optional]
            if not isinstance(value, str) or not value:
                raise ProjectStateError(
                    f"{entry_source}.{optional}: expected a non-empty string."
                )
        if not isinstance(item_hash, str) or not re.fullmatch(
            r"[0-9a-f]{64}", item_hash
        ):
            raise ProjectStateError(
                f"{entry_source}.hash: expected 64 lowercase hex characters."
            )
        if isinstance(item_size, bool) or not isinstance(item_size, int) or item_size < 0:
            raise ProjectStateError(
                f"{entry_source}.size: expected a non-negative integer."
            )
        manifest_paths.append(item_path)
    if manifest_paths != sorted(manifest_paths) or len(manifest_paths) != len(
        set(manifest_paths)
    ):
        raise ProjectStateError(f"{source}.files: paths must be unique and sorted.")
    manifest_id = manifest["manifestId"]
    if manifest_id != reference.manifest_id:
        raise ProjectStateError(
            f"{source}.manifestId: expected {reference.manifest_id}, found {manifest_id}."
        )
    canonical_manifest_id = _canonical_manifest_id(manifest)
    if manifest_id != canonical_manifest_id:
        raise ProjectStateError(
            f"{source}.manifestId: canonical body hashes to {canonical_manifest_id}."
        )
    root_hash = manifest["rootHash"]
    if not isinstance(root_hash, str) or not re.fullmatch(r"[0-9a-f]{64}", root_hash):
        raise ProjectStateError(f"{source}.rootHash: expected 64 lowercase hex characters.")
    if manifest_id != f"sha256:{root_hash}":
        raise ProjectStateError(
            f"{source}: manifestId must be the sha256-prefixed rootHash."
        )


def validate_active_content_repository(root: Path, active_root: Path) -> None:
    reference = load_active_content_reference(root)
    revision = _git(active_root, "rev-parse", "HEAD").stdout.strip()
    if revision != reference.revision:
        raise ProjectStateError(
            f"Active content revision {revision} does not match {reference.revision}."
        )
    timestamp = _git(active_root, "show", "-s", "--format=%cI", "HEAD").stdout.strip()
    try:
        parsed_timestamp = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ProjectStateError(
            f"git returned an invalid active content timestamp {timestamp!r}."
        ) from exc
    if parsed_timestamp.tzinfo is None:
        raise ProjectStateError(
            f"git returned a timezone-less active content timestamp {timestamp!r}."
        )
    committed_at = parsed_timestamp.astimezone(timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%SZ"
    )
    if committed_at != reference.committed_at:
        raise ProjectStateError(
            f"Active content commit time {committed_at} does not match "
            f"{reference.committed_at}."
        )
    _validate_manifest(active_root, reference.public)
    _validate_manifest(active_root, reference.private)


def parse_versions(root: Path) -> tuple[str, str, str]:
    mobile = _read(root, ".github/workflows/ci-mobile.yml")
    android = _read(root, ".github/workflows/release-android.yml")
    codemagic = _read(root, "codemagic.yaml")
    backend = _read(root, ".github/workflows/ci-backend.yml")

    primary = _one(
        r'^\s*FLUTTER_VERSION:\s*["\']([^"\']+)["\']',
        mobile,
        ".github/workflows/ci-mobile.yml",
        re.M,
    )
    android_version = _one(
        r'^\s*FLUTTER_VERSION:\s*["\']([^"\']+)["\']',
        android,
        ".github/workflows/release-android.yml",
        re.M,
    )

    codemagic_versions: dict[str, str] = {}
    for workflow in ("ios-release", "ios-release-dry"):
        body = _one(
            rf"^  {re.escape(workflow)}:\s*\n(.*?)(?=^  [a-z][a-z0-9-]+:\s*\n|\Z)",
            codemagic,
            f"codemagic.yaml workflow {workflow}",
            re.M | re.S,
        )
        codemagic_versions[workflow] = _one(
            r"^\s{6}flutter:\s*([^\s#]+)",
            body,
            f"codemagic.yaml workflow {workflow}",
            re.M,
        )

    primary_sources = {
        "ci-mobile/app": primary,
        "release-android": android_version,
        **{f"codemagic/{name}": version for name, version in codemagic_versions.items()},
    }
    if len(set(primary_sources.values())) != 1:
        details = ", ".join(f"{name}={version}" for name, version in primary_sources.items())
        raise ProjectStateError(f"Primary Flutter versions are misaligned: {details}.")
    readme = _read(root, "README.md")
    expected_readme_pin = f"| Flutter SDK | **{primary}**"
    if expected_readme_pin not in readme:
        raise ProjectStateError(
            f"README.md: expected primary Flutter documentation {expected_readme_pin!r}."
        )

    dotnet = _one(
        r'^\s*dotnet-version:\s*["\']([^"\']+)["\']',
        backend,
        ".github/workflows/ci-backend.yml",
        re.M,
    )
    try:
        package = json.loads(_read(root, "package.json"))
    except json.JSONDecodeError as exc:
        raise ProjectStateError(f"package.json: invalid JSON: {exc}") from exc
    node = package.get("engines", {}).get("node") if isinstance(package, dict) else None
    if not isinstance(node, str) or not node.strip():
        raise ProjectStateError("package.json: engines.node is required.")
    return primary, dotnet, node


def parse_pedagogical_types(root: Path) -> tuple[str, ...]:
    try:
        schema = json.loads(_read(root, "content/schema/lesson.schema.json"))
        schema_types = schema["$defs"]["item"]["properties"]["type"]["enum"]
    except (json.JSONDecodeError, KeyError, TypeError) as exc:
        raise ProjectStateError(
            "content/schema/lesson.schema.json: cannot read $defs.item.properties.type.enum."
        ) from exc
    if not isinstance(schema_types, list) or not all(
        isinstance(item, str) and item for item in schema_types
    ):
        raise ProjectStateError("lesson.schema.json: pedagogical type enum must be strings.")

    models = _read(root, "backend/src/Certigo.Domain/Content/ContentModels.cs")
    body = _one(
        r"public\s+enum\s+ItemType\s*\{(.*?)\}",
        models,
        "ContentModels.cs ItemType",
        re.S,
    )
    csharp_types = []
    for member in body.split(","):
        name = re.sub(r"//.*", "", member).strip()
        if name:
            csharp_types.append(name[0].lower() + name[1:])
    if schema_types != csharp_types:
        raise ProjectStateError(
            "Pedagogical types are misaligned: "
            f"lesson.schema.json={schema_types}, ContentModels.cs={csharp_types}."
        )
    return tuple(schema_types)


def discover_tests(root: Path) -> tuple[int, int, int, int, int, int]:
    dotnet_projects = sorted((root / "backend/tests").glob("*/*.csproj"))
    dotnet_files = sorted((root / "backend/tests").rglob("*Tests.cs"))

    dart_roots = [
        path
        for path in (
            root / "apps/mobile/test",
            root / "apps/mobile/integration_test",
            *sorted((root / "packages").glob("*/test")),
        )
        if path.is_dir()
    ]
    dart_files = [
        path
        for test_root in dart_roots
        for path in test_root.rglob("*_test.dart")
        if path.is_file()
    ]
    python_files = sorted((root / "tools/tests").glob("test_*.py"))
    python_roots = {path.parent for path in python_files}
    if not dotnet_projects or not dotnet_files or not dart_roots or not dart_files:
        raise ProjectStateError(
            "Test discovery found an empty required family (.NET projects/files or Dart roots/files)."
        )
    return (
        len(dotnet_projects),
        len(dotnet_files),
        len(dart_roots),
        len(dart_files),
        len(python_roots),
        len(python_files),
    )


def discover_corpus(root: Path) -> tuple[int, int]:
    content = root / "content"
    tracks = sorted(path.parent for path in content.glob("*/track.yaml"))
    lessons = sorted(content.glob("*/lessons/*.lesson.yaml"))
    if not tracks or not lessons:
        raise ProjectStateError(
            "Historical corpus discovery requires content/*/track.yaml and "
            "content/*/lessons/*.lesson.yaml."
        )
    return len(tracks), len(lessons)


def collect(root: Path) -> ProjectState:
    validate_forbidden_domain_references(root)
    reference_date, reference_commit = load_reference(root)
    flutter, dotnet, node = parse_versions(root)
    active_content = load_active_content_reference(root)
    workflow_paths = {
        *Path(root / ".github/workflows").glob("*.yml"),
        *Path(root / ".github/workflows").glob("*.yaml"),
    }
    workflows = tuple(path.name for path in sorted(workflow_paths))
    if not workflows:
        raise ProjectStateError("No .github/workflows/*.yml or *.yaml files were discovered.")
    tests = discover_tests(root)
    tracks, lessons = discover_corpus(root)
    pedagogical_types = parse_pedagogical_types(root)
    return ProjectState(
        reference_date,
        reference_commit,
        flutter,
        dotnet,
        node,
        active_content,
        workflows,
        *tests,
        tracks,
        lessons,
        pedagogical_types,
    )


def render(state: ProjectState) -> str:
    total_test_files = (
        state.dotnet_test_files + state.dart_test_files + state.python_test_files
    )
    workflow_list = ", ".join(f"`{name}`" for name in state.workflows)
    item_types = ", ".join(f"`{name}`" for name in state.pedagogical_types)
    return "\n".join(
        [
            START_MARKER,
            "",
            "## État technique généré",
            "",
            "> Ne pas modifier ce bloc à la main. Sources et commande sont documentées juste après.",
            "",
            "| Fait observable | Valeur générée |",
            "|---|---|",
            f"| Date de référence analysée | **{state.reference_date}** |",
            f"| Commit de référence analysé | `{state.reference_commit}` |",
            f"| Flutter | **{state.flutter_primary}** — aligné entre `ci-mobile` (app et goldens), Android et les deux workflows iOS Codemagic |",
            f"| .NET CI | **{state.dotnet}** |",
            f"| Node.js outillage | **{state.node}** (`package.json#engines`) |",
            f"| Contenu actif | `{state.active_content.repository}@{state.active_content.branch}` — révision `{state.active_content.revision}` du **{state.active_content.date}** |",
            f"| Package public actif | **{state.active_content.public.file_count} fichiers** — `{state.active_content.public.manifest_id}` |",
            f"| Package privé actif (`answerKey`) | **{state.active_content.private.file_count} fichiers** — `{state.active_content.private.manifest_id}` |",
            f"| Workflows GitHub Actions | **{len(state.workflows)}** fichiers : {workflow_list} |",
            f"| Tests découverts | **{total_test_files} fichiers** — .NET : {state.dotnet_test_projects} projets / {state.dotnet_test_files} fichiers ; Flutter/Dart : {state.dart_test_roots} racines / {state.dart_test_files} fichiers ; Python : {state.python_test_roots} racine / {state.python_test_files} fichier |",
            f"| Corpus **historique** local | **{state.tracks} pistes**, **{state.lessons} leçons** sous `content/` — instantané de compatibilité, non actif |",
            f"| Types pédagogiques canoniques | **{len(state.pedagogical_types)}** : {item_types} (schéma JSON et `ItemType` C# alignés) |",
            "",
            END_MARKER,
        ]
    )


def replace_generated(document: str, generated: str) -> str:
    start_count = document.count(START_MARKER)
    end_count = document.count(END_MARKER)
    if start_count != 1 or end_count != 1:
        raise ProjectStateError(
            "docs/ETAT_DU_PROJET.md must contain exactly one start and one end "
            f"GENERATED:PROJECT-STATE marker (found start={start_count}, end={end_count})."
        )
    start = document.index(START_MARKER)
    end = document.index(END_MARKER)
    if end < start:
        raise ProjectStateError("GENERATED:PROJECT-STATE end marker precedes start marker.")
    end += len(END_MARKER)
    return document[:start] + generated + document[end:]


def update(root: Path, check: bool, document_path: Path = DEFAULT_DOCUMENT) -> bool:
    if check:
        generator_path = Path(__file__).with_name("generated_contracts.py")
        spec = importlib.util.spec_from_file_location("generated_contracts", generator_path)
        if spec is None or spec.loader is None:
            raise ProjectStateError(f"Cannot load generated-contract checker {generator_path}.")
        generated_contracts = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(generated_contracts)
        try:
            generated_contracts.refresh(root, check=True)
        except generated_contracts.ContractError as exc:
            raise ProjectStateError(str(exc)) from exc
    path = root / document_path
    current = _read(root, document_path)
    expected = replace_generated(current, render(collect(root)))
    if current == expected:
        return False
    if check:
        raise ProjectStateError(
            f"{document_path} is stale. Run `python tools/project_state.py --update` "
            "and commit the result."
        )
    path.write_text(expected, encoding="utf-8", newline="\n")
    return True


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--update", action="store_true", help="rewrite the generated block")
    mode.add_argument("--check", action="store_true", help="fail if the committed block is stale")
    mode.add_argument(
        "--refresh-reference",
        action="store_true",
        help="point at committed observable sources and rewrite the generated block",
    )
    mode.add_argument(
        "--validate-active-content",
        metavar="PATH",
        type=Path,
        help="validate a packaged certigo-content checkout against the active reference",
    )
    parser.add_argument(
        "--root",
        metavar="PATH",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="repository workspace to inspect (defaults to this script's repository)",
    )
    args = parser.parse_args(argv)
    try:
        root = args.root.resolve(strict=True)
        if not root.is_dir():
            raise ProjectStateError(f"Repository root is not a directory: {root}.")
        if args.validate_active_content:
            validate_active_content_repository(root, args.validate_active_content.resolve())
            print("Active content reference is current.")
            return 0
        if args.refresh_reference:
            refresh_reference(root)
        changed = update(root, check=args.check)
    except ProjectStateError as exc:
        print(f"project-state: {exc}", file=sys.stderr)
        return 1
    if args.check:
        print("Project state is current.")
    else:
        print("Project state updated." if changed else "Project state already current.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
