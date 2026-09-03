import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

import {
  isPoweredCapacity,
  reconcileRunnerInstances,
  RUNNER_CLASSES,
  summarizePoolBoundaries,
  trustClassOfRunner,
} from './runner-inventory.mjs';
import {
  advanceScaleInSafety,
  armScaleInReactivation,
} from './scale-in-safety.mjs';

function isCertigoJob(job, runnerClasses) {
  const labels = new Set(job.labels ?? []);
  return runnerClasses.some((runnerClass) => labels.has(runnerClass));
}

function enabledRunnerClasses(config) {
  return config.classOrder.filter((runnerClass) => config.classEnabled[runnerClass]);
}

function modeCapacity(config, mode) {
  const capacity = config.modes?.[mode];
  if (!capacity) {
    throw new Error(`Missing capacity mode: ${mode}`);
  }
  return Object.fromEntries(
    config.classOrder.map((runnerClass) => [
      runnerClass,
      capacity[runnerClass],
    ]),
  );
}

function aggregateCapacity(capacityByTrust) {
  return Object.values(capacityByTrust).reduce(
    (total, capacity) => total + capacity,
    0,
  );
}

function capacityForClasses(capacityByTrust, runnerClasses) {
  return Object.fromEntries(
    runnerClasses.map((runnerClass) => [
      runnerClass,
      capacityByTrust[runnerClass] ?? 0,
    ]),
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

function validateCapacityConfig(config) {
  const trustClasses = config.classOrder;
  if (config.stateVersion !== 3) {
    throw new Error('capacity controller stateVersion must be 3');
  }
  if (config.scaleStep !== 1) {
    throw new Error('scaleStep must remain exactly 1');
  }
  if (
    config.minimumExclusivePools < 2 ||
    config.minimumExclusiveSubnets < 2
  ) {
    throw new Error('at least two exclusive pools and subnets are required');
  }
  if (
    !Array.isArray(config.inventory?.externalGithubRunnerIds) ||
    !Array.isArray(config.inventory?.externalVirtualMachines) ||
    !Array.isArray(config.inventory?.forbiddenVirtualMachines) ||
    !Array.isArray(config.inventory?.managedRunnerBindings) ||
    config.inventory.externalGithubRunnerIds.some(
      (id) => !Number.isInteger(id) || id <= 0,
    ) ||
    config.inventory.externalVirtualMachines.some(
      (name) => typeof name !== 'string' || name.length === 0,
    ) ||
    config.inventory.forbiddenVirtualMachines.some(
      (name) => typeof name !== 'string' || name.length === 0,
    ) ||
    config.inventory.managedRunnerBindings.some(
      (binding) =>
        !Number.isInteger(binding.githubRunnerId) ||
        binding.githubRunnerId <= 0 ||
        typeof binding.runnerName !== 'string' ||
        binding.runnerName.length === 0 ||
        typeof binding.virtualMachineId !== 'string' ||
        binding.virtualMachineId.length === 0 ||
        typeof binding.virtualMachineName !== 'string' ||
        binding.virtualMachineName.length === 0,
    )
  ) {
    throw new Error(
      'inventory classifications and managed runner bindings are invalid',
    );
  }
  if (
    !Array.isArray(trustClasses) ||
    trustClasses.length < 2 ||
    new Set(trustClasses).size !== trustClasses.length ||
    trustClasses.some(
      (runnerClass) =>
        typeof runnerClass !== 'string' ||
        !/^certigo-[a-z0-9-]+$/.test(runnerClass),
    )
  ) {
    throw new Error(
      'classOrder must contain at least two unique certigo-* labels',
    );
  }
  if (
    Object.keys(config.classEnabled ?? {}).sort().join(',') !==
      [...trustClasses].sort().join(',') ||
    trustClasses.some(
      (runnerClass) => typeof config.classEnabled[runnerClass] !== 'boolean',
    )
  ) {
    throw new Error(
      'classEnabled must define every configured runner class exactly once',
    );
  }
  if (
    Object.keys(config.classLifecycle ?? {}).sort().join(',') !==
      [...trustClasses].sort().join(',') ||
    trustClasses.some(
      (runnerClass) =>
        !['managed-reusable', 'ephemeral-delete'].includes(
          config.classLifecycle[runnerClass],
        ),
    )
  ) {
    throw new Error(
      'classLifecycle must define every configured runner class exactly once',
    );
  }
  const managedMachineNames = config.inventory.managedRunnerBindings.map(
    (binding) => binding.virtualMachineName.toLowerCase(),
  );
  const managedRunnerNames = config.inventory.managedRunnerBindings.map(
    (binding) => binding.runnerName.toLowerCase(),
  );
  if (
    new Set(managedMachineNames).size !== managedMachineNames.length ||
    new Set(managedRunnerNames).size !== managedRunnerNames.length
  ) {
    throw new Error('managed runner bindings must be one-to-one');
  }
  if (
    Object.keys(config.pilotTarget ?? {}).sort().join(',') !==
    [...trustClasses].sort().join(',')
  ) {
    throw new Error('pilotTarget must define exactly the four runner classes');
  }
  for (const trustClass of trustClasses) {
    if (
      !Number.isInteger(config.pilotTarget?.[trustClass]) ||
      config.pilotTarget[trustClass] <= 0
    ) {
      throw new Error(`pilotTarget.${trustClass} must be a positive integer`);
    }
    if (
      config.classLifecycle[trustClass] === 'ephemeral-delete' &&
      config.pilotTarget[trustClass] !== 1
    ) {
      throw new Error(
        `ephemeral runner class ${trustClass} must have maximum capacity one`,
      );
    }
  }
  for (const mode of ['idle', 'normal', 'boost']) {
    if (
      Object.keys(config.modes?.[mode] ?? {}).sort().join(',') !==
      [...trustClasses].sort().join(',')
    ) {
      throw new Error(`modes.${mode} must define exactly the four runner classes`);
    }
    const capacity = modeCapacity(config, mode);
    for (const trustClass of trustClasses) {
      if (
        !Number.isInteger(capacity[trustClass]) ||
        capacity[trustClass] < 0 ||
        capacity[trustClass] > config.pilotTarget[trustClass]
      ) {
        throw new Error(
          `modes.${mode}.${trustClass} must be within the pilot target`,
        );
      }
    }
  }
  if (
    enabledRunnerClasses(config).some(
      (trustClass) =>
        modeCapacity(config, 'boost')[trustClass] !==
        config.pilotTarget[trustClass],
    )
  ) {
    throw new Error('boost mode must equal the approved pilot target');
  }
  for (const trustClass of trustClasses.filter(
    (runnerClass) => !config.classEnabled[runnerClass],
  )) {
    if (
      ['idle', 'normal', 'boost'].some(
        (mode) => modeCapacity(config, mode)[trustClass] !== 0,
      )
    ) {
      throw new Error(
        `disabled runner class ${trustClass} must have zero capacity in every mode`,
      );
    }
  }
  if (
    config.quietPeriodSeconds !== 300 ||
    config.requiredPostQuietGuards !== 2
  ) {
    throw new Error(
      'scale-in requires a resettable 300-second quiet period and two guards',
    );
  }
  if (
    !Array.isArray(config.scaleInOrder) ||
    config.scaleInOrder.length !== trustClasses.length ||
    config.scaleInOrder.some(
      (trustClass, index) => trustClass !== trustClasses[index],
    )
  ) {
    throw new Error(
      `scaleInOrder must be exactly ${trustClasses.join(', ')}`,
    );
  }
}

export function reduceWorkflowJobState(
  state,
  event,
  now,
  runnerClasses = RUNNER_CLASSES,
) {
  const nextState = {
    ...state,
    jobs: { ...(state.jobs ?? {}) },
  };
  if (
    !event?.workflow_job ||
    !isCertigoJob(event.workflow_job, runnerClasses)
  ) {
    return nextState;
  }

  const jobId = String(event.workflow_job.id);
  if (event.action === 'completed') {
    delete nextState.jobs[jobId];
    return nextState;
  }

  if (!['queued', 'in_progress', 'waiting'].includes(event.action)) {
    throw new Error(`Unsupported workflow_job action: ${event.action}`);
  }

  const previous = nextState.jobs[jobId] ?? {};
  nextState.jobs[jobId] = {
    labels: event.workflow_job.labels ?? [],
    queuedAt:
      previous.queuedAt ??
      event.workflow_job.created_at ??
      new Date(now).toISOString(),
    status: event.action,
    updatedAt: new Date(now).toISOString(),
  };
  return nextState;
}

function queueAgeSeconds(jobs, now) {
  const queuedAt = Object.values(jobs)
    .filter((job) => job.status === 'queued')
    .map((job) => Date.parse(job.queuedAt))
    .filter(Number.isFinite);
  if (queuedAt.length === 0) {
    return 0;
  }
  return Math.max(0, Math.floor((now - Math.min(...queuedAt)) / 1000));
}

export function createCapacityPlan({
  config,
  event,
  inventory,
  leaseHeld = false,
  leaseGeneration,
  now = Date.now(),
  persistedStateRevision,
  state = { jobs: {} },
}) {
  if (config.trigger !== 'workflow_job') {
    throw new Error(`Unsupported capacity trigger: ${config.trigger}`);
  }
  validateCapacityConfig(config);
  if (
    state.version !== undefined &&
    state.version !== config.stateVersion
  ) {
    throw new Error(
      `capacity state version ${state.version} is not supported`,
    );
  }
  const stateRevision = state.revision ?? 0;
  if (!Number.isInteger(stateRevision) || stateRevision < 0) {
    throw new Error('capacity state revision must be a non-negative integer');
  }
  const persistedRevisionProvided =
    persistedStateRevision !== undefined;
  const persistedRevision = persistedRevisionProvided
    ? persistedStateRevision
    : null;
  if (
    persistedRevisionProvided &&
    (!Number.isInteger(persistedRevision) || persistedRevision < 0)
  ) {
    throw new Error(
      'persisted state revision must be a non-negative integer',
    );
  }
  const leaseGenerationValid =
    Number.isInteger(leaseGeneration) && leaseGeneration > 0;
  const sameLeaseGeneration =
    state.leaseGeneration === undefined ||
    state.leaseGeneration === leaseGeneration;
  const mutationFenceReady =
    !config.leaseRequired ||
    (leaseHeld &&
      leaseGenerationValid &&
      sameLeaseGeneration &&
      persistedRevisionProvided &&
      persistedRevision === stateRevision);

  const nextState = reduceWorkflowJobState(
    state,
    event,
    now,
    config.classOrder,
  );
  nextState.version = config.stateVersion;
  nextState.revision = stateRevision + 1;
  if (leaseGenerationValid) {
    nextState.leaseGeneration = leaseGeneration;
  }
  if (!sameLeaseGeneration) {
    nextState.scaleInSafety = {};
  }
  const jobs = Object.values(nextState.jobs);
  const stateQueued = jobs.filter((job) => job.status === 'queued').length;
  const stateActive = jobs.filter((job) => job.status === 'in_progress').length;
  const queuedRuns = inventory.runners?.queuedRuns?.total_count ?? 0;
  const activeRuns = inventory.runners?.activeRuns?.total_count ?? 0;
  const queued = Math.max(stateQueued, queuedRuns);
  const active = Math.max(stateActive, activeRuns);
  const oldestQueuedSeconds = queueAgeSeconds(nextState.jobs, now);
  const queuedByTrust = Object.fromEntries(
    config.classOrder.map((runnerClass) => [runnerClass, 0]),
  );
  const activeByTrust = Object.fromEntries(
    config.classOrder.map((runnerClass) => [runnerClass, 0]),
  );
  for (const job of jobs.filter((candidate) => candidate.status === 'queued')) {
    const trustClass = trustClassOfRunner(job, config.classOrder);
    if (config.classOrder.includes(trustClass)) {
      queuedByTrust[trustClass] += 1;
    }
  }
  for (const job of jobs.filter(
    (candidate) => candidate.status === 'in_progress',
  )) {
    const trustClass = trustClassOfRunner(job, config.classOrder);
    if (config.classOrder.includes(trustClass)) {
      activeByTrust[trustClass] += 1;
    }
  }
  const disabledRunnerClasses = config.classOrder.filter(
    (runnerClass) => !config.classEnabled[runnerClass],
  );
  const disabledClassDemand = disabledRunnerClasses.some(
    (runnerClass) =>
      queuedByTrust[runnerClass] > 0 || activeByTrust[runnerClass] > 0,
  );

  const runners = inventory.runners?.github?.runners ?? [];
  const virtualMachines = inventory.runners?.virtualMachines ?? [];
  const instanceInventory = reconcileRunnerInstances(
    virtualMachines,
    runners,
    {
      ...config.inventory,
      runnerClasses: config.classOrder,
    },
  );
  const certigoRunners = instanceInventory.certigoRunners;
  const busy = certigoRunners.filter((runner) => runner.busy).length;
  const dualTrust = certigoRunners.filter(
    (runner) => trustClassOfRunner(runner, config.classOrder) === 'dual',
  );
  const managedByTrust = Object.fromEntries(
    config.classOrder.map((runnerClass) => [runnerClass, []]),
  );
  for (const managedInstance of instanceInventory.managedInstances) {
    const trustClass = trustClassOfRunner(
      managedInstance.runner,
      config.classOrder,
    );
    if (config.classOrder.includes(trustClass)) {
      managedByTrust[trustClass].push(managedInstance);
    }
  }
  const exclusiveRunnersByClass = Object.fromEntries(
    Object.entries(managedByTrust).map(([runnerClass, managedInstances]) => [
      runnerClass,
      managedInstances.map(({ runner }) => runner),
    ]),
  );
  const exclusivePr = exclusiveRunnersByClass['certigo-pr'] ?? [];
  const exclusiveTrusted = exclusiveRunnersByClass['certigo-trusted'] ?? [];

  const poweredManagedInstances = instanceInventory.managedInstances.filter(
    ({ virtualMachine }) => isPoweredCapacity(virtualMachine),
  );
  const currentCapacity = poweredManagedInstances.length;
  const physicalManagedCapacity = instanceInventory.managedInstances.length;
  const usableCapacity = poweredManagedInstances.filter(
    ({ runner }) => runner.status === 'online',
  ).length;
  const currentCapacityByTrust = Object.fromEntries(
    Object.entries(managedByTrust).map(([trustClass, managedInstances]) => [
      trustClass,
      managedInstances.filter(({ virtualMachine }) =>
        isPoweredCapacity(virtualMachine),
      ).length,
    ]),
  );
  const usableCapacityByTrust = Object.fromEntries(
    Object.entries(managedByTrust).map(([trustClass, managedInstances]) => [
      trustClass,
      managedInstances.filter(
        ({ runner, virtualMachine }) =>
          runner.status === 'online' &&
          isPoweredCapacity(virtualMachine),
      ).length,
    ]),
  );
  const vmScaleSets = inventory.runners?.vmScaleSets ?? [];
  const poolBoundaries = summarizePoolBoundaries(
    vmScaleSets,
    instanceInventory.managedInstances,
    config.classOrder,
  );
  const identitiesReady =
    poolBoundaries.distinctIdentityBoundaryCount >=
      config.minimumExclusivePools &&
    poolBoundaries.poolsWithoutIdentityEvidence.length === 0 &&
    poolBoundaries.sharedIdentityIds.length === 0;
  const subnetsReady =
    poolBoundaries.distinctSubnetCount >= config.minimumExclusiveSubnets &&
    poolBoundaries.poolsWithoutSubnet.length === 0 &&
    poolBoundaries.sharedSubnetIds.length === 0;
  const instanceInventoryReady =
    instanceInventory.absentRunners.length === 0 &&
    instanceInventory.bindingMismatches.length === 0 &&
    instanceInventory.forbiddenVirtualMachinesPresent.length === 0 &&
    instanceInventory.missingManagedRunnerVirtualMachines.length === 0 &&
    instanceInventory.unboundRunnerVirtualMachinePairs.length === 0 &&
    instanceInventory.unclassifiedVirtualMachines.length === 0 &&
    physicalManagedCapacity >= aggregateCapacity(modeCapacity(config, 'normal'));
  const capacityEnabledRunnerClasses = enabledRunnerClasses(config);
  const exclusiveBoundariesReady =
    dualTrust.length === 0 &&
    capacityEnabledRunnerClasses.every(
      (runnerClass) => exclusiveRunnersByClass[runnerClass].length > 0,
    ) &&
    poolBoundaries.managedPoolCount >= config.minimumExclusivePools &&
    poolBoundaries.managedInstancesWithoutPool.length === 0 &&
    poolBoundaries.missingManagedScaleSets.length === 0 &&
    poolBoundaries.poolsWithMixedTrustLabels.length === 0 &&
    capacityEnabledRunnerClasses.every(
      (runnerClass) =>
        poolBoundaries.trustClassPoolCounts[runnerClass] > 0,
    ) &&
    identitiesReady &&
    subnetsReady &&
    instanceInventoryReady;

  const normalCapacity = aggregateCapacity(modeCapacity(config, 'normal'));
  let mode = 'normal';
  if (queued === 0 && active === 0 && busy === 0) {
    mode = 'idle';
  } else if (
    queued >= config.boostQueueDepth ||
    oldestQueuedSeconds >= config.boostOldestQueuedSeconds ||
    (queued > 0 && busy >= normalCapacity)
  ) {
    mode = 'boost';
  }

  const targetCapacityByTrust = modeCapacity(config, mode);
  const targetCapacity = aggregateCapacity(targetCapacityByTrust);
  const workloadIdle = queued === 0 && active === 0 && busy === 0;
  const pendingRearmTarget =
    nextState.scaleInSafety?.rearmTargetCapacityByTrust ?? null;
  const scaleInBaseSafe =
    workloadIdle &&
    exclusiveBoundariesReady &&
    Object.keys(currentCapacityByTrust).every(
      (trustClass) =>
        usableCapacityByTrust[trustClass] ===
        currentCapacityByTrust[trustClass],
    );
  const scaleInSafety = advanceScaleInSafety({
    idle: scaleInBaseSafe,
    now,
    quietPeriodSeconds: config.quietPeriodSeconds,
    rearmSatisfied: capacitySatisfies(
      usableCapacityByTrust,
      pendingRearmTarget,
    ),
    requiredGuards: config.requiredPostQuietGuards,
    state: nextState.scaleInSafety,
  });
  nextState.scaleInSafety = scaleInSafety.nextState;
  const scaleInSafe = scaleInBaseSafe && scaleInSafety.ready;
  const effectiveTargetCapacityByTrust = {
    ...targetCapacityByTrust,
  };
  if (scaleInSafety.rearmRequired) {
    for (const [trustClass, capacity] of Object.entries(
      scaleInSafety.rearmTargetCapacityByTrust,
    )) {
      effectiveTargetCapacityByTrust[trustClass] = Math.max(
        effectiveTargetCapacityByTrust[trustClass] ?? 0,
        capacity,
      );
    }
  }

  let action = 'hold';
  let nextCapacity = currentCapacity;
  let targetTrustClass = null;
  const nextCapacityByTrust = { ...currentCapacityByTrust };
  const requestedScaleOutCandidates = Object.keys(
    effectiveTargetCapacityByTrust,
  ).filter(
    (trustClass) =>
      effectiveTargetCapacityByTrust[trustClass] >
      usableCapacityByTrust[trustClass],
  );
  const scaleOutCandidates = requestedScaleOutCandidates.filter(
    (trustClass) =>
      config.classEnabled[trustClass] &&
      currentCapacityByTrust[trustClass] <
      config.pilotTarget[trustClass],
  );
  const enabledPilotTarget = capacityForClasses(
    config.pilotTarget,
    capacityEnabledRunnerClasses,
  );
  if (
    !disabledClassDemand &&
    scaleOutCandidates.length > 0 &&
    currentCapacity < aggregateCapacity(enabledPilotTarget) &&
    exclusiveBoundariesReady
  ) {
    action = 'scale-out-one';
    targetTrustClass = scaleOutCandidates
      .sort((left, right) => {
        const queuePriority =
          Number(queuedByTrust[right] > 0) -
          Number(queuedByTrust[left] > 0);
        if (queuePriority !== 0) {
          return queuePriority;
        }
        return (
          effectiveTargetCapacityByTrust[right] -
          usableCapacityByTrust[right] -
          (effectiveTargetCapacityByTrust[left] -
            usableCapacityByTrust[left])
        );
      })[0];
    nextCapacity = currentCapacity + config.scaleStep;
    nextCapacityByTrust[targetTrustClass] += config.scaleStep;
  } else if (
    !disabledClassDemand &&
    targetCapacity < currentCapacity &&
    scaleInSafe
  ) {
    action = 'scale-in-one';
    targetTrustClass = config.scaleInOrder.find(
      (trustClass) =>
        currentCapacityByTrust[trustClass] >
        targetCapacityByTrust[trustClass],
    );
    nextCapacity = Math.max(currentCapacity - config.scaleStep, targetCapacity);
    nextCapacityByTrust[targetTrustClass] -= config.scaleStep;
  }

  const blockers = [];
  if (!config.enabled) {
    blockers.push('capacity controller feature flag is off');
  }
  if (!exclusiveBoundariesReady) {
    blockers.push(
      `exclusive ${capacityEnabledRunnerClasses.join('/')} labels, identities, and subnets are not reconciled`,
    );
  }
  if (disabledClassDemand) {
    blockers.push(
      `queued or active work targets disabled runner classes: ${disabledRunnerClasses.join(', ')}`,
    );
  }
  if (config.leaseRequired && !leaseHeld) {
    blockers.push('a distributed lease is required before any mutable action');
  }
  if (
    config.leaseRequired &&
    leaseHeld &&
    (!leaseGenerationValid || !sameLeaseGeneration)
  ) {
    blockers.push(
      'the distributed lease requires a stable positive fencing generation',
    );
  }
  if (!persistedRevisionProvided) {
    blockers.push(
      'the persisted capacity state revision is required before any mutable action',
    );
  } else if (persistedRevision !== stateRevision) {
    blockers.push(
      'the capacity state revision is stale and must be reloaded before planning',
    );
  }
  if (targetCapacity < currentCapacity && !scaleInSafe) {
    blockers.push(
      'scale-in requires a resettable five-minute quiet period followed by two guards',
    );
  }
  if (
    requestedScaleOutCandidates.length > 0 &&
    (scaleOutCandidates.length === 0 ||
      currentCapacity >= aggregateCapacity(enabledPilotTarget))
  ) {
    blockers.push(
      'usable capacity is below target but the pilot capacity boundary forbids another instance',
    );
  }

  const canRequestChange =
    config.enabled &&
    exclusiveBoundariesReady &&
    mutationFenceReady &&
    !disabledClassDemand &&
    action !== 'hold';
  const targetInstanceAction =
    action === 'hold'
      ? 'none'
      : config.classLifecycle[targetTrustClass] === 'ephemeral-delete'
        ? action === 'scale-out-one'
          ? 'create-fresh'
          : 'delete-retired'
        : action === 'scale-out-one'
          ? 'start-or-create'
          : 'deallocate';
  if (action === 'scale-in-one' && canRequestChange) {
    nextState.scaleInSafety = armScaleInReactivation(
      nextState.scaleInSafety,
      usableCapacityByTrust,
    );
  }

  return {
    readOnly: true,
    featureEnabled: config.enabled,
    trigger: config.trigger,
    mode,
    action,
    currentCapacity,
    currentCapacityByTrust,
    physicalManagedCapacity,
    usableCapacity,
    usableCapacityByTrust,
    targetCapacity,
    targetCapacityByTrust,
    effectiveTargetCapacityByTrust,
    targetTrustClass,
    targetInstanceAction,
    nextCapacity,
    nextCapacityByTrust,
    pilotTarget: config.pilotTarget,
    pilotTargetCapacity: aggregateCapacity(enabledPilotTarget),
    runnerClasses: config.classOrder,
    classEnabled: config.classEnabled,
    classLifecycle: config.classLifecycle,
    scaleInSafe,
    canRequestChange,
    blockers,
    mutationFence: {
      leaseGeneration: leaseGenerationValid ? leaseGeneration : null,
      persistedStateRevision: persistedRevision,
      requiredStateRevision: stateRevision,
      ready: mutationFenceReady,
    },
    safety: {
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
    workload: {
      queued,
      queuedByTrust,
      active,
      activeByTrust,
      busy,
      oldestQueuedSeconds,
    },
    trust: {
      dualTrustRunners: dualTrust.map((runner) => runner.name),
      exclusivePrRunners: exclusivePr.map((runner) => runner.name),
      exclusiveTrustedRunners: exclusiveTrusted.map((runner) => runner.name),
      exclusiveRunnersByClass: Object.fromEntries(
        Object.entries(exclusiveRunnersByClass).map(
          ([runnerClass, classRunners]) => [
            runnerClass,
            classRunners.map((runner) => runner.name),
          ],
        ),
      ),
      absentRunners: instanceInventory.absentRunners,
      bindingMismatches: instanceInventory.bindingMismatches,
      distinctIdentityBoundaryCount:
        poolBoundaries.distinctIdentityBoundaryCount,
      distinctSubnetCount: poolBoundaries.distinctSubnetCount,
      externalVirtualMachines: instanceInventory.externalVirtualMachines,
      externalGitHubRunnerIds: instanceInventory.externalGitHubRunners.map(
        (runner) => Number(runner.id),
      ),
      forbiddenVirtualMachinesPresent:
        instanceInventory.forbiddenVirtualMachinesPresent,
      managedMachineNames: instanceInventory.managedMachineNames,
      managedPoolNames: poolBoundaries.managedPoolNames,
      managedInstancesWithoutPool:
        poolBoundaries.managedInstancesWithoutPool,
      missingManagedScaleSets: poolBoundaries.missingManagedScaleSets,
      missingManagedRunnerVirtualMachines:
        instanceInventory.missingManagedRunnerVirtualMachines,
      poolsWithoutSubnet: poolBoundaries.poolsWithoutSubnet,
      poolsWithoutIdentityEvidence:
        poolBoundaries.poolsWithoutIdentityEvidence,
      poolsWithMixedTrustLabels:
        poolBoundaries.poolsWithMixedTrustLabels,
      sharedIdentityIds: poolBoundaries.sharedIdentityIds,
      sharedSubnetIds: poolBoundaries.sharedSubnetIds,
      unboundRunnerVirtualMachinePairs:
        instanceInventory.unboundRunnerVirtualMachinePairs,
      unclassifiedVirtualMachines:
        instanceInventory.unclassifiedVirtualMachines,
      vmScaleSetCount: vmScaleSets.length,
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

function readOptionalJson(fileName, fallback) {
  return fileName ? JSON.parse(fs.readFileSync(fileName, 'utf8')) : fallback;
}

const isMain =
  process.argv[1] &&
  import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href;

if (isMain) {
  const args = parseArguments(process.argv.slice(2));
  for (const argument of ['--config', '--inventory']) {
    if (!args[argument]) {
      throw new Error(`Missing ${argument}`);
    }
  }

  const plan = createCapacityPlan({
    config: JSON.parse(fs.readFileSync(args['--config'], 'utf8')),
    event: readOptionalJson(args['--event'], null),
    inventory: JSON.parse(fs.readFileSync(args['--inventory'], 'utf8')),
    state: readOptionalJson(args['--state'], { jobs: {} }),
  });
  process.stdout.write(`${JSON.stringify(plan, null, 2)}\n`);
}
