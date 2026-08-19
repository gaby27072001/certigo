import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
  '..',
);
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

function resourcesOfType(template, type) {
  return template.resources.filter((resource) => resource.type === type);
}

test('private network separates Flex integration from private endpoints', () => {
  const template = compileTemplate('infra/modules/privateNetwork.bicep');
  const [vnet] = resourcesOfType(template, 'Microsoft.Network/virtualNetworks');
  assert.ok(vnet);

  const functionSubnet = vnet.properties.subnets.find(
    (subnet) => subnet.name === "[parameters('functionIntegrationSubnetName')]",
  );
  assert.deepEqual(functionSubnet.properties.delegations, [
    {
      name: 'flex-consumption',
      properties: {
        serviceName: 'Microsoft.App/environments',
      },
    },
  ]);

  const privateEndpointSubnet = vnet.properties.subnets.find(
    (subnet) => subnet.name === "[parameters('privateEndpointSubnetName')]",
  );
  assert.equal(
    privateEndpointSubnet.properties.privateEndpointNetworkPolicies,
    'Disabled',
  );
  assert.equal(functionSubnet.properties.privateEndpointNetworkPolicies, undefined);
});

test('private endpoints and DNS cover every backend dependency', () => {
  const template = compileTemplate('infra/modules/sharedPrivateDns.bicep');
  const zones = resourcesOfType(
    template,
    'Microsoft.Network/privateDnsZones',
  ).map((resource) => resource.name);
  assert.deepEqual(zones.sort(), [
    'privatelink.blob.core.windows.net',
    'privatelink.documents.azure.com',
    'privatelink.queue.core.windows.net',
    'privatelink.table.core.windows.net',
    'privatelink.vaultcore.azure.net',
  ]);

  const links = resourcesOfType(
    template,
    'Microsoft.Network/privateDnsZones/virtualNetworkLinks',
  );
  assert.equal(links.length, 5);
  assert.ok(
    links.every(
      (link) =>
        link.properties.registrationEnabled === false &&
        typeof link.properties.virtualNetwork.id === 'string',
    ),
  );
  const ciLinks = links.filter((link) =>
    String(link.name).includes("parameters('ciVnetName')"),
  );
  assert.equal(ciLinks.length, 5);
  const vaultLink = links.find((link) =>
    String(link.name).includes('kv-dnslink'),
  );
  assert.ok(vaultLink);

  const appLinks = resourcesOfType(
    compileTemplate('infra/modules/privateDnsAppLinks.bicep'),
    'Microsoft.Network/privateDnsZones/virtualNetworkLinks',
  );
  assert.equal(appLinks.length, 5);
  assert.ok(
    appLinks.every(
      (link) =>
        link.properties.registrationEnabled === false &&
        link.properties.virtualNetwork.id === "[parameters('appVnetId')]",
    ),
  );

  const endpoints = resourcesOfType(
    compileTemplate('infra/modules/privateNetwork.bicep'),
    'Microsoft.Network/privateEndpoints',
  );
  assert.equal(endpoints.length, 5);
  const groupIds = endpoints
    .flatMap((endpoint) => endpoint.properties.privateLinkServiceConnections)
    .flatMap((connection) => connection.properties.groupIds)
    .sort();
  assert.deepEqual(groupIds, ['Sql', 'blob', 'queue', 'table', 'vault']);
  assert.deepEqual(
    endpoints.map((endpoint) => endpoint.name).sort(),
    [
      "[parameters('cosmosPrivateEndpointName')]",
      "[parameters('keyVaultPrivateEndpointName')]",
      "[parameters('storageBlobPrivateEndpointName')]",
      "[parameters('storageQueuePrivateEndpointName')]",
      "[parameters('storageTablePrivateEndpointName')]",
    ].sort(),
  );

  const zoneGroups = resourcesOfType(
    compileTemplate('infra/modules/privateNetwork.bicep'),
    'Microsoft.Network/privateEndpoints/privateDnsZoneGroups',
  );
  assert.equal(zoneGroups.length, 5);
  assert.ok(
    zoneGroups.every(
      (group) => group.properties.privateDnsZoneConfigs.length === 1,
    ),
  );
  assert.deepEqual(
    zoneGroups.map((group) => group.name).sort(),
    [
      "[format('{0}/{1}', parameters('cosmosPrivateEndpointName'), parameters('cosmosPrivateDnsZoneGroupName'))]",
      "[format('{0}/{1}', parameters('keyVaultPrivateEndpointName'), parameters('keyVaultPrivateDnsZoneGroupName'))]",
      "[format('{0}/{1}', parameters('storageBlobPrivateEndpointName'), parameters('storageBlobPrivateDnsZoneGroupName'))]",
      "[format('{0}/{1}', parameters('storageQueuePrivateEndpointName'), parameters('storageQueuePrivateDnsZoneGroupName'))]",
      "[format('{0}/{1}', parameters('storageTablePrivateEndpointName'), parameters('storageTablePrivateDnsZoneGroupName'))]",
    ].sort(),
  );
});

