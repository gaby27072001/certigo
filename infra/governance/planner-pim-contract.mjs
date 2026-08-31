import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

import { validateDeploymentParameters } from './validate-evidence.mjs';
import { armGuid, validatePhaseAProof } from './validate-what-if.mjs';

const identityName = 'id-certigo-governance-phase-b1a-plan';
const environmentName = 'azure-governance-bootstrap-phase-b';
const expectedSubject =
  `repo:gchambaud_microsoft/Certigo:environment:${environmentName}`;

function requireEqual(actual, expected, message) {
  if (normalize(actual) !== normalize(expected)) {
    throw new Error(message);
  }
}

function sha256File(filePath) {
  return createHash('sha256').update(fs.readFileSync(filePath)).digest('hex');
}

function normalize(value) {
  return String(value ?? '').toLowerCase();
}

function roleClause(principalId, roleDefinitionId) {
  return (
    `((@Request[Microsoft.Authorization/roleAssignments:PrincipalId] GuidEquals ${principalId}) AND ` +
    `(@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] GuidEquals ${roleDefinitionId.split('/').at(-1)}))`
  );
}

function condition(combinations) {
  return (
    "((!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})) OR " +
    `((${combinations.map(([principal, role]) => roleClause(principal, role)).join(' OR ')}) AND ` +
    '(@Request[Microsoft.Authorization/roleAssignments:PrincipalType] ' +
    "StringEqualsIgnoreCase 'ServicePrincipal')))"
  );
}

export function validatePlannerDeployment(
  phaseA,
  deployment,
  manifest,
  expectedManifestSha256,
  actualManifestSha256,
  approvedParameters,
) {
  const proof = validatePhaseAProof(phaseA, phaseA.subscriptionId);
  const subscriptionScope = `/subscriptions/${proof.subscriptionId}`;
  requireEqual(manifest.phase, 'A0-B1a-Planner', 'planner evidence phase mismatch');
  requireEqual(
    manifest.subscriptionId,
    proof.subscriptionId,
    'planner evidence subscription mismatch',
  );
  requireEqual(manifest.tenantId, proof.tenantId, 'planner evidence tenant mismatch');
  requireEqual(
    actualManifestSha256,
    expectedManifestSha256,
    'planner evidence manifest hash mismatch',
  );
  requireEqual(
    deployment.properties?.provisioningState,
    'Succeeded',
    'planner deployment state mismatch',
  );
  requireEqual(
    String(deployment.properties?.templateHash ?? ''),
    manifest.template?.armTemplateHash,
    'planner deployment template hash mismatch',
  );
  validateDeploymentParameters(deployment, approvedParameters);
  const planner = deployment.properties?.outputs?.governancePlanner?.value;
  if (!planner || planner.schemaVersion !== 1) {
    throw new Error('planner deployment output is missing or invalid');
  }
  const expectedIdentityId =
    `${subscriptionScope}/resourceGroups/rg-certigo-identities/providers/` +
    `Microsoft.ManagedIdentity/userAssignedIdentities/${identityName}`;
  const expectedRoleDefinitionId =
    `${subscriptionScope}/providers/Microsoft.Authorization/roleDefinitions/` +
    armGuid(subscriptionScope, 'certigo-governance-phase-b1a-planner');
  requireEqual(planner.subscriptionId, proof.subscriptionId, 'planner subscription mismatch');
  requireEqual(planner.tenantId, proof.tenantId, 'planner tenant mismatch');
  requireEqual(planner.identityName, identityName, 'planner identity name mismatch');
  requireEqual(planner.resourceId, expectedIdentityId, 'planner identity resource mismatch');
  requireEqual(planner.subject, expectedSubject, 'planner federated subject mismatch');
  requireEqual(
    planner.roleDefinitionId,
    expectedRoleDefinitionId,
    'planner role definition mismatch',
  );
  requireEqual(
    planner.subscriptionDeploymentLauncherRoleDefinitionId,
    proof.roleDefinitionIds.subscriptionDeploymentLauncher,
    'planner deployment launcher role mismatch',
  );
  for (const [name, value] of [
    ['clientId', planner.clientId],
    ['principalId', planner.principalId],
  ]) {
    if (!/^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(value ?? '')) {
      throw new Error(`planner ${name} is not a UUID`);
    }
  }
  return planner;
}

