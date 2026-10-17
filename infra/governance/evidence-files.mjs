import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const sha256Pattern = /^[0-9a-f]{64}$/;

function comparePath(left, right) {
  return left.path < right.path ? -1 : left.path > right.path ? 1 : 0;
}

export function sha256File(filePath) {
  return createHash('sha256').update(fs.readFileSync(filePath)).digest('hex');
}

export function normalizeEvidencePath(value, label = 'evidence path') {
  if (typeof value !== 'string' || value.length === 0 || value.includes('\0')) {
    throw new Error(`${label} is missing or invalid`);
  }
  const normalized = value.replaceAll('\\', '/');
  if (
    normalized.startsWith('/') ||
    normalized.startsWith('//') ||
    /^[a-z]:\//i.test(normalized)
  ) {
    throw new Error(`${label} must be repository-relative`);
  }
  const segments = normalized.split('/');
  if (
    segments.some(
      (segment) => segment.length === 0 || segment === '.' || segment === '..',
    )
  ) {
    throw new Error(`${label} contains traversal or empty segments`);
  }
  return segments.join('/');
}

function requireContainedPath(root, filePath, label) {
  const resolvedRoot = path.resolve(root);
  const resolvedFile = path.resolve(filePath);
  const relative = path.relative(resolvedRoot, resolvedFile);
  if (
    relative === '' ||
    relative === '..' ||
    relative.startsWith(`..${path.sep}`) ||
    path.isAbsolute(relative)
  ) {
    throw new Error(`${label} is outside its trusted root`);
  }
  return { resolvedRoot, resolvedFile, relative };
}

export function requireTrustedDirectory(directory, label = 'evidence directory') {
  const resolved = path.resolve(directory);
  if (
    !fs.existsSync(resolved) ||
    !fs.lstatSync(resolved).isDirectory() ||
    fs.lstatSync(resolved).isSymbolicLink()
  ) {
    throw new Error(`${label} is missing, not a directory, or is a symbolic link`);
  }
  const parsed = path.parse(resolved);
  let current = parsed.root;
  for (const segment of resolved.slice(parsed.root.length).split(path.sep)) {
    if (!segment) {
      continue;
    }
    current = path.join(current, segment);
    if (fs.lstatSync(current).isSymbolicLink()) {
      throw new Error(`${label} must not traverse a symbolic link`);
    }
  }
  return resolved;
}

function rejectSymbolicLinks(root, filePath, label) {
  const { resolvedRoot, resolvedFile, relative } = requireContainedPath(
    root,
    filePath,
    label,
  );
  requireTrustedDirectory(resolvedRoot, `${label} root`);
  let current = resolvedRoot;
  for (const segment of relative.split(path.sep)) {
    current = path.join(current, segment);
    if (fs.lstatSync(current).isSymbolicLink()) {
      throw new Error(`${label} must not contain a symbolic link`);
    }
  }
  if (!fs.lstatSync(resolvedFile).isFile()) {
    throw new Error(`${label} must be a regular file`);
  }
}

export function requireRegularFile(filePath, label = 'evidence file') {
  const resolved = path.resolve(filePath);
  if (!fs.existsSync(resolved)) {
    throw new Error(`${label} is missing`);
  }
  const root = path.dirname(resolved);
  rejectSymbolicLinks(root, resolved, label);
  return resolved;
}

export function relativeEvidenceFile(root, filePath, label = 'evidence source') {
  const { resolvedFile, relative } = requireContainedPath(root, filePath, label);
  rejectSymbolicLinks(root, resolvedFile, label);
  return {
    path: normalizeEvidencePath(relative, label),
    sha256: sha256File(resolvedFile),
  };
}

export function validateEvidenceEntries(entries, label) {
  if (!Array.isArray(entries)) {
    throw new Error(`${label} must be an array`);
  }
  const caseInsensitivePaths = new Set();
  return entries.map((entry, index) => {
    if (
      !entry ||
      typeof entry !== 'object' ||
      Array.isArray(entry) ||
      JSON.stringify(Object.keys(entry).sort()) !==
        JSON.stringify(['path', 'sha256'])
    ) {
      throw new Error(`${label}[${index}] fields must be exactly path, sha256`);
    }
    const normalizedPath = normalizeEvidencePath(
      entry.path,
      `${label}[${index}].path`,
    );
    const collisionKey = normalizedPath.toLowerCase();
    if (caseInsensitivePaths.has(collisionKey)) {
      throw new Error(`${label} contains a case-insensitive path collision`);
    }
    caseInsensitivePaths.add(collisionKey);
    if (
      typeof entry.sha256 !== 'string' ||
      !sha256Pattern.test(entry.sha256)
    ) {
      throw new Error(`${label}[${index}].sha256 is invalid`);
    }
    return { path: normalizedPath, sha256: entry.sha256 };
  });
}

export function resolveEvidenceFile(root, portablePath, label = 'evidence file') {
  const normalized = normalizeEvidencePath(portablePath, label);
  const filePath = path.join(path.resolve(root), ...normalized.split('/'));
  rejectSymbolicLinks(root, filePath, label);
  return filePath;
}

