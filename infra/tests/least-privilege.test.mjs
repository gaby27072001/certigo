import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { validateWhatIf } from '../governance/validate-what-if.mjs';

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
  const resources = Array.isArray(template.resources)
    ? template.resources
    : Object.values(template.resources ?? {});
  return resources.filter((resource) => resource.type === type);
}

test('governance identities trust one protected environment subject each', () => {
  const template = compileTemplate(
    'infra/governance/modules/githubEnvironmentIdentity.bicep',
  );
  const [credential] = resourcesOfType(
    template,
    'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials',
  );

  assert.ok(credential);
  assert.equal(
    credential.properties.issuer,
    'https://token.actions.githubusercontent.com',
  );
  assert.deepEqual(credential.properties.audiences, [
    'api://AzureADTokenExchange',
  ]);
  assert.match(
    credential.properties.subject,
    /environment:\$\{githubEnvironmentName\}|parameters\('githubEnvironmentName'\)/,
  );
  assert.doesNotMatch(credential.properties.subject, /workflow_dispatch|pull_request/);
});

test('custom deployment roles avoid wildcard, delete, compute, and general RBAC admin', () => {
  const template = compileTemplate('infra/governance/main.bicep');
  const definitions = resourcesOfType(
    template,
    'Microsoft.Authorization/roleDefinitions',
  );
  assert.equal(definitions.length, 3);

  for (const definition of definitions) {
    const actions = definition.properties.permissions.flatMap(
      (permission) => permission.actions,
    );
    assert.ok(actions.every((action) => !action.includes('*')));
    assert.ok(actions.every((action) => !/delete/i.test(action)));
  }

  const launcher = definitions.find((definition) =>
    definition.properties.roleName.includes('Subscription Deployment Launcher'),
  );
  assert.ok(launcher);
  assert.deepEqual(launcher.properties.permissions[0].actions.sort(), [
    'Microsoft.Resources/deployments/read',
    'Microsoft.Resources/deployments/validate/action',
    'Microsoft.Resources/deployments/whatIf/action',
    'Microsoft.Resources/deployments/write',
    'Microsoft.Resources/subscriptions/resourceGroups/read',
  ]);

  const sharedNetwork = definitions.find((definition) =>
    definition.properties.roleName.includes('Shared Network Deployment'),
  );
  assert.ok(sharedNetwork);
  assert.ok(
    sharedNetwork.properties.permissions[0].actions.every(
      (action) => !/Microsoft\.Compute|Microsoft\.KeyVault/i.test(action),
    ),
  );
});

test('environment role writer cannot delete assignments and is condition-bound', () => {
  const template = compileTemplate(
    'infra/governance/modules/environmentRbac.bicep',
  );
  const assignments = resourcesOfType(
    template,
    'Microsoft.Authorization/roleAssignments',
  );
  const conditional = assignments.find(
    (assignment) => assignment.properties.conditionVersion === '2.0',
  );

  assert.ok(conditional);
  assert.equal(
    conditional.properties.condition,
    "[variables('roleAssignmentCondition')]",
  );
  assert.match(template.variables.roleAssignmentCondition, /RoleDefinitionId/);
  assert.match(template.variables.roleAssignmentCondition, /PrincipalType/);
  assert.match(template.variables.roleAssignmentCondition, /ServicePrincipal/);

  const governance = compileTemplate('infra/governance/main.bicep');
  const roleWriter = resourcesOfType(
    governance,
    'Microsoft.Authorization/roleDefinitions',
  ).find((definition) =>
    definition.properties.roleName.includes('Runtime Role Assignment Writer'),
  );
  const actions = roleWriter.properties.permissions[0].actions;
  assert.ok(actions.includes('Microsoft.Authorization/roleAssignments/write'));
  assert.ok(!actions.includes('Microsoft.Authorization/roleAssignments/delete'));
});

test('policy starts in audit and targets privileged service-principal assignments', () => {
  const template = compileTemplate('infra/governance/main.bicep');
  const [definition] = resourcesOfType(
    template,
    'Microsoft.Authorization/policyDefinitions',
  );
  const [assignment] = resourcesOfType(
    template,
    'Microsoft.Authorization/policyAssignments',
  );

  assert.ok(definition);
  assert.deepEqual(
    definition.properties.parameters.effect.allowedValues,
    ['Audit', 'Deny', 'Disabled'],
  );
  assert.equal(definition.properties.parameters.effect.defaultValue, 'Audit');
  assert.match(
    JSON.stringify(definition.properties.policyRule),
    /principalType.*ServicePrincipal/i,
  );
  assert.match(
    JSON.stringify(definition.properties.policyRule),
    /roleDefinitionId/i,
  );
  assert.equal(assignment.properties.enforcementMode, 'Default');
});

test('application template uses pre-created environment resource groups', () => {
  const template = compileTemplate('infra/main.bicep');
  const [resourceGroup] = resourcesOfType(
    template,
    'Microsoft.Resources/resourceGroups',
  );
  assert.ok(resourceGroup);
  assert.equal(resourceGroup.existing, true);
});

