import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  addUtcDays,
  computeWorkflowStates,
  consumePreApprovals,
  defaultPreApprovalDays,
  dropExpiredPreApprovals,
  isPreApprovalActive,
  loadWorkflowManifest,
  maxPreApprovalDays,
  preApproveWorkflowChanges,
  proposalDirectory,
  proposalRelativePath,
  renderWorkflowManifest,
  workflowSourceRelativePath,
} from './workflow-semantic-fingerprint.mjs';
import {
  extractManifestGoldenDigest,
  goldenTestRelativePath,
  listProposalFiles,
  manifestRelativePath,
  validateCandidateWorkflowManifest,
} from './workflow-manifest-consistency.mjs';

const modes = ['--write', '--check', '--pre-approve'];
const usage = 'Usage: generate-workflow-semantic-manifest.mjs '
  + `[--write | --check | --pre-approve [--expires-in-days <1-${maxPreApprovalDays}>]]`;

function resolveInRoot(root, relativePath) {
  return path.join(root, ...relativePath.split('/'));
}

function sha256(text) {
  return crypto.createHash('sha256').update(text).digest('hex');
}

function reportGolden(root, serialized, log) {
  const expected = sha256(serialized);
  let current = null;
  try {
    current = extractManifestGoldenDigest(
      fs.readFileSync(resolveInRoot(root, goldenTestRelativePath), 'utf8'),
    );
  } catch {
    current = null;
  }
  if (current === expected) {
    log(`manifestGoldenDigest already matches ${expected}.`);
  } else {
    log(`Update manifestGoldenDigest in ${goldenTestRelativePath} to '${expected}'.`);
  }
}

export function parseGeneratorArguments(argv) {
  let mode = '--print';
  let expiresInDays = defaultPreApprovalDays;
  let expiresGiven = false;
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (modes.includes(argument)) {
      if (mode !== '--print') {
        return { error: `${usage}\n--write, --check and --pre-approve are mutually exclusive` };
      }
      mode = argument;
    } else if (argument === '--expires-in-days' || argument.startsWith('--expires-in-days=')) {
      const value = argument.includes('=') ? argument.slice(argument.indexOf('=') + 1) : argv[++index];
      if (!/^\d+$/.test(value ?? '')) {
        return { error: `${usage}\n--expires-in-days needs a whole number of days` };
      }
      expiresInDays = Number(value);
      expiresGiven = true;
    } else {
      return { error: `${usage}\nunknown argument ${argument}` };
    }
  }
  if (expiresGiven && mode !== '--pre-approve') {
    return { error: `${usage}\n--expires-in-days only applies to --pre-approve` };
  }
  if (expiresInDays < 1 || expiresInDays > maxPreApprovalDays) {
    return { error: `${usage}\na pre-approval lasts between 1 and ${maxPreApprovalDays} days` };
  }
  return { mode, expiresInDays };
}

function removeEmptyProposalDirectory(root) {
  const directory = resolveInRoot(root, proposalDirectory);
  try {
    if (fs.readdirSync(directory).length === 0) {
      fs.rmdirSync(directory);
    }
  } catch {
    // Répertoire absent : rien à nettoyer.
  }
}

