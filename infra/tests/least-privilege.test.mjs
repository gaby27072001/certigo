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
          location: 'westeurope',
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

function roleAssignmentChange(scope, nameSeed, properties) {
  return {
    changeType: 'Create',
    resourceId:
      `${scope}/providers/Microsoft.Authorization/roleAssignments/` +
      armGuid(scope, nameSeed, properties.roleDefinitionId),
    after: { properties },
  };
}

function makeCompletePhaseBPlans(proof) {
  const b1Changes = [];
  const b2Changes = [];
  const contributor =
    `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
    'roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c';
  for (const environment of ['dev', 'staging', 'prod']) {
    const key = `deploy${environment[0].toUpperCase()}${environment.slice(1)}`;
    const principalId = proof.identities[key].principalId;
    b1Changes.push(
      roleAssignmentChange(`/subscriptions/${subscription}`, proof.identities[key].name, {
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
        proof.identities[key].name,
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
        proof.identities[key].name,
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
        proof.identities[key].name,
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
  b1Changes.push(
    roleAssignmentChange(
      `/subscriptions/${subscription}/resourceGroups/rg-certigo-content`,
      proof.identities.contentInfrastructurePlan.name,
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
  b2Changes.push(
    roleAssignmentChange(
      `/subscriptions/${subscription}/resourceGroups/rg-certigo-ci/providers/` +
        'Microsoft.Network/virtualNetworks/vnet-certigo-ci/subnets/snet-runners',
      contentPrincipal,
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
      contentPrincipal,
      {
        description:
          'Allows the content plan to read and join only the shared Blob private DNS zone.',
        principalId: contentPrincipal,
        principalType: 'ServicePrincipal',
        roleDefinitionId:
          proof.roleDefinitionIds.contentInfrastructurePlanExternalJoin,
      },
    ),
  );
  return {
    b1: whatIfPlan(b1Changes),
    b2: whatIfPlan(b2Changes),
  };
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

test('Phase B1 uses literal Phase A IDs and creates only internal assignments', () => {
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
  assert.doesNotMatch(source, /\.properties\.principalId/);
  assert.doesNotMatch(source, /\breference\s*\(/);
  assert.match(source, /principalId: environment\.identity\.principalId/);
  assert.match(
    source,
    /principalId: phaseA\.identities\.contentInfrastructurePlan\.principalId/,
  );
  assert.equal(template.outputs.assignmentCount.value, 14);
});

test('Phase B2 uses only literal exact subnet and DNS resources', () => {
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
    () => validateWhatIf(whatIfPlan([]), subscription, { phase: 'B1' }),
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

test('Phase B1 and B2 accept only their exact assignment contracts', () => {
  const proof = makePhaseAProof();
  const { b1, b2 } = makeCompletePhaseBPlans(proof);
  assert.equal(
    validateWhatIf(b1, subscription, { phase: 'B1', phaseA: proof }).total,
    14,
  );
  assert.equal(
    validateWhatIf(b2, subscription, { phase: 'B2', phaseA: proof }).total,
    2,
  );
  assert.throws(
    () => validateWhatIf(b2, subscription, { phase: 'B1', phaseA: proof }),
    /outside the exact Phase B1 contract|Phase B1 plan is incomplete/,
  );
  assert.throws(
    () => validateWhatIf(b1, subscription, { phase: 'B2', phaseA: proof }),
    /outside the exact Phase B2 contract|Phase B2 plan is incomplete/,
  );
});

test('Phase B validators reject IDs, principals, types, scopes, and conditions', () => {
  const proof = makePhaseAProof();
  const mutations = [
    (plans) => {
      plans.b1.changes[0].resourceId = plans.b1.changes[0].resourceId.replace(
        /[0-9a-f-]{36}$/,
        '90000000-0000-0000-0000-000000000001',
      );
      return ['b1', 'B1'];
    },
    (plans) => {
      plans.b1.changes[0].after.properties.principalId =
        '90000000-0000-0000-0000-000000000001';
      return ['b1', 'B1'];
    },
    (plans) => {
      plans.b1.changes[0].after.properties.principalType = 'User';
      return ['b1', 'B1'];
    },
    (plans) => {
      plans.b1.changes.find(
        ({ after }) => after.properties.conditionVersion === '2.0',
      ).after.properties.condition = 'true';
      return ['b1', 'B1'];
    },
    (plans) => {
      plans.b2.changes[0].resourceId = plans.b2.changes[0].resourceId.replace(
        '/subnets/snet-runners/',
        '/subnets/attacker/',
      );
      return ['b2', 'B2'];
    },
  ];
  for (const mutate of mutations) {
    const plans = makeCompletePhaseBPlans(proof);
    const [key, phase] = mutate(plans);
    assert.throws(
      () =>
        validateWhatIf(plans[key], subscription, { phase, phaseA: proof }),
      new RegExp(`outside the exact Phase ${phase} contract`),
    );
  }
});

test('Phase B validators accept exact NoChange retries only', () => {
  const proof = makePhaseAProof();
  for (const [key, phase, total] of [
    ['b1', 'B1', 14],
    ['b2', 'B2', 2],
  ]) {
    const create = makeCompletePhaseBPlans(proof)[key];
    const noChange = whatIfPlan(create.changes.map(materializeNoChange));
    assert.equal(
      validateWhatIf(noChange, subscription, { phase, phaseA: proof }).total,
      total,
    );
    const missing = structuredClone(noChange);
    delete missing.changes[0].after;
    assert.throws(
      () => validateWhatIf(missing, subscription, { phase, phaseA: proof }),
      new RegExp(`NoChange resource is outside the Phase ${phase} allowlist`),
    );
  }
});

test('Phase B requires a complete Phase A proof and exact policy scope', () => {
  const proof = makePhaseAProof();
  assert.throws(
    () => validateWhatIf(whatIfPlan([]), subscription, { phase: 'B1' }),
    /Phase A proof is missing/,
  );
  const { b1 } = makeCompletePhaseBPlans(proof);
  const policy = b1.changes.find(({ resourceId }) =>
    resourceId.includes('/policyAssignments/'),
  );
  policy.resourceId =
    `/subscriptions/${subscription}/resourceGroups/rg-certigo-ci/providers/` +
    'Microsoft.Authorization/policyAssignments/certigo-privileged-ci-rbac';
  assert.throws(
    () => validateWhatIf(b1, subscription, { phase: 'B1', phaseA: proof }),
    /outside the exact Phase B1 contract/,
  );
});

test('Phase B1 and B2 prove Phase A before independent what-if plans', () => {
  const governance = path.join(repositoryRoot, 'infra', 'governance');
  const prepare = readFileSync(
    path.join(governance, 'prepare-phase-b.sh'),
    'utf8',
  );
  const b1 = readFileSync(
    path.join(governance, 'what-if-phase-b1.sh'),
    'utf8',
  );
  const b2 = readFileSync(
    path.join(governance, 'what-if-phase-b2.sh'),
    'utf8',
  );
  const orchestrator = readFileSync(
    path.join(governance, 'what-if-phase-b.sh'),
    'utf8',
  );
  const proofIndex = prepare.indexOf('provisioningState');
  const resourceIndex = prepare.indexOf('az resource show');
  const credentialIndex = prepare.indexOf(
    'az identity federated-credential list',
  );
  assert.ok(proofIndex >= 0);
  assert.ok(resourceIndex > proofIndex);
  assert.ok(credentialIndex > resourceIndex);
  assert.match(prepare, /provisioning_state.*Succeeded/s);
  assert.match(prepare, /validatePhaseAProof/);
  assert.match(prepare, /live identity does not match Phase A proof/);
  assert.match(prepare, /phaseA\.identityResourceGroupId/);
  assert.ok(b1.indexOf('prepare-phase-b.sh') < b1.indexOf('deployment sub what-if'));
  assert.ok(b2.indexOf('prepare-phase-b.sh') < b2.indexOf('deployment group what-if'));
  assert.match(b1, /--phase B1/);
  assert.match(b2, /--phase B2/);
  assert.match(b1, /manifest\.json/);
  assert.match(b2, /manifest\.json/);
  assert.match(orchestrator, /what-if-phase-b1\.sh/);
  assert.doesNotMatch(orchestrator, /what-if-phase-b2\.sh/);
});

test('read-only governance scripts contain no live mutation commands', () => {
  for (const relativePath of [
    'infra/governance/inventory.sh',
    'infra/governance/prepare-phase-b.sh',
    'infra/governance/what-if-phase-a.sh',
    'infra/governance/what-if-phase-b.sh',
    'infra/governance/what-if-phase-b1.sh',
    'infra/governance/what-if-phase-b2.sh',
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
