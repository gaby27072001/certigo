#!/usr/bin/env python3
"""Offline structural checks, not deployment approval or a live runtime probe."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


class ReadinessError(ValueError):
    """A required offline backend input is missing or inconsistent."""


def read_json(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ReadinessError(f"{path.name}: expected a JSON object.")
    return value


def validate_sdk(version: str) -> None:
    if re.fullmatch(r"10\.\d+\.\d+", version.strip()) is None:
        raise ReadinessError("Use a stable .NET 10 SDK; no SDK was installed or selected.")


def validate_source(root: Path) -> int:
    projects = sorted(
        path
        for area in ("src", "tests")
        for path in (root / "backend" / area).glob("*/*.csproj")
    )
    api = root / "backend" / "src" / "Certigo.Api" / "Certigo.Api.csproj"
    if api not in projects:
        raise ReadinessError("The API project is missing.")
    for path in projects:
        raw = path.read_text(encoding="utf-8")
        if "<!DOCTYPE" in raw.upper() or "<!ENTITY" in raw.upper():
            raise ReadinessError(f"{path.name}: XML entities are unsupported.")
        project = ET.fromstring(raw)
        targets = project.findall("./PropertyGroup/TargetFramework")
        if (
            len(targets) != 1
            or targets[0].text != "net10.0"
            or project.findall(".//TargetFrameworks")
            or any("Condition" in node.attrib for node in project.iter())
        ):
            raise ReadinessError(f"{path.name}: expected one unconditional net10.0 target.")
        if path == api:
            if project.attrib.get("Sdk") != "Azure.Functions.Sdk/1.0.0":
                raise ReadinessError("Review the Functions SDK contract before changing it.")
            workers = project.findall(
                "./ItemGroup/PackageReference[@Include='Microsoft.Azure.Functions.Worker']"
            )
            if len(workers) != 1 or workers[0].attrib.get("Version") != "2.52.0":
                raise ReadinessError("Review the isolated Worker contract before changing it.")

    function = root / "infra" / "modules" / "functionApp.bicep"
    # This is a deliberately narrow source assertion, not a Bicep parser or what-if.
    text = "\n".join(
        line for line in function.read_text(encoding="utf-8").splitlines()
        if not line.lstrip().startswith("//")
    )
    runtimes = re.findall(r"\bruntime\s*:\s*\{([^{}]*)\}", text)
    if len(runtimes) != 1 or re.fullmatch(
        r"\s*name:\s*'dotnet-isolated'\s+version:\s*'10\.0'\s*", runtimes[0]
    ) is None:
        raise ReadinessError("Expected the literal Flex dotnet-isolated 10.0 runtime.")
    settings = read_json(api.parent / "local.settings.json.example")
    values = settings.get("Values")
    if not isinstance(values, dict) or values.get("FUNCTIONS_WORKER_RUNTIME") != "dotnet-isolated":
        raise ReadinessError("The example must select the isolated worker.")
    if read_json(api.parent / "host.json").get("version") != "2.0":
        raise ReadinessError("Expected Functions host schema 2.0 (not the .NET version).")
    return len(projects)


def validate_publish(directory: Path) -> None:
    directory = directory.resolve(strict=True)

    def artifact(name: str) -> Path:
        path = directory / name
        if path.is_symlink() or not path.is_file() or path.stat().st_size == 0:
            raise ReadinessError(f"Publish requires a nonempty regular {name}.")
        if not path.resolve().is_relative_to(directory):
            raise ReadinessError(f"Publish artifact escapes the directory: {name}.")
        return path

    artifact("Certigo.Api.dll")
    if (directory / "local.settings.json").exists():
        raise ReadinessError("Publish must not contain local.settings.json.")
    if read_json(artifact("host.json")).get("version") != "2.0":
        raise ReadinessError("Published host schema must be 2.0.")
    options = read_json(artifact("Certigo.Api.runtimeconfig.json")).get("runtimeOptions")
    if not isinstance(options, dict) or options.get("tfm") != "net10.0":
        raise ReadinessError("Published runtimeconfig must target net10.0.")
    frameworks = options.get("frameworks")
    if not isinstance(frameworks, list) or len(frameworks) != 2:
        raise ReadinessError("Expected both framework-dependent .NET and ASP.NET runtimes.")
    if any(
        not isinstance(value, dict)
        or not isinstance(value.get("name"), str)
        or not isinstance(value.get("version"), str)
        for value in frameworks
    ) or {
        (value.get("name"), value.get("version")) for value in frameworks
    } != {("Microsoft.NETCore.App", "10.0.0"), ("Microsoft.AspNetCore.App", "10.0.0")}:
        raise ReadinessError("Published shared frameworks must match .NET 10.")
    description = read_json(artifact("worker.config.json")).get("description")
    if not isinstance(description, dict) or any(
        description.get(key) != expected
        for key, expected in {
            "language": "dotnet-isolated",
            "defaultExecutablePath": "dotnet",
            "defaultWorkerPath": "Certigo.Api.dll",
            "workerIndexing": "true",
        }.items()
    ):
        raise ReadinessError("Published worker configuration must use .NET worker indexing.")
    read_json(artifact("Certigo.Api.deps.json"))
    # Azure.Functions.Sdk uses worker indexing; functions.metadata is not required.


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--dotnet", default="dotnet", help="Existing trusted SDK executable only.")
    parser.add_argument("--publish-dir", type=Path, help="Optional already-published local directory.")
    args = parser.parse_args()
    try:
        result = subprocess.run(
            [args.dotnet, "--version"], cwd=args.root, capture_output=True, text=True, check=True
        )
        validate_sdk(result.stdout)
        count = validate_source(args.root)
        if args.publish_dir is not None:
            validate_publish(args.publish_dir)
    except (OSError, ValueError, ET.ParseError, subprocess.CalledProcessError) as exc:
        print(f"Backend offline readiness FAILED: {exc}", file=sys.stderr)
        return 1
    print(
        f"Backend offline structure OK: {count} projects; "
        f"publish={'checked' if args.publish_dir else 'NOT CHECKED'}. "
        "No Azure, provenance, app health, restore or deployment approval was verified."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
