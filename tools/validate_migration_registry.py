#!/usr/bin/env python3
"""Validate the migration registry and its human-readable mirror."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError as exc:  # pragma: no cover - exercised by CI setup failures
    raise SystemExit(
        "PyYAML is required: install it with `python -m pip install PyYAML`."
    ) from exc


ROOT = Path(__file__).resolve().parents[1]
MIGRATION_DIR = ROOT / "docs" / "migration"
MANIFEST_PATH = MIGRATION_DIR / "work-packages.yaml"
STATE_TABLE_PATH = MIGRATION_DIR / "STATE.md"
STATE_DIR = MIGRATION_DIR / "state"
LOG_PATH = MIGRATION_DIR / "log.jsonl"
PLACEHOLDER_PREFIX = "wp-phase-"
DEPENDENCY_READY_STATUSES = {"in_progress", "in_review", "done"}
REQUIRED_FIELDS = {
    "id",
    "phase",
    "title",
    "size",
    "effort_pweeks",
    "depends_on",
    "precondition",
    "dod",
    "rollback",
    "status",
}
STATE_ROW = re.compile(
    r"^\|\s*`(?P<id>[^`]+)`\s*\|[^|]*\|[^|]*\|\s*"
    r"(?P<status>[a-z_]+)\s*\|"
)


class RegistryErrors:
    def __init__(self) -> None:
        self.messages: list[str] = []

    def add(self, message: str) -> None:
        self.messages.append(message)

    def require(self, condition: bool, message: str) -> None:
        if not condition:
            self.add(message)


def load_yaml(errors: RegistryErrors) -> dict[str, Any]:
    try:
        value = yaml.safe_load(MANIFEST_PATH.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as exc:
        errors.add(f"{MANIFEST_PATH.relative_to(ROOT)}: {exc}")
        return {}
    if not isinstance(value, dict):
        errors.add("work-packages.yaml must contain a YAML mapping.")
        return {}
    return value


def load_json(path: Path, errors: RegistryErrors) -> dict[str, Any] | None:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        errors.add(f"{path.relative_to(ROOT)}: {exc}")
        return None
    if not isinstance(value, dict):
        errors.add(f"{path.relative_to(ROOT)} must contain a JSON object.")
        return None
    return value


def parse_state_table(errors: RegistryErrors) -> dict[str, str]:
    rows: dict[str, str] = {}
    try:
        lines = STATE_TABLE_PATH.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        errors.add(f"{STATE_TABLE_PATH.relative_to(ROOT)}: {exc}")
        return rows

    for line in lines:
        match = STATE_ROW.match(line)
        if not match:
            continue
        package_id = match.group("id")
        if package_id in rows:
            errors.add(f"STATE.md contains duplicate row {package_id!r}.")
        rows[package_id] = match.group("status")
    return rows


def parse_log(
    allowed_statuses: set[str], errors: RegistryErrors
) -> dict[str, str]:
    last_status: dict[str, str] = {}
    try:
        lines = LOG_PATH.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        errors.add(f"{LOG_PATH.relative_to(ROOT)}: {exc}")
        return last_status

    for line_number, line in enumerate(lines, start=1):
        if not line.strip():
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError as exc:
            errors.add(f"log.jsonl:{line_number}: {exc}")
            continue
        if not isinstance(event, dict):
            errors.add(f"log.jsonl:{line_number}: expected a JSON object.")
            continue
        package_id = event.get("id")
        target = event.get("to")
        if not isinstance(package_id, str) or not package_id:
            errors.add(f"log.jsonl:{line_number}: missing non-empty id.")
        if target not in allowed_statuses:
            errors.add(
                f"log.jsonl:{line_number}: invalid target status {target!r}."
            )
        if isinstance(package_id, str) and target in allowed_statuses:
            last_status[package_id] = target
    return last_status


def detect_cycles(
    dependencies: dict[str, list[str]], errors: RegistryErrors
) -> None:
    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(package_id: str, path: list[str]) -> None:
        if package_id in visiting:
            start = path.index(package_id)
            errors.add(
                "Dependency cycle: " + " -> ".join(path[start:] + [package_id])
            )
            return
        if package_id in visited:
            return
        visiting.add(package_id)
        for dependency in dependencies.get(package_id, []):
            if dependency in dependencies:
                visit(dependency, path + [package_id])
        visiting.remove(package_id)
        visited.add(package_id)

    for package_id in dependencies:
        visit(package_id, [])


def validate() -> list[str]:
    errors = RegistryErrors()
    manifest = load_yaml(errors)
    conventions = manifest.get("conventions", {})
    statuses = conventions.get("statuses", {}) if isinstance(conventions, dict) else {}
    allowed_statuses = set(statuses) if isinstance(statuses, dict) else set()
    errors.require(bool(allowed_statuses), "No allowed statuses found in conventions.")

    raw_packages = manifest.get("work_packages", [])
    if not isinstance(raw_packages, list):
        errors.add("work_packages must be a YAML list.")
        raw_packages = []

    packages: dict[str, dict[str, Any]] = {}
    dependencies: dict[str, list[str]] = {}
    for index, package in enumerate(raw_packages, start=1):
        if not isinstance(package, dict):
            errors.add(f"work_packages[{index}] must be a mapping.")
            continue
        package_id = package.get("id")
        if not isinstance(package_id, str) or not package_id:
            errors.add(f"work_packages[{index}] has no non-empty id.")
            continue
        if package_id in packages:
            errors.add(f"Duplicate work package id {package_id!r}.")
            continue
        packages[package_id] = package
        missing = sorted(REQUIRED_FIELDS - set(package))
        if missing:
            errors.add(f"{package_id}: missing fields {', '.join(missing)}.")
        errors.require(
            package.get("status") in allowed_statuses,
            f"{package_id}: invalid status {package.get('status')!r}.",
        )
        raw_dependencies = package.get("depends_on")
        if not isinstance(raw_dependencies, list) or not all(
            isinstance(value, str) for value in raw_dependencies
        ):
            errors.add(f"{package_id}: depends_on must be a list of ids.")
            dependencies[package_id] = []
        else:
            dependencies[package_id] = raw_dependencies
        if package_id.startswith("wp-p2-"):
            steps = package.get("steps")
            errors.require(
                isinstance(steps, list)
                and bool(steps)
                and all(isinstance(step, str) and step.strip() for step in steps),
                f"{package_id}: remediation packages require non-empty steps.",
            )

    for package_id, required_ids in dependencies.items():
        for required_id in required_ids:
            errors.require(
                required_id in packages,
                f"{package_id}: unknown dependency {required_id!r}.",
            )
            errors.require(
                required_id != package_id,
                f"{package_id}: a package cannot depend on itself.",
            )
            if (
                package_id in packages
                and required_id in packages
                and packages[package_id].get("status") in DEPENDENCY_READY_STATUSES
            ):
                errors.require(
                    packages[required_id].get("status") == "done",
                    f"{package_id}: status {packages[package_id].get('status')!r} "
                    f"requires dependency {required_id!r} to be 'done', got "
                    f"{packages[required_id].get('status')!r}.",
                )
    detect_cycles(dependencies, errors)

    gated_statuses = {"in_progress", "in_review", "done"}
    for package_id, package in packages.items():
        package_status = package.get("status")
        if package_status not in gated_statuses:
            continue
        for required_id in dependencies.get(package_id, []):
            dependency = packages.get(required_id)
            if dependency is None:
                continue
            dependency_status = dependency.get("status")
            errors.require(
                dependency_status == "done",
                f"{package_id}: status {package_status!r} requires dependency "
                f"{required_id} to be done, found {dependency_status!r}.",
            )

    table_statuses = parse_state_table(errors)
    errors.require(
        set(table_statuses) == set(packages),
        "STATE.md ids differ from work-packages.yaml "
        f"(missing={sorted(set(packages) - set(table_statuses))}, "
        f"extra={sorted(set(table_statuses) - set(packages))}).",
    )

    expected_state_ids = {
        package_id
        for package_id in packages
        if not package_id.startswith(PLACEHOLDER_PREFIX)
    }
    actual_state_paths = {
        path.stem: path
        for path in STATE_DIR.glob("*.json")
        if path.name != "_TEMPLATE.json"
    }
    errors.require(
        set(actual_state_paths) == expected_state_ids,
        "state/*.json references differ from concrete work packages "
        f"(missing={sorted(expected_state_ids - set(actual_state_paths))}, "
        f"orphaned={sorted(set(actual_state_paths) - expected_state_ids)}).",
    )

    state_statuses: dict[str, str] = {}
    for filename_id, path in sorted(actual_state_paths.items()):
        state = load_json(path, errors)
        if state is None:
            continue
        state_id = state.get("id")
        errors.require(
            state_id == filename_id,
            f"{path.relative_to(ROOT)}: id {state_id!r} does not match filename.",
        )
        state_status = state.get("status")
        errors.require(
            state_status in allowed_statuses,
            f"{filename_id}: invalid state status {state_status!r}.",
        )
        if isinstance(state_id, str) and isinstance(state_status, str):
            state_statuses[state_id] = state_status

    last_log_status = parse_log(allowed_statuses, errors)
    for package_id, package in packages.items():
        manifest_status = package.get("status")
        table_status = table_statuses.get(package_id)
        errors.require(
            table_status == manifest_status,
            f"{package_id}: manifest={manifest_status!r}, STATE.md={table_status!r}.",
        )
        if package_id in expected_state_ids:
            state_status = state_statuses.get(package_id)
            errors.require(
                state_status == manifest_status,
                f"{package_id}: manifest={manifest_status!r}, "
                f"state={state_status!r}.",
            )
            errors.require(
                manifest_status == "todo" or package_id in last_log_status,
                f"{package_id}: status {manifest_status!r} requires a "
                "matching transition in log.jsonl.",
            )
            if package_id in last_log_status:
                errors.require(
                    last_log_status[package_id] == manifest_status,
                    f"{package_id}: current status={manifest_status!r}, "
                    f"last log transition={last_log_status[package_id]!r}.",
                )
    return errors.messages


def main() -> int:
    errors = validate()
    if errors:
        print(f"Migration registry validation failed ({len(errors)} error(s)):")
        for error in errors:
            print(f"  - {error}")
        return 1
    print("Migration registry validation passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
