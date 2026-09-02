#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
case "$(uname -s)" in
  MINGW*|MSYS*) export MSYS2_ARG_CONV_EXCL="/subscriptions" ;;
esac
subscription_id="${AZURE_SUBSCRIPTION_ID:?Set AZURE_SUBSCRIPTION_ID explicitly.}"
tenant_id="${AZURE_TENANT_ID:?Set AZURE_TENANT_ID explicitly.}"
node "${root}/infra/governance/phase-b-target.mjs" \
  "${subscription_id}" "${tenant_id}"
phase_a_deployment="${PHASE_A_DEPLOYMENT_NAME:?Set PHASE_A_DEPLOYMENT_NAME to the approved successful Phase A deployment.}"
phase_a_evidence_dir="${PHASE_A_EVIDENCE_DIR:?Set PHASE_A_EVIDENCE_DIR to the approved Phase A artifact.}"
phase_a_evidence_sha="${PHASE_A_EVIDENCE_MANIFEST_SHA256:?Set PHASE_A_EVIDENCE_MANIFEST_SHA256 to the approved manifest hash.}"
work_dir="${PHASE_B_WORK_DIR:?Set PHASE_B_WORK_DIR to a private temporary directory.}"
phase_a_file="${work_dir}/phase-a.json"
phase_a_deployment_file="${work_dir}/phase-a-deployment.json"
phase_a_operations_file="${work_dir}/phase-a-operations.json"
phase_a_role_assignments_file="${work_dir}/phase-a-role-assignments.json"
phase_a_policy_assignments_file="${work_dir}/phase-a-policy-assignments.json"
phase_a_binding_file="${work_dir}/phase-a-binding.json"
b1_parameters_file="${work_dir}/b1-parameters.json"
b2_parameters_file="${work_dir}/b2-parameters.json"
inventory_file="${work_dir}/phase-a-inventory.tsv"
legacy_transition_source="${LEGACY_TRANSITION_FILE:?Set LEGACY_TRANSITION_FILE to the approved transition evidence.}"
legacy_transition_sha="${LEGACY_TRANSITION_SHA256:?Set LEGACY_TRANSITION_SHA256 to the approved transition evidence hash.}"
legacy_transition_file="${work_dir}/legacy-transition.json"
legacy_assignments_file="${work_dir}/legacy-live-assignments.json"
legacy_group_ids_file="${work_dir}/legacy-transitive-group-ids.json"
legacy_access_scopes_file="${work_dir}/legacy-access-scopes.json"
legacy_schedule_instances_file="${work_dir}/legacy-live-schedule-instances.json"
legacy_eligibility_instances_file="${work_dir}/legacy-live-eligibility-instances.json"

for evidence_file in \
  "${phase_a_evidence_dir}/manifest.json" \
  "${phase_a_evidence_dir}/plan.json" \
  "${phase_a_evidence_dir}/parameters.json" \
  "${phase_a_evidence_dir}/compiled-template.json"; do
  if ! node "${root}/infra/governance/evidence-files.mjs" require-file \
    "${evidence_file}"; then
    echo \
      "Approved Phase A evidence is missing or unsafe. Never reconstruct it locally; run and approve a separate repair what-if/deployment tied to the current template." \
      >&2
    exit 1
  fi
done

mkdir -p "${work_dir}"
chmod 700 "${work_dir}"

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
  --output json > "${phase_a_deployment_file}"
jq '.properties.outputs.phaseA.value' \
  "${phase_a_deployment_file}" > "${phase_a_file}"

node --input-type=module - \
  "${root}/infra/governance/validate-what-if.mjs" \
  "${phase_a_file}" "${subscription_id}" \
  "${b1_parameters_file}" "${b2_parameters_file}" "${inventory_file}" <<'NODE'
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';

