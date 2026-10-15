"""Enforce completeness of one pinned Checkov Bicep JSON report."""

import argparse
import json
from pathlib import Path
import sys


def unique_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate JSON key")
        result[key] = value
    return result


def evaluate(report, scanner_status):
    if type(scanner_status) is not int or not 0 <= scanner_status <= 255:
        raise ValueError("invalid scanner exit code")
    if not isinstance(report, dict) or report.get("check_type") != "bicep":
        raise ValueError("expected one Bicep report")
    summary = report.get("summary")
    results = report.get("results")
    if not isinstance(summary, dict) or not isinstance(results, dict):
        raise ValueError("missing summary or results")
    if summary.get("checkov_version") != "3.2.495":
        raise ValueError("unexpected Checkov version")
    fields = {
        "passed": "passed_checks",
        "failed": "failed_checks",
        "skipped": "skipped_checks",
        "parsing_errors": "parsing_errors",
    }
    for counter in (*fields, "resource_count"):
        value = summary.get(counter)
        if type(value) is not int or value < 0:
            raise ValueError("invalid summary counter")
    assessed = set()
    for counter, key in fields.items():
        records = results.get(key)
        if not isinstance(records, list) or len(records) != summary[counter]:
            raise ValueError("summary does not match report records")
        for record in records:
            if counter == "parsing_errors":
                if not isinstance(record, str) or not record:
                    raise ValueError("invalid parsing error record")
            else:
                if not isinstance(record, dict):
                    raise ValueError("invalid check record")
                for field in ("check_id", "file_path", "resource"):
                    if not isinstance(record.get(field), str) or not record[field]:
                        raise ValueError("invalid check identity")
                if counter != "skipped":
                    assessed.add((record["file_path"], record["resource"]))
    problems = []
    if scanner_status:
        problems.append("scanner exit code is nonzero")
    if summary["failed"]:
        problems.append("failed checks")
    if summary["parsing_errors"]:
        problems.append("parsing errors")
    if summary["resource_count"] == 0 or not assessed:
        problems.append("zero effective resource coverage")
    lines = [
        "## Checkov IaC scan",
        "",
        f"- Scanner exit code: `{scanner_status}`",
        f"- Passed checks: {summary['passed']}",
        f"- Failed checks: {summary['failed']}",
        f"- Skipped checks: {summary['skipped']}",
        f"- Parsing errors: {summary['parsing_errors']}",
        f"- Scanner-reported resource count: {summary['resource_count']}",
        f"- Resource identities with executed checks: {len(assessed)}",
        "- Resource counts do not prove exhaustive source coverage or unique deployed resources.",
        f"- Result: **{'blocked' if problems else 'passed'}**",
    ]
    if problems:
        lines.append("- Blocking reasons: " + "; ".join(problems) + ".")
    return (1 if problems else 0), "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("scanner_status", type=int)
    args = parser.parse_args()
    try:
        report = json.loads(
            args.report.read_text(encoding="utf-8"), object_pairs_hook=unique_keys
        )
        status, summary = evaluate(report, args.scanner_status)
    except (OSError, UnicodeError, ValueError) as error:
        print(
            "Checkov output is missing or malformed "
            f"({type(error).__name__}); scan is blocked.",
            file=sys.stderr,
        )
        return 1
    print(summary, end="")
    return status


if __name__ == "__main__":
    sys.exit(main())
