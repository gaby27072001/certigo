import {
  lstat,
  mkdir,
  readFile,
  readdir,
  writeFile,
} from 'node:fs/promises';
import { dirname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  canonicalPublicHost,
  validatePublicDomainConfiguration,
} from '../.github/scripts/public-domain-contract.mjs';

const supportEmail = 'gabriel.chambaud@icloud.com';
const associationFileNames = [
  'apple-app-site-association',
  'assetlinks.json',
];
const expectedAssociationRoutes = [
  ['/learn/*/*', 'Authenticated lesson route'],
  ['/assignments/*', 'Authenticated assignment route'],
  ['/achievements/*', 'Authenticated achievement route'],
  ['/account-deletion', 'Public account-deletion route'],
];
const expectedArtifactPaths = [
  '.nojekyll',
  '.well-known/apple-app-site-association',
  '.well-known/assetlinks.json',
  'CNAME',
  'account-deletion/index.html',
  'privacy-policy/index.html',
];
const appIdPattern =
  /^(?<teamId>[A-Z0-9]{10})\.(?<bundleId>[A-Za-z0-9]+(?:[.-][A-Za-z0-9]+)+)$/;
const bundleIdPattern = /^[A-Za-z0-9]+(?:[.-][A-Za-z0-9]+)+$/;
const fingerprintPattern = /^(?:[0-9A-F]{2}:){31}[0-9A-F]{2}$/;
const maximumAssociationBytes = 32 * 1024;

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

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function requireObjectKeys(value, expected, label) {
  if (!isObject(value)) {
    throw new Error(`${label} must be a JSON object.`);
  }
  const actual = Object.keys(value).sort();
  const wanted = [...expected].sort();
  if (actual.length !== wanted.length || actual.some((key, index) => key !== wanted[index])) {
    throw new Error(`${label} contains unexpected public fields.`);
  }
}

function parseStableJson(content, fileName) {
  if (Buffer.byteLength(content, 'utf8') > maximumAssociationBytes) {
    throw new Error(`${fileName} exceeds the public association size limit.`);
  }

  let value;
  try {
    value = JSON.parse(content);
  } catch {
    throw new Error(`${fileName} must contain valid JSON.`);
  }
  if (`${JSON.stringify(value, null, 2)}\n` !== content) {
    throw new Error(`${fileName} must use the deterministic generator format.`);
  }
  return value;
}

function normalizeGeneratedJson(content, fileName) {
  const normalized = content.replaceAll('\r\n', '\n');
  if (normalized.includes('\r')) {
    throw new Error(`${fileName} contains non-canonical line endings.`);
  }
  return normalized;
}

function validateAppleAssociation(content) {
  const apple = parseStableJson(content, 'apple-app-site-association');
  requireObjectKeys(apple, ['applinks'], 'apple-app-site-association');
  requireObjectKeys(apple.applinks, ['details'], 'apple-app-site-association.applinks');
  if (!Array.isArray(apple.applinks.details) || apple.applinks.details.length !== 1) {
    throw new Error('apple-app-site-association must contain one application detail.');
  }

  const detail = apple.applinks.details[0];
  requireObjectKeys(detail, ['appIDs', 'components'], 'apple-app-site-association detail');
  if (!Array.isArray(detail.appIDs) || detail.appIDs.length !== 1) {
    throw new Error('apple-app-site-association must contain one application identifier.');
  }
  const match = typeof detail.appIDs[0] === 'string'
    ? appIdPattern.exec(detail.appIDs[0])
    : null;
  if (!match?.groups) {
    throw new Error('apple-app-site-association contains an invalid application identifier.');
  }
  if (
    !Array.isArray(detail.components)
    || detail.components.length !== expectedAssociationRoutes.length
  ) {
    throw new Error('apple-app-site-association routes do not match the root-domain contract.');
  }
  for (const [index, [route, comment]] of expectedAssociationRoutes.entries()) {
    const component = detail.components[index];
    requireObjectKeys(component, ['/', 'comment'], `apple-app-site-association component ${index}`);
    if (component['/'] !== route || component.comment !== comment) {
      throw new Error('apple-app-site-association routes do not match the root-domain contract.');
    }
  }
  return match.groups.bundleId;
}

