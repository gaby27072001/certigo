#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

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
const azureLinuxRunner = 'runs-on: [self-hosted, Linux, X64, certigo-ci]';
const allowedRunnerLines = new Set([
  azureLinuxRunner,
  'runs-on: [self-hosted, macOS]',
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

function validateWorkflow(file) {
  const text = fs.readFileSync(file, 'utf8');
  const lines = text.split(/\r?\n/);
  const errors = [];

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
  const secureBicepWriter = fs.readFileSync(
    path.join(root, '.github', 'scripts', 'write-secure-bicep-parameters.mjs'),
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
    [
      'main or tag provenance gate',
      "github.ref == 'refs/heads/main' || github.ref_type == 'tag'",
    ],
    ['tag ancestry validation', 'git merge-base --is-ancestor'],
    ['annotated tag validation', 'Le tag de release doit être annoté'],
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
  if (!codeql.includes('CodeQL / Security gate')) {
    errors.push('codeql.yml: stable security gate is missing');
  }
  for (const marker of [
    'pull_request_target:',
    azureLinuxRunner,
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
    azureLinuxRunner,
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
    "'**/Directory.Build.props'",
    "'**/Directory.Build.targets'",
    "'**/NuGet.Config'",
    "'**/.npmrc'",
    "'**/pubspec_overrides.yaml'",
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
    if (!workflow.includes(azureLinuxRunner)) {
      errors.push(`${fileName}: scanner must use the fixed Azure self-hosted pool`);
    }
    if (
      !workflow.includes(
        "environment: ${{ github.event_name == 'pull_request_target' && 'pr-ci' || '' }}",
      )
    ) {
      errors.push(`${fileName}: reusable scanner must require pr-ci for PR execution`);
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
    '--config="$TRUSTED_CONTROL_DIR/.github/osv-scanner.toml"',
    '--output-file "$output_temp"',
    'node "$TRUSTED_CONTROL_DIR/.github/scripts/enforce-osv-json.mjs"',
    '"$OSV_RESULTS_FILE" 2> "$OSV_ENFORCE_LOG"',
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
    'vulnerabilityCount',
  ]) {
    if (!osvEnforcer.includes(marker)) {
      errors.push(`enforce-osv-json.mjs: missing fail-closed invariant ${marker}`);
    }
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
  for (const marker of [
    'pull_request_target:',
    'Fork PR policy / Required gate',
    azureLinuxRunner,
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
