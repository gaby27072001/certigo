import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

import {
  labelsOf,
  reconcileRunnerInstances,
} from './runner-inventory.mjs';

function isCertigoJob(job) {
  const labels = new Set(job.labels ?? []);
  return labels.has('certigo-pr') || labels.has('certigo-trusted');
}

function identitiesOf(scaleSet) {
  const userAssigned = Object.keys(
    scaleSet.identity?.userAssignedIdentities ?? {},
  );
  const systemAssigned = scaleSet.identity?.principalId
    ? [scaleSet.identity.principalId]
    : [];
  return [...userAssigned, ...systemAssigned];
}

export function reduceWorkflowJobState(state, event, now) {
  const nextState = {
    jobs: { ...(state.jobs ?? {}) },
  };
  if (!event?.workflow_job || !isCertigoJob(event.workflow_job)) {
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
  now = Date.now(),
  state = { jobs: {} },
}) {
  if (config.trigger !== 'workflow_job') {
    throw new Error(`Unsupported capacity trigger: ${config.trigger}`);
  }
  if (config.maxAggregateCapacity > 4) {
    throw new Error('maxAggregateCapacity must never exceed 4');
  }

  const nextState = reduceWorkflowJobState(state, event, now);
  const jobs = Object.values(nextState.jobs);
  const stateQueued = jobs.filter((job) => job.status === 'queued').length;
  const stateActive = jobs.filter((job) => job.status === 'in_progress').length;
  const queuedRuns = inventory.runners?.queuedRuns?.total_count ?? 0;
  const activeRuns = inventory.runners?.activeRuns?.total_count ?? 0;
  const queued = Math.max(stateQueued, queuedRuns);
  const active = Math.max(stateActive, activeRuns);
  const oldestQueuedSeconds = queueAgeSeconds(nextState.jobs, now);

  const runners = inventory.runners?.github?.runners ?? [];
  const virtualMachines = inventory.runners?.virtualMachines ?? [];
  const instanceInventory = reconcileRunnerInstances(virtualMachines, runners);
  const certigoRunners = instanceInventory.certigoRunners;
  const busy = certigoRunners.filter((runner) => runner.busy).length;
  const dualTrust = certigoRunners.filter((runner) => {
    const labels = labelsOf(runner);
    return labels.has('certigo-pr') && labels.has('certigo-trusted');
  });
  const exclusivePr = certigoRunners.filter((runner) => {
    const labels = labelsOf(runner);
    return labels.has('certigo-pr') && !labels.has('certigo-trusted');
  });
  const exclusiveTrusted = certigoRunners.filter((runner) => {
    const labels = labelsOf(runner);
    return labels.has('certigo-trusted') && !labels.has('certigo-pr');
  });

  const currentCapacity = virtualMachines.length;
  const usableCapacity = instanceInventory.reconciled.filter(
    ({ runner }) => runner.status === 'online',
  ).length;
  const vmScaleSets = inventory.runners?.vmScaleSets ?? [];
  const distinctPoolIdentities = new Set(
    vmScaleSets.flatMap((scaleSet) => identitiesOf(scaleSet)),
  );
  const identitiesReady =
    vmScaleSets.every((scaleSet) => identitiesOf(scaleSet).length > 0) &&
    distinctPoolIdentities.size >= config.minimumExclusivePools;
  const instanceInventoryReady =
    instanceInventory.missingAzureForRunners.length === 0 &&
    instanceInventory.unregisteredAzureMachines.length === 0 &&
    usableCapacity >= config.modes.normal.aggregateCapacity;
  const exclusivePoolsReady =
    dualTrust.length === 0 &&
    exclusivePr.length > 0 &&
    exclusiveTrusted.length > 0 &&
    vmScaleSets.length >= config.minimumExclusivePools &&
    identitiesReady &&
    instanceInventoryReady;

  let mode = 'normal';
  if (queued === 0 && active === 0 && busy === 0) {
    mode = 'idle';
  } else if (
    queued >= config.boostQueueDepth ||
    oldestQueuedSeconds >= config.boostOldestQueuedSeconds ||
    (queued > 0 && busy >= config.modes.normal.aggregateCapacity)
  ) {
    mode = 'boost';
  }

  const targetCapacity = Math.min(
    config.modes[mode].aggregateCapacity,
    config.maxAggregateCapacity,
  );
  const scaleInSafe =
    queued === 0 &&
    active === 0 &&
    busy === 0 &&
    exclusivePoolsReady;

  let action = 'hold';
  let nextCapacity = currentCapacity;
  if (targetCapacity > currentCapacity && exclusivePoolsReady) {
    action = 'scale-out-one';
    nextCapacity = Math.min(
      currentCapacity + config.scaleStep,
      targetCapacity,
      config.maxAggregateCapacity,
    );
  } else if (targetCapacity < currentCapacity && scaleInSafe) {
    action = 'scale-in-one';
    nextCapacity = Math.max(
      currentCapacity - config.scaleStep,
      targetCapacity,
    );
  }

  const blockers = [];
  if (!config.enabled) {
    blockers.push('capacity controller feature flag is off');
  }
  if (!exclusivePoolsReady) {
    blockers.push(
      'exclusive certigo-pr/certigo-trusted pools and identities are not reconciled',
    );
  }
  if (config.leaseRequired && !leaseHeld) {
    blockers.push('a distributed lease is required before any mutable action');
  }
  if (targetCapacity < currentCapacity && !scaleInSafe) {
    blockers.push('scale-in requires an empty queue, zero active jobs, and no busy runner');
  }

  return {
    readOnly: true,
    featureEnabled: config.enabled,
    trigger: config.trigger,
    mode,
    action,
    currentCapacity,
    usableCapacity,
    targetCapacity,
    nextCapacity,
    maxAggregateCapacity: config.maxAggregateCapacity,
    scaleInSafe,
    canRequestChange:
      config.enabled &&
      exclusivePoolsReady &&
      (!config.leaseRequired || leaseHeld) &&
      action !== 'hold',
    blockers,
    workload: {
      queued,
      active,
      busy,
      oldestQueuedSeconds,
    },
    trust: {
      dualTrustRunners: dualTrust.map((runner) => runner.name),
      exclusivePrRunners: exclusivePr.map((runner) => runner.name),
      exclusiveTrustedRunners: exclusiveTrusted.map((runner) => runner.name),
      distinctPoolIdentityCount: distinctPoolIdentities.size,
      missingAzureForRunners: instanceInventory.missingAzureForRunners,
      unregisteredAzureMachines: instanceInventory.unregisteredAzureMachines,
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
