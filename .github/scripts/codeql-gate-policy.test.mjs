import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const codeqlWorkflow = fs.readFileSync(
  path.join(root, '.github', 'workflows', 'codeql.yml'),
  'utf8',
);
const forkPolicy = fs.readFileSync(
  path.join(root, '.github', 'workflows', 'fork-pr-policy.yml'),
  'utf8',
);

function jobBlock(text, jobId) {
  const lines = text.split(/\r?\n/u);
  const start = lines.findIndex((line) => line === `  ${jobId}:`);
  assert.notEqual(start, -1, `Missing job ${jobId}`);
  const next = lines.findIndex(
    (line, index) => index > start && /^ {2}[a-z0-9-]+:\s*$/u.test(line),
  );
  return lines.slice(start, next === -1 ? undefined : next).join('\n');
}

function runScript(stepName, block) {
  const lines = block.split('\n');
  const step = lines.findIndex((line) => line === `      - name: ${stepName}`);
  assert.notEqual(step, -1, `Missing step ${stepName}`);
  const run = lines.findIndex(
    (line, index) => index > step && line === '        run: |',
  );
  assert.notEqual(run, -1, `Missing run block for ${stepName}`);

  const script = [];
  for (const line of lines.slice(run + 1)) {
    if (line !== '' && !line.startsWith('          ')) {
      break;
    }
    script.push(line === '' ? '' : line.slice(10));
  }
  return script.join('\n');
}

const gateJob = jobBlock(codeqlWorkflow, 'security-gate');
const gateScript = runScript('Enforce CodeQL result', gateJob);
const defaultEnvironment = {
  EVENT_NAME: 'push',
  FRESHNESS_RESULT: 'skipped',
  FRESHNESS_CURRENT: '',
  CHANGES_RESULT: 'success',
  HAS_CHANGES: 'false',
  ANALYZE_RESULT: 'skipped',
};

function executeGate(environment = {}) {
  const result = spawnSync('bash', ['-c', gateScript], {
    encoding: 'utf8',
    env: {
      ...process.env,
      ...defaultEnvironment,
      ...environment,
    },
  });
  if (result.error) {
    throw result.error;
  }
  return result;
}

function gateIsScheduled({
  eventName,
  freshnessCurrent = '',
  headRepository = '',
  repository = 'gchambaud_microsoft/Certigo',
}) {
  return eventName !== 'pull_request_target'
    || (
      freshnessCurrent !== 'false'
      && headRepository === repository
    );
}

test('aggregate gate orchestration excludes stale and fork pull requests', () => {
  const expectedGuard =
    "${{ always() && (github.event_name != 'pull_request_target' || (needs.freshness.outputs.current != 'false' && github.event.pull_request.head.repo.full_name == github.repository)) }}";
  const guard = gateJob.match(/^ {4}if:\s*(.+)$/mu)?.[1];
  assert.equal(guard, expectedGuard);

  const cases = [
    {
      name: 'push',
      eventName: 'push',
      expected: true,
    },
    {
      name: 'fresh same-repository pull request',
      eventName: 'pull_request_target',
      freshnessCurrent: 'true',
      headRepository: 'gchambaud_microsoft/Certigo',
      expected: true,
    },
    {
      name: 'indeterminate freshness reaches the fail-closed result check',
      eventName: 'pull_request_target',
      freshnessCurrent: '',
      headRepository: 'gchambaud_microsoft/Certigo',
      expected: true,
    },
    {
      name: 'stale pull request',
      eventName: 'pull_request_target',
      freshnessCurrent: 'false',
      headRepository: 'gchambaud_microsoft/Certigo',
      expected: false,
    },
    {
      name: 'fork pull request',
      eventName: 'pull_request_target',
      freshnessCurrent: 'true',
      headRepository: 'attacker/Certigo',
      expected: false,
    },
  ];

  for (const scenario of cases) {
    assert.equal(
      gateIsScheduled(scenario),
      scenario.expected,
      scenario.name,
    );
  }
  assert.match(forkPolicy, /Fork PR policy \/ Required gate/u);
  assert.match(forkPolicy, /HEAD_REPOSITORY" != "\$BASE_REPOSITORY/u);
});

