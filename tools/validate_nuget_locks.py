#!/usr/bin/env python3
"""Validate committed NuGet lockfiles without evaluating untrusted MSBuild projects."""

from __future__ import annotations

import argparse
import base64
import binascii
import json
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path, PurePosixPath


PACKAGE_ID = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*")
EXACT_VERSION = re.compile(r"[0-9A-Za-z][0-9A-Za-z.+-]*")


class NuGetLockError(RuntimeError):
    """Raised when a project/lockfile pair is missing, stale, or malformed."""


def _local_name(name: str) -> str:
    return name.rsplit("}", 1)[-1]


def _tracked_paths(root: Path) -> tuple[PurePosixPath, ...]:
    try:
        result = subprocess.run(
            [
                "git",
                "-c",
                "core.hooksPath=/dev/null",
                "ls-files",
                "-z",
            ],
            cwd=root,
            check=True,
            capture_output=True,
        )
    except OSError as exc:
        raise NuGetLockError(f"Cannot execute git: {exc}") from exc
    except subprocess.CalledProcessError as exc:
        detail = exc.stderr.decode("utf-8", errors="replace").strip()
        raise NuGetLockError(f"git ls-files failed: {detail}") from exc
    paths = tuple(
        PurePosixPath(value.decode("utf-8"))
        for value in result.stdout.split(b"\0")
        if value
    )
    for relative in paths:
        if relative.is_absolute() or ".." in relative.parts:
            raise NuGetLockError(f"Git returned an unsafe tracked path: {relative}.")
    return paths


def _safe_file(root: Path, relative: PurePosixPath) -> Path:
    path = root.joinpath(*relative.parts)
    if path.is_symlink():
        raise NuGetLockError(f"{relative}: symlinks are not allowed.")
    try:
        canonical_root = root.resolve(strict=True)
        candidate = path.resolve(strict=True)
    except OSError as exc:
        raise NuGetLockError(f"Cannot resolve tracked file {relative}: {exc}") from exc
    if not candidate.is_relative_to(canonical_root) or not candidate.is_file():
        raise NuGetLockError(f"{relative}: expected a regular file inside the repository.")
    return candidate


def _condition(element: ET.Element) -> str | None:
    for name, value in element.attrib.items():
        if _local_name(name).lower() == "condition" and value.strip():
            return value
    return None


def _direct_references(project_path: Path, source: PurePosixPath) -> dict[str, tuple[str, str]]:
    try:
        raw = project_path.read_text(encoding="utf-8")
    except OSError as exc:
        raise NuGetLockError(f"Cannot read {source}: {exc}") from exc
    if "<!DOCTYPE" in raw.upper() or "<!ENTITY" in raw.upper():
        raise NuGetLockError(f"{source}: DTD and entity declarations are not allowed.")
    try:
        root = ET.fromstring(raw)
    except ET.ParseError as exc:
        raise NuGetLockError(f"{source}: invalid XML: {exc}") from exc
    if _local_name(root.tag) != "Project":
        raise NuGetLockError(f"{source}: expected an MSBuild Project root.")
    root_attributes = {
        _local_name(name).lower(): value.strip()
        for name, value in root.attrib.items()
    }
    if root_attributes.get("sdk") != "Microsoft.NET.Sdk":
        raise NuGetLockError(
            f"{source}: Project Sdk must be exactly Microsoft.NET.Sdk."
        )

    references: dict[str, tuple[str, str]] = {}

    def walk(
        element: ET.Element,
        conditional: bool,
        ancestors: tuple[str, ...],
    ) -> None:
        element_name = _local_name(element.tag)
        if element_name in {"Import", "Choose", "Sdk"}:
            raise NuGetLockError(
                f"{source}: {element_name} elements are unsupported."
            )
        current_conditional = conditional or _condition(element) is not None
        if element_name == "PackageReference":
            if current_conditional:
                raise NuGetLockError(
                    f"{source}: conditional PackageReference elements are unsupported."
                )
            if ancestors != ("Project", "ItemGroup"):
                raise NuGetLockError(
                    f"{source}: PackageReference must be directly inside an ItemGroup."
                )
            attributes = {
                _local_name(name).lower(): value.strip()
                for name, value in element.attrib.items()
            }
            package_name = attributes.get("include", "")
            if not PACKAGE_ID.fullmatch(package_name):
                raise NuGetLockError(
                    f"{source}: PackageReference Include must be a literal NuGet package ID."
                )
            child_versions = [
                child
                for child in element
                if _local_name(child.tag) == "Version"
            ]
            if len(child_versions) > 1:
                raise NuGetLockError(
                    f"{source}: {package_name} has multiple Version elements."
                )
            attribute_version = attributes.get("version")
            child_version = None
            if child_versions:
                if _condition(child_versions[0]) is not None:
                    raise NuGetLockError(
                        f"{source}: conditional versions are unsupported for {package_name}."
                    )
                child_version = (child_versions[0].text or "").strip()
            if attribute_version and child_version:
                raise NuGetLockError(
                    f"{source}: {package_name} defines Version twice."
                )
            version = attribute_version or child_version or ""
            if (
                not EXACT_VERSION.fullmatch(version)
                or any(character in version for character in "*$[](),")
            ):
                raise NuGetLockError(
                    f"{source}: {package_name} must use a literal exact Version."
                )
            key = package_name.casefold()
            if key in references:
                raise NuGetLockError(
                    f"{source}: duplicate PackageReference for {package_name}."
                )
            references[key] = (package_name, version)
        for child in element:
            walk(child, current_conditional, (*ancestors, element_name))

    walk(root, False, ())
    return references


