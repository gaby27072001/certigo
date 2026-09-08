import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  canonicalizationId,
  fingerprintWorkflow,
  manifestSchemaVersion,
} from './workflow-semantic-fingerprint.mjs';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(scriptDirectory, '..', '..');
const manifestPath = path.join(scriptDirectory, 'workflow-semantic-manifest.json');
const workflowsDirectory = path.join(repositoryRoot, '.github', 'workflows');
const disabledDirectory = path.join(repositoryRoot, '.github', 'workflows-disabled');
const legacyName = 'test-account-deletion-cosmos.yml';
const oneShotName = 'post-merge-cosmos-account-deletion.yml';

function sourcePath(name) {
  const active = path.join(workflowsDirectory, name);
  const archived = path.join(disabledDirectory, name);
  if (fs.existsSync(active) === fs.existsSync(archived)) {
    throw new Error(`${name} must exist in exactly one lifecycle directory`);
  }
  return fs.existsSync(active) ? active : archived;
}

function digest(canonicalPath, filePath) {
  const result = fingerprintWorkflow(canonicalPath, fs.readFileSync(filePath, 'utf8'));
  if (result.errors.length > 0) {
    throw new Error(result.errors.join('\n'));
  }
  return result.digest;
}

function sorted(entries) {
  return Object.fromEntries([...entries].sort(([left], [right]) => (
    left < right ? -1 : left > right ? 1 : 0
  )));
}

function generateManifest() {
  const baseline = [];
  for (const entry of fs.readdirSync(workflowsDirectory, { withFileTypes: true })) {
    if (!entry.isFile() || !/\.ya?ml$/.test(entry.name)) {
      continue;
    }
    if (entry.name === legacyName || entry.name === oneShotName) {
      continue;
    }
    const canonicalPath = `.github/workflows/${entry.name}`;
    baseline.push([canonicalPath, digest(canonicalPath, path.join(workflowsDirectory, entry.name))]);
  }
  const stateB = sorted(baseline);
  const stateA = sorted([
    ...baseline,
    [
      `.github/workflows/${legacyName}`,
      digest(`.github/workflows/${legacyName}`, sourcePath(legacyName)),
    ],
  ]);
  const stateC = sorted([
    ...baseline,
    [
      `.github/workflows/${oneShotName}`,
      digest(`.github/workflows/${oneShotName}`, sourcePath(oneShotName)),
    ],
  ]);
  return {
    schemaVersion: manifestSchemaVersion,
    canonicalization: canonicalizationId,
    states: { A: stateA, B: stateB, C: stateC },
  };
}

const serialized = `${JSON.stringify(generateManifest(), null, 2)}\n`;
const write = process.argv.includes('--write');
const check = process.argv.includes('--check');
if (write && check) {
  throw new Error('--write and --check are mutually exclusive');
}
if (write) {
  fs.writeFileSync(manifestPath, serialized);
} else if (check) {
  if (!fs.existsSync(manifestPath) || fs.readFileSync(manifestPath, 'utf8') !== serialized) {
    console.error('workflow semantic manifest is stale; review changes and run with --write');
    process.exitCode = 1;
  }
} else {
  process.stdout.write(serialized);
}
