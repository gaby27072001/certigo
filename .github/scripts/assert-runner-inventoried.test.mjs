import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

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

test('the PR pilot runner is present in the versioned inventory', () => {
  assert.deepEqual(
    assertRunnerInventoried('certigo-prIVJAN8', repositoryConfig),
    [],
  );
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
