import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';
import { createRequire } from 'node:module';

export const target = Object.freeze({
  repository: 'gaby27072001/certigo',
  owner: 'gaby27072001',
  ownerId: 260654382,
  branch: 'gaby27072001-proof-owner-bootstrap',
  workflow: '.github/workflows/ci-content.yml',
  workflowId: 383380838,
  base: '8ddca44c67de35eac6f39c0412802a23588fd841',
  candidate: '4cbb61c46b45c676b01a36fda0dad7e453a312c3',
  pull: 10,
  category: '/bootstrap-proof/pr-10/javascript-typescript',
});
const sha40 = /^[a-f0-9]{40}$/;
const requireValue = (value, message) => assert.ok(value, `REFUSE: ${message}`);
export const hash = (bytes) => createHash('sha256').update(bytes).digest('hex');

export function verifyMetadata(m, source) {
  requireValue(sha40.test(source), 'missing or invalid immutable source SHA');
  requireValue(m.repository?.full_name === target.repository, 'wrong repository');
  requireValue(m.repository.owner?.login === target.owner
    && m.repository.owner?.id === target.ownerId, 'wrong repository owner');
  requireValue(m.owner?.login === target.owner && m.owner?.id === target.ownerId,
    'owner API identity differs');
  requireValue(m.actor === target.owner && String(m.actorId) === String(m.owner.id),
    'nonowner actor or inconsistent actor ID');
  requireValue(m.event === 'workflow_dispatch', 'not a workflow_dispatch proof');
  requireValue(m.ref === `refs/heads/${target.branch}`, 'wrong proof branch');
  requireValue(m.workflowRef
    === `${target.repository}/${target.workflow}@refs/heads/${target.branch}`,
  'wrong workflow ref');
  requireValue(m.workflowSha === source && m.sourceRef === source, 'wrong workflow source SHA');
  requireValue(m.workflow?.id === target.workflowId
    && m.workflow.path === target.workflow && m.workflow.state === 'active',
  'wrong or disabled dispatch transport');
  requireValue(m.mainRef === target.base, 'main changed');
  const p = m.pull;
  requireValue(p?.number === target.pull && p.state === 'open', 'closed or missing PR');
  requireValue(p.head?.repo?.full_name === target.repository
    && p.head.repo.fork === false && p.base?.repo?.full_name === target.repository,
  'fork or incomplete PR repository');
  requireValue(p.base.ref === 'main' && p.base.sha === target.base, 'stale PR base');
  requireValue(p.head.sha === target.candidate && m.pullRef === target.candidate,
    'stale or missing PR head');
  verifyRun(m.run, source, false);
}

export function verifyRun(run, source, completed = true) {
  requireValue(run && Number.isSafeInteger(run.id) && run.id > 0, 'missing Actions run');
  requireValue(run.repository?.full_name === target.repository
    && run.head_repository?.full_name === target.repository, 'wrong run repository');
  requireValue(run.actor?.login === target.owner && run.actor.id === target.ownerId
    && run.triggering_actor?.login === target.owner
    && run.triggering_actor.id === target.ownerId, 'nonowner run');
  requireValue(run.event === 'workflow_dispatch' && run.path === target.workflow
    && run.workflow_id === target.workflowId && run.head_branch === target.branch,
  'wrong run event, path or workflow');
  requireValue(sha40.test(source) && run.head_sha === source, 'wrong run source SHA');
  requireValue(run.run_attempt === 1, 'reruns are not accepted as this bounded proof');
  if (completed) {
    requireValue(run.status === 'completed' && run.conclusion === 'success',
      'run missing, running, skipped, cancelled or failed');
  }
}

export const policyJobs = [
  'Bootstrap proof / owner admission',
  'Bootstrap proof / immutable BASE controls',
  'Bootstrap proof / CodeQL JavaScript (not official)',
];
export const candidateJob = 'Bootstrap proof / candidate suite (report only)';

