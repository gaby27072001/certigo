import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const supportEmail = 'gabriel.chambaud@icloud.com';

function htmlEscape(value) {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function layout(title, content) {
  return `<!doctype html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${htmlEscape(title)}</title>
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

export async function buildPublicPages({ root, output }) {
  const privacy = await readFile(resolve(root, 'docs/legal/privacy-policy.md'), 'utf8');
  const deletion = await readFile(resolve(root, 'docs/legal/account-deletion.md'), 'utf8');
  const mailto = `mailto:${supportEmail}?subject=${encodeURIComponent('Suppression de compte Certigo')}`;

  const privacyPath = resolve(output, 'privacy-policy/index.html');
  const deletionPath = resolve(output, 'account-deletion/index.html');
  await mkdir(dirname(privacyPath), { recursive: true });
  await mkdir(dirname(deletionPath), { recursive: true });

  await writeFile(
    privacyPath,
    layout(
      'Politique de confidentialité — Certigo',
      `<h1>Politique de confidentialité — Certigo</h1><pre>${htmlEscape(privacy)}</pre>`,
    ),
    'utf8',
  );
  await writeFile(
    deletionPath,
    layout(
      'Suppression de compte — Certigo',
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
  await buildPublicPages({ root: process.cwd(), output: resolve(output) });
}
