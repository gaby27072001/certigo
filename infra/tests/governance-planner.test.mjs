import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  b1aPlannerAssignments,
  plannerAccessScopes,
  validatePlannerAccess,
  validateLivePlannerResources,
  validatePlannerDeployment,
  validateB1aPlannerAssignments,
} from '../governance/planner-pim-contract.mjs';
import { armGuid } from '../governance/validate-what-if.mjs';
import { validatePlannerWhatIf } from
  '../governance/validate-planner-what-if.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const subscription = '00000000-0000-0000-0000-000000000001';

function compile() {
  return JSON.parse(
    execFileSync(
      process.env.BICEP_CLI || 'bicep',
      ['build', path.join(root, 'infra/governance/bootstrap-planning-identity.bicep'), '--stdout'],
      { encoding: 'utf8' },
    ),
  );
}

function resources(template) {
  const result = [];
  function visit(current) {
    for (const resource of current?.resources ?? []) {
      result.push(resource);
      visit(resource.properties?.template);
    }
  }
  visit(template);
  return result;
}

function proof() {
  const identity = (name, suffix) => ({
    clientId: `10000000-0000-0000-0000-0000000000${suffix}`,
    name,
    principalId: `20000000-0000-0000-0000-0000000000${suffix}`,
    resourceId:
      `/subscriptions/${subscription}/resourceGroups/rg-certigo-identities/` +
      `providers/Microsoft.ManagedIdentity/userAssignedIdentities/${name}`,
  });
  const role = (seed) =>
    `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
    `roleDefinitions/${armGuid(`/subscriptions/${subscription}`, seed)}`;
  return {
    schemaVersion: 2,
    subscriptionId: subscription,
    tenantId: '00000000-0000-0000-0000-000000000002',
    contentResourceGroupId:
      `/subscriptions/${subscription}/resourceGroups/rg-certigo-content`,
    identityResourceGroupId:
      `/subscriptions/${subscription}/resourceGroups/rg-certigo-identities`,
    identities: {
      deployDev: identity('id-certigo-deploy-dev', '01'),
      deployStaging: identity('id-certigo-deploy-staging', '02'),
      deployProd: identity('id-certigo-deploy-prod', '03'),
      contentInfrastructurePlan: {
        ...identity('id-certigo-content-infra-plan', '04'),
        federatedSubject:
          'repo:gchambaud_microsoft/Certigo:environment:azure-content-infra-plan',
      },
      contentRelease: identity('id-certigo-content-release', '05'),
      contentPublic: identity('id-certigo-content-public', '06'),
      contentAnswerKey: identity('id-certigo-content-answer-key', '07'),
      contentReader: identity('id-certigo-content-reader', '08'),
    },
    policyDefinitionId: role('certigo-privileged-ci-role-assignments').replace(
      '/roleDefinitions/',
      '/policyDefinitions/',
    ),
    roleDefinitionIds: {
      subscriptionDeploymentLauncher: role('certigo-subscription-deployment-launcher'),
      runtimeRoleAssignmentWriter: role('certigo-runtime-role-assignment-writer'),
      sharedNetworkDeployment: role('certigo-shared-network-deployment'),
      contentPublisher:
        `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
        'roleDefinitions/c8a9d1bb-39d7-4f4f-9a4c-17b4c81aa5de',
      contentInfrastructurePlanExecutor: role('certigo-content-infrastructure-plan-executor'),
      contentInfrastructurePlanExternalJoin: role('certigo-content-infrastructure-plan-external-join'),
    },
  };
}

test('A0 planner bootstrap creates one B1a identity and no assignments', () => {
  const template = compile();
  const all = resources(template);
  assert.equal(
    all.filter(({ type }) => type === 'Microsoft.ManagedIdentity/userAssignedIdentities').length,
    1,
  );
  assert.equal(
    all.filter(
      ({ type }) =>
        type ===
        'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials',
    ).length,
    1,
  );
  assert.equal(
    all.filter(
      ({ type }) =>
        type === 'Microsoft.Authorization/roleAssignments' ||
        type === 'Microsoft.Authorization/policyAssignments',
    ).length,
    0,
  );
  const [role] = all.filter(
    ({ type }) => type === 'Microsoft.Authorization/roleDefinitions',
  );
  assert.deepEqual(role.properties.permissions[0].actions.sort(), [
    'Microsoft.Authorization/roleAssignments/read',
    'Microsoft.Authorization/roleAssignments/write',
    'Microsoft.Authorization/roleDefinitions/read',
  ].sort());
  assert.equal(
    role.properties.assignableScopes,
    "[variables('exactAssignmentScopes')]",
  );
  assert.equal(template.variables.exactAssignmentScopes.length, 4);
});

