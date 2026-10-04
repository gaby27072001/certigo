from __future__ import annotations

import contextlib
import importlib.util
import io
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
        # Capture stdout even when the assertion ignores it. A fixture here copies the
        # REAL reference and overwrites only the dates, so its ::warning:: line carries an
        # authentic revision SHA with synthetic timestamps — it has every marker of a
        # production reading. Left on the console it is indistinguishable from one, and it
        # has already been mistaken for the real pin age once. No fixture output escapes.
        # An explicit budget below the default warning threshold needs its own threshold,
        # otherwise the argument check rejects the pair before the age is even measured.
        warn = str(max(1, int(days) - 4))
        code, _ = self.run_capturing(
            root, now, "--max-age-days", days, "--warn-age-days", warn
        )
        return code

    def run_capturing(
        self, root: Path, now: str, *extra: str
    ) -> tuple[int, str]:
        # Both streams: the failure path prints the same real-SHA/synthetic-date mix on
        # stderr that the warning prints on stdout, and it is just as easy to mistake for
        # a production reading when skimming a test log.
        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer), contextlib.redirect_stderr(buffer):
            code = check_active_content_age.main(
                ["--root", str(root), "--now", now, *extra]
            )
        return code, buffer.getvalue()

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

    def test_stays_silent_below_the_warning_threshold(self) -> None:
        root = self.workspace("2026-09-01T00:00:00Z")
        code, out = self.run_capturing(root, "2026-09-23T00:00:00Z")
        self.assertEqual(code, 0)
        self.assertNotIn("::warning::", out)

    def test_warns_without_failing_inside_the_warning_band(self) -> None:
        """The band exists so the budget degrades as a slope, not as a wall."""
        root = self.workspace("2026-09-01T00:00:00Z")
        code, out = self.run_capturing(root, "2026-09-26T00:00:00Z")
        self.assertEqual(code, 0)
        self.assertIn("::warning::", out)
        self.assertIn("expires in 5 day(s)", out)

    def test_rejects_a_warning_threshold_at_or_above_the_budget(self) -> None:
        root = self.workspace("2026-09-01T00:00:00Z")
        code, _ = self.run_capturing(
            root, "2026-09-02T00:00:00Z", "--max-age-days", "14", "--warn-age-days", "14"
        )
        self.assertEqual(code, 1)

    def test_rejects_a_non_positive_warning_threshold(self) -> None:
        root = self.workspace("2026-09-01T00:00:00Z")
        code, _ = self.run_capturing(
            root, "2026-09-02T00:00:00Z", "--warn-age-days", "0"
        )
        self.assertEqual(code, 1)

    def test_still_fails_past_the_budget_even_though_it_warned_first(self) -> None:
        root = self.workspace("2026-09-01T00:00:00Z")
        code, _ = self.run_capturing(root, "2026-10-02T00:00:00Z")
        self.assertEqual(code, 1)

    def test_default_budget_covers_the_upstream_catalog_freshness_window(self) -> None:
        """A pin must survive until the next re-verification campaign of certigo-content.

        Campaigns are at most `freshness.maxAgeDays` (30) apart upstream, so the default
        budget may not be shorter: exactly 30 days still passes, one second more fails.
        """
        self.assertEqual(check_active_content_age.DEFAULT_MAX_AGE_DAYS, 30)
        self.assertLess(
            check_active_content_age.DEFAULT_WARN_AGE_DAYS,
            check_active_content_age.DEFAULT_MAX_AGE_DAYS,
        )
        root = self.workspace("2026-09-01T00:00:00Z")
        self.assertEqual(self.run_capturing(root, "2026-10-01T00:00:00Z")[0], 0)
        self.assertEqual(self.run_capturing(root, "2026-10-01T00:00:01Z")[0], 1)


if __name__ == "__main__":
    unittest.main()
