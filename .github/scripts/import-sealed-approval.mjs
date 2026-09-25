import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  approvalSuffix,
  approvalsDirectory,
  extractApproval,
  parseApprovalFile,
  validateSealedApprovals,
} from './sealed-approval.mjs';

// Côté agent : transforme le bloc que Gabriel a collé (commentaire de PR, message) en fichier
// `.github/sealed-approvals/pr-<n>.approval`, puis rejoue localement le jugement de la CI contre
// une copie de `main`. N'ajoute aucune confiance : la CI revérifie tout avec la clé de `main`.
export function importApproval({ text, pr, candidateRoot, trustedRoot, now = new Date() }) {
  if (!/^[1-9][0-9]{0,6}$/u.test(String(pr))) {
    throw new Error(`invalid pull request number: ${pr}`);
  }
  const block = extractApproval(text);
  const approval = parseApprovalFile(block);
  const relativePath = `${approvalsDirectory}/pr-${pr}${approvalSuffix}`;
  const destination = path.join(candidateRoot, ...relativePath.split('/'));
  if (fs.existsSync(destination) && fs.readFileSync(destination, 'utf8') !== block) {
    throw new Error(`${relativePath} already holds a different approval; remove it deliberately first`);
  }
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.writeFileSync(destination, block);
  const result = validateSealedApprovals(candidateRoot, trustedRoot, {
    protectedPaths: approval.changes.map((change) => change.path),
    now,
  });
  return { relativePath, approval, ...result };
}

function parseArguments(argv) {
  const options = {};
  for (let index = 0; index < argv.length; index += 1) {
    const [name, inline] = argv[index].split(/=(.*)/su);
    const value = inline ?? argv[++index];
    if (!['--pr', '--input', '--trusted'].includes(name) || value === undefined) {
      throw new Error(
        'Usage: import-sealed-approval.mjs --pr <n> --trusted <checkout of main> [--input <file>]',
      );
    }
    options[name.slice(2)] = value;
  }
  if (!options.pr || !options.trusted) {
    throw new Error('--pr and --trusted are required');
  }
  return options;
}

function invokedDirectly() {
  return process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
}

if (invokedDirectly()) {
  try {
    const options = parseArguments(process.argv.slice(2));
    const text = fs.readFileSync(options.input ?? 0, 'utf8');
    const result = importApproval({
      text,
      pr: options.pr,
      candidateRoot: process.cwd(),
      trustedRoot: path.resolve(options.trusted),
    });
    console.log(`wrote ${result.relativePath} (expires ${result.approval.expires})`);
    for (const entry of result.approved) {
      console.log(`approved by ${entry.principal}: ${entry.path} ${entry.from} -> ${entry.to}`);
    }
    if (result.errors.length > 0) {
      console.error(result.errors.join('\n'));
      process.exitCode = 1;
    }
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
