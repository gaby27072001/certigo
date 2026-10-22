import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { isAlias, isMap, isPair, isScalar, isSeq, parseDocument } from 'yaml';

export const canonicalizationId = 'certigo-workflow-semantic-v1';
export const manifestSchemaVersion = 2;
export const legacyWorkflowName = 'test-account-deletion-cosmos.yml';
export const oneShotWorkflowName = 'post-merge-cosmos-account-deletion.yml';
export const lifecycleWorkflowNames = Object.freeze([legacyWorkflowName, oneShotWorkflowName]);
const legacyWorkflowPath = `.github/workflows/${legacyWorkflowName}`;
const oneShotWorkflowPath = `.github/workflows/${oneShotWorkflowName}`;
// Le contenu pré-approuvé vit hors de `.github/workflows/` : GitHub ne l'exécute jamais, et la
// PR de pré-approbation montre ainsi le workflow futur en entier, pas seulement son empreinte.
export const proposalDirectory = '.github/workflows-proposed';
export const defaultPreApprovalDays = 14;
export const maxPreApprovalDays = 30;

const manifestKeys = Object.freeze(['schemaVersion', 'canonicalization', 'states', 'preApproved']);
const preApprovalKeys = Object.freeze(['digest', 'expires']);
const stateNames = Object.freeze(['A', 'B', 'C']);
const digestPattern = /^[0-9a-f]{64}$/;
const datePattern = /^\d{4}-\d{2}-\d{2}$/;
const dayMilliseconds = 24 * 60 * 60 * 1000;

function compareCodeUnits(left, right) {
  return left < right ? -1 : left > right ? 1 : 0;
}

function sortedObject(entries) {
  return Object.fromEntries([...entries].sort(([left], [right]) => compareCodeUnits(left, right)));
}

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

export function utcDate(now) {
  if (!(now instanceof Date) || Number.isNaN(now.getTime())) {
    throw new TypeError('now must be a valid Date');
  }
  return now.toISOString().slice(0, 10);
}

export function addUtcDays(now, days) {
  return utcDate(new Date(Date.parse(`${utcDate(now)}T00:00:00Z`) + days * dayMilliseconds));
}

export function isCalendarDate(value) {
  return typeof value === 'string'
    && datePattern.test(value)
    && !Number.isNaN(Date.parse(`${value}T00:00:00Z`))
    && new Date(`${value}T00:00:00Z`).toISOString().slice(0, 10) === value;
}

// Une pré-approbation reste valable jusqu'à la fin (UTC) du jour `expires` inclus.
export function isPreApprovalActive(entry, now) {
  return utcDate(now) <= entry.expires;
}

export function proposalRelativePath(workflowPath) {
  return `${proposalDirectory}/${path.posix.basename(workflowPath)}`;
}

// Emplacement réel d'un workflow dans un arbre : un workflow Cosmos de cycle de vie peut être
// archivé sous `.github/workflows-disabled/` tout en gardant son chemin canonique.
export function workflowSourceRelativePath(root, workflowPath) {
  const name = path.posix.basename(workflowPath);
  if (
    lifecycleWorkflowNames.includes(name)
    && !fs.existsSync(path.join(root, '.github', 'workflows', name))
  ) {
    return `.github/workflows-disabled/${name}`;
  }
  return workflowPath;
}

// Une empreinte ne doit jamais réunir deux contenus qui s'exécutent différemment. Un retour chariot
// décodé (échappement `\r`) ou une chaîne non NFC sont donc refusés au lieu d'être normalisés :
// `"# a\rcurl x"` est un commentaire bash, `"# a\ncurl x"` exécute `curl`. Les fins de ligne
// physiques du fichier, elles, sont déjà ramenées à LF par le parseur YAML.
function canonicalString(value, label, errors) {
  if (value.includes('\r')) {
    errors.push(`${label}: carriage returns inside YAML strings are forbidden`);
  }
  if (value !== value.normalize('NFC')) {
    errors.push(`${label}: YAML strings must use Unicode NFC`);
  }
  return value;
}

