"""Real Bicep qualification controls, without scanning infra or adopting a gate."""

from copy import deepcopy
from contextlib import contextmanager
import hashlib
from importlib.metadata import version
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from checkov.common.models.enums import CheckResult
from checkov.arm.checks.resource.AppServicePublicAccessDisabled import check as ingress
from checkov.arm.checks.resource.AppServiceHttpLoggingEnabled import check as logging

from bicep_ingress_candidate import (
    CONFIG_CHECKS, COSMOS_CHECKS, FUNCTION_CHECKS, FUNCTION_RULE_SOURCES, RULE_SOURCES, UPSTREAM_PARSER_SOURCES,
    Runner, _function_inventory, _parse_source, _parser_source, _verify_cosmos_dispatch,
    _verify_function_dispatch, _verify_parser, inventory, qualify, qualify_cosmos_snapshot,
    qualify_function_snapshot, qualify_local_module, qualify_local_modules,
    reconcile, resolve_local_module_bindings,
)
from build_parser_wheel import PATCHED_FILES, VERSION as COMPAT_PARSER_VERSION


UAMI = (
    "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/fixture"
    "/providers/Microsoft.ManagedIdentity/userAssignedIdentities/reader"
)
SITE = """resource site 'Microsoft.Web/sites@2024-04-01' = {
 name: 'fixture'
 properties: { publicNetworkAccess: 'Disabled' }
 identity: {
  type: 'SystemAssigned, UserAssigned'
  userAssignedIdentities: { 'UAMI_ID': {} }
 }
}
""".replace("UAMI_ID", UAMI)
CHILD = """resource settings 'Microsoft.Web/sites/config@2024-04-01' = {
 parent: site
 name: 'appsettings'
 properties: { EXAMPLE: 'value' }
}
"""
WEB = """resource web 'Microsoft.Web/sites/config@2024-04-01' = {
 parent: site
 name: 'web'
 properties: {
  netFrameworkVersion: 'v8.0'
  requestTracingEnabled: true
  httpLoggingEnabled: true
  publicNetworkAccess: 'Disabled'
  azureStorageAccounts: { example: { type: 'AzureFiles' } }
 }
}
"""
AUTH = """resource auth 'Microsoft.Web/sites/config@2024-04-01' = {
 parent: site
 name: 'authsettings'
 properties: { enabled: true }
}
"""
COSMOS = """resource account 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
 name: 'fixture-account'
 kind: 'GlobalDocumentDB'
 properties: {
  publicNetworkAccess: 'Disabled'
  enableMultipleWriteLocations: false
  disableLocalAuth: true
  disableKeyBasedMetadataWriteAccess: true
 }
}
"""
FULL = SITE + WEB + AUTH + CHILD
PARENT = "Microsoft.Web/sites.site"
SETTINGS = "Microsoft.Web/sites/config.settings"
MODULE_ROOT = """@allowed([ 'dev', 'staging', 'prod' ])
param env string
var authMode = env == 'dev' ? 'dev' : 'prod'
module api './modules/functionApp.bicep' = {
 name: 'api'
 params: {
  allowedCorsOrigins: env == 'dev' ? [ '*' ] : []
  authMode: authMode
 }
}
"""
MODULE_SOURCE = """param allowedCorsOrigins array
param authMode string
resource site 'Microsoft.Web/sites@2024-04-01' = {
 name: 'fixture'
 properties: {
  publicNetworkAccess: 'Disabled'
  siteConfig: { cors: { allowedOrigins: allowedCorsOrigins } }
 }
 identity: {
  type: 'SystemAssigned, UserAssigned'
  userAssignedIdentities: { 'UAMI_ID': {} }
 }
}
""".replace("UAMI_ID", UAMI) + WEB + AUTH + """resource settings 'Microsoft.Web/sites/config@2024-04-01' = {
 parent: site
 name: 'appsettings'
 properties: { AUTH_MODE: authMode }
}
"""

MULTI_ROOT = MODULE_ROOT + """module data './modules/cosmos.bicep' = {
 name: 'cosmos-${env}'
 params: { deploymentLabel: env }
}
"""


@contextmanager
def module_fixture(root_source=MULTI_ROOT, app_source=MODULE_SOURCE, cosmos_source=COSMOS):
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary) / "main.bicep"
        module_dir = root.parent / "modules"
        module_dir.mkdir()
        root.write_text(root_source, encoding="utf-8")
        (module_dir / "functionApp.bicep").write_text(app_source, encoding="utf-8")
        (module_dir / "cosmos.bicep").write_text(
            "param deploymentLabel string\n" + cosmos_source, encoding="utf-8"
        )
        yield root


@contextmanager
def real_cosmos_fixture(environment):
    repository = Path(__file__).resolve().parents[2]
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary) / "infra" / "main.bicep"
        root.parent.mkdir()
        (root.parent / "modules").mkdir()
        contracts = root.parent.parent / "contracts"
        contracts.mkdir()
        (contracts / "cosmos-containers.json").write_bytes(
            (repository / "contracts" / "cosmos-containers.json").read_bytes()
        )
        (root.parent / "modules" / "cosmos.bicep").write_bytes(
            (repository / "infra" / "modules" / "cosmos.bicep").read_bytes()
        )
        root.write_text(
            "@allowed(['dev', 'staging', 'prod'])\nparam env string\n"
            "var hardened = env != 'dev'\n"
            "var contract = loadJsonContent('../contracts/cosmos-containers.json')\n"
            "var tags = union({product: 'Certigo'}, {env: env})\n"
            "module data './modules/cosmos.bicep' = {\n name: 'data'\n params: {\n"
            " accountName: 'fixture-${env}'\n location: 'westeurope'\n"
            " databaseName: contract.databaseName\n disableLocalAuth: hardened\n"
            " backupMode: 'Periodic'\n tags: tags\n }\n}\n", encoding="utf-8",
        )
        yield root


@contextmanager
def snapshot_fixture():
    with real_cosmos_fixture("staging") as root:
        text = root.read_text().replace(
            "var hardened",
            "@allowed(['Periodic', 'Continuous'])\nparam cosmosBackupMode string\n"
            "param appName string = 'certigo'\n"
            "var suffix = uniqueString(subscription().id, appName, env)\nvar hardened",
        ).replace("accountName: 'fixture-${env}'", "accountName: 'cosmos-${appName}-${env}-${suffix}'").replace(
            "backupMode: 'Periodic'", "backupMode: cosmosBackupMode",
        )
        root.write_text(text)
        yield root


