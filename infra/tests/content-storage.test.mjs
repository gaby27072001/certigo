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
const compiledTemplates = new Map();

function compileTemplate(relativePath) {
  if (compiledTemplates.has(relativePath)) {
    return compiledTemplates.get(relativePath);
  }
  const bicep = process.env.BICEP_CLI || 'bicep';
  const template = JSON.parse(
    execFileSync(
      bicep,
      ['build', path.join(repositoryRoot, relativePath), '--stdout'],
      { encoding: 'utf8' },
    ),
  );
  compiledTemplates.set(relativePath, template);
  return template;
}

function resourcesOfType(template, type) {
  return template.resources.filter((resource) => resource.type === type);
}

test('content storage matches the single-endpoint runtime contract', () => {
  const template = compileTemplate('infra/modules/contentStorage.bicep');
  const [account] = resourcesOfType(
    template,
    'Microsoft.Storage/storageAccounts',
  );
  assert.equal(account.properties.allowBlobPublicAccess, false);
  assert.equal(account.properties.allowSharedKeyAccess, false);
  assert.equal(account.properties.defaultToOAuthAuthentication, true);
  assert.equal(account.properties.minimumTlsVersion, 'TLS1_2');
  assert.equal(account.properties.publicNetworkAccess, 'Disabled');
  assert.equal(account.properties.networkAcls.defaultAction, 'Deny');
  assert.equal(account.properties.networkAcls.bypass, 'AzureServices');
  assert.equal(account.properties.encryption.requireInfrastructureEncryption, true);

  const [blobService] = resourcesOfType(
    template,
    'Microsoft.Storage/storageAccounts/blobServices',
  );
  assert.equal(blobService.properties.isVersioningEnabled, true);
  assert.equal(blobService.properties.deleteRetentionPolicy.enabled, true);
  assert.equal(blobService.properties.containerDeleteRetentionPolicy.enabled, true);

  const containers = resourcesOfType(
    template,
    'Microsoft.Storage/storageAccounts/blobServices/containers',
  );
  assert.equal(containers.length, 3);
  assert.deepEqual(
    containers.map((container) => container.name).sort(),
    [
      "[format('{0}/{1}/{2}', parameters('accountName'), 'default', parameters('descriptorContainerName'))]",
      "[format('{0}/{1}/{2}', parameters('accountName'), 'default', parameters('privateContainerName'))]",
      "[format('{0}/{1}/{2}', parameters('accountName'), 'default', parameters('publicContainerName'))]",
    ].sort(),
  );
  assert.ok(
    containers.every(
      (container) =>
        container.properties.publicAccess === 'None' &&
        container.properties.denyEncryptionScopeOverride === true &&
        container.properties.immutableStorageWithVersioning.enabled === true,
    ),
  );
});

test('all three containers have unlocked WORM defaults and no lifecycle deletion', () => {
  const template = compileTemplate('infra/modules/contentStorage.bicep');
  const policies = resourcesOfType(
    template,
    'Microsoft.Storage/storageAccounts/blobServices/containers/immutabilityPolicies',
  );
  assert.equal(policies.length, 3);
  assert.ok(
    policies.every(
      (policy) =>
        policy.properties.allowProtectedAppendWrites === false &&
        policy.properties.allowProtectedAppendWritesAll === false,
    ),
  );

  const [lifecycle] = resourcesOfType(
    template,
    'Microsoft.Storage/storageAccounts/managementPolicies',
  );
  const prefixes = lifecycle.properties.policy.rules.flatMap(
    (rule) => rule.definition.filters.prefixMatch,
  );
  assert.deepEqual(prefixes.sort(), [
    "[format('{0}/manifests/', parameters('privateContainerName'))]",
    "[format('{0}/manifests/', parameters('publicContainerName'))]",
    "[format('{0}/releases/', parameters('descriptorContainerName'))]",
  ].sort());
  assert.ok(
    lifecycle.properties.policy.rules.every(
      (rule) => rule.definition.actions.baseBlob.delete === undefined,
    ),
  );
});

