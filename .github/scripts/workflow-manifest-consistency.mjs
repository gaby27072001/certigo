import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  addUtcDays,
  computeWorkflowStates,
  consumePreApprovals,
  fingerprintWorkflow,
  loadWorkflowManifest,
  maxPreApprovalDays,
  proposalDirectory,
  proposalRelativePath,
  readRegularRepositoryFile,
  renderWorkflowManifest,
  reviewedWorkflowDigest,
  utcDate,
  validateWorkflowManifest,
} from './workflow-semantic-fingerprint.mjs';

export const manifestRelativePath = '.github/scripts/workflow-semantic-manifest.json';
export const goldenTestRelativePath = '.github/scripts/account-deletion-cosmos-policy.test.mjs';
const trustedManifestPath = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  'workflow-semantic-manifest.json',
);
const goldenDeclaration = /^const manifestGoldenDigest = '([0-9a-f]{64})';\r?$/gmu;
const maxDriftDetails = 6;

// Ces contrôles jugent le `main` que la PR produirait. Le validateur lit le manifeste de la base,
// jamais celui du candidat : sans eux, rien ne vérifiait avant la fusion que le manifeste fusionné
// décrit bien ses propres workflows. Or un `main` incohérent refuse ensuite toute PR, y compris
// celle qui le réparerait, sur un contexte requis et sous `enforce_admins` (#497).
const consequence = 'Merging this would leave main with a manifest that disagrees with its own '
  + 'tree, and every later pull request, including the one meant to repair it, would fail the '
  + 'required check Validate workflow YAML (#497).';
const remedy = 'To pre-approve a future workflow change, run '
  + '`node .github/scripts/generate-workflow-semantic-manifest.mjs --pre-approve`, then restore '
  + 'the workflow files; to land a pre-approved change, commit it together with the output of '
  + '`--write`. `--check` reproduces this verification locally. See '
  + 'docs/runbooks/CI_WORKFLOW_CHANGES.md.';

export function extractManifestGoldenDigest(text) {
  const declarations = [...text.matchAll(goldenDeclaration)];
  return declarations.length === 1 ? declarations[0][1] : null;
}

function valueAt(entries, workflowPath) {
  return Object.hasOwn(entries, workflowPath) ? entries[workflowPath] : null;
}

function shortDigest(value) {
  return value === null ? 'absent' : value.slice(0, 12);
}

function describeDrift(manifest, treeStates) {
  const details = [];
  const reported = new Set();
  for (const state of ['A', 'B', 'C']) {
    const reviewed = manifest.states[state];
    const actual = treeStates[state];
    const paths = new Set([...Object.keys(reviewed), ...Object.keys(actual)]);
    for (const workflowPath of [...paths].sort()) {
      const expected = valueAt(reviewed, workflowPath);
      const found = valueAt(actual, workflowPath);
      if (expected !== found && !reported.has(workflowPath)) {
        reported.add(workflowPath);
        details.push(
          `${workflowPath}: manifest states say ${shortDigest(expected)}, `
          + `this branch has ${shortDigest(found)}`,
        );
      }
    }
  }
  for (const [workflowPath, entry] of Object.entries(manifest.preApproved)) {
    if (entry.digest === reviewedWorkflowDigest(treeStates, workflowPath)) {
      details.push(`${workflowPath}: its pre-approval has landed and must be consumed with --write`);
    }
  }
  if (details.length === 0) {
    details.push('the file differs from the canonical rendering of the generator');
  }
  if (details.length > maxDriftDetails) {
    const hidden = details.length - maxDriftDetails;
    return [...details.slice(0, maxDriftDetails), `and ${hidden} more`].join('; ');
  }
  return details.join('; ');
}

export function loadCandidateManifest(root) {
  const file = readRegularRepositoryFile(root, manifestRelativePath);
  if (!file.exists) {
    return { errors: [`candidate workflow manifest: ${manifestRelativePath} is missing`] };
  }
  if (file.error) {
    return { errors: [`candidate workflow manifest: ${file.error}`] };
  }
  let manifest;
  try {
    manifest = JSON.parse(file.content);
  } catch (error) {
    return { errors: [`candidate workflow manifest: invalid JSON (${error.message})`] };
  }
  const errors = validateWorkflowManifest(manifest).map((error) => `candidate ${error}`);
  return { text: file.content, bytes: file.bytes, manifest, errors };
}

