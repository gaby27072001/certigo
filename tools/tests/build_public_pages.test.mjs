import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
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
