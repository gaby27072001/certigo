import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { parseDocument, stringify } from 'yaml';
import { validateRunnerRouting } from './workflow-runner-routing-policy.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const transitionFiles = [
  'ci-project-state.yml',
  'codeql.yml',
  'security-gate.yml',
  'runner-health.yml',
];
const targetReplacements = new Map([
  [
    'ci-project-state.yml',
    [
      [
        '    runs-on: [self-hosted, Linux, X64, certigo-trusted]\n'
          + '    permissions:\n'
          + '      contents: read',
        '    runs-on: [self-hosted, Linux, X64, certigo-pr]\n'
          + '    permissions: {}',
      ],
    ],
  ],
  [
    'codeql.yml',
    [[
      '    runs-on: [self-hosted, Linux, X64, certigo-trusted]',
      '    runs-on: [self-hosted, Linux, X64, certigo-pr]',
    ]],
  ],
  [
    'security-gate.yml',
    [[
      '    runs-on: [self-hosted, Linux, X64, certigo-trusted]',
      '    runs-on: [self-hosted, Linux, X64, certigo-pr]',
    ]],
  ],
  [
    'runner-health.yml',
    [
      [
        '    # EMU policy keeps this on the redundant self-hosted pool. There is no PR\n'
          + '    # trigger, so untrusted fork code cannot reach a persistent runner.\n'
          + '    runs-on: [self-hosted, Linux, X64, certigo-trusted]',
        '    # The checkout and operational probes are isolated from both PR and\n'
          + '    # identity-bearing trusted capacity, with no fallback across labels.\n'
          + '    runs-on: [self-hosted, Linux, X64, certigo-ops-probe]',
      ],
    ],
  ],
]);

function fixture() {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-runner-routing-'));
  fs.mkdirSync(path.join(temporary, '.github'), { recursive: true });
  fs.cpSync(
    path.join(root, '.github', 'workflows'),
    path.join(temporary, '.github', 'workflows'),
    { recursive: true },
  );
  fs.copyFileSync(
    path.join(root, '.github', 'branch-protection-main.json'),
    path.join(temporary, '.github', 'branch-protection-main.json'),
  );
  return temporary;
}

function withFixture(callback) {
  const temporary = fixture();
  try {
    callback(temporary);
  } finally {
    fs.rmSync(temporary, { recursive: true, force: true });
  }
}

function workflowPath(repositoryRoot, fileName) {
  return path.join(repositoryRoot, '.github', 'workflows', fileName);
}

function replaceOnce(text, before, after, fileName) {
  const occurrences = text.split(before).length - 1;
  assert.equal(occurrences, 1, `${fileName}: expected exactly one reviewed replacement`);
  return text.replace(before, after);
}

function applyTargetFile(repositoryRoot, fileName) {
  const file = workflowPath(repositoryRoot, fileName);
  let text = fs.readFileSync(file, 'utf8');
  for (const [before, after] of targetReplacements.get(fileName)) {
    text = replaceOnce(text, before, after, fileName);
  }
  fs.writeFileSync(file, text, 'utf8');
}

function applyTargetState(repositoryRoot) {
  for (const fileName of transitionFiles) {
    applyTargetFile(repositoryRoot, fileName);
  }
}

function mutateJob(repositoryRoot, fileName, jobId, mutate) {
  const file = workflowPath(repositoryRoot, fileName);
  const document = parseDocument(fs.readFileSync(file, 'utf8'), {
    uniqueKeys: true,
  });
  assert.equal(document.errors.length, 0);
  const workflow = document.toJS();
  mutate(workflow.jobs[jobId]);
  fs.writeFileSync(file, stringify(workflow), 'utf8');
}

function assertRejected(repositoryRoot, expected = /must match one reviewed Git blob/u) {
  assert.match(validateRunnerRouting(repositoryRoot).join('\n'), expected);
}

test('accepts the exact temporary baseline Git blobs', () => {
  assert.deepEqual(validateRunnerRouting(root), []);
});

test('accepts the exact PR #356 target Git blobs', () => {
  withFixture((temporary) => {
    applyTargetState(temporary);
    assert.deepEqual(validateRunnerRouting(temporary), []);
  });
});