test('publishers are isolated and the runtime reader is read-only on every container', () => {
  const template = compileTemplate('infra/modules/contentStorage.bicep');
  const assignments = resourcesOfType(
    template,
    'Microsoft.Authorization/roleAssignments',
  );
  assert.equal(assignments.length, 6);

  const publisherAssignments = assignments.filter(
    (assignment) =>
      assignment.properties.roleDefinitionId ===
      "[parameters('publisherRoleDefinitionId')]",
  );
  assert.equal(publisherAssignments.length, 3);
  assert.deepEqual(
    publisherAssignments
      .map((assignment) => assignment.properties.principalId)
      .sort(),
    [
      "[parameters('descriptorPublisherPrincipalId')]",
      "[parameters('privatePublisherPrincipalId')]",
      "[parameters('publicPublisherPrincipalId')]",
    ].sort(),
  );

  const readerAssignments = assignments.filter(
    (assignment) =>
      assignment.properties.roleDefinitionId ===
      "[parameters('readerRoleDefinitionId')]",
  );
  assert.equal(readerAssignments.length, 3);
  assert.ok(
    readerAssignments.every(
      (assignment) =>
        assignment.properties.principalId ===
        "[parameters('readerPrincipalId')]",
    ),
  );
  assert.ok(
    assignments.every(
      (assignment) =>
        assignment.scope.includes(
          'Microsoft.Storage/storageAccounts/blobServices/containers',
        ) &&
        assignment.properties.principalType === 'ServicePrincipal',
    ),
  );
});

test('custom publisher role grants metadata reads without data-plane access', () => {
  const template = compileTemplate(
    'infra/governance/bootstrap-identities.bicep',
  );
  const [role] = resourcesOfType(
    template,
    'Microsoft.Authorization/roleDefinitions',
  ).filter(
    (definition) =>
      definition.name === 'c8a9d1bb-39d7-4f4f-9a4c-17b4c81aa5de',
  );
  assert.equal(
    role.name,
    'c8a9d1bb-39d7-4f4f-9a4c-17b4c81aa5de',
  );
  const [permissions] = role.properties.permissions;
  assert.deepEqual(permissions.actions.sort(), [
    'Microsoft.Storage/storageAccounts/blobServices/containers/immutabilityPolicies/read',
    'Microsoft.Storage/storageAccounts/blobServices/containers/read',
  ]);
  assert.deepEqual(permissions.dataActions, []);
  assert.deepEqual(permissions.notActions, []);
  assert.deepEqual(permissions.notDataActions, []);
  assert.ok(
    [...permissions.actions, ...permissions.dataActions].every(
      (action) =>
        !action.toLowerCase().includes('delete') &&
        !action.toLowerCase().includes('immutabilitypolicies/write'),
    ),
  );
});

test('outputs map exactly to PR 304 runtime settings and current publisher channels', () => {
  const template = compileTemplate('infra/content/main.bicep');
  const defaults = Object.fromEntries(
    Object.entries(template.parameters)
      .filter(([, parameter]) => 'defaultValue' in parameter)
      .map(([name, parameter]) => [name, parameter.defaultValue]),
  );
  assert.deepEqual(
    {
      descriptorContainerName: defaults.descriptorContainerName,
      privateContainerName: defaults.privateContainerName,
      publicContainerName: defaults.publicContainerName,
      storageSkuName: defaults.storageSkuName,
    },
    {
      descriptorContainerName: 'content-release-descriptors',
      privateContainerName: 'content-private-releases',
      publicContainerName: 'content-public-releases',
      storageSkuName: 'Standard_GRS',
    },
  );

  for (const output of [
    'azureBlobEndpoint',
    'azureContentReaderClientId',
    'azureContentReaderPrincipalId',
    'azureContentReaderResourceId',
    'azureDescriptorContainer',
    'azurePrivateContainer',
    'azurePublicContainer',
    'azureStorageAccount',
    'contentAllowMutableBlobsDefault',
    'contentRepositoryModeDefault',
  ]) {
    assert.ok(template.outputs[output], `missing runtime output ${output}`);
  }
  assert.equal(template.outputs.contentRepositoryModeDefault.value, 'legacy');
  assert.equal(template.outputs.contentAllowMutableBlobsDefault.value, 'false');

  for (const output of [
    'azureDescriptorEnvironment',
    'azureDescriptorPublisherClientId',
    'azureDescriptorStorageTarget',
    'azurePrivateEnvironment',
    'azurePrivatePublisherClientId',
    'azurePrivateStorageTarget',
    'azurePublicEnvironment',
    'azurePublicPublisherClientId',
    'azurePublicStorageTarget',
    'azureResourceGroup',
    'azureSubscriptionId',
    'azureTenantId',
  ]) {
    assert.ok(template.outputs[output], `missing publisher output ${output}`);
  }
});

