import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import {
  createCapacityPlan,
  reduceWorkflowJobState,
} from './capacity-controller.mjs';
import { reconcileRunnerDrift } from './reconcile-drift.mjs';
import { reconcileRunnerInstances } from './runner-inventory.mjs';

const repositoryConfig = JSON.parse(
  readFileSync(
    new URL('./capacity-controller.config.json', import.meta.url),
    'utf8',
  ),
);
const capacityTemplate = readFileSync(
  new URL('./capacity.bicep', import.meta.url),
  'utf8',
);
const config = {
  ...repositoryConfig,
  inventory: {
    ...repositoryConfig.inventory,
    managedRunnerBindings: [],
  },
};
const f55VmName = 'vmss-certigo-runner-zonal_f55d176e';
const f55VmId =
  '/subscriptions/b8952c8c-8f72-469d-99cd-ac906da4e2fc/' +
  'resourceGroups/RG-CERTIGO-CI/providers/Microsoft.Compute/' +
  `virtualMachines/${f55VmName}`;
const pilotVmName = 'vmss-certigo-pr-pilot-z1_bbf83c5c';
const pilotVmId =
  '/subscriptions/b8952c8c-8f72-469d-99cd-ac906da4e2fc/' +
  'resourceGroups/RG-CERTIGO-CI/providers/Microsoft.Compute/' +
  `virtualMachines/${pilotVmName}`;
// The second PR runner bought in #402. The fixture carries it because the
// redundancy floor is now two per trust class: a fixture stuck on the
// pre-scale-out fleet would make a satisfied floor look like a shortfall.
const pilot2VmName = 'vmss-certigo-pr-pilot-z1_a14700a3';
const pilot2VmId =
  '/subscriptions/b8952c8c-8f72-469d-99cd-ac906da4e2fc/' +
  'resourceGroups/RG-CERTIGO-CI/providers/Microsoft.Compute/' +
  `virtualMachines/${pilot2VmName}`;

function runner(
  name,
  labels,
  { busy = false, id, status = 'online' } = {},
) {
  return {
    ...(id === undefined ? {} : { id }),
    name,
    busy,
    status,
    labels: labels.map((label) => ({ name: label })),
  };
}

