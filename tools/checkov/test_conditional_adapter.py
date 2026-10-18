"""Exercise actual pinned checks on conditional resource bodies; no infrastructure scan."""

from copy import deepcopy
from importlib.metadata import version
import hashlib
from pathlib import Path
import tempfile
import unittest

import checkov.arm
from checkov.arm.checks.resource.AzureScaleSetPassword import check as password
from checkov.arm.checks.resource.LinuxVMUsesSSH import check as ssh
from checkov.arm.checks.resource.VMDisablePasswordAuthentication import check as password_disabled
from checkov.arm.checks.resource.VMEncryptionAtHostEnabled import check as encryption
from checkov.bicep.runner import Runner
from checkov.common.models.enums import CheckResult
from checkov.runner_filter import RunnerFilter
from pycep import BicepParser

from build_checkov_wheel import PATCHED_SOURCE_SHA256, SOURCE, VERSION


CHECKS = (encryption, password_disabled, ssh, password)
TYPE = "Microsoft.Compute/virtualMachineScaleSets"
BODY = {
    "name": "fixture",
    "properties": {
        "virtualMachineProfile": {
            "securityProfile": {"encryptionAtHost": True},
            "osProfile": {
                "linuxConfiguration": {
                    "disablePasswordAuthentication": True,
                    "ssh": {"publicKeys": [{"keyData": "public-only", "path": "/home/test/.ssh/authorized_keys"}]},
                },
            },
        },
    },
}


def entity(body, guard="deploy", existing=False):
    return {
        "type": TYPE, "existing": existing, "api_version": "2024-11-01",
        "config": {"condition": guard, "config": body},
    }


class AdapterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if version("checkov") != VERSION:
            raise ValueError("Tests require the pinned Checkov adapter wheel")
        path = Path(checkov.arm.__file__).resolve().parents[1] / Path(SOURCE).relative_to("checkov")
        if hashlib.sha256(path.read_bytes()).hexdigest() != PATCHED_SOURCE_SHA256:
            raise ValueError("Unexpected installed adapter source")

    def test_potential_bodies_are_checked_without_evaluating_the_guard(self):
        for guard in (True, False, "deploy", {"operator": {"type": "unresolved"}}):
            conf = entity(deepcopy(BODY), guard)
            original = deepcopy(conf)
            for check in CHECKS:
                with self.subTest(guard=guard, check=check.id):
                    self.assertEqual(check.scan_entity_conf(conf, TYPE), CheckResult.PASSED)
            self.assertEqual(conf, original)

    def test_each_insecure_body_fails_under_every_guard(self):
        for guard in (True, False, "deploy"):
            for check in CHECKS:
                body = deepcopy(BODY)
                profile = body["properties"]["virtualMachineProfile"]
                if check is encryption:
                    profile["securityProfile"]["encryptionAtHost"] = False
                elif check is ssh:
                    profile["osProfile"]["linuxConfiguration"]["ssh"]["publicKeys"] = []
                else:
                    profile["osProfile"]["linuxConfiguration"]["disablePasswordAuthentication"] = False
                with self.subTest(guard=guard, check=check.id):
                    self.assertEqual(check.scan_entity_conf(entity(body, guard), TYPE), CheckResult.FAILED)

    def test_unknown_properties_and_unknown_rule_results_remain_blocking(self):
        for check in (encryption, password_disabled, password):
            body = deepcopy(BODY)
            profile = body["properties"]["virtualMachineProfile"]
            if check is encryption:
                profile["securityProfile"]["encryptionAtHost"] = {"function": {"type": "unknown"}}
            else:
                profile["osProfile"]["linuxConfiguration"]["disablePasswordAuthentication"] = {"function": {"type": "unknown"}}
            with self.subTest(check=check.id):
                self.assertEqual(check.scan_entity_conf(entity(body), TYPE), CheckResult.FAILED)
        with self.assertLogs(level="WARNING") as captured:
            body = {"properties": {"virtualMachineProfile": {"securityProfile": {"encryptionAtHost": True}}}}
            self.assertEqual(password_disabled.scan_entity_conf(entity(body), TYPE), CheckResult.FAILED)
        self.assertIn("UNKNOWN", "\n".join(captured.output))

    def test_malformed_wrappers_fail_explicitly(self):
        for wrapper in ({"condition": "deploy"}, {"condition": "deploy", "config": None}):
            conf = entity({})
            conf["config"] = wrapper
            with self.assertLogs(level="WARNING"):
                self.assertEqual(encryption.scan_entity_conf(conf, TYPE), CheckResult.FAILED)

    def test_existing_and_unconditional_resources_keep_their_results(self):
        self.assertEqual(encryption.scan_entity_conf(entity(BODY, existing=True), TYPE), CheckResult.UNKNOWN)
        for check in CHECKS:
            conf = entity(deepcopy(BODY))
            conf["config"] = deepcopy(BODY)
            self.assertEqual(check.scan_entity_conf(conf, TYPE), CheckResult.PASSED)
            conf["config"] = {"loop_type": {"type": "range"}, "config": deepcopy(BODY)}
            self.assertEqual(check.scan_entity_conf(conf, TYPE), CheckResult.PASSED)
        conf = entity({"properties": {"virtualMachineProfile": {"securityProfile": {}}}})
        conf["config"] = conf["config"]["config"]
        self.assertEqual(password_disabled.scan_entity_conf(conf, TYPE), CheckResult.UNKNOWN)
        for check in CHECKS:
            self.assertEqual(check.scan_entity_conf(deepcopy(BODY), TYPE), CheckResult.PASSED)

    def test_exact_canary_ast_retains_guard_and_secure_property_checks(self):
        source = Path(__file__).resolve().parents[2] / "infra/ci-runner/image/canary.bicep"
        conf = BicepParser().parse(file_path=source)["resources"]["runnerScaleSet"]
        original = deepcopy(conf)
        self.assertEqual(conf["config"]["condition"], "effectiveDeploymentEnabled")
        for check in CHECKS:
            with self.subTest(check=check.id):
                self.assertEqual(check.scan_entity_conf(conf, TYPE), CheckResult.PASSED)
        self.assertEqual(conf, original)

    def test_real_runner_reports_secure_insecure_and_unknown_bodies(self):
        for setting, passed in (("true", True), ("false", False), ("encryptionEnabled", False)):
            source = (
                "param deploy bool\nparam encryptionEnabled bool\n"
                "resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2024-11-01' = if (deploy) {\n"
                " name: 'fixture'\n properties: {\n virtualMachineProfile: {\n"
                " securityProfile: { encryptionAtHost: " + setting + " }\n"
                " osProfile: {\n linuxConfiguration: {\n disablePasswordAuthentication: true\n"
                " ssh: { publicKeys: [{ keyData: 'public-only', path: '/home/test/.ssh/authorized_keys' }] }\n"
                " }\n }\n }\n }\n}\n"
            )
            tree = BicepParser().parse(text=source)
            self.assertIn("condition", tree["resources"]["vmss"]["config"])
            with tempfile.TemporaryDirectory() as temporary:
                path = Path(temporary) / "fixture.bicep"
                path.write_text(source, encoding="utf-8")
                report = Runner().run(
                    root_folder=temporary, files=[str(path)],
                    runner_filter=RunnerFilter(checks=[check.id for check in CHECKS], show_progress_bar=False),
                )
            self.assertFalse(report.parsing_errors)
            self.assertFalse(report.skipped_checks)
            actual = {record.check_id: record.check_result["result"] for record in report.passed_checks + report.failed_checks}
            expected = {check.id: CheckResult.PASSED for check in CHECKS}
            if not passed:
                expected[encryption.id] = CheckResult.FAILED
            self.assertEqual(actual, expected)

    def test_real_runner_retains_unknown_check_as_a_failed_record(self):
        source = (
            "param deploy bool\n"
            "resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2024-11-01' = if (deploy) {\n"
            " name: 'fixture'\n properties: {\n virtualMachineProfile: {\n"
            " securityProfile: { encryptionAtHost: true }\n }\n }\n}\n"
        )
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "unknown.bicep"
            path.write_text(source, encoding="utf-8")
            with self.assertLogs(level="WARNING") as captured:
                report = Runner().run(
                    root_folder=temporary, files=[str(path)],
                    runner_filter=RunnerFilter(checks=[password_disabled.id], show_progress_bar=False),
                )
        self.assertFalse(report.parsing_errors)
        self.assertFalse(report.passed_checks)
        self.assertFalse(report.skipped_checks)
        self.assertEqual(len(report.failed_checks), 1)
        self.assertEqual(report.failed_checks[0].check_id, password_disabled.id)
        self.assertIn("UNKNOWN", "\n".join(captured.output))


if __name__ == "__main__":
    unittest.main(verbosity=2)
