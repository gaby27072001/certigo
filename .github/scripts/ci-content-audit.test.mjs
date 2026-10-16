import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import YAML from 'yaml';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const workflow = YAML.parse(fs.readFileSync(
  path.join(root, '.github/workflows/ci-content.yml'), 'utf8',
));
const audit = Object.values(workflow.jobs).flatMap((job) => job.steps ?? [])
  .find((step) => step.name === 'npm audit backend tools');

test('backend audit keeps its explicit nonblocking policy without swallowing directory failure', {
  skip: process.platform === 'win32' ? 'Linux workflow shell' : false,
}, (t) => {
  assert.equal(audit['working-directory'], 'backend');
  assert.equal(audit.run, 'npm audit --audit-level=high 2>/dev/null || true');
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-audit-cwd-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const bin = path.join(directory, 'bin');
  const backend = path.join(directory, 'backend');
  fs.mkdirSync(bin);
  fs.mkdirSync(backend);
  fs.writeFileSync(path.join(bin, 'npm'), '#!/bin/sh\npwd\nexit 7\n', { mode: 0o755 });
  const result = spawnSync('bash', ['--noprofile', '--norc', '-eo', 'pipefail', '-c', audit.run], {
    cwd: backend, env: { ...process.env, PATH: `${bin}:${process.env.PATH}` }, encoding: 'utf8',
  });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout.trim(), backend);
  const missing = spawnSync('bash', ['-c', audit.run], {
    cwd: path.join(directory, 'missing-backend'), encoding: 'utf8',
  });
  assert.equal(missing.error?.code, 'ENOENT');
});
