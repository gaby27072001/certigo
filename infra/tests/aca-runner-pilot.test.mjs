import assert from 'node:assert/strict';
import {
  createVerify,
  generateKeyPairSync,
} from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import {
  createAppJwt,
  requestJitConfiguration,
} from '../ci-runner/aca/image/prepare-jit.mjs';
import { validateWhatIf } from '../ci-runner/aca/validate-what-if.mjs';

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
  '..',
);
const acaRoot = path.join(repositoryRoot, 'infra', 'ci-runner', 'aca');
const bicep = fs.readFileSync(path.join(acaRoot, 'main.bicep'), 'utf8');
const dockerfile = fs.readFileSync(
  path.join(acaRoot, 'image', 'Dockerfile'),
  'utf8',
);
const runner = fs.readFileSync(
  path.join(acaRoot, 'image', 'run-ephemeral.sh'),
  'utf8',
);
const preflight = fs.readFileSync(
  path.join(acaRoot, 'preflight.ps1'),
  'utf8',
);
const workflow = fs.readFileSync(
  path.join(repositoryRoot, '.github', 'workflows', 'ci-aca-pilot.yml'),
  'utf8',
);

test('ACA resources remain disabled and identity-free by default', () => {
  assert.match(bicep, /param pilotEnabled bool = false/);
  assert.match(
    bicep,
    /resource runnerJob 'Microsoft\.App\/jobs@2025-01-01' = if \(pilotEnabled\)/,
  );
  assert.match(bicep, /minExecutions: 0/);
  assert.match(bicep, /maxExecutions: maxExecutions/);
  assert.match(bicep, /@maxValue\(2\)/);
  assert.match(bicep, /replicaRetryLimit: 0/);
  assert.match(bicep, /parallelism: 1/);
  assert.match(bicep, /replicaCompletionCount: 1/);
  assert.doesNotMatch(bicep, /ephemeralStorage:/);
  assert.equal((bicep.match(/type: 'None'/g) ?? []).length, 2);
  assert.doesNotMatch(bicep, /userAssignedIdentities|registry|vnet|subnet/i);
});

test('GitHub App key is limited to KEDA and the init container', () => {
  assert.match(bicep, /triggerParameter: 'appKey'/);
  assert.match(
    bicep,
    /name: 'jit-config'[\s\S]*?name: 'GITHUB_APP_PRIVATE_KEY'[\s\S]*?secretRef: 'github-app-key'/,
  );
  const runnerContainer = bicep.slice(bicep.indexOf("name: 'runner'"));
  assert.doesNotMatch(runnerContainer, /GITHUB_APP_PRIVATE_KEY|github-app-key/);
  assert.match(runner, /Forbidden control-plane or Azure identity variable/);
  assert.match(runner, /169\.254\.169\.254/);
  assert.match(runner, /\.\/run\.sh --jitconfig/);
  assert.match(runner, /RUNNER_LOG_TO_STDOUT=1/);
});

test('runner image and GitHub runner payload are pinned', () => {
  assert.match(
    dockerfile,
    /^FROM node:20\.20\.2-bookworm-slim@sha256:[0-9a-f]{64}$/m,
  );
  assert.match(dockerfile, /ARG RUNNER_VERSION=2\.336\.0/);
  assert.match(dockerfile, /ARG RUNNER_SHA256=[0-9a-f]{64}/);
  assert.match(dockerfile, /sha256sum --check --strict/);
  assert.doesNotMatch(dockerfile, /docker|containerd|sudo/i);
});

