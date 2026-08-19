import assert from 'node:assert/strict';
import test from 'node:test';

import { evaluateLifecycle } from './evaluate-lifecycle.mjs';

function runner(name, labels, { busy = false, status = 'online' } = {}) {
  return {
    name,
    labels: labels.map((label) => ({ name: label })),
    busy,
    status,
  };
}

test('deallocation is blocked for the observed dual-label busy autoscaled pool', () => {
  const result = evaluateLifecycle({
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
  });

  assert.equal(result.preflightOnly, true);
  assert.equal(result.safeToRequestChange, false);
  assert.ok(result.reasons.some((reason) => reason.startsWith('dual trust labels')));
  assert.ok(result.reasons.includes('CPU autoscale contains an unsafe scale-in rule'));
  assert.ok(result.reasons.includes('queued workflow runs: 10'));
  assert.ok(result.reasons.includes('active workflow runs: 1'));
});

test('idle reconciled exclusive pools pass the read-only preflight', () => {
  const result = evaluateLifecycle({
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
    virtualMachines: [{ name: 'vm-pr' }, { name: 'vm-trusted' }],
  });

  assert.equal(result.safeToRequestChange, true);
  assert.deepEqual(result.reasons, []);
});

test('equal VM and runner counts still fail when their names do not reconcile', () => {
  const result = evaluateLifecycle({
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
      { name: 'vmss-certigo-runner-zonal_f55d176e' },
    ],
  });

  assert.equal(result.safeToRequestChange, false);
  assert.ok(
    result.reasons.some(
      (reason) =>
        reason.includes('22f7fb52-Certigo') &&
        reason.includes('4153d1dd'),
    ),
  );
});

test('unknown lifecycle operations fail closed', () => {
  assert.throws(
    () =>
      evaluateLifecycle({
        operation: 'delete',
        runners: { runners: [] },
        queuedRuns: { total_count: 0 },
        activeRuns: { total_count: 0 },
        autoscale: {},
        virtualMachines: [],
      }),
    /Unsupported lifecycle operation/,
  );
});
