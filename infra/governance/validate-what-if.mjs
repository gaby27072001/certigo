import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const allowedResourceGroups = new Set([
  'rg-certigo-ci',
  'rg-certigo-content',
  'rg-certigo-dev',
  'rg-certigo-staging',
  'rg-certigo-prod',
]);

const allowedCiIdentityNames = new Set([
  'id-certigo-content-infra-plan',
  'id-certigo-deploy-dev',
  'id-certigo-deploy-prod',
  'id-certigo-deploy-staging',
]);

const allowedContentIdentityNames = new Set([
  'id-certigo-content-answer-key',
  'id-certigo-content-public',
  'id-certigo-content-reader',
  'id-certigo-content-release',
]);

const expectedFederatedCredentials = new Map([
  ...['dev', 'staging', 'prod'].map((environment) => [
    `id-certigo-deploy-${environment}`,
    {
      name: `github-${environment}`,
      subject:
        `repo:gchambaud_microsoft/Certigo:environment:${environment}`,
    },
  ]),
  [
    'id-certigo-content-infra-plan',
    {
      name: 'github-azure-content-infra-plan',
      subject:
        'repo:gchambaud_microsoft/Certigo:environment:azure-content-infra-plan',
    },
  ],
  [
    'id-certigo-content-release',
    {
      name: 'github-azure-content-release',
      subject:
        'repo:gchambaud_microsoft/certigo-content:environment:azure-content-release',
    },
  ],
  [
    'id-certigo-content-public',
    {
      name: 'github-azure-content-public',
      subject:
        'repo:gchambaud_microsoft/certigo-content:environment:azure-content-public',
    },
  ],
  [
    'id-certigo-content-answer-key',
    {
      name: 'github-azure-content-answer-key',
      subject:
        'repo:gchambaud_microsoft/certigo-content:environment:azure-content-answer-key',
    },
  ],
]);

const subscriptionLauncherActions = [
  'Microsoft.Resources/deployments/read',
  'Microsoft.Resources/deployments/validate/action',
  'Microsoft.Resources/deployments/whatIf/action',
  'Microsoft.Resources/deployments/write',
  'Microsoft.Resources/subscriptions/resourceGroups/read',
].sort();

const roleContracts = [
  {
    kind: 'launcher',
    name: /^Certigo Subscription Deployment Launcher [a-z0-9]{6}$/,
    actions: subscriptionLauncherActions,
    dataActions: [],
    scopes: (subscriptionId) => [`/subscriptions/${subscriptionId}`],
  },
  {
    kind: 'runtime-writer',
    name: /^Certigo Runtime Role Assignment Writer [a-z0-9]{6}$/,
    actions: [
      'Microsoft.Authorization/roleAssignments/read',
      'Microsoft.Authorization/roleAssignments/write',
      'Microsoft.Authorization/roleDefinitions/read',
      'Microsoft.Resources/subscriptions/resourceGroups/read',
    ].sort(),
    dataActions: [],
    scopes: (subscriptionId) =>
      ['dev', 'staging', 'prod'].map(
        (environment) =>
          `/subscriptions/${subscriptionId}/resourceGroups/rg-certigo-${environment}`,
      ),
  },
  {
    kind: 'shared-network',
    name: /^Certigo Shared Network Deployment [a-z0-9]{6}$/,
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
    ].sort(),
    dataActions: [],
    scopes: (subscriptionId) => [
      `/subscriptions/${subscriptionId}/resourceGroups/rg-certigo-ci`,
    ],
  },
  {
    kind: 'publisher',
    name: /^Certigo Immutable Content Publisher [a-z0-9]{6}$/,
    actions: [
      'Microsoft.Storage/storageAccounts/blobServices/containers/immutabilityPolicies/read',
      'Microsoft.Storage/storageAccounts/blobServices/containers/read',
    ].sort(),
    dataActions: [
      'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read',
      'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write',
    ].sort(),
    scopes: (subscriptionId) => [
      `/subscriptions/${subscriptionId}/resourceGroups/rg-certigo-content`,
    ],
  },
  {
    kind: 'content-plan',
    name: /^Certigo Content Infrastructure Plan Executor [a-z0-9]{6}$/,
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
      'Microsoft.Storage/storageAccounts/blobServices/containers/immutabilityPolicies/read',
      'Microsoft.Storage/storageAccounts/blobServices/containers/immutabilityPolicies/write',
      'Microsoft.Storage/storageAccounts/blobServices/containers/read',
      'Microsoft.Storage/storageAccounts/blobServices/containers/write',
      'Microsoft.Storage/storageAccounts/blobServices/read',
      'Microsoft.Storage/storageAccounts/blobServices/write',
      'Microsoft.Storage/storageAccounts/managementPolicies/read',
      'Microsoft.Storage/storageAccounts/managementPolicies/write',
      'Microsoft.Storage/storageAccounts/PrivateEndpointConnectionsApproval/action',
      'Microsoft.Storage/storageAccounts/read',
      'Microsoft.Storage/storageAccounts/write',
    ].sort(),
    dataActions: [],
    scopes: (subscriptionId) => [
      `/subscriptions/${subscriptionId}/resourceGroups/rg-certigo-content`,
    ],
  },
  {
    kind: 'external-join',
    name: /^Certigo Content Infrastructure Plan External Join [a-z0-9]{6}$/,
    actions: [
      'Microsoft.Network/privateDnsZones/join/action',
      'Microsoft.Network/privateDnsZones/read',
      'Microsoft.Network/virtualNetworks/subnets/join/action',
      'Microsoft.Network/virtualNetworks/subnets/read',
    ].sort(),
    dataActions: [],
    scopes: (subscriptionId) => [
      `/subscriptions/${subscriptionId}/resourceGroups/rg-certigo-ci`,
    ],
  },
];