function normalizeScalar(value, label, errors) {
  if (value === null || typeof value === 'boolean') {
    return value;
  }
  if (typeof value === 'string') {
    return canonicalString(value, label, errors);
  }
  if (typeof value === 'number') {
    if (!Number.isSafeInteger(value)) {
      errors.push(`${label}: non-integer or unsafe YAML numbers are forbidden`);
      return null;
    }
    return Object.is(value, -0) ? 0 : value;
  }
  if (typeof value === 'bigint') {
    if (
      value < BigInt(Number.MIN_SAFE_INTEGER)
      || value > BigInt(Number.MAX_SAFE_INTEGER)
    ) {
      errors.push(`${label}: non-integer or unsafe YAML numbers are forbidden`);
      return null;
    }
    return Number(value);
  }
  errors.push(`${label}: unsupported YAML scalar type ${typeof value}`);
  return null;
}

function inspectNode(node, label, errors) {
  if (!node) {
    return;
  }
  if (isAlias(node)) {
    errors.push(`${label}: YAML aliases and merge indirection are forbidden`);
    return;
  }
  if (node.anchor) {
    errors.push(`${label}: YAML anchors are forbidden`);
  }
  if (node.tag) {
    errors.push(`${label}: explicit or custom YAML tags are forbidden`);
  }
  if (isPair(node)) {
    if (!isScalar(node.key) || typeof node.key.value !== 'string') {
      errors.push(`${label}: YAML mapping keys must decode to strings`);
    } else {
      const key = node.key.value;
      if (key === '<<') {
        errors.push(`${label}: YAML merge keys are forbidden`);
      }
      if (key.includes('${{')) {
        errors.push(`${label}: dynamic YAML mapping keys are forbidden`);
      }
    }
    inspectNode(node.key, label, errors);
    inspectNode(node.value, label, errors);
    return;
  }
  if (isMap(node) || isSeq(node)) {
    for (const item of node.items) {
      inspectNode(item, label, errors);
    }
  }
}

function canonicalizeNode(node, label, errors) {
  if (node === null) {
    return null;
  }
  if (isScalar(node)) {
    return normalizeScalar(node.value, label, errors);
  }
  if (isSeq(node)) {
    return node.items.map((item) => canonicalizeNode(item, label, errors));
  }
  if (isMap(node)) {
    const entries = [];
    const normalizedKeys = new Set();
    for (const pair of node.items) {
      if (!isPair(pair) || !isScalar(pair.key) || typeof pair.key.value !== 'string') {
        continue;
      }
      const key = canonicalString(pair.key.value, label, errors);
      if (normalizedKeys.has(key)) {
        errors.push(`${label}: duplicate key after Unicode normalization: ${key}`);
        continue;
      }
      normalizedKeys.add(key);
      entries.push([key, canonicalizeNode(pair.value, label, errors)]);
    }
    entries.sort(([left], [right]) => (
      left < right ? -1 : left > right ? 1 : 0
    ));
    return Object.fromEntries(entries);
  }
  errors.push(`${label}: unsupported YAML node type`);
  return null;
}

export function canonicalWorkflowPath(relativePath) {
  const canonicalPath = relativePath.split(path.sep).join('/');
  if (
    canonicalPath !== path.posix.normalize(canonicalPath)
    || canonicalPath.startsWith('../')
    || path.posix.isAbsolute(canonicalPath)
    || !/^\.github\/workflows\/[^/]+\.ya?ml$/.test(canonicalPath)
  ) {
    throw new Error(`invalid canonical workflow path: ${relativePath}`);
  }
  return canonicalPath.normalize('NFC');
}

export function parseCanonicalWorkflow(content, label) {
  const errors = [];
  const document = parseDocument(content, {
    intAsBigInt: true,
    merge: false,
    strict: true,
    stringKeys: true,
    uniqueKeys: true,
  });
  for (const issue of [...document.errors, ...document.warnings]) {
    errors.push(`${label}: invalid YAML: ${issue.message}`);
  }
  inspectNode(document.contents, label, errors);
  const canonicalValue = canonicalizeNode(document.contents, label, errors);
  if (errors.length > 0) {
    return { errors, value: null, serialized: null };
  }
  return {
    errors,
    value: document.toJS({ maxAliasCount: 0 }),
    serialized: JSON.stringify(canonicalValue),
  };
}

