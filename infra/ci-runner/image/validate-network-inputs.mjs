import { createHash } from 'node:crypto';
import { lstatSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const imageRoot = fileURLToPath(new URL('./', import.meta.url));
const locks = [
  ['aptPackageLockSha256', 'apt-packages.lock.json'],
  ['flutterEngineArtifactLockSha256', 'flutter-engine-artifacts.lock.json'],
  ['pythonWheelLockSha256', 'python-wheels.lock.json'],
];
// The offline consumer (install_offline.py) exists and is exercised by the qemu harness.
// Admission still requires independent review, green CI and explicit approval.
export const installationBlocker =
  'Image installation blocked: the offline installer is not admitted until review, CI and explicit approval (#341).';

// This is an integrity check, not evidence of dependency closure or offline
// consumption. A later implementation must validate the complete lock schemas
// and use their bytes exclusively before it can authorize an image.
export function verifyNetworkLockDigests(contract, root = imageRoot) {
  for (const [field, filename] of locks) {
    const expected = contract.reproducibility?.[field];
    if (typeof expected !== 'string' || !/^[0-9a-f]{64}$/.test(expected)) {
      throw new Error(`Missing or invalid ${field}.`);
    }
    const path = join(root, filename);
    const stat = lstatSync(path);
    if (!stat.isFile() || stat.isSymbolicLink()) {
      throw new Error(`Network lock must be a regular file: ${filename}.`);
    }
    const bytes = readFileSync(path);
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
    throw new Error('Image transition is blocked until APT, Flutter and Python network artifacts are fully locked.');
  }
  if (typeof contract.reproducibility.aptSnapshot !== 'string' ||
      !/^https:\/\/snapshot\.ubuntu\.com\/ubuntu\/\d{8}T\d{6}Z\/?$/.test(
        contract.reproducibility.aptSnapshot,
      )) {
    throw new Error('APT snapshot must be an exact immutable Ubuntu snapshot URL.');
  }
  verifyNetworkLockDigests(contract, root);
  // Deliberately not a JSON flag: correct digests must not admit the offline installer
  // (install_offline.py) before independent review, green CI and explicit approval.
  throw new Error(installationBlocker);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    if (process.argv.length !== 2) {
      throw new Error('Usage: node validate-network-inputs.mjs');
    }
    const contract = JSON.parse(readFileSync(join(imageRoot, 'image-build-contract.json'), 'utf8'));
    assertNetworkInputsReady(contract);
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  }
}
