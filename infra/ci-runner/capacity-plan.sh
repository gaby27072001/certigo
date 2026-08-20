#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
subscription_id="${AZURE_SUBSCRIPTION_ID:?Set AZURE_SUBSCRIPTION_ID explicitly.}"
work_dir="$(mktemp -d)"
trap 'rm -rf -- "${work_dir}"' EXIT
chmod 700 "${work_dir}"

inventory_file="${work_dir}/inventory.json"
state_file="${CAPACITY_STATE_FILE:-}"
event_file="${GITHUB_EVENT_PATH:-}"

if [[ -n "${state_file}" && ! -f "${state_file}" ]]; then
  echo "CAPACITY_STATE_FILE must reference an existing read-only state snapshot." >&2
  exit 66
fi

AZURE_SUBSCRIPTION_ID="${subscription_id}" \
  bash "${root}/infra/governance/inventory.sh" > "${inventory_file}"

node "${root}/infra/ci-runner/reconcile-drift.mjs" \
  --config "${root}/infra/ci-runner/capacity-controller.config.json" \
  --inventory "${inventory_file}" \
  --runner-template "${root}/infra/ci-runner/runner.bicep"

arguments=(
  --config "${root}/infra/ci-runner/capacity-controller.config.json"
  --inventory "${inventory_file}"
)
if [[ -n "${state_file}" ]]; then
  arguments+=(--state "${state_file}")
fi
if [[ -n "${event_file}" ]]; then
  arguments+=(--event "${event_file}")
fi

node "${root}/infra/ci-runner/capacity-controller.mjs" "${arguments[@]}"
