#!/usr/bin/env node
// Compare le contenu public servi au rendu des documents légaux et du pilote éditorial.
//
// Invariant que ce script existe pour couvrir : la publication des pages
// legales est manuelle et aucun workflow ne peut la declencher (le scelle des
// workflows privilegies interdit d'en ajouter un). La derive entre la source et
// la page servie est donc silencieuse : rien ne la signale, aucune execution
// n'echoue, et seule une comparaison explicite la revele.
// Voir docs/legal/README.md.
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { buildPublicPages } from './build_public_pages.mjs';

export const publishedRoutes = [
  'privacy-policy',
  'account-deletion',
  'learn/responsible-ai-assistants',
  'learn/responsible-ai-assistants/verify-claims',
  'learn/responsible-ai-assistants/retrieval-not-training',
  'learn/responsible-ai-assistants/stop-and-escalate',
];

// La comparaison porte sur le texte rendu, pas sur les octets : la mise en page
// et les styles ne sont pas ce qui doit declencher une republication.
export function normalizeHtml(html) {
  return html
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

export function firstDifference(expected, served) {
  const shared = Math.min(expected.length, served.length);
  let index = 0;
  while (index < shared && expected[index] === served[index]) {
    index += 1;
  }
  if (index === shared && expected.length === served.length) {
    return null;
  }
  const from = Math.max(0, index - 40);
  return {
    index,
    expected: expected.slice(from, from + 140),
    served: served.slice(from, from + 140),
  };
}

async function fetchOverHttp(url) {
  const response = await fetch(url, { redirect: 'follow' });
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }
  return response.text();
}

export async function comparePublicPages({
  root,
  publicWebOrigin,
  publicDomainVerified,
  appleCiamDomainReconfigured,
  fetchPage = fetchOverHttp,
}) {
  const output = await mkdtemp(join(tmpdir(), 'certigo-public-pages-drift-'));
  try {
    await buildPublicPages({
      root,
      output,
      publicWebOrigin,
      publicDomainVerified,
      appleCiamDomainReconfigured,
    });

    const results = [];
    for (const route of publishedRoutes) {
      const expected = normalizeHtml(
        await readFile(resolve(output, route, 'index.html'), 'utf8'),
      );
      const url = `${publicWebOrigin}/${route}/`;
      let served = null;
      let error = null;
      try {
        served = normalizeHtml(await fetchPage(url));
      } catch (cause) {
        error = cause instanceof Error ? cause.message : String(cause);
      }
      results.push({
        route,
        url,
        error,
        // Une route injoignable n'est pas « a jour » : l'echec de lecture et la
        // concordance doivent rester deux etats distincts.
        inSync: error === null && served === expected,
        difference: error === null ? firstDifference(expected, served) : null,
      });
    }
    return results;
  } finally {
    await rm(output, { recursive: true, force: true });
  }
}

async function main() {
  const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
  const publicWebOrigin = process.env.PUBLIC_WEB_ORIGIN;
  if (!publicWebOrigin) {
    console.error(
      'PUBLIC_WEB_ORIGIN est requis (origine canonique, sans barre oblique finale).',
    );
    process.exitCode = 1;
    return;
  }

  const results = await comparePublicPages({
    root,
    publicWebOrigin,
    publicDomainVerified: process.env.PUBLIC_DOMAIN_VERIFIED,
    appleCiamDomainReconfigured: process.env.APPLE_CIAM_DOMAIN_RECONFIGURED,
  });

  let drifted = false;
  for (const result of results) {
    if (result.error !== null) {
      drifted = true;
      console.error(`${result.route}: illisible (${result.error}) — ${result.url}`);
      continue;
    }
    if (result.inSync) {
      console.log(`${result.route}: a jour`);
      continue;
    }
    drifted = true;
    console.error(`${result.route}: DIVERGENT — ${result.url}`);
    if (result.difference) {
      console.error(`  premiere divergence a l'offset ${result.difference.index}`);
      console.error(`  source : ...${result.difference.expected}`);
      console.error(`  servi  : ...${result.difference.served}`);
    }
  }

  if (drifted) {
    console.error(
      'Republier les pages publiques, puis relancer ce controle. Voir docs/legal/README.md.',
    );
    process.exitCode = 1;
  }
}

if (process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url))) {
  await main();
}