function validateAndroidAssociation(content, expectedBundleId) {
  const android = parseStableJson(content, 'assetlinks.json');
  if (!Array.isArray(android) || android.length !== 1) {
    throw new Error('assetlinks.json must contain one application association.');
  }

  const statement = android[0];
  requireObjectKeys(statement, ['relation', 'target'], 'assetlinks.json statement');
  if (
    !Array.isArray(statement.relation)
    || statement.relation.length !== 1
    || statement.relation[0] !== 'delegate_permission/common.handle_all_urls'
  ) {
    throw new Error('assetlinks.json contains an unexpected relation.');
  }

  requireObjectKeys(
    statement.target,
    ['namespace', 'package_name', 'sha256_cert_fingerprints'],
    'assetlinks.json target',
  );
  const {
    package_name: packageName,
    sha256_cert_fingerprints: fingerprints,
  } = statement.target;
  if (
    statement.target.namespace !== 'android_app'
    || typeof packageName !== 'string'
    || !bundleIdPattern.test(packageName)
    || packageName !== expectedBundleId
  ) {
    throw new Error('assetlinks.json application identifier does not match the Apple association.');
  }
  if (
    !Array.isArray(fingerprints)
    || fingerprints.length === 0
    || fingerprints.some((fingerprint) => !fingerprintPattern.test(fingerprint))
    || new Set(fingerprints).size !== fingerprints.length
  ) {
    throw new Error('assetlinks.json requires unique verified SHA-256 fingerprints.');
  }
}

async function readAssociationFiles(associationSource) {
  if (typeof associationSource !== 'string' || associationSource.length === 0) {
    throw new Error('A generated association source is required before public Pages activation.');
  }

  let sourceStats;
  try {
    sourceStats = await lstat(associationSource);
  } catch (error) {
    if (error?.code === 'ENOENT') {
      throw new Error('The generated association source does not exist.');
    }
    throw error;
  }
  if (!sourceStats.isDirectory() || sourceStats.isSymbolicLink()) {
    throw new Error('The generated association source must be a real directory.');
  }

  const entries = await readdir(associationSource, { withFileTypes: true });
  const actualNames = entries.map((entry) => entry.name).sort();
  if (
    actualNames.length !== associationFileNames.length
    || actualNames.some((name, index) => name !== associationFileNames[index])
  ) {
    throw new Error('The association source must contain only the two public association files.');
  }
  if (entries.some((entry) => !entry.isFile() || entry.isSymbolicLink())) {
    throw new Error('Public association inputs must be regular files.');
  }

  const apple = normalizeGeneratedJson(
    await readFile(join(associationSource, associationFileNames[0]), 'utf8'),
    associationFileNames[0],
  );
  const android = normalizeGeneratedJson(
    await readFile(join(associationSource, associationFileNames[1]), 'utf8'),
    associationFileNames[1],
  );
  const bundleId = validateAppleAssociation(apple);
  validateAndroidAssociation(android, bundleId);
  return { apple, android };
}

async function ensureEmptyOutput(output) {
  let outputStats;
  try {
    outputStats = await lstat(output);
  } catch (error) {
    if (error?.code === 'ENOENT') {
      return;
    }
    throw error;
  }
  if (!outputStats.isDirectory() || outputStats.isSymbolicLink()) {
    throw new Error('The public Pages output must be a real directory.');
  }
  if ((await readdir(output)).length > 0) {
    throw new Error('The public Pages output must be empty to prevent stale or private content.');
  }
}

async function listArtifactFiles(directory, root = directory) {
  const files = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isSymbolicLink()) {
      throw new Error('The public Pages artifact must not contain symbolic links.');
    }
    if (entry.isDirectory()) {
      files.push(...await listArtifactFiles(path, root));
    } else if (entry.isFile()) {
      files.push(relative(root, path).split(sep).join('/'));
    } else {
      throw new Error('The public Pages artifact may contain only directories and regular files.');
    }
  }
  return files.sort();
}