function sameStrings(actual = [], expected = []) {
  return (
    JSON.stringify([...actual].sort()) === JSON.stringify([...expected].sort())
  );
}

function matchRoleContract(change, subscriptionId) {
  const properties = change.after?.properties;
  const [permissions] = properties?.permissions ?? [];
  const contract = roleContracts.find((candidate) =>
    candidate.name.test(properties?.roleName ?? ''),
  );
  if (
    !contract ||
    properties?.type !== 'CustomRole' ||
    (properties.permissions ?? []).length !== 1 ||
    !sameStrings(permissions.actions, contract.actions) ||
    !sameStrings(permissions.dataActions, contract.dataActions) ||
    !sameStrings(permissions.notActions, []) ||
    !sameStrings(permissions.notDataActions, []) ||
    !sameStrings(properties.assignableScopes, contract.scopes(subscriptionId))
  ) {
    return null;
  }
  if (
    contract.kind === 'publisher' &&
    !(change.resourceId ?? '')
      .toLowerCase()
      .endsWith('/c8a9d1bb-39d7-4f4f-9a4c-17b4c81aa5de')
  ) {
    return null;
  }
  return contract.kind;
}

function expectedResourceGroupAssignment(
  description,
  resourceGroup,
  scope,
  subscriptionId,
) {
  const environmentMatch = description.match(
    /^Allows (dev|staging|prod) to reconcile only shared DNS links and VNet peerings\.$/,
  );
  if (environmentMatch && resourceGroup === 'rg-certigo-ci') {
    return {
      conditioned: false,
      identityName: `id-certigo-deploy-${environmentMatch[1]}`,
      roleKind: 'shared-network',
      scope:
        `/subscriptions/${subscriptionId}/resourcegroups/rg-certigo-ci`,
    };
  }
  if (
    description ===
      'Certigo environment deployment; no role-assignment administration.' &&
    /^rg-certigo-(dev|staging|prod)$/.test(resourceGroup ?? '')
  ) {
    return {
      conditioned: false,
      identityName: `id-certigo-deploy-${resourceGroup.slice('rg-certigo-'.length)}`,
      roleKind: 'builtin-contributor',
      scope: `/subscriptions/${subscriptionId}/resourcegroups/${resourceGroup}`,
    };
  }
  if (
    description ===
      'May create only approved runtime roles for service principals in this environment.' &&
    /^rg-certigo-(dev|staging|prod)$/.test(resourceGroup ?? '')
  ) {
    return {
      conditioned: true,
      identityName: `id-certigo-deploy-${resourceGroup.slice('rg-certigo-'.length)}`,
      roleKind: 'runtime-writer',
      scope: `/subscriptions/${subscriptionId}/resourcegroups/${resourceGroup}`,
    };
  }
  if (
    description ===
      'Plans the content stack and may assign only approved content roles to service principals.' &&
    resourceGroup === 'rg-certigo-content'
  ) {
    return {
      conditioned: true,
      identityName: 'id-certigo-content-infra-plan',
      roleKind: 'content-plan',
      scope:
        `/subscriptions/${subscriptionId}/resourcegroups/rg-certigo-content`,
    };
  }
  if (
    description ===
      'Allows the content plan to read and join only the trusted CI runner subnet.' &&
    scope.endsWith(
      '/resourcegroups/rg-certigo-ci/providers/microsoft.network/virtualnetworks/vnet-certigo-ci/subnets/snet-runners',
    )
  ) {
    return {
      conditioned: false,
      identityName: 'id-certigo-content-infra-plan',
      roleKind: 'external-join',
      scope,
    };
  }
  if (
    description ===
      'Allows the content plan to read and join only the shared Blob private DNS zone.' &&
    scope.endsWith(
      '/resourcegroups/rg-certigo-ci/providers/microsoft.network/privatednszones/privatelink.blob.core.windows.net',
    )
  ) {
    return {
      conditioned: false,
      identityName: 'id-certigo-content-infra-plan',
      roleKind: 'external-join',
      scope,
    };
  }
  return null;
}

