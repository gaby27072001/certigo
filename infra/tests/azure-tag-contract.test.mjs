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
const contract = JSON.parse(
  readFileSync(
    path.join(repositoryRoot, 'infra', 'finops', 'scopes.json'),
    'utf8',
  ),
);
const expectedRunnerTags = {
  owner: 'certigo-platform',
  product: 'Certigo',
  env: 'ci',
  managedBy: 'bicep',
  costCenter: 'engineering',
};
const requiredTagKeys = contract.requiredTagKeys;
const placeholderValues = new Set(['n/a', 'none', 'tbd', 'unknown']);
const runnerTagParameterNames = {
  owner: 'tagOwner',
  product: 'tagProduct',
  env: 'tagEnvironment',
  managedBy: 'tagManagedBy',
  costCenter: 'tagCostCenter',
};
const applicationTagParameterNames = {
  owner: 'tagOwner',
  product: 'tagProduct',
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

function assertRunnerRequiredTags(template) {
  for (const [tagKey, parameterName] of Object.entries(runnerTagParameterNames)) {
    assert.equal(
      template.parameters[parameterName].defaultValue,
      expectedRunnerTags[tagKey],
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

test('runner defaults implement the canonical FinOps contract without personal values', () => {
  assert.deepEqual(Object.keys(expectedRunnerTags), requiredTagKeys);
  assert.ok(contract.scopes.some((scope) => scope.environment === 'ci'));
  assert.ok(
    Object.values(expectedRunnerTags).every((value) => value.trim() !== ''),
  );
  assert.ok(
    Object.values(expectedRunnerTags).every(
      (value) => !value.includes('@') && !placeholderValues.has(value.toLowerCase()),
    ),
  );
});

test('runner network applies parameterized non-personal tags additively', () => {
  const template = compileTemplate('infra/ci-runner/network.bicep');
  assertRunnerRequiredTags(template);

  const publicIp = resources(template).find(
    (resource) => resource.type === 'Microsoft.Network/publicIPAddresses',
  );
  const natGateway = resources(template).find(
    (resource) => resource.type === 'Microsoft.Network/natGateways',
  );
  assert.equal(publicIp.name, "[parameters('publicIpName')]");
  assert.equal(natGateway.name, "[parameters('natGatewayName')]");
  assert.deepEqual(publicIp.sku, { name: 'Standard', tier: 'Regional' });
  assert.deepEqual(natGateway.sku, { name: 'Standard' });
});

test('runner compute preserves provenance tags under the mandatory contract', () => {
  const template = compileTemplate('infra/ci-runner/runner.bicep');
  assertRunnerRequiredTags(template);
  assert.match(template.variables.effectiveTags, /imageVersion/);
  assert.match(template.variables.effectiveTags, /bootstrapSha256/);

  const nic = resources(template).find(
    (resource) => resource.type === 'Microsoft.Network/networkInterfaces',
  );
  const vm = resources(template).find(
    (resource) => resource.type === 'Microsoft.Compute/virtualMachines',
  );
  assert.equal(nic.name, "[format('{0}-nic', parameters('runnerName'))]");
  assert.equal(vm.name, "[parameters('runnerName')]");
  assert.equal(vm.properties.hardwareProfile.vmSize, "[parameters('vmSize')]");
  assert.equal(vm.properties.storageProfile.osDisk.deleteOption, 'Delete');
});

test('application composition applies the canonical contract additively by scope', () => {
  const template = compileTemplate('infra/main.bicep');
  const applicationEnvironments = contract.scopes
    .map((scope) => scope.environment)
    .filter((environment) => environment !== 'ci')
    .sort();

  for (const [tagKey, parameterName] of Object.entries(
    applicationTagParameterNames,
  )) {
    assert.equal(
      template.parameters[parameterName].defaultValue,
      expectedRunnerTags[tagKey],
    );
  }
  assert.deepEqual(
    [...template.parameters.env.allowedValues].sort(),
    applicationEnvironments,
  );
  assert.equal(template.parameters.tagOwner.minLength, 1);
  assert.equal(template.parameters.tagCostCenter.minLength, 1);
  assert.deepEqual(template.parameters.tagProduct.allowedValues, ['Certigo']);
  assert.deepEqual(template.parameters.tagManagedBy.allowedValues, ['bicep']);
  assert.deepEqual(Object.keys(template.variables.requiredTags), requiredTagKeys);
  assert.equal(template.variables.requiredTags.env, "[parameters('env')]");
  assert.equal(
    template.variables.effectiveTags,
    "[union(parameters('tags'), variables('requiredTags'))]",
  );
  assert.equal(
    template.variables.ciTags,
    "[union(variables('effectiveTags'), createObject('env', 'ci'))]",
  );

  const deployments = resources(template).filter(
    (resource) => resource.type === 'Microsoft.Resources/deployments',
  );
  const tagValues = deployments
    .map((deployment) => deployment.properties.parameters.tags?.value)
    .filter((value) => value !== undefined);
  assert.ok(tagValues.length > 0);
  assert.ok(tagValues.includes("[variables('effectiveTags')]"));
  assert.ok(tagValues.includes("[variables('ciTags')]"));
  assert.ok(
    tagValues.includes(
      "[union(variables('ciTags'), createObject('scope', 'shared'))]",
    ),
  );
  assert.ok(
    tagValues.every(
      (value) =>
        value === "[variables('effectiveTags')]" ||
        value === "[variables('ciTags')]" ||
        value ===
          "[union(variables('ciTags'), createObject('scope', 'shared'))]",
    ),
  );

  for (const deploymentName of [
    'ciMobileSecretsAccess',
    'defender',
    'policy',
  ]) {
    const deployment = deployments.find(
      (resource) => resource.name === deploymentName,
    );
    assert.ok(deployment);
    assert.equal(deployment.properties.parameters.tags, undefined);
  }
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
