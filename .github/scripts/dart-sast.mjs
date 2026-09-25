#!/usr/bin/env node
// Dart/Flutter SAST runner and gate (Semgrep Community Edition).
//
// The controls (rules, scope, baseline, Semgrep lock, fixtures) default to the files next to
// this script, so running the BASE copy (.trusted-control) always applies the base controls;
// the pull request tree is only ever read as data. See docs/runbooks/DART_SAST.md.
//
//   check       list the tracked targets, run Semgrep, enforce coverage and the baseline
//   test-rules  run the rules on their annotated fixtures (ruleid:/ok: annotations)
//   baseline    print draft baseline entries for the current findings (maintainers only)
//
// Exit status: 0 clean, 1 new findings or failed rule tests, 2 invalid or incomplete
// scan (tool error, parse error, uncovered target, malformed input).

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

export const FINGERPRINT_PREFIX = 'certigo-dart-sast-v1';
export const SCOPE_SCHEMA = 'certigo.dart-sast-scope/v1';
export const BASELINE_SCHEMA = 'certigo.dart-sast-baseline/v1';
export const CLASSIFICATIONS = new Set(['false-positive', 'accepted-risk']);
const CONTROL_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
export const DEFAULT_CONTROLS = Object.freeze({
  rules: path.join(CONTROL_ROOT, '.github', 'sast', 'rules'),
  scope: path.join(CONTROL_ROOT, '.github', 'sast', 'scope.json'),
  baseline: path.join(CONTROL_ROOT, '.github', 'sast', 'baseline.json'),
  lock: path.join(CONTROL_ROOT, '.github', 'sast', 'semgrep-requirements.lock'),
  fixtures: path.join(CONTROL_ROOT, '.github', 'sast', 'tests'),
});
const RULE_ID_PATTERN = /^(?:dart|mobile)-[a-z0-9]+(?:-[a-z0-9]+)*$/;
const RULE_ID_LINE = /^\s*-\s+id:\s*(\S+)\s*$/;
const SEVERITIES = new Set(['ERROR', 'WARNING', 'INFO']);
const FINGERPRINT_PATTERN = /^sha256:[0-9a-f]{64}$/;
const DATE_PATTERN = /^(\d{4})-(\d{2})-(\d{2})$/;
const MAX_SNIPPET_LINES = 20;
const BINARY_PROBE_BYTES = 8000;
const SEMGREP_ENV_ALLOWLIST = ['PATH', 'LANG', 'LC_ALL', 'TMPDIR', 'TEMP', 'TMP', 'SYSTEMROOT'];

export class GateError extends Error {
  constructor(message, exitCode = 2) {
    super(message);
    this.exitCode = exitCode;
  }
}

// ------------------------------------------------------------------ paths

export function safeRelativePath(value, label) {
  if (
    typeof value !== 'string'
    || value.length === 0
    || value.includes('\\')
    || value.startsWith('/')
    || /^[A-Za-z]:/.test(value)
    || /[\u0000-\u001f\u007f]/.test(value)
  ) {
    throw new GateError(`${label}: expected a safe repository-relative path, got ${JSON.stringify(value)}`);
  }
  const normalized = value.replace(/^(?:\.\/)+/, '');
  const segments = normalized.split('/');
  if (segments.some((segment) => segment === '' || segment === '.' || segment === '..')) {
    throw new GateError(`${label}: path must be normalized: ${JSON.stringify(value)}`);
  }
  return normalized;
}

function regularFileInside(root, relative, label) {
  const canonicalRoot = fs.realpathSync(root);
  let current = canonicalRoot;
  for (const segment of relative.split('/')) {
    current = path.join(current, segment);
    const stats = fs.lstatSync(current, { throwIfNoEntry: false });
    if (!stats) {
      throw new GateError(`${label}: ${relative} does not exist`);
    }
    if (stats.isSymbolicLink()) {
      throw new GateError(`${label}: ${relative} goes through a symbolic link, which the scan refuses`);
    }
  }
  if (!fs.lstatSync(current).isFile()) {
    throw new GateError(`${label}: ${relative} is not a regular file`);
  }
  return current;
}

function readJson(file, label) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (error) {
    throw new GateError(`${label}: cannot read JSON from ${file}: ${error.message}`);
  }
}

function exactKeys(value, required, optional, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new GateError(`${label}: expected an object`);
  }
  const allowed = new Set([...required, ...optional]);
  for (const key of Object.keys(value)) {
    if (!allowed.has(key)) {
      throw new GateError(`${label}: unexpected key ${key}`);
    }
  }
  for (const key of required) {
    if (!Object.hasOwn(value, key)) {
      throw new GateError(`${label}: missing key ${key}`);
    }
  }
}

