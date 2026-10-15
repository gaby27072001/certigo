import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import YAML from 'yaml';
import { fileURLToPath } from 'node:url';
import {
  isReviewedMainCodeqlJob,
  isReviewedWorkflowTransition,
} from './backend-deploy-workflow-policy.mjs';
import {
  fingerprintWorkflow, proposalRelativePath, renderWorkflowManifest,
} from './workflow-semantic-fingerprint.mjs';
import { validateRunnerLabels } from './workflow-runner-labels.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const workflowPath = '.github/workflows/codeql.yml';
const target = fs.readFileSync(path.join(root, workflowPath), 'utf8');
const hash = (bytes) => createHash('sha256').update(bytes).digest('hex');
const prRunner = 'runs-on: [self-hosted, Linux, X64, certigo-pr]';
const trustedRunner = 'runs-on: [self-hosted, Linux, X64, certigo-trusted]';
const targetCondition = "${{ always() && github.event_name == 'pull_request_target'"
  + " && github.event.pull_request.head.repo.full_name == github.repository"
  + " && needs.freshness.outputs.current != 'false' && needs.changes.outputs.has_changes == 'true' }}";
const sourceCondition = "${{ always() && (github.event_name != 'pull_request_target'"
  + " || needs.freshness.outputs.current != 'false') && needs.changes.outputs.has_changes == 'true' }}";
const source = target
  .replace(/^  analyze-main:[\s\S]*?(?=^  security-gate:)/mu, '')
  .replace(targetCondition, sourceCondition)
  .replace('      pull-requests: read\n    env:', '      pull-requests: read\n      security-events: write\n    env:')
  .replace('upload: never', 'upload: always')
  .replace('needs: [freshness, changes, analyze, analyze-main]', 'needs: [freshness, changes, analyze]')
  .replace("ANALYZE_RESULT: ${{ github.event_name == 'pull_request_target' && needs.analyze.result || needs.analyze-main.result }}",
    'ANALYZE_RESULT: ${{ needs.analyze.result }}')
  .replaceAll('runs-on: ubuntu-24.04', prRunner)
  .replace(/(  security-gate:[\s\S]*?)runs-on: \[self-hosted, Linux, X64, certigo-pr\]/u,
    `$1${trustedRunner}`);
const now = new Date('2026-10-15T00:00:00Z');
function write(directory, relative, bytes) {
  const file = path.join(directory, relative);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, bytes);
}
function fixture(t) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-scanner-transition-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const manifest = JSON.parse(fs.readFileSync(
    path.join(root, '.github/scripts/workflow-semantic-manifest.json'), 'utf8',
  ));
  manifest.preApproved = {};
  for (const state of Object.values(manifest.states)) {
    state[workflowPath] = fingerprintWorkflow(workflowPath, source).digest;
  }
  write(directory, workflowPath, source);
  write(directory, '.github/scripts/workflow-semantic-manifest.json', renderWorkflowManifest(manifest));
  return { directory, manifest };
}
function approve({ directory, manifest }, expires = '2026-10-29') {
  manifest.preApproved[workflowPath] = {
    digest: fingerprintWorkflow(workflowPath, target).digest, expires,
  };
  write(directory, proposalRelativePath(workflowPath), target);
  write(directory, '.github/scripts/workflow-semantic-manifest.json', renderWorkflowManifest(manifest));
}

