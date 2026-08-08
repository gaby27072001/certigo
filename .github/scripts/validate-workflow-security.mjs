#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const workflowsDir = path.join(root, '.github', 'workflows');
const shaPattern = /^[0-9a-f]{40}$/;
const versionPattern = /^v[0-9]+\.[0-9]+\.[0-9]+(?:[-.][0-9A-Za-z.-]+)?$/;
const usesPattern =
  /^\s*(?:-\s+)?uses:\s*(?<value>[^#\s]+)(?:\s+#\s*(?<version>\S+))?\s*$/;
const runPattern = /^(?<indent>\s*)(?:-\s+)?run:\s*(?<value>.*)$/;
const forbiddenAutomation = [
  'AUTOMERGE_TOKEN',
  'enablePullRequestAutoMerge',
  '/reviews',
  'gh pr merge',
];

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
  if (text.includes('pull_request_target:')) {
    errors.push(`${file}: pull_request_target is forbidden`);
  }
  if (/^\s*secrets:\s*inherit\s*$/m.test(text)) {
    errors.push(`${file}: reusable workflows must pass only explicit secrets`);
  }
  if (/^\s*(?:actions|checks|contents|pull-requests):\s*write\s*$/m.test(text)) {
    errors.push(`${file}: privileged repository write permission is forbidden`);
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
  const codeql = fs.readFileSync(path.join(workflowsDir, 'codeql.yml'), 'utf8');
  const lint = fs.readFileSync(path.join(workflowsDir, 'lint-workflows.yml'), 'utf8');
  const securityGate = fs.readFileSync(path.join(workflowsDir, 'security-gate.yml'), 'utf8');
  const dependencyScan = fs.readFileSync(
    path.join(workflowsDir, 'dependency-vuln-scan.yml'),
    'utf8',
  );
  const nugetScan = fs.readFileSync(path.join(workflowsDir, 'nuget-vuln-scan.yml'), 'utf8');
  const iacScan = fs.readFileSync(path.join(workflowsDir, 'security-scan.yml'), 'utf8');
  const branchProtection = JSON.parse(
    fs.readFileSync(path.join(root, '.github', 'branch-protection-main.json'), 'utf8'),
  );
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
  }
  if (!codeql.includes('CodeQL / Security gate')) {
    errors.push('codeql.yml: stable security gate is missing');
  }
  if (
    !codeql.includes(
      "runs-on: ${{ github.event_name == 'pull_request' && 'ubuntu-latest'",
    ) ||
    !codeql.includes("&& 'never' || 'always' }}")
  ) {
    errors.push('codeql.yml: fork pull requests must analyze on GitHub-hosted runners');
  }
  if (
    codeql.includes(
      "if: ${{ github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository }}",
    )
  ) {
    errors.push('codeql.yml: required CodeQL jobs must not skip fork pull requests');
  }
  if (!lint.includes('name: Validate workflow YAML') || !lint.includes('runs-on: ubuntu-latest')) {
    errors.push('lint-workflows.yml: required lint must run on a GitHub-hosted runner');
  }
  if (lint.includes('environment:') || lint.includes('head.repo.full_name == github.repository')) {
    errors.push('lint-workflows.yml: required lint must not skip or gate fork pull requests');
  }
  for (const marker of [
    'name: Security / Required gate',
    'needs: [changes, osv, nuget, checkov]',
    'uses: ./.github/workflows/dependency-vuln-scan.yml',
    'uses: ./.github/workflows/nuget-vuln-scan.yml',
    'uses: ./.github/workflows/security-scan.yml',
    'if: ${{ always() }}',
  ]) {
    if (!securityGate.includes(marker)) {
      errors.push(`security-gate.yml: missing required invariant ${marker}`);
    }
  }
  if (securityGate.includes('\n    paths:')) {
    errors.push('security-gate.yml: required workflow triggers must not be path-scoped');
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
    ['nuget-vuln-scan.yml', nugetScan],
    ['security-scan.yml', iacScan],
  ]) {
    if (!workflow.includes('workflow_call:')) {
      errors.push(`${fileName}: scanner must be callable by the stable security gate`);
    }
    if (!workflow.includes("github.event_name == 'pull_request' && 'ubuntu-latest'")) {
      errors.push(`${fileName}: fork pull requests must use a GitHub-hosted runner`);
    }
    if (workflow.includes('environment:')) {
      errors.push(`${fileName}: fork-safe scanners must not use protected environments`);
    }
  }
  if (
    !branchProtection.required_status_checks.contexts.includes('Security / Required gate')
  ) {
    errors.push('branch-protection-main.json: stable security gate is not required');
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
