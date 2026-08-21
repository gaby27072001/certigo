#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
subscription_id="${AZURE_SUBSCRIPTION_ID:?Set AZURE_SUBSCRIPTION_ID explicitly.}"
location="${AZURE_LOCATION:-westeurope}"
identity_resource_group="${CERTIGO_IDENTITY_RESOURCE_GROUP:-rg-certigo-ci}"
identity_name="id-certigo-content-infra-plan"
credential_name="github-azure-content-infra-plan"
expected_subject="repo:gchambaud_microsoft/Certigo:environment:azure-content-infra-plan"
work_dir="$(mktemp -d)"
trap 'rm -rf -- "${work_dir}"' EXIT
chmod 700 "${work_dir}"
plan_file="${work_dir}/plan.json"
identity_file="${work_dir}/identity.json"
identity_error_file="${work_dir}/identity-error.txt"
credentials_file="${work_dir}/credentials.json"
identity_id="/subscriptions/${subscription_id}/resourceGroups/${identity_resource_group}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${identity_name}"

if az resource show \
  --ids "${identity_id}" \
  --only-show-errors \
  --output json > "${identity_file}" 2> "${identity_error_file}"; then
  az identity federated-credential list \
    --subscription "${subscription_id}" \
    --resource-group "${identity_resource_group}" \
    --identity-name "${identity_name}" \
    --output json > "${credentials_file}"
  node --input-type=module - \
    "${credentials_file}" "${credential_name}" "${expected_subject}" <<'NODE'
import fs from 'node:fs';

const [file, expectedName, expectedSubject] = process.argv.slice(2);
const credentials = JSON.parse(fs.readFileSync(file, 'utf8'));
const standardAudience = ['api://AzureADTokenExchange'];
if (
  credentials.length !== 1 ||
  credentials[0].name !== expectedName ||
  credentials[0].issuer !== 'https://token.actions.githubusercontent.com' ||
  credentials[0].subject !== expectedSubject ||
  JSON.stringify(credentials[0].audiences) !== JSON.stringify(standardAudience)
) {
  throw new Error(
    'content plan identity must have exactly the approved federated credential',
  );
}
NODE
elif ! grep -Eqi 'ResourceNotFound|could not be found' "${identity_error_file}"; then
  cat "${identity_error_file}" >&2
  exit 1
fi

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
