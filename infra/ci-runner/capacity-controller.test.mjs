import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import {
  createCapacityPlan,
  reduceWorkflowJobState,
} from './capacity-controller.mjs';
import { reconcileRunnerDrift } from './reconcile-drift.mjs';
import { reconcileRunnerInstances } from './runner-inventory.mjs';

const config = JSON.parse(
  readFileSync(
    new URL('./capacity-controller.config.json', import.meta.url),
    'utf8',
  ),
);

function runner(
  name,
  labels,
  { busy = false, status = 'online' } = {},
) {
  return {
    name,
    busy,
    status,
    labels: labels.map((label) => ({ name: label })),
  };
}

function inventory({
  active = 0,
  busy = false,
  capacity = 2,
  dualTrust = false,
  poweredCapacity = capacity,
  queued = 0,
  vmScaleSetCount = 2,
} = {}) {
  const labels = dualTrust
    ? ['certigo-pr', 'certigo-trusted']
    : ['certigo-pr'];
  const virtualMachines = Array.from({ length: capacity }, (_, index) => ({
    name: `vm-${index}`,
    powerState:
      index < poweredCapacity ? 'VM running' : 'VM deallocated',
    virtualMachineScaleSet: {
      id:
        `/subscriptions/example/resourceGroups/rg/providers/` +
        `Microsoft.Compute/virtualMachineScaleSets/pool-${index % vmScaleSetCount}`,
    },
  }));
  return {
    runners: {
      activeRuns: { total_count: active },
      queuedRuns: { total_count: queued },
      github: {
        runners: virtualMachines.map((virtualMachine, index) =>
          runner(
            `${virtualMachine.name}-Certigo`,
            dualTrust
              ? labels
              : [index % 2 === 0 ? 'certigo-pr' : 'certigo-trusted'],
            {
              busy,
              status: index < poweredCapacity ? 'online' : 'offline',
            },
          ),
        ),
      },
      virtualMachines,
      vmScaleSets: Array.from({ length: vmScaleSetCount }, (_, index) => ({
        name: `pool-${index}`,
        identity: {
          userAssignedIdentities: {
            [`/identities/pool-${index}`]: {},
          },
        },
        virtualMachineProfile: {
          networkProfile: {
            networkInterfaceConfigurations: [
              {
                properties: {
                  ipConfigurations: [
                    {
                      properties: {
                        subnet: {
                          id: `/networks/runner-${index}/subnets/default`,
                        },
                      },
                    },
                  ],
                },
              },
            ],
          },
        },
      })),
    },
  };
}

test('workflow_job events maintain queue state without writing it', () => {
  const now = Date.parse('2026-08-19T12:00:00Z');
  const queued = reduceWorkflowJobState(
    { jobs: {} },
    {
      action: 'queued',
      workflow_job: {
        id: 42,
        labels: ['self-hosted', 'certigo-pr'],
        created_at: '2026-08-19T11:59:00Z',
      },
    },
    now,
  );
  assert.equal(queued.jobs['42'].status, 'queued');

  const active = reduceWorkflowJobState(
    queued,
    {
      action: 'in_progress',
      workflow_job: {
        id: 42,
        labels: ['self-hosted', 'certigo-pr'],
      },
    },
    now,
  );
  assert.equal(active.jobs['42'].status, 'in_progress');

  const waiting = reduceWorkflowJobState(
    active,
    {
      action: 'waiting',
      workflow_job: {
        id: 42,
        labels: ['self-hosted', 'certigo-pr'],
      },
    },
    now,
  );
  assert.equal(waiting.jobs['42'].status, 'waiting');
  const waitingPlan = createCapacityPlan({
    config,
    inventory: inventory(),
    state: waiting,
  });
  assert.equal(waitingPlan.mode, 'idle');

  const completed = reduceWorkflowJobState(
    waiting,
    {
      action: 'completed',
      workflow_job: {
        id: 42,
        labels: ['self-hosted', 'certigo-pr'],
      },
    },
    now,
  );
  assert.deepEqual(completed.jobs, {});
});

