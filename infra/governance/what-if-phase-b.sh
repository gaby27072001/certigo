#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
subscription_id="${AZURE_SUBSCRIPTION_ID:?Set AZURE_SUBSCRIPTION_ID explicitly.}"
location="${AZURE_LOCATION:-westeurope}"
phase_a_deployment="${PHASE_A_DEPLOYMENT_NAME:?Set PHASE_A_DEPLOYMENT_NAME to the approved successful Phase A deployment.}"
work_dir="$(mktemp -d)"
trap 'rm -rf -- "${work_dir}"' EXIT
chmod 700 "${work_dir}"
phase_a_file="${work_dir}/phase-a.json"
parameters_file="${work_dir}/parameters.json"
plan_file="${work_dir}/plan.json"

provisioning_state="$(
  az deployment sub show \
    --subscription "${subscription_id}" \
    --name "${phase_a_deployment}" \
    --query properties.provisioningState \
    --output tsv
)"
if [[ "${provisioning_state}" != "Succeeded" ]]; then
  echo "Phase A deployment must exist and have provisioningState=Succeeded." >&2
  exit 1
fi

az deployment sub show \
  --subscription "${subscription_id}" \
  --name "${phase_a_deployment}" \
  --query properties.outputs.phaseA.value \
  --output json > "${phase_a_file}"

node --input-type=module - \
  "${root}/infra/governance/validate-what-if.mjs" \
  "${phase_a_file}" "${subscription_id}" "${parameters_file}" <<'NODE'
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';

const [validatorPath, proofPath, subscriptionId, parametersPath] =
  process.argv.slice(2);
const { validatePhaseAProof } = await import(pathToFileURL(validatorPath));
const phaseA = validatePhaseAProof(
  JSON.parse(fs.readFileSync(proofPath, 'utf8')),
  subscriptionId,
);
fs.writeFileSync(
  parametersPath,
  JSON.stringify({
    $schema:
      'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#',
    contentVersion: '1.0.0.0',
    parameters: { phaseA: { value: phaseA } },
  }),
  { mode: 0o600 },
);
for (const identity of Object.values(phaseA.identities)) {
  process.stdout.write(
    `identity\t${identity.resourceId}\t${identity.clientId}\t${identity.principalId}\n`,
  );
}
for (const roleDefinitionId of Object.values(phaseA.roleDefinitionIds)) {
  process.stdout.write(`resource\t${roleDefinitionId}\t-\t-\n`);
}
process.stdout.write(`resource\t${phaseA.policyDefinitionId}\t-\t-\n`);
process.stdout.write(`resource\t${phaseA.contentResourceGroupId}\t-\t-\n`);
NODE

while IFS=$'\t' read -r kind resource_id expected_client_id expected_principal_id; do
  resource_file="${work_dir}/resource.json"
  az resource show \
    --subscription "${subscription_id}" \
    --ids "${resource_id}" \
    --only-show-errors \
    --output json > "${resource_file}"
  node --input-type=module - \
    "${root}/infra/governance/validate-what-if.mjs" \
    "${resource_file}" "${subscription_id}" <<'NODE'
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';

const [validatorPath, resourcePath, subscriptionId] = process.argv.slice(2);
const { validatePhaseAResource } = await import(pathToFileURL(validatorPath));
const resource = JSON.parse(fs.readFileSync(resourcePath, 'utf8'));
validatePhaseAResource(resource, subscriptionId);
NODE
  if [[ "${kind}" == "identity" ]]; then
    node --input-type=module - \
      "${resource_file}" "${expected_client_id}" "${expected_principal_id}" <<'NODE'
import fs from 'node:fs';

const [resourcePath, expectedClientId, expectedPrincipalId] =
  process.argv.slice(2);
const resource = JSON.parse(fs.readFileSync(resourcePath, 'utf8'));
if (
  resource.properties?.clientId?.toLowerCase() !== expectedClientId.toLowerCase() ||
  resource.properties?.principalId?.toLowerCase() !==
    expectedPrincipalId.toLowerCase()
) {
  throw new Error(`live identity does not match Phase A proof: ${resource.id}`);
}
NODE
  fi