test('JIT bootstrap requests one exact ephemeral repository runner', async () => {
  const { privateKey, publicKey } = generateKeyPairSync('rsa', {
    modulusLength: 2048,
    privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
    publicKeyEncoding: { type: 'spki', format: 'pem' },
  });
  const calls = [];
  const fetchImpl = async (url, options) => {
    calls.push({ url: String(url), options });
    if (String(url).includes('/access_tokens')) {
      return new Response(JSON.stringify({ token: 'installation-token' }), {
        status: 201,
        headers: { 'content-type': 'application/json' },
      });
    }
    return new Response(JSON.stringify({
      runner: {
        id: 99,
        ephemeral: true,
        labels: [
          { name: 'self-hosted' },
          { name: 'Linux' },
          { name: 'X64' },
          { name: 'certigo-pr-aca' },
        ],
      },
      encoded_jit_config: 'encoded-once',
    }), {
      status: 201,
      headers: { 'content-type': 'application/json' },
    });
  };

  const result = await requestJitConfiguration({
    apiUrl: 'https://api.github.com',
    owner: 'gchambaud_microsoft',
    repository: 'Certigo',
    appId: '123',
    installationId: '456',
    privateKey,
    runnerGroupId: '1',
    runnerLabel: 'certigo-pr-aca',
  }, fetchImpl);

  assert.equal(result.encodedJitConfig, 'encoded-once');
  assert.match(result.runnerName, /^certigo-aca-[0-9a-f]{16}$/);
  assert.equal(calls.length, 2);
  const installationBody = JSON.parse(calls[0].options.body);
  assert.deepEqual(installationBody, {
    repositories: ['Certigo'],
    permissions: {
      actions: 'read',
      administration: 'write',
    },
  });
  const jwt = calls[0].options.headers.authorization.replace(/^Bearer /, '');
  const [header, payload, signature] = jwt.split('.');
  const verifier = createVerify('RSA-SHA256');
  verifier.update(`${header}.${payload}`);
  verifier.end();
  assert.equal(verifier.verify(publicKey, signature, 'base64url'), true);

  const jitBody = JSON.parse(calls[1].options.body);
  assert.equal(jitBody.runner_group_id, 1);
  assert.deepEqual(jitBody.labels, [
    'self-hosted',
    'Linux',
    'X64',
    'certigo-pr-aca',
  ]);
  assert.equal(calls[1].options.headers.authorization, 'Bearer installation-token');
});

test('JIT bootstrap rejects trust-boundary label substitution', async () => {
  await assert.rejects(
    requestJitConfiguration({
      apiUrl: 'https://api.github.com',
      owner: 'gchambaud_microsoft',
      repository: 'Certigo',
      appId: '123',
      installationId: '456',
      privateKey: 'unused',
      runnerGroupId: '1',
      runnerLabel: 'certigo-trusted',
    }, async () => {
      throw new Error('network must not be reached');
    }),
    /RUNNER_LABEL must be exactly certigo-pr-aca/,
  );
});

test('JIT bootstrap rejects additional labels returned by GitHub', async () => {
  const { privateKey } = generateKeyPairSync('rsa', {
    modulusLength: 2048,
    privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
    publicKeyEncoding: { type: 'spki', format: 'pem' },
  });
  let requestCount = 0;
  const fetchImpl = async () => {
    requestCount += 1;
    if (requestCount === 1) {
      return new Response(JSON.stringify({ token: 'installation-token' }), {
        status: 201,
        headers: { 'content-type': 'application/json' },
      });
    }
    return new Response(JSON.stringify({
      runner: {
        id: 99,
        ephemeral: true,
        labels: [
          { name: 'self-hosted' },
          { name: 'Linux' },
          { name: 'X64' },
          { name: 'certigo-pr-aca' },
          { name: 'unexpected-label' },
        ],
      },
      encoded_jit_config: 'encoded-once',
    }), {
      status: 201,
      headers: { 'content-type': 'application/json' },
    });
  };

  await assert.rejects(
    requestJitConfiguration({
      apiUrl: 'https://api.github.com',
      owner: 'gchambaud_microsoft',
      repository: 'Certigo',
      appId: '123',
      installationId: '456',
      privateKey,
      runnerGroupId: '1',
      runnerLabel: 'certigo-pr-aca',
    }, fetchImpl),
    /outside the certigo-pr-aca trust boundary/,
  );
});

