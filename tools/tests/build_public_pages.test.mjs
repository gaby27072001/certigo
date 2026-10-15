import assert from 'node:assert/strict';
import { mkdir, mkdtemp, readFile, readdir, rm, symlink, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import test from 'node:test';

import { buildPublicPages } from '../build_public_pages.mjs';

test('builds public privacy and account-deletion routes without a data form', async () => {
  const output = await mkdtemp(join(tmpdir(), 'certigo-public-pages-'));
  try {
    await buildPublicPages({
      root: resolve('.'),
      output,
      publicWebOrigin: 'https://github.com',
      publicDomainVerified: true,
      appleCiamDomainReconfigured: false,
    });

    const deletion = await readFile(join(output, 'account-deletion/index.html'), 'utf8');
    const privacy = await readFile(join(output, 'privacy-policy/index.html'), 'utf8');

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
      /<link rel="canonical" href="https:\/\/github\.com\/account-deletion\/">/,
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
      /<link rel="canonical" href="https:\/\/github\.com\/privacy-policy\/">/,
    );
  } finally {
    await rm(output, { recursive: true, force: true });
  }
});

test('fails before creating output when the public domain is not verified', async () => {
  const output = join(tmpdir(), `certigo-public-pages-closed-${process.pid}-${Date.now()}`);
  await assert.rejects(
    buildPublicPages({
      root: resolve('.'),
      output,
      publicWebOrigin: '',
      publicDomainVerified: false,
      appleCiamDomainReconfigured: false,
    }),
    /PUBLIC_WEB_ORIGIN is required/,
  );
  await assert.rejects(readFile(join(output, 'privacy-policy/index.html')), /ENOENT/);
});

test('safely replaces generated files on repeated builds', async () => {
  const output = await mkdtemp(join(tmpdir(), 'certigo-public-pages-repeat-'));
  try {
    await buildPublicPages({
      root: resolve('.'),
      output,
      publicWebOrigin: 'https://github.com',
      publicDomainVerified: true,
      appleCiamDomainReconfigured: false,
    });
    const paths = [
      'staticwebapp.config.json',
      'index.html',
      'privacy-policy/index.html',
      'account-deletion/index.html',
    ];
    const first = await Promise.all(paths.map((file) => readFile(join(output, file))));

    await buildPublicPages({
      root: resolve('.'),
      output,
      publicWebOrigin: 'https://github.com',
      publicDomainVerified: true,
      appleCiamDomainReconfigured: false,
    });

    assert.deepEqual(
      await Promise.all(paths.map((file) => readFile(join(output, file)))),
      first,
    );
    assert.deepEqual((await readdir(output)).sort(), [
      'account-deletion',
      'index.html',
      'privacy-policy',
      'staticwebapp.config.json',
    ]);
  } finally {
    await rm(output, { recursive: true, force: true });
  }
});

test('refuses symlinked and non-regular generated destinations', async () => {
  const targets = [
    'staticwebapp.config.json',
    'index.html',
    'privacy-policy/index.html',
    'account-deletion/index.html',
  ];
  for (const target of targets) {
    const output = await mkdtemp(join(tmpdir(), 'certigo-public-pages-link-'));
    const outside = join(output, 'outside.txt');
    const destination = join(output, target);
    try {
      await mkdir(dirname(destination), { recursive: true });
      await writeFile(outside, 'must remain untouched');
      try {
        await symlink(outside, destination, 'file');
      } catch (error) {
        if (error.code === 'EPERM') {
          continue;
        }
        throw error;
      }

      await assert.rejects(
        buildPublicPages({
          root: resolve('.'),
          output,
          publicWebOrigin: 'https://github.com',
          publicDomainVerified: true,
          appleCiamDomainReconfigured: false,
        }),
        /regular non-symlink file/,
      );
      assert.equal(await readFile(outside, 'utf8'), 'must remain untouched');
    } finally {
      await rm(output, { recursive: true, force: true });
    }
  }
  const output = await mkdtemp(join(tmpdir(), 'certigo-public-pages-directory-'));
  try {
    await mkdir(join(output, 'staticwebapp.config.json'));
    await assert.rejects(
      buildPublicPages({
        root: resolve('.'),
        output,
        publicWebOrigin: 'https://github.com',
        publicDomainVerified: true,
        appleCiamDomainReconfigured: false,
      }),
      /regular non-symlink file/,
    );
  } finally {
    await rm(output, { recursive: true, force: true });
  }

  const linkedOutput = await mkdtemp(join(tmpdir(), 'certigo-public-pages-parent-link-'));
  const outside = await mkdtemp(join(tmpdir(), 'certigo-public-pages-parent-outside-'));
  try {
    await mkdir(join(outside, 'privacy-policy'));
    await writeFile(join(outside, 'privacy-policy/index.html'), 'must remain untouched');
    try {
      await symlink(outside, join(linkedOutput, 'privacy-policy'), 'junction');
    } catch (error) {
      if (error.code === 'EPERM') {
        return;
      }
      throw error;
    }
    await assert.rejects(
      buildPublicPages({
        root: resolve('.'),
        output: linkedOutput,
        publicWebOrigin: 'https://github.com',
        publicDomainVerified: true,
        appleCiamDomainReconfigured: false,
      }),
      /real non-symlink directory/,
    );
    assert.equal(
      await readFile(join(outside, 'privacy-policy/index.html'), 'utf8'),
      'must remain untouched',
    );
  } finally {
    await rm(linkedOutput, { recursive: true, force: true });
    await rm(outside, { recursive: true, force: true });
  }
});
