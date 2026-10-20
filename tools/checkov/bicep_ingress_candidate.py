"""Inactive, single-file literal Bicep ingress qualification; never a CI gate."""

import argparse
import hashlib
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


CHECK = "CKV_AZURE_222"
SITE = "Microsoft.Web/sites"
CONFIG = SITE + "/config"


def inventory(source, environment, instance):
    """Derive obligations from authored AST, never returned scanner records."""
    problems = []
    entries = []
    if environment not in ("dev", "staging", "prod") or instance != "root":
        problems.append("only an explicit environment and root module instance are qualified")
    try:
        tree = BicepParser().parse(text=source)
    except Exception as error:
        # Parser exceptions are a reported blocking outcome, not an empty inventory.
        return [], ["source parsing failed: " + type(error).__name__]
    if set(tree) - {"globals", "resources"}:
        problems.append("parameters, variables, outputs and modules are not qualified")
    if tree.get("globals", {}).get("scope", {}).get("value") != "resourceGroup":
        problems.append("only resource-group scope is qualified")
    resources = tree.get("resources", {})
    if not resources:
        problems.append("empty source inventory")
    parents = {}
    names = set()
    for symbol, resource in resources.items():
        kind = resource.get("type")
        conf = resource.get("config", {})
        key = str(kind) + "." + symbol
        if resource.get("existing") is not False or resource.get("api_version") != "2024-04-01":
            problems.append("unsupported existing resource or API version: " + key)
        if kind == SITE:
            parents[symbol] = key
            props = conf.get("properties")
            if (
                set(conf) != {"name", "properties"}
                or type(conf.get("name")) is not str
                or not conf.get("name")
                or not isinstance(props, dict)
                or set(props) != {"publicNetworkAccess"}
                or type(props.get("publicNetworkAccess")) is not str
                or props["publicNetworkAccess"] not in ("Enabled", "Disabled")
            ):
                problems.append("site configuration is outside the literal ingress fixture contract: " + key)
            if type(conf.get("name")) is str and conf["name"] in names:
                problems.append("duplicate authored site name: " + key)
            if type(conf.get("name")) is str:
                names.add(conf["name"])
            entries.append(dict(resource=key, check=CHECK, expected="APPLICABLE", parent=None))
        elif kind == CONFIG:
            props = conf.get("properties")
            if (
                set(conf) != {"name", "parent", "properties"}
                or type(conf.get("name")) is not str or conf["name"] != "appsettings"
                or type(conf.get("parent")) is not BicepElement
                or not isinstance(props, dict)
                or any(type(key) is not str or type(value) is not str for key, value in props.items())
            ):
                problems.append("unknown subtype or nonliteral StringDictionary: " + key)
            entries.append(dict(
                resource=key, check=CHECK, expected="NOT_APPLICABLE",
                parent=conf.get("parent"),
            ))
        else:
            problems.append("resource type has no qualified ingress mapping: " + key)
    for entry in entries:
        if entry["expected"] == "NOT_APPLICABLE":
            symbol = entry["parent"]
            if not isinstance(symbol, str) or symbol not in parents:
                problems.append("missing or unresolved site parent: " + entry["resource"])
                entry["parent"] = None
            else:
                entry["parent"] = parents[symbol]
    children = [entry["parent"] for entry in entries if entry["expected"] == "NOT_APPLICABLE"]
    if len(children) != len(set(children)):
        problems.append("duplicate appsettings child for a site")
    return entries, problems