test('aggregate gate accepts only canonical event and analysis results', () => {
  const cases = [
    {
      name: 'push without analyzable changes',
      environment: {},
    },
    {
      name: 'push with analyzable changes',
      environment: {
        HAS_CHANGES: 'true',
        ANALYZE_RESULT: 'success',
      },
    },
    {
      name: 'fresh pull request without analyzable changes',
      environment: {
        EVENT_NAME: 'pull_request_target',
        FRESHNESS_RESULT: 'success',
        FRESHNESS_CURRENT: 'true',
      },
    },
    {
      name: 'fresh pull request with analyzable changes',
      environment: {
        EVENT_NAME: 'pull_request_target',
        FRESHNESS_RESULT: 'success',
        FRESHNESS_CURRENT: 'true',
        HAS_CHANGES: 'true',
        ANALYZE_RESULT: 'success',
      },
    },
    {
      name: 'scheduled full scan',
      environment: {
        EVENT_NAME: 'schedule',
        HAS_CHANGES: 'true',
        ANALYZE_RESULT: 'success',
      },
    },
  ];

  for (const scenario of cases) {
    const result = executeGate(scenario.environment);
    assert.equal(
      result.status,
      0,
      `${scenario.name}\n${result.stdout}\n${result.stderr}`,
    );
  }
});

test('aggregate gate rejects unexpected skipped, failure, and cancelled results', () => {
  const cases = [
    ['push freshness success', { FRESHNESS_RESULT: 'success' }],
    ['push freshness failure', { FRESHNESS_RESULT: 'failure' }],
    ['push freshness cancelled', { FRESHNESS_RESULT: 'cancelled' }],
    [
      'pull request freshness skipped',
      {
        EVENT_NAME: 'pull_request_target',
        FRESHNESS_CURRENT: 'true',
      },
    ],
    [
      'pull request freshness failure',
      {
        EVENT_NAME: 'pull_request_target',
        FRESHNESS_RESULT: 'failure',
        FRESHNESS_CURRENT: 'true',
      },
    ],
    [
      'pull request freshness cancelled',
      {
        EVENT_NAME: 'pull_request_target',
        FRESHNESS_RESULT: 'cancelled',
        FRESHNESS_CURRENT: 'true',
      },
    ],
    [
      'pull request current head missing',
      {
        EVENT_NAME: 'pull_request_target',
        FRESHNESS_RESULT: 'success',
      },
    ],
    [
      'pull request stale head if invoked defensively',
      {
        EVENT_NAME: 'pull_request_target',
        FRESHNESS_RESULT: 'success',
        FRESHNESS_CURRENT: 'false',
      },
    ],
    ['path selection skipped', { CHANGES_RESULT: 'skipped' }],
    ['path selection failure', { CHANGES_RESULT: 'failure' }],
    ['path selection cancelled', { CHANGES_RESULT: 'cancelled' }],
    [
      'applicable analysis skipped',
      {
        HAS_CHANGES: 'true',
      },
    ],
    [
      'applicable analysis failure',
      {
        HAS_CHANGES: 'true',
        ANALYZE_RESULT: 'failure',
      },
    ],
    [
      'applicable analysis cancelled',
      {
        HAS_CHANGES: 'true',
        ANALYZE_RESULT: 'cancelled',
      },
    ],
    ['inapplicable analysis success', { ANALYZE_RESULT: 'success' }],
    ['inapplicable analysis failure', { ANALYZE_RESULT: 'failure' }],
    ['inapplicable analysis cancelled', { ANALYZE_RESULT: 'cancelled' }],
    ['missing has_changes output', { HAS_CHANGES: '' }],
    ['invalid has_changes output', { HAS_CHANGES: 'unknown' }],
    ['unsupported event', { EVENT_NAME: 'workflow_dispatch' }],
  ];

  for (const [name, environment] of cases) {
    const result = executeGate(environment);
    assert.notEqual(
      result.status,
      0,
      `${name} unexpectedly passed\n${result.stdout}\n${result.stderr}`,
    );
    assert.match(`${result.stdout}\n${result.stderr}`, /::error::/u, name);
  }
});