export function verifyJobs(jobs, runId) {
  requireValue(Array.isArray(jobs) && jobs.length === 4, 'missing or unexpected proof jobs');
  const ids = new Set();
  for (const name of [...policyJobs, candidateJob]) {
    const matches = jobs.filter((job) => job.name === name);
    requireValue(matches.length === 1, `missing or duplicate job ${name}`);
    const job = matches[0];
    requireValue(Number.isSafeInteger(job.id) && !ids.has(job.id)
      && job.run_id === runId && job.run_attempt === 1, 'wrong job identity');
    ids.add(job.id);
    requireValue(job.status === 'completed', `${name} is still running`);
    requireValue(job.labels?.length === 1 && job.labels[0] === 'ubuntu-24.04'
      && job.runner_group_name === 'GitHub Actions'
      && /^GitHub Actions \d+$/.test(job.runner_name ?? ''),
    `${name} has wrong hosted runner provenance`);
    requireValue(job.steps?.length > 0 && job.started_at && job.completed_at,
      `${name} has incomplete execution metadata`);
    if (policyJobs.includes(name)) {
      requireValue(job.conclusion === 'success', `${name} skipped, cancelled or failed`);
    } else {
      requireValue(['success', 'failure'].includes(job.conclusion),
        'candidate report was not executed');
    }
  }
}

export function verifyAnalysis(analysis, source, runId) {
  requireValue(Number.isSafeInteger(analysis?.id) && analysis.id > 0,
    'missing analysis ID');
  requireValue(analysis.commit_sha === target.candidate
    && analysis.ref === 'refs/pull/10/head', 'wrong analysis commit/ref');
  requireValue(analysis.category === target.category && analysis.tool?.name === 'CodeQL'
    && typeof analysis.tool.version === 'string', 'wrong CodeQL tool/category');
  requireValue(analysis.analysis_key === `${target.workflow}:codeql-proof`,
    'wrong analysis workflow/job');
  requireValue(analysis.environment === '{}' && analysis.error === ''
    && analysis.results_count >= 0, 'incomplete or failed analysis');
  const url = new URL(analysis.sarif_url);
  requireValue(url.origin === 'https://api.github.com'
    && url.pathname.startsWith(`/repos/${target.repository}/code-scanning/sarifs/`),
  'wrong analysis SARIF provenance');
  // The analyses API does not supply a workflow SHA or Actions run ID.
  requireValue(sha40.test(source) && Number.isSafeInteger(runId),
    'missing separately verified run provenance');
}

export async function collect(github, context, env = process.env) {
  const repo = { owner: target.owner, repo: 'certigo' };
  const data = async (promise) => (await promise).data;
  const [repository, owner, workflow, main, source, pull, pullRef, run] = await Promise.all([
    data(github.rest.repos.get(repo)),
    data(github.rest.users.getByUsername({ username: target.owner })),
    data(github.rest.actions.getWorkflow({ ...repo, workflow_id: target.workflowId })),
    data(github.rest.git.getRef({ ...repo, ref: 'heads/main' })),
    data(github.rest.git.getRef({ ...repo, ref: `heads/${target.branch}` })),
    data(github.rest.pulls.get({ ...repo, pull_number: target.pull })),
    data(github.rest.repos.getCommit({ ...repo, ref: 'refs/pull/10/head' })),
    data(github.rest.actions.getWorkflowRun({ ...repo, run_id: context.runId })),
  ]);
  const metadata = {
    repository, owner, workflow, pull, run,
    mainRef: main.object?.sha,
    sourceRef: source.object?.sha,
    pullRef: pullRef.sha,
    actor: context.actor,
    actorId: env.GITHUB_ACTOR_ID,
    event: context.eventName,
    ref: context.ref,
    workflowRef: env.GITHUB_WORKFLOW_REF,
    workflowSha: env.GITHUB_WORKFLOW_SHA,
  };
  verifyMetadata(metadata, context.sha);
  requireValue(Number(env.GITHUB_RUN_ATTEMPT) === run.run_attempt,
    'attempt environment differs from API');
  console.log(JSON.stringify({
    evidence: 'API metadata, not a pull_request_target event',
    sourceHeadShaFromRunAPI: run.head_sha,
    workflowShaFromGitHubEnvironment: env.GITHUB_WORKFLOW_SHA,
    base: target.base, candidate: target.candidate, run: run.id, attempt: run.run_attempt,
  }));
  return metadata;
}

function execute(command, args, cwd, env = {}) {
  const result = spawnSync(command, args, {
    cwd, env: { ...process.env, ...env }, encoding: 'utf8', maxBuffer: 32 * 1024 * 1024,
  });
  if (result.error) throw result.error;
  return result;
}

function succeed(command, args, cwd, env) {
  const result = execute(command, args, cwd, env);
  process.stdout.write(result.stdout);
  process.stderr.write(result.stderr);
  requireValue(result.status === 0, `${command} ${args.join(' ')} exited ${result.status}`);
  return result;
}

