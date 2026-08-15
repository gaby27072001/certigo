#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { validateTrustedCachePolicy } from './workflow-security-cache-policy.mjs';

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
const prLinuxRunner = 'runs-on: [self-hosted, Linux, X64, certigo-pr]';
const trustedLinuxRunner = 'runs-on: [self-hosted, Linux, X64, certigo-trusted]';
const allowedRunnerLines = new Set([
  prLinuxRunner,
  trustedLinuxRunner,
  'runs-on: [self-hosted, macOS, certigo-trusted]',
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
  'deploy-privacy-policy.yml',
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
  ['security-gate.yml', new Set(['security-gate'])],
]);
const privilegedDispatchTypes = new Map([
  ['deploy-privacy-policy.yml', 'deploy-privacy-policy'],
  ['promote-backend-staging-prod.yml', 'promote-backend-staging-prod'],
  ['release-android.yml', 'release-android'],
  ['release-ios.yml', 'release-ios-legacy'],
  ['runner-health.yml', 'runner-health'],
  ['runner-resilience-drill.yml', 'runner-resilience-drill'],
  ['sync-ios-certs.yml', 'sync-ios-certs-legacy'],
]);

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

function jobBlocks(text) {
  const jobsStart = text.indexOf('\njobs:\n');
  if (jobsStart < 0) {
    return [];
  }
  const jobsText = text.slice(jobsStart + 1);
  const matches = [...jobsText.matchAll(/^  (?<id>[A-Za-z0-9_-]+):\s*$/gm)];
  return matches.map((match, index) => ({
    id: match.groups.id,
    text: jobsText.slice(
      match.index,
      index + 1 < matches.length ? matches[index + 1].index : undefined,
    ),
  }));
}

