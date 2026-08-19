import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
  '..',
);

function compile(relativePath) {
  const bicep = process.env.BICEP_CLI || 'bicep';
  return JSON.parse(
    execFileSync(
      bicep,
      ['build', path.join(repositoryRoot, relativePath), '--stdout'],
      { encoding: 'utf8' },
    ),
  );
}

function resourcesOfType(template, type) {
  return template.resources.filter((resource) => resource.type === type);
}

test('content storage is private, keyless, versioned and WORM-enabled', () => {
  const template = compile('infra/modules/contentStorage.bicep');
  const [account] = resourcesOfType(template, 'Microsoft.Storage/storageAccounts');
  assert.equal(account.properties.allowBlobPublicAccess, false);
  assert.equal(account.properties.allowSharedKeyAccess, false);
  assert.equal(account.properties.publicNetworkAccess, 'Disabled');

  const [blob] = resourcesOfType(
    template,
    'Microsoft.Storage/storageAccounts/blobServices',
  );
  assert.equal(blob.properties.isVersioningEnabled, true);

  const containers = resourcesOfType(
    template,
    'Microsoft.Storage/storageAccounts/blobServices/containers',
  );
  assert.deepEqual(
    containers.map((container) => container.name).sort(),
    [
      "[format('{0}/{1}/{2}', parameters('accountName'), 'default', 'content-private-releases')]",
      "[format('{0}/{1}/{2}', parameters('accountName'), 'default', 'content-public-releases')]",
      "[format('{0}/{1}/{2}', parameters('accountName'), 'default', 'content-release-descriptors')]",
    ].sort(),
  );
  assert.ok(
    containers.every(
      (container) =>
        container.properties.publicAccess === 'None' &&
        container.properties.immutableStorageWithVersioning.enabled === true,
    ),
  );
  assert.equal(
    resourcesOfType(
      template,
      'Microsoft.Storage/storageAccounts/managementPolicies',
    ).length,
    0,
  );
});

test('function content identity receives container-scoped read-only access', () => {
  const template = compile('infra/modules/functionApp.bicep');
  const assignments = resourcesOfType(
    template,
    'Microsoft.Authorization/roleAssignments',
  ).filter(
    (assignment) =>
      assignment.properties.roleDefinitionId ===
      "[variables('storageBlobDataReader')]",
  );
  assert.equal(assignments.length, 3);
  assert.ok(
    assignments.every(
      (assignment) =>
        assignment.properties.principalId ===
          "[reference(resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', format('id-{0}-content-reader', parameters('functionAppName'))), '2023-01-31').principalId]" &&
        assignment.scope.includes(
          "Microsoft.Storage/storageAccounts/blobServices/containers",
        ),
    ),
  );

  const [settings] = resourcesOfType(template, 'Microsoft.Web/sites/config');
  assert.equal(settings.properties.CONTENT_REPOSITORY_MODE, "[parameters('contentRepositoryMode')]");
  assert.equal(settings.properties.CONTENT_ALLOW_MUTABLE_BLOBS, 'false');
  assert.equal(settings.properties.CONTENT_ADMIN_ROLE, 'Content.Release.Admin');
});

test('main derives a content storage suffix within the 24-character Azure limit', () => {
  const template = compile('infra/main.bicep');
  assert.equal(
    template.variables.contentStorageSuffixLen,
    "[min(8, sub(24, length(format('stc{0}{1}', parameters('appName'), parameters('env')))))]",
  );
  assert.equal(
    template.resources.contentStorage.properties.parameters.accountName.value,
    "[toLower(format('stc{0}{1}{2}', parameters('appName'), parameters('env'), take(variables('suffix'), variables('contentStorageSuffixLen'))))]",
  );
});