function plannerPlan() {
  const identityId =
    `/subscriptions/${subscription}/resourceGroups/rg-certigo-identities/` +
    'providers/Microsoft.ManagedIdentity/userAssignedIdentities/' +
    'id-certigo-governance-phase-b1a-plan';
  return {
    status: 'Succeeded',
    error: null,
    diagnostics: null,
    potentialChanges: null,
    changes: [
      {
        changeType: 'Create',
        resourceId: identityId,
        after: {
          type: 'Microsoft.ManagedIdentity/userAssignedIdentities',
          location: 'westeurope',
        },
      },
      {
        changeType: 'Create',
        resourceId:
          `${identityId}/federatedIdentityCredentials/` +
          'github-azure-governance-bootstrap-phase-b',
        after: {
          type:
            'Microsoft.ManagedIdentity/userAssignedIdentities/' +
            'federatedIdentityCredentials',
          properties: {
            issuer: 'https://token.actions.githubusercontent.com',
            subject:
              'repo:gchambaud_microsoft/Certigo:environment:' +
              'azure-governance-bootstrap-phase-b',
            audiences: ['api://AzureADTokenExchange'],
          },
        },
      },
      {
        changeType: 'Create',
        resourceId:
          `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
          `roleDefinitions/${armGuid(
            `/subscriptions/${subscription}`,
            'certigo-governance-phase-b1a-planner',
          )}`,
        after: {
          type: 'Microsoft.Authorization/roleDefinitions',
          properties: {
            roleName: 'Certigo Governance Phase B1a Planner abc123',
            type: 'CustomRole',
            permissions: [
              {
                actions: [
                  'Microsoft.Authorization/roleAssignments/read',
                  'Microsoft.Authorization/roleAssignments/write',
                  'Microsoft.Authorization/roleDefinitions/read',
                ],
                notActions: [],
                dataActions: [],
                notDataActions: [],
              },
            ],
            assignableScopes: [
              'rg-certigo-dev',
              'rg-certigo-staging',
              'rg-certigo-prod',
              'rg-certigo-ci',
            ].map(
              (name) =>
                `/subscriptions/${subscription}/resourceGroups/${name}`,
            ),
          },
        },
      },
    ],
  };
}

test('planner validator rejects confused-deputy and privilege escalation', () => {
  assert.equal(validatePlannerWhatIf(plannerPlan(), subscription).total, 3);
  for (const mutate of [
    (plan) => {
      plan.changes[1].after.properties.subject =
        'repo:attacker/repository:environment:azure-governance-bootstrap-phase-b';
    },
    (plan) => {
      plan.changes[1].after.properties.audiences = ['api://attacker'];
    },
    (plan) => {
      plan.changes[2].after.properties.permissions[0].actions.push(
        'Microsoft.Authorization/policyAssignments/write',
      );
    },
    (plan) => {
      plan.changes[2].after.properties.permissions.push({
        actions: ['*'],
        notActions: [],
        dataActions: ['*'],
        notDataActions: [],
      });
    },
    (plan) => {
      plan.changes.push({
        changeType: 'Create',
        resourceId:
          `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
          'roleAssignments/90000000-0000-0000-0000-000000000001',
        after: { type: 'Microsoft.Authorization/roleAssignments' },
      });
    },
  ]) {
    const invalid = plannerPlan();
    mutate(invalid);
    assert.throws(
      () => validatePlannerWhatIf(invalid, subscription),
      /outside planner contract/,
    );
  }
});

