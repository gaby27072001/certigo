import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from checkov_report_gate import evaluate


def report():
    return {
        "check_type": "bicep",
        "summary": {
            "passed": 1,
            "failed": 0,
            "skipped": 0,
            "parsing_errors": 0,
            "resource_count": 1,
            "checkov_version": "3.2.495",
        },
        "results": {
            "passed_checks": [
                {
                    "check_id": "CKV_AZURE_3",
                    "file_path": "/fixture.bicep",
                    "resource": "storage",
                }
            ],
            "failed_checks": [],
            "skipped_checks": [],
            "parsing_errors": [],
        },
    }


class CheckovReportGateTests(unittest.TestCase):
    def test_complete_scan_passes(self):
        status, text = evaluate(report(), 0)
        self.assertEqual(status, 0)
        self.assertIn("identities with executed checks: 1", text)
        self.assertIn("do not prove exhaustive source coverage", text)

    def test_nonzero_scanner_status_blocks(self):
        for status in (1, 2, 127, 255):
            with self.subTest(status=status):
                self.assertEqual(evaluate(report(), status)[0], 1)

    def test_failed_check_blocks_even_with_zero_scanner_exit(self):
        value = report()
        value["results"]["failed_checks"] = value["results"]["passed_checks"]
        value["results"]["passed_checks"] = []
        value["summary"].update(passed=0, failed=1)
        self.assertEqual(evaluate(value, 0)[0], 1)

    def test_parsing_errors_block_even_with_passed_checks_and_zero_exit(self):
        value = report()
        value["summary"]["parsing_errors"] = 22
        value["results"]["parsing_errors"] = [f"/broken-{i}.bicep" for i in range(22)]
        status, text = evaluate(value, 0)
        self.assertEqual(status, 1)
        self.assertIn("Parsing errors: 22", text)

    def test_zero_reported_resources_blocks(self):
        value = report()
        value["summary"]["resource_count"] = 0
        self.assertEqual(evaluate(value, 0)[0], 1)

    def test_no_executed_checks_blocks_even_with_nonzero_resource_count(self):
        value = report()
        value["summary"]["passed"] = 0
        value["results"]["passed_checks"] = []
        self.assertEqual(evaluate(value, 0)[0], 1)

    def test_skipped_only_does_not_prove_effective_coverage(self):
        value = report()
        value["summary"].update(passed=0, skipped=1)
        value["results"]["skipped_checks"] = value["results"]["passed_checks"]
        value["results"]["passed_checks"] = []
        self.assertEqual(evaluate(value, 0)[0], 1)

    def test_existing_skips_are_not_new_exclusions(self):
        value = report()
        value["summary"]["skipped"] = 1
        value["results"]["skipped_checks"] = copy.deepcopy(
            value["results"]["passed_checks"]
        )
        self.assertEqual(evaluate(value, 0)[0], 0)

    def test_multiple_rules_on_one_resource_are_not_unique_resources(self):
        value = report()
        other = copy.deepcopy(value["results"]["passed_checks"][0])
        other["check_id"] = "CKV_AZURE_4"
        value["results"]["passed_checks"].append(other)
        value["summary"]["passed"] = 2
        self.assertIn("identities with executed checks: 1", evaluate(value, 0)[1])

    def test_wrong_framework_version_and_multiple_reports_are_rejected(self):
        for key, replacement in (("check_type", "arm"), ("check_type", None)):
            value = report()
            value[key] = replacement
            with self.subTest(key=key, replacement=replacement), self.assertRaises(ValueError):
                evaluate(value, 0)
        value = report()
        value["summary"]["checkov_version"] = "3.3.29"
        with self.assertRaises(ValueError):
            evaluate(value, 0)
        with self.assertRaises(ValueError):
            evaluate([report()], 0)

    def test_counters_reject_missing_negative_float_string_bool_and_null(self):
        for field in report()["summary"]:
            if field == "checkov_version":
                continue
            for invalid in (-1, 1.5, "0", True, None):
                value = report()
                value["summary"][field] = invalid
                with self.subTest(field=field, invalid=invalid), self.assertRaises(ValueError):
                    evaluate(value, 0)
            value = report()
            del value["summary"][field]
            with self.subTest(field=field), self.assertRaises(ValueError):
                evaluate(value, 0)

    def test_missing_or_inconsistent_results_are_rejected(self):
        for key in report()["results"]:
            value = report()
            del value["results"][key]
            with self.subTest(key=key), self.assertRaises(ValueError):
                evaluate(value, 0)
            value = report()
            value["results"][key] = {}
            with self.subTest(key=key), self.assertRaises(ValueError):
                evaluate(value, 0)
        value = report()
        value["summary"]["parsing_errors"] = 1
        with self.assertRaises(ValueError):
            evaluate(value, 0)

    def test_invalid_record_identity_is_rejected(self):
        for field in ("check_id", "file_path", "resource"):
            value = report()
            value["results"]["passed_checks"][0][field] = None
            with self.subTest(field=field), self.assertRaises(ValueError):
                evaluate(value, 0)

    def test_scanner_control_characters_never_reach_summary(self):
        value = report()
        for field in ("check_id", "file_path", "resource"):
            value["results"]["passed_checks"][0][field] = "::error::unsafe\ninjected"
        text = evaluate(value, 0)[1]
        self.assertNotIn("injected", text)
        self.assertNotIn("::error::", text)

    def test_invalid_status_rejected(self):
        for status in (True, -1, 256, "0", None):
            with self.subTest(status=status), self.assertRaises(ValueError):
                evaluate(report(), status)

    def test_cli_enforces_json_and_status(self):
        script = Path(__file__).with_name("checkov_report_gate.py")
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "report.json"
            for contents, scanner_status, expected in (
                (json.dumps(report()), "0", 0),
                (json.dumps(report()), "1", 1),
                ("", "0", 1),
                ("not json", "0", 1),
                ('{"check_type":"arm","check_type":"bicep"}', "0", 1),
                ("{}", "0", 1),
                ("[]", "0", 1),
                (json.dumps(report()), "invalid", 2),
            ):
                source.write_text(contents, encoding="utf-8")
                result = subprocess.run(
                    [sys.executable, str(script), str(source), scanner_status],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                with self.subTest(contents=contents[:40], scanner_status=scanner_status):
                    self.assertEqual(result.returncode, expected, result.stderr)
            source.unlink()
            result = subprocess.run(
                [sys.executable, str(script), str(source), "0"],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 1)
            self.assertIn("FileNotFoundError", result.stderr)


if __name__ == "__main__":
    unittest.main()
