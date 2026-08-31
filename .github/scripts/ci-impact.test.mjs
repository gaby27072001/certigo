import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  assertMatrixNotWeakened,
  bicepTargets,
  changedPaths,
  globToRegExp,
  loadMatrix,
  selectGates,
  validateMatrix,
  validateWorkflowInputs,
} from './ci-impact.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const matrix = loadMatrix(path.join(root, '.github', 'ci', 'impact-matrix.json'));

test('sensitive assertions cannot skip their required gates', () => {
  for (const assertion of matrix.sensitiveAssertions) {
    const selected = selectGates(matrix, [assertion.path]);
    for (const gate of assertion.gates) {
      assert.ok(selected.includes(gate), `${assertion.path} skipped ${gate}`);
    }
  }
});

test('unknown paths still execute the fail-closed preflight gate', () => {
  assert.deepEqual(selectGates(matrix, ['future/product/new-surface.txt']), ['preflight']);
});

test('glob matching covers roots, descendants and one-segment wildcards', () => {
  assert.match('infra/main.bicep', globToRegExp('infra/**/*.bicep'));
  assert.match('infra/modules/app.bicep', globToRegExp('infra/**/*.bicep'));
  assert.match('packages/cortex/test/a.dart', globToRegExp('packages/*/test/**'));
  assert.doesNotMatch('packages/cortex/lib/a.dart', globToRegExp('packages/*/test/**'));
});

test('invalid or weakened matrices fail closed', () => {
  const weakened = structuredClone(matrix);
  weakened.defaultGates = [];
  assert.throws(() => validateMatrix(weakened), /must fail closed/);

  const unknownGate = structuredClone(matrix);
  unknownGate.sensitiveAssertions[0].gates.push('does-not-exist');
  assert.throws(() => validateMatrix(unknownGate), /unknown gate/);

  const removedPattern = structuredClone(matrix);
  removedPattern.gates['security-policy'] = ['SECURITY.md'];
  assert.throws(
    () => assertMatrixNotWeakened(matrix, removedPattern),
    /weakened security-policy/,
  );

  const removedAssertion = structuredClone(matrix);
  removedAssertion.sensitiveAssertions = removedAssertion.sensitiveAssertions.slice(1);
  assert.throws(
    () => assertMatrixNotWeakened(matrix, removedAssertion),
    /removed sensitive assertion/,
  );
});

test('rename detection evaluates both old and new sensitive paths', () => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-impact-test-'));
  try {
    const git = (...args) => {
      const result = spawnSync('git', args, {
        cwd: temporary,
        encoding: 'utf8',
        windowsHide: true,
      });
      assert.equal(result.status, 0, result.stderr);
      return result.stdout.trim();
    };
    git('init', '--quiet');
    git('config', 'user.email', 'ci-impact@example.test');
    git('config', 'user.name', 'CI Impact Tests');
    fs.mkdirSync(path.join(temporary, '.github', 'workflows'), { recursive: true });
    fs.writeFileSync(
      path.join(temporary, '.github', 'workflows', 'security-gate.yml'),
      'name: security\n',
      'utf8',
    );
    git('add', '.');
    git('commit', '--quiet', '-m', 'baseline');
    const base = git('rev-parse', 'HEAD');
    fs.renameSync(
      path.join(temporary, '.github', 'workflows', 'security-gate.yml'),
      path.join(temporary, 'security-gate-disabled.txt'),
    );
    git('add', '-A');
    git('commit', '--quiet', '-m', 'rename');
    const head = git('rev-parse', 'HEAD');

    assert.deepEqual(changedPaths(temporary, base, head), [
      '.github/workflows/security-gate.yml',
      'security-gate-disabled.txt',
    ]);
    assert.ok(
      selectGates(matrix, changedPaths(temporary, base, head)).includes('security-policy'),
    );
  } finally {
    fs.rmSync(temporary, { recursive: true, force: true });
  }
});

test('Bicep changes compile main plus changed extant sources only', () => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-impact-bicep-'));
  try {
    fs.mkdirSync(path.join(temporary, 'infra', 'modules'), { recursive: true });
    fs.writeFileSync(path.join(temporary, 'infra', 'main.bicep'), '', 'utf8');
    fs.writeFileSync(path.join(temporary, 'infra', 'modules', 'app.bicep'), '', 'utf8');
    const git = (...args) => {
      const result = spawnSync('git', args, {
        cwd: temporary,
        encoding: 'utf8',
        windowsHide: true,
      });
      assert.equal(result.status, 0, result.stderr);
    };
    git('init', '--quiet');
    git('add', '.');
    assert.deepEqual(
      bicepTargets(temporary, [
        'infra/modules/app.bicep',
        'infra/modules/deleted.bicep',
        'docs/architecture.md',
      ]),
      ['infra/main.bicep', 'infra/modules/app.bicep'],
    );
    assert.deepEqual(
      bicepTargets(temporary, ['infra/modules/bicepconfig.json']),
      ['infra/main.bicep', 'infra/modules/app.bicep'],
    );
  } finally {
    fs.rmSync(temporary, { recursive: true, force: true });
  }
});

test('workflow inputs must be regular files contained by the PR checkout', (context) => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-impact-workflows-'));
  try {
    const workflows = path.join(temporary, '.github', 'workflows');
    fs.mkdirSync(workflows, { recursive: true });
    fs.writeFileSync(path.join(workflows, 'safe.yml'), 'name: safe\n', 'utf8');
    validateWorkflowInputs(temporary);
    fs.rmSync(path.join(workflows, 'safe.yml'));
    try {
      fs.symlinkSync(path.join(root, '.github', 'workflows', 'ci-backend.yml'), path.join(workflows, 'unsafe.yml'));
    } catch (error) {
      if (error.code === 'EPERM') {
        context.skip('symlink creation requires an unavailable Windows privilege');
        return;
      }
      throw error;
    }
    assert.throws(() => validateWorkflowInputs(temporary), /regular file|symbolic link/);
  } finally {
    fs.rmSync(temporary, { recursive: true, force: true });
  }
});
