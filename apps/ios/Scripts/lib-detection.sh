#!/usr/bin/env bash
#
# Certigo iOS — détection d'outils, en fonctions pures et testables.
#
# ─────────────────────────────────────────────────────────────────────────────
# POURQUOI CE FICHIER EXISTE
#
# `demarrer.sh` testait la présence de Xcode ainsi :
#
#     if ! command -v xcodebuild >/dev/null 2>&1; then  ...aide...  fi
#     XCODE_VERSION="$(xcodebuild -version 2>/dev/null | head -n 1 | awk ...)"
#
# **Sur un Mac qui n'a que les Command Line Tools, `/usr/bin/xcodebuild`
# EXISTE.** C'est un relais `xcode-select` qui échoue dès qu'on l'invoque :
#
#     tool 'xcodebuild' requires Xcode, but active developer directory
#     '/Library/Developer/CommandLineTools' is a command line tools instance
#
# Donc, dans l'ordre :
#   1. `command -v` RÉUSSIT — l'aide n'est jamais affichée ;
#   2. `xcodebuild -version` échoue, et `2>/dev/null` **jette la seule ligne
#      qui nommait la cause** ;
#   3. sous `set -euo pipefail`, une affectation dont la substitution échoue
#      **fait sortir le script** — sans un mot.
#
# Le garde-fou testait **l'existence** là où il fallait tester **l'utilisabilité**.
# Il ne pouvait structurellement pas se déclencher sur le cas qu'il visait.
#
# Mesuré sur un vrai MacBook le 2026-09-14 : le script affichait
# « ✓ macOS 26.6.2 (arm64) » puis rendait le prompt. Rien d'autre.
#
# ─────────────────────────────────────────────────────────────────────────────
# RÈGLES DE CE FICHIER
#
#   * aucune fonction n'appelle `exit` — elles rendent un état, l'appelant
#     décide. C'est ce qui les rend testables ;
#   * aucune fonction n'écrit sur la sortie standard — elles remplissent des
#     variables. Un test lit les variables ;
#   * `stderr` de l'outil sondé est **conservé**, jamais jeté : c'est lui qui
#     porte le diagnostic.
#
# Testé par `tools/tests/test_ios_detection.py`, exécuté en CI par
# `ci-project-state.yml` (`unittest discover -s tools/tests`).

# Détecte l'état de Xcode et remplit trois variables globales :
#
#   CERTIGO_XCODE_ETAT     absent | clt | casse | ok
#   CERTIGO_XCODE_VERSION  la version, uniquement si ETAT=ok
#   CERTIGO_XCODE_DIAG     la sortie brute de l'outil quand il a échoué
#
# Les quatre états, et pourquoi ils sont distincts :
#
#   absent — `xcodebuild` n'est nulle part sur le PATH. Remède : installer
#            Xcode.
#   clt    — `xcodebuild` existe mais n'est que le relais des Command Line
#            Tools. **C'est le cas le plus probable sur un Mac neuf**, et son
#            remède diffère : soit Xcode n'est pas installé, soit il l'est mais
#            `xcode-select` pointe ailleurs.
#   casse  — il échoue pour une autre raison (licence non acceptée, installation
#            corrompue). On rend le message tel quel plutôt que de deviner.
#   ok     — il répond, et on a sa version.
#
# Rend toujours 0 : l'échec de l'outil sondé n'est pas l'échec de la sonde.
certigo_detecter_xcode() {
  CERTIGO_XCODE_ETAT=""
  CERTIGO_XCODE_VERSION=""
  CERTIGO_XCODE_DIAG=""

  if ! command -v xcodebuild >/dev/null 2>&1; then
    CERTIGO_XCODE_ETAT="absent"
    return 0
  fi

  local sortie statut avait_e
  case "$-" in
    *e*) avait_e=1 ;;
    *) avait_e=0 ;;
  esac

  # On VEUT observer l'échec, pas le subir : `set -e` est suspendu le temps de
  # la sonde, puis rétabli exactement dans l'état où on l'a trouvé.
  set +e
  # `2>&1` et non `2>/dev/null` : le diagnostic vit sur stderr.
  sortie="$(xcodebuild -version 2>&1)"
  statut=$?
  if [[ "$avait_e" == "1" ]]; then set -e; fi

  if [[ "$statut" -ne 0 ]]; then
    CERTIGO_XCODE_DIAG="$sortie"
    case "$sortie" in
      *"requires Xcode"* | *CommandLineTools*) CERTIGO_XCODE_ETAT="clt" ;;
      *) CERTIGO_XCODE_ETAT="casse" ;;
    esac
    return 0
  fi

  local version
  version="$(printf '%s\n' "$sortie" | head -n 1 | awk '{print $2}')"
  if [[ -z "$version" ]]; then
    # Il a rendu 0 mais rien d'exploitable : anormal, on ne devine pas.
    CERTIGO_XCODE_ETAT="casse"
    CERTIGO_XCODE_DIAG="$sortie"
    return 0
  fi

  CERTIGO_XCODE_ETAT="ok"
  CERTIGO_XCODE_VERSION="$version"
  return 0
}

# Même principe, générique : un outil peut être présent et inutilisable.
#
#   CERTIGO_OUTIL_ETAT     absent | casse | ok
#   CERTIGO_OUTIL_SORTIE   la première ligne rendue, quand ETAT=ok
#   CERTIGO_OUTIL_DIAG     la sortie brute, quand ETAT=casse
#
# Usage :  certigo_detecter_outil xcodegen --version
certigo_detecter_outil() {
  local nom="$1"
  shift

  CERTIGO_OUTIL_ETAT=""
  CERTIGO_OUTIL_SORTIE=""
  CERTIGO_OUTIL_DIAG=""

  if ! command -v "$nom" >/dev/null 2>&1; then
    CERTIGO_OUTIL_ETAT="absent"
    return 0
  fi

  local sortie statut avait_e
  case "$-" in
    *e*) avait_e=1 ;;
    *) avait_e=0 ;;
  esac

  set +e
  sortie="$("$nom" "$@" 2>&1)"
  statut=$?
  if [[ "$avait_e" == "1" ]]; then set -e; fi

  if [[ "$statut" -ne 0 ]]; then
    CERTIGO_OUTIL_ETAT="casse"
    CERTIGO_OUTIL_DIAG="$sortie"
    return 0
  fi

  CERTIGO_OUTIL_ETAT="ok"
  CERTIGO_OUTIL_SORTIE="$(printf '%s\n' "$sortie" | head -n 1)"
  return 0
}
