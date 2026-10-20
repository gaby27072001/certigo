"""Inactive, single-file literal Bicep applicability qualification."""

import argparse
import hashlib
from importlib import import_module
from importlib.metadata import version
import json
from pathlib import Path
import sys
import tempfile

import checkov.arm
from checkov.bicep.runner import Runner
from checkov.runner_filter import RunnerFilter
from pycep import BicepParser
from pycep.transformer import BicepElement

from build_checkov_wheel import VERSION


SITE = "Microsoft.Web/sites"
CONFIG = SITE + "/config"
COSMOS = "Microsoft.DocumentDB/databaseAccounts"
SITE_CHECKS = ("CKV_AZURE_16", "CKV_AZURE_222")
CONFIG_CHECKS = {
    "CKV_AZURE_13": "authsettings",
    "CKV_AZURE_80": "web",
    "CKV_AZURE_66": "web",
    "CKV_AZURE_63": "web",
    "CKV_AZURE_222": "web",
    "CKV_AZURE_88": "web",
}
CHECKS = tuple(sorted({*SITE_CHECKS, *CONFIG_CHECKS, "CKV_AZURE_99"}))
API_VERSION = "2024-04-01"
COSMOS_API_VERSION = "2024-11-15"

RULE_SOURCES = {
    "checkov/arm/checks/resource/AppServiceIdentity.py":
        "f36911729b239513c83641ed171b86518227e92af0b97b618821143189a4010d",
    "checkov/arm/checks/resource/AppServiceAuthentication.py":
        "af80cdbff008b91ae1c051dbaec6eaa3801deb3f20217d3c6fb49d32404c86bb",
    "checkov/arm/checks/resource/AppServiceDotnetFrameworkVersion.py":
        "9725066ac8de44b476dea83cacdedb1588881e629cbe62f19c85860adeefdaa2",
    "checkov/arm/checks/resource/AppServiceEnableFailedRequest.py":
        "e84a6a67111f1bd450221688a4ef74f97f608d53e189d435c204ab81ede53849",
    "checkov/arm/checks/resource/AppServiceHttpLoggingEnabled.py":
        "e4121eed5a46c54078f0299091bd2baa9bc71f208be6437c88be523f7729e5af",
    "checkov/arm/checks/resource/AppServicePublicAccessDisabled.py":
        "e618b4d8ee177117986c07f4a9b0f96d1b122dfe0fe89d88103db9d3f930c431",
    "checkov/arm/checks/resource/AppServiceUsedAzureFiles.py":
        "1e9c1452bed550c63b48a973abe164b9d011b9de102ce652c09b6a7f450f1b48",
    "checkov/arm/checks/resource/CosmosDBAccountsRestrictedAccess.py":
        "2a5d260ab48a02032dfed01f14ba9c4fb4d806f23414f4c12c6d1a031b1c0384",
}
REGISTRY_SHA256 = "35a84e2225433f4529efcfdeebc6fe872e8ebca50674ab03717aff3d33d44fd0"


def _literal_string(value):
    return type(value) is str and "${" not in value


def _literal_identity(identity):
    if not isinstance(identity, dict) or set(identity) - {"type", "userAssignedIdentities"}:
        return False
    kind = identity.get("type")
    if type(kind) is not str or kind not in {
        "None", "SystemAssigned", "UserAssigned",
        "SystemAssigned, UserAssigned", "UserAssigned,SystemAssigned",
    }:
        return False
    assignments = identity.get("userAssignedIdentities")
    if "userAssignedIdentities" in identity and (
        not isinstance(assignments, dict)
        or any(
            type(resource_id) is not str
            or not resource_id.startswith("'/") or not resource_id.endswith("'")
            or "${" in resource_id
            or not isinstance(config, dict) or config
            for resource_id, config in assignments.items()
        )
    ):
        return False
    return True


def _literal_web(properties):
    expected = {
        "netFrameworkVersion", "requestTracingEnabled", "httpLoggingEnabled",
        "publicNetworkAccess", "azureStorageAccounts",
    }
    if not isinstance(properties, dict) or set(properties) != expected:
        return False
    if (
        not _literal_string(properties["netFrameworkVersion"])
        or type(properties["requestTracingEnabled"]) is not bool
        or type(properties["httpLoggingEnabled"]) is not bool
        or type(properties["publicNetworkAccess"]) is not str
        or properties["publicNetworkAccess"] not in ("Enabled", "Disabled")
    ):
        return False
    storage = properties["azureStorageAccounts"]
    return isinstance(storage, dict) and all(
        _literal_string(name)
        and isinstance(value, dict)
        and set(value) == {"type"}
        and _literal_string(value["type"])
        for name, value in storage.items()
    )


