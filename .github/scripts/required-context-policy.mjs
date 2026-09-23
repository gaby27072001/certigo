import fs from 'node:fs';
import path from 'node:path';
import { parseDocument } from 'yaml';
import { loadCandidateManifest, listProposalFiles } from './workflow-manifest-consistency.mjs';
import { readRegularRepositoryFile } from './workflow-semantic-fingerprint.mjs';

// Un contexte requis que plus aucun job ne publie bloque `main` pour de bon : sous
// `enforce_admins`, chaque PR — y compris celle qui réparerait — attendrait indéfiniment un
// contrôle que plus rien ne produit. La pré-approbation rend les workflows modifiables : cette
// règle, possédée par la base, empêche qu'un renommage de job, un retrait de déclencheur ou un
// filtre de chemins au niveau du workflow y parviennent (#497).
const protectionRelativePath = '.github/branch-protection-main.json';
const requiredPullRequestTypes = Object.freeze(['opened', 'synchronize', 'reopened']);
const excludingFilters = Object.freeze(['paths', 'paths-ignore', 'branches-ignore', 'tags', 'tags-ignore']);

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

export function readRequiredContexts(text) {
  const protection = JSON.parse(text);
  const contexts = protection?.required_status_checks?.contexts;
  if (!Array.isArray(contexts) || contexts.some((context) => typeof context !== 'string')) {
    throw new Error('required_status_checks.contexts must be a list of strings');
  }
  return contexts;
}

function parseWorkflow(text) {
  const document = parseDocument(text, {
    merge: false,
    strict: true,
    stringKeys: true,
    uniqueKeys: true,
  });
  if (document.errors.length > 0) {
    return null;
  }
  try {
    return document.toJS({ maxAliasCount: 0 });
  } catch {
    return null;
  }
}

// Le contrôle n'est publié sur toute PR vers `main` que si `pull_request_target` n'est pas filtré
// au niveau du workflow (les filtres de chemins se font au niveau du job, voir ci-mobile.yml).
function reportsOnEveryPullRequest(triggers) {
  if (triggers === 'pull_request_target') {
    return true;
  }
  if (Array.isArray(triggers)) {
    return triggers.includes('pull_request_target');
  }
  if (!isPlainObject(triggers) || !Object.hasOwn(triggers, 'pull_request_target')) {
    return false;
  }
  const config = triggers.pull_request_target;
  if (config === null) {
    return true;
  }
  if (!isPlainObject(config) || excludingFilters.some((key) => Object.hasOwn(config, key))) {
    return false;
  }
  if (Object.hasOwn(config, 'branches')) {
    // Filtres ordonnés à motifs et négations (`[main, '!main']` exclut main) : seule la forme
    // exacte `[main]` est acceptée, pour ne jamais avoir à rejouer la sémantique de GitHub.
    const branches = Array.isArray(config.branches) ? config.branches : [config.branches];
    if (branches.length !== 1 || branches[0] !== 'main') {
      return false;
    }
  }
  if (Object.hasOwn(config, 'types')) {
    const types = Array.isArray(config.types) ? config.types : [config.types];
    if (!requiredPullRequestTypes.every((type) => types.includes(type))) {
      return false;
    }
  }
  return true;
}

// Un contexte agrégé stable : job ordinaire nommé exactement, sans matrice ni appel de workflow
// réutilisable, dont le nom publié changerait (voir branch-protection-main.json).
export function producedContexts(workflows) {
  const produced = new Set();
  for (const text of workflows.values()) {
    const workflow = parseWorkflow(text);
    if (!workflow || !reportsOnEveryPullRequest(workflow.on) || !isPlainObject(workflow.jobs)) {
      continue;
    }
    for (const job of Object.values(workflow.jobs)) {
      if (
        isPlainObject(job)
        && typeof job.name === 'string'
        && Object.hasOwn(job, 'runs-on')
        && !Object.hasOwn(job, 'uses')
        && !Object.hasOwn(job, 'strategy')
      ) {
        produced.add(job.name);
      }
    }
  }
  return produced;
}

export function missingRequiredContexts(contexts, workflows) {
  const produced = producedContexts(workflows);
  return contexts.filter((context) => !produced.has(context));
}

function describe(missing, label) {
  return missing.map((context) => (
    `${label}: required status check "${context}" would no longer be reported by an unfiltered `
    + 'pull_request_target job named exactly so, without matrix or reusable call; under '
    + 'enforce_admins every later pull request would wait for it forever (#497)'
  ));
}

function readActiveWorkflows(root) {
  const workflows = new Map();
  const errors = [];
  const directory = path.join(root, '.github', 'workflows');
  let entries;
  try {
    entries = fs.readdirSync(directory, { withFileTypes: true });
  } catch (error) {
    return { workflows, errors: [`.github/workflows: ${error.message}`] };
  }
  for (const entry of entries) {
    if (!/\.ya?ml$/.test(entry.name)) {
      continue;
    }
    const file = readRegularRepositoryFile(root, `.github/workflows/${entry.name}`);
    if (file.error) {
      errors.push(file.error);
    } else if (file.exists) {
      workflows.set(entry.name, file.content);
    }
  }
  return { workflows, errors };
}

function contextsFrom(root, relativePath, source) {
  const file = readRegularRepositoryFile(root, relativePath);
  if (!file.exists || file.error) {
    throw new Error(`${source} ${relativePath}: ${file.error ?? 'missing'}`);
  }
  return readRequiredContexts(file.content);
}

// Juge l'état présent du candidat, puis chaque état futur qu'une de ses pré-approbations en
// attente produirait : une approbation qui ferait disparaître un contexte requis est refusée dès
// la PR A, avant de pouvoir être consommée.
export function validateRequiredContexts(root, { trustedRoot }) {
  let contexts;
  try {
    contexts = [...new Set([
      ...contextsFrom(trustedRoot, protectionRelativePath, 'trusted'),
      ...contextsFrom(root, protectionRelativePath, 'candidate'),
    ])];
  } catch (error) {
    return [`required status checks: ${error.message}`];
  }
  const active = readActiveWorkflows(root);
  const errors = [...active.errors];
  errors.push(...describe(missingRequiredContexts(contexts, active.workflows), '.github/workflows'));

  const candidate = loadCandidateManifest(root);
  const pending = candidate.errors.length === 0 ? candidate.manifest.preApproved : {};
  const proposals = new Map(listProposalFiles(root).files.map((file) => [file.name, file]));
  for (const [workflowPath, entry] of Object.entries(pending)) {
    const name = path.posix.basename(workflowPath);
    const future = new Map(active.workflows);
    if (entry.digest === null) {
      future.delete(name);
    } else if (proposals.has(name)) {
      future.set(name, proposals.get(name).content);
    } else {
      continue;
    }
    errors.push(...describe(
      missingRequiredContexts(contexts, future),
      `pre-approval of ${workflowPath}`,
    ));
  }
  return errors;
}