test('A0 deployment instructions verify the complete approved evidence', () => {
  const validator = fs.readFileSync(
    path.join(root, 'infra/governance/validate-planner-what-if.mjs'),
    'utf8',
  );
  const runbook = fs.readFileSync(
    path.join(root, 'docs/runbooks/CLOUD_LEAST_PRIVILEGE.md'),
    'utf8',
  );
  assert.match(validator, /verifyManifestFiles\(manifest,/);
  assert.match(
    validator,
    /parametersPath: path\.join\(artifactDirectory, 'parameters\.json'\)/,
  );
  assert.match(validator, /requireHead: true/);
  assert.match(
    runbook,
    /validate-planner-what-if\.mjs evidence[\s\S]+approved-planner-manifest-sha256/,
  );
  const contract = fs.readFileSync(
    path.join(root, 'infra/governance/planner-pim-contract.mjs'),
    'utf8',
  );
  assert.match(contract, /validatePlannerEvidence\(\{/);
  assert.match(contract, /transitiveMemberOf/);
  assert.doesNotMatch(contract, /ConsistencyLevel=eventual|\$count=true/);
  assert.match(
    contract,
    /--scope[\s\S]+\/subscriptions\/\$\{phaseA\.subscriptionId\}[\s\S]+--include-inherited/,
  );
});

test('planner evidence CLI parses arguments after the subcommand', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'planner-evidence-cli-'));
  const manifestPath = path.join(directory, 'manifest.json');
  fs.writeFileSync(manifestPath, '{}\n');
  const result = spawnSync(
    process.execPath,
    [
      path.join(root, 'infra/governance/validate-planner-what-if.mjs'),
      'evidence',
      manifestPath,
      'a'.repeat(64),
      root,
      subscription,
      proof().tenantId,
    ],
    { encoding: 'utf8' },
  );
  fs.rmSync(directory, { recursive: true, force: true });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /planner evidence scope or phase mismatch/);
  assert.doesNotMatch(result.stderr, /ENOENT.*evidence/);
});

test('planner contract rejects every pre-existing active or eligible access', () => {
  const empty = {
    visibilityComplete: true,
    groupIds: [],
    scopes: [`/subscriptions/${subscription}`],
    activeAssignments: [],
    eligibleSchedules: [],
    activeSchedules: [],
  };
  assert.doesNotThrow(() => validatePlannerAccess(empty));
  for (const name of [
    'activeAssignments',
    'eligibleSchedules',
    'activeSchedules',
  ]) {
    const inventory = structuredClone(empty);
    inventory[name].push({ id: 'unexpected' });
    assert.throws(
      () => validatePlannerAccess(inventory),
      /planner has pre-existing/,
    );
  }
  assert.throws(
    () => validatePlannerAccess({ ...empty, visibilityComplete: false }),
    /visibility is incomplete/,
  );
  assert.throws(
    () =>
      validatePlannerAccess({
        ...empty,
        groupIds: ['90000000-0000-0000-0000-000000000001'],
        activeAssignments: [{ principalType: 'Group' }],
      }),
    /pre-existing active role assignments/,
  );
});

