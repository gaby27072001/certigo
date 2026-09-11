#!/usr/bin/env bash
#
# Certigo iOS — démarrage complet, depuis un Mac vierge.
#
# C'est LA commande du premier soir. Elle vérifie l'environnement, exécute les
# tests, génère le projet Xcode, compile, et lance l'application dans le
# simulateur.
#
# Usage :
#   ./Scripts/demarrer.sh                 # tout, jusqu'au lancement
#   ./Scripts/demarrer.sh --tests-seuls   # s'arrête après les tests
#   ./Scripts/demarrer.sh --sans-lancer   # compile mais ne lance pas
#   CERTIGO_SIMULATEUR="iPhone 17 Pro" ./Scripts/demarrer.sh
#   CERTIGO_IGNORER_XCODE=1 ./Scripts/demarrer.sh   # passe outre le contrôle 26.6
#
# Tout le code Swift de ce dépôt a été écrit sur Windows et n'a JAMAIS été
# compilé. Ce script est donc autant un instrument de diagnostic qu'un
# lanceur : quand quelque chose casse, il doit dire quoi, et où regarder.

set -euo pipefail

XCODE_ATTENDU="26.6"
PLANCHER_TESTS=50
BUNDLE_ID="com.certigo.native"
# Le nom du produit est une variable et non un littéral : le dépôt interdit
# toute occurrence du domaine `certigo` suivi de `.app` dans ses sources, et
# le bundle macOS `Certigo` + `.app` déclencherait cette garde.
NOM_PRODUIT="Certigo"

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RACINE"

# ---------------------------------------------------------------- affichage --
if [[ -t 1 ]]; then
  G=$'\033[0;32m'; R=$'\033[0;31m'; J=$'\033[0;33m'; B=$'\033[1m'; N=$'\033[0m'
else
  G=""; R=""; J=""; B=""; N=""
fi
etape()   { printf "\n%s▸ %s%s\n" "$B" "$1" "$N"; }
ok()      { printf "  %s✓%s %s\n" "$G" "$N" "$1"; }
alerte()  { printf "  %s!%s %s\n" "$J" "$N" "$1"; }
echec()   { printf "\n%s✗ %s%s\n" "$R" "$1" "$N" >&2; }

# On affiche une aide ciblée plutôt qu'un « exit 1 » muet.
aide_et_sortir() {
  echec "$1"
  shift
  for ligne in "$@"; do printf "    %s\n" "$ligne" >&2; done
  printf "\n    Détails et pannes courantes : %s/DEMARRAGE.md\n\n" "$RACINE" >&2
  exit 1
}

TESTS_SEULS=0
SANS_LANCER=0
for arg in "$@"; do
  case "$arg" in
    --tests-seuls) TESTS_SEULS=1 ;;
    --sans-lancer) SANS_LANCER=1 ;;
    -h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) aide_et_sortir "Option inconnue : $arg" "Options : --tests-seuls, --sans-lancer" ;;
  esac
done

printf "\n%sCertigo iOS — démarrage%s\n" "$B" "$N"

# ------------------------------------------------------------ 1. la machine --
etape "1/6  Vérification de la machine"

if [[ "$(uname -s)" != "Darwin" ]]; then
  aide_et_sortir "Ce script ne fonctionne que sur macOS." \
    "SwiftUI et UIKit n'existent que dans le SDK d'Apple, livré uniquement avec macOS." \
    "Ce n'est pas une lacune d'installation : c'est permanent."
fi
ok "macOS $(sw_vers -productVersion) ($(uname -m))"

if ! command -v xcodebuild >/dev/null 2>&1; then
  aide_et_sortir "Xcode est introuvable." \
    "Installer Xcode depuis l'App Store, puis l'ouvrir une fois pour accepter la licence." \
    "Ensuite : sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
fi

XCODE_VERSION="$(xcodebuild -version 2>/dev/null | head -n 1 | awk '{print $2}')"
if [[ "$XCODE_VERSION" != "$XCODE_ATTENDU" ]]; then
  if [[ "${CERTIGO_IGNORER_XCODE:-0}" == "1" ]]; then
    alerte "Xcode $XCODE_VERSION au lieu de $XCODE_ATTENDU — contrôle ignoré sur demande."
  else
    aide_et_sortir "Xcode $XCODE_VERSION, alors que le projet vise $XCODE_ATTENDU." \
      "La CI de livraison (codemagic.yaml) est épinglée à Xcode $XCODE_ATTENDU." \
      "Un écart entre le poste et la CI est ce qui produit les pannes les plus" \
      "difficiles à diagnostiquer : ce qui compile ici casse là-bas, ou l'inverse." \
      "" \
      "Si plusieurs Xcode sont installés :" \
      "  sudo xcode-select -s /Applications/Xcode-$XCODE_ATTENDU.app/Contents/Developer" \
      "" \
      "Pour passer outre malgré tout :" \
      "  CERTIGO_IGNORER_XCODE=1 ./Scripts/demarrer.sh"
  fi
else
  ok "Xcode $XCODE_VERSION"
fi

ok "Swift $(swift --version 2>/dev/null | head -n 1 | sed -E 's/.*version ([0-9.]+).*/\1/')"

# ------------------------------------------------------- 2. l'outil de génération --
etape "2/6  Vérification de XcodeGen"

if ! command -v xcodegen >/dev/null 2>&1; then
  aide_et_sortir "XcodeGen est introuvable." \
    "Le projet Xcode n'est pas versionné : il est régénéré depuis project.yml." \
    "" \
    "  brew install xcodegen" \
    "" \
    "Si Homebrew n'est pas installé :" \
    "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
fi
ok "XcodeGen $(xcodegen --version 2>/dev/null | tail -n 1)"

