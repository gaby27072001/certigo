import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { isDeepStrictEqual } from 'node:util';

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const identityContracts = {
  deployDev: {
    name: 'id-certigo-deploy-dev',
    resourceGroup: 'rg-certigo-identities',
    credential: {
      name: 'github-dev',
      subject: 'repo:gchambaud_microsoft/Certigo:environment:dev',
    },
  },
  deployStaging: {
    name: 'id-certigo-deploy-staging',
    resourceGroup: 'rg-certigo-identities',
    credential: {
      name: 'github-staging',
      subject: 'repo:gchambaud_microsoft/Certigo:environment:staging',
    },
  },
  deployProd: {
    name: 'id-certigo-deploy-prod',
    resourceGroup: 'rg-certigo-identities',
    credential: {
      name: 'github-prod',
      subject: 'repo:gchambaud_microsoft/Certigo:environment:prod',
    },
  },
  contentInfrastructurePlan: {
    name: 'id-certigo-content-infra-plan',
    resourceGroup: 'rg-certigo-identities',
    credential: {
      name: 'github-azure-content-infra-plan',
      subject:
        'repo:gchambaud_microsoft/Certigo:environment:azure-content-infra-plan',
    },
  },
  contentRelease: {
    name: 'id-certigo-content-release',
    resourceGroup: 'rg-certigo-identities',
    credential: {
      name: 'github-azure-content-release',
      subject:
        'repo:gchambaud_microsoft/certigo-content:environment:azure-content-release',
    },
  },
  contentPublic: {
    name: 'id-certigo-content-public',
    resourceGroup: 'rg-certigo-identities',
    credential: {
      name: 'github-azure-content-public',
      subject:
        'repo:gchambaud_microsoft/certigo-content:environment:azure-content-public',
    },
  },
  contentAnswerKey: {
    name: 'id-certigo-content-answer-key',
    resourceGroup: 'rg-certigo-identities',
    credential: {
      name: 'github-azure-content-answer-key',
      subject:
        'repo:gchambaud_microsoft/certigo-content:environment:azure-content-answer-key',
    },
  },
  contentReader: {
    name: 'id-certigo-content-reader',
    resourceGroup: 'rg-certigo-identities',
  },
};

const roleContracts = {
  subscriptionDeploymentLauncher: {
    seed: 'certigo-subscription-deployment-launcher',
    roleName: /^Certigo Subscription Deployment Launcher [a-z0-9]{6}$/,
    actions: [
      'Microsoft.Resources/deployments/read',
      'Microsoft.Resources/deployments/operations/read',
      'Microsoft.Resources/deployments/validate/action',
      'Microsoft.Resources/deployments/whatIf/action',
      'Microsoft.Resources/deployments/write',
      'Microsoft.Resources/subscriptions/resourceGroups/read',
      'Microsoft.Authorization/policyAssignments/read',
      'Microsoft.Authorization/policyDefinitions/read',
      'Microsoft.Authorization/roleAssignments/read',
      'Microsoft.Authorization/roleDefinitions/read',
      'Microsoft.ManagedIdentity/userAssignedIdentities/read',
      'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials/read',
    ],
    scopes: (subscriptionId) => [`/subscriptions/${subscriptionId}`],
  },
  runtimeRoleAssignmentWriter: {
    seed: 'certigo-runtime-role-assignment-writer',
    roleName: /^Certigo Runtime Role Assignment Writer [a-z0-9]{6}$/,
    actions: [
      'Microsoft.Authorization/roleAssignments/read',
      'Microsoft.Authorization/roleAssignments/write',
      'Microsoft.Authorization/roleDefinitions/read',
      'Microsoft.Resources/subscriptions/resourceGroups/read',
    ],
    scopes: (subscriptionId) =>
      ['dev', 'staging', 'prod'].map(
        (environment) =>
          `/subscriptions/${subscriptionId}/resourceGroups/rg-certigo-${environment}`,
      ),
  },
  sharedNetworkDeployment: {
    seed: 'certigo-shared-network-deployment',
    roleName: /^Certigo Shared Network Deployment [a-z0-9]{6}$/,
    actions: [
      'Microsoft.Network/privateDnsZones/join/action',
      'Microsoft.Network/privateDnsZones/read',
      'Microsoft.Network/privateDnsZones/virtualNetworkLinks/read',
      'Microsoft.Network/privateDnsZones/virtualNetworkLinks/write',
      'Microsoft.Network/privateDnsZones/write',
      'Microsoft.Network/virtualNetworks/read',
      'Microsoft.Network/virtualNetworks/virtualNetworkPeerings/read',
      'Microsoft.Network/virtualNetworks/virtualNetworkPeerings/write',
      'Microsoft.Resources/deployments/read',
      'Microsoft.Resources/deployments/validate/action',
      'Microsoft.Resources/deployments/whatIf/action',
      'Microsoft.Resources/deployments/write',
      'Microsoft.Resources/subscriptions/resourceGroups/read',
    ],
    scopes: (subscriptionId) => [
      `/subscriptions/${subscriptionId}/resourceGroups/rg-certigo-ci`,
    ],
  },
  contentPublisher: {
    fixedId: 'c8a9d1bb-39d7-4f4f-9a4c-17b4c81aa5de',
    roleName: /^Certigo Immutable Content Publisher [a-z0-9]{6}$/,
    actions: [
      'Microsoft.Storage/storageAccounts/blobServices/containers/immutabilityPolicies/read',
      'Microsoft.Storage/storageAccounts/blobServices/containers/read',
    ],
    // Create-and-verify only: no blobs/delete, so a publisher can never remove
    // or truncate a published release.
    dataActions: [
      'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read',
      'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write',
    ],
    scopes: (subscriptionId) => [
      `/subscriptions/${subscriptionId}/resourceGroups/rg-certigo-content`,
    ],
  },
  contentInfrastructurePlanExecutor: {
    seed: 'certigo-content-infrastructure-plan-executor',
    roleName: /^Certigo Content Infrastructure Plan Executor [a-z0-9]{6}$/,
    actions: [
      'Microsoft.Authorization/roleAssignments/read',
      'Microsoft.Authorization/roleAssignments/write',
      'Microsoft.Authorization/roleDefinitions/read',
      'Microsoft.ManagedIdentity/userAssignedIdentities/read',
      'Microsoft.Network/privateEndpoints/privateDnsZoneGroups/read',
      'Microsoft.Network/privateEndpoints/privateDnsZoneGroups/write',
      'Microsoft.Network/privateEndpoints/read',
      'Microsoft.Network/privateEndpoints/write',
      'Microsoft.Resources/deployments/read',
      'Microsoft.Resources/deployments/validate/action',
      'Microsoft.Resources/deployments/whatIf/action',
      'Microsoft.Resources/deployments/write',
      'Microsoft.Storage/storageAccounts/PrivateEndpointConnectionsApproval/action',
      'Microsoft.Storage/storageAccounts/blobServices/containers/immutabilityPolicies/read',
      'Microsoft.Storage/storageAccounts/blobServices/containers/immutabilityPolicies/write',
      'Microsoft.Storage/storageAccounts/blobServices/containers/read',
      'Microsoft.Storage/storageAccounts/blobServices/containers/write',
      'Microsoft.Storage/storageAccounts/blobServices/read',
      'Microsoft.Storage/storageAccounts/blobServices/write',
      'Microsoft.Storage/storageAccounts/managementPolicies/read',
      'Microsoft.Storage/storageAccounts/managementPolicies/write',
      'Microsoft.Storage/storageAccounts/read',
      'Microsoft.Storage/storageAccounts/write',
    ],
    scopes: (subscriptionId) => [
      `/subscriptions/${subscriptionId}/resourceGroups/rg-certigo-content`,
    ],
  },
  contentInfrastructurePlanExternalJoin: {
    seed: 'certigo-content-infrastructure-plan-external-join',
    roleName: /^Certigo Content Infrastructure Plan External Join [a-z0-9]{6}$/,
    actions: [
      'Microsoft.Network/privateDnsZones/join/action',
      'Microsoft.Network/privateDnsZones/read',
      'Microsoft.Network/virtualNetworks/subnets/join/action',
      'Microsoft.Network/virtualNetworks/subnets/read',
    ],
    scopes: (subscriptionId) => [
      `/subscriptions/${subscriptionId}/resourceGroups/rg-certigo-ci`,
    ],
  },
};

