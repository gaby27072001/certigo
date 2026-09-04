from __future__ import annotations

import importlib.util
import json
import os
import shutil
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "check_active_content_age.py"
REPO_ROOT = Path(
    os.environ.get("CERTIGO_WORKSPACE", MODULE_PATH.parents[1])
).resolve()
SPEC = importlib.util.spec_from_file_location("check_active_content_age", MODULE_PATH)
assert SPEC and SPEC.loader
check_active_content_age = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = check_active_content_age
SPEC.loader.exec_module(check_active_content_age)

REFERENCE = Path("docs/active-content-reference.json")


class CheckActiveContentAgeTest(unittest.TestCase):
    def workspace(self, committed_at: str | None = None) -> Path:
        root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, root, True)
        target = root / REFERENCE
        target.parent.mkdir(parents=True, exist_ok=True)
        value = json.loads((REPO_ROOT / REFERENCE).read_text(encoding="utf-8"))
        if committed_at is not None:
            value["committedAt"] = committed_at
            value["date"] = committed_at[:10]
        target.write_text(
            json.dumps(value, indent=2) + "\n", encoding="utf-8", newline="\n"
        )
        return root

    def run_main(self, root: Path, now: str, days: str = "14") -> int:
        return check_active_content_age.main(
            ["--root", str(root), "--now", now, "--max-age-days", days]
        )

    def test_accepts_a_pin_inside_the_refresh_budget(self) -> None:
        root = self.workspace("2026-09-01T00:00:00Z")
        self.assertEqual(self.run_main(root, "2026-09-14T23:59:59Z"), 0)

    def test_rejects_a_pin_past_the_refresh_budget(self) -> None:
        root = self.workspace("2026-09-01T00:00:00Z")
        self.assertEqual(self.run_main(root, "2026-09-15T00:00:01Z"), 1)

    def test_rejects_a_pin_committed_in_the_future(self) -> None:
        root = self.workspace("2026-09-20T00:00:00Z")
        self.assertEqual(self.run_main(root, "2026-09-15T00:00:00Z"), 1)

    def test_rejects_a_non_positive_budget(self) -> None:
        root = self.workspace("2026-09-01T00:00:00Z")
        self.assertEqual(self.run_main(root, "2026-09-02T00:00:00Z", days="0"), 1)

    def test_rejects_a_malformed_now(self) -> None:
        root = self.workspace("2026-09-01T00:00:00Z")
        self.assertEqual(self.run_main(root, "2026-09-02"), 1)

    def test_rejects_an_invalid_reference(self) -> None:
        root = self.workspace()
        (root / REFERENCE).write_text("{}\n", encoding="utf-8", newline="\n")
        self.assertEqual(self.run_main(root, "2026-09-02T00:00:00Z"), 1)


if __name__ == "__main__":
    unittest.main()
