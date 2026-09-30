import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { expandModuleWorkflows, resources } from './support/logic-app-simulator.mjs';

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

function readJson(...segments) {
  return JSON.parse(readFileSync(path.join(repositoryRoot, ...segments), 'utf8'));
}

const onDemandConfig = readJson('infra', 'ci-runner', 'on-demand.config.json');
const inventory = readJson('infra', 'ci-runner', 'capacity-controller.config.json');
const composition = 'infra/ci-runner/on-demand.bicep';

function roleDefinitions() {
  return resources(compileTemplate(composition)).filter(
    (resource) => resource.type === 'Microsoft.Authorization/roleDefinitions',
  );
}

function roleNamed(seed) {
  const role = roleDefinitions().find((candidate) => candidate.name.includes(`'${seed}'`));
  assert.ok(role, `role definition ${seed} must exist`);
  return role;
}

function expanded() {
  return expandModuleWorkflows(compileTemplate(composition), 'certigo-ci-runner-on-demand');
}

function allActions(actions, found = {}) {
  for (const [name, action] of Object.entries(actions ?? {})) {
    found[name] = action;
    allActions(action.actions, found);
    allActions(action.else?.actions, found);
  }
  return found;
}

// Every action that "Virtual Machine Contributor" grants through
// Microsoft.Compute/virtualMachines/* and that neither on-demand identity needs.
const alwaysForbidden = [
  'Microsoft.Compute/virtualMachines/delete',
  'Microsoft.Compute/virtualMachines/write',
  'Microsoft.Compute/virtualMachines/powerOff/action',
  'Microsoft.Compute/virtualMachines/restart/action',
  'Microsoft.Compute/virtualMachines/redeploy/action',
  'Microsoft.Compute/virtualMachines/reimage/action',
  'Microsoft.Compute/virtualMachines/runCommand/action',
  'Microsoft.Compute/virtualMachines/capture/action',
];

test('the wake identity may only read and start runner VMs', () => {
  const permission = roleNamed('certigo-ci-runner-wake').properties.permissions[0];
  assert.deepEqual([...permission.actions].sort(), [
    'Microsoft.Compute/virtualMachines/read',
    'Microsoft.Compute/virtualMachines/start/action',
  ]);
  assert.ok(!permission.actions.includes('Microsoft.Compute/virtualMachines/deallocate/action'));
  for (const action of alwaysForbidden) assert.ok(!permission.actions.includes(action), action);
  assert.deepEqual(permission.notActions, []);
  assert.deepEqual(permission.dataActions, []);
});

test('the deallocation identity may only read and deallocate runner VMs', () => {
  const permission = roleNamed('certigo-ci-runner-idle-deallocation').properties.permissions[0];
  assert.deepEqual([...permission.actions].sort(), [
    'Microsoft.Compute/virtualMachines/deallocate/action',
    'Microsoft.Compute/virtualMachines/read',
  ]);
  // Deallocating and starting are never held by the same identity: a compromised or
  // misconfigured workflow can either wake or stop the fleet, not both.
  assert.ok(!permission.actions.includes('Microsoft.Compute/virtualMachines/start/action'));
  for (const action of alwaysForbidden) assert.ok(!permission.actions.includes(action), action);
  assert.deepEqual(permission.dataActions, []);
});

test('both roles are assignable only to the runner resource group and never wildcarded', () => {
  const template = compileTemplate(composition);
  assert.equal(roleDefinitions().length, 2);
  for (const role of roleDefinitions()) {
    assert.equal(role.properties.type, 'CustomRole');
    assert.equal(role.properties.assignableScopes, "[variables('assignableScopes')]");
    for (const action of role.properties.permissions[0].actions) {
      assert.ok(!action.includes('*'), `wildcard action is forbidden: ${action}`);
      assert.ok(action.startsWith('Microsoft.Compute/virtualMachines/'), action);
    }
  }
  assert.equal(template.variables.assignableScopes.length, 1);
  assert.match(
    template.variables.assignableScopes[0],
    /subscriptionResourceId\('Microsoft\.Resources\/resourceGroups', parameters\('resourceGroupName'\)\)/,
  );
  assert.equal(template.parameters.resourceGroupName.defaultValue, 'rg-certigo-ci');

  // Each identity receives its own role through the shared RBAC primitive, never a built-in.
  const assignments = resources(template).filter(
    (resource) => resource.type === 'Microsoft.Resources/deployments' && resource.name.endsWith('-rbac'),
  );
  assert.deepEqual(assignments.map((module) => module.name).sort(), [
    'certigo-ci-runner-idle-deallocation-rbac',
    'certigo-ci-runner-wake-rbac',
  ]);
  for (const module of assignments) {
    const parameters = JSON.stringify(module.properties.parameters);
    assert.ok(!parameters.includes('9980e02c-c2be-4d73-94e8-173b1dc7cf3c'), 'Virtual Machine Contributor');
    assert.ok(!parameters.includes('b24988ac-6180-42a0-ab88-20f7382dd24c'), 'Contributor');
  }
  assert.match(
    JSON.stringify(assignments.find((module) => module.name === 'certigo-ci-runner-wake-rbac').properties.parameters),
    /wakePrincipalId/,
  );
  assert.match(
    JSON.stringify(assignments.find((module) => module.name === 'certigo-ci-runner-idle-deallocation-rbac').properties.parameters),
    /deallocationPrincipalId/,
  );
});