function phaseADeploymentIds(subscriptionId) {
  const resourceId = (resourceGroup, name) =>
    `/subscriptions/${subscriptionId}/resourceGroups/${resourceGroup}/` +
    `providers/Microsoft.Resources/deployments/${name}`;
  return new Map([
    ['identity-dev', resourceId('rg-certigo-identities', 'identity-dev')],
    ['identity-staging', resourceId('rg-certigo-identities', 'identity-staging')],
    ['identity-prod', resourceId('rg-certigo-identities', 'identity-prod')],
    [
      'identity-content-infra-plan',
      resourceId('rg-certigo-identities', 'identity-content-infra-plan'),
    ],
    [
      'content-release-publisher-identity',
      resourceId('rg-certigo-identities', 'content-release-publisher-identity'),
    ],
    [
      'content-public-publisher-identity',
      resourceId('rg-certigo-identities', 'content-public-publisher-identity'),
    ],
    [
      'content-private-publisher-identity',
      resourceId('rg-certigo-identities', 'content-private-publisher-identity'),
    ],
    [
      'content-reader-identity',
      resourceId('rg-certigo-identities', 'content-reader-identity'),
    ],
  ]);
}

function phaseB1DeploymentIds(subscriptionId) {
  const resourceId = (resourceGroup, name) =>
    `/subscriptions/${subscriptionId}/resourceGroups/${resourceGroup}/` +
    `providers/Microsoft.Resources/deployments/${name}`;
  return new Map([
    ['rbac-dev', resourceId('rg-certigo-dev', 'rbac-dev')],
    ['rbac-staging', resourceId('rg-certigo-staging', 'rbac-staging')],
    ['rbac-prod', resourceId('rg-certigo-prod', 'rbac-prod')],
    [
      'shared-network-rbac-dev',
      resourceId('rg-certigo-ci', 'shared-network-rbac-dev'),
    ],
    [
      'shared-network-rbac-staging',
      resourceId('rg-certigo-ci', 'shared-network-rbac-staging'),
    ],
    [
      'shared-network-rbac-prod',
      resourceId('rg-certigo-ci', 'shared-network-rbac-prod'),
    ],
    [
      'content-infra-plan-executor-rbac',
      resourceId('rg-certigo-content', 'content-infra-plan-executor-rbac'),
    ],
  ]);
}

function normalizeId(value) {
  return String(value ?? '').replace(/\/+$/, '').toLowerCase();
}

export function armGuid(...values) {
  const namespace = Buffer.from(
    '11fb06fb712d4ddd98c7e71bbd588830',
    'hex',
  );
  const hash = createHash('sha1')
    .update(namespace)
    .update(values.join('-'))
    .digest()
    .subarray(0, 16);
  hash[6] = (hash[6] & 0x0f) | 0x50;
  hash[8] = (hash[8] & 0x3f) | 0x80;
  const hex = hash.toString('hex');
  return [
    hex.slice(0, 8),
    hex.slice(8, 12),
    hex.slice(12, 16),
    hex.slice(16, 20),
    hex.slice(20),
  ].join('-');
}

function sameStrings(actual = [], expected = []) {
  return (
    JSON.stringify([...actual].map(normalizeId).sort()) ===
    JSON.stringify([...expected].map(normalizeId).sort())
  );
}

function isInertIgnore(change) {
  return Boolean(
    change.before &&
      change.after &&
      isDeepStrictEqual(change.before, change.after) &&
      change.delta == null &&
      change.unsupportedReason == null,
  );
}