test('dedicated stack creates support identities but no application runtime', () => {
  const template = compileTemplate('infra/content/main.bicep');
  assert.deepEqual(
    template.resources.map(({ type, name }) => `${type}:${name}`).sort(),
    [
      'Microsoft.Resources/deployments:content-private-endpoint',
      'Microsoft.Resources/deployments:content-storage',
    ].sort(),
  );
  assert.equal(
    template.parameters.contentPublisherRoleDefinitionGuid.defaultValue,
    'c8a9d1bb-39d7-4f4f-9a4c-17b4c81aa5de',
  );
  assert.ok(
    template.$schema.includes('/deploymentTemplate.json#'),
    'content deployment must target an existing resource group',
  );
});

test('publisher identities have exact OIDC subjects and reader has no federation', () => {
  const template = compileTemplate(
    'infra/governance/bootstrap-identities.bicep',
  );
  assert.equal(
    template.variables.descriptorEnvironmentName,
    'azure-content-release',
  );
  assert.equal(template.variables.publicEnvironmentName, 'azure-content-public');
  assert.equal(
    template.variables.privateEnvironmentName,
    'azure-content-answer-key',
  );

  const identityTemplate = compileTemplate('infra/modules/contentIdentity.bicep');
  const [credential] = resourcesOfType(
    identityTemplate,
    'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials',
  );
  assert.equal(
    credential.properties.issuer,
    'https://token.actions.githubusercontent.com',
  );
  assert.deepEqual(credential.properties.audiences, [
    'api://AzureADTokenExchange',
  ]);
  assert.match(credential.properties.subject, /environment:\{2\}'/);

  const readerTemplate = compileTemplate(
    'infra/modules/contentReaderIdentity.bicep',
  );
  assert.equal(
    resourcesOfType(
      readerTemplate,
      'Microsoft.ManagedIdentity/userAssignedIdentities',
    ).length,
    1,
  );
  assert.equal(
    resourcesOfType(
      readerTemplate,
      'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials',
    ).length,
    0,
  );

  const identityDeployments = resourcesOfType(
    template,
    'Microsoft.Resources/deployments',
  );
  assert.equal(identityDeployments.length, 6);
  assert.ok(
    identityDeployments.every(
      (deployment) =>
        deployment.resourceGroup === "[parameters('identityResourceGroupName')]",
    ),
  );
  const publisherDeployments = identityDeployments.filter((deployment) =>
    [
      'content-release-publisher-identity',
      'content-public-publisher-identity',
      'content-private-publisher-identity',
    ].includes(deployment.name),
  );
  assert.deepEqual(
    publisherDeployments.map((deployment) => ({
      environment:
        deployment.properties.parameters.githubEnvironmentName.value,
      repository:
        `${deployment.properties.parameters.githubRepositoryOwner.value}/` +
        deployment.properties.parameters.githubRepositoryName.value,
    })),
    [
      {
        environment: "[variables('descriptorEnvironmentName')]",
        repository:
          "[parameters('contentRepositoryOwner')]/" +
          "[parameters('contentRepositoryName')]",
      },
      {
        environment: "[variables('publicEnvironmentName')]",
        repository:
          "[parameters('contentRepositoryOwner')]/" +
          "[parameters('contentRepositoryName')]",
      },
      {
        environment: "[variables('privateEnvironmentName')]",
        repository:
          "[parameters('contentRepositoryOwner')]/" +
          "[parameters('contentRepositoryName')]",
      },
    ],
  );
  const readerDeployment = identityDeployments.find(
    ({ name }) => name === 'content-reader-identity',
  );
  assert.ok(readerDeployment);
  assert.equal(
    readerDeployment.properties.parameters.githubEnvironmentName,
    undefined,
  );
  assert.equal(
    resourcesOfType(template, 'Microsoft.Resources/resourceGroups').find(
      ({ name }) => name === "[parameters('contentResourceGroupName')]",
    ).name,
    "[parameters('contentResourceGroupName')]",
  );
});

test('one account-level private endpoint uses the trusted CI subnet and shared DNS', () => {
  const template = compileTemplate(
    'infra/modules/contentPrivateEndpoints.bicep',
  );
  const [endpoint] = resourcesOfType(
    template,
    'Microsoft.Network/privateEndpoints',
  );
  assert.equal(
    endpoint.properties.subnet.id,
    "[parameters('ciRunnerSubnetId')]",
  );
  assert.deepEqual(
    endpoint.properties.privateLinkServiceConnections[0].properties.groupIds,
    ['blob'],
  );
  assert.equal(
    endpoint.properties.privateLinkServiceConnections[0].properties
      .privateLinkServiceId,
    "[parameters('storageAccountId')]",
  );

  const [zoneGroup] = resourcesOfType(
    template,
    'Microsoft.Network/privateEndpoints/privateDnsZoneGroups',
  );
  assert.equal(
    zoneGroup.properties.privateDnsZoneConfigs[0].properties.privateDnsZoneId,
    "[parameters('blobPrivateDnsZoneId')]",
  );
});

test('what-if workflow evaluates current main and cannot deploy', () => {
  const workflow = readFileSync(
    path.join(repositoryRoot, '.github/workflows/content-infra-what-if.yml'),
    'utf8',
  );
  assert.doesNotMatch(workflow, /workflow_dispatch:/);
  assert.match(workflow, /ref: refs\/heads\/main/);
  assert.match(workflow, /az deployment group what-if/);
  assert.match(workflow, /--resource-group rg-certigo-content/);
  assert.doesNotMatch(workflow, /az deployment sub what-if/);
  assert.doesNotMatch(workflow, /az deployment (?:sub|group) (?:create|validate)/);
  assert.doesNotMatch(workflow, /\bsecrets\./);
  assert.match(workflow, /environment: azure-content-infra-plan/);
  assert.match(workflow, /outsideAllowedScope/);
  assert.doesNotMatch(workflow, /roledefinitions/i);
  assert.match(workflow, /!normalized\.startsWith\(`\$\{contentScope\}\//);
  assert.match(workflow, /Delete/);
  assert.match(workflow, /Resource ID/);
});

test('runtime consumes the official external storage outputs without provisioning a duplicate', () => {
  const main = compileTemplate('infra/main.bicep');
  assert.equal(main.resources.contentStorage, undefined);
  assert.equal(main.parameters.contentBlobEndpoint.defaultValue, '');
  assert.equal(main.parameters.contentReaderClientId.defaultValue, '');
  assert.equal(main.parameters.contentReaderResourceId.defaultValue, '');
  assert.equal(
    main.parameters.contentDescriptorContainerName.defaultValue,
    'content-release-descriptors',
  );
  assert.equal(
    main.parameters.contentPublicContainerName.defaultValue,
    'content-public-releases',
  );
  assert.equal(
    main.parameters.contentPrivateContainerName.defaultValue,
    'content-private-releases',
  );

  const apiParameters = main.resources.api.properties.parameters;
  assert.equal(
    apiParameters.contentBlobEndpoint.value,
    "[variables('effectiveContentBlobEndpoint')]",
  );
  assert.equal(
    apiParameters.contentReaderClientId.value,
    "[parameters('contentReaderClientId')]",
  );
  assert.equal(
    apiParameters.contentReaderResourceId.value,
    "[parameters('contentReaderResourceId')]",
  );
});

test('application Function attaches only the external reader UAMI and creates no content RBAC', () => {
  const template = compileTemplate('infra/modules/functionApp.bicep');
  const identities = resourcesOfType(
    template,
    'Microsoft.ManagedIdentity/userAssignedIdentities',
  );
  assert.equal(identities.length, 1);
  assert.doesNotMatch(identities[0].name, /content-reader/);

  const assignments = resourcesOfType(
    template,
    'Microsoft.Authorization/roleAssignments',
  );
  assert.ok(
    assignments.every(
      (assignment) =>
        !String(assignment.scope).includes(
          'Microsoft.Storage/storageAccounts/blobServices/containers',
        ),
    ),
  );

  const [app] = resourcesOfType(template, 'Microsoft.Web/sites');
  assert.match(
    JSON.stringify(app.identity.userAssignedIdentities),
    /contentReaderIdentityAssignment/,
  );
  assert.match(
    JSON.stringify(template.variables.contentReaderIdentityAssignment),
    /contentReaderResourceId/,
  );

  const [settings] = resourcesOfType(template, 'Microsoft.Web/sites/config');
  const contentSettings = template.variables.contentRuntimeSettings;
  assert.match(
    contentSettings,
    /if\(empty\(parameters\('contentBlobEndpoint'\)\), createObject\(\),/,
  );
  assert.match(contentSettings, /'CONTENT_BLOB_ENDPOINT', parameters\('contentBlobEndpoint'\)/);
  assert.match(contentSettings, /'CONTENT_STORAGE_CLIENT_ID', parameters\('contentReaderClientId'\)/);
  assert.match(settings.properties, /variables\('contentRuntimeSettings'\)/);
  assert.match(
    settings.properties,
    /'CONTENT_REPOSITORY_MODE', parameters\('contentRepositoryMode'\)/,
  );
  assert.match(settings.properties, /'CONTENT_ALLOW_MUTABLE_BLOBS', 'false'/);
  assert.match(settings.properties, /'CONTENT_ADMIN_ROLE', 'Content\.Release\.Admin'/);
  const program = readFileSync(
    path.join(
      repositoryRoot,
      'backend',
      'src',
      'Certigo.Api',
      'Program.cs',
    ),
    'utf8',
  );
  assert.match(program, /string\.IsNullOrWhiteSpace\(endpoint\)/);
  assert.doesNotMatch(
    program,
    /ContentBlobEndpoint\]\s*\?\?\s*configuration\["BLOB_ENDPOINT"\]/,
  );
});

test('release descriptor path remains compatible with the official release.json contract', () => {
  const source = path.join(
    repositoryRoot,
    'backend',
    'src',
    'Certigo.Infrastructure',
    'Blob',
    'BlobContentReleaseSource.cs',
  );
  const contents = readFileSync(source, 'utf8');
  assert.match(contents, /releases\/\{releaseId\}\/release\.json/);
});

test('all committed environments stay legacy and immutable', () => {
  const main = compileTemplate('infra/main.bicep');
  assert.equal(main.parameters.contentRepositoryMode.defaultValue, 'legacy');
  for (const environment of ['dev', 'staging', 'prod']) {
    const parameters = readFileSync(
      path.join(repositoryRoot, 'infra', 'params', `${environment}.bicepparam`),
      'utf8',
    );
    assert.doesNotMatch(parameters, /param contentRepositoryMode\s*=/);
    assert.doesNotMatch(parameters, /CONTENT_ALLOW_MUTABLE_BLOBS/);
  }

  const localSettings = JSON.parse(
    readFileSync(
      path.join(
        repositoryRoot,
        'backend',
        'src',
        'Certigo.Api',
        'local.settings.json.example',
      ),
      'utf8',
    ),
  );
  assert.equal(localSettings.Values.CONTENT_REPOSITORY_MODE, 'legacy');
  assert.equal(localSettings.Values.CONTENT_ALLOW_MUTABLE_BLOBS, 'false');
});
