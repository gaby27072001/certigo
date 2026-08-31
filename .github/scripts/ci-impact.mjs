#!/usr/bin/env node

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const scriptRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const defaultMatrix = path.join(scriptRoot, '.github', 'ci', 'impact-matrix.json');
const shaPattern = /^[0-9a-f]{40}$/;
const gatePattern = /^[a-z][a-z0-9-]*$/;

function exactKeys(value, expected, label) {
  const actual = Object.keys(value).sort();
  const wanted = [...expected].sort();
  if (JSON.stringify(actual) !== JSON.stringify(wanted)) {
    throw new Error(`${label}: expected keys ${wanted.join(', ')}, found ${actual.join(', ')}`);
  }
}

function normalizedRepositoryPath(value, label) {
  if (
    typeof value !== 'string'
    || value.length === 0
    || value.includes('\\')
    || value.startsWith('/')
    || value.split('/').includes('..')
    || /[\u0000-\u001f\u007f]/.test(value)
  ) {
    throw new Error(`${label}: expected a safe repository-relative path`);
  }
  return value.replace(/^\.\//, '');
}

export function globToRegExp(pattern) {
  const normalized = normalizedRepositoryPath(pattern, `pattern ${JSON.stringify(pattern)}`);
  let expression = '^';
  for (let index = 0; index < normalized.length; index += 1) {
    const character = normalized[index];
    if (character === '*' && normalized[index + 1] === '*') {
      if (normalized[index + 2] === '/') {
        expression += '(?:.*/)?';
        index += 2;
      } else {
        expression += '.*';
        index += 1;
      }
    } else if (character === '*') {
      expression += '[^/]*';
    } else if (character === '?') {
      expression += '[^/]';
    } else {
      expression += character.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    }
  }
  return new RegExp(`${expression}$`);
}

export function validateMatrix(value, label = 'impact matrix') {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error(`${label}: expected an object`);
  }
  exactKeys(value, ['schema', 'version', 'defaultGates', 'gates', 'sensitiveAssertions'], label);
  if (value.schema !== 'certigo.ci-impact/v1' || value.version !== 1) {
    throw new Error(`${label}: unsupported schema or version`);
  }
  if (!value.gates || typeof value.gates !== 'object' || Array.isArray(value.gates)) {
    throw new Error(`${label}.gates: expected an object`);
  }
  const gateNames = Object.keys(value.gates);
  if (!gateNames.includes('preflight')) {
    throw new Error(`${label}.gates: preflight gate is mandatory`);
  }
  for (const gate of gateNames) {
    if (!gatePattern.test(gate)) {
      throw new Error(`${label}.gates: invalid gate name ${gate}`);
    }
    const patterns = value.gates[gate];
    if (!Array.isArray(patterns) || patterns.length === 0) {
      throw new Error(`${label}.gates.${gate}: expected at least one pattern`);
    }
    for (const pattern of patterns) {
      globToRegExp(pattern);
    }
  }
  if (
    !Array.isArray(value.defaultGates)
    || value.defaultGates.length !== 1
    || value.defaultGates[0] !== 'preflight'
  ) {
    throw new Error(`${label}.defaultGates: must fail closed to the preflight gate`);
  }
  if (!Array.isArray(value.sensitiveAssertions) || value.sensitiveAssertions.length === 0) {
    throw new Error(`${label}.sensitiveAssertions: expected adversarial coverage fixtures`);
  }
  for (const [index, assertion] of value.sensitiveAssertions.entries()) {
    const assertionLabel = `${label}.sensitiveAssertions[${index}]`;
    if (!assertion || typeof assertion !== 'object' || Array.isArray(assertion)) {
      throw new Error(`${assertionLabel}: expected an object`);
    }
    exactKeys(assertion, ['path', 'gates'], assertionLabel);
    normalizedRepositoryPath(assertion.path, `${assertionLabel}.path`);
    if (!Array.isArray(assertion.gates) || assertion.gates.length === 0) {
      throw new Error(`${assertionLabel}.gates: expected at least one gate`);
    }
    for (const gate of assertion.gates) {
      if (!gateNames.includes(gate)) {
        throw new Error(`${assertionLabel}.gates: unknown gate ${gate}`);
      }
    }
  }
  return value;
}