function validateWorkflow(file) {
  const text = fs.readFileSync(file, 'utf8');
  const lines = text.split(/\r?\n/);
  const errors = [];
  const fileName = path.basename(file);
  const hasTrustedJob = text.includes('certigo-trusted');

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
    if (trimmed.startsWith('runs-on:') && !allowedRunnerLines.has(trimmed)) {
      errors.push(`${file}: runner must use a fixed Azure self-hosted label set`);
    }
  }
  if (
    lines.some(
      (line) => line.trim().startsWith('runs-on:') && line.includes('certigo-ci'),
    )
  ) {
    errors.push(`${file}: legacy mixed-trust runner label certigo-ci is forbidden`);
  }
  errors.push(...validateTrustedCachePolicy(text, file));
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
  const expectedDispatchType = privilegedDispatchTypes.get(fileName);
  if (
    expectedDispatchType
    && !text.includes(`repository_dispatch:\n    types: [${expectedDispatchType}]`)
  ) {
    errors.push(
      `${file}: privileged dispatch must use the dedicated repository_dispatch type ${expectedDispatchType}`,
    );
  }
  if (
    expectedDispatchType
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
  for (const job of jobBlocks(text)) {
    if (
      trustedOnlyWorkflowFiles.has(fileName)
      && job.text.includes('runs-on:')
      && !job.text.includes('certigo-trusted')
    ) {
      errors.push(`${file}: operational job ${job.id} must use certigo-trusted`);
    }
    if (
      trustedAggregateJobs.get(fileName)?.has(job.id)
      && !job.text.includes(trustedLinuxRunner)
    ) {
      errors.push(`${file}: aggregate job ${job.id} must use certigo-trusted`);
    }
    if (job.text.includes(prLinuxRunner)) {
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
  }
  if (text.includes('pull_request_target:')) {
    const isForkPolicy = path.basename(file) === 'fork-pr-policy.yml';
    if (isForkPolicy) {
      if (
        text.includes('actions/checkout@') ||
        text.includes('github.event.pull_request.head.sha') ||
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
  const android = fs.readFileSync(path.join(workflowsDir, 'release-android.yml'), 'utf8');
  const backend = fs.readFileSync(path.join(workflowsDir, 'cd-backend.yml'), 'utf8');
  const backendCi = fs.readFileSync(path.join(workflowsDir, 'ci-backend.yml'), 'utf8');
  const promoteBackend = fs.readFileSync(
    path.join(workflowsDir, 'promote-backend-staging-prod.yml'),
    'utf8',
  );
  const codeql = fs.readFileSync(path.join(workflowsDir, 'codeql.yml'), 'utf8');
  const codeqlEnforcer = fs.readFileSync(
    path.join(root, '.github', 'scripts', 'enforce-codeql-sarif.mjs'),
    'utf8',
  );
  const osvEnforcer = fs.readFileSync(
    path.join(root, '.github', 'scripts', 'enforce-osv-json.mjs'),
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
  const flexOneDeploy = fs.readFileSync(
    path.join(root, '.github', 'scripts', 'deploy-flex-onedeploy.sh'),
    'utf8',
  );
  const lint = fs.readFileSync(path.join(workflowsDir, 'lint-workflows.yml'), 'utf8');
  const projectState = fs.readFileSync(
    path.join(workflowsDir, 'ci-project-state.yml'),
    'utf8',
  );
  const securityGate = fs.readFileSync(path.join(workflowsDir, 'security-gate.yml'), 'utf8');
  const forkPolicy = fs.readFileSync(path.join(workflowsDir, 'fork-pr-policy.yml'), 'utf8');
  const dependencyScan = fs.readFileSync(
    path.join(workflowsDir, 'dependency-vuln-scan.yml'),
    'utf8',
  );
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
      'Une configuration API/Entra complète et valide est obligatoire avant publication',
    ],
    [
      'Play credential gate',
      'PLAY_SERVICE_ACCOUNT_JSON est obligatoire pour une publication non dry-run',
    ],
    ['production configuration gate', 'La piste production exige MOBILE_CERTIGO_ENV=prod'],
  ]);

  for (const [label, marker] of androidRequirements) {
    if (!android.includes(marker)) {
      errors.push(`release-android.yml: missing ${label}`);
    }
  }
  if (!backend.includes('dev|staging|prod')) {
    errors.push('cd-backend.yml: deployment environments are not strictly allowlisted');
  }
  if (!backend.includes('environment: ${{ needs.validate-target.outputs.target }}')) {
    errors.push('cd-backend.yml: deployment environment is not sourced from validation');
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
  if (!backendCi.includes('dotnet restore Certigo.sln --locked-mode')) {
    errors.push('ci-backend.yml: backend build must restore committed locks in locked mode');
  }
  for (const secret of [
    'AZURE_CLIENT_ID',
    'AZURE_TENANT_ID',
    'AZURE_SUBSCRIPTION_ID',
  ]) {
    if (!backend.includes(`${secret}:`)) {
      errors.push(`cd-backend.yml: missing explicit reusable secret ${secret}`);
    }
    for (const marker of [
      'AUTH_JWT_SIGNING_KEY:\n        required: false',
      'AUTH_JWT_SIGNING_KEY: ${{ secrets.AUTH_JWT_SIGNING_KEY }}',
      'az bicep build-params',
      'node .github/scripts/write-secure-bicep-parameters.mjs',
      'DEPLOYMENT_OUTPUTS_FILE',
      "trap 'rm -f -- \"$BASE_PARAMETERS_FILE\" \"$AUTH_PARAMETERS_FILE\"' EXIT",
      '--parameters "@$AUTH_PARAMETERS_FILE"',
    ]) {
      if (!backend.includes(marker)) {
        errors.push(`cd-backend.yml: missing secure JWT deployment invariant ${marker}`);
      }
    }
    if (
      backend.includes('authJwtSigningKey="$AUTH_JWT_SIGNING_KEY"') ||
      backend.includes('--parameters authJwtSigningKey') ||
      promoteBackend.includes('AUTH_JWT_SIGNING_KEY')
    ) {
      errors.push(
        'backend deployment: JWT signing key must come from the called job environment and never a command argument',
      );
    }
    for (const marker of [
      "environment !== 'dev'",
      'compiled.parameters.authJwtSigningKey',
      'mode: 0o600',
      "flag: 'wx'",
    ]) {
      if (!secureBicepWriter.includes(marker)) {
        errors.push(`write-secure-bicep-parameters.mjs: missing invariant ${marker}`);
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
    'APPROVED_REQUIRED_GROUPS',
    "contains(['Sql', 'blob', 'queue', 'table', 'vault'], @)",
    'SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}',
    'COMMIT_SHA: ${{ github.sha }}',
  ]) {
    if (!backend.includes(marker)) {
      errors.push(`cd-backend.yml: missing private OneDeploy invariant ${marker}`);
    }
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
    'retained for lifecycle cleanup',
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
    "github.event_name != 'pull_request_target' || github.event.pull_request.head.repo.full_name == github.repository",
    "ref: ${{ github.event_name == 'pull_request_target' && github.event.pull_request.head.sha || github.sha }}",
    "ref: ${{ github.event_name == 'pull_request_target' && github.event.pull_request.base.sha || github.sha }}",
    'path: .untrusted-source',
    'path: .trusted-control',
    "- '.github/scripts/**/*.js'",
    "- '.github/scripts/**/*.mjs'",
  ]) {
    if (!codeql.includes(marker)) {
      errors.push(`codeql.yml: missing Azure/same-repository invariant ${marker}`);
    }
  }
  for (const marker of [
    'CODEQL_BLOCKING_SECURITY_SEVERITY: "7.0"',
    'output: ${{ env.CODEQL_RESULTS_DIR }}',
    'upload: always',
    'security-events: write',
    'source-root: .untrusted-source',
    'config-file: ./.trusted-control/.github/codeql/codeql-config.yml',
    'checkout_path: ${{ env.UNTRUSTED_SOURCE_DIR }}',
    'name: Enforce CodeQL severity threshold',
    'node "$TRUSTED_CONTROL_DIR/.github/scripts/enforce-codeql-sarif.mjs" "$CODEQL_RESULTS_DIR"',
  ]) {
    if (!codeql.includes(marker)) {
      errors.push(`codeql.yml: missing SARIF enforcement invariant ${marker}`);
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
    if (!lint.includes(marker)) {
      errors.push(`lint-workflows.yml: missing trusted Azure PR invariant ${marker}`);
    }
  }
  if (
    !lint.includes('working-directory: .trusted-control') ||
    !lint.includes('node --test .github/scripts/*.test.mjs')
  ) {
    errors.push('lint-workflows.yml: workflow security script tests are not enforced');
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
    'token: ${{',
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
    if (!workflow.includes(prLinuxRunner)) {
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
    '--format=json',
    '--no-ignore',
    '--all-packages',
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
    '--config="$TRUSTED_CONTROL_DIR/.github/osv-scanner.toml"',
    '--output-file "$output_temp"',
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
    'OSV-Scanner JSON must contain a results array.',
    'packageResult.vulnerabilities',
    'packageResult.groups',
    'references unknown vulnerability',
    'omitted expected tracked lockfiles',
    'pubManifests',
    'allowedEmptyNugetPackages',
    'may be empty only for a validated',
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
    'allowedEmptyNugetPackages',
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
  const codemagic = fs.readFileSync(path.join(root, 'codemagic.yaml'), 'utf8');
  if (/(?:dart|flutter)\s+pub\s+get(?!\s+--enforce-lockfile)/.test(codemagic)) {
    errors.push('codemagic.yaml: Flutter dependency resolution must enforce the lockfile');
  }
  for (const marker of [
    'pull_request_target:',
    'Fork PR policy / Required gate',
    prLinuxRunner,
    'HEAD_REPOSITORY" != "$BASE_REPOSITORY',
  ]) {
    if (!forkPolicy.includes(marker)) {
      errors.push(`fork-pr-policy.yml: missing fail-closed invariant ${marker}`);
    }
  }
  if (
    forkPolicy.includes('actions/checkout@') ||
    forkPolicy.includes('github.event.pull_request.head.sha')
  ) {
    errors.push('fork-pr-policy.yml: fork gate must never checkout pull request code');
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
const errors = [
  ...(fs.existsSync(path.join(workflowsDir, 'copilot-auto-merge.yml'))
    ? ['copilot-auto-merge.yml: privileged auto-merge workflow must remain removed']
    : []),
  ...workflowFiles.flatMap(validateWorkflow),
  ...validateRepositoryInvariants(),
];

if (errors.length > 0) {
  console.error(errors.join('\n'));
  process.exitCode = 1;
} else {
  console.log('Workflow security policy passed.');
}
