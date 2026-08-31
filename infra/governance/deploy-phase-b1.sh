#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
subscription_id="${AZURE_SUBSCRIPTION_ID:?Set AZURE_SUBSCRIPTION_ID explicitly.}"
evidence_dir="${PHASE_B1_EVIDENCE_DIR:?Set PHASE_B1_EVIDENCE_DIR to approved B1 evidence.}"
approval_file="${PHASE_B1_APPROVAL_FILE:?Set PHASE_B1_APPROVAL_FILE to the approval JSON.}"
deployment_name="${PHASE_B1_DEPLOYMENT_NAME:?Set a unique PHASE_B1_DEPLOYMENT_NAME.}"
work_dir="$(mktemp -d)"
trap 'rm -rf -- "${work_dir}"' EXIT

[[ -z "$(git -C "${root}" status --porcelain)" ]]
tenant_id="$(az account show --query tenantId --output tsv)"
export PHASE_B_WORK_DIR="${work_dir}/fresh-binding"
export PHASE_B_STAGE=B1a
bash "${root}/infra/governance/prepare-phase-b.sh"
az bicep build \
  --file "${root}/infra/governance/bootstrap-rbac.bicep" \
  --stdout > "${work_dir}/fresh-compiled-template.json"
cp "${evidence_dir}/compiled-template.json" "${work_dir}/template.json"
cp "${PHASE_B_WORK_DIR}/b1-parameters.json" "${work_dir}/parameters.json"
chmod 400 "${work_dir}/template.json" "${work_dir}/parameters.json"
cmp "${work_dir}/fresh-compiled-template.json" "${work_dir}/template.json"

node "${root}/infra/governance/validate-evidence.mjs" deployment-approval \
  --approval "${approval_file}" \
  --manifest "${evidence_dir}/manifest.json" \
  --plan "${evidence_dir}/plan.json" \
  --parameters "${work_dir}/parameters.json" \
  --compiled-template "${work_dir}/template.json" \
  --phase-a-proof "${PHASE_B_WORK_DIR}/phase-a.json" \
  --phase-a-binding "${PHASE_B_WORK_DIR}/phase-a-binding.json" \
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
[[ "$(sha256sum "${work_dir}/template.json" | cut -d' ' -f1)" == \
  "${expected_template_hash}" ]]
[[ "$(sha256sum "${work_dir}/parameters.json" | cut -d' ' -f1)" == \
  "${expected_parameters_hash}" ]]
az deployment sub create \
  --subscription "${subscription_id}" \
  --name "${deployment_name}" \
  --location "${AZURE_LOCATION:-westeurope}" \
  --template-file "${work_dir}/template.json" \
  --parameters "@${work_dir}/parameters.json"
