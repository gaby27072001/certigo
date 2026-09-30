import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import {
  MockArm,
  deploymentContext,
  expandModuleWorkflows,
  runWorkflow,
} from './support/logic-app-simulator.mjs';

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
  '..',
);
let compiled;

function workflows() {
  if (!compiled) {
    const bicep = process.env.BICEP_CLI || 'bicep';
    const template = JSON.parse(
      execFileSync(
        bicep,
        ['build', path.join(repositoryRoot, 'infra', 'ci-runner', 'on-demand.bicep'), '--stdout'],
        { encoding: 'utf8' },
      ),
    );
    compiled = expandModuleWorkflows(template, 'certigo-ci-runner-on-demand').workflows;
  }
  return compiled;
}

const inventory = JSON.parse(
  readFileSync(path.join(repositoryRoot, 'infra', 'ci-runner', 'capacity-controller.config.json'), 'utf8'),
);
const trustedPool = 'vmss-certigo-runner-zonal';
const prPool = 'vmss-certigo-pr-pilot-z1';

function scaleSetId(name, resourceGroupName = deploymentContext.resourceGroupName) {
  return `/subscriptions/${deploymentContext.subscriptionId}/resourceGroups/${resourceGroupName}/providers/Microsoft.Compute/virtualMachineScaleSets/${name}`;
}

// The live fleet: two trusted instances, four PR instances (their scale set reference carries
// the upper-case resource group, as measured), plus one retired PR instance that must never be
// touched because it is listed in forbiddenVirtualMachines.
function fleet(power = {}, extra = {}) {
  const upper = 'RG-CERTIGO-CI';
  const managed = [
    [inventory.inventory.managedRunnerBindings[0].virtualMachineName, trustedPool, undefined],
    [inventory.inventory.managedRunnerBindings[1].virtualMachineName, trustedPool, undefined],
    ...inventory.inventory.managedRunnerBindings.slice(2).map(({ virtualMachineName }) => [virtualMachineName, prPool, upper]),
  ];
  const vms = managed.map(([name, pool, resourceGroupName]) => ({
    name,
    scaleSetId: scaleSetId(pool, resourceGroupName),
    provisioningState: 'Succeeded',
    power: power[name] ?? power[pool] ?? 'deallocated',
    onStart: 'ok',
    ...(extra[name] ?? {}),
  }));
  vms.push({
    name: 'vmss-certigo-pr-pilot-z1_bbf83c5c',
    scaleSetId: scaleSetId(prPool, upper),
    provisioningState: 'Succeeded',
    power: power.retired ?? 'stopped',
    onStart: 'ok',
  });
  return vms;
}

const trustedNames = inventory.inventory.managedRunnerBindings
  .map(({ virtualMachineName }) => virtualMachineName)
  .filter((name) => name.startsWith(`${trustedPool}_`));
const prNames = inventory.inventory.managedRunnerBindings
  .map(({ virtualMachineName }) => virtualMachineName)
  .filter((name) => name.startsWith(`${prPool}_`));

function delivery(action, labels, repository = 'gchambaud_microsoft/Certigo') {
  return {
    headers: { 'X-GitHub-Event': 'workflow_job' },
    body: {
      action,
      repository: { full_name: repository },
      workflow_job: { id: 1, run_id: 2, labels },
    },
  };
}

async function wake(arm, trigger) {
  return runWorkflow(workflows()['logic-certigo-ci-runner-wake'].definition, arm, { trigger });
}

async function deallocate(arm) {
  return runWorkflow(workflows()['logic-certigo-ci-runner-idle-deallocation'].definition, arm);
}

function sorted(values) {
  return [...values].sort();
}

