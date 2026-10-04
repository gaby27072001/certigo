import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import {
  MockArm,
  deploymentContext,
  expandRecoveryWorkflow,
  resources,
  runWorkflow,
} from './support/logic-app-simulator.mjs';

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

const config = JSON.parse(
  readFileSync(path.join(repositoryRoot, 'infra', 'ci-runner', 'capacity-controller.config.json'), 'utf8'),
);

function scaleSetId(name, resourceGroupName = deploymentContext.resourceGroupName) {
  return `/subscriptions/${deploymentContext.subscriptionId}/resourceGroups/${resourceGroupName}/providers/Microsoft.Compute/virtualMachineScaleSets/${name}`;
}

function vm(name, scaleSetName, options = {}) {
  return {
    name,
    scaleSetId: scaleSetId(scaleSetName, options.resourceGroupName),
    provisioningState: options.provisioningState ?? 'Succeeded',
    power: options.power ?? 'deallocated',
    onStart: options.onStart ?? 'ok',
  };
}

function liveTopology(overrides = {}) {
  const upper = 'RG-CERTIGO-CI';
  const vms = [
    vm('vmss-certigo-runner-zonal_f55d176e', 'vmss-certigo-runner-zonal'),
    vm('vmss-certigo-runner-zonal_be505fa1', 'vmss-certigo-runner-zonal'),
    vm('vmss-certigo-runner-zonal_22f7fb52', 'vmss-certigo-runner-zonal'),
    vm('vmss-certigo-pr-v2-z1_feedbee1', 'vmss-certigo-pr-v2-z1', { resourceGroupName: upper }),
    vm('vmss-certigo-pr-v2-z1_feedbee2', 'vmss-certigo-pr-v2-z1', { resourceGroupName: upper }),
    vm('vmss-certigo-pr-v2-z1_feedbee3', 'vmss-certigo-pr-v2-z1', { resourceGroupName: upper }),
    vm('vmss-certigo-pr-v2-z1_feedbee4', 'vmss-certigo-pr-v2-z1', { resourceGroupName: upper }),
    vm('vmss-certigo-pr-pilot-z1_5275ea21', 'vmss-certigo-pr-pilot-z1', { resourceGroupName: upper }),
    vm('vmss-certigo-pr-pilot-z1_94bad106', 'vmss-certigo-pr-pilot-z1', { resourceGroupName: upper }),
    vm('vmss-certigo-pr-pilot-z1_1a6deaa2', 'vmss-certigo-pr-pilot-z1', { resourceGroupName: upper }),
    vm('vmss-certigo-pr-pilot-z1_6e3abce4', 'vmss-certigo-pr-pilot-z1', { resourceGroupName: upper }),
  ];
  return vms.map((item) => ({ ...item, ...(overrides[item.name] ?? {}) }));
}

function recoveryDefinition(options = {}) {
  const template = compileTemplate('infra/ci-runner/auto-recovery.bicep');
  return expandRecoveryWorkflow(template, options).definition;
}

async function runRecovery(vms, options = {}) {
  const definition = recoveryDefinition(options);
  const arm = new MockArm({
    vms,
    failListScaleSets: options.failListScaleSets,
    nextLinkScaleSets: options.nextLinkScaleSets,
  });
  return runWorkflow(definition, arm);
}

function sorted(values) {
  return [...values].sort();
}

test('starts exactly the managed live runners measured after MCAPS teardown and skips exclusions', async () => {
  const result = await runRecovery(liveTopology());
  const expected = config.inventory.managedRunnerBindings.map((binding) => binding.virtualMachineName);
  const excluded = new Set([
    ...config.inventory.forbiddenVirtualMachines,
    ...config.inventory.externalVirtualMachines,
  ].map((name) => name.toLowerCase()));

  assert.equal(result.status, 'Succeeded');
  assert.deepEqual([...result.branches.values()], ['then', 'then', 'then']);
  assert.deepEqual(sorted(result.requests.filter((request) => request.method === 'POST').map((request) => request.name)), sorted(expected));
  for (const name of result.requests.filter((request) => request.method === 'POST').map((request) => request.name)) {
    assert.ok(!excluded.has(name.toLowerCase()), `${name} must not be excluded`);
  }
});

test('discovers, starts, and verifies a replacement PR instance absent from every static list', async () => {
  const replacement = 'vmss-certigo-pr-v2-z1_0123abcd';
  const result = await runRecovery([
    ...liveTopology(),
    vm(replacement, 'vmss-certigo-pr-v2-z1'),
  ]);

  assert.equal(result.status, 'Succeeded');
  assert.ok(result.requests.filter((request) => request.method === 'POST').some((request) => request.name === replacement));
});

