"""Tests of the order-sensitive grading sweep (`tools/sweep_answer_grading.py`, wp-p2-06, Q2 a)."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import sweep_answer_grading as sweep  # noqa: E402


def item(item_type: str, options: list[str], correct: list[str], stem: str = "Question ?") -> dict:
    return {"source": "test", "id": f"{item_type}-1", "type": item_type, "stem": stem,
            "options": [{"id": value, "label": value} for value in options], "correct": correct}


def rules(findings: list[dict[str, str]], level: str = "error") -> set[str]:
    return {finding["rule"] for finding in findings if finding["level"] == level}


class CheckItemTests(unittest.TestCase):
    def test_valid_ordered_items_have_no_finding(self) -> None:
        self.assertEqual(sweep.check_item(item("ordering", ["c", "a", "b"], ["a", "b", "c"])), [])
        self.assertEqual(sweep.check_item(item("applied", ["b", "a"], ["a", "b"])), [])
        self.assertEqual(
            sweep.check_item(item("cloze", ["x", "y", "z"], ["y", "x"], stem="Le ____ puis le ____.")), [])

    def test_ordering_key_must_be_a_permutation_of_every_option(self) -> None:
        self.assertIn("ORDERING_NOT_A_PERMUTATION", rules(sweep.check_item(item("ordering", ["a", "b", "c"], ["b", "a"]))))

    def test_applied_with_distractors_cannot_be_submitted_by_the_client(self) -> None:
        findings = sweep.check_item(item("applied", ["c", "a", "b"], ["a", "b"]))
        self.assertIn("APPLIED_UNSUBMITTABLE", rules(findings))

    def test_cloze_key_must_fill_every_blank(self) -> None:
        findings = sweep.check_item(item("cloze", ["x", "y"], ["x"], stem="Le ____ puis le ____."))
        self.assertIn("CLOZE_BLANKS_MISMATCH", rules(findings))

    def test_key_ids_must_exist_and_be_unique(self) -> None:
        self.assertIn("KEY_NOT_IN_OPTIONS", rules(sweep.check_item(item("ordering", ["a", "b"], ["a", "z"]))))
        self.assertIn("DUPLICATE_IN_KEY", rules(sweep.check_item(item("applied", ["a", "b"], ["a", "a"]))))

    def test_display_order_equal_to_the_key_is_a_warning(self) -> None:
        findings = sweep.check_item(item("ordering", ["a", "b", "c"], ["a", "b", "c"]))
        self.assertEqual(rules(findings), set())
        self.assertEqual(rules(findings, "warning"), {"DISPLAY_ORDER_REVEALS_ANSWER"})

    def test_rules_agree_on_the_canonical_answer_and_differ_on_a_wrong_order(self) -> None:
        self.assertTrue(sweep.old_rule(["a", "b"], ["a", "b"]))
        self.assertTrue(sweep.new_rule("ordering", ["a", "b"], ["a", "b"]))
        self.assertTrue(sweep.old_rule(["a", "b"], ["b", "a"]))
        self.assertFalse(sweep.new_rule("ordering", ["a", "b"], ["b", "a"]))
        self.assertTrue(sweep.new_rule("multi", ["a", "b"], ["b", "a"]))
        self.assertFalse(sweep.new_rule("multi", ["a", "b"], ["a", "a"]))


class CorpusTests(unittest.TestCase):
    """Ratchet: every ordered item of the legacy corpus stays gradable in order."""

    def test_legacy_corpus_has_no_error(self) -> None:
        report = sweep.sweep(sweep.legacy_items())
        self.assertEqual(report["errors"], [])
        self.assertGreater(sum(row["items"] for row in report["counts"]), 0)


if __name__ == "__main__":
    unittest.main()
