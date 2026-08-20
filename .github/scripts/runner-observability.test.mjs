import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
  '..',
);
const workflow = readFileSync(
  path.join(repositoryRoot, '.github', 'workflows', 'runner-health.yml'),
  'utf8',
);
const healthProbe = readFileSync(
  path.join(repositoryRoot, 'infra', 'ci-runner', 'health-probe.sh'),
  'utf8',
);

test('runner queue wait uses GitHub run timestamps rather than elapsed job time', () => {
  assert.match(workflow, /^\s{2}actions: read$/m);
  assert.match(workflow, /\[\.created_at, \.run_started_at\] \| @tsv/);
  assert.match(
    workflow,
    /RUN_QUEUE_WAIT_SECONDS=\$\(\(STARTED_EPOCH - CREATED_EPOCH\)\)/,
  );
  assert.doesNotMatch(workflow, /RUN_QUEUE_WAIT_SECONDS=.*NOW_EPOCH/);
});

test('runner summary emits lifecycle, queue, cache and package metrics', () => {
  for (const metric of [
    'runner.lifecycle.active',
    'runner.queue.wait',
    'runner.cache.local',
    'runner.package.',
  ]) {
    assert.match(healthProbe, new RegExp(metric.replaceAll('.', '\\.')));
  }
  assert.match(workflow, /CACHE_PATHS:/);
});