const [
  validatorPath,
  proofPath,
  subscriptionId,
  b1ParametersPath,
  b2ParametersPath,
  inventoryPath,
] = process.argv.slice(2);
const { validatePhaseAProof } = await import(pathToFileURL(validatorPath));
const phaseA = validatePhaseAProof(
  JSON.parse(fs.readFileSync(proofPath, 'utf8')),
  subscriptionId,
);
const parameterDocument = (parameters) => ({
  $schema:
    'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#',
  contentVersion: '1.0.0.0',
  parameters,
});
fs.writeFileSync(
  b1ParametersPath,
  JSON.stringify(parameterDocument({ phaseA: { value: phaseA } })),
  { mode: 0o600 },
);
fs.writeFileSync(
  b2ParametersPath,
  JSON.stringify(
    parameterDocument({
      ciVnetName: { value: 'vnet-certigo-ci' },
      ciRunnerSubnetName: { value: 'snet-runners' },
      blobPrivateDnsZoneName: { value: 'privatelink.blob.core.windows.net' },
      principalId: {
        value: phaseA.identities.contentInfrastructurePlan.principalId,
      },
      roleDefinitionId: {
        value: phaseA.roleDefinitionIds.contentInfrastructurePlanExternalJoin,
      },
    }),
  ),
  { mode: 0o600 },
);
const inventory = [];
for (const identity of Object.values(phaseA.identities)) {
  inventory.push(
    `identity\t${identity.resourceId}\t${identity.clientId}\t${identity.principalId}`,
  );
}
for (const roleDefinitionId of Object.values(phaseA.roleDefinitionIds)) {
  inventory.push(`resource\t${roleDefinitionId}\t-\t-`);
}
inventory.push(`resource\t${phaseA.policyDefinitionId}\t-\t-`);
inventory.push(`resource\t${phaseA.contentResourceGroupId}\t-\t-`);
inventory.push(`resource\t${phaseA.identityResourceGroupId}\t-\t-`);
fs.writeFileSync(inventoryPath, `${inventory.join('\n')}\n`, { mode: 0o600 });
NODE

node "${root}/infra/governance/evidence-files.mjs" require-file \
  "${legacy_transition_source}"
actual_transition_sha="$(
  node "${root}/infra/governance/evidence-files.mjs" hash \
    "${legacy_transition_source}"
)"
if [[ "${actual_transition_sha}" != "${legacy_transition_sha,,}" ]]; then
  echo "Legacy transition evidence hash does not match the approved SHA-256." >&2
  exit 1
fi
cp "${legacy_transition_source}" "${legacy_transition_file}"
legacy_principal_id="$(
  node -p "require(process.argv[1]).legacyPrincipalId" "${legacy_transition_file}"
)"
node "${root}/infra/governance/collect-transitive-groups.mjs" \
  "${legacy_group_ids_file}" "${legacy_principal_id}"
az account management-group entities list \
  --output json > "${work_dir}/management-group-entities.json"
node --input-type=module - \
  "${root}/infra/governance/planner-pim-contract.mjs" \
  "${phase_a_file}" "${work_dir}/management-group-entities.json" \
  "${legacy_access_scopes_file}" <<'NODE'
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';
const [contractPath, phaseAPath, entitiesPath, outputPath] =
  process.argv.slice(2);
const { plannerAccessScopes } = await import(pathToFileURL(contractPath));
const phaseA = JSON.parse(fs.readFileSync(phaseAPath, 'utf8'));
const entities = JSON.parse(fs.readFileSync(entitiesPath, 'utf8'));
const subscriptionScope = `/subscriptions/${phaseA.subscriptionId}`;
const scopes = [
  ...plannerAccessScopes(entities, phaseA.subscriptionId, phaseA.tenantId),
  ...['ci', 'dev', 'staging', 'prod'].map(
    (name) => `${subscriptionScope}/resourceGroups/rg-certigo-${name}`,
  ),
];
fs.writeFileSync(outputPath, JSON.stringify(scopes), { mode: 0o600 });
NODE
mapfile -t legacy_principal_ids < <(
  node --input-type=module - \
    "${legacy_principal_id}" "${legacy_group_ids_file}" <<'NODE'
import fs from 'node:fs';
const [principalId, groupIdsPath] = process.argv.slice(2);
const groupIds = JSON.parse(fs.readFileSync(groupIdsPath, 'utf8'));
for (const id of [principalId, ...groupIds]) {
  process.stdout.write(`${id}\n`);
}
NODE
)
printf '[]' > "${legacy_assignments_file}"
for candidate_principal_id in "${legacy_principal_ids[@]}"; do
  candidate_assignments_file="${work_dir}/legacy-assignments-${candidate_principal_id}.json"
  merged_assignments_file="${work_dir}/legacy-assignments-merged.json"
  az role assignment list \
    --subscription "${subscription_id}" \
    --assignee-object-id "${candidate_principal_id}" \
    --include-inherited \
    --all \
    --output json > "${candidate_assignments_file}"
  jq -s 'add' \
    "${legacy_assignments_file}" "${candidate_assignments_file}" \
    > "${merged_assignments_file}"
  mv "${merged_assignments_file}" "${legacy_assignments_file}"
