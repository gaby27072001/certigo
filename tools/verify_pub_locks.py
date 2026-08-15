#!/usr/bin/env python3
"""Resolve trusted-inventory Pub manifests without allowing lockfile changes."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path, PurePosixPath


class PubLockVerificationError(RuntimeError):
    """Raised when Pub resolution cannot prove the committed locks are current."""


def _load_manifest_paths(contract_file: Path) -> tuple[PurePosixPath, ...]:
    try:
        contract = json.loads(contract_file.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise PubLockVerificationError(f"Invalid dependency contract: {exc}") from exc
    if not isinstance(contract, dict):
        raise PubLockVerificationError("Dependency contract must be a JSON object.")
    values = contract.get("pubManifests")
    if (
        not isinstance(values, list)
        or not values
        or any(not isinstance(value, str) or not value for value in values)
    ):
        raise PubLockVerificationError(
            "Dependency contract must contain a non-empty pubManifests string list."
        )
    if values != sorted(set(values)):
        raise PubLockVerificationError(
            "Dependency contract pubManifests must be sorted and unique."
        )
    return tuple(PurePosixPath(value) for value in values)


def _safe_file(root: Path, relative: PurePosixPath, expected_name: str) -> Path:
    if (
        relative.is_absolute()
        or ".." in relative.parts
        or relative.name != expected_name
    ):
        raise PubLockVerificationError(f"{relative}: unsafe dependency path.")
    candidate = root.joinpath(*relative.parts)
    if candidate.is_symlink():
        raise PubLockVerificationError(f"{relative}: symbolic paths are forbidden.")
    try:
        resolved = candidate.resolve(strict=True)
    except OSError as exc:
        raise PubLockVerificationError(f"Cannot resolve {relative}: {exc}") from exc
    if not resolved.is_relative_to(root) or not resolved.is_file():
        raise PubLockVerificationError(f"{relative}: expected a repository file.")
    return resolved


def verify_pub_locks(
    root: Path,
    contract_file: Path,
    flutter_executable: Path,
    pub_cache: Path,
) -> int:
    canonical_root = root.resolve(strict=True)
    executable = flutter_executable.resolve(strict=True)
    if not executable.is_file() or executable.is_relative_to(canonical_root):
        raise PubLockVerificationError(
            f"Flutter executable must be a trusted file outside the source: {executable}"
        )
    isolated_cache = pub_cache.resolve()
    if isolated_cache.is_relative_to(canonical_root):
        raise PubLockVerificationError("PUB_CACHE must be outside the source checkout.")
    isolated_cache.mkdir(parents=True, exist_ok=True)

    manifests = _load_manifest_paths(contract_file.resolve(strict=True))
    locks: list[PurePosixPath] = []
    baseline: dict[PurePosixPath, bytes] = {}
    for manifest in manifests:
        manifest_file = _safe_file(canonical_root, manifest, "pubspec.yaml")
        lock = manifest.parent / "pubspec.lock"
        lock_file = _safe_file(canonical_root, lock, "pubspec.lock")
        locks.append(lock)
        baseline[lock] = lock_file.read_bytes()

        environment = os.environ.copy()
        environment["PUB_CACHE"] = str(isolated_cache)
        try:
            subprocess.run(
                [str(executable), "pub", "get", "--enforce-lockfile"],
                cwd=manifest_file.parent,
                env=environment,
                check=True,
            )
        except subprocess.CalledProcessError as exc:
            raise PubLockVerificationError(
                f"{manifest}: flutter pub get --enforce-lockfile failed "
                f"with exit code {exc.returncode}."
            ) from exc

        if lock_file.read_bytes() != baseline[lock]:
            raise PubLockVerificationError(
                f"{lock}: Pub resolution changed the committed lockfile."
            )

    for lock, expected in baseline.items():
        lock_file = _safe_file(canonical_root, lock, "pubspec.lock")
        if lock_file.read_bytes() != expected:
            raise PubLockVerificationError(
                f"{lock}: a later Pub resolution changed the committed lockfile."
            )

    try:
        subprocess.run(
            [
                "git",
                "-c",
                "core.hooksPath=/dev/null",
                "diff",
                "--exit-code",
                "--",
                *(str(lock) for lock in locks),
            ],
            cwd=canonical_root,
            check=True,
        )
    except (OSError, subprocess.CalledProcessError) as exc:
        raise PubLockVerificationError(
            "Pub lockfiles differ from the checked-out Git index."
        ) from exc

    return len(manifests)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--contract", type=Path, required=True)
    parser.add_argument("--flutter", type=Path, required=True)
    parser.add_argument("--pub-cache", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        count = verify_pub_locks(
            args.root,
            args.contract,
            args.flutter,
            args.pub_cache,
        )
    except (OSError, PubLockVerificationError) as exc:
        print(f"pub-locks: {exc}", file=sys.stderr)
        return 1
    print(f"Pub lock resolution valid: {count} manifest(s), lockfiles unchanged.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