test('fails loudly when a non-excluded runner cannot be started and remains deallocated', async () => {
  const broken = 'vmss-certigo-pr-v2-z1_0123abcd';
  const result = await runRecovery([
    ...liveTopology(),
    vm(broken, 'vmss-certigo-pr-v2-z1', { onStart: 'fail' }),
  ]);
  const expectedOtherStarts = config.inventory.managedRunnerBindings.map((binding) => binding.virtualMachineName);

  assert.equal(result.status, 'Failed');
  assert.equal(result.error.code, 'RunnerPowerStateNotRunning');
  assert.match(result.error.message, new RegExp(broken));
  // Retired instances are excluded from the verification as well as from the start.
  assert.doesNotMatch(result.error.message, /22f7fb52|vmss-certigo-pr-pilot-z1_/);
  assert.equal(result.actions.get('Start_each_instance_of_vmss_certigo_runner_zonal').status, 'Succeeded');
  assert.equal(result.actions.get('Start_each_instance_of_vmss_certigo_pr_v2_z1').status, 'Failed');
  for (const name of expectedOtherStarts) {
    assert.ok(result.requests.filter((request) => request.method === 'POST').some((request) => request.name === name), `${name} was not started`);
  }
});

test('fails the redundancy floor when PR managed instances are excluded but still starts trusted runners', async () => {
  const prManaged = config.inventory.managedRunnerBindings
    .map((binding) => binding.virtualMachineName)
    .filter((name) => name.startsWith('vmss-certigo-pr-v2-z1_'));
  const result = await runRecovery(liveTopology(), {
    moduleParameters: {
      excludedVirtualMachineNames: [
        ...config.inventory.forbiddenVirtualMachines,
        ...config.inventory.externalVirtualMachines,
        ...prManaged,
      ],
    },
  });

  assert.equal(result.status, 'Failed');
  assert.equal(result.error.code, 'RunnerPoolBelowRedundancyFloor');
  assert.deepEqual(
    sorted(result.requests.filter((request) => request.method === 'POST').map((request) => request.name)),
    sorted(['vmss-certigo-runner-zonal_f55d176e', 'vmss-certigo-runner-zonal_be505fa1']),
  );
});

test('fails with RunnerEnumerationIncomplete when ARM returns a nextLink', async () => {
  const result = await runRecovery(liveTopology(), {
    nextLinkScaleSets: ['vmss-certigo-pr-v2-z1'],
  });

  assert.equal(result.status, 'Failed');
  assert.equal(result.error.code, 'RunnerEnumerationIncomplete');
});

test('still starts trusted runners when the PR pool list returns 403 and marks the run failed', async () => {
  const result = await runRecovery(liveTopology(), {
    failListScaleSets: ['vmss-certigo-pr-v2-z1'],
  });

  assert.equal(result.status, 'Failed');
  assert.deepEqual(
    sorted(result.requests.filter((request) => request.method === 'POST').map((request) => request.name)),
    sorted(['vmss-certigo-runner-zonal_f55d176e', 'vmss-certigo-runner-zonal_be505fa1']),
  );
});

test('matches upper-case exclusions case-insensitively', async () => {
  const excluded = 'vmss-certigo-pr-v2-z1_0123abcd';
  const result = await runRecovery([
    ...liveTopology(),
    vm(excluded, 'vmss-certigo-pr-v2-z1'),
  ], {
    moduleParameters: {
      excludedVirtualMachineNames: [
        ...config.inventory.forbiddenVirtualMachines,
        ...config.inventory.externalVirtualMachines,
        excluded.toUpperCase(),
      ],
    },
  });

  assert.equal(result.status, 'Succeeded');
  assert.ok(!result.requests.filter((request) => request.method === 'POST').some((request) => request.name === excluded));
});

test('succeeds without assertion else branches when every managed instance is already running', async () => {
  const result = await runRecovery(liveTopology(Object.fromEntries(
    config.inventory.managedRunnerBindings.map((binding) => [binding.virtualMachineName, { power: 'running' }]),
  )));

  assert.equal(result.status, 'Succeeded');
  assert.deepEqual([...result.branches.values()], ['then', 'then', 'then']);
});

