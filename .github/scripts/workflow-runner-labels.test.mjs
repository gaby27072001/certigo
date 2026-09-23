import assert from 'node:assert/strict';
import test from 'node:test';
import { allowedRunnerLabelSets, validateRunnerLabels } from './workflow-runner-labels.mjs';

function workflowWith(job) {
  return `name: probe
on:
  workflow_dispatch:
permissions:
  contents: read
jobs:
  probe:
${job}
`;
}

test('accepts exactly the fixed self-hosted label sets', () => {
  for (const labels of allowedRunnerLabelSets) {
    assert.deepEqual(
      validateRunnerLabels(workflowWith(`    runs-on: [${labels.join(', ')}]\n    steps: []`), 'w.yml'),
      [],
    );
  }
  assert.deepEqual(
    validateRunnerLabels(workflowWith('    uses: ./.github/workflows/pr-head-freshness.yml'), 'w.yml'),
    [],
  );
});

test('rejects a quoted runs-on key that the line-based rule cannot see', () => {
  const errors = validateRunnerLabels(
    workflowWith('    "runs-on": [self-hosted, Linux, X64]\n    steps: []'),
    'w.yml',
  );
  assert.equal(errors.length, 1);
  assert.match(errors[0], /job probe must run on a fixed Azure self-hosted label set/);
});

test('rejects dynamic, grouped, reordered, extended and block-list runner selections', () => {
  for (const runsOn of [
    'runs-on: ${{ vars.RUNNER }}',
    'runs-on:\n      group: certigo\n      labels: [self-hosted, Linux, X64, certigo-pr]',
    'runs-on: [Linux, self-hosted, X64, certigo-pr]',
    'runs-on: [self-hosted, Linux, X64, certigo-pr, extra]',
    'runs-on:\n      - self-hosted\n      - Linux\n      - X64',
    'runs-on: ubuntu-latest',
    '? runs-on\n    : [self-hosted, Linux, X64]',
  ]) {
    const errors = validateRunnerLabels(workflowWith(`    ${runsOn}\n    steps: []`), 'w.yml');
    assert.equal(errors.length, 1, runsOn);
  }
});

test('refuses to vouch for labels it cannot parse', () => {
  assert.match(
    validateRunnerLabels('jobs:\n  a:\n    runs-on: x\n    runs-on: y\n', 'w.yml')[0],
    /cannot be checked on invalid YAML/,
  );
  assert.match(
    validateRunnerLabels(
      'labels: &labels [self-hosted, Linux, X64]\njobs:\n  a:\n    runs-on: *labels\n',
      'w.yml',
    )[0],
    /cannot be checked on unsafe YAML/,
  );
});