test('application and CI virtual networks are peered in both directions', () => {
  const appTemplate = compileTemplate('infra/modules/privateNetwork.bicep');
  const [appPeering] = resourcesOfType(
    appTemplate,
    'Microsoft.Network/virtualNetworks/virtualNetworkPeerings',
  );
  assert.ok(appPeering);
  assert.equal(appPeering.properties.allowVirtualNetworkAccess, true);
  assert.equal(appPeering.properties.allowForwardedTraffic, false);
  assert.equal(appPeering.properties.allowGatewayTransit, false);
  assert.equal(appPeering.properties.useRemoteGateways, false);

  const ciTemplate = compileTemplate('infra/modules/ciVnetPeering.bicep');
  const [ciPeering] = resourcesOfType(
    ciTemplate,
    'Microsoft.Network/virtualNetworks/virtualNetworkPeerings',
  );
  assert.ok(ciPeering);
  assert.equal(ciPeering.properties.allowVirtualNetworkAccess, true);
  assert.equal(
    ciPeering.properties.remoteVirtualNetwork.id,
    "[parameters('appVnetId')]",
  );
});

test('OIDC deployment principal receives container blob access and account delegation only', () => {
  const template = compileTemplate('infra/modules/storage.bicep');
  const assignments = resourcesOfType(
    template,
    'Microsoft.Authorization/roleAssignments',
  );
  assert.equal(assignments.length, 2);
  assert.ok(
    assignments.every(
      (assignment) =>
        assignment.properties.principalId ===
          "[parameters('ciDeploymentPrincipalId')]" &&
        assignment.properties.principalType === 'ServicePrincipal',
    ),
  );
  const blobContributor = assignments.find(
    (assignment) =>
      assignment.properties.roleDefinitionId ===
      "[variables('storageBlobDataContributor')]",
  );
  const blobDelegator = assignments.find(
    (assignment) =>
      assignment.properties.roleDefinitionId ===
      "[variables('storageBlobDelegator')]",
  );
  assert.ok(blobContributor);
  assert.match(blobContributor.scope, /blobServices\/containers/);
  assert.match(blobContributor.scope, /app-package/);
  assert.doesNotMatch(blobContributor.scope, /lesson-assets/);
  assert.ok(blobDelegator);
  assert.equal(
    blobDelegator.scope,
    "[resourceId('Microsoft.Storage/storageAccounts', parameters('accountName'))]",
  );
  assert.match(
    template.variables.storageBlobDataContributor,
    /ba92f5b4-2d11-453d-a403-e96b0029c9fe/,
  );
  assert.match(
    template.variables.storageBlobDelegator,
    /db58b8e5-c6ad-4a2a-8342-4190687cbf4a/,
  );

  for (const environment of ['dev', 'staging', 'prod']) {
    const parameters = readFileSync(
      path.join(repositoryRoot, 'infra', 'params', `${environment}.bicepparam`),
      'utf8',
    );
    assert.match(
      parameters,
      /ciDeploymentPrincipalId = '15d2b34a-c0a0-4b5d-8360-b895a8164706'/,
    );
  }
});

