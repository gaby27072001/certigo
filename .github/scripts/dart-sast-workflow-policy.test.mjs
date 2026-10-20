import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  acceptedDartSastWorkflowForms,
  dartSastGateJobId,
  dartSastGateName,
  loadDartSastWorkflowForms,
  validateDartSastWorkflow,
} from './dart-sast-workflow-policy.mjs';

// Self-contained: the reviewed forms belong to the policy itself. These tests never read the
// workflow, a proposal or a pre-approval of main (docs/runbooks/CI_WORKFLOW_CHANGES.md,
// « Règle pour les tests de .github/scripts »).
const newest = acceptedDartSastWorkflowForms.at(-1);
const scanStep = '      - name: Scan the source tree with trusted controls\n';
const scanEnv = '    env:\n'
  + '      UNTRUSTED_SOURCE_DIR: ${{ github.workspace }}/.untrusted-source\n'
  + '      TRUSTED_CONTROL_DIR: ${{ github.workspace }}/.trusted-control\n';
const prRunner = ['self-hosted', 'Linux', 'X64', 'certigo-pr'];
const trustedRunner = ['self-hosted', 'Linux', 'X64', 'certigo-trusted'];

function mutate(from, to, text = newest.text) {
  assert.ok(text.includes(from), `${newest.name} no longer contains ${JSON.stringify(from)}`);
  assert.equal(text.indexOf(from), text.lastIndexOf(from), `ambiguous anchor ${JSON.stringify(from)}`);
  return text.replace(from, () => to);
}

function rejected(text, forms = acceptedDartSastWorkflowForms) {
  const errors = validateDartSastWorkflow(text, 'dart-sast.yml', forms);
  assert.ok(errors.length > 0, 'the mutated workflow was accepted');
  return errors.join('\n');
}

function temporaryDirectory(context) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'dart-sast-forms-'));
  context.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  return directory;
}