// ------------------------------------------------------------------ rule catalog

export function parseRuleCatalog(files) {
  const rules = new Map();
  for (const { name, text } of files) {
    const lines = text.split(/\r?\n/);
    const starts = [];
    lines.forEach((line, index) => {
      const match = RULE_ID_LINE.exec(line);
      if (match) {
        starts.push({ index, id: match[1] });
      }
    });
    if (starts.length === 0) {
      throw new GateError(`${name}: no rule found`);
    }
    starts.forEach(({ index, id }, position) => {
      if (!RULE_ID_PATTERN.test(id)) {
        throw new GateError(`${name}: rule id ${id} must match ${RULE_ID_PATTERN}`);
      }
      if (rules.has(id)) {
        throw new GateError(`${name}: duplicate rule id ${id}`);
      }
      const end = position + 1 < starts.length ? starts[position + 1].index : lines.length;
      const block = lines.slice(index, end).join('\n');
      const risk = /^\s+certigo-risk:\s*([a-z-]+)\s*$/m.exec(block);
      if (!risk) {
        throw new GateError(`${name}: rule ${id} must declare metadata.certigo-risk`);
      }
      rules.set(id, {
        id,
        file: name,
        risk: risk[1],
        redact: /^\s+certigo-redact:\s*true\s*$/m.test(block),
      });
    });
  }
  return rules;
}

export function loadRuleCatalog(rulesDir) {
  const entries = fs.readdirSync(rulesDir, { withFileTypes: true })
    .filter((entry) => /\.ya?ml$/.test(entry.name))
    .sort((left, right) => left.name.localeCompare(right.name));
  if (entries.length === 0) {
    throw new GateError(`${rulesDir}: no rule file found`);
  }
  const files = entries.map((entry) => {
    if (!entry.isFile()) {
      throw new GateError(`${rulesDir}/${entry.name}: rule files must be regular files`);
    }
    return { name: entry.name, text: fs.readFileSync(path.join(rulesDir, entry.name), 'utf8') };
  });
  return parseRuleCatalog(files);
}

// ------------------------------------------------------------------ scope

export function validateScope(value, label = 'scope') {
  exactKeys(value, ['schema', 'roots', 'everywhereExtensions', 'excludePrefixes', 'binaryExtensions'], [], label);
  if (value.schema !== SCOPE_SCHEMA) {
    throw new GateError(`${label}: unsupported schema ${JSON.stringify(value.schema)}`);
  }
  for (const key of ['roots', 'everywhereExtensions', 'excludePrefixes', 'binaryExtensions']) {
    if (!Array.isArray(value[key]) || value[key].some((item) => typeof item !== 'string')) {
      throw new GateError(`${label}.${key}: expected an array of strings`);
    }
  }
  if (value.roots.length === 0) {
    throw new GateError(`${label}.roots: at least one root is required`);
  }
  value.roots.forEach((root) => safeRelativePath(root, `${label}.roots`));
  value.excludePrefixes.forEach((prefix) => {
    if (!prefix.endsWith('/')) {
      throw new GateError(`${label}.excludePrefixes: ${prefix} must end with /`);
    }
    safeRelativePath(prefix.slice(0, -1), `${label}.excludePrefixes`);
  });
  for (const key of ['everywhereExtensions', 'binaryExtensions']) {
    for (const extension of value[key]) {
      if (!/^\.[a-z0-9]+$/.test(extension)) {
        throw new GateError(`${label}.${key}: invalid extension ${extension}`);
      }
    }
  }
  return value;
}

export function selectScopeTargets(trackedFiles, scope, isBinary) {
  const roots = scope.roots.map((root) => `${root}/`);
  const binary = new Set(scope.binaryExtensions);
  const everywhere = new Set(scope.everywhereExtensions);
  const selected = [];
  for (const file of [...new Set(trackedFiles)].sort()) {
    if (scope.excludePrefixes.some((prefix) => file.startsWith(prefix))) {
      continue;
    }
    const extension = path.posix.extname(file).toLowerCase();
    const inRoot = roots.some((root) => file.startsWith(root));
    if (!inRoot && !everywhere.has(extension)) {
      continue;
    }
    if (binary.has(extension) || isBinary(file)) {
      continue;
    }
    selected.push(file);
  }
  return selected;
}