def reconcile(entries, report):
    """Preserve raw results while separating applicability from parent verdict."""
    problems = []
    raw = {}
    results = report.get("results", {})
    summary = report.get("summary", {})
    # Checkov's report uses its internal upstream version, not wheel metadata.
    if report.get("check_type") != "bicep" or summary.get("checkov_version") != "3.2.495":
        problems.append("unexpected framework or candidate version")
    paths = set()
    for key, status in (("passed_checks", "PASSED"), ("failed_checks", "FAILED")):
        records = results.get(key)
        if not isinstance(records, list):
            problems.append("missing result list")
            continue
        if summary.get("passed" if status == "PASSED" else "failed") != len(records):
            problems.append("summary/evidence mismatch")
        for record in records:
            pair = (record.get("resource"), record.get("check_id"))
            if pair in raw:
                problems.append("duplicate result")
            if record.get("check_result", {}).get("result") != status:
                problems.append("inconsistent result status")
            raw[pair] = status
            paths.add(record.get("file_path"))
    if len(paths) != 1 or not all(isinstance(path, str) and path for path in paths):
        problems.append("single-file effective coverage required")
    for key, count in (("parsing_errors", "parsing_errors"), ("skipped_checks", "skipped")):
        if results.get(key) != [] or summary.get(count) != 0:
            problems.append("parsing or skipped evidence")
    expected = {(entry["resource"], entry["check"]) for entry in entries}
    if not expected or len(expected) != len(entries) or set(raw) != expected:
        problems.append("missing, duplicate or unexpected resource/check obligation")
    if type(summary.get("resource_count")) is not int or summary["resource_count"] != len(entries):
        problems.append("source/report resource cardinality mismatch")
    qualified = []
    for entry in entries:
        pair = (entry["resource"], entry["check"])
        outcome = raw.get(pair)
        if outcome is None:
            status, reason = "BLOCKED", "expected scanner evidence absent, including possible UNKNOWN"
        elif entry["expected"] == "NOT_APPLICABLE":
            parent = (entry["parent"], entry["check"])
            if parent not in expected or parent not in raw:
                status, reason = "BLOCKED", "independent parent obligation or verdict absent"
                problems.append("parent not reconciled")
            else:
                status, reason = "NOT_APPLICABLE", "appsettings StringDictionary is not site ingress configuration"
        else:
            status, reason = outcome, "unmodified Checkov parent ingress verdict"
            if status == "FAILED":
                problems.append("applicable ingress check failed")
        qualified.append({**entry, "status": status, "reason": reason, "scanner_status": outcome})
    return qualified, problems


def qualify(path, environment, instance="root"):
    """Parse once independently, execute real Runner, then reconcile identities."""
    if version("checkov") != VERSION or version("pycep-parser") != "0.5.1":
        raise ValueError("requires existing candidate and pinned upstream parser")
    # Pin both dispatch and ingress predicate; this adapter changes neither.
    import checkov.bicep.checks.resource.base_registry as registry
    from checkov.arm.checks.resource.AppServicePublicAccessDisabled import check

    for filename, expected in (
        (Path(registry.__file__), "35a84e2225433f4529efcfdeebc6fe872e8ebca50674ab03717aff3d33d44fd0"),
        (Path(sys.modules[check.__module__].__file__), "e618b4d8ee177117986c07f4a9b0f96d1b122dfe0fe89d88103db9d3f930c431"),
    ):
        if hashlib.sha256(filename.read_bytes()).hexdigest() != expected:
            raise ValueError("unexpected installed dispatch or ingress implementation")
    contents = path.read_bytes()
    source = contents.decode("utf-8")
    entries, problems = inventory(source, environment, instance)
    provenance = dict(
        source=str(path.resolve()), sha256=hashlib.sha256(contents).hexdigest(),
        environment=environment, module_instance=instance, parameters="none; declarations rejected",
        candidate_version=VERSION,
    )
    raw = None
    qualified = []
    if not problems:
        with tempfile.TemporaryDirectory(prefix="certigo-bicep-ingress-") as temporary:
            snapshot = Path(temporary) / "source.bicep"
            snapshot.write_bytes(contents)
            report = Runner().run(
                root_folder=temporary, files=[str(snapshot)],
                runner_filter=RunnerFilter(checks=[CHECK], show_progress_bar=False),
            )
            raw = report.get_dict()
        qualified, problems = reconcile(entries, raw)
    return dict(
        schema="certigo.bicep-ingress-qualification/v1",
        scope="literal root site/appsettings ingress only; not whole-source security coverage",
        production_adoptable=False, provenance=provenance, obligations=entries,
        status="BLOCKED" if problems else "QUALIFIED_SUBSET",
        blockers=problems, applicability=qualified, scanner_report=raw,
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
