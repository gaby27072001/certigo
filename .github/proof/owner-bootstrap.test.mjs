import assert from 'node:assert/strict';
import test from 'node:test';
import {
  target, verifyMetadata, verifyRun, verifyJobs, policyJobs, candidateJob, verifyAnalysis, collect,
  verifyCoverageEntries,
  verifyProcessing, verifyUploadInterval,
  verifyUploaded,
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
      number: target.pull, state: 'open',
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
    id: 1, commit_sha: target.candidate, ref: `refs/pull/${target.pull}/head`,
    category: target.category, tool: { name: 'CodeQL', version: '2.27.2' },
    analysis_key: `${target.workflow}:codeql-proof`, environment: '{}',
    error: '', results_count: 0,
    sarif_id: 'd05895b6-c883-11f1-96cd-d32848f39038',
    url: `https://api.github.com/repos/${target.repository}/code-scanning/analyses/1`,
  };
  verifyAnalysis(analysis, source, 1);
  for (const key of ['commit_sha', 'ref', 'category', 'analysis_key', 'sarif_id', 'url']) {
    assert.throws(() => verifyAnalysis({ ...analysis, [key]: 'wrong' }, source, 1));
  }
  assert.throws(() => verifyAnalysis({
    ...analysis, tool: { name: 'CodeQL', version: 'changed-version' },
  }, source, 1), /REFUSE/);
});

test('REFUSE PR10 metadata or analysis in the independent PR16 proof', () => {
  const m = fixture();
  m.pull.number = 10;
  assert.throws(() => verifyMetadata(m, source), /REFUSE/);
  m.pull.number = target.pull;
  m.pull.head.sha = '4cbb61c46b45c676b01a36fda0dad7e453a312c3';
  assert.throws(() => verifyMetadata(m, source), /REFUSE/);
});

test('accepts actual processing API shape and refuses pending/errors/wrong destination', () => {
  const sarifId = 'd05895b6-c883-11f1-96cd-d32848f39038';
  const status = {
    processing_status: 'complete', errors: null,
    analyses_url: `https://api.github.com/repos/${target.repository}/code-scanning/analyses?sarif_id=${sarifId}`,
  };
  verifyProcessing(status, sarifId);
  for (const processing_status of ['pending', 'failed', undefined]) {
    assert.throws(() => verifyProcessing({ ...status, processing_status }, sarifId), /REFUSE/);
  }
  assert.throws(() => verifyProcessing({ ...status, errors: ['error'] }, sarifId), /REFUSE/);
  assert.throws(() => verifyProcessing({
    ...status, analyses_url: 'https://example.invalid',
  }, sarifId), /REFUSE/);
});

test('REFUSE missing or out-of-job analysis timestamps', () => {
  const upload = {
    started_at: '2026-10-15T10:33:00Z', completed_at: '2026-10-15T10:33:15Z',
  };
  verifyUploadInterval({ created_at: '2026-10-15T10:33:10Z' }, upload);
  for (const created_at of [undefined, 'invalid', '2026-10-15T10:32:59Z', '2026-10-15T10:33:16Z']) {
    assert.throws(() => verifyUploadInterval({ created_at }, upload), /REFUSE/);
  }
});

test('full upload verifier accepts actual API fields without sarif_url and still fails closed', async () => {
  const m = fixture();
  const sarifId = 'd05895b6-c883-11f1-96cd-d32848f39038';
  const analysis = {
    id: 1, commit_sha: target.candidate, ref: `refs/pull/${target.pull}/head`,
    category: target.category, tool: { name: 'CodeQL', version: '2.27.2' },
    analysis_key: `${target.workflow}:codeql-proof`, environment: '{}',
    error: '', results_count: 5, sarif_id: sarifId,
    url: `https://api.github.com/repos/${target.repository}/code-scanning/analyses/1`,
    created_at: '2026-10-15T10:33:10Z',
  };
  const status = {
    processing_status: 'complete', errors: null,
    analyses_url: `https://api.github.com/repos/${target.repository}/code-scanning/analyses?sarif_id=${sarifId}`,
  };
  const data = (value) => async () => ({ data: value });
  const upload = {
    name: 'Analyze and upload under dedicated NONOFFICIAL category', conclusion: 'success',
    started_at: '2026-10-15T10:33:00Z', completed_at: '2026-10-15T10:33:15Z',
  };
  const github = {
    rest: {
      repos: { get: data(m.repository), getCommit: data({ sha: target.candidate }) },
      users: { getByUsername: data(m.owner) },
      actions: { getWorkflow: data(m.workflow), getWorkflowRun: data(m.run),
        listJobsForWorkflowRunAttempt: () => {} },
      git: { getRef: async ({ ref }) => ({
        data: { object: { sha: ref === 'heads/main' ? target.base : source } },
      }) },
      pulls: { get: data(m.pull) },
      codeScanning: { getSarif: data(status) },
    },
    request: data([analysis]),
    paginate: async () => [{ id: 1, name: policyJobs[2], run_id: 1, steps: [upload] }],
  };
  const context = {
    runId: 1, sha: source, actor: target.owner, eventName: 'workflow_dispatch', ref: m.ref,
  };
  const env = {
    GITHUB_ACTOR_ID: String(target.ownerId), GITHUB_WORKFLOW_REF: m.workflowRef,
    GITHUB_WORKFLOW_SHA: source, GITHUB_RUN_ATTEMPT: '1',
  };
  const original = Object.fromEntries(Object.keys(env).map((key) => [key, process.env[key]]));
  Object.assign(process.env, env);
  try {
    await verifyUploaded(github, context, sarifId);
    analysis.sarif_id = 'b05895b6-c883-11f1-96cd-d32848f39038';
    await assert.rejects(verifyUploaded(github, context, sarifId), /SARIF ID mismatch/);
    analysis.sarif_id = sarifId;
    status.processing_status = 'pending';
    await assert.rejects(verifyUploaded(github, context, sarifId), /REFUSE/);
    status.processing_status = 'complete';
    upload.conclusion = 'failure';
    await assert.rejects(verifyUploaded(github, context, sarifId), /REFUSE/);
  } finally {
    for (const [key, value] of Object.entries(original)) {
      if (value === undefined) delete process.env[key]; else process.env[key] = value;
    }
  }
});

test('REFUSE missing changed-script extraction rather than accept a successful empty scan', () => {
  const scripts = ['.github/scripts/validate-workflow-security.mjs'];
  verifyCoverageEntries(['home/runner/work/certigo/certigo/candidate/' + scripts[0]], scripts);
  assert.throws(() => verifyCoverageEntries([], scripts), /REFUSE/);
  assert.throws(() => verifyCoverageEntries(['tools/other.mjs'], scripts), /REFUSE/);
  assert.throws(() => verifyCoverageEntries(['.trusted-control/' + scripts[0]], scripts), /REFUSE/);
});