export function loadMatrix(file = defaultMatrix) {
  let value;
  try {
    value = JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (error) {
    throw new Error(`${file}: cannot load impact matrix: ${error.message}`, { cause: error });
  }
  return validateMatrix(value, file);
}

export function assertMatrixNotWeakened(trusted, candidate) {
  for (const [gate, trustedPatterns] of Object.entries(trusted.gates)) {
    const candidatePatterns = candidate.gates[gate];
    if (!candidatePatterns) {
      throw new Error(`candidate impact matrix removed gate ${gate}`);
    }
    const missingPatterns = trustedPatterns.filter(
      (pattern) => !candidatePatterns.includes(pattern),
    );
    if (missingPatterns.length > 0) {
      throw new Error(
        `candidate impact matrix weakened ${gate}: missing ${missingPatterns.join(', ')}`,
      );
    }
  }
  for (const trustedAssertion of trusted.sensitiveAssertions) {
    const candidateAssertion = candidate.sensitiveAssertions.find(
      (assertion) => assertion.path === trustedAssertion.path,
    );
    if (!candidateAssertion) {
      throw new Error(
        `candidate impact matrix removed sensitive assertion ${trustedAssertion.path}`,
      );
    }
    const missingGates = trustedAssertion.gates.filter(
      (gate) => !candidateAssertion.gates.includes(gate),
    );
    if (missingGates.length > 0) {
      throw new Error(
        `candidate impact matrix weakened ${trustedAssertion.path}: `
          + `missing ${missingGates.join(', ')}`,
      );
    }
  }
}

export function selectGates(matrix, changedPaths) {
  const selected = new Set(matrix.defaultGates);
  const matchers = Object.entries(matrix.gates).map(([gate, patterns]) => [
    gate,
    patterns.map(globToRegExp),
  ]);
  for (const rawPath of changedPaths) {
    const changedPath = normalizedRepositoryPath(rawPath, 'changed path');
    for (const [gate, patterns] of matchers) {
      if (patterns.some((pattern) => pattern.test(changedPath))) {
        selected.add(gate);
      }
    }
  }
  return [...selected].sort();
}

function git(workspace, args) {
  const result = spawnSync('git', args, {
    cwd: workspace,
    encoding: 'buffer',
    windowsHide: true,
  });
  if (result.status !== 0) {
    const detail = result.stderr.toString('utf8').trim() || `exit ${result.status}`;
    throw new Error(`git ${args.join(' ')} failed: ${detail}`);
  }
  return result.stdout;
}

export function changedPaths(workspace, base, head) {
  if (!shaPattern.test(base) || !shaPattern.test(head)) {
    throw new Error('base and head must be full lowercase commit SHAs');
  }
  const fields = git(workspace, [
    'diff',
    '--name-status',
    '-z',
    '--diff-filter=ACDMRTUXB',
    `${base}...${head}`,
  ]).toString('utf8').split('\0');
  const paths = new Set();
  for (let index = 0; index < fields.length && fields[index];) {
    const status = fields[index];
    index += 1;
    const pathCount = /^[RC]/.test(status) ? 2 : 1;
    if (!/^(?:[ACDMRTUXB]|[RC][0-9]{1,3})$/.test(status)) {
      throw new Error(`git diff returned an unsupported status: ${status}`);
    }
    for (let pathIndex = 0; pathIndex < pathCount; pathIndex += 1) {
      if (!fields[index]) {
        throw new Error(`git diff returned a truncated ${status} record`);
      }
      paths.add(normalizedRepositoryPath(fields[index], 'git diff path'));
      index += 1;
    }
  }
  return [...paths].sort();
}

function safeWorkspaceFile(workspace, relative) {
  const root = fs.realpathSync(workspace);
  const candidate = path.resolve(root, relative);
  const resolved = fs.realpathSync(candidate);
  if (resolved !== root && !resolved.startsWith(`${root}${path.sep}`)) {
    throw new Error(`Bicep target escapes the workspace: ${relative}`);
  }
  if (fs.lstatSync(candidate).isSymbolicLink()) {
    throw new Error(`Untrusted input must not be a symbolic link: ${relative}`);
  }
  return resolved;
}

export function validateWorkflowInputs(workspace) {
  const workflowDirectory = safeWorkspaceFile(workspace, '.github/workflows');
  const workflows = fs.readdirSync(workflowDirectory, { withFileTypes: true })
    .filter((entry) => entry.name.endsWith('.yml') || entry.name.endsWith('.yaml'));
  if (workflows.length === 0) {
    throw new Error('No workflow files found under .github/workflows');
  }
  for (const workflow of workflows) {
    if (!workflow.isFile() || workflow.isSymbolicLink()) {
      throw new Error(`Workflow input must be a regular file: ${workflow.name}`);
    }
    safeWorkspaceFile(workspace, `.github/workflows/${workflow.name}`);
  }
}

export function bicepTargets(workspace, paths) {
  let sources = paths.filter(
    (file) => file.startsWith('infra/')
      && (file.endsWith('.bicep') || file.endsWith('.bicepparam')),
  );
  const configurationChanged = paths.some(
    (file) => file.startsWith('infra/') && file.endsWith('/bicepconfig.json'),
  );
  if (sources.length === 0 && !configurationChanged) {
    return [];
  }
  if (configurationChanged) {
    sources = git(workspace, [
      'ls-files',
      '-z',
      '--',
      ':(glob)infra/**/*.bicep',
      ':(glob)infra/**/*.bicepparam',
    ]).toString('utf8').split('\0').filter(Boolean);
  }
  const targets = new Set(['infra/main.bicep']);
  for (const source of sources) {
    const candidate = path.join(workspace, source);
    if (fs.existsSync(candidate)) {
      targets.add(source);
    }
  }
  return [...targets].sort();
}

function compileBicep(workspace, binary, paths) {
  const targets = bicepTargets(workspace, paths);
  const output = fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-bicep-preflight-'));
  try {
    for (const [index, target] of targets.entries()) {
      const source = safeWorkspaceFile(workspace, target);
      const command = target.endsWith('.bicepparam') ? 'build-params' : 'build';
      const result = spawnSync(binary, [
        command,
        source,
        '--outfile',
        path.join(output, `${index}.json`),
      ], {
        cwd: workspace,
        encoding: 'utf8',
        stdio: 'inherit',
        windowsHide: true,
      });
      if (result.status !== 0) {
        throw new Error(`Bicep ${command} failed for ${target} with exit ${result.status}`);
      }
      process.stdout.write(`Compiled ${target}\n`);
    }
  } finally {
    fs.rmSync(output, { recursive: true, force: true });
  }
}

function parseArguments(argv) {
  const values = new Map();
  for (let index = 0; index < argv.length; index += 2) {
    const key = argv[index];
    const value = argv[index + 1];
    if (!key?.startsWith('--') || value === undefined) {
      throw new Error('Arguments must be provided as --key value pairs');
    }
    values.set(key.slice(2), value);
  }
  return values;
}

function writeGitHubOutputs(file, matrix, paths, gates) {
  const knownGates = Object.keys(matrix.gates).sort();
  const lines = [
    `changed_paths=${JSON.stringify(paths)}`,
    `selected_gates=${JSON.stringify(gates)}`,
    ...knownGates.map((gate) => `${gate.replaceAll('-', '_')}=${gates.includes(gate)}`),
  ];
  fs.appendFileSync(file, `${lines.join('\n')}\n`, 'utf8');
}

function validateSensitiveAssertions(matrix) {
  for (const assertion of matrix.sensitiveAssertions) {
    const selected = selectGates(matrix, [assertion.path]);
    const missing = assertion.gates.filter((gate) => !selected.includes(gate));
    if (missing.length > 0) {
      throw new Error(
        `Sensitive path ${assertion.path} can skip required gates: ${missing.join(', ')}`,
      );
    }
  }
}

function main(argv) {
  const args = parseArguments(argv);
  const workspace = args.get('workspace');
  const base = args.get('base');
  const head = args.get('head');
  if (!workspace || !base || !head) {
    throw new Error('--workspace, --base and --head are required');
  }
  const matrix = loadMatrix(args.get('matrix') ?? defaultMatrix);
  validateSensitiveAssertions(matrix);
  if (args.has('candidate-matrix')) {
    const candidatePath = safeWorkspaceFile(
      workspace,
      path.relative(workspace, args.get('candidate-matrix')),
    );
    const candidate = loadMatrix(candidatePath);
    validateSensitiveAssertions(candidate);
    assertMatrixNotWeakened(matrix, candidate);
  }
  validateWorkflowInputs(workspace);
  const paths = changedPaths(workspace, base, head);
  const gates = selectGates(matrix, paths);
  if (args.has('compile-bicep')) {
    compileBicep(workspace, args.get('compile-bicep'), paths);
  }
  if (args.has('github-output')) {
    writeGitHubOutputs(args.get('github-output'), matrix, paths, gates);
  }
  process.stdout.write(`${JSON.stringify({ paths, gates }, null, 2)}\n`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    main(process.argv.slice(2));
  } catch (error) {
    process.stderr.write(`ci-impact: ${error.message}\n`);
    process.exitCode = 1;
  }
}
