#!/usr/bin/env python3
"""Fail when the pinned certigo-content reference has not been refreshed recently.

The `Generated state equals committed state` gate deliberately receives no secret and
reaches no external repository (docs/GOVERNANCE.md), so it cannot observe
`certigo-content/main`. The content bump is therefore manual, and nothing used to notice
when it stopped happening. This check is the secret-free half of that guarantee: it does
not detect upstream drift, it detects an un-refreshed pin.
"""

from __future__ import annotations

import argparse
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from project_state import (  # noqa: E402
    ACTIVE_CONTENT_REFERENCE_FILE,
    ProjectStateError,
    load_active_content_reference,
)

DEFAULT_MAX_AGE_DAYS = 14


def reference_age(root: Path, now: datetime) -> tuple[str, timedelta]:
    reference = load_active_content_reference(root)
    committed_at = datetime.strptime(
        reference.committed_at, "%Y-%m-%dT%H:%M:%SZ"
    ).replace(tzinfo=timezone.utc)
    if committed_at > now:
        raise ProjectStateError(
            f"{ACTIVE_CONTENT_REFERENCE_FILE}: committedAt {reference.committed_at} is in "
            f"the future relative to {now.strftime('%Y-%m-%dT%H:%M:%SZ')}."
        )
    return reference.revision, now - committed_at


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        metavar="PATH",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="repository workspace to inspect (defaults to this script's repository)",
    )
    parser.add_argument(
        "--max-age-days",
        metavar="DAYS",
        type=int,
        default=DEFAULT_MAX_AGE_DAYS,
        help=f"refresh budget in days (default {DEFAULT_MAX_AGE_DAYS})",
    )
    parser.add_argument(
        "--now",
        metavar="TIMESTAMP",
        help="UTC YYYY-MM-DDTHH:MM:SSZ instant to compare against (defaults to now)",
    )
    args = parser.parse_args(argv)
    try:
        if args.max_age_days < 1:
            raise ProjectStateError("--max-age-days must be a positive number of days.")
        if args.now is None:
            now = datetime.now(timezone.utc).replace(microsecond=0)
        else:
            try:
                now = datetime.strptime(args.now, "%Y-%m-%dT%H:%M:%SZ").replace(
                    tzinfo=timezone.utc
                )
            except ValueError as exc:
                raise ProjectStateError(
                    f"--now: expected UTC YYYY-MM-DDTHH:MM:SSZ, got {args.now!r}."
                ) from exc
        root = args.root.resolve(strict=True)
        revision, age = reference_age(root, now)
    except (OSError, ProjectStateError) as exc:
        print(f"active-content-age: {exc}", file=sys.stderr)
        return 1
    if age > timedelta(days=args.max_age_days):
        print(
            f"active-content-age: {ACTIVE_CONTENT_REFERENCE_FILE} still pins {revision}, "
            f"committed {age.days} days ago (budget {args.max_age_days} days). This does not "
            "prove upstream drift, only that nobody re-ran the documented bump. Follow "
            "docs/GOVERNANCE.md: check out the certigo-content SHA, `npm ci --ignore-scripts` "
            "then `npm run package`, report the revision/timestamp/manifests, and run "
            "`python tools/project_state.py --validate-active-content <checkout>`.",
            file=sys.stderr,
        )
        return 1
    print(
        f"Active content pin {revision} was refreshed {age.days} days ago "
        f"(budget {args.max_age_days} days)."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
