"""Paired pinned-rule controls; no deployment, expression evaluator or full scan."""

from copy import deepcopy
from importlib.metadata import version
import hashlib
from pathlib import Path
import tempfile
import unittest

import checkov.arm
from checkov.arm.checks.resource.AppServiceIdentity import check as identity
from checkov.arm.checks.resource.CosmosDBAccountsRestrictedAccess import check as cosmos
from checkov.bicep.runner import Runner
from checkov.common.models.enums import CheckResult
from checkov.runner_filter import RunnerFilter
from pycep import BicepParser
from pycep.transformer import BicepElement

from build_checkov_wheel import RULE_FIXES, VERSION


ROOT = Path(__file__).resolve().parents[2]
SUBSCRIPTION = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/fixture"
UAMI = SUBSCRIPTION + "/providers/Microsoft.ManagedIdentity/userAssignedIdentities/reader"
SUBNET = SUBSCRIPTION + "/providers/Microsoft.Network/virtualNetworks/test/subnets/private"


def run_fixture(source, check):
    with tempfile.TemporaryDirectory() as temporary:
        path = Path(temporary) / "fixture.bicep"
        path.write_text(source, encoding="utf-8")
        report = Runner().run(
            root_folder=temporary, files=[str(path)],
            runner_filter=RunnerFilter(checks=[check.id], show_progress_bar=False),
        )
    return report


class RuleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if version("checkov") != VERSION:
            raise ValueError("Tests require the pinned resource-rule wheel")
        root = Path(checkov.arm.__file__).resolve().parents[1]
        for relative, _, _, digest in RULE_FIXES.values():
            path = root / Path(relative).relative_to("checkov")
            if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
                raise ValueError(f"Unexpected installed rule source: {relative}")

    def test_literal_system_and_combined_identities_pass(self):
        for kind in ("SystemAssigned", "SystemAssigned, UserAssigned", "UserAssigned,SystemAssigned"):
            for assignments in ({}, {"function": {"type": "union"}}, None):
                conf = {"identity": {"type": kind, "userAssignedIdentities": assignments}}
                self.assertEqual(identity.scan_resource_conf(conf), CheckResult.PASSED)

    def test_user_identity_requires_known_nonempty_assignments(self):
        self.assertEqual(
            identity.scan_resource_conf({"identity": {"type": "UserAssigned", "userAssignedIdentities": {UAMI: {}}}}),
            CheckResult.PASSED,
        )
        for assignments in ({}, None, [], {"function": {"type": "union"}}, {"": {}},
                            {"${reader.id}": {}}, {BicepElement(UAMI): {}},
                            {UAMI: {"function": {"type": "unknown"}}}):
            with self.subTest(assignments=assignments):
                self.assertEqual(
                    identity.scan_resource_conf({"identity": {"type": "UserAssigned", "userAssignedIdentities": assignments}}),
                    CheckResult.FAILED,
                )

    def test_missing_none_malformed_or_symbolic_identity_types_fail(self):
        for kind in (None, "None", "", "Unknown", "SystemAssigned, None", "SystemAssigned,SystemAssigned",
                     {"function": {"type": "unknown"}}, BicepElement("SystemAssigned")):
            self.assertEqual(identity.scan_resource_conf({"identity": {"type": kind}}), CheckResult.FAILED)
        for conf in ({}, {"identity": None}, {"identity": "SystemAssigned"}):
            self.assertEqual(identity.scan_resource_conf(conf), CheckResult.FAILED)

    def test_cosmos_disabled_literal_proves_public_endpoint_closed(self):
        for multiple in (True, False, None):
            conf = {"properties": {"publicNetworkAccess": "Disabled", "enableMultipleWriteLocations": multiple}}
            self.assertEqual(cosmos.scan_resource_conf(conf), CheckResult.PASSED)

    def test_cosmos_unrestricted_and_unknown_values_fail(self):
        for value in ("Enabled", BicepElement("Disabled"), {"function": {"type": "unknown"}}, "unknown", None):
            for multiple in (True, False):
                conf = {"properties": {"publicNetworkAccess": value, "enableMultipleWriteLocations": multiple}}
                with self.subTest(value=value, multiple=multiple):
                    self.assertEqual(cosmos.scan_resource_conf(conf), CheckResult.FAILED)
        for conf in ({}, {"properties": None}, {"properties": {}}, {"properties": {"enableMultipleWriteLocations": False}}):
            self.assertEqual(cosmos.scan_resource_conf(conf), CheckResult.FAILED)

    def test_bounded_vnet_or_ip_rules_preserve_restricted_configuration(self):
        for rules in ({"virtualNetworkRules": [{"id": SUBNET}]},
                      {"ipRules": [{"ipAddressOrRange": "203.0.113.42"}]},
                      {"ipRules": [{"ipAddressOrRange": "203.0.113.0/24"}]}):
            for write_options in ({}, {"enableMultipleWriteLocations": True}, {"enableMultipleWriteLocations": False}):
                conf = {"properties": {"publicNetworkAccess": "Enabled", "isVirtualNetworkFilterEnabled": True,
                                       **rules, **write_options}}
                self.assertEqual(cosmos.scan_resource_conf(conf), CheckResult.PASSED)
            for flag in (False, None, "true", 1, BicepElement("true"), {"function": {"type": "unknown"}}):
                conf = {"properties": {"publicNetworkAccess": "Enabled", "isVirtualNetworkFilterEnabled": flag, **rules}}
                self.assertEqual(cosmos.scan_resource_conf(conf), CheckResult.FAILED)

    def test_all_ips_azure_services_unknown_and_malformed_network_rules_fail(self):
        cases = (
            {"ipRules": [{"ipAddressOrRange": value}]}
            for value in ("0.0.0.0", "0.0.0.0/0", "0.0.0.0/1", "128.0.0.0/1", "::/0",
                          "not-an-IP", BicepElement("203.0.113.42"), {"function": {"type": "unknown"}})
        )
        others = (
            {"virtualNetworkRules": [{"id": "${subnet.id}"}]},
            {"virtualNetworkRules": {"function": {"type": "map"}}},
            {"virtualNetworkRules": [{"id": BicepElement(SUBNET)}]},
            {"virtualNetworkRules": [{"id": SUBNET}], "ipRules": [{"ipAddressOrRange": "0.0.0.0"}]},
            {"ipRules": [{"ipAddressOrRange": "203.0.113.42"}], "virtualNetworkRules": {"function": {}}},
            {"ipRules": []},
        )
        for rules in (*cases, *others):
            conf = {"properties": {"publicNetworkAccess": "Enabled", "isVirtualNetworkFilterEnabled": True, **rules}}
            self.assertEqual(cosmos.scan_resource_conf(conf), CheckResult.FAILED, str(rules))

    def test_current_authored_resources_pass_without_source_or_ast_mutation(self):
        cases = (
            ("infra/modules/functionApp.bicep", "functionApp", identity),
            ("infra/modules/cosmos.bicep", "account", cosmos),
        )
        for relative, name, check in cases:
            conf = BicepParser().parse(file_path=ROOT / relative)["resources"][name]
            original = deepcopy(conf)
            self.assertEqual(check.scan_entity_conf(conf, conf["type"]), CheckResult.PASSED)
            self.assertEqual(conf, original)

    def test_real_runner_identity_secure_insecure_unknown_each_retained(self):
        for kind, expected in (("'SystemAssigned, UserAssigned'", CheckResult.PASSED),
                               ("'None'", CheckResult.FAILED), ("identityType", CheckResult.FAILED)):
            source = (
                "param identityType string\n"
                "resource site 'Microsoft.Web/sites@2024-04-01' = {\n"
                " name: 'fixture'\n identity: { type: " + kind + " }\n}\n"
            )
            report = run_fixture(source, identity)
            self.assertFalse(report.parsing_errors)
            self.assertFalse(report.skipped_checks)
            records = report.passed_checks + report.failed_checks
            self.assertEqual(len(records), 1)
            self.assertEqual(records[0].check_result["result"], expected)

    def test_real_runner_cosmos_secure_insecure_unknown_each_retained(self):
        for value, expected in (("'Disabled'", CheckResult.PASSED), ("'Enabled'", CheckResult.FAILED),
                                ("publicAccess", CheckResult.FAILED)):
            source = (
                "param publicAccess string\n"
                "resource account 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {\n"
                " name: 'fixture'\n properties: {\n publicNetworkAccess: " + value +
                "\n enableMultipleWriteLocations: false\n }\n}\n"
            )
            report = run_fixture(source, cosmos)
            self.assertFalse(report.parsing_errors)
            self.assertFalse(report.skipped_checks)
            records = report.passed_checks + report.failed_checks
            self.assertEqual(len(records), 1)
            self.assertEqual(records[0].check_result["result"], expected)

    def test_real_runner_cosmos_both_ipv4_halves_remain_blocking(self):
        for cidr in ("0.0.0.0/1", "128.0.0.0/1"):
            with self.subTest(cidr=cidr):
                source = (
                    "resource account 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {\n"
                    " name: 'fixture'\n properties: {\n publicNetworkAccess: 'Enabled'\n"
                    " isVirtualNetworkFilterEnabled: true\n"
                    " ipRules: [{ ipAddressOrRange: '" + cidr + "' }]\n }\n}\n"
                )
                report = run_fixture(source, cosmos)
                self.assertFalse(report.parsing_errors)
                self.assertFalse(report.skipped_checks)
                self.assertFalse(report.passed_checks)
                self.assertEqual(len(report.failed_checks), 1)
                self.assertEqual(report.failed_checks[0].check_result["result"], CheckResult.FAILED)


if __name__ == "__main__":
    unittest.main(verbosity=2)
