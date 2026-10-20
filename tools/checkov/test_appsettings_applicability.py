"""Qualify the blocked subtype/report contract without changing scanner behavior."""

from contextlib import ExitStack
from copy import deepcopy
import hashlib
from importlib import import_module
from importlib.metadata import version
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import checkov.arm
from checkov.bicep.checks.resource.registry import registry
from checkov.bicep.runner import Runner
from checkov.common.models.enums import CheckResult
from checkov.runner_filter import RunnerFilter
from pycep import BicepParser

from build_checkov_wheel import VERSION


RULES = (
    ("AppServiceAuthentication", "af80cdbff008b91ae1c051dbaec6eaa3801deb3f20217d3c6fb49d32404c86bb"),
    ("AppServiceDotnetFrameworkVersion", "9725066ac8de44b476dea83cacdedb1588881e629cbe62f19c85860adeefdaa2"),
    ("AppServiceEnableFailedRequest", "e84a6a67111f1bd450221688a4ef74f97f608d53e189d435c204ab81ede53849"),
    ("AppServiceHttpLoggingEnabled", "e4121eed5a46c54078f0299091bd2baa9bc71f208be6437c88be523f7729e5af"),
    ("AppServicePublicAccessDisabled", "e618b4d8ee177117986c07f4a9b0f96d1b122dfe0fe89d88103db9d3f930c431"),
    ("AppServiceUsedAzureFiles", "1e9c1452bed550c63b48a973abe164b9d011b9de102ce652c09b6a7f450f1b48"),
)
CHECKS = tuple(import_module("checkov.arm.checks.resource." + name).check for name, _ in RULES)
IDS = {check.id for check in CHECKS}
CHILD = "Microsoft.Web/sites/config.settings"
PARENT = "Microsoft.Web/sites.site"


def child(name="'appsettings'", properties="{}", parent=""):
    return (
        "resource settings 'Microsoft.Web/sites/config@2024-04-01' = {\n"
        f" name: {name}\n{parent} properties: {properties}\n"
        "}\n"
    )


def run_fixture(source, ids=IDS):
    with tempfile.TemporaryDirectory() as temporary:
        path = Path(temporary) / "fixture.bicep"
        path.write_text(source, encoding="utf-8")
        report = Runner().run(
            root_folder=temporary, files=[str(path)],
            runner_filter=RunnerFilter(checks=sorted(ids), show_progress_bar=False),
        )
    return report


class ApplicabilityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if version("checkov") != VERSION:
            raise ValueError("Qualification requires the pinned candidate wheel")
        root = Path(checkov.arm.__file__).parent / "checks" / "resource"
        for name, digest in RULES:
            if hashlib.sha256((root / (name + ".py")).read_bytes()).hexdigest() != digest:
                raise ValueError(f"Qualification requires unchanged upstream rule: {name}")

    def assert_retained(self, report, expected):
        self.assertFalse(report.parsing_errors)
        self.assertFalse(report.skipped_checks)
        records = report.passed_checks + report.failed_checks
        actual = {(record.resource, record.check_id): record.check_result["result"] for record in records}
        self.assertEqual(len(records), len(actual))
        self.assertEqual(actual, expected)

    def test_appsettings_and_unresolved_subtypes_keep_six_failures(self):
        for name in ("'appsettings'", "'site/appsettings'", "subtype"):
            report = run_fixture("param subtype string\n" + child(name))
            self.assert_retained(report, {(CHILD, id): CheckResult.FAILED for id in IDS})

    def test_parent_secure_insecure_unknown_or_absent_does_not_certify_child(self):
        for value, expected in (("'Disabled'", CheckResult.PASSED), ("'Enabled'", CheckResult.FAILED),
                                ("publicAccess", CheckResult.FAILED), (None, None)):
            source = "param publicAccess string\n"
            link = ""
            if value is not None:
                source += (
                    "resource site 'Microsoft.Web/sites@2024-04-01' = {\n"
                    f" name: 'fixture'\n properties: {{ publicNetworkAccess: {value} }}\n"
                    "}\n"
                )
                link = " parent: site\n"
            report = run_fixture(source + child(parent=link))
            records = {(CHILD, id): CheckResult.FAILED for id in IDS}
            if expected is not None:
                records[(PARENT, "CKV_AZURE_222")] = expected
            self.assert_retained(report, records)

    def test_synthetic_subtype_property_controls_keep_secure_insecure_unknown_records(self):
        cases = (
            ("CKV_AZURE_13", "'authsettings'", "enabled", "true", "false", "param setting bool\n"),
            ("CKV_AZURE_80", "'web'", "netFrameworkVersion", "'v8.0'", "'v4.0'", "param setting string\n"),
            ("CKV_AZURE_66", "'web'", "requestTracingEnabled", "true", "false", "param setting bool\n"),
            ("CKV_AZURE_63", "'web'", "httpLoggingEnabled", "true", "false", "param setting bool\n"),
            ("CKV_AZURE_222", "'web'", "publicNetworkAccess", "'Disabled'", "'Enabled'", "param setting string\n"),
            ("CKV_AZURE_88", "'web'", "azureStorageAccounts", "{ mount: { type: 'AzureFiles' } }",
             "{ mount: { type: 'AzureBlob' } }", "param setting object\n"),
        )
        for id, name, key, secure, insecure, parameter in cases:
            for value, expected in ((secure, CheckResult.PASSED), (insecure, CheckResult.FAILED),
                                    ("setting", CheckResult.FAILED)):
                with self.subTest(id=id, value=value):
                    report = run_fixture(parameter + child(name, "{ " + key + ": " + value + " }"), {id})
                    self.assert_retained(report, {(CHILD, id): expected})

    def test_injected_web_property_shapes_can_spoof_five_checks_without_subtype_proof(self):
        properties = (
            "{ netFrameworkVersion: 'v8.0'\n requestTracingEnabled: true\n"
            " httpLoggingEnabled: true\n publicNetworkAccess: 'Disabled'\n"
            " azureStorageAccounts: { mount: { type: 'AzureFiles' } }\n }"
        )
        report = run_fixture(child(properties=properties))
        self.assert_retained(report, {
            (CHILD, id): CheckResult.FAILED if id == "CKV_AZURE_13" else CheckResult.PASSED for id in IDS
        })

    def test_string_dictionary_names_are_not_parent_configuration_proof(self):
        report = run_fixture(child(properties=(
            "{ netFrameworkVersion: 'v8.0'\n requestTracingEnabled: 'true'\n"
            " httpLoggingEnabled: 'true'\n publicNetworkAccess: 'Disabled'\n }"
        )))
        self.assert_retained(report, {
            (CHILD, id): CheckResult.PASSED if id in {"CKV_AZURE_80", "CKV_AZURE_222"}
            else CheckResult.FAILED for id in IDS
        })

    def test_unknown_workaround_loses_all_six_records_without_parse_error(self):
        with ExitStack() as stack:
            for check in CHECKS:
                stack.enter_context(patch.object(check, "scan_resource_conf", return_value=CheckResult.UNKNOWN))
            report = run_fixture(child())
        self.assert_retained(report, {})
        self.assertEqual(len(report.resources), 1)
        self.assertEqual(report.get_summary()["failed"], 0)
        self.assertEqual(report.get_summary()["passed"], 0)
        self.assertNotIn("NOT_APPLICABLE", {result.value for result in CheckResult})

    def test_existing_auth_rule_already_loses_nested_short_type_appsettings(self):
        check = next(check for check in CHECKS if check.id == "CKV_AZURE_13")
        self.assertEqual(
            check.scan_entity_conf({"name": "appsettings", "parent_type": "Microsoft.Web/sites"}, "config"),
            CheckResult.UNKNOWN,
        )

    def test_authored_appsettings_ast_keeps_each_failure_and_has_no_parent_configuration(self):
        root = Path(__file__).resolve().parents[2]
        resources = BicepParser().parse(file_path=root / "infra" / "modules" / "functionApp.bicep")["resources"]
        children = [conf for conf in resources.values()
                    if conf["type"] == "Microsoft.Web/sites/config" and conf["config"].get("name") == "appsettings"]
        self.assertEqual(len(children), 1)
        conf = children[0]
        original = deepcopy(conf)
        _, _, extracted = registry.extract_entity_details({"settings": conf})
        self.assertIs(extracted, conf)
        self.assertNotIn("publicNetworkAccess", extracted["config"].get("properties", {}))
        for check in CHECKS:
            self.assertEqual(check.scan_entity_conf(conf, conf["type"]), CheckResult.FAILED)
        self.assertEqual(conf, original)


if __name__ == "__main__":
    unittest.main(verbosity=2)