test('CodeQL exact source and target keep threshold, no artifact dependency and PR read-only isolation', () => {
  assert.equal(hash(source), '30cb9b1ab2d3a8d440530194b593e34bdc2623ac28b04f3fa46c391a58afa124');
  assert.equal(hash(target), 'dc1fd62b98b5bbe676984059025e99f77aa3bf0bdfc012c69fa2d478bb28dd6e');
  const workflow = YAML.parse(target);
  const { analyze, 'analyze-main': main, 'security-gate': gate } = workflow.jobs;
  assert.deepEqual(analyze.permissions, { actions: 'read', contents: 'read', 'pull-requests': 'read' });
  assert.equal(analyze.if, targetCondition);
  assert.equal(analyze.steps.find((step) => step.id === 'codeql-analysis').with.upload, 'never');
  assert.equal(main.permissions['security-events'], 'write');
  assert.equal(main.if, "${{ always() && (github.event_name == 'push' || github.event_name == 'schedule') && github.ref == 'refs/heads/main' && needs.changes.result == 'success' && needs.changes.outputs.has_changes == 'true' }}");
  for (const job of [analyze, main]) {
    assert.equal(job.env.CODEQL_BLOCKING_SECURITY_SEVERITY, '7.0');
    assert.ok(job.steps.some((step) => step.name === 'Enforce CodeQL severity threshold'
      && step.if === '${{ always() }}'
      && step.run.includes('$TRUSTED_CONTROL_DIR/.github/scripts/enforce-codeql-sarif.mjs')));
    assert.equal(job.steps.find((step) => step.name === 'Initialize CodeQL').with['config-file'],
      './.trusted-control/.github/codeql/codeql-config.yml');
    assert.doesNotMatch(JSON.stringify(job), /upload-artifact|download-artifact|secrets\.|id-token|environment/iu);
  }
  for (const step of main.steps.filter((step) => step.uses?.startsWith('actions/checkout@'))) {
    assert.equal(step.with.ref, '${{ github.sha }}');
    assert.equal(step.with['persist-credentials'], false);
  }
  assert.deepEqual(gate.permissions, {});
  assert.deepEqual(gate.needs, ['freshness', 'changes', 'analyze', 'analyze-main']);
  assert.equal(gate.steps[0].env.ANALYZE_RESULT,
    "${{ github.event_name == 'pull_request_target' && needs.analyze.result || needs.analyze-main.result }}");
  assert.doesNotMatch(JSON.stringify(gate), /checkout@|\.untrusted-source|head\.sha/u);
});

test('scanner privilege transition needs exact trusted source, active BASE approval and exact target', (t) => {
  const trusted = fixture(t);
  const candidate = fixture(t);
  approve(candidate);
  assert.equal(isReviewedWorkflowTransition(target, workflowPath, trusted.directory, { now }), false);
  assert.equal(isReviewedWorkflowTransition(target, proposalRelativePath(workflowPath), trusted.directory, { now }), true);
  approve(trusted);
  assert.equal(isReviewedWorkflowTransition(target, workflowPath, trusted.directory, { now }), true);
  assert.equal(isReviewedMainCodeqlJob(target, workflowPath, 'analyze-main', trusted.directory), true);
  assert.deepEqual(validateRunnerLabels(target, workflowPath, { trustedRoot: trusted.directory }), []);
  for (const mutation of [
    target + '\n# mutation\n',
    target.replace('CODEQL_BLOCKING_SECURITY_SEVERITY: "7.0"', 'CODEQL_BLOCKING_SECURITY_SEVERITY: "9.0"'),
    target.replace('upload: never', 'upload: always'),
    target.replace("github.event_name == 'push' || github.event_name == 'schedule'", "github.event_name == 'pull_request_target'"),
    target.replace('ref: ${{ github.sha }}', 'ref: ${{ github.event.pull_request.head.sha }}'),
    target.replace('permissions: {}', 'permissions:\n  contents: write'),
    target.replace('    runs-on: ubuntu-24.04', '    runs-on: ubuntu-latest'),
  ]) {
    assert.equal(isReviewedWorkflowTransition(mutation, workflowPath, trusted.directory, { now }), false);
    assert.equal(isReviewedMainCodeqlJob(mutation, workflowPath, 'analyze-main', trusted.directory), false);
    assert.notDeepEqual(validateRunnerLabels(mutation, workflowPath, { trustedRoot: trusted.directory }), []);
  }
  assert.equal(isReviewedWorkflowTransition(target, '.github/workflows/other.yml', trusted.directory, { now }), false);
  approve(trusted, '2026-10-14');
  assert.equal(isReviewedWorkflowTransition(target, workflowPath, trusted.directory, { now }), false);
  approve(trusted);
  write(trusted.directory, workflowPath, `${source}\n# changed BASE\n`);
  assert.equal(isReviewedWorkflowTransition(target, workflowPath, trusted.directory, { now }), false);
});

