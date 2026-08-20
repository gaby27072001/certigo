import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

import {
  isPoweredCapacity,
  labelsOf,
  reconcileRunnerInstances,
  summarizePoolBoundaries,
  trustClassOfRunner,
} from './runner-inventory.mjs';
import {
  advanceScaleInSafety,
  armScaleInReactivation,
} from './scale-in-safety.mjs';

function scaleInRules(autoscale) {
  return (autoscale.profiles ?? []).flatMap((profile) =>
    (profile.rules ?? []).filter(
      (rule) => rule.scaleAction?.direction === 'Decrease',
    ),
  );
}

function aggregateCapacity(capacityByTrust) {
  return (
    capacityByTrust['certigo-pr'] +
    capacityByTrust['certigo-trusted']
  );
}

function capacitySatisfies(actual, required) {
  if (required === null || required === undefined) {
    return false;
  }
  return Object.entries(required).every(
    ([trustClass, capacity]) =>
      (actual[trustClass] ?? 0) >= capacity,
  );
}

export function evaluateLifecycle({
  config,
  operation,
  runners,
  queuedRuns,
  activeRuns,
  autoscale,
  virtualMachines,
  vmScaleSets,
  now = Date.now(),
  state = {},
}) {
  if (!['start', 'deallocate'].includes(operation)) {
    throw new Error(`Unsupported lifecycle operation: ${operation}`);
  }
  if (
    state.version !== undefined &&
    state.version !== config.stateVersion
  ) {
    throw new Error(
      `capacity state version ${state.version} is not supported`,
    );
  }

  const reasons = [];
  if (!config.enabled) {
    reasons.push('capacity controller feature flag is off');
  }
  const repositoryRunners = runners.runners ?? [];
  const certigoRunners = repositoryRunners.filter((runner) => {
    const labels = labelsOf(runner);
    return labels.has('certigo-pr') || labels.has('certigo-trusted');
  });
  const dualTrustRunners = certigoRunners.filter((runner) => {
    const labels = labelsOf(runner);
    return labels.has('certigo-pr') && labels.has('certigo-trusted');
  });
  const prRunners = certigoRunners.filter((runner) => {
    const labels = labelsOf(runner);
    return labels.has('certigo-pr') && !labels.has('certigo-trusted');
  });
  const trustedRunners = certigoRunners.filter((runner) => {
    const labels = labelsOf(runner);
    return labels.has('certigo-trusted') && !labels.has('certigo-pr');
  });

  if (dualTrustRunners.length > 0) {
    reasons.push(
      `dual trust labels: ${dualTrustRunners.map((runner) => runner.name).join(', ')}`,
    );
  }
  if (prRunners.length === 0 || trustedRunners.length === 0) {
    reasons.push('at least one exclusive certigo-pr and certigo-trusted runner is required');
  }

  const instanceInventory = reconcileRunnerInstances(
    virtualMachines,
    certigoRunners,
    config.inventory,
  );
  if (instanceInventory.absentRunners.length > 0) {
    reasons.push(
      `absent Azure VMs for registered runners: ${instanceInventory.absentRunners.join(', ')}`,
    );
  }
  if (instanceInventory.unclassifiedVirtualMachines.length > 0) {
    reasons.push(
      `unclassified Azure VMs: ${instanceInventory.unclassifiedVirtualMachines.join(', ')}`,
    );
  }
  if (instanceInventory.bindingMismatches.length > 0) {
    reasons.push(
      `managed runner binding mismatches: ${instanceInventory.bindingMismatches.join(', ')}`,
    );
  }
  if (instanceInventory.missingManagedRunnerVirtualMachines.length > 0) {
    reasons.push(
      `managed VMs without their bound runner: ${instanceInventory.missingManagedRunnerVirtualMachines.join(', ')}`,
    );
  }
  if (instanceInventory.unboundRunnerVirtualMachinePairs.length > 0) {
    reasons.push(
      `unbound runner/VM pairs: ${instanceInventory.unboundRunnerVirtualMachinePairs.join(', ')}`,
    );
  }
  if (instanceInventory.forbiddenVirtualMachinesPresent.length > 0) {
    reasons.push(
      `forbidden Azure VMs are present: ${instanceInventory.forbiddenVirtualMachinesPresent.join(', ')}`,
    );
  }

  const poolBoundaries = summarizePoolBoundaries(
    vmScaleSets,
    instanceInventory.managedInstances,
  );
  if (
    poolBoundaries.managedPoolCount < config.minimumExclusivePools ||
    poolBoundaries.managedInstancesWithoutPool.length > 0 ||
    poolBoundaries.missingManagedScaleSets.length > 0 ||
    poolBoundaries.distinctIdentityBoundaryCount <
      config.minimumExclusivePools ||
    poolBoundaries.sharedIdentityIds.length > 0
  ) {
    reasons.push('runner pool identities are not exclusive');
  }
  if (
    poolBoundaries.distinctSubnetCount <
      config.minimumExclusiveSubnets ||
    poolBoundaries.poolsWithoutSubnet.length > 0 ||
    poolBoundaries.sharedSubnetIds.length > 0
  ) {
    reasons.push('runner pool subnets are not exclusive');
  }
  if (
    poolBoundaries.poolsWithMixedTrustLabels.length > 0 ||
    poolBoundaries.trustClassPoolCounts['certigo-pr'] === 0 ||
    poolBoundaries.trustClassPoolCounts['certigo-trusted'] === 0
  ) {
    reasons.push('runner labels are not isolated by managed pool');
  }
  if (autoscale.enabled && scaleInRules(autoscale).length > 0) {
    reasons.push('CPU autoscale contains an unsafe scale-in rule');
  }

  const usableManagedCapacity = instanceInventory.managedInstances.filter(
    ({ runner, virtualMachine }) =>
      runner.status === 'online' &&
      isPoweredCapacity(virtualMachine),
  ).length;
  const usableCapacityByTrust = {
    'certigo-pr': 0,
    'certigo-trusted': 0,
  };
  for (const { runner, virtualMachine } of instanceInventory.managedInstances) {
    const trustClass = trustClassOfRunner(runner);
    if (
      (trustClass === 'certigo-pr' ||
        trustClass === 'certigo-trusted') &&
      runner.status === 'online' &&
      isPoweredCapacity(virtualMachine)
    ) {
      usableCapacityByTrust[trustClass] += 1;
    }
  }
  let scaleInSafety = null;
  let nextState = { ...state, version: config.stateVersion };
  if (operation === 'deallocate') {
    const busyRunners = certigoRunners.filter((runner) => runner.busy);
    if (busyRunners.length > 0) {
      reasons.push(
        `busy runners: ${busyRunners.map((runner) => runner.name).join(', ')}`,
      );
    }
    if ((queuedRuns.total_count ?? 0) > 0) {
      reasons.push(`queued workflow runs: ${queuedRuns.total_count}`);
    }
    if ((activeRuns.total_count ?? 0) > 0) {
      reasons.push(`active workflow runs: ${activeRuns.total_count}`);
    }
    const offlineManagedRunners = instanceInventory.managedInstances
      .filter(
        ({ runner, virtualMachine }) =>
          runner.status !== 'online' ||
          !isPoweredCapacity(virtualMachine),
      )
      .map(({ runner }) => runner.name);
    if (offlineManagedRunners.length > 0) {
      reasons.push(
        `managed runners not powered and online: ${offlineManagedRunners.join(', ')}`,
      );
    }

    const quietEligible =
      reasons.length === 0 &&
      busyRunners.length === 0 &&
      (queuedRuns.total_count ?? 0) === 0 &&
      (activeRuns.total_count ?? 0) === 0;
    scaleInSafety = advanceScaleInSafety({
      idle: quietEligible,
      now,
      quietPeriodSeconds: config.quietPeriodSeconds,
      rearmSatisfied: capacitySatisfies(
        usableCapacityByTrust,
        state.scaleInSafety?.rearmTargetCapacityByTrust,
      ),
      requiredGuards: config.requiredPostQuietGuards,
      state: state.scaleInSafety,
    });
    nextState.scaleInSafety = scaleInSafety.nextState;
    if (scaleInSafety.rearmRequired) {
      reasons.push('post-scale-in activity requires managed capacity rearm');
    }
    if (!scaleInSafety.ready) {
      reasons.push(
        'resettable five-minute quiet period and two post-quiet guards are incomplete',
      );
    }
  }

  const safeToRequestChange = reasons.length === 0;
  if (operation === 'deallocate' && safeToRequestChange) {
    nextState.scaleInSafety = armScaleInReactivation(
      nextState.scaleInSafety,
      usableCapacityByTrust,
    );
  }

  return {
    operation,
    preflightOnly: true,
    safeToRequestChange,
    reasons,
    safety:
      scaleInSafety === null
        ? null
        : {
            guardCount: scaleInSafety.guardCount,
            quietComplete: scaleInSafety.quietComplete,
            quietElapsedSeconds: scaleInSafety.quietElapsedSeconds,
            quietReset: scaleInSafety.quietReset,
            rearmRequired: scaleInSafety.rearmRequired,
            rearmTargetCapacityByTrust:
              scaleInSafety.rearmTargetCapacityByTrust,
            requiredGuards: config.requiredPostQuietGuards,
            quietPeriodSeconds: config.quietPeriodSeconds,
          },
    observed: {
      activeRuns: activeRuns.total_count ?? 0,
      absentRunners: instanceInventory.absentRunners,
      bindingMismatches: instanceInventory.bindingMismatches,
      azureVirtualMachines: (virtualMachines ?? []).length,
      certigoRunners: certigoRunners.length,
      dualTrustRunners: dualTrustRunners.length,
      externalVirtualMachines: instanceInventory.externalVirtualMachines,
      forbiddenVirtualMachinesPresent:
        instanceInventory.forbiddenVirtualMachinesPresent,
      managedMachineNames: instanceInventory.managedMachineNames,
      managedPoolNames: poolBoundaries.managedPoolNames,
      missingManagedRunnerVirtualMachines:
        instanceInventory.missingManagedRunnerVirtualMachines,
      unclassifiedVirtualMachines:
        instanceInventory.unclassifiedVirtualMachines,
      prRunners: prRunners.length,
      queuedRuns: queuedRuns.total_count ?? 0,
      unboundRunnerVirtualMachinePairs:
        instanceInventory.unboundRunnerVirtualMachinePairs,
      distinctIdentityBoundaryCount:
        poolBoundaries.distinctIdentityBoundaryCount,
      distinctSubnetCount: poolBoundaries.distinctSubnetCount,
      trustedRunners: trustedRunners.length,
      usableManagedCapacity,
      usableCapacityByTrust,
    },
    nextState,
  };
}

