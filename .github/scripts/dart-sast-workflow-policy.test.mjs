import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  dartSastGateName,
  validateDartSastWorkflow,
} from './dart-sast-workflow-policy.mjs';

// Self-contained fixture: base tests must not depend on the workflow or pre-approvals on main
// (docs/runbooks/CI_WORKFLOW_CHANGES.md, « Règle pour les tests de .github/scripts »).
const valid = String.raw`name: dart-sast
on:
  push:
    branches: [main]
  pull_request_target:
    branches: [main]
permissions: {}
jobs:
  scan:
    name: Dart SAST (base controls)
    runs-on: [self-hosted, Linux, X64, certigo-pr]
    permissions:
      contents: read
      pull-requests: read
    steps:
      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0
        with:
          ref: ${'$'}{{ github.event_name == 'pull_request_target' && github.event.pull_request.head.sha || github.sha }}
          path: .untrusted-source
          persist-credentials: false
      - name: Checkout immutable trusted controls
        uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0
        with:
          ref: ${'$'}{{ github.event_name == 'pull_request_target' && github.event.pull_request.base.sha || github.sha }}
          path: .trusted-control
          persist-credentials: false
      - name: Install hash-locked Semgrep from trusted controls
        run: |
          python -m venv "$SAST_STATE_DIR/venv"
          "$SAST_STATE_DIR/venv/bin/python" -m pip install --isolated --no-cache-dir \
            --disable-pip-version-check --require-hashes --only-binary=:all: --no-deps \
            -r "$TRUSTED_CONTROL_DIR/.github/sast/semgrep-requirements.lock"
      - name: Scan the source tree with trusted controls
        run: |
          node "$TRUSTED_CONTROL_DIR/.github/scripts/dart-sast.mjs" check \
            --semgrep "$SAST_STATE_DIR/venv/bin/semgrep" \
            --root "$UNTRUSTED_SOURCE_DIR" \
            --state "$SAST_STATE_DIR/scan" \
            --summary "$GITHUB_STEP_SUMMARY" \
            --github
  candidate:
    name: Dart SAST (pull request controls)
    runs-on: [self-hosted, Linux, X64, certigo-pr]
    permissions:
      contents: read
      pull-requests: read
    steps:
      - run: node "$UNTRUSTED_SOURCE_DIR/.github/scripts/dart-sast.mjs" test-rules
  gate:
    name: Dart SAST / Security gate
    needs: [freshness, scan, candidate]
    if: ${'$'}{{ always() && github.event.pull_request.head.repo.full_name == github.repository }}
    runs-on: [self-hosted, Linux, X64, certigo-trusted]
    permissions: {}
    steps:
      - name: Enforce Dart SAST results
        shell: bash
        env:
          SCAN_RESULT: ${'$'}{{ needs.scan.result }}
          CANDIDATE_RESULT: ${'$'}{{ needs.candidate.result }}
        run: |
          if [ "$SCAN_RESULT" != "success" ]; then
            exit 1
          fi
          if [ "$CANDIDATE_RESULT" != "$expected_candidate" ]; then
            exit 1
          fi
`;

function mutate(from, to) {
  assert.ok(valid.includes(from), `fixture no longer contains ${JSON.stringify(from)}`);
  return valid.replace(from, to);
}

function expectError(text, pattern) {
  const errors = validateDartSastWorkflow(text, 'dart-sast.yml');
  assert.ok(errors.some((error) => pattern.test(error)), `expected ${pattern} in:\n${errors.join('\n')}`);
}

test('accepts a workflow whose verdict comes from the base controls', () => {
  assert.deepEqual(validateDartSastWorkflow(valid), []);
});

test('the scan must run the base copy of the script, never the pull request copy', () => {
  expectError(
    mutate(
      'node "$TRUSTED_CONTROL_DIR/.github/scripts/dart-sast.mjs" check',
      'node "$UNTRUSTED_SOURCE_DIR/.github/scripts/dart-sast.mjs" check',
    ),
    /job scan must run exactly one unconditional/u,
  );
});

test('the scan must not override its controls with pull request files', () => {
  for (const option of ['--baseline', '--rules', '--scope', '--lock', '--fixtures']) {
    const text = mutate(
      '--state "$SAST_STATE_DIR/scan" \\',
      `--state "$SAST_STATE_DIR/scan" ${option} "$UNTRUSTED_SOURCE_DIR/.github/sast/x" \\`,
    );
    expectError(text, /without overriding its controls/u);
    expectError(text, /only as scan data/u);
  }
});

test('the scan must not tolerate a failure or be skipped', () => {
  expectError(
    mutate('      - name: Scan the source tree with trusted controls\n', '      - name: Scan the source tree with trusted controls\n        continue-on-error: true\n'),
    /never publish artifacts or SARIF|must run exactly one unconditional/u,
  );
  expectError(
    mutate('      - name: Scan the source tree with trusted controls\n', "      - name: Scan the source tree with trusted controls\n        if: ${{ false }}\n"),
    /must run exactly one unconditional/u,
  );
});

test('Semgrep must come from the trusted lock, hash-checked and without builds', () => {
  expectError(
    mutate(
      '-r "$TRUSTED_CONTROL_DIR/.github/sast/semgrep-requirements.lock"',
      '-r "$UNTRUSTED_SOURCE_DIR/.github/sast/semgrep-requirements.lock"',
    ),
    /install Semgrep from the trusted lock/u,
  );
  for (const flag of ['--require-hashes', '--only-binary=:all:', '--no-deps', '--isolated', '--no-cache-dir']) {
    expectError(mutate(`${flag} `, ''), /install Semgrep from the trusted lock/u);
  }
});

