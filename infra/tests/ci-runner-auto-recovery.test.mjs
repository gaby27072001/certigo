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

// The recovery identity may start and read the CI runner VMs and nothing else.
// These are the only three control-plane actions the workflow issues.
const allowedActions = [
  'Microsoft.Compute/virtualMachines/read',
  'Microsoft.Compute/virtualMachines/start/action',
  'Microsoft.Compute/virtualMachines/instanceView/read',
];

// Every one of these is a DISTINCT action that "Virtual Machine Contributor"
// would grant through Microsoft.Compute/virtualMachines/*. Granting any of them
// would let the recovery identity destroy exactly what it exists to restore.
const forbiddenActions = [
  'Microsoft.Compute/virtualMachines/delete',
  'Microsoft.Compute/virtualMachines/write',
  'Microsoft.Compute/virtualMachines/deallocate/action',
  'Microsoft.Compute/virtualMachines/powerOff/action',
  'Microsoft.Compute/virtualMachines/restart/action',
  'Microsoft.Compute/virtualMachines/redeploy/action',
  'Microsoft.Compute/virtualMachines/reimage/action',
  'Microsoft.Compute/virtualMachines/runCommand/action',
  'Microsoft.Compute/virtualMachines/capture/action',
];

test('recovery role grants exactly three actions and no escalation surface', () => {
  const template = compileTemplate('infra/ci-runner/auto-recovery.bicep');
  const role = resources(template).find(
    (resource) => resource.type === 'Microsoft.Authorization/roleDefinitions',
  );

  assert.ok(role, 'the composition must declare a custom role definition');
  assert.equal(role.properties.type, 'CustomRole');
  assert.equal(role.properties.permissions.length, 1);

  const permission = role.properties.permissions[0];
  assert.deepEqual([...permission.actions].sort(), [...allowedActions].sort());
  assert.deepEqual(permission.notActions, []);
  assert.deepEqual(permission.dataActions, []);
  assert.deepEqual(permission.notDataActions, []);

  for (const action of forbiddenActions) {
    assert.ok(
      !permission.actions.includes(action),
      `${action} must never be granted to the recovery identity`,
    );
  }

  // A wildcard would silently re-acquire delete and runCommand.
  for (const action of permission.actions) {
    assert.ok(!action.includes('*'), `wildcard action is forbidden: ${action}`);
    assert.ok(
      action.startsWith('Microsoft.Compute/virtualMachines/'),
      `only virtualMachines actions are permitted, found: ${action}`,
    );
  }
});

