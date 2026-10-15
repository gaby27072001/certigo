import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { target, hash, verifyMetadata, verifyRun, verifyJobs } from './owner-bootstrap.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
function command(program, args) {
  const result = spawnSync(program, args, {
    cwd: root, encoding: 'utf8', windowsHide: true, maxBuffer: 32 * 1024 * 1024,
  });
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.trim();
}
const api = (route) => JSON.parse(command('gh', ['api', route]));
const repository = `repos/${target.repository}`;
const mode = process.argv[2];
assert.ok(['preflight', 'verify'].includes(mode), 'preflight or verify required');
const source = command('git', ['rev-parse', 'HEAD']);
assert.match(source, /^[a-f0-9]{40}$/);
assert.equal(command('git', ['branch', '--show-current']), target.branch);
assert.equal(command('git', ['status', '--porcelain']), '', 'dirty proof tree');
assert.equal(command('git', ['merge-base', target.base, source]), target.base);
const changed = command('git', ['diff', '--name-only', target.base, source]).split('\n').sort();
assert.deepEqual(changed, [
  '.github/proof/inspect-owner-proof.mjs',
  '.github/proof/owner-bootstrap.mjs',
  '.github/proof/owner-bootstrap.test.mjs',
  target.workflow,
].sort(), 'proof branch changed files outside its exact scope');
const owner = api(`users/${target.owner}`);
const actor = api('user');
const repo = api(repository);
const workflow = api(`${repository}/actions/workflows/${target.workflowId}`);
const mainRef = api(`${repository}/git/ref/heads/main`).object.sha;
const sourceRef = api(`${repository}/git/ref/heads/${target.branch}`).object.sha;
const pull = api(`${repository}/pulls/10`);
const pullRef = api(`${repository}/git/ref/pull/10/head`).object.sha;
const liveFile = api(`${repository}/contents/${target.workflow}?ref=${source}`);
assert.equal(liveFile.type, 'file');
assert.equal(liveFile.encoding, 'base64');
const remoteBytes = Buffer.from(liveFile.content, 'base64');
const localBytes = Buffer.from(command('git', ['show', `${source}:${target.workflow}`]) + '\n');
assert.equal(hash(remoteBytes), hash(localBytes), 'live workflow bytes differ from commit');
assert.equal(hash(fs.readFileSync(path.join(root, target.workflow)).toString()
  .replace(/\r\n/g, '\n')), hash(remoteBytes), 'working workflow differs from live source');
const metadata = {
  repository: repo, owner, actor: actor.login, actorId: actor.id,
  event: 'workflow_dispatch', ref: `refs/heads/${target.branch}`,
  workflowRef: `${target.repository}/${target.workflow}@refs/heads/${target.branch}`,
  workflowSha: source, sourceRef, workflow, mainRef, pull, pullRef,
};
if (mode === 'preflight') {
  // No fabricated run metadata: an Actions run does not exist before dispatch.
  assert.equal(metadata.repository.full_name, target.repository);
  assert.equal(owner.id, target.ownerId);
  assert.equal(owner.login, target.owner);
  assert.equal(repo.owner.id, owner.id);
  assert.equal(repo.owner.login, owner.login);
  assert.equal(actor.login, owner.login);
  assert.equal(actor.id, owner.id);
  assert.equal(workflow.id, target.workflowId);
  assert.equal(workflow.path, target.workflow);
  assert.equal(workflow.state, 'active');
  assert.equal(mainRef, target.base);
  assert.equal(sourceRef, source);
  assert.equal(pull.number, 10);
  assert.equal(pull.state, 'open');
  assert.equal(pull.head.repo.full_name, target.repository);
  assert.equal(pull.head.repo.fork, false);
  assert.equal(pull.base.repo.full_name, target.repository);
  assert.equal(pull.head.sha, target.candidate);
  assert.equal(pullRef, target.candidate);
  assert.equal(pull.base.sha, target.base);
  assert.equal(pull.base.ref, 'main');
  console.log(JSON.stringify({
    source, computedWorkflowFileSha256: hash(remoteBytes),
    workflowGitBlobShaFromContentsAPI: liveFile.sha,
    base: mainRef, candidate: pull.head.sha, actor: actor.login, actorId: actor.id,
    dispatch: `gh workflow run ${target.workflowId} --repo ${target.repository} --ref ${target.branch}`,
    boundary: 'NONMERGEABLE transport; no run or workflow_sha API evidence claimed before dispatch',
  }, null, 2));
} else {
  const runId = Number(process.argv[3]);
  assert.ok(Number.isSafeInteger(runId) && runId > 0, 'exact run ID required');
  const run = api(`${repository}/actions/runs/${runId}`);
  metadata.run = run;
  verifyMetadata(metadata, source);
  verifyRun(run, source);
  const response = api(`${repository}/actions/runs/${runId}/attempts/1/jobs?per_page=100`);
  assert.equal(response.total_count, response.jobs.length);
  verifyJobs(response.jobs, runId);
  console.log(JSON.stringify({
    source, computedWorkflowFileSha256: hash(remoteBytes),
    workflowGitBlobShaFromContentsAPI: liveFile.sha,
    run: {
      id: run.id, url: run.html_url, event: run.event, actor: run.actor,
      attempt: run.run_attempt, path: run.path, sourceHeadShaFromActionsAPI: run.head_sha,
      status: run.status, conclusion: run.conclusion,
    },
    jobs: response.jobs.map((job) => ({
      id: job.id, name: job.name, conclusion: job.conclusion, status: job.status,
      labels: job.labels, runner_name: job.runner_name,
      runner_group_name: job.runner_group_name,
    })),
    base: mainRef, candidate: pull.head.sha,
    boundary: 'Proof only. Candidate conclusion is report-only. No official seven-context or merge attestation.',
  }, null, 2));
}
