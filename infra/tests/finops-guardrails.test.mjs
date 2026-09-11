import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { validateInventory } from '../finops/verify-tags.mjs';

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
  '..',
);

function compileTemplate(relativePath) {
  const bicep = process.env.BICEP_CLI || 'bicep';
  return JSON.parse(
    execFileSync(
      bicep,
      ['build', path.join(repositoryRoot, relativePath), '--stdout'],
      { encoding: 'utf8' },
    ),
  );
}

function compileParameters(relativePath) {
  const bicep = process.env.BICEP_CLI || 'bicep';
  const output = JSON.parse(
    execFileSync(
      bicep,
      ['build-params', path.join(repositoryRoot, relativePath), '--stdout'],
      { encoding: 'utf8' },
    ),
  );
  return JSON.parse(output.parametersJson);
}

test('monthly budget alerts on forecast acceleration and on a confirmed overrun', () => {
  const template = compileTemplate('infra/finops/budget.bicep');
  const [budget] = template.resources.filter(
    (resource) => resource.type === 'Microsoft.Consumption/budgets',
  );
  assert.ok(budget);
  assert.equal(budget.apiVersion, '2023-11-01');
  assert.equal(budget.properties.category, 'Cost');
  assert.equal(budget.properties.timeGrain, 'Monthly');

  const notifications = Object.values(budget.properties.notifications);
  assert.equal(notifications.length, 3);

  const forecasted = notifications
    .filter((notification) => notification.thresholdType === 'Forecasted')
    .map((notification) => notification.threshold)
    .sort((a, b) => a - b);
  const actual = notifications
    .filter((notification) => notification.thresholdType === 'Actual')
    .map((notification) => notification.threshold)
    .sort((a, b) => a - b);

  assert.deepEqual(forecasted, [100, 200]);
  assert.deepEqual(actual, [100]);

  // Amounts are calibrated to 1.25x the last complete normal month, so a normal
  // month lands at 80% of the amount. Any Actual threshold below 100 would fire
  // every normal month by construction, which is why none is allowed.
  assert.ok(actual.every((threshold) => threshold >= 100));

  assert.ok(
    notifications.every(
      (notification) =>
        notification.enabled === true &&
        ['GreaterThan', 'GreaterThanOrEqualTo'].includes(notification.operator) &&
        notification.contactEmails.length === 1,
    ),
  );
});

test('default preview evaluates to zero budget writes', () => {
  const template = compileTemplate('infra/finops/main.bicep');
  const parameters = compileParameters('infra/params/finops.bicepparam');
  const deployments = template.resources.filter(
    (resource) => resource.type === 'Microsoft.Resources/deployments',
  );

  assert.equal(template.parameters.enableBudgets.defaultValue, false);
  assert.equal(template.parameters.alertEmail.type, 'securestring');
  assert.equal(template.parameters.alertEmail.defaultValue, '');
  assert.equal(parameters.parameters.enableBudgets.value, false);
  assert.equal(parameters.parameters.alertEmail, undefined);
  assert.equal(deployments.length, 5);
  assert.ok(
    deployments.every(
      (deployment) => deployment.condition === "[parameters('enableBudgets')]",
    ),
  );
});

test('budget deployment is opt-in and uses the documented 30-day baselines', () => {
  const parameters = readFileSync(
    path.join(repositoryRoot, 'infra', 'params', 'finops.bicepparam'),
    'utf8',
  );
  const contract = JSON.parse(
    readFileSync(
      path.join(repositoryRoot, 'infra', 'finops', 'scopes.json'),
      'utf8',
    ),
  );

  assert.match(parameters, /param enableBudgets = false/);
  // The content scope is a budget scope but not an application environment, so it
  // is deliberately absent from scopes.json: infra/tests/azure-tag-contract.test.mjs
  // pins scopes.json (minus ci) to the env allowedValues of infra/main.bicep.
  assert.match(parameters, /param contentResourceGroupName = 'rg-certigo-content'/);
  assert.match(parameters, /param contentMonthlyBudgetUsd = 25/);
  for (const scope of contract.scopes) {
    assert.ok(scope.baseline30DayUsd > 0);
    assert.ok(scope.monthlyBudgetUsd >= Math.ceil(scope.baseline30DayUsd));
    assert.match(
      parameters,
      new RegExp(`param ${scope.environment}MonthlyBudgetUsd = ${scope.monthlyBudgetUsd}`),
    );
    assert.match(
      parameters,
      new RegExp(
        `param ${scope.environment}ResourceGroupName = '${scope.resourceGroupName}'`,
      ),
    );
  }
});

test('tag contract requires allocation tags and rejects placeholders', () => {
  const contract = JSON.parse(
    readFileSync(
      path.join(repositoryRoot, 'infra', 'finops', 'scopes.json'),
      'utf8',
    ),
  );
  assert.deepEqual(contract.requiredTagKeys, [
    'owner',
    'product',
    'env',
    'managedBy',
    'costCenter',
  ]);

  const validInventory = Object.fromEntries(
    contract.scopes.map((scope) => [
      scope.resourceGroupName,
      [
        {
          id: `/subscriptions/test/resourceGroups/${scope.resourceGroupName}`,
          tags: {
            owner: 'certigo-platform',
            product: 'Certigo',
            env: scope.environment,
            managedBy: 'bicep',
            costCenter: 'engineering',
          },
        },
      ],
    ]),
  );
  assert.deepEqual(validateInventory(contract, validInventory), []);

  validInventory['rg-certigo-ci'][0].tags.costCenter = 'TBD';
  assert.match(validateInventory(contract, validInventory)[0], /costCenter/);

  validInventory['rg-certigo-ci'][0].tags.costCenter = 'engineering';
  validInventory['rg-certigo-ci'][0].tags.product = 'certigo';
  assert.match(validateInventory(contract, validInventory)[0], /expected "Certigo"/);
});

test('existing lifecycle deletes only bounded deployment and release prefixes', () => {
  const storage = compileTemplate('infra/modules/storage.bicep');
  const [policy] = storage.resources.filter(
    (resource) =>
      resource.type === 'Microsoft.Storage/storageAccounts/managementPolicies',
  );
  const rules = policy.properties.policy.rules;

  assert.deepEqual(
    rules.map((rule) => rule.definition.filters.prefixMatch).flat().sort(),
    ['app-package/deployments/', 'app-package/releases/'],
  );
  assert.deepEqual(
    rules
      .map(
        (rule) =>
          rule.definition.actions.baseBlob.delete.daysAfterModificationGreaterThan,
      )
      .sort((a, b) => a - b),
    [30, 90],
  );
});
