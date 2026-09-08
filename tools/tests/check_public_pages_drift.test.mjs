import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import test from 'node:test';

import { buildPublicPages } from '../build_public_pages.mjs';
import {
  comparePublicPages,
  firstDifference,
  normalizeHtml,
  publishedRoutes,
} from '../check_public_pages_drift.mjs';

const config = {
  root: resolve('.'),
  publicWebOrigin: 'https://github.com',
  publicDomainVerified: true,
  appleCiamDomainReconfigured: false,
};

// Rend le HTML que le site devrait servir pour chaque route, en reutilisant le
// meme constructeur que le controle. Sans cette reference, le test « a jour »
// ne prouverait rien : un comparateur qui ne compare rien rendrait le meme vert.
async function renderExpectedPages() {
  const output = await mkdtemp(join(tmpdir(), 'certigo-drift-fixture-'));
  try {
    await buildPublicPages({ ...config, output });
    const pages = new Map();
    for (const route of publishedRoutes) {
      pages.set(route, await readFile(join(output, route, 'index.html'), 'utf8'));
    }
    return pages;
  } finally {
    await rm(output, { recursive: true, force: true });
  }
}

function routeOf(url) {
  return publishedRoutes.find((name) => url.endsWith(`/${name}/`));
}

test('normalise le balisage et les styles avant comparaison', () => {
  const html = '<html><style>.a{color:red}</style><p>Bonjour   le\nmonde</p></html>';
  assert.equal(normalizeHtml(html), 'Bonjour le monde');
});

test('firstDifference rend null sur deux textes identiques', () => {
  assert.equal(firstDifference('abc', 'abc'), null);
  assert.equal(firstDifference('abc', 'abd').index, 2);
  assert.equal(firstDifference('abc', 'abcd').index, 3);
});

test('rend inSync quand la page servie est exactement le rendu de la source', async () => {
  const expected = await renderExpectedPages();
  const asked = [];

  const results = await comparePublicPages({
    ...config,
    fetchPage: async (url) => {
      asked.push(url);
      return expected.get(routeOf(url));
    },
  });

  assert.deepEqual(
    asked,
    publishedRoutes.map((route) => `https://github.com/${route}/`),
  );
  assert.equal(results.length, publishedRoutes.length);
  for (const result of results) {
    assert.equal(result.error, null, `${result.route} devrait etre lisible`);
    assert.equal(result.inSync, true, `${result.route} devrait etre a jour`);
    assert.equal(result.difference, null);
  }
});

test('detecte une page servie restee sur un contenu anterieur', async () => {
  const expected = await renderExpectedPages();

  const results = await comparePublicPages({
    ...config,
    fetchPage: async (url) => {
      const html = expected.get(routeOf(url));
      if (routeOf(url) !== 'privacy-policy') {
        return html;
      }
      return html.replace('Politique de confidentialité', 'Politique obsolete');
    },
  });

  const privacy = results.find((result) => result.route === 'privacy-policy');
  const deletion = results.find((result) => result.route === 'account-deletion');
  assert.equal(privacy.error, null);
  assert.equal(privacy.inSync, false);
  assert.notEqual(privacy.difference, null);
  assert.match(privacy.difference.served, /Politique obsolete/);
  assert.equal(deletion.inSync, true, 'une seule route doit deriver');
});

test('une route injoignable est signalee comme telle et jamais comme a jour', async () => {
  const results = await comparePublicPages({
    ...config,
    fetchPage: async () => {
      throw new Error('HTTP 404');
    },
  });

  for (const result of results) {
    assert.equal(result.error, 'HTTP 404');
    assert.equal(result.inSync, false);
    assert.equal(result.difference, null);
  }
});
