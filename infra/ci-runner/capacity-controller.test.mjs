import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import {
  createCapacityPlan,
  reduceWorkflowJobState,
} from './capacity-controller.mjs';
import { reconcileRunnerDrift } from './reconcile-drift.mjs';

const config = JSON.parse(
  readFileSync(
    new URL('./capacity-controller.config.json', import.meta.url),
    'utf8',
  ),
);

function runner(name, labels, busy = false) {
  return {
    name,
    busy,
    status: 'online',
    labels: labels.map((label) => ({ name: label })),
  };
}

function inventory({
  active = 0,
  busy = false,
  capacity = 2,
  dualTrust = false,
  queued = 0,
  vmScaleSetCount = 2,
} = {}) {
  const labels = dualTrust
    ? ['certigo-pr', 'certigo-trusted']
    : ['certigo-pr'];
  const virtualMachines = Array.from({ length: capacity }, (_, index) => ({
    name: `vm-${index}`,
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
            busy,
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

test('backlog selects boost but feature flag and max four remain hard stops', () => {
  const plan = createCapacityPlan({
    config,
    inventory: inventory({ queued: 3, busy: true }),
  });

  assert.equal(plan.mode, 'boost');
  assert.equal(plan.targetCapacity, 4);
  assert.ok(plan.nextCapacity <= 4);
  assert.equal(plan.featureEnabled, false);
  assert.equal(plan.canRequestChange, false);
  assert.ok(plan.blockers.includes('capacity controller feature flag is off'));
  assert.equal(config.observedBaseline30Days.queueP99Seconds, 12628);
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

test('scale-in requires a complete drain and proceeds one instance at a time', () => {
  const drained = createCapacityPlan({
    config,
    inventory: inventory({ capacity: 4 }),
  });
  assert.equal(drained.mode, 'idle');
  assert.equal(drained.scaleInSafe, true);
  assert.equal(drained.action, 'scale-in-one');
  assert.equal(drained.nextCapacity, 3);

  const active = createCapacityPlan({
    config,
    inventory: inventory({ active: 1, capacity: 4 }),
  });
  assert.equal(active.scaleInSafe, false);
  assert.equal(active.action, 'hold');
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
    { name: 'vmss-certigo-runner-zonal_4153d1dd' },
    { name: 'vmss-certigo-runner-zonal_f55d176e' },
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
      'COMPUTE_MODEL_DRIFT',
      'CPU_SCALE_IN_DRIFT',
      'INSTANCE_REGISTRATION_DRIFT',
      'POOL_IDENTITY_DRIFT',
      'REDUNDANCY_DRIFT',
      'TRUST_LABEL_DRIFT',
      'VM_SIZE_DRIFT',
    ],
  );
  assert.equal(result.baseline30Days.costUsd, 242.06);
});

test('configuration refuses an aggregate ceiling above four', () => {
  assert.throws(
    () =>
      createCapacityPlan({
        config: { ...config, maxAggregateCapacity: 5 },
        inventory: inventory(),
      }),
    /must never exceed 4/,
  );
});
