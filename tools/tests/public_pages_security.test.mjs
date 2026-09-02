import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import {
  mkdir,
  mkdtemp,
  readFile,
  rm,
  writeFile,
} from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import test from 'node:test';
import { promisify } from 'node:util';

import { buildPublicPages } from '../build_public_pages.mjs';

const execFileAsync = promisify(execFile);
const testFingerprint = Array.from({ length: 32 }, () => 'CD').join(':');

async function generateAssociations(root) {
  const associationOutput = join(root, 'associations');
  await execFileAsync(process.env.PYTHON || 'python', [
    resolve('tools/generate_link_associations.py'),
    '--confirmed-domain',
    'certigo-app.com',
    '--apple-team-id',
    'ABCDEFGHIJ',
    '--bundle-id',
    'com.certigo.testapp',
    '--android-sha256',
    testFingerprint,
    '--output-dir',
    associationOutput,
  ]);
  return join(associationOutput, 'certigo-app.com', '.well-known');
}

function buildOptions(output, associationSource) {
  return {
    root: resolve('.'),
    output,
    associationSource,
    publicWebOrigin: 'https://certigo-app.com',
    publicDomainVerified: true,
    appleCiamDomainReconfigured: true,
  };
}

test('rejects extra association files before any public artifact is created', async () => {
  const temporary = await mkdtemp(join(tmpdir(), 'certigo-public-pages-security-'));
  const output = join(temporary, 'site');
  try {
    const associationSource = await generateAssociations(temporary);
    await writeFile(
      join(associationSource, 'private-answer-key.json'),
      '{"answerKey":"must-not-publish"}\n',
      'utf8',
    );

    await assert.rejects(
      buildPublicPages(buildOptions(output, associationSource)),
      /only the two public association files/,
    );
    await assert.rejects(readFile(join(output, 'CNAME')), /ENOENT/);
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
});

test('rejects unexpected JSON fields before any public artifact is created', async () => {
  const temporary = await mkdtemp(join(tmpdir(), 'certigo-public-pages-security-'));
  const output = join(temporary, 'site');
  try {
    const associationSource = await generateAssociations(temporary);
    const applePath = join(associationSource, 'apple-app-site-association');
    const apple = JSON.parse(await readFile(applePath, 'utf8'));
    apple.privateAnswerKey = 'must-not-publish';
    await writeFile(applePath, `${JSON.stringify(apple, null, 2)}\n`, 'utf8');

    await assert.rejects(
      buildPublicPages(buildOptions(output, associationSource)),
      /unexpected public fields/,
    );
    await assert.rejects(readFile(join(output, 'CNAME')), /ENOENT/);
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
});

test('refuses to mix public output with stale or private files', async () => {
  const temporary = await mkdtemp(join(tmpdir(), 'certigo-public-pages-security-'));
  const output = join(temporary, 'site');
  try {
    const associationSource = await generateAssociations(temporary);
    await mkdir(output);
    const privatePath = join(output, 'private-answer-key.json');
    await writeFile(privatePath, '{"answerKey":"must-not-publish"}\n', 'utf8');

    await assert.rejects(
      buildPublicPages(buildOptions(output, associationSource)),
      /output must be empty/,
    );
    assert.equal(
      await readFile(privatePath, 'utf8'),
      '{"answerKey":"must-not-publish"}\n',
    );
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
});

test('rejects project-path association routes before creating output', async () => {
  const temporary = await mkdtemp(join(tmpdir(), 'certigo-public-pages-security-'));
  const output = join(temporary, 'site');
  try {
    const associationSource = await generateAssociations(temporary);
    const applePath = join(associationSource, 'apple-app-site-association');
    const apple = JSON.parse(await readFile(applePath, 'utf8'));
    apple.applinks.details[0].components[0]['/'] = '/Certigo/learn/*/*';
    await writeFile(applePath, `${JSON.stringify(apple, null, 2)}\n`, 'utf8');

    await assert.rejects(
      buildPublicPages(buildOptions(output, associationSource)),
      /routes do not match the root-domain contract/,
    );
    await assert.rejects(readFile(join(output, 'CNAME')), /ENOENT/);
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
});