test('deployment packages and release bundles expire through bounded lifecycle policies', () => {
  const template = compileTemplate('infra/modules/storage.bicep');
  const [policy] = resourcesOfType(
    template,
    'Microsoft.Storage/storageAccounts/managementPolicies',
  );
  const rules = Object.fromEntries(
    policy.properties.policy.rules.map((rule) => [rule.name, rule]),
  );
  const deploymentRule = rules['delete-expired-deployment-packages'];
  assert.equal(deploymentRule.enabled, true);
  assert.equal(deploymentRule.type, 'Lifecycle');
  assert.deepEqual(deploymentRule.definition.filters.prefixMatch, [
    'app-package/deployments/',
  ]);
  assert.deepEqual(deploymentRule.definition.filters.blobTypes, ['blockBlob']);
  assert.equal(
    deploymentRule.definition.actions.baseBlob.delete.daysAfterModificationGreaterThan,
    30,
  );
  const releaseRule = rules['delete-expired-release-bundles'];
  assert.equal(releaseRule.enabled, true);
  assert.equal(releaseRule.type, 'Lifecycle');
  assert.deepEqual(releaseRule.definition.filters.prefixMatch, [
    'app-package/releases/',
  ]);
  assert.deepEqual(releaseRule.definition.filters.blobTypes, ['blockBlob']);
  assert.equal(
    releaseRule.definition.actions.baseBlob.delete.daysAfterModificationGreaterThan,
    90,
  );
  assert.equal(
    releaseRule.definition.actions.version.delete.daysAfterCreationGreaterThan,
    90,
  );
});

test('storage protections remain compatible with policy-enforced point-in-time restore', () => {
  const template = compileTemplate('infra/main.bicep');
  const parameters = template.resources.storage.properties.parameters;
  assert.equal(parameters.enableVersioning.value, true);
  assert.equal(parameters.blobSoftDeleteDays.value, 30);
  assert.equal(parameters.containerSoftDeleteDays.value, 30);
});

test('policy-constrained services permanently disable public access', () => {
  for (const [file, resourceType] of [
    ['infra/modules/storage.bicep', 'Microsoft.Storage/storageAccounts'],
    ['infra/modules/keyvault.bicep', 'Microsoft.KeyVault/vaults'],
    ['infra/modules/cosmos.bicep', 'Microsoft.DocumentDB/databaseAccounts'],
  ]) {
    const template = compileTemplate(file);
    const [resource] = resourcesOfType(template, resourceType);
    assert.equal(resource.properties.publicNetworkAccess, 'Disabled');
  }
});

test('diagnostic settings adopt the live storage setting names', () => {
  const template = compileTemplate('infra/modules/diagnostics.bicep');
  const settings = resourcesOfType(template, 'Microsoft.Insights/diagnosticSettings');
  const storageSettings = settings.slice(3, 7).map((setting) => setting.name);

  assert.deepEqual(storageSettings, [
    "[parameters('storageDiagnosticSettingName')]",
    "[parameters('blobServiceDiagnosticSettingName')]",
    "[parameters('queueServiceDiagnosticSettingName')]",
    "[parameters('tableServiceDiagnosticSettingName')]",
  ]);

  for (const environment of ['staging', 'prod']) {
    const parameters = readFileSync(
      path.join(repositoryRoot, 'infra', 'params', `${environment}.bicepparam`),
      'utf8',
    );
    assert.match(parameters, /storageDiagnosticSettingName = 'diag-to-log-analytics'/);
  }
});

test('readiness availability alert requires both low-frequency probe locations to fail', () => {
  const template = compileTemplate('infra/modules/diagnostics.bicep');
  const [webTest] = resourcesOfType(template, 'Microsoft.Insights/webtests');
  const [alert] = resourcesOfType(template, 'Microsoft.Insights/metricAlerts');

  assert.equal(webTest.kind, 'standard');
  assert.equal(webTest.properties.Frequency, 300);
  assert.equal(
    webTest.properties.Request.RequestUrl,
    "[format('https://{0}/api/health/ready', parameters('functionAppHostName'))]",
  );
  assert.deepEqual(webTest.properties.Locations, [
    { Id: 'emea-nl-ams-azr' },
    { Id: 'us-va-ash-azr' },
  ]);
  assert.equal(
    alert.properties.criteria['odata.type'],
    'Microsoft.Azure.Monitor.WebtestLocationAvailabilityCriteria',
  );
  assert.equal(alert.properties.criteria.failedLocationCount, 2);
  assert.equal(alert.properties.evaluationFrequency, 'PT5M');
});