done < <(
  node --input-type=module - \
    "${root}/infra/governance/validate-what-if.mjs" \
    "${phase_a_file}" "${subscription_id}" <<'NODE'
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';

const [validatorPath, proofPath, subscriptionId] = process.argv.slice(2);
const { validatePhaseAProof } = await import(pathToFileURL(validatorPath));
const phaseA = validatePhaseAProof(
  JSON.parse(fs.readFileSync(proofPath, 'utf8')),
  subscriptionId,
);
for (const identity of Object.values(phaseA.identities)) {
  process.stdout.write(
    `identity\t${identity.resourceId}\t${identity.clientId}\t${identity.principalId}\n`,
  );
}
for (const roleDefinitionId of Object.values(phaseA.roleDefinitionIds)) {
  process.stdout.write(`resource\t${roleDefinitionId}\t-\t-\n`);
}
process.stdout.write(`resource\t${phaseA.policyDefinitionId}\t-\t-\n`);
process.stdout.write(`resource\t${phaseA.contentResourceGroupId}\t-\t-\n`);
NODE
)

node --input-type=module - \
  "${phase_a_file}" "${subscription_id}" "${work_dir}" <<'NODE'
import fs from 'node:fs';

const [proofPath, subscriptionId, workDir] = process.argv.slice(2);
const proof = JSON.parse(fs.readFileSync(proofPath, 'utf8'));
for (const [key, identity] of Object.entries(proof.identities)) {
  const resourceGroup =
    identity.resourceId.match(/\/resourceGroups\/([^/]+)/i)?.[1];
  fs.writeFileSync(
    `${workDir}/fic-${key}.request`,
    `${subscriptionId}\n${resourceGroup}\n${identity.name}\n`,
  );
}
NODE

for request in "${work_dir}"/fic-*.request; do
  mapfile -t fields < "${request}"
  key="$(basename "${request}" .request)"
  credentials_file="${work_dir}/${key}.json"
  az identity federated-credential list \
    --subscription "${fields[0]}" \
    --resource-group "${fields[1]}" \
    --identity-name "${fields[2]}" \
    --output json > "${credentials_file}"
done

node --input-type=module - "${phase_a_file}" "${work_dir}" <<'NODE'
import fs from 'node:fs';

const [proofPath, workDir] = process.argv.slice(2);
const proof = JSON.parse(fs.readFileSync(proofPath, 'utf8'));
const expected = {
  deployDev: ['github-dev', 'repo:gchambaud_microsoft/Certigo:environment:dev'],
  deployStaging: [
    'github-staging',
    'repo:gchambaud_microsoft/Certigo:environment:staging',
  ],
  deployProd: ['github-prod', 'repo:gchambaud_microsoft/Certigo:environment:prod'],
  contentInfrastructurePlan: [
    'github-azure-content-infra-plan',
    'repo:gchambaud_microsoft/Certigo:environment:azure-content-infra-plan',
  ],
  contentRelease: [
    'github-azure-content-release',
    'repo:gchambaud_microsoft/certigo-content:environment:azure-content-release',
  ],
  contentPublic: [
    'github-azure-content-public',
    'repo:gchambaud_microsoft/certigo-content:environment:azure-content-public',
  ],
  contentAnswerKey: [
    'github-azure-content-answer-key',
    'repo:gchambaud_microsoft/certigo-content:environment:azure-content-answer-key',
  ],
  contentReader: null,
};
for (const key of Object.keys(proof.identities)) {
  const credentials = JSON.parse(
    fs.readFileSync(`${workDir}/fic-${key}.json`, 'utf8'),
  );
  const contract = expected[key];
  if (
    (!contract && credentials.length !== 0) ||
    (contract &&
      (credentials.length !== 1 ||
        credentials[0].name !== contract[0] ||
        credentials[0].issuer !== 'https://token.actions.githubusercontent.com' ||
        credentials[0].subject !== contract[1] ||
        JSON.stringify(credentials[0].audiences) !==
          JSON.stringify(['api://AzureADTokenExchange'])))
  ) {
    throw new Error(`live federated credentials violate Phase A proof: ${key}`);
  }
}
NODE

az deployment sub what-if \
  --subscription "${subscription_id}" \
  --name certigo-governance-bootstrap-rbac-plan \
  --location "${location}" \
  --template-file "${root}/infra/governance/bootstrap-rbac.bicep" \
  --parameters "@${parameters_file}" \
  --result-format FullResourcePayloads \
  --no-pretty-print \
  --output json > "${plan_file}"

node "${root}/infra/governance/validate-what-if.mjs" \
  --plan "${plan_file}" \
  --subscription "${subscription_id}" \
  --phase B \
  --phase-a "${phase_a_file}"
