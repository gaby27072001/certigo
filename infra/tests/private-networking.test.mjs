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
    (subnet) => subnet.name === 'snet-functions',
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
    (subnet) => subnet.name === 'snet-private-endpoints',
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

test('deployment packages expire through a bounded prefix lifecycle policy', () => {
  const template = compileTemplate('infra/modules/storage.bicep');
  const [policy] = resourcesOfType(
    template,
    'Microsoft.Storage/storageAccounts/managementPolicies',
  );
  const [rule] = policy.properties.policy.rules;
  assert.equal(rule.enabled, true);
  assert.equal(rule.type, 'Lifecycle');
  assert.deepEqual(rule.definition.filters.prefixMatch, [
    'app-package/deployments/',
  ]);
  assert.deepEqual(rule.definition.filters.blobTypes, ['blockBlob']);
  assert.equal(
    rule.definition.actions.baseBlob.delete.daysAfterModificationGreaterThan,
    30,
  );
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
  const prefixes = ['10.60.0.0/24', '10.61.0.0/24', '10.62.0.0/24'];
  for (const [index, environment] of ['dev', 'staging', 'prod'].entries()) {
    const parameters = readFileSync(
      path.join(repositoryRoot, 'infra', 'params', `${environment}.bicepparam`),
      'utf8',
    );
    assert.match(parameters, new RegExp(`vnetAddressPrefix = '${prefixes[index]}'`));
    assert.doesNotMatch(parameters, /10\.42\./);
  }
});