test('deployment failure alert is scoped to failed backend operations in its resource group', () => {
  const template = compileTemplate('infra/modules/diagnostics.bicep');
  const [alert] = resourcesOfType(
    template,
    'Microsoft.Insights/activityLogAlerts',
  );
  const condition = alert.properties.condition.allOf;

  assert.deepEqual(condition.slice(0, 3), [
    { field: 'category', equals: 'Administrative' },
    { field: 'status', equals: 'Failed' },
    { field: 'resourceGroup', equals: '[resourceGroup().name]' },
  ]);
  assert.deepEqual(condition[3].anyOf, [
    {
      field: 'operationName',
      equals: 'Microsoft.Resources/deployments/write',
    },
    {
      field: 'operationName',
      equals: 'Microsoft.Web/sites/extensions/write',
    },
  ]);
});

test('staging and production do not commit an alert receiver address', () => {
  for (const environment of ['staging', 'prod']) {
    const parameters = readFileSync(
      path.join(repositoryRoot, 'infra', 'params', `${environment}.bicepparam`),
      'utf8',
    );
    assert.doesNotMatch(parameters, /^\s*param\s+alertEmail\s*=/m);
    assert.match(parameters, /ALERT_EMAIL variable on the/);
  }
});

test('Key Vault purge protection is enabled in every environment', () => {
  const template = compileTemplate('infra/modules/keyvault.bicep');
  const [vault] = resourcesOfType(template, 'Microsoft.KeyVault/vaults');
  assert.equal(vault.properties.enablePurgeProtection, true);
  assert.doesNotMatch(
    readFileSync(path.join(repositoryRoot, '.checkov.yaml'), 'utf8'),
    /CKV_AZURE_(42|110)/,
  );
});

test('Flex app uses the delegated subnet without forcing public egress into it', () => {
  const template = compileTemplate('infra/modules/functionApp.bicep');
  const [site] = resourcesOfType(template, 'Microsoft.Web/sites');
  assert.equal(
    site.properties.virtualNetworkSubnetId,
    "[parameters('functionIntegrationSubnetId')]",
  );
  assert.equal(site.properties.siteConfig.vnetRouteAllEnabled, false);
});

test('Function app settings pass only versioned Key Vault secret URIs after the site', () => {
  const template = compileTemplate('infra/modules/functionApp.bicep');
  const [site] = resourcesOfType(template, 'Microsoft.Web/sites');
  const [settings] = resourcesOfType(template, 'Microsoft.Web/sites/config');
  const accountDeletionParameters = [
    'entraReauthAudience',
    'entraGraphTenantId',
    'entraGraphClientId',
    'entraGraphClientSecretSecretUri',
  ];

  assert.equal(site.properties.siteConfig.appSettings, undefined);
  assert.equal(settings.name, "[format('{0}/{1}', parameters('functionAppName'), 'appsettings')]");
  assert.equal(
    settings.properties.AUTH_JWT_SIGNING_KEY_SECRET_URI,
    "[parameters('authJwtSigningKeySecretUri')]",
  );
  assert.equal(settings.properties.AUTH_JWT_SIGNING_KEY, undefined);
  assert.equal(
    settings.properties.ENTRA_REAUTH_AUDIENCE,
    "[parameters('entraReauthAudience')]",
  );
  assert.equal(
    settings.properties.ENTRA_GRAPH_TENANT_ID,
    "[parameters('entraGraphTenantId')]",
  );
  assert.equal(
    settings.properties.ENTRA_GRAPH_CLIENT_ID,
    "[parameters('entraGraphClientId')]",
  );
  assert.equal(
    settings.properties.ENTRA_GRAPH_CLIENT_SECRET_SECRET_URI,
    "[parameters('entraGraphClientSecretSecretUri')]",
  );
  assert.equal(settings.properties.ENTRA_GRAPH_CLIENT_SECRET, undefined);
  for (const parameter of accountDeletionParameters) {
    assert.equal(template.parameters[parameter].type, 'securestring');
  }
  assert.equal(
    site.properties.keyVaultReferenceIdentity,
    "[resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', format('id-{0}-host', parameters('functionAppName')))]",
  );
  const vaultAccess = resourcesOfType(
    template,
    'Microsoft.Authorization/roleAssignments',
  ).find(
    (assignment) =>
      assignment.scope
        === "[resourceId('Microsoft.KeyVault/vaults', parameters('keyVaultName'))]",
  );
  assert.ok(vaultAccess);
  assert.equal(
    vaultAccess.properties.roleDefinitionId,
    "[variables('keyVaultSecretsUser')]",
  );
  assert.ok(settings.dependsOn.includes("[resourceId('Microsoft.Web/sites', parameters('functionAppName'))]"));
});