function leaseFence(state = {}) {
  return {
    leaseGeneration: 7,
    leaseHeld: true,
    persistedStateRevision: state.revision ?? 0,
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

function reconciledCapacityInventory() {
  const live = inventory();
  const legacyId =
    '/subscriptions/example/resourceGroups/RG-CERTIGO-CI/providers/' +
    'Microsoft.Compute/virtualMachineScaleSets/vmss-certigo-runner-zonal';
  live.runners.vmScaleSets = live.runners.vmScaleSets.map(
    (scaleSet, index) => ({
      ...scaleSet,
      id:
        index === 0
          ? legacyId
          : '/subscriptions/example/resourceGroups/RG-CERTIGO-CI/providers/' +
            'Microsoft.Compute/virtualMachineScaleSets/vmss-certigo-pr-pilot-z1',
      name:
        index === 0
          ? 'vmss-certigo-runner-zonal'
          : 'vmss-certigo-pr-pilot-z1',
      orchestrationMode: 'Flexible',
      sku: { name: 'Standard_D2ads_v6' },
    }),
  );
  live.runners.autoscaleSettings = [
    {
      enabled: true,
      name: 'autoscale-vmss-certigo-runner-zonal',
      predictiveAutoscalePolicy: { scaleMode: 'Disabled' },
      targetResourceUri: legacyId,
      profiles: [
        {
          name: 'default',
          capacity: {
            minimum: '2',
            default: '2',
            maximum: '4',
          },
          rules: [
            {
              metricTrigger: {
                metricName: 'Percentage CPU',
                metricNamespace: '',
                metricResourceUri: legacyId,
                operator: 'GreaterThan',
                statistic: 'Average',
                threshold: 70,
                timeAggregation: 'Average',
                timeGrain: 'PT1M',
                timeWindow: 'PT10M',
                dividePerInstance: false,
              },
              scaleAction: {
                cooldown: 'PT10M',
                direction: 'Increase',
                type: 'ChangeCount',
                value: '1',
              },
            },
          ],
        },
      ],
    },
  ];
  return live;
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

  const withoutPersistedRevision = createCapacityPlan({
    config: { ...config, enabled: true },
    inventory: inventory({ queued: 3 }),
    leaseGeneration: 7,
    leaseHeld: true,
  });
  assert.equal(withoutPersistedRevision.canRequestChange, false);
  assert.ok(
    withoutPersistedRevision.blockers.includes(
      'the persisted capacity state revision is required before any mutable action',
    ),
  );

  const withLease = createCapacityPlan({
    config: { ...config, enabled: true },
    inventory: inventory({ queued: 3 }),
    ...leaseFence(),
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

test('a powered runner that is offline remains a usable-capacity deficit', () => {
  const live = inventory({ queued: 1 });
  live.runners.github.runners[0].status = 'offline';
  const plan = createCapacityPlan({
    config: { ...config, enabled: true },
    inventory: live,
    ...leaseFence(),
  });

  assert.equal(plan.currentCapacityByTrust['certigo-pr'], 1);
  assert.equal(plan.usableCapacityByTrust['certigo-pr'], 0);
  assert.equal(plan.action, 'scale-out-one');
  assert.equal(plan.targetTrustClass, 'certigo-pr');
  assert.equal(plan.canRequestChange, true);
});

test('scale-in requires a resettable five-minute quiet period, two guards, and rearm', () => {
  const enabledConfig = { ...config, enabled: true };
  const start = Date.parse('2026-08-20T06:00:00Z');
  const quietStarted = createCapacityPlan({
    config: enabledConfig,
    inventory: inventory({ capacity: 4 }),
    ...leaseFence(),
    now: start,
  });
  assert.equal(quietStarted.action, 'hold');
  assert.equal(quietStarted.safety.quietComplete, false);

  const activityReset = createCapacityPlan({
    config: enabledConfig,
    inventory: inventory({ active: 1, capacity: 4 }),
    ...leaseFence(quietStarted.nextState),
    now: start + 299_000,
    state: quietStarted.nextState,
  });
  assert.equal(activityReset.action, 'hold');
  assert.equal(activityReset.safety.quietReset, true);
  assert.equal(activityReset.nextState.scaleInSafety.quietSince, null);

  const quietRestarted = createCapacityPlan({
    config: enabledConfig,
    inventory: inventory({ capacity: 4 }),
    ...leaseFence(activityReset.nextState),
    now: start + 300_000,
    state: activityReset.nextState,
  });
  const firstGuard = createCapacityPlan({
    config: enabledConfig,
    inventory: inventory({ capacity: 4 }),
    ...leaseFence(quietRestarted.nextState),
    now: start + 600_000,
    state: quietRestarted.nextState,
  });
  assert.equal(firstGuard.action, 'hold');
  assert.equal(firstGuard.safety.guardCount, 1);

  const secondGuard = createCapacityPlan({
    config: enabledConfig,
    inventory: inventory({ capacity: 4 }),
    ...leaseFence(firstGuard.nextState),
    now: start + 601_000,
    state: firstGuard.nextState,
  });
  assert.equal(secondGuard.scaleInSafe, true);
  assert.equal(secondGuard.action, 'scale-in-one');
  assert.equal(secondGuard.targetTrustClass, 'certigo-pr');
  assert.equal(secondGuard.nextCapacity, 3);
  assert.equal(secondGuard.safety.guardCount, 2);
  assert.deepEqual(
    secondGuard.nextState.scaleInSafety.rearmTargetCapacityByTrust,
    {
      'certigo-pr': 2,
      'certigo-trusted': 2,
    },
  );
  assert.equal(secondGuard.nextState.scaleInSafety.guardCount, 0);
  assert.equal(secondGuard.nextState.scaleInSafety.quietSince, null);

  const staleWatcher = createCapacityPlan({
    config: enabledConfig,
    inventory: inventory({ capacity: 4 }),
    ...leaseFence(firstGuard.nextState),
    now: start + 602_000,
    persistedStateRevision: secondGuard.nextState.revision,
    state: firstGuard.nextState,
  });
  assert.equal(staleWatcher.action, 'scale-in-one');
  assert.equal(staleWatcher.canRequestChange, false);
  assert.ok(
    staleWatcher.blockers.includes(
      'the capacity state revision is stale and must be reloaded before planning',
    ),
  );

  const busyFinalGuard = createCapacityPlan({
    config: enabledConfig,
    inventory: inventory({ busy: true, capacity: 4 }),
    ...leaseFence(firstGuard.nextState),
    now: start + 602_000,
    state: firstGuard.nextState,
  });
  assert.equal(busyFinalGuard.action, 'hold');
  assert.equal(busyFinalGuard.canRequestChange, false);
  assert.equal(busyFinalGuard.safety.quietReset, true);
  assert.equal(busyFinalGuard.nextState.scaleInSafety.quietSince, null);

  const afterPilotScaleIn = inventory({
    capacity: 4,
    poweredCapacity: 4,
  });
  afterPilotScaleIn.runners.virtualMachines[2].powerState = 'VM deallocated';
  afterPilotScaleIn.runners.github.runners[2].status = 'offline';
  const primaryQuietStarted = createCapacityPlan({
    config: enabledConfig,
    inventory: afterPilotScaleIn,
    ...leaseFence(secondGuard.nextState),
    now: start + 602_000,
    state: secondGuard.nextState,
  });
  assert.equal(primaryQuietStarted.action, 'hold');
  assert.equal(primaryQuietStarted.safety.rearmRequired, false);
  const primaryFirstGuard = createCapacityPlan({
    config: enabledConfig,
    inventory: afterPilotScaleIn,
    ...leaseFence(primaryQuietStarted.nextState),
    now: start + 902_000,
    state: primaryQuietStarted.nextState,
  });
  const primarySecondGuard = createCapacityPlan({
    config: enabledConfig,
    inventory: afterPilotScaleIn,
    ...leaseFence(primaryFirstGuard.nextState),
    now: start + 903_000,
    state: primaryFirstGuard.nextState,
  });
  assert.equal(primarySecondGuard.action, 'scale-in-one');
  assert.equal(primarySecondGuard.targetTrustClass, 'certigo-pr');
  assert.deepEqual(
    primarySecondGuard.nextState.scaleInSafety.rearmTargetCapacityByTrust,
    {
      'certigo-pr': 2,
      'certigo-trusted': 2,
    },
  );

  const rearm = createCapacityPlan({
    config: enabledConfig,
    inventory: inventory({
      capacity: 4,
      poweredCapacity: 3,
      queued: 1,
    }),
    ...leaseFence(secondGuard.nextState),
    now: start + 602_000,
    state: secondGuard.nextState,
  });
  assert.equal(rearm.action, 'scale-out-one');
  assert.equal(rearm.targetTrustClass, 'certigo-trusted');
  assert.equal(rearm.safety.quietReset, false);
  assert.equal(rearm.safety.rearmRequired, true);
  assert.deepEqual(rearm.safety.rearmTargetCapacityByTrust, {
    'certigo-pr': 2,
    'certigo-trusted': 2,
  });
});

test('the PR pilot is deallocated before the trusted primary', () => {
  const now = Date.parse('2026-08-20T07:00:00Z');
  const afterPilotScaleIn = inventory({
    capacity: 2,
    poweredCapacity: 2,
  });
  afterPilotScaleIn.runners.virtualMachines[0].powerState = 'VM deallocated';
  afterPilotScaleIn.runners.github.runners[0].status = 'offline';

  const result = createCapacityPlan({
    config: { ...config, enabled: true },
    inventory: afterPilotScaleIn,
    ...leaseFence(),
    now,
    persistedStateRevision: 4,
    state: {
      jobs: {},
      leaseGeneration: 7,
      revision: 4,
      scaleInSafety: {
        guardCount: 1,
        lastGuardAt: new Date(now - 1_000).toISOString(),
        quietSince: new Date(now - 301_000).toISOString(),
        rearmRequired: false,
        rearmTargetCapacityByTrust: {
          'certigo-pr': 1,
          'certigo-trusted': 1,
        },
      },
      version: 3,
    },
  });

  assert.equal(result.action, 'scale-in-one');
  assert.equal(result.targetTrustClass, 'certigo-trusted');
  assert.equal(result.canRequestChange, true);
});

test('forged quiet-period guard state fails closed', () => {
  const now = Date.parse('2026-08-20T06:10:00Z');
  assert.throws(
    () =>
      createCapacityPlan({
        config: { ...config, enabled: true },
        inventory: inventory({ capacity: 4 }),
        ...leaseFence(),
        now,
        state: {
          jobs: {},
          scaleInSafety: {
            guardCount: 2,
            lastGuardAt: null,
            quietSince: new Date(now - 300_000).toISOString(),
            rearmTargetCapacityByTrust: null,
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
    ...leaseFence(),
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
    ...leaseFence(),
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
    ...leaseFence(),
  });

  assert.equal(plan.action, 'hold');
  assert.equal(plan.canRequestChange, false);
  assert.deepEqual(plan.trust.unclassifiedVirtualMachines, [
    'vmss-certigo-pr_unexpected',
  ]);
});

test('real inventory binds f55 and the PR pilot while keeping runner 26 and VM 415 external', () => {
  const result = reconcileRunnerInstances(
    [
      { name: 'vmss-certigo-runner-zonal_4153d1dd' },
      {
        id: f55VmId,
        name: f55VmName,
        powerState: 'VM running',
        virtualMachineScaleSet: { id: '/vmss/vmss-certigo-runner-zonal' },
        zones: ['2'],
      },
      {
        id: pilotVmId,
        name: pilotVmName,
        powerState: 'VM running',
        virtualMachineScaleSet: { id: '/vmss/vmss-certigo-pr-pilot-z1' },
        zones: ['1'],
      },
    ],
    [
      runner(
        'vmss-certigo-runner-zonal_22f7fb52-Certigo',
        ['certigo-pr'],
        { id: 26, status: 'offline' },
      ),
      runner(
        'vmss-certigo-runner-zonal_f55d176e-Certigo',
        ['certigo-pr', 'certigo-trusted'],
        { id: 27 },
      ),
      runner(
        'certigo-prIVJAN8',
        ['certigo-pr', 'certigo-pr-pilot'],
        { id: 28 },
      ),
    ],
    repositoryConfig.inventory,
  );

  assert.deepEqual(result.absentRunners, []);
  assert.deepEqual(
    result.externalGitHubRunners.map(({ id }) => id),
    [26],
  );
  assert.deepEqual(result.managedMachineNames, [
    pilotVmName,
    f55VmName,
  ]);
  assert.deepEqual(result.externalVirtualMachines, [
    'vmss-certigo-runner-zonal_4153d1dd',
  ]);
  assert.deepEqual(result.bindingMismatches, []);
  assert.ok(
    result.managedInstances.every(
      (managedInstance) => managedInstance.binding === 'explicit',
    ),
  );
});

test('explicit bindings reject an additional name-matched runner and VM', () => {
  const result = reconcileRunnerInstances(
    [
      {
        id: '/subscriptions/example/resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm-approved',
        name: 'vm-approved',
      },
      {
        id: '/subscriptions/example/resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm-extra',
        name: 'vm-extra',
      },
    ],
    [
      runner('runner-approved', ['certigo-pr'], { id: 101 }),
      runner('vm-extra-Certigo', ['certigo-pr'], { id: 102 }),
    ],
    {
      externalVirtualMachines: [],
      forbiddenVirtualMachines: [],
      managedRunnerBindings: [
        {
          githubRunnerId: 101,
          runnerName: 'runner-approved',
          virtualMachineId:
            '/subscriptions/example/resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm-approved',
          virtualMachineName: 'vm-approved',
        },
      ],
    },
  );

  assert.deepEqual(result.managedMachineNames, ['vm-approved']);
  assert.deepEqual(result.unboundRunnerVirtualMachinePairs, [
    'vm-extra-Certigo -> vm-extra',
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
      id: f55VmId,
      name: 'vmss-certigo-runner-zonal_f55d176e',
      powerState: 'VM running',
      virtualMachineScaleSet: {
        id: '/vmss/vmss-certigo-runner-zonal',
      },
    },
  ];
  live.runners.github.runners = [
    runner(
      'vmss-certigo-runner-zonal_22f7fb52-Certigo',
      ['certigo-pr', 'certigo-trusted'],
      { id: 26 },
    ),
    {
      ...runner(
        'vmss-certigo-runner-zonal_f55d176e-Certigo',
        ['certigo-pr', 'certigo-trusted'],
        { id: 27 },
      ),
      status: 'online',
    },
  ];

  const result = reconcileRunnerDrift(
    live,
    "param vmSize string = 'Standard_D4s_v5'\nresource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {}",
    repositoryConfig,
  );
  assert.equal(result.readOnly, true);
  assert.deepEqual(
    result.findings.map((finding) => finding.code).sort(),
    [
      'COMPUTE_MODEL_DRIFT',
      'CPU_SCALE_IN_DRIFT',
      'EXTERNAL_INSTANCE_OBSERVED',
      'POOL_IDENTITY_DRIFT',
      'POOL_SUBNET_DRIFT',
      'POOL_TRUST_BOUNDARY_DRIFT',
      'REDUNDANCY_DRIFT',
      // The only managed runner here carries both trust labels, so it counts
      // for neither class and both floors are unmet.
      'TRUST_CLASS_REDUNDANCY_DRIFT',
      'TRUST_CLASS_REDUNDANCY_DRIFT',
      'TRUST_LABEL_DRIFT',
      'VM_SIZE_DRIFT',
    ],
  );
  assert.equal(result.baseline30Days.costUsd, 242.06);
  assert.deepEqual(result.observed.absentRunners, []);
  assert.deepEqual(result.observed.managedMachineNames, [
    'vmss-certigo-runner-zonal_f55d176e',
  ]);
  assert.deepEqual(result.observed.externalVirtualMachines, [
    'vmss-certigo-runner-zonal_4153d1dd',
  ]);
});

test('drift reconciliation validates every VMSS SKU and the full autoscale contract', () => {
  const live = reconciledCapacityInventory();
  const reconciled = reconcileRunnerDrift(live, capacityTemplate, config);
  assert.equal(
    reconciled.findings.some(
      (finding) => finding.code === 'AUTOSCALE_CONTRACT_DRIFT',
    ),
    false,
  );

  live.runners.vmScaleSets[1].sku.name = 'Standard_D4s_v5';
  live.runners.autoscaleSettings[0] = {
    ...live.runners.autoscaleSettings[0],
    enabled: false,
    targetResourceUri: '/subscriptions/example/resourceGroups/rg/providers/wrong',
    profiles: [
      {
        name: 'default',
        capacity: {
          minimum: '0',
          default: '0',
          maximum: '99',
        },
        rules: [],
      },
    ],
  };

  const drifted = reconcileRunnerDrift(live, capacityTemplate, config);
  const codes = drifted.findings.map((finding) => finding.code);
  assert.ok(codes.includes('VM_SIZE_DRIFT'));
  assert.ok(codes.includes('AUTOSCALE_CONTRACT_DRIFT'));
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

const be505VmName = 'vmss-certigo-runner-zonal_be505fa1';
const be505VmId =
  '/subscriptions/b8952c8c-8f72-469d-99cd-ac906da4e2fc/' +
  'resourceGroups/RG-CERTIGO-CI/providers/Microsoft.Compute/' +
  `virtualMachines/${be505VmName}`;

// Mirrors the live topology: one certigo-pr pilot instance and two
// certigo-trusted instances of vmss-certigo-runner-zonal across zones 1 and 2.
function zonalInventory({ zone1Powered = true, zone1Online = true } = {}) {
  const scaleSet = (name, index) => ({
    name,
    identity: { userAssignedIdentities: { [`/identities/${name}`]: {} } },
    virtualMachineProfile: {
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            properties: {
              ipConfigurations: [
                {
                  properties: {
                    subnet: { id: `/networks/net-${index}/subnets/default` },
                  },
                },
              ],
            },
          },
        ],
      },
    },
  });
  return {
    runners: {
      activeRuns: { total_count: 0 },
      queuedRuns: { total_count: 0 },
      github: {
        runners: [
          runner('vmss-certigo-runner-zonal_f55d176e-Certigo', [
            'certigo-trusted',
          ], { id: 27 }),
          runner('vmss-certigo-runner-zonal_be505fa1-Certigo', [
            'certigo-trusted',
          ], { id: 29, status: zone1Online ? 'online' : 'offline' }),
          runner('certigo-prIVJAN8', ['certigo-pr'], { id: 28 }),
          runner('certigo-prQA5OWT', ['certigo-pr'], { id: 30 }),
        ],
      },
      virtualMachines: [
        {
          id: f55VmId,
          name: f55VmName,
          powerState: 'VM running',
          virtualMachineScaleSet: { id: '/vmss/vmss-certigo-runner-zonal' },
          zones: ['2'],
        },
        {
          id: be505VmId,
          name: be505VmName,
          powerState: zone1Powered ? 'VM running' : 'VM deallocated',
          virtualMachineScaleSet: { id: '/vmss/vmss-certigo-runner-zonal' },
          zones: ['1'],
        },
        {
          id: pilotVmId,
          name: pilotVmName,
          powerState: 'VM running',
          virtualMachineScaleSet: { id: '/vmss/vmss-certigo-pr-pilot-z1' },
          zones: ['1'],
        },
        {
          id: pilot2VmId,
          name: pilot2VmName,
          powerState: 'VM running',
          virtualMachineScaleSet: { id: '/vmss/vmss-certigo-pr-pilot-z1' },
          zones: ['1'],
        },
      ],
      vmScaleSets: [
        scaleSet('vmss-certigo-runner-zonal', 0),
        scaleSet('vmss-certigo-pr-pilot-z1', 1),
      ],
    },
  };
}

test('the versioned inventory binds both trusted zones so neither can go missing', () => {
  const result = reconcileRunnerInstances(
    zonalInventory().runners.virtualMachines,
    zonalInventory().runners.github.runners,
    repositoryConfig.inventory,
  );

  assert.deepEqual(result.unclassifiedVirtualMachines, []);
  assert.deepEqual(result.managedMachineNames, [
    pilot2VmName,
    pilotVmName,
    be505VmName,
    f55VmName,
  ]);
  assert.deepEqual(result.bindingMismatches, []);
  assert.deepEqual(result.absentRunners, []);
});

test('two online trusted runners satisfy the redundancy floor', () => {
  const plan = createCapacityPlan({
    config: repositoryConfig,
    inventory: zonalInventory(),
  });

  assert.equal(plan.usableCapacityByTrust['certigo-trusted'], 2);
  assert.equal(plan.trust.redundancyReady, true);
  assert.deepEqual(plan.trust.redundancyShortfalls, []);
  assert.ok(
    !plan.blockers.some((blocker) => blocker.includes('redundancy')),
  );
});

test('a deallocated trusted zone is reported as a redundancy shortfall', () => {
  const plan = createCapacityPlan({
    config: repositoryConfig,
    inventory: zonalInventory({ zone1Powered: false, zone1Online: false }),
  });

  assert.equal(plan.usableCapacityByTrust['certigo-trusted'], 1);
  assert.equal(plan.trust.redundancyReady, false);
  assert.deepEqual(plan.trust.redundancyShortfalls, [
    { trustClass: 'certigo-trusted', online: 1, required: 2 },
  ]);
  assert.ok(
    plan.blockers.includes(
      'certigo-trusted has 1 online runner(s) but requires 2 for redundancy',
    ),
  );
});

test('a running VM whose GitHub runner is offline still counts as a shortfall', () => {
  // The zone-1 outage presented exactly this way: Azure reported "VM running"
  // while GitHub had garbage-collected the runner registration.
  const plan = createCapacityPlan({
    config: repositoryConfig,
    inventory: zonalInventory({ zone1Powered: true, zone1Online: false }),
  });

  assert.equal(plan.currentCapacityByTrust['certigo-trusted'], 2);
  assert.equal(plan.usableCapacityByTrust['certigo-trusted'], 1);
  assert.equal(plan.trust.redundancyReady, false);
});

test('configuration refuses a redundancy floor below one or above the pilot target', () => {
  assert.throws(
    () =>
      createCapacityPlan({
        config: {
          ...config,
          minimumOnlineByTrust: {
            'certigo-pr': 1,
            'certigo-trusted': 0,
          },
        },
        inventory: inventory(),
      }),
    /minimumOnlineByTrust\.certigo-trusted must be a positive integer/,
  );

  assert.throws(
    () =>
      createCapacityPlan({
        config: {
          ...config,
          minimumOnlineByTrust: {
            'certigo-pr': 1,
            'certigo-trusted': 3,
          },
        },
        inventory: inventory(),
      }),
    /minimumOnlineByTrust\.certigo-trusted must stay within the pilot target/,
  );
});