done
node "${root}/infra/governance/collect-role-assignment-schedules.mjs" \
  "${legacy_schedule_instances_file}" "${subscription_id}" \
  roleAssignmentScheduleInstances "${legacy_access_scopes_file}" \
  "${legacy_principal_ids[@]}"
node "${root}/infra/governance/collect-role-assignment-schedules.mjs" \
  "${legacy_eligibility_instances_file}" "${subscription_id}" \
  roleEligibilityScheduleInstances "${legacy_access_scopes_file}" \
  "${legacy_principal_ids[@]}"
node "${root}/infra/governance/legacy-transition-contract.mjs" \
  "${legacy_transition_file}" "${phase_a_file}" \
  "${legacy_assignments_file}" "${legacy_schedule_instances_file}" \
  "${legacy_group_ids_file}" "${legacy_eligibility_instances_file}"

resource_index=0
while IFS=$'\t' read -r kind resource_id expected_client_id expected_principal_id; do
  resource_index=$((resource_index + 1))
  resource_file="${work_dir}/phase-a-resource-${resource_index}.json"
  az resource show \
    --subscription "${subscription_id}" \
    --ids "${resource_id}" \
    --only-show-errors \
    --output json > "${resource_file}"
  node --input-type=module - \
    "${root}/infra/governance/validate-what-if.mjs" \
    "${resource_file}" "${subscription_id}" \
    "${kind}" "${expected_client_id}" "${expected_principal_id}" <<'NODE'
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';

const [
  validatorPath,
  resourcePath,
  subscriptionId,
  kind,
  expectedClientId,
  expectedPrincipalId,
] = process.argv.slice(2);
const { validatePhaseAResource } = await import(pathToFileURL(validatorPath));
const resource = JSON.parse(fs.readFileSync(resourcePath, 'utf8'));
validatePhaseAResource(resource, subscriptionId);
if (
  kind === 'identity' &&
  (resource.properties?.clientId?.toLowerCase() !== expectedClientId.toLowerCase() ||
    resource.properties?.principalId?.toLowerCase() !==
      expectedPrincipalId.toLowerCase())
) {
  throw new Error(`live identity does not match Phase A proof: ${resource.id}`);
}
NODE
done < "${inventory_file}"

az deployment operation sub list \
  --subscription "${subscription_id}" \
  --name "${phase_a_deployment}" \
  --output json > "${work_dir}/phase-a-operations-sub.json"
for deployment in \
  identity-dev \
  identity-staging \
  identity-prod \
  identity-content-infra-plan \
  content-release-publisher-identity \
  content-public-publisher-identity \
  content-private-publisher-identity \
  content-reader-identity; do
  az deployment operation group list \
    --subscription "${subscription_id}" \
    --resource-group rg-certigo-identities \
    --name "${deployment}" \
    --output json > "${work_dir}/phase-a-operations-${deployment}.json"
done
node --input-type=module - "${work_dir}" "${phase_a_operations_file}" <<'NODE'
import fs from 'node:fs';
import path from 'node:path';

const [workDir, outputPath] = process.argv.slice(2);
const operations = fs
  .readdirSync(workDir)
  .filter((name) => name.startsWith('phase-a-operations-') && name.endsWith('.json'))
  .flatMap((name) =>
    JSON.parse(fs.readFileSync(path.join(workDir, name), 'utf8')),
  );
fs.writeFileSync(outputPath, JSON.stringify(operations), { mode: 0o600 });
NODE

node --input-type=module - "${phase_a_file}" "${work_dir}" <<'NODE'
import fs from 'node:fs';