class CandidateTests(unittest.TestCase):
    def run_source(self, source):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "fixture.bicep"
            path.write_text(source, encoding="utf-8")
            result = qualify(path, "staging")
            self.assertEqual(result["provenance"]["sha256"], hashlib.sha256(path.read_bytes()).hexdigest())
            self.assertEqual(path.read_text(encoding="utf-8"), source)
            return result

    def assert_blocked(self, result):
        self.assertEqual(result["status"], "BLOCKED")
        self.assertTrue(result["blockers"])
        self.assertFalse(result["production_adoptable"])

    def test_real_six_child_rules_require_passed_same_site_proofs_and_keep_raw_failures(self):
        result = self.run_source(FULL)
        self.assertEqual(result["status"], "QUALIFIED_SUBSET", result["blockers"])
        self.assertFalse(result["production_adoptable"])
        self.assertEqual(len(result["obligations"]), 20)
        report = result["scanner_report"]
        self.assertEqual(report["summary"]["resource_count"], 4)
        self.assertEqual(len(report["results"]["passed_checks"]), 8)
        self.assertEqual(len(report["results"]["failed_checks"]), 12)
        records = {
            (row["resource"], row["check"]): row
            for row in result["applicability"]
        }
        for check in CONFIG_CHECKS:
            row = records[(SETTINGS, check)]
            self.assertEqual(row["status"], "NOT_APPLICABLE")
            self.assertEqual(row["scanner_status"], "FAILED")
            self.assertEqual(row["parent"], PARENT)
            self.assertTrue(row["applicability_evidence"])
            self.assertEqual(len(row["applicability_evidence"]),
                             2 if check == "CKV_AZURE_222" else 1)
            self.assertEqual(len({
                (proof["resource"], proof["check"])
                for proof in row["applicability_evidence"]
            }), len(row["applicability_evidence"]))
            self.assertTrue(all(
                evidence["scanner_status"] == "PASSED"
                for evidence in row["applicability_evidence"]
            ))
        self.assertEqual(records[(PARENT, "CKV_AZURE_16")]["status"], "PASSED")

    def test_each_corresponding_insecure_property_blocks_child_applicability(self):
        for original, replacement, check in (
            ("publicNetworkAccess: 'Disabled'", "publicNetworkAccess: 'Enabled'", "CKV_AZURE_222"),
            ("netFrameworkVersion: 'v8.0'", "netFrameworkVersion: 'v4.0'", "CKV_AZURE_80"),
            ("requestTracingEnabled: true", "requestTracingEnabled: false", "CKV_AZURE_66"),
            ("httpLoggingEnabled: true", "httpLoggingEnabled: false", "CKV_AZURE_63"),
            ("type: 'AzureFiles'", "type: 'AzureBlob'", "CKV_AZURE_88"),
            ("enabled: true", "enabled: false", "CKV_AZURE_13"),
        ):
            with self.subTest(check=check):
                result = self.run_source(FULL.replace(original, replacement))
                self.assert_blocked(result)
                child = next(
                    row for row in result["applicability"]
                    if row["resource"] == SETTINGS and row["check"] == check
                )
                self.assertEqual(child["status"], "BLOCKED")
                self.assertEqual(child["scanner_status"], "FAILED")
                self.assertTrue(any(
                    row["check_id"] == check and row["check_result"]["result"] == "FAILED"
                    for row in result["scanner_report"]["results"]["failed_checks"]
                ))

    def test_missing_sibling_or_parent_does_not_become_nonapplicable(self):
        for source in (FULL.replace(WEB, ""), FULL.replace(AUTH, ""), FULL.replace(SITE, "")):
            with self.subTest(source=source):
                result = self.run_source(source)
                self.assert_blocked(result)
        result = self.run_source(SITE + CHILD)
        self.assert_blocked(result)
        self.assertIsNotNone(result["scanner_report"])
        statuses = {row["check"]: row["status"] for row in result["applicability"] if row["resource"] == SETTINGS}
        self.assertEqual(statuses["CKV_AZURE_222"], "NOT_APPLICABLE")
        self.assertEqual({statuses[check] for check in CONFIG_CHECKS if check != "CKV_AZURE_222"}, {"BLOCKED"})

    def test_site_and_web_ingress_must_both_pass_when_both_are_authored(self):
        for source in (
            SITE.replace("'Disabled'", "'Enabled'") + WEB + AUTH + CHILD,
            SITE + WEB.replace("'Disabled'", "'Enabled'") + AUTH + CHILD,
        ):
            result = self.run_source(source)
            self.assert_blocked(result)
            row = next(row for row in result["applicability"]
                       if row["resource"] == SETTINGS and row["check"] == "CKV_AZURE_222")
            self.assertEqual(row["status"], "BLOCKED")
            self.assertEqual({proof["scanner_status"] for proof in row["applicability_evidence"]},
                             {"PASSED", "FAILED"})

    def test_same_source_different_site_cannot_supply_a_sibling_proof(self):
        other_site = SITE.replace("resource site ", "resource other ").replace("'fixture'", "'other'")
        foreign_auth = AUTH.replace("parent: site", "parent: other")
        result = self.run_source(SITE + other_site + WEB + CHILD + foreign_auth)
        self.assert_blocked(result)
        child = next(row for row in result["applicability"]
                     if row["resource"] == SETTINGS and row["check"] == "CKV_AZURE_13")
        self.assertEqual(child["status"], "BLOCKED")
        self.assertEqual(child["applicability_evidence"], [])

    def test_unknown_child_sibling_or_parent_cannot_disappear_behind_other_successes(self):
        for selected, name in ((ingress, "appsettings"), (ingress, "fixture"), (logging, "web")):
            with self.subTest(check=selected.id, name=name):
                original = selected.scan_resource_conf

                def unknown(conf):
                    return CheckResult.UNKNOWN if conf.get("name") == name else original(conf)

                with patch.object(selected, "scan_resource_conf", side_effect=unknown):
                    result = self.run_source(FULL)
                self.assert_blocked(result)
                self.assertIn("missing, duplicate or unexpected resource/check obligation", result["blockers"])
                self.assertGreater(len(result["scanner_report"]["results"]["passed_checks"]), 0)
                self.assertTrue(any(row["status"] == "BLOCKED" for row in result["applicability"]))

    def test_literal_mixed_identity_passes_and_user_only_empty_or_quoted_keys_stay_failed(self):
        for identity_type in ("SystemAssigned, UserAssigned", "UserAssigned,SystemAssigned"):
            result = self.run_source(SITE.replace("SystemAssigned, UserAssigned", identity_type))
            self.assertEqual(result["status"], "QUALIFIED_SUBSET", result["blockers"])
        quoted_user = self.run_source(SITE.replace("SystemAssigned, UserAssigned", "UserAssigned"))
        self.assert_blocked(quoted_user)
        self.assertEqual(next(row["status"] for row in quoted_user["applicability"]
                              if row["check"] == "CKV_AZURE_16"), "FAILED")
        result = self.run_source(SITE.replace("SystemAssigned, UserAssigned", "UserAssigned")
                                 .replace("'" + UAMI + "': {}", ""))
        self.assert_blocked(result)
        row = next(row for row in result["applicability"] if row["check"] == "CKV_AZURE_16")
        self.assertEqual(row["status"], "FAILED")
        self.assertEqual(len(result["scanner_report"]["results"]["failed_checks"]), 1)
        result = self.run_source(SITE.replace(UAMI, "/identities/example")
                                 .replace("SystemAssigned, UserAssigned", "UserAssigned"))
        self.assert_blocked(result)
        self.assertEqual(next(row["status"] for row in result["applicability"]
                              if row["check"] == "CKV_AZURE_16"), "FAILED")

    def test_cosmos_is_not_a_site_check_and_multiwrite_false_does_not_bypass_network(self):
        secure = self.run_source(COSMOS)
        self.assertEqual(secure["status"], "QUALIFIED_SUBSET", secure["blockers"])
        self.assertEqual(len(secure["obligations"]), 4)
        self.assertEqual({row["check"] for row in secure["obligations"]}, set(COSMOS_CHECKS))
        self.assertEqual(secure["obligations"][0]["resource"], "Microsoft.DocumentDB/databaseAccounts.account")
        safe_record = next(
            row for row in secure["scanner_report"]["results"]["passed_checks"]
            if row["check_id"] == "CKV_AZURE_99"
        )
        self.assertEqual(safe_record["check_result"]["result"], "PASSED")
        unsafe = self.run_source(COSMOS.replace("'Disabled'", "'Enabled'"))
        self.assert_blocked(unsafe)
        self.assertEqual(unsafe["applicability"][0]["status"], "FAILED")
        unsafe_record = next(
            row for row in unsafe["scanner_report"]["results"]["failed_checks"]
            if row["check_id"] == "CKV_AZURE_99"
        )
        self.assertEqual(unsafe_record["check_result"]["result"], "FAILED")
        combined = self.run_source(FULL + COSMOS)
        self.assertEqual(combined["status"], "QUALIFIED_SUBSET", combined["blockers"])
        self.assertEqual(len(combined["obligations"]), 24)

    def test_cosmos_all_dispatched_rules_are_obligations_not_only_network(self):
        for field, check in (
            ("disableLocalAuth", "CKV_AZURE_140"),
            ("disableKeyBasedMetadataWriteAccess", "CKV_AZURE_132"),
        ):
            with self.subTest(field=field):
                result = self.run_source(COSMOS.replace("  " + field + ": true\n", ""))
                self.assert_blocked(result)
                self.assertEqual({row["check"] for row in result["obligations"]}, set(COSMOS_CHECKS))
                row = next(row for row in result["applicability"] if row["check"] == check)
                self.assertEqual(row["status"], "FAILED")
                self.assertEqual(row["scanner_status"], "FAILED")
                self.assertTrue(any(
                    item["check_id"] == "CKV_AZURE_99"
                    for item in result["scanner_report"]["results"]["passed_checks"]
                ))

    def test_cosmos_unknown_or_lost_each_rule_blocks_despite_other_passes(self):
        from checkov.bicep.checks.resource.registry import registry

        checks = registry.get_checks("Microsoft.DocumentDB/databaseAccounts")
        self.assertEqual({check.id for check in checks}, set(COSMOS_CHECKS))
        for check in checks:
            with self.subTest(check=check.id), patch.object(
                check, "scan_resource_conf", return_value=CheckResult.UNKNOWN,
            ):
                result = self.run_source(COSMOS)
                self.assert_blocked(result)
                self.assertIn("missing, duplicate or unexpected resource/check obligation", result["blockers"])
                self.assertEqual(len(result["scanner_report"]["results"]["passed_checks"]), 3)

    def test_cosmos_added_python_or_graph_dispatch_never_silently_drops_a_policy(self):
        from checkov.bicep.checks.resource.registry import registry
        from types import SimpleNamespace

        _verify_cosmos_dispatch()
        original = registry.get_checks
        for kind in (
            "Microsoft.DocumentDB/databaseAccounts",
            "Microsoft.DocumentDB/databaseAccounts/sqlDatabases",
            "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers",
        ):
            with self.subTest(kind=kind), patch.object(
                registry, "get_checks",
                side_effect=lambda selected: original(selected) + (
                    [SimpleNamespace(id="NEW_POLICY")] if selected == kind else []
                ),
            ), self.assertRaisesRegex(ValueError, "unqualified Cosmos policy dispatch"):
                _verify_cosmos_dispatch()
        graph = SimpleNamespace(
            resource_types=["Microsoft.DocumentDB/*"], connected_resources_types=[], sub_checks=[],
        )
        with patch.object(registry.graph_registry, "checks", [graph]), self.assertRaisesRegex(
            ValueError, "unqualified Cosmos policy dispatch",
        ):
            _verify_cosmos_dispatch()

    def test_truthy_unresolved_runner_flag_cannot_override_bound_false(self):
        parameterized = "param metadataDisabled bool\n" + COSMOS.replace(
            "disableKeyBasedMetadataWriteAccess: true",
            "disableKeyBasedMetadataWriteAccess: metadataDisabled",
        )
        source = MULTI_ROOT.replace("deploymentLabel: env",
                                   "deploymentLabel: env\n metadataDisabled: false")
        with module_fixture(root_source=source, cosmos_source=parameterized) as root:
            result = qualify_local_module(root, "prod", "data")
        self.assert_blocked(result)
        raw = result["scanner_report"]
        self.assertEqual(raw["results"]["failed_checks"], [])
        self.assertEqual(len(raw["results"]["passed_checks"]), 4)
        row = next(row for row in result["applicability"] if row["check"] == "CKV_AZURE_132")
        self.assertEqual(row["scanner_status"], "PASSED")
        self.assertEqual(row["status"], "BLOCKED")
        self.assertIn("Runner inputs differ from bound AST: "
                      "Microsoft.DocumentDB/databaseAccounts.account/CKV_AZURE_132", result["blockers"])
        self.assertFalse(next(
            proof["matches_bound_ast"] for proof in result["scanner_input_provenance"]
            if proof["check"] == "CKV_AZURE_132"
        ))

    def test_real_cosmos_literal_policy_positive_fixture_qualifies_without_rewriting_runner_input(self):
        with real_cosmos_fixture("staging") as root:
            child = root.parent / "modules" / "cosmos.bicep"
            original = child.read_text()
            # Authored test-only security literals; no infrastructure source is changed.
            source = original.replace("disableLocalAuth: disableLocalAuth", "disableLocalAuth: true").replace(
                "minimalTlsVersion: 'Tls12'",
                "minimalTlsVersion: 'Tls12'\n    disableKeyBasedMetadataWriteAccess: true",
            )
            self.assertNotEqual(source, original)
            child.write_text(source)
            result = qualify_local_module(root, "staging", "data")
            if version("pycep-parser") != COMPAT_PARSER_VERSION:
                self.assert_blocked(result)
                self.assertIn("module source parsing failed: UnexpectedToken", result["blockers"])
                self.assertIsNone(result["scanner_report"])
                self.assertEqual(child.read_text(), source)
                return
            self.assertEqual(result["status"], "QUALIFIED_SUBSET", result["blockers"])
            self.assertEqual(len(result["obligations"]), 18)
            self.assertEqual(len(result["scanner_report"]["results"]["passed_checks"]), 4)
            self.assertTrue(all(proof["matches_bound_ast"]
                                for proof in result["scanner_input_provenance"]))
            self.assertEqual(child.read_text(), source)
            self.assertFalse(result["production_adoptable"])

    def test_real_cosmos_children_contract_and_full_rule_inventory_keep_raw_failures(self):
        for environment in ("dev", "staging", "prod"):
            with self.subTest(environment=environment), real_cosmos_fixture(environment) as root:
                result = qualify_local_module(root, environment, "data")
                self.assert_blocked(result)
                if version("pycep-parser") != COMPAT_PARSER_VERSION:
                    self.assertIn("module source parsing failed: UnexpectedToken", result["blockers"])
                    self.assertIsNone(result["scanner_report"])
                    continue
                binding = result["binding_resolution"]
                params = {item["parameter"]: item for item in binding["parameters"]}
                self.assertEqual(params["disableLocalAuth"]["value"], environment != "dev")
                self.assertEqual(params["tags"]["value"], {"product": "Certigo", "env": environment})
                self.assertFalse(binding["blockers"], binding["blockers"])
                self.assertEqual(len(result["obligations"]), 18)  # account checks + database + 13 containers
                self.assertEqual({row["check"] for row in result["obligations"] if row["check"]}, set(COSMOS_CHECKS))
                children = [row for row in result["applicability"] if row["check"] is None]
                self.assertEqual(len(children), 14)
                self.assertEqual({row["status"] for row in children}, {"NO_POLICY_IN_PINNED_RUNNER"})
                self.assertTrue(all(row["parent"] for row in children))
                report = result["scanner_report"]
                self.assertIsNotNone(report, result["blockers"])
                self.assertEqual(report["summary"]["resource_count"], 1)
                self.assertEqual({r["check_id"] for r in report["results"]["passed_checks"]},
                                 {"CKV_AZURE_99", "CKV_AZURE_101"})
                self.assertEqual({r["check_id"] for r in report["results"]["failed_checks"]},
                                 {"CKV_AZURE_132", "CKV_AZURE_140"})
                contract = root.parent.parent / "contracts" / "cosmos-containers.json"
                self.assertEqual(binding["source_inputs"][str(contract)]["sha256"],
                                 hashlib.sha256(contract.read_bytes()).hexdigest())
                child = root.parent / "modules" / "cosmos.bicep"
                self.assertEqual(result["provenance"]["module_sha256"],
                                 hashlib.sha256(child.read_bytes()).hexdigest())

    def test_real_cosmos_unsafe_network_unknown_parent_and_contract_damage_block(self):
        for damage in (
            "network", "unknown-network", "parent", "duplicate-container", "bad-json",
            "foreign-json", "loop-condition", "loop-function", "output",
        ):
            with self.subTest(damage=damage), real_cosmos_fixture("prod") as root:
                child = root.parent / "modules" / "cosmos.bicep"
                text = child.read_text()
                original = text
                contract = root.parent.parent / "contracts" / "cosmos-containers.json"
                if damage == "network":
                    text = text.replace("publicNetworkAccess: 'Disabled'", "publicNetworkAccess: 'Enabled'")
                elif damage == "unknown-network":
                    text = text.replace("publicNetworkAccess: 'Disabled'", "publicNetworkAccess: accountName")
                elif damage == "parent":
                    text = text.replace("parent: database", "parent: missing")
                elif damage == "duplicate-container":
                    value = json.loads(contract.read_text())
                    value["containers"].append(value["containers"][0])
                    contract.write_text(json.dumps(value))
                elif damage == "bad-json":
                    contract.write_text("{invalid}")
                elif damage == "foreign-json":
                    text = text.replace("../../contracts/cosmos-containers.json", "../../private.json")
                elif damage == "loop-condition":
                    text = text.replace("for c in containers: {", "for c in containers: if (hardened) {")
                elif damage == "loop-function":
                    text = text.replace("id: c.name", "id: uniqueString(c.name)")
                elif damage == "output":
                    text = text.replace("output backupMode string = backupMode", "output backupMode string = accountName")
                if damage not in ("duplicate-container", "bad-json"):
                    self.assertNotEqual(text, original, damage)
                child.write_text(text)
                result = qualify_local_module(root, "prod", "data")
                self.assert_blocked(result)
                if damage == "network" and version("pycep-parser") == COMPAT_PARSER_VERSION:
                    self.assertEqual({r["check_id"] for r in result["scanner_report"]["results"]["failed_checks"]},
                                     set(COSMOS_CHECKS))
                else:
                    self.assertIsNone(result["scanner_report"])

    def test_cosmos_contract_snapshot_is_captured_once_and_rejects_missing_empty_or_duplicate_input(self):
        for damage in ("missing", "empty", "duplicate-json-key", "symbol", "ttl", "symlink"):
            with self.subTest(damage=damage), real_cosmos_fixture("prod") as root:
                contract = root.parent.parent / "contracts" / "cosmos-containers.json"
                value = json.loads(contract.read_text())
                if damage == "missing":
                    contract.unlink()
                elif damage == "empty":
                    value["containers"] = []
                    contract.write_text(json.dumps(value))
                elif damage == "duplicate-json-key":
                    contract.write_text(contract.read_text().replace(
                        '"databaseName": "certigo"', '"databaseName": "certigo", "databaseName": "other"',
                    ))
                elif damage == "symbol":
                    value["containers"][1]["symbol"] = value["containers"][0]["symbol"]
                    contract.write_text(json.dumps(value))
                elif damage == "ttl":
                    value["containers"][0]["defaultTimeToLive"] = True
                    contract.write_text(json.dumps(value))
                else:
                    target = contract.with_name("other.json")
                    contract.rename(target)
                    contract.symlink_to(target)
                with patch("bicep_ingress_candidate.Runner.run") as runner:
                    result = qualify_local_module(root, "prod", "data")
                self.assert_blocked(result)
                runner.assert_not_called()
                if version("pycep-parser") == COMPAT_PARSER_VERSION:
                    self.assertTrue(any("Cosmos" in reason and "contract" in reason
                                        for reason in result["blockers"]))
                else:
                    self.assertIn("module source parsing failed: UnexpectedToken", result["blockers"])
        with real_cosmos_fixture("prod") as root:
            contract = root.parent.parent / "contracts" / "cosmos-containers.json"
            original_open = Path.open
            reads = []

            def capture(path, *args, **kwargs):
                if path == contract:
                    reads.append(path)
                return original_open(path, *args, **kwargs)

            with patch.object(Path, "open", capture):
                binding = resolve_local_module_bindings(root, "prod", "data")
            if version("pycep-parser") == COMPAT_PARSER_VERSION:
                self.assertFalse(binding["blockers"], binding["blockers"])
                self.assertEqual(reads, [contract])
                self.assertEqual(len(binding["values"]["containers"]), 13)
            else:
                self.assertIn("module source parsing failed: UnexpectedToken", binding["blockers"])
                self.assertEqual(reads, [])

    def test_real_root_cosmos_provenance_never_invents_subscription_name_or_required_backup(self):
        root = Path(__file__).resolve().parents[2] / "infra" / "main.bicep"
        for environment in ("dev", "staging", "prod"):
            with self.subTest(environment=environment), patch("bicep_ingress_candidate.Runner.run") as runner:
                result = qualify_local_module(root, environment, "data")
            self.assert_blocked(result)
            runner.assert_not_called()
            if version("pycep-parser") != COMPAT_PARSER_VERSION:
                self.assertTrue(any("root source parsing failed" in b for b in result["blockers"]))
                continue
            binding = result["binding_resolution"]
            params = {item["parameter"]: item for item in binding["parameters"]}
            self.assertEqual({name for name, item in params.items() if not item["resolved"]},
                             {"accountName", "backupMode"})
            self.assertEqual(params["databaseName"]["value"], "certigo")
            self.assertEqual(params["location"]["value"], "westeurope")
            self.assertEqual(params["disableLocalAuth"]["value"], environment != "dev")
            self.assertEqual(params["tags"]["value"]["env"], environment)
            self.assertEqual(len(result["obligations"]), 18)

    def test_resolved_snapshot_keeps_original_failures_and_real_metadata_failure(self):
        with snapshot_fixture() as root:
            child = root.parent / "modules" / "cosmos.bicep"
            before = (root.read_bytes(), child.read_bytes())
            for env, mode in (("dev", "Periodic"), ("staging", "Continuous"), ("prod", "Continuous")):
                with self.subTest(environment=env):
                    result = qualify_cosmos_snapshot(root, env, mode)
                    self.assert_blocked(result)
                    if version("pycep-parser") != COMPAT_PARSER_VERSION:
                        self.assertIsNone(result["resolved_report"])
                        self.assertIn("module source parsing failed: UnexpectedToken", result["blockers"])
                        continue
                    self.assertEqual(result["schema"], "certigo.bicep-cosmos-resolved-qualification/v5")
                    self.assertEqual(len(result["obligations"]), 18)
                    self.assertEqual({r["check_id"] for r in result["authored_report"]["results"]["failed_checks"]},
                                     {"CKV_AZURE_132", "CKV_AZURE_140"})
                    expected = {"CKV_AZURE_132", "CKV_AZURE_140"} if env == "dev" else {"CKV_AZURE_132"}
                    self.assertEqual({r["check_id"] for r in result["resolved_report"]["results"]["failed_checks"]},
                                     expected)
                    snapshot = result["resolved_snapshot"]
                    self.assertEqual(len(snapshot["source_map"]), 15)
                    self.assertEqual(snapshot["sha256"], hashlib.sha256(
                        snapshot["source_text"].encode("utf-8"),
                    ).hexdigest())
                    self.assertTrue(snapshot["ast_round_trip_verified"])
                    lines = snapshot["source_text"].splitlines()
                    for entry in snapshot["source_map"]:
                        start, end = entry["snapshot_line_range"]
                        self.assertTrue(lines[start - 1].startswith("resource " + entry["snapshot_symbol"] + " "))
                        self.assertLessEqual(start, end)
                        self.assertLessEqual(end, len(lines))
                    self.assertFalse(snapshot["actual_deployment_parameters_verified"])
                    self.assertFalse(snapshot["symbolic_inputs"][0]["actual_azure_name_known"])
                    self.assertEqual(snapshot["explicit_root_parameters"], {"cosmosBackupMode": mode})
                    self.assertTrue(all(p["matches_bound_ast"] for p in result["resolved_input_provenance"]))
                    self.assertEqual({row["status"] for row in result["resolved_applicability"] if row["check"] is None},
                                     {"NO_POLICY_IN_PINNED_RUNNER"})
            self.assertEqual((root.read_bytes(), child.read_bytes()), before)

    def test_resolved_snapshot_positive_and_deterministic_hash_are_separate_from_authored_report(self):
        with snapshot_fixture() as root:
            child = root.parent / "modules" / "cosmos.bicep"
            child.write_text(child.read_text().replace(
                "minimalTlsVersion: 'Tls12'",
                "minimalTlsVersion: 'Tls12'\n    disableKeyBasedMetadataWriteAccess: true",
            ))
            first = qualify_cosmos_snapshot(root, "staging", "Continuous")
            if version("pycep-parser") != COMPAT_PARSER_VERSION:
                self.assert_blocked(first)
                self.assertIsNone(first["resolved_report"])
                return
            self.assertEqual(first["status"], "QUALIFIED_SUBSET", first["blockers"])
            second = qualify_cosmos_snapshot(root, "staging", "Continuous")
            self.assertEqual(first["resolved_snapshot"], second["resolved_snapshot"])
            self.assertEqual(len(first["resolved_report"]["results"]["passed_checks"]), 4)
            self.assertEqual({r["check_id"] for r in first["authored_report"]["results"]["failed_checks"]},
                             {"CKV_AZURE_140"})
            self.assertFalse(first["production_adoptable"])

    def test_resolved_snapshot_rejects_symbolic_network_reuse_secret_or_unreviewed_suffix(self):
        for damage in ("network-reuse", "suffix", "secret", "dynamic", "unused-backup"):
            with self.subTest(damage=damage), snapshot_fixture() as root:
                child = root.parent / "modules" / "cosmos.bicep"
                if damage == "network-reuse":
                    child.write_text(child.read_text().replace(
                        "publicNetworkAccess: 'Disabled'", "publicNetworkAccess: accountName",
                    ))
                elif damage == "suffix":
                    root.write_text(root.read_text().replace("subscription().id", "resourceGroup().id"))
                elif damage == "secret":
                    root.write_text(root.read_text().replace("param cosmosBackupMode", "@secure()\nparam cosmosBackupMode"))
                elif damage == "unused-backup":
                    root.write_text(root.read_text().replace("backupMode: cosmosBackupMode", "backupMode: 'Periodic'"))
                else:
                    child.write_text(child.read_text().replace("publicNetworkAccess: 'Disabled'",
                                                              "publicNetworkAccess: unknownFunction()"))
                with patch("bicep_ingress_candidate.Runner.run") as runner:
                    result = qualify_cosmos_snapshot(root, "prod", "Continuous")
                self.assert_blocked(result)
                runner.assert_not_called()
                self.assertIsNone(result["authored_report"])
                self.assertIsNone(result["resolved_report"])

    def test_resolved_snapshot_cannot_repair_a_lost_authored_unknown_record(self):
        from checkov.arm.checks.resource.CosmosDBDisablesPublicNetwork import check

        with snapshot_fixture() as root, patch.object(
            check, "scan_resource_conf", return_value=CheckResult.UNKNOWN,
        ):
            result = qualify_cosmos_snapshot(root, "prod", "Continuous")
        self.assert_blocked(result)
        if version("pycep-parser") == COMPAT_PARSER_VERSION:
            self.assertIsNotNone(result["authored_report"])
            self.assertIn("missing, duplicate or unexpected resource/check obligation", result["blockers"])
        self.assertIsNone(result["resolved_report"])
        original = check.scan_resource_conf
        calls = []

        def lose_second(conf):
            calls.append(conf)
            return CheckResult.UNKNOWN if len(calls) == 2 else original(conf)

        with snapshot_fixture() as root, patch.object(check, "scan_resource_conf", side_effect=lose_second):
            result = qualify_cosmos_snapshot(root, "prod", "Continuous")
        self.assert_blocked(result)
        if version("pycep-parser") == COMPAT_PARSER_VERSION:
            self.assertEqual(len(calls), 2)
            self.assertIsNotNone(result["resolved_report"])
            self.assertIn("missing, duplicate or unexpected resource/check obligation", result["blockers"])

    def test_resolved_snapshot_lost_child_blocks_ast_round_trip_before_second_runner(self):
        original = _parse_source

        def lose_child(source):
            tree = original(source)
            if source.startswith("resource account "):
                tree["resources"].pop("containerResources_12")
            return tree

        with snapshot_fixture() as root, patch("bicep_ingress_candidate._parse_source", side_effect=lose_child):
            result = qualify_cosmos_snapshot(root, "prod", "Continuous")
        self.assert_blocked(result)
        self.assertIsNone(result["resolved_report"])
        if version("pycep-parser") == COMPAT_PARSER_VERSION:
            self.assertIsNotNone(result["authored_report"])
            self.assertIn("snapshot AST does not exactly reproduce the independent resource inventory",
                          result["blockers"])

    def test_resolved_snapshot_preserves_unsafe_network_and_blocks_escaping(self):
        for damage in ("enabled", "escaping"):
            with self.subTest(damage=damage), snapshot_fixture() as root:
                child = root.parent / "modules" / "cosmos.bicep"
                if damage == "enabled":
                    child.write_text(child.read_text().replace("publicNetworkAccess: 'Disabled'",
                                                              "publicNetworkAccess: 'Enabled'"))
                else:
                    root.write_text(root.read_text().replace("product: 'Certigo'", "product: 'Certigo\\\\test'"))
                result = qualify_cosmos_snapshot(root, "prod", "Continuous")
                self.assert_blocked(result)
                if version("pycep-parser") != COMPAT_PARSER_VERSION:
                    self.assertIsNone(result["resolved_report"])
                elif damage == "enabled":
                    self.assertEqual({r["check_id"] for r in result["resolved_report"]["results"]["failed_checks"]},
                                     {"CKV_AZURE_99", "CKV_AZURE_101", "CKV_AZURE_132"})
                else:
                    self.assertTrue(any("snapshot rendering blocked" in reason for reason in result["blockers"]))
                    self.assertIsNone(result["resolved_report"])

    def test_resolved_cli_requires_explicit_mode_and_exact_module_selection(self):
        script = str(Path(__file__).with_name("bicep_ingress_candidate.py"))
        with snapshot_fixture() as root:
            for flags in (
                ["--resolved-cosmos-snapshot", "--module-symbol", "data"],
                ["--cosmos-backup-mode", "Periodic"],
                ["--resolved-cosmos-snapshot", "--module-symbol", "api", "--cosmos-backup-mode", "Periodic"],
            ):
                run = subprocess.run([sys.executable, script, str(root), "--environment", "prod", *flags],
                                     capture_output=True, text=True)
                self.assertEqual(run.returncode, 2, run.stderr)
            with self.assertRaisesRegex(ValueError, "explicit Periodic or Continuous"):
                qualify_cosmos_snapshot(root, "prod", None)
            run = subprocess.run(
                [sys.executable, script, str(root), "--environment", "prod",
                 "--module-symbol", "data", "--resolved-cosmos-snapshot", "--cosmos-backup-mode", "Continuous"],
                capture_output=True, text=True,
            )
            self.assertEqual(run.returncode, 1, run.stderr)
            result = json.loads(run.stdout)
            self.assertEqual(result["schema"], "certigo.bicep-cosmos-resolved-qualification/v5")
            self.assert_blocked(result)
            if version("pycep-parser") == COMPAT_PARSER_VERSION:
                self.assertEqual({r["check_id"] for r in result["resolved_report"]["results"]["failed_checks"]},
                                 {"CKV_AZURE_132"})

    def test_local_module_resolves_explicit_environment_bindings_before_real_runner(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "main.bicep"
            module_dir = Path(temporary) / "modules"
            module_dir.mkdir()
            module_path = module_dir / "functionApp.bicep"
            root.write_text(MODULE_ROOT, encoding="utf-8")
            module_path.write_text(MODULE_SOURCE, encoding="utf-8")
            expected = {
                "dev": (["*"], "dev"),
                "staging": ([], "prod"),
                "prod": ([], "prod"),
            }
            for environment, (origins, auth_mode) in expected.items():
                bindings = resolve_local_module_bindings(root, environment)
                self.assertEqual(bindings["blockers"], [])
                values = bindings["values"]
                self.assertEqual(values["allowedCorsOrigins"], origins)
                self.assertEqual(values["authMode"], auth_mode)
            result = qualify_local_module(root, "staging")
            self.assertEqual(result["status"], "QUALIFIED_SUBSET", result["blockers"])
            self.assertEqual(result["schema"], "certigo.bicep-appservice-qualification/v3")
            self.assertFalse(result["production_adoptable"])
            self.assertEqual(result["binding_resolution"]["module_sha256"],
                             hashlib.sha256(module_path.read_bytes()).hexdigest())
            self.assertEqual(result["provenance"]["root_sha256"],
                             hashlib.sha256(root.read_bytes()).hexdigest())
            self.assertEqual(result["provenance"]["module_instance"], "root/api")
            settings = next(row for row in result["obligations"]
                            if row["resource"] == SETTINGS)
            self.assertEqual(settings["subtype"], "appsettings")
            self.assertEqual(result["scanner_report"]["summary"]["resource_count"], 4)

    def test_unresolved_local_module_binding_blocks_before_runner_and_redacts_secure_values(self):
        root_source = MODULE_ROOT.replace(
            "param env string",
            "param env string\n@secure()\nparam deploymentSecret string",
        ).replace(
            "authMode: authMode",
            "authMode: authMode\n deploymentSecret: deploymentSecret",
        )
        module_source = MODULE_SOURCE.replace(
            "param authMode string",
            "@secure()\nparam deploymentSecret string\nparam authMode string",
        )
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "main.bicep"
            module_dir = Path(temporary) / "modules"
            module_dir.mkdir()
            (module_dir / "functionApp.bicep").write_text(module_source, encoding="utf-8")
            root.write_text(root_source, encoding="utf-8")
            result = qualify_local_module(root, "prod")
            self.assertEqual(result["status"], "BLOCKED")
            self.assertIsNone(result["scanner_report"])
            binding = result["binding_resolution"]
            secret = next(item for item in binding["parameters"]
                          if item["parameter"] == "deploymentSecret")
            self.assertFalse(secret["resolved"])
            self.assertTrue(secret["secure"])
            self.assertNotIn("value", secret)
            self.assertTrue(any("deploymentSecret" in blocker
                                for blocker in result["blockers"]))

    def test_repository_modules_have_explicit_provenance_but_unqualified_values_stay_blocked(self):
        infra = Path(__file__).resolve().parents[2] / "infra"
        for environment in ("dev", "staging", "prod"):
            with self.subTest(environment=environment):
                result = qualify_local_modules(infra / "main.bicep", environment, ["data", "api"])
                self.assert_blocked(result)
                self.assertEqual(result["provenance"]["parser"]["version"], version("pycep-parser"))
                if version("pycep-parser") == "0.5.1":
                    self.assertEqual(result["modules"], [])
                    self.assertTrue(any("root source parsing failed" in blocker
                                        for blocker in result["blockers"]))
                    continue
                self.assertEqual(len(result["modules"]), 2)
                calls = result["root_inventory"]["module_calls"]
                self.assertEqual({item["symbol"] for item in calls if item["selected"]}, {"data", "api"})
                self.assertTrue(any(not item["selected"] for item in calls))
                for module, symbol, filename in zip(
                    result["modules"], ("data", "api"), ("cosmos.bicep", "functionApp.bicep")
                ):
                    self.assert_blocked(module)
                    self.assertIsNone(module["scanner_report"])
                    self.assertEqual(module["provenance"]["module_instance"], "root/" + symbol)
                    binding = module["binding_resolution"]
                    self.assertEqual(binding["module_sha256"], hashlib.sha256(
                        (infra / "modules" / filename).read_bytes()
                    ).hexdigest())
                    self.assertEqual(binding["module_scope"]["name"], "rg-certigo-" + environment)
                    self.assertFalse(any("root source parsing failed" in b for b in module["blockers"]))
                app = result["modules"][1]
                params = {item["parameter"]: item for item in app["binding_resolution"]["parameters"]}
                self.assertEqual(params["allowedCorsOrigins"]["value"], ["*"] if environment == "dev" else [])
                self.assertEqual(params["authMode"]["value"], "dev" if environment == "dev" else "prod")
                self.assertFalse(params["functionAppName"]["resolved"])
                self.assertTrue(any("resource type has no qualified mapping" in b for b in app["blockers"]))

    def test_multiple_modules_keep_independent_reports_and_all_selected_instances(self):
        with module_fixture() as root:
            result = qualify_local_modules(root, "staging", ["api", "data"])
            self.assertEqual(result["status"], "QUALIFIED_SUBSET", result["blockers"])
            self.assertEqual(result["schema"], "certigo.bicep-appservice-qualification/v4")
            self.assertFalse(result["production_adoptable"])
            self.assertEqual([m["provenance"]["module_instance"] for m in result["modules"]],
                             ["root/api", "root/data"])
            self.assertEqual([m["scanner_report"]["summary"]["resource_count"] for m in result["modules"]],
                             [4, 1])
            self.assertEqual(len(result["modules"][1]["obligations"]), 4)
            self.assertEqual(result["modules"][1]["binding_resolution"]["module_name"], "cosmos-staging")
            self.assertEqual(result["provenance"]["root_sha256"], hashlib.sha256(root.read_bytes()).hexdigest())

    def test_all_selected_module_inventories_exist_before_first_runner(self):
        events = []
        original_inventory = inventory
        original_run = Runner.run

        def observed_inventory(*args, **kwargs):
            events.append("inventory")
            return original_inventory(*args, **kwargs)

        def observed_run(*args, **kwargs):
            events.append("runner")
            return original_run(*args, **kwargs)

        with module_fixture() as root, patch(
            "bicep_ingress_candidate.inventory", side_effect=observed_inventory
        ), patch.object(Runner, "run", side_effect=observed_run, autospec=True):
            result = qualify_local_modules(root, "prod", ["api", "data"])
        self.assertEqual(result["status"], "QUALIFIED_SUBSET", result["blockers"])
        self.assertEqual(events, ["inventory", "inventory", "runner", "runner"])

    def test_unsafe_missing_or_unresolved_second_module_never_hides_behind_safe_first(self):
        for damage in ("unsafe", "missing", "dynamic", "unknown-resource", "parse", "unknown-result"):
            with self.subTest(damage=damage), module_fixture() as root:
                child = root.parent / "modules" / "cosmos.bicep"
                if damage == "unsafe":
                    child.write_text(child.read_text().replace("'Disabled'", "'Enabled'"), encoding="utf-8")
                elif damage == "missing":
                    child.unlink()
                elif damage == "dynamic":
                    root.write_text(MULTI_ROOT.replace("deploymentLabel: env", "deploymentLabel: missing"),
                                    encoding="utf-8")
                elif damage == "unknown-resource":
                    child.write_text(child.read_text() + "\nresource other 'Example/unknown@2024-01-01' = { name: 'x' }\n",
                                     encoding="utf-8")
                elif damage == "parse":
                    child.write_text("resource broken", encoding="utf-8")
                from checkov.arm.checks.resource.CosmosDBAccountsRestrictedAccess import check as cosmos_check

                original = cosmos_check.scan_resource_conf
                with patch.object(cosmos_check, "scan_resource_conf", side_effect=(
                    (lambda conf: CheckResult.UNKNOWN) if damage == "unknown-result" else original
                )):
                    result = qualify_local_modules(root, "prod", ["api", "data"])
                self.assert_blocked(result)
                self.assertEqual(result["modules"][0]["status"], "QUALIFIED_SUBSET")
                failed = result["modules"][1]
                self.assert_blocked(failed)
                if damage == "unsafe":
                    self.assertEqual(failed["applicability"][0]["status"], "FAILED")
                    self.assertEqual(
                        {row["check_id"] for row in failed["scanner_report"]["results"]["failed_checks"]},
                        {"CKV_AZURE_99", "CKV_AZURE_101"},
                    )
                elif damage != "unknown-result":
                    self.assertIsNone(failed["scanner_report"])

    def test_module_selection_scope_conditions_loops_and_secret_defaults_fail_closed(self):
        for damage in ("empty", "duplicate", "absent", "scope", "condition", "loop", "secret", "function"):
            with self.subTest(damage=damage), module_fixture() as root:
                selected = ["api", "data"]
                if damage == "empty":
                    selected = []
                elif damage == "duplicate":
                    selected = ["api", "api"]
                elif damage == "absent":
                    selected = ["api", "absent"]
                else:
                    source = MULTI_ROOT
                    if damage == "scope":
                        source = source.replace("name: 'cosmos-${env}'", "scope: resourceGroup('other')\n name: 'cosmos-${env}'")
                    elif damage == "condition":
                        source = source.replace("'./modules/cosmos.bicep' = {", "'./modules/cosmos.bicep' = if (true) {")
                    elif damage == "loop":
                        source = source.replace("'./modules/cosmos.bicep' = {", "'./modules/cosmos.bicep' = [for x in [1]: {")
                        source = source.rstrip() + "]\n"
                    elif damage == "secret":
                        source = source.replace("param env string", "param env string\n@secure()\nparam hidden string = 'sentinel-not-a-secret'")
                        source = source.replace("deploymentLabel: env", "deploymentLabel: hidden")
                    else:
                        source = source.replace("deploymentLabel: env", "deploymentLabel: uniqueString('seed')")
                    root.write_text(source, encoding="utf-8")
                result = qualify_local_modules(root, "staging", selected)
                self.assert_blocked(result)
                self.assertNotIn("sentinel-not-a-secret", json.dumps(result))

    def test_symbolic_existing_group_scope_is_bound_to_each_environment(self):
        scoped = ("targetScope = 'subscription'\n" + MULTI_ROOT).replace(
            "module api", "resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {\n name: 'rg-${env}'\n}\nmodule api"
        ).replace("name: 'api'", "scope: rg\n name: 'api'").replace(
            "name: 'cosmos-${env}'", "scope: rg\n name: 'cosmos-${env}'\n dependsOn: [api]"
        )
        with module_fixture(root_source=scoped) as root:
            for environment in ("dev", "staging", "prod"):
                bindings = resolve_local_module_bindings(root, environment, "data")
                self.assertEqual(bindings["blockers"], [])
                self.assertEqual(bindings["module_scope"], {
                    "kind": "existing-resource-group", "symbol": "rg", "name": "rg-" + environment,
                })
                self.assertEqual(bindings["dependencies"], ["api"])
            result = qualify_local_modules(root, "prod", ["api", "data"])
            self.assertEqual(result["status"], "QUALIFIED_SUBSET", result["blockers"])
            self.assertFalse(result["root_inventory"]["resources"][0]["qualified"])

    def test_parser_version_and_source_seals_reject_unreviewed_runtimes(self):
        observed = _verify_parser()
        self.assertIn(observed["version"], ("0.5.1", COMPAT_PARSER_VERSION))
        self.assertEqual(set(observed["source_sha256"]), set(UPSTREAM_PARSER_SOURCES))
        with patch("bicep_ingress_candidate.version", return_value="0.5.2"):
            with self.assertRaisesRegex(ValueError, "pinned upstream or reviewed"):
                _verify_parser()
        with patch.dict(UPSTREAM_PARSER_SOURCES, {"pycep/main.py": "0" * 64}):
            with self.assertRaisesRegex(ValueError, "unexpected installed parser source"):
                _verify_parser()
        if observed["version"] == COMPAT_PARSER_VERSION:
            with patch.dict(PATCHED_FILES, {"pycep/bicep.lark": "0" * 64}):
                with self.assertRaisesRegex(ValueError, "unexpected installed parser source"):
                    _verify_parser()

    def test_compatibility_parser_consumes_unmodified_authored_source(self):
        source = MODULE_ROOT.replace(" ? [ '*' ] : []", "\n  ? [ '*' ]\n  : []")
        options = (
            {"side_effect": AssertionError("compatibility parser must not normalize source")}
            if version("pycep-parser") == COMPAT_PARSER_VERSION
            else {"wraps": _parser_source}
        )
        with module_fixture(root_source=source) as root, patch(
            "bicep_ingress_candidate._parser_source", **options
        ) as normalization:
            result = qualify_local_module(root, "staging")
            if version("pycep-parser") == "0.5.1":
                normalization.assert_called()
        self.assertEqual(result["status"], "QUALIFIED_SUBSET", result["blockers"])

    def test_ast_resolved_security_value_does_not_replace_missing_raw_scanner_evidence(self):
        parameterized = "param publicAccess string\n" + COSMOS.replace("'Disabled'", "publicAccess")
        source = MULTI_ROOT.replace("deploymentLabel: env", "deploymentLabel: env\n publicAccess: 'Disabled'")
        with module_fixture(root_source=source, cosmos_source=parameterized) as root:
            result = qualify_local_modules(root, "prod", ["api", "data"])
        self.assert_blocked(result)
        module = result["modules"][1]
        parameters = {item["parameter"]: item for item in module["binding_resolution"]["parameters"]}
        self.assertEqual(parameters["publicAccess"]["value"], "Disabled")
        self.assertTrue(module["blockers"])
        self.assertIsNotNone(module["scanner_report"])

    def test_reused_module_source_has_distinct_instance_provenance_not_shared_verdicts(self):
        source = MULTI_ROOT + """module another './modules/cosmos.bicep' = {
 name: 'another'
 params: { deploymentLabel: 'other' }
}
"""
        with module_fixture(root_source=source) as root:
            source_path = root.parent / "modules" / "cosmos.bicep"
            original_read = Path.read_bytes
            reads = []

            def capture_read(path):
                if path == source_path:
                    reads.append(path)
                return original_read(path)

            with patch.object(Path, "read_bytes", autospec=True, side_effect=capture_read):
                result = qualify_local_modules(root, "prod", ["data", "another"])
            self.assertEqual(len(reads), 1)
        self.assertEqual(result["status"], "QUALIFIED_SUBSET", result["blockers"])
        first, second = result["modules"]
        self.assertEqual(first["provenance"]["module_sha256"], second["provenance"]["module_sha256"])
        self.assertNotEqual(first["provenance"]["module_instance"], second["provenance"]["module_instance"])
        self.assertIsNot(first["scanner_report"], second["scanner_report"])

    def test_cli_multiple_modules_emits_every_instance_and_a_blocking_exit(self):
        with module_fixture(cosmos_source=COSMOS.replace("'Disabled'", "'Enabled'")) as root:
            run = subprocess.run(
                [sys.executable, str(Path(__file__).with_name("bicep_ingress_candidate.py")),
                 str(root), "--environment", "staging", "--module-symbol", "api",
                 "--module-symbol", "data"],
                text=True, capture_output=True, timeout=90,
            )
            self.assertEqual(run.returncode, 1, run.stderr)
            result = json.loads(run.stdout)
            self.assertEqual(result["schema"], "certigo.bicep-appservice-qualification/v4")
            self.assertEqual(len(result["modules"]), 2)
            self.assert_blocked(result)

    def test_unknown_bindings_subtypes_or_properties_block_before_runner(self):
        for source in (
            CHILD,
            FULL.replace("parent: site", "parent: missing"),
            FULL.replace("parent: site", "parent: 'site'"),
            FULL.replace("parent: site", "parent: { id: 'site' }"),
            FULL.replace("'appsettings'", "'authsettingsV2'"),
            FULL.replace("'value'", "setting"),
            FULL.replace("'value'", "'${setting}'"),
            "param setting string\n" + FULL,
            "var value = 'fixture'\n" + FULL,
            "module other './other.bicep' = { name: 'other' }\n" + FULL,
            "output example string = 'fixture'\n" + FULL,
            FULL.replace("httpLoggingEnabled: true", "httpLoggingEnabled: setting"),
            FULL.replace("netFrameworkVersion: 'v8.0'", "netFrameworkVersion: '${runtime}'"),
            FULL.replace("'Disabled'", "ingress"),
            FULL.replace("'fixture'", "''"),
            FULL.replace("'fixture'", "'${setting}'"),
            FULL.replace("type: 'SystemAssigned, UserAssigned'", "type: identityType"),
            FULL.replace("type: 'SystemAssigned, UserAssigned'", "type: 'SystemAssigned, None'"),
            FULL.replace("'" + UAMI + "': {}", "'" + UAMI + "': { unexpected: true }"),
            FULL.replace("userAssignedIdentities: { '" + UAMI + "': {} }", "userAssignedIdentities: null"),
            FULL.replace("properties: { publicNetworkAccess:", "kind: 'functionapp'\n properties: { publicNetworkAccess:"),
            FULL + SITE.replace("resource site ", "resource another "),
            FULL + CHILD.replace("resource settings ", "resource another "),
            FULL.replace("= {", "= if (true) {", 1),
            FULL.replace(" = {", " existing = {", 1),
            FULL.replace("@2024-04-01", "@2023-01-01"),
            COSMOS.replace("'Disabled'", "ingress"),
            COSMOS.replace("enableMultipleWriteLocations: false", "ipRules: [{ ipAddressOrRange: '${ip}' }]"),
            "", "resource broken",
        ):
            with self.subTest(source=source):
                result = self.run_source(source)
                self.assert_blocked(result)
                self.assertIsNone(result["scanner_report"])

    def test_missing_duplicate_unknown_or_corrupt_report_evidence_fails_closed_without_mutation(self):
        result = self.run_source(FULL)
        for damage in (
            "parse", "skip", "duplicate", "lost-parent", "lost-child", "lost-sibling",
            "version", "framework", "resource-count", "summary", "status", "identity",
            "path", "malformed-record", "malformed-result", "missing-list",
        ):
            report = deepcopy(result["scanner_report"])
            if damage == "parse":
                report["results"]["parsing_errors"] = ["fixture.bicep"]
                report["summary"]["parsing_errors"] = 1
            elif damage == "skip":
                report["results"]["skipped_checks"] = [{}]
                report["summary"]["skipped"] = 1
            elif damage == "duplicate":
                report["results"]["passed_checks"] *= 2
                report["summary"]["passed"] *= 2
            elif damage.startswith("lost-"):
                resource = {"lost-parent": PARENT, "lost-child": SETTINGS,
                            "lost-sibling": "Microsoft.Web/sites/config.web"}[damage]
                for key, counter in (("passed_checks", "passed"), ("failed_checks", "failed")):
                    report["results"][key] = [row for row in report["results"][key] if row["resource"] != resource]
                    report["summary"][counter] = len(report["results"][key])
            elif damage == "version":
                report["summary"]["checkov_version"] = "unexpected"
            elif damage == "framework":
                report["check_type"] = "arm"
            elif damage == "resource-count":
                report["summary"]["resource_count"] = len(result["obligations"])
            elif damage == "summary":
                report["summary"]["passed"] = True
            elif damage == "status":
                report["results"]["passed_checks"][0]["check_result"]["result"] = "FAILED"
            elif damage == "identity":
                report["results"]["passed_checks"][0]["resource"] = []
            elif damage == "path":
                report["results"]["passed_checks"][0]["file_path"] = "other.bicep"
            elif damage == "malformed-record":
                report["results"]["passed_checks"][0] = None
            elif damage == "malformed-result":
                report["results"]["passed_checks"][0]["check_result"] = None
            else:
                report["results"].pop("passed_checks")
            before = deepcopy(report)
            with self.subTest(damage=damage):
                _, problems = reconcile(result["obligations"], 4, report)
                self.assertTrue(problems)
                self.assertEqual(report, before)

    def test_empty_duplicate_foreign_obligations_or_malformed_report_never_qualify(self):
        result = self.run_source(FULL)
        for entries in ([], result["obligations"] * 2, [{**result["obligations"][0], "resource": "foreign"}]):
            _, problems = reconcile(entries, 4, result["scanner_report"])
            self.assertTrue(problems)
        for report in (None, {}, {"results": {}, "summary": None}):
            _, problems = reconcile(result["obligations"], 4, report)
            self.assertTrue(problems)

    def test_unqualified_environment_module_or_runtime_digest_block(self):
        for environment, instance in (("", "root"), ("unknown", "root"), ("prod", "module/other")):
            _, _, problems = inventory(FULL, environment, instance)
            self.assertTrue(problems)
        with patch.dict(RULE_SOURCES, {"checkov/arm/checks/resource/AppServiceIdentity.py": "0" * 64}):
            with self.assertRaisesRegex(ValueError, "unexpected installed Checkov resource rule"):
                self.run_source(FULL)

    def test_cli_emits_versioned_inactive_report_with_success_and_blocking_exit(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "fixture.bicep"
            for source, expected in ((FULL, 0), (SITE + CHILD, 1), (COSMOS.replace("'Disabled'", "'Enabled'"), 1)):
                path.write_text(source, encoding="utf-8")
                run = subprocess.run(
                    [sys.executable, str(Path(__file__).with_name("bicep_ingress_candidate.py")),
                     str(path), "--environment", "staging"],
                    text=True, capture_output=True, timeout=90,
                )
                self.assertEqual(run.returncode, expected, run.stderr)
                report = json.loads(run.stdout)
                self.assertFalse(report["production_adoptable"])
                self.assertEqual(report["schema"], "certigo.bicep-appservice-qualification/v2")


FUNCTION_PLAN = """resource plan 'Microsoft.Web/serverfarms@2024-04-01' = {
 name: 'fixture-plan'
 sku: { name: 'FC1' tier: 'FlexConsumption' }
 properties: { reserved: true }
}
"""
# Negative Runner-input harness, not a deployable Function App. The pinned Java
# rule reads the wrong top-level path; explicit outdated versions retain FAILED
# records instead of its disappearing UNKNOWN. Real source is never rewritten.
FUNCTION_RUNNER_SOURCE = MODULE_SOURCE.replace(
    "properties: {\n  publicNetworkAccess",
    "siteConfig: { javaVersion: 'outdated' }\n properties: {\n  publicNetworkAccess",
).replace(
    "siteConfig: { cors:",
    "siteConfig: { phpVersion: 'outdated' pythonVersion: 'outdated' cors:",
) + FUNCTION_PLAN


class FunctionModuleTests(unittest.TestCase):
    def test_bound_snapshot_executes_both_runners_without_suppressing_flex_failures(self):
        events = []
        original_inventory = _function_inventory
        original_run = Runner.run

        def observed_inventory(*args, **kwargs):
            events.append("inventory")
            return original_inventory(*args, **kwargs)

        def observed_run(*args, **kwargs):
            events.append("runner")
            return original_run(*args, **kwargs)

        with module_fixture(app_source=FUNCTION_RUNNER_SOURCE) as root, patch(
            "bicep_ingress_candidate._function_inventory", side_effect=observed_inventory,
        ), patch.object(Runner, "run", side_effect=observed_run, autospec=True):
            before = (root.parent / "modules" / "functionApp.bicep").read_bytes()
            result = qualify_function_snapshot(root, "staging")
            self.assertEqual(before, (root.parent / "modules" / "functionApp.bicep").read_bytes())
        self.assertEqual(events, ["inventory", "runner", "runner"])
        self.assertEqual(result["status"], "BLOCKED")
        self.assertFalse(result["production_adoptable"])
        self.assertEqual(len(result["obligations"]), 49)
        self.assertEqual(len(result["resource_inventory"]), 5)
        self.assertTrue(all(p["matches_bound_ast"] for p in result["resolved_input_provenance"]))
        snapshot = result["resolved_snapshot"]
        self.assertTrue(snapshot["ast_round_trip_verified"])
        self.assertEqual(snapshot["sha256"], hashlib.sha256(snapshot["source_text"].encode()).hexdigest())
        self.assertEqual(len(snapshot["source_map"]), 5)
        self.assertFalse(snapshot["actual_deployment_parameters_verified"])
        for report in (result["authored_report"], result["resolved_report"]):
            self.assertEqual(report["summary"]["resource_count"], 5)
            self.assertEqual(report["summary"]["passed"] + report["summary"]["failed"], 49)
            self.assertIn("CKV_AZURE_225", {r["check_id"] for r in report["results"]["failed_checks"]})
        settings = [row for row in result["resolved_applicability"] if row["resource"] == SETTINGS]
        self.assertEqual({r["check"] for r in settings}, set(FUNCTION_CHECKS["Microsoft.Web/sites/config"]))
        for row in settings:
            if row["check"] in CONFIG_CHECKS:
                self.assertEqual(row["status"], "NOT_APPLICABLE")
                self.assertTrue(all(p["scanner_status"] == "PASSED" for p in row["applicability_evidence"]))

    def test_real_api_inventory_keeps_all_declarations_and_unresolved_inputs_block(self):
        root = Path(__file__).resolve().parents[2] / "infra" / "main.bicep"
        for environment in ("dev", "staging", "prod"):
            binding = resolve_local_module_bindings(root, environment, "api", _function_module=True)
            self.assertTrue(binding["blockers"])
            if version("pycep-parser") != COMPAT_PARSER_VERSION:
                self.assertTrue(any("root source parsing failed" in p for p in binding["blockers"]))
                continue
            entries, count, declared, _, structural, unresolved = _function_inventory(binding)
            self.assertEqual(structural, [])
            self.assertTrue(unresolved)
            self.assertEqual((len(entries), count, len(declared)), (38, 3, 14))
            self.assertEqual(sum(row["existing"] for row in declared), 4)
            self.assertEqual(sum(row["expected"] == "NO_POLICY_IN_PINNED_RUNNER" for row in entries), 7)
            parameters = {p["parameter"]: p for p in binding["parameters"]}
            self.assertEqual(parameters["allowedCorsOrigins"]["value"], ["*"] if environment == "dev" else [])
            self.assertFalse(parameters["entraAuthority"]["resolved"])
            self.assertNotIn("value", parameters["entraAuthority"])
        result = qualify_function_snapshot(root, "staging")
        self.assertEqual(result["status"], "BLOCKED")
        self.assertIsNone(result["resolved_snapshot"])
        self.assertIsNone(result["resolved_report"])
        if version("pycep-parser") == COMPAT_PARSER_VERSION:
            self.assertIsNotNone(result["authored_report"])
            failed = {r["check_id"] for r in result["authored_report"]["results"]["failed_checks"]}
            self.assertTrue({"CKV_AZURE_225", "CKV_AZURE_222"} <= failed)
            self.assertFalse(any("nested modules and outputs" in p for p in result["blockers"]))
            missing = {row["check"] for row in result["authored_applicability"]
                       if row["check"] and row["scanner_status"] is None}
            self.assertEqual(missing, {"CKV_AZURE_81", "CKV_AZURE_82", "CKV_AZURE_83"})

    def test_unknown_in_either_real_runner_never_disappears_into_qualification(self):
        from checkov.arm.checks.resource.AppServicePlanZoneRedundant import check

        original = check.scan_resource_conf
        for unknown_pass in (1, 2):
            calls = []

            def scan(conf):
                calls.append(conf)
                return CheckResult.UNKNOWN if len(calls) == unknown_pass else original(conf)

            with module_fixture(app_source=FUNCTION_RUNNER_SOURCE) as root, patch.object(
                check, "scan_resource_conf", side_effect=scan,
            ):
                result = qualify_function_snapshot(root, "prod")
            self.assertEqual(result["status"], "BLOCKED")
            self.assertTrue(any("obligation" in p for p in result["blockers"]))
            self.assertEqual(len(calls), unknown_pass)
            self.assertEqual(result["resolved_report"] is None, unknown_pass == 1)

    def test_snapshot_round_trip_cannot_lose_a_declared_child(self):
        original = _parse_source

        def lose_child(source):
            tree = original(source)
            if source.startswith("resource "):
                tree["resources"].pop("settings", None)
            return tree

        with module_fixture(app_source=FUNCTION_RUNNER_SOURCE) as root, patch(
            "bicep_ingress_candidate._parse_source", side_effect=lose_child,
        ):
            result = qualify_function_snapshot(root, "staging")
        self.assertIsNotNone(result["authored_report"])
        self.assertIsNone(result["resolved_report"])
        identity = next(row for row in result["authored_applicability"]
                        if row["resource"] == PARENT and row["check"] == "CKV_AZURE_16")
        self.assertEqual(identity["scanner_status"], "PASSED")
        self.assertEqual(identity["status"], "BLOCKED")
        self.assertTrue(all(row["status"] != "NOT_APPLICABLE"
                            for row in result["authored_applicability"] if row["resource"] == SETTINGS))
        self.assertTrue(any("exactly reproduce" in p for p in result["blockers"]))

    def test_structural_drift_is_blocked_before_authored_runner(self):
        for damage in ("parent", "unknown", "condition", "api", "existing", "duplicate", "output"):
            source = MODULE_SOURCE + FUNCTION_PLAN
            if damage == "parent":
                source = source.replace("parent: site", "parent: missing")
            elif damage == "unknown":
                source += "resource other 'Unknown/type@2024-01-01' = { name: 'other' }\n"
            elif damage == "condition":
                source = source.replace("'Microsoft.Web/serverfarms@2024-04-01' = {",
                                        "'Microsoft.Web/serverfarms@2024-04-01' = if (true) {")
            elif damage == "api":
                source = source.replace("serverfarms@2024-04-01", "serverfarms@2023-01-01")
            elif damage == "existing":
                source += "resource other 'Microsoft.Storage/storageAccounts@2024-01-01' existing = { name: 'x' properties: {} }\n"
            elif damage == "duplicate":
                source += CHILD.replace("resource settings", "resource duplicate")
            else:
                source += "output functionAppName string = 'functionApp.name'\n"
            with self.subTest(damage=damage), module_fixture(app_source=source) as root, patch(
                "bicep_ingress_candidate.Runner.run",
            ) as runner:
                result = qualify_function_snapshot(root, "prod")
                self.assertEqual(result["status"], "BLOCKED")
                self.assertIsNone(result["authored_report"])
                runner.assert_not_called()

    def test_secret_or_dynamic_inputs_do_not_get_materialized_by_opt_in(self):
        for declaration in ("@secure()\nparam extra string = 'sentinel-not-a-secret'",
                            "param extra string = uniqueString('unknown')"):
            source = declaration + "\n" + MODULE_SOURCE + FUNCTION_PLAN
            with module_fixture(app_source=source) as root:
                result = qualify_function_snapshot(root, "prod")
            self.assertEqual(result["status"], "BLOCKED")
            self.assertIsNotNone(result["authored_report"])
            self.assertIsNone(result["resolved_snapshot"])
            self.assertNotIn("sentinel-not-a-secret", json.dumps(result))

    def test_dispatch_and_rule_source_drift_cannot_claim_no_policy_or_complete_coverage(self):
        from checkov.bicep.checks.resource.registry import registry

        original = registry.get_checks
        for kind in ("Microsoft.Web/sites", "Microsoft.Authorization/roleAssignments"):
            fake = type("NewCheck", (), {"id": "UNQUALIFIED"})()
            with patch.object(registry, "get_checks", side_effect=lambda k: [
                *original(k), *([fake] if k == kind else []),
            ]):
                with self.assertRaisesRegex(ValueError, "unqualified Function App policy dispatch"):
                    _verify_function_dispatch()
        with patch.dict(FUNCTION_RULE_SOURCES, {"AppServicePlanZoneRedundant": "0" * 64}):
            with self.assertRaisesRegex(ValueError, "unexpected installed Function App rule"):
                _verify_function_dispatch()
        from types import SimpleNamespace

        wildcard = SimpleNamespace(resource_types=["Microsoft.Web/*"], connected_resources_types=[], sub_checks=[])
        with patch.object(registry.graph_registry, "checks", [*registry.graph_registry.checks, wildcard]):
            with self.assertRaisesRegex(ValueError, "unqualified Function App policy dispatch"):
                _verify_function_dispatch()

    def test_default_api_uses_function_inventory_and_cli_rejects_wrong_snapshot_scope(self):
        with module_fixture(app_source=MODULE_SOURCE + FUNCTION_PLAN) as root:
            result = qualify_local_module(root, "dev")
            self.assertEqual(result["schema"], "certigo.bicep-function-module-qualification/v6")
            self.assertIsNotNone(result["authored_report"])
            self.assertIsNone(result["resolved_report"])
            for flags in (["--module-symbol", "data"], ["--module-symbol", "api", "--resolved-cosmos-snapshot"],
                          ["--module-symbol", "api", "--cosmos-backup-mode", "Periodic"]):
                run = subprocess.run(
                    [sys.executable, str(Path(__file__).with_name("bicep_ingress_candidate.py")),
                     str(root), "--environment", "dev", "--resolved-function-snapshot", *flags],
                    text=True, capture_output=True, timeout=90,
                )
                self.assertEqual(run.returncode, 2, run.stderr)

    def test_complete_literal_snapshot_is_deterministic_but_never_a_flex_exemption(self):
        with module_fixture(app_source=FUNCTION_RUNNER_SOURCE) as root:
            first = qualify_function_snapshot(root, "staging")
            second = qualify_function_snapshot(root, "prod")
        self.assertEqual(first["resolved_snapshot"], second["resolved_snapshot"])
        for result in (first, second):
            self.assertEqual(result["status"], "BLOCKED")
            failed = {row["check_id"] for row in result["resolved_report"]["results"]["failed_checks"]}
            self.assertTrue({"CKV_AZURE_81", "CKV_AZURE_82", "CKV_AZURE_83", "CKV_AZURE_225"} <= failed)


if __name__ == "__main__":
    unittest.main(verbosity=2)