test('recovery role is assignable only to the runner resource group', () => {
  const template = compileTemplate('infra/ci-runner/auto-recovery.bicep');
  const role = resources(template).find(
    (resource) => resource.type === 'Microsoft.Authorization/roleDefinitions',
  );

  const scopes = template.variables.assignableScopes;
  assert.equal(role.properties.assignableScopes, "[variables('assignableScopes')]");
  assert.equal(scopes.length, 1, 'exactly one assignable scope');
  assert.match(scopes[0], /resourceGroups/);
  assert.ok(
    !scopes[0].includes('managementGroups'),
    'the recovery role must never be assignable at management group scope',
  );

  // Subscription scope would let a future operator widen the blast radius
  // without editing the role itself.
  assert.match(
    scopes[0],
    /subscriptionResourceId\('Microsoft\.Resources\/resourceGroups'/,
  );
  assert.equal(
    template.parameters.resourceGroupName.defaultValue,
    'rg-certigo-ci',
  );
});

test('recovery runs after the teardown window and never races it', () => {
  const template = compileTemplate('infra/ci-runner/auto-recovery.bicep');
  const hour = template.parameters.scheduleHourUtc.defaultValue;
  const minute = template.parameters.scheduleMinuteUtc.defaultValue;
  const minutesAfterMidnightUtc = hour * 60 + minute;

  // The governance teardown deallocates every VM at 00:46-00:49 UTC. Starting
  // inside or immediately after that window would race the deallocation.
  assert.ok(
    minutesAfterMidnightUtc > 49,
    'recovery must start strictly after the 00:49 UTC teardown window closes',
  );
  assert.ok(
    minutesAfterMidnightUtc >= 60,
    'recovery must keep at least ~10 minutes of margin after the window',
  );
  assert.equal(minutesAfterMidnightUtc, 90, 'documented schedule is 01:30 UTC');
});

test('recovery workflow holds no credential and uses a managed identity', () => {
  const template = compileTemplate('infra/ci-runner/modules/runnerAutoRecovery.bicep');
  const workflow = resources(template).find(
    (resource) => resource.type === 'Microsoft.Logic/workflows',
  );

  assert.ok(workflow, 'the module must declare the recovery workflow');
  assert.equal(workflow.identity.type, 'SystemAssigned');

  const serialized = JSON.stringify(template);

  // No GitHub credential may exist anywhere in Azure. Verification that a
  // RUNNER is online lives on the GitHub side, in runner-health.yml.
  for (const marker of [
    'api.github.com',
    'github.com',
    'ghp_',
    'personal-access-token',
    'privateKey',
    'installationId',
    'listSecrets',
    'Authorization',
  ]) {
    assert.ok(
      !serialized.includes(marker),
      `no GitHub credential or raw auth header may appear in Azure: ${marker}`,
    );
  }

  // Every outbound call must authenticate as the managed identity.
  assert.ok(
    !serialized.includes('@secure()') && !template.parameters.githubToken,
    'the module must not accept a token parameter',
  );
  assert.match(serialized, /ManagedServiceIdentity/);
});

test('recovery verifies power state and fails loudly when it is not running', () => {
  const template = compileTemplate('infra/ci-runner/modules/runnerAutoRecovery.bicep');
  const serialized = JSON.stringify(template);

  // Starting is not the same as recovering: the run must assert the result. The power state
  // now arrives with the filtered listing of each scale set rather than a per-VM call.
  assert.match(serialized, /\$expand=instanceView/);
  assert.match(serialized, /PowerState\/running/);

  // A silent success would make the whole mechanism worthless.
  assert.match(serialized, /Terminate/);
  assert.match(serialized, /Failed/);
  for (const code of [
    'RunnerPowerStateNotRunning',
    'RunnerPoolBelowRedundancyFloor',
    'RunnerEnumerationIncomplete',
  ]) {
    assert.match(serialized, new RegExp(code), `${code} must terminate the run as Failed`);
  }
});

test('recovery enumerates scale set members at run time instead of freezing names', () => {
  const template = compileTemplate('infra/ci-runner/modules/runnerAutoRecovery.bicep');
  const serialized = JSON.stringify(template);

  assert.equal(template.parameters.virtualMachineNames, undefined);
  assert.equal(template.parameters.scaleSets.type, 'array');
  assert.equal(template.parameters.scaleSets.minLength, 1);

  // ARM only accepts `$expand=instanceView` together with this filter, and only when the
  // property name is quoted; the filter is also what makes the membership authoritative
  // (tags are asymmetric between the pools and would lose the trusted instances).
  assert.match(
    serialized,
    /uriComponent\(format\('''virtualMachineScaleSet\/id'' eq ''\{0\}''', resourceId\('Microsoft\.Compute\/virtualMachineScaleSets'/,
  );
  // Scale set enumeration through the VMSS API would need virtualMachineScaleSets/read,
  // which the recovery role deliberately does not hold.
  assert.doesNotMatch(serialized, /virtualMachineScaleSets\/[^'"]*\/virtualMachines/);
  assert.doesNotMatch(serialized, /vmss-certigo-[a-z0-9-]+_[0-9a-f]{8}/);

  // Exclusions are compared in lower case on both sides.
  assert.match(serialized, /toLower\(item\(\)\?\[''name''\]\)/);
  assert.match(serialized, /toLower\(string\(lambdaVariables\('name'\)\)\)/);
});

test('the recovery scope is declared once and follows the inventory', async () => {
  const template = compileTemplate('infra/ci-runner/auto-recovery.bicep');
  const capacity = compileTemplate('infra/ci-runner/capacity.bicep');
  const { readFileSync } = await import('node:fs');
  const config = JSON.parse(
    readFileSync(
      path.join(repositoryRoot, 'infra', 'ci-runner', 'capacity-controller.config.json'),
      'utf8',
    ),
  );

  assert.equal(template.parameters.virtualMachineNames, undefined);
  const scaleSets = template.parameters.scaleSets.defaultValue;
  // The recovered scale sets are the two pools the capacity contract observes: a pool added
  // there without being added here would never be restarted.
  assert.deepEqual(
    scaleSets.map(({ name }) => name).sort(),
    [
      capacity.parameters.legacyVmScaleSetName.defaultValue,
      capacity.parameters.pilotVmScaleSetName.defaultValue,
    ].sort(),
  );
  assert.deepEqual(
    Object.fromEntries(scaleSets.map(({ name, trustClass }) => [name, trustClass])),
    {
      'vmss-certigo-runner-zonal': 'certigo-trusted',
      'vmss-certigo-pr-pilot-z1': 'certigo-pr',
    },
  );
  // Each pool's floor comes from minimumOnlineByTrust; a zero floor would make the floor
  // assertion vacuous, which is precisely the failure mode it exists to prevent.
  for (const { trustClass } of scaleSets) {
    assert.ok(
      Number.isInteger(config.minimumOnlineByTrust[trustClass]) &&
        config.minimumOnlineByTrust[trustClass] >= 1,
      `${trustClass} must have a redundancy floor of at least 1`,
    );
  }

  // The exclusions are loaded from the inventory, not copied: the compiled template must
  // embed exactly the current forbidden and external instance lists.
  const loaded = Object.values(template.variables).filter(Array.isArray);
  for (const list of [
    config.inventory.forbiddenVirtualMachines,
    config.inventory.externalVirtualMachines,
  ]) {
    assert.ok(
      loaded.some((values) => JSON.stringify(values) === JSON.stringify(list)),
      `the compiled recovery must embed ${JSON.stringify(list)}`,
    );
  }
  assert.equal(
    template.variables.excludedVirtualMachineNames,
    "[union(variables('forbiddenVirtualMachines'), variables('externalVirtualMachines'))]",
  );

  const module = resources(template).find(
    (resource) => resource.name === 'certigo-ci-runner-auto-recovery',
  );
  assert.deepEqual(module.properties.parameters.scaleSets, {
    value: "[variables('recoveredScaleSets')]",
  });
  assert.deepEqual(module.properties.parameters.excludedVirtualMachineNames, {
    value: "[variables('excludedVirtualMachineNames')]",
  });

  // Every managed runner is in scope and never excluded; every forbidden instance is.
  const excluded = new Set(
    [
      ...config.inventory.forbiddenVirtualMachines,
      ...config.inventory.externalVirtualMachines,
    ].map((name) => name.toLowerCase()),
  );
  const managed = config.inventory.managedRunnerBindings.map(
    ({ virtualMachineName }) => virtualMachineName,
  );
  assert.ok(managed.length > 0, 'the inventory must declare managed runner bindings');
  for (const name of managed) {
    assert.ok(
      scaleSets.some(({ name: scaleSet }) => name.startsWith(`${scaleSet}_`)),
      `${name} must belong to a recovered scale set`,
    );
    assert.ok(!excluded.has(name.toLowerCase()), `${name} must never be excluded`);
  }
});

test('recovery failure surfaces through an alert, not only a run history', () => {
  const template = compileTemplate('infra/ci-runner/modules/runnerAutoRecovery.bicep');
  const alert = resources(template).find(
    (resource) => resource.type === 'Microsoft.Insights/metricAlerts',
  );
  const actionGroup = resources(template).find(
    (resource) => resource.type === 'Microsoft.Insights/actionGroups',
  );

  assert.ok(actionGroup, 'an action group must exist to route the failure');
  assert.ok(alert, 'an alert must exist so a human learns about the failure');
  assert.equal(alert.properties.enabled, true);
  assert.equal(alert.properties.severity, 1);

  const criterion = alert.properties.criteria.allOf[0];
  assert.equal(criterion.metricName, 'RunsFailed');
  assert.equal(criterion.operator, 'GreaterThan');
  assert.equal(criterion.threshold, 0);
  assert.equal(criterion.timeAggregation, 'Total');
  assert.deepEqual(alert.properties.actions, [
    { actionGroupId: "[resourceId('Microsoft.Insights/actionGroups', 'ag-certigo-ci-recovery')]" },
  ]);
});

test('the runner resource group carries a CanNotDelete lock', () => {
  const template = compileTemplate('infra/ci-runner/modules/resourceGroupDeletionLock.bicep');
  const lock = resources(template).find(
    (resource) => resource.type === 'Microsoft.Authorization/locks',
  );

  assert.ok(lock, 'the module must declare a resource group lock');
  assert.equal(lock.properties.level, 'CanNotDelete');

  // A ReadOnly lock would block the recovery itself: starting a VM is a write
  // on the control plane.
  assert.notEqual(lock.properties.level, 'ReadOnly');
  assert.match(lock.properties.notes, /Complete/);
});

test('recovery composition wires the lock and reuses the shared RBAC primitive', () => {
  const template = compileTemplate('infra/ci-runner/auto-recovery.bicep');
  const modules = resources(template).filter(
    (resource) => resource.type === 'Microsoft.Resources/deployments',
  );
  const names = modules.map((module) => module.name);

  assert.ok(names.includes('certigo-ci-runner-auto-recovery'));
  assert.ok(names.includes('certigo-ci-runner-auto-recovery-rbac'));
  assert.ok(names.includes('certigo-ci-deletion-lock'));

  // The role assignment must bind the workflow identity to the custom role,
  // never to a built-in role id.
  const rbac = modules.find(
    (module) => module.name === 'certigo-ci-runner-auto-recovery-rbac',
  );
  const rbacParameters = JSON.stringify(rbac.properties.parameters);
  assert.match(rbacParameters, /roleDefinitionId/);
  assert.ok(
    !rbacParameters.includes('9980e02c-c2be-4d73-94e8-173b1dc7cf3c'),
    'the built-in Virtual Machine Contributor role must never be assigned',
  );
  assert.ok(
    !rbacParameters.includes('b24988ac-6180-42a0-ab88-20f7382dd24c'),
    'the built-in Contributor role must never be assigned',
  );
});
