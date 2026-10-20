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


if __name__ == "__main__":
    unittest.main(verbosity=2)