test('backlog selects the future six PR plus two trusted pilot target while feature stays off', () => {
  const plan = createCapacityPlan({
    config,
    inventory: inventory({ queued: 3, busy: true }),
  });

  assert.equal(plan.mode, 'boost');
  assert.equal(plan.targetCapacity, 8);
  assert.deepEqual(plan.targetCapacityByTrust, {
    'certigo-pr': 6,
    'certigo-trusted': 2,
  });
  assert.equal(plan.targetTrustClass, 'certigo-pr');
  assert.equal(plan.nextCapacity, 3);
  assert.equal(plan.featureEnabled, false);
  assert.equal(plan.canRequestChange, false);
  assert.ok(plan.blockers.includes('capacity controller feature flag is off'));
  assert.equal(config.observedBaseline30Days.queueP99Seconds, 12628);
  assert.equal('maxAggregateCapacity' in config, false);
});

test('an enabled future controller still requires a lease and increments by one', () => {
  const withoutLease = createCapacityPlan({
    config: { ...config, enabled: true },
    inventory: inventory({ queued: 3 }),
  });
  assert.equal(withoutLease.action, 'scale-out-one');
  assert.equal(withoutLease.nextCapacity, 3);
  assert.equal(withoutLease.canRequestChange, false);

  const withLease = createCapacityPlan({
    config: { ...config, enabled: true },
    inventory: inventory({ queued: 3 }),
    leaseHeld: true,
  });
  assert.equal(withLease.nextCapacity, 3);
  assert.equal(withLease.canRequestChange, true);
});

test('a queued trusted job selects trusted capacity before the larger PR deficit', () => {
  const now = Date.parse('2026-08-20T06:00:00Z');
  const state = {
    jobs: {
      '41': {
        labels: ['self-hosted', 'certigo-trusted'],
        queuedAt: new Date(now - 1_000).toISOString(),
        status: 'queued',
      },
      '42': {
        labels: ['self-hosted', 'certigo-trusted'],
        queuedAt: new Date(now - 500).toISOString(),
        status: 'queued',
      },
    },
  };
  const plan = createCapacityPlan({
    config,
    inventory: inventory(),
    now,
    state,
  });

  assert.equal(plan.mode, 'boost');
  assert.equal(plan.targetTrustClass, 'certigo-trusted');
  assert.deepEqual(plan.workload.queuedByTrust, {
    'certigo-pr': 0,
    'certigo-trusted': 2,
  });
});

test('scale-in requires a resettable five-minute quiet period, two guards, and rearm', () => {
  const enabledConfig = { ...config, enabled: true };
  const start = Date.parse('2026-08-20T06:00:00Z');
  const quietStarted = createCapacityPlan({
    config: enabledConfig,
    inventory: inventory({ capacity: 4 }),
    leaseHeld: true,
    now: start,
  });
  assert.equal(quietStarted.action, 'hold');
  assert.equal(quietStarted.safety.quietComplete, false);

  const activityReset = createCapacityPlan({
    config: enabledConfig,
    inventory: inventory({ active: 1, capacity: 4 }),
    leaseHeld: true,
    now: start + 299_000,
    state: quietStarted.nextState,
  });
  assert.equal(activityReset.action, 'hold');
  assert.equal(activityReset.safety.quietReset, true);
  assert.equal(activityReset.nextState.scaleInSafety.quietSince, null);

  const quietRestarted = createCapacityPlan({
    config: enabledConfig,
    inventory: inventory({ capacity: 4 }),
    leaseHeld: true,
    now: start + 300_000,
    state: activityReset.nextState,
  });
  const firstGuard = createCapacityPlan({
    config: enabledConfig,
    inventory: inventory({ capacity: 4 }),
    leaseHeld: true,
    now: start + 600_000,
    state: quietRestarted.nextState,
  });
  assert.equal(firstGuard.action, 'hold');
  assert.equal(firstGuard.safety.guardCount, 1);

  const secondGuard = createCapacityPlan({
    config: enabledConfig,
    inventory: inventory({ capacity: 4 }),
    leaseHeld: true,
    now: start + 601_000,
    state: firstGuard.nextState,
  });
  assert.equal(secondGuard.scaleInSafe, true);
  assert.equal(secondGuard.action, 'scale-in-one');
  assert.equal(secondGuard.nextCapacity, 3);
  assert.equal(secondGuard.safety.guardCount, 2);
  assert.equal(secondGuard.nextState.scaleInSafety.rearmArmed, true);
  assert.equal(secondGuard.nextState.scaleInSafety.guardCount, 0);
  assert.equal(secondGuard.nextState.scaleInSafety.quietSince, null);

  const rearm = createCapacityPlan({
    config: enabledConfig,
    inventory: inventory({
      capacity: 2,
      poweredCapacity: 1,
      queued: 1,
    }),
    leaseHeld: true,
    now: start + 602_000,
    state: secondGuard.nextState,
  });
  assert.equal(rearm.action, 'scale-out-one');
  assert.equal(rearm.safety.quietReset, false);
  assert.equal(rearm.safety.rearmRequired, true);
});