test('every reviewed form is accepted; comments, quoting style and key order do not matter', () => {
  assert.ok(acceptedDartSastWorkflowForms.length >= 1);
  for (const form of acceptedDartSastWorkflowForms) {
    assert.deepEqual(validateDartSastWorkflow(form.text, form.name), [], form.name);
  }
  const restyled = mutate(
    '    permissions:\n      contents: read\n      pull-requests: read\n' + scanEnv,
    "    # same meaning, other spelling\n    permissions:\n      'pull-requests': read\n      contents: \"read\"\n"
      + scanEnv,
  ).replace(/^#.*\n/gmu, '');
  assert.ok(!restyled.startsWith('#'));
  assert.deepEqual(validateDartSastWorkflow(restyled, 'dart-sast.yml'), []);
});

// Each bypass of the former substring policy found by the independent review of #560 comes
// first; every other entry changes one security-relevant field.
const changes = [
  [
    'the scan exit status is discarded',
    '            --label "base controls" \\\n            --summary "$GITHUB_STEP_SUMMARY" \\\n            --github\n',
    '            --label "base controls" \\\n            --summary "$GITHUB_STEP_SUMMARY" \\\n            --github || true\n',
  ],
  [
    'a second --root points the base script at the base tree',
    '            --label "base controls" \\\n',
    '            --label "base controls" \\\n            --root "$TRUSTED_CONTROL_DIR" \\\n',
  ],
  [
    'the two tree variables are swapped',
    scanEnv,
    scanEnv.replace('.untrusted-source', '.SWAP').replace('.trusted-control', '.untrusted-source')
      .replace('.SWAP', '.trusted-control'),
  ],
  ['the scan step gets a neutralising shell', scanStep, `${scanStep}        shell: "true {0}"\n`],
  [
    'the workflow gets a neutralising default shell',
    'permissions: {}\n\njobs:\n',
    'permissions: {}\n\ndefaults:\n  run:\n    shell: "true {0}"\n\njobs:\n',
  ],
  ['the scan job gets a neutralising default shell', scanEnv, `    defaults:\n      run:\n        shell: "true {0}"\n${scanEnv}`],
  ['the scan runs from the pull request tree', scanStep, `${scanStep}        working-directory: .untrusted-source\n`],
  [
    'a step runs pull request code before the scan',
    scanStep,
    `      - name: Prepare\n        run: bash "$UNTRUSTED_SOURCE_DIR/prepare.sh"\n${scanStep}`,
  ],
  [
    'the gate no longer fails on a failed scan',
    "expected 'success'.\"\n            exit 1\n",
    "expected 'success'.\"\n",
  ],
  ['the scan job tolerates its own failure', '    name: Dart SAST (base controls)\n', '    name: Dart SAST (base controls)\n    continue-on-error: true\n'],
  ['the scan step is skipped', scanStep, scanStep + '        if: ${{ false }}\n'],
  [
    'node preloads pull request code',
    'permissions: {}\n\njobs:\n',
    'permissions: {}\n\nenv:\n  NODE_OPTIONS: --require ./.untrusted-source/hook.cjs\n\njobs:\n',
  ],
  [
    'Python imports pull request code',
    '      SAST_STATE_DIR: ${{ github.workspace }}/.dart-sast-state\n',
    '      SAST_STATE_DIR: ${{ github.workspace }}/.dart-sast-state\n'
      + '      PYTHONPATH: ${{ github.workspace }}/.untrusted-source\n',
  ],
  [
    'the scan runs the pull request copy of the script',
    'node "$TRUSTED_CONTROL_DIR/.github/scripts/dart-sast.mjs" check',
    'node "$UNTRUSTED_SOURCE_DIR/.github/scripts/dart-sast.mjs" check',
  ],
  [
    'the scan reads pull request controls',
    '            --label "base controls" \\\n',
    '            --label "base controls" \\\n'
      + '            --baseline "$UNTRUSTED_SOURCE_DIR/.github/sast/baseline.json" \\\n',
  ],
  [
    'Semgrep comes from the pull request lock',
    '-r "$TRUSTED_CONTROL_DIR/.github/sast/semgrep-requirements.lock"',
    '-r "$UNTRUSTED_SOURCE_DIR/.github/sast/semgrep-requirements.lock"',
  ],
  [
    'hashes are no longer required',
    'from trusted controls\n        run: |\n          set -euo pipefail\n          python -m venv "$SAST_STATE_DIR/venv"\n'
      + '          "$SAST_STATE_DIR/venv/bin/python" -m pip install --isolated --no-cache-dir \\\n'
      + '            --disable-pip-version-check --require-hashes ',
    'from trusted controls\n        run: |\n          set -euo pipefail\n          python -m venv "$SAST_STATE_DIR/venv"\n'
      + '          "$SAST_STATE_DIR/venv/bin/python" -m pip install --isolated --no-cache-dir \\\n'
      + '            --disable-pip-version-check ',
  ],
  [
    'the trusted checkout follows the pull request head',
    "github.event.pull_request.base.sha || github.sha }}",
    "github.event.pull_request.head.sha || github.sha }}",
  ],
  [
    'the trusted checkout keeps credentials',
    '          path: .trusted-control\n          persist-credentials: false\n',
    '          path: .trusted-control\n          persist-credentials: true\n',
  ],
  [
    'an action moves to another revision',
    'Checkout immutable trusted controls\n        uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262',
    'Checkout immutable trusted controls\n        uses: actions/checkout@0000000000000000000000000000000000000000',
  ],
  [
    'the gate runs on the untrusted pool',
    '    runs-on: [self-hosted, Linux, X64, certigo-trusted]\n',
    '    runs-on: [self-hosted, Linux, X64, certigo-pr]\n',
  ],
  ['the gate receives a token', '    timeout-minutes: 5\n    permissions: {}\n', '    timeout-minutes: 5\n    permissions:\n      contents: read\n'],
  ['the gate stops waiting for the scan', 'needs: [freshness, scan, candidate]', 'needs: [freshness, candidate]'],
  ['the gate is renamed', `    name: ${dartSastGateName}\n`, '    name: Dart SAST\n'],
  [
    'the gate only runs after success',
    '    needs: [freshness, scan, candidate]\n    if: ${{ always() &&',
    '    needs: [freshness, scan, candidate]\n    if: ${{ success() &&',
  ],
  [
    'the workflow becomes path-scoped',
    '  pull_request_target:\n    branches: [main]\n',
    '  pull_request_target:\n    branches: [main]\n    paths: [apps/**]\n',
  ],
  ['the workflow stops running on main', '  push:\n    branches: [main]\n', ''],
  ['the workflow grants a token permission', 'permissions: {}\n\njobs:\n', 'permissions:\n  contents: read\n\njobs:\n'],
  [
    'a job is added',
    '\n  gate:\n',
    '\n  extra:\n    runs-on: [self-hosted, Linux, X64, certigo-pr]\n    permissions: {}\n'
      + '    steps:\n      - run: echo extra\n\n  gate:\n',
  ],
  ['a timeout changes', '    timeout-minutes: 5\n', '    timeout-minutes: 6\n'],
];

test('any change to a reviewed form is refused, starting with the bypasses found in review', () => {
  for (const [change, from, to] of changes) {
    assert.match(
      rejected(mutate(from, to)),
      new RegExp(`must be exactly a reviewed form of \\.github/scripts/dart-sast-workflow-forms/ \\(first difference with ${newest.name.replace('.', '\\.')} at `, 'u'),
      change,
    );
  }
});

test('YAML indirection, duplicate keys, carriage returns and extra documents are refused', () => {
  const permissions = '    permissions:\n      contents: read\n      pull-requests: read\n';
  assert.match(
    rejected(mutate(permissions + scanEnv, `    permissions: &read\n      contents: read\n      pull-requests: read\n${scanEnv}`)),
    /YAML anchors are forbidden/u,
  );
  assert.match(
    rejected(mutate(
      '    runs-on: [self-hosted, Linux, X64, certigo-trusted]\n',
      '    runs-on: [self-hosted, Linux, X64, certigo-trusted]\n    runs-on: [self-hosted, Linux, X64, certigo-pr]\n',
    )),
    /invalid YAML/u,
  );
  assert.match(
    rejected(mutate('    name: Dart SAST (base controls)\n', '    name: "Dart SAST (base controls)\\r"\n')),
    /carriage returns inside YAML strings are forbidden/u,
  );
  assert.match(rejected(`${newest.text}---\nname: other\n`), /invalid YAML/u);
  assert.match(rejected('jobs: [\n'), /invalid YAML/u);
});

test('a transition accepts the previous and the next reviewed form, and only them', (context) => {
  const directory = temporaryDirectory(context);
  const next = mutate('    timeout-minutes: 5\n', '    timeout-minutes: 6\n');
  fs.writeFileSync(path.join(directory, 'v10.yml'), next);
  fs.writeFileSync(path.join(directory, 'v9.yml'), newest.text);
  const forms = loadDartSastWorkflowForms(directory);
  assert.deepEqual(forms.map((form) => form.name), ['v9.yml', 'v10.yml']);
  assert.deepEqual(validateDartSastWorkflow(newest.text, 'dart-sast.yml', forms), []);
  assert.deepEqual(validateDartSastWorkflow(next, 'dart-sast.yml', forms), []);
  assert.match(
    rejected(mutate('    timeout-minutes: 5\n', '    timeout-minutes: 7\n'), forms),
    /first difference with v10\.yml at jobs\.gate\.timeout-minutes\)/u,
  );
  const single = new RegExp(`first difference with ${newest.name.replace('.', '\\.')} at jobs\\.scan\\.name\\)`, 'u');
  assert.match(rejected(mutate('    name: Dart SAST (base controls)\n', '    name: Dart SAST\n')), single);
  assert.match(rejected(mutate('permissions: {}\n\njobs:\n', 'permissions: {}\n\ndefaults: {}\n\njobs:\n')), /at defaults\)/u);
});