test('preflight always removes the temporary secret parameter file', () => {
  const tryIndex = preflight.indexOf('try {');
  const writeIndex = preflight.indexOf('[IO.File]::WriteAllText(');
  const finallyIndex = preflight.indexOf('finally {');
  assert.ok(tryIndex >= 0 && tryIndex < writeIndex);
  assert.ok(writeIndex < finallyIndex);
  assert.match(
    preflight,
    /finally \{[\s\S]*Remove-Item -LiteralPath \$parameterPath -Force/,
  );
});

const subscriptionId = '00000000-0000-4000-8000-000000000000';
const resourceGroup = 'rg-certigo-ci';
const resourceGroupId =
  `/subscriptions/${subscriptionId}/resourceGroups/${resourceGroup}`;
const runnerImage =
  `docker.io/certigo/runner@sha256:${'a'.repeat(64)}`;
const pilotTags = {
  env: 'ci-pilot',
  lifecycle: 'ephemeral',
  trustBoundary: 'untrusted-pr',
  workload: 'github-actions-runner',
};

function relativeId(type, name) {
  if (type === 'Microsoft.Insights/diagnosticSettings') {
    return 'providers/Microsoft.App/managedEnvironments/cae-certigo-ci-aca-pilot'
      + `/providers/${type}/${name}`;
  }
  return `providers/${type}/${name}`;
}

function validAfter(type, name) {
  const id = `${resourceGroupId}/${relativeId(type, name)}`;
  const base = {
    id,
    name,
    resourceGroup,
    type,
  };
  if (type === 'Microsoft.OperationalInsights/workspaces') {
    return {
      ...base,
      properties: {
        publicNetworkAccessForIngestion: 'Enabled',
        publicNetworkAccessForQuery: 'Enabled',
        retentionInDays: 30,
      },
      tags: pilotTags,
    };
  }
  if (type === 'Microsoft.App/managedEnvironments') {
    return {
      ...base,
      identity: { type: 'None' },
      properties: {
        appLogsConfiguration: { destination: 'azure-monitor' },
        zoneRedundant: false,
      },
      tags: pilotTags,
    };
  }
  if (type === 'Microsoft.Insights/diagnosticSettings') {
    return {
      ...base,
      properties: {
        logs: [{ categoryGroup: 'allLogs', enabled: true }],
        metrics: [{ category: 'AllMetrics', enabled: true }],
        workspaceId:
          `${resourceGroupId}/providers/Microsoft.OperationalInsights`
          + '/workspaces/log-certigo-aca-pilot',
      },
    };
  }
  if (type === 'Microsoft.App/jobs') {
    return {
      ...base,
      identity: { type: 'None' },
      properties: {
        configuration: {
          eventTriggerConfig: {
            parallelism: 1,
            replicaCompletionCount: 1,
            scale: {
              maxExecutions: 2,
              minExecutions: 0,
              pollingInterval: 30,
              rules: [{
                auth: [{ secretRef: '*******', triggerParameter: 'appKey' }],
                metadata: {
                  applicationID: '123',
                  enableEtags: 'true',
                  githubAPIURL: 'https://api.github.com',
                  installationID: '456',
                  labels: 'certigo-pr-aca',
                  noDefaultLabels: 'false',
                  owner: 'gchambaud_microsoft',
                  repos: 'Certigo',
                  runnerScope: 'repo',
                  targetWorkflowQueueLength: '1',
                },
                name: 'github-runner',
                type: 'github-runner',
              }],
            },
          },
          replicaRetryLimit: 0,
          replicaTimeout: 1800,
          secrets: [{ name: '*******', value: '*******' }],
          triggerType: 'Event',
        },
        environmentId:
          `${resourceGroupId}/providers/Microsoft.App/managedEnvironments`
          + '/cae-certigo-ci-aca-pilot',
        template: {
          containers: [{
            command: ['/opt/certigo/run-ephemeral.sh'],
            env: [
              { name: 'EXPECTED_RUNNER_LABEL', value: 'certigo-pr-aca' },
              {
                name: 'JIT_CONFIG_PATH',
                value: '/var/run/certigo-runner/jitconfig',
              },
              { name: 'RUNNER_LOG_TO_STDOUT', value: '1' },
              {
                name: 'ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT',
                value: '1',
              },
            ],
            image: runnerImage,
            name: 'runner',
            resources: { cpu: 2, memory: '4Gi' },
            volumeMounts: [{
              mountPath: '/var/run/certigo-runner',
              volumeName: 'runner-jit',
            }],
          }],
          initContainers: [{
            args: ['/opt/certigo/prepare-jit.mjs'],
            command: ['node'],
            env: [
              { name: 'GITHUB_API_URL', value: 'https://api.github.com' },
              { name: 'GITHUB_OWNER', value: 'gchambaud_microsoft' },
              { name: 'GITHUB_REPOSITORY', value: 'Certigo' },
              { name: 'GITHUB_APP_ID', value: '123' },
              { name: 'GITHUB_APP_INSTALLATION_ID', value: '456' },
              { name: 'GITHUB_APP_PRIVATE_KEY', secretRef: '*******' },
              { name: 'RUNNER_GROUP_ID', value: '1' },
              { name: 'RUNNER_LABEL', value: 'certigo-pr-aca' },
              {
                name: 'JIT_CONFIG_PATH',
                value: '/var/run/certigo-runner/jitconfig',
              },
            ],
            image: runnerImage,
            name: 'jit-config',
            resources: { cpu: 0.25, memory: '0.5Gi' },
            volumeMounts: [{
              mountPath: '/var/run/certigo-runner',
              volumeName: 'runner-jit',
            }],
          }],
          volumes: [{ name: 'runner-jit', storageType: 'EmptyDir' }],
        },
      },
      tags: pilotTags,
    };
  }
  return base;
}

function change(type, name, changeType = 'Create') {
  const after = validAfter(type, name);
  return {
    changeType,
    resourceId: after.id,
    after,
  };
}

function validChanges(pilotEnabled) {
  const changes = [
    change('Microsoft.OperationalInsights/workspaces', 'log-certigo-aca-pilot'),
    change('Microsoft.App/managedEnvironments', 'cae-certigo-ci-aca-pilot'),
    change(
      'Microsoft.Insights/diagnosticSettings',
      'certigo-aca-pilot-logs',
    ),
  ];
  if (pilotEnabled) {
    changes.push(change('Microsoft.App/jobs', 'job-certigo-pr-aca'));
  }
  return changes;
}

test('what-if validator accepts only the bounded disabled control plane', () => {
  const result = {
    status: 'Succeeded',
    properties: {
      changes: [
        ...validChanges(false),
        change(
          'Microsoft.Compute/virtualMachineScaleSets',
          'vmss-certigo-runner-zonal',
          'Ignore',
        ),
      ],
    },
  };
  const summary = validateWhatIf(result, {
    pilotEnabled: false,
    resourceGroup: 'RG-CERTIGO-CI',
  });
  assert.equal(summary.jobChanges, 0);
  assert.equal(summary.ignoredChanges, 1);
});

test('what-if validator accepts the exact bounded enabled pilot', () => {
  const summary = validateWhatIf({
    status: 'Succeeded',
    properties: { changes: validChanges(true) },
  }, {
    pilotEnabled: true,
    resourceGroup: 'RG-CERTIGO-CI',
  });
  assert.equal(summary.jobChanges, 1);
});

test('what-if validator fails closed on mutation or an enabled job in disabled mode', () => {
  const modified = {
    status: 'Succeeded',
    properties: {
      changes: [
        change('Microsoft.App/managedEnvironments', 'cae-certigo-ci-aca-pilot', 'Modify'),
      ],
    },
  };
  assert.throws(
    () => validateWhatIf(modified, {
      pilotEnabled: false,
      resourceGroup: 'RG-CERTIGO-CI',
    }),
    /unsafe what-if change type: Modify/,
  );

  const unexpectedJob = {
    status: 'Succeeded',
    properties: {
      changes: [
        change('Microsoft.App/jobs', 'job-certigo-pr-aca'),
      ],
    },
  };
  assert.throws(
    () => validateWhatIf(unexpectedJob, {
      pilotEnabled: false,
      resourceGroup: 'RG-CERTIGO-CI',
    }),
    /disabled preflight must not plan/,
  );

  const ignoredExistingJob = {
    status: 'Succeeded',
    changes: [
      change('Microsoft.App/jobs', 'job-certigo-pr-aca', 'Ignore'),
    ],
  };
  assert.throws(
    () => validateWhatIf(ignoredExistingJob, {
      pilotEnabled: false,
      resourceGroup: 'RG-CERTIGO-CI',
    }),
    /pilot resource unexpectedly ignored/,
  );
});

test('what-if validator rejects identity, secret, and scope expansion', () => {
  const identityChanges = validChanges(true);
  identityChanges.at(-1).after.identity = { type: 'SystemAssigned' };
  assert.throws(
    () => validateWhatIf({ changes: identityChanges }, {
      pilotEnabled: true,
      resourceGroup: 'RG-CERTIGO-CI',
    }),
    /runner job identity must be None/,
  );

  const secretChanges = validChanges(true);
  secretChanges.at(-1).after.properties.template.containers[0].env.push({
    name: 'GITHUB_APP_PRIVATE_KEY',
    secretRef: '*******',
  });
  assert.throws(
    () => validateWhatIf({ changes: secretChanges }, {
      pilotEnabled: true,
      resourceGroup: 'RG-CERTIGO-CI',
    }),
    /runner container env crosses the pilot boundary/,
  );

  const scopeChanges = validChanges(false);
  const diagnostic = scopeChanges.find(
    (candidate) => candidate.after.type === 'Microsoft.Insights/diagnosticSettings',
  );
  diagnostic.resourceId =
    `${resourceGroupId}/providers/Microsoft.Compute/virtualMachineScaleSets`
    + '/vmss-certigo-runner-zonal/providers/Microsoft.Insights'
    + '/diagnosticSettings/certigo-aca-pilot-logs';
  diagnostic.after.id = diagnostic.resourceId;
  assert.throws(
    () => validateWhatIf({ changes: scopeChanges }, {
      pilotEnabled: false,
      resourceGroup: 'RG-CERTIGO-CI',
    }),
    /resource id is outside the ACA pilot boundary/,
  );
});

test('pilot workflow preserves VMSS fallback and gates one internal PR validation', () => {
  assert.match(workflow, /^ {2}workflow_dispatch:\s*$/m);
  assert.match(workflow, /vars\.CERTIGO_ACA_PILOT_ENABLED == 'true'/);
  assert.match(workflow, /runs-on: \[self-hosted, Linux, X64, certigo-pr-aca]/);
  assert.match(workflow, /pull\.head\.repo\?\.full_name/);
  assert.match(workflow, /pull\.base\.ref !== 'main'/);
  assert.match(workflow, /node --test \.github\/scripts\/\*\.test\.mjs/);
  assert.match(workflow, /npm audit --audit-level=high/);
  assert.match(workflow, /pip check/);
  assert.doesNotMatch(workflow, /id-token:\s*write|environment:|secrets\./);

  for (const file of [
    'ci-content.yml',
    'ci-migration-registry.yml',
    'lint-workflows.yml',
    'ci-project-state.yml',
  ]) {
    const existing = fs.readFileSync(
      path.join(repositoryRoot, '.github', 'workflows', file),
      'utf8',
    );
    assert.match(existing, /runs-on: \[self-hosted, Linux, X64, certigo-pr]/);
    assert.doesNotMatch(existing, /certigo-pr-aca/);
  }

  for (const file of fs.readdirSync(
    path.join(repositoryRoot, '.github', 'workflows'),
  )) {
    if (!/^(?:cd-|release-|sync-).+\.ya?ml$/.test(file)) {
      continue;
    }
    const productionWorkflow = fs.readFileSync(
      path.join(repositoryRoot, '.github', 'workflows', file),
      'utf8',
    );
    assert.doesNotMatch(productionWorkflow, /certigo-pr-aca/);
  }
});

test('runbook records the activation blockers and exact rollback boundary', () => {
  const runbook = fs.readFileSync(
    path.join(repositoryRoot, 'docs', 'runbooks', 'ACA_JOBS_PILOT.md'),
    'utf8',
  );
  assert.match(runbook, /CERTIGO_ACA_PILOT_ENABLED=false/);
  assert.match(runbook, /pilotEnabled=false/);
  assert.match(runbook, /mode \*\*Incremental\*\*/);
  assert.match(runbook, /job-certigo-pr-aca/);
  assert.match(runbook, /ne supprime pas un job déjà créé/);
  assert.match(runbook, /moteur Docker actif/);
  assert.match(runbook, /PR #366/);
});
