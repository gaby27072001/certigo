import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import YAML from 'yaml';
import { isReviewedWorkflowTransition } from './backend-deploy-workflow-policy.mjs';
import {
  fingerprintWorkflow, proposalRelativePath, renderWorkflowManifest,
} from './workflow-semantic-fingerprint.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const file = '.github/workflows/codeql.yml';
const checkedIn = fs.readFileSync(path.join(root, file), 'utf8');
const target = checkedIn
  .replaceAll('UNTRUSTED_SOURCE_DIR: ${{ github.workspace }}/.untrusted-source',
    'UNTRUSTED_SOURCE_DIR: ${{ github.workspace }}')
  .replaceAll('          path: .untrusted-source\n', '          path: .\n')
  .replaceAll('          source-root: .untrusted-source\n', '          source-root: .\n');
const source = target
  .replaceAll('UNTRUSTED_SOURCE_DIR: ${{ github.workspace }}\n',
    'UNTRUSTED_SOURCE_DIR: ${{ github.workspace }}/.untrusted-source\n')
  .replaceAll('          path: .\n', '          path: .untrusted-source\n')
  .replaceAll('          source-root: .\n', '          source-root: .untrusted-source\n');
const digest = (bytes) => createHash('sha256').update(bytes).digest('hex');
function write(directory, relative, bytes) {
  const destination = path.join(directory, relative);
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.writeFileSync(destination, bytes);
}
function temporary(t) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-codeql-root-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  return directory;
}

test('PR and main use the extraction working directory while retaining immutable isolated controls', () => {
  assert.equal(digest(source), 'dc1fd62b98b5bbe676984059025e99f77aa3bf0bdfc012c69fa2d478bb28dd6e');
  assert.equal(digest(target), 'd903e104d74b224950c1bcc89ae489ef381ef43d1846b5dca02c853f50c591e6');
  const workflow = YAML.parse(target);
  for (const id of ['analyze', 'analyze-main']) {
    const job = workflow.jobs[id];
    const checkouts = job.steps.filter((step) => step.uses?.startsWith('actions/checkout@'));
    assert.equal(checkouts[0].with.path, '.');
    assert.equal(checkouts[0].with['persist-credentials'], false);
    assert.equal(checkouts[1].with.path, '.trusted-control');
    assert.equal(checkouts[1].with['persist-credentials'], false);
    assert.equal(checkouts[1].with.ref, id === 'analyze-main' ? '${{ github.sha }}'
      : "${{ github.event_name == 'pull_request_target' && github.event.pull_request.base.sha || github.sha }}");
    assert.equal(job.env.UNTRUSTED_SOURCE_DIR, '${{ github.workspace }}');
    assert.equal(job.env.CODEQL_BLOCKING_SECURITY_SEVERITY, '7.0');
    assert.equal(job.steps.find((step) => step.name === 'Initialize CodeQL').with['source-root'], '.');
    assert.equal(job.steps.find((step) => step.name === 'Perform CodeQL analysis').with.checkout_path,
      '${{ env.UNTRUSTED_SOURCE_DIR }}');
  }
  assert.deepEqual(YAML.parse(fs.readFileSync(
    path.join(root, '.github/codeql/codeql-config.yml'), 'utf8',
  ))['paths-ignore'], ['.trusted-control/**']);
});

test('double-checkout layout exposes real JavaScript and C# at extractor cwd, not hidden source only', (t) => {
  const broken = temporary(t);
  const corrected = temporary(t);
  const files = ['tools/validate_content.mjs', 'backend/src/Certigo.Api/Program.cs'];
  for (const relative of files) {
    const bytes = fs.readFileSync(path.join(root, relative));
    assert.ok(bytes.length > 0);
    write(broken, `.untrusted-source/${relative}`, bytes);
    write(corrected, relative, bytes);
  }
  for (const directory of [broken, corrected]) {
    write(directory, '.trusted-control/.github/codeql/codeql-config.yml',
      fs.readFileSync(path.join(root, '.github/codeql/codeql-config.yml')));
    write(directory, '.trusted-control/tools/trusted-only.mjs', 'throw new Error("not source");');
    write(directory, '.trusted-control/backend/TrustedOnly.cs', 'class TrustedOnly {}');
  }
  // The pinned action uses process.cwd() for trace-command, independently of init source-root.
  function visibleSources(directory) {
    return fs.readdirSync(directory, { recursive: true }).filter((relative) =>
      !relative.split(path.sep).some((part) => part.startsWith('.'))
      && /\.(?:mjs|cs)$/u.test(relative)).map((relative) => relative.split(path.sep).join('/')).sort();
  }
  assert.deepEqual(visibleSources(broken), []);
  assert.deepEqual(visibleSources(corrected), files.toSorted());
  for (const relative of files) {
    assert.deepEqual(fs.readFileSync(path.join(corrected, relative)),
      fs.readFileSync(path.join(root, relative)));
  }
});

test('root correction still requires exact trusted source and independent active BASE approval', (t) => {
  const trusted = temporary(t);
  const manifest = JSON.parse(fs.readFileSync(
    path.join(root, '.github/scripts/workflow-semantic-manifest.json'), 'utf8',
  ));
  manifest.preApproved = {};
  for (const state of Object.values(manifest.states)) {
    state[file] = fingerprintWorkflow(file, source).digest;
  }
  write(trusted, file, source);
  const save = () => write(trusted, '.github/scripts/workflow-semantic-manifest.json',
    renderWorkflowManifest(manifest));
  save();
  const now = new Date('2026-10-15T00:00:00Z');
  assert.equal(isReviewedWorkflowTransition(target, file, trusted, { now }), false);
  assert.equal(isReviewedWorkflowTransition(target, proposalRelativePath(file), trusted, { now }), true);
  manifest.preApproved[file] = {
    digest: fingerprintWorkflow(file, target).digest, expires: '2026-10-29',
  };
  write(trusted, proposalRelativePath(file), target);
  save();
  assert.equal(isReviewedWorkflowTransition(target, file, trusted, { now }), true);
  for (const mutation of [
    target.replace('source-root: .\n', 'source-root: .trusted-control\n'),
    target.replace('CODEQL_BLOCKING_SECURITY_SEVERITY: "7.0"', 'CODEQL_BLOCKING_SECURITY_SEVERITY: "9.0"'),
    target.replace('upload: never', 'upload: always'),
    target + '\n# different bytes\n',
  ]) assert.equal(isReviewedWorkflowTransition(mutation, file, trusted, { now }), false);
  manifest.preApproved[file].expires = '2026-10-14';
  save();
  assert.equal(isReviewedWorkflowTransition(target, file, trusted, { now }), false);
});