test('both checkouts are pinned to their trees and never persist credentials', () => {
  expectError(
    mutate('          path: .trusted-control\n          persist-credentials: false', '          path: .trusted-control\n          persist-credentials: true'),
    /base SHA into \.trusted-control/u,
  );
  expectError(
    mutate('github.event.pull_request.base.sha || github.sha', 'github.event.pull_request.head.sha || github.sha'),
    /base SHA into \.trusted-control/u,
  );
  expectError(
    mutate('          path: .untrusted-source\n          persist-credentials: false', '          path: .untrusted-source\n          persist-credentials: true'),
    /pull request head into \.untrusted-source/u,
  );
});

test('the scan job keeps the untrusted pool and read-only permissions', () => {
  expectError(
    mutate(
      '    name: Dart SAST (base controls)\n    runs-on: [self-hosted, Linux, X64, certigo-pr]',
      '    name: Dart SAST (base controls)\n    runs-on: [self-hosted, Linux, X64, certigo-trusted]',
    ),
    /job scan must run on the untrusted certigo-pr pool/u,
  );
  expectError(
    mutate('    permissions:\n      contents: read\n      pull-requests: read\n    steps:\n      - uses', '    permissions:\n      contents: write\n      pull-requests: read\n    steps:\n      - uses'),
    /job scan must keep exactly read-only/u,
  );
});

test('the aggregate gate is stable, trusted, permission-free and enforcing', () => {
  expectError(mutate(`name: ${dartSastGateName}`, 'name: Dart SAST'), /must be named "Dart SAST \/ Security gate"/u);
  expectError(
    mutate('    runs-on: [self-hosted, Linux, X64, certigo-trusted]', '    runs-on: [self-hosted, Linux, X64, certigo-pr]'),
    /certigo-trusted pool, like every aggregate gate/u,
  );
  expectError(mutate('    permissions: {}\n    steps:\n      - name: Enforce', '    permissions:\n      contents: read\n    steps:\n      - name: Enforce'), /must not receive any token permission/u);
  expectError(mutate('needs: [freshness, scan, candidate]', 'needs: [freshness, candidate]'), /must need scan and candidate/u);
  expectError(mutate('if: ${{ always() && github', 'if: ${{ success() && github'), /run under always\(\)/u);
  expectError(mutate('if [ "$SCAN_RESULT" != "success" ]; then', 'if [ "$SCAN_RESULT" = "never" ]; then'), /exactly one unconditional step/u);
  expectError(mutate('          CANDIDATE_RESULT: ${{ needs.candidate.result }}\n', ''), /exactly one unconditional step/u);
  expectError(
    mutate('      - name: Enforce Dart SAST results\n', '      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0\n      - name: Enforce Dart SAST results\n'),
    /must never check out or read pull request source/u,
  );
  expectError(
    mutate('  candidate:\n    name: Dart SAST (pull request controls)', `  candidate:\n    name: ${dartSastGateName}`),
    /must be the only job named/u,
  );
});

test('the workflow always reports, publishes nothing and declares no permission', () => {
  expectError(mutate('  pull_request_target:\n    branches: [main]', '  pull_request_target:\n    branches: [main]\n    paths: [apps/**]'), /must not be path-scoped/u);
  expectError(mutate('  pull_request_target:\n    branches: [main]\n', ''), /must run for pull_request_target and push/u);
  expectError(mutate('permissions: {}\njobs:', 'permissions:\n  contents: read\njobs:'), /empty top-level permissions/u);
  expectError(`${valid}      - uses: actions/upload-artifact@0000000000000000000000000000000000000000 # v4.0.0\n`, /never publish artifacts or SARIF/u);
});

test('markers in comments or invalid YAML never satisfy the policy', () => {
  const commented = mutate(
    '          node "$TRUSTED_CONTROL_DIR/.github/scripts/dart-sast.mjs" check \\',
    '          # node "$TRUSTED_CONTROL_DIR/.github/scripts/dart-sast.mjs" check\n          node other.mjs check \\',
  );
  expectError(commented, /job scan must run exactly one unconditional/u);
  expectError('jobs: [\n', /cannot be checked on invalid YAML/u);
  expectError('jobs:\n  a: &x {}\n  b: *x\n', /cannot be checked on unsafe YAML|has no jobs|is missing/u);
});

test('the validator applies this policy to the workflow, its proposal and its aggregate gate', () => {
  // Asserted on the source, following the convention used for validate-workflow-security.mjs,
  // which runs its checks at import time and cannot be imported from a test.
  const source = fs.readFileSync(
    path.join(path.dirname(fileURLToPath(import.meta.url)), 'validate-workflow-security.mjs'),
    'utf8',
  );
  assert.ok(source.includes('function validateWorkflow(file) {'), 'positive control: validateWorkflow');
  assert.ok(
    /import \{[^}]*\bvalidateDartSastWorkflow\b[^}]*\} from '\.\/dart-sast-workflow-policy\.mjs';/u.test(source),
    'the validator must import the Dart SAST policy',
  );
  assert.ok(
    /if \(fileName === dartSastWorkflowFile\) \{\s*errors\.push\(\.\.\.validateDartSastWorkflow\(text, file\)\);/u.test(source),
    'validateWorkflow must run the Dart SAST policy on dart-sast.yml, workflow and proposal alike',
  );
  assert.ok(source.includes("[dartSastWorkflowFile, new Set([dartSastGateJobId])],"));
  assert.ok(source.includes('...proposalFiles.flatMap(validateWorkflow),'), 'proposals go through validateWorkflow');
});