function contentPlanRoleAssignmentCondition(principalIdsByIdentityName) {
  const publisherPrincipalIds = [
    'id-certigo-content-release',
    'id-certigo-content-public',
    'id-certigo-content-answer-key',
  ].map((name) => principalIdsByIdentityName.get(name));
  const readerPrincipalId = principalIdsByIdentityName.get(
    'id-certigo-content-reader',
  );
  if (
    publisherPrincipalIds.some((principalId) => !principalId) ||
    !readerPrincipalId
  ) {
    return null;
  }
  return (
    "((!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})) OR " +
    '(((@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ' +
    'GuidEquals c8a9d1bb-39d7-4f4f-9a4c-17b4c81aa5de) AND ' +
    '(@Request[Microsoft.Authorization/roleAssignments:PrincipalId] ' +
    `ForAnyOfAnyValues:GuidEquals {${publisherPrincipalIds.join(', ')}})) OR ` +
    '((@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ' +
    'GuidEquals 2a2b9908-6ea1-4ae2-8e65-a410df84e7d1) AND ' +
    '(@Request[Microsoft.Authorization/roleAssignments:PrincipalId] ' +
    `GuidEquals ${readerPrincipalId}))) AND ` +
    '(@Request[Microsoft.Authorization/roleAssignments:PrincipalType] ' +
    "StringEqualsIgnoreCase 'ServicePrincipal'))"
  );
}

const allowedSubscriptionTypes = new Set([
  'microsoft.authorization/policyassignments',
  'microsoft.authorization/policydefinitions',
  'microsoft.authorization/roleassignments',
  'microsoft.authorization/roledefinitions',
  'microsoft.resources/deployments',
  'microsoft.resources/resourcegroups',
]);

const allowedResourceGroupTypes = new Map([
  [
    'rg-certigo-content',
    new Set([
      'microsoft.authorization/roleassignments',
      'microsoft.managedidentity/userassignedidentities',
      'microsoft.managedidentity/userassignedidentities/federatedidentitycredentials',
      'microsoft.resources/deployments',
    ]),
  ],
  [
    'rg-certigo-ci',
    new Set([
      'microsoft.authorization/roleassignments',
      'microsoft.managedidentity/userassignedidentities',
      'microsoft.managedidentity/userassignedidentities/federatedidentitycredentials',
      'microsoft.resources/deployments',
    ]),
  ],
  ...['rg-certigo-dev', 'rg-certigo-staging', 'rg-certigo-prod'].map(
    (resourceGroup) => [
      resourceGroup,
      new Set([
        'microsoft.authorization/roleassignments',
        'microsoft.resources/deployments',
      ]),
    ],
  ),
]);

