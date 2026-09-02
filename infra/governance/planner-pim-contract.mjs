import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

import { validateDeploymentParameters } from './validate-evidence.mjs';
import { validatePlannerEvidence } from './validate-planner-what-if.mjs';
import { armGuid, validatePhaseAProof } from './validate-what-if.mjs';

const identityName = 'id-certigo-governance-phase-b1a-plan';
const environmentName = 'azure-governance-bootstrap-phase-b';
const expectedSubject =
  `repo:gchambaud_microsoft/Certigo:environment:${environmentName}`;
const expectedIssuer = 'https://token.actions.githubusercontent.com';
const expectedAudience = 'api://AzureADTokenExchange';
const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
  '..',
);
const exactResourceGroups = [
  'rg-certigo-dev',
  'rg-certigo-staging',
  'rg-certigo-prod',
  'rg-certigo-ci',
];

function requireEqual(actual, expected, message) {
  if (normalize(actual) !== normalize(expected)) {
    throw new Error(message);
  }
}

function sha256File(filePath) {
  return createHash('sha256').update(fs.readFileSync(filePath)).digest('hex');
}

function same(actual = [], expected = []) {
  return (
    JSON.stringify(actual.map(normalize).sort()) ===
    JSON.stringify(expected.map(normalize).sort())
  );
}

export function validateLivePlannerResources(
  phaseA,
  planner,
  approvedParameters,
  identity,
  credentials,
  roleDefinition,
) {
  const proof = validatePhaseAProof(phaseA, phaseA.subscriptionId);
  const subscriptionScope = `/subscriptions/${proof.subscriptionId}`;
  const expectedRoleId =
    `${subscriptionScope}/providers/Microsoft.Authorization/roleDefinitions/` +
    armGuid(subscriptionScope, 'certigo-governance-phase-b1a-planner');
  const expectedLocation =
    approvedParameters?.parameters?.location?.value ?? 'westeurope';
  requireEqual(identity.id, planner.resourceId, 'live planner identity resource mismatch');
  requireEqual(identity.name, identityName, 'live planner identity name mismatch');
  requireEqual(identity.location, expectedLocation, 'live planner identity location mismatch');
  requireEqual(
    identity.properties?.clientId,
    planner.clientId,
    'live planner client ID mismatch',
  );
  requireEqual(
    identity.properties?.principalId,
    planner.principalId,
    'live planner principal ID mismatch',
  );
  if (!Array.isArray(credentials) || credentials.length !== 1) {
    throw new Error('live planner must have exactly one federated credential');
  }
  const [credential] = credentials;
  requireEqual(
    credential.id,
    `${planner.resourceId}/federatedIdentityCredentials/github-${environmentName}`,
    'live planner credential resource mismatch',
  );
  requireEqual(
    credential.properties?.issuer,
    expectedIssuer,
    'live planner credential issuer mismatch',
  );
  requireEqual(
    credential.properties?.subject,
    expectedSubject,
    'live planner credential subject mismatch',
  );
  if (!same(credential.properties?.audiences, [expectedAudience])) {
    throw new Error('live planner credential audience mismatch');
  }
  requireEqual(roleDefinition.id, expectedRoleId, 'live planner role resource mismatch');
  const properties = roleDefinition.properties ?? {};
  const permissions = properties.permissions;
  const permission =
    Array.isArray(permissions) && permissions.length === 1
      ? permissions[0]
      : {};
  if (
    properties.type !== 'CustomRole' ||
    permissions?.length !== 1 ||
    !same(permission.actions, [
      'Microsoft.Authorization/roleAssignments/read',
      'Microsoft.Authorization/roleAssignments/write',
      'Microsoft.Authorization/roleDefinitions/read',
    ]) ||
    !same(permission.notActions, []) ||
    !same(permission.dataActions, []) ||
    !same(permission.notDataActions, []) ||
    !same(
      properties.assignableScopes,
      exactResourceGroups.map(
        (name) => `${subscriptionScope}/resourceGroups/${name}`,
      ),
    )
  ) {
    throw new Error('live planner role definition violates the exact contract');
  }
  return planner;
}

export function validatePlannerAccess(inventory) {
  if (inventory.visibilityComplete !== true) {
    throw new Error('planner access visibility is incomplete');
  }
  if (
    !Array.isArray(inventory.groupIds) ||
    !Array.isArray(inventory.scopes) ||
    inventory.scopes.length === 0
  ) {
    throw new Error('planner access inventory is malformed');
  }
  for (const [name, values] of [
    ['active role assignments', inventory.activeAssignments],
    ['eligible PIM schedules', inventory.eligibleSchedules],
    ['active PIM schedules', inventory.activeSchedules],
  ]) {
    if (!Array.isArray(values)) {
      throw new Error(`planner ${name} inventory is malformed`);
    }
    if (values.length !== 0) {
      throw new Error(`planner has pre-existing ${name}`);
    }
  }
}