export function fingerprintWorkflow(canonicalPath, content) {
  const normalizedPath = canonicalWorkflowPath(canonicalPath);
  const parsed = parseCanonicalWorkflow(content, normalizedPath);
  if (parsed.errors.length > 0) {
    return { ...parsed, digest: null };
  }
  return {
    ...parsed,
    digest: crypto
      .createHash('sha256')
      .update(normalizedPath)
      .update('\0')
      .update(parsed.serialized)
      .digest('hex'),
  };
}

function isLifecyclePath(workflowPath) {
  return lifecycleWorkflowNames.includes(path.posix.basename(workflowPath));
}

function validateWorkflowPath(workflowPath, errors) {
  try {
    if (canonicalWorkflowPath(workflowPath) !== workflowPath) {
      errors.push(`workflow semantic manifest: non-canonical path ${workflowPath}`);
      return false;
    }
  } catch {
    errors.push(`workflow semantic manifest: invalid path ${workflowPath}`);
    return false;
  }
  return true;
}

function validateStates(states, errors) {
  if (
    !isPlainObject(states)
    || JSON.stringify(Object.keys(states)) !== JSON.stringify(stateNames)
  ) {
    errors.push('workflow semantic manifest: states must be exactly A, B, and C');
    return false;
  }
  let valid = true;
  for (const state of stateNames) {
    const entries = states[state];
    if (!isPlainObject(entries)) {
      errors.push(`workflow semantic manifest: state ${state} must be a path map`);
      valid = false;
      continue;
    }
    const paths = Object.keys(entries);
    if (JSON.stringify(paths) !== JSON.stringify([...paths].sort(compareCodeUnits))) {
      errors.push(`workflow semantic manifest: state ${state} paths must be sorted`);
      valid = false;
    }
    for (const [workflowPath, digest] of Object.entries(entries)) {
      valid = validateWorkflowPath(workflowPath, errors) && valid;
      if (typeof digest !== 'string' || !digestPattern.test(digest)) {
        errors.push(`workflow semantic manifest: invalid SHA-256 for ${workflowPath}`);
        valid = false;
      }
    }
  }
  if (!valid) {
    return false;
  }
  // Les trois états partagent la même baseline : seul le workflow Cosmos de cycle de vie diffère.
  // Une pré-approbation porte donc sur un chemin, quel que soit l'état de migration.
  const baseline = JSON.stringify(states.B);
  const withoutPath = (entries, excluded) => JSON.stringify(Object.fromEntries(
    Object.entries(entries).filter(([workflowPath]) => workflowPath !== excluded),
  ));
  if (
    Object.keys(states.B).some(isLifecyclePath)
    || !Object.hasOwn(states.A, legacyWorkflowPath)
    || Object.hasOwn(states.A, oneShotWorkflowPath)
    || withoutPath(states.A, legacyWorkflowPath) !== baseline
    || !Object.hasOwn(states.C, oneShotWorkflowPath)
    || Object.hasOwn(states.C, legacyWorkflowPath)
    || withoutPath(states.C, oneShotWorkflowPath) !== baseline
  ) {
    errors.push(
      'workflow semantic manifest: states A and C must equal the state B baseline plus exactly '
      + 'their own lifecycle workflow',
    );
    return false;
  }
  return true;
}

// Empreinte revue d'un chemin : celle de son propre état pour les deux workflows Cosmos de cycle
// de vie (A pour le legacy, C pour le one-shot), celle de la baseline B pour tous les autres, et
// `null` quand le chemin n'est pas revu (workflow absent).
export function reviewedWorkflowDigest(states, workflowPath) {
  const state = workflowPath === legacyWorkflowPath
    ? 'A'
    : workflowPath === oneShotWorkflowPath ? 'C' : 'B';
  return Object.hasOwn(states[state], workflowPath) ? states[state][workflowPath] : null;
}