function parseResourceId(resourceId) {
  const parts = String(resourceId).split('/').filter(Boolean);
  const resourceGroupIndex = parts.findIndex(
    (part) => part.toLowerCase() === 'resourcegroups',
  );
  const providerIndex = parts.findLastIndex(
    (part) => part.toLowerCase() === 'providers',
  );
  const types = [];
  const names = [];
  if (providerIndex >= 0) {
    for (let index = providerIndex + 2; index < parts.length; index += 2) {
      types.push(parts[index]);
      names.push(parts[index + 1]);
    }
  }
  return {
    names,
    resourceGroup:
      resourceGroupIndex >= 0 ? parts[resourceGroupIndex + 1]?.toLowerCase() : null,
    type:
      providerIndex >= 0
        ? `${parts[providerIndex + 1]}/${types.join('/')}`.toLowerCase()
        : null,
  };
}

function expectedIdentityResourceId(subscriptionId, contract) {
  return (
    `/subscriptions/${subscriptionId}/resourceGroups/${contract.resourceGroup}/` +
    `providers/Microsoft.ManagedIdentity/userAssignedIdentities/${contract.name}`
  );
}

export function validatePhaseAProof(phaseA, subscriptionId) {
  const errors = [];
  if (!phaseA || phaseA.schemaVersion !== 2) {
    throw new Error('Phase A proof is missing or has an unsupported schemaVersion');
  }
  if (normalizeId(phaseA.subscriptionId) !== normalizeId(subscriptionId)) {
    errors.push('Phase A proof subscriptionId does not match the target subscription');
  }
  if (!uuidPattern.test(phaseA.tenantId ?? '')) {
    errors.push('Phase A proof tenantId is missing or invalid');
  }
  const expectedContentResourceGroupId =
    `/subscriptions/${subscriptionId}/resourceGroups/rg-certigo-content`;
  const expectedIdentityResourceGroupId =
    `/subscriptions/${subscriptionId}/resourceGroups/rg-certigo-identities`;
  if (
    normalizeId(phaseA.contentResourceGroupId) !==
    normalizeId(expectedContentResourceGroupId)
  ) {
    errors.push('Phase A proof content resource group is outside the exact contract');
  }
  if (
    normalizeId(phaseA.identityResourceGroupId) !==
    normalizeId(expectedIdentityResourceGroupId)
  ) {
    errors.push('Phase A proof identity resource group is outside the exact contract');
  }

  const principalIds = new Set();
  const clientIds = new Set();
  for (const [key, contract] of Object.entries(identityContracts)) {
    const identity = phaseA.identities?.[key];
    if (
      !identity ||
      identity.name !== contract.name ||
      normalizeId(identity.resourceId) !==
        normalizeId(expectedIdentityResourceId(subscriptionId, contract)) ||
      !uuidPattern.test(identity.principalId ?? '') ||
      !uuidPattern.test(identity.clientId ?? '')
    ) {
      errors.push(`Phase A proof identity ${key} is missing or invalid`);
      continue;
    }
    principalIds.add(identity.principalId.toLowerCase());
    clientIds.add(identity.clientId.toLowerCase());
    if (
      contract.credential &&
      key === 'contentInfrastructurePlan' &&
      identity.federatedSubject !== contract.credential.subject
    ) {
      errors.push(`Phase A proof identity ${key} has an invalid federated subject`);
    }
  }
  if (principalIds.size !== Object.keys(identityContracts).length) {
    errors.push('Phase A proof principal IDs must be present and unique');
  }
  if (clientIds.size !== Object.keys(identityContracts).length) {
    errors.push('Phase A proof client IDs must be present and unique');
  }

  const roleIds = new Set();
  for (const [key, contract] of Object.entries(roleContracts)) {
    const roleDefinitionId = phaseA.roleDefinitionIds?.[key];
    const parsed = parseResourceId(roleDefinitionId ?? '');
    const roleGuid = parsed.names[0] ?? '';
    if (
      normalizeId(roleDefinitionId).split(
        `/subscriptions/${subscriptionId.toLowerCase()}/providers/` +
          'microsoft.authorization/roledefinitions/',
      ).length !== 2 ||
      parsed.type !== 'microsoft.authorization/roledefinitions' ||
      !uuidPattern.test(roleGuid) ||
      roleGuid.toLowerCase() !==
        (contract.fixedId ??
          armGuid(`/subscriptions/${subscriptionId}`, contract.seed))
    ) {
      errors.push(`Phase A proof role ${key} is missing or invalid`);
      continue;
    }
    roleIds.add(normalizeId(roleDefinitionId));
  }
  if (roleIds.size !== Object.keys(roleContracts).length) {
    errors.push('Phase A proof role definition IDs must be present and unique');
  }

  const policy = parseResourceId(phaseA.policyDefinitionId ?? '');
  if (
    policy.type !== 'microsoft.authorization/policydefinitions' ||
    !uuidPattern.test(policy.names[0] ?? '') ||
    !normalizeId(phaseA.policyDefinitionId).startsWith(
      `/subscriptions/${subscriptionId.toLowerCase()}/providers/` +
        'microsoft.authorization/policydefinitions/',
    )
  ) {
    errors.push('Phase A proof policyDefinitionId is missing or invalid');
  }

  if (errors.length > 0) {
    throw new Error(errors.join('\n'));
  }
  return phaseA;
}

function identifyRoleContract(change, subscriptionId) {
  const properties = change.after?.properties;
  const [permissions] = properties?.permissions ?? [];
  const entry = Object.entries(roleContracts).find(([, contract]) =>
    contract.roleName.test(properties?.roleName ?? ''),
  );
  if (!entry) {
    return null;
  }
  const [key, contract] = entry;
  const roleGuid = parseResourceId(change.resourceId).names[0]?.toLowerCase();
  const expectedRoleGuid =
    contract.fixedId ??
    armGuid(`/subscriptions/${subscriptionId}`, contract.seed);
  if (
    properties.type !== 'CustomRole' ||
    (properties.permissions ?? []).length !== 1 ||
    !sameStrings(permissions.actions, contract.actions) ||
    !sameStrings(permissions.dataActions, contract.dataActions ?? []) ||
    !sameStrings(permissions.notActions, []) ||
    !sameStrings(permissions.notDataActions, []) ||
    !sameStrings(properties.assignableScopes, contract.scopes(subscriptionId)) ||
    roleGuid !== expectedRoleGuid
  ) {
    return null;
  }
  return key;
}

