#!/bin/bash
# certigo-approve — approuver, depuis le Mac de Gabriel, un changement « scellé » de Certigo.
#
# L'outil ne fait confiance ni à la PR ni aux agents : il récupère lui-même `main` et la tête de
# la PR sur GitHub, calcule les empreintes, montre le diff complet, puis signe avec la clé qui ne
# quitte pas le Mac (Secretive : Touch ID à chaque signature). Il n'écrit rien dans le dépôt et
# ne pousse rien. Mode d'emploi : docs/runbooks/APPROBATION_SCELLEE.md.
#
# Compatible avec le bash 3.2 de macOS.
set -euo pipefail

readonly NAMESPACE='certigo-sealed-approval-v1'
readonly REPOSITORY='gchambaud_microsoft/Certigo'
readonly SIGNERS_PATH='.github/sealed-approvers/allowed_signers'
readonly APPROVALS_DIR='.github/sealed-approvals'
readonly SELF_PATH='tools/certigo-approve.sh'
readonly PATH_PATTERN='^[A-Za-z0-9._@+-]+(/[A-Za-z0-9._@+-]+)*$'
readonly SECRETIVE_SOCKET="$HOME/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh"
KEY_FILE="${CERTIGO_APPROVAL_KEY:-$HOME/.ssh/certigo-approval.pub}"
KEY_TYPE=''
KEY_DATA=''
BASE=''
WORK=''

usage() {
  cat <<'USAGE'
Usage :
  certigo-approve cle                 affiche ta clé à enrôler et son empreinte
  certigo-approve verifier            vérifie que main porte bien ta clé
  certigo-approve <PR> [--jours N]    signe l'approbation de la PR (N : 1 à 30, défaut 14)
USAGE
  exit 2
}

die() {
  printf '\n⛔ %s\n' "$*" >&2
  exit 1
}

cleanup() {
  if [ -n "$WORK" ]; then
    rm -rf "$WORK"
  fi
}
trap cleanup EXIT

sha256_stdin() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | cut -d' ' -f1
  else
    shasum -a 256 | cut -d' ' -f1
  fi
}

use_signing_agent() {
  local agent="${CERTIGO_APPROVAL_AGENT:-}"
  if [ -z "$agent" ] && [ -S "$SECRETIVE_SOCKET" ]; then
    agent="$SECRETIVE_SOCKET"
  fi
  if [ -n "$agent" ]; then
    export SSH_AUTH_SOCK="$agent"
  fi
}

require_repository() {
  command -v git >/dev/null 2>&1 || die "git est introuvable."
  command -v ssh-keygen >/dev/null 2>&1 || die "ssh-keygen est introuvable."
  git rev-parse --show-toplevel >/dev/null 2>&1 \
    || die "Lance certigo-approve depuis ta copie du dépôt Certigo (par exemple : cd ~/Certigo)."
  case "$(git remote get-url origin 2>/dev/null || true)" in
    *"$REPOSITORY" | *"$REPOSITORY.git" | *"$REPOSITORY/") ;;
    *) die "Le dépôt courant n'est pas $REPOSITORY (remote origin)." ;;
  esac
}

require_key() {
  [ -f "$KEY_FILE" ] || die "Clé publique introuvable : $KEY_FILE (voir l'étape 1 du guide)."
  KEY_TYPE="$(awk 'NR == 1 { print $1 }' "$KEY_FILE")"
  KEY_DATA="$(awk 'NR == 1 { print $2 }' "$KEY_FILE")"
  case "$KEY_TYPE" in
    ecdsa-sha2-nistp256 | ecdsa-sha2-nistp384 | ssh-ed25519) ;;
    *) die "Type de clé « $KEY_TYPE » non pris en charge : crée une clé Secretive (ecdsa-sha2-nistp256)." ;;
  esac
  [ -n "$KEY_DATA" ] || die "$KEY_FILE ne contient pas de clé publique."
}

fetch_main() {
  git fetch --quiet --no-tags origin '+refs/heads/main:refs/certigo-approve/main' \
    || die "Impossible de récupérer main depuis GitHub."
  BASE="$(git rev-parse --verify --quiet 'refs/certigo-approve/main^{commit}')" \
    || die "main est introuvable après le fetch."
}

