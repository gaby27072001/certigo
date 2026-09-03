import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { parseDocument, stringify } from 'yaml';
import { validateRunnerRouting } from './workflow-runner-routing-policy.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');

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

function mutateJob(repositoryRoot, fileName, jobId, mutate) {
  const workflowPath = path.join(
    repositoryRoot,
    '.github',
    'workflows',
    fileName,
  );
  const document = parseDocument(fs.readFileSync(workflowPath, 'utf8'), {
    uniqueKeys: true,
  });
  assert.equal(document.errors.length, 0);
  const workflow = document.toJS();
  mutate(workflow.jobs[jobId]);
  fs.writeFileSync(workflowPath, stringify(workflow), 'utf8');
}

test('accepts the committed runner routing contract', () => {
  assert.deepEqual(validateRunnerRouting(root), []);
});

for (const [fileName, jobId] of [
  ['ci-project-state.yml', 'validate'],
  ['codeql.yml', 'security-gate'],
  ['security-gate.yml', 'security-gate'],
]) {
  test(`rejects trusted fallback for ${fileName}/${jobId}`, () => {
    withFixture((temporary) => {
      mutateJob(temporary, fileName, jobId, (job) => {
        job['runs-on'] = ['self-hosted', 'Linux', 'X64', 'certigo-trusted'];
      });
      assert.match(
        validateRunnerRouting(temporary).join('\n'),
        /aggregate must use exact runner labels/u,
      );
    });
  });
}

for (const [surface, mutate, expected] of [
  [
    'non-empty token permissions',
    (job) => {
      job.permissions = { contents: 'read' };
    },
    /aggregate permissions must be empty/u,
  ],
  [
    'OIDC permission',
    (job) => {
      job.permissions = { 'id-token': 'write' };
    },
    /aggregate permissions must be empty/u,
  ],
  [
    'deployment environment',
    (job) => {
      job.environment = 'production';
    },
    /aggregate must not use an environment/u,
  ],
  [
    'secret reference',
    (job) => {
      job.steps[0].env.DEPLOY_TOKEN = '${{ secrets.DEPLOY_TOKEN }}';
    },
    /must not reference secrets, tokens, or OIDC/u,
  ],
  [
    'checkout action',
    (job) => {
      job.steps[0].uses = 'actions/checkout@0123456789012345678901234567890123456789';
    },
    /must not invoke actions or checkout source/u,
  ],
  [
    'repository script source',
    (job) => {
      job.steps[0].run += '\nsource .github/scripts/bootstrap.sh';
    },
    /must not load source or invoke external scripts/u,
  ],
]) {
  test(`rejects aggregate ${surface}`, () => {
    withFixture((temporary) => {
      mutateJob(temporary, 'codeql.yml', 'security-gate', mutate);
      assert.match(validateRunnerRouting(temporary).join('\n'), expected);
    });
  });
}

test('rejects a trusted fallback on the operations health probe', () => {
  withFixture((temporary) => {
    mutateJob(temporary, 'runner-health.yml', 'probe', (job) => {
      job['runs-on'] = [
        'self-hosted',
        'Linux',
        'X64',
        'certigo-ops-probe',
        'certigo-trusted',
      ];
    });
    assert.match(
      validateRunnerRouting(temporary).join('\n'),
      /health probe must use exact isolated labels/u,
    );
  });
});

test('rejects moving an existing Azure deployment job off trusted capacity', () => {
  withFixture((temporary) => {
    mutateJob(temporary, 'cd-backend.yml', 'deploy-backend', (job) => {
      job['runs-on'] = ['self-hosted', 'Linux', 'X64', 'certigo-pr'];
    });
    assert.match(
      validateRunnerRouting(temporary).join('\n'),
      /privileged job must retain exact trusted labels/u,
    );
  });
});

test('rejects changes to required check names in workflows or branch protection', () => {
  withFixture((temporary) => {
    mutateJob(temporary, 'security-gate.yml', 'security-gate', (job) => {
      job.name = 'Security gate';
    });
    const protectionPath = path.join(
      temporary,
      '.github',
      'branch-protection-main.json',
    );
    const protection = JSON.parse(fs.readFileSync(protectionPath, 'utf8'));
    protection.required_status_checks.contexts[4] = 'Renamed CodeQL gate';
    fs.writeFileSync(protectionPath, JSON.stringify(protection), 'utf8');

    const errors = validateRunnerRouting(temporary).join('\n');
    assert.match(errors, /required check name must remain "Security \/ Required gate"/u);
    assert.match(errors, /required check names or order changed/u);
  });
});
