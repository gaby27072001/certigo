import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { assertRunnerInventoried } from './assert-runner-inventoried.mjs';

const repositoryConfig = JSON.parse(
  readFileSync(
    new URL(
      '../../infra/ci-runner/capacity-controller.config.json',
      import.meta.url,
    ),
    'utf8',
  ),
);

test('both live trusted runners are present in the versioned inventory', () => {
  for (const name of [
    'vmss-certigo-runner-zonal_f55d176e-Certigo',
    'vmss-certigo-runner-zonal_be505fa1-Certigo',
  ]) {
    assert.deepEqual(assertRunnerInventoried(name, repositoryConfig), []);
  }
});

test('every live PR runner is present in the versioned inventory', () => {
  for (const name of [
    'certigo-prPLCHD1',
    'certigo-prPLCHD2',
    'certigo-prPLCHD3',
    'certigo-prPLCHD4',
  ]) {
    assert.deepEqual(assertRunnerInventoried(name, repositoryConfig), []);
  }
});

test('an uninventoried runner fails closed', () => {
  const errors = assertRunnerInventoried(
    'vmss-certigo-runner-zonal_deadbeef-Certigo',
    repositoryConfig,
  );
  assert.equal(errors.length, 1);
  assert.match(errors[0], /is not in capacity-controller\.config\.json/);
});

test('runner name matching ignores case', () => {
  assert.deepEqual(
    assertRunnerInventoried(
      'VMSS-CERTIGO-RUNNER-ZONAL_BE505FA1-CERTIGO',
      repositoryConfig,
    ),
    [],
  );
});

test('an empty runner name or empty inventory fails closed', () => {
  assert.match(
    assertRunnerInventoried('', repositoryConfig)[0],
    /runner name was empty/,
  );
  assert.match(
    assertRunnerInventoried('anything', {
      inventory: { managedRunnerBindings: [] },
    })[0],
    /declares no managed runners/,
  );
});

// The workflow invokes this file as a CLI, so the exported function passing is
// not evidence that the step can fail. A broken entry-point guard makes main()
// never run: the step then exits 0 and the safeguard is silently absent while
// every function-level test still passes.
//
// Both cases below inject a recognisable value and assert the report contains
// that exact value, rather than merely being non-empty or non-zero. A report
// checked only for "not empty" is consistent with a mechanism that fabricates
// it; matching an injected sentinel is what makes the assertion real.
const cliPath = fileURLToPath(
  new URL('./assert-runner-inventoried.mjs', import.meta.url),
);
const repositoryRoot = path.resolve(path.dirname(cliPath), '..', '..');
const configPath = path.join(
  repositoryRoot,
  'infra',
  'ci-runner',
  'capacity-controller.config.json',
);

function runCli(runnerName) {
  return spawnSync(process.execPath, [cliPath, runnerName, configPath], {
    encoding: 'utf8',
  });
}

test('the CLI exits non-zero and names the uninventoried runner', () => {
  const sentinel = 'sentinel-uninventoried-runner-8f3a2c';
  const result = runCli(sentinel);

  assert.equal(result.status, 1);
  assert.match(result.stderr, /::error::/);
  assert.ok(
    result.stderr.includes(sentinel),
    `stderr must name the injected runner ${sentinel}, got: ${result.stderr}`,
  );
});

test('the CLI exits zero and names an inventoried runner', () => {
  const inventoried = 'vmss-certigo-runner-zonal_be505fa1-Certigo';
  const result = runCli(inventoried);

  assert.equal(result.status, 0);
  assert.ok(
    result.stdout.includes(inventoried),
    `stdout must name the inventoried runner, got: ${result.stdout}`,
  );
});
