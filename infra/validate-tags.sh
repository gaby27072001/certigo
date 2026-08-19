#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bicep_bin="${BICEP_BIN:-bicep}"
checkov_bin="${CHECKOV_BIN:-checkov}"

command -v "${bicep_bin}" >/dev/null 2>&1 || {
  echo "Bicep CLI is required. Set BICEP_BIN to a pinned executable." >&2
  exit 1
}
command -v "${checkov_bin}" >/dev/null 2>&1 || {
  echo "Checkov is required. Set CHECKOV_BIN to a pinned executable." >&2
  exit 1
}

(
  cd "${root}"
  BICEP_CLI="${bicep_bin}" node --test infra/tests/azure-tag-contract.test.mjs
  "${checkov_bin}" --directory infra --framework bicep --compact --quiet \
    --config-file .checkov.yaml
)

echo "Azure tag contract validation passed."
