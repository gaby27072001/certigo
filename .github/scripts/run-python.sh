#!/usr/bin/env bash
set -euo pipefail

if (($# == 0)); then
  echo "Usage: run-python.sh <python-arguments...>" >&2
  exit 64
fi

python_arguments=("$@")

canonical_path() {
  local target="$1"
  local directory link

  while [[ -L "${target}" ]]; do
    directory="${target%/*}"
    [[ "${directory}" == "${target}" ]] && directory="."
    link="$(readlink -- "${target}")" || return 1
    if [[ "${link}" == /* ]]; then
      target="${link}"
    else
      target="${directory}/${link}"
    fi
  done

  directory="${target%/*}"
  [[ "${directory}" == "${target}" ]] && directory="."
  directory="$(cd -P -- "${directory}" && pwd)" || return 1
  printf '%s/%s\n' "${directory}" "${target##*/}"
}

try_launcher() {
  local command_name="$1"
  shift
  local -a launcher_arguments=("$@")
  local resolved canonical untrusted_root

  resolved="$(type -P -- "${command_name}" 2>/dev/null || true)"
  [[ -n "${resolved}" ]] || return 1

  canonical="$(canonical_path "${resolved}")" || {
    echo "::error::Cannot resolve Python launcher ${resolved}." >&2
    exit 126
  }

  if [[ -n "${UNTRUSTED_SOURCE_DIR:-}" ]]; then
    untrusted_root="$(canonical_path "${UNTRUSTED_SOURCE_DIR}")" || {
      echo "::error::Cannot resolve untrusted source directory." >&2
      exit 126
    }
    case "${canonical}" in
      "${untrusted_root}" | "${untrusted_root}"/*)
        echo "::error::Refusing Python launcher from untrusted source: ${canonical}" >&2
        exit 126
        ;;
    esac
  fi

  if ! "${canonical}" "${launcher_arguments[@]}" -P -c \
    'import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)' \
    >/dev/null 2>&1; then
    echo "::warning::Ignoring ${canonical}: Python 3.11+ safe-path mode is unavailable." >&2
    return 1
  fi

  echo "Using Python launcher: ${canonical}" >&2
  exec "${canonical}" "${launcher_arguments[@]}" -P "${python_arguments[@]}"
}

try_launcher python3 || true
try_launcher python || true
try_launcher py -3 || true

echo "::error::Python 3.11+ with safe-path mode is required; tried python3, python, and py -3." >&2
exit 127