export function collectArtifactFiles(directory, excludedPaths = []) {
  const root = requireTrustedDirectory(directory, 'artifact directory');
  const excluded = new Set(
    excludedPaths.map((entry) => normalizeEvidencePath(entry).toLowerCase()),
  );
  const files = [];
  const caseInsensitivePaths = new Set();
  const visit = (current, segments) => {
    const entries = fs
      .readdirSync(current, { withFileTypes: true })
      .sort((left, right) =>
        left.name < right.name ? -1 : left.name > right.name ? 1 : 0
      );
    for (const entry of entries) {
      const entrySegments = [...segments, entry.name];
      const portablePath = normalizeEvidencePath(entrySegments.join('/'));
      const fullPath = path.join(current, entry.name);
      if (entry.isSymbolicLink()) {
        throw new Error(`artifact path must not be a symbolic link: ${portablePath}`);
      }
      if (entry.isDirectory()) {
        visit(fullPath, entrySegments);
        continue;
      }
      if (!entry.isFile()) {
        throw new Error(`artifact path must be a regular file: ${portablePath}`);
      }
      const collisionKey = portablePath.toLowerCase();
      if (caseInsensitivePaths.has(collisionKey)) {
        throw new Error('artifact inventory contains a case-insensitive path collision');
      }
      caseInsensitivePaths.add(collisionKey);
      if (!excluded.has(collisionKey)) {
        files.push({ path: portablePath, sha256: sha256File(fullPath) });
      }
    }
  };
  visit(root, []);
  return files.sort(comparePath);
}

export function writeManifestSeal(manifestPath, outputPath) {
  const manifest = requireRegularFile(manifestPath, 'evidence manifest');
  const seal = path.resolve(outputPath);
  if (path.basename(manifest) !== 'manifest.json') {
    throw new Error('evidence manifest must be named manifest.json');
  }
  requireTrustedDirectory(path.dirname(seal), 'evidence manifest seal directory');
  let inspected;
  try {
    inspected = fs.lstatSync(seal);
  } catch (error) {
    if (error.code !== 'ENOENT') {
      throw error;
    }
  }
  if (inspected?.isSymbolicLink()) {
    throw new Error('evidence manifest seal must not be a symbolic link');
  }
  if (inspected && !inspected.isFile()) {
    throw new Error('evidence manifest seal must be a regular file');
  }
  const contents = `${sha256File(manifest)}  manifest.json\n`;
  // Never truncate a pathname before inspecting its opened object. NOFOLLOW
  // supplements, but does not replace, the legacy trusted-directory boundary.
  const descriptor = fs.openSync(
    seal,
    fs.constants.O_WRONLY
      | (inspected ? 0 : fs.constants.O_CREAT | fs.constants.O_EXCL)
      | (fs.constants.O_NOFOLLOW ?? 0)
      | (fs.constants.O_NONBLOCK ?? 0),
    0o600,
  );
  try {
    const opened = fs.fstatSync(descriptor);
    const current = fs.lstatSync(seal);
    if (
      !opened.isFile()
      || !current.isFile()
      || current.isSymbolicLink()
      || opened.dev !== current.dev
      || opened.ino !== current.ino
      || (inspected && (opened.dev !== inspected.dev || opened.ino !== inspected.ino))
    ) {
      throw new Error('evidence manifest seal changed before writing');
    }
    fs.ftruncateSync(descriptor, 0);
    fs.writeFileSync(descriptor, contents);
  } finally {
    fs.closeSync(descriptor);
  }
}

export function verifyManifestSeal(manifestPath, sealPath) {
  const manifest = requireRegularFile(manifestPath, 'evidence manifest');
  const seal = requireRegularFile(sealPath, 'evidence manifest seal');
  const match = fs
    .readFileSync(seal, 'utf8')
    .match(/^([0-9a-f]{64})  manifest\.json\r?\n?$/);
  if (!match || match[1] !== sha256File(manifest)) {
    throw new Error('evidence manifest seal is invalid');
  }
}

function main() {
  const [command, firstPath, secondPath] = process.argv.slice(2);
  if (command === 'hash' && firstPath && !secondPath) {
    process.stdout.write(`${sha256File(requireRegularFile(firstPath))}\n`);
    return;
  }
  if (command === 'seal' && firstPath && secondPath) {
    writeManifestSeal(firstPath, secondPath);
    return;
  }
  if (command === 'verify-seal' && firstPath && secondPath) {
    verifyManifestSeal(firstPath, secondPath);
    return;
  }
  if (command === 'require-file' && firstPath && !secondPath) {
    requireRegularFile(firstPath, 'approved Phase A evidence artifact');
    return;
  }
  if (command === 'require-directory' && firstPath && !secondPath) {
    requireTrustedDirectory(firstPath);
    return;
  }
  throw new Error(
    'command must be hash, seal, verify-seal, require-file, or require-directory with the required paths',
  );
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  main();
}