export async function trustedChecks(base, candidate) {
  const validator = path.join(base, '.github/scripts/validate-workflow-security.mjs');
  succeed(process.execPath, [validator, '--workspace', candidate], base);
  const { runManifestGenerator } = await import(pathToFileURL(
    path.join(base, '.github/scripts/generate-workflow-semantic-manifest.mjs'),
  ));
  // The BASE CLI has no workspace argument: use its exact exported entry point.
  requireValue(runManifestGenerator({ root: candidate, mode: '--check' }) === 0,
    'BASE manifest generator --check refused candidate');
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'bootstrap-adversarial-'));
  try {
    fs.cpSync(candidate, temporary, {
      recursive: true,
      filter: (source) => !['node_modules', '.git'].includes(path.basename(source)),
    });
    const variants = [
      ['modified sealed control', '.github/scripts/backend-deploy-workflow-policy.mjs',
        (text) => `${text}\n// adversarial fixture\n`],
      ['out-of-scope runner', '.github/workflows/ci-content.yml',
        (text) => text.replace('runs-on: [self-hosted, Linux, X64, certigo-pr]',
          'runs-on: ubuntu-24.04')],
      ['unapproved workflow', '.github/workflows/ci-content.yml',
        (text) => text.replace('name: ci-content', 'name: unapproved-bootstrap-fixture')],
    ];
    for (const [label, relative, mutate] of variants) {
      const file = path.join(temporary, relative);
      const original = fs.readFileSync(file, 'utf8');
      const changed = mutate(original);
      requireValue(changed !== original, `${label} fixture did not mutate anything`);
      fs.writeFileSync(file, changed);
      const result = execute(process.execPath, [validator, '--workspace', temporary], base);
      fs.writeFileSync(file, original);
      requireValue(result.status === 1 && /policy|sealed|runner|manifest/i.test(result.stderr),
        `${label} not refused by exact BASE validator: ${result.stdout}${result.stderr}`);
      console.log(`REFUSED by exact BASE validator: ${label}\n${result.stderr}`);
    }
  } finally {
    fs.rmSync(temporary, { recursive: true, force: true });
  }
}

export function baseStep(base, workflow, job, name) {
  const requireBase = createRequire(path.join(base, 'package.json'));
  const { parse } = requireBase('yaml');
  const steps = parse(fs.readFileSync(
    path.join(base, `.github/workflows/${workflow}.yml`), 'utf8',
  )).jobs[job].steps;
  const matches = steps.filter((step) => step.name === name);
  requireValue(matches.length === 1 && typeof matches[0].run === 'string',
    'exact BASE shell step missing or ambiguous');
  return matches[0].run;
}

export function runBaseStep(base, workflow, job, name, env = {}) {
  succeed('bash', ['-c', baseStep(base, workflow, job, name)], base, env);
}

export function compareLint(base, candidate) {
  const relative = '.github/workflows';
  const names = (root) => fs.readdirSync(path.join(root, relative))
    .filter((name) => /\.ya?ml$/.test(name)).sort();
  assert.deepEqual(names(base), names(candidate), 'workflow file sets differ');
  for (const name of names(base)) {
    assert.deepEqual(fs.readFileSync(path.join(base, relative, name)),
      fs.readFileSync(path.join(candidate, relative, name)), `${name} changed from BASE`);
  }
  const script = baseStep(base, 'lint-workflows', 'validate', 'Validate all workflows');
  const results = [base, candidate].map((root) => execute('bash', ['-c', script], base, {
    UNTRUSTED_SOURCE_DIR: root,
  }));
  const normalize = (text, root) => {
    const relativeRoot = path.relative(base, root).replace(/\\/g, '/');
    let normalized = text.replaceAll(`${root}/`, '');
    if (relativeRoot) normalized = normalized.replaceAll(`${relativeRoot}/`, '');
    return normalized;
  };
  console.log('Exact BASE actionlint invocation on BASE:\n' + results[0].stdout + results[0].stderr);
  console.log('Exact BASE actionlint invocation on CANDIDATE:\n' + results[1].stdout + results[1].stderr);
  requireValue(results[0].status === results[1].status
    && normalize(results[0].stdout + results[0].stderr, base)
      === normalize(results[1].stdout + results[1].stderr, candidate),
  'BASE and candidate actionlint diagnostics differ');
  console.log('BASE and candidate workflow bytes and actionlint diagnostics are identical; baseline failures are NOT a pass.');
  requireValue(results[1].status === 0, 'exact BASE lint remains failed on BASE and candidate');
}

