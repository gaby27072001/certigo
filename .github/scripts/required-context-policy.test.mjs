import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import {
  missingRequiredContexts,
  producedContexts,
  validateRequiredContexts,
} from './required-context-policy.mjs';

function gate({ on = 'pull_request_target:\n    branches: [main]', job = '' } = {}) {
  return `name: gate
on:
  ${on}
permissions:
  contents: read
jobs:
  gate:
    name: Required gate
    runs-on: [self-hosted, Linux, X64, certigo-pr]
${job}    steps: []
`;
}

function only(text) {
  return new Map([['gate.yml', text]]);
}

test('a named, unfiltered pull_request_target job reports its required context', () => {
  for (const on of [
    'pull_request_target:',
    'pull_request_target:\n    branches: [main]',
    'pull_request_target:\n    types: [opened, synchronize, reopened, ready_for_review]',
    'workflow_dispatch:\n  pull_request_target:',
  ]) {
    assert.ok(producedContexts(only(gate({ on }))).has('Required gate'), on);
  }
});

test('renaming, filtering, fanning out or dropping the trigger loses the required context', () => {
  const variants = [
    gate().replace('name: Required gate', 'name: Required gate (renamed)'),
    gate({ on: 'push:\n    branches: [main]' }),
    gate({ on: 'pull_request_target:\n    paths: ["apps/**"]' }),
    gate({ on: 'pull_request_target:\n    paths-ignore: ["docs/**"]' }),
    gate({ on: 'pull_request_target:\n    branches: [release]' }),
    gate({ on: "pull_request_target:\n    branches: [main, '!main']" }),
    gate({ on: "pull_request_target:\n    branches: ['**', '!main']" }),
    gate({ on: 'pull_request_target:\n    types: [opened]' }),
    gate({ job: '    strategy:\n      matrix:\n        shard: [1, 2]\n' }),
    gate().replace('    runs-on: [self-hosted, Linux, X64, certigo-pr]\n', '    uses: ./.github/workflows/reusable.yml\n'),
    'name: gate\non:\n  pull_request_target:\njobs:\n  gate:\n    name: Required gate\n    name: duplicate\n',
  ];
  for (const text of variants) {
    assert.deepEqual(missingRequiredContexts(['Required gate'], only(text)), ['Required gate'], text);
  }
});

function protection(contexts) {
  return `${JSON.stringify({ required_status_checks: { strict: true, contexts } }, null, 2)}\n`;
}

function manifest(preApproved) {
  const baseline = { '.github/workflows/gate.yml': 'a'.repeat(64) };
  return `${JSON.stringify({
    schemaVersion: 2,
    canonicalization: 'certigo-workflow-semantic-v1',
    states: {
      A: { ...baseline, '.github/workflows/test-account-deletion-cosmos.yml': 'b'.repeat(64) },
      B: baseline,
      C: { ...baseline, '.github/workflows/post-merge-cosmos-account-deletion.yml': 'c'.repeat(64) },
    },
    preApproved,
  }, null, 2)}\n`;
}

function repository(track, { contexts = ['Required gate'], workflow = gate(), preApproved = {}, proposal } = {}) {
  const root = track(fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-required-context-')));
  const write = (relativePath, content) => {
    const destination = path.join(root, ...relativePath.split('/'));
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    fs.writeFileSync(destination, content);
  };
  write('.github/branch-protection-main.json', protection(contexts));
  if (workflow !== null) {
    write('.github/workflows/gate.yml', workflow);
  } else {
    fs.mkdirSync(path.join(root, '.github', 'workflows'), { recursive: true });
  }
  write('.github/scripts/workflow-semantic-manifest.json', manifest(preApproved));
  if (proposal !== undefined) {
    write('.github/workflows-proposed/gate.yml', proposal);
  }
  return root;
}

function withTrees(callback) {
  const trees = [];
  try {
    callback((root) => {
      trees.push(root);
      return root;
    });
  } finally {
    for (const root of trees) {
      fs.rmSync(root, { recursive: true, force: true });
    }
  }
}

test('the base refuses a candidate that would stop reporting a required context', () => {
  withTrees((track) => {
    const trusted = repository(track);
    assert.deepEqual(validateRequiredContexts(repository(track), { trustedRoot: trusted }), []);

    const renamed = repository(track, {
      workflow: gate().replace('name: Required gate', 'name: Gate'),
    });
    assert.match(
      validateRequiredContexts(renamed, { trustedRoot: trusted }).join('\n'),
      /required status check "Required gate" would no longer be reported/,
    );

    // Retirer le contexte de sa propre copie de la protection ne dispense pas du contrôle.
    const unlisted = repository(track, {
      contexts: [],
      workflow: gate().replace('name: Required gate', 'name: Gate'),
    });
    assert.notDeepEqual(validateRequiredContexts(unlisted, { trustedRoot: trusted }), []);

    // Exiger un contexte que la PR ne produit pas bloquerait main après la fusion.
    const planned = repository(track, { contexts: ['Required gate', 'Future gate'] });
    assert.match(
      validateRequiredContexts(planned, { trustedRoot: trusted }).join('\n'),
      /required status check "Future gate"/,
    );
  });
});

test('a pre-approval that would drop a required context is refused before it can land', () => {
  withTrees((track) => {
    const trusted = repository(track);
    const entry = { digest: 'd'.repeat(64), expires: '2026-10-01' };
    const renaming = repository(track, {
      preApproved: { '.github/workflows/gate.yml': entry },
      proposal: gate().replace('name: Required gate', 'name: Gate'),
    });
    assert.match(
      validateRequiredContexts(renaming, { trustedRoot: trusted }).join('\n'),
      /pre-approval of \.github\/workflows\/gate\.yml: required status check "Required gate"/,
    );

    const removal = repository(track, {
      preApproved: { '.github/workflows/gate.yml': { digest: null, expires: '2026-10-01' } },
    });
    assert.match(
      validateRequiredContexts(removal, { trustedRoot: trusted }).join('\n'),
      /pre-approval of \.github\/workflows\/gate\.yml/,
    );

    const harmless = repository(track, {
      preApproved: { '.github/workflows/gate.yml': entry },
      proposal: gate({ job: '    timeout-minutes: 10\n' }),
    });
    assert.deepEqual(validateRequiredContexts(harmless, { trustedRoot: trusted }), []);
  });
});
