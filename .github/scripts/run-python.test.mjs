import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import {
  chmodSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const script = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  'run-python.sh',
);
const preflightWorkflow = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
  'workflows',
  'ci-preflight.yml',
);

function bashPath(file) {
  return file.replaceAll('\\', '/');
}

function bashExecutable() {
  if (process.platform === 'win32') {
    const result = spawnSync('where.exe', ['bash.exe'], { encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr);
    return result.stdout.split(/\r?\n/u).find(Boolean);
  }
  const result = spawnSync('sh', ['-c', 'command -v bash'], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.trim();
}

function writeLauncher(file, { supportsSafePath = true } = {}) {
  writeFileSync(
    file,
    `#!/usr/bin/bash
set -euo pipefail
if [[ " $* " == *" -c "* ]]; then
  exit ${supportsSafePath ? 0 : 1}
fi
printf '%s\\n' "$@" > "$CAPTURE_FILE"
`,
    'utf8',
  );
  chmodSync(file, 0o755);
}

function harness() {
  const root = mkdtempSync(path.join(tmpdir(), 'certigo-python-launcher-'));
  const runnerBin = path.join(root, 'runner-bin');
  const setupBin = path.join(root, 'setup-bin');
  const untrusted = path.join(root, 'untrusted');
  mkdirSync(runnerBin);
  mkdirSync(setupBin);
  mkdirSync(untrusted);
  return {
    root,
    pathEntries: [runnerBin],
    runnerBin,
    setupBin,
    untrusted,
    capture: path.join(root, 'arguments.txt'),
  };
}

function run(harnessState) {
  return spawnSync(
    bashExecutable(),
    [bashPath(script), 'fixture.py', '--check'],
    {
      encoding: 'utf8',
      env: {
        ...process.env,
        PATH: harnessState.pathEntries.map(bashPath).join(':'),
        CAPTURE_FILE: bashPath(harnessState.capture),
        UNTRUSTED_SOURCE_DIR: bashPath(harnessState.untrusted),
      },
    },
  );
}

test('uses setup Python 3.12 ahead of runner Python 3.10', () => {
  const state = harness();
  try {
    writeLauncher(
      path.join(state.runnerBin, 'python3'),
      { supportsSafePath: false },
    );
    writeLauncher(path.join(state.setupBin, 'python3'));
    state.pathEntries = [state.setupBin, state.runnerBin];
    const result = run(state);

    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stderr, /Using Python launcher: .*\/setup-bin\/python3/u);
    assert.deepEqual(
      readFileSync(state.capture, 'utf8').trim().split(/\r?\n/u),
      ['-P', 'fixture.py', '--check'],
    );
  } finally {
    rmSync(state.root, { recursive: true, force: true });
  }
});

test('fails closed when setup is absent and the runner only has Python 3.10', () => {
  const state = harness();
  try {
    writeLauncher(
      path.join(state.runnerBin, 'python3'),
      { supportsSafePath: false },
    );
    const result = run(state);

    assert.equal(result.status, 127);
    assert.match(result.stderr, /Python 3\.11\+ safe-path mode is unavailable/u);
    assert.match(result.stderr, /tried python3, python, and py -3/u);
  } finally {
    rmSync(state.root, { recursive: true, force: true });
  }
});

test('rejects a Python launcher resolved from the untrusted checkout', () => {
  const state = harness();
  try {
    const untrustedBin = path.join(state.untrusted, 'bin');
    mkdirSync(untrustedBin);
    writeLauncher(path.join(untrustedBin, 'python3'));
    state.pathEntries = [untrustedBin];
    const result = run(state);

    assert.equal(result.status, 126);
    assert.match(result.stderr, /Refusing Python launcher from untrusted source/u);
  } finally {
    rmSync(state.root, { recursive: true, force: true });
  }
});

test('pins a fail-closed cache-free bootstrap before either checkout', () => {
  const workflow = readFileSync(preflightWorkflow, 'utf8');
  const bootstrap = workflow.indexOf(
    'uses: actions/setup-python@a26af69be951a213d495a4c3e4e4022e16d87065 # v5.6.0',
  );
  const firstCheckout = workflow.indexOf('uses: actions/checkout@');
  const bootstrapBlock = workflow.slice(bootstrap, firstCheckout);

  assert.notEqual(bootstrap, -1);
  assert.ok(bootstrap < firstCheckout);
  assert.match(bootstrapBlock, /python-version: "3\.12\.10"/u);
  assert.match(bootstrapBlock, /architecture: "x64"/u);
  assert.match(bootstrapBlock, /check-latest: false/u);
  assert.match(bootstrapBlock, /sys\.flags\.safe_path/u);
  assert.doesNotMatch(bootstrapBlock, /^\s+cache:/mu);
  assert.doesNotMatch(bootstrapBlock, /continue-on-error:/u);
  assert.doesNotMatch(bootstrapBlock, /\.untrusted-source|UNTRUSTED_SOURCE_DIR/u);
});
