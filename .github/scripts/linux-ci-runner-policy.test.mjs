import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import { parseDocument, stringify } from 'yaml';
import { linuxCiJobs, hostedLinuxRunner } from './linux-ci-runner-policy.mjs';
import { validateRunnerLabels } from './workflow-runner-labels.mjs';
import { validatePersistentCachePolicy } from './workflow-security-cache-policy.mjs';
import { runManifestGenerator } from './generate-workflow-semantic-manifest.mjs';

function workflow(job, permissions = { contents: 'read' }) {
  return stringify({ permissions, jobs: { validate: { 'runs-on': hostedLinuxRunner, ...job } } });
}

test('the hosted exception is exactly twelve workflows and twenty named jobs', () => {
  assert.equal(Object.keys(linuxCiJobs).length, 12);
  assert.equal(Object.values(linuxCiJobs).flat().length, 20);
  for (const [file, ids] of Object.entries(linuxCiJobs)) {
    const source = fs.readFileSync(path.resolve('.github', 'workflows', file), 'utf8');
    const document = parseDocument(source);
    const original = document.toJS();
    for (const id of ids) {
      assert.ok(Object.hasOwn(original.jobs, id), `${file}: ${id}`);
      document.setIn(['jobs', id, 'runs-on'], hostedLinuxRunner);
    }
    assert.deepEqual(validateRunnerLabels(source, file), [], file);
    assert.deepEqual(validateRunnerLabels(String(document), file), [], file);
    assert.deepEqual(validatePersistentCachePolicy(String(document), file), [], file);
    assert.deepEqual(
      validateRunnerLabels(String(document).replaceAll('runs-on:', '"runs-on":'), file),
      [],
      `quoted key: ${file}`,
    );
  }
});

test('hosted runners never widen the workflow, job, or runner scope', () => {
  for (const file of [
    'codeql.yml', 'ci-infra.yml', 'security-gate.yml', 'cd-backend.yml',
    'release-android.yml', 'release-ios.yml', 'runner-health.yml',
    'test-account-deletion-cosmos.yml', 'dart-sast.yml', 'unknown.yml',
  ]) {
    assert.ok(validateRunnerLabels(workflow({}), file).length > 0, file);
  }
  assert.ok(validateRunnerLabels(workflow({}), 'ci-mobile.yml').length > 0);
  for (const runner of [
    'ubuntu-latest', 'ubuntu-22.04', 'macos-15', ['ubuntu-24.04'],
    '${{ vars.RUNNER }}', { labels: 'ubuntu-24.04' },
  ]) {
    assert.ok(validateRunnerLabels(workflow({ 'runs-on': runner }), 'ci-content.yml').length > 0);
  }
});

test('hosted Linux jobs reject decoded privilege surfaces and inherited write permissions', () => {
  for (const job of [
    { permissions: { contents: 'write' } },
    { permissions: { 'id-token': 'write' } },
    { permissions: 'write-all' },
    { environment: 'production' },
    { secrets: 'inherit' },
    { env: { TOKEN: '${{ secrets["TOKEN"] }}' } },
    { steps: [{ uses: 'azure/login@sha' }] },
    { steps: [{ run: 'az login --identity' }] },
    { steps: [{ run: 'echo KeyVault' }] },
  ]) {
    assert.ok(validateRunnerLabels(workflow(job), 'ci-content.yml').length > 0, JSON.stringify(job));
  }
  assert.ok(validateRunnerLabels(workflow({}, { contents: 'write' }), 'ci-content.yml').length > 0);
  assert.ok(validateRunnerLabels(workflow({}, 'read-all'), 'ci-content.yml').length > 0);
});

test('the hosted project-state aggregate cannot consume PR source', () => {
  for (const value of [
    '${{ github.event.pull_request.head.sha }}', '.untrusted-source', '.untrusted-restore',
  ]) {
    assert.match(
      validateRunnerLabels(workflow({ steps: [{ run: `echo ${value}` }] }), 'ci-project-state.yml')
        .join('\n'),
      /aggregate job validate must not checkout or parse PR source/,
    );
  }
});

