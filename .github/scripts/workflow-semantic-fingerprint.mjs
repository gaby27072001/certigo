import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { isAlias, isMap, isPair, isScalar, isSeq, parseDocument } from 'yaml';

export const canonicalizationId = 'certigo-workflow-semantic-v1';
export const manifestSchemaVersion = 1;

function normalizeString(value) {
  return value.replace(/\r\n?/g, '\n').normalize('NFC');
}

function normalizeScalar(value, label, errors) {
  if (value === null || typeof value === 'boolean') {
    return value;
  }
  if (typeof value === 'string') {
    return normalizeString(value);
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
      const key = normalizeString(node.key.value);
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
      const key = normalizeString(pair.key.value);
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

export function loadWorkflowManifest(manifestPath) {
  const raw = fs.readFileSync(manifestPath, 'utf8');
  const manifest = JSON.parse(raw);
  const errors = [];
  if (
    manifest === null
    || typeof manifest !== 'object'
    || Array.isArray(manifest)
    || JSON.stringify(Object.keys(manifest)) !== JSON.stringify([
      'schemaVersion',
      'canonicalization',
      'states',
    ])
  ) {
    errors.push('workflow semantic manifest: top-level contract must match exactly');
    return { manifest, errors };
  }
  if (
    manifest.schemaVersion !== manifestSchemaVersion
    || manifest.canonicalization !== canonicalizationId
  ) {
    errors.push('workflow semantic manifest: unsupported schema or canonicalization');
  }
  if (
    manifest.states === null
    || typeof manifest.states !== 'object'
    || Array.isArray(manifest.states)
    || JSON.stringify(Object.keys(manifest.states)) !== JSON.stringify(['A', 'B', 'C'])
  ) {
    errors.push('workflow semantic manifest: states must be exactly A, B, and C');
    return { manifest, errors };
  }
  for (const state of ['A', 'B', 'C']) {
    const entries = manifest.states[state];
    if (entries === null || typeof entries !== 'object' || Array.isArray(entries)) {
      errors.push(`workflow semantic manifest: state ${state} must be a path map`);
      continue;
    }
    const paths = Object.keys(entries);
    if (JSON.stringify(paths) !== JSON.stringify([...paths].sort())) {
      errors.push(`workflow semantic manifest: state ${state} paths must be sorted`);
    }
    for (const [workflowPath, digest] of Object.entries(entries)) {
      try {
        if (canonicalWorkflowPath(workflowPath) !== workflowPath) {
          errors.push(`workflow semantic manifest: non-canonical path ${workflowPath}`);
        }
      } catch {
        errors.push(`workflow semantic manifest: invalid path ${workflowPath}`);
      }
      if (!/^[0-9a-f]{64}$/.test(digest)) {
        errors.push(`workflow semantic manifest: invalid SHA-256 for ${workflowPath}`);
      }
    }
  }
  return { manifest, errors };
}