function hasCompletePayload(change) {
  const after = change.after;
  const parsed = parseResourceId(change.resourceId);
  const expectedName = String(change.resourceId).split('/').filter(Boolean).at(-1);
  const payloadName = String(after?.name ?? '').toLowerCase();
  const expectedType =
    parsed.type ??
    (parsed.resourceGroup && /\/resourceGroups\/[^/]+$/i.test(change.resourceId)
      ? 'microsoft.resources/resourcegroups'
      : null);
  return Boolean(
    after &&
      typeof after === 'object' &&
      normalizeId(after.id) === normalizeId(change.resourceId) &&
      typeof after.name === 'string' &&
      (payloadName === expectedName?.toLowerCase() ||
        payloadName.endsWith(`/${expectedName?.toLowerCase()}`)) &&
      typeof after.type === 'string' &&
      normalizeId(after.type) === expectedType &&
      after.properties &&
      typeof after.properties === 'object',
  );
}

function validateIdentityChange(
  change,
  subscriptionId,
  requireMaterialized = false,
) {
  const parsed = parseResourceId(change.resourceId);
  const contract = Object.values(identityContracts).find(
    (candidate) =>
      normalizeId(change.resourceId) ===
      normalizeId(expectedIdentityResourceId(subscriptionId, candidate)),
  );
  if (!contract || parsed.names.length !== 1) {
    return false;
  }
  const properties = change.after?.properties ?? {};
  return Boolean(
    (!requireMaterialized ||
      (hasCompletePayload(change) &&
      change.after.location?.toLowerCase() === 'westeurope' &&
      uuidPattern.test(properties.clientId ?? '') &&
        uuidPattern.test(properties.principalId ?? ''))) &&
      (!properties.principalId || uuidPattern.test(properties.principalId)),
  );
}

function validateCredentialChange(change, subscriptionId) {
  const contract = Object.values(identityContracts).find((candidate) => {
    if (!candidate.credential) {
      return false;
    }
    return (
      normalizeId(change.resourceId) ===
      normalizeId(
        `${expectedIdentityResourceId(subscriptionId, candidate)}/` +
          `federatedIdentityCredentials/${candidate.credential.name}`,
      )
    );
  });
  const properties = change.after?.properties ?? {};
  return Boolean(
    contract &&
      properties.issuer === 'https://token.actions.githubusercontent.com' &&
      properties.subject === contract.credential.subject &&
      sameStrings(properties.audiences, ['api://AzureADTokenExchange']),
  );
}

function validatePolicyDefinition(change, subscriptionId) {
  const properties = change.after?.properties ?? {};
  const expectedPrivilegedRoles = [
    '8e3af657-a8ff-443c-a75c-2fe8c4bcb635',
    'b24988ac-6180-42a0-ab88-20f7382dd24c',
    '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9',
    'f58310d9-a9f6-439a-9e8d-f62e7b41a168',
  ].map(
    (role) =>
      `/subscriptions/${subscriptionId}/providers/Microsoft.Authorization/` +
      `roleDefinitions/${role}`,
  );
  const clauses = properties.policyRule?.if?.allOf ?? [];
  return (
    parseResourceId(change.resourceId).type ===
      'microsoft.authorization/policydefinitions' &&
    normalizeId(change.resourceId) ===
      normalizeId(
        `/subscriptions/${subscriptionId}/providers/` +
          'Microsoft.Authorization/policyDefinitions/' +
          armGuid(
            `/subscriptions/${subscriptionId}`,
            'certigo-privileged-ci-role-assignments',
          ),
      ) &&
    properties.policyType === 'Custom' &&
    properties.mode === 'All' &&
    properties.parameters?.effect?.defaultValue === 'Audit' &&
    sameStrings(properties.parameters?.effect?.allowedValues, [
      'Audit',
      'Deny',
      'Disabled',
    ]) &&
    clauses.length === 4 &&
    clauses[0]?.field === 'type' &&
    clauses[0]?.equals === 'Microsoft.Authorization/roleAssignments' &&
    clauses[1]?.field ===
      'Microsoft.Authorization/roleAssignments/principalType' &&
    clauses[1]?.equals === 'ServicePrincipal' &&
    clauses[2]?.field === 'Microsoft.Authorization/roleAssignments/scope' &&
    normalizeId(clauses[2]?.equals) ===
      normalizeId(`/subscriptions/${subscriptionId}`) &&
    clauses[3]?.field ===
      'Microsoft.Authorization/roleAssignments/roleDefinitionId' &&
    sameStrings(clauses[3]?.in, expectedPrivilegedRoles) &&
    properties.policyRule?.then?.effect === "[parameters('effect')]"
  );
}

export function contentPlanCondition(phaseA) {
  const publishers = [
    phaseA.identities.contentRelease.principalId,
    phaseA.identities.contentPublic.principalId,
    phaseA.identities.contentAnswerKey.principalId,
  ];
  return (
    "((!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})) OR " +
    '(((@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ' +
    'GuidEquals c8a9d1bb-39d7-4f4f-9a4c-17b4c81aa5de) AND ' +
    '(@Request[Microsoft.Authorization/roleAssignments:PrincipalId] ' +
    `ForAnyOfAnyValues:GuidEquals {${publishers.join(', ')}})) OR ` +
    '((@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ' +
    'GuidEquals 2a2b9908-6ea1-4ae2-8e65-a410df84e7d1) AND ' +
    '(@Request[Microsoft.Authorization/roleAssignments:PrincipalId] ' +
    `GuidEquals ${phaseA.identities.contentReader.principalId}))) AND ` +
    '(@Request[Microsoft.Authorization/roleAssignments:PrincipalType] ' +
    "StringEqualsIgnoreCase 'ServicePrincipal'))"
  );
}

