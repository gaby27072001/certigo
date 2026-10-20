import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { loadDeploymentState } from './backend-deployment-state.mjs';
import { loadDartSastWorkflowForms } from './dart-sast-workflow-policy.mjs';
import { readRegularRepositoryFile } from './workflow-semantic-fingerprint.mjs';
import { writeManifestSeal, verifyManifestSeal } from '../../infra/governance/evidence-files.mjs';

function fixture(context) {
  const root = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-file-race-')));
  context.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const file = path.join(root, 'input');
  fs.writeFileSync(file, 'reviewed');
  return { root, file };
}

function symlink(context, target, link) {
  try {
    fs.symlinkSync(target, link, 'file');
    return true;
  } catch (error) {
    if (process.platform === 'win32' && error.code === 'EPERM') {
      context.skip('file symlinks require Windows developer mode');
      return false;
    }
    throw error;
  }
}

test('repository reads use a validated descriptor and always close it', (context) => {
  const { root } = fixture(context);
  const read = fs.readSync;
  const reads = context.mock.method(fs, 'readSync', (descriptor, ...args) => {
    assert.equal(typeof descriptor, 'number');
    return read(descriptor, ...args);
  });
  const closes = context.mock.method(fs, 'closeSync');
  assert.equal(readRegularRepositoryFile(root, 'input').content, 'reviewed');
  assert.equal(reads.mock.callCount(), 1);
  assert.equal(closes.mock.callCount(), 1);
  assert.deepEqual(readRegularRepositoryFile(root, 'missing'), { exists: false });
  assert.match(readRegularRepositoryFile(root, '.').error, /regular non-symlink/);
});

test('repository read rejects replacement between open and path inspection', (context) => {
  const { root, file } = fixture(context);
  const open = fs.openSync;
  context.mock.method(fs, 'openSync', (target, ...args) => {
    const descriptor = open(target, ...args);
    fs.renameSync(file, `${file}.original`);
    fs.writeFileSync(file, 'unreviewed');
    return descriptor;
  });
  const reads = context.mock.method(fs, 'readSync');
  const closes = context.mock.method(fs, 'closeSync');
  assert.match(readRegularRepositoryFile(root, 'input').error, /matching the opened descriptor/);
  assert.equal(reads.mock.callCount(), 0);
  assert.equal(closes.mock.callCount(), 1);
});

test('repository read rejects in-place modification during read', (context) => {
  const { root, file } = fixture(context);
  const read = fs.readSync;
  context.mock.method(fs, 'readSync', (descriptor, ...args) => {
    const bytes = read(descriptor, ...args);
    fs.appendFileSync(file, ' changed');
    return bytes;
  });
  assert.match(readRegularRepositoryFile(root, 'input').error, /changed while being read/);
});

test('repository read rejects a symlink substituted immediately before open', (context) => {
  const { root, file } = fixture(context);
  const outside = path.join(root, 'outside');
  fs.writeFileSync(outside, 'unreviewed');
  const probe = path.join(root, 'probe');
  if (!symlink(context, outside, probe)) return;
  fs.unlinkSync(probe);
  const open = fs.openSync;
  context.mock.method(fs, 'openSync', (target, ...args) => {
    fs.renameSync(file, `${file}.original`);
    fs.symlinkSync(outside, file, 'file');
    return open(target, ...args);
  });
  const reads = context.mock.method(fs, 'readSync');
  assert.ok(readRegularRepositoryFile(root, 'input').error);
  assert.equal(reads.mock.callCount(), 0);
});

test('repository reads bound allocation and reject oversized files before reading', (context) => {
  const { root, file } = fixture(context);
  fs.truncateSync(file, 16 * 1024 * 1024 + 1);
  const reads = context.mock.method(fs, 'readSync');
  assert.match(readRegularRepositoryFile(root, 'input').error, /exceeds the 16 MiB limit/);
  assert.equal(reads.mock.callCount(), 0);
  fs.truncateSync(file, 16 * 1024 * 1024);
  assert.equal(readRegularRepositoryFile(root, 'input').bytes.length, 16 * 1024 * 1024);
  fs.truncateSync(file, 0);
  assert.equal(readRegularRepositoryFile(root, 'input').content, '');
});

test('repository reads handle short reads and reject truncation without looping', (context) => {
  const { root, file } = fixture(context);
  const read = fs.readSync;
  context.mock.method(fs, 'readSync', (descriptor, buffer, offset, length, position) =>
    read(descriptor, buffer, offset, Math.min(length, 2), position));
  assert.equal(readRegularRepositoryFile(root, 'input').content, 'reviewed');
  context.mock.restoreAll();
  context.mock.method(fs, 'readSync', () => {
    fs.truncateSync(file, 0);
    return 0;
  });
  assert.match(readRegularRepositoryFile(root, 'input').error, /changed while being read/);
});

test('repository reads reject leaf and parent symlinks, including dangling links', (context) => {
  const { root, file } = fixture(context);
  const link = path.join(root, 'link');
  if (!symlink(context, file, link)) return;
  assert.match(readRegularRepositoryFile(root, 'link').error, /regular non-symlink/);
  fs.unlinkSync(link);
  fs.symlinkSync(path.join(root, 'missing'), link, 'file');
  assert.match(readRegularRepositoryFile(root, 'link').error, /regular non-symlink/);
  const directory = path.join(root, 'real');
  fs.mkdirSync(directory);
  fs.writeFileSync(path.join(directory, 'input'), 'outside');
  fs.symlinkSync(directory, path.join(root, 'parent'), 'junction');
  assert.match(readRegularRepositoryFile(root, 'parent/input').error, /exact repository path/);
});