function validatePreApproved(preApproved, states, errors) {
  if (!isPlainObject(preApproved)) {
    errors.push('workflow semantic manifest: preApproved must be a path map');
    return;
  }
  const paths = Object.keys(preApproved);
  if (JSON.stringify(paths) !== JSON.stringify([...paths].sort(compareCodeUnits))) {
    errors.push('workflow semantic manifest: preApproved paths must be sorted');
  }
  for (const [workflowPath, entry] of Object.entries(preApproved)) {
    if (!validateWorkflowPath(workflowPath, errors)) {
      continue;
    }
    if (
      !isPlainObject(entry)
      || JSON.stringify(Object.keys(entry)) !== JSON.stringify(preApprovalKeys)
    ) {
      errors.push(
        `workflow semantic manifest: pre-approval for ${workflowPath} must be exactly `
        + '{ "digest", "expires" }',
      );
      continue;
    }
    if (entry.digest !== null && (
      typeof entry.digest !== 'string' || !digestPattern.test(entry.digest)
    )) {
      errors.push(
        `workflow semantic manifest: pre-approval for ${workflowPath} must carry a SHA-256 `
        + 'digest, or null for an approved removal',
      );
    }
    // La présence des workflows Cosmos de cycle de vie relève du contrat A/B/C : on peut en
    // pré-approuver un contenu, jamais le retrait.
    if (entry.digest === null && isLifecyclePath(workflowPath)) {
      errors.push(
        `workflow semantic manifest: ${workflowPath} follows the A/B/C migration contract; its `
        + 'removal cannot be pre-approved',
      );
    }
    if (!isCalendarDate(entry.expires)) {
      errors.push(
        `workflow semantic manifest: pre-approval for ${workflowPath} must expire on a `
        + 'YYYY-MM-DD calendar date',
      );
    }
    if (entry.digest === reviewedWorkflowDigest(states, workflowPath)) {
      errors.push(
        `workflow semantic manifest: pre-approval for ${workflowPath} already matches the reviewed `
        + 'state; a landed pre-approval must be consumed with --write',
      );
    }
  }
}

export function validateWorkflowManifest(manifest) {
  const errors = [];
  if (!isPlainObject(manifest)) {
    errors.push('workflow semantic manifest: top-level contract must match exactly');
    return errors;
  }
  if (
    manifest.schemaVersion !== manifestSchemaVersion
    || manifest.canonicalization !== canonicalizationId
  ) {
    errors.push('workflow semantic manifest: unsupported schema or canonicalization');
    return errors;
  }
  if (JSON.stringify(Object.keys(manifest)) !== JSON.stringify(manifestKeys)) {
    errors.push('workflow semantic manifest: top-level contract must match exactly');
    return errors;
  }
  if (!validateStates(manifest.states, errors)) {
    return errors;
  }
  validatePreApproved(manifest.preApproved, manifest.states, errors);
  return errors;
}

export function loadWorkflowManifest(manifestPath) {
  const raw = fs.readFileSync(manifestPath, 'utf8');
  const manifest = JSON.parse(raw);
  return { manifest, errors: validateWorkflowManifest(manifest) };
}

// Bind reviewed policy reads to the inspected inode; mutable ancestors still require
// a stable checkout because O_NOFOLLOW protects only the final component.
export function readVerifiedRegularFileSync(filePath, expectedStat) {
  const absolutePath = path.resolve(filePath);
  if (!expectedStat.isFile() || expectedStat.isSymbolicLink()) {
    throw new Error('must be a real regular non-symlink file');
  }
  if (fs.realpathSync(absolutePath) !== absolutePath) {
    throw new Error('must resolve to its exact repository path');
  }

  const flags = fs.constants.O_RDONLY
    | (fs.constants.O_NOFOLLOW ?? 0)
    | (fs.constants.O_NONBLOCK ?? 0);
  const descriptor = fs.openSync(absolutePath, flags);
  try {
    const openedStat = fs.fstatSync(descriptor);
    if (
      !openedStat.isFile()
      || openedStat.dev !== expectedStat.dev
      || openedStat.ino !== expectedStat.ino
    ) {
      throw new Error('file changed while opening');
    }
    const currentStat = fs.lstatSync(absolutePath);
    if (
      fs.realpathSync(absolutePath) !== absolutePath
      || !currentStat.isFile()
      || currentStat.isSymbolicLink()
      || currentStat.dev !== expectedStat.dev
      || currentStat.ino !== expectedStat.ino
    ) {
      throw new Error('file path changed while opening');
    }
    return fs.readFileSync(descriptor);
  } finally {
    fs.closeSync(descriptor);
  }
}