export function runtimeWriterCondition() {
  const roles = [
    'ba92f5b4-2d11-453d-a403-e96b0029c9fe',
    'b7e6dc6d-f1e8-4753-8033-0f276bb0955b',
    'db58b8e5-c6ad-4a2a-8342-4190687cbf4a',
    '974c5e8b-45b9-4653-ba55-5f855dd0fb88',
    '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3',
    '3913510d-42f4-4e42-8a64-420c390055eb',
    '4633458b-17de-408a-b874-0445c86b69e6',
    '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd',
    '73c42c96-874c-492b-b04d-ab87d138a893',
  ];
  return (
    "((!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})) OR " +
    '((@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ' +
    `ForAnyOfAnyValues:GuidEquals {${roles.join(', ')}}) AND ` +
    '(@Request[Microsoft.Authorization/roleAssignments:PrincipalType] ' +
    "StringEqualsIgnoreCase 'ServicePrincipal')))"
  );
}

function assignmentResourceId(scope, nameSeed, roleDefinitionId) {
  return (
    `${scope}/providers/Microsoft.Authorization/roleAssignments/` +
    armGuid(scope, nameSeed, roleDefinitionId)
  );
}

function managedIdentityOperatorRoleDefinitionId(subscriptionId) {
  return (
    `/subscriptions/${subscriptionId}/providers/Microsoft.Authorization/` +
    'roleDefinitions/f1a07417-d97a-45cb-824c-7a7467783830'
  );
}

function expectedRoleAssignments(subscriptionId, phaseA) {
  const roleIds = Object.fromEntries(
    Object.entries(phaseA.roleDefinitionIds).map(([key, value]) => [
      key,
      value,
    ]),
  );
  const contributorRoleId =
    `/subscriptions/${subscriptionId}/providers/Microsoft.Authorization/` +
    'roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c';
  const managedIdentityOperatorRoleId =
    managedIdentityOperatorRoleDefinitionId(subscriptionId);
  const descriptions = [];

  for (const environment of ['dev', 'staging', 'prod']) {
    const identity =
      phaseA.identities[
        `deploy${environment[0].toUpperCase()}${environment.slice(1)}`
      ];
    descriptions.push({
      nameSeed: identity.name,
      condition: null,
      description:
        `Launches the ${environment} subscription deployment without general ` +
        'subscription access.',
      principalId: identity.principalId,
      roleDefinitionId: roleIds.subscriptionDeploymentLauncher,
      scope: `/subscriptions/${subscriptionId}`,
    });
    descriptions.push({
      nameSeed: identity.name,
      condition: null,
      description: 'Certigo environment deployment; no role-assignment administration.',
      principalId: identity.principalId,
      roleDefinitionId: contributorRoleId,
      scope:
        `/subscriptions/${subscriptionId}/resourceGroups/rg-certigo-${environment}`,
    });
    descriptions.push({
      nameSeed: identity.name,
      condition: runtimeWriterCondition(),
      description:
        'May create only approved runtime roles for service principals in this environment.',
      principalId: identity.principalId,
      roleDefinitionId: roleIds.runtimeRoleAssignmentWriter,
      scope:
        `/subscriptions/${subscriptionId}/resourceGroups/rg-certigo-${environment}`,
    });
    descriptions.push({
      nameSeed: identity.name,
      condition: null,
      description:
        `Allows ${environment} to reconcile only shared DNS links and VNet peerings.`,
      principalId: identity.principalId,
      roleDefinitionId: roleIds.sharedNetworkDeployment,
      scope: `/subscriptions/${subscriptionId}/resourceGroups/rg-certigo-ci`,
    });
    descriptions.push({
      nameSeed: identity.name,
      condition: null,
      description:
        `Allows ${environment} deployment to attach only the immutable content reader identity.`,
      principalId: identity.principalId,
      roleDefinitionId: managedIdentityOperatorRoleId,
      scope: phaseA.identities.contentReader.resourceId,
    });
  }

  descriptions.push(
    {
      nameSeed: phaseA.identities.contentInfrastructurePlan.name,
      condition: contentPlanCondition(phaseA),
      description:
        'Plans the content stack and may assign only approved content roles to service principals.',
      principalId: phaseA.identities.contentInfrastructurePlan.principalId,
      roleDefinitionId: roleIds.contentInfrastructurePlanExecutor,
      scope: `/subscriptions/${subscriptionId}/resourceGroups/rg-certigo-content`,
    },
    {
      nameSeed: phaseA.identities.contentInfrastructurePlan.principalId,
      condition: null,
      description:
        'Allows the content plan to read and join only the trusted CI runner subnet.',
      principalId: phaseA.identities.contentInfrastructurePlan.principalId,
      roleDefinitionId: roleIds.contentInfrastructurePlanExternalJoin,
      scope:
        `/subscriptions/${subscriptionId}/resourceGroups/rg-certigo-ci/providers/` +
        'Microsoft.Network/virtualNetworks/vnet-certigo-ci/subnets/snet-runners',
    },
    {
      nameSeed: phaseA.identities.contentInfrastructurePlan.principalId,
      condition: null,
      description:
        'Allows the content plan to read and join only the shared Blob private DNS zone.',
      principalId: phaseA.identities.contentInfrastructurePlan.principalId,
      roleDefinitionId: roleIds.contentInfrastructurePlanExternalJoin,
      scope:
        `/subscriptions/${subscriptionId}/resourceGroups/rg-certigo-ci/providers/` +
        'Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net',
    },
  );

  return descriptions.map((description) => ({
    ...description,
    resourceId: assignmentResourceId(
      description.scope,
      description.nameSeed,
      description.roleDefinitionId,
    ),
  }));
}

function expectedRoleAssignment(properties, scope, subscriptionId, phaseA) {
  const normalizedScope = normalizeId(scope);
  return expectedRoleAssignments(subscriptionId, phaseA).find(
    (candidate) =>
      candidate.description === properties.description &&
      normalizeId(candidate.scope) === normalizedScope,
  );
}

