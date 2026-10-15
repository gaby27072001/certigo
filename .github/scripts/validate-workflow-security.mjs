#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { validateAccountDeletionCosmosLayout } from './account-deletion-cosmos-policy.mjs';
import { validateCandidateScriptTestsJob } from './candidate-script-tests-policy.mjs';
import {
  dartSastGateJobId,
  dartSastWorkflowFile,
  validateDartSastWorkflow,
} from './dart-sast-workflow-policy.mjs';
import {
  isReviewedGenerationJob,
  validateBackendDeployWorkspace,
} from './backend-deploy-workflow-policy.mjs';
import { validateOsvWorkflowPolicy } from './osv-workflow-policy.mjs';
import { validateWorkflowConcurrency } from './workflow-concurrency-policy.mjs';
import {
  listProposalFiles,
  validateCandidateWorkflowManifest,
  validatePreApprovalChanges,
  validateWorkflowRemovals,
} from './workflow-manifest-consistency.mjs';
import { validateRequiredContexts } from './required-context-policy.mjs';
import { validateRunnerLabels } from './workflow-runner-labels.mjs';
import { validatePersistentCachePolicy } from './workflow-security-cache-policy.mjs';
import { parseDocument } from 'yaml';
import { hostedLinuxRunner, isHostedLinuxCiRunner, isPrLinuxCiRunner } from './linux-ci-runner-policy.mjs';

const controlRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');

function workspaceRoot(argv) {
  if (argv.length === 0) {
    return controlRoot;
  }
  if (argv.length !== 2 || argv[0] !== '--workspace') {
    throw new Error('Usage: validate-workflow-security.mjs [--workspace <repository-root>]');
  }
  const workspace = fs.realpathSync(argv[1]);
  if (!fs.statSync(workspace).isDirectory()) {
    throw new Error(`Workflow workspace is not a directory: ${workspace}`);
  }
  return workspace;
}