test('planner access scopes follow only complete management-group parent IDs', () => {
  const rootId =
    `/providers/Microsoft.Management/managementGroups/${
      proof().tenantId
    }`;
  const childId =
    '/providers/Microsoft.Management/managementGroups/platform';
  const entities = [
    {
      id: `/subscriptions/${subscription}`,
      name: subscription,
      type: 'Microsoft.Management/managementGroups/subscriptions',
      parent: { id: childId },
      parentNameChain: ['ignored-display-name'],
    },
    {
      id: childId,
      type: 'Microsoft.Management/managementGroups',
      properties: { parent: { id: rootId } },
    },
    {
      type: 'Microsoft.Management/managementGroups',
      properties: { id: rootId },
    },
  ];
  assert.deepEqual(plannerAccessScopes(entities, subscription, proof().tenantId), [
    `/subscriptions/${subscription}`,
    childId,
    rootId,
  ]);
  assert.throws(
    () =>
      plannerAccessScopes(
        entities.slice(0, 2),
        subscription,
        proof().tenantId,
      ),
    /ancestry is incomplete/,
  );
  const cycle = structuredClone(entities);
  cycle[2].properties.parent = { id: childId };
  assert.throws(
    () => plannerAccessScopes(cycle, subscription, proof().tenantId),
    /ancestry contains a cycle/,
  );
  assert.throws(
    () =>
      plannerAccessScopes(
        [
          {
            id: `/subscriptions/${subscription}`,
            type: 'Microsoft.Management/managementGroups/subscriptions',
            parent: { id: 'invalid' },
          },
        ],
        subscription,
        proof().tenantId,
      ),
    /parent ID is malformed/,
  );
  const truncated = structuredClone(entities);
  truncated[1].properties.parent = undefined;
  assert.throws(
    () => plannerAccessScopes(truncated, subscription, proof().tenantId),
    /did not reach the tenant root/,
  );
  const collidingManagementGroup = {
    id: '/providers/Microsoft.Management/managementGroups/collision',
    name: subscription,
    type: 'Microsoft.Management/managementGroups',
    parent: { id: rootId },
  };
  assert.deepEqual(
    plannerAccessScopes(
      [collidingManagementGroup, ...entities],
      subscription,
      proof().tenantId,
    ),
    [`/subscriptions/${subscription}`, childId, rootId],
  );
  const ambiguousSubscription = structuredClone(entities);
  ambiguousSubscription.push(structuredClone(entities[0]));
  assert.throws(
    () =>
      plannerAccessScopes(
        ambiguousSubscription,
        subscription,
        proof().tenantId,
      ),
    /ancestry is not visible/,
  );
});

