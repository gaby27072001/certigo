import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { mkdtemp, readFile, readdir, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import test from 'node:test';
import { promisify } from 'node:util';

import { buildPublicPages } from '../build_public_pages.mjs';

const execFileAsync = promisify(execFile);
const canonicalOrigin = 'https://certigo-app.com';
const testFingerprint = Array.from({ length: 32 }, () => 'AB').join(':');
const python = process.env.PYTHON || (process.platform === 'win32' ? 'python' : 'python3');

async function generateAssociations(root) {
  const associationOutput = join(root, 'associations');
  await execFileAsync(python, [
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

async function listFiles(directory, root = directory) {
  const files = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      files.push(...await listFiles(path, root));
    } else {
      files.push(path.slice(root.length + 1).replaceAll('\\', '/'));
    }
  }
  return files.sort();
}

test('builds the exact root-domain artifact from generator-owned associations', async () => {
  const temporary = await mkdtemp(join(tmpdir(), 'certigo-public-pages-'));
  const output = join(temporary, 'site');
  try {
    const associationSource = await generateAssociations(temporary);
    await buildPublicPages({
      root: resolve('.'),
      output,
      associationSource,
      publicWebOrigin: canonicalOrigin,
      publicDomainVerified: true,
      appleCiamDomainReconfigured: true,
    });

    const deletion = await readFile(join(output, 'account-deletion/index.html'), 'utf8');
    const privacy = await readFile(join(output, 'privacy-policy/index.html'), 'utf8');
    const apple = JSON.parse(
      await readFile(join(output, '.well-known/apple-app-site-association'), 'utf8'),
    );
    const android = JSON.parse(
      await readFile(join(output, '.well-known/assetlinks.json'), 'utf8'),
    );

    assert.match(deletion, /Demander la suppression d’un compte Certigo/);
    assert.match(deletion, /mailto:gabriel\.chambaud@icloud\.com/);
    assert.match(deletion, /données actives sont supprimées immédiatement/);
    assert.match(deletion, /reçu pseudonymisé expire après 30 jours/);
    assert.match(deletion, /sauvegardes résiduelles expirent au plus tard après 30 jours/);
    assert.match(deletion, /journaux techniques sans identité sont conservés 90 jours/);
    assert.match(deletion, /N’envoyez jamais .* pièce d’identité/);
    assert.match(deletion, /<html lang="fr">/);
    assert.match(deletion, /aria-labelledby="request-title"/);
    assert.match(
      deletion,
      /<link rel="canonical" href="https:\/\/certigo-app\.com\/account-deletion\/">/,
    );
    assert.match(deletion, /\.button:focus-visible/);
    assert.doesNotMatch(deletion, /<form\b/i);
    assert.doesNotMatch(deletion, /password|mot de passe" type=/i);
    assert.match(privacy, /Politique de confidentialité/);
    assert.match(privacy, /gabriel\.chambaud@icloud\.com/);
    assert.match(privacy, /immédiatement après la vérification/);
    assert.match(privacy, /récupération maximale de 30 jours/);
    assert.match(privacy, /conservés pendant 90 jours/);
    assert.match(privacy, /ne demande pas de pièce d’identité/);
    assert.match(
      privacy,
      /<link rel="canonical" href="https:\/\/certigo-app\.com\/privacy-policy\/">/,
    );
    assert.equal(await readFile(join(output, 'CNAME'), 'utf8'), 'certigo-app.com\n');
    assert.equal(await readFile(join(output, '.nojekyll'), 'utf8'), '');
    assert.deepEqual(
      apple.applinks.details[0].components.map((component) => component['/']),
      [
        '/learn/*/*',
        '/assignments/*',
        '/achievements/*',
        '/account-deletion',
      ],
    );
    assert.deepEqual(apple.applinks.details[0].appIDs, ['ABCDEFGHIJ.com.certigo.testapp']);
    assert.equal(android[0].target.package_name, 'com.certigo.testapp');
    assert.deepEqual(android[0].target.sha256_cert_fingerprints, [testFingerprint]);
    assert.deepEqual(
      await listFiles(output),
      [
        '.nojekyll',
        '.well-known/apple-app-site-association',
        '.well-known/assetlinks.json',
        'CNAME',
        'account-deletion/index.html',
        'privacy-policy/index.html',
      ],
    );
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
});

test('fails before creating output when the public domain is not verified', async () => {
  const output = join(tmpdir(), `certigo-public-pages-closed-${process.pid}-${Date.now()}`);
  await assert.rejects(
    buildPublicPages({
      root: resolve('.'),
      output,
      associationSource: '',
      publicWebOrigin: '',
      publicDomainVerified: false,
      appleCiamDomainReconfigured: false,
    }),
    /PUBLIC_WEB_ORIGIN is required/,
  );
  await assert.rejects(readFile(join(output, 'privacy-policy/index.html')), /ENOENT/);
});

test('fails before creating output when an association activation proof is absent', async () => {
  const temporary = await mkdtemp(join(tmpdir(), 'certigo-public-pages-closed-'));
  const output = join(temporary, 'site');
  try {
    const associationSource = await generateAssociations(temporary);
    await assert.rejects(
      buildPublicPages({
        root: resolve('.'),
        output,
        associationSource,
        publicWebOrigin: canonicalOrigin,
        publicDomainVerified: true,
        appleCiamDomainReconfigured: false,
      }),
      /APPLE_CIAM_DOMAIN_RECONFIGURED must be explicitly true/,
    );
    await assert.rejects(readFile(join(output, 'CNAME')), /ENOENT/);
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
});
