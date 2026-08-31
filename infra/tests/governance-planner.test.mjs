import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  b1aPlannerAssignments,
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
  assert.equal(template.variables.exactAssignmentScopes.length, 5);
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
          'roleDefinitions/40000000-0000-0000-0000-000000000001',
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
              'rg-certigo-content',
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
  assert.equal(
    validatePlannerDeployment(
      phaseA,
      deployment,
      manifest,
      'a'.repeat(64),
      'a'.repeat(64),
      approvedParameters,
    ),
    planner,
  );
  for (const mutate of [
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
        ),
      /planner .* mismatch/,
    );
  }
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
      ),
    /deployment parameter mismatch/,
  );
  const assignments = b1aPlannerAssignments(phaseA, planner);
  assert.equal(assignments.length, 6);
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
    1,
  );
});
