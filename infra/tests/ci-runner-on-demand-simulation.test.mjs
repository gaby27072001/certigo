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
const prPool = 'vmss-certigo-pr-v2-z1';
// Replaced by prPool (#553). Its instances are kept, deallocated, until their deletion is
// approved: the scale set is no on-demand pool any more and each of its instances is forbidden.
const retiredPrPool = 'vmss-certigo-pr-pilot-z1';
const forbidden = inventory.inventory.forbiddenVirtualMachines;
const retiredInPool = forbidden.find((name) => name.startsWith(`${trustedPool}_`));
const retiredPrNames = forbidden.filter((name) => name.startsWith(`${retiredPrPool}_`));
assert.ok(retiredInPool, 'the inventory forbids a retired trusted instance');
assert.ok(retiredPrNames.length > 0, 'the inventory forbids the retired PR pool');

function scaleSetId(name, resourceGroupName = deploymentContext.resourceGroupName) {
  return `/subscriptions/${deploymentContext.subscriptionId}/resourceGroups/${resourceGroupName}/providers/Microsoft.Compute/virtualMachineScaleSets/${name}`;
}

function instance(name, pool, power, resourceGroupName) {
  return {
    name,
    scaleSetId: scaleSetId(pool, resourceGroupName),
    provisioningState: 'Succeeded',
    power,
    onStart: 'ok',
  };
}

// The live fleet: two trusted instances and four PR instances (the PR scale set reference
// carries the upper-case resource group, as measured on the previous pool: comparisons must
// ignore case). Two kinds of retired instances must never be touched: one still listed by its
// own scale set, kept out only by forbiddenVirtualMachines, and those of the retired PR scale
// set, which no pool lists any more. An instance of the latter that halted itself therefore
// stays stopped, and billed, until an operator deallocates it.
function fleet(power = {}, extra = {}) {
  const upper = 'RG-CERTIGO-CI';
  const managed = [
    [inventory.inventory.managedRunnerBindings[0].virtualMachineName, trustedPool, undefined],
    [inventory.inventory.managedRunnerBindings[1].virtualMachineName, trustedPool, undefined],
    ...inventory.inventory.managedRunnerBindings.slice(2).map(({ virtualMachineName }) => [virtualMachineName, prPool, upper]),
  ];
  const vms = managed.map(([name, pool, resourceGroupName]) => ({
    ...instance(name, pool, power[name] ?? power[pool] ?? 'deallocated', resourceGroupName),
    ...(extra[name] ?? {}),
  }));
  vms.push(instance(retiredInPool, trustedPool, power.retired ?? 'stopped'));
  for (const name of retiredPrNames) vms.push(instance(name, retiredPrPool, power.retiredPool ?? 'stopped', upper));
  return vms;
}

function untouchedRetired(arm) {
  assert.equal(arm.powerOf(retiredInPool), 'stopped', 'a retired instance is never touched');
  for (const name of retiredPrNames) assert.equal(arm.powerOf(name), 'stopped', `${name} is in the retired pool`);
  assert.ok(arm.requests.every(({ uri }) => !uri.includes(retiredPrPool)), 'the retired pool is never listed');
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
  untouchedRetired(arm);
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
    untouchedRetired(arm);
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
  assert.match(result.error.message, new RegExp(prPool));
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
      retiredPool: 'stopped',
    }),
  });
  const result = await deallocate(arm);
  assert.equal(result.status, 'Succeeded');
  assert.deepEqual(sorted(arm.deallocatedNames()), sorted([stoppedPr, stoppedTrusted]));
  assert.equal(arm.powerOf(runningPr), 'running');
  assert.equal(arm.powerOf(runningTrusted), 'running');
  assert.equal(arm.powerOf(startingPr), 'starting');
  untouchedRetired(arm);
  assert.deepEqual(arm.startedNames(), [], 'deallocation never starts anything');
});

test('an instance retired inside the PR pool is kept out by its name alone', async () => {
  // A later replacement inside the PR scale set: until its deletion, the retired instance is
  // still listed by the pool, and only forbiddenVirtualMachines keeps it out of both paths.
  const retired = `${prPool}_0ff1ced0`;
  const excluding = (workflowName) => {
    const definition = structuredClone(workflows()[workflowName].definition);
    definition.parameters.excludedVirtualMachineNames.defaultValue.push(retired);
    return definition;
  };
  const withRetired = (power) => [...fleet(power), instance(retired, prPool, 'stopped', 'RG-CERTIGO-CI')];

  const woken = new MockArm({ vms: withRetired({}) });
  const wakeResult = await runWorkflow(excluding('logic-certigo-ci-runner-wake'), woken, {
    trigger: delivery('queued', ['certigo-pr']),
  });
  assert.equal(wakeResult.status, 'Succeeded');
  assert.deepEqual(sorted(new Set(woken.startedNames())), sorted(prNames));
  assert.equal(woken.powerOf(retired), 'stopped');

  const [stoppedPr] = prNames;
  const halted = new MockArm({ vms: withRetired({ [stoppedPr]: 'stopped' }) });
  const deallocationResult = await runWorkflow(excluding('logic-certigo-ci-runner-idle-deallocation'), halted);
  assert.equal(deallocationResult.status, 'Succeeded');
  assert.deepEqual(halted.deallocatedNames(), [stoppedPr]);
  assert.equal(halted.powerOf(retired), 'stopped');
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
