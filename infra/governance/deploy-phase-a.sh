#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
subscription_id="${AZURE_SUBSCRIPTION_ID:?Set AZURE_SUBSCRIPTION_ID explicitly.}"
evidence_dir="${PHASE_A_EVIDENCE_DIR:?Set PHASE_A_EVIDENCE_DIR to approved evidence.}"
approval_file="${PHASE_A_APPROVAL_FILE:?Set PHASE_A_APPROVAL_FILE to approval JSON.}"
deployment_name="${PHASE_A_DEPLOYMENT_NAME:?Set a unique PHASE_A_DEPLOYMENT_NAME.}"
work_dir="$(mktemp -d)"
trap 'rm -rf -- "${work_dir}"' EXIT

[[ -z "$(git -C "${root}" status --porcelain)" ]]
tenant_id="$(az account show --query tenantId --output tsv)"
az bicep build \
  --file "${root}/infra/governance/bootstrap-identities.bicep" \
  --stdout > "${work_dir}/fresh-compiled-template.json"
cp "${evidence_dir}/compiled-template.json" "${work_dir}/template.json"
cp "${evidence_dir}/parameters.json" "${work_dir}/parameters.json"
chmod 400 "${work_dir}/template.json" "${work_dir}/parameters.json"
cmp "${work_dir}/fresh-compiled-template.json" "${work_dir}/template.json"

node "${root}/infra/governance/validate-evidence.mjs" deployment-approval \
  --approval "${approval_file}" \
  --manifest "${evidence_dir}/manifest.json" \
  --plan "${evidence_dir}/plan.json" \
  --parameters "${evidence_dir}/parameters.json" \
  --compiled-template "${evidence_dir}/compiled-template.json" \
  --source-root "${root}" \
  --subscription "${subscription_id}" \
  --tenant "${tenant_id}"

expected_template_hash="$(
  node -p "require(process.argv[1]).template.compiledSha256" \
    "${evidence_dir}/manifest.json"
)"
expected_parameters_hash="$(
  node -p "require(process.argv[1]).parameters.sha256" \
    "${evidence_dir}/manifest.json"
)"
[[ "$(node "${root}/infra/governance/evidence-files.mjs" hash \
  "${work_dir}/template.json")" == \
  "${expected_template_hash}" ]]
[[ "$(node "${root}/infra/governance/evidence-files.mjs" hash \
  "${work_dir}/parameters.json")" == \
  "${expected_parameters_hash}" ]]

az deployment sub create \
  --subscription "${subscription_id}" \
  --name "${deployment_name}" \
  --location "${AZURE_LOCATION:-westeurope}" \
  --template-file "${work_dir}/template.json" \
  --parameters "@${work_dir}/parameters.json"