export function b1aPlannerAssignments(phaseA, planner) {
  const proof = validatePhaseAProof(phaseA, phaseA.subscriptionId);
  const subscriptionScope = `/subscriptions/${proof.subscriptionId}`;
  const environment = (name) =>
    proof.identities[
      `deploy${name[0].toUpperCase()}${name.slice(1)}`
    ];
  const rg = (name) => `${subscriptionScope}/resourceGroups/${name}`;
  return [
    {
      scope: subscriptionScope,
      principalId: planner.principalId,
      principalType: 'ServicePrincipal',
      roleDefinitionId:
        planner.subscriptionDeploymentLauncherRoleDefinitionId,
      condition: null,
      conditionVersion: null,
    },
    ...['dev', 'staging', 'prod'].map((name) => ({
      scope: rg(`rg-certigo-${name}`),
      principalId: planner.principalId,
      principalType: 'ServicePrincipal',
      roleDefinitionId: planner.roleDefinitionId,
      condition: condition([
        [
          environment(name).principalId,
          `${subscriptionScope}/providers/Microsoft.Authorization/` +
            'roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c',
        ],
        [
          environment(name).principalId,
          proof.roleDefinitionIds.runtimeRoleAssignmentWriter,
        ],
      ]),
      conditionVersion: '2.0',
    })),
    {
      scope: rg('rg-certigo-ci'),
      principalId: planner.principalId,
      principalType: 'ServicePrincipal',
      roleDefinitionId: planner.roleDefinitionId,
      condition: condition(
        ['dev', 'staging', 'prod'].map((name) => [
          environment(name).principalId,
          proof.roleDefinitionIds.sharedNetworkDeployment,
        ]),
      ),
      conditionVersion: '2.0',
    },
    {
      scope: rg('rg-certigo-content'),
      principalId: planner.principalId,
      principalType: 'ServicePrincipal',
      roleDefinitionId: planner.roleDefinitionId,
      condition: condition([
        [
          proof.identities.contentInfrastructurePlan.principalId,
          proof.roleDefinitionIds.contentInfrastructurePlanExecutor,
        ],
      ]),
      conditionVersion: '2.0',
    },
  ];
}

export function validateB1aPlannerAssignments(
  assignments,
  phaseA,
  planner,
) {
  const expected = b1aPlannerAssignments(phaseA, planner);
  if (
    assignments.length !== expected.length ||
    JSON.stringify(
      assignments
        .map((assignment) => ({
          ...assignment,
          scope: normalize(assignment.scope),
          principalId: normalize(assignment.principalId),
          roleDefinitionId: normalize(assignment.roleDefinitionId),
        }))
        .sort((left, right) => left.scope.localeCompare(right.scope)),
    ) !==
      JSON.stringify(
        expected
          .map((assignment) => ({
            ...assignment,
            scope: normalize(assignment.scope),
            principalId: normalize(assignment.principalId),
            roleDefinitionId: normalize(assignment.roleDefinitionId),
          }))
          .sort((left, right) => left.scope.localeCompare(right.scope)),
      )
  ) {
    throw new Error('B1a planner assignments violate the exact PIM contract');
  }
  return assignments;
}

function main() {
  const [
    phaseAPath,
    manifestPath,
    expectedManifestSha256,
    deploymentName,
    outputPath,
  ] = process.argv.slice(2);
  if (
    !phaseAPath ||
    !manifestPath ||
    !expectedManifestSha256 ||
    !deploymentName ||
    !outputPath
  ) {
    throw new Error(
      'Usage: planner-pim-contract.mjs <phase-a-proof> <planner-manifest> ' +
        '<planner-manifest-sha256> <planner-deployment-name> <output>',
    );
  }
  const phaseA = JSON.parse(fs.readFileSync(path.resolve(phaseAPath), 'utf8'));
  const manifestResolved = path.resolve(manifestPath);
  const manifest = JSON.parse(fs.readFileSync(manifestResolved, 'utf8'));
  const deployment = JSON.parse(
    execFileSync(
      'az',
      [
        'deployment',
        'sub',
        'show',
        '--subscription',
        phaseA.subscriptionId,
        '--name',
        deploymentName,
        '--output',
        'json',
      ],
      { encoding: 'utf8' },
    ),
  );
  const planner = validatePlannerDeployment(
    phaseA,
    deployment,
    manifest,
    expectedManifestSha256,
    sha256File(manifestResolved),
    JSON.parse(
      fs.readFileSync(path.join(path.dirname(manifestResolved), 'parameters.json'), 'utf8'),
    ),
  );
  const assignments = b1aPlannerAssignments(
    phaseA,
    planner,
  );
  fs.writeFileSync(
    path.resolve(outputPath),
    `${JSON.stringify({ schemaVersion: 1, assignments }, null, 2)}\n`,
    { mode: 0o600 },
  );
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  main();
}