function roleAssignmentScope(resourceId) {
  const marker = '/providers/microsoft.authorization/roleassignments/';
  const normalized = normalizeId(resourceId);
  const index = normalized.lastIndexOf(marker);
  return index >= 0 ? normalized.slice(0, index) : null;
}

function validateRoleAssignment(change, subscriptionId, phaseA) {
  const properties = change.after?.properties ?? {};
  const scope = roleAssignmentScope(change.resourceId);
  if (!scope) {
    return false;
  }
  const expected = expectedRoleAssignment(
    properties,
    scope,
    subscriptionId,
    phaseA,
  );
  return Boolean(
    expected &&
      normalizeId(change.resourceId) === normalizeId(expected.resourceId) &&
      properties.principalType === 'ServicePrincipal' &&
      normalizeId(properties.principalId) === normalizeId(expected.principalId) &&
      normalizeId(properties.roleDefinitionId) ===
        normalizeId(expected.roleDefinitionId) &&
      (properties.condition ?? null) === expected.condition &&
      (expected.condition === null ||
        properties.conditionVersion === '2.0'),
  );
}

function validatePolicyAssignment(change, subscriptionId, phaseA) {
  const properties = change.after?.properties ?? {};
  return (
    normalizeId(change.resourceId) ===
      normalizeId(
        `/subscriptions/${subscriptionId}/providers/Microsoft.Authorization/` +
          'policyAssignments/certigo-privileged-ci-rbac',
      ) &&
    normalizeId(properties.policyDefinitionId) ===
      normalizeId(phaseA.policyDefinitionId) &&
    properties.enforcementMode === 'Default' &&
    properties.parameters?.effect?.value === 'Audit'
  );
}

function validateDeployment(change, expectedIds) {
  const parsed = parseResourceId(change.resourceId);
  const expectedId = expectedIds.get(parsed.names[0]);
  const requireMaterialized =
    change.changeType === 'Ignore' || change.changeType === 'NoChange';
  const properties = change.after?.properties;
  const nonEmptyString = (value) =>
    typeof value === 'string' && value.trim().length > 0;
  const hasDeploymentState = Boolean(
    nonEmptyString(properties?.provisioningState) ||
      nonEmptyString(properties?.templateHash) ||
      (properties?.templateLink &&
        typeof properties.templateLink === 'object' &&
        ['id', 'relativePath', 'uri'].some((key) =>
          nonEmptyString(properties.templateLink[key]),
        )),
  );
  return (
    parsed.type === 'microsoft.resources/deployments' &&
    change.resourceId === expectedId &&
    (!requireMaterialized ||
      (hasCompletePayload(change) &&
        change.after.type === 'Microsoft.Resources/deployments' &&
        hasDeploymentState))
  );
}

function phaseAContract(change, subscriptionId) {
  const id = normalizeId(change.resourceId);
  const parsed = parseResourceId(id);
  const requireMaterialized =
    change.changeType === 'Ignore' || change.changeType === 'NoChange';
  if (requireMaterialized && !hasCompletePayload(change)) {
    return null;
  }
  if (
    id ===
    normalizeId(
      `/subscriptions/${subscriptionId}/resourceGroups/rg-certigo-content`,
    )
  ) {
    if (
      requireMaterialized &&
      (change.after.location?.toLowerCase() !== 'westeurope' ||
        change.after.tags?.product !== 'Certigo' ||
        change.after.tags?.workload !== 'immutable-content' ||
        change.after.tags?.managedBy !== 'bicep')
    ) {
      return null;
    }
    return 'resource-group:rg-certigo-content';
  }
  if (
    id ===
    normalizeId(
      `/subscriptions/${subscriptionId}/resourceGroups/rg-certigo-identities`,
    )
  ) {
    if (
      requireMaterialized &&
      (change.after.location?.toLowerCase() !== 'westeurope' ||
        change.after.tags?.product !== 'Certigo' ||
        change.after.tags?.managedBy !== 'bicep' ||
        change.after.tags?.purpose !== 'github-oidc-deployment')
    ) {
      return null;
    }
    return 'resource-group:rg-certigo-identities';
  }

  if (parsed.type === 'microsoft.authorization/roledefinitions') {
    const role = identifyRoleContract(change, subscriptionId);
    return role ? `role:${role}` : null;
  }
  if (parsed.type === 'microsoft.managedidentity/userassignedidentities') {
    return validateIdentityChange(change, subscriptionId, requireMaterialized)
      ? `identity:${parsed.names[0]}`
      : null;
  }
  if (
    parsed.type ===
    'microsoft.managedidentity/userassignedidentities/federatedidentitycredentials'
  ) {
    return (
      validateCredentialChange(change, subscriptionId)
    )
      ? `credential:${parsed.names.join('/')}`
      : null;
  }
  if (parsed.type === 'microsoft.authorization/policydefinitions') {
    return validatePolicyDefinition(change, subscriptionId)
      ? 'policy-definition'
      : null;
  }
  if (validateDeployment(change, phaseADeploymentIds(subscriptionId))) {
    return `deployment:${parsed.names[0]}`;
  }
  return null;
}

export function validatePhaseAResource(resource, subscriptionId) {
  const contract = phaseAContract(
    {
      changeType: 'NoChange',
      resourceId: resource?.id,
      after: resource,
    },
    subscriptionId,
  );
  if (!contract || contract.startsWith('auxiliary:')) {
    throw new Error(
      `live resource violates the exact Phase A contract: ${resource?.id}`,
    );
  }
  return contract;
}

export function expectedPhaseBContracts(subscriptionId, phaseA, phase) {
  const proof = validatePhaseAProof(phaseA, subscriptionId);
  if (phase === 'B1a') {
    return [...requiredPhaseB1aContracts(subscriptionId, proof)].sort();
  }
  if (phase === 'B1b') {
    return [...requiredPhaseB1bContracts(subscriptionId, proof)].sort();
  }
  if (phase === 'B2') {
    return [...requiredPhaseB2Contracts(subscriptionId, proof)].sort();
  }
  throw new Error('phase must be B1a, B1b, or B2');
}