// Liste les propositions de workflows : fichiers réguliers uniquement, jamais de lien symbolique,
// car l'arbre lu peut être celui d'une PR non fiable.
export function listProposalFiles(root) {
  const directory = path.join(root, ...proposalDirectory.split('/'));
  let stat;
  try {
    stat = fs.lstatSync(directory);
  } catch (error) {
    return error.code === 'ENOENT'
      ? { files: [], errors: [] }
      : { files: [], errors: [`${proposalDirectory}: ${error.message}`] };
  }
  if (
    !stat.isDirectory()
    || stat.isSymbolicLink()
    || fs.realpathSync(directory) !== path.resolve(directory)
  ) {
    return { files: [], errors: [`${proposalDirectory} must be a real non-symlink directory`] };
  }
  const files = [];
  const errors = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const relativePath = `${proposalDirectory}/${entry.name}`;
    if (!/\.ya?ml$/.test(entry.name)) {
      errors.push(`${relativePath}: only workflow proposals (*.yml, *.yaml) belong here`);
      continue;
    }
    const file = readRegularRepositoryFile(root, relativePath);
    if (file.error) {
      errors.push(file.error);
      continue;
    }
    files.push({ name: entry.name, relativePath, content: file.content });
  }
  files.sort((left, right) => (left.name < right.name ? -1 : left.name > right.name ? 1 : 0));
  return { files, errors };
}

// Une pré-approbation n'est vérifiable que si la PR montre le workflow futur en entier : chaque
// empreinte en attente doit correspondre, octet sémantique pour octet, à sa proposition.
function validateProposals(root, pending) {
  const errors = [];
  const listing = listProposalFiles(root);
  errors.push(...listing.errors);
  const proposals = new Map(listing.files.map((file) => [file.name, file]));
  const expectedNames = new Set();
  for (const [workflowPath, entry] of Object.entries(pending)) {
    const relativePath = proposalRelativePath(workflowPath);
    const name = path.posix.basename(relativePath);
    const proposal = proposals.get(name);
    if (entry.digest === null) {
      if (proposal) {
        errors.push(
          `${relativePath}: the pre-approval for ${workflowPath} approves a removal and must `
          + 'not carry a proposal',
        );
      }
      continue;
    }
    expectedNames.add(name);
    if (!proposal) {
      errors.push(
        `${relativePath}: missing proposal for the pre-approval of ${workflowPath}; a `
        + 'pre-approval must show the exact future workflow, not only its digest',
      );
      continue;
    }
    const result = fingerprintWorkflow(workflowPath, proposal.content);
    if (result.errors.length > 0) {
      errors.push(...result.errors.map((error) => `${relativePath}: ${error}`));
    } else if (result.digest !== entry.digest) {
      errors.push(
        `${relativePath}: proposal hashes to ${result.digest} but the pre-approval of `
        + `${workflowPath} approves ${entry.digest}`,
      );
    }
  }
  for (const name of proposals.keys()) {
    if (!expectedNames.has(name)) {
      errors.push(
        `${proposalDirectory}/${name}: orphan proposal without a pending pre-approval; a landed `
        + 'or withdrawn pre-approval must delete its proposal',
      );
    }
  }
  return errors;
}

// Vérifie, avec le code de la base, que le candidat laisserait `main` cohérent : manifeste valide,
// `states` égaux aux empreintes de ses propres workflows, pré-approbations encore en attente et
// adossées à leur proposition, golden digest aligné. Indépendant de l'heure par construction.
export function validateCandidateWorkflowManifest(root) {
  const candidate = loadCandidateManifest(root);
  if (candidate.errors.length > 0) {
    return candidate.errors.map((error) => `${error}. ${consequence}`);
  }
  const tree = computeWorkflowStates(root);
  if (tree.errors.length > 0) {
    return tree.errors.map((error) => `candidate workflow tree: ${error}`);
  }

  const errors = [];
  const pending = consumePreApprovals(candidate.manifest.preApproved, tree.states);
  const canonical = renderWorkflowManifest({ states: tree.states, preApproved: pending });
  if (candidate.text !== canonical) {
    errors.push(
      'candidate workflow manifest does not describe the workflows of this branch '
      + `(${describeDrift(candidate.manifest, tree.states)}). ${consequence} ${remedy}`,
    );
  }
  errors.push(...validateProposals(root, pending).map((error) => `candidate ${error}. ${remedy}`));

  const goldenFile = readRegularRepositoryFile(root, goldenTestRelativePath);
  if (!goldenFile.exists || goldenFile.error) {
    errors.push(
      'candidate manifest golden digest: '
      + `${goldenFile.error ?? `${goldenTestRelativePath} is missing`}. ${consequence}`,
    );
    return errors;
  }
  const golden = extractManifestGoldenDigest(goldenFile.content);
  const actual = crypto.createHash('sha256').update(candidate.bytes).digest('hex');
  if (golden === null) {
    errors.push(
      `candidate manifest golden digest: ${goldenTestRelativePath} must declare exactly one `
      + `manifestGoldenDigest. ${consequence}`,
    );
  } else if (golden !== actual) {
    errors.push(
      `candidate manifest golden digest: manifestGoldenDigest is ${golden} but `
      + `${manifestRelativePath} hashes to ${actual}. ${consequence}`,
    );
  }
  return errors;
}

