"""Per-type anti-leak guarantees of the legacy content compiler (`tools/seed_content.py`).

The production `legacy` repository serves lessons compiled by this script: the public
lesson document ships to every learner, the answer key stays server-only. These tests
prove, for every exercise type, that no answer material reaches the public document and
that each public check keeps exactly one server-side answer key.
"""

from __future__ import annotations

import sys
import unittest
from collections import Counter
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import seed_content  # noqa: E402

ITEM_TYPES = ("mcq", "multi", "scenario", "cloze", "ordering", "matchPairs", "spotTheIssue", "applied")
ANSWER_MATERIAL = frozenset(
    {"correct", "correctoptionids", "explanation", "rationale", "answerkey", "solution", "matches", "pairs"}
)
PUBLIC_CHECK_FIELDS = {"id", "conceptId", "type", "stem", "options"}


def answer_keys_in(value: Any) -> set[str]:
    if isinstance(value, dict):
        found = {key for key in value if key.lower() in ANSWER_MATERIAL}
        for nested in value.values():
            found |= answer_keys_in(nested)
        return found
    if isinstance(value, list):
        found: set[str] = set()
        for nested in value:
            found |= answer_keys_in(nested)
        return found
    return set()


def authored_item(item_type: str) -> dict[str, Any]:
    """An authored check carrying every kind of answer material a type can hold."""
    return {
        "id": f"check-{item_type.lower()}",
        "conceptId": "concept-1",
        "type": item_type,
        "stem": f"Consigne {item_type}",
        "options": [{"id": "a", "label": "A"}, {"id": "b", "label": "B"}],
        "matches": [{"id": "x", "label": "X"}],
        "pairs": [{"leftId": "a", "rightId": "x"}],
        "correct": ["a"],
        "explanation": "Pourquoi A.",
        "rationale": "Détail privé.",
        "difficulty": 2,
    }


class PublicLessonAntiLeakTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.documents = seed_content.build_documents()
        cls.lessons = [doc for doc in cls.documents if doc["type"] == "lesson"]
        cls.keys = [doc for doc in cls.documents if doc["type"] == "answerKey"]

    def test_every_type_strips_answer_material_from_the_public_check(self) -> None:
        for item_type in ITEM_TYPES:
            with self.subTest(item_type=item_type):
                public = seed_content.public_block({"type": "check", "check": authored_item(item_type)})

                self.assertEqual(set(public["check"]), PUBLIC_CHECK_FIELDS)
                self.assertEqual(public["check"]["type"], item_type)
                self.assertEqual(answer_keys_in(public), set())

    def test_every_type_keeps_its_answer_key_server_side(self) -> None:
        for item_type in ITEM_TYPES:
            with self.subTest(item_type=item_type):
                keys = seed_content.answer_keys({"blocks": [{"type": "check", "check": authored_item(item_type)}]})

                self.assertEqual(len(keys), 1)
                self.assertEqual(keys[0]["type"], item_type)
                self.assertEqual(keys[0]["correct"], ["a"])
                self.assertEqual(keys[0]["explanation"], "Pourquoi A.")

    def test_no_compiled_public_lesson_carries_answer_material(self) -> None:
        self.assertTrue(self.lessons)
        for lesson in self.lessons:
            with self.subTest(lesson=lesson["id"]):
                self.assertEqual(answer_keys_in(lesson), set())

    def test_each_public_check_has_exactly_one_answer_key_of_the_same_type(self) -> None:
        public_checks = {
            (lesson["id"], block["check"]["id"]): block["check"]["type"]
            for lesson in self.lessons
            for block in lesson["blocks"]
            if block.get("check")
        }
        keyed = Counter(
            (key["lessonId"], item["itemId"]) for key in self.keys for item in key["items"]
        )
        key_types = {
            (key["lessonId"], item["itemId"]): item["type"] for key in self.keys for item in key["items"]
        }

        self.assertEqual(set(keyed), set(public_checks))
        self.assertTrue(all(count == 1 for count in keyed.values()))
        self.assertEqual(key_types, public_checks)
        for key in self.keys:
            for item in key["items"]:
                with self.subTest(item=item["itemId"]):
                    self.assertTrue(item["correct"])

    def test_the_corpus_exercises_every_authorable_type(self) -> None:
        present = {
            block["check"]["type"] for lesson in self.lessons for block in lesson["blocks"] if block.get("check")
        }

        # matchPairs has no publishable pair contract yet (#245), so it is the only
        # type the corpus may lack.
        self.assertEqual(set(ITEM_TYPES) - present, {"matchPairs"})


if __name__ == "__main__":
    unittest.main()
