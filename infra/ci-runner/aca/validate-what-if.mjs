#!/usr/bin/env node

import fs from 'node:fs';
import { pathToFileURL } from 'node:url';

const allowedNamesByType = new Map([
  ['microsoft.operationalinsights/workspaces', new Set(['log-certigo-aca-pilot'])],
  ['microsoft.app/managedenvironments', new Set(['cae-certigo-ci-aca-pilot'])],
  ['microsoft.app/jobs', new Set(['job-certigo-pr-aca'])],
  ['microsoft.insights/diagnosticsettings', new Set(['certigo-aca-pilot-logs'])],
]);
const expectedRelativeIdsByKey = new Map([
  [
    'microsoft.operationalinsights/workspaces/log-certigo-aca-pilot',
    'providers/microsoft.operationalinsights/workspaces/log-certigo-aca-pilot',
  ],
  [
    'microsoft.app/managedenvironments/cae-certigo-ci-aca-pilot',
    'providers/microsoft.app/managedenvironments/cae-certigo-ci-aca-pilot',
  ],
  [
    'microsoft.app/jobs/job-certigo-pr-aca',
    'providers/microsoft.app/jobs/job-certigo-pr-aca',
  ],
  [
    'microsoft.insights/diagnosticsettings/certigo-aca-pilot-logs',
    'providers/microsoft.app/managedenvironments/cae-certigo-ci-aca-pilot'
      + '/providers/microsoft.insights/diagnosticsettings/certigo-aca-pilot-logs',
  ],
]);
const immutableImagePattern =
  /^[a-z0-9.-]+(?:\/[a-z0-9._-]+)+@sha256:[0-9a-f]{64}$/;
const subscriptionPattern =
  /^\/subscriptions\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\/resourcegroups\/([^/]+)\/(.+)$/;

function normalizedType(change) {
  return String(
    change.after?.type
      ?? change.before?.type
      ?? change.resourceType
      ?? '',
  ).toLowerCase();
}

function normalizedName(change) {
  return String(
    change.after?.name
      ?? change.before?.name
      ?? change.resourceId?.split('/').at(-1)
      ?? '',
  ).toLowerCase();
}