const root = workspaceRoot(process.argv.slice(2));
const workflowsDir = path.join(root, '.github', 'workflows');
const shaPattern = /^[0-9a-f]{40}$/;
const versionPattern = /^v[0-9]+\.[0-9]+\.[0-9]+(?:[-.][0-9A-Za-z.-]+)?$/;
const usesPattern =
  /^\s*(?:-\s+)?uses:\s*(?<value>[^#\s]+)(?:\s+#\s*(?<version>\S+))?\s*$/;
const runPattern = /^(?<indent>\s*)(?:-\s+)?run:\s*(?<value>.*)$/;
const trustedControlReferencePattern =
  /\$(?:\{TRUSTED_CONTROL_DIR\}|TRUSTED_CONTROL_DIR)\/(?<relative>[A-Za-z0-9._/-]+)/g;
const trustedImpactTestPattern =
  /^\.github\/scripts\/[A-Za-z0-9._-]+\.test\.mjs$/;
const requiredTrustedImpactTests = new Set([
  '.github/scripts/backend-deploy-gate.test.mjs',
  '.github/scripts/ci-impact.test.mjs',
  '.github/scripts/codeql-gate-policy.test.mjs',
  '.github/scripts/workflow-concurrency-policy.test.mjs',
  '.github/scripts/workflow-security-cache-policy.test.mjs',
]);
const prLinuxRunner = 'runs-on: [self-hosted, Linux, X64, certigo-pr]';
const trustedLinuxRunner = 'runs-on: [self-hosted, Linux, X64, certigo-trusted]';
const cosmosLinuxRunner =
  'runs-on: [self-hosted, Linux, X64, certigo-cosmos-emulator]';
const allowedRunnerLines = new Set([
  prLinuxRunner,
  trustedLinuxRunner,
  cosmosLinuxRunner,
  'runs-on: [self-hosted, macOS, certigo-trusted]',
  `runs-on: ${hostedLinuxRunner}`,
]);
const forbiddenRunnerConfiguration = [
  'CI_GITHUB_HOSTED_FALLBACK',
  'BACKEND_CI_FALLBACK',
  'MAIN_CRITICAL_RUNNER_LABELS',
  'PR_RUNNER_LABELS',
];
const forbiddenAutomation = [
  'AUTOMERGE_TOKEN',
  'enablePullRequestAutoMerge',
  '/reviews',
  'gh pr merge',
];
const reusableScannerFiles = new Set([
  'dependency-vuln-scan.yml',
  'security-scan.yml',
]);
const trustedOnlyWorkflowFiles = new Set([
  'cd-backend.yml',
  'content-infra-apply.yml',
  'deploy-privacy-policy.yml',
  'governance-bootstrap-phase-a-what-if.yml',
  'governance-bootstrap-phase-b-what-if.yml',
  'publish-verified-public-pages.yml',
  'promote-backend-staging-prod.yml',
  'release-android.yml',
  'release-ios.yml',
  'runner-health.yml',
  'runner-resilience-drill.yml',
  'sync-ios-certs.yml',
]);
const trustedAggregateJobs = new Map([
  ['ci-project-state.yml', new Set(['validate'])],
  ['codeql.yml', new Set(['security-gate'])],
  [dartSastWorkflowFile, new Set([dartSastGateJobId])],
  ['security-gate.yml', new Set(['security-gate'])],
]);
const privilegedDispatchTypes = new Map([
  ['cd-backend.yml', 'promote-backend'],
  ['content-infra-apply.yml', 'content-infra-apply'],
  ['deploy-privacy-policy.yml', 'deploy-privacy-policy'],
  [
    'governance-bootstrap-phase-a-what-if.yml',
    'governance-bootstrap-phase-a-what-if',
  ],
  [
    'governance-bootstrap-phase-b-what-if.yml',
    'governance-bootstrap-phase-b-what-if',
  ],
  ['publish-verified-public-pages.yml', 'publish-verified-public-pages'],
  ['promote-backend-staging-prod.yml', 'promote-backend-staging-prod'],
  ['release-android.yml', 'release-android'],
  ['release-ios.yml', 'release-ios-legacy'],
  ['runner-health.yml', 'runner-health'],
  ['runner-resilience-drill.yml', 'runner-resilience-drill'],
  ['sync-ios-certs.yml', 'sync-ios-certs-legacy'],
]);

function sealedControlFileError(repositoryRoot, relativePath, source) {
  const normalized = path.posix.normalize(relativePath);
  if (
    normalized !== relativePath
    || normalized === '..'
    || normalized.startsWith('../')
    || path.posix.isAbsolute(normalized)
  ) {
    return `${source}: trusted-control path must stay within the repository: ${relativePath}`;
  }

  const candidate = path.resolve(repositoryRoot, ...normalized.split('/'));
  let declaredStats;
  let canonicalRoot;
  let canonicalCandidate;
  try {
    declaredStats = fs.lstatSync(candidate);
    canonicalRoot = fs.realpathSync(repositoryRoot);
    canonicalCandidate = fs.realpathSync(candidate);
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    return `${source}: trusted-control file is missing: ${relativePath} (${detail})`;
  }

  if (declaredStats.isSymbolicLink() || !declaredStats.isFile()) {
    return `${source}: trusted-control path must be a regular non-symlink file: ${relativePath}`;
  }

  const relation = path.relative(canonicalRoot, canonicalCandidate);
  if (
    relation === '..'
    || relation.startsWith(`..${path.sep}`)
    || path.isAbsolute(relation)
  ) {
    return `${source}: trusted-control file escapes the repository: ${relativePath}`;
  }
  return null;
}

function validateTrustedControlReferences(text, source) {
  const errors = [];
  const references = new Set(
    [...text.matchAll(trustedControlReferencePattern)]
      .map((match) => match.groups.relative),
  );
  for (const relativePath of references) {
    const error = sealedControlFileError(root, relativePath, source);
    if (error) {
      errors.push(error);
    }
  }
  return errors;
}

function validateTrustedImpactTestManifest() {
  const source = 'package.json#scripts.test:ci-impact';
  let manifest;
  try {
    manifest = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'));
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    return [`${source}: cannot read the trusted test manifest (${detail})`];
  }

  const command = manifest?.scripts?.['test:ci-impact'];
  if (typeof command !== 'string') {
    return [`${source}: trusted test manifest is missing`];
  }
  for (const lifecycleScript of ['pretest:ci-impact', 'posttest:ci-impact']) {
    if (Object.hasOwn(manifest.scripts, lifecycleScript)) {
      return [`${source}: lifecycle hook ${lifecycleScript} is forbidden`];
    }
  }
  const tokens = command.trim().split(/\s+/);
  const tests = tokens.slice(2);
  const errors = [];
  if (
    tokens[0] !== 'node'
    || tokens[1] !== '--test'
    || tests.length === 0
    || tests.some((test) => !trustedImpactTestPattern.test(test))
  ) {
    errors.push(
      `${source}: command must be node --test followed only by trusted .github/scripts tests`,
    );
    return errors;
  }
  if (new Set(tests).size !== tests.length) {
    errors.push(`${source}: trusted test paths must not be duplicated`);
  }
  for (const requiredTest of requiredTrustedImpactTests) {
    if (!tests.includes(requiredTest)) {
      errors.push(`${source}: missing required trusted test ${requiredTest}`);
    }
  }
  for (const test of tests) {
    const error = sealedControlFileError(root, test, source);
    if (error) {
      errors.push(error);
    }
  }
  return errors;
}

function shellExpressions(lines) {
  const findings = [];
  let index = 0;
  while (index < lines.length) {
    const match = lines[index].match(runPattern);
    if (!match) {
      index += 1;
      continue;
    }

    const baseIndent = match.groups.indent.length;
    const value = match.groups.value;
    if (value.includes('${{')) {
      findings.push(index + 1);
    }

    if (!['|', '>', '|-', '>-', '|+', '>+'].includes(value.trim())) {
      index += 1;
      continue;
    }

    index += 1;
    while (index < lines.length) {
      const line = lines[index];
      if (line.trim() === '') {
        index += 1;
        continue;
      }
      const indent = line.length - line.trimStart().length;
      if (indent <= baseIndent) {
        break;
      }
      if (line.includes('${{')) {
        findings.push(index + 1);
      }
      index += 1;
    }
  }
  return findings;
}

// Refuses to report an empty result. Every rule below that inspects a job is
// silent when this returns nothing, so a parser that loses its grip reads as a
// clean workflow rather than as an unreadable one. Measured: a CRLF file makes
// the '\njobs:\n' probe miss and the validator exits 0 with the job rules never
// applied. Raising here closes the class - CRLF, a BOM, an indented `jobs:`, an
// unexpected encoding - instead of the one cause. No workflow in this
// repository has zero jobs, and GitHub rejects one that does.
function jobBlocks(text) {
  const jobsStart = text.indexOf('\njobs:\n');
  const jobsText = jobsStart < 0 ? '' : text.slice(jobsStart + 1);
  const matches = jobsText
    ? [...jobsText.matchAll(/^ {2}(?<id>[A-Za-z0-9_-]+):\s*$/gm)]
    : [];
  if (matches.length === 0) {
    throw new Error(
      'the job parser found no jobs, so every job-level rule below would be '
      + 'skipped silently; the file is unreadable to this parser rather than '
      + 'free of jobs (CRLF line endings, a byte order mark, or an indented '
      + '`jobs:` each produce this)',
    );
  }
  return matches.map((match, index) => ({
    id: match.groups.id,
    text: jobsText.slice(
      match.index,
      index + 1 < matches.length ? matches[index + 1].index : undefined,
    ),
  }));
}

function hasPrCiRunner(text, file) {
  const document = parseDocument(text, { uniqueKeys: true });
  if (document.errors.length > 0) {
    return false;
  }
  try {
    const jobs = document.toJS({ maxAliasCount: 0 })?.jobs ?? {};
    return Object.entries(jobs).some(([id, job]) => isPrLinuxCiRunner(file, id, job?.['runs-on']));
  } catch {
    return false;
  }
}

function validateWorkflow(file) {
  const text = fs.readFileSync(file, 'utf8');
  const lines = text.split(/\r?\n/);
  const errors = [];
  const fileName = path.basename(file);
  const hasTrustedJob = text.includes('certigo-trusted');
  const hasCosmosJob = text.includes('certigo-cosmos-emulator');
  const hasPrTrigger =
    /^ {2}pull_request(?:_target)?:\s*$/m.test(text);
  const parsedDocument = parseDocument(text, { uniqueKeys: true });
  let parsedJobs = {};
  if (parsedDocument.errors.length === 0) {
    try {
      parsedJobs = parsedDocument.toJS({ maxAliasCount: 0 })?.jobs ?? {};
    } catch {
      // validateRunnerLabels reports unsafe YAML below.
    }
  }

  errors.push(...validateTrustedControlReferences(text, file));
  if (fileName === dartSastWorkflowFile) {
    errors.push(...validateDartSastWorkflow(text, file));
  }
  if (!lines.some((line) => /^permissions:\s*(?:\{\})?\s*$/.test(line))) {
    errors.push(`${file}: missing explicit top-level permissions`);
  }
  if (/^ {2}pull_request:\s*$/m.test(text)) {
    errors.push(`${file}: pull_request workflows are forbidden because fork code must not control workflow execution`);
  }
  if (/^\s*runs-on:\s*\S+-latest\s*$/m.test(text)) {
    errors.push(`${file}: GitHub-hosted *-latest runner labels are forbidden`);
  }
  for (const token of forbiddenRunnerConfiguration) {
    if (text.includes(token)) {
      errors.push(`${file}: forbidden mutable runner/fallback configuration ${token}`);
    }
  }
  for (const line of lines) {
    const trimmed = line.trim();
    if (
      trimmed.startsWith('runs-on:') && !allowedRunnerLines.has(trimmed)
      && !(trimmed === 'runs-on: ubuntu-24.04' && (
        isReviewedGenerationJob(text, file, 'build', controlRoot)
        || isReviewedGenerationJob(text, file, 'bicep-build', controlRoot)
      ))
    ) {
      errors.push(`${file}: runner must use a fixed Azure self-hosted label set`);
    }
  }
  errors.push(...validateRunnerLabels(text, file, { trustedRoot: controlRoot }));
  if (
    lines.some(
      (line) => line.trim().startsWith('runs-on:') && line.includes('certigo-ci'),
    )
  ) {
    errors.push(`${file}: legacy mixed-trust runner label certigo-ci is forbidden`);
  }
  errors.push(...validatePersistentCachePolicy(text, file));
  errors.push(...validateWorkflowConcurrency(text, file));
  if (hasTrustedJob && /^ {2}workflow_dispatch:/m.test(text)) {
    errors.push(`${file}: certigo-trusted workflows must not use workflow_dispatch`);
  }
  if (
    hasTrustedJob
    && (
      /^ {4}tags(?:-ignore)?:/m.test(text)
      || /^ {2}push:\s*\{[^\n}]*tags(?:-ignore)?\s*:/m.test(text)
    )
  ) {
    errors.push(`${file}: certigo-trusted workflows must not run from mutable tag triggers`);
  }
  if (
    hasTrustedJob
    && /^ {2}push:/m.test(text)
    && !/^ {4}branches:\s*/m.test(text)
  ) {
    errors.push(`${file}: certigo-trusted push triggers must be restricted to named branches`);
  }
  if (hasCosmosJob) {
    if (
      !/^ {2}workflow_dispatch:\s*$/m.test(text)
      || text.includes('repository_dispatch:')
      || text.includes('pull_request_target:')
      || /^ {2}pull_request:\s*$/m.test(text)
      || /^ {2}push:/m.test(text)
    ) {
      errors.push(
        `${file}: certigo-cosmos-emulator workflows must be manual and must not run for repository events`,
      );
    }
    if (
      !text.includes("github.event_name == 'workflow_dispatch'")
      || !text.includes("github.repository == 'gchambaud_microsoft/Certigo'")
      || !text.includes("github.ref == 'refs/heads/main'")
      || !text.includes('ref: refs/heads/main')
      || !text.includes("vars.CERTIGO_COSMOS_EMULATOR_ENABLED == 'true'")
    ) {
      errors.push(
        `${file}: certigo-cosmos-emulator workflows must explicitly gate manual execution and checkout merged main`,
      );
    }
  }
  const expectedDispatchType = privilegedDispatchTypes.get(fileName);
  if (
    expectedDispatchType
    && text.includes('repository_dispatch:')
    && !new RegExp(
      `repository_dispatch:\\r?\\n {4}types: \\[${expectedDispatchType}\\]`,
    ).test(text)
  ) {
    errors.push(
      `${file}: privileged dispatch must use the dedicated repository_dispatch type ${expectedDispatchType}`,
    );
  }
  if (
    expectedDispatchType
    && text.includes('repository_dispatch:')
    && (
      !text.includes('CLIENT_PAYLOAD_JSON: ${{ toJSON(github.event.client_payload) }}')
      || !text.includes("github.ref == 'refs/heads/main'")
    )
  ) {
    errors.push(
      `${file}: privileged dispatch must validate client_payload from env and enforce main`,
    );
  }
  if (
    text.includes('repository_dispatch:')
    && !/^ {4}types:\s*\[[a-z0-9-]+]\s*$/m.test(text)
  ) {
    errors.push(`${file}: repository_dispatch must use one explicit event type`);
  }
  let jobs;
  try {
    jobs = jobBlocks(text);
  } catch (error) {
    errors.push(`${file}: ${error.message}`);
    jobs = [];
  }
  for (const job of jobs) {
    if (
      trustedOnlyWorkflowFiles.has(fileName)
      && job.text.includes('runs-on:')
      && !job.text.includes('certigo-trusted')
      && !isReviewedGenerationJob(text, file, job.id, controlRoot)
    ) {
      errors.push(`${file}: operational job ${job.id} must use certigo-trusted`);
    }
    if (
      trustedAggregateJobs.get(fileName)?.has(job.id)
      && !job.text.includes(trustedLinuxRunner)
      && !isHostedLinuxCiRunner(fileName, job.id, parsedJobs[job.id]?.['runs-on'])
    ) {
      errors.push(`${file}: aggregate job ${job.id} must use certigo-trusted`);
    }
    if (isPrLinuxCiRunner(fileName, job.id, parsedJobs[job.id]?.['runs-on'])) {
      if (
        job.text.includes('secrets.')
        || /^\s+environment:\s*/m.test(job.text)
        || job.text.includes('azure/login@')
        || /key\s*vault|keyvault/i.test(job.text)
      ) {
        errors.push(
          `${file}: certigo-pr job ${job.id} must not receive secrets, environments, or cloud identity`,
        );
      }
    }
    const prHeadCheckoutIndexes = [
      "ref: ${{ github.event.pull_request.head.sha }}",
      "ref: ${{ github.event_name == 'pull_request_target' && github.event.pull_request.head.sha || github.sha }}",
    ]
      .map((marker) => job.text.indexOf(marker))
      .filter((index) => index >= 0);
    const prHeadCheckout = prHeadCheckoutIndexes.length > 0
      ? Math.min(...prHeadCheckoutIndexes)
      : -1;
    const assignedHeadRecheck = job.text.indexOf(
      'name: Recheck current PR head after assignment',
    );
    const initialHeadCheck = job.text.indexOf(
      'name: Enforce initial PR freshness validation',
    );
    if (
      hasPrTrigger
      && assignedHeadRecheck >= 0
      && (
        initialHeadCheck < 0
        || initialHeadCheck > assignedHeadRecheck
        || !job.text.includes('needs.freshness.result')
      )
    ) {
      errors.push(
        `${file}: PR job ${job.id} must fail closed when initial freshness validation fails`,
      );
    }
    if (
      prHeadCheckout >= 0
      && (
        assignedHeadRecheck < 0
        || assignedHeadRecheck > prHeadCheckout
        || !job.text.includes(
          'actions/github-script@ed597411d8f924073f98dfc5c65a23a2325f34cd # v8.0.0',
        )
        || !job.text.includes('pull-requests: read')
      )
    ) {
      errors.push(
        `${file}: PR-consuming job ${job.id} must recheck the current head after assignment`,
      );
    }
    if (
      job.text.includes('certigo-trusted')
      && (
        job.text.includes('github.event.pull_request.head.sha')
        || job.text.includes('.untrusted-source')
        || job.text.includes('.untrusted-restore')
      )
    ) {
      errors.push(`${file}: certigo-trusted job ${job.id} must not checkout or parse PR source`);
    }
    if (job.text.includes('certigo-cosmos-emulator')) {
      if (
        job.text.includes('secrets.')
        || /^\s+environment:\s*/m.test(job.text)
        || job.text.includes('azure/login@')
        || /key\s*vault|keyvault/i.test(job.text)
        || /^\s+id-token:\s*write\s*$/m.test(job.text)
      ) {
        errors.push(
          `${file}: certigo-cosmos-emulator job ${job.id} must not receive secrets, environments, or cloud identity`,
        );
      }
      if (
        job.text.includes('github.event.pull_request')
        || job.text.includes('.untrusted-source')
        || job.text.includes('.untrusted-restore')
      ) {
        errors.push(
          `${file}: certigo-cosmos-emulator job ${job.id} must consume merged main only`,
        );
      }
    }
  }
  if (text.includes('pull_request_target:')) {
    const isForkPolicy = path.basename(file) === 'fork-pr-policy.yml';
    if (isForkPolicy) {
      if (
        text.includes('actions/checkout@') ||
        !text.includes('Fork PR policy / Required gate') ||
        !text.includes('HEAD_REPOSITORY') ||
        !text.includes('HEAD_REPOSITORY" != "$BASE_REPOSITORY')
      ) {
        errors.push(`${file}: fork policy must fail closed from base code without checkout`);
      }
    } else {
      if (!text.includes('github.event.pull_request.head.repo.full_name == github.repository')) {
        errors.push(`${file}: pull_request_target jobs must be restricted to same-repository PRs`);
      }
      if (
        text.includes('actions/checkout@') &&
        !text.includes("ref: ${{ github.event_name == 'pull_request_target' && github.event.pull_request.head.sha || github.sha }}") &&
        !text.includes('ref: ${{ github.event.pull_request.head.sha }}')
      ) {
        errors.push(`${file}: trusted PR workflow must explicitly checkout the internal head SHA`);
      }
    }
  }
  if (reusableScannerFiles.has(path.basename(file))) {
    if (!text.includes('github.event.pull_request.head.sha')) {
      errors.push(`${file}: reusable scanner must check out the same-repository PR head SHA`);
    }
    if (!text.includes('persist-credentials: false')) {
      errors.push(`${file}: reusable scanner checkout must not persist GitHub credentials`);
    }
  }
  if (/^\s*secrets:\s*inherit\s*$/m.test(text)) {
    errors.push(`${file}: reusable workflows must pass only explicit secrets`);
  }
  if (/^\s*(?:actions|checks|contents|pull-requests):\s*write\s*$/m.test(text)) {
    errors.push(`${file}: privileged repository write permission is forbidden`);
  }
  if (
    /^\s*security-events:\s*write\s*$/m.test(text)
    && path.basename(file) !== 'codeql.yml'
  ) {
    errors.push(`${file}: security-events write is restricted to CodeQL uploads`);
  }
  for (const token of forbiddenAutomation) {
    if (text.includes(token)) {
      errors.push(`${file}: forbidden privileged merge automation token ${token}`);
    }
  }
  for (const lineNumber of shellExpressions(lines)) {
    errors.push(
      `${file}:${lineNumber}: GitHub expressions must pass through env before shell use`,
    );
  }
  if (/(?:dart|flutter)\s+pub\s+get(?!\s+--enforce-lockfile)/.test(text)) {
    errors.push(`${file}: Dart and Flutter dependency resolution must enforce lockfiles`);
  }

  lines.forEach((line, index) => {
    const match = line.match(usesPattern);
    if (!match) {
      return;
    }
    const value = match.groups.value;
    if (value.startsWith('./')) {
      return;
    }
    if (!value.includes('@')) {
      errors.push(`${file}:${index + 1}: action reference has no revision`);
      return;
    }
    const revision = value.slice(value.lastIndexOf('@') + 1);
    if (!shaPattern.test(revision)) {
      errors.push(`${file}:${index + 1}: action must use a full commit SHA`);
    }
    if (!match.groups.version || !versionPattern.test(match.groups.version)) {
      errors.push(`${file}:${index + 1}: pinned action needs a version comment`);
    }
  });

  return errors;
}

function validateRepositoryInvariants() {
  const errors = [];
  errors.push(...validateTrustedImpactTestManifest());
  errors.push(...validateBackendDeployWorkspace(root, controlRoot));
  const android = fs.readFileSync(path.join(workflowsDir, 'release-android.yml'), 'utf8');
  const iosRelease = fs.readFileSync(path.join(workflowsDir, 'release-ios.yml'), 'utf8');
  const codemagic = fs.readFileSync(path.join(root, 'codemagic.yaml'), 'utf8');
  const backend = fs.readFileSync(path.join(workflowsDir, 'cd-backend.yml'), 'utf8');
  const backendCi = fs.readFileSync(path.join(workflowsDir, 'ci-backend.yml'), 'utf8');
  const promoteBackendPath = path.join(
    workflowsDir,
    'promote-backend-staging-prod.yml',
  );
  const promoteBackend = fs.existsSync(promoteBackendPath)
    ? fs.readFileSync(promoteBackendPath, 'utf8')
    : '';
  const codeql = fs.readFileSync(path.join(workflowsDir, 'codeql.yml'), 'utf8');
  const codeqlEnforcer = fs.readFileSync(
    path.join(root, '.github', 'scripts', 'enforce-codeql-sarif.mjs'),
    'utf8',
  );
  const osvEnforcer = fs.readFileSync(
    path.join(root, '.github', 'scripts', 'enforce-osv-json.mjs'),
    'utf8',
  );
  const osvRunner = fs.readFileSync(
    path.join(root, '.github', 'scripts', 'run-osv-scan.mjs'),
    'utf8',
  );
  const nugetLockValidator = fs.readFileSync(
    path.join(root, 'tools', 'validate_nuget_locks.py'),
    'utf8',
  );
  const dependencyLockValidator = fs.readFileSync(
    path.join(root, 'tools', 'validate_dependency_locks.py'),
    'utf8',
  );
  const pubLockVerifier = fs.readFileSync(
    path.join(root, 'tools', 'verify_pub_locks.py'),
    'utf8',
  );
  const flutterInstaller = fs.readFileSync(
    path.join(root, '.github', 'scripts', 'install-verified-flutter.sh'),
    'utf8',
  );
  const secureBicepWriter = fs.readFileSync(
    path.join(root, '.github', 'scripts', 'write-secure-bicep-parameters.mjs'),
    'utf8',
  );
  const publicDomainContract = fs.readFileSync(
    path.join(root, '.github', 'scripts', 'public-domain-contract.mjs'),
    'utf8',
  );
  const publicPagesWorkflow = fs.readFileSync(
    path.join(workflowsDir, 'publish-verified-public-pages.yml'),
    'utf8',
  );
  const accountDeletionCosmosGate = fs.readFileSync(
    path.join(root, 'backend', 'run-account-deletion-cosmos-emulator.sh'),
    'utf8',
  );
  const releaseEnvironmentParameters = ['staging', 'prod'].map((environment) => ({
    environment,
    content: fs.readFileSync(
      path.join(root, 'infra', 'params', `${environment}.bicepparam`),
      'utf8',
    ),
  }));
  const flexOneDeploy = fs.readFileSync(
    path.join(root, '.github', 'scripts', 'deploy-flex-onedeploy.sh'),
    'utf8',
  );
  const releaseTransfer = fs.readFileSync(
    path.join(root, '.github', 'scripts', 'transfer-backend-release.sh'),
    'utf8',
  );
  const lint = fs.readFileSync(path.join(workflowsDir, 'lint-workflows.yml'), 'utf8');
  const preflight = fs.readFileSync(path.join(workflowsDir, 'ci-preflight.yml'), 'utf8');
  const pythonLauncher = fs.readFileSync(
    path.join(root, '.github', 'scripts', 'run-python.sh'),
    'utf8',
  );
  const projectState = fs.readFileSync(
    path.join(workflowsDir, 'ci-project-state.yml'),
    'utf8',
  );
  const securityGate = fs.readFileSync(path.join(workflowsDir, 'security-gate.yml'), 'utf8');
  const forkPolicy = fs.readFileSync(path.join(workflowsDir, 'fork-pr-policy.yml'), 'utf8');
  const prHeadFreshness = fs.readFileSync(
    path.join(workflowsDir, 'pr-head-freshness.yml'),
    'utf8',
  );
  const dependencyScan = fs.readFileSync(
    path.join(workflowsDir, 'dependency-vuln-scan.yml'),
    'utf8',
  );
  errors.push(...validateOsvWorkflowPolicy(dependencyScan));
  const iacScan = fs.readFileSync(path.join(workflowsDir, 'security-scan.yml'), 'utf8');
  const branchProtection = JSON.parse(
    fs.readFileSync(path.join(root, '.github', 'branch-protection-main.json'), 'utf8'),
  );
  const governance = fs.readFileSync(path.join(root, 'docs', 'GOVERNANCE.md'), 'utf8');
  const securityPolicy = fs.readFileSync(path.join(root, 'SECURITY.md'), 'utf8');
  const androidRequirements = new Map([
    ['fixed beta environment', 'environment: beta'],
    ['default-branch repository dispatch', 'types: [release-android]'],
    ['main provenance gate', "github.ref == 'refs/heads/main'"],
    ['payload schema validation', 'client_payload Android invalide'],
    ['explicit dry-run intent', 'has("dry_run") and (.dry_run | type == "boolean")'],
    ['strict track allowlist', 'internal|alpha|beta|production'],
    ['strict version validation', 'version_name doit être un SemVer strict'],
    [
      'strict build validation',
      'build_number doit être un entier entre 1 et 2100000000',
    ],
    [
      'blocking API/Entra validation',
      'validate-mobile-release-config.mjs',
    ],
    [
      'Play credential gate',
      'PLAY_SERVICE_ACCOUNT_JSON est obligatoire pour une publication non dry-run',
    ],
    ['production configuration gate', '--certigo-env "$CERTIGO_ENV"'],
    [
      'account deletion release gate',
      '--dart-define="ACCOUNT_DELETION_ENABLED=$ACCOUNT_DELETION_ENABLED"',
    ],
  ]);

  for (const [label, marker] of androidRequirements) {
    if (!android.includes(marker)) {
      errors.push(`release-android.yml: missing ${label}`);
    }
  }
  if (android.includes('${{ vars.API_BASE_URL }}')) {
    errors.push('release-android.yml: legacy API_BASE_URL repository variable is forbidden');
  }
  if (
    codemagic.split(
      '--dart-define=ACCOUNT_DELETION_ENABLED="$ACCOUNT_DELETION_ENABLED"',
    ).length !== 3
  ) {
    errors.push(
      'codemagic.yaml: production and dev IPA builds must carry the account deletion flag',
    );
  }
  const directPromotion = backend.includes('promote-backend');
  if (
    directPromotion
      ? !backend.includes('TARGET=dev')
        || !backend.includes('.environment == "dev"')
        || !backend.includes('.environment == "staging"')
        || !backend.includes('.environment == "prod"')
      : !backend.includes('dev|staging|prod')
  ) {
    errors.push('cd-backend.yml: deployment environments are not strictly allowlisted');
  }
  if (!backend.includes('environment: ${{ needs.validate-target.outputs.target }}')) {
    errors.push('cd-backend.yml: deployment environment is not sourced from validation');
  }
  const promotionControl = directPromotion ? backend : promoteBackend;
  const promotionControlFile = directPromotion
    ? 'cd-backend.yml'
    : 'promote-backend-staging-prod.yml';
  const promotionMarkers = directPromotion
    ? [
        'keys == ["environment", "operation", "source_run_id"]',
        'test("^[1-9][0-9]{0,19}$")',
        '.operation == "promotion" or .operation == "rollback"',
        'promotion:staging|promotion:prod|rollback:dev|rollback:staging|rollback:prod',
        'TARGET="$(jq -r \'.environment\'',
        'EVENT_NAME: ${{ github.event_name }}',
        'CLIENT_PAYLOAD_JSON: ${{ toJSON(github.event.client_payload) }}',
        'node .github/scripts/resolve-backend-release.mjs',
        'actions/download-artifact@',
        'node .github/scripts/backend-release-manifest.mjs verify',
      ]
    : [
        'keys == ["environment"]',
        '.environment == "staging" or .environment == "prod"',
        'target=$(jq -r \'.environment // "staging-prod"\'',
        "needs.validate-dispatch.outputs.target != 'prod'",
        "needs.validate-dispatch.outputs.target == 'prod'",
        "needs.validate-dispatch.outputs.target == 'staging-prod'",
      ];
  for (const marker of promotionMarkers) {
    if (!promotionControl.includes(marker)) {
      errors.push(`${promotionControlFile}: missing controlled promotion invariant ${marker}`);
    }
  }
  for (const marker of [
    'dotnet restore backend/src/Certigo.Api/Certigo.Api.csproj',
    '--locked-mode',
    '--no-restore',
  ]) {
    if (!backend.includes(marker)) {
      errors.push(`cd-backend.yml: missing locked dependency invariant ${marker}`);
    }
  }
  for (const marker of [
    'openssl rand -base64 64',
    'KEY_FILE=/run/secrets/cosmos.key',
    '--publish 127.0.0.1:8081:8081',
    'CERTIGO_COSMOS_TESTS=1',
    'COSMOS_EMULATOR_ENDPOINT=https://127.0.0.1:8081',
    'CosmosRepositoriesIntegrationTests.Account_deletion_removes_user_partitions_and_keeps_only_pseudonymous_tombstone',
    'docker rm --force',
    'trap cleanup EXIT',
  ]) {
    if (!accountDeletionCosmosGate.includes(marker)) {
      errors.push(
        `run-account-deletion-cosmos-emulator.sh: missing local-only invariant ${marker}`,
      );
    }
  }
  if (
    accountDeletionCosmosGate.includes('COSMOS_ENDPOINT')
    || accountDeletionCosmosGate.includes('AZURE_SUBSCRIPTION')
    || accountDeletionCosmosGate.includes('secrets.')
  ) {
    errors.push(
      'run-account-deletion-cosmos-emulator.sh: live Azure configuration is forbidden',
    );
  }
  if (!backendCi.includes('dotnet restore Certigo.sln --locked-mode')) {
    errors.push('ci-backend.yml: backend build must restore committed locks in locked mode');
  }
  for (const secret of [
    'AZURE_CLIENT_ID',
    'AZURE_TENANT_ID',
    'AZURE_SUBSCRIPTION_ID',
  ]) {
    const secretMarker = backend.includes('workflow_call:')
      ? `${secret}:`
      : `secrets.${secret}`;
    if (!backend.includes(secretMarker)) {
      errors.push(`cd-backend.yml: missing deployment secret ${secret}`);
    }
    for (const marker of [
      'ALERT_EMAIL: ${{ vars.ALERT_EMAIL }}',
      'AUTH_JWT_SIGNING_KEY: ${{ secrets.AUTH_JWT_SIGNING_KEY }}',
      'ENTRA_GRAPH_TENANT_ID: ${{ vars.ENTRA_GRAPH_TENANT_ID }}',
      'ENTRA_GRAPH_CLIENT_ID: ${{ vars.ENTRA_GRAPH_CLIENT_ID }}',
      'ENTRA_GRAPH_CLIENT_SECRET: ${{ secrets.ENTRA_GRAPH_CLIENT_SECRET }}',
      'ENTRA_GRAPH_CLIENT_SECRET_EXPIRES_ON: ${{ vars.ENTRA_GRAPH_CLIENT_SECRET_EXPIRES_ON }}',
      'ENTRA_REAUTH_AUDIENCE: ${{ vars.ENTRA_REAUTH_AUDIENCE }}',
      'PUBLIC_WEB_ORIGIN: ${{ vars.PUBLIC_WEB_ORIGIN }}',
      'PUBLIC_DOMAIN_VERIFIED: ${{ vars.PUBLIC_DOMAIN_VERIFIED }}',
      'APPLE_CIAM_DOMAIN_RECONFIGURED: ${{ vars.APPLE_CIAM_DOMAIN_RECONFIGURED }}',
      'az bicep build-params',
      'node .github/scripts/write-secure-bicep-parameters.mjs',
      'DEPLOYMENT_OUTPUTS_FILE',
      "trap 'rm -f -- \"$BASE_PARAMETERS_FILE\" \"$AUTH_PARAMETERS_FILE\"' EXIT",
      '--parameters "@$AUTH_PARAMETERS_FILE"',
    ]) {
      if (!backend.includes(marker)) {
        errors.push(`cd-backend.yml: missing secure deployment invariant ${marker}`);
      }
    }
    if (
      (!backend.includes('workflow_call:')
        && (
          backend.includes('AUTH_JWT_SIGNING_KEY:\n        required: false')
          || backend.includes('AUTH_JWT_PREVIOUS_SIGNING_KEY:\n        required: false')
        ))
      || backend.includes('authJwtSigningKey="$AUTH_JWT_SIGNING_KEY"')
      || backend.includes('--parameters authJwtSigningKey')
      || backend.includes('--parameters entraGraphClientSecret')
      || backend.includes('ENTRA_GRAPH_CLIENT_SECRET_SECRET_URI: ${{ vars.')
      || promoteBackend.includes('AUTH_JWT_SIGNING_KEY')
      || promoteBackend.includes('ENTRA_GRAPH_CLIENT_SECRET')
    ) {
      errors.push(
        'backend deployment: sensitive keys must come from the target environment and never a command argument or promotion payload',
      );
    }
    if (
      backend.includes('workflow_call:')
      && !backend.includes('ENTRA_GRAPH_CLIENT_SECRET:\n        required: true')
    ) {
      errors.push(
        'cd-backend.yml: reusable workflow must declare ENTRA_GRAPH_CLIENT_SECRET as required',
      );
    }
    for (const marker of [
      "environment !== 'dev'",
      'compiled.parameters.alertEmail',
      'compiled.parameters.authJwtSigningKey',
      'compiled.parameters.entraGraphTenantId',
      'compiled.parameters.entraGraphClientId',
      'compiled.parameters.entraGraphClientSecret',
      'compiled.parameters.entraGraphClientSecretExpiresOn',
      'compiled.parameters.entraReauthAudience',
      'compiled.parameters.publicWebOrigin',
      'compiled.parameters.publicDomainVerified',
      'compiled.parameters.appleCiamDomainReconfigured',
      'mode: 0o600',
      "flag: 'wx'",
    ]) {
      if (!secureBicepWriter.includes(marker)) {
        errors.push(`write-secure-bicep-parameters.mjs: missing invariant ${marker}`);
      }
    }
    for (const { environment, content } of releaseEnvironmentParameters) {
      if (/^\s*param\s+alertEmail\s*=/m.test(content)) {
        errors.push(
          `${environment}.bicepparam: alertEmail must come from the GitHub Environment`,
        );
      }
      if (
        /^\s*param\s+entra(GraphTenantId|GraphClientId|GraphClientSecret|ReauthAudience)\s*=/m
          .test(content)
      ) {
        errors.push(
          `${environment}.bicepparam: account deletion identity values must come from the GitHub Environment`,
        );
      }
      if (
        /^\s*param\s+(publicWebOrigin|publicDomainVerified|appleCiamDomainReconfigured)\s*=/m
          .test(content)
      ) {
        errors.push(
          `${environment}.bicepparam: public-domain values must come from the GitHub Environment`,
        );
      }
    }
  }
  for (const marker of [
    "'infrastructure'",
    'PUBLIC_WEB_ORIGIN must be a canonical HTTPS origin',
    'PUBLIC_DOMAIN_VERIFIED must be explicitly true',
    'APPLE_CIAM_DOMAIN_RECONFIGURED must be explicitly true',
    "host.endsWith('.invalid')",
    "host.endsWith('.')",
    "host.endsWith('.test')",
    "['certigo', 'app'].join('.')",
  ]) {
    if (!publicDomainContract.includes(marker)) {
      errors.push(`public-domain-contract.mjs: missing fail-closed invariant ${marker}`);
    }
  }
  for (const marker of [
    'environment: github-pages',
    'PUBLIC_WEB_ORIGIN: ${{ vars.PUBLIC_WEB_ORIGIN }}',
    'PUBLIC_DOMAIN_VERIFIED: ${{ vars.PUBLIC_DOMAIN_VERIFIED }}',
    'APPLE_CIAM_DOMAIN_RECONFIGURED: ${{ vars.APPLE_CIAM_DOMAIN_RECONFIGURED }}',
    'PAGES_ORIGIN: ${{ steps.pages.outputs.origin }}',
    'PAGES_BASE_PATH: ${{ steps.pages.outputs.base_path }}',
    'node .github/scripts/public-domain-contract.mjs legal-pages',
    'node tools/build_public_pages.mjs --output _site',
  ]) {
    if (!publicPagesWorkflow.includes(marker)) {
      errors.push(`publish-verified-public-pages.yml: missing verified-domain invariant ${marker}`);
    }
  }
  if (
    publicPagesWorkflow.indexOf('node tools/build_public_pages.mjs --output _site')
    > publicPagesWorkflow.indexOf('actions/upload-pages-artifact@')
  ) {
    errors.push(
      'publish-verified-public-pages.yml: domain validation must run before the Pages artifact upload',
    );
  }
  for (const marker of [
    'validate-public-domain:',
    'Require verified public-domain contract before Azure access',
    'Require verified public-domain contract before deploy or rollback',
    'node .github/scripts/public-domain-contract.mjs infrastructure',
  ]) {
    if (!backend.includes(marker)) {
      errors.push(`cd-backend.yml: missing public-domain deploy/rollback gate ${marker}`);
    }
  }
  if (
    backend.indexOf('validate-public-domain:')
    > backend.indexOf('resolve-release:')
  ) {
    errors.push('cd-backend.yml: public-domain preflight must precede Azure release retrieval');
  }
  for (const [file, content] of [
    ['release-android.yml', android],
    ['release-ios.yml', iosRelease],
    ['codemagic.yaml', codemagic],
  ]) {
    for (const marker of [
      'PUBLIC_WEB_ORIGIN',
      'PUBLIC_DOMAIN_VERIFIED',
      'APPLE_CIAM_DOMAIN_RECONFIGURED',
      'public-domain-contract.mjs account-deletion-url',
    ]) {
      if (!content.includes(marker)) {
        errors.push(`${file}: missing public-domain release gate ${marker}`);
      }
    }
  }
  if (backend.includes('config-zip')) {
    errors.push('cd-backend.yml: local config-zip is forbidden for private Flex storage');
  }
  for (const marker of [
    'bash .github/scripts/deploy-flex-onedeploy.sh',
    'STORAGE_BLOB_ENDPOINT',
    'DEPLOYMENT_CONTAINER',
    'FUNCTION_INTEGRATION_SUBNET_ID',
    'functionIntegrationSubnetName: ${{ steps.target.outputs.functionIntegrationSubnetName }}',
    'FUNCTION_INTEGRATION_SUBNET_NAME: ${{ needs.deploy-infra.outputs.functionIntegrationSubnetName }}',
    '/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}',
    'APPROVED_REQUIRED_GROUPS',
    "contains(['Sql', 'blob', 'queue', 'table', 'vault'], @)",
    'SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}',
    'COMMIT_SHA: ${{ needs.resolve-release.outputs.sourceCommit }}',
    'EXPECTED_PACKAGE_SHA256: ${{ needs.resolve-release.outputs.packageSha256 }}',
    'SOURCE_RUN_ID: ${{ needs.validate-target.outputs.sourceRunId }}',
    'verify-backend-deployment-state.mjs',
    '--environment staging',
    '--slot current',
    '--slot previous',
    'bash .github/scripts/transfer-backend-release.sh',
    'RELEASE_ACTION: upload',
    'RELEASE_ACTION: download',
    '--expected-run-id',
    '--expected-package-sha256',
    'CERTIGO_RELEASE_PACKAGE_SHA256=',
    '/actions/runs/$SOURCE_RUN_ID/logs',
    'ACTIONS_ID_TOKEN_REQUEST_TOKEN: ""',
    'ACTIONS_ID_TOKEN_REQUEST_URL: ""',
  ]) {
    if (!backend.includes(marker)) {
      errors.push(`cd-backend.yml: missing private OneDeploy invariant ${marker}`);
    }
  }
  if (/^\s*-\s+uses:\s+actions\/(?:upload|download)-artifact@/m.test(backend)) {
    errors.push('cd-backend.yml: retained releases must not depend on GitHub artifact quota');
  }
  for (const variable of [
    'ACTIONS_ID_TOKEN_REQUEST_TOKEN: ""',
    'ACTIONS_ID_TOKEN_REQUEST_URL: ""',
  ]) {
    if (backend.split(variable).length - 1 < 5) {
      errors.push(`cd-backend.yml: build subprocesses must clear ${variable}`);
    }
  }
  for (const marker of [
    'RELEASE_PREFIX="releases/${SOURCE_RUN_ID}"',
    '--auth-mode login',
    '--overwrite false',
    '--metadata "sha256=${digest}"',
  ]) {
    if (!releaseTransfer.includes(marker)) {
      errors.push(`transfer-backend-release.sh: missing immutable storage invariant ${marker}`);
    }
  }
  if (/generate-sas|account-key|connection-string/.test(releaseTransfer)) {
    errors.push('transfer-backend-release.sh: release storage must use OIDC only');
  }
  if (
    backend.includes(
      'functionIntegrationSubnetId: ${{ steps.deploy-bicep.outputs.functionIntegrationSubnetId }}',
    )
  ) {
    errors.push(
      'cd-backend.yml: subnet resource ids containing the masked subscription id cannot cross job boundaries',
    );
  }
  if (backend.includes("--query 'length(@)' -o tsv")) {
    errors.push(
      'cd-backend.yml: private endpoint validation must not reject unrelated approved endpoints',
    );
  }
  for (const marker of [
    'az storage blob upload',
    '--auth-mode login',
    '--overwrite false',
    'az storage blob generate-sas',
    '--as-user',
    '--permissions r',
    '--https-only',
    'mapfile -t storage_security_settings',
    'mapfile -t deployment_settings',
    'az account get-access-token',
    "https://management.azure.com/",
    '/extensions/onedeploy?api-version=2024-04-01',
    '"packageUri"',
    '"async":true',
    'Azure-AsyncOperation',
    'Location',
    '--dump-header',
    '--config "$auth_config_file"',
    'health_check \'health/live\'',
    'health_check \'health/ready\'',
    'state/backend-release.json',
    'current and previous immutable releases',
    '"$integration_subnet" != "$FUNCTION_INTEGRATION_SUBNET_ID"',
  ]) {
    if (!flexOneDeploy.includes(marker)) {
      errors.push(`deploy-flex-onedeploy.sh: missing deployment invariant ${marker}`);
    }
  }
  if (/config-zip|--account-key|--sas-token/.test(flexOneDeploy)) {
    errors.push('deploy-flex-onedeploy.sh: key-based or config-zip deployment is forbidden');
  }
  if (flexOneDeploy.includes('az storage blob delete')) {
    errors.push('deploy-flex-onedeploy.sh: OneDeploy source must be retained for lifecycle cleanup');
  }
  if (!codeql.includes('CodeQL / Security gate')) {
    errors.push('codeql.yml: stable security gate is missing');
  }
  for (const marker of [
    'pull_request_target:',
    prLinuxRunner,
    'github.event.pull_request.head.repo.full_name == github.repository',
    "ref: ${{ github.event_name == 'pull_request_target' && github.event.pull_request.head.sha || github.sha }}",
    "ref: ${{ github.event_name == 'pull_request_target' && github.event.pull_request.base.sha || github.sha }}",
    'path: .trusted-control',
    "- '.github/scripts/**/*.js'",
    "- '.github/scripts/**/*.mjs'",
  ]) {
    if (marker === prLinuxRunner ? !hasPrCiRunner(codeql, 'codeql.yml') : !codeql.includes(marker)) {
      errors.push(`codeql.yml: missing Azure/same-repository invariant ${marker}`);
    }
  }
  for (const marker of [
    'CODEQL_BLOCKING_SECURITY_SEVERITY: "7.0"',
    'output: ${{ env.CODEQL_RESULTS_DIR }}',
    'upload: always',
    'security-events: write',
    'config-file: ./.trusted-control/.github/codeql/codeql-config.yml',
    'checkout_path: ${{ env.UNTRUSTED_SOURCE_DIR }}',
    'name: Enforce CodeQL severity threshold',
    'node "$TRUSTED_CONTROL_DIR/.github/scripts/enforce-codeql-sarif.mjs" "$CODEQL_RESULTS_DIR"',
  ]) {
    if (!codeql.includes(marker)) {
      errors.push(`codeql.yml: missing SARIF enforcement invariant ${marker}`);
    }
  }
  const codeqlDocument = parseDocument(codeql).toJS();
  for (const id of ['analyze', 'analyze-main']) {
    const job = codeqlDocument.jobs?.[id];
    if (!job) continue;
    const sourceCheckout = job.steps?.find((step) => step.uses?.startsWith('actions/checkout@'));
    const init = job.steps?.find((step) => step.name === 'Initialize CodeQL');
    const source = sourceCheckout?.with?.path;
    const expectedDirectory = source === '.' ? '${{ github.workspace }}'
      : '${{ github.workspace }}/.untrusted-source';
    if (!['.', '.untrusted-source'].includes(source)
      || init?.with?.['source-root'] !== source
      || job.env?.UNTRUSTED_SOURCE_DIR !== expectedDirectory) {
      errors.push(`codeql.yml: ${id} must keep source checkout, extraction root and SARIF checkout coherent`);
    }
  }
  for (const marker of [
    'EVENT_NAME: ${{ github.event_name }}',
    'FRESHNESS_CURRENT: ${{ needs.freshness.outputs.current }}',
    'pull_request|pull_request_target)',
    'push|schedule)',
    'expected_freshness="success"',
    'expected_freshness="skipped"',
    'if [ "$FRESHNESS_RESULT" != "$expected_freshness" ]; then',
    'case "$HAS_CHANGES" in',
    'if [ "$ANALYZE_RESULT" != "$expected_analysis" ]; then',
  ]) {
    if (!codeql.includes(marker)) {
      errors.push(`codeql.yml: missing event-aware aggregate gate invariant ${marker}`);
    }
  }
  if (codeql.includes('actions/upload-artifact@')) {
    errors.push('codeql.yml: local SARIF enforcement must not depend on artifact storage');
  }
  for (const marker of [
    "securitySeverity >= threshold",
    "level === 'error'",
    'No SARIF files found',
    'SARIF run is missing tool.driver.name',
    "['none', 'note', 'warning', 'error'].includes(level)",
    'GITHUB_STEP_SUMMARY',
    'Sanitized finding records are available in this job log.',
  ]) {
    if (!codeqlEnforcer.includes(marker)) {
      errors.push(`enforce-codeql-sarif.mjs: missing fail-closed invariant ${marker}`);
    }
  }
  for (const marker of [
    'name: Validate workflow YAML',
    'pull_request_target:',
    prLinuxRunner,
    'github.event.pull_request.head.repo.full_name == github.repository',
    'ref: ${{ github.event.pull_request.head.sha }}',
    'ref: ${{ github.event.pull_request.base.sha }}',
    'path: .untrusted-source',
    'path: .trusted-control',
    'node "$TRUSTED_CONTROL_DIR/.github/scripts/validate-workflow-security.mjs"',
    '--workspace "$UNTRUSTED_SOURCE_DIR"',
  ]) {
    if (marker === prLinuxRunner ? !hasPrCiRunner(lint, 'lint-workflows.yml') : !lint.includes(marker)) {
      errors.push(`lint-workflows.yml: missing trusted Azure PR invariant ${marker}`);
    }
  }
  if (
    !lint.includes('working-directory: .trusted-control') ||
    !lint.includes('node --test .github/scripts/*.test.mjs')
  ) {
    errors.push('lint-workflows.yml: workflow security script tests are not enforced');
  }
  errors.push(...validateCandidateScriptTestsJob(lint));
  for (const marker of [
    'pull_request_target:',
    prLinuxRunner,
    'github.event.pull_request.head.repo.full_name == github.repository',
    'uses: actions/setup-python@a26af69be951a213d495a4c3e4e4022e16d87065 # v5.6.0',
    'python-version: "3.12.10"',
    'architecture: "x64"',
    'check-latest: false',
    'name: Verify trusted Python bootstrap',
    'sys.flags.safe_path',
    'path: .untrusted-source',
    'path: .trusted-control',
    'bash "$TRUSTED_CONTROL_DIR/.github/scripts/run-python.sh"',
    '"$TRUSTED_CONTROL_DIR/tools/project_state.py"',
    '--root "$UNTRUSTED_SOURCE_DIR"',
  ]) {
    if (marker === prLinuxRunner ? !hasPrCiRunner(preflight, 'ci-preflight.yml') : !preflight.includes(marker)) {
      errors.push(`ci-preflight.yml: missing trusted Python launcher invariant ${marker}`);
    }
  }
  const policyTestsStart = preflight.indexOf(
    '      - name: Run adversarial selector and security-policy tests',
  );
  const dependencyInstallStart = preflight.indexOf(
    '      - name: Install trusted validator dependencies',
  );
  const projectStateStart = preflight.indexOf(
    '      - name: Validate project-state source',
    policyTestsStart,
  );
  if (
    dependencyInstallStart < 0
    || policyTestsStart < 0
    || dependencyInstallStart > policyTestsStart
    || projectStateStart < 0
  ) {
    errors.push('ci-preflight.yml: trusted security-policy test step is missing');
  } else {
    const dependencyInstall = preflight.slice(dependencyInstallStart, policyTestsStart);
    for (const marker of [
      'working-directory: .trusted-control',
      'run: npm ci --ignore-scripts',
    ]) {
      if (!dependencyInstall.includes(marker)) {
        errors.push(`ci-preflight.yml: missing trusted dependency invariant ${marker}`);
      }
    }
    if (
      dependencyInstall.includes('UNTRUSTED_SOURCE_DIR')
      || dependencyInstall.includes('--prefix')
    ) {
      errors.push('ci-preflight.yml: trusted npm resolution must not use PR-controlled paths');
    }
    const policyTests = preflight.slice(policyTestsStart, projectStateStart);
    for (const marker of [
      'working-directory: .trusted-control',
      'npm --ignore-scripts run test:ci-impact',
      'node "$TRUSTED_CONTROL_DIR/.github/scripts/validate-workflow-security.mjs"',
    ]) {
      if (!policyTests.includes(marker)) {
        errors.push(`ci-preflight.yml: missing revision-local test invariant ${marker}`);
      }
    }
    if (
      policyTests.includes('node --test')
      || /\$(?:\{TRUSTED_CONTROL_DIR\}|TRUSTED_CONTROL_DIR)\/[A-Za-z0-9._/-]+\.test\.mjs/.test(
        policyTests,
      )
    ) {
      errors.push(
        'ci-preflight.yml: trusted tests must come from the revision-local package manifest',
      );
    }
  }
  const pythonBootstrap = preflight.indexOf('uses: actions/setup-python@');
  const firstPreflightCheckout = preflight.indexOf('uses: actions/checkout@');
  if (
    pythonBootstrap < 0
    || firstPreflightCheckout < 0
    || pythonBootstrap > firstPreflightCheckout
  ) {
    errors.push('ci-preflight.yml: trusted Python must be bootstrapped before any checkout');
  }
  const bootstrapBlock = preflight.slice(pythonBootstrap, firstPreflightCheckout);
  if (/^\s+cache:/mu.test(bootstrapBlock)) {
    errors.push('ci-preflight.yml: trusted Python bootstrap must not use a persistent cache');
  }
  if (bootstrapBlock.includes('continue-on-error:')) {
    errors.push('ci-preflight.yml: trusted Python bootstrap must fail closed');
  }
  if (
    bootstrapBlock.includes('.untrusted-source')
    || bootstrapBlock.includes('UNTRUSTED_SOURCE_DIR')
  ) {
    errors.push('ci-preflight.yml: trusted Python bootstrap must not inspect PR source');
  }
  if (/(?:^|\s)(?:python|python3|py)\s+-P\s+["']?\$TRUSTED_CONTROL_DIR/mu.test(preflight)) {
    errors.push('ci-preflight.yml: project-state must use the trusted Python launcher');
  }
  for (const marker of [
    'try_launcher python3',
    'try_launcher python',
    'try_launcher py -3',
    'Python 3.11+ with safe-path mode is required',
    'UNTRUSTED_SOURCE_DIR',
    'Refusing Python launcher from untrusted source',
    'exec "${canonical}" "${launcher_arguments[@]}" -P "${python_arguments[@]}"',
  ]) {
    if (!pythonLauncher.includes(marker)) {
      errors.push(`run-python.sh: missing fail-closed launcher invariant ${marker}`);
    }
  }
  for (const marker of [
    'validate-source:',
    'name: Validate project-state source',
    'needs: validate-source',
    'name: Generated state equals committed state',
    "ref: ${{ github.event_name == 'pull_request_target' && github.event.pull_request.head.sha || github.sha }}",
    "ref: ${{ github.event_name == 'pull_request_target' && github.event.pull_request.base.sha || github.sha }}",
    'path: .untrusted-source',
    'path: .trusted-control',
    'python -P -m unittest discover -s tools/tests',
    'name: Validate committed active-content reference and generated state',
    'python -P tools/project_state.py --root "$PROJECT_WORKSPACE" --check',
    'working-directory: .trusted-control',
    '--root "$PROJECT_WORKSPACE"',
  ]) {
    if (!projectState.includes(marker)) {
      errors.push(`ci-project-state.yml: missing local trusted-base invariant ${marker}`);
    }
  }
  const sourceJobStart = projectState.indexOf('  validate-source:');
  const gateJobStart = projectState.indexOf('  validate:\n', sourceJobStart);
  if (
    sourceJobStart < 0
    || gateJobStart < 0
    || projectState.slice(sourceJobStart, gateJobStart).includes('secrets.')
  ) {
    errors.push('ci-project-state.yml: secret-free source validation job is not isolated');
  }
  if (gateJobStart >= 0 && projectState.slice(gateJobStart).includes('actions/checkout@')) {
    errors.push('ci-project-state.yml: required gate must not perform another checkout');
  }
  for (const forbiddenMarker of [
    'secrets.',
    'repository:',
    'ssh-key:',
    'ssh-known-hosts:',
    'actions/setup-node@',
    'npm ci',
    'npm run',
    '--validate-active-content',
    'CERTIGO_CONTENT_',
    'actions/create-github-app-token',
  ]) {
    if (projectState.includes(forbiddenMarker)) {
      errors.push(`ci-project-state.yml: forbidden App/PAT fallback ${forbiddenMarker}`);
    }
  }
  for (const marker of [
    'name: Security / Required gate',
    'needs: [changes, osv, checkov]',
    'uses: ./.github/workflows/dependency-vuln-scan.yml',
    'uses: ./.github/workflows/security-scan.yml',
    "if: ${{ always() && (github.event_name != 'pull_request_target' || github.event.pull_request.head.repo.full_name == github.repository) }}",
  ]) {
    if (!securityGate.includes(marker)) {
      errors.push(`security-gate.yml: missing required invariant ${marker}`);
    }
  }
  if (securityGate.includes('\n    paths:')) {
    errors.push('security-gate.yml: required workflow triggers must not be path-scoped');
  }
  for (const forbiddenMarker of [
    'nuget-vuln-scan',
    'nuget-scanner.config',
    'NUGET_RESULT',
    'enforce_result "NuGet"',
  ]) {
    if (securityGate.includes(forbiddenMarker)) {
      errors.push(`security-gate.yml: removed NuGet scanner remains referenced: ${forbiddenMarker}`);
    }
  }
  for (const removedPath of [
    path.join(workflowsDir, 'nuget-vuln-scan.yml'),
    path.join(root, '.github', 'nuget-scanner.config'),
  ]) {
    if (fs.existsSync(removedPath)) {
      errors.push(`removed NuGet scanner surface still exists: ${path.relative(root, removedPath)}`);
    }
  }
  for (const dependencyInput of [
    "'.gitignore'",
    "'**/.gitignore'",
    "'**/Directory.Build.props'",
    "'**/Directory.Build.targets'",
    "'**/NuGet.Config'",
    "'**/.npmrc'",
    "'**/pubspec_overrides.yaml'",
    "'tools/validate_nuget_locks.py'",
    "'tools/validate_dependency_locks.py'",
    "'tools/verify_pub_locks.py'",
    "'.github/scripts/install-verified-flutter.sh'",
    "'tools/tests/test_validate_nuget_locks.py'",
    "'tools/tests/test_validate_dependency_locks.py'",
    "'tools/tests/test_verify_pub_locks.py'",
  ]) {
    if (!securityGate.includes(dependencyInput)) {
      errors.push(`security-gate.yml: dependency filter omits ${dependencyInput}`);
    }
  }
  for (const [fileName, workflow] of [
    ['dependency-vuln-scan.yml', dependencyScan],
    ['security-scan.yml', iacScan],
  ]) {
    if (!workflow.includes('workflow_call:')) {
      errors.push(`${fileName}: scanner must be callable by the stable security gate`);
    }
    if (!hasPrCiRunner(workflow, fileName)) {
      errors.push(`${fileName}: scanner must use the isolated PR runner`);
    }
    for (const marker of [
      "ref: ${{ github.event_name == 'pull_request_target' && github.event.pull_request.head.sha || github.sha }}",
      "ref: ${{ github.event_name == 'pull_request_target' && github.event.pull_request.base.sha || github.sha }}",
      'path: .untrusted-source',
      'path: .trusted-control',
    ]) {
      if (!workflow.includes(marker)) {
        errors.push(`${fileName}: missing trusted-base scanner invariant ${marker}`);
      }
    }
    if (workflow.includes('actions/upload-artifact@')) {
      errors.push(`${fileName}: scanner result must not depend on artifact storage`);
    }
    if (!workflow.includes('$GITHUB_STEP_SUMMARY')) {
      errors.push(`${fileName}: scanner must publish a non-secret step summary`);
    }
    if (workflow.includes('continue-on-error: true')) {
      errors.push(`${fileName}: scanner failures must not be converted to successful steps`);
    }
    if (
      workflow.includes('upload-sarif@') ||
      workflow.includes('security-events: write')
    ) {
      errors.push(`${fileName}: scanner must not depend on GitHub Code Scanning`);
    }
  }
  for (const marker of [
    'OSV-Scanner output is missing or malformed.',
    'node "$TRUSTED_CONTROL_DIR/.github/scripts/run-osv-scan.mjs"',
    'python -P "$TRUSTED_CONTROL_DIR/tools/validate_dependency_locks.py"',
    '--root "$UNTRUSTED_SOURCE_DIR"',
    '--write-expected-sources "$EXPECTED_LOCKS_FILE"',
    'path: .untrusted-pub-restore',
    'name: Reset isolated dependency state',
    '/usr/bin/rm -rf -- "$SCANNER_STATE_DIR" "$UNTRUSTED_PUB_DIR"',
    'name: Install digest-verified Flutter without shared caches',
    'bash "$TRUSTED_CONTROL_DIR/.github/scripts/install-verified-flutter.sh"',
    'python -P "$TRUSTED_CONTROL_DIR/tools/verify_pub_locks.py"',
    '--root "$UNTRUSTED_PUB_DIR"',
    '--contract "$EXPECTED_LOCKS_FILE"',
    '--flutter "$FLUTTER_EXECUTABLE"',
    '--pub-cache "$PUB_CACHE"',
    'FLUTTER_EXECUTABLE="$FLUTTER_INSTALL_DIR/flutter/bin/flutter"',
    'name: Verify trusted controls remain immutable',
    'git -C "$TRUSTED_CONTROL_DIR" status --porcelain --untracked-files=all',
    'node "$TRUSTED_CONTROL_DIR/.github/scripts/enforce-osv-json.mjs"',
    '"$EXPECTED_LOCKS_FILE"',
    '"$UNTRUSTED_SOURCE_DIR" 2> "$OSV_ENFORCE_LOG"',
    'path: .untrusted-source',
    'path: .trusted-control',
    "ref: ${{ github.event_name == 'pull_request_target' && github.event.pull_request.base.sha || github.sha }}",
    'finding_count',
  ]) {
    if (!dependencyScan.includes(marker)) {
      errors.push(`dependency-vuln-scan.yml: missing fail-closed output invariant ${marker}`);
    }
  }
  for (const marker of [
    "'--format=json'",
    "'--no-ignore'",
    '`--config=${path.resolve(configFile)}`',
    "'--output-file'",
    '`--lockfile=${canonicalSource}`',
    'Expected OSV source contract must contain at least one lockfile.',
    'Expected OSV source contract contains duplicate lockfiles.',
    'must reference a regular lockfile.',
    'spawnSync(scanner, args',
    'assertOsvScannedEveryLockfile',
    'OSV-Scanner did not confirm scanning lockfiles',
  ]) {
    if (!osvRunner.includes(marker)) {
      errors.push(`run-osv-scan.mjs: missing explicit lockfile invariant ${marker}`);
    }
  }
  for (const marker of [
    'OSV-Scanner JSON must contain a results array.',
    'packageResult.vulnerabilities',
    'packageResult.groups',
    'references unknown vulnerability',
    'was not present in the validated lockfile contract',
    'pubManifests',
    'package.version',
    'vulnerabilityCount',
  ]) {
    if (!osvEnforcer.includes(marker)) {
      errors.push(`enforce-osv-json.mjs: missing fail-closed invariant ${marker}`);
    }
  }
  for (const marker of [
    'core.hooksPath=/dev/null',
    'git ls-files',
    'PackageReference',
    'packages.lock.json',
    'Project Sdk must be exactly Microsoft.NET.Sdk',
    'Central/imported MSBuild dependency configuration is unsupported',
    'Import", "Choose", "Sdk',
    'expected NuGet lock schema version 1',
    'Direct packages differ from the project',
    'expected requested',
    'is absent from the target graph',
    'expected a 64-byte SHA-512 digest',
    'unreachable from Direct/Project roots',
    'conditional MSBuild elements are unsupported',
    'PackageReference contains unsupported metadata',
    'declared ProjectReference entries are absent',
  ]) {
    if (!nugetLockValidator.includes(marker)) {
      errors.push(`validate_nuget_locks.py: missing fail-closed invariant ${marker}`);
    }
  }
  for (const marker of [
    'git ls-files',
    'package-lock.json',
    'pubspec.lock',
    'packages.lock.json',
    'lockfileVersion',
    'root {field} differs',
    'core.hooksPath=/dev/null',
    'validate_nuget_locks.py',
    'pubManifests',
  ]) {
    if (!dependencyLockValidator.includes(marker)) {
      errors.push(`validate_dependency_locks.py: missing fail-closed invariant ${marker}`);
    }
  }
  for (const marker of [
    'flutter pub get --enforce-lockfile failed',
    'Pub resolution changed the committed lockfile',
    'git',
    'diff',
    '--exit-code',
    'PUB_CACHE must be outside the source checkout',
    'pubManifests must be sorted and unique',
  ]) {
    if (!pubLockVerifier.includes(marker)) {
      errors.push(`verify_pub_locks.py: missing fail-closed invariant ${marker}`);
    }
  }
  for (const marker of [
    'name: NuGet locked restore (no secrets)',
    'needs: osv-scan',
    'actions/setup-dotnet@67a3573c9a986a3f9c594539f4ab511d57bb3ce9 # v4.3.1',
    'DOTNET_INSTALL_DIR: ${{ github.workspace }}/.dotnet-locked',
    'DOTNET_EXECUTABLE: ${{ github.workspace }}/.dotnet-locked/dotnet',
    '"$DOTNET_EXECUTABLE" restore "$RESTORE_SOLUTION" --locked-mode',
    'name: Remove untrusted restore state',
    '/usr/bin/rm -rf -- "$CLEANUP_DOTNET_DIR" "$CLEANUP_SOURCE_DIR"',
  ]) {
    if (!dependencyScan.includes(marker)) {
      errors.push(`dependency-vuln-scan.yml: missing isolated restore invariant ${marker}`);
    }
  }
  if (dependencyScan.includes('secrets.')) {
    errors.push('dependency-vuln-scan.yml: dependency jobs must not receive secrets');
  }
  for (const forbiddenCacheSurface of [
    'actions/cache@',
    'subosito/flutter-action@',
    'command -v flutter',
  ]) {
    if (dependencyScan.includes(forbiddenCacheSurface)) {
      errors.push(
        `dependency-vuln-scan.yml: forbidden shared Flutter/cache surface `
        + forbiddenCacheSurface,
      );
    }
  }
  for (const marker of [
    'https://storage.googleapis.com/flutter_infra_release/releases/$archive',
    'sha256sum --check --strict',
    'shasum -a 256',
    'c853cda0312a162854c481fe6a1bc286d84fbb74bfab7037c39750061dc9b466',
    '32bca4386121042e827ff2d90edbd7c7fb47c514fc04d5a87db6e3202dafde5d',
    'eac833fe956c670d1f27946f25de8bc4fe4fb86146d5ef8d53e79a971a3ba042',
  ]) {
    if (!flutterInstaller.includes(marker)) {
      errors.push(`install-verified-flutter.sh: missing immutable SDK invariant ${marker}`);
    }
  }
  for (const mutableManifest of ['releases_linux.json', 'releases_macos.json']) {
    if (flutterInstaller.includes(mutableManifest)) {
      errors.push(
        `install-verified-flutter.sh: runtime release manifest is forbidden: `
        + mutableManifest,
      );
    }
  }
  const restoreJob = dependencyScan.indexOf('  locked-restore:');
  const untrustedRestore = dependencyScan.indexOf('path: .untrusted-restore', restoreJob);
  const lockedRestore = dependencyScan.indexOf('--locked-mode', untrustedRestore);
  const cleanupRestore = dependencyScan.indexOf(
    'name: Remove untrusted restore state',
    lockedRestore,
  );
  if (
    restoreJob < 0
    || untrustedRestore < restoreJob
    || lockedRestore < untrustedRestore
    || cleanupRestore < lockedRestore
  ) {
    errors.push('dependency-vuln-scan.yml: untrusted locked restore order is unsafe');
  }
  const staticValidation = dependencyScan.indexOf(
    'python -P "$TRUSTED_CONTROL_DIR/tools/validate_dependency_locks.py"',
  );
  const pubCheckout = dependencyScan.indexOf('path: .untrusted-pub-restore', staticValidation);
  const flutterSetup = dependencyScan.indexOf(
    'name: Install digest-verified Flutter without shared caches',
    pubCheckout,
  );
  const pubRestore = dependencyScan.indexOf(
    'python -P "$TRUSTED_CONTROL_DIR/tools/verify_pub_locks.py"',
    flutterSetup,
  );
  const pubCleanup = dependencyScan.indexOf(
    'name: Remove isolated Pub restore state',
    pubRestore,
  );
  const immutableControlCheck = dependencyScan.indexOf(
    'name: Verify trusted controls remain immutable',
    pubCleanup,
  );
  const osvScan = dependencyScan.indexOf(
    'name: Run and enforce OSV-Scanner',
    immutableControlCheck,
  );
  if (
    staticValidation < 0
    || pubCheckout < staticValidation
    || flutterSetup < pubCheckout
    || pubRestore < flutterSetup
    || pubCleanup < pubRestore
    || immutableControlCheck < pubCleanup
    || osvScan < immutableControlCheck
  ) {
    errors.push('dependency-vuln-scan.yml: Pub lock restore order is unsafe');
  }
  for (const marker of [
    'Checkov output is missing or malformed.',
    'Passed checks: [0-9]+, Failed checks: [0-9]+',
    '--directory "$UNTRUSTED_SOURCE_DIR/infra"',
    '--config-file "$TRUSTED_CONTROL_DIR/.checkov.yaml"',
    'failed_checks',
    '--output cli --output json',
    '--output-file-path "console,$CHECKOV_SCAN_LOG.json"',
    'python "$TRUSTED_CONTROL_DIR/.github/scripts/checkov_report_gate.py"',
    '"$CHECKOV_SCAN_LOG.json" "$scan_status" | tee -a "$GITHUB_STEP_SUMMARY"',
    'Checkov report is incomplete, has blocking findings, or has zero effective coverage.',
  ]) {
    if (!iacScan.includes(marker)) {
      errors.push(`security-scan.yml: missing fail-closed output invariant ${marker}`);
    }
  }
  if (
    !branchProtection.required_status_checks.contexts.includes('Security / Required gate')
  ) {
    errors.push('branch-protection-main.json: stable security gate is not required');
  }
  const stableContexts = [
    'Build & test',
    'Flutter app + UI packages',
    'Generated state equals committed state',
    'Validate workflow YAML',
    'CodeQL / Security gate',
    'Security / Required gate',
    'Fork PR policy / Required gate',
  ];
  if (
    JSON.stringify(branchProtection.required_status_checks.contexts)
    !== JSON.stringify(stableContexts)
    || !branchProtection._comment.includes('gates agreges stables')
  ) {
    errors.push(
      'branch-protection-main.json: required checks must be the seven stable aggregate gates',
    );
  }
  const contentWorkflow = fs.readFileSync(path.join(workflowsDir, 'ci-content.yml'), 'utf8');
  if (!contentWorkflow.includes('run: npm ci') || contentWorkflow.includes('npm install')) {
    errors.push('ci-content.yml: npm dependencies must be installed exclusively with npm ci');
  }
  if (/(?:dart|flutter)\s+pub\s+get(?!\s+--enforce-lockfile)/.test(codemagic)) {
    errors.push('codemagic.yaml: Flutter dependency resolution must enforce the lockfile');
  }
  for (const marker of [
    'pull_request_target:',
    'Fork PR policy / Required gate',
    prLinuxRunner,
    'HEAD_REPOSITORY" != "$BASE_REPOSITORY',
  ]) {
    if (marker === prLinuxRunner ? !hasPrCiRunner(forkPolicy, 'fork-pr-policy.yml') : !forkPolicy.includes(marker)) {
      errors.push(`fork-pr-policy.yml: missing fail-closed invariant ${marker}`);
    }
  }
  if (
    forkPolicy.includes('actions/checkout@')
  ) {
    errors.push('fork-pr-policy.yml: fork gate must never checkout pull request code');
  }
  for (const marker of [
    'workflow_call:',
    prLinuxRunner,
    'pull-requests: read',
    'actions/github-script@ed597411d8f924073f98dfc5c65a23a2325f34cd # v8.0.0',
    'const current = pull.head.sha === eventHeadSha;',
    "core.setOutput('current', current ? 'true' : 'false');",
  ]) {
    if (marker === prLinuxRunner ? !hasPrCiRunner(prHeadFreshness, 'pr-head-freshness.yml') : !prHeadFreshness.includes(marker)) {
      errors.push(`pr-head-freshness.yml: missing fail-closed freshness invariant ${marker}`);
    }
  }
  for (const forbiddenMarker of [
    'actions/checkout@',
    'secrets.',
    'environment:',
    'id-token: write',
  ]) {
    if (prHeadFreshness.includes(forbiddenMarker)) {
      errors.push(`pr-head-freshness.yml: forbidden trust surface ${forbiddenMarker}`);
    }
  }
  if (
    !branchProtection.required_status_checks.contexts.includes(
      'Fork PR policy / Required gate',
    )
  ) {
    errors.push('branch-protection-main.json: fork policy gate is not required');
  }
  for (const [fileName, document] of [
    ['docs/GOVERNANCE.md', governance],
    ['SECURITY.md', securityPolicy],
  ]) {
    for (const forbiddenMarker of [
      'Dependabot alerts',
      'Dependabot security updates',
      'suivies par Dependabot',
      '**Dependabot** (dépendances)',
    ]) {
      if (document.includes(forbiddenMarker)) {
        errors.push(`${fileName}: security must not depend on ${forbiddenMarker}`);
      }
    }
  }
  return errors;
}

const workflowFiles = fs
  .readdirSync(workflowsDir)
  .filter((file) => file.endsWith('.yml') || file.endsWith('.yaml'))
  .sort()
  .map((file) => path.join(workflowsDir, file));
// Une proposition deviendra un workflow : les règles par fichier s'y appliquent dès la PR de
// pré-approbation, pour qu'une approbation ne porte jamais sur un contenu que la fusion refuserait.
const proposalFiles = listProposalFiles(root).files
  .map((proposal) => path.join(root, ...proposal.relativePath.split('/')));
const errors = [
  ...validateAccountDeletionCosmosLayout(root),
  ...validateCandidateWorkflowManifest(root),
  ...validatePreApprovalChanges(root),
  ...validateWorkflowRemovals(root),
  ...validateRequiredContexts(root, { trustedRoot: controlRoot }),
  ...(fs.existsSync(path.join(workflowsDir, 'copilot-auto-merge.yml'))
    ? ['copilot-auto-merge.yml: privileged auto-merge workflow must remain removed']
    : []),
  ...workflowFiles.flatMap(validateWorkflow),
  ...proposalFiles.flatMap(validateWorkflow),
  ...validateRepositoryInvariants(),
];

if (errors.length > 0) {
  console.error(errors.join('\n'));
  process.exitCode = 1;
} else {
  console.log('Workflow security policy passed.');
}