function runGit(root, args) {
  const result = spawnSync('git', ['-c', 'core.hooksPath=/dev/null', '-c', 'core.fsmonitor=false', ...args], {
    cwd: root,
    encoding: 'buffer',
    maxBuffer: 256 * 1024 * 1024,
    windowsHide: true,
  });
  if (result.error || result.status !== 0) {
    const detail = result.error?.message ?? result.stderr.toString('utf8').trim();
    throw new GateError(`git ${args.join(' ')} failed: ${detail || `exit ${result.status}`}`);
  }
  return result.stdout;
}

export function listTrackedFiles(root) {
  const entries = runGit(root, ['ls-files', '-z', '--stage']).toString('utf8').split('\0').filter(Boolean);
  const files = [];
  for (const entry of entries) {
    const match = /^(\d{6}) [0-9a-f]{40,64} \d\t(.+)$/s.exec(entry);
    if (!match) {
      throw new GateError(`git ls-files returned an unexpected record ${JSON.stringify(entry)}`);
    }
    const [, mode, file] = match;
    const relative = safeRelativePath(file, 'tracked file');
    if (mode === '120000' || mode === '160000') {
      files.push({ path: relative, special: mode === '120000' ? 'symbolic link' : 'submodule' });
    } else {
      files.push({ path: relative, special: null });
    }
  }
  return files;
}

function containsNul(file) {
  const handle = fs.openSync(file, 'r');
  try {
    const buffer = Buffer.alloc(BINARY_PROBE_BYTES);
    const read = fs.readSync(handle, buffer, 0, BINARY_PROBE_BYTES, 0);
    return buffer.subarray(0, read).includes(0);
  } finally {
    fs.closeSync(handle);
  }
}

export function computeTargets(root, scope) {
  const tracked = listTrackedFiles(root);
  const special = new Map(tracked.filter((entry) => entry.special).map((entry) => [entry.path, entry.special]));
  const targets = selectScopeTargets(tracked.map((entry) => entry.path), scope, (file) => {
    if (special.has(file)) {
      throw new GateError(`scope: ${file} is a ${special.get(file)}, which the scan refuses`);
    }
    return containsNul(regularFileInside(root, file, 'scope'));
  });
  if (targets.length === 0) {
    throw new GateError('scope: no target selected; refusing an empty scan');
  }
  if (!targets.some((file) => file.endsWith('.dart'))) {
    throw new GateError('scope: no Dart file selected; refusing a scan that cannot cover Dart');
  }
  return targets;
}

// ------------------------------------------------------------------ Semgrep

export function semgrepArguments({ rulesDir, output, targets }) {
  return [
    'scan',
    '--config', rulesDir,
    '--json',
    '--output', output,
    '--metrics=off',
    '--disable-version-check',
    '--oss-only',
    '--disable-nosem',
    '--no-rewrite-rule-ids',
    '--x-ignore-semgrepignore-files',
    '--no-git-ignore',
    '--max-target-bytes=0',
    '--timeout=30',
    '--timeout-threshold=0',
    '--quiet',
    '--',
    ...targets.map((target) => `./${target}`),
  ];
}

export function semgrepEnvironment(stateDir, source = process.env) {
  const environment = {};
  for (const key of SEMGREP_ENV_ALLOWLIST) {
    if (source[key] !== undefined) {
      environment[key] = source[key];
    }
  }
  const home = path.join(stateDir, 'home');
  fs.mkdirSync(home, { recursive: true });
  return {
    ...environment,
    HOME: home,
    XDG_CONFIG_HOME: path.join(home, '.config'),
    XDG_CACHE_HOME: path.join(home, '.cache'),
    SEMGREP_SEND_METRICS: 'off',
    SEMGREP_ENABLE_VERSION_CHECK: '0',
    NO_COLOR: '1',
    PYTHONNOUSERSITE: '1',
    PYTHONDONTWRITEBYTECODE: '1',
  };
}

export function readPinnedVersion(lockFile) {
  const text = fs.readFileSync(lockFile, 'utf8');
  const matches = [...text.matchAll(/^semgrep==([0-9]+\.[0-9]+\.[0-9]+)\s*\\?$/gm)];
  if (matches.length !== 1) {
    throw new GateError(`${lockFile}: expected exactly one pinned semgrep==X.Y.Z requirement`);
  }
  return matches[0][1];
}