test('what-if validation rejects deletes and resources outside Certigo scopes', () => {
  const subscription = '00000000-0000-0000-0000-000000000001';
  const valid = validateWhatIf(
    {
      changes: [
        {
          changeType: 'Create',
          resourceId:
            `/subscriptions/${subscription}/resourceGroups/rg-certigo-ci/` +
            'providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-certigo-deploy-dev',
        },
        {
          changeType: 'Modify',
          resourceId:
            `/subscriptions/${subscription}/providers/` +
            'Microsoft.Authorization/policyAssignments/certigo-privileged-ci-rbac',
        },
      ],
    },
    subscription,
  );
  assert.equal(valid.total, 2);

  assert.throws(
    () =>
      validateWhatIf(
        {
          changes: [
            {
              changeType: 'Delete',
              resourceId:
                `/subscriptions/${subscription}/resourceGroups/rg-certigo-prod/` +
                'providers/Microsoft.Storage/storageAccounts/example',
            },
          ],
        },
        subscription,
      ),
    /delete is forbidden/,
  );

  assert.throws(
    () =>
      validateWhatIf(
        {
          changes: [
            {
              changeType: 'Create',
              resourceId:
                `/subscriptions/${subscription}/resourceGroups/unrelated/` +
                'providers/Microsoft.Storage/storageAccounts/example',
            },
          ],
        },
        subscription,
      ),
    /outside the approved set/,
  );

  assert.throws(
    () =>
      validateWhatIf(
        {
          changes: [
            {
              changeType: 'Modify',
              resourceId:
                `/subscriptions/${subscription}/resourceGroups/rg-certigo-ci/` +
                'providers/Microsoft.Compute/virtualMachineScaleSets/runners',
            },
          ],
        },
        subscription,
      ),
    /resource type is not approved/,
  );
});

test('read-only scripts contain no live mutation commands', () => {
  for (const relativePath of [
    'infra/governance/inventory.sh',
    'infra/governance/what-if.sh',
    'infra/ci-runner/capacity-plan.sh',
    'infra/ci-runner/lifecycle-preflight.sh',
  ]) {
    const script = readFileSync(path.join(repositoryRoot, relativePath), 'utf8');
    assert.doesNotMatch(
      script,
      /\baz\s+(?:deployment\s+(?:sub|group)\s+create|role\s+assignment\s+(?:create|delete)|vm(?:ss)?\s+(?:start|stop|deallocate|delete)|group\s+delete)\b/,
    );
    assert.doesNotMatch(
      script,
      /\bgh\s+api\s+(?:--method\s+)?(?:POST|PUT|PATCH|DELETE)\b/,
    );
  }
});

test('runner capacity planning stays off and encodes the guarded pilot contract', () => {
  const config = JSON.parse(
    readFileSync(
      path.join(
        repositoryRoot,
        'infra',
        'ci-runner',
        'capacity-controller.config.json',
      ),
      'utf8',
    ),
  );

  assert.equal(config.enabled, false);
  assert.equal(config.stateVersion, 3);
  assert.equal('maxAggregateCapacity' in config, false);
  assert.deepEqual(config.pilotTarget, {
    'certigo-pr': 6,
    'certigo-trusted': 2,
  });
  assert.deepEqual(config.modes.boost, config.pilotTarget);
  assert.equal(config.quietPeriodSeconds, 300);
  assert.equal(config.requiredPostQuietGuards, 2);
  assert.equal(config.minimumExclusivePools, 2);
  assert.equal(config.minimumExclusiveSubnets, 2);
  assert.deepEqual(config.inventory.externalVirtualMachines, [
    'vmss-certigo-runner-zonal_4153d1dd',
  ]);
  assert.deepEqual(config.inventory.forbiddenVirtualMachines, [
    'vmss-certigo-runner-zonal_22f7fb52',
    'vmss-certigo-pr-pilot-z1_4596a9d5',
  ]);
  assert.deepEqual(
    config.inventory.managedRunnerBindings.map(
      ({ githubRunnerId, runnerName, virtualMachineName }) => ({
        githubRunnerId,
        runnerName,
        virtualMachineName,
      }),
    ),
    [
      {
        githubRunnerId: 27,
        runnerName:
          'vmss-certigo-runner-zonal_f55d176e-Certigo',
        virtualMachineName: 'vmss-certigo-runner-zonal_f55d176e',
      },
      {
        githubRunnerId: 28,
        runnerName: 'certigo-prIVJAN8',
        virtualMachineName: 'vmss-certigo-pr-pilot-z1_bbf83c5c',
      },
    ],
  );
});

test('infra validation bootstraps pinned Node for bare Linux runners', () => {
  const validation = readFileSync(
    path.join(repositoryRoot, 'infra', 'validate.sh'),
    'utf8',
  );
  assert.match(validation, /version="20\.20\.2"/);
  assert.match(
    validation,
    /df770b2a6f130ed8627c9782c988fda9669fa23898329a61a871e32f965e007d/,
  );
  assert.match(validation, /sha256sum --check --strict/);
  assert.match(validation, /GITHUB_PATH/);
});

test('environment parameters retain historical principals only for staged cutover', () => {
  for (const environment of ['dev', 'staging', 'prod']) {
    const parameters = readFileSync(
      path.join(repositoryRoot, 'infra', 'params', `${environment}.bicepparam`),
      'utf8',
    );
    assert.match(
      parameters,
      /ciDeploymentPrincipalId = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'/,
    );
  }

  const runbook = readFileSync(
    path.join(
      repositoryRoot,
      'docs',
      'runbooks',
      'CLOUD_LEAST_PRIVILEGE.md',
    ),
    'utf8',
  );
  assert.match(runbook, /deux déploiements\s+prod réussis/i);
  assert.match(runbook, /Contributor` puis `User Access Administrator/i);
  assert.match(runbook, /#290 stockage contenu/);
  assert.match(runbook, /#296 suppression de compte/);
  assert.match(runbook, /#297 onboarding/);
  assert.match(runbook, /Catalogue `content\/`/);
});
