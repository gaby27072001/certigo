import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import { evaluateDriftGate, readPolicy } from './drift-gate.mjs';
import { reconcileRunnerDrift } from './reconcile-drift.mjs';

const config = JSON.parse(
  readFileSync(
    new URL('./capacity-controller.config.json', import.meta.url),
    'utf8',
  ),
);
const policy = JSON.parse(
  readFileSync(new URL('./drift-gate.policy.json', import.meta.url), 'utf8'),
);
const runnerTemplate = readFileSync(
  new URL('./runner.bicep', import.meta.url),
  'utf8',
);

const poolOf = (binding) =>
  binding.virtualMachineName.startsWith('vmss-certigo-pr-pilot')
    ? 'vmss-certigo-pr-pilot-z1'
    : 'vmss-certigo-runner-zonal';
const trustOf = (binding) =>
  poolOf(binding) === 'vmss-certigo-pr-pilot-z1'
    ? 'certigo-pr'
    : 'certigo-trusted';

function scaleSet(name, index) {
  return {
    name,
    sku: { name: 'Standard_D2ads_v6' },
    orchestrationMode: 'Flexible',
    identity: {
      userAssignedIdentities: { [`/identities/${name}`]: {} },
    },
    virtualMachineProfile: {
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            properties: {
              ipConfigurations: [
                {
                  properties: {
                    subnet: { id: `/networks/runner-${index}/subnets/default` },
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

// Mirrors the live shape closely enough that the real config and the real
// detector produce the live finding set. Anything this fixture gets wrong shows
// up as an extra finding, which the first assertion below would catch.
function liveInventory() {
  const bindings = config.inventory.managedRunnerBindings;
  return {
    runners: {
      activeRuns: { total_count: 0 },
      queuedRuns: { total_count: 0 },
      virtualMachines: bindings.map((binding) => ({
        name: binding.virtualMachineName,
        id: binding.virtualMachineId,
        powerState: 'VM running',
        virtualMachineScaleSet: {
          id:
            '/subscriptions/example/resourceGroups/RG-CERTIGO-CI/providers/' +
            `Microsoft.Compute/virtualMachineScaleSets/${poolOf(binding)}`,
        },
      })),
      github: {
        runners: bindings.map((binding) => ({
          id: binding.githubRunnerId,
          name: binding.runnerName,
          busy: false,
          status: 'online',
          labels: [{ name: trustOf(binding) }],
        })),
      },
      vmScaleSets: [
        scaleSet('vmss-certigo-runner-zonal', 0),
        scaleSet('vmss-certigo-pr-pilot-z1', 1),
      ],
      autoscaleSettings: [
        {
          profiles: [
            { rules: [{ scaleAction: { direction: 'Decrease' } }] },
          ],
        },
      ],
    },
  };
}

const codesOf = (findings) => findings.map((finding) => finding.code).sort();

test('the live shape yields only the acknowledged historical findings', () => {
  const report = reconcileRunnerDrift(liveInventory(), runnerTemplate, config);
  const verdict = evaluateDriftGate(report, policy);

  assert.deepEqual(codesOf(verdict.blocking), []);
  assert.deepEqual(verdict.stale, []);
  assert.deepEqual(codesOf(verdict.acknowledged), [
    'COMPUTE_MODEL_DRIFT',
    'CPU_SCALE_IN_DRIFT',
    'VM_SIZE_DRIFT',
  ]);
  assert.equal(verdict.ok, true);
});

test('removing one managed VM turns the gate red', () => {
  const amputated = liveInventory();
  const [removed] = amputated.runners.virtualMachines.splice(3, 1);
  const report = reconcileRunnerDrift(amputated, runnerTemplate, config);
  const verdict = evaluateDriftGate(report, policy);

  assert.equal(verdict.ok, false);
  assert.ok(codesOf(verdict.blocking).includes('ABSENT_RUNNER_DRIFT'));
  assert.ok(
    verdict.blocking
      .find((finding) => finding.code === 'ABSENT_RUNNER_DRIFT')
      .detail.includes(
        config.inventory.managedRunnerBindings[3].runnerName,
      ),
  );
  // The control that makes the red meaningful: the same fixture with the VM put
  // back is green, so the red is caused by the amputation and not by the fixture.
  amputated.runners.virtualMachines.push(removed);
  assert.equal(
    evaluateDriftGate(
      reconcileRunnerDrift(amputated, runnerTemplate, config),
      policy,
    ).ok,
    true,
  );
});

// The 2026-09-08 incident, replayed: vmss-certigo-pr-pilot-z1_a14700a3 stayed
// deallocated after the nightly teardown and its runner went offline, leaving a
// single certigo-pr runner for fifteen queued jobs. The gate was green.
test('losing one certigo-pr runner turns the gate red', () => {
  const incident = liveInventory();
  const bindings = config.inventory.managedRunnerBindings;
  const lostIndex = bindings.findIndex(
    (binding) => trustOf(binding) === 'certigo-pr',
  );
  assert.notEqual(lostIndex, -1, 'the fixture must contain a certigo-pr runner');
  const lost = bindings[lostIndex];
  incident.runners.virtualMachines.find(
    (vm) => vm.name === lost.virtualMachineName,
  ).powerState = 'VM deallocated';
  incident.runners.github.runners.find(
    (runner) => runner.id === lost.githubRunnerId,
  ).status = 'offline';

  const report = reconcileRunnerDrift(incident, runnerTemplate, config);
  const verdict = evaluateDriftGate(report, policy);

  assert.equal(verdict.ok, false);
  const finding = verdict.blocking.find(
    (entry) => entry.code === 'TRUST_CLASS_REDUNDANCY_DRIFT',
  );
  assert.ok(finding, 'the per-class shortfall must be reported');
  assert.match(finding.detail, /certigo-pr capacity is 1/);
  assert.match(finding.detail, /requires 2/);

  // Why the per-class check had to exist: the aggregate target is 2 and three
  // runners are still usable, so REDUNDANCY_DRIFT stays silent on the very
  // failure that took PR capacity down to one.
  assert.equal(
    report.findings.some((entry) => entry.code === 'REDUNDANCY_DRIFT'),
    false,
  );

  // The control that makes the red meaningful: restoring the runner is green,
  // so the red comes from the lost availability and not from the fixture.
  incident.runners.virtualMachines.find(
    (vm) => vm.name === lost.virtualMachineName,
  ).powerState = 'VM running';
  incident.runners.github.runners.find(
    (runner) => runner.id === lost.githubRunnerId,
  ).status = 'online';
  assert.equal(
    evaluateDriftGate(
      reconcileRunnerDrift(incident, runnerTemplate, config),
      policy,
    ).ok,
    true,
  );
});

test('a missing trust-class floor is reported instead of passing silently', () => {
  const withoutFloor = {
    ...config,
    minimumOnlineByTrust: { 'certigo-trusted': 2 },
  };
  const report = reconcileRunnerDrift(
    liveInventory(),
    runnerTemplate,
    withoutFloor,
  );

  assert.ok(
    report.findings.some(
      (entry) =>
        entry.code === 'TRUST_CLASS_FLOOR_MISSING' &&
        entry.detail.includes('certigo-pr'),
    ),
  );
  assert.equal(evaluateDriftGate(report, policy).ok, false);
});

test('a blocking code the policy does not name fails closed', () => {
  const verdict = evaluateDriftGate(
    { findings: [{ severity: 'blocking', code: 'CODE_ADDED_LATER', detail: 'x' }] },
    policy,
  );

  assert.equal(verdict.ok, false);
  assert.deepEqual(codesOf(verdict.blocking), ['CODE_ADDED_LATER']);
});

test('an acknowledgement that stops being reported fails the gate', () => {
  const report = reconcileRunnerDrift(liveInventory(), runnerTemplate, config);
  const withoutSizeDrift = {
    ...report,
    findings: report.findings.filter(
      (finding) => finding.code !== 'VM_SIZE_DRIFT',
    ),
  };
  const verdict = evaluateDriftGate(withoutSizeDrift, policy);

  assert.equal(verdict.ok, false);
  assert.deepEqual(
    verdict.stale.map((entry) => entry.code),
    ['VM_SIZE_DRIFT'],
  );
});

test('informational findings never fail the gate', () => {
  const verdict = evaluateDriftGate(
    {
      findings: [
        { severity: 'informational', code: 'EXTERNAL_INSTANCE_OBSERVED', detail: 'x' },
      ],
    },
    { acknowledgedFindings: [] },
  );

  assert.equal(verdict.ok, true);
  assert.deepEqual(codesOf(verdict.informational), [
    'EXTERNAL_INSTANCE_OBSERVED',
  ]);
});

test('every acknowledgement states a reason and a condition that ends it', () => {
  const entries = policy.acknowledgedFindings;
  assert.ok(entries.length > 0);
  for (const entry of entries) {
    assert.ok(entry.reason.trim().length > 0, `${entry.code} needs a reason`);
    assert.ok(
      entry.invalidatedWhen.trim().length > 0,
      `${entry.code} needs an invalidation condition`,
    );
  }
  assert.equal(readPolicy(policy).size, entries.length);
});

test('an acknowledgement without a written reason is rejected', () => {
  assert.throws(
    () =>
      readPolicy({
        acknowledgedFindings: [{ code: 'X', invalidatedWhen: 'never' }],
      }),
    /reason must be a non-empty string/,
  );
  assert.throws(
    () => readPolicy({ acknowledgedFindings: [{ code: 'X', reason: 'because' }] }),
    /invalidatedWhen must be a non-empty string/,
  );
});
