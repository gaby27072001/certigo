import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  armGuid,
  contentPlanCondition,
  runtimeWriterCondition,
  validatePhaseAProof,
  validateWhatIf,
} from '../governance/validate-what-if.mjs';

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
  '..',
);
const subscription = '00000000-0000-0000-0000-000000000001';
const tenant = '00000000-0000-0000-0000-000000000002';
const templates = new Map();

function compileTemplate(relativePath) {
  if (!templates.has(relativePath)) {
    const bicep = process.env.BICEP_CLI || 'bicep';
    templates.set(
      relativePath,
      JSON.parse(
        execFileSync(
          bicep,
          ['build', path.join(repositoryRoot, relativePath), '--stdout'],
          { encoding: 'utf8' },
        ),
      ),
    );
  }
  return templates.get(relativePath);
}

function allResources(template) {
  const result = [];
  function visit(resources) {
    for (const resource of Array.isArray(resources)
      ? resources
      : Object.values(resources ?? {})) {
      result.push(resource);
      visit(resource.properties?.template?.resources);
    }
  }
  visit(template.resources);
  return result;
}

function resourcesOfType(template, type) {
  return allResources(template).filter((resource) => resource.type === type);
}

function makePhaseAProof() {
  const identity = (name, resourceGroup, suffix, extra = {}) => ({
    clientId: `10000000-0000-0000-0000-0000000000${suffix}`,
    name,
    principalId: `20000000-0000-0000-0000-0000000000${suffix}`,
    resourceId:
      `/subscriptions/${subscription}/resourceGroups/${resourceGroup}/providers/` +
      `Microsoft.ManagedIdentity/userAssignedIdentities/${name}`,
    ...extra,
  });
  const role = (seed) =>
    `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
    `roleDefinitions/${armGuid(`/subscriptions/${subscription}`, seed)}`;
  return {
    schemaVersion: 2,
    subscriptionId: subscription,
    tenantId: tenant,
    contentResourceGroupId:
      `/subscriptions/${subscription}/resourceGroups/rg-certigo-content`,
    identityResourceGroupId:
      `/subscriptions/${subscription}/resourceGroups/rg-certigo-identities`,
    identities: {
      contentAnswerKey: identity(
        'id-certigo-content-answer-key',
        'rg-certigo-identities',
        '01',
      ),
      contentInfrastructurePlan: identity(
        'id-certigo-content-infra-plan',
        'rg-certigo-identities',
        '02',
        {
          federatedSubject:
            'repo:gchambaud_microsoft/Certigo:environment:azure-content-infra-plan',
        },
      ),
      contentPublic: identity(
        'id-certigo-content-public',
        'rg-certigo-identities',
        '03',
      ),
      contentReader: identity(
        'id-certigo-content-reader',
        'rg-certigo-identities',
        '04',
      ),
      contentRelease: identity(
        'id-certigo-content-release',
        'rg-certigo-identities',
        '05',
      ),
      deployDev: identity('id-certigo-deploy-dev', 'rg-certigo-identities', '06'),
      deployProd: identity('id-certigo-deploy-prod', 'rg-certigo-identities', '07'),
      deployStaging: identity(
        'id-certigo-deploy-staging',
        'rg-certigo-identities',
        '08',
      ),
    },
    policyDefinitionId:
      `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
      `policyDefinitions/${armGuid(
        `/subscriptions/${subscription}`,
        'certigo-privileged-ci-role-assignments',
      )}`,
    roleDefinitionIds: {
      contentInfrastructurePlanExecutor: role(
        'certigo-content-infrastructure-plan-executor',
      ),
      contentInfrastructurePlanExternalJoin: role(
        'certigo-content-infrastructure-plan-external-join',
      ),
      contentPublisher:
        `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
        'roleDefinitions/c8a9d1bb-39d7-4f4f-9a4c-17b4c81aa5de',
      runtimeRoleAssignmentWriter: role(
        'certigo-runtime-role-assignment-writer',
      ),
      sharedNetworkDeployment: role('certigo-shared-network-deployment'),
      subscriptionDeploymentLauncher: role(
        'certigo-subscription-deployment-launcher',
      ),
    },
  };
}

function materializeNoChange(change) {
  const result = structuredClone(change);
  const parts = result.resourceId.split('/').filter(Boolean);
  const providerIndex = parts.lastIndexOf('providers');
  const types = [];
  for (
    let index = providerIndex + 2;
    providerIndex >= 0 && index < parts.length;
    index += 2
  ) {
    types.push(parts[index]);
  }
  result.changeType = 'NoChange';
  result.after = {
    ...result.after,
    id: result.resourceId,
    name: parts.at(-1),
    type:
      providerIndex >= 0
        ? `${parts[providerIndex + 1]}/${types.join('/')}`
        : 'Microsoft.Resources/resourceGroups',
    properties: result.after?.properties ?? {},
  };
  return result;
}

function deploymentChange(changeType, resourceId, properties = {}) {
  const change = materializeNoChange({
    resourceId,
    after: {
      properties,
    },
  });
  change.changeType = changeType;
  if (changeType === 'Ignore') {
    change.before = structuredClone(change.after);
    change.delta = null;
  }
  return change;
}

function whatIfPlan(changes) {
  return {
    changes,
    diagnostics: null,
    error: null,
    potentialChanges: null,
    status: 'Succeeded',
  };
}

function makeCompletePhaseAPlan(proof) {
  const template = compileTemplate(
    'infra/governance/bootstrap-identities.bicep',
  );
  const roleTemplates = resourcesOfType(
    template,
    'Microsoft.Authorization/roleDefinitions',
  );
  const roleFixtures = [
    [
      'subscriptionDeploymentLauncher',
      'Certigo Subscription Deployment Launcher abc123',
      [`/subscriptions/${subscription}`],
    ],
    [
      'runtimeRoleAssignmentWriter',
      'Certigo Runtime Role Assignment Writer abc123',
      ['dev', 'staging', 'prod'].map(
        (environment) =>
          `/subscriptions/${subscription}/resourceGroups/rg-certigo-${environment}`,
      ),
    ],
    [
      'sharedNetworkDeployment',
      'Certigo Shared Network Deployment abc123',
      [`/subscriptions/${subscription}/resourceGroups/rg-certigo-ci`],
    ],
    [
      'contentPublisher',
      'Certigo Immutable Content Publisher abc123',
      [`/subscriptions/${subscription}/resourceGroups/rg-certigo-content`],
    ],
    [
      'contentInfrastructurePlanExecutor',
      'Certigo Content Infrastructure Plan Executor abc123',
      [`/subscriptions/${subscription}/resourceGroups/rg-certigo-content`],
    ],
    [
      'contentInfrastructurePlanExternalJoin',
      'Certigo Content Infrastructure Plan External Join abc123',
      [`/subscriptions/${subscription}/resourceGroups/rg-certigo-ci`],
    ],
  ];
  const changes = [
    materializeNoChange({
      resourceId: proof.contentResourceGroupId,
      after: {
        location: 'westeurope',
        tags: {
          managedBy: 'bicep',
          product: 'Certigo',
          workload: 'immutable-content',
        },
        properties: {},
      },
    }),
    materializeNoChange({
      resourceId: proof.identityResourceGroupId,
      after: {
        location: 'westeurope',
        tags: {
          managedBy: 'bicep',
          product: 'Certigo',
          purpose: 'github-oidc-deployment',
        },
        properties: {},
      },
    }),
  ];
  for (let index = 0; index < roleFixtures.length; index += 1) {
    const [key, roleName, assignableScopes] = roleFixtures[index];
    changes.push(
      materializeNoChange({
        resourceId: proof.roleDefinitionIds[key],
        after: {
          properties: {
            assignableScopes,
            permissions: roleTemplates[index].properties.permissions,
            roleName,
            type: 'CustomRole',
          },
        },
      }),
    );
  }
  for (const identity of Object.values(proof.identities)) {
    changes.push(
      materializeNoChange({
        resourceId: identity.resourceId,
        after: {
          properties: {
            clientId: identity.clientId,
            principalId: identity.principalId,
          },
        },
      }),
    );
  }
  const credentialFixtures = [
    [
      proof.identities.deployDev,
      'github-dev',
      'repo:gchambaud_microsoft/Certigo:environment:dev',
    ],
    [
      proof.identities.deployStaging,
      'github-staging',
      'repo:gchambaud_microsoft/Certigo:environment:staging',
    ],
    [
      proof.identities.deployProd,
      'github-prod',
      'repo:gchambaud_microsoft/Certigo:environment:prod',
    ],
    [
      proof.identities.contentInfrastructurePlan,
      'github-azure-content-infra-plan',
      'repo:gchambaud_microsoft/Certigo:environment:azure-content-infra-plan',
    ],
    [
      proof.identities.contentRelease,
      'github-azure-content-release',
      'repo:gchambaud_microsoft/certigo-content:environment:azure-content-release',
    ],
    [
      proof.identities.contentPublic,
      'github-azure-content-public',
      'repo:gchambaud_microsoft/certigo-content:environment:azure-content-public',
    ],
    [
      proof.identities.contentAnswerKey,
      'github-azure-content-answer-key',
      'repo:gchambaud_microsoft/certigo-content:environment:azure-content-answer-key',
    ],
  ];
  for (const [identity, credentialName, subject] of credentialFixtures) {
    changes.push(
      materializeNoChange({
        resourceId:
          `${identity.resourceId}/federatedIdentityCredentials/${credentialName}`,
        after: {
          properties: {
            audiences: ['api://AzureADTokenExchange'],
            issuer: 'https://token.actions.githubusercontent.com',
            subject,
          },
        },
      }),
    );
  }
  changes.push(
    materializeNoChange({
      resourceId: proof.policyDefinitionId,
      after: {
        properties: {
          mode: 'All',
          parameters: {
            effect: {
              allowedValues: ['Audit', 'Deny', 'Disabled'],
              defaultValue: 'Audit',
            },
          },
          policyRule: {
            if: {
              allOf: [
                {
                  field: 'type',
                  equals: 'Microsoft.Authorization/roleAssignments',
                },
                {
                  field:
                    'Microsoft.Authorization/roleAssignments/principalType',
                  equals: 'ServicePrincipal',
                },
                {
                  field: 'Microsoft.Authorization/roleAssignments/scope',
                  equals: `/subscriptions/${subscription}`,
                },
                {
                  field:
                    'Microsoft.Authorization/roleAssignments/roleDefinitionId',
                  in: [
                    '8e3af657-a8ff-443c-a75c-2fe8c4bcb635',
                    'b24988ac-6180-42a0-ab88-20f7382dd24c',
                    '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9',
                    'f58310d9-a9f6-439a-9e8d-f62e7b41a168',
                  ].map(
                    (role) =>
                      `/subscriptions/${subscription}/providers/` +
                      `Microsoft.Authorization/roleDefinitions/${role}`,
                  ),
                },
              ],
            },
            then: { effect: "[parameters('effect')]" },
          },
          policyType: 'Custom',
        },
      },
    }),
  );
  return whatIfPlan(changes);
}

function roleAssignmentChange(scope, name, properties) {
  return {
    changeType: 'Create',
    resourceId:
      `${scope}/providers/Microsoft.Authorization/roleAssignments/${name}`,
    after: { properties },
  };
}

function makeCompletePhaseBPlan(proof) {
  const changes = [];
  let assignment = 1;
  const nextName = () =>
    `50000000-0000-0000-0000-${String(assignment++).padStart(12, '0')}`;
  const contributor =
    `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
    'roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c';
  for (const environment of ['dev', 'staging', 'prod']) {
    const key = `deploy${environment[0].toUpperCase()}${environment.slice(1)}`;
    const principalId = proof.identities[key].principalId;
    changes.push(
      roleAssignmentChange(`/subscriptions/${subscription}`, nextName(), {
        description:
          `Launches the ${environment} subscription deployment without general ` +
          'subscription access.',
        principalId,
        principalType: 'ServicePrincipal',
        roleDefinitionId:
          proof.roleDefinitionIds.subscriptionDeploymentLauncher,
      }),
      roleAssignmentChange(
        `/subscriptions/${subscription}/resourceGroups/rg-certigo-${environment}`,
        nextName(),
        {
          description:
            'Certigo environment deployment; no role-assignment administration.',
          principalId,
          principalType: 'ServicePrincipal',
          roleDefinitionId: contributor,
        },
      ),
      roleAssignmentChange(
        `/subscriptions/${subscription}/resourceGroups/rg-certigo-${environment}`,
        nextName(),
        {
          condition: runtimeWriterCondition(),
          conditionVersion: '2.0',
          description:
            'May create only approved runtime roles for service principals in this environment.',
          principalId,
          principalType: 'ServicePrincipal',
          roleDefinitionId:
            proof.roleDefinitionIds.runtimeRoleAssignmentWriter,
        },
      ),
      roleAssignmentChange(
        `/subscriptions/${subscription}/resourceGroups/rg-certigo-ci`,
        nextName(),
        {
          description:
            `Allows ${environment} to reconcile only shared DNS links and VNet peerings.`,
          principalId,
          principalType: 'ServicePrincipal',
          roleDefinitionId: proof.roleDefinitionIds.sharedNetworkDeployment,
        },
      ),
    );
  }
  const contentPrincipal =
    proof.identities.contentInfrastructurePlan.principalId;
  changes.push(
    roleAssignmentChange(
      `/subscriptions/${subscription}/resourceGroups/rg-certigo-content`,
      nextName(),
      {
        condition: contentPlanCondition(proof),
        conditionVersion: '2.0',
        description:
          'Plans the content stack and may assign only approved content roles to service principals.',
        principalId: contentPrincipal,
        principalType: 'ServicePrincipal',
        roleDefinitionId:
          proof.roleDefinitionIds.contentInfrastructurePlanExecutor,
      },
    ),
    roleAssignmentChange(
      `/subscriptions/${subscription}/resourceGroups/rg-certigo-ci/providers/` +
        'Microsoft.Network/virtualNetworks/vnet-certigo-ci/subnets/snet-runners',
      nextName(),
      {
        description:
          'Allows the content plan to read and join only the trusted CI runner subnet.',
        principalId: contentPrincipal,
        principalType: 'ServicePrincipal',
        roleDefinitionId:
          proof.roleDefinitionIds.contentInfrastructurePlanExternalJoin,
      },
    ),
    roleAssignmentChange(
      `/subscriptions/${subscription}/resourceGroups/rg-certigo-ci/providers/` +
        'Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net',
      nextName(),
      {
        description:
          'Allows the content plan to read and join only the shared Blob private DNS zone.',
        principalId: contentPrincipal,
        principalType: 'ServicePrincipal',
        roleDefinitionId:
          proof.roleDefinitionIds.contentInfrastructurePlanExternalJoin,
      },
    ),
    {
      changeType: 'Create',
      resourceId:
        `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
        'policyAssignments/certigo-privileged-ci-rbac',
      after: {
        properties: {
          enforcementMode: 'Default',
          parameters: { effect: { value: 'Audit' } },
          policyDefinitionId: proof.policyDefinitionId,
        },
      },
    },
  );
  return whatIfPlan(changes);
}

test('Phase A creates identities and definitions without effective permissions', () => {
  const template = compileTemplate(
    'infra/governance/bootstrap-identities.bicep',
  );
  const source = readFileSync(
    path.join(repositoryRoot, 'infra', 'governance', 'bootstrap-identities.bicep'),
    'utf8',
  );
  assert.deepEqual(
    resourcesOfType(template, 'Microsoft.Resources/resourceGroups').map(
      ({ name }) => name,
    ),
    [
      "[parameters('contentResourceGroupName')]",
      "[parameters('identityResourceGroupName')]",
    ],
  );
  assert.equal(
    resourcesOfType(template, 'Microsoft.Authorization/roleDefinitions').length,
    6,
  );
  const identities = resourcesOfType(
    template,
    'Microsoft.ManagedIdentity/userAssignedIdentities',
  );
  const credentials = resourcesOfType(
    template,
    'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials',
  );
  const deploymentIdentityCopy = template.resources.find(
    (resource) =>
      resource.type === 'Microsoft.Resources/deployments' &&
      resource.copy?.count === "[length(parameters('environments'))]",
  );
  assert.equal(identities.length + 2, 8);
  assert.equal(credentials.length + 2, 7);
  assert.ok(deploymentIdentityCopy);
  assert.equal(
    resourcesOfType(template, 'Microsoft.Authorization/policyDefinitions').length,
    1,
  );
  assert.equal(
    resourcesOfType(template, 'Microsoft.Authorization/roleAssignments').length,
    0,
  );
  assert.equal(
    resourcesOfType(template, 'Microsoft.Authorization/policyAssignments').length,
    0,
  );
  assert.doesNotMatch(
    source,
    /resource\s+\w+\s+'Microsoft\.Resources\/resourceGroups@[^']+'\s+existing\s*=\s*\{\s*name:\s*ciResourceGroupName/s,
  );
  assert.doesNotMatch(source, /scope:\s*ciResourceGroup/);
  assert.ok(template.outputs.phaseA);
});

test('Phase A custom roles contain no wildcard or delete action', () => {
  const template = compileTemplate(
    'infra/governance/bootstrap-identities.bicep',
  );
  for (const role of resourcesOfType(
    template,
    'Microsoft.Authorization/roleDefinitions',
  )) {
    const permissions = role.properties.permissions.flatMap((value) => [
      ...(value.actions ?? []),
      ...(value.dataActions ?? []),
    ]);
    assert.ok(permissions.every((permission) => !permission.includes('*')));
    assert.ok(permissions.every((permission) => !/delete/i.test(permission)));
    assert.deepEqual(
      role.properties.permissions.flatMap((value) => value.dataActions ?? []),
      [],
    );
  }
});

test('Phase B consumes Phase A resources as existing and creates exact assignments', () => {
  const template = compileTemplate('infra/governance/bootstrap-rbac.bicep');
  const source = readFileSync(
    path.join(repositoryRoot, 'infra', 'governance', 'bootstrap-rbac.bicep'),
    'utf8',
  );
  const topLevelAssignments = template.resources.filter(
    (resource) => resource.type === 'Microsoft.Authorization/roleAssignments',
  );
  const assignmentDeployments = template.resources.filter(
    (resource) =>
      resource.type === 'Microsoft.Resources/deployments' &&
      resourcesOfType(resource.properties.template, 'Microsoft.Authorization/roleAssignments')
        .length > 0,
  );
  assert.equal(topLevelAssignments.length, 1);
  assert.equal(
    topLevelAssignments[0].copy.count,
    "[length(variables('environments'))]",
  );
  assert.deepEqual(
    assignmentDeployments.map((deployment) => ({
      copy: deployment.copy?.count ?? null,
      nested: resourcesOfType(
        deployment.properties.template,
        'Microsoft.Authorization/roleAssignments',
      ).length,
    })),
    [
      { copy: "[length(variables('environments'))]", nested: 2 },
      { copy: "[length(variables('environments'))]", nested: 1 },
      { copy: null, nested: 1 },
      { copy: null, nested: 2 },
    ],
  );
  assert.equal(
    resourcesOfType(template, 'Microsoft.Authorization/policyAssignments').length,
    1,
  );
  assert.equal(
    resourcesOfType(template, 'Microsoft.Authorization/roleDefinitions').length,
    0,
  );
  assert.equal(
    resourcesOfType(
      template,
      'Microsoft.ManagedIdentity/userAssignedIdentities',
    ).length,
    0,
  );
  assert.match(
    source,
    /resource deploymentIdentities .* existing =/s,
  );
  assert.match(
    source,
    /resource contentInfrastructurePlanIdentity .* existing =/s,
  );
  assert.match(source, /resource contentIdentities .* existing =/s);
  assert.match(
    source,
    /resource subscriptionDeploymentLauncher .* existing =/s,
  );
  assert.match(source, /resource privilegedCiAssignmentPolicy .* existing =/s);
});

test('external assignments use only literal expected subnet and DNS resources', () => {
  const template = compileTemplate(
    'infra/governance/modules/contentPlanExternalJoinAssignments.bicep',
  );
  const assignments = resourcesOfType(
    template,
    'Microsoft.Authorization/roleAssignments',
  );
  assert.equal(assignments.length, 2);
  assert.deepEqual(
    assignments.map(({ scope }) => scope),
    [
      "[resourceId('Microsoft.Network/virtualNetworks/subnets', parameters('ciVnetName'), parameters('ciRunnerSubnetName'))]",
      "[resourceId('Microsoft.Network/privateDnsZones', parameters('blobPrivateDnsZoneName'))]",
    ],
  );
});

test('Phase B proof validation is mandatory, complete, and subscription-bound', () => {
  const proof = makePhaseAProof();
  assert.equal(validatePhaseAProof(proof, subscription), proof);
  assert.throws(
    () => validateWhatIf(whatIfPlan([]), subscription, { phase: 'B' }),
    /Phase A proof is missing/,
  );
  assert.throws(
    () =>
      validatePhaseAProof(
        {
          ...proof,
          identities: {
            ...proof.identities,
            deployProd: undefined,
          },
        },
        subscription,
      ),
    /deployProd is missing or invalid/,
  );
  assert.throws(
    () =>
      validatePhaseAProof(
        {
          ...proof,
          subscriptionId: '00000000-0000-0000-0000-000000000099',
        },
        subscription,
      ),
    /subscriptionId does not match/,
  );
});

test('phase validators reject mutation types and RBAC in Phase A', () => {
  assert.throws(
    () => validateWhatIf(whatIfPlan([]), subscription, { phase: 'A' }),
    /Phase A plan is incomplete/,
  );
  for (const changeType of ['Modify', 'Delete', 'Unsupported']) {
    assert.throws(
      () =>
        validateWhatIf(
          whatIfPlan([
              {
                changeType,
                resourceId:
                  `/subscriptions/${subscription}/resourceGroups/` +
                  'rg-certigo-content',
              },
          ]),
          subscription,
          { phase: 'A' },
        ),
      new RegExp(`Phase A forbids ${changeType}`),
    );
  }
  assert.throws(
    () =>
      validateWhatIf(
        whatIfPlan([
            {
              changeType: 'Create',
              resourceId:
                `/subscriptions/${subscription}/resourceGroups/rg-certigo-content/` +
                'providers/Microsoft.Authorization/roleAssignments/attack',
              after: { properties: {} },
            },
        ]),
        subscription,
        { phase: 'A' },
      ),
    /outside the exact Phase A contract/,
  );
});

test('phase validators reject incomplete or diagnostic what-if payloads', () => {
  const invalidPlans = [
    [{ ...whatIfPlan([]), status: 'Failed' }, /status must be Succeeded/],
    [{ ...whatIfPlan([]), error: { code: 'InvalidTemplate' } }, /error payload/],
    [
      {
        ...whatIfPlan([]),
        diagnostics: [{ level: 'Warning', message: 'Expansion limited' }],
      },
      /returned diagnostics/,
    ],
    [
      { ...whatIfPlan([]), potentialChanges: [{ resourceId: 'unknown' }] },
      /expansion is incomplete/,
    ],
    [{ ...whatIfPlan([]), changes: null }, /materialized array/],
  ];
  for (const [plan, expected] of invalidPlans) {
    assert.throws(
      () => validateWhatIf(plan, subscription, { phase: 'A' }),
      expected,
    );
  }

  const unsupported = makeCompletePhaseAPlan(makePhaseAProof());
  unsupported.changes[0].unsupportedReason = 'Resource expansion was limited';
  assert.throws(
    () => validateWhatIf(unsupported, subscription, { phase: 'A' }),
    /rejects unsupported resource expansion/,
  );
});

test('Phase A accepts exact NoChange and mixed retry plans only', () => {
  const proof = makePhaseAProof();
  const exact = makeCompletePhaseAPlan(proof);
  assert.equal(
    validateWhatIf(exact, subscription, { phase: 'A' }).total,
    24,
  );

  const mixed = structuredClone(exact);
  for (let index = 0; index < mixed.changes.length; index += 2) {
    mixed.changes[index].changeType = 'Create';
  }
  assert.equal(
    validateWhatIf(mixed, subscription, { phase: 'A' }).total,
    24,
  );

  const wrongRole = structuredClone(exact);
  wrongRole.changes
    .find(({ resourceId }) =>
      resourceId.includes('/roleDefinitions/'),
    )
    .after.properties.permissions[0].actions.push(
      'Microsoft.Authorization/roleAssignments/delete',
    );
  assert.throws(
    () => validateWhatIf(wrongRole, subscription, { phase: 'A' }),
    /NoChange resource is outside the Phase A allowlist/,
  );

  const wrongCredential = structuredClone(exact);
  wrongCredential.changes
    .find(({ resourceId }) =>
      resourceId.includes('/federatedIdentityCredentials/'),
    )
    .after.properties.subject = 'repo:attacker/repository:environment:prod';
  assert.throws(
    () => validateWhatIf(wrongCredential, subscription, { phase: 'A' }),
    /NoChange resource is outside the Phase A allowlist/,
  );

  const missingPayload = structuredClone(exact);
  delete missingPayload.changes[0].after;
  assert.throws(
    () => validateWhatIf(missingPayload, subscription, { phase: 'A' }),
    /NoChange resource is outside the Phase A allowlist/,
  );

  const duplicate = structuredClone(exact);
  duplicate.changes.push({
    ...structuredClone(duplicate.changes[0]),
    changeType: 'Create',
  });
  assert.throws(
    () => validateWhatIf(duplicate, subscription, { phase: 'A' }),
    /duplicate Phase A contract resource/,
  );
});

test('Phase A rejects unlisted and non-inert Ignore payloads', () => {
  const proof = makePhaseAProof();
  const attacker = makeCompletePhaseAPlan(proof);
  attacker.changes.push(
    deploymentChange(
      'Ignore',
      `/subscriptions/${subscription}/resourceGroups/rg-attacker/providers/` +
        'Microsoft.Compute/virtualMachines/attacker',
    ),
  );
  assert.throws(
    () => validateWhatIf(attacker, subscription, { phase: 'A' }),
    /Ignore resource is outside the Phase A allowlist/,
  );

  const unlisted = makeCompletePhaseAPlan(proof);
  unlisted.changes.push(
    deploymentChange(
      'Ignore',
      `/subscriptions/${subscription}/resourceGroups/rg-certigo-ci/providers/` +
        'Microsoft.Compute/virtualMachines/unlisted',
    ),
  );
  assert.throws(
    () => validateWhatIf(unlisted, subscription, { phase: 'A' }),
    /Ignore resource is outside the Phase A allowlist/,
  );

  const changed = makeCompletePhaseAPlan(proof);
  const resourceGroup = deploymentChange(
    'Ignore',
    `/subscriptions/${subscription}/resourceGroups/rg-certigo-ci`,
  );
  resourceGroup.delta = {
    path: 'tags.attacker',
    propertyChangeType: 'Create',
  };
  changed.changes.push(resourceGroup);
  assert.throws(
    () => validateWhatIf(changed, subscription, { phase: 'A' }),
    /Phase A rejects non-inert Ignore/,
  );
});

test('Phase A deployment wrappers require exact scope and materialized retries', () => {
  const proof = makePhaseAProof();
  const exactId =
    `/subscriptions/${subscription}/resourceGroups/rg-certigo-identities/providers/` +
    'Microsoft.Resources/deployments/identity-dev';
  for (const changeType of ['Create', 'Ignore', 'NoChange']) {
    const plan = makeCompletePhaseAPlan(proof);
    plan.changes.push(
      deploymentChange(changeType, exactId, { templateHash: '123456789' }),
    );
    assert.equal(
      validateWhatIf(plan, subscription, { phase: 'A' }).total,
      25,
    );
  }

  for (const invalidId of [
    `/subscriptions/${subscription}/resourceGroups/rg-attacker/providers/` +
      'Microsoft.Resources/deployments/identity-dev',
    '/subscriptions/00000000-0000-0000-0000-000000000099/resourceGroups/' +
      'rg-certigo-identities/providers/Microsoft.Resources/deployments/identity-dev',
    `/subscriptions/${subscription}/resourcegroups/rg-certigo-content/providers/` +
      'Microsoft.Resources/deployments/identity-dev',
  ]) {
    const plan = makeCompletePhaseAPlan(proof);
    plan.changes.push(
      deploymentChange('NoChange', invalidId, { templateHash: '123456789' }),
    );
    assert.throws(
      () => validateWhatIf(plan, subscription, { phase: 'A' }),
      /outside (subscription|the Phase A allowlist)/,
    );
  }

  for (const changeType of ['Ignore', 'NoChange']) {
    const plan = makeCompletePhaseAPlan(proof);
    plan.changes.push(deploymentChange(changeType, exactId));
    assert.throws(
      () => validateWhatIf(plan, subscription, { phase: 'A' }),
      new RegExp(`${changeType} resource is outside the Phase A allowlist`),
    );
  }
  for (const properties of [
    { provisioningState: '   ' },
    { templateHash: '' },
    { templateLink: { uri: ' ' } },
  ]) {
    const plan = makeCompletePhaseAPlan(proof);
    plan.changes.push(deploymentChange('NoChange', exactId, properties));
    assert.throws(
      () => validateWhatIf(plan, subscription, { phase: 'A' }),
      /NoChange resource is outside the Phase A allowlist/,
    );
  }

  const duplicateLeaf = makeCompletePhaseAPlan(proof);
  duplicateLeaf.changes.push(
    deploymentChange('Create', exactId),
    deploymentChange(
      'NoChange',
      `/subscriptions/${subscription}/resourceGroups/rg-attacker/providers/` +
        'Microsoft.Resources/deployments/identity-dev',
      { provisioningState: 'Succeeded' },
    ),
  );
  assert.throws(
    () => validateWhatIf(duplicateLeaf, subscription, { phase: 'A' }),
    /NoChange resource is outside the Phase A allowlist/,
  );
});

test('Phase B accepts only exact external subnet and DNS scopes', () => {
  const proof = makePhaseAProof();
  const plan = makeCompletePhaseBPlan(proof);
  const valid = validateWhatIf(
    plan,
    subscription,
    { phase: 'B', phaseA: proof },
  );
  assert.equal(valid.total, 16);

  for (const invalidScope of [
    `/subscriptions/${subscription}/resourceGroups/rg-certigo-ci`,
    `/subscriptions/${subscription}/resourceGroups/rg-certigo-ci/providers/` +
      'Microsoft.Network/virtualNetworks/vnet-certigo-ci/subnets/other',
    `/subscriptions/${subscription}/resourceGroups/rg-certigo-ci/providers/` +
      'Microsoft.Network/privateDnsZones/other.example',
  ]) {
    const invalid = structuredClone(plan);
    const subnetAssignment = invalid.changes.find(
      (change) =>
        change.after?.properties?.description ===
        'Allows the content plan to read and join only the trusted CI runner subnet.',
    );
    subnetAssignment.resourceId =
      `${invalidScope}/providers/Microsoft.Authorization/roleAssignments/` +
      '50000000-0000-0000-0000-000000000013';
    assert.throws(
      () =>
        validateWhatIf(
          invalid,
          subscription,
          { phase: 'B', phaseA: proof },
        ),
      /outside the exact Phase B contract/,
    );
  }
});

test('Phase B accepts exact NoChange and mixed retry plans only', () => {
  const proof = makePhaseAProof();
  const createPlan = makeCompletePhaseBPlan(proof);
  const noChange = whatIfPlan(createPlan.changes.map(materializeNoChange));
  assert.equal(
    validateWhatIf(noChange, subscription, { phase: 'B', phaseA: proof })
      .total,
    16,
  );

  const mixed = structuredClone(noChange);
  for (let index = 0; index < mixed.changes.length; index += 2) {
    mixed.changes[index] = structuredClone(createPlan.changes[index]);
  }
  assert.equal(
    validateWhatIf(mixed, subscription, { phase: 'B', phaseA: proof }).total,
    16,
  );

  const wrongPrincipal = structuredClone(noChange);
  wrongPrincipal.changes[0].after.properties.principalId =
    '90000000-0000-0000-0000-000000000001';
  assert.throws(
    () =>
      validateWhatIf(wrongPrincipal, subscription, {
        phase: 'B',
        phaseA: proof,
      }),
    /NoChange resource is outside the Phase B allowlist/,
  );

  const wrongRole = structuredClone(noChange);
  wrongRole.changes[0].after.properties.roleDefinitionId =
    `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
    'roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635';
  assert.throws(
    () =>
      validateWhatIf(wrongRole, subscription, {
        phase: 'B',
        phaseA: proof,
      }),
    /NoChange resource is outside the Phase B allowlist/,
  );

  const wrongCondition = structuredClone(noChange);
  wrongCondition.changes.find(
    ({ after }) => after.properties.conditionVersion === '2.0',
  ).after.properties.condition = 'true';
  assert.throws(
    () =>
      validateWhatIf(wrongCondition, subscription, {
        phase: 'B',
        phaseA: proof,
      }),
    /NoChange resource is outside the Phase B allowlist/,
  );

  const wrongScope = structuredClone(noChange);
  wrongScope.changes.find(
    ({ after }) =>
      after.properties.description ===
      'Allows the content plan to read and join only the trusted CI runner subnet.',
  ).resourceId =
    `/subscriptions/${subscription}/resourceGroups/rg-certigo-ci/providers/` +
    'Microsoft.Network/virtualNetworks/vnet-certigo-ci/subnets/other/providers/' +
    'Microsoft.Authorization/roleAssignments/' +
    '50000000-0000-0000-0000-000000000013';
  assert.throws(
    () =>
      validateWhatIf(wrongScope, subscription, {
        phase: 'B',
        phaseA: proof,
      }),
    /NoChange resource is outside the Phase B allowlist/,
  );

  const missingPayload = structuredClone(noChange);
  delete missingPayload.changes[0].after;
  assert.throws(
    () =>
      validateWhatIf(missingPayload, subscription, {
        phase: 'B',
        phaseA: proof,
      }),
    /NoChange resource is outside the Phase B allowlist/,
  );

  const duplicate = structuredClone(noChange);
  duplicate.changes.push({
    ...structuredClone(createPlan.changes[0]),
    changeType: 'Create',
  });
  assert.throws(
    () =>
      validateWhatIf(duplicate, subscription, {
        phase: 'B',
        phaseA: proof,
      }),
    /duplicate Phase B contract resource/,
  );
});

test('Phase B deployment wrappers require exact scope and materialized retries', () => {
  const proof = makePhaseAProof();
  const exactId =
    `/subscriptions/${subscription}/resourceGroups/rg-certigo-content/providers/` +
    'Microsoft.Resources/deployments/content-infra-plan-executor-rbac';
  for (const changeType of ['Create', 'Ignore', 'NoChange']) {
    const plan = makeCompletePhaseBPlan(proof);
    plan.changes.push(
      deploymentChange(changeType, exactId, {
        templateLink: { id: 'sha256:fixture' },
      }),
    );
    assert.equal(
      validateWhatIf(plan, subscription, { phase: 'B', phaseA: proof }).total,
      17,
    );
  }

  for (const invalidId of [
    `/subscriptions/${subscription}/resourceGroups/rg-certigo-ci/providers/` +
      'Microsoft.Resources/deployments/content-infra-plan-executor-rbac',
    '/subscriptions/00000000-0000-0000-0000-000000000099/resourceGroups/' +
      'rg-certigo-content/providers/Microsoft.Resources/deployments/' +
      'content-infra-plan-executor-rbac',
    `/subscriptions/${subscription}/resourceGroups/rg-certigo-content/providers/` +
      'microsoft.resources/deployments/content-infra-plan-executor-rbac',
  ]) {
    const plan = makeCompletePhaseBPlan(proof);
    plan.changes.push(
      deploymentChange('Ignore', invalidId, {
        provisioningState: 'Succeeded',
      }),
    );
    assert.throws(
      () =>
        validateWhatIf(plan, subscription, { phase: 'B', phaseA: proof }),
      /outside (subscription|the Phase B allowlist)/,
    );
  }

  for (const changeType of ['Ignore', 'NoChange']) {
    const plan = makeCompletePhaseBPlan(proof);
    plan.changes.push(deploymentChange(changeType, exactId));
    assert.throws(
      () =>
        validateWhatIf(plan, subscription, { phase: 'B', phaseA: proof }),
      new RegExp(`${changeType} resource is outside the Phase B allowlist`),
    );
  }
  for (const properties of [
    { provisioningState: '' },
    { templateHash: '   ' },
    { templateLink: { id: '' } },
  ]) {
    const plan = makeCompletePhaseBPlan(proof);
    plan.changes.push(deploymentChange('Ignore', exactId, properties));
    assert.throws(
      () =>
        validateWhatIf(plan, subscription, { phase: 'B', phaseA: proof }),
      /Ignore resource is outside the Phase B allowlist/,
    );
  }

  const duplicateLeaf = makeCompletePhaseBPlan(proof);
  duplicateLeaf.changes.push(
    deploymentChange('Create', exactId),
    deploymentChange(
      'Ignore',
      `/subscriptions/${subscription}/resourceGroups/rg-attacker/providers/` +
        'Microsoft.Resources/deployments/content-infra-plan-executor-rbac',
      { templateHash: '123456789' },
    ),
  );
  assert.throws(
    () =>
      validateWhatIf(duplicateLeaf, subscription, {
        phase: 'B',
        phaseA: proof,
      }),
    /Ignore resource is outside the Phase B allowlist/,
  );
});

test('Phase B rejects empty plans and policy assignment below subscription scope', () => {
  const proof = makePhaseAProof();
  assert.throws(
    () =>
      validateWhatIf(
        whatIfPlan([]),
        subscription,
        { phase: 'B', phaseA: proof },
      ),
    /Phase B plan is incomplete/,
  );
  const plan = makeCompletePhaseBPlan(proof);
  const policy = plan.changes.find(({ resourceId }) =>
    resourceId.includes('/policyAssignments/'),
  );
  policy.resourceId =
    `/subscriptions/${subscription}/resourceGroups/rg-certigo-ci/providers/` +
    'Microsoft.Authorization/policyAssignments/certigo-privileged-ci-rbac';
  assert.throws(
    () =>
      validateWhatIf(plan, subscription, { phase: 'B', phaseA: proof }),
    /outside the exact Phase B contract/,
  );
});

test('Phase B script proves Phase A and all live resources before what-if', () => {
  const script = readFileSync(
    path.join(
      repositoryRoot,
      'infra',
      'governance',
      'what-if-phase-b.sh',
    ),
    'utf8',
  );
  const proofIndex = script.indexOf('provisioningState');
  const resourceIndex = script.indexOf('az resource show');
  const credentialIndex = script.indexOf(
    'az identity federated-credential list',
  );
  const whatIfIndex = script.indexOf('az deployment sub what-if');
  assert.ok(proofIndex >= 0);
  assert.ok(resourceIndex > proofIndex);
  assert.ok(credentialIndex > resourceIndex);
  assert.ok(whatIfIndex > credentialIndex);
  assert.match(script, /provisioning_state.*Succeeded/s);
  assert.match(script, /validatePhaseAProof/);
  assert.match(script, /live identity does not match Phase A proof/);
  assert.equal(
    script.match(/phaseA\.identityResourceGroupId/g)?.length,
    2,
  );
});

test('read-only governance scripts contain no live mutation commands', () => {
  for (const relativePath of [
    'infra/governance/inventory.sh',
    'infra/governance/what-if-phase-a.sh',
    'infra/governance/what-if-phase-b.sh',
    'infra/ci-runner/capacity-plan.sh',
    'infra/ci-runner/lifecycle-preflight.sh',
  ]) {
    const script = readFileSync(path.join(repositoryRoot, relativePath), 'utf8');
    assert.doesNotMatch(
      script,
      /\baz\s+(?:deployment\s+(?:sub|group)\s+create|role\s+assignment\s+(?:create|delete)|vm(?:ss)?\s+(?:start|stop|deallocate|delete)|group\s+delete)\b/,
    );
    assert.doesNotMatch(
      script,
      /\bgh\s+api\s+(?:--method\s+)?(?:POST|PUT|PATCH|DELETE)\b/,
    );
  }
});

test('Phase A what-if preserves the complete raw ARM payload', () => {
  const script = readFileSync(
    path.join(
      repositoryRoot,
      'infra',
      'governance',
      'what-if-phase-a.sh',
    ),
    'utf8',
  );
  assert.doesNotMatch(script, /--exclude-change-types/);
  assert.match(script, /--result-format FullResourcePayloads/);
});

test('application template uses pre-created environment resource groups', () => {
  const template = compileTemplate('infra/main.bicep');
  const [resourceGroup] = resourcesOfType(
    template,
    'Microsoft.Resources/resourceGroups',
  );
  assert.ok(resourceGroup);
  assert.equal(resourceGroup.existing, true);
});

test('runner capacity planning stays off and encodes the guarded pilot contract', () => {
  const config = JSON.parse(
    readFileSync(
      path.join(
        repositoryRoot,
        'infra',
        'ci-runner',
        'capacity-controller.config.json',
      ),
      'utf8',
    ),
  );
  assert.equal(config.enabled, false);
  assert.equal(config.stateVersion, 3);
  assert.equal('maxAggregateCapacity' in config, false);
  assert.deepEqual(config.pilotTarget, {
    'certigo-pr': 6,
    'certigo-trusted': 2,
  });
  assert.deepEqual(config.modes.boost, config.pilotTarget);
  assert.equal(config.quietPeriodSeconds, 300);
  assert.equal(config.requiredPostQuietGuards, 2);
  assert.equal(config.minimumExclusivePools, 2);
  assert.equal(config.minimumExclusiveSubnets, 2);
  assert.deepEqual(config.scaleInOrder, ['certigo-pr', 'certigo-trusted']);
  assert.deepEqual(config.inventory.externalGithubRunnerIds, [26]);
  assert.deepEqual(config.inventory.externalVirtualMachines, [
    'vmss-certigo-runner-zonal_4153d1dd',
  ]);
  assert.deepEqual(config.inventory.forbiddenVirtualMachines, [
    'vmss-certigo-runner-zonal_22f7fb52',
    'vmss-certigo-pr-pilot-z1_4596a9d5',
  ]);
  assert.equal(config.inventory.managedRunnerBindings.length, 2);
});

test('infra validation bootstraps pinned Node for bare Linux runners', () => {
  const validation = readFileSync(
    path.join(repositoryRoot, 'infra', 'validate.sh'),
    'utf8',
  );
  assert.match(validation, /version="20\.20\.2"/);
  assert.match(
    validation,
    /df770b2a6f130ed8627c9782c988fda9669fa23898329a61a871e32f965e007d/,
  );
  assert.match(validation, /sha256sum --check --strict/);
  assert.match(validation, /GITHUB_PATH/);
});

test('environment parameters retain historical principals for staged rollback', () => {
  for (const environment of ['dev', 'staging', 'prod']) {
    const parameters = readFileSync(
      path.join(repositoryRoot, 'infra', 'params', `${environment}.bicepparam`),
      'utf8',
    );
    assert.match(
      parameters,
      /ciDeploymentPrincipalId = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'/,
    );
  }
  const runbook = readFileSync(
    path.join(
      repositoryRoot,
      'docs',
      'runbooks',
      'CLOUD_LEAST_PRIVILEGE.md',
    ),
    'utf8',
  );
  assert.match(runbook, /deux déploiements\s+prod réussis/i);
  assert.match(runbook, /Contributor` puis `User Access Administrator/i);
  assert.match(runbook, /access review/i);
  assert.match(runbook, /rollback/i);
});