def _literal_cosmos(properties):
    allowed = {
        "publicNetworkAccess", "enableMultipleWriteLocations",
        "isVirtualNetworkFilterEnabled", "virtualNetworkRules", "ipRules",
    }
    if (
        not isinstance(properties, dict)
        or set(properties) - allowed
        or type(properties.get("publicNetworkAccess")) is not str
        or properties["publicNetworkAccess"] not in ("Enabled", "Disabled")
    ):
        return False
    for key in ("enableMultipleWriteLocations", "isVirtualNetworkFilterEnabled"):
        if key in properties and type(properties[key]) is not bool:
            return False
    for key, value_key in (
        ("virtualNetworkRules", "id"), ("ipRules", "ipAddressOrRange"),
    ):
        if key in properties and (
            not isinstance(properties[key], list)
            or any(
                not isinstance(rule, dict)
                or set(rule) != {value_key}
                or not _literal_string(rule[value_key])
                for rule in properties[key]
            )
        ):
            return False
    return True


def inventory(source, environment, instance):
    """Derive exact obligations from authored AST before running Checkov."""
    problems = []
    entries = []
    if environment not in ("dev", "staging", "prod") or instance != "root":
        problems.append("only an explicit environment and root module instance are qualified")
    try:
        tree = BicepParser().parse(text=source)
    except Exception as error:
        return [], 0, ["source parsing failed: " + type(error).__name__]
    if not isinstance(tree, dict):
        return [], 0, ["malformed source AST"]
    if set(tree) - {"globals", "resources"}:
        problems.append("parameters, variables, outputs and modules are not qualified")
    if tree.get("globals", {}).get("scope", {}).get("value") != "resourceGroup":
        problems.append("only resource-group scope is qualified")
    resources = tree.get("resources", {})
    if not isinstance(resources, dict) or not resources:
        return [], 0, problems + ["empty or malformed source inventory"]

    parents = {}
    children = []
    cosmos_names = set()
    site_names = set()
    for symbol, resource in resources.items():
        if not isinstance(resource, dict):
            problems.append("malformed resource AST")
            continue
        kind = resource.get("type")
        conf = resource.get("config")
        key = str(kind) + "." + str(symbol)
        if not isinstance(conf, dict) or resource.get("existing") is not False:
            problems.append("unsupported or malformed resource: " + key)
            continue
        if kind == SITE:
            if resource.get("api_version") != API_VERSION:
                problems.append("unsupported site API version: " + key)
            name = conf.get("name")
            properties = conf.get("properties")
            identity = conf.get("identity")
            if (
                set(conf) != {"name", "properties", "identity"}
                or type(name) is not str or not name or "${" in name
                or not isinstance(properties, dict)
                or set(properties) != {"publicNetworkAccess"}
                or type(properties.get("publicNetworkAccess")) is not str
                or properties["publicNetworkAccess"] not in ("Enabled", "Disabled")
                or not _literal_identity(identity)
            ):
                problems.append("site is outside the literal ingress/identity contract: " + key)
            if type(name) is str and name in site_names:
                problems.append("duplicate authored site name: " + key)
            if type(name) is str:
                site_names.add(name)
            parents[symbol] = key
            entries.extend(
                dict(resource=key, check=check, expected="APPLICABLE", parent=None)
                for check in SITE_CHECKS
            )
        elif kind == CONFIG:
            if resource.get("api_version") != API_VERSION:
                problems.append("unsupported site config API version: " + key)
            name = conf.get("name")
            parent = conf.get("parent")
            properties = conf.get("properties")
            if (
                set(conf) != {"name", "parent", "properties"}
                or type(name) is not str or name not in ("appsettings", "authsettings", "web")
                or type(parent) is not BicepElement
                or not isinstance(properties, dict)
            ):
                problems.append("unknown config subtype or nonliteral parent: " + key)
            elif name == "appsettings":
                if any(type(k) is not str or type(v) is not str or "${" in k or "${" in v
                       for k, v in properties.items()):
                    problems.append("appsettings must be a literal StringDictionary: " + key)
            elif name == "authsettings":
                if set(properties) != {"enabled"} or type(properties.get("enabled")) is not bool:
                    problems.append("authsettings must contain only literal enabled: " + key)
            elif not _literal_web(properties):
                problems.append("web config is outside the literal property contract: " + key)
            children.append((symbol, key, name, parent))
        elif kind == COSMOS:
            if resource.get("api_version") != COSMOS_API_VERSION:
                problems.append("unsupported Cosmos API version: " + key)
            name = conf.get("name")
            properties = conf.get("properties")
            if (
                set(conf) != {"name", "properties"}
                or type(name) is not str or not name or "${" in name
                or not _literal_cosmos(properties)
            ):
                problems.append("Cosmos resource is outside the literal network contract: " + key)
            if type(name) is str and name in cosmos_names:
                problems.append("duplicate authored Cosmos account name: " + key)
            if type(name) is str:
                cosmos_names.add(name)
            entries.append(dict(resource=key, check="CKV_AZURE_99", expected="APPLICABLE", parent=None))
        else:
            problems.append("resource type has no qualified mapping: " + key)

    child_names = set()
    for symbol, key, name, parent in children:
        if type(parent) is not BicepElement or parent not in parents:
            problems.append("missing or unresolved site parent: " + key)
            continue
        if type(name) is not str:
            continue
        identity = (parent, name)
        if identity in child_names:
            problems.append("duplicate site config subtype: " + key)
        child_names.add(identity)
        parent_key = parents[parent]
        entries.extend(
            dict(
                resource=key,
                check=check,
                expected="APPLICABLE" if CONFIG_CHECKS[check] == name else "NOT_APPLICABLE",
                parent=parent_key,
                subtype=name,
            )
            for check in sorted(CONFIG_CHECKS)
        )
    return entries, len(resources), problems


