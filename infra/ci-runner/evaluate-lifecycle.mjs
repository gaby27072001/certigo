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

export function isIgnorableSystemDependabotRun(run) {
  const jobs = run?.jobs;
  return (
    run?.actor?.login === 'dependabot[bot]' &&
    run?.event === 'dynamic' &&
    Array.isArray(jobs) &&
    jobs.length > 0 &&
    jobs.every((job) => {
      const labels = job.labels ?? [];
      return (
        !job.runner_name &&
        labels.length === 1 &&
        labels[0] === 'dependabot'
      );
    })
  );
}

function summarizeWorkflowRuns(collection) {
  if (!Array.isArray(collection?.workflow_runs)) {
    return {
      blockingCount: collection?.total_count ?? 0,
      ignoredRunIds: [],
    };
  }

  const ignored = collection.workflow_runs.filter(
    isIgnorableSystemDependabotRun,
  );
  return {
    blockingCount: collection.workflow_runs.length - ignored.length,
    ignoredRunIds: ignored.map((run) => run.id).sort(),
  };
}

function isExplicitlyDeallocated(virtualMachine) {
  return String(virtualMachine.powerState ?? '')
    .toLowerCase()
    .includes('deallocated');
}

function observedRunnerInventory(runners, bindings = []) {
  if (bindings.length === 0) {
    return {
      bindingMismatches: [],
      missingBindings: [],
      runners: [],
    };
  }

  const observed = [];
  const bindingMismatches = [];
  const missingBindings = [];
  for (const binding of bindings) {
    const candidates = runners.filter(
      (runner) =>
        Number(runner.id) === binding.githubRunnerId &&
        String(runner.repository ?? '').toLowerCase() ===
          String(binding.repository).toLowerCase(),
    );
    if (candidates.length !== 1) {
      missingBindings.push(
        `${binding.repository}#${binding.githubRunnerId} (${binding.runnerName})`,
      );
      continue;
    }
    const candidate = candidates[0];
    if (candidate.name !== binding.runnerName) {
      bindingMismatches.push(
        `${binding.repository}#${binding.githubRunnerId}: ${candidate.name} != ${binding.runnerName}`,
      );
      continue;
    }
    observed.push(candidate);
  }

  return {
    bindingMismatches: bindingMismatches.sort(),
    missingBindings: missingBindings.sort(),
    runners: observed,
  };
}

