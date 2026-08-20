import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

import {
  isPoweredCapacity,
  labelsOf,
  reconcileRunnerInstances,
  summarizePoolBoundaries,
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
  let scaleInSafety = null;
  let nextState = { ...state };
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
      rearmSatisfied:
        usableManagedCapacity >= aggregateCapacity(config.modes.normal),
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
            requiredGuards: config.requiredPostQuietGuards,
            quietPeriodSeconds: config.quietPeriodSeconds,
          },
    observed: {
      activeRuns: activeRuns.total_count ?? 0,
      absentRunners: instanceInventory.absentRunners,
      azureVirtualMachines: (virtualMachines ?? []).length,
      certigoRunners: certigoRunners.length,
      dualTrustRunners: dualTrustRunners.length,
      externalVirtualMachines: instanceInventory.externalVirtualMachines,
      managedMachineNames: instanceInventory.managedMachineNames,
      managedPoolNames: poolBoundaries.managedPoolNames,
      unclassifiedVirtualMachines:
        instanceInventory.unclassifiedVirtualMachines,
      prRunners: prRunners.length,
      queuedRuns: queuedRuns.total_count ?? 0,
      distinctIdentityBoundaryCount:
        poolBoundaries.distinctIdentityBoundaryCount,
      distinctSubnetCount: poolBoundaries.distinctSubnetCount,
      trustedRunners: trustedRunners.length,
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