function runSemgrep({ semgrep, rulesDir, cwd, targets, stateDir, label }) {
  fs.mkdirSync(stateDir, { recursive: true });
  const output = path.join(stateDir, `${label}-semgrep.json`);
  fs.rmSync(output, { force: true });
  const result = spawnSync(semgrep, semgrepArguments({ rulesDir: path.resolve(rulesDir), output, targets }), {
    cwd,
    env: semgrepEnvironment(stateDir),
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024,
    windowsHide: true,
  });
  if (result.error) {
    throw new GateError(`${label}: cannot start Semgrep: ${result.error.message}`);
  }
  const diagnostics = `${result.stdout ?? ''}${result.stderr ?? ''}`.trim();
  if (result.status !== 0) {
    let reported = '';
    try {
      const partial = JSON.parse(fs.readFileSync(output, 'utf8'));
      reported = (partial.errors ?? [])
        .map((error) => `  - ${String(error?.message ?? error?.type ?? 'error').split('\n').slice(0, 6).join(' | ')}`)
        .join('\n');
    } catch {
      reported = '';
    }
    throw new GateError(
      `${label}: Semgrep exited with status ${result.status}`
        + `${reported ? `:\n${reported}` : ''}${diagnostics ? `\n${diagnostics}` : ''}`,
    );
  }
  return { output: readJson(output, `${label} Semgrep output`), diagnostics };
}

// ------------------------------------------------------------------ results

function position(value, label) {
  exactKeys(value, ['line', 'col', 'offset'], [], label);
  for (const key of ['line', 'col', 'offset']) {
    if (!Number.isInteger(value[key]) || value[key] < (key === 'offset' ? 0 : 1)) {
      throw new GateError(`${label}.${key}: expected a positive integer`);
    }
  }
  return value;
}

export function validateSemgrepOutput(output, { expectedVersion, targets, catalog }) {
  if (!output || typeof output !== 'object' || Array.isArray(output)) {
    throw new GateError('Semgrep output: expected a JSON object');
  }
  if (expectedVersion && output.version !== expectedVersion) {
    throw new GateError(
      `Semgrep output: version ${JSON.stringify(output.version)} differs from the pinned ${expectedVersion}`,
    );
  }
  if (!Array.isArray(output.results) || !Array.isArray(output.errors)) {
    throw new GateError('Semgrep output: results and errors must be arrays');
  }
  if (!output.paths || !Array.isArray(output.paths.scanned)) {
    throw new GateError('Semgrep output: paths.scanned must be an array');
  }
  const expected = new Set(targets);
  const scanned = new Set(
    output.paths.scanned.map((file) => safeRelativePath(file, 'Semgrep scanned path')),
  );
  const problems = [];
  for (const error of output.errors) {
    const type = Array.isArray(error?.type) ? error.type[0] : error?.type;
    const where = typeof error?.path === 'string' ? ` in ${error.path}` : '';
    const message = typeof error?.message === 'string' ? error.message.split('\n')[0].slice(0, 300) : '';
    problems.push(`Semgrep reported ${String(type ?? 'an error')}${where}: ${message}`);
  }
  const uncovered = targets.filter((file) => !scanned.has(file));
  for (const file of uncovered) {
    problems.push(`target was not analysed by any rule: ${file}`);
  }
  const unexpected = [...scanned].filter((file) => !expected.has(file)).sort();
  for (const file of unexpected) {
    problems.push(`Semgrep analysed a file outside the requested targets: ${file}`);
  }
  const results = output.results.map((result, index) => {
    const label = `Semgrep result ${index}`;
    if (!result || typeof result !== 'object') {
      throw new GateError(`${label}: expected an object`);
    }
    const rule = result.check_id;
    if (!catalog.has(rule)) {
      throw new GateError(`${label}: unknown rule ${JSON.stringify(rule)}`);
    }
    const file = safeRelativePath(result.path, `${label}.path`);
    if (!expected.has(file)) {
      throw new GateError(`${label}: finding in ${file}, which is not a requested target`);
    }
    const start = position(result.start, `${label}.start`);
    const end = position(result.end, `${label}.end`);
    if (end.offset < start.offset || end.line < start.line) {
      throw new GateError(`${label}: end precedes start`);
    }
    const severity = result.extra?.severity;
    if (!SEVERITIES.has(severity)) {
      throw new GateError(`${label}: invalid severity ${JSON.stringify(severity)}`);
    }
    const message = typeof result.extra?.message === 'string' ? result.extra.message : '';
    return { rule, path: file, start, end, severity, message };
  });
  return { results, problems };
}

export function normalizeSnippet(lines) {
  return lines.map((line) => line.trim()).filter(Boolean).join(' ').replace(/\s+/g, ' ');
}

export function snippetFor(sourceText, startLine, endLine) {
  const lines = sourceText.split(/\r?\n/);
  const last = Math.min(endLine, startLine + MAX_SNIPPET_LINES - 1, lines.length);
  return normalizeSnippet(lines.slice(startLine - 1, last));
}

