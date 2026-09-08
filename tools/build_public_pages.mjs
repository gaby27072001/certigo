import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { validatePublicDomainConfiguration } from '../.github/scripts/public-domain-contract.mjs';

const supportEmail = 'gabriel.chambaud@icloud.com';

function htmlEscape(value) {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function layout(title, canonicalUrl, content) {
  return `<!doctype html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${htmlEscape(title)}</title>
  <link rel="canonical" href="${htmlEscape(canonicalUrl)}">
  <style>
    :root { color-scheme: light dark; }
    body { font-family: system-ui, -apple-system, "Segoe UI", sans-serif; margin: 0; line-height: 1.55; }
    main { margin: 2rem auto; max-width: 760px; padding: 0 1.25rem 3rem; }
    pre { white-space: pre-wrap; word-break: break-word; background: CanvasText; color: Canvas; padding: 1rem; border-radius: .75rem; }
    .card { border: 1px solid color-mix(in srgb, CanvasText 20%, transparent); border-radius: 1rem; padding: 1.25rem; }
    .button { display: inline-block; background: #146c43; color: white; border-radius: .6rem; padding: .8rem 1rem; font-weight: 700; text-decoration: none; }
    .button:focus-visible { outline: 3px solid #f4b400; outline-offset: 3px; }
  </style>
</head>
<body><main>${content}</main></body>
</html>`;
}

export async function buildPublicPages({
  root,
  output,
  publicWebOrigin,
  publicDomainVerified,
  appleCiamDomainReconfigured,
}) {
  const publicDomain = validatePublicDomainConfiguration({
    environment: 'prod',
    feature: 'legal-pages',
    publicWebOrigin,
    publicDomainVerified,
    appleCiamDomainReconfigured,
  });
  const privacy = await readFile(resolve(root, 'docs/legal/privacy-policy.md'), 'utf8');
  const deletion = await readFile(resolve(root, 'docs/legal/account-deletion.md'), 'utf8');
  const mailto = `mailto:${supportEmail}?subject=${encodeURIComponent('Suppression de compte Certigo')}`;

  const privacyPath = resolve(output, 'privacy-policy/index.html');
  const deletionPath = resolve(output, 'account-deletion/index.html');
  const indexPath = resolve(output, 'index.html');
  const configPath = resolve(output, 'staticwebapp.config.json');
  await mkdir(dirname(privacyPath), { recursive: true });
  await mkdir(dirname(deletionPath), { recursive: true });
  await mkdir(dirname(indexPath), { recursive: true });

  // Azure Static Web Apps sert /.well-known/ tel quel, mais attribue
  // application/octet-stream a un fichier sans extension, et Apple exige
  // application/json sur l'apple-app-site-association. Mesure du 2026-09-08 :
  //   headers.content-type sur la route      -> ignore (octet-stream persiste)
  //   mimeTypes avec la cle "."              -> ignore
  //   rewrite vers un jumeau .json           -> 200, application/json, 0 redirection
  // Un en-tete temoin pose sur la meme route etait bien renvoye : la regle
  // s'appliquait, c'est content-type seul qui resistait. Sans ce controle, on
  // aurait conclu que les routes ne fonctionnent pas.
  //
  // rewrite et non redirect : Apple ne suit aucune redirection. La distinction
  // est invisible dans un navigateur et fatale pour un lien profond, qui echoue
  // alors en silence en ouvrant le navigateur au lieu de l'application.
  await writeFile(
    configPath,
    `${JSON.stringify(
      {
        mimeTypes: { '.json': 'application/json' },
        routes: [
          {
            route: '/.well-known/apple-app-site-association',
            rewrite: '/.well-known/apple-app-site-association.json',
          },
        ],
      },
      null,
      2,
    )}\n`,
    'utf8',
  );

  // Azure Static Web Apps refuse de publier un dossier sans fichier par defaut
  // a la racine, et son client rend un code de sortie 0 en le refusant : le
  // 2026-09-07, un deploiement « reussi » sans cette page a laisse les deux
  // URLs en 404. GitHub Pages, lui, n'exigeait rien de tel. Cette page est
  // aussi le « Site web » declare dans la fiche Google Play.
  await writeFile(
    indexPath,
    layout(
      'Certigo — informations légales',
      `${publicDomain.publicWebOrigin}/`,
      `<h1>Certigo — informations légales</h1>
<p>Certigo est une application d’entraînement aux certifications IT. Cette page
rassemble les documents publics de l’application.</p>
<ul>
  <li><a href="/privacy-policy/">Politique de confidentialité</a></li>
  <li><a href="/account-deletion/">Demander la suppression d’un compte</a></li>
</ul>
<p>Contact : <a href="mailto:${htmlEscape(supportEmail)}">${htmlEscape(supportEmail)}</a></p>
<p><small>Certigo est une plateforme indépendante, non affiliée aux organismes de
certification dont elle prépare les examens.</small></p>`,
    ),
    'utf8',
  );

  await writeFile(
    privacyPath,
    layout(
      'Politique de confidentialité — Certigo',
      `${publicDomain.publicWebOrigin}/privacy-policy/`,
      `<h1>Politique de confidentialité — Certigo</h1><pre>${htmlEscape(privacy)}</pre>`,
    ),
    'utf8',
  );
  await writeFile(
    deletionPath,
    layout(
      'Suppression de compte — Certigo',
      `${publicDomain.publicWebOrigin}/account-deletion/`,
      `<h1>Demander la suppression d’un compte Certigo</h1>
<p>Cette page reste utilisable après la désinstallation de l’application.</p>
<section class="card" aria-labelledby="request-title">
  <h2 id="request-title">Envoyer la demande</h2>
  <p>Utilisez l’adresse associée au compte. N’envoyez jamais de mot de passe, de jeton ou de pièce d’identité.</p>
  <a class="button" href="${htmlEscape(mailto)}">Ouvrir ma messagerie</a>
  <p><small>Ce site ne collecte et ne stocke aucune donnée saisie. Le lien ouvre votre application de messagerie.</small></p>
</section>
<h2>Ce qui est supprimé</h2>
<p>Après vérification et exécution de la demande, les données actives sont supprimées immédiatement.</p>
<p>Le reçu pseudonymisé expire après 30 jours. Les sauvegardes résiduelles expirent au plus tard après 30 jours. Les journaux techniques sans identité sont conservés 90 jours.</p>
<details><summary>Politique technique complète</summary><pre>${htmlEscape(deletion)}</pre></details>`,
    ),
    'utf8',
  );
}

const currentFile = fileURLToPath(import.meta.url);
if (process.argv[1] && resolve(process.argv[1]) === currentFile) {
  const outputIndex = process.argv.indexOf('--output');
  const output = outputIndex >= 0 ? process.argv[outputIndex + 1] : '_site';
  await buildPublicPages({
    root: process.cwd(),
    output: resolve(output),
    publicWebOrigin: process.env.PUBLIC_WEB_ORIGIN,
    publicDomainVerified: process.env.PUBLIC_DOMAIN_VERIFIED,
    appleCiamDomainReconfigured: process.env.APPLE_CIAM_DOMAIN_RECONFIGURED,
  });
}
