#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
subscription_id="${AZURE_SUBSCRIPTION_ID:?Set AZURE_SUBSCRIPTION_ID explicitly.}"
location="${AZURE_LOCATION:-westeurope}"
evidence_dir="${PHASE_A_EVIDENCE_DIR:-$(mktemp -d)}"
mkdir -p "${evidence_dir}"
chmod 700 "${evidence_dir}"
exec > "${evidence_dir}/stdout.log" 2> "${evidence_dir}/stderr.log"

finalize() {
  status=$?
  trap - EXIT
  printf '%s\n' "${status}" > "${evidence_dir}/exit-code.txt"
  printf '{"schemaVersion":1,"phase":"A","exitCode":%s,"deploymentExecuted":false}\n' \
    "${status}" > "${evidence_dir}/metadata.json"
  source_commit="$(git -C "${root}" rev-parse HEAD)"
  tenant_id="$(az account show --query tenantId --output tsv 2>/dev/null || true)"
  sources="$(
      printf '%s,' \
        "${root}/infra/governance/bootstrap-identities.bicep" \
        "${root}/infra/governance/modules/githubEnvironmentIdentity.bicep" \
        "${root}/infra/modules/contentIdentity.bicep"
      printf '%s' "${root}/infra/modules/contentReaderIdentity.bicep"
  )"
  node "${root}/infra/governance/write-what-if-manifest.mjs" \
      --phase A \
      --plan "${evidence_dir}/plan.json" \
      --output "${evidence_dir}/manifest.json" \
      --template "${root}/infra/governance/bootstrap-identities.bicep" \
      --compiled-template "${evidence_dir}/compiled-template.json" \
      --parameters "${evidence_dir}/parameters.json" \
      --source-root "${root}" \
      --source-commit "${source_commit}" \
      --subscription "${subscription_id}" \
      --tenant "${tenant_id}" \
      --sources "${sources}" \
      --artifact-dir "${evidence_dir}"
  sha256sum "${evidence_dir}/manifest.json" > \
    "${evidence_dir}/manifest.sha256"
  exit "${status}"
}
trap finalize EXIT

az bicep build \
  --file "${root}/infra/governance/bootstrap-identities.bicep" \
  --stdout > "${evidence_dir}/compiled-template.json"
az bicep build-params \
  --file "${root}/infra/params/bootstrap-identities.bicepparam" \
  --stdout > "${evidence_dir}/parameters.json"
set +e
az deployment sub what-if \
  --subscription "${subscription_id}" \
  --name certigo-governance-bootstrap-identities-plan \
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
node "${root}/infra/governance/validate-what-if.mjs" \
  --plan "${evidence_dir}/plan.json" \
  --subscription "${subscription_id}" \
  --phase A