export async function replay(github, context, base) {
  const metadata = await collect(github, context);
  const requireBase = createRequire(path.join(base, 'package.json'));
  const { parse } = requireBase('yaml');
  const workflow = (name) => parse(fs.readFileSync(
    path.join(base, `.github/workflows/${name}.yml`), 'utf8',
  ));
  const fresh = workflow('pr-head-freshness').jobs.freshness.steps[0].with.script;
  const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
  const output = new Map();
  const core = {
    setFailed: (message) => { throw new Error(message); },
    setOutput: (name, value) => output.set(name, value),
    notice: (message) => console.log(message),
  };
  const previous = {
    PULL_REQUEST_NUMBER: process.env.PULL_REQUEST_NUMBER,
    EVENT_HEAD_SHA: process.env.EVENT_HEAD_SHA,
  };
  process.env.PULL_REQUEST_NUMBER = String(metadata.pull.number);
  process.env.EVENT_HEAD_SHA = metadata.pull.head.sha;
  try {
    // Pass the authentic dispatch context; no fabricated PR payload/event.
    await new AsyncFunction('github', 'context', 'core', fresh)(github, context, core);
  } finally {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) delete process.env[key]; else process.env[key] = value;
    }
  }
  requireValue(output.get('current') === 'true', 'exact BASE freshness replay failed');
  const fork = workflow('fork-pr-policy').jobs['trust-gate'].steps[0].run;
  succeed('bash', ['-c', fork], base, {
    BASE_REPOSITORY: metadata.repository.full_name,
    HEAD_REPOSITORY: metadata.pull.head.repo.full_name,
  });
  console.log('Exact BASE freshness JS and fork shell replayed on authentic API metadata; not official PR context.');

  const compare = (await github.rest.repos.compareCommitsWithBasehead({
    owner: target.owner, repo: 'certigo',
    basehead: `${target.base}...${target.candidate}`, per_page: 100, page: 1,
  })).data;
  const files = await github.paginate(github.rest.pulls.listFiles, {
    owner: target.owner, repo: 'certigo', pull_number: target.pull, per_page: 100,
  });
  requireValue(compare.base_commit?.sha === target.base
    && compare.merge_base_commit?.sha === target.base && compare.status === 'ahead',
  'unexpected compare ancestry');
  requireValue(compare.total_commits === compare.commits?.length
    && compare.commits.at(-1)?.sha === target.candidate && compare.files?.length < 300,
  'incomplete compare commits or files');
  requireValue(files.length === metadata.pull.changed_files && files.length > 0
    && files.length < 300
    && JSON.stringify(compare.files.map((f) => [f.filename, f.status, f.previous_filename]).sort())
      === JSON.stringify(files.map((f) => [f.filename, f.status, f.previous_filename]).sort()),
  'API file lists incomplete or inconsistent');
  const { loadMatrix, selectGates } = await import(pathToFileURL(
    path.join(base, '.github/scripts/ci-impact.mjs'),
  ));
  const paths = files.flatMap((f) => f.previous_filename
    ? [f.filename, f.previous_filename] : [f.filename]);
  const selected = selectGates(loadMatrix(path.join(base, '.github/ci/impact-matrix.json')), paths);
  requireValue(selected.includes('codeql-javascript'), 'JavaScript CodeQL relevance missing');
  for (const gate of ['backend', 'mobile', 'cortex-parity', 'dependency-scan', 'iac-security']) {
    requireValue(!selected.includes(gate), `unexpected applicable gate ${gate}`);
  }
  console.log(JSON.stringify({
    evidence: 'Exact BASE ci-impact selector; does not exercise dorny PR event wiring',
    paths, selected, notRun: ['backend', 'mobile', 'cortex-parity', 'OSV', 'Checkov'],
  }));

  const security = workflow('security-gate');
  const selector = security.jobs.changes.steps.find((s) => s.id === 'selection').run;
  const aggregator = security.jobs['security-gate'].steps[0].run;
  const outputFile = path.join(os.tmpdir(), `bootstrap-selector-${process.pid}`);
  try {
    for (const dependencies of ['true', 'false']) {
      for (const iac of ['true', 'false']) {
        fs.writeFileSync(outputFile, '');
        succeed('bash', ['-c', selector], base, {
          EVENT_NAME: 'workflow_dispatch', DEPENDENCIES_CHANGED: dependencies,
          IAC_CHANGED: iac, GITHUB_OUTPUT: outputFile,
        });
        const actual = fs.readFileSync(outputFile, 'utf8');
        requireValue(actual.includes(`dependencies=${dependencies}`)
          && actual.includes(`iac=${iac}`), 'BASE scanner selector output differs');
        const env = {
          CHANGES_RESULT: 'success', DEPENDENCIES_APPLICABLE: dependencies,
          IAC_APPLICABLE: iac,
          OSV_RESULT: dependencies === 'true' ? 'success' : 'skipped',
          CHECKOV_RESULT: iac === 'true' ? 'success' : 'skipped',
        };
        succeed('bash', ['-c', aggregator], base, env);
        for (const key of ['OSV_RESULT', 'CHECKOV_RESULT']) {
          for (const bad of ['failure', 'cancelled', 'skipped', 'success', '']) {
            if (bad === env[key]) continue;
            requireValue(execute('bash', ['-c', aggregator], base,
              { ...env, [key]: bad }).status !== 0, 'BASE scanner aggregator accepted invalid result');
          }
        }
      }
    }
    requireValue(execute('bash', ['-c', selector], base, {
      EVENT_NAME: 'workflow_dispatch', DEPENDENCIES_CHANGED: 'invalid',
      IAC_CHANGED: 'false', GITHUB_OUTPUT: outputFile,
    }).status !== 0, 'BASE scanner selector accepted invalid value');
    console.log('Exact BASE security selector and aggregator truth tables passed (scanner execution not claimed).');
  } finally {
    fs.rmSync(outputFile, { force: true });
  }
  await collect(github, context);
}

