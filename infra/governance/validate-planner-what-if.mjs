import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

import { verifyManifestFiles } from './validate-evidence.mjs';

const identityName = 'id-certigo-governance-phase-b1a-plan';
const environmentName = 'azure-governance-bootstrap-phase-b';
const expectedSubject =
  `repo:gchambaud_microsoft/Certigo:environment:${environmentName}`;
const exactScopes = [
  'rg-certigo-dev',
  'rg-certigo-staging',
  'rg-certigo-prod',
  'rg-certigo-ci',
  'rg-certigo-content',
];

function normalize(value) {
  return String(value ?? '').toLowerCase().replace(/\/+$/, '');
}

function same(actual = [], expected = []) {
  return (
    JSON.stringify(actual.map(normalize).sort()) ===
    JSON.stringify(expected.map(normalize).sort())
  );
}

export function validatePlannerWhatIf(plan, subscriptionId) {
  if (
    plan.status !== 'Succeeded' ||
    plan.error != null ||
    plan.diagnostics != null ||
    plan.potentialChanges != null ||
    !Array.isArray(plan.changes)
  ) {
    throw new Error('planner what-if is incomplete or diagnostic');
  }
  const contracts = new Set();
  const identityId =
    `/subscriptions/${subscriptionId}/resourceGroups/rg-certigo-identities/` +
    `providers/Microsoft.ManagedIdentity/userAssignedIdentities/${identityName}`;
  for (const change of plan.changes) {
    if (!['Create', 'NoChange'].includes(change.changeType)) {
      throw new Error(`planner forbids ${change.changeType}`);
    }
    const after = change.after ?? {};
    const id = normalize(change.resourceId);
    let contract = null;
    if (id === normalize(identityId)) {
      contract = after.location?.toLowerCase() === 'westeurope'
        ? 'identity'
        : null;
    } else if (
      after.type ===
      'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials'
    ) {
      contract =
        id ===
          normalize(
            `${identityId}/federatedIdentityCredentials/github-${environmentName}`,
          ) &&
        after.properties?.issuer ===
          'https://token.actions.githubusercontent.com' &&
        after.properties?.subject === expectedSubject &&
        same(after.properties?.audiences, ['api://AzureADTokenExchange'])
          ? 'credential'
          : null;
    } else if (after.type === 'Microsoft.Authorization/roleDefinitions') {
      const permission = after.properties?.permissions?.[0] ?? {};
      contract =
        /^Certigo Governance Phase B1a Planner [a-z0-9]{6}$/.test(
          after.properties?.roleName ?? '',
        ) &&
        after.properties?.type === 'CustomRole' &&
        same(permission.actions, [
          'Microsoft.Authorization/roleAssignments/read',
          'Microsoft.Authorization/roleAssignments/write',
          'Microsoft.Authorization/roleDefinitions/read',
        ]) &&
        same(permission.notActions, []) &&
        same(permission.dataActions, []) &&
        same(permission.notDataActions, []) &&
        same(
          after.properties?.assignableScopes,
          exactScopes.map(
            (scope) =>
              `/subscriptions/${subscriptionId}/resourceGroups/${scope}`,
          ),
        )
          ? 'role'
          : null;
    } else if (
      id ===
      normalize(
        `/subscriptions/${subscriptionId}/resourceGroups/rg-certigo-identities`,
      )
    ) {
      contract = 'input-resource-group';
    }
    if (!contract) {
      throw new Error(`resource is outside planner contract: ${change.resourceId}`);
    }
    if (contracts.has(contract)) {
      throw new Error(`duplicate planner contract: ${contract}`);
    }
    contracts.add(contract);
  }
  for (const required of ['identity', 'credential', 'role']) {
    if (!contracts.has(required)) {
      throw new Error(`planner plan is incomplete: ${required}`);
    }
  }
  return { total: plan.changes.length };
}

export function validatePlannerEvidence(input) {
  const {
    manifestPath,
    expectedManifestSha256,
    sourceRoot,
    subscriptionId,
    tenantId,
  } = input;
  const artifactDirectory = path.dirname(manifestPath);
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  if (
    manifest.phase !== 'A0-B1a-Planner' ||
    normalize(manifest.subscriptionId) !== normalize(subscriptionId) ||
    normalize(manifest.tenantId) !== normalize(tenantId)
  ) {
    throw new Error('planner evidence scope or phase mismatch');
  }
  verifyManifestFiles(manifest, {
    manifestPath,
    planPath: path.join(artifactDirectory, 'plan.json'),
    parametersPath: path.join(artifactDirectory, 'parameters.json'),
    compiledTemplatePath: path.join(artifactDirectory, 'compiled-template.json'),
    sourceRoot,
    expectedManifestSha256,
    requireHead: true,
  });
  return validatePlannerWhatIf(
    JSON.parse(fs.readFileSync(path.join(artifactDirectory, 'plan.json'), 'utf8')),
    subscriptionId,
  );
}

function main() {
  if (process.argv[2] === 'evidence') {
    const [
      ,
      ,
      manifestPath,
      expectedManifestSha256,
      sourceRoot,
      subscriptionId,
      tenantId,
    ] = process.argv;
    process.stdout.write(
      `${JSON.stringify(
        validatePlannerEvidence({
          manifestPath: path.resolve(manifestPath),
          expectedManifestSha256,
          sourceRoot: path.resolve(sourceRoot),
          subscriptionId,
          tenantId,
        }),
      )}\n`,
    );
    return;
  }
  const [planPath, subscriptionId] = process.argv.slice(2);
  const plan = JSON.parse(fs.readFileSync(path.resolve(planPath), 'utf8'));
  process.stdout.write(
    `${JSON.stringify(validatePlannerWhatIf(plan, subscriptionId))}\n`,
  );
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  main();
}