test('a queued PR job starts every PR instance and nothing else', async () => {
  const arm = new MockArm({ vms: fleet() });
  const result = await wake(arm, delivery('queued', ['self-hosted', 'Linux', 'X64', 'certigo-pr']));
  assert.equal(result.status, 'Succeeded');
  assert.deepEqual(sorted(new Set(arm.startedNames())), sorted(prNames));
  for (const name of trustedNames) assert.equal(arm.powerOf(name), 'deallocated', `${name} is trusted`);
  assert.equal(arm.powerOf('vmss-certigo-pr-pilot-z1_bbf83c5c'), 'stopped', 'a retired instance is never started');
  assert.deepEqual(arm.deallocatedNames(), [], 'waking never deallocates');
});

test('trusted and content jobs start the trusted pool only', async () => {
  for (const [labels, repository] of [
    [['self-hosted', 'Linux', 'X64', 'certigo-trusted'], 'gchambaud_microsoft/Certigo'],
    [['self-hosted', 'Linux', 'X64', 'certigo-ci', 'azure'], 'gchambaud_microsoft/certigo-content'],
  ]) {
    const arm = new MockArm({ vms: fleet() });
    const result = await wake(arm, delivery('queued', labels, repository));
    assert.equal(result.status, 'Succeeded');
    assert.deepEqual(sorted(new Set(arm.startedNames())), sorted(trustedNames), labels.join(','));
    for (const name of prNames) assert.equal(arm.powerOf(name), 'deallocated');
  }
});

test('labels and repositories are compared without regard to case', async () => {
  const arm = new MockArm({ vms: fleet() });
  const result = await wake(arm, delivery('queued', ['Self-Hosted', 'CERTIGO-PR'], 'GCHAMBAUD_MICROSOFT/CERTIGO'));
  assert.equal(result.status, 'Succeeded');
  assert.deepEqual(sorted(new Set(arm.startedNames())), sorted(prNames));
});

test('deliveries that are not runner demand start nothing and call nothing', async () => {
  const cases = {
    'in progress': delivery('in_progress', ['certigo-pr']),
    completed: delivery('completed', ['certigo-trusted']),
    'unknown repository': delivery('queued', ['certigo-pr'], 'someone/else'),
    'hosted runner': delivery('queued', ['ubuntu-latest']),
    'another self-hosted label': delivery('queued', ['self-hosted', 'certigo-cosmos-emulator']),
    'webhook ping': { headers: { 'X-GitHub-Event': 'ping' }, body: { zen: 'Keep it logically awesome.', hook_id: 1 } },
    'empty body': { headers: {}, body: null },
  };
  for (const [label, trigger] of Object.entries(cases)) {
    const arm = new MockArm({ vms: fleet() });
    const result = await wake(arm, trigger);
    assert.equal(result.status, 'Succeeded', label);
    assert.deepEqual(arm.requests, [], `${label} must not touch ARM`);
  }
});

test('an instance that halts itself while the job is queued is started by a later pass', async () => {
  // Every PR runner looks running when the job is queued, but each one is in its final guard:
  // its OS halts 20 seconds later. A single pass would leave the job stranded.
  const extra = Object.fromEntries(prNames.map((name) => [name, { timeline: [{ at: 20, power: 'stopped' }] }]));
  const arm = new MockArm({ vms: fleet({ [prPool]: 'running' }, extra) });
  const result = await wake(arm, delivery('queued', ['certigo-pr']));
  assert.equal(result.status, 'Succeeded');
  assert.deepEqual(sorted(new Set(arm.startedNames())), sorted(prNames));
  for (const name of prNames) assert.equal(arm.powerOf(name), 'running');
});

test('an instance still being deallocated is started once the deallocation completes', async () => {
  const [first] = prNames;
  const extra = { [first]: { timeline: [{ at: 120, power: 'deallocated' }] } };
  const power = Object.fromEntries(prNames.map((name) => [name, name === first ? 'deallocating' : 'deallocated']));
  const arm = new MockArm({ vms: fleet(power, extra) });
  const result = await wake(arm, delivery('queued', ['certigo-pr']));
  assert.equal(result.status, 'Succeeded');
  assert.equal(arm.powerOf(first), 'running');
});