test('no GitHub credential exists in Azure and every ARM call uses a managed identity', () => {
  const module = compileTemplate('infra/ci-runner/modules/runnerOnDemand.bicep');
  const serialized = JSON.stringify(module);
  for (const marker of [
    'api.github.com',
    'github.com',
    'ghp_',
    'github_pat_',
    'personal-access-token',
    'privateKey',
    'installationId',
    'listCallbackUrl',
    'Authorization',
  ]) {
    assert.ok(!serialized.includes(marker), `forbidden marker in the on-demand module: ${marker}`);
  }
  assert.ok(!serialized.includes('@secure()') && !module.parameters.githubToken);
  // The signed trigger URL is a bearer secret: it must never become a deployment output.
  for (const output of Object.keys(module.outputs)) assert.doesNotMatch(output, /url|callback|sig/i);
  for (const output of Object.keys(compileTemplate(composition).outputs)) {
    assert.doesNotMatch(output, /url|callback|sig/i);
  }

  const { workflows } = expanded();
  const httpActions = Object.values(workflows).flatMap(({ definition }) =>
    Object.values(allActions(definition.actions)).filter((action) => action.type === 'Http'),
  );
  assert.ok(httpActions.length > 0);
  for (const action of httpActions) {
    assert.equal(action.inputs.authentication.type, 'ManagedServiceIdentity');
    assert.match(action.inputs.uri, /^https:\/\/management\.azure\.com\/subscriptions\//);
    assert.equal(action.inputs.headers, undefined, 'no header can carry a credential');
  }
});

test('the pools, labels and exclusions come from the versioned inventory', () => {
  const capacity = compileTemplate('infra/ci-runner/capacity.bicep');
  const recovery = compileTemplate('infra/ci-runner/auto-recovery.bicep');
  // The on-demand pools are exactly the two scale sets the capacity contract observes, with
  // the same trust class as the nightly recovery: a third pool would need all three updated.
  assert.deepEqual(
    onDemandConfig.pools.map(({ scaleSet }) => scaleSet).sort(),
    [
      capacity.parameters.legacyVmScaleSetName.defaultValue,
      capacity.parameters.pilotVmScaleSetName.defaultValue,
    ].sort(),
  );
  assert.deepEqual(
    Object.fromEntries(onDemandConfig.pools.map(({ scaleSet, trustClass }) => [scaleSet, trustClass])),
    Object.fromEntries(
      recovery.parameters.scaleSets.defaultValue.map(({ name, trustClass }) => [name, trustClass]),
    ),
  );

  // The trust boundary: a PR label never wakes the trusted pool and a trusted label never
  // wakes the PR pool. `certigo-ci` is the certigo-content label carried by the trusted VMs.
  const labels = Object.fromEntries(onDemandConfig.pools.map(({ trustClass, wakeLabels }) => [trustClass, wakeLabels]));
  assert.deepEqual(labels['certigo-pr'], ['certigo-pr']);
  assert.deepEqual([...labels['certigo-trusted']].sort(), ['certigo-ci', 'certigo-trusted']);

  const source = readFileSync(path.join(repositoryRoot, 'infra', 'ci-runner', 'on-demand.bicep'), 'utf8');
  for (const pointer of [
    "loadJsonContent('capacity-controller.config.json', '$.repositories')",
    "loadJsonContent('capacity-controller.config.json', '$.inventory.forbiddenVirtualMachines')",
    "loadJsonContent('capacity-controller.config.json', '$.inventory.externalVirtualMachines')",
    "loadJsonContent('on-demand.config.json', '$.pools')",
  ]) {
    assert.ok(source.includes(pointer), `${pointer} must be loaded, not copied`);
  }
  assert.doesNotMatch(source, /vmss-certigo-[a-z0-9-]+_[0-9a-f]{8}/, 'no instance may be named');

  const { workflows } = expanded();
  const excluded = [
    ...inventory.inventory.forbiddenVirtualMachines,
    ...inventory.inventory.externalVirtualMachines,
  ].map((name) => name.toLowerCase());
  for (const { definition } of Object.values(workflows)) {
    assert.deepEqual(definition.parameters.excludedVirtualMachineNames.defaultValue, excluded);
  }
  const wake = workflows['logic-certigo-ci-runner-wake'].definition;
  assert.deepEqual(
    wake.parameters.repositories.defaultValue,
    inventory.repositories.map((repository) => repository.toLowerCase()),
  );
  assert.deepEqual(wake.parameters.wakeLabelsByPool.defaultValue, {
    'vmss-certigo-runner-zonal': ['certigo-trusted', 'certigo-ci'],
    'vmss-certigo-pr-pilot-z1': ['certigo-pr'],
  });

  // Every managed runner can be woken and deallocated: none is excluded.
  for (const { virtualMachineName } of inventory.inventory.managedRunnerBindings) {
    assert.ok(!excluded.includes(virtualMachineName.toLowerCase()), virtualMachineName);
  }
});

test('the wake trigger accepts only GitHub hook sources and only runner demand', () => {
  const { workflows } = expanded();
  const wake = workflows['logic-certigo-ci-runner-wake'];
  const ranges = wake.accessControl.triggers.allowedCallerIpAddresses.map(({ addressRange }) => addressRange);
  assert.deepEqual(ranges, onDemandConfig.githubHookSourceRanges.addressRanges);
  assert.ok(ranges.length > 0);
  for (const range of ranges) {
    assert.match(range, /^\d{1,3}(\.\d{1,3}){3}\/(1[6-9]|2\d|3[0-2])$/, `IPv4 CIDR no wider than /16: ${range}`);
    assert.notEqual(range, '0.0.0.0/0');
  }

  const [trigger] = Object.values(wake.definition.triggers);
  assert.equal(trigger.type, 'Request');
  assert.equal(trigger.inputs.method, 'POST');
  // No Response action: the trigger answers 202 at once, well inside GitHub's 10-second limit.
  assert.ok(!Object.values(allActions(wake.definition.actions)).some((action) => action.type === 'Response'));

  // Only jobs waiting for a runner wake a pool: in_progress and completed never do.
  assert.deepEqual(wake.definition.parameters.wakeActions.defaultValue, onDemandConfig.wakeActions);
  assert.deepEqual([...onDemandConfig.wakeActions].sort(), ['queued', 'waiting']);
});

test('waking only starts powered-off instances and fails loudly when nothing wakes up', () => {
  const { workflows } = expanded();
  const actions = allActions(workflows['logic-certigo-ci-runner-wake'].definition.actions);
  const starts = Object.entries(actions).filter(([, action]) => action.type === 'Http' && action.inputs.method === 'POST');
  assert.equal(starts.length, onDemandConfig.pools.length * onDemandConfig.wakePassDelaysSeconds.length);
  for (const [name, action] of starts) {
    assert.match(action.inputs.uri, /\/start\?api-version=/, name);
    assert.equal(action.operationOptions, 'DisableAsyncPattern', name);
  }
  const selections = Object.entries(actions).filter(([name]) => name.startsWith('Select_the_instances_to_wake_in_'));
  assert.equal(selections.length, starts.length);
  for (const [, action] of selections) {
    assert.match(action.inputs.where, /PowerState\/deallocated/);
    assert.match(action.inputs.where, /PowerState\/stopped/);
    assert.doesNotMatch(action.inputs.where, /PowerState\/running/);
  }
  const terminations = Object.values(actions).filter((action) => action.type === 'Terminate');
  assert.equal(terminations.length, onDemandConfig.pools.length);
  for (const termination of terminations) {
    assert.equal(termination.inputs.runStatus, 'Failed');
    assert.equal(termination.inputs.runError.code, 'RunnerWakeFailed');
  }
  // Terminate is never placed inside a loop.
  for (const action of Object.values(actions).filter((candidate) => candidate.type === 'Foreach')) {
    assert.ok(!Object.values(allActions(action.actions)).some((inner) => inner.type === 'Terminate'));
  }
});

test('deallocation only touches instances whose OS already stopped, outside the nightly windows', () => {
  const { workflows } = expanded();
  const deallocation = workflows['logic-certigo-ci-runner-idle-deallocation'].definition;
  const [trigger] = Object.values(deallocation.triggers);
  assert.equal(trigger.type, 'Recurrence');
  assert.equal(trigger.recurrence.timeZone, 'UTC');
  assert.equal(trigger.runtimeConfiguration.concurrency.runs, 1);
  // Never during the MCAPS teardown (00:46-00:49 UTC) nor the recovery (01:30 UTC).
  const hours = trigger.recurrence.schedule.hours;
  assert.ok(!hours.includes(0) && !hours.includes(1), `hours ${hours}`);
  assert.deepEqual(hours, Array.from({ length: 22 }, (_value, offset) => offset + 2));
  assert.equal(trigger.recurrence.schedule.minutes.length, 12);

  const actions = allActions(deallocation.actions);
  const posts = Object.entries(actions).filter(([, action]) => action.type === 'Http' && action.inputs.method === 'POST');
  assert.equal(posts.length, onDemandConfig.pools.length);
  for (const [name, action] of posts) {
    assert.match(action.inputs.uri, /\/deallocate\?api-version=/, name);
    assert.doesNotMatch(action.inputs.uri, /\/(start|delete|powerOff|restart|runCommand)/, name);
  }
  const selections = Object.entries(actions).filter(([name]) => name.startsWith('Select_the_stopped_instances_of_'));
  assert.equal(selections.length, onDemandConfig.pools.length);
  for (const [, action] of selections) {
    assert.match(action.inputs.where, /PowerState\/stopped/);
    for (const other of ['running', 'starting', 'deallocated', 'stopping']) {
      assert.doesNotMatch(action.inputs.where, new RegExp(`PowerState/${other}`));
    }
  }
  // Each candidate is reread immediately before deallocation.
  const gates = Object.entries(actions).filter(([name]) => name.startsWith('Deallocate_if_the_instance_of_'));
  assert.equal(gates.length, onDemandConfig.pools.length);
  for (const [, gate] of gates) {
    assert.match(JSON.stringify(gate.expression), /PowerState\/stopped/);
    assert.match(JSON.stringify(gate.runAfter), /Reread_a_stopped_instance_of_/);
  }
});

test('failures of both workflows reach the recovery action group', () => {
  const module = compileTemplate('infra/ci-runner/modules/runnerOnDemand.bicep');
  const alerts = resources(module).filter((resource) => resource.type === 'Microsoft.Insights/metricAlerts');
  assert.deepEqual(alerts.map((alert) => alert.name).sort(), [
    'alert-certigo-ci-runner-idle-deallocation-failed',
    'alert-certigo-ci-runner-wake-failed',
  ]);
  for (const alert of alerts) {
    assert.equal(alert.properties.enabled, true);
    const [criterion] = alert.properties.criteria.allOf;
    assert.equal(criterion.metricName, 'RunsFailed');
    assert.equal(criterion.operator, 'GreaterThan');
    assert.equal(criterion.timeAggregation, 'Total');
    assert.match(JSON.stringify(alert.properties.actions), /actionGroups/);
  }
  const wake = alerts.find((alert) => alert.name === 'alert-certigo-ci-runner-wake-failed');
  assert.equal(wake.properties.criteria.allOf[0].threshold, 0);
  assert.equal(wake.properties.severity, 1);
  assert.equal(module.parameters.actionGroupName.defaultValue, 'ag-certigo-ci-recovery');
  // The on-demand module creates no action group, hence no new e-mail recipient.
  assert.equal(resources(module).filter((resource) => resource.type === 'Microsoft.Insights/actionGroups' && !resource.existing).length, 0);
});

test('the VM-side quiet periods honour the controller contract', () => {
  const controller = readJson('infra', 'ci-runner', 'capacity-controller.config.json');
  for (const pool of onDemandConfig.pools) {
    assert.ok(Number.isInteger(pool.quietPeriodSeconds));
    assert.ok(pool.quietPeriodSeconds >= controller.quietPeriodSeconds, `${pool.scaleSet} quiet period`);
  }
  // The PR pool idles out before the trusted pool (controller scaleInOrder).
  const byTrust = Object.fromEntries(onDemandConfig.pools.map((pool) => [pool.trustClass, pool.quietPeriodSeconds]));
  assert.deepEqual(controller.scaleInOrder, ['certigo-pr', 'certigo-trusted']);
  assert.ok(byTrust['certigo-pr'] < byTrust['certigo-trusted']);

  const agent = readFileSync(path.join(repositoryRoot, 'infra', 'ci-runner', 'idle-shutdown.sh'), 'utf8');
  assert.match(agent, /readonly MINIMUM_QUIET_PERIOD_SECONDS=300$/m);
  assert.match(agent, /readonly REQUIRED_GUARDS=2$/m);
  // The agent's no-shutdown window covers the 01:30 UTC recovery.
  assert.match(agent, /readonly DEFAULT_NO_SHUTDOWN_WINDOW_UTC='0115-0150'$/m);
  const recovery = compileTemplate('infra/ci-runner/auto-recovery.bicep');
  const recoveryMinute =
    recovery.parameters.scheduleHourUtc.defaultValue * 60 + recovery.parameters.scheduleMinuteUtc.defaultValue;
  assert.ok(recoveryMinute >= 75 && recoveryMinute + 15 <= 110, 'recovery must sit inside the window with margin');
  // The agent holds no identity and never talks to Azure or GitHub.
  for (const marker of ['169.254.169.254', 'management.azure.com', 'api.github.com', 'az ', 'curl ']) {
    assert.ok(!agent.includes(marker), `the idle agent must not call ${marker.trim()}`);
  }
});
