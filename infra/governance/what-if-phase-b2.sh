#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
subscription_id="${AZURE_SUBSCRIPTION_ID:?Set AZURE_SUBSCRIPTION_ID explicitly.}"
evidence_dir="${PHASE_B2_EVIDENCE_DIR:?Set PHASE_B2_EVIDENCE_DIR.}"
mkdir -p "${evidence_dir}"
chmod 700 "${evidence_dir}"
exec > "${evidence_dir}/stdout.log" 2> "${evidence_dir}/stderr.log"
export PHASE_B_WORK_DIR="${evidence_dir}"
export PHASE_B_STAGE=B2

finalize() {
  status=$?
  trap - EXIT
  printf '%s\n' "${status}" > "${evidence_dir}/exit-code.txt"
  printf '{"schemaVersion":1,"phase":"B2","exitCode":%s,"deploymentExecuted":false}\n' \
    "${status}" > "${evidence_dir}/metadata.json"
  source_commit="$(git -C "${root}" rev-parse HEAD)"
  tenant_id="$(az account show --query tenantId --output tsv 2>/dev/null || true)"
  manifest_args=(
    node "${root}/infra/governance/write-what-if-manifest.mjs"
      --phase B2 \
      --plan "${evidence_dir}/plan.json" \
      --output "${evidence_dir}/manifest.json" \
      --template \
        "${root}/infra/governance/modules/contentPlanExternalJoinAssignments.bicep" \
      --compiled-template "${evidence_dir}/compiled-template.json" \
      --parameters "${evidence_dir}/parameters.json" \
      --source-root "${root}" \
      --source-commit "${source_commit}" \
      --subscription "${subscription_id}" \
      --tenant "${tenant_id}" \
      --sources \
        "${root}/infra/governance/modules/contentPlanExternalJoinAssignments.bicep"
      --artifact-dir "${evidence_dir}"
  )
  if [[ -f "${evidence_dir}/phase-a-deployment.json" &&
        -f "${evidence_dir}/phase-a-binding.json" ]]; then
    manifest_args+=(
      --phase-a-deployment "${evidence_dir}/phase-a-deployment.json"
      --phase-a-evidence-manifest "${PHASE_A_EVIDENCE_DIR}/manifest.json"
      --phase-a-binding "${evidence_dir}/phase-a-binding.json"
    )
  fi
  "${manifest_args[@]}"
  sha256sum "${evidence_dir}/manifest.json" > \
    "${evidence_dir}/manifest.sha256"
  exit "${status}"
}
trap finalize EXIT

az bicep build \
  --file \
    "${root}/infra/governance/modules/contentPlanExternalJoinAssignments.bicep" \
  --stdout > "${evidence_dir}/compiled-template.json"
bash "${root}/infra/governance/prepare-phase-b.sh"
b1_evidence_dir="${PHASE_B1_EVIDENCE_DIR:?Set approved B1 evidence.}"
b1_evidence_sha="${PHASE_B1_EVIDENCE_MANIFEST_SHA256:?Set approved B1 manifest hash.}"
b1_deployment="${PHASE_B1_DEPLOYMENT_NAME:?Set approved B1 deployment name.}"
az deployment sub show \
  --subscription "${subscription_id}" \
  --name "${b1_deployment}" \
  --output json > "${evidence_dir}/b1-deployment.json"
node "${root}/infra/governance/validate-evidence.mjs" prior-b1-deployment \
  --manifest "${b1_evidence_dir}/manifest.json" \
  --plan "${b1_evidence_dir}/plan.json" \
  --parameters "${b1_evidence_dir}/parameters.json" \
  --compiled-template "${b1_evidence_dir}/compiled-template.json" \
  --deployment "${evidence_dir}/b1-deployment.json" \
  --phase-a-proof "${evidence_dir}/phase-a.json" \
  --phase B1a \
  --source-root "${root}" \
  --expected-manifest-sha256 "${b1_evidence_sha}"
b1b_evidence_dir="${PHASE_B1B_EVIDENCE_DIR:?Set approved B1b evidence.}"
b1b_evidence_sha="${PHASE_B1B_EVIDENCE_MANIFEST_SHA256:?Set approved B1b manifest hash.}"
b1b_deployment="${PHASE_B1B_DEPLOYMENT_NAME:?Set approved B1b deployment name.}"
az deployment sub show \
  --subscription "${subscription_id}" \
  --name "${b1b_deployment}" \
  --output json > "${evidence_dir}/b1b-deployment.json"
node "${root}/infra/governance/validate-evidence.mjs" prior-b1-deployment \
  --manifest "${b1b_evidence_dir}/manifest.json" \
  --plan "${b1b_evidence_dir}/plan.json" \
  --parameters "${b1b_evidence_dir}/parameters.json" \
  --compiled-template "${b1b_evidence_dir}/compiled-template.json" \
  --deployment "${evidence_dir}/b1b-deployment.json" \
  --phase-a-proof "${evidence_dir}/phase-a.json" \
  --phase B1b \
  --source-root "${root}" \
  --expected-manifest-sha256 "${b1b_evidence_sha}"
cp "${evidence_dir}/b2-parameters.json" "${evidence_dir}/parameters.json"
set +e
az deployment group what-if \
  --subscription "${subscription_id}" \
  --name certigo-governance-bootstrap-rbac-external-plan \
  --resource-group rg-certigo-ci \
  --template-file "${evidence_dir}/compiled-template.json" \
  --parameters "@${evidence_dir}/parameters.json" \
  --result-format FullResourcePayloads \
  --no-pretty-print \
  --output json > "${evidence_dir}/plan.json"
what_if_status=$?
set -e
printf '%s\n' "${what_if_status}" > "${evidence_dir}/what-if-exit-code.txt"
[[ "${what_if_status}" -eq 0 ]]
node "${root}/infra/governance/validate-what-if.mjs" \
  --plan "${evidence_dir}/plan.json" \
  --subscription "${subscription_id}" \
  --phase B2 \
  --phase-a "${evidence_dir}/phase-a.json"