def _required_proofs(entry, entries):
    check = entry["check"]
    parent = entry["parent"]
    if check == "CKV_AZURE_222":
        return [
            (parent, "CKV_AZURE_222"),
            *(
                (candidate["resource"], check)
                for candidate in entries
                if candidate.get("parent") == parent and candidate.get("subtype") == "web"
                and candidate["check"] == check
            ),
        ]
    proof_subtype = CONFIG_CHECKS[check]
    return [
        (candidate["resource"], check)
        for candidate in entries
        if candidate.get("parent") == parent and candidate.get("subtype") == proof_subtype
        and candidate["check"] == check
    ]


def reconcile(entries, resource_count, report):
    """Keep raw Checkov evidence intact; qualify NA only with passed sibling proof."""
    problems = []
    raw = {}
    if not isinstance(report, dict):
        return [], ["malformed scanner report"]
    results = report.get("results")
    summary = report.get("summary")
    if not isinstance(results, dict) or not isinstance(summary, dict):
        return [], ["missing scanner results or summary"]
    if report.get("check_type") != "bicep" or summary.get("checkov_version") != "3.2.495":
        problems.append("unexpected framework or candidate version")
    paths = []
    for key, status in (("passed_checks", "PASSED"), ("failed_checks", "FAILED")):
        records = results.get(key)
        if not isinstance(records, list):
            problems.append("missing result list")
            continue
        count = summary.get("passed" if status == "PASSED" else "failed")
        if type(count) is not int or count != len(records):
            problems.append("summary/evidence mismatch")
        for record in records:
            if not isinstance(record, dict):
                problems.append("malformed scanner record")
                continue
            result = record.get("check_result")
            if not isinstance(result, dict):
                problems.append("malformed scanner result status")
                continue
            pair = (record.get("resource"), record.get("check_id"))
            if any(type(value) is not str or not value for value in pair):
                problems.append("malformed scanner resource/check identity")
                continue
            if pair in raw:
                problems.append("duplicate result")
            if result.get("result") != status:
                problems.append("inconsistent result status")
            raw[pair] = status
            paths.append(record.get("file_path"))
    if len(paths) == 0 or any(not isinstance(path, str) or not path for path in paths) or len(set(paths)) != 1:
        problems.append("single-file effective coverage required")
    for key, count_key in (("parsing_errors", "parsing_errors"), ("skipped_checks", "skipped")):
        count = summary.get(count_key)
        if results.get(key) != [] or type(count) is not int or count != 0:
            problems.append("parsing or skipped evidence")
    expected = {(entry["resource"], entry["check"]) for entry in entries}
    if not expected or len(expected) != len(entries) or set(raw) != expected:
        problems.append("missing, duplicate or unexpected resource/check obligation")
    if type(summary.get("resource_count")) is not int or summary["resource_count"] != resource_count:
        problems.append("source/report resource cardinality mismatch")

    qualified = []
    for entry in entries:
        pair = (entry["resource"], entry["check"])
        outcome = raw.get(pair)
        if outcome is None:
            status, reason = "BLOCKED", "expected scanner evidence absent, including possible UNKNOWN"
        elif entry["expected"] == "NOT_APPLICABLE":
            required = _required_proofs(entry, entries)
            evidence = [
                {"resource": resource, "check": check, "scanner_status": raw.get((resource, check))}
                for resource, check in required
            ]
            if not required or any(item["scanner_status"] != "PASSED" for item in evidence):
                status, reason = "BLOCKED", "applicable same-site parent verdict missing or not PASSED"
                problems.append("non-applicable check lacks a passed same-site parent proof")
            else:
                status, reason = "NOT_APPLICABLE", "the authored config subtype does not own this property"
            qualified.append({**entry, "status": status, "reason": reason, "scanner_status": outcome,
                              "applicability_evidence": evidence})
            continue
        else:
            status, reason = outcome, "unmodified Checkov verdict for an applicable resource"
            if status == "FAILED":
                problems.append("applicable check failed: " + entry["check"])
        qualified.append({**entry, "status": status, "reason": reason, "scanner_status": outcome})
    return qualified, problems


