#!/usr/bin/env bash
#
# Certigo iOS — le lot de tests, avec son compteur.
#
# ─────────────────────────────────────────────────────────────────────────────
# POURQUOI CE SCRIPT EXISTE PLUTÔT QU'UN SIMPLE `swift test`
#
# `swift test` et `xcodebuild test` rendent le code de retour **0** quand ils
# ne découvrent AUCUN test. Un lot vide et un lot entièrement vert rendent donc
# exactement le même verdict.
#
# Un instrument muet doit échouer, pas rendre zéro.
#
# Ce script vérifie donc trois choses, et pas une seule :
#   1. combien de tests sont DÉCOUVERTS  → au moins le plancher
#   2. combien de tests sont EXÉCUTÉS    → autant que découverts
#   3. le verdict de l'exécution         → vert
#
# Sans la marche 2, un lot pourrait découvrir 54 tests, en exécuter 2, et
# rendre vert.
# ─────────────────────────────────────────────────────────────────────────────
#
# Usage :
#   ./Scripts/verifier-tests.sh
#   ./Scripts/verifier-tests.sh --plancher 40

set -euo pipefail

PLANCHER="${CERTIGO_PLANCHER_TESTS:-50}"

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PAQUET="$RACINE/Packages/CertigoKit"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plancher) PLANCHER="$2"; shift 2 ;;
    *) printf "Option inconnue : %s\n" "$1" >&2; exit 2 ;;
  esac
done

if [[ -t 1 ]]; then
  G=$'\033[0;32m'; R=$'\033[0;31m'; J=$'\033[0;33m'; N=$'\033[0m'
else
  G=""; R=""; J=""; N=""
fi
ok()     { printf "  %s✓%s %s\n" "$G" "$N" "$1"; }
alerte() { printf "  %s!%s %s\n" "$J" "$N" "$1"; }
echec()  { printf "\n%s✗ %s%s\n\n" "$R" "$1" "$N" >&2; exit 1; }

cd "$PAQUET"

# ------------------------------------------------------ 1. tests DÉCOUVERTS --
# Le nom de la sous-commande a changé entre les versions de SwiftPM ; on essaie
# les deux formes avant de renoncer, plutôt que de parier sur une seule.
#
# Le stderr des deux tentatives est CONSERVÉ et non jeté : si les deux échouent,
# c'est lui qui dit pourquoi. Jeter un diagnostic dans /dev/null est exactement
# ce qui a rendu la panne du 2026-09-14 indéchiffrable.
LISTE=""
DIAG_LISTE=""
for _forme in "list" "--list-tests"; do
  set +e
  _sortie="$(swift test "$_forme" 2>&1)"
  _statut=$?
  set -e
  if [[ "$_statut" -eq 0 ]]; then
    LISTE="$_sortie"
    break
  fi
  DIAG_LISTE="$DIAG_LISTE$_sortie"$'\n'
done

# Une ligne de test ressemble à :
#   CertigoKitPackageTests.DesignSystemTests/PrismContrastTests/testFormulaAnchors
DECOUVERTS=0
if [[ -n "$LISTE" ]]; then
  DECOUVERTS="$(grep -c '/' <<<"$LISTE" || true)"
fi

if [[ "$DECOUVERTS" -eq 0 ]]; then
  alerte "L'énumération des tests n'a rien rendu (sous-commande indisponible ?)."
  if [[ -n "$DIAG_LISTE" ]]; then
    printf '  %s\n' "$(printf '%s' "$DIAG_LISTE" | tail -n 3)" >&2
  fi
  alerte "On se rabat sur le comptage des tests EXÉCUTÉS, ci-dessous."
else
  if [[ "$DECOUVERTS" -lt "$PLANCHER" ]]; then
    echec "Seulement $DECOUVERTS tests découverts, plancher à $PLANCHER.
    Un lot qui rétrécit sans que personne ne le décide est une garde qui
    disparaît en silence. Si la baisse est volontaire, abaisser le plancher
    dans ce script — explicitement, dans le même commit."
  fi
  ok "$DECOUVERTS tests découverts (plancher : $PLANCHER)"
fi

# ------------------------------------------------------- 2 et 3. exécution --
JOURNAL="$RACINE/.build/tests.log"
mkdir -p "$RACINE/.build"

set +e
swift test 2>&1 | tee "$JOURNAL"
VERDICT="${PIPESTATUS[0]}"
set -e

# `Executed N tests` apparaît une fois par suite ; le total est le maximum.
EXECUTES="$(grep -oE 'Executed [0-9]+ test' "$JOURNAL" \
  | grep -oE '[0-9]+' \
  | sort -n \
  | tail -n 1 || true)"
EXECUTES="${EXECUTES:-0}"

# Swift Testing, s'il est introduit plus tard, écrit une autre phrase. On la
# reconnaît aussi pour que cette garde survive au changement de cadre de test.
if [[ "$EXECUTES" -eq 0 ]]; then
  EXECUTES="$(grep -oE 'with [0-9]+ test' "$JOURNAL" \
    | grep -oE '[0-9]+' | sort -n | tail -n 1 || true)"
  EXECUTES="${EXECUTES:-0}"
fi

printf "\n"

if [[ "$EXECUTES" -eq 0 ]]; then
  echec "AUCUN test exécuté.
    C'est exactement le cas que ce script existe pour attraper : sans lui,
    \`swift test\` aurait rendu 0 et la chaîne aurait été déclarée verte.
    Journal : $JOURNAL"
fi

if [[ "$EXECUTES" -lt "$PLANCHER" ]]; then
  echec "$EXECUTES tests exécutés, plancher à $PLANCHER.
    Journal : $JOURNAL"
fi

if [[ "$DECOUVERTS" -gt 0 && "$EXECUTES" -lt "$DECOUVERTS" ]]; then
  alerte "$EXECUTES exécutés pour $DECOUVERTS découverts — des tests ont été sautés."
fi

if [[ "$VERDICT" -ne 0 ]]; then
  echec "Des tests ont échoué (code $VERDICT).
    Journal : $JOURNAL"
fi

ok "$EXECUTES tests exécutés, tous verts"
