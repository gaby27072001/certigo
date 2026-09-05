#!/usr/bin/env python3
"""Refresh or check repository files derived from canonical source contracts."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


CONTENT_PACKAGE_CONTRACTS = (
    Path("contracts/content-package-v2.json"),
    Path("contracts/content-package-v1.json"),
)
CONTENT_PACKAGE_ENVELOPES = {
    "certigo.source-contract/content-package/v1": {
        "schema",
        "activeReferenceSchema",
        "packageContract",
    },
    "certigo.source-contract/content-package/v2": {
        "schema",
        "activeReferenceSchema",
        "packageContract",
        "segmentPattern",
        "fileSuffix",
        "manifestShapes",
    },
}
COSMOS_CONTRACT = Path("contracts/cosmos-containers.json")
ACTIVE_CONTENT_REFERENCE = Path("docs/active-content-reference.json")
COSMOS_CSHARP = Path(
    "backend/src/Certigo.Infrastructure/Cosmos/CosmosContainers.cs"
)
COSMOS_RESOURCE_NAME_MAX_LENGTH = 255
COSMOS_RESOURCE_NAME_FORBIDDEN_CHARACTERS = frozenset("/\\?#")


class ContractError(ValueError):
    """Raised when a source contract or generated output is invalid."""


def _validate_cosmos_resource_name(value: object, source: str) -> str:
    if not isinstance(value, str) or not value or value.isspace():
        raise ContractError(f"{source}: expected a non-empty Cosmos resource name.")
    if len(value) > COSMOS_RESOURCE_NAME_MAX_LENGTH:
        raise ContractError(
            f"{source}: Cosmos resource names cannot exceed "
            f"{COSMOS_RESOURCE_NAME_MAX_LENGTH} characters."
        )
    invalid = sorted(set(value) & COSMOS_RESOURCE_NAME_FORBIDDEN_CHARACTERS)
    if invalid:
        characters = ", ".join(repr(character) for character in invalid)
        raise ContractError(
            f"{source}: Cosmos resource names cannot contain {characters}."
        )
    if value.endswith(" "):
        raise ContractError(f"{source}: Cosmos resource names cannot end with a space.")
    try:
        value.encode("utf-8")
    except UnicodeEncodeError as exc:
        raise ContractError(
            f"{source}: expected valid Unicode for a Cosmos resource name."
        ) from exc
    return value


def _csharp_string_literal(value: str) -> str:
    return json.dumps(value, ensure_ascii=True)


def _load_json(root: Path, relative: Path) -> dict[str, object]:
    try:
        value = json.loads((root / relative).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ContractError(f"{relative}: cannot load canonical JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise ContractError(f"{relative}: expected a JSON object.")
    return value


def content_package_contract_path(root: Path) -> Path:
    """Return the active content-package contract relative to ``root``.

    The newest envelope wins so a migration can introduce it without disturbing
    the superseded file, which the previous release's validator still reads.
    """
    for relative in CONTENT_PACKAGE_CONTRACTS:
        if (root / relative).is_file():
            return relative
    raise ContractError(
        "No content-package contract found; expected one of "
        f"{[path.as_posix() for path in CONTENT_PACKAGE_CONTRACTS]}."
    )


def _package_contract(root: Path) -> tuple[str, dict[str, object]]:
    relative = content_package_contract_path(root)
    value = _load_json(root, relative)
    expected_fields = CONTENT_PACKAGE_ENVELOPES.get(value.get("schema"))
    if expected_fields is None:
        raise ContractError(f"{relative}: unsupported schema.")
    if set(value) != expected_fields:
        raise ContractError(f"{relative}: unexpected fields.")
    active_schema = value["activeReferenceSchema"]
    package_contract = value["packageContract"]
    if not isinstance(active_schema, str) or not isinstance(package_contract, dict):
        raise ContractError(f"{relative}: invalid contract values.")
    return active_schema, package_contract


def _cosmos_contract(root: Path) -> tuple[str, list[dict[str, object]]]:
    value = _load_json(root, COSMOS_CONTRACT)
    if set(value) != {"schema", "databaseName", "containers"}:
        raise ContractError(f"{COSMOS_CONTRACT}: unexpected fields.")
    if value["schema"] != "certigo.source-contract/cosmos-containers/v1":
        raise ContractError(f"{COSMOS_CONTRACT}: unsupported schema.")
    database_name = _validate_cosmos_resource_name(
        value["databaseName"], f"{COSMOS_CONTRACT}.databaseName"
    )
    containers = value["containers"]
    if not isinstance(containers, list) or not containers:
        raise ContractError(f"{COSMOS_CONTRACT}.containers: expected a non-empty array.")

    names: set[str] = set()
    symbols: set[str] = set()
    validated: list[dict[str, object]] = []
    expected_fields = {
        "symbol",
        "name",
        "partitionKeyPath",
        "defaultTimeToLive",
    }
    for index, item in enumerate(containers):
        source = f"{COSMOS_CONTRACT}.containers[{index}]"
        if not isinstance(item, dict) or set(item) != expected_fields:
            raise ContractError(f"{source}: unexpected fields.")
        symbol = item["symbol"]
        name = _validate_cosmos_resource_name(item["name"], f"{source}.name")
        partition_key = item["partitionKeyPath"]
        ttl = item["defaultTimeToLive"]
        if not isinstance(symbol, str) or not re.fullmatch(r"[A-Z][A-Za-z0-9]*", symbol):
            raise ContractError(f"{source}.symbol: expected a C# identifier.")
        if not isinstance(partition_key, str) or not re.fullmatch(
            r"/[A-Za-z][A-Za-z0-9]*", partition_key
        ):
            raise ContractError(f"{source}.partitionKeyPath: expected one path segment.")
        if ttl not in (None, -1):
            raise ContractError(f"{source}.defaultTimeToLive: expected null or -1.")
        normalized_name = name.casefold()
        if normalized_name in names:
            raise ContractError(
                f"{source}.name: container names must be unique ignoring case."
            )
        if symbol in symbols:
            raise ContractError(f"{source}.symbol: container symbols must be unique.")
        names.add(normalized_name)
        symbols.add(symbol)
        validated.append(item)
    return database_name, validated


def _active_content_output(root: Path) -> str:
    active_schema, package_contract = _package_contract(root)
    value = _load_json(root, ACTIVE_CONTENT_REFERENCE)
    value["schema"] = active_schema
    value["packageContract"] = package_contract
    return json.dumps(value, indent=2, ensure_ascii=False) + "\n"


def _cosmos_csharp_output(root: Path) -> str:
    database_name, containers = _cosmos_contract(root)
    constants = "\n".join(
        f'    public const string {item["symbol"]} = '
        f'{_csharp_string_literal(item["name"])};'
        for item in containers
    )
    definitions = []
    for item in containers:
        suffix = (
            ", DefaultTimeToLive: -1"
            if item["defaultTimeToLive"] == -1
            else ""
        )
        definitions.append(
            f"        new({item['symbol']}, "
            f"{_csharp_string_literal(item['partitionKeyPath'])}{suffix})"
        )
    all_definitions = ",\n".join(definitions)
    return f"""// <auto-generated by tools/generated_contracts.py>