function parseArguments(argv) {
  const result = {};
  for (let index = 0; index < argv.length; index += 2) {
    result[argv[index]] = argv[index + 1];
  }
  return result;
}

const isMain =
  process.argv[1] &&
  import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href;

if (isMain) {
  const args = parseArguments(process.argv.slice(2));
  const required = [
    '--config',
    '--operation',
    '--runners',
    '--queued-runs',
    '--active-runs',
    '--autoscale',
    '--virtual-machines',
    '--vm-scale-sets',
  ];
  for (const argument of required) {
    if (!args[argument]) {
      throw new Error(`Missing ${argument}`);
    }
  }

  const result = evaluateLifecycle({
    config: JSON.parse(fs.readFileSync(args['--config'], 'utf8')),
    operation: args['--operation'],
    runners: JSON.parse(fs.readFileSync(args['--runners'], 'utf8')),
    queuedRuns: JSON.parse(fs.readFileSync(args['--queued-runs'], 'utf8')),
    activeRuns: JSON.parse(fs.readFileSync(args['--active-runs'], 'utf8')),
    autoscale: JSON.parse(fs.readFileSync(args['--autoscale'], 'utf8')),
    virtualMachines: JSON.parse(
      fs.readFileSync(args['--virtual-machines'], 'utf8'),
    ),
    vmScaleSets: JSON.parse(
      fs.readFileSync(args['--vm-scale-sets'], 'utf8'),
    ),
    state: args['--state']
      ? JSON.parse(fs.readFileSync(args['--state'], 'utf8'))
      : {},
  });

  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  if (!result.safeToRequestChange) {
    process.exitCode = 2;
  }
}
