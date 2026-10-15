import assert from 'node:assert/strict';
import test from 'node:test';
import {
  target, verifyMetadata, verifyRun, verifyJobs, policyJobs, candidateJob, verifyAnalysis, collect,
} from './owner-bootstrap.mjs';

const source = 'a'.repeat(40);
function fixture() {
  const owner = { login: target.owner, id: target.ownerId };
  const repo = { full_name: target.repository, owner, fork: false };
  return {
    repository: repo, owner, actor: owner.login, actorId: owner.id,
    event: 'workflow_dispatch', ref: `refs/heads/${target.branch}`,
    workflowRef: `${target.repository}/${target.workflow}@refs/heads/${target.branch}`,
    workflowSha: source, sourceRef: source, mainRef: target.base, pullRef: target.candidate,
    workflow: { id: target.workflowId, path: target.workflow, state: 'active' },
    pull: {
      number: 10, state: 'open',
      head: { sha: target.candidate, repo },
      base: { sha: target.base, ref: 'main', repo },
    },
    run: {
      id: 1, repository: repo, head_repository: repo, actor: owner, triggering_actor: owner,
      event: 'workflow_dispatch', path: target.workflow, workflow_id: target.workflowId,
      head_branch: target.branch, head_sha: source, run_attempt: 1,
      status: 'completed', conclusion: 'success',
    },
  };
}

test('accepts only complete owner-bound immutable metadata', () => {
  verifyMetadata(fixture(), source);
  verifyRun(fixture().run, source);
});

for (const [name, mutate] of [
  ['nonowner', (m) => { m.actor = 'outsider'; }],
  ['wrong actor ID', (m) => { m.actorId = 1; }],
  ['fork', (m) => { m.pull.head.repo = { full_name: 'fork/repo', fork: true }; }],
  ['closed PR', (m) => { m.pull.state = 'closed'; }],
  ['stale head', (m) => { m.pull.head.sha = 'b'.repeat(40); }],
  ['stale base', (m) => { m.pull.base.sha = 'b'.repeat(40); }],
  ['changed main', (m) => { m.mainRef = 'b'.repeat(40); }],
  ['missing SHA', (m) => { delete m.pull.head.sha; }],
  ['incomplete metadata', (m) => { delete m.owner; }],
  ['wrong workflow ref', (m) => { m.workflowRef += '/wrong'; }],
  ['wrong source SHA', (m) => { m.workflowSha = 'b'.repeat(40); }],
  ['source branch moved', (m) => { m.sourceRef = 'b'.repeat(40); }],
  ['wrong event', (m) => { m.event = 'pull_request_target'; }],
  ['wrong branch', (m) => { m.ref = 'refs/heads/main'; }],
  ['wrong workflow', (m) => { m.workflow.id = 42; }],
  ['missing run', (m) => { delete m.run; }],
  ['wrong run source', (m) => { m.run.head_sha = 'b'.repeat(40); }],
  ['nonowner triggering actor', (m) => { m.run.triggering_actor = { login: 'outsider' }; }],
  ['rerun', (m) => { m.run.run_attempt = 2; }],
]) {
  test(`REFUSE ${name}`, () => {
    const metadata = fixture();
    mutate(metadata);
    assert.throws(() => verifyMetadata(metadata, source));
  });
}

test('REFUSE API 404 (never convert failure to acceptance)', async () => {
  const api404 = () => Promise.reject(Object.assign(new Error('Not Found'), { status: 404 }));
  const github = { rest: {
    repos: { get: api404, getCommit: api404 },
    users: { getByUsername: api404 }, actions: { getWorkflow: api404, getWorkflowRun: api404 },
    git: { getRef: api404 }, pulls: { get: api404 },
  } };
  await assert.rejects(collect(github, { runId: 1 }), /Not Found/);
});

const jobs = () => [...policyJobs, candidateJob].map((name, index) => ({
  name, id: index + 1, run_id: 1, run_attempt: 1, status: 'completed', conclusion: 'success',
  labels: ['ubuntu-24.04'], runner_name: `GitHub Actions ${index + 1}`,
  runner_group_name: 'GitHub Actions', steps: [{ conclusion: 'success' }],
  started_at: '2026-10-15T10:00:00Z', completed_at: '2026-10-15T10:01:00Z',
}));
test('accepts exact hosted provenance; candidate failure is report-only', () => {
  verifyJobs(jobs(), 1);
  const candidateFailure = jobs();
  candidateFailure[3].conclusion = 'failure';
  verifyJobs(candidateFailure, 1);
});
for (const status of ['running', 'skipped', 'cancelled', 'failure']) {
  test(`REFUSE ${status} relevant proof job/run`, () => {
    const j = jobs();
    j[0].conclusion = status;
    if (status === 'running') j[0].status = 'in_progress';
    assert.throws(() => verifyJobs(j, 1), /REFUSE/);
    const run = fixture().run;
    run.conclusion = status;
    if (status === 'running') run.status = 'in_progress';
    assert.throws(() => verifyRun(run, source), /REFUSE/);
  });
}
test('REFUSE missing jobs and wrong hosted labels', () => {
  assert.throws(() => verifyJobs(jobs().slice(1), 1), /REFUSE/);
  const j = jobs();
  j[0].labels = ['self-hosted', 'ubuntu-24.04'];
  assert.throws(() => verifyJobs(j, 1), /REFUSE/);
  j[0].labels = ['ubuntu-24.04'];
  j[0].runner_group_name = 'Default';
  assert.throws(() => verifyJobs(j, 1), /REFUSE/);
});
test('REFUSE invalid/missing upload provenance', () => {
  assert.throws(() => verifyAnalysis(null, source, 1), /REFUSE/);
  const analysis = {
    id: 1, commit_sha: target.candidate, ref: 'refs/pull/10/head',
    category: target.category, tool: { name: 'CodeQL', version: 'verified-at-runtime' },
    analysis_key: `${target.workflow}:codeql-proof`, environment: '{}',
    error: '', results_count: 0,
    sarif_url: `https://api.github.com/repos/${target.repository}/code-scanning/sarifs/id`,
  };
  verifyAnalysis(analysis, source, 1);
  for (const key of ['commit_sha', 'ref', 'category', 'analysis_key', 'sarif_url']) {
    assert.throws(() => verifyAnalysis({ ...analysis, [key]: 'wrong' }, source, 1));
  }
});