export async function validatePublicArtifact(output) {
  const outputStats = await lstat(output);
  if (!outputStats.isDirectory() || outputStats.isSymbolicLink()) {
    throw new Error('The public Pages artifact must be a real directory.');
  }
  const actualPaths = await listArtifactFiles(output);
  if (
    actualPaths.length !== expectedArtifactPaths.length
    || actualPaths.some((path, index) => path !== expectedArtifactPaths[index])
  ) {
    throw new Error('The public Pages artifact contains an unexpected path.');
  }
  if (await readFile(join(output, 'CNAME'), 'utf8') !== `${canonicalPublicHost}\n`) {
    throw new Error('The public Pages CNAME does not match the canonical host.');
  }
  if (await readFile(join(output, '.nojekyll'), 'utf8') !== '') {
    throw new Error('The public Pages .nojekyll marker must be empty.');
  }
}

export async function buildPublicPages({
  root,
  output,
  associationSource,
  publicWebOrigin,
  publicDomainVerified,
  appleCiamDomainReconfigured,
}) {
  const publicDomain = validatePublicDomainConfiguration({
    environment: 'prod',
    feature: 'link-associations',
    publicWebOrigin,
    publicDomainVerified,
    appleCiamDomainReconfigured,
  });
  const privacy = await readFile(resolve(root, 'docs/legal/privacy-policy.md'), 'utf8');
  const deletion = await readFile(resolve(root, 'docs/legal/account-deletion.md'), 'utf8');
  const associations = await readAssociationFiles(associationSource);
  await ensureEmptyOutput(output);
  const mailto = `mailto:${supportEmail}?subject=${encodeURIComponent('Suppression de compte Certigo')}`;

  const privacyPath = resolve(output, 'privacy-policy/index.html');
  const deletionPath = resolve(output, 'account-deletion/index.html');
  const applePath = resolve(output, '.well-known/apple-app-site-association');
  const androidPath = resolve(output, '.well-known/assetlinks.json');
  await mkdir(dirname(privacyPath), { recursive: true });
  await mkdir(dirname(deletionPath), { recursive: true });
  await mkdir(dirname(applePath), { recursive: true });

  await writeFile(resolve(output, 'CNAME'), `${canonicalPublicHost}\n`, 'utf8');
  await writeFile(resolve(output, '.nojekyll'), '', 'utf8');
  await writeFile(applePath, associations.apple, 'utf8');
  await writeFile(androidPath, associations.android, 'utf8');
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
  await validatePublicArtifact(output);
}

function commandLineOptions(args) {
  const options = {
    associationSource: '',
    output: '_site',
  };
  for (let index = 0; index < args.length; index += 2) {
    const option = args[index];
    const value = args[index + 1];
    if (
      !['--association-source', '--output'].includes(option)
      || typeof value !== 'string'
      || value.length === 0
      || value.startsWith('--')
    ) {
      throw new Error(
        'Usage: build_public_pages.mjs [--output <directory>] '
        + '--association-source <directory>',
      );
    }
    if (option === '--association-source') {
      options.associationSource = value;
    } else {
      options.output = value;
    }
  }
  return options;
}

const currentFile = fileURLToPath(import.meta.url);
if (process.argv[1] && resolve(process.argv[1]) === currentFile) {
  const { associationSource, output } = commandLineOptions(process.argv.slice(2));
  await buildPublicPages({
    root: process.cwd(),
    output: resolve(output),
    associationSource: associationSource ? resolve(associationSource) : '',
    publicWebOrigin: process.env.PUBLIC_WEB_ORIGIN,
    publicDomainVerified: process.env.PUBLIC_DOMAIN_VERIFIED,
    appleCiamDomainReconfigured: process.env.APPLE_CIAM_DOMAIN_RECONFIGURED,
  });
}