export function fingerprintFor(rule, file, snippet) {
  const digest = crypto.createHash('sha256')
    .update(`${FINGERPRINT_PREFIX}\0${rule}\0${file}\0${snippet}`, 'utf8')
    .digest('hex');
  return `sha256:${digest}`;
}

export function buildFindings(results, readSource, catalog) {
  const unique = new Map();
  for (const result of results) {
    const key = `${result.rule}\0${result.path}\0${result.start.offset}\0${result.end.offset}`;
    if (!unique.has(key)) {
      unique.set(key, result);
    }
  }
  const sorted = [...unique.values()].sort((left, right) => (
    left.path.localeCompare(right.path)
    || left.start.offset - right.start.offset
    || left.end.offset - right.end.offset
    || left.rule.localeCompare(right.rule)
  ));
  const sources = new Map();
  const occurrences = new Map();
  return sorted.map((result) => {
    if (!sources.has(result.path)) {
      sources.set(result.path, readSource(result.path));
    }
    const snippet = snippetFor(sources.get(result.path), result.start.line, result.end.line);
    const fingerprint = fingerprintFor(result.rule, result.path, snippet);
    const occurrence = (occurrences.get(fingerprint) ?? 0) + 1;
    occurrences.set(fingerprint, occurrence);
    return {
      ...result,
      line: result.start.line,
      column: result.start.col,
      snippet,
      fingerprint,
      occurrence,
      redact: catalog.get(result.rule).redact,
      risk: catalog.get(result.rule).risk,
    };
  });
}

// ------------------------------------------------------------------ baseline

function validDate(value) {
  const match = DATE_PATTERN.exec(value ?? '');
  if (!match) {
    return false;
  }
  const date = new Date(Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3])));
  return date.toISOString().slice(0, 10) === value;
}

export function validateBaseline(value, catalog, label = 'baseline') {
  exactKeys(value, ['schema', 'entries'], ['_comment'], label);
  if (value.schema !== BASELINE_SCHEMA) {
    throw new GateError(`${label}: unsupported schema ${JSON.stringify(value.schema)}`);
  }
  if (!Array.isArray(value.entries)) {
    throw new GateError(`${label}.entries: expected an array`);
  }
  const seen = new Set();
  return value.entries.map((entry, index) => {
    const entryLabel = `${label}.entries[${index}]`;
    exactKeys(
      entry,
      ['rule', 'path', 'fingerprint', 'occurrence', 'classification', 'reviewedAt', 'justification', 'revisitWhen'],
      [],
      entryLabel,
    );
    if (!catalog.has(entry.rule)) {
      throw new GateError(`${entryLabel}: unknown rule ${JSON.stringify(entry.rule)}`);
    }
    safeRelativePath(entry.path, `${entryLabel}.path`);
    if (!FINGERPRINT_PATTERN.test(entry.fingerprint)) {
      throw new GateError(`${entryLabel}: fingerprint must be sha256:<64 lowercase hex>`);
    }
    if (!Number.isInteger(entry.occurrence) || entry.occurrence < 1) {
      throw new GateError(`${entryLabel}: occurrence must be a positive integer`);
    }
    if (!CLASSIFICATIONS.has(entry.classification)) {
      throw new GateError(`${entryLabel}: classification must be one of ${[...CLASSIFICATIONS].join(', ')}`);
    }
    if (!validDate(entry.reviewedAt)) {
      throw new GateError(`${entryLabel}: reviewedAt must be a real YYYY-MM-DD date`);
    }
    for (const key of ['justification', 'revisitWhen']) {
      if (typeof entry[key] !== 'string' || entry[key].trim().length < 20) {
        throw new GateError(`${entryLabel}: ${key} must explain the decision (20 characters or more)`);
      }
    }
    const key = `${entry.fingerprint}#${entry.occurrence}`;
    if (seen.has(key)) {
      throw new GateError(`${entryLabel}: duplicate fingerprint and occurrence`);
    }
    seen.add(key);
    return entry;
  });
}

export function compareWithBaseline(findings, entries) {
  const byKey = new Map(entries.map((entry) => [`${entry.fingerprint}#${entry.occurrence}`, entry]));
  const matched = new Set();
  const fresh = [];
  const accepted = [];
  for (const finding of findings) {
    const key = `${finding.fingerprint}#${finding.occurrence}`;
    const entry = byKey.get(key);
    if (entry && entry.rule === finding.rule && entry.path === finding.path) {
      matched.add(key);
      accepted.push({ finding, entry });
    } else {
      fresh.push(finding);
    }
  }
  const stale = entries.filter((entry) => !matched.has(`${entry.fingerprint}#${entry.occurrence}`));
  return { fresh, accepted, stale };
}

// ------------------------------------------------------------------ reporting

