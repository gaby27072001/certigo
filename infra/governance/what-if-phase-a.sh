#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
subscription_id="${AZURE_SUBSCRIPTION_ID:?Set AZURE_SUBSCRIPTION_ID explicitly.}"
location="${AZURE_LOCATION:-westeurope}"
work_dir="$(mktemp -d)"
trap 'rm -rf -- "${work_dir}"' EXIT
chmod 700 "${work_dir}"
plan_file="${work_dir}/plan.json"

az deployment sub what-if \
  --subscription "${subscription_id}" \
  --name certigo-governance-bootstrap-identities-plan \
  --location "${location}" \
  --template-file "${root}/infra/governance/bootstrap-identities.bicep" \
  --parameters "${root}/infra/params/bootstrap-identities.bicepparam" \
  --result-format FullResourcePayloads \
  --no-pretty-print \
  --output json > "${plan_file}"

node "${root}/infra/governance/validate-what-if.mjs" \
  --plan "${plan_file}" \
  --subscription "${subscription_id}" \
  --phase A
