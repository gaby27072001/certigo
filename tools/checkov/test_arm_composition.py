"""Qualify the existing candidate with ARM Runner, not a second policy engine."""

from copy import deepcopy
import hashlib
from importlib.metadata import version
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import checkov.arm
from checkov.arm.checks.resource.AppServiceIdentity import check as identity_check
from checkov.arm.runner import Runner
from checkov.runner_filter import RunnerFilter

from build_checkov_wheel import RULE_FIXES, VERSION


CONFIG_CHECKS = {"CKV_AZURE_" + number for number in ("88", "222", "63", "66", "80", "13")}
UAMI = (
    "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/fixture"
    "/providers/Microsoft.ManagedIdentity/userAssignedIdentities/reader"
)
SUBNET = (
    "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/fixture"
    "/providers/Microsoft.Network/virtualNetworks/fixture/subnets/private"
)


def resource(kind, name, properties, **extra):
    return dict(type=kind, apiVersion="2024-04-01", name=name, properties=properties, **extra)


def site(identity):
    return resource("Microsoft.Web/sites", "example", {}, identity=identity)


def config(name, properties):
    return resource("Microsoft.Web/sites/config", "example/" + name, properties)


def template(resources):
    return {
        "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
        "contentVersion": "1.0.0.0",
        "resources": resources,
    }


def run_fixture(document, checks):
    with tempfile.TemporaryDirectory(prefix="certigo-arm-composition-") as temporary:
        path = Path(temporary) / "fixture.json"
        path.write_text(json.dumps(document), encoding="utf-8")
        report = Runner().run(
            root_folder=temporary, files=[str(path)],
            runner_filter=RunnerFilter(checks=sorted(checks), show_progress_bar=False),
        )
    return report


def records(report):
    result = {}
    for group, status in ((report.passed_checks, "PASSED"), (report.failed_checks, "FAILED")):
        for entry in group:
            if entry.check_result["result"].value != status:
                raise ValueError("inconsistent record status")
            result.setdefault(entry.check_id, []).append(status)
    return {key: sorted(value) for key, value in result.items()}


def require_fixture_coverage(report, expected):
    """Require exact obligations for one fixture, not a production inventory."""
    if not expected or len(expected) != len(set(expected)):
        raise ValueError("empty or duplicate fixture obligations")
    if report.parsing_errors or report.skipped_checks:
        raise ValueError("parsing or skipped coverage")
    actual = {}
    paths = set()
    for group, status in ((report.passed_checks, "PASSED"), (report.failed_checks, "FAILED")):
        for entry in group:
            key = (entry.resource, entry.check_id)
            if key in actual:
                raise ValueError("duplicate resource/check evidence")
            if entry.check_result["result"].value != status:
                raise ValueError("inconsistent record status")
            actual[key] = status
            paths.add(entry.file_path)
    if len(paths) != 1:
        raise ValueError("expected one fixture with executed checks")
    if set(actual) != set(expected):
        raise ValueError("missing or unexpected resource/check evidence")
    # FAILED is coverage evidence, never a successful security verdict.
    return actual


def cases():
    for label, identity, status in (
        ("system", {"type": "SystemAssigned"}, "PASSED"),
        ("user", {"type": "UserAssigned", "userAssignedIdentities": {"/identities/example": {}}}, "FAILED"),
        ("mixed", {"type": "SystemAssigned, UserAssigned",
                   "userAssignedIdentities": {"/identities/example": {}}}, "PASSED"),
        ("none", {"type": "None"}, "FAILED"),
        ("empty-user", {"type": "UserAssigned", "userAssignedIdentities": {}}, "FAILED"),
    ):
        yield "identity-" + label, [site(identity)], {"CKV_AZURE_16"}, {"CKV_AZURE_16": [status]}
    for label, props, status in (
        ("private", {"publicNetworkAccess": "Disabled"}, "PASSED"),
        ("filtered", {"isVirtualNetworkFilterEnabled": True,
                      "virtualNetworkRules": [{"id": "/subnets/example"}]}, "FAILED"),
        ("public", {"publicNetworkAccess": "Enabled"}, "FAILED"),
        ("public-multiwrite-false", {"publicNetworkAccess": "Enabled",
                                    "enableMultipleWriteLocations": False}, "FAILED"),
    ):
        yield "cosmos-" + label, [
            resource("Microsoft.DocumentDB/databaseAccounts", "example", props)
        ], {"CKV_AZURE_99"}, {"CKV_AZURE_99": [status]}
    yield "appsettings", [config("appsettings", {"EXAMPLE": "value"})], CONFIG_CHECKS, {
        key: ["FAILED"] for key in CONFIG_CHECKS
    }
    for enabled in (True, False):
        yield "auth-" + str(enabled).lower(), [config("authsettings", {"enabled": enabled})], {
            "CKV_AZURE_13"
        }, {"CKV_AZURE_13": ["PASSED" if enabled else "FAILED"]}
    yield "auth-parent-child", [
        config("authsettings", {"enabled": True}), config("appsettings", {"EXAMPLE": "value"})
    ], {"CKV_AZURE_13"}, {"CKV_AZURE_13": ["FAILED", "PASSED"]}
    for secure in (True, False):
        checks = CONFIG_CHECKS - {"CKV_AZURE_13"}
        yield "web-config-" + str(secure).lower(), [config("web", {
            "azureStorageAccounts": {"example": {"type": "AzureFiles" if secure else "AzureBlob"}},
            "publicNetworkAccess": "Disabled" if secure else "Enabled",
            "httpLoggingEnabled": secure,
            "requestTracingEnabled": secure,
            "netFrameworkVersion": "v8.0" if secure else "v4.0",
        })], checks, {key: ["PASSED" if secure else "FAILED"] for key in checks}
    yield "network-parent-child", [
        resource("Microsoft.Web/sites", "example", {"publicNetworkAccess": "Disabled"}),
        config("appsettings", {"EXAMPLE": "value"}),
    ], {"CKV_AZURE_222"}, {"CKV_AZURE_222": ["FAILED", "PASSED"]}
    yield "unresolved-network", [
        resource("Microsoft.Web/sites", "example", {"publicNetworkAccess": "[parameters('ingress')]"})
    ], {"CKV_AZURE_222"}, {"CKV_AZURE_222": ["FAILED"]}
    yield "empty-template", [], {"CKV_AZURE_222"}, {}


class CompositionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if version("checkov") != VERSION:
            raise ValueError("composition tests require the existing pinned candidate")
        root = Path(checkov.arm.__file__).resolve().parents[1]
        for relative, _, _, expected in RULE_FIXES.values():
            if hashlib.sha256((root / Path(relative).relative_to("checkov")).read_bytes()).hexdigest() != expected:
                raise ValueError("candidate predicate source mismatch")

    def test_eighteen_original_shapes_with_corrected_candidate_expectations(self):
        fixtures = list(cases())
        self.assertEqual(len(fixtures), 18)
        for name, resources, checks, expected in fixtures:
            with self.subTest(case=name):
                document = template(resources)
                original = deepcopy(document)
                report = run_fixture(document, checks)
                self.assertFalse(report.parsing_errors)
                self.assertFalse(report.skipped_checks)
                self.assertEqual(records(report), expected)
                self.assertEqual(document, original)
                if name == "empty-template":
                    self.assertFalse(report.passed_checks or report.failed_checks)
                else:
                    self.assertTrue(report.passed_checks or report.failed_checks)

    def test_literal_qualified_user_and_subnet_positive_controls(self):
        for resources, check in (
            ([site({"type": "UserAssigned", "userAssignedIdentities": {UAMI: {}}})], "CKV_AZURE_16"),
            ([resource("Microsoft.DocumentDB/databaseAccounts", "example", {
                "isVirtualNetworkFilterEnabled": True,
                "virtualNetworkRules": [{"id": SUBNET}],
            })], "CKV_AZURE_99"),
        ):
            with self.subTest(check=check):
                report = run_fixture(template(resources), {check})
                self.assertFalse(report.parsing_errors or report.skipped_checks)
                self.assertEqual(records(report), {check: ["PASSED"]})
                self.assertEqual(require_fixture_coverage(report, [
                    (resources[0]["type"] + "." + resources[0]["name"], check)
                ]), {(resources[0]["type"] + "." + resources[0]["name"], check): "PASSED"})

    def test_arm_loader_adds_only_line_markers_to_empty_identity_configuration(self):
        captured = []
        original = identity_check.scan_resource_conf

        def inspect(conf):
            captured.append(deepcopy(conf))
            before = deepcopy(conf)
            result = original(conf)
            self.assertEqual(conf, before)
            return result

        with patch.object(identity_check, "scan_resource_conf", side_effect=inspect):
            report = run_fixture(template([
                site({"type": "UserAssigned", "userAssignedIdentities": {UAMI: {}}})
            ]), {"CKV_AZURE_16"})
        self.assertEqual(records(report), {"CKV_AZURE_16": ["PASSED"]})
        self.assertEqual(len(captured), 1)
        conf = captured[0]
        assignments = conf["identity"]["userAssignedIdentities"]
        fields = {"__startline__", "__endline__"}
        self.assertEqual(set(assignments), {UAMI} | fields)
        self.assertEqual(set(assignments[UAMI]), fields)
        for mapping in (assignments, assignments[UAMI]):
            self.assertIs(type(mapping["__startline__"]), int)
            self.assertIs(type(mapping["__endline__"]), int)
            self.assertLessEqual(conf["__startline__"], mapping["__startline__"])
            self.assertLessEqual(mapping["__startline__"], mapping["__endline__"])
            self.assertLessEqual(mapping["__endline__"], conf["__endline__"])

    def test_real_arm_empty_unknown_and_malformed_assignments_remain_failed(self):
        for assignments in (
            {}, None, [], {"": {}}, {"${reader.id}": {}}, {"/identities/example": {}},
            {UAMI: {"unexpected": True}}, {UAMI: {"__file__": "not-allowed"}},
            {UAMI: None}, {UAMI: []}, {UAMI: "[parameters('configuration')]"},
        ):
            with self.subTest(assignments=assignments):
                report = run_fixture(template([
                    site({"type": "UserAssigned", "userAssignedIdentities": assignments})
                ]), {"CKV_AZURE_16"})
                self.assertFalse(report.parsing_errors or report.skipped_checks)
                self.assertEqual(records(report), {"CKV_AZURE_16": ["FAILED"]})

    def test_real_arm_malformed_and_unresolved_identity_types_remain_failed(self):
        for kind in (None, "", "Unknown", "SystemAssigned, None",
                     "SystemAssigned,SystemAssigned", "[parameters('identityType')]"):
            with self.subTest(kind=kind):
                report = run_fixture(template([
                    site({"type": kind, "userAssignedIdentities": {UAMI: {}}})
                ]), {"CKV_AZURE_16"})
                self.assertFalse(report.parsing_errors or report.skipped_checks)
                self.assertEqual(records(report), {"CKV_AZURE_16": ["FAILED"]})

    def test_nested_short_type_child_disappears_despite_success_and_two_resources(self):
        parent = resource("Microsoft.Web/sites", "example", {"publicNetworkAccess": "Disabled"})
        parent["resources"] = [resource("config", "appsettings", {"EXAMPLE": "value"})]
        report = run_fixture(template([parent]), {"CKV_AZURE_13", "CKV_AZURE_222"})
        self.assertFalse(report.parsing_errors or report.skipped_checks or report.failed_checks)
        self.assertEqual(len(report.resources), 2)
        self.assertEqual(records(report), {"CKV_AZURE_222": ["PASSED"]})
        with self.assertRaisesRegex(ValueError, "missing or unexpected"):
            require_fixture_coverage(report, [
                ("Microsoft.Web/sites.example", "CKV_AZURE_222"),
                ("config.appsettings", "CKV_AZURE_13"),
            ])

    def test_unknown_check_with_other_success_cannot_meet_exact_obligations(self):
        from checkov.arm.checks.resource.AppServicePublicAccessDisabled import check as ingress
        from checkov.common.models.enums import CheckResult

        document = template([resource(
            "Microsoft.Web/sites", "example", {"publicNetworkAccess": "Disabled"},
            identity={"type": "SystemAssigned"},
        )])
        obligations = [
            ("Microsoft.Web/sites.example", "CKV_AZURE_16"),
            ("Microsoft.Web/sites.example", "CKV_AZURE_222"),
        ]
        complete = run_fixture(document, {"CKV_AZURE_16", "CKV_AZURE_222"})
        self.assertEqual(set(require_fixture_coverage(complete, obligations).values()), {"PASSED"})
        with patch.object(ingress, "scan_resource_conf", return_value=CheckResult.UNKNOWN):
            missing = run_fixture(document, {"CKV_AZURE_16", "CKV_AZURE_222"})
        self.assertEqual(len(missing.passed_checks), 1)
        self.assertFalse(missing.failed_checks or missing.parsing_errors or missing.skipped_checks)
        with self.assertRaisesRegex(ValueError, "missing or unexpected"):
            require_fixture_coverage(missing, obligations)

    def test_failed_parent_and_all_six_child_failures_remain_coverage_not_success(self):
        report = run_fixture(template([
            resource("Microsoft.Web/sites", "example", {"publicNetworkAccess": "Enabled"}),
            config("appsettings", {"EXAMPLE": "value"}),
        ]), CONFIG_CHECKS)
        obligations = [
            ("Microsoft.Web/sites.example", "CKV_AZURE_222"),
            *(("Microsoft.Web/sites/config.example/appsettings", check) for check in sorted(CONFIG_CHECKS)),
        ]
        result = require_fixture_coverage(report, obligations)
        self.assertEqual(len(result), 7)
        self.assertEqual(set(result.values()), {"FAILED"})
        self.assertEqual(len(report.failed_checks), 7)

    def test_exact_fixture_obligations_reject_empty_duplicate_skip_parse_and_foreign(self):
        report = run_fixture(template([
            resource("Microsoft.Web/sites", "example", {"publicNetworkAccess": "Disabled"})
        ]), {"CKV_AZURE_222"})
        obligations = [("Microsoft.Web/sites.example", "CKV_AZURE_222")]
        for expected in ([], obligations * 2, [("foreign", "CKV_AZURE_222")]):
            with self.subTest(expected=expected), self.assertRaises(ValueError):
                require_fixture_coverage(report, expected)
        for mutation in ("parsing", "skipped", "duplicate", "status"):
            changed = deepcopy(report)
            if mutation == "parsing":
                changed.parsing_errors.append("fixture.json")
            elif mutation == "skipped":
                changed.skipped_checks.append(deepcopy(changed.passed_checks[0]))
            elif mutation == "duplicate":
                changed.passed_checks.append(deepcopy(changed.passed_checks[0]))
            else:
                changed.failed_checks = changed.passed_checks
                changed.passed_checks = []
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                require_fixture_coverage(changed, obligations)
        empty = run_fixture(template([]), {"CKV_AZURE_222"})
        with self.assertRaises(ValueError):
            require_fixture_coverage(empty, obligations)


if __name__ == "__main__":
    unittest.main(verbosity=2)