def _reject_duplicate_keys(pairs: list[tuple[str, object]]) -> dict[str, object]:
    value: dict[str, object] = {}
    for key, item in pairs:
        if key in value:
            raise NuGetLockError(f"Duplicate JSON key {key!r}.")
        value[key] = item
    return value


def _load_lock(lock_path: Path, source: PurePosixPath) -> dict[str, object]:
    try:
        raw = lock_path.read_text(encoding="utf-8")
    except OSError as exc:
        raise NuGetLockError(f"Cannot read {source}: {exc}") from exc
    try:
        value = json.loads(raw, object_pairs_hook=_reject_duplicate_keys)
    except (json.JSONDecodeError, NuGetLockError) as exc:
        raise NuGetLockError(f"{source}: invalid lock JSON: {exc}") from exc
    if not isinstance(value, dict) or set(value) != {"version", "dependencies"}:
        raise NuGetLockError(
            f"{source}: expected only version and dependencies at the document root."
        )
    if isinstance(value["version"], bool) or value["version"] != 1:
        raise NuGetLockError(f"{source}: expected NuGet lock schema version 1.")
    if not isinstance(value["dependencies"], dict) or not value["dependencies"]:
        raise NuGetLockError(f"{source}: dependencies must contain at least one target.")
    return value


def _validate_content_hash(value: object, source: str) -> None:
    if not isinstance(value, str) or not value:
        raise NuGetLockError(f"{source}.contentHash: expected non-empty base64.")
    try:
        decoded = base64.b64decode(value, validate=True)
    except (ValueError, binascii.Error) as exc:
        raise NuGetLockError(f"{source}.contentHash: invalid base64.") from exc
    if len(decoded) != 64:
        raise NuGetLockError(
            f"{source}.contentHash: expected a 64-byte SHA-512 digest."
        )