test('reviewed Dart forms fail closed if a form is replaced after open', (context) => {
  const { root } = fixture(context);
  fs.rmSync(path.join(root, 'input'));
  const form = path.join(root, 'v1.yml');
  fs.writeFileSync(form, 'name: reviewed\n');
  const open = fs.openSync;
  context.mock.method(fs, 'openSync', (target, ...args) => {
    const descriptor = open(target, ...args);
    fs.renameSync(form, `${form}.original`);
    fs.writeFileSync(form, 'name: unreviewed\n');
    return descriptor;
  });
  assert.throws(() => loadDartSastWorkflowForms(root), /matching the opened descriptor/);
});

test('deployment state preserves missing and empty semantics without path prechecks', (context) => {
  const { root, file } = fixture(context);
  const closes = context.mock.method(fs, 'closeSync');
  context.mock.method(fs, 'existsSync', () => assert.fail('unexpected path existence check'));
  context.mock.method(fs, 'statSync', () => assert.fail('unexpected path stat'));
  assert.equal(loadDeploymentState(undefined, 'dev'), null);
  assert.equal(loadDeploymentState(path.join(root, 'missing'), 'dev'), null);
  fs.writeFileSync(file, '');
  assert.equal(loadDeploymentState(file, 'dev'), null);
  assert.equal(closes.mock.callCount(), 1);
  fs.writeFileSync(file, '{invalid');
  assert.throws(() => loadDeploymentState(file, 'dev'), SyntaxError);
  assert.equal(closes.mock.callCount(), 2);
  fs.writeFileSync(file, '{}');
  assert.throws(() => loadDeploymentState(file, 'dev'), /fields must be exactly/);
  assert.equal(closes.mock.callCount(), 3);
});

test('deployment state size and bytes refer to the same opened file', (context) => {
  const { file } = fixture(context);
  const stat = fs.fstatSync;
  context.mock.method(fs, 'fstatSync', (descriptor) => {
    const result = stat(descriptor);
    fs.renameSync(file, `${file}.original`);
    fs.writeFileSync(file, '');
    return result;
  });
  assert.throws(() => loadDeploymentState(file, 'dev'), SyntaxError);
});

test('manifest seal can be created and overwritten through its descriptor', (context) => {
  const { root, file } = fixture(context);
  const manifest = path.join(root, 'manifest.json');
  fs.renameSync(file, manifest);
  const seal = path.join(root, 'manifest.sha256');
  writeManifestSeal(manifest, seal);
  fs.writeFileSync(seal, 'old longer seal'.repeat(20));
  writeManifestSeal(manifest, seal);
  verifyManifestSeal(manifest, seal);
  if (process.platform !== 'win32') {
    assert.equal(fs.statSync(seal).mode & 0o777, 0o600);
  }
});

test('manifest seal rejects hard links without truncating their target', (context) => {
  const { root, file } = fixture(context);
  const manifest = path.join(root, 'manifest.json');
  fs.writeFileSync(manifest, '{}');
  const seal = path.join(root, 'manifest.sha256');
  fs.linkSync(file, seal);
  assert.throws(() => writeManifestSeal(manifest, seal), /owned regular non-symlink/);
  assert.equal(fs.readFileSync(file, 'utf8'), 'reviewed');
});

test('manifest seal refuses a symlink substituted immediately before open', (context) => {
  const { root, file } = fixture(context);
  const manifest = path.join(root, 'manifest.json');
  fs.writeFileSync(manifest, '{}');
  const seal = path.join(root, 'manifest.sha256');
  if (!symlink(context, file, seal)) return;
  fs.unlinkSync(seal);
  fs.writeFileSync(seal, 'old seal');
  const open = fs.openSync;
  context.mock.method(fs, 'openSync', (target, ...args) => {
    if (target === seal) {
      fs.unlinkSync(seal);
      fs.symlinkSync(file, seal, 'file');
    }
    return open(target, ...args);
  });
  assert.throws(() => writeManifestSeal(manifest, seal));
  assert.equal(fs.readFileSync(file, 'utf8'), 'reviewed');
});

test('manifest seal rejects foreign ownership before truncating', (context) => {
  if (typeof process.geteuid !== 'function') {
    context.skip('POSIX ownership is unavailable on Windows');
    return;
  }
  const { root, file } = fixture(context);
  const manifest = path.join(root, 'manifest.json');
  fs.writeFileSync(manifest, '{}');
  const stat = fs.fstatSync;
  context.mock.method(fs, 'fstatSync', (descriptor) => {
    const result = stat(descriptor);
    result.uid = process.geteuid() + 1;
    return result;
  });
  assert.throws(() => writeManifestSeal(manifest, file), /owned regular non-symlink/);
  assert.equal(fs.readFileSync(file, 'utf8'), 'reviewed');
});

test('manifest seal rejects a parent replaced by a symlink before open', (context) => {
  if (process.platform === 'win32') {
    context.skip('POSIX directory symlink race');
    return;
  }
  const { root } = fixture(context);
  const manifest = path.join(root, 'manifest.json');
  fs.writeFileSync(manifest, '{}');
  const directory = path.join(root, 'seals');
  const outside = path.join(root, 'outside');
  fs.mkdirSync(directory);
  fs.mkdirSync(outside);
  const seal = path.join(directory, 'manifest.sha256');
  const target = path.join(outside, 'manifest.sha256');
  fs.writeFileSync(target, 'untouched');
  const open = fs.openSync;
  context.mock.method(fs, 'openSync', (file, ...args) => {
    if (file === seal) {
      fs.renameSync(directory, `${directory}.original`);
      fs.symlinkSync(outside, directory, 'dir');
    }
    return open(file, ...args);
  });
  assert.throws(() => writeManifestSeal(manifest, seal), /symbolic link/);
  assert.equal(fs.readFileSync(target, 'utf8'), 'untouched');
});
