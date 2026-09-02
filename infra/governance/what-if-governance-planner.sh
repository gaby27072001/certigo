#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
subscription_id="${AZURE_SUBSCRIPTION_ID:?Set AZURE_SUBSCRIPTION_ID explicitly.}"
evidence_dir="${GOVERNANCE_PLANNER_EVIDENCE_DIR:-$(mktemp -d)}"
mkdir -p "${evidence_dir}"
node "${root}/infra/governance/evidence-files.mjs" require-directory \
  "${evidence_dir}"
chmod 700 "${evidence_dir}"
az bicep build \
  --file "${root}/infra/governance/bootstrap-planning-identity.bicep" \
  --stdout > "${evidence_dir}/compiled-template.json"
az bicep build-params \
  --file "${root}/infra/params/bootstrap-planning-identity.bicepparam" \
  --stdout > "${evidence_dir}/build-params-output.json"
node "${root}/infra/governance/bicep-parameters.mjs" extract \
  "${evidence_dir}/build-params-output.json" \
  "${evidence_dir}/parameters.json"
az deployment sub what-if \
  --subscription "${subscription_id}" \
  --name certigo-governance-b1a-planner-bootstrap-plan \
  --location "${AZURE_LOCATION:-westeurope}" \
  --template-file "${evidence_dir}/compiled-template.json" \
  --parameters "@${evidence_dir}/parameters.json" \
  --result-format FullResourcePayloads \
  --no-pretty-print \
  --output json > "${evidence_dir}/plan.json"
node "${root}/infra/governance/validate-planner-what-if.mjs" \
  "${evidence_dir}/plan.json" "${subscription_id}"
node "${root}/infra/governance/write-what-if-manifest.mjs" \
  --phase A0-B1a-Planner \
  --plan "${evidence_dir}/plan.json" \
  --output "${evidence_dir}/manifest.json" \
  --template "${root}/infra/governance/bootstrap-planning-identity.bicep" \
  --compiled-template "${evidence_dir}/compiled-template.json" \
  --parameters "${evidence_dir}/parameters.json" \
  --source-root "${root}" \
  --source-commit "$(git -C "${root}" rev-parse HEAD)" \
  --subscription "${subscription_id}" \
  --tenant "$(az account show --query tenantId --output tsv)" \
  --sources \
    "${root}/infra/governance/bootstrap-planning-identity.bicep,${root}/infra/governance/modules/governancePlanningIdentity.bicep" \
  --artifact-dir "${evidence_dir}"
node "${root}/infra/governance/evidence-files.mjs" seal \
  "${evidence_dir}/manifest.json" "${evidence_dir}/manifest.sha256"