test('moving to hosted Linux cannot introduce persistent dependency caches', () => {
  for (const step of [
    { uses: 'actions/cache@sha' },
    { uses: 'actions/setup-node@sha', with: { cache: 'npm' } },
    { uses: 'subosito/flutter-action@sha' },
  ]) {
    assert.ok(validatePersistentCachePolicy(workflow({ steps: [step] }), 'ci-content.yml').length > 0);
  }
});

function setFixtureRunners(root, hosted) {
  for (const [file, ids] of Object.entries(linuxCiJobs)) {
    const location = path.join(root, '.github', 'workflows', file);
    let currentJob;
    const text = fs.readFileSync(location, 'utf8').split('\n').map((line) => {
      const match = /^ {2}([\w-]+):\s*$/u.exec(line);
      if (match) currentJob = match[1];
      if (!ids.includes(currentJob) || !/^ {4}runs-on:/u.test(line)) return line;
      const pool = file === 'ci-project-state.yml' && currentJob === 'validate'
        ? 'certigo-trusted' : 'certigo-pr';
      return `    runs-on: ${hosted ? hostedLinuxRunner : `[self-hosted, Linux, X64, ${pool}]`}`;
    }).join('\n');
    fs.writeFileSync(location, text);
  }
}

function validateFixtureTransition(t, copiedHosted) {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-linux-ci-'));
  t.after(() => fs.rmSync(temporary, { recursive: true, force: true }));
  const base = path.join(temporary, 'base');
  fs.mkdirSync(base);
  for (const relative of [
    '.github', 'docs', 'tools', 'infra', 'backend/run-account-deletion-cosmos-emulator.sh',
    'codemagic.yaml', 'SECURITY.md', 'package.json', '.checkov.yaml',
  ]) {
    const target = path.join(base, relative);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.cpSync(path.resolve(relative), target, { recursive: true });
  }
  fs.symlinkSync(path.resolve('node_modules'), path.join(base, 'node_modules'),
    process.platform === 'win32' ? 'junction' : 'dir');
  const manifestPath = path.join(base, '.github', 'scripts', 'workflow-semantic-manifest.json');
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  manifest.preApproved = {};
  fs.writeFileSync(manifestPath, JSON.stringify(manifest));
  const proposals = path.join(base, '.github', 'workflows-proposed');
  if (fs.existsSync(proposals)) {
    fs.rmSync(proposals, { recursive: true });
  }
  const generate = (root, mode) => {
    assert.equal(runManifestGenerator({ root, mode, log: () => {}, print: () => {} }), 0);
    const golden = path.join(root, '.github', 'scripts', 'account-deletion-cosmos-policy.test.mjs');
    const digest = crypto.createHash('sha256')
      .update(fs.readFileSync(path.join(root, '.github', 'scripts', 'workflow-semantic-manifest.json')))
      .digest('hex');
    fs.writeFileSync(golden, fs.readFileSync(golden, 'utf8')
      .replace(/const manifestGoldenDigest = '[a-f0-9]{64}'/u,
        `const manifestGoldenDigest = '${digest}'`));
  };
  const validate = (root) => {
    const result = spawnSync(process.execPath, [
      path.join(base, '.github', 'scripts', 'validate-workflow-security.mjs'), '--workspace', root,
    ], { encoding: 'utf8' });
    assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`);
  };
  setFixtureRunners(base, copiedHosted);
  generate(base, '--write');
  validate(base);
  // The transition always starts from its own old state, not production's current runners.
  setFixtureRunners(base, false);
  generate(base, '--write');
  validate(base);
  const originals = new Map();
  for (const file of Object.keys(linuxCiJobs)) {
    const location = path.join(base, '.github', 'workflows', file);
    originals.set(location, fs.readFileSync(location, 'utf8'));
  }
  setFixtureRunners(base, true);
  generate(base, '--pre-approve');
  const candidate = path.join(temporary, 'candidate');
  fs.cpSync(base, candidate, { recursive: true, filter: (source) => path.basename(source) !== 'node_modules' });
  for (const [location, source] of originals) fs.writeFileSync(location, source);
  validate(base);
  generate(candidate, '--write');
  validate(candidate);
}

test('the full validator accepts old, pre-approved and applied Linux runner trees', (t) => {
  for (const copiedHosted of [false, true]) {
    validateFixtureTransition(t, copiedHosted);
  }
});