test('the reviewed forms directory fails closed', (context) => {
  const directory = temporaryDirectory(context);
  assert.throws(() => loadDartSastWorkflowForms(directory), /at least one/u);
  fs.writeFileSync(path.join(directory, 'v1.yml'), newest.text);
  assert.equal(loadDartSastWorkflowForms(directory).length, 1);
  for (const stray of ['notes.md', 'v02.yml', 'v0.yml', 'v3.yaml']) {
    fs.writeFileSync(path.join(directory, stray), newest.text);
    assert.throws(() => loadDartSastWorkflowForms(directory), /only reviewed forms named v<n>\.yml/u, stray);
    fs.rmSync(path.join(directory, stray));
  }
  fs.writeFileSync(path.join(directory, 'v2.yml'), 'jobs: &x {}\n');
  assert.throws(() => loadDartSastWorkflowForms(directory), /YAML anchors are forbidden/u);
  fs.rmSync(path.join(directory, 'v2.yml'));
  fs.mkdirSync(path.join(directory, 'v3.yml'));
  assert.throws(() => loadDartSastWorkflowForms(directory), /must be a real regular non-symlink file/u);
});

// A new form is reviewed by humans and by these invariants: they are what the exact contract
// protects, written down so that a future form cannot drop one unnoticed.
test('every reviewed form keeps the verdict on the base controls', () => {
  for (const form of acceptedDartSastWorkflowForms) {
    const workflow = JSON.parse(form.serialized);
    const label = form.name;
    assert.deepEqual(workflow.permissions, {}, label);
    assert.ok(!Object.hasOwn(workflow, 'env') && !Object.hasOwn(workflow, 'defaults'), label);
    assert.ok(Object.hasOwn(workflow.on, 'pull_request_target') && Object.hasOwn(workflow.on, 'push'), label);
    for (const trigger of Object.values(workflow.on)) {
      assert.ok(!Object.hasOwn(trigger ?? {}, 'paths') && !Object.hasOwn(trigger ?? {}, 'paths-ignore'), label);
    }
    assert.doesNotMatch(
      form.serialized,
      /secrets\.|"environment"|"continue-on-error"|"defaults"|"working-directory"|upload-artifact|upload-sarif/u,
      label,
    );
    for (const [id, job] of Object.entries(workflow.jobs)) {
      assert.ok(Object.values(job.permissions).every((value) => value === 'read'), `${label} ${id}`);
    }

    const gates = Object.entries(workflow.jobs).filter(([, job]) => job.name === dartSastGateName);
    assert.deepEqual(gates.map(([id]) => id), [dartSastGateJobId], label);
    const gate = workflow.jobs[dartSastGateJobId];
    assert.deepEqual(gate['runs-on'], trustedRunner, label);
    assert.deepEqual(gate.permissions, {}, label);
    assert.ok(gate.needs.includes('scan') && gate.needs.includes('candidate'), label);
    assert.match(gate.if, /^\$\{\{ always\(\) /u, label);
    assert.doesNotMatch(JSON.stringify(gate), /checkout|untrusted|head\.sha|secrets/iu, label);
    const enforce = gate.steps.map((step) => step.run ?? '').join('\n');
    assert.match(enforce, /^set -euo pipefail\n/u, label);
    assert.match(enforce, /if \[ "\$SCAN_RESULT" != "success" \]; then\n[^\n]*\n\s*exit 1\n/u, label);
    assert.match(enforce, /if \[ "\$CANDIDATE_RESULT" != "\$expected_candidate" \]; then\n[^\n]*\n\s*exit 1\n/u, label);

    const scan = workflow.jobs.scan;
    assert.deepEqual(scan['runs-on'], prRunner, label);
    assert.equal(scan.env.TRUSTED_CONTROL_DIR, '${{ github.workspace }}/.trusted-control', label);
    assert.equal(scan.env.UNTRUSTED_SOURCE_DIR, '${{ github.workspace }}/.untrusted-source', label);
    const steps = scan.steps;
    const verdicts = steps.flatMap((step, index) => (String(step.run ?? '').includes('dart-sast.mjs') ? [index] : []));
    assert.equal(verdicts.length, 1, label);
    const [verdict] = verdicts;
    const command = steps[verdict].run;
    assert.ok(command.startsWith('node "$TRUSTED_CONTROL_DIR/.github/scripts/dart-sast.mjs" check \\\n'), label);
    assert.equal(command.match(/--root /gu).length, 1, label);
    assert.match(command, /--root "\$UNTRUSTED_SOURCE_DIR"/u, label);
    assert.doesNotMatch(command, /[|&;`]|\$\(|--(?:rules|scope|baseline|lock|fixtures)\b/u, label);
    assert.ok(!['if', 'shell', 'env'].some((key) => Object.hasOwn(steps[verdict], key)), label);

    const trusted = steps.findIndex((step) => step.with?.path === '.trusted-control');
    assert.ok(trusted >= 0 && trusted < verdict, label);
    assert.equal(
      steps[trusted].with.ref,
      "${{ github.event_name == 'pull_request_target' && github.event.pull_request.base.sha || github.sha }}",
      label,
    );
    assert.equal(steps[trusted].with['persist-credentials'], false, label);
    const install = steps.findIndex((step) => String(step.run ?? '').includes('semgrep-requirements.lock'));
    assert.ok(install >= 0 && install < verdict, label);
    assert.match(steps[install].run, /-r "\$TRUSTED_CONTROL_DIR\/\.github\/sast\/semgrep-requirements\.lock"/u, label);
    for (const flag of ['--isolated', '--no-cache-dir', '--require-hashes', '--only-binary=:all:', '--no-deps']) {
      assert.ok(steps[install].run.includes(flag), `${label} ${flag}`);
    }
    for (const step of steps.slice(0, verdict)) {
      const read = step.with?.path === '.untrusted-source' ? { ...step, with: {} } : step;
      assert.doesNotMatch(JSON.stringify(read), /UNTRUSTED_SOURCE_DIR|\.untrusted-source/u, `${label} ${step.name}`);
    }
  }
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