// Valide le descripteur avant d'en lire les octets et refuse les liens, parents compris.
// L'arbre peut venir d'une PR non fiable, mais ses parents doivent rester sans autre écrivain :
// les API Node utilisées ne résolvent pas atomiquement tous les composants parents.
// La lecture reste bornée à la taille inspectée (16 MiB maximum), même si le fichier grandit.
export function readRegularRepositoryFile(root, relativePath) {
  const filePath = path.join(root, ...relativePath.split('/'));
  let descriptor;
  try {
    descriptor = fs.openSync(
      filePath,
      fs.constants.O_RDONLY | fs.constants.O_NOFOLLOW | fs.constants.O_NONBLOCK,
    );
    const opened = fs.fstatSync(descriptor);
    const current = fs.lstatSync(filePath);
    if (
      !opened.isFile()
      || !current.isFile()
      || current.isSymbolicLink()
      || opened.dev !== current.dev || opened.ino !== current.ino
    ) {
      throw new Error('must be a real regular non-symlink file matching the opened descriptor');
    }
    if (fs.realpathSync(filePath) !== path.resolve(filePath)) {
      throw new Error('must resolve to its exact repository path');
    }
    if (opened.size > 16 * 1024 * 1024) {
      throw new Error('repository control file exceeds the 16 MiB limit');
    }
    const bytes = Buffer.alloc(opened.size);
    let offset = 0;
    while (offset < bytes.length) {
      const count = fs.readSync(descriptor, bytes, offset, bytes.length - offset, null);
      if (count === 0) {
        throw new Error('file changed while being read');
      }
      offset += count;
    }
    const after = fs.fstatSync(descriptor);
    if (
      after.size !== opened.size
      || after.mtimeMs !== opened.mtimeMs
      || after.ctimeMs !== opened.ctimeMs
    ) {
      throw new Error('file changed while being read');
    }
    return { exists: true, bytes, content: bytes.toString('utf8') };
  } catch (error) {
    if (descriptor === undefined && (error.code === 'ENOENT' || error.code === 'ENOTDIR')) {
      try {
        fs.lstatSync(filePath);
      } catch (inspectionError) {
        if (inspectionError.code === 'ENOENT' || inspectionError.code === 'ENOTDIR') {
          return { exists: false };
        }
        return { exists: true, error: `${relativePath}: ${inspectionError.message}` };
      }
    }
    if (['ELOOP', 'EISDIR', 'ENOENT'].includes(error.code)) {
      return { exists: true, error: `${relativePath}: must be a real regular non-symlink file` };
    }
    return { exists: true, error: `${relativePath}: ${error.message}` };
  } finally {
    if (descriptor !== undefined) {
      fs.closeSync(descriptor);
    }
  }
}

// Calcule les états A/B/C d'un arbre stable, en refusant les liens symboliques présents.
export function computeWorkflowStates(root) {
  const errors = [];
  const workflowsRelative = '.github/workflows';
  const workflows = path.join(root, '.github', 'workflows');
  let directoryStat;
  try {
    directoryStat = fs.lstatSync(workflows);
  } catch (error) {
    return { states: null, errors: [`${workflowsRelative}: ${error.message}`] };
  }
  if (
    !directoryStat.isDirectory()
    || directoryStat.isSymbolicLink()
    || fs.realpathSync(workflows) !== path.resolve(workflows)
  ) {
    return {
      states: null,
      errors: [`${workflowsRelative} must be a real non-symlink directory`],
    };
  }
  const baseline = [];
  for (const entry of fs.readdirSync(workflows, { withFileTypes: true })) {
    if (!/\.ya?ml$/.test(entry.name) || lifecycleWorkflowNames.includes(entry.name)) {
      continue;
    }
    const canonicalPath = `${workflowsRelative}/${entry.name}`;
    const file = readRegularRepositoryFile(root, canonicalPath);
    if (file.error) {
      errors.push(file.error);
      continue;
    }
    const result = fingerprintWorkflow(canonicalPath, file.content);
    errors.push(...result.errors);
    if (result.errors.length === 0) {
      baseline.push([canonicalPath, result.digest]);
    }
  }
  const lifecycle = new Map();
  for (const name of lifecycleWorkflowNames) {
    const active = readRegularRepositoryFile(root, `${workflowsRelative}/${name}`);
    const archived = readRegularRepositoryFile(root, `.github/workflows-disabled/${name}`);
    if (active.error || archived.error) {
      errors.push(...[active.error, archived.error].filter(Boolean));
      continue;
    }
    if (active.exists === archived.exists) {
      errors.push(`${name} must exist in exactly one lifecycle directory`);
      continue;
    }
    const canonicalPath = `${workflowsRelative}/${name}`;
    const result = fingerprintWorkflow(
      canonicalPath,
      active.exists ? active.content : archived.content,
    );
    errors.push(...result.errors);
    if (result.errors.length === 0) {
      lifecycle.set(name, [canonicalPath, result.digest]);
    }
  }
  if (errors.length > 0) {
    return { states: null, errors };
  }
  return {
    states: {
      A: sortedObject([...baseline, lifecycle.get(legacyWorkflowName)]),
      B: sortedObject(baseline),
      C: sortedObject([...baseline, lifecycle.get(oneShotWorkflowName)]),
    },
    errors,
  };
}