main_signers() {
  git cat-file blob "$BASE:$SIGNERS_PATH" > "$1" 2>/dev/null \
    || die "main ne porte encore aucune clé enrôlée ($SIGNERS_PATH)."
}

# Principal enrôlé sur main pour TA clé ; vide si elle n'y est pas.
enrolled_principal() {
  awk -v ns="namespaces=\"$NAMESPACE\"" -v t="$KEY_TYPE" -v k="$KEY_DATA" \
    '$0 !~ /^#/ && $2 == ns && $3 == t && $4 == k { print $1; exit }' "$1"
}

fingerprint_of() {
  ssh-keygen -lf "$1" | awk '{ print $2 }'
}

refuse_outdated_tool() {
  if git cat-file -e "$BASE:$SELF_PATH" 2>/dev/null \
    && ! git cat-file blob "$BASE:$SELF_PATH" | cmp -s - "$0"; then
    die "Cette copie de certigo-approve diffère de celle de main. Fais « git switch main && git pull --ff-only », puis relance."
  fi
}

command_key() {
  require_key
  printf "Ta clé d'approbation : %s\n\n" "$(fingerprint_of "$KEY_FILE")"
  printf "Ligne à donner à l'agent pour l'enrôler (elle ne contient aucun secret) :\n\n"
  printf 'gabriel@certigo-approval namespaces="%s" %s %s\n\n' "$NAMESPACE" "$KEY_TYPE" "$KEY_DATA"
  printf "Compare l'empreinte SHA256 ci-dessus avec celle que montre Secretive : elles doivent être identiques.\n"
}

command_verify() {
  require_repository
  require_key
  fetch_main
  WORK="$(mktemp -d)"
  main_signers "$WORK/allowed_signers"
  printf 'Clés enrôlées sur main (%s) :\n' "$(git rev-parse --short "$BASE")"
  local line index=0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in '' | '#'*) continue ;; esac
    index=$((index + 1))
    printf '%s\n' "$line" | awk '{ print $3, $4 }' > "$WORK/key-$index.pub"
    printf '  %-28s %s\n' "$(printf '%s\n' "$line" | awk '{ print $1 }')" "$(fingerprint_of "$WORK/key-$index.pub")"
  done < "$WORK/allowed_signers"
  printf '\nTa clé :                       %s\n' "$(fingerprint_of "$KEY_FILE")"
  local principal
  principal="$(enrolled_principal "$WORK/allowed_signers")"
  [ -n "$principal" ] \
    || die "ALERTE : ta clé n'est PAS enrôlée sur main. Ne signe rien et préviens l'orchestrateur."
  printf '\n✅ main porte bien ta clé (principal %s).\n' "$principal"
}

digest_at() {
  local rev="$1" file="$2" mode
  mode="$(git ls-tree "$rev" -- "$file" | awk '{ print $1 }')"
  if [ -z "$mode" ]; then
    printf 'absent'
    return 0
  fi
  case "$mode" in
    100644 | 100755) git cat-file blob "$rev:$file" | sha256_stdin ;;
    *) return 1 ;;
  esac
}