def _verify_runtime():
    if version("checkov") != VERSION or version("pycep-parser") != "0.5.1":
        raise ValueError("requires existing candidate and pinned upstream parser")
    import checkov.bicep.checks.resource.base_registry as registry

    if hashlib.sha256(Path(registry.__file__).read_bytes()).hexdigest() != REGISTRY_SHA256:
        raise ValueError("unexpected installed Bicep dispatch implementation")
    for relative, expected in RULE_SOURCES.items():
        module_name = relative.removesuffix(".py").replace("/", ".")
        path = Path(import_module(module_name).__file__)
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise ValueError("unexpected installed Checkov resource rule: " + relative)


def qualify(path, environment, instance="root"):
    """Parse independent obligations, execute real Runner on the same bytes, reconcile."""
    _verify_runtime()
    contents = path.read_bytes()
    provenance = dict(
        source=str(path.resolve()),
        sha256=hashlib.sha256(contents).hexdigest(),
        environment=environment,
        module_instance=instance,
        parameters="none; declarations rejected",
        candidate_version=VERSION,
    )
    try:
        source = contents.decode("utf-8")
    except UnicodeError as error:
        return dict(
            schema="certigo.bicep-appservice-qualification/v2",
            scope="literal root App Service applicability, managed identity and Cosmos network rules",
            production_adoptable=False,
            provenance=provenance,
            obligations=[],
            status="BLOCKED",
            blockers=["source is not UTF-8: " + type(error).__name__],
            applicability=[],
            scanner_report=None,
        )
    entries, resource_count, problems = inventory(source, environment, instance)
    raw = None
    qualified = []
    if not problems:
        with tempfile.TemporaryDirectory(prefix="certigo-bicep-appservice-") as temporary:
            snapshot = Path(temporary) / "source.bicep"
            snapshot.write_bytes(contents)
            report = Runner().run(
                root_folder=temporary,
                files=[str(snapshot)],
                runner_filter=RunnerFilter(checks=list(CHECKS), show_progress_bar=False),
            )
            raw = report.get_dict()
        qualified, problems = reconcile(entries, resource_count, raw)
    return dict(
        schema="certigo.bicep-appservice-qualification/v2",
        scope="literal root App Service subtype applicability, identity and Cosmos network controls only",
        production_adoptable=False,
        provenance=provenance,
        obligations=entries,
        status="BLOCKED" if problems else "QUALIFIED_SUBSET",
        blockers=problems,
        applicability=qualified,
        scanner_report=raw,
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--environment", required=True, choices=("dev", "staging", "prod"))
    args = parser.parse_args()
    result = qualify(args.source, args.environment)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 1 if result["status"] == "BLOCKED" else 0


if __name__ == "__main__":
    sys.exit(main())
