"""Real Bicep qualification controls, with no repository scan or active gate."""

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
from checkov.arm.checks.resource.AppServicePublicAccessDisabled import check

from bicep_ingress_candidate import CHECK, inventory, qualify, reconcile


SITE = """resource site 'Microsoft.Web/sites@2024-04-01' = {
 name: 'fixture'
 properties: { publicNetworkAccess: 'Disabled' }
}
"""
CHILD = """resource settings 'Microsoft.Web/sites/config@2024-04-01' = {
 parent: site
 name: 'appsettings'
 properties: { KEY: 'value' }
}
"""


class CandidateTests(unittest.TestCase):
    def run_source(self, source):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "fixture.bicep"
            path.write_text(source, encoding="utf-8")
            result = qualify(path, "staging")
            self.assertEqual(result["provenance"]["sha256"], hashlib.sha256(path.read_bytes()).hexdigest())
            self.assertEqual(path.read_text(encoding="utf-8"), source)
            return result

    def test_real_parent_and_child_have_separate_verdicts_and_raw_failure_survives(self):
        result = self.run_source(SITE + CHILD)
        self.assertEqual(result["status"], "QUALIFIED_SUBSET")
        self.assertFalse(result["production_adoptable"])
        entries = {row["resource"]: row for row in result["applicability"]}
        self.assertEqual(entries["Microsoft.Web/sites.site"]["status"], "PASSED")
        child = entries["Microsoft.Web/sites/config.settings"]
        self.assertEqual(child["status"], "NOT_APPLICABLE")
        self.assertEqual(child["parent"], "Microsoft.Web/sites.site")
        self.assertEqual(child["scanner_status"], "FAILED")
        self.assertEqual(len(result["scanner_report"]["results"]["failed_checks"]), 1)

    def test_real_insecure_parent_stays_failed_despite_nonapplicable_child(self):
        result = self.run_source((SITE + CHILD).replace("'Disabled'", "'Enabled'"))
        self.assertEqual(result["status"], "BLOCKED")
        self.assertEqual(len(result["scanner_report"]["results"]["failed_checks"]), 2)
        self.assertEqual(next(
            row["status"] for row in result["applicability"] if row["parent"] is not None
        ), "NOT_APPLICABLE")
        self.assertIn("applicable ingress check failed", result["blockers"])

    def test_missing_and_unknown_checks_cannot_disappear(self):
        result = self.run_source(SITE + CHILD)
        report = deepcopy(result["scanner_report"])
        report["results"]["failed_checks"] = []
        report["summary"]["failed"] = 0
        _, problems = reconcile(result["obligations"], report)
        self.assertIn("missing, duplicate or unexpected resource/check obligation", problems)
        original = check.scan_resource_conf

        def unknown_child(conf):
            return CheckResult.UNKNOWN if conf.get("name") == "appsettings" else original(conf)

        with patch.object(check, "scan_resource_conf", side_effect=unknown_child):
            missing = self.run_source(SITE + CHILD)
        self.assertEqual(missing["status"], "BLOCKED")
        self.assertTrue(any(row["status"] == "BLOCKED" for row in missing["applicability"]))
        self.assertEqual(len(missing["scanner_report"]["results"]["passed_checks"]), 1)

    def test_unknown_or_missing_parent_subtype_binding_and_parse_block_before_runner(self):
        for source in (
            CHILD,
            (SITE + CHILD).replace("parent: site", "parent: missing"),
            (SITE + CHILD).replace("parent: site", "parent: 'site'"),
            (SITE + CHILD).replace("'appsettings'", "'web'"),
            (SITE + CHILD).replace("'value'", "setting"),
            "param setting string\n" + SITE,
            "module other './other.bicep' = { name: 'other' }\n" + SITE,
            SITE.replace("'Disabled'", "ingress"),
            SITE.replace("'fixture'", "''"),
            SITE + SITE.replace("resource site ", "resource another "),
            SITE + CHILD + CHILD.replace("resource settings ", "resource another "),
            SITE.replace("= {", "= if (true) {", 1),
            SITE.replace("resource site", "resource site").replace(" = {", " existing = {", 1),
            "", "resource broken",
        ):
            with self.subTest(source=source):
                result = self.run_source(source)
                self.assertEqual(result["status"], "BLOCKED")
                self.assertIsNone(result["scanner_report"])
                self.assertTrue(result["blockers"])

    def test_malformed_report_and_lost_parent_fail_closed(self):
        result = self.run_source(SITE + CHILD)
        for damage in ("parse", "skip", "duplicate", "lost-parent", "version"):
            report = deepcopy(result["scanner_report"])
            if damage == "parse":
                report["results"]["parsing_errors"] = ["fixture.bicep"]
                report["summary"]["parsing_errors"] = 1
            elif damage == "skip":
                report["results"]["skipped_checks"] = [{}]
                report["summary"]["skipped"] = 1
            elif damage == "duplicate":
                report["results"]["passed_checks"] *= 2
                report["summary"]["passed"] = 2
            elif damage == "lost-parent":
                report["results"]["passed_checks"] = []
                report["summary"]["passed"] = 0
            else:
                report["summary"]["checkov_version"] = "unexpected"
            before = deepcopy(report)
            _, problems = reconcile(result["obligations"], report)
            self.assertTrue(problems, damage)
            self.assertEqual(report, before)

    def test_environment_and_module_instance_never_infer_bindings(self):
        for environment, instance in (("", "root"), ("unknown", "root"), ("prod", "module/other")):
            _, problems = inventory(SITE, environment, instance)
            self.assertTrue(problems)

    def test_cli_emits_versioned_inactive_report_and_blocking_exit(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "fixture.bicep"
            for source, expected in ((SITE + CHILD, 0), (SITE.replace("'Disabled'", "'Enabled'"), 1)):
                path.write_text(source, encoding="utf-8")
                run = subprocess.run(
                    [sys.executable, str(Path(__file__).with_name("bicep_ingress_candidate.py")),
                     str(path), "--environment", "staging"],
                    text=True, capture_output=True, timeout=90,
                )
                self.assertEqual(run.returncode, expected, run.stderr)
                report = json.loads(run.stdout)
                self.assertFalse(report["production_adoptable"])
                self.assertEqual(report["schema"], "certigo.bicep-ingress-qualification/v1")


if __name__ == "__main__":
    unittest.main(verbosity=2)