function requireInvariant(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function scopedResource(resourceId, resourceGroup) {
  const normalized = String(resourceId ?? '').toLowerCase();
  const match = subscriptionPattern.exec(normalized);
  if (!match || match[1] !== resourceGroup) {
    throw new Error(`resource escapes ${resourceGroup}: ${resourceId}`);
  }
  return {
    baseId: normalized.slice(0, normalized.length - match[2].length - 1),
    normalized,
    relativeId: match[2],
  };
}

function singleEntry(value, label) {
  requireInvariant(Array.isArray(value) && value.length === 1, `${label} must contain one entry`);
  return value[0];
}

function environmentEntries(container, expectedNames, label) {
  requireInvariant(Array.isArray(container.env), `${label} env must be an array`);
  const entries = new Map();
  for (const entry of container.env) {
    requireInvariant(
      typeof entry?.name === 'string' && !entries.has(entry.name),
      `${label} env contains a missing or duplicate name`,
    );
    entries.set(entry.name, entry);
  }
  requireInvariant(
    entries.size === expectedNames.length
      && expectedNames.every((name) => entries.has(name)),
    `${label} env crosses the pilot boundary`,
  );
  return entries;
}

function requireValue(entries, name, value, label) {
  requireInvariant(
    entries.get(name)?.value === value,
    `${label} env ${name} must equal ${value}`,
  );
}

function validatePilotTags(after, label) {
  for (const [name, value] of Object.entries({
    env: 'ci-pilot',
    lifecycle: 'ephemeral',
    trustBoundary: 'untrusted-pr',
    workload: 'github-actions-runner',
  })) {
    requireInvariant(after.tags?.[name] === value, `${label} tag ${name} must equal ${value}`);
  }
}

function validateWorkspace(after) {
  validatePilotTags(after, 'workspace');
  const properties = after.properties ?? {};
  requireInvariant(properties.retentionInDays === 30, 'workspace retention must be 30 days');
  requireInvariant(
    properties.publicNetworkAccessForIngestion === 'Enabled'
      && properties.publicNetworkAccessForQuery === 'Enabled',
    'workspace access must remain explicit for the isolated public pilot',
  );
}

function validateEnvironment(after) {
  validatePilotTags(after, 'managed environment');
  requireInvariant(
    after.identity?.type === 'None' && !after.identity?.userAssignedIdentities,
    'managed environment identity must be None',
  );
  const properties = after.properties ?? {};
  requireInvariant(
    properties.appLogsConfiguration?.destination === 'azure-monitor',
    'managed environment must emit logs to Azure Monitor',
  );
  requireInvariant(properties.zoneRedundant === false, 'managed environment zoning changed');
  requireInvariant(
    !Object.hasOwn(properties, 'vnetConfiguration')
      && !Object.hasOwn(properties, 'infrastructureSubnetId'),
    'managed environment must not attach to a virtual network',
  );
}

function validateDiagnostics(after, scope) {
  const properties = after.properties ?? {};
  requireInvariant(
    String(properties.workspaceId ?? '').toLowerCase()
      === `${scope.baseId}/providers/microsoft.operationalinsights/workspaces/log-certigo-aca-pilot`,
    'diagnostic setting must target the dedicated pilot workspace',
  );
  const logs = singleEntry(properties.logs, 'diagnostic logs');
  requireInvariant(
    logs.categoryGroup === 'allLogs' && logs.enabled === true,
    'diagnostic setting must enable all logs',
  );
  const metrics = singleEntry(properties.metrics, 'diagnostic metrics');
  requireInvariant(
    metrics.category === 'AllMetrics' && metrics.enabled === true,
    'diagnostic setting must enable all metrics',
  );
}

function validateMount(container, label) {
  const mount = singleEntry(container.volumeMounts, `${label} volume mounts`);
  requireInvariant(
    mount.volumeName === 'runner-jit'
      && mount.mountPath === '/var/run/certigo-runner',
    `${label} must mount only the JIT EmptyDir`,
  );
}

function validateJob(after, scope) {
  validatePilotTags(after, 'runner job');
  requireInvariant(
    after.identity?.type === 'None' && !after.identity?.userAssignedIdentities,
    'runner job identity must be None',
  );
  const properties = after.properties ?? {};
  requireInvariant(
    String(properties.environmentId ?? '').toLowerCase()
      === `${scope.baseId}/providers/microsoft.app/managedenvironments/cae-certigo-ci-aca-pilot`,
    'runner job must target the dedicated managed environment',
  );

  const configuration = properties.configuration ?? {};
  requireInvariant(
    configuration.triggerType === 'Event'
      && configuration.replicaRetryLimit === 0
      && configuration.replicaTimeout === 1800,
    'runner job retry or timeout boundary changed',
  );
  requireInvariant(
    !Object.hasOwn(configuration, 'registries'),
    'runner job must not receive registry credentials',
  );
  singleEntry(configuration.secrets, 'runner job secrets');

  const eventTrigger = configuration.eventTriggerConfig ?? {};
  requireInvariant(
    eventTrigger.parallelism === 1 && eventTrigger.replicaCompletionCount === 1,
    'runner job must execute one completion at a time per replica',
  );
  const scale = eventTrigger.scale ?? {};
  requireInvariant(
    scale.minExecutions === 0
      && Number.isInteger(scale.maxExecutions)
      && scale.maxExecutions >= 1
      && scale.maxExecutions <= 2
      && scale.pollingInterval === 30,
    'runner job capacity boundary changed',
  );
  const rule = singleEntry(scale.rules, 'runner scale rules');
  requireInvariant(
    rule.name === 'github-runner' && rule.type === 'github-runner',
    'runner job must use the GitHub runner scaler',
  );
  const metadata = rule.metadata ?? {};
  for (const [name, value] of Object.entries({
    enableEtags: 'true',
    githubAPIURL: 'https://api.github.com',
    labels: 'certigo-pr-aca',
    noDefaultLabels: 'false',
    owner: 'gchambaud_microsoft',
    repos: 'Certigo',
    runnerScope: 'repo',
    targetWorkflowQueueLength: '1',
  })) {
    requireInvariant(metadata[name] === value, `runner scaler metadata ${name} changed`);
  }
  requireInvariant(
    /^[1-9][0-9]*$/.test(metadata.applicationID ?? '')
      && /^[1-9][0-9]*$/.test(metadata.installationID ?? ''),
    'runner scaler GitHub App identifiers must be positive integers',
  );
  const auth = singleEntry(rule.auth, 'runner scaler auth');
  requireInvariant(
    auth.triggerParameter === 'appKey',
    'runner scaler must authenticate only with the GitHub App key',
  );

  const template = properties.template ?? {};
  const runner = singleEntry(template.containers, 'runner containers');
  const init = singleEntry(template.initContainers, 'runner init containers');
  requireInvariant(
    runner.name === 'runner'
      && JSON.stringify(runner.command) === JSON.stringify(['/opt/certigo/run-ephemeral.sh']),
    'runner container command changed',
  );
  requireInvariant(
    init.name === 'jit-config'
      && JSON.stringify(init.command) === JSON.stringify(['node'])
      && JSON.stringify(init.args) === JSON.stringify(['/opt/certigo/prepare-jit.mjs']),
    'JIT init container command changed',
  );
  requireInvariant(
    immutableImagePattern.test(runner.image ?? '')
      && !runner.image.startsWith('invalid.invalid/')
      && runner.image === init.image,
    'runner containers must share one immutable public image',
  );
  requireInvariant(
    runner.resources?.cpu === 2
      && runner.resources?.memory === '4Gi'
      && init.resources?.cpu === 0.25
      && init.resources?.memory === '0.5Gi',
    'runner container resource boundary changed',
  );
  validateMount(runner, 'runner container');
  validateMount(init, 'JIT init container');
  const volume = singleEntry(template.volumes, 'runner volumes');
  requireInvariant(
    volume.name === 'runner-jit' && volume.storageType === 'EmptyDir',
    'runner job must use only the JIT EmptyDir',
  );

  const runnerEnvironment = environmentEntries(
    runner,
    [
      'EXPECTED_RUNNER_LABEL',
      'JIT_CONFIG_PATH',
      'RUNNER_LOG_TO_STDOUT',
      'ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT',
    ],
    'runner container',
  );
  requireValue(runnerEnvironment, 'EXPECTED_RUNNER_LABEL', 'certigo-pr-aca', 'runner container');
  requireValue(
    runnerEnvironment,
    'JIT_CONFIG_PATH',
    '/var/run/certigo-runner/jitconfig',
    'runner container',
  );
  requireInvariant(
    [...runnerEnvironment.values()].every((entry) => !Object.hasOwn(entry, 'secretRef')),
    'runner container must not receive a secret reference',
  );

  const initEnvironment = environmentEntries(
    init,
    [
      'GITHUB_API_URL',
      'GITHUB_OWNER',
      'GITHUB_REPOSITORY',
      'GITHUB_APP_ID',
      'GITHUB_APP_INSTALLATION_ID',
      'GITHUB_APP_PRIVATE_KEY',
      'RUNNER_GROUP_ID',
      'RUNNER_LABEL',
      'JIT_CONFIG_PATH',
    ],
    'JIT init container',
  );
  requireValue(initEnvironment, 'GITHUB_API_URL', 'https://api.github.com', 'JIT init container');
  requireValue(initEnvironment, 'GITHUB_OWNER', 'gchambaud_microsoft', 'JIT init container');
  requireValue(initEnvironment, 'GITHUB_REPOSITORY', 'Certigo', 'JIT init container');
  requireValue(initEnvironment, 'RUNNER_LABEL', 'certigo-pr-aca', 'JIT init container');
  requireValue(
    initEnvironment,
    'JIT_CONFIG_PATH',
    '/var/run/certigo-runner/jitconfig',
    'JIT init container',
  );
  requireInvariant(
    /^[1-9][0-9]*$/.test(initEnvironment.get('GITHUB_APP_ID')?.value ?? '')
      && initEnvironment.get('GITHUB_APP_ID')?.value === metadata.applicationID
      && /^[1-9][0-9]*$/.test(
        initEnvironment.get('GITHUB_APP_INSTALLATION_ID')?.value ?? '',
      )
      && initEnvironment.get('GITHUB_APP_INSTALLATION_ID')?.value
        === metadata.installationID
      && /^[1-9][0-9]*$/.test(initEnvironment.get('RUNNER_GROUP_ID')?.value ?? ''),
    'JIT init identifiers must match the scaler',
  );
  const privateKey = initEnvironment.get('GITHUB_APP_PRIVATE_KEY');
  requireInvariant(
    privateKey
      && Object.hasOwn(privateKey, 'secretRef')
      && !Object.hasOwn(privateKey, 'value'),
    'GitHub App key must reach only the JIT init container by secret reference',
  );
}

function validatePayload(type, after, scope) {
  if (type === 'microsoft.operationalinsights/workspaces') {
    validateWorkspace(after);
  } else if (type === 'microsoft.app/managedenvironments') {
    validateEnvironment(after);
  } else if (type === 'microsoft.insights/diagnosticsettings') {
    validateDiagnostics(after, scope);
  } else if (type === 'microsoft.app/jobs') {
    validateJob(after, scope);
  }
}

export function validateWhatIf(result, options) {
  const pilotEnabled = options.pilotEnabled === true;
  const resourceGroup = String(options.resourceGroup ?? '').toLowerCase();
  if (!resourceGroup) {
    throw new Error('resourceGroup is required');
  }

  const properties = result.properties ?? result;
  if (result.status && result.status !== 'Succeeded') {
    throw new Error(`what-if status is ${result.status}`);
  }
  if (result.error || properties.error) {
    throw new Error('what-if returned an error payload');
  }
  if ((properties.diagnostics ?? []).length > 0) {
    throw new Error('what-if returned diagnostics');
  }
  if ((properties.potentialChanges ?? []).length > 0) {
    throw new Error('what-if returned potential changes');
  }

  const changes = properties.changes ?? [];
  let jobChanges = 0;
  let ignoredChanges = 0;
  const counts = {};
  const seenPilotResources = new Set();
  for (const change of changes) {
    const changeType = String(change.changeType ?? '');
    counts[changeType] = (counts[changeType] ?? 0) + 1;
    if (!['Create', 'NoChange', 'Ignore'].includes(changeType)) {
      throw new Error(`unsafe what-if change type: ${changeType || '<missing>'}`);
    }

    const scope = scopedResource(change.resourceId, resourceGroup);
    const type = normalizedType(change);
    const name = normalizedName(change);
    const key = `${type}/${name}`;
    if (changeType === 'Ignore') {
      if (allowedNamesByType.get(type)?.has(name)) {
        throw new Error(`pilot resource unexpectedly ignored by what-if: ${type}/${name}`);
      }
      ignoredChanges += 1;
      continue;
    }
    if (!allowedNamesByType.get(type)?.has(name)) {
      throw new Error(`resource is outside the ACA pilot allow-list: ${type}/${name}`);
    }
    requireInvariant(
      scope.relativeId === expectedRelativeIdsByKey.get(key),
      `resource id is outside the ACA pilot boundary: ${change.resourceId}`,
    );
    requireInvariant(
      change.after
        && String(change.after.id ?? '').toLowerCase() === scope.normalized
        && normalizedType({ after: change.after }) === type
        && normalizedName({ after: change.after }) === name
        && String(change.after.resourceGroup ?? '').toLowerCase() === resourceGroup,
      `resource payload identity does not match ${type}/${name}`,
    );
    requireInvariant(
      !seenPilotResources.has(key),
      `duplicate ACA pilot resource in what-if: ${type}/${name}`,
    );
    seenPilotResources.add(key);
    validatePayload(type, change.after, scope);
    if (type === 'microsoft.app/jobs') {
      jobChanges += 1;
    }
  }

  if (!pilotEnabled && jobChanges !== 0) {
    throw new Error('disabled preflight must not plan a Container Apps job');
  }
  if (pilotEnabled && jobChanges !== 1) {
    throw new Error('enabled preflight must contain exactly one Container Apps job');
  }
  const expectedPilotResources = new Set(
    [...expectedRelativeIdsByKey.keys()].filter(
      (key) => pilotEnabled || key !== 'microsoft.app/jobs/job-certigo-pr-aca',
    ),
  );
  requireInvariant(
    seenPilotResources.size === expectedPilotResources.size
      && [...expectedPilotResources].every((key) => seenPilotResources.has(key)),
    `what-if must contain exactly ${expectedPilotResources.size} ACA pilot resources`,
  );
  return { counts, ignoredChanges, jobChanges };
}

function cli() {
  const [, , resultPath, state, resourceGroup] = process.argv;
  if (!resultPath || !['enabled', 'disabled'].includes(state) || !resourceGroup) {
    throw new Error(
      'Usage: validate-what-if.mjs <result.json> <enabled|disabled> <resource-group>',
    );
  }
  const result = JSON.parse(fs.readFileSync(resultPath, 'utf8'));
  const summary = validateWhatIf(result, {
    pilotEnabled: state === 'enabled',
    resourceGroup,
  });
  process.stdout.write(`${JSON.stringify(summary)}\n`);
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    cli();
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
