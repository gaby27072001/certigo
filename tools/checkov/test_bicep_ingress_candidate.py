"""Real Bicep qualification controls, without scanning infra or adopting a gate."""

from copy import deepcopy
import hashlib
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
    CONFIG_CHECKS, RULE_SOURCES, inventory, qualify, reconcile,
)


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
        unsafe = self.run_source(COSMOS.replace("'Disabled'", "'Enabled'"))
        self.assert_blocked(unsafe)
        self.assertEqual(unsafe["applicability"][0]["status"], "FAILED")
        combined = self.run_source(FULL + COSMOS)
        self.assertEqual(combined["status"], "QUALIFIED_SUBSET", combined["blockers"])
        self.assertEqual(len(combined["obligations"]), 21)

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