test('compiled workflow has no per-instance coupling and authenticates every HTTP action with MSI', () => {
  const composition = compileTemplate('infra/ci-runner/auto-recovery.bicep');
  const { definition, moduleTemplate } = expandRecoveryWorkflow(composition);
  const excluded = new Set([
    ...config.inventory.forbiddenVirtualMachines,
    ...config.inventory.externalVirtualMachines,
  ]);

  const assertNoTerminateInForeach = (actions) => {
    for (const action of Object.values(actions ?? {})) {
      if (action.type === 'Foreach') {
        assert.ok(!JSON.stringify(action.actions ?? {}).includes('Terminate'), 'Terminate must not be inside a Foreach');
      }
      assertNoTerminateInForeach(action.actions);
      assertNoTerminateInForeach(action.else?.actions);
    }
  };
  const assertHttpMsi = (actions) => {
    for (const action of Object.values(actions ?? {})) {
      if (action.type === 'Http') assert.equal(action.inputs.authentication?.type, 'ManagedServiceIdentity');
      assertHttpMsi(action.actions);
      assertHttpMsi(action.else?.actions);
    }
  };

  assertNoTerminateInForeach(definition.actions);
  assertHttpMsi(definition.actions);
  // The real engine rejects a zero-argument createArray() (InvalidTemplate, run
  // 08584114192689525938465393788CU124): it must never appear, even behind a coalesce.
  assert.doesNotMatch(JSON.stringify(definition), /createArray\(\s*\)/);
  assert.equal(JSON.stringify(moduleTemplate).match(/vmss-certigo-[a-z0-9-]+_[0-9a-f]{8}/g), null);
  const compositionMatches = JSON.stringify(composition).match(/vmss-certigo-[a-z0-9-]+_[0-9a-f]{8}/g) ?? [];
  for (const match of compositionMatches) assert.ok(excluded.has(match), `${match} must only appear as exclusion data`);
});

test('the redundancy floor is not vacuous: a floor above the live PR capacity fails the run', async () => {
  const result = await runRecovery(liveTopology(), {
    moduleParameters: {
      scaleSets: [
        { name: 'vmss-certigo-runner-zonal', minimumRunning: 2 },
        { name: 'vmss-certigo-pr-v2-z1', minimumRunning: 5 },
      ],
    },
  });

  assert.equal(result.status, 'Failed');
  assert.equal(result.error.code, 'RunnerPoolBelowRedundancyFloor');
  assert.match(result.error.message, /vmss-certigo-pr-v2-z1 : 4 running pour un minimum de 5/);
  assert.match(result.error.message, /vmss-certigo-runner-zonal : 2 running pour un minimum de 2/);
});

test('mutation control: without the exclusion filter a forbidden recovered instance would be started', async () => {
  const definition = recoveryDefinition();
  definition.actions.Select_the_instances_to_start_in_vmss_certigo_runner_zonal.inputs.where = '@true';
  const result = await runWorkflow(definition, new MockArm({ vms: liveTopology() }));
  const started = result.requests.filter((request) => request.method === 'POST').map((request) => request.name);

  assert.ok(
    started.includes('vmss-certigo-runner-zonal_22f7fb52'),
    'the mutation must prove the recovered-scale-set exclusion filter blocks forbidden instances',
  );
});

test('old PR pilot pool is never listed or started by recovery', async () => {
  const result = await runRecovery(liveTopology());
  const requests = result.requests.map((request) => ({
    method: request.method,
    name: request.name ?? '',
    uri: request.uri,
  }));

  assert.equal(result.status, 'Succeeded');
  assert.ok(
    requests
      .filter((request) => request.method === 'GET')
      .every((request) => !request.uri.includes('vmss-certigo-pr-pilot-z1')),
    'the retired PR scale set must not be enumerated',
  );
  assert.ok(
    requests
      .filter((request) => request.method === 'POST')
      .every((request) => !request.name.startsWith('vmss-certigo-pr-pilot-z1_')),
    'retired PR instances must not be started',
  );
});

test('positive control: a tiny workflow terminates through an If else branch', async () => {
  const arm = new MockArm({ vms: [] });
  const result = await runWorkflow({
    parameters: {},
    actions: {
      Must_take_else: {
        type: 'If',
        runAfter: {},
        expression: { equals: [1, 2] },
        actions: {},
        else: {
          actions: {
            Fail_from_else: {
              type: 'Terminate',
              runAfter: {},
              inputs: {
                runStatus: 'Failed',
                runError: { code: 'PositiveControl', message: 'else branch executed' },
              },
            },
          },
        },
      },
    },
  }, arm);

  assert.equal(result.status, 'Failed');
  assert.equal(result.error.code, 'PositiveControl');
  assert.equal(result.branches.get('Must_take_else'), 'else');
});
