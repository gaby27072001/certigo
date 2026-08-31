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

function writeLauncher(file) {
  writeFileSync(
    file,
    `#!/usr/bin/bash
set -euo pipefail
if [[ " $* " == *" -c "* ]]; then
  exit 0
fi
printf '%s\\n' "$@" > "$CAPTURE_FILE"
`,
    'utf8',
  );
  chmodSync(file, 0o755);
}

function harness() {
  const root = mkdtempSync(path.join(tmpdir(), 'certigo-python-launcher-'));
  const bin = path.join(root, 'bin');
  const untrusted = path.join(root, 'untrusted');
  mkdirSync(bin);
  mkdirSync(untrusted);
  return {
    root,
    bin,
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
        PATH: bashPath(harnessState.bin),
        CAPTURE_FILE: bashPath(harnessState.capture),
        UNTRUSTED_SOURCE_DIR: bashPath(harnessState.untrusted),
      },
    },
  );
}

test('uses python3 explicitly when the python alias is absent', () => {
  const state = harness();
  try {
    writeLauncher(path.join(state.bin, 'python3'));
    const result = run(state);

    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stderr, /Using Python launcher: .*python3/u);
    assert.deepEqual(
      readFileSync(state.capture, 'utf8').trim().split(/\r?\n/u),
      ['-P', 'fixture.py', '--check'],
    );
  } finally {
    rmSync(state.root, { recursive: true, force: true });
  }
});

test('fails closed when no Python interpreter is available', () => {
  const state = harness();
  try {
    const result = run(state);

    assert.equal(result.status, 127);
    assert.match(result.stderr, /tried python3, python, and py -3/u);
  } finally {
    rmSync(state.root, { recursive: true, force: true });
  }
});

test('rejects a Python launcher resolved from the untrusted checkout', () => {
  const state = harness();
  try {
    state.bin = path.join(state.untrusted, 'bin');
    mkdirSync(state.bin);
    writeLauncher(path.join(state.bin, 'python3'));
    const result = run(state);

    assert.equal(result.status, 126);
    assert.match(result.stderr, /Refusing Python launcher from untrusted source/u);
  } finally {
    rmSync(state.root, { recursive: true, force: true });
  }
});