export function validatePhaseBResource(resource, subscriptionId, phaseA, phase) {
  if (!['B1a', 'B1b', 'B2'].includes(phase)) {
    throw new Error('Phase B resource validation requires B1a, B1b, or B2');
  }
  const proof = validatePhaseAProof(phaseA, subscriptionId);
  const contract = phaseBContract(
    {
      changeType: 'Create',
      resourceId: resource?.id,
      after: resource,
    },
    subscriptionId,
    proof,
    phase,
  );
  if (
    !contract ||
    (!contract.startsWith('role-assignment:') &&
      contract !== 'policy-assignment')
  ) {
    throw new Error(
      `live resource violates the exact Phase ${phase} contract: ${resource?.id}`,
    );
  }
  return contract;
}

function assignmentContract(candidate) {
  return (
    `role-assignment:${normalizeId(candidate.scope)}:${candidate.description}`
  );
}

function phaseBContract(change, subscriptionId, phaseA, phase) {
  const id = normalizeId(change.resourceId);
  const parsed = parseResourceId(id);
  const requireMaterialized =
    change.changeType === 'Ignore' || change.changeType === 'NoChange';
  if (requireMaterialized && !hasCompletePayload(change)) {
    return null;
  }
  if (
    parsed.type === 'microsoft.authorization/roleassignments' &&
    validateRoleAssignment(change, subscriptionId, phaseA)
  ) {
    const contract = `role-assignment:${roleAssignmentScope(change.resourceId)}:${
      change.after?.properties?.description
    }`;
    const allowed =
      phase === 'B1a'
        ? requiredPhaseB1aContracts(subscriptionId, phaseA)
        : phase === 'B1b'
          ? requiredPhaseB1bContracts(subscriptionId, phaseA)
          : requiredPhaseB2Contracts(subscriptionId, phaseA);
    return allowed.has(contract) ? contract : null;
  }
  if (
    phase === 'B1b' &&
    parsed.type === 'microsoft.authorization/policyassignments' &&
    validatePolicyAssignment(change, subscriptionId, phaseA)
  ) {
    return 'policy-assignment';
  }
  if (
    phase === 'B1a' &&
    validateDeployment(change, phaseB1DeploymentIds(subscriptionId))
  ) {
    return `deployment:${parsed.names[0]}`;
  }
  if (change.changeType === 'Create') {
    return null;
  }
  const resourceGroupId = (name) =>
    normalizeId(`/subscriptions/${subscriptionId}/resourceGroups/${name}`);
  const exactInputs =
    phase !== 'B2'
      ? new Set(
          ['rg-certigo-ci', 'rg-certigo-content', 'rg-certigo-dev',
            'rg-certigo-staging', 'rg-certigo-prod'].map(resourceGroupId),
        )
      : new Set([
          resourceGroupId('rg-certigo-ci'),
          normalizeId(
            `/subscriptions/${subscriptionId}/resourceGroups/rg-certigo-ci/` +
              'providers/Microsoft.Network/virtualNetworks/vnet-certigo-ci',
          ),
          normalizeId(
            `/subscriptions/${subscriptionId}/resourceGroups/rg-certigo-ci/` +
              'providers/Microsoft.Network/virtualNetworks/vnet-certigo-ci/' +
              'subnets/snet-runners',
          ),
          normalizeId(
            `/subscriptions/${subscriptionId}/resourceGroups/rg-certigo-ci/` +
              'providers/Microsoft.Network/privateDnsZones/' +
              'privatelink.blob.core.windows.net',
          ),
        ]);
  return exactInputs.has(id) ? `input:resource:${id}` : null;
}

function requiredPhaseAContracts() {
  return new Set([
    'resource-group:rg-certigo-content',
    'resource-group:rg-certigo-identities',
    ...Object.keys(roleContracts).map((key) => `role:${key}`),
    ...Object.values(identityContracts).map(
      (identity) => `identity:${identity.name}`,
    ),
    ...Object.values(identityContracts)
      .filter((identity) => identity.credential)
      .map(
        (identity) =>
          `credential:${identity.name}/${identity.credential.name}`,
      ),
    'policy-definition',
  ]);
}

function isExternalJoinAssignment(candidate) {
  return candidate.description.startsWith(
    'Allows the content plan to read and join only the ',
  );
}

function isSubscriptionLauncherAssignment(candidate) {
  return candidate.description.startsWith('Launches the ');
}

function requiredPhaseB1aContracts(subscriptionId, phaseA) {
  return new Set(
    expectedRoleAssignments(subscriptionId, phaseA)
      .filter(
        (candidate) =>
          !isExternalJoinAssignment(candidate) &&
          !isSubscriptionLauncherAssignment(candidate) &&
          ![
            managedIdentityOperatorRoleDefinitionId(subscriptionId),
            phaseA.roleDefinitionIds.runtimeRoleAssignmentWriter,
            phaseA.roleDefinitionIds.contentInfrastructurePlanExecutor,
          ].some(
            (roleDefinitionId) =>
              normalizeId(roleDefinitionId) ===
              normalizeId(candidate.roleDefinitionId),
          ),
      )
      .map(assignmentContract),
  );
}

function requiredPhaseB1bContracts(subscriptionId, phaseA) {
  return new Set([
    'policy-assignment',
    ...expectedRoleAssignments(subscriptionId, phaseA)
      .filter(isSubscriptionLauncherAssignment)
      .concat(
        expectedRoleAssignments(subscriptionId, phaseA).filter((candidate) =>
          [
            managedIdentityOperatorRoleDefinitionId(subscriptionId),
            phaseA.roleDefinitionIds.runtimeRoleAssignmentWriter,
            phaseA.roleDefinitionIds.contentInfrastructurePlanExecutor,
          ].some(
            (roleDefinitionId) =>
              normalizeId(roleDefinitionId) ===
              normalizeId(candidate.roleDefinitionId),
          ),
        ),
      )
      .map(assignmentContract),
  ]);
}

