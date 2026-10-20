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
    CONFIG_CHECKS, RULE_SOURCES, UPSTREAM_PARSER_SOURCES,
    _verify_parser, inventory, qualify, qualify_local_module, qualify_local_modules,
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
 properties: {
  publicNetworkAccess: 'Disabled'
  enableMultipleWriteLocations: false
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
        self.assertEqual(len(secure["obligations"]), 1)
        self.assertEqual(secure["obligations"][0]["check"], "CKV_AZURE_99")
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
        self.assertEqual(len(combined["obligations"]), 21)

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
            self.assertEqual(len(result["modules"][1]["obligations"]), 1)
            self.assertEqual(result["modules"][1]["binding_resolution"]["module_name"], "cosmos-staging")
            self.assertEqual(result["provenance"]["root_sha256"], hashlib.sha256(root.read_bytes()).hexdigest())

    def test_all_selected_module_inventories_exist_before_first_runner(self):
        import bicep_ingress_candidate as candidate

        events = []
        original_inventory = candidate.inventory
        original_run = candidate.Runner.run

        def observed_inventory(*args, **kwargs):
            events.append("inventory")
            return original_inventory(*args, **kwargs)

        def observed_run(*args, **kwargs):
            events.append("runner")
            return original_run(*args, **kwargs)

        with module_fixture() as root, patch.object(
            candidate, "inventory", side_effect=observed_inventory
        ), patch.object(candidate.Runner, "run", side_effect=observed_run, autospec=True):
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
                    self.assertEqual(len(failed["scanner_report"]["results"]["failed_checks"]), 1)
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
        import bicep_ingress_candidate as candidate

        source = MODULE_ROOT.replace(" ? [ '*' ] : []", "\n  ? [ '*' ]\n  : []")
        options = (
            {"side_effect": AssertionError("compatibility parser must not normalize source")}
            if version("pycep-parser") == COMPAT_PARSER_VERSION
            else {"wraps": candidate._parser_source}
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


if __name__ == "__main__":
    unittest.main(verbosity=2)
