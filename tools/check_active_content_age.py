#!/usr/bin/env python3
"""Fail when the pinned certigo-content reference has not been refreshed recently.

The `Generated state equals committed state` gate deliberately receives no secret and
reaches no external repository (docs/GOVERNANCE.md), so it cannot observe
`certigo-content/main`. The content bump is therefore manual, and nothing used to notice
when it stopped happening. This check is the secret-free half of that guarantee: it does
not detect upstream drift, it detects an un-refreshed pin.

Deux limites de ce budget, mesurées le 2026-09-11, à lire avant de l'ajuster.

1. **Le budget suit la cadence de revérification amont (révisé le 2026-09-24).** Jusqu'au
   2026-09-24, il valait 14 jours sans aucune borne : rien ne justifiait 14 plutôt que 10
   ou 30. Il est désormais aligné, au sens de docs/GOVERNANCE.md, section « Un nombre qui
   décide s'écrit avec le mécanisme qui le contraint », sur les trois éléments suivants.
   - **Borne respectée** : un pin ne peut avancer qu'après une publication de
     `certigo-content` (point 2 ci-dessous). Or une publication suit une campagne de
     revérification des sources, et ces campagnes sont espacées d'au plus
     `freshness.maxAgeDays` = 30 jours : au-delà, `npm run catalog:freshness` fait échouer
     la CI de `certigo-content`. Ce budget doit donc couvrir au moins cet intervalle, sinon
     il expire entre deux publications légitimes. Mesuré le 2026-09-23 : avec 14 jours, la
     release R2 (commit du 2026-09-23T19:28:45Z) expirait le 2026-10-07, soit deux semaines
     avant la campagne suivante, prévue le 2026-10-21.
   - **Marge** : l'âge part de la date du commit de campagne, qui est égale ou postérieure
     au `asOf` du catalogue. Le pin reste donc valide jusqu'au `reviewDueOn` de ce
     catalogue, au moins. La marge réelle est le temps entre la campagne suivante et ce
     `reviewDueOn`, qui doit suffire à publier, avec le feu vert de Gabriel, puis à
     déclarer.
   - **Où la borne est définie** : `freshness.maxAgeDays` et `freshness.reviewDueOn` dans
     `content/public/catalog/certifications.json` de `gchambaud_microsoft/certigo-content`.
     Si cette valeur change, relire ce budget.

2. **Le bump que ce budget réclame n'est pas toujours jouable depuis ce dépôt.** Il n'est
   légitime qu'*après* une publication côté `certigo-content` :
   `tools/check_published_content_release.py` compare le pin à la release **publiée**
   dans le stockage immuable, pas à `certigo-content/main`. Avancer le pin sur une
   révision non encore publiée fait donc rougir *cette* comparaison-là. Ce budget peut
   par conséquent expirer sans qu'aucun geste de ce dépôt puisse le refermer, et
   l'avertissement progressif ci-dessous existe pour que ce cas se voie avant le mur.
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

DEFAULT_MAX_AGE_DAYS = 30
# Seuil d'avertissement : en deçà du mur, la sortie reste verte (code 0) mais
# annonce l'échéance. Motif : ce budget échoue sur un fait qui n'est pas causé
# par la PR qui le subit, donc son expiration se présente comme une panne
# généralisée — toutes les PR en vol rougissent le même jour sur un contrôle
# étranger à leur contenu, et la recherche d'une cause commune inexistante coûte
# plus cher que le bump lui-même. L'avertissement transforme ce mur en pente.
# Sept jours de préavis (30 - 7 = 23) : la veille de fraîcheur, hebdomadaire,
# voit donc au moins une fois l'avertissement avant le mur.
DEFAULT_WARN_AGE_DAYS = 23


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
        "--warn-age-days",
        metavar="DAYS",
        type=int,
        default=DEFAULT_WARN_AGE_DAYS,
        help=(
            "age in days above which the pin is reported as nearing expiry while still "
            f"passing (default {DEFAULT_WARN_AGE_DAYS}); must stay below --max-age-days"
        ),
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
        if args.warn_age_days < 1:
            raise ProjectStateError("--warn-age-days must be a positive number of days.")
        if args.warn_age_days >= args.max_age_days:
            raise ProjectStateError(
                f"--warn-age-days ({args.warn_age_days}) must stay below --max-age-days "
                f"({args.max_age_days}); otherwise the warning band is empty and the "
                "budget is a wall again."
            )
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
    if age > timedelta(days=args.warn_age_days):
        remaining = args.max_age_days - age.days
        print(
            f"::warning::active-content-age: {ACTIVE_CONTENT_REFERENCE_FILE} pins {revision}, "
            f"committed {age.days} days ago. It expires in {remaining} day(s) (budget "
            f"{args.max_age_days} days), after which THIS CHECK FAILS ON EVERY BRANCH AT ONCE "
            "for a reason unrelated to any individual change. Re-run the documented bump now "
            "(docs/GOVERNANCE.md). If certigo-content has not published a new release yet, the "
            "bump is not yet legitimate: say so on the tracking issue rather than waiting for "
            "the wall, because no action in this repository can close the budget in that case."
        )
    print(
        f"Active content pin {revision} was refreshed {age.days} days ago "
        f"(budget {args.max_age_days} days)."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