const [proofPath, workDir] = process.argv.slice(2);
const proof = JSON.parse(fs.readFileSync(proofPath, 'utf8'));
for (const [key, identity] of Object.entries(proof.identities)) {
  fs.writeFileSync(
    `${workDir}/assignments-${key}.request`,
    `${proof.subscriptionId}\n${identity.principalId}\n`,
    { mode: 0o600 },
  );
}
NODE
for request in "${work_dir}"/assignments-*.request; do
  mapfile -t fields < "${request}"
  key="$(basename "${request}" .request)"
  az role assignment list \
    --subscription "${fields[0]}" \
    --assignee-object-id "${fields[1]}" \
    --all \
    --include-inherited \
    --output json > "${work_dir}/${key}.json"
done
node --input-type=module - \
  "${work_dir}" "${phase_a_role_assignments_file}" <<'NODE'
import fs from 'node:fs';
import path from 'node:path';

const [workDir, outputPath] = process.argv.slice(2);
const assignments = fs
  .readdirSync(workDir)
  .filter((name) => name.startsWith('assignments-') && name.endsWith('.json'))
  .flatMap((name) =>
    JSON.parse(fs.readFileSync(path.join(workDir, name), 'utf8')),
  );
fs.writeFileSync(outputPath, JSON.stringify(assignments), { mode: 0o600 });
NODE
az policy assignment list \
  --subscription "${subscription_id}" \
  --disable-scope-strict-match \
  --output json > "${work_dir}/all-policy-assignments.json"
node --input-type=module - \
  "${phase_a_file}" "${work_dir}/all-policy-assignments.json" \
  "${phase_a_policy_assignments_file}" <<'NODE'
import fs from 'node:fs';

const [proofPath, assignmentsPath, outputPath] = process.argv.slice(2);
const proof = JSON.parse(fs.readFileSync(proofPath, 'utf8'));
const assignments = JSON.parse(fs.readFileSync(assignmentsPath, 'utf8')).filter(
  (assignment) =>
    assignment.policyDefinitionId?.toLowerCase() ===
    proof.policyDefinitionId.toLowerCase(),
);
fs.writeFileSync(outputPath, JSON.stringify(assignments), { mode: 0o600 });
NODE

node --input-type=module - "${phase_a_file}" "${work_dir}" <<'NODE'
import fs from 'node:fs';

const [proofPath, workDir] = process.argv.slice(2);
const proof = JSON.parse(fs.readFileSync(proofPath, 'utf8'));
for (const [key, identity] of Object.entries(proof.identities)) {
  const resourceGroup =
    identity.resourceId.match(/\/resourceGroups\/([^/]+)/i)?.[1];
  fs.writeFileSync(
    `${workDir}/fic-${key}.request`,
    `${proof.subscriptionId}\n${resourceGroup}\n${identity.name}\n`,
  );
}
NODE

for request in "${work_dir}"/fic-*.request; do
  mapfile -t fields < "${request}"
  key="$(basename "${request}" .request)"
  az identity federated-credential list \
    --subscription "${fields[0]}" \
    --resource-group "${fields[1]}" \
    --identity-name "${fields[2]}" \
    --output json > "${work_dir}/${key}.json"
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

node "${root}/infra/governance/validate-evidence.mjs" phase-a-binding \
  --manifest "${phase_a_evidence_dir}/manifest.json" \
  --plan "${phase_a_evidence_dir}/plan.json" \
  --parameters "${phase_a_evidence_dir}/parameters.json" \
  --approved-parameters "${phase_a_evidence_dir}/parameters.json" \
  --compiled-template "${phase_a_evidence_dir}/compiled-template.json" \
  --deployment "${phase_a_deployment_file}" \
  --operations "${phase_a_operations_file}" \
  --role-assignments "${phase_a_role_assignments_file}" \
  --policy-assignments "${phase_a_policy_assignments_file}" \
  --source-root "${root}" \
  --expected-manifest-sha256 "${phase_a_evidence_sha}" \
  --stage "${PHASE_B_STAGE:?Set PHASE_B_STAGE to B1 or B2.}" \
  --output "${phase_a_binding_file}"