test('account deletion identity flows through secure parameters and a versioned Key Vault secret', () => {
  const template = compileTemplate('infra/main.bicep');
  const accountDeletionParameters = {
    entraReauthAudience: 'effectiveEntraReauthAudience',
    entraGraphTenantId: 'effectiveEntraGraphTenantId',
    entraGraphClientId: 'effectiveEntraGraphClientId',
    entraGraphClientSecret: 'effectiveEntraGraphClientSecret',
  };
  for (const parameter of Object.keys(accountDeletionParameters)) {
    assert.equal(template.parameters[parameter].type, 'securestring');
  }
  for (const [parameter, variable] of Object.entries(accountDeletionParameters)) {
    const deployment = parameter === 'entraGraphClientSecret'
      ? template.resources.graphClientSecret
      : template.resources.api;
    const deploymentParameter = parameter === 'entraGraphClientSecret'
      ? 'graphClientSecret'
      : parameter;
    assert.equal(
      deployment.properties.parameters[deploymentParameter].value,
      `[variables('${variable}')]`,
    );
  }
  assert.equal(template.parameters.entraGraphClientSecretSecretUri, undefined);
  assert.equal(
    template.resources.graphClientSecret.condition,
    "[variables('useEntraGraphClientSecret')]",
  );
  assert.match(
    template.resources.api.properties.parameters.entraGraphClientSecretSecretUri.value,
    /reference\('graphClientSecret'\).*'secretUri'/,
  );
  for (const variable of Object.values(accountDeletionParameters)) {
    assert.match(
      template.variables[variable],
      /variables\('hardened'\).*fail\('.*staging and production deployments\.'\).*''\)\]$/,
    );
  }

  for (const environment of ['staging', 'prod']) {
    const parameters = readFileSync(
      path.join(repositoryRoot, 'infra', 'params', `${environment}.bicepparam`),
      'utf8',
    );
    assert.doesNotMatch(
      parameters,
      /^\s*param\s+entra(GraphTenantId|GraphClientId|GraphClientSecret|ReauthAudience)\s*=/m,
    );
  }
});

