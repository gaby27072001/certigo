#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
subscription_id="${AZURE_SUBSCRIPTION_ID:?Set AZURE_SUBSCRIPTION_ID explicitly.}"
tenant_id="${AZURE_TENANT_ID:?Set AZURE_TENANT_ID explicitly.}"
node "${root}/infra/governance/phase-b-target.mjs" \
  "${subscription_id}" "${tenant_id}"
location="${AZURE_LOCATION:-westeurope}"
evidence_dir="${PHASE_B1_EVIDENCE_DIR:?Set PHASE_B1_EVIDENCE_DIR.}"
mkdir -p "${evidence_dir}"
node "${root}/infra/governance/evidence-files.mjs" require-directory \
  "${evidence_dir}"
chmod 700 "${evidence_dir}"
exec > "${evidence_dir}/stdout.log" 2> "${evidence_dir}/stderr.log"
export PHASE_B_WORK_DIR="${evidence_dir}"
export PHASE_B_STAGE=B1a

finalize() {
  status=$?
  trap - EXIT
  printf '%s\n' "${status}" > "${evidence_dir}/exit-code.txt"
  node --input-type=module - "${evidence_dir}/metadata.json" "${status}" <<'NODE'
import fs from 'node:fs';
const [output, status] = process.argv.slice(2);
fs.writeFileSync(output, `${JSON.stringify({
  schemaVersion: 1,
  phase: 'B1a',
  exitCode: Number(status),
  deploymentExecuted: false,
}, null, 2)}\n`);
NODE
  source_commit="$(git -C "${root}" rev-parse HEAD)"
  tenant_id="$(az account show --query tenantId --output tsv 2>/dev/null || true)"
  sources="$(
      printf '%s,' \
        "${root}/infra/governance/bootstrap-rbac.bicep" \
        "${root}/infra/governance/modules/environmentRbac.bicep" \
        "${root}/infra/governance/modules/resourceGroupRoleAssignment.bicep"
      printf '%s' \
        "${root}/infra/governance/modules/contentPlanExecutorAssignment.bicep"
  )"
  manifest_args=(
    node "${root}/infra/governance/write-what-if-manifest.mjs"
      --phase B1a \
      --plan "${evidence_dir}/plan.json" \
      --output "${evidence_dir}/manifest.json" \
      --template "${root}/infra/governance/bootstrap-rbac.bicep" \
      --compiled-template "${evidence_dir}/compiled-template.json" \
      --parameters "${evidence_dir}/parameters.json" \
      --source-root "${root}" \
      --source-commit "${source_commit}" \
      --subscription "${subscription_id}" \
      --tenant "${tenant_id}" \
      --sources "${sources}" \
      --artifact-dir "${evidence_dir}"
  )
  if [[ -f "${evidence_dir}/phase-a-deployment.json" &&
        -f "${evidence_dir}/phase-a-binding.json" ]]; then
    manifest_args+=(
      --phase-a-deployment "${evidence_dir}/phase-a-deployment.json"
      --phase-a-evidence-manifest "${PHASE_A_EVIDENCE_DIR}/manifest.json"
      --phase-a-binding "${evidence_dir}/phase-a-binding.json"
      --legacy-transition "${evidence_dir}/legacy-transition.json"
    )
  fi
  "${manifest_args[@]}"
  node "${root}/infra/governance/evidence-files.mjs" seal \
    "${evidence_dir}/manifest.json" "${evidence_dir}/manifest.sha256"
  exit "${status}"
}
trap finalize EXIT

az bicep build \
  --file "${root}/infra/governance/bootstrap-rbac.bicep" \
  --stdout > "${evidence_dir}/compiled-template.json"
bash "${root}/infra/governance/prepare-phase-b.sh"
cp "${evidence_dir}/b1-parameters.json" "${evidence_dir}/parameters.json"
node "${root}/infra/governance/bicep-parameters.mjs" validate \
  "${evidence_dir}/parameters.json"
set +e
az deployment sub what-if \
  --subscription "${subscription_id}" \
  --name certigo-governance-bootstrap-rbac-internal-plan \
  --location "${location}" \
  --template-file "${evidence_dir}/compiled-template.json" \
  --parameters "@${evidence_dir}/parameters.json" \
  --result-format FullResourcePayloads \
  --no-pretty-print \
  --output json > "${evidence_dir}/plan.json"
what_if_status=$?
set -e
printf '%s\n' "${what_if_status}" > "${evidence_dir}/what-if-exit-code.txt"
[[ "${what_if_status}" -eq 0 ]]
node "${root}/infra/governance/normalize-principal-types.mjs" \
  "${evidence_dir}/plan.json" \
  "${evidence_dir}/compiled-template.json" \
  "${evidence_dir}/phase-a.json" \
  "${evidence_dir}/normalized-plan.json" \
  "${evidence_dir}/principal-type-provenance.json"
node "${root}/infra/governance/validate-what-if.mjs" \
  --plan "${evidence_dir}/normalized-plan.json" \
  --subscription "${subscription_id}" \
  --phase B1a \
  --phase-a "${evidence_dir}/phase-a.json"
