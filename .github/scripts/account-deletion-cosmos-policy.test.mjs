import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { validateAccountDeletionCosmosLayout } from './account-deletion-cosmos-policy.mjs';

const legacyContent = `
name: test-account-deletion-cosmos
on:
  repository_dispatch:
    types: [test-account-deletion-cosmos]
jobs:
  preflight:
    run: type == "object" and length == 0
  emulator:
    if: \${{ github.ref == 'refs/heads/main' }}
    runs-on: [self-hosted, Linux, X64, certigo-trusted]
    steps:
      - with:
          ref: \${{ github.sha }}
      - env:
          ACTIONS_ID_TOKEN_REQUEST_TOKEN: ""
        run: bash backend/run-account-deletion-cosmos-emulator.sh
# refs/heads/main
`;

const archivedLegacyContent = `# RETIRED: replaced by the feature-off one-shot gate.
${legacyContent}`;

const archivedOneShotContent = `
# FEATURE-OFF: activation requires a separate reviewed change.
name: post-merge-cosmos-account-deletion
on:
  workflow_dispatch:
jobs:
  account-deletion:
    if: >-
      github.event_name == 'workflow_dispatch'
      && github.repository == 'gchambaud_microsoft/Certigo'
      && github.ref == 'refs/heads/main'
      && vars.CERTIGO_COSMOS_EMULATOR_ENABLED == 'true'
    runs-on: [self-hosted, Linux, X64, certigo-cosmos-emulator]
    steps:
      - with:
          ref: refs/heads/main
          persist-credentials: false
      - run: bash infra/ci-runner/cosmos-emulator/run-account-deletion.sh
`;

const files = {
  activeLegacy: ['workflows', 'test-account-deletion-cosmos.yml', legacyContent],
  activeOneShot: ['workflows', 'post-merge-cosmos-account-deletion.yml', archivedOneShotContent],
  archivedLegacy: [
    'workflows-disabled',
    'test-account-deletion-cosmos.yml',
    archivedLegacyContent,
  ],
  archivedOneShot: [
    'workflows-disabled',
    'post-merge-cosmos-account-deletion.yml',
    archivedOneShotContent,
  ],
};

function fixture(layout) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-cosmos-policy-'));
  for (const label of layout) {
    const [directory, name, content] = files[label];
    const destination = path.join(root, '.github', directory, name);
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    fs.writeFileSync(destination, content);
  }
  return root;
}

function withFixture(layout, callback) {
  const root = fixture(layout);
  try {
    callback(root);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
}

test('accepts migration state A with only the invariant-preserving legacy workflow active', () => {
  withFixture(['activeLegacy'], (root) => {
    assert.deepEqual(validateAccountDeletionCosmosLayout(root), []);
  });
});

test('accepts migration state B with both controlled archives and no active Cosmos workflow', () => {
  withFixture(['archivedLegacy', 'archivedOneShot'], (root) => {
    assert.deepEqual(validateAccountDeletionCosmosLayout(root), []);
  });
});

test('rejects every partial or mixed workflow migration layout', () => {
  const labels = Object.keys(files);
  const validMasks = new Set([0b0001, 0b1100]);
  for (let mask = 0; mask < 2 ** labels.length; mask += 1) {
    if (validMasks.has(mask)) {
      continue;
    }
    const layout = labels.filter((_, index) => mask & (1 << index));
    withFixture(layout, (root) => {
      const errors = validateAccountDeletionCosmosLayout(root);
      assert.equal(errors.length, 1, `layout ${layout.join(', ') || 'none'} must fail`);
      assert.match(errors[0], /must be exactly legacy-active or fully archived/);
    });
  }
});

test('preserves every existing legacy workflow invariant in both migration states', () => {
  for (const [layout, target] of [
    [['activeLegacy'], ['workflows', 'test-account-deletion-cosmos.yml']],
    [
      ['archivedLegacy', 'archivedOneShot'],
      ['workflows-disabled', 'test-account-deletion-cosmos.yml'],
    ],
  ]) {
    withFixture(layout, (root) => {
      const file = path.join(root, '.github', ...target);
      fs.writeFileSync(
        file,
        fs.readFileSync(file, 'utf8').replace('type == "object" and length == 0', ''),
      );
      assert.ok(
        validateAccountDeletionCosmosLayout(root)
          .some((error) => error.includes(
            'missing fail-closed invariant type == "object" and length == 0',
          )),
      );
    });
  }
});

for (const forbidden of [
  '\npull_request:\n',
  '\npull_request_target:\n',
  '\npush:\n',
  '\nvalue: ${{ secrets.AZURE_CLIENT_ID }}\n',
  '\n- uses: azure/login@0123456789012345678901234567890123456789\n',
  '\npermissions:\n  id-token: write\n',
  '\nrun: core.getIDToken()\n',
]) {
  test(`rejects cloud or automatic trigger capability in the one-shot archive: ${forbidden.trim()}`, () => {
    withFixture(['archivedLegacy', 'archivedOneShot'], (root) => {
      const file = path.join(
        root,
        '.github',
        'workflows-disabled',
        'post-merge-cosmos-account-deletion.yml',
      );
      fs.appendFileSync(file, forbidden);
      assert.ok(
        validateAccountDeletionCosmosLayout(root)
          .some((error) => error.includes('must not accept PR/push events or cloud credentials')),
      );
    });
  });
}