export function plannerAccessScopes(entities, subscriptionId, tenantId) {
  if (!Array.isArray(entities)) {
    throw new Error('management group visibility is incomplete');
  }
  const entityId = (entity) => entity.id ?? entity.properties?.id ?? '';
  const entityType = (entity) => entity.type ?? entity.properties?.type ?? '';
  const parentId = (entity) =>
    entity.parent?.id ?? entity.properties?.parent?.id ?? '';
  const subscriptionResourceId = `/subscriptions/${subscriptionId}`;
  const subscriptionEntities = entities.filter(
    (entity) =>
      normalize(entityId(entity)) === normalize(subscriptionResourceId) &&
      normalize(entityType(entity)) ===
        'microsoft.management/managementgroups/subscriptions',
  );
  if (subscriptionEntities.length !== 1) {
    throw new Error('subscription management group ancestry is not visible');
  }
  const [subscriptionEntity] = subscriptionEntities;
  const scopes = [`/subscriptions/${subscriptionId}`];
  let currentParentId = parentId(subscriptionEntity);
  const seenParents = new Set();
  while (currentParentId) {
    const normalizedParent = normalize(currentParentId).replace(/\/+$/, '');
    if (
      !normalizedParent.match(
        /^\/providers\/microsoft\.management\/managementgroups\/[^/]+$/,
      )
    ) {
      throw new Error('management group parent ID is malformed');
    }
    if (seenParents.has(normalizedParent)) {
      throw new Error('management group ancestry contains a cycle');
    }
    seenParents.add(normalizedParent);
    const parentEntities = entities.filter(
      (candidate) =>
        normalize(entityId(candidate)) === normalizedParent &&
        normalize(entityType(candidate)) ===
          'microsoft.management/managementgroups',
    );
    if (parentEntities.length !== 1) {
      throw new Error('management group ancestry is incomplete');
    }
    const [entity] = parentEntities;
    scopes.push(currentParentId.replace(/\/+$/, ''));
    currentParentId = parentId(entity);
  }
  requireEqual(
    scopes.at(-1),
    `/providers/Microsoft.Management/managementGroups/${tenantId}`,
    'management group ancestry did not reach the tenant root',
  );
  return scopes;
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
  expectedDeploymentName,
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
  requireEqual(deployment.name, expectedDeploymentName, 'planner deployment name mismatch');
  requireEqual(
    deployment.id,
    `${subscriptionScope}/providers/Microsoft.Resources/deployments/` +
      expectedDeploymentName,
    'planner deployment resource mismatch',
  );
  requireEqual(
    deployment.location,
    approvedParameters?.parameters?.location?.value ?? 'westeurope',
    'planner deployment location mismatch',
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
      condition: condition([[
        environment(name).principalId,
        `${subscriptionScope}/providers/Microsoft.Authorization/` +
          'roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c',
      ]]),
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
    manifestPath,
    expectedManifestSha256,
    deploymentName,
    outputPath,
  ] = process.argv.slice(2);
  if (
    !manifestPath ||
    !expectedManifestSha256 ||
    !deploymentName ||
    !outputPath
  ) {
    throw new Error(
      'Usage: planner-pim-contract.mjs <planner-manifest> ' +
        '<planner-manifest-sha256> <planner-deployment-name> <output>',
    );
  }
  const workDirectory = fs.mkdtempSync(
    path.join(os.tmpdir(), 'certigo-planner-pim-contract-'),
  );
  fs.chmodSync(workDirectory, 0o700);
  process.once('exit', () => {
    fs.rmSync(workDirectory, { recursive: true, force: true });
  });
  execFileSync(
    'bash',
    [path.join(repositoryRoot, 'infra/governance/prepare-phase-b.sh')],
    {
      cwd: repositoryRoot,
      env: {
        ...process.env,
        PHASE_B_STAGE: 'B1a',
        PHASE_B_WORK_DIR: workDirectory,
      },
      stdio: 'inherit',
    },
  );
  const phaseA = JSON.parse(
    fs.readFileSync(path.join(workDirectory, 'phase-a.json'), 'utf8'),
  );
  const manifestResolved = path.resolve(manifestPath);
  const manifest = JSON.parse(fs.readFileSync(manifestResolved, 'utf8'));
  validatePlannerEvidence({
    manifestPath: manifestResolved,
    expectedManifestSha256,
    sourceRoot: repositoryRoot,
    subscriptionId: phaseA.subscriptionId,
    tenantId: phaseA.tenantId,
  });
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
    deploymentName,
  );
  const api = (resourceId, apiVersion) =>
    JSON.parse(
      execFileSync(
        'az',
        [
          'rest',
          '--method',
          'get',
          '--url',
          `https://management.azure.com${resourceId}?api-version=${apiVersion}`,
          '--output',
          'json',
        ],
        { encoding: 'utf8' },
      ),
    );
  const apiList = (resourceId, apiVersion, query = '') => {
    const values = [];
    let url =
      `https://management.azure.com${resourceId}?api-version=${apiVersion}${query}`;
    while (url) {
      const page = JSON.parse(
        execFileSync(
          'az',
          [
            'rest',
            '--method',
            'get',
            '--url',
            url,
            '--output',
            'json',
          ],
          { encoding: 'utf8' },
        ),
      );
      if (!Array.isArray(page.value)) {
        throw new Error('live planner credential list is malformed');
      }
      values.push(...page.value);
      url = page.nextLink ?? '';
    }
    return values;
  };
  const absoluteList = (initialUrl, headers = []) => {
    const values = [];
    let url = initialUrl;
    while (url) {
      const page = JSON.parse(
        execFileSync(
          'az',
          [
            'rest',
            '--method',
            'get',
            '--url',
            url,
            ...headers.flatMap((header) => ['--headers', header]),
            '--output',
            'json',
          ],
          { encoding: 'utf8' },
        ),
      );
      if (!Array.isArray(page.value)) {
        throw new Error('planner access list is malformed');
      }
      values.push(...page.value);
      url = page['@odata.nextLink'] ?? page.nextLink ?? '';
    }
    return values;
  };
  validateLivePlannerResources(
    phaseA,
    planner,
    JSON.parse(
      fs.readFileSync(path.join(path.dirname(manifestResolved), 'parameters.json'), 'utf8'),
    ),
    api(planner.resourceId, '2024-11-30'),
    apiList(
      `${planner.resourceId}/federatedIdentityCredentials`,
      '2024-11-30',
    ),
    api(planner.roleDefinitionId, '2022-04-01'),
  );
  const entities = JSON.parse(
    execFileSync(
      'az',
      ['account', 'management-group', 'entities', 'list', '--output', 'json'],
      { encoding: 'utf8' },
    ),
  );
  const scopes = plannerAccessScopes(
    entities,
    phaseA.subscriptionId,
    phaseA.tenantId,
  );
  const listAssignments = (principalId, args) => {
    const result = JSON.parse(
      execFileSync(
        'az',
        [
          'role',
          'assignment',
          'list',
          '--subscription',
          phaseA.subscriptionId,
          '--assignee-object-id',
          principalId,
          ...args,
          '--output',
          'json',
        ],
        { encoding: 'utf8' },
      ),
    );
    if (!Array.isArray(result)) {
      throw new Error('planner active role assignment inventory is malformed');
    }
    return result;
  };
  const schedules = (principalIds, resourceType) =>
    scopes.flatMap((scope) =>
      principalIds.flatMap((principalId) =>
        apiList(
          `${scope}/providers/Microsoft.Authorization/${resourceType}`,
          '2020-10-01',
          `&$filter=principalId%20eq%20'${principalId}'`,
        ),
      ),
    );
  const validatePrincipalAccess = (principalId) => {
    const directoryObjects = absoluteList(
      `https://graph.microsoft.com/v1.0/servicePrincipals/${principalId}/` +
        'transitiveMemberOf',
    );
    const groups = directoryObjects.filter(
      (entry) => entry['@odata.type'] === '#microsoft.graph.group',
    );
    if (groups.some((group) => !/^[0-9a-f-]{36}$/i.test(group.id ?? ''))) {
      throw new Error('group membership inventory is malformed');
    }
    const principalIds = [principalId, ...groups.map(({ id }) => id)];
    validatePlannerAccess({
      visibilityComplete: true,
      groupIds: groups.map(({ id }) => id),
      scopes,
      activeAssignments: principalIds.flatMap((candidateId) => [
        ...listAssignments(candidateId, ['--all']),
        ...listAssignments(candidateId, [
          '--scope',
          `/subscriptions/${phaseA.subscriptionId}`,
          '--include-inherited',
        ]),
      ]),
      eligibleSchedules: schedules(
        principalIds,
        'roleEligibilityScheduleInstances',
      ),
      activeSchedules: schedules(
        principalIds,
        'roleAssignmentScheduleInstances',
      ),
    });
  };
  validatePrincipalAccess(planner.principalId);
  for (const identity of Object.values(phaseA.identities)) {
    validatePrincipalAccess(identity.principalId);
  }
  const assignments = b1aPlannerAssignments(
    phaseA,
    planner,
  );
  fs.writeFileSync(
    path.resolve(outputPath),
    `${JSON.stringify({ schemaVersion: 1, assignments }, null, 2)}\n`,
    { mode: 0o600 },
  );
  fs.rmSync(workDirectory, { recursive: true, force: true });
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  main();
}