def _validate_graph(
    graph: object,
    direct_references: dict[str, tuple[str, str]],
    source: str,
) -> int:
    if not isinstance(graph, dict):
        raise NuGetLockError(f"{source}: expected a package object.")
    packages: dict[str, tuple[str, dict[str, object]]] = {}
    for package_name, entry in graph.items():
        if not isinstance(package_name, str) or not PACKAGE_ID.fullmatch(package_name):
            raise NuGetLockError(f"{source}: invalid package ID {package_name!r}.")
        if not isinstance(entry, dict):
            raise NuGetLockError(f"{source}.{package_name}: expected an object.")
        key = package_name.casefold()
        if key in packages:
            raise NuGetLockError(
                f"{source}: duplicate case-insensitive package ID {package_name}."
            )
        packages[key] = (package_name, entry)

    direct_packages = {
        key for key, (_, entry) in packages.items() if entry.get("type") == "Direct"
    }
    if direct_packages != set(direct_references):
        missing = sorted(set(direct_references) - direct_packages)
        extra = sorted(direct_packages - set(direct_references))
        raise NuGetLockError(
            f"{source}: Direct packages differ from the project "
            f"(missing={missing}, extra={extra})."
        )

    for key, (declared_name, version) in direct_references.items():
        locked_name, entry = packages[key]
        if entry.get("type") != "Direct":
            raise NuGetLockError(f"{source}.{locked_name}: expected type Direct.")
        expected_requested = f"[{version}, )"
        if entry.get("requested") != expected_requested or entry.get("resolved") != version:
            raise NuGetLockError(
                f"{source}.{locked_name}: expected requested {expected_requested!r} "
                f"and resolved {version!r} for {declared_name}."
            )

    allowed_keys = {
        "Direct": ({"type", "requested", "resolved", "contentHash"}, {"dependencies"}),
        "Transitive": ({"type", "resolved", "contentHash"}, {"dependencies"}),
        "Project": ({"type"}, {"dependencies"}),
    }
    for package_name, entry in packages.values():
        entry_type = entry.get("type")
        if entry_type not in allowed_keys:
            raise NuGetLockError(
                f"{source}.{package_name}.type: unsupported value {entry_type!r}."
            )
        required, optional = allowed_keys[entry_type]
        keys = set(entry)
        if not required.issubset(keys) or not keys.issubset(required | optional):
            raise NuGetLockError(
                f"{source}.{package_name}: malformed {entry_type} lock entry."
            )
        if entry_type != "Project":
            resolved = entry["resolved"]
            if not isinstance(resolved, str) or not resolved:
                raise NuGetLockError(
                    f"{source}.{package_name}.resolved: expected a version."
                )
            _validate_content_hash(
                entry["contentHash"], f"{source}.{package_name}"
            )
        dependencies = entry.get("dependencies", {})
        if not isinstance(dependencies, dict):
            raise NuGetLockError(
                f"{source}.{package_name}.dependencies: expected an object."
            )
        for dependency_name, dependency_version in dependencies.items():
            if (
                not isinstance(dependency_name, str)
                or dependency_name.casefold() not in packages
            ):
                raise NuGetLockError(
                    f"{source}.{package_name}: dependency {dependency_name!r} "
                    "is absent from the target graph."
                )
            if not isinstance(dependency_version, str) or not dependency_version:
                raise NuGetLockError(
                    f"{source}.{package_name}.{dependency_name}: expected a version."
                )
    reachable = {
        key
        for key, (_, entry) in packages.items()
        if entry.get("type") in {"Direct", "Project"}
    }
    pending = list(reachable)
    while pending:
        current = pending.pop()
        dependencies = packages[current][1].get("dependencies", {})
        assert isinstance(dependencies, dict)
        for dependency_name in dependencies:
            dependency_key = dependency_name.casefold()
            if dependency_key not in reachable:
                reachable.add(dependency_key)
                pending.append(dependency_key)
    unreachable = sorted(set(packages) - reachable)
    if unreachable:
        raise NuGetLockError(
            f"{source}: package entries are unreachable from Direct/Project roots: "
            f"{unreachable}."
        )
    return len(packages)


def validate_repository(root: Path) -> tuple[int, int, int]:
    canonical_root = root.resolve(strict=True)
    tracked = _tracked_paths(canonical_root)
    projects = tuple(
        path
        for path in tracked
        if path.parts
        and path.parts[0] == "backend"
        and path.suffix.casefold() == ".csproj"
    )
    tracked_locks = {
        path
        for path in tracked
        if path.parts
        and path.parts[0] == "backend"
        and path.name.casefold() == "packages.lock.json"
    }
    unsupported_configuration = sorted(
        str(path)
        for path in tracked
        if path.name.casefold()
        in {
            "directory.build.props",
            "directory.build.targets",
            "directory.packages.props",
            "directory.packages.targets",
        }
    )
    if unsupported_configuration:
        raise NuGetLockError(
            "Central/imported MSBuild dependency configuration is unsupported: "
            f"{unsupported_configuration}."
        )
    if not projects:
        raise NuGetLockError("No tracked backend .csproj files were found.")
    expected_locks = {
        project.parent / "packages.lock.json" for project in projects
    }
    if tracked_locks != expected_locks:
        missing = sorted(str(path) for path in expected_locks - tracked_locks)
        orphaned = sorted(str(path) for path in tracked_locks - expected_locks)
        raise NuGetLockError(
            "Tracked lockfiles must map one-to-one with backend projects "
            f"(missing={missing}, orphaned={orphaned})."
        )

    target_count = 0
    package_count = 0
    for project in sorted(projects, key=str):
        lock = project.parent / "packages.lock.json"
        references = _direct_references(
            _safe_file(canonical_root, project), project
        )
        lock_value = _load_lock(_safe_file(canonical_root, lock), lock)
        dependencies = lock_value["dependencies"]
        assert isinstance(dependencies, dict)
        for target, graph in dependencies.items():
            if not isinstance(target, str) or not target.strip():
                raise NuGetLockError(f"{lock}: target names must be non-empty strings.")
            package_count += _validate_graph(
                graph, references, f"{lock}.dependencies.{target}"
            )
            target_count += 1
    return len(projects), target_count, package_count


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="repository root to validate",
    )
    args = parser.parse_args(argv)
    try:
        projects, targets, packages = validate_repository(args.root)
    except (NuGetLockError, OSError) as exc:
        print(f"nuget-locks: {exc}", file=sys.stderr)
        return 1
    print(
        f"NuGet locks valid: {projects} projects, {targets} targets, "
        f"{packages} package entries."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