export async function verifyUploaded(github, context, sarifId) {
  await collect(github, context);
  requireValue(typeof sarifId === 'string' && /^[a-zA-Z0-9-]+$/.test(sarifId),
    'missing SARIF upload ID');
  const repo = { owner: target.owner, repo: 'certigo' };
  const status = (await github.rest.codeScanning.getSarif({ ...repo, sarif_id: sarifId })).data;
  requireValue(status.processing_status === 'complete' && !status.errors?.length
    && status.analyses_url, 'SARIF processing incomplete or failed');
  const analyses = (await github.request('GET {url}', { url: status.analyses_url })).data;
  requireValue(Array.isArray(analyses) && analyses.length === 1,
    'missing or duplicate uploaded analysis');
  const analysis = analyses[0];
  verifyAnalysis(analysis, context.sha, context.runId);
  requireValue(analysis.sarif_url.endsWith(`/sarifs/${sarifId}`), 'SARIF ID mismatch');
  console.log(JSON.stringify({
    evidence: 'processed CodeQL upload; run/source verified separately through Actions API',
    runId: context.runId, sourceHeadSha: context.sha, sarifId, analysis,
  }));
}

export async function verifyExtracted(github, context, archive) {
  const metadata = await collect(github, context);
  const files = await github.paginate(github.rest.pulls.listFiles, {
    owner: target.owner, repo: 'certigo', pull_number: target.pull, per_page: 100,
  });
  requireValue(files.length === metadata.pull.changed_files && files.length < 300,
    'incomplete extraction coverage input');
  const changedScripts = files
    .filter((file) => file.status !== 'removed' && /\.(?:mjs|cjs|js|ts)$/.test(file.filename))
    .map((file) => file.filename);
  requireValue(changedScripts.length > 0 && fs.statSync(archive).isFile(),
    'missing source archive or changed JavaScript files');
  const entries = succeed('unzip', ['-Z1', archive], process.env.GITHUB_WORKSPACE)
    .stdout.split('\n').map((entry) => entry.replace(/\\/g, '/'));
  verifyCoverageEntries(entries, changedScripts);
  console.log(JSON.stringify({
    evidence: 'Changed JavaScript source coverage verified in this CodeQL database source archive',
    archiveSha256: hash(fs.readFileSync(archive)),
    changedScripts,
  }));
}

export function verifyCoverageEntries(entries, changedScripts) {
  requireValue(Array.isArray(entries) && entries.length > 0
    && Array.isArray(changedScripts) && changedScripts.length > 0,
  'empty extraction coverage');
  for (const script of changedScripts) {
    requireValue(entries.some((entry) => entry === script
      || entry.endsWith(`/candidate/${script}`)), `CodeQL did not extract changed script ${script}`);
  }
}
