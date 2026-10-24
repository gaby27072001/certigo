import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { readRegularRepositoryFile } from './workflow-semantic-fingerprint.mjs';

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
  assert.match(readRegularRepositoryFile(root, '.').error, /regular non-symlink/u);
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
  assert.match(
    readRegularRepositoryFile(root, 'input').error,
    /matching the opened descriptor/u,
  );
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
  assert.match(
    readRegularRepositoryFile(root, 'input').error,
    /changed while being read/u,
  );
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
  assert.match(
    readRegularRepositoryFile(root, 'input').error,
    /exceeds the 16 MiB limit/u,
  );
  assert.equal(reads.mock.callCount(), 0);
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
  assert.match(
    readRegularRepositoryFile(root, 'input').error,
    /changed while being read/u,
  );
});

test('repository reads reject leaf and parent symlinks, including dangling links', (context) => {
  const { root, file } = fixture(context);
  const link = path.join(root, 'link');
  if (!symlink(context, file, link)) return;
  assert.match(readRegularRepositoryFile(root, 'link').error, /regular non-symlink/u);
  fs.unlinkSync(link);
  fs.symlinkSync(path.join(root, 'missing'), link, 'file');
  assert.match(readRegularRepositoryFile(root, 'link').error, /regular non-symlink/u);
  const directory = path.join(root, 'real');
  fs.mkdirSync(directory);
  fs.writeFileSync(path.join(directory, 'input'), 'outside');
  fs.symlinkSync(directory, path.join(root, 'parent'), 'junction');
  assert.match(
    readRegularRepositoryFile(root, 'parent/input').error,
    /exact repository path/u,
  );
});