// Usage unique : une pré-approbation dont l'empreinte est atteinte par l'arbre est retirée, et
// l'ancienne empreinte, remplacée dans `states`, cesse d'être acceptée. Ne dépend pas de l'heure :
// le contrôle de cohérence d'un candidat ne doit jamais pouvoir rougir par simple passage du temps.
export function consumePreApprovals(preApproved, states) {
  return sortedObject(Object.entries(preApproved ?? {}).filter(
    ([workflowPath, entry]) => entry.digest !== reviewedWorkflowDigest(states, workflowPath),
  ));
}

export function dropExpiredPreApprovals(preApproved, now) {
  return sortedObject(Object.entries(preApproved ?? {}).filter(
    ([, entry]) => isPreApprovalActive(entry, now),
  ));
}

export function renderWorkflowManifest({ states, preApproved }) {
  return `${JSON.stringify({
    schemaVersion: manifestSchemaVersion,
    canonicalization: canonicalizationId,
    states: {
      A: sortedObject(Object.entries(states.A)),
      B: sortedObject(Object.entries(states.B)),
      C: sortedObject(Object.entries(states.C)),
    },
    preApproved: sortedObject(Object.entries(preApproved).map(([workflowPath, entry]) => [
      workflowPath,
      { digest: entry.digest, expires: entry.expires },
    ])),
  }, null, 2)}\n`;
}

// Enregistre comme pré-approbations les écarts entre l'arbre de travail et les états revus, sans
// toucher aux états : `main` continue de décrire exactement ses propres workflows.
export function preApproveWorkflowChanges(manifest, treeStates, { expires }) {
  const errors = [];
  if (!isCalendarDate(expires)) {
    errors.push(`pre-approval expiry must be a YYYY-MM-DD calendar date, got ${expires}`);
  }
  const preApproved = { ...manifest.preApproved };
  const changed = [];
  const paths = new Set(stateNames.flatMap((state) => [
    ...Object.keys(manifest.states[state]),
    ...Object.keys(treeStates[state]),
  ]));
  for (const workflowPath of [...paths].sort(compareCodeUnits)) {
    const reviewed = reviewedWorkflowDigest(manifest.states, workflowPath);
    const proposed = reviewedWorkflowDigest(treeStates, workflowPath);
    if (reviewed === proposed) {
      continue;
    }
    preApproved[workflowPath] = { digest: proposed, expires };
    changed.push({ path: workflowPath, from: reviewed, to: proposed });
  }
  if (changed.length === 0 && errors.length === 0) {
    errors.push(
      'nothing to pre-approve: the working-tree workflows already match the reviewed states',
    );
  }
  return {
    manifest: {
      schemaVersion: manifest.schemaVersion,
      canonicalization: manifest.canonicalization,
      states: manifest.states,
      preApproved: sortedObject(Object.entries(preApproved)),
    },
    changed,
    errors,
  };
}