function parseResourceId(resourceId) {
  const parts = resourceId.split('/').filter(Boolean);
  const resourceGroupIndex = parts.findIndex(
    (part) => part.toLowerCase() === 'resourcegroups',
  );
  const providerIndex = parts.findLastIndex(
    (part) => part.toLowerCase() === 'providers',
  );
  const resourceTypes = [];
  if (providerIndex >= 0) {
    for (let index = providerIndex + 2; index < parts.length; index += 2) {
      resourceTypes.push(parts[index]);
    }
  }

  return {
    resourceGroup:
      resourceGroupIndex >= 0 ? parts[resourceGroupIndex + 1]?.toLowerCase() : null,
    type:
      providerIndex >= 0
        ? `${parts[providerIndex + 1]}/${resourceTypes.join('/')}`.toLowerCase()
        : null,
    names:
      providerIndex >= 0
        ? parts.filter(
            (_, index) =>
              index >= providerIndex + 3 &&
              (index - providerIndex) % 2 === 1,
          )
        : [],
  };
}

export function validateWhatIf(plan, subscriptionId) {
  const changes = plan.changes ?? [];
  const errors = [];
  const counts = {};
  const roleKindsById = new Map(
    changes
      .filter(
        (change) =>
          parseResourceId(change.resourceId ?? '').type ===
          'microsoft.authorization/roledefinitions',
      )
      .map((change) => [
        (change.resourceId ?? '').toLowerCase(),
        matchRoleContract(change, subscriptionId),
      ]),
  );
  const principalIdsByIdentityName = new Map(
    changes
      .filter(
        (change) =>
          parseResourceId(change.resourceId ?? '').type ===
          'microsoft.managedidentity/userassignedidentities',
      )
      .map((change) => [
        parseResourceId(change.resourceId ?? '').names[0]?.toLowerCase(),
        change.after?.properties?.principalId?.toLowerCase(),
      ])
      .filter(([, principalId]) => principalId),
  );

  for (const change of changes) {
    const changeType = change.changeType ?? 'Unknown';
    const resourceId = change.resourceId ?? '';
    counts[changeType] = (counts[changeType] ?? 0) + 1;

    if (changeType === 'Ignore') {
      continue;
    }

    if (changeType === 'Delete') {
      errors.push(`delete is forbidden: ${resourceId}`);
      continue;
    }

    const expectedPrefix = `/subscriptions/${subscriptionId}/`;
    if (!resourceId.toLowerCase().startsWith(expectedPrefix.toLowerCase())) {
      errors.push(`resource is outside subscription ${subscriptionId}: ${resourceId}`);
      continue;
    }

    const { names, resourceGroup, type } = parseResourceId(resourceId);
    if (
      type === 'microsoft.authorization/roledefinitions' &&
      !roleKindsById.get(resourceId.toLowerCase())
    ) {
      errors.push(`custom role definition is outside the exact contract: ${resourceId}`);
      continue;
    }
    if (resourceGroup !== null && !allowedResourceGroups.has(resourceGroup)) {
      errors.push(`resource group is outside the approved set: ${resourceId}`);
    } else if (
      resourceGroup !== null &&
      type !== null &&
      !allowedResourceGroupTypes.get(resourceGroup)?.has(type)
    ) {
      errors.push(
        `resource type is not approved in ${resourceGroup}: ${resourceId}`,
      );
    } else if (
      resourceGroup === null &&
      type === 'microsoft.authorization/roleassignments'
    ) {
      const roleDefinitionId =
        change.after?.properties?.roleDefinitionId?.toLowerCase();
      const description = change.after?.properties?.description ?? '';
      if (
        !roleDefinitionId ||
        roleKindsById.get(roleDefinitionId) !== 'launcher' ||
        !/^Launches the (dev|staging|prod) subscription deployment without general subscription access\.$/.test(
          description,
        ) ||
        change.after?.properties?.principalType !== 'ServicePrincipal' ||
        change.after?.properties?.principalId?.toLowerCase() !==
          principalIdsByIdentityName.get(
            `id-certigo-deploy-${description.match(/^Launches the (dev|staging|prod)/)?.[1]}`,
          )
      ) {
        errors.push(
          `subscription role assignment is outside the approved launcher set: ${resourceId}`,
        );
      }
    } else if (type === 'microsoft.authorization/roleassignments') {
      const properties = change.after?.properties ?? {};
      const roleDefinitionId = properties.roleDefinitionId?.toLowerCase();
      const contributorRoleDefinitionId =
        `/subscriptions/${subscriptionId.toLowerCase()}/providers/` +
        'microsoft.authorization/roledefinitions/' +
        'b24988ac-6180-42a0-ab88-20f7382dd24c';
      const roleKind =
        roleDefinitionId === contributorRoleDefinitionId
          ? 'builtin-contributor'
          : roleKindsById.get(roleDefinitionId);
      const scope = resourceId
        .toLowerCase()
        .split('/providers/microsoft.authorization/roleassignments/')[0];
      const expected = expectedResourceGroupAssignment(
        properties.description ?? '',
        resourceGroup,
        scope,
        subscriptionId.toLowerCase(),
      );
      const expectedCondition =
        expected?.roleKind === 'content-plan'
          ? contentPlanRoleAssignmentCondition(principalIdsByIdentityName)
          : null;
      if (
        !expected ||
        scope !== expected.scope ||
        roleKind !== expected.roleKind ||
        properties.principalType !== 'ServicePrincipal' ||
        properties.principalId?.toLowerCase() !==
          principalIdsByIdentityName.get(expected.identityName) ||
        Boolean(properties.condition) !== expected.conditioned ||
        (expected.conditioned && properties.conditionVersion !== '2.0') ||
        (expected.roleKind === 'content-plan' &&
          properties.condition !== expectedCondition)
      ) {
        errors.push(`role assignment is outside the exact contract: ${resourceId}`);
      }
    } else if (
      type ===
      'microsoft.managedidentity/userassignedidentities/federatedidentitycredentials'
    ) {
      const expected = expectedFederatedCredentials.get(
        names[0]?.toLowerCase(),
      );
      const properties = change.after?.properties ?? {};
      if (
        !expected ||
        names[1]?.toLowerCase() !== expected.name ||
        properties.issuer !== 'https://token.actions.githubusercontent.com' ||
        properties.subject !== expected.subject ||
        !sameStrings(properties.audiences, ['api://AzureADTokenExchange'])
      ) {
        errors.push(
          `federated credential is outside the exact contract: ${resourceId}`,
        );
      }
    } else if (
      resourceGroup === 'rg-certigo-ci' &&
      type?.startsWith('microsoft.managedidentity/userassignedidentities') &&
      !allowedCiIdentityNames.has(names[0]?.toLowerCase())
    ) {
      errors.push(`managed identity is outside the approved set: ${resourceId}`);
    } else if (
      resourceGroup === 'rg-certigo-content' &&
      type?.startsWith('microsoft.managedidentity/userassignedidentities') &&
      !allowedContentIdentityNames.has(names[0]?.toLowerCase())
    ) {
      errors.push(`managed identity is outside the approved set: ${resourceId}`);
    } else if (
      resourceGroup === null &&
      type !== null &&
      !allowedSubscriptionTypes.has(type)
    ) {
      errors.push(`subscription resource type is not approved: ${resourceId}`);
    }

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

const isMain =
  process.argv[1] &&
  import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href;

if (isMain) {
  const args = parseArguments(process.argv.slice(2));
  if (!args['--plan'] || !args['--subscription']) {
    throw new Error(
      'Usage: node validate-what-if.mjs --plan <path> --subscription <id>',
    );
  }

  const plan = JSON.parse(fs.readFileSync(args['--plan'], 'utf8'));
  const summary = validateWhatIf(plan, args['--subscription']);
  const markdown =
    `## Least-privilege governance what-if\n\n` +
    `No deployment was executed. No deletes or out-of-scope resources were found.\n\n` +
    `\`\`\`json\n${JSON.stringify(summary, null, 2)}\n\`\`\`\n`;

  process.stdout.write(markdown);
  if (process.env.GITHUB_STEP_SUMMARY) {
    fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, markdown);
  }
}
