#!/usr/bin/env python3
"""Cross-check the migration registry against real GitHub PR state.

This is a **manual, on-demand** verification helper -- it is not wired into any
CI gate. `tools/validate_migration_registry.py` already guarantees internal
consistency (work-packages.yaml <-> STATE.md <-> state/*.json <-> log.jsonl),
but nothing in that gate can verify that a package's declared status still
matches the *external*, live state of its linked GitHub pull request: a PR can
merge (or close) at any time without anyone updating the registry, which is
exactly the drift found and fixed during the 2026-09-03 documentation
consolidation (`wp-p1-10-mobile-crash-reporting`, `wp-p2-08`).

This script reads each work package's linked PR (from `state/<id>.json`'s
`pr` field, which is a much more structured source than the free-text `notes`
field in `work-packages.yaml`) and calls `gh pr view` to compare the
registry's declared status against the PR's real state. It never edits any
file -- it only reports. A human (or a future session) decides what to do with
a reported mismatch, because a merged PR does not always mean the work
package's Definition of Done is fully satisfied (see wp-p1-10: PR merged, but
only partial DoD delivered).

Usage:
    python tools/check_migration_pr_status.py
    python tools/check_migration_pr_status.py --id wp-p2-09
    python tools/check_migration_pr_status.py --repo gchambaud_microsoft/Certigo

Requires the `gh` CLI, authenticated against GitHub.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError as exc:  # pragma: no cover - exercised by CI setup failures
    raise SystemExit(
        "PyYAML is required: install it with `python -m pip install PyYAML`."
    ) from exc


ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "docs" / "migration" / "work-packages.yaml"
STATE_DIR = ROOT / "docs" / "migration" / "state"
DEFAULT_REPO = "gchambaud_microsoft/Certigo"
PLACEHOLDER_PREFIX = "wp-phase-"

# Statuses for which a merged PR is the *expected* end state. Anything else
# (todo, blocked, planned) has no strict expectation and is skipped unless
# a PR happens to be linked anyway.
STATUS_EXPECTS_MERGED = {"done"}
STATUS_EXPECTS_OPEN = {"in_review", "in_progress"}

PR_NUMBER_IN_URL = re.compile(r"/pull/(\d+)")


@dataclass(frozen=True)
class PackageCheck:
    package_id: str
    manifest_status: str
    pr_number: int | None
    pr_state: str | None
    pr_merged_at: str | None
    pr_title: str | None
    mismatch: str | None


def load_manifest() -> dict[str, dict[str, Any]]:
    data = yaml.safe_load(MANIFEST_PATH.read_text(encoding="utf-8"))
    packages = data["work_packages"] if isinstance(data, dict) else data
    result: dict[str, dict[str, Any]] = {}
    for entry in packages:
        if isinstance(entry, dict) and "id" in entry:
            result[entry["id"]] = entry
    return result


def extract_pr_number(pr_field: Any) -> int | None:
    if pr_field is None:
        return None
    if isinstance(pr_field, int):
        return pr_field
    if isinstance(pr_field, str):
        match = PR_NUMBER_IN_URL.search(pr_field)
        if match:
            return int(match.group(1))
        if pr_field.isdigit():
            return int(pr_field)
    return None


def fetch_pr_state(repo: str, pr_number: int) -> dict[str, Any] | None:
    try:
        completed = subprocess.run(
            [
                "gh",
                "pr",
                "view",
                str(pr_number),
                "--repo",
                repo,
                "--json",
                "number,title,state,mergedAt,url",
            ],
            capture_output=True,
            text=True,
            check=False,
            timeout=30,
        )
    except FileNotFoundError:
        print(
            "error: `gh` CLI not found on PATH. Install/authenticate the "
            "GitHub CLI to use this script.",
            file=sys.stderr,
        )
        raise SystemExit(2)
    if completed.returncode != 0:
        print(
            f"warning: `gh pr view {pr_number}` failed: "
            f"{completed.stderr.strip()}",
            file=sys.stderr,
        )
        return None
    try:
        return json.loads(completed.stdout)
    except json.JSONDecodeError:
        print(
            f"warning: could not parse `gh pr view {pr_number}` output.",
            file=sys.stderr,
        )
        return None


def evaluate(package_id: str, manifest_status: str, pr: dict[str, Any] | None) -> PackageCheck:
    if pr is None:
        return PackageCheck(package_id, manifest_status, None, None, None, None, None)

    pr_state = pr.get("state")
    merged_at = pr.get("mergedAt")
    mismatch = None
    if manifest_status in STATUS_EXPECTS_MERGED and pr_state != "MERGED":
        mismatch = (
            f"registry says {manifest_status!r} but PR #{pr['number']} is "
            f"{pr_state!r} (not merged)."
        )
    elif manifest_status in STATUS_EXPECTS_OPEN and pr_state == "MERGED":
        mismatch = (
            f"registry says {manifest_status!r} but PR #{pr['number']} is "
            f"already MERGED ({merged_at}). Re-verify the Definition of Done "
            "before flipping the status to `done` -- a merged PR does not "
            "always mean the work package is fully complete (see "
            "wp-p1-10-mobile-crash-reporting)."
        )
    return PackageCheck(
        package_id,
        manifest_status,
        pr.get("number"),
        pr_state,
        merged_at,
        pr.get("title"),
        mismatch,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--id",
        action="append",
        dest="ids",
        help="Limit the check to one or more specific package ids "
        "(repeatable). Defaults to every non-todo/non-planned package.",
    )
    parser.add_argument(
        "--repo",
        default=DEFAULT_REPO,
        help=f"GitHub repo to query (default: {DEFAULT_REPO}).",
    )
    args = parser.parse_args()

    packages = load_manifest()
    target_ids = args.ids or [
        package_id
        for package_id in packages
        if not package_id.startswith(PLACEHOLDER_PREFIX)
        and packages[package_id].get("status") not in {"todo", "planned"}
    ]

    checks: list[PackageCheck] = []
    for package_id in sorted(target_ids):
        package = packages.get(package_id)
        if package is None:
            print(f"warning: unknown package id {package_id!r}, skipping.", file=sys.stderr)
            continue
        state_path = STATE_DIR / f"{package_id}.json"
        pr_number = None
        if state_path.exists():
            state = json.loads(state_path.read_text(encoding="utf-8"))
            pr_number = extract_pr_number(state.get("pr"))
        pr = fetch_pr_state(args.repo, pr_number) if pr_number else None
        checks.append(evaluate(package_id, package.get("status", "?"), pr))

    mismatches = [check for check in checks if check.mismatch]
    no_pr = [check for check in checks if check.pr_number is None]

    print(f"Checked {len(checks)} package(s) against {args.repo}.\n")
    for check in checks:
        if check.pr_number is None:
            print(f"  [skip] {check.package_id} [{check.manifest_status}] -- no linked PR in state/*.json.")
        elif check.mismatch:
            print(f"  [MISMATCH] {check.package_id} [{check.manifest_status}] -- {check.mismatch}")
        else:
            print(
                f"  [ok] {check.package_id} [{check.manifest_status}] -- "
                f"PR #{check.pr_number} ({check.pr_state}) consistent."
            )

    print(f"\n{len(mismatches)} mismatch(es), {len(no_pr)} package(s) with no linked PR to check.")
    return 1 if mismatches else 0


if __name__ == "__main__":
    raise SystemExit(main())