test('forged quiet-period guard state fails closed', () => {
  const now = Date.parse('2026-08-20T06:10:00Z');
  assert.throws(
    () =>
      createCapacityPlan({
        config: { ...config, enabled: true },
        inventory: inventory({ capacity: 4 }),
        leaseHeld: true,
        now,
        state: {
          jobs: {},
          scaleInSafety: {
            guardCount: 2,
            lastGuardAt: null,
            quietSince: new Date(now - 300_000).toISOString(),
            rearmArmed: false,
          },
        },
      }),
    /guards require quietSince and lastGuardAt/,
  );
});

test('dual trust labels and one VMSS block every capacity request', () => {
  const plan = createCapacityPlan({
    config,
    inventory: inventory({
      capacity: 3,
      dualTrust: true,
      queued: 3,
      vmScaleSetCount: 1,
    }),
  });
  assert.equal(plan.action, 'hold');
  assert.equal(plan.canRequestChange, false);
  assert.equal(plan.trust.dualTrustRunners.length, 3);
});

test('shared runner subnets block every capacity request', () => {
  const live = inventory({ queued: 3 });
  const sharedSubnet =
    live.runners.vmScaleSets[0].virtualMachineProfile.networkProfile
      .networkInterfaceConfigurations[0].properties.ipConfigurations[0]
      .properties.subnet.id;
  live.runners.vmScaleSets[1].virtualMachineProfile.networkProfile
    .networkInterfaceConfigurations[0].properties.ipConfigurations[0]
    .properties.subnet.id = sharedSubnet;

  const plan = createCapacityPlan({
    config: { ...config, enabled: true },
    inventory: live,
    leaseHeld: true,
  });

  assert.equal(plan.action, 'hold');
  assert.equal(plan.canRequestChange, false);
  assert.deepEqual(plan.trust.sharedSubnetIds, [
    sharedSubnet.toLowerCase(),
  ]);
});

test('an unused external VMSS cannot satisfy managed pool separation', () => {
  const live = inventory({ queued: 3 });
  for (const virtualMachine of live.runners.virtualMachines) {
    virtualMachine.virtualMachineScaleSet.id =
      '/subscriptions/example/resourceGroups/rg/providers/' +
      'Microsoft.Compute/virtualMachineScaleSets/pool-0';
  }

  const plan = createCapacityPlan({
    config: { ...config, enabled: true },
    inventory: live,
    leaseHeld: true,
  });

  assert.equal(plan.action, 'hold');
  assert.equal(plan.canRequestChange, false);
  assert.deepEqual(plan.trust.managedPoolNames, ['pool-0']);
  assert.deepEqual(plan.trust.poolsWithMixedTrustLabels, ['pool-0']);
  assert.equal(plan.trust.vmScaleSetCount, 2);
});

test('an unmatched VM without explicit external classification fails closed', () => {
  const live = inventory({ queued: 3 });
  live.runners.virtualMachines.push({
    name: 'vmss-certigo-pr_unexpected',
    powerState: 'VM running',
  });

  const plan = createCapacityPlan({
    config: { ...config, enabled: true },
    inventory: live,
    leaseHeld: true,
  });

  assert.equal(plan.action, 'hold');
  assert.equal(plan.canRequestChange, false);
  assert.deepEqual(plan.trust.unclassifiedVirtualMachines, [
    'vmss-certigo-pr_unexpected',
  ]);
});