// Seules les pré-approbations que la PR ajoute ou modifie sont bornées dans le temps : une PR
// qui hérite du manifeste de `main` sans y toucher n'est jamais jugée sur l'heure qu'il est.
export function validatePreApprovalChanges(
  root,
  { trustedManifestPath: basePath = trustedManifestPath, now = new Date() } = {},
) {
  const candidate = loadCandidateManifest(root);
  if (candidate.errors.length > 0) {
    return [];
  }
  let trusted;
  try {
    trusted = loadWorkflowManifest(basePath);
  } catch {
    return [];
  }
  if (trusted.errors.length > 0) {
    return [];
  }
  const errors = [];
  const today = utcDate(now);
  const latest = addUtcDays(now, maxPreApprovalDays);
  for (const [workflowPath, entry] of Object.entries(candidate.manifest.preApproved)) {
    const inherited = valueAt(trusted.manifest.preApproved, workflowPath);
    if (
      inherited
      && inherited.digest === entry.digest
      && inherited.expires === entry.expires
    ) {
      continue;
    }
    if (entry.expires < today || entry.expires > latest) {
      errors.push(
        `${manifestRelativePath}: the pre-approval of ${workflowPath} added or changed by this `
        + `pull request must expire between ${today} and ${latest} (UTC), got ${entry.expires}`,
      );
    }
  }
  return errors;
}

// Les tests trusted de `.github/scripts` tournent sur l'arbre de la base à chaque PR, jamais sur
// la PR qui les modifie. Un workflow retiré alors qu'un script le cite encore ferait échouer
// `main` sur ses propres tests après la fusion : c'est le blocage de #497 sous une autre forme.
export function validateWorkflowRemovals(
  root,
  { trustedManifestPath: basePath = trustedManifestPath } = {},
) {
  const candidate = loadCandidateManifest(root);
  const tree = computeWorkflowStates(root);
  if (candidate.errors.length > 0 || tree.errors.length > 0) {
    return [];
  }
  let trusted;
  try {
    trusted = loadWorkflowManifest(basePath);
  } catch {
    return [];
  }
  if (trusted.errors.length > 0) {
    return [];
  }
  const removed = new Set();
  for (const workflowPath of Object.keys(trusted.manifest.states.B)) {
    if (!Object.hasOwn(tree.states.B, workflowPath)) {
      removed.add(path.posix.basename(workflowPath));
    }
  }
  for (const [workflowPath, entry] of Object.entries(candidate.manifest.preApproved)) {
    if (entry.digest === null) {
      removed.add(path.posix.basename(workflowPath));
    }
  }
  if (removed.size === 0) {
    return [];
  }
  const errors = [];
  const scripts = path.join(root, '.github', 'scripts');
  let entries;
  try {
    entries = fs.readdirSync(scripts, { withFileTypes: true });
  } catch {
    return [];
  }
  for (const entry of entries) {
    if (!/\.m?js$/.test(entry.name)) {
      continue;
    }
    const relativePath = `.github/scripts/${entry.name}`;
    const file = readRegularRepositoryFile(root, relativePath);
    if (!file.exists || file.error) {
      continue;
    }
    for (const name of [...removed].sort()) {
      if (file.content.includes(name)) {
        errors.push(
          `${relativePath} still references ${name}, whose removal this pull request lands or `
          + 'pre-approves: after the merge, the trusted tests of main would fail for every pull '
          + 'request (#497). Remove the reference in the same pull request.',
        );
      }
    }
  }
  return errors;
}