test('B1a PIM assignments pin exact principals roles and structural scopes', () => {
  const phaseA = proof();
  const subscriptionScope = `/subscriptions/${subscription}`;
  const planner = {
    schemaVersion: 1,
    clientId: '30000000-0000-0000-0000-000000000002',
    identityName: 'id-certigo-governance-phase-b1a-plan',
    principalId: '30000000-0000-0000-0000-000000000001',
    resourceId:
      `${subscriptionScope}/resourceGroups/rg-certigo-identities/providers/` +
      'Microsoft.ManagedIdentity/userAssignedIdentities/' +
      'id-certigo-governance-phase-b1a-plan',
    roleDefinitionId:
      `${subscriptionScope}/providers/Microsoft.Authorization/roleDefinitions/` +
      armGuid(subscriptionScope, 'certigo-governance-phase-b1a-planner'),
    subject:
      'repo:gchambaud_microsoft/Certigo:environment:' +
      'azure-governance-bootstrap-phase-b',
    subscriptionDeploymentLauncherRoleDefinitionId:
      phaseA.roleDefinitionIds.subscriptionDeploymentLauncher,
    subscriptionId: subscription,
    tenantId: phaseA.tenantId,
  };
  const manifest = {
    phase: 'A0-B1a-Planner',
    subscriptionId: subscription,
    tenantId: phaseA.tenantId,
    template: { armTemplateHash: '123456789' },
  };
  const deployment = {
    id:
      `${subscriptionScope}/providers/Microsoft.Resources/deployments/` +
      'certigo-governance-b1a-planner-bootstrap-test',
    name: 'certigo-governance-b1a-planner-bootstrap-test',
    location: 'westeurope',
    properties: {
      provisioningState: 'Succeeded',
      templateHash: '123456789',
      parameters: { location: { value: 'westeurope' } },
      outputs: { governancePlanner: { value: planner } },
    },
  };
  const approvedParameters = {
    parameters: { location: { value: 'westeurope' } },
  };
  const liveIdentity = {
    id: planner.resourceId,
    name: planner.identityName,
    location: 'westeurope',
    properties: {
      clientId: planner.clientId,
      principalId: planner.principalId,
    },
  };
  const liveCredential = {
    id:
      `${planner.resourceId}/federatedIdentityCredentials/` +
      'github-azure-governance-bootstrap-phase-b',
    properties: {
      issuer: 'https://token.actions.githubusercontent.com',
      subject: planner.subject,
      audiences: ['api://AzureADTokenExchange'],
    },
  };
  const liveRole = {
    id: planner.roleDefinitionId,
    properties: {
      type: 'CustomRole',
      permissions: [
        {
          actions: [
            'Microsoft.Authorization/roleAssignments/read',
            'Microsoft.Authorization/roleAssignments/write',
            'Microsoft.Authorization/roleDefinitions/read',
          ],
          notActions: [],
          dataActions: [],
          notDataActions: [],
        },
      ],
      assignableScopes: [
        'rg-certigo-dev',
        'rg-certigo-staging',
        'rg-certigo-prod',
        'rg-certigo-ci',
      ].map((name) => `${subscriptionScope}/resourceGroups/${name}`),
    },
  };
  assert.equal(
    validatePlannerDeployment(
      phaseA,
      deployment,
      manifest,
      'a'.repeat(64),
      'a'.repeat(64),
      approvedParameters,
      deployment.name,
    ),
    planner,
  );
  assert.equal(
    validateLivePlannerResources(
      phaseA,
      planner,
      approvedParameters,
      liveIdentity,
      [liveCredential],
      liveRole,
    ),
    planner,
  );
  for (const [resource, mutate] of [
    [liveIdentity, (value) => {
      value.properties.principalId = '90000000-0000-0000-0000-000000000001';
    }],
    [liveCredential, (value) => {
      value.properties.subject =
        'repo:attacker/repository:environment:azure-governance-bootstrap-phase-b';
    }],
    [liveRole, (value) => {
      value.properties.permissions[0].actions.push(
        'Microsoft.Authorization/policyAssignments/write',
      );
    }],
    [liveRole, (value) => {
      value.properties.permissions.push({
        actions: ['*'],
        notActions: [],
        dataActions: ['*'],
        notDataActions: [],
      });
    }],
  ]) {
    const identity = structuredClone(liveIdentity);
    const credential = structuredClone(liveCredential);
    const role = structuredClone(liveRole);
    const target =
      resource === liveIdentity
        ? identity
        : resource === liveCredential
          ? credential
          : role;
    mutate(target);
    assert.throws(
      () =>
        validateLivePlannerResources(
          phaseA,
          planner,
          approvedParameters,
          identity,
          [credential],
          role,
        ),
      /live planner/,
    );
  }
  assert.throws(
    () =>
      validateLivePlannerResources(
        phaseA,
        planner,
        approvedParameters,
        liveIdentity,
        [
          liveCredential,
          {
            ...structuredClone(liveCredential),
            id:
              `${planner.resourceId}/federatedIdentityCredentials/` +
              'github-attacker',
            properties: {
              ...liveCredential.properties,
              subject:
                'repo:attacker/repository:environment:' +
                'azure-governance-bootstrap-phase-b',
            },
          },
        ],
        liveRole,
      ),
    /exactly one federated credential/,
  );
  for (const mutate of [
    (value) => {
      value.name = 'replayed-deployment';
    },
    (value) => {
      value.id =
        `${subscriptionScope}/providers/Microsoft.Resources/deployments/` +
        'replayed-deployment';
    },
    (value) => {
      value.location = 'eastus';
    },
    (value) => {
      value.properties.templateHash = 'stale-template';
    },
    (value) => {
      value.properties.outputs.governancePlanner.value.roleDefinitionId =
        `${subscriptionScope}/providers/Microsoft.Authorization/roleDefinitions/` +
        '90000000-0000-0000-0000-000000000001';
    },
    (value) => {
      value.properties.outputs.governancePlanner.value.subject =
        'repo:attacker/repository:environment:azure-governance-bootstrap-phase-b';
    },
    (value) => {
      value.properties.outputs.governancePlanner.value
        .subscriptionDeploymentLauncherRoleDefinitionId =
        `${subscriptionScope}/providers/Microsoft.Authorization/roleDefinitions/` +
        '8e3af657-a8ff-443c-a75c-2fe8c4bcb635';
    },
  ]) {
    const invalid = structuredClone(deployment);
    mutate(invalid);
    assert.throws(
      () =>
        validatePlannerDeployment(
          phaseA,
          invalid,
          manifest,
          'a'.repeat(64),
          'a'.repeat(64),
          approvedParameters,
          deployment.name,
        ),
      /planner .* mismatch/,
    );
  }
  assert.throws(
    () =>
      validatePlannerDeployment(
        phaseA,
        deployment,
        manifest,
        'b'.repeat(64),
        'a'.repeat(64),
        approvedParameters,
        deployment.name,
      ),
    /manifest hash mismatch/,
  );
  const wrongParameters = structuredClone(deployment);
  wrongParameters.properties.parameters.location.value = 'eastus';
  assert.throws(
    () =>
      validatePlannerDeployment(
        phaseA,
        wrongParameters,
        manifest,
        'a'.repeat(64),
        'a'.repeat(64),
        approvedParameters,
        deployment.name,
      ),
    /deployment parameter mismatch/,
  );
  const assignments = b1aPlannerAssignments(phaseA, planner);
  assert.equal(assignments.length, 5);
  assert.equal(
    validateB1aPlannerAssignments(assignments, phaseA, planner),
    assignments,
  );
  assert.equal(assignments.filter(({ condition }) => condition === null).length, 1);
  assert.ok(
    assignments
      .filter(({ condition }) => condition !== null)
      .every(
        ({ condition }) =>
          condition.includes('PrincipalId') &&
          condition.includes('RoleDefinitionId') &&
          condition.includes('PrincipalType'),
      ),
  );
  for (const mutate of [
    (items) => {
      items[1].principalId = '90000000-0000-0000-0000-000000000001';
    },
    (items) => {
      items[1].scope += '/providers/Microsoft.Storage/storageAccounts/attacker';
    },
    (items) => {
      items[1].condition = items[1].condition.replace(
        phaseA.identities.deployDev.principalId,
        '90000000-0000-0000-0000-000000000001',
      );
    },
    (items) => {
      items[1].roleDefinitionId =
        `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
        'roleDefinitions/90000000-0000-0000-0000-000000000001';
    },
  ]) {
    const invalid = structuredClone(assignments);
    mutate(invalid);
    assert.throws(
      () => validateB1aPlannerAssignments(invalid, phaseA, planner),
      /B1a planner assignments violate the exact PIM contract/,
    );
  }
});

test('A0 and B1b templates are human-only nonconditionable operations', () => {
  const bicep = execFileSync(
    process.env.BICEP_CLI || 'bicep',
    ['build', path.join(root, 'infra/governance/bootstrap-rbac-admin.bicep'), '--stdout'],
    { encoding: 'utf8' },
  );
  const template = JSON.parse(bicep);
  assert.equal(
    resources(template).filter(
      ({ type }) => type === 'Microsoft.Authorization/policyAssignments',
    ).length,
    1,
  );
  assert.equal(
    resources(template).filter(
      ({ type }) => type === 'Microsoft.Authorization/roleAssignments',
    ).length,
    4,
  );
  assert.equal(template.outputs.assignmentCount.value, 11);
});

test('subscription launcher adds only the reads required by Phase A binding', () => {
  const template = JSON.parse(
    execFileSync(
      process.env.BICEP_CLI || 'bicep',
      [
        'build',
        path.join(root, 'infra/governance/bootstrap-identities.bicep'),
        '--stdout',
      ],
      { encoding: 'utf8' },
    ),
  );
  const launcher = resources(template).find(
    ({ type, properties }) =>
      type === 'Microsoft.Authorization/roleDefinitions' &&
      properties.roleName.includes('Subscription Deployment Launcher'),
  );
  const actions = launcher.properties.permissions[0].actions;
  assert.ok(
    [
      'Microsoft.Authorization/policyAssignments/read',
      'Microsoft.Authorization/policyDefinitions/read',
      'Microsoft.Authorization/roleAssignments/read',
      'Microsoft.Authorization/roleDefinitions/read',
      'Microsoft.ManagedIdentity/userAssignedIdentities/read',
      'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials/read',
      'Microsoft.Resources/deployments/operations/read',
    ].every((action) => actions.includes(action)),
  );
  assert.equal(
    actions.filter(
      (action) =>
        action.endsWith('/write') &&
        action !== 'Microsoft.Resources/deployments/write',
    ).length,
    0,
  );
});