test('a wake that cannot start anything fails the run loudly', async () => {
  const extra = Object.fromEntries(prNames.map((name) => [name, { onStart: 'forbidden' }]));
  const arm = new MockArm({ vms: fleet({}, extra) });
  const result = await wake(arm, delivery('queued', ['certigo-pr']));
  assert.equal(result.status, 'Failed');
  assert.equal(result.error.code, 'RunnerWakeFailed');
  assert.match(result.error.message, /vmss-certigo-pr-pilot-z1/);
});

test('a throttled or refused start on one instance is tolerated while another wakes', async () => {
  const [first, second] = prNames;
  const arm = new MockArm({ vms: fleet({}, { [first]: { onStart: 'throttled' }, [second]: { onStart: 'forbidden' } }) });
  const result = await wake(arm, delivery('queued', ['certigo-pr']));
  assert.equal(result.status, 'Succeeded');
  assert.equal(arm.powerOf(first), 'deallocated');
  assert.equal(arm.powerOf(prNames[2]), 'running');
});

test('an instance that is still starting counts as awake', async () => {
  const extra = Object.fromEntries(prNames.map((name) => [name, { startsInto: 'starting' }]));
  const arm = new MockArm({ vms: fleet({}, extra) });
  const result = await wake(arm, delivery('queued', ['certigo-pr']));
  assert.equal(result.status, 'Succeeded');
  // Starting instances are not started again by the later passes.
  assert.equal(arm.startedNames().length, prNames.length);
});

test('deallocation handles only instances whose OS stopped, and never excluded ones', async () => {
  const [stoppedPr, runningPr, startingPr, deallocatedPr] = prNames;
  const [stoppedTrusted, runningTrusted] = trustedNames;
  const arm = new MockArm({
    vms: fleet({
      [stoppedPr]: 'stopped',
      [runningPr]: 'running',
      [startingPr]: 'starting',
      [deallocatedPr]: 'deallocated',
      [stoppedTrusted]: 'stopped',
      [runningTrusted]: 'running',
      retired: 'stopped',
    }),
  });
  const result = await deallocate(arm);
  assert.equal(result.status, 'Succeeded');
  assert.deepEqual(sorted(arm.deallocatedNames()), sorted([stoppedPr, stoppedTrusted]));
  assert.equal(arm.powerOf(runningPr), 'running');
  assert.equal(arm.powerOf(runningTrusted), 'running');
  assert.equal(arm.powerOf(startingPr), 'starting');
  assert.equal(arm.powerOf('vmss-certigo-pr-pilot-z1_bbf83c5c'), 'stopped', 'a retired instance is never touched');
  assert.deepEqual(arm.startedNames(), [], 'deallocation never starts anything');
});

test('an instance woken between the listing and the deallocation is left alone', async () => {
  const [first] = prNames;
  const arm = new MockArm({ vms: fleet({ [first]: 'stopped' }) });
  // The reread (a single-instance GET) observes the start issued by a concurrent wake.
  const originalRequest = arm.request.bind(arm);
  arm.request = async (method, uri) => {
    if (method === 'GET' && uri.includes(`/virtualMachines/${first}?`)) {
      arm.vms.find((vm) => vm.name === first).power = 'starting';
    }
    return originalRequest(method, uri);
  };
  const result = await deallocate(arm);
  assert.equal(result.status, 'Succeeded');
  assert.deepEqual(arm.deallocatedNames(), []);
  assert.equal(arm.powerOf(first), 'starting');
});

test('a refused deallocation fails the run so that repeated failures alert', async () => {
  const [first] = prNames;
  const arm = new MockArm({ vms: fleet({ [first]: 'stopped' }, { [first]: { onDeallocate: 'fail' } }) });
  const result = await deallocate(arm);
  assert.equal(result.status, 'Failed');
  assert.equal(arm.powerOf(first), 'stopped');
});