test('real inventory classifies 22f absent, f55 managed, and 415 external', () => {
  const result = reconcileRunnerInstances(
    [
      { name: 'vmss-certigo-runner-zonal_4153d1dd' },
      { name: 'vmss-certigo-runner-zonal_f55d176e' },
    ],
    [
      runner(
        'vmss-certigo-runner-zonal_22f7fb52-Certigo',
        ['certigo-pr'],
        { status: 'offline' },
      ),
      runner(
        'vmss-certigo-runner-zonal_f55d176e-Certigo',
        ['certigo-trusted'],
      ),
    ],
    config.inventory,
  );

  assert.deepEqual(result.absentRunners, [
    'vmss-certigo-runner-zonal_22f7fb52-Certigo',
  ]);
  assert.deepEqual(result.managedMachineNames, [
    'vmss-certigo-runner-zonal_f55d176e',
  ]);
  assert.deepEqual(result.externalVirtualMachines, [
    'vmss-certigo-runner-zonal_4153d1dd',
  ]);
});

test('drift reconciliation reports live VMSS, SKU, CPU scale-in, and labels', () => {
  const live = inventory({
    capacity: 3,
    dualTrust: true,
    vmScaleSetCount: 1,
  });
  live.runners.vmScaleSets[0] = {
    name: 'vmss-certigo-runner-zonal',
    orchestrationMode: 'Flexible',
    sku: { name: 'Standard_D2ads_v6' },
    identity: {
      userAssignedIdentities: {
        '/identities/shared': {},
      },
    },
    virtualMachineProfile: {
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            properties: {
              ipConfigurations: [
                {
                  properties: {
                    subnet: {
                      id: '/networks/live/subnets/shared',
                    },
                  },
                },
              ],
            },
          },
        ],
      },
    },
  };
  live.runners.autoscaleSettings = [
    {
      profiles: [
        {
          rules: [{ scaleAction: { direction: 'Decrease' } }],
        },
      ],
    },
  ];
  live.runners.virtualMachines = [
    {
      name: 'vmss-certigo-runner-zonal_4153d1dd',
      powerState: 'VM deallocated',
    },
    {
      name: 'vmss-certigo-runner-zonal_f55d176e',
      powerState: 'VM running',
    },
  ];
  live.runners.github.runners = [
    runner(
      'vmss-certigo-runner-zonal_22f7fb52-Certigo',
      ['certigo-pr', 'certigo-trusted'],
    ),
    {
      ...runner(
        'vmss-certigo-runner-zonal_f55d176e-Certigo',
        ['certigo-pr', 'certigo-trusted'],
      ),
      status: 'online',
    },
  ];

  const result = reconcileRunnerDrift(
    live,
    "param vmSize string = 'Standard_D4s_v5'\nresource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {}",
    config,
  );
  assert.equal(result.readOnly, true);
  assert.deepEqual(
    result.findings.map((finding) => finding.code).sort(),
    [
      'ABSENT_RUNNER_DRIFT',
      'COMPUTE_MODEL_DRIFT',
      'CPU_SCALE_IN_DRIFT',
      'EXTERNAL_INSTANCE_OBSERVED',
      'POOL_IDENTITY_DRIFT',
      'POOL_SUBNET_DRIFT',
      'POOL_TRUST_BOUNDARY_DRIFT',
      'REDUNDANCY_DRIFT',
      'TRUST_LABEL_DRIFT',
      'VM_SIZE_DRIFT',
    ],
  );
  assert.equal(result.baseline30Days.costUsd, 242.06);
  assert.deepEqual(result.observed.absentRunners, [
    'vmss-certigo-runner-zonal_22f7fb52-Certigo',
  ]);
  assert.deepEqual(result.observed.managedMachineNames, [
    'vmss-certigo-runner-zonal_f55d176e',
  ]);
  assert.deepEqual(result.observed.externalVirtualMachines, [
    'vmss-certigo-runner-zonal_4153d1dd',
  ]);
});

test('configuration refuses a boost mode that differs from the pilot target', () => {
  assert.throws(
    () =>
      createCapacityPlan({
        config: {
          ...config,
          modes: {
            ...config.modes,
            boost: {
              'certigo-pr': 5,
              'certigo-trusted': 2,
            },
          },
        },
        inventory: inventory(),
      }),
    /boost mode must equal the approved pilot target/,
  );
});