function validateObservedRunnerBindings(config) {
  const managedBindings = config.inventory?.managedRunnerBindings ?? [];
  const observedBindings = config.inventory?.observedRunnerBindings ?? [];
  const repositories = config.repositories ?? [];
  if (
    !Array.isArray(repositories) ||
    repositories.length === 0 ||
    repositories.some(
      (repository) =>
        typeof repository !== 'string' || repository.length === 0,
    )
  ) {
    throw new Error('lifecycle repositories must be a non-empty array');
  }
  if (managedBindings.length === 0 && observedBindings.length === 0) {
    return;
  }
  if (!Array.isArray(observedBindings) || observedBindings.length === 0) {
    throw new Error(
      'managed lifecycle capacity requires observed runner bindings',
    );
  }

  const repositoryNames = new Set(
    repositories.map((repository) => repository.toLowerCase()),
  );
  const managedMachineNames = new Set(
    managedBindings.map((binding) =>
      String(binding.virtualMachineName).toLowerCase(),
    ),
  );
  const observedKeys = new Set();
  const observedRunnerNames = new Set();
  const observedMachineNames = new Set();
  for (const binding of observedBindings) {
    const repository = String(binding.repository ?? '').toLowerCase();
    const runnerName = String(binding.runnerName ?? '').toLowerCase();
    const machineName = String(
      binding.virtualMachineName ?? '',
    ).toLowerCase();
    const key = `${repository}#${binding.githubRunnerId}`;
    if (
      !repositoryNames.has(repository) ||
      !Number.isInteger(binding.githubRunnerId) ||
      binding.githubRunnerId <= 0 ||
      !runnerName ||
      !managedMachineNames.has(machineName) ||
      observedKeys.has(key) ||
      observedRunnerNames.has(`${repository}#${runnerName}`)
    ) {
      throw new Error('observed runner bindings are invalid');
    }
    observedKeys.add(key);
    observedRunnerNames.add(`${repository}#${runnerName}`);
    observedMachineNames.add(machineName);
  }
  if (
    [...managedMachineNames].some(
      (machineName) => !observedMachineNames.has(machineName),
    )
  ) {
    throw new Error(
      'every managed machine requires an observed runner binding',
    );
  }
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
  validateObservedRunnerBindings(config);
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
  const observedRunners = observedRunnerInventory(
    repositoryRunners,
    config.inventory?.observedRunnerBindings,
  );
  if (observedRunners.missingBindings.length > 0) {
    reasons.push(
      `missing observed runner bindings: ${observedRunners.missingBindings.join(', ')}`,
    );
  }
  if (observedRunners.bindingMismatches.length > 0) {
    reasons.push(
      `observed runner binding mismatches: ${observedRunners.bindingMismatches.join(', ')}`,
    );
  }

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
  const queuedRunSummary = summarizeWorkflowRuns(queuedRuns);
  const activeRunSummary = summarizeWorkflowRuns(activeRuns);
  const lifecycleRunners =
    observedRunners.runners.length > 0
      ? observedRunners.runners
      : certigoRunners;
  const busyLifecycleRunners = lifecycleRunners.filter(
    (runner) => runner.busy === true,
  );
  const unknownBusyLifecycleRunners = lifecycleRunners.filter(
    (runner) => runner.busy !== true && runner.busy !== false,
  );
  const expectedManagedMachineCount = new Set(
    (config.inventory?.managedRunnerBindings ?? []).map((binding) =>
      String(binding.virtualMachineName).toLowerCase(),
    ),
  ).size;
  const managedInventoryIsExact =
    expectedManagedMachineCount > 0 &&
    instanceInventory.managedInstances.length ===
      expectedManagedMachineCount &&
    instanceInventory.bindingMismatches.length === 0 &&
    instanceInventory.missingManagedRunnerVirtualMachines.length === 0 &&
    instanceInventory.forbiddenVirtualMachinesPresent.length === 0 &&
    instanceInventory.unclassifiedVirtualMachines.length === 0 &&
    instanceInventory.unboundRunnerVirtualMachinePairs.length === 0;
  const terminalAlreadyDeallocated =
    operation === 'deallocate' &&
    managedInventoryIsExact &&
    instanceInventory.managedInstances.every(({ virtualMachine }) =>
      isExplicitlyDeallocated(virtualMachine),
    ) &&
    observedRunners.missingBindings.length === 0 &&
    observedRunners.bindingMismatches.length === 0 &&
    busyLifecycleRunners.length === 0 &&
    unknownBusyLifecycleRunners.length === 0 &&
    queuedRunSummary.blockingCount === 0 &&
    activeRunSummary.blockingCount === 0;
  let scaleInSafety = null;
  let nextState = { ...state, version: config.stateVersion };
  if (operation === 'deallocate') {
    if (busyLifecycleRunners.length > 0) {
      reasons.push(
        `busy runners: ${busyLifecycleRunners.map((runner) => runner.name).join(', ')}`,
      );
    }
    if (unknownBusyLifecycleRunners.length > 0) {
      reasons.push(
        `runner busy state is not explicit: ${unknownBusyLifecycleRunners.map((runner) => runner.name).join(', ')}`,
      );
    }
    if (queuedRunSummary.blockingCount > 0) {
      reasons.push(
        `queued workflow runs: ${queuedRunSummary.blockingCount}`,
      );
    }
    if (activeRunSummary.blockingCount > 0) {
      reasons.push(
        `active workflow runs: ${activeRunSummary.blockingCount}`,
      );
    }
    if (!terminalAlreadyDeallocated) {
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
        busyLifecycleRunners.length === 0 &&
        queuedRunSummary.blockingCount === 0 &&
        activeRunSummary.blockingCount === 0;
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
    } else {
      nextState.scaleInSafety = state.scaleInSafety ?? null;
    }
  }

  const safeToRequestChange =
    !terminalAlreadyDeallocated && reasons.length === 0;
  if (operation === 'deallocate' && safeToRequestChange) {
    nextState.scaleInSafety = armScaleInReactivation(
      nextState.scaleInSafety,
      usableCapacityByTrust,
    );
  }

  return {
    operation,
    preflightOnly: true,
    requestedChange: safeToRequestChange ? operation : 'none',
    safeToRequestChange,
    terminalAlreadyDeallocated,
    terminalSafe: terminalAlreadyDeallocated,
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
      activeRuns: activeRunSummary.blockingCount,
      absentRunners: instanceInventory.absentRunners,
      bindingMismatches: instanceInventory.bindingMismatches,
      azureVirtualMachines: (virtualMachines ?? []).length,
      certigoRunners: certigoRunners.length,
      dualTrustRunners: dualTrustRunners.length,
      externalVirtualMachines: instanceInventory.externalVirtualMachines,
      forbiddenVirtualMachinesPresent:
        instanceInventory.forbiddenVirtualMachinesPresent,
      ignoredSystemDependabotRunIds: [
        ...queuedRunSummary.ignoredRunIds,
        ...activeRunSummary.ignoredRunIds,
      ].sort(),
      managedMachineNames: instanceInventory.managedMachineNames,
      managedPoolNames: poolBoundaries.managedPoolNames,
      missingManagedRunnerVirtualMachines:
        instanceInventory.missingManagedRunnerVirtualMachines,
      observedRunnerBindingMismatches:
        observedRunners.bindingMismatches,
      missingObservedRunnerBindings: observedRunners.missingBindings,
      unclassifiedVirtualMachines:
        instanceInventory.unclassifiedVirtualMachines,
      prRunners: prRunners.length,
      queuedRuns: queuedRunSummary.blockingCount,
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
  if (!result.safeToRequestChange && !result.terminalSafe) {
    process.exitCode = 2;
  }
}