test('read-only scanner aggregates reject privilege or PR source execution', () => {
  for (const file of ['codeql.yml', 'security-gate.yml']) {
    for (const mutation of [
      { permissions: { 'security-events': 'write' } },
      { permissions: { 'id-token': 'write' } },
      { env: { SECRET: '${{ secrets.TOKEN }}' } },
      { steps: [{ uses: 'actions/checkout@sha', with: { ref: '${{ github.event.pull_request.head.sha }}' } }] },
    ]) {
      const text = YAML.stringify({
        permissions: {}, jobs: { 'security-gate': { 'runs-on': 'ubuntu-24.04', ...mutation } },
      });
      assert.notDeepEqual(validateRunnerLabels(text, file), []);
    }
  }
});

test('security scanner orchestration is another exact prior-BASE-approved transition', (t) => {
  const file = '.github/workflows/security-gate.yml';
  const text = fs.readFileSync(path.join(root, file), 'utf8');
  const original = text.replaceAll('runs-on: ubuntu-24.04', prRunner)
    .replace(/(  security-gate:[\s\S]*?)runs-on: \[self-hosted, Linux, X64, certigo-pr\]/u,
      `$1${trustedRunner}`);
  assert.equal(hash(original), 'f8b0c946071b40068f89e4c04a6bb3c41e260086325651788632788a1c6dbab6');
  assert.equal(hash(text), '17e00493c9e5e6a7c6c337ceb1706f0717419f797b5661ecb33d6e447e38a6e6');
  const trusted = fixture(t);
  write(trusted.directory, file, original);
  for (const state of Object.values(trusted.manifest.states)) {
    state[file] = fingerprintWorkflow(file, original).digest;
  }
  write(trusted.directory, '.github/scripts/workflow-semantic-manifest.json',
    renderWorkflowManifest(trusted.manifest));
  assert.equal(isReviewedWorkflowTransition(text, file, trusted.directory, { now }), false);
  trusted.manifest.preApproved[file] = {
    digest: fingerprintWorkflow(file, text).digest, expires: '2026-10-29',
  };
  write(trusted.directory, proposalRelativePath(file), text);
  write(trusted.directory, '.github/scripts/workflow-semantic-manifest.json',
    renderWorkflowManifest(trusted.manifest));
  assert.equal(isReviewedWorkflowTransition(text, file, trusted.directory, { now }), true);
  for (const mutation of [
    text + '\n# unrelated change\n',
    text.replace('permissions: {}', 'permissions:\n  contents: write'),
    text.replace('enforce_result "Checkov"', 'true # enforce_result "Checkov"'),
    text.replace('    permissions: {}', '    permissions:\n      id-token: write'),
  ]) {
    assert.equal(isReviewedWorkflowTransition(mutation, file, trusted.directory, { now }), false);
  }
});

test('every executable official PR and reusable CI job is hosted and read-only', () => {
  const directory = path.join(root, '.github/workflows');
  let inspected = 0;
  for (const file of fs.readdirSync(directory).filter((name) => name.endsWith('.yml'))) {
    const workflow = YAML.parse(fs.readFileSync(path.join(directory, file), 'utf8'));
    if (!workflow.on || !['pull_request', 'pull_request_target', 'workflow_call']
      .some((event) => Object.hasOwn(workflow.on, event))) continue;
    for (const [id, job] of Object.entries(workflow.jobs)) {
      if (job.uses) {
        assert.match(job.uses, /^\.\/\.github\/workflows\//u);
        assert.equal(job.secrets, undefined);
        continue;
      }
      if (file === 'codeql.yml' && id === 'analyze-main') continue;
      inspected += 1;
      assert.equal(job['runs-on'], 'ubuntu-24.04', `${file}/${id}`);
      for (const permissions of [workflow.permissions, job.permissions]) {
        if (permissions === undefined) continue;
        assert.equal(typeof permissions, 'object', `${file}/${id}`);
        assert.ok(Object.entries(permissions).every(
          ([key, value]) => ['read', 'none'].includes(value) && key !== 'id-token',
        ), `${file}/${id}`);
      }
      assert.equal(job.environment, undefined, `${file}/${id}`);
      assert.equal(job.secrets, undefined, `${file}/${id}`);
      assert.doesNotMatch(JSON.stringify([workflow.env, job]), /secrets\s*[.[]|azure\/login@/iu);
    }
  }
  assert.equal(inspected, 26);
});
