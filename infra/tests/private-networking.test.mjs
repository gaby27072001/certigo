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
  const template = compileTemplate('infra/modules/privateNetwork.bicep');
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

  const endpoints = resourcesOfType(
    template,
    'Microsoft.Network/privateEndpoints',
  );
  assert.equal(endpoints.length, 5);
  const groupIds = endpoints
    .flatMap((endpoint) => endpoint.properties.privateLinkServiceConnections)
    .flatMap((connection) => connection.properties.groupIds)
    .sort();
  assert.deepEqual(groupIds, ['Sql', 'blob', 'queue', 'table', 'vault']);

  const zoneGroups = resourcesOfType(
    template,
    'Microsoft.Network/privateEndpoints/privateDnsZoneGroups',
  );
  assert.equal(zoneGroups.length, 5);
  assert.ok(
    zoneGroups.every(
      (group) => group.properties.privateDnsZoneConfigs.length === 1,
    ),
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
  assert.ok(functionDeployment.dependsOn.includes('privateNetwork'));
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