command_sign() {
  local pr="$1" days="$2"
  case "$pr" in '' | 0* | *[!0-9]*) die "Numéro de PR invalide : $pr" ;; esac
  case "$days" in '' | 0* | *[!0-9]*) die "--jours doit être un nombre entier de 1 à 30." ;; esac
  [ "$days" -ge 1 ] && [ "$days" -le 30 ] || die "--jours doit être compris entre 1 et 30."
  require_repository
  require_key
  fetch_main
  refuse_outdated_tool
  git fetch --quiet --no-tags origin "+refs/pull/$pr/head:refs/certigo-approve/pr-$pr" \
    || die "Impossible de récupérer la PR #$pr depuis GitHub."
  local head
  head="$(git rev-parse --verify --quiet "refs/certigo-approve/pr-$pr^{commit}")" \
    || die "La tête de la PR #$pr est introuvable."
  git merge-base --is-ancestor "$BASE" "$head" \
    || die "La PR #$pr n'est pas à jour avec main : demande à l'agent de la mettre à jour, puis relance."

  WORK="$(mktemp -d)"
  main_signers "$WORK/allowed_signers"
  local principal
  principal="$(enrolled_principal "$WORK/allowed_signers")"
  [ -n "$principal" ] \
    || die "ALERTE : ta clé n'est pas enrôlée sur main. Ne signe rien et lance « certigo-approve verifier »."

  : > "$WORK/changes"
  : > "$WORK/skipped"
  local file from to
  while IFS= read -r -d '' file; do
    case "$file" in
      "$APPROVALS_DIR"/*) continue ;;
      *.bat | *.cmd) printf '%s\n' "$file" >> "$WORK/skipped"; continue ;;
    esac
    if ! printf '%s\n' "$file" | grep -Eq "$PATH_PATTERN"; then
      printf '%s\n' "$file" >> "$WORK/skipped"
      continue
    fi
    from="$(digest_at "$BASE" "$file")" || die "$file : lien ou sous-module sur main, impossible à approuver."
    to="$(digest_at "$head" "$file")" || die "$file : lien ou sous-module dans la PR, impossible à approuver."
    printf 'change %s %s %s\n' "$file" "$from" "$to" >> "$WORK/changes"
  done < <(git diff --name-only --no-renames -z "$BASE" "$head")
  [ -s "$WORK/changes" ] || die "La PR #$pr ne modifie aucun fichier à approuver."

  local expires
  expires="$(date -u -v+"${days}"d +%Y-%m-%d 2>/dev/null || date -u -d "+${days} days" +%Y-%m-%d)"
  {
    printf '%s\n' "$NAMESPACE" "repository $REPOSITORY" "expires $expires"
    LC_ALL=C sort "$WORK/changes"
  } > "$WORK/message"

  printf '\n══ PR #%s — %s\n' "$pr" "$(git log -1 --format=%s "$head")"
  printf '   main %s  →  PR %s\n\n' "$(git rev-parse --short "$BASE")" "$(git rev-parse --short "$head")"
  git --no-pager diff --stat --no-renames "$BASE" "$head"
  printf "\nLe diff complet va s'afficher (touche q pour quitter). Lis-le en entier.\n"
  git --paginate diff --no-renames "$BASE" "$head" || true
  if [ -s "$WORK/skipped" ]; then
    printf '\nNon couverts par la signature (ils ne peuvent pas être protégés) :\n'
    sed 's/^/  /' "$WORK/skipped"
  fi
  printf "\nTu vas approuver, jusqu'au %s inclus (UTC), exactement ceci :\n\n" "$expires"
  sed 's/^/  /' "$WORK/message"
  printf '\nApprouver exactement ce changement ? Tape « oui » pour signer : '
  local answer=''
  IFS= read -r answer || true
  [ "$answer" = 'oui' ] || die "Rien n'a été signé."

  use_signing_agent
  printf "\nTouch ID va être demandé : c'est la signature. Ne l'accepte que maintenant.\n"
  ssh-keygen -Y sign -q -n "$NAMESPACE" -f "$KEY_FILE" "$WORK/message" \
    || die "La signature a échoué (Secretive est-il ouvert ? Touch ID refusé ?)."
  ssh-keygen -Y verify -f "$WORK/allowed_signers" -I "$principal" -n "$NAMESPACE" \
    -s "$WORK/message.sig" < "$WORK/message" >/dev/null 2>&1 \
    || die "La signature ne se vérifie pas avec la clé enrôlée sur main : n'envoie rien."

  local output="$HOME/certigo-approval-pr-$pr.approval"
  cat "$WORK/message" "$WORK/message.sig" > "$output"
  printf '\n✅ Approbation signée et vérifiée. Enregistrée dans : %s\n' "$output"
  if command -v pbcopy >/dev/null 2>&1 && pbcopy < "$output"; then
    printf '   Elle est aussi dans le presse-papiers.\n'
  fi
  printf '\nColle ce bloc dans un commentaire de la PR #%s (il ne contient aucun secret) :\n\n' "$pr"
  cat "$output"
}

case "${1:-}" in
  cle) command_key ;;
  verifier) command_verify ;;
  '' | -h | --help | aide) usage ;;
  *)
    pr="$1"
    days=14
    shift
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --jours) [ "$#" -ge 2 ] || usage; days="$2"; shift 2 ;;
        --jours=*) days="${1#--jours=}"; shift ;;
        *) usage ;;
      esac
    done
    command_sign "$pr" "$days"
    ;;
esac
