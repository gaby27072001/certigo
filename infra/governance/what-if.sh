#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
subscription_id="${AZURE_SUBSCRIPTION_ID:?Set AZURE_SUBSCRIPTION_ID explicitly.}"
location="${AZURE_LOCATION:-westeurope}"
plan_file="$(mktemp)"
trap 'rm -f -- "${plan_file}"' EXIT
chmod 600 "${plan_file}"

az deployment sub what-if \
  --subscription "${subscription_id}" \
  --name certigo-least-privilege-plan \
  --location "${location}" \
  --template-file "${root}/infra/governance/main.bicep" \
  --parameters "${root}/infra/params/least-privilege.bicepparam" \
  --result-format FullResourcePayloads \
  --no-pretty-print \
  --output json > "${plan_file}"

node "${root}/infra/governance/validate-what-if.mjs" \
  --plan "${plan_file}" \
  --subscription "${subscription_id}"
