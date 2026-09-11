#!/usr/bin/env bash
#
# Certigo iOS — la preuve que le lot de tests MORD.
#
# ─────────────────────────────────────────────────────────────────────────────
# Un lot de tests entièrement vert ne prouve rien tant qu'on n'a pas vu un test
# échouer. C'est la seule façon de distinguer « tout passe » de « rien ne
# s'exécute ».
#
# Ce script :
#   1. injecte un test volontairement faux,
#   2. exige que le lot rougisse,
#   3. retire le test,
#   4. exige que le lot redevienne vert.
#
# Le fichier injecté est supprimé quoi qu'il arrive, même en cas d'interruption.
# Aucune trace n'est laissée dans le dépôt.
# ─────────────────────────────────────────────────────────────────────────────
#
# Usage :  ./Scripts/prouver-le-rouge.sh

set -euo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PAQUET="$RACINE/Packages/CertigoKit"
TEMOIN="$PAQUET/Tests/NavigationTests/TemoinRougeTemporaire.swift"

if [[ -t 1 ]]; then
  G=$'\033[0;32m'; R=$'\033[0;31m'; B=$'\033[1m'; N=$'\033[0m'
else
  G=""; R=""; B=""; N=""
fi

nettoyer() { rm -f "$TEMOIN"; }
trap nettoyer EXIT INT TERM

if [[ -e "$TEMOIN" ]]; then
  printf "%s✗ %s existe déjà. Le supprimer avant de relancer.%s\n" "$R" "$TEMOIN" "$N" >&2
  exit 1
fi

printf "\n%sPreuve du rouge — le lot de tests mord-il ?%s\n" "$B" "$N"

# ------------------------------------------------------------ 1. le rouge ----
printf "\n▸ 1/4  Injection d'un test volontairement faux\n"
cat >"$TEMOIN" <<'SWIFT'
// FICHIER TEMPORAIRE — créé et supprimé par Scripts/prouver-le-rouge.sh.
// S'il est encore là, c'est que le script a été interrompu : le supprimer.

import XCTest

@testable import Navigation

final class TemoinRougeTemporaire: XCTestCase {
    /// Faux exprès. Si ce test PASSE, c'est que rien ne s'exécute.
    func testCeTestDoitEchouer() {
        XCTAssertEqual(
            Destination.allCases.count, 999,
            "Témoin volontaire : si tu lis ce message, le lot de tests mord bien."
        )
    }
}
SWIFT
printf "  Créé : %s\n" "${TEMOIN#"$RACINE"/}"

printf "\n▸ 2/4  Exécution — le lot DOIT rougir\n"
cd "$PAQUET"
if swift test >/dev/null 2>&1; then
  printf "\n%s✗ ÉCHEC DE LA PREUVE.%s\n" "$R" "$N" >&2
  cat >&2 <<'TEXTE'

    Un test volontairement faux est PASSÉ. Cela signifie que les tests ne
    s'exécutent pas réellement : le lot est un instrument muet.

    C'est un défaut plus grave qu'un test qui échoue, parce qu'il est
    invisible. Ne pas continuer tant qu'il n'est pas compris.

TEXTE
  exit 1
fi
printf "  %s✓%s Le lot a rougi, comme attendu.\n" "$G" "$N"

# ------------------------------------------------------------ 2. le vert -----
printf "\n▸ 3/4  Retrait du témoin\n"
nettoyer
trap - EXIT INT TERM
printf "  Supprimé.\n"

printf "\n▸ 4/4  Exécution — le lot DOIT redevenir vert\n"
if ! "$RACINE/Scripts/verifier-tests.sh"; then
  printf "\n%s✗ Le lot ne redevient pas vert après retrait du témoin.%s\n" "$R" "$N" >&2
  printf "    Vérifier que %s a bien été supprimé.\n\n" "$TEMOIN" >&2
  exit 1
fi

printf "\n%s%s✓ Preuve faite : le lot de tests distingue le vrai du faux.%s\n\n" "$G" "$B" "$N"