test('rejects every partial baseline and target mixture', () => {
  const targetStateMask = (1 << transitionFiles.length) - 1;
  for (let mask = 1; mask < targetStateMask; mask += 1) {
    withFixture((temporary) => {
      transitionFiles.forEach((fileName, index) => {
        if ((mask & (1 << index)) !== 0) {
          applyTargetFile(temporary, fileName);
        }
      });
      assertRejected(
        temporary,
        /temporary bootstrap contract forbids mixed baseline\/target blobs/u,
      );
    });
  }
});

test('rejects byte drift even when routing semantics are unchanged', () => {
  withFixture((temporary) => {
    const file = workflowPath(temporary, 'runner-health.yml');
    fs.appendFileSync(file, '# unreviewed byte drift\n', 'utf8');
    assertRejected(temporary);
  });
});

test('rejects CRLF bytes instead of hashing the worktree representation', () => {
  withFixture((temporary) => {
    const file = workflowPath(temporary, 'security-gate.yml');
    const text = fs.readFileSync(file, 'utf8');
    fs.writeFileSync(file, text.replaceAll('\n', '\r\n'), 'utf8');
    assertRejected(temporary);
  });
});

for (const [surface, mutate] of [
  [
    'alternate runner label',
    (job) => {
      job['runs-on'] = ['self-hosted', 'Linux', 'X64', 'certigo-other'];
    },
  ],
  [
    'non-empty permissions',
    (job) => {
      job.permissions = { contents: 'read' };
    },
  ],
  [
    'OIDC permission',
    (job) => {
      job.permissions = { 'id-token': 'write' };
    },
  ],
  [
    'deployment environment',
    (job) => {
      job.environment = 'production';
    },
  ],
  [
    'secret reference',
    (job) => {
      job.steps[0].env.DEPLOY_TOKEN = '${{ secrets.DEPLOY_TOKEN }}';
    },
  ],
  [
    'checkout action',
    (job) => {
      job.steps[0].uses = 'actions/checkout@0123456789012345678901234567890123456789';
    },
  ],
  [
    'repository script source',
    (job) => {
      job.steps[0].run += '\nsource .github/scripts/bootstrap.sh';
    },
  ],
  [
    'required check name',
    (job) => {
      job.name = 'Renamed CodeQL gate';
    },
  ],
]) {
  test(`rejects target aggregate ${surface}`, () => {
    withFixture((temporary) => {
      applyTargetState(temporary);
      mutateJob(temporary, 'codeql.yml', 'security-gate', mutate);
      assertRejected(temporary);
    });
  });
}

test('rejects a fallback label on the target operations health probe', () => {
  withFixture((temporary) => {
    applyTargetState(temporary);
    mutateJob(temporary, 'runner-health.yml', 'probe', (job) => {
      job['runs-on'] = [
        'self-hosted',
        'Linux',
        'X64',
        'certigo-ops-probe',
        'certigo-trusted',
      ];
    });
    assertRejected(temporary);
  });
});

test('rejects moving an existing Azure deployment job off trusted capacity', () => {
  withFixture((temporary) => {
    mutateJob(temporary, 'cd-backend.yml', 'deploy-backend', (job) => {
      job['runs-on'] = ['self-hosted', 'Linux', 'X64', 'certigo-pr'];
    });
    assertRejected(temporary, /privileged job must retain exact trusted labels/u);
  });
});

test('rejects use of the operations label outside runner health', () => {
  withFixture((temporary) => {
    mutateJob(temporary, 'ci-backend.yml', 'build-test', (job) => {
      job['runs-on'] = ['self-hosted', 'Linux', 'X64', 'certigo-ops-probe'];
    });
    assertRejected(temporary, /certigo-ops-probe is reserved for runner health/u);
  });
});

test('rejects changes to required check names in branch protection', () => {
  withFixture((temporary) => {
    const protectionPath = path.join(
      temporary,
      '.github',
      'branch-protection-main.json',
    );
    const protection = JSON.parse(fs.readFileSync(protectionPath, 'utf8'));
    protection.required_status_checks.contexts[4] = 'Renamed CodeQL gate';
    fs.writeFileSync(protectionPath, JSON.stringify(protection), 'utf8');
    assertRejected(temporary, /required check names or order changed/u);
  });
});