namespace Certigo.Infrastructure.Cosmos;

public static class CosmosContainers
{{
    public const string DatabaseName = {_csharp_string_literal(database_name)};
{constants}

    public static IReadOnlyList<CosmosContainerDefinition> All {{ get; }} =
    [
{all_definitions}
    ];
}}

public sealed record CosmosContainerDefinition(
    string Name,
    string PartitionKeyPath,
    int? DefaultTimeToLive = null);
"""


def expected_outputs(root: Path) -> dict[Path, str]:
    return {
        ACTIVE_CONTENT_REFERENCE: _active_content_output(root),
        COSMOS_CSHARP: _cosmos_csharp_output(root),
    }


def refresh(root: Path, check: bool) -> bool:
    stale: list[Path] = []
    for relative, expected in expected_outputs(root).items():
        path = root / relative
        try:
            current = path.read_text(encoding="utf-8")
        except OSError:
            current = ""
        if current == expected:
            continue
        stale.append(relative)
        if not check:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(expected, encoding="utf-8", newline="\n")
    if check and stale:
        paths = ", ".join(path.as_posix() for path in stale)
        raise ContractError(
            f"generated contracts are stale: {paths}. "
            "Run `python tools/generated_contracts.py --refresh`."
        )
    return bool(stale)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--refresh", action="store_true")
    mode.add_argument("--check", action="store_true")
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
    )
    args = parser.parse_args(argv)
    try:
        changed = refresh(args.root.resolve(strict=True), check=args.check)
    except ContractError as exc:
        print(f"generated-contracts: {exc}", file=sys.stderr)
        return 1
    if args.check:
        print("Generated contracts are current.")
    else:
        print("Generated contracts refreshed." if changed else "Generated contracts already current.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