function requiredPhaseB2Contracts(subscriptionId, phaseA) {
  return new Set(
    expectedRoleAssignments(subscriptionId, phaseA)
      .filter(isExternalJoinAssignment)
      .map(assignmentContract),
  );
}

export function validateWhatIf(
  plan,
  subscriptionId,
  { phase = 'A', phaseA = null } = {},
) {
  if (!uuidPattern.test(subscriptionId ?? '')) {
    throw new Error('subscription id must be an explicit UUID');
  }
  if (!['A', 'B1a', 'B1b', 'B2'].includes(phase)) {
    throw new Error('phase must be A, B1a, B1b, or B2');
  }
  const errors = [];
  if (plan.status !== 'Succeeded') {
    errors.push(`what-if status must be Succeeded, received ${plan.status ?? '<missing>'}`);
  }
  if (plan.error != null) {
    errors.push('what-if returned an error payload');
  }
  if (
    plan.diagnostics != null &&
    (!Array.isArray(plan.diagnostics) || plan.diagnostics.length > 0)
  ) {
    errors.push('what-if returned diagnostics');
  }
  if (plan.potentialChanges != null) {
    errors.push('what-if expansion is incomplete: potentialChanges must be null');
  }
  if (!Array.isArray(plan.changes)) {
    errors.push('what-if changes must be a materialized array');
  }
  if (errors.length > 0) {
    throw new Error(errors.join('\n'));
  }
  const proof = phase !== 'A' ? validatePhaseAProof(phaseA, subscriptionId) : null;
  const changes = plan.changes;
  const counts = {};
  const seenContracts = new Set();

  for (const change of changes) {
    const changeType = change.changeType ?? 'Unknown';
    const resourceId = change.resourceId ?? '';
    counts[changeType] = (counts[changeType] ?? 0) + 1;

    if (change.unsupportedReason != null) {
      errors.push(
        `Phase ${phase} rejects unsupported resource expansion: ${
          resourceId || '<missing resource id>'
        }`,
      );
      continue;
    }
    if (!['Create', 'Ignore', 'NoChange'].includes(changeType)) {
      errors.push(
        `Phase ${phase} forbids ${changeType}: ${resourceId || '<missing resource id>'}`,
      );
      continue;
    }
    if (
      !normalizeId(resourceId).startsWith(
        `/subscriptions/${subscriptionId.toLowerCase()}`,
      )
    ) {
      errors.push(`resource is outside subscription ${subscriptionId}: ${resourceId}`);
      continue;
    }
    if (changeType === 'Ignore' && !isInertIgnore(change)) {
      errors.push(
        `Phase ${phase} rejects non-inert Ignore: ${resourceId || '<missing resource id>'}`,
      );
      continue;
    }
    if (changeType === 'Ignore' || changeType === 'NoChange') {
      const contract =
        phase === 'A'
          ? phaseAContract(change, subscriptionId)
          : phaseBContract(change, subscriptionId, proof, phase);
      if (!contract) {
        errors.push(
          `${changeType} resource is outside the Phase ${phase} allowlist: ${resourceId}`,
        );
      } else if (seenContracts.has(contract)) {
        errors.push(`duplicate Phase ${phase} contract resource: ${contract}`);
      } else {
        seenContracts.add(contract);
      }
      continue;
    }

    const contract =
      phase === 'A'
        ? phaseAContract(change, subscriptionId)
        : phaseBContract(change, subscriptionId, proof, phase);

    if (!contract) {
      errors.push(`resource is outside the exact Phase ${phase} contract: ${resourceId}`);
    } else if (seenContracts.has(contract)) {
      errors.push(`duplicate Phase ${phase} contract resource: ${contract}`);
    } else {
      seenContracts.add(contract);
    }
  }

  const required =
    phase === 'A'
      ? requiredPhaseAContracts()
      : phase === 'B1a'
        ? requiredPhaseB1aContracts(subscriptionId, proof)
        : phase === 'B1b'
          ? requiredPhaseB1bContracts(subscriptionId, proof)
          : requiredPhaseB2Contracts(subscriptionId, proof);
  const missing = [...required].filter((contract) => !seenContracts.has(contract));
  if (missing.length > 0) {
    errors.push(`Phase ${phase} plan is incomplete: ${missing.join(', ')}`);
  }

  if (errors.length > 0) {
    throw new Error(errors.join('\n'));
  }
  return { counts, total: changes.length };
}

function parseArguments(argv) {
  const result = {};
  for (let index = 0; index < argv.length; index += 2) {
    result[argv[index]] = argv[index + 1];
  }
  return result;
}

function main() {
  const args = parseArguments(process.argv.slice(2));
  const planPath = args['--plan'];
  const subscriptionId = args['--subscription'];
  const phase = args['--phase'];
  const phaseAPath = args['--phase-a'];
  if (
    !planPath ||
    !subscriptionId ||
    !phase ||
    (phase !== 'A' && !phaseAPath)
  ) {
    throw new Error(
      'Usage: node validate-what-if.mjs --plan <path> --subscription <id> ' +
        '--phase <A|B1a|B1b|B2> [--phase-a <outputs.json>]',
    );
  }
  const plan = JSON.parse(fs.readFileSync(path.resolve(planPath), 'utf8'));
  const phaseA = phaseAPath
    ? JSON.parse(fs.readFileSync(path.resolve(phaseAPath), 'utf8'))
    : null;
  const result = validateWhatIf(plan, subscriptionId, { phase, phaseA });
  const summary = process.env.GITHUB_STEP_SUMMARY;
  if (summary) {
    fs.appendFileSync(
      summary,
      `## Certigo governance bootstrap Phase ${phase} what-if\n\n` +
        'No deployment was executed. Only exact `Create`, `Ignore`, and ' +
        '`NoChange` resources are allowed; ' +
        '`Modify`, `Delete`, and `Unsupported` fail closed.\n\n' +
        `\`\`\`json\n${JSON.stringify(result.counts, null, 2)}\n\`\`\`\n`,
    );
  }
  process.stdout.write(`${JSON.stringify(result)}\n`);
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  main();
}
