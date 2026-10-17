import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { loadDartSastWorkflowForms } from './dart-sast-workflow-policy.mjs';
import {
  readRegularRepositoryFile,
  readVerifiedRegularFileSync,
} from './workflow-semantic-fingerprint.mjs';

function fixture(context) {
  const root = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'verified-read-')));
  context.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const file = path.join(root, 'v1.yml');
  fs.writeFileSync(file, 'name: trusted\n');
  return { root, file };
}

test('verified reads preserve bytes, missing paths, form ordering and parser refusal', (context) => {
  const { root, file } = fixture(context);
  const read = readRegularRepositoryFile(root, 'v1.yml');
  assert.deepEqual(read.bytes, Buffer.from('name: trusted\n'));
  assert.equal(read.content, 'name: trusted\n');
  assert.deepEqual(readRegularRepositoryFile(root, 'absent'), { exists: false });
  assert.deepEqual(readRegularRepositoryFile(root, 'v1.yml/absent'), { exists: false });
  assert.match(readRegularRepositoryFile(root, '.').error, /regular non-symlink/);
  fs.writeFileSync(path.join(root, 'v10.yml'), 'name: ten\n');
  fs.writeFileSync(path.join(root, 'v2.yml'), 'name: two\n');
  assert.deepEqual(loadDartSastWorkflowForms(root).map(({ name }) => name),
    ['v1.yml', 'v2.yml', 'v10.yml']);
  fs.writeFileSync(file, 'name: one\nname: duplicate\n');
  assert.throws(() => loadDartSastWorkflowForms(root), /duplicate/i);
});

for (const caller of ['repository', 'forms']) {
  test(`${caller} refuses a different inode before any replacement bytes are read`, (context) => {
    const { root, file } = fixture(context);
    const originalOpen = fs.openSync;
    const originalRead = fs.readFileSync;
    let replacementRead = false;
    context.mock.method(fs, 'openSync', (target, ...args) => {
      if (target === file) {
        fs.renameSync(file, path.join(root, 'original'));
        fs.writeFileSync(file, 'name: attacker\n');
      }
      return originalOpen(target, ...args);
    });
    context.mock.method(fs, 'readFileSync', (...args) => {
      replacementRead = true;
      return originalRead(...args);
    });
    if (caller === 'repository') {
      assert.match(readRegularRepositoryFile(root, 'v1.yml').error, /changed while opening/);
    } else {
      assert.throws(() => loadDartSastWorkflowForms(root), /changed while opening/);
    }
    assert.equal(replacementRead, false);
  });
}

test('verified reads close the descriptor on success and on read failure', (context) => {
  const { file } = fixture(context);
  const expected = fs.lstatSync(file);
  const originalOpen = fs.openSync;
  let descriptor;
  context.mock.method(fs, 'openSync', (...args) => {
    descriptor = originalOpen(...args);
    return descriptor;
  });
  assert.equal(readVerifiedRegularFileSync(file, expected).toString(), 'name: trusted\n');
  assert.throws(() => fs.fstatSync(descriptor), { code: 'EBADF' });
  context.mock.method(fs, 'readFileSync', () => {
    throw new Error('injected read failure');
  });
  assert.throws(() => readVerifiedRegularFileSync(file, expected), /injected read failure/);
  assert.throws(() => fs.fstatSync(descriptor), { code: 'EBADF' });
});

test('forms and repository reject pre-existing parent links and nonregular entries', (context) => {
  const { root, file } = fixture(context);
  const directory = path.join(root, 'directory');
  fs.mkdirSync(directory);
  const alias = path.join(root, 'alias');
  fs.symlinkSync(directory, alias, 'junction');
  fs.writeFileSync(path.join(directory, 'v1.yml'), 'name: linked\n');
  assert.match(readRegularRepositoryFile(root, 'alias/v1.yml').error, /exact repository path/);
  assert.throws(() => loadDartSastWorkflowForms(alias), /exact repository path/);
  fs.unlinkSync(file);
  fs.mkdirSync(file);
  fs.mkdirSync(path.join(directory, 'v2.yml'));
  assert.throws(() => loadDartSastWorkflowForms(directory), /regular file/);
  assert.match(readRegularRepositoryFile(root, 'v1.yml').error, /regular non-symlink/);
});

test('parent substitution before open is rejected before reading external contents', (context) => {
  const { root } = fixture(context);
  const parent = path.join(root, 'parent');
  const outside = path.join(root, 'outside');
  fs.mkdirSync(parent);
  fs.mkdirSync(outside);
  fs.writeFileSync(path.join(parent, 'file'), 'trusted');
  fs.writeFileSync(path.join(outside, 'file'), 'outside');
  const originalOpen = fs.openSync;
  context.mock.method(fs, 'openSync', (file, ...args) => {
    fs.renameSync(parent, path.join(root, 'original-parent'));
    fs.symlinkSync(outside, parent, 'junction');
    return originalOpen(file, ...args);
  });
  assert.match(readRegularRepositoryFile(root, 'parent/file').error, /changed while opening/);
});

test('path substitution after open is rejected and still closes the descriptor', (context) => {
  const { root, file } = fixture(context);
  const originalOpen = fs.openSync;
  let descriptor;
  context.mock.method(fs, 'openSync', (...args) => {
    descriptor = originalOpen(...args);
    fs.renameSync(file, path.join(root, 'original'));
    fs.writeFileSync(file, 'replacement');
    return descriptor;
  });
  assert.match(readRegularRepositoryFile(root, 'v1.yml').error, /path changed while opening/);
  assert.throws(() => fs.fstatSync(descriptor), { code: 'EBADF' });
});

test('a substituted final symlink is rejected without reading its target', {
  skip: process.platform === 'win32' && 'file symlink creation requires Windows privilege',
}, (context) => {
  const { root, file } = fixture(context);
  const target = path.join(root, 'target');
  fs.writeFileSync(target, 'name: attacker\n');
  const originalOpen = fs.openSync;
  context.mock.method(fs, 'openSync', (value, ...args) => {
    fs.renameSync(file, path.join(root, 'original'));
    fs.symlinkSync(target, file);
    return originalOpen(value, ...args);
  });
  assert.match(readRegularRepositoryFile(root, 'v1.yml').error, /ELOOP|changed while opening/);
});

test('a substituted FIFO is rejected without blocking', {
  skip: process.platform === 'win32' && 'FIFO fixture is POSIX-only',
  timeout: 5000,
}, (context) => {
  const { root, file } = fixture(context);
  const originalOpen = fs.openSync;
  context.mock.method(fs, 'openSync', (value, ...args) => {
    fs.renameSync(file, path.join(root, 'original'));
    execFileSync('mkfifo', [file], { timeout: 2000 });
    return originalOpen(value, ...args);
  });
  assert.match(readRegularRepositoryFile(root, 'v1.yml').error, /changed while opening/);
});
