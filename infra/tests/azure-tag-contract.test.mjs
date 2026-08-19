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
const expectedRequiredTags = {
  owner: 'certigo-platform',
  product: 'Certigo',
  env: 'ci',
  managedBy: 'bicep',
  costCenter: 'engineering',
};
const requiredTagKeys = Object.keys(expectedRequiredTags);
const tagParameterNames = {
  owner: 'tagOwner',
  product: 'tagProduct',
  env: 'tagEnvironment',
  managedBy: 'tagManagedBy',
  costCenter: 'tagCostCenter',
};
const taggableResourceTypes = new Set([
  'Microsoft.Compute/virtualMachines',
  'Microsoft.Network/natGateways',
  'Microsoft.Network/networkInterfaces',
  'Microsoft.Network/networkSecurityGroups',
  'Microsoft.Network/publicIPAddresses',
  'Microsoft.Network/virtualNetworks',
]);
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

function resources(template) {
  return Array.isArray(template.resources)
    ? template.resources
    : Object.values(template.resources);
}

function assertRequiredTags(template) {
  for (const [tagKey, parameterName] of Object.entries(tagParameterNames)) {
    assert.equal(
      template.parameters[parameterName].defaultValue,
      expectedRequiredTags[tagKey],
    );
  }
  assert.equal(template.parameters.tagOwner.minLength, 1);
  assert.equal(template.parameters.tagCostCenter.minLength, 1);
  assert.deepEqual(template.parameters.tagProduct.allowedValues, ['Certigo']);
  assert.deepEqual(template.parameters.tagEnvironment.allowedValues, ['ci']);
  assert.deepEqual(template.parameters.tagManagedBy.allowedValues, ['bicep']);
  assert.deepEqual(Object.keys(template.variables.requiredTags), requiredTagKeys);
  assert.match(
    template.variables.effectiveTags,
    /union\(parameters\('tags'\).+variables\('requiredTags'\)\)/,
  );

  const taggableResources = resources(template).filter(
    (resource) =>
      resource.existing !== true && taggableResourceTypes.has(resource.type),
  );
  assert.ok(taggableResources.length > 0);
  assert.ok(
    taggableResources.every(
      (resource) => resource.tags === "[variables('effectiveTags')]",
    ),
  );
}

test('shared contract defines the five FinOps tags and non-personal CI defaults', () => {
  const contract = JSON.parse(
    readFileSync(
      path.join(repositoryRoot, 'infra', 'shared', 'tag-contract.json'),
      'utf8',
    ),
  );

  assert.deepEqual(contract.requiredTagKeys, requiredTagKeys);
  assert.deepEqual(contract.defaults.ci, expectedRequiredTags);
  assert.ok(Object.values(contract.defaults.ci).every((value) => value.trim() !== ''));
  assert.ok(Object.values(contract.defaults.ci).every((value) => !value.includes('@')));
  assert.ok(
    Object.values(contract.defaults.ci).every(
      (value) => !contract.placeholderValues.includes(value.toLowerCase()),
    ),
  );
});

test('runner network applies parameterized non-personal tags additively', () => {
  const template = compileTemplate('infra/ci-runner/network.bicep');
  assertRequiredTags(template);

  const publicIp = resources(template).find(
    (resource) => resource.type === 'Microsoft.Network/publicIPAddresses',
  );
  const natGateway = resources(template).find(
    (resource) => resource.type === 'Microsoft.Network/natGateways',
  );
  assert.deepEqual(publicIp.sku, { name: 'Standard', tier: 'Regional' });
  assert.deepEqual(natGateway.sku, { name: 'Standard' });
});

test('runner compute preserves provenance tags under the mandatory contract', () => {
  const template = compileTemplate('infra/ci-runner/runner.bicep');
  assertRequiredTags(template);
  assert.match(template.variables.effectiveTags, /imageVersion/);
  assert.match(template.variables.effectiveTags, /bootstrapSha256/);

  const vm = resources(template).find(
    (resource) => resource.type === 'Microsoft.Compute/virtualMachines',
  );
  assert.equal(vm.properties.hardwareProfile.vmSize, "[parameters('vmSize')]");
  assert.equal(vm.properties.storageProfile.osDisk.deleteOption, 'Delete');
});

test('only directly declared taggable runner resources receive the contract', () => {
  for (const relativePath of [
    'infra/ci-runner/network.bicep',
    'infra/ci-runner/runner.bicep',
  ]) {
    const template = compileTemplate(relativePath);
    for (const resource of resources(template)) {
      if (resource.existing === true || !taggableResourceTypes.has(resource.type)) {
        assert.equal(resource.tags, undefined);
      }
    }
  }
});
