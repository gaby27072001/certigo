import fs from 'node:fs';
import { readFile } from 'node:fs/promises';
import { dirname, parse, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

import { validatePublicDomainConfiguration } from '../.github/scripts/public-domain-contract.mjs';

const supportEmail = 'gabriel.chambaud@icloud.com';
const editorialPilotPath = 'backend/src/Certigo.Infrastructure/Learning/Fixtures/responsible-ai-assistants.json';
const editorialPilotId = 'responsible-ai-assistants';
const editorialLessonIds = [
  'verify-claims',
  'retrieval-not-training',
  'stop-and-escalate',
];
const editorialOrigin = 'https://www.certigo-app.com';
const productionAppleAppID = 'FFQPC7NC68.com.certigo.mobileapp';

function ensureOutputDirectory(directory) {
  const absolute = resolve(directory);
  let current = parse(absolute).root;
  for (const component of relative(current, absolute).split(sep).filter(Boolean)) {
    current = resolve(current, component);
    let stat;
    try {
      stat = fs.lstatSync(current);
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
      fs.mkdirSync(current);
      stat = fs.lstatSync(current);
    }
    if (!stat.isDirectory() || stat.isSymbolicLink()) {
      throw new Error(`${current}: output ancestors must be real non-symlink directories`);
    }
  }
}

function outputFileStat(filePath) {
  try {
    const stat = fs.lstatSync(filePath);
    if (!stat.isFile() || stat.isSymbolicLink() || stat.nlink !== 1) {
      throw new Error(`${filePath}: output must be a regular non-symlink single-link file`);
    }
    return stat;
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
    return null;
  }
}

// Generation requires a stable, isolated workspace with no hostile concurrent writer.
// Portable Node cannot atomically confine mutable ancestors; O_NOFOLLOW is final-only.
// Never use pathname rename/unlink publication, which can substitute a homonymous source.
function writeOutputFile(filePath, contents) {
  ensureOutputDirectory(dirname(filePath));
  const previous = outputFileStat(filePath);
  const flags = fs.constants.O_WRONLY
    | (fs.constants.O_NOFOLLOW ?? 0)
    | (fs.constants.O_NONBLOCK ?? 0)
    | (previous ? 0 : fs.constants.O_CREAT | fs.constants.O_EXCL);
  const descriptor = fs.openSync(filePath, flags, 0o600);
  try {
    const opened = fs.fstatSync(descriptor);
    if (
      !opened.isFile()
      || opened.nlink !== 1
      || (previous && (opened.dev !== previous.dev || opened.ino !== previous.ino))
    ) {
      throw new Error(`${filePath}: output file changed while opening`);
    }
    ensureOutputDirectory(dirname(filePath));
    const current = outputFileStat(filePath);
    if (!current || current.dev !== opened.dev || current.ino !== opened.ino) {
      throw new Error(`${filePath}: output path changed while opening`);
    }
    // Check before truncating an existing file, and preserve its permissions on reruns.
    fs.ftruncateSync(descriptor, 0);
    fs.writeFileSync(descriptor, contents, 'utf8');
    if (!previous && process.platform !== 'win32') {
      fs.fchmodSync(descriptor, 0o666 & ~process.umask());
    }
  } finally {
    fs.closeSync(descriptor);
  }
}

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

function validateEditorialPilot(pilot) {
  if (
    pilot?.id !== editorialPilotId
    || pilot.status !== 'draft'
    || pilot.purpose !== 'learning-not-certification'
    || typeof pilot.title !== 'string'
    || typeof pilot.scope !== 'string'
    || !Array.isArray(pilot.lessons)
    || !Array.isArray(pilot.sources)
    || pilot.sources.length === 0
  ) {
    throw new Error('The editorial pilot does not match the stable public lesson-link contract.');
  }
  const lessonIDs = pilot.lessons.map((lesson) => lesson?.id);
  if (
    lessonIDs.length !== editorialLessonIds.length
    || new Set(lessonIDs).size !== lessonIDs.length
    || editorialLessonIds.some((id) => !lessonIDs.includes(id))
  ) {
    throw new Error('The editorial pilot does not match the stable public lesson-link contract.');
  }

  if (pilot.sources.some((source) =>
    !source
    || typeof source.id !== 'string'
    || typeof source.title !== 'string'
    || typeof source.checkedOn !== 'string'
    || typeof source.supports !== 'string'
    || typeof source.limits !== 'string'
    || typeof source.url !== 'string'
  )) {
    throw new Error('The editorial pilot does not match the stable public lesson-link contract.');
  }
  const sources = new Map(pilot.sources.map((source) => [source.id, source]));
  if (sources.size !== pilot.sources.length) {
    throw new Error('The editorial pilot does not match the stable public lesson-link contract.');
  }
  for (const source of pilot.sources) {
    let url;
    try {
      url = new URL(source.url);
    } catch {
      throw new Error(`Invalid editorial pilot source URL: ${source.id}`);
    }
    if (
      url.protocol !== 'https:'
      || !url.hostname
      || url.username
      || url.password
      || url.search
      || url.hash
    ) {
      throw new Error(`Invalid editorial pilot source URL: ${source.id}`);
    }
  }
  const textArray = (value) =>
    Array.isArray(value) && value.length > 0 && value.every((item) => typeof item === 'string');
  for (const lesson of pilot.lessons) {
    if (
      typeof lesson.title !== 'string'
      || typeof lesson.objective !== 'string'
      || typeof lesson.hook !== 'string'
      || !textArray(lesson.keyIdeas)
      || typeof lesson.workedExample?.situation !== 'string'
      || !textArray(lesson.workedExample.steps)
      || typeof lesson.workedExample.decision !== 'string'
      || typeof lesson.practice?.prompt !== 'string'
      || !textArray(lesson.practice.successCriteria)
      || typeof lesson.practice.feedback !== 'string'
      || typeof lesson.recap !== 'string'
      || !Number.isInteger(lesson.estimatedMinutes)
      || lesson.estimatedMinutes <= 0
      || !textArray(lesson.sourceIds)
      || lesson.sourceIds.some((sourceID) => !sources.has(sourceID))
    ) {
      throw new Error(`Invalid editorial pilot lesson content: ${lesson.id}`);
    }
  }
  return pilot;
}

function renderEditorialPilotIndex(pilot, canonicalUrl) {
  const lessons = pilot.lessons.map((lesson) => `
  <li>
    <h2><a href="/learn/${htmlEscape(pilot.id)}/${htmlEscape(lesson.id)}/">${htmlEscape(lesson.title)}</a></h2>
    <p>${htmlEscape(lesson.objective)}</p>
  </li>`).join('');
  return layout(
    `${pilot.title} — Certigo`,
    canonicalUrl,
    `<h1>${htmlEscape(pilot.title)}</h1>
<p><strong>Apprentissage, pas certification · brouillon éditorial</strong></p>
<p>${htmlEscape(pilot.scope)}</p>
<h2>Leçons</h2>
<ol>${lessons}
</ol>
<p>Cette version web ne nécessite pas de connexion et n’enregistre aucune activité.</p>`,
  );
}

function renderEditorialLesson(pilot, lesson, canonicalUrl) {
  const list = (items) => `<ul>${items.map((item) => `<li>${htmlEscape(item)}</li>`).join('')}</ul>`;
  const sources = lesson.sourceIds.map((sourceID) => {
    const source = pilot.sources.find((candidate) => candidate.id === sourceID);
    return `<li>
  <a href="${htmlEscape(source.url)}" target="_blank" rel="noopener noreferrer">${htmlEscape(source.title)}</a>
  <p>Consultée le ${htmlEscape(source.checkedOn)}. ${htmlEscape(source.supports)}</p>
  <p>${htmlEscape(source.limits)}</p>
</li>`;
  }).join('');
  const steps = lesson.workedExample.steps
    .map((step) => `<li>${htmlEscape(step)}</li>`)
    .join('');
  return layout(
    `${lesson.title} — Certigo`,
    canonicalUrl,
    `<nav aria-label="Breadcrumb"><a href="/learn/${htmlEscape(pilot.id)}/">${htmlEscape(pilot.title)}</a></nav>
<p><strong>Apprentissage, pas certification · brouillon éditorial</strong></p>
<h1>${htmlEscape(lesson.title)}</h1>
<p><strong>Objectif :</strong> ${htmlEscape(lesson.objective)}</p>
<p>${htmlEscape(lesson.hook)}</p>
<p>Durée estimée : ${htmlEscape(String(lesson.estimatedMinutes))} min</p>
<section><h2>Idées clés</h2>${list(lesson.keyIdeas)}</section>
<section>
  <h2>Exemple résolu</h2>
  <p>${htmlEscape(lesson.workedExample.situation)}</p>
  <ol>${steps}</ol>
  <p><strong>Décision :</strong> ${htmlEscape(lesson.workedExample.decision)}</p>
</section>
<section>
  <h2>Pratique formative · sans réponse enregistrée</h2>
  <p>${htmlEscape(lesson.practice.prompt)}</p>
  ${list(lesson.practice.successCriteria)}
  <p>${htmlEscape(lesson.practice.feedback)}</p>
</section>
<section><h2>À retenir</h2><p>${htmlEscape(lesson.recap)}</p></section>
<section><h2>Sources et limites</h2><ul>${sources}</ul></section>
<p>La lecture web ne crée pas de compte, ne transmet pas de réponse et n’enregistre aucune activité.</p>
<p><a href="/learn/${htmlEscape(pilot.id)}/">Revenir à la liste des leçons</a></p>`,
  );
}

export async function buildPublicPages({
  root,
  output,
  publicWebOrigin,
  publicDomainVerified,
  appleCiamDomainReconfigured,
  iosUniversalLinksBuildVerified = false,
}) {
  const publicDomain = validatePublicDomainConfiguration({
    environment: 'prod',
    feature: 'legal-pages',
    publicWebOrigin,
    publicDomainVerified,
    appleCiamDomainReconfigured,
    // This builder writes the domain's own pages, so activation is mandatory here: an
    // unconfigured domain must stop the build instead of producing pages with no home.
    activationRequested: true,
  });
  if (typeof iosUniversalLinksBuildVerified !== 'boolean') {
    throw new Error('iosUniversalLinksBuildVerified must be a boolean.');
  }
  if (
    iosUniversalLinksBuildVerified
    && publicDomain.publicWebOrigin !== editorialOrigin
  ) {
    throw new Error(`Universal Links can only be enabled for ${editorialOrigin}.`);
  }
  const privacy = await readFile(resolve(root, 'docs/legal/privacy-policy.md'), 'utf8');
  const deletion = await readFile(resolve(root, 'docs/legal/account-deletion.md'), 'utf8');
  const editorialPilot = validateEditorialPilot(
    JSON.parse(await readFile(resolve(root, editorialPilotPath), 'utf8')),
  );
  const mailto = `mailto:${supportEmail}?subject=${encodeURIComponent('Suppression de compte Certigo')}`;

  const privacyPath = resolve(output, 'privacy-policy/index.html');
  const deletionPath = resolve(output, 'account-deletion/index.html');
  const indexPath = resolve(output, 'index.html');
  const editorialIndexPath = resolve(output, `learn/${editorialPilot.id}/index.html`);
  const editorialLessonPaths = editorialPilot.lessons.map((lesson) => ({
    lesson,
    path: resolve(output, `learn/${editorialPilot.id}/${lesson.id}/index.html`),
  }));
  const aasaPath = resolve(output, '.well-known/apple-app-site-association.json');
  const configPath = resolve(output, 'staticwebapp.config.json');
  ensureOutputDirectory(dirname(privacyPath));
  ensureOutputDirectory(dirname(deletionPath));
  ensureOutputDirectory(dirname(indexPath));
  const expectedOutputPaths = [
    configPath,
    indexPath,
    privacyPath,
    deletionPath,
    editorialIndexPath,
    ...editorialLessonPaths.map(({ path }) => path),
    ...(iosUniversalLinksBuildVerified ? [aasaPath] : []),
  ];
  for (const filePath of expectedOutputPaths) {
    outputFileStat(filePath);
  }

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
  const routes = iosUniversalLinksBuildVerified
    ? [
      {
        route: '/.well-known/apple-app-site-association',
        rewrite: '/.well-known/apple-app-site-association.json',
      },
    ]
    : [];
  writeOutputFile(
    configPath,
    `${JSON.stringify(
      {
        mimeTypes: { '.json': 'application/json' },
        routes,
      },
      null,
      2,
    )}\n`,
  );
  if (iosUniversalLinksBuildVerified) {
    writeOutputFile(
      aasaPath,
      `${JSON.stringify(
        {
          applinks: {
            apps: [],
            details: [
              {
                appID: productionAppleAppID,
                paths: editorialPilot.lessons.flatMap(({ id }) => [
                  `/learn/${editorialPilot.id}/${id}`,
                  `/learn/${editorialPilot.id}/${id}/`,
                ]),
              },
            ],
          },
        },
        null,
        2,
      )}\n`,
    );
  }

  // Azure Static Web Apps refuse de publier un dossier sans fichier par defaut
  // a la racine, et son client rend un code de sortie 0 en le refusant : le
  // 2026-09-07, un deploiement « reussi » sans cette page a laisse les deux
  // URLs en 404. GitHub Pages, lui, n'exigeait rien de tel. Cette page est
  // aussi le « Site web » declare dans la fiche Google Play.
  writeOutputFile(
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
  <li><a href="/learn/${htmlEscape(editorialPilot.id)}/">Pilote éditorial d’apprentissage</a></li>
</ul>
<p>Contact : <a href="mailto:${htmlEscape(supportEmail)}">${htmlEscape(supportEmail)}</a></p>
<p><small>Certigo est une plateforme indépendante, non affiliée aux organismes de
certification dont elle prépare les examens.</small></p>`,
    ),
  );

  writeOutputFile(
    editorialIndexPath,
    renderEditorialPilotIndex(
      editorialPilot,
      `${publicDomain.publicWebOrigin}/learn/${editorialPilot.id}/`,
    ),
  );
  for (const { lesson, path } of editorialLessonPaths) {
    writeOutputFile(
      path,
      renderEditorialLesson(
        editorialPilot,
        lesson,
        `${publicDomain.publicWebOrigin}/learn/${editorialPilot.id}/${lesson.id}/`,
      ),
    );
  }

  writeOutputFile(
    privacyPath,
    layout(
      'Politique de confidentialité — Certigo',
      `${publicDomain.publicWebOrigin}/privacy-policy/`,
      `<h1>Politique de confidentialité — Certigo</h1><pre>${htmlEscape(privacy)}</pre>`,
    ),
  );
  writeOutputFile(
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
  );
}

const currentFile = fileURLToPath(import.meta.url);
if (process.argv[1] && resolve(process.argv[1]) === currentFile) {
  const outputIndex = process.argv.indexOf('--output');
  const output = outputIndex >= 0 ? process.argv[outputIndex + 1] : '_site';
  const buildVerifiedFlag = process.env.APPLE_UNIVERSAL_LINKS_COMPATIBLE_BUILD_VERIFIED;
  if (buildVerifiedFlag !== undefined && !['true', 'false'].includes(buildVerifiedFlag)) {
    throw new Error('APPLE_UNIVERSAL_LINKS_COMPATIBLE_BUILD_VERIFIED must be true or false.');
  }
  await buildPublicPages({
    root: process.cwd(),
    output: resolve(output),
    publicWebOrigin: process.env.PUBLIC_WEB_ORIGIN,
    publicDomainVerified: process.env.PUBLIC_DOMAIN_VERIFIED,
    appleCiamDomainReconfigured: process.env.APPLE_CIAM_DOMAIN_RECONFIGURED,
    iosUniversalLinksBuildVerified: buildVerifiedFlag === 'true',
  });
}
