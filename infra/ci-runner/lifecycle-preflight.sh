#!/usr/bin/env bash
set -euo pipefail

operation="${1:-}"
if [[ "${operation}" != "start" && "${operation}" != "deallocate" ]]; then
  echo "Usage: lifecycle-preflight.sh <start|deallocate>" >&2
  exit 64
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
subscription_id="${AZURE_SUBSCRIPTION_ID:?Set AZURE_SUBSCRIPTION_ID explicitly.}"
resource_group="${CERTIGO_CI_RESOURCE_GROUP:-rg-certigo-ci}"
vmss_name="${CERTIGO_RUNNER_VMSS:-vmss-certigo-runner-zonal}"
repository="${GITHUB_REPOSITORY:-gchambaud_microsoft/Certigo}"
state_file="${LIFECYCLE_STATE_FILE:-}"

work_dir="$(mktemp -d)"
trap 'rm -rf -- "${work_dir}"' EXIT
chmod 700 "${work_dir}"

if [[ -n "${state_file}" && ! -f "${state_file}" ]]; then
  echo "LIFECYCLE_STATE_FILE must reference an existing read-only state snapshot." >&2
  exit 66
fi

gh api "repos/${repository}/actions/runners" > "${work_dir}/runners.json"
gh api "repos/${repository}/actions/runs?status=queued&per_page=100" \
  > "${work_dir}/queued-runs.json"
gh api "repos/${repository}/actions/runs?status=in_progress&per_page=100" \
  > "${work_dir}/active-runs.json"

az monitor autoscale show \
  --subscription "${subscription_id}" \
  --resource-group "${resource_group}" \
  --name "autoscale-${vmss_name}" \
  --output json > "${work_dir}/autoscale.json"

az vm list \
  --subscription "${subscription_id}" \
  --resource-group "${resource_group}" \
  --show-details \
  --output json > "${work_dir}/virtual-machines.json"

az vmss list \
  --subscription "${subscription_id}" \
  --resource-group "${resource_group}" \
  --output json > "${work_dir}/vm-scale-sets.json"

arguments=(
  --config "${root}/infra/ci-runner/capacity-controller.config.json"
  --operation "${operation}"
  --runners "${work_dir}/runners.json"
  --queued-runs "${work_dir}/queued-runs.json"
  --active-runs "${work_dir}/active-runs.json"
  --autoscale "${work_dir}/autoscale.json"
  --virtual-machines "${work_dir}/virtual-machines.json"
  --vm-scale-sets "${work_dir}/vm-scale-sets.json"
)
if [[ -n "${state_file}" ]]; then
  arguments+=(--state "${state_file}")
fi

node "${root}/infra/ci-runner/evaluate-lifecycle.mjs" "${arguments[@]}"
