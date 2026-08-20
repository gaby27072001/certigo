import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import { evaluateLifecycle } from './evaluate-lifecycle.mjs';

const config = JSON.parse(
  readFileSync(
    new URL('./capacity-controller.config.json', import.meta.url),
    'utf8',
  ),
);
const f55VmName = 'vmss-certigo-runner-zonal_f55d176e';
const f55VmId =
  '/subscriptions/b8952c8c-8f72-469d-99cd-ac906da4e2fc/' +
  'resourceGroups/RG-CERTIGO-CI/providers/Microsoft.Compute/' +
  `virtualMachines/${f55VmName}`;

function runner(
  name,
  labels,
  { busy = false, id, status = 'online' } = {},
) {
  return {
    ...(id === undefined ? {} : { id }),
    name,
    labels: labels.map((label) => ({ name: label })),
    busy,
    status,
  };
}

function scaleSet(name, subnet, identity = `/identities/${name}`) {
  return {
    name,
    identity: identity
      ? { userAssignedIdentities: { [identity]: {} } }
      : {},
    virtualMachineProfile: {
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            properties: {
              ipConfigurations: [
                {
                  properties: {
                    subnet: { id: subnet },
                  },
                },
              ],
            },
          },
        ],
      },
    },
  };
}

test('deallocation is blocked for the observed dual-label busy autoscaled pool', () => {
  const result = evaluateLifecycle({
    config,
    operation: 'deallocate',
    runners: {
      runners: [
        runner('runner-a', ['certigo-pr', 'certigo-trusted'], { busy: true }),
        runner('runner-b', ['certigo-pr', 'certigo-trusted']),
      ],
    },
    queuedRuns: { total_count: 10 },
    activeRuns: { total_count: 1 },
    autoscale: {
      enabled: true,
      profiles: [
        {
          rules: [{ scaleAction: { direction: 'Decrease' } }],
        },
      ],
    },
    virtualMachines: [{ name: 'vm-a' }, { name: 'vm-b' }, { name: 'vm-c' }],
    vmScaleSets: [
      scaleSet('pool-shared', '/networks/shared/subnets/runners'),
    ],
  });

  assert.equal(result.preflightOnly, true);
  assert.equal(result.safeToRequestChange, false);
  assert.ok(result.reasons.some((reason) => reason.startsWith('dual trust labels')));
  assert.ok(result.reasons.includes('CPU autoscale contains an unsafe scale-in rule'));
  assert.ok(result.reasons.includes('queued workflow runs: 10'));
  assert.ok(result.reasons.includes('active workflow runs: 1'));
});

test('feature-off blocks an otherwise valid start preflight', () => {
  const result = evaluateLifecycle({
    config,
    operation: 'start',
    runners: {
      runners: [
        runner('vm-pr-Certigo', ['certigo-pr']),
        runner('vm-trusted-Certigo', ['certigo-trusted']),
      ],
    },
    queuedRuns: { total_count: 0 },
    activeRuns: { total_count: 0 },
    autoscale: { enabled: false, profiles: [] },
    virtualMachines: [
      {
        name: 'vm-pr',
        powerState: 'VM deallocated',
        virtualMachineScaleSet: { id: '/vmss/pool-pr' },
      },
      {
        name: 'vm-trusted',
        powerState: 'VM deallocated',
        virtualMachineScaleSet: { id: '/vmss/pool-trusted' },
      },
    ],
    vmScaleSets: [
      scaleSet('pool-pr', '/networks/pr/subnets/runners', null),
      scaleSet(
        'pool-trusted',
        '/networks/trusted/subnets/runners',
        '/identities/trusted',
      ),
    ],
  });

  assert.equal(result.safeToRequestChange, false);
  assert.ok(
    result.reasons.includes('capacity controller feature flag is off'),
  );
});