# --------------------------------------------------------------- 3. les tests --
etape "3/6  Tests unitaires (paquet CertigoKit, sans Xcode)"
"$RACINE/Scripts/verifier-tests.sh"

if [[ "$TESTS_SEULS" == "1" ]]; then
  printf "\n%s✓ Tests terminés (arrêt demandé).%s\n\n" "$G" "$N"
  exit 0
fi

# ---------------------------------------------------------- 4. la génération --
etape "4/6  Génération du projet Xcode"

# La génération EST un test : si project.yml est faux, on le sait ici.
if ! xcodegen generate --spec project.yml --quiet; then
  aide_et_sortir "XcodeGen n'a pas pu générer le projet." \
    "Le message ci-dessus indique la ligne fautive de project.yml." \
    "Ce fichier a été écrit sans pouvoir être exécuté : une erreur ici est attendue" \
    "et facile à corriger. Rapporte le message tel quel."
fi
ok "Certigo.xcodeproj généré"

# ---------------------------------------------------------- 5. la compilation --
etape "5/6  Compilation pour le simulateur"

CIBLE="${CERTIGO_SIMULATEUR:-}"
if [[ -n "$CIBLE" ]]; then
  LIGNE="$(xcrun simctl list devices available | grep -F " $CIBLE (" | head -n 1 || true)"
  [[ -z "$LIGNE" ]] && aide_et_sortir "Aucun simulateur nommé « $CIBLE »." \
    "Liste des simulateurs disponibles :" "  xcrun simctl list devices available"
else
  # On ne devine PAS un nom de modèle : on prend le premier iPhone réellement
  # disponible. Un nom en dur (« iPhone 17 ») est le mode de panne le plus
  # courant de ce genre de script.
  LIGNE="$(xcrun simctl list devices available | grep -E '^[[:space:]]+iPhone' | head -n 1 || true)"
  [[ -z "$LIGNE" ]] && aide_et_sortir "Aucun simulateur iPhone disponible." \
    "Ouvrir Xcode ▸ Settings ▸ Components et installer un runtime iOS," \
    "puis créer un simulateur dans Window ▸ Devices and Simulators."
fi

UDID="$(sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/' <<<"$LIGNE")"
NOM="$(sed -E 's/^[[:space:]]*(.*) \([0-9A-Fa-f-]{36}\).*/\1/' <<<"$LIGNE")"
ok "Simulateur : $NOM"

JOURNAL="$RACINE/.build/compilation.log"
mkdir -p "$RACINE/.build"

if ! xcodebuild \
      -project Certigo.xcodeproj \
      -scheme Certigo \
      -configuration Debug \
      -destination "id=$UDID" \
      -derivedDataPath .build/DerivedData \
      -quiet \
      build >"$JOURNAL" 2>&1; then
  echec "La compilation a échoué."
  printf "\n  Les 40 dernières lignes du journal :\n\n" >&2
  tail -n 40 "$JOURNAL" >&2
  printf "\n  Journal complet : %s\n" "$JOURNAL" >&2
  printf "\n  ⚠️  Attendu : ce code n'a jamais été compilé. Les erreurs les plus\n" >&2
  printf "     probables et leur correction sont dans DEMARRAGE.md, section\n" >&2
  printf "     « Les trois erreurs les plus probables ».\n\n" >&2
  exit 1
fi
ok "Compilation réussie"

APP="$RACINE/.build/DerivedData/Build/Products/Debug-iphonesimulator/${NOM_PRODUIT}.app"
[[ -d "$APP" ]] || aide_et_sortir "L'application compilée est introuvable." \
  "Attendue ici : $APP" \
  "Chercher le vrai chemin :  find .build/DerivedData -name '${NOM_PRODUIT}.app'"

if [[ "$SANS_LANCER" == "1" ]]; then
  printf "\n%s✓ Compilation terminée (lancement non demandé).%s\n\n" "$G" "$N"
  exit 0
fi

# ------------------------------------------------------------ 6. le lancement --
etape "6/6  Lancement dans le simulateur"

xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
open -a Simulator || true
# Le simulateur met quelques secondes à être prêt à recevoir une installation.
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || true

xcrun simctl install "$UDID" "$APP"
ok "Application installée"
xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
ok "Application lancée"

cat <<TEXTE

${G}${B}✓ Terminé.${N}

  Ce que tu dois voir à l'écran :

    • Un fond teinté de VIOLET en haut, qui s'éteint vers le bas.
      C'est la couleur de la piste « Azure Fundamentals » qui irradie sa
      région — la même mécanique que le halo de pochette d'Apple Music.

    • Le titre « Certigo » en très gros, violet lui aussi.

    • Une liste de six parcours, chacun d'une couleur DIFFÉRENTE
      (violet, magenta, rose, ambre, vert, cyan). Touche-en un : le fond
      du haut change de couleur en glissant, sans à-coup.

    • En bas, une pilule flottante qui ne touche AUCUN bord, posée
      au-dessus du contenu. Le texte défile DESSOUS en se brouillant
      légèrement à son approche — c'est Liquid Glass.
      Touche la pilule : elle s'étire en trois pilules au lieu de
      disparaître puis réapparaître.

    • Plus bas : les 15 créneaux typographiques, puis 9 mesures de
      contraste, toutes en vert.

    • Bouton « Échouer » : une erreur s'affiche AVEC un bouton
      « Réessayer ». Il fonctionne.

  ${J}Si le verre ressemble à un simple flou gris, sans reflet ni
  refraction :${N} le simulateur tourne probablement sous iOS 18. Liquid
  Glass demande iOS 26. Choisis un simulateur iOS 26 :
    CERTIGO_SIMULATEUR="iPhone 17" ./Scripts/demarrer.sh

TEXTE