test('Graph client secret module stores the value only in Key Vault and returns a versioned URI', () => {
  const template = compileTemplate('infra/modules/keyvaultGraphClientSecret.bicep');
  const [secret] = resourcesOfType(template, 'Microsoft.KeyVault/vaults/secrets');

  assert.equal(template.parameters.graphClientSecret.type, 'securestring');
  assert.equal(
    secret.name,
    "[format('{0}/{1}', parameters('keyVaultName'), 'ENTRA-GRAPH-CLIENT-SECRET')]",
  );
  assert.equal(secret.properties.value, "[parameters('graphClientSecret')]");
  assert.match(template.outputs.secretUri.value, /secretUriWithVersion/);
  assert.doesNotMatch(JSON.stringify(template), /ENTRA_GRAPH_CLIENT_SECRET":/);
});

test('Function deployment waits for the complete private network deployment', () => {
  const template = compileTemplate('infra/main.bicep');
  const networkDeployment = template.resources.privateNetwork;
  const functionDeployment = template.resources.api;

  assert.ok(networkDeployment.dependsOn.includes('storage'));
  assert.ok(networkDeployment.dependsOn.includes('vault'));
  assert.ok(networkDeployment.dependsOn.includes('data'));
  assert.ok(networkDeployment.dependsOn.includes('sharedPrivateDns'));
  assert.ok(functionDeployment.dependsOn.includes('privateNetwork'));
  assert.ok(functionDeployment.dependsOn.includes('privateDnsAppLinks'));
  assert.ok(template.resources.privateDnsAppLinks.dependsOn.includes('privateNetwork'));
  assert.ok(template.resources.ciVnetPeering.dependsOn.includes('privateNetwork'));
});

test('environment address spaces are unique and do not overlap the CI runner VNet', () => {
  const prefixes = ['10.60.0.0/24', '10.80.0.0/16', '10.100.0.0/16'];
  for (const [index, environment] of ['dev', 'staging', 'prod'].entries()) {
    const parameters = readFileSync(
      path.join(repositoryRoot, 'infra', 'params', `${environment}.bicepparam`),
      'utf8',
    );
    assert.match(parameters, new RegExp(`vnetAddressPrefix = '${prefixes[index]}'`));
    assert.doesNotMatch(parameters, /10\.42\./);
  }
});

test('environment parameters adopt the live subnets and private endpoints', () => {
  const expected = {
    dev: {
      functionSubnet: 'snet-functions',
      privateEndpointSubnet: 'snet-private-endpoints',
      endpoints: [
        'pep-stcertigodevbk3j5ja6-blob',
        'pep-stcertigodevbk3j5ja6-queue',
        'pep-stcertigodevbk3j5ja6-table',
        'pep-kv-certigo-dev-bk3j5j-vault',
        'pep-cosmos-certigo-dev-bk3j5ja6vw23s-sql',
      ],
      connections: [
        'stcertigodevbk3j5ja6-blob',
        'stcertigodevbk3j5ja6-queue',
        'stcertigodevbk3j5ja6-table',
        'kv-certigo-dev-bk3j5j-vault',
        'cosmos-certigo-dev-bk3j5ja6vw23s-sql',
      ],
      zoneGroups: [],
    },
    staging: {
      functionSubnet: 'snet-func-flex',
      privateEndpointSubnet: 'snet-kv-private-endpoint',
      endpoints: [
        'pe-st-certigo-staging-blob',
        'pe-st-certigo-staging-queue',
        'pe-st-certigo-staging-table',
        'pe-kv-certigo-staging',
        'pe-cosmos-certigo-staging',
      ],
      connections: [
        'conn-pe-st-certigo-staging-blob',
        'conn-pe-st-certigo-staging-queue',
        'pe-st-certigo-staging-table-conn',
        'conn-pe-kv-certigo-staging',
        'conn-pe-cosmos-certigo-staging',
      ],
      zoneGroups: [
        'pdzg-st-certigo-staging-blob',
        'pdzg-kv-certigo-staging',
      ],
    },
    prod: {
      functionSubnet: 'snet-func-flex',
      privateEndpointSubnet: 'snet-private-endpoints',
      endpoints: [
        'pe-st-certigo-prod-blob',
        'pe-st-certigo-prod-queue',
        'pe-st-certigo-prod-table',
        'pe-kv-certigo-prod',
        'pe-cosmos-certigo-prod-sql',
      ],
      connections: [
        'pe-st-certigo-prod-blob-conn',
        'pe-st-certigo-prod-queue-conn',
        'pe-st-certigo-prod-table-conn',
        'pe-kv-certigo-prod-conn',
        'pe-cosmos-certigo-prod-sql-conn',
      ],
      zoneGroups: [],
    },
  };

  for (const [environment, values] of Object.entries(expected)) {
    const parameters = readFileSync(
      path.join(repositoryRoot, 'infra', 'params', `${environment}.bicepparam`),
      'utf8',
    );
    assert.match(
      parameters,
      new RegExp(`functionIntegrationSubnetName = '${values.functionSubnet}'`),
    );
    assert.match(
      parameters,
      new RegExp(`privateEndpointSubnetName = '${values.privateEndpointSubnet}'`),
    );
    for (const endpoint of values.endpoints) {
      assert.ok(parameters.includes(`= '${endpoint}'`));
    }
    for (const connection of values.connections) {
      assert.ok(parameters.includes(`= '${connection}'`));
    }
    for (const zoneGroup of values.zoneGroups) {
      assert.ok(parameters.includes(`= '${zoneGroup}'`));
    }
  }
});