test('idle exclusive pools require five minutes, two guards, then arm reactivation', () => {
  const start = Date.parse('2026-08-20T06:00:00Z');
  const input = {
    config: { ...config, enabled: true },
    operation: 'deallocate',
    runners: {
      runners: [
        runner('vm-pr-Certigo', ['certigo-pr']),
        runner('vm-trusted-Certigo', ['certigo-trusted']),
      ],
    },
    queuedRuns: { total_count: 0 },
    activeRuns: { total_count: 0 },
    autoscale: {
      enabled: false,
      profiles: [],
    },
    virtualMachines: [
      {
        name: 'vm-pr',
        powerState: 'VM running',
        virtualMachineScaleSet: { id: '/vmss/pool-pr' },
      },
      {
        name: 'vm-trusted',
        powerState: 'VM running',
        virtualMachineScaleSet: { id: '/vmss/pool-trusted' },
      },
    ],
    vmScaleSets: [
      scaleSet('pool-pr', '/networks/pr/subnets/runners', null),
      scaleSet(
        'pool-trusted',
        '/networks/trusted/subnets/runners',
        '/identities/trusted',
      ),
    ],
  };

  const quietStarted = evaluateLifecycle({ ...input, now: start });
  assert.equal(quietStarted.safeToRequestChange, false);
  assert.equal(quietStarted.safety.guardCount, 0);

  const firstGuard = evaluateLifecycle({
    ...input,
    now: start + 300_000,
    state: quietStarted.nextState,
  });
  assert.equal(firstGuard.safeToRequestChange, false);
  assert.equal(firstGuard.safety.guardCount, 1);

  const secondGuard = evaluateLifecycle({
    ...input,
    now: start + 301_000,
    state: firstGuard.nextState,
  });
  assert.equal(secondGuard.safeToRequestChange, true);
  assert.deepEqual(secondGuard.reasons, []);
  assert.equal(secondGuard.safety.guardCount, 2);
  assert.deepEqual(
    secondGuard.nextState.scaleInSafety.rearmTargetCapacityByTrust,
    {
      'certigo-pr': 1,
      'certigo-trusted': 1,
    },
  );
  assert.equal(secondGuard.nextState.scaleInSafety.guardCount, 0);

  const stoppedInput = structuredClone(input);
  stoppedInput.runners.runners[1].status = 'offline';
  stoppedInput.virtualMachines[1].powerState = 'VM deallocated';
  const activity = evaluateLifecycle({
    ...stoppedInput,
    now: start + 302_000,
    queuedRuns: { total_count: 1 },
    state: secondGuard.nextState,
  });
  assert.equal(activity.safeToRequestChange, false);
  assert.equal(activity.safety.quietReset, false);
  assert.equal(activity.safety.rearmRequired, true);
  assert.ok(
    activity.reasons.includes(
      'post-scale-in activity requires managed capacity rearm',
    ),
  );
});

test('equal VM and runner counts still fail when their names do not reconcile', () => {
  const result = evaluateLifecycle({
    config,
    operation: 'deallocate',
    runners: {
      runners: [
        runner(
          'vmss-certigo-runner-zonal_22f7fb52-Certigo',
          ['certigo-pr'],
          { status: 'offline' },
        ),
        runner(
          'vmss-certigo-runner-zonal_f55d176e-Certigo',
          ['certigo-trusted'],
          { id: 27 },
        ),
      ],
    },
    queuedRuns: { total_count: 0 },
    activeRuns: { total_count: 0 },
    autoscale: {
      enabled: false,
      profiles: [],
    },
    virtualMachines: [
      { name: 'vmss-certigo-runner-zonal_4153d1dd' },
      {
        id: f55VmId,
        name: f55VmName,
        powerState: 'VM running',
        virtualMachineScaleSet: {
          id: '/vmss/vmss-certigo-runner-zonal',
        },
      },
    ],
    vmScaleSets: [
      scaleSet(
        'vmss-certigo-runner-zonal',
        '/networks/live/subnets/runners',
      ),
    ],
  });

  assert.equal(result.safeToRequestChange, false);
  assert.ok(
    result.reasons.some((reason) => reason.includes('22f7fb52-Certigo')),
  );
  assert.deepEqual(result.observed.managedMachineNames, [
    'vmss-certigo-runner-zonal_f55d176e',
  ]);
  assert.deepEqual(result.observed.externalVirtualMachines, [
    'vmss-certigo-runner-zonal_4153d1dd',
  ]);
});

test('unknown lifecycle operations fail closed', () => {
  assert.throws(
    () =>
      evaluateLifecycle({
        config,
        operation: 'delete',
        runners: { runners: [] },
        queuedRuns: { total_count: 0 },
        activeRuns: { total_count: 0 },
        autoscale: {},
        virtualMachines: [],
        vmScaleSets: [],
      }),
    /Unsupported lifecycle operation/,
  );
});