export function runManifestGenerator({
  root,
  mode = '--print',
  now = new Date(),
  expiresInDays = defaultPreApprovalDays,
  log = (message) => console.error(message),
  print = (text) => process.stdout.write(text),
}) {
  if (mode === '--check') {
    const errors = validateCandidateWorkflowManifest(root);
    errors.forEach((error) => log(error));
    try {
      const { manifest } = loadWorkflowManifest(resolveInRoot(root, manifestRelativePath));
      for (const [workflowPath, entry] of Object.entries(manifest.preApproved ?? {})) {
        if (!isPreApprovalActive(entry, now)) {
          log(`note: the pre-approval of ${workflowPath} expired on ${entry.expires}; --write drops it`);
        }
      }
    } catch {
      // Les erreurs de lecture sont déjà rapportées par la vérification de cohérence.
    }
    return errors.length === 0 ? 0 : 1;
  }

  const tree = computeWorkflowStates(root);
  if (tree.errors.length > 0) {
    tree.errors.forEach((error) => log(error));
    return 1;
  }
  let committed;
  try {
    committed = loadWorkflowManifest(resolveInRoot(root, manifestRelativePath));
  } catch (error) {
    log(`workflow semantic manifest: ${error.message}`);
    return 1;
  }
  if (committed.errors.length > 0) {
    committed.errors.forEach((error) => log(error));
    return 1;
  }

  if (mode === '--pre-approve') {
    if (
      !Number.isSafeInteger(expiresInDays)
      || expiresInDays < 1
      || expiresInDays > maxPreApprovalDays
    ) {
      log(`a pre-approval lasts between 1 and ${maxPreApprovalDays} days`);
      return 2;
    }
    const expires = addUtcDays(now, expiresInDays);
    const plan = preApproveWorkflowChanges(committed.manifest, tree.states, { expires });
    if (plan.errors.length > 0) {
      plan.errors.forEach((error) => log(error));
      return 1;
    }
    for (const change of plan.changed) {
      const proposal = proposalRelativePath(change.path);
      const proposalPath = resolveInRoot(root, proposal);
      if (change.to === null) {
        fs.rmSync(proposalPath, { force: true });
        log(`pre-approved the removal of ${change.path} until ${expires}`);
        continue;
      }
      fs.mkdirSync(path.dirname(proposalPath), { recursive: true });
      fs.copyFileSync(
        resolveInRoot(root, workflowSourceRelativePath(root, change.path)),
        proposalPath,
      );
      log(
        `pre-approved ${change.path} until ${expires}: ${change.from ?? 'absent'} -> `
        + `${change.to}; exact content recorded in ${proposal}`,
      );
    }
    const serialized = renderWorkflowManifest(plan.manifest);
    fs.writeFileSync(resolveInRoot(root, manifestRelativePath), serialized);
    reportGolden(root, serialized, log);
    log(
      'Now restore the workflow files (for example `git restore .github/workflows`) and commit '
      + `only the manifest, ${proposalDirectory}/ and manifestGoldenDigest: the pre-approval `
      + 'pull request must not change any workflow.',
    );
    return 0;
  }

  const pending = dropExpiredPreApprovals(
    consumePreApprovals(committed.manifest.preApproved, tree.states),
    now,
  );
  const serialized = renderWorkflowManifest({ states: tree.states, preApproved: pending });
  if (mode === '--write') {
    fs.writeFileSync(resolveInRoot(root, manifestRelativePath), serialized);
    const kept = new Set(
      Object.entries(pending)
        .filter(([, entry]) => entry.digest !== null)
        .map(([workflowPath]) => path.posix.basename(proposalRelativePath(workflowPath))),
    );
    for (const proposal of listProposalFiles(root).files) {
      if (!kept.has(proposal.name)) {
        fs.rmSync(resolveInRoot(root, proposal.relativePath));
        log(`removed ${proposal.relativePath}: its pre-approval has landed or expired`);
      }
    }
    removeEmptyProposalDirectory(root);
    reportGolden(root, serialized, log);
    return 0;
  }
  print(serialized);
  return 0;
}

function invokedDirectly() {
  if (!process.argv[1]) {
    return false;
  }
  const invoked = path.resolve(process.argv[1]);
  const self = fileURLToPath(import.meta.url);
  return process.platform === 'win32'
    ? invoked.toLowerCase() === self.toLowerCase()
    : invoked === self;
}

if (invokedDirectly()) {
  const parsed = parseGeneratorArguments(process.argv.slice(2));
  if (parsed.error) {
    console.error(parsed.error);
    process.exitCode = 2;
  } else {
    process.exitCode = runManifestGenerator({
      root: path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..'),
      mode: parsed.mode,
      expiresInDays: parsed.expiresInDays,
    });
  }
}
