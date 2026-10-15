import { createHash } from 'node:crypto';
import { execFileSync, spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const imageRoot = fileURLToPath(new URL('./', import.meta.url));
const locks = [
  ['aptPackageLockSha256', 'infra/ci-runner/image/apt-packages.lock.json'],
  ['flutterEngineArtifactLockSha256', 'infra/ci-runner/image/flutter-engine-artifacts.lock.json'],
];
export const installationBlocker =
  'Image installation blocked: exhaustive offline network input consumption is not implemented (#341).';

function committedSource(contract, root) {
  const commit = contract.contractCommit;
  if (typeof commit !== 'string' || !/^(?:[0-9a-f]{40}|[0-9a-f]{64})$/.test(commit)) {
    throw new Error('Missing or invalid contractCommit.');
  }
  const objectFormat = execFileSync(
    'git',
    ['-C', root, 'rev-parse', '--show-object-format'],
    { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] },
  ).trim();
  const oidLength = objectFormat === 'sha256' ? 64 : 40;
  if (commit.length !== oidLength) {
    throw new Error('contractCommit must be a full Git object SHA.');
  }
  const repositoryRoot = execFileSync(
    'git',
    ['-C', root, 'rev-parse', '--show-toplevel'],
    { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] },
  ).trim();
  return { commit, oidLength, repositoryRoot };
}

export function prepareNetworkLockCommit(contract, root = imageRoot) {
  const { commit, repositoryRoot } = committedSource(contract, root);
  const present = spawnSync(
    'git',
    ['--no-replace-objects', '-C', repositoryRoot, 'rev-parse', '--verify', '--quiet',
      `${commit}^{object}`],
    { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] },
  );
  if (present.error) throw present.error;
  if (present.status === 1) {
    // Fetch objects only: no branch update, FETCH_HEAD write, or mutable ref selection.
    execFileSync(
      'git',
      ['--no-replace-objects', '-C', repositoryRoot, 'fetch', '--no-tags',
        '--no-recurse-submodules', '--no-write-fetch-head', '--refmap=', '--depth=1',
        'origin', commit],
      { stdio: ['ignore', 'pipe', 'pipe'] },
    );
  } else if (present.status !== 0) {
    throw new Error(`Cannot inspect network lock commit: ${present.stderr.trim()}`);
  }
  verifyNetworkLockDigests(contract, root);
}

// The checkout supplies Git metadata, but mutable lock paths are never opened.
function readCommittedLocks(contract, root) {
  const { commit, oidLength, repositoryRoot } = committedSource(contract, root);
  const commitType = execFileSync(
    'git',
    ['--no-replace-objects', '-C', repositoryRoot, 'cat-file', '-t', commit],
    { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] },
  ).trim();
  if (commitType !== 'commit') {
    throw new Error('contractCommit must identify a Git commit.');
  }
  return locks.map(([, filename]) => {
    const treeOutput = execFileSync(
      'git',
      ['--no-replace-objects', '-C', repositoryRoot, 'ls-tree', '-z', '--full-tree',
        commit, '--', filename],
      { stdio: ['ignore', 'pipe', 'pipe'] },
    ).toString('utf8');
    const records = treeOutput.split('\0').filter(Boolean);
    const name = filename.split('/').at(-1);
    if (records.length !== 1) {
      throw new Error(`Network lock is missing from contract commit: ${name}.`);
    }
    const separator = records[0].indexOf('\t');
    const [mode, type, objectId] = records[0].slice(0, separator).split(' ');
    if (!['100644', '100755'].includes(mode) || type !== 'blob' ||
        objectId.length !== oidLength || !/^[0-9a-f]+$/.test(objectId)) {
      throw new Error(`Network lock must be a regular committed file: ${name}.`);
    }
    return execFileSync(
      'git',
      ['--no-replace-objects', '-C', repositoryRoot, 'cat-file', 'blob', objectId],
      { stdio: ['ignore', 'pipe', 'pipe'] },
    );
  });
}

// This is an integrity check, not evidence of dependency closure or offline
// consumption. A later implementation must validate the complete lock schemas
// and use their bytes exclusively before it can authorize an image.
export function verifyNetworkLockDigests(contract, root = imageRoot) {
  for (const [field] of locks) {
    const expected = contract.reproducibility?.[field];
    if (typeof expected !== 'string' || !/^[0-9a-f]{64}$/.test(expected)) {
      throw new Error(`Missing or invalid ${field}.`);
    }
  }
  const committedLocks = readCommittedLocks(contract, root);
  for (const [index, [field, filename]] of locks.entries()) {
    const expected = contract.reproducibility[field];
    const bytes = committedLocks[index];
    if (createHash('sha256').update(bytes).digest('hex') !== expected) {
      throw new Error(`Network lock digest mismatch: ${filename}.`);
    }
    const value = JSON.parse(bytes.toString('utf8'));
    if (!value || Array.isArray(value) || typeof value !== 'object' ||
        Object.keys(value).length === 0) {
      throw new Error(`Network lock must be a nonempty JSON object: ${filename}.`);
    }
  }
}

export function assertNetworkInputsReady(contract, root = imageRoot) {
  if (contract.policy?.reproducibleInputsReady !== true ||
      contract.reproducibility?.status !== 'locked') {
    throw new Error('Image transition is blocked until APT and Flutter network artifacts are fully locked.');
  }
  if (typeof contract.reproducibility.aptSnapshot !== 'string' ||
      !/^https:\/\/snapshot\.ubuntu\.com\/ubuntu\/\d{8}T\d{6}Z\/?$/.test(
        contract.reproducibility.aptSnapshot,
      )) {
    throw new Error('APT snapshot must be an exact immutable Ubuntu snapshot URL.');
  }
  verifyNetworkLockDigests(contract, root);
  // Deliberately not a JSON flag: correct digests must not activate the existing
  // unconstrained bootstrap/installdependencies.sh, APT, pip or Flutter paths.
  throw new Error(installationBlocker);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    if (process.argv.length !== 2 &&
        !(process.argv.length === 3 && process.argv[2] === '--prepare-contract')) {
      throw new Error('Usage: node validate-network-inputs.mjs [--prepare-contract]');
    }
    const contract = JSON.parse(readFileSync(join(imageRoot, 'image-build-contract.json'), 'utf8'));
    if (process.argv[2] === '--prepare-contract') {
      prepareNetworkLockCommit(contract);
    } else {
      assertNetworkInputsReady(contract);
    }
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  }
}
