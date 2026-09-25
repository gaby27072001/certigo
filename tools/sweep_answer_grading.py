#!/usr/bin/env python3
"""Sweep the corpus before switching server grading to order-sensitive (wp-p2-06, decision Q2 a).

Two sources:

* ``legacy`` — the documents ``tools/seed_content.py`` compiles from ``content/``: exactly what
  the production ``legacy`` repository serves (public checks + server-only answer keys);
* ``runtime`` — an unpacked release (``dist/`` of certigo-content: ``public/questions`` and
  ``private/solutions``), optional.

For every item it replays the canonical right answer — the answer key, in its order — through
the old rule (sorted comparison) and the new rule (``AnswerGrading``: sequence for ordering,
cloze and applied; multiset otherwise). It also checks that the client can *submit* that answer
(``LessonSessionState.canSubmitCurrent``): an item whose right answer cannot be submitted, or
whose key is not a valid sequence, is an error. Exit status 1 on any error.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path
from typing import Any, Iterable

sys.path.insert(0, str(Path(__file__).resolve().parent))

ORDERED_TYPES = frozenset({"ordering", "cloze", "applied"})
BLANK = re.compile(r"_{4,}")


def old_rule(expected: list[str], selected: list[str]) -> bool:
    return sorted(expected) == sorted(selected)


def new_rule(item_type: str, expected: list[str], selected: list[str]) -> bool:
    if item_type in ORDERED_TYPES:
        return list(expected) == list(selected)
    return Counter(expected) == Counter(selected)


def check_item(item: dict[str, Any]) -> list[dict[str, str]]:
    """Findings for one joined item {source, id, type, stem, options, correct}."""
    findings: list[dict[str, str]] = []

    def add(level: str, rule: str, detail: str) -> None:
        findings.append({"level": level, "rule": rule, "source": item["source"], "id": item["id"],
                         "type": item["type"], "detail": detail})

    item_type = item["type"]
    options = [option["id"] for option in item["options"]]
    correct = list(item["correct"])
    if not new_rule(item_type, correct, correct):
        add("error", "CANONICAL_REJECTED", "the answer key does not grade as correct")
    if old_rule(correct, correct) != new_rule(item_type, correct, correct):
        add("error", "CANONICAL_VERDICT_CHANGES", "the right answer changes verdict")
    if item_type not in ORDERED_TYPES:
        return findings

    if len(set(correct)) != len(correct):
        add("error", "DUPLICATE_IN_KEY", f"key={correct}")
    unknown = [value for value in correct if value not in options]
    if unknown:
        add("error", "KEY_NOT_IN_OPTIONS", f"unknown={unknown}")
    if item_type == "ordering" and (len(correct) != len(options) or set(correct) != set(options)):
        add("error", "ORDERING_NOT_A_PERMUTATION", f"options={len(options)} key={len(correct)}")
    if item_type == "applied":
        if len(correct) < 2:
            add("error", "APPLIED_TOO_SHORT", f"key={len(correct)}")
        if len(correct) != len(options):
            # The client only submits once every option is placed (canSubmitCurrent).
            add("error", "APPLIED_UNSUBMITTABLE",
                f"options={len(options)} key={len(correct)}: the right answer cannot be submitted")
    if item_type == "cloze":
        blanks = len(BLANK.findall(item["stem"]))
        if blanks < 1 or blanks != len(correct) or len(options) < blanks:
            add("error", "CLOZE_BLANKS_MISMATCH", f"blanks={blanks} key={len(correct)} options={len(options)}")
    if item_type in {"ordering", "applied"}:
        published = [value for value in options if value in correct]
        if published == correct:
            add("warning", "DISPLAY_ORDER_REVEALS_ANSWER", "options are published in the key order")
    return findings


def legacy_items() -> Iterable[dict[str, Any]]:
    import seed_content

    documents = seed_content.build_documents()
    checks: dict[str, dict[str, Any]] = {}
    for document in documents:
        if document.get("type") != "lesson":
            continue
        for block in document["blocks"]:
            check = block.get("check")
            if check:
                checks[check["id"]] = check
    for document in documents:
        if document.get("type") != "answerKey":
            continue
        for key in document["items"]:
            check = checks[key["itemId"]]
            yield {"source": "legacy", "id": key["itemId"], "type": key["type"], "stem": check["stem"],
                   "options": check["options"], "correct": key["correct"]}


def runtime_items(package: Path) -> Iterable[dict[str, Any]]:
    solutions = {}
    for path in sorted((package / "private" / "solutions").rglob("*.json")):
        solution = json.loads(path.read_text(encoding="utf-8"))
        solutions[solution["id"]] = solution
    for path in sorted((package / "public" / "questions").rglob("*.json")):
        question = json.loads(path.read_text(encoding="utf-8"))
        solution = solutions[question["id"]]
        if question["schemaVersion"] in {"v2", "v3"}:
            # Single-answer choices: the backend projects them to mcq with derived option ids.
            options = [{"id": choice, "label": choice} for choice in question["choices"]]
            correct = [solution["correct"]]
            item_type = "mcq"
        else:
            options = question["options"]
            correct = solution["correctOptionIds"]
            item_type = question["itemType"]
        yield {"source": f"runtime:{question['schemaVersion']}", "id": question["id"], "type": item_type,
               "stem": question["prompt"], "options": options, "correct": correct}


def sweep(items: Iterable[dict[str, Any]]) -> dict[str, Any]:
    counts: Counter[tuple[str, str]] = Counter()
    ordered: list[dict[str, Any]] = []
    findings: list[dict[str, str]] = []
    for item in items:
        counts[(item["source"], item["type"])] += 1
        findings.extend(check_item(item))
        if item["type"] in ORDERED_TYPES:
            ordered.append({"source": item["source"], "id": item["id"], "type": item["type"],
                            "options": len(item["options"]), "key": len(item["correct"]),
                            "blanks": len(BLANK.findall(item["stem"])) if item["type"] == "cloze" else None})
    return {
        "schema": "certigo.answer-grading-sweep/v1",
        "counts": [{"source": s, "type": t, "items": n} for (s, t), n in sorted(counts.items())],
        "orderedItems": ordered,
        "errors": [f for f in findings if f["level"] == "error"],
        "warnings": [f for f in findings if f["level"] == "warning"],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--runtime-package", type=Path, help="Unpacked release (certigo-content dist/).")
    parser.add_argument("--report", type=Path, help="Write the JSON report to this file.")
    arguments = parser.parse_args(argv)

    items: list[dict[str, Any]] = list(legacy_items())
    if arguments.runtime_package is not None:
        items.extend(runtime_items(arguments.runtime_package))
    report = sweep(items)
    text = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if arguments.report is not None:
        arguments.report.write_text(text, encoding="utf-8")
    for row in report["counts"]:
        print(f"{row['source']:<14} {row['type']:<13} {row['items']}")
    print(f"ordered items: {len(report['orderedItems'])}, errors: {len(report['errors'])}, "
          f"warnings: {len(report['warnings'])}")
    for finding in report["errors"] + report["warnings"]:
        print(f"{finding['level']:<7} {finding['rule']:<28} {finding['source']} {finding['id']} {finding['detail']}")
    return 1 if report["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