function escapeProperty(value) {
  return String(value)
    .replaceAll('%', '%25')
    .replaceAll('\r', '%0D')
    .replaceAll('\n', '%0A')
    .replaceAll(':', '%3A')
    .replaceAll(',', '%2C');
}

function escapeMarkdown(value) {
  return String(value).replace(/[\\`*_|<>[\]]/g, (character) => `\\${character}`);
}

export function renderReport({ label, targets, findings, comparison, problems }) {
  const lines = [
    `Dart SAST (${label}): ${targets.length} targets, ${findings.length} findings, `
      + `${comparison.accepted.length} baselined, ${comparison.fresh.length} new, `
      + `${comparison.stale.length} stale baseline entries, ${problems.length} coverage problems.`,
  ];
  for (const problem of problems) {
    lines.push(`INCOMPLETE ${problem}`);
  }
  for (const finding of comparison.fresh) {
    lines.push(
      `NEW ${finding.severity} ${finding.rule} ${finding.path}:${finding.line}:${finding.column}`,
      `    ${finding.message.replace(/\s+/g, ' ').trim()}`,
      finding.redact ? '    source: <redacted: secret rule>' : `    source: ${finding.snippet}`,
      `    baseline key: fingerprint ${finding.fingerprint} occurrence ${finding.occurrence}`,
    );
  }
  for (const { finding, entry } of comparison.accepted) {
    lines.push(
      `BASELINED ${finding.rule} ${finding.path}:${finding.line} (${entry.classification}, reviewed ${entry.reviewedAt})`,
    );
  }
  for (const entry of comparison.stale) {
    lines.push(`STALE baseline entry ${entry.rule} ${entry.path} ${entry.fingerprint}#${entry.occurrence}`);
  }
  return `${lines.join('\n')}\n`;
}

export function renderAnnotations(findings) {
  return findings.map((finding) => (
    `::error file=${escapeProperty(finding.path)},line=${finding.line},col=${finding.column},`
      + `title=${escapeProperty(`Dart SAST ${finding.rule}`)}::`
      + `${finding.rule} (new ${finding.severity.toLowerCase()} finding, details in the job log)`
  )).join('\n');
}

export function renderSummary({ label, targets, findings, comparison, problems, version }) {
  const lines = [
    `## Dart/Flutter SAST — ${escapeMarkdown(label)}`,
    '',
    `- Engine: Semgrep Community Edition ${escapeMarkdown(version)} (rules, scope and baseline from the base SHA)`,
    `- Targets analysed: **${targets.length}**`,
    `- Findings: **${findings.length}** — baselined **${comparison.accepted.length}**, new **${comparison.fresh.length}**`,
    `- Stale baseline entries: **${comparison.stale.length}**`,
    `- Coverage problems: **${problems.length}**`,
  ];
  if (comparison.fresh.length > 0) {
    lines.push('', '| Severity | Rule | Location |', '| --- | --- | --- |');
    for (const finding of comparison.fresh) {
      lines.push(
        `| ${finding.severity} | ${escapeMarkdown(finding.rule)} | ${escapeMarkdown(finding.path)}:${finding.line} |`,
      );
    }
  }
  return `${lines.join('\n')}\n`;
}

function printUntrusted(text) {
  const token = crypto.randomUUID();
  process.stdout.write(`::stop-commands::${token}\n${text}::${token}::\n`);
}

// ------------------------------------------------------------------ commands

function controlPath(args, name) {
  const value = args.get(name);
  if (value !== undefined && (typeof value !== 'string' || value.length === 0)) {
    throw new GateError(`--${name} expects a path`);
  }
  return path.resolve(value ?? DEFAULT_CONTROLS[name]);
}

function requireArgument(args, name) {
  const value = args.get(name);
  if (typeof value !== 'string' || value.length === 0) {
    throw new GateError(`--${name} is required`);
  }
  return value;
}

export function parseArguments(argv) {
  const args = new Map();
  for (let index = 0; index < argv.length; index += 1) {
    const key = argv[index];
    if (!key.startsWith('--')) {
      throw new GateError(`unexpected argument ${JSON.stringify(key)}`);
    }
    const name = key.slice(2);
    if (name === 'github') {
      args.set(name, true);
      continue;
    }
    const value = argv[index + 1];
    if (value === undefined || value.startsWith('--')) {
      throw new GateError(`--${name} expects a value`);
    }
    args.set(name, value);
    index += 1;
  }
  return args;
}

function scanTree(args) {
  const root = path.resolve(requireArgument(args, 'root'));
  const rulesDir = controlPath(args, 'rules');
  const stateDir = path.resolve(requireArgument(args, 'state'));
  const label = args.get('label') ?? 'scan';
  const catalog = loadRuleCatalog(rulesDir);
  const scope = validateScope(readJson(controlPath(args, 'scope'), 'scope'));
  const expectedVersion = readPinnedVersion(controlPath(args, 'lock'));
  const targets = computeTargets(root, scope);
  const { output } = runSemgrep({
    semgrep: requireArgument(args, 'semgrep'),
    rulesDir,
    cwd: root,
    targets,
    stateDir,
    label,
  });
  const { results, problems } = validateSemgrepOutput(output, { expectedVersion, targets, catalog });
  const findings = buildFindings(
    results,
    (file) => fs.readFileSync(regularFileInside(root, file, 'finding'), 'utf8'),
    catalog,
  );
  return { label, catalog, targets, findings, problems, version: expectedVersion };
}

function commandCheck(args) {
  const scan = scanTree(args);
  const baseline = validateBaseline(readJson(controlPath(args, 'baseline'), 'baseline'), scan.catalog);
  const comparison = compareWithBaseline(scan.findings, baseline);
  const report = renderReport({ ...scan, comparison });
  if (args.get('github')) {
    printUntrusted(report);
    const annotations = renderAnnotations(comparison.fresh);
    if (annotations) {
      process.stdout.write(`${annotations}\n`);
    }
  } else {
    process.stdout.write(report);
  }
  if (args.has('summary')) {
    fs.appendFileSync(args.get('summary'), renderSummary({ ...scan, comparison }), 'utf8');
  }
  if (scan.problems.length > 0) {
    throw new GateError(`Dart SAST (${scan.label}): the scan is incomplete; see INCOMPLETE lines above.`);
  }
  if (comparison.fresh.length > 0) {
    throw new GateError(
      `Dart SAST (${scan.label}): ${comparison.fresh.length} new finding(s). Fix them, or record a `
        + 'reviewed baseline entry in a separate, earlier pull request (docs/runbooks/DART_SAST.md).',
      1,
    );
  }
  process.stdout.write(`Dart SAST (${scan.label}): no new finding.\n`);
}

function commandBaseline(args) {
  const scan = scanTree(args);
  const today = new Date().toISOString().slice(0, 10);
  const entries = scan.findings.map((finding) => ({
    rule: finding.rule,
    path: finding.path,
    fingerprint: finding.fingerprint,
    occurrence: finding.occurrence,
    classification: 'false-positive | accepted-risk',
    reviewedAt: today,
    justification: 'TODO: why this finding is not a vulnerability or why the risk is accepted.',
    revisitWhen: 'TODO: the concrete change that would invalidate this decision.',
  }));
  process.stdout.write(`${JSON.stringify({ schema: BASELINE_SCHEMA, entries }, null, 2)}\n`);
  if (scan.problems.length > 0) {
    throw new GateError(`the scan is incomplete:\n${scan.problems.join('\n')}`);
  }
}

// Annotations: `// ruleid: a, b` (or `# `, `<!-- … -->`, bare) applies to the next line that is
// neither blank nor another annotation.
const ANNOTATION = /^\s*(?:\/\/+|#|<!--|;)?\s*(ruleid|ok):\s*([a-z0-9-]+(?:\s*,\s*[a-z0-9-]+)*)\s*(?:-->)?\s*$/;

export function parseFixtureAnnotations(file, text) {
  const lines = text.split(/\r?\n/);
  const expected = [];
  const forbidden = [];
  lines.forEach((line, index) => {
    const match = ANNOTATION.exec(line);
    if (!match) {
      return;
    }
    let target = index + 1;
    while (target < lines.length && (lines[target].trim() === '' || ANNOTATION.test(lines[target]))) {
      target += 1;
    }
    if (target >= lines.length) {
      throw new GateError(`${file}:${index + 1}: annotation has no following code line`);
    }
    for (const rule of match[2].split(',').map((item) => item.trim())) {
      (match[1] === 'ruleid' ? expected : forbidden).push({ file, line: target + 1, rule });
    }
  });
  return { expected, forbidden };
}

export function evaluateFixtures({ catalog, annotations, results, problems }) {
  const failures = [...problems];
  const key = (item) => `${item.file}:${item.line}:${item.rule}`;
  const actual = new Set(results.map((result) => key({ file: result.path, line: result.start.line, rule: result.rule })));
  const expected = new Set(annotations.expected.map(key));
  const forbidden = new Set(annotations.forbidden.map(key));
  for (const item of [...annotations.expected, ...annotations.forbidden]) {
    if (!catalog.has(item.rule)) {
      failures.push(`${item.file}:${item.line}: annotation names unknown rule ${item.rule}`);
    }
  }
  for (const item of expected) {
    if (!actual.has(item)) {
      failures.push(`missed: ${item} (expected by a ruleid annotation)`);
    }
  }
  for (const item of forbidden) {
    if (actual.has(item)) {
      failures.push(`false positive: ${item} (forbidden by an ok annotation)`);
    }
  }
  for (const item of actual) {
    if (!expected.has(item) && !forbidden.has(item)) {
      failures.push(`unexpected: ${item} (no ruleid annotation)`);
    }
  }
  for (const rule of catalog.keys()) {
    if (!annotations.expected.some((item) => item.rule === rule)) {
      failures.push(`rule ${rule} has no positive fixture (ruleid)`);
    }
    if (!annotations.forbidden.some((item) => item.rule === rule)) {
      failures.push(`rule ${rule} has no negative fixture (ok)`);
    }
  }
  return failures;
}

export function listFixtureFiles(fixturesDir) {
  const files = [];
  const walk = (relative) => {
    const absolute = path.join(fixturesDir, relative);
    for (const entry of fs.readdirSync(absolute, { withFileTypes: true })) {
      const child = relative ? `${relative}/${entry.name}` : entry.name;
      if (entry.isSymbolicLink()) {
        throw new GateError(`fixtures: ${child} is a symbolic link`);
      }
      if (entry.isDirectory()) {
        walk(child);
      } else if (entry.isFile()) {
        files.push(safeRelativePath(child, 'fixture'));
      } else {
        throw new GateError(`fixtures: ${child} is not a regular file`);
      }
    }
  };
  walk('');
  return files.sort();
}

function commandTestRules(args) {
  const rulesDir = controlPath(args, 'rules');
  const fixturesDir = controlPath(args, 'fixtures');
  const label = args.get('label') ?? 'rules';
  const catalog = loadRuleCatalog(rulesDir);
  const expectedVersion = readPinnedVersion(controlPath(args, 'lock'));
  const targets = listFixtureFiles(fixturesDir);
  if (targets.length === 0) {
    throw new GateError(`${fixturesDir}: no fixture found`);
  }
  const annotations = { expected: [], forbidden: [] };
  for (const file of targets) {
    const parsed = parseFixtureAnnotations(file, fs.readFileSync(path.join(fixturesDir, file), 'utf8'));
    annotations.expected.push(...parsed.expected);
    annotations.forbidden.push(...parsed.forbidden);
  }
  const { output } = runSemgrep({
    semgrep: requireArgument(args, 'semgrep'),
    rulesDir,
    cwd: fixturesDir,
    targets,
    stateDir: path.resolve(requireArgument(args, 'state')),
    label: `${label}-fixtures`,
  });
  const { results, problems } = validateSemgrepOutput(output, { expectedVersion, targets, catalog });
  const failures = evaluateFixtures({ catalog, annotations, results, problems });
  const summary = `Dart SAST rule tests (${label}): ${catalog.size} rules, ${targets.length} fixtures, `
    + `${annotations.expected.length} positive and ${annotations.forbidden.length} negative cases.`;
  if (failures.length > 0) {
    const text = `${summary}\n${failures.map((failure) => `FAIL ${failure}`).join('\n')}\n`;
    if (args.get('github')) {
      printUntrusted(text);
    } else {
      process.stdout.write(text);
    }
    throw new GateError(`Dart SAST rule tests (${label}): ${failures.length} failure(s).`, 1);
  }
  process.stdout.write(`${summary} All passed.\n`);
}

export function main(argv) {
  const [command, ...rest] = argv;
  const args = parseArguments(rest);
  switch (command) {
    case 'check':
      return commandCheck(args);
    case 'test-rules':
      return commandTestRules(args);
    case 'baseline':
      return commandBaseline(args);
    default:
      throw new GateError('usage: dart-sast.mjs <check|test-rules|baseline> --key value ...');
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    main(process.argv.slice(2));
  } catch (error) {
    const exitCode = error instanceof GateError ? error.exitCode : 2;
    const message = `${error instanceof GateError ? error.message : error.stack}\n`;
    if (process.argv.includes('--github')) {
      // The message can quote scanner output about pull request files: never let it issue
      // workflow commands.
      printUntrusted(message);
      process.stdout.write(`::error title=Dart SAST::${exitCode === 1 ? 'New Dart SAST finding or failed rule test' : 'Dart SAST scan invalid or incomplete'} (see the job log).\n`);
    } else {
      process.stderr.write(message);
    }
    process.exitCode = exitCode;
  }
}
