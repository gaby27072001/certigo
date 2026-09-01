#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
subscription_id="${AZURE_SUBSCRIPTION_ID:?Set AZURE_SUBSCRIPTION_ID explicitly.}"
evidence_dir="${PHASE_B1B_EVIDENCE_DIR:?Set PHASE_B1B_EVIDENCE_DIR.}"
mkdir -p "${evidence_dir}"
chmod 700 "${evidence_dir}"
export PHASE_B_WORK_DIR="${evidence_dir}"
export PHASE_B_STAGE=B1b

bash "${root}/infra/governance/prepare-phase-b.sh"
cp "${evidence_dir}/b1-parameters.json" "${evidence_dir}/parameters.json"
az bicep build \
  --file "${root}/infra/governance/bootstrap-rbac-admin.bicep" \
  --stdout > "${evidence_dir}/compiled-template.json"
az deployment sub what-if \
  --subscription "${subscription_id}" \
  --name certigo-governance-bootstrap-rbac-admin-plan \
  --location "${AZURE_LOCATION:-westeurope}" \
  --template-file "${evidence_dir}/compiled-template.json" \
  --parameters "@${evidence_dir}/parameters.json" \
  --result-format FullResourcePayloads \
  --no-pretty-print \
  --output json > "${evidence_dir}/plan.json"
node "${root}/infra/governance/normalize-principal-types.mjs" \
  "${evidence_dir}/plan.json" \
  "${evidence_dir}/compiled-template.json" \
  "${evidence_dir}/phase-a.json" \
  "${evidence_dir}/normalized-plan.json" \
  "${evidence_dir}/principal-type-provenance.json"
node "${root}/infra/governance/validate-what-if.mjs" \
  --plan "${evidence_dir}/normalized-plan.json" \
  --subscription "${subscription_id}" \
  --phase B1b \
  --phase-a "${evidence_dir}/phase-a.json"
source_commit="$(git -C "${root}" rev-parse HEAD)"
tenant_id="$(az account show --query tenantId --output tsv)"
sources="$(
  printf '%s,' \
    "${root}/infra/governance/bootstrap-rbac-admin.bicep"
  printf '%s' \
    "${root}/infra/governance/modules/managedIdentityOperatorAssignment.bicep"
)"
node "${root}/infra/governance/write-what-if-manifest.mjs" \
  --phase B1b \
  --plan "${evidence_dir}/plan.json" \
  --output "${evidence_dir}/manifest.json" \
  --template "${root}/infra/governance/bootstrap-rbac-admin.bicep" \
  --compiled-template "${evidence_dir}/compiled-template.json" \
  --parameters "${evidence_dir}/parameters.json" \
  --source-root "${root}" \
  --source-commit "${source_commit}" \
  --subscription "${subscription_id}" \
  --tenant "${tenant_id}" \
  --sources "${sources}" \
  --artifact-dir "${evidence_dir}" \
  --phase-a-deployment "${evidence_dir}/phase-a-deployment.json" \
  --phase-a-evidence-manifest "${PHASE_A_EVIDENCE_DIR}/manifest.json" \
  --phase-a-binding "${evidence_dir}/phase-a-binding.json"
sha256sum "${evidence_dir}/manifest.json" > \
  "${evidence_dir}/manifest.sha256"
