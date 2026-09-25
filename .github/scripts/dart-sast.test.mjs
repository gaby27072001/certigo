import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  BASELINE_SCHEMA,
  DEFAULT_CONTROLS,
  GateError,
  buildFindings,
  compareWithBaseline,
  computeTargets,
  evaluateFixtures,
  fingerprintFor,
  listFixtureFiles,
  loadRuleCatalog,
  parseArguments,
  parseFixtureAnnotations,
  parseRuleCatalog,
  readPinnedVersion,
  renderAnnotations,
  renderReport,
  renderSummary,
  safeRelativePath,
  selectScopeTargets,
  semgrepArguments,
  semgrepEnvironment,
  snippetFor,
  validateBaseline,
  validateScope,
  validateSemgrepOutput,
} from './dart-sast.mjs';

const scriptPath = fileURLToPath(new URL('./dart-sast.mjs', import.meta.url));

const RULES = `rules:
  - id: dart-sample-logged
    metadata:
      certigo-risk: logging
    pattern: print($X)
  - id: dart-sample-secret
    metadata:
      certigo-risk: secrets
      certigo-redact: true
    pattern: secret($X)
`;

function catalog() {
  return parseRuleCatalog([{ name: 'sample.yaml', text: RULES }]);
}

function scope(overrides = {}) {
  return {
    schema: 'certigo.dart-sast-scope/v1',
    roots: ['apps/mobile', 'packages'],
    everywhereExtensions: ['.dart'],
    excludePrefixes: ['.github/sast/tests/'],
    binaryExtensions: ['.png'],
    ...overrides,
  };
}

function result(overrides = {}) {
  return {
    check_id: 'dart-sample-logged',
    path: 'apps/mobile/lib/a.dart',
    start: { line: 2, col: 3, offset: 20 },
    end: { line: 2, col: 18, offset: 35 },
    extra: { severity: 'ERROR', message: 'sample message' },
    ...overrides,
  };
}

function output(overrides = {}) {
  return {
    version: '1.178.0',
    results: [result()],
    errors: [],
    paths: { scanned: ['apps/mobile/lib/a.dart', 'packages/core/lib/b.dart'] },
    ...overrides,
  };
}

const targets = ['apps/mobile/lib/a.dart', 'packages/core/lib/b.dart'];

function entry(overrides = {}) {
  return {
    rule: 'dart-sample-logged',
    path: 'apps/mobile/lib/a.dart',
    fingerprint: `sha256:${'a'.repeat(64)}`,
    occurrence: 1,
    classification: 'false-positive',
    reviewedAt: '2026-09-24',
    justification: 'The printed value is a constant label, never a credential.',
    revisitWhen: 'The printed expression starts carrying user or session data.',
    ...overrides,
  };
}

test('the committed controls are consistent and every rule has both fixture kinds', () => {
  const catalog = loadRuleCatalog(DEFAULT_CONTROLS.rules);
  assert.ok(catalog.size >= 30, `only ${catalog.size} rules found`);
  validateScope(JSON.parse(fs.readFileSync(DEFAULT_CONTROLS.scope, 'utf8')));
  validateBaseline(JSON.parse(fs.readFileSync(DEFAULT_CONTROLS.baseline, 'utf8')), catalog);
  assert.match(readPinnedVersion(DEFAULT_CONTROLS.lock), /^\d+\.\d+\.\d+$/);
  assert.match(fs.readFileSync(DEFAULT_CONTROLS.lock, 'utf8'), /--hash=sha256:[0-9a-f]{64}/);

  const annotations = { expected: [], forbidden: [] };
  for (const file of listFixtureFiles(DEFAULT_CONTROLS.fixtures)) {
    const text = fs.readFileSync(path.join(DEFAULT_CONTROLS.fixtures, file), 'utf8');
    const parsed = parseFixtureAnnotations(file, text);
    annotations.expected.push(...parsed.expected);
    annotations.forbidden.push(...parsed.forbidden);
  }
  const named = new Set([...annotations.expected, ...annotations.forbidden].map((item) => item.rule));
  assert.deepEqual([...named].filter((rule) => !catalog.has(rule)), []);
  for (const rule of catalog.keys()) {
    assert.ok(annotations.expected.some((item) => item.rule === rule), `${rule} has no ruleid fixture`);
    assert.ok(annotations.forbidden.some((item) => item.rule === rule), `${rule} has no ok fixture`);
  }
});

test('repository-relative paths are normalized and unsafe paths are refused', () => {
  assert.equal(safeRelativePath('./apps/mobile/lib/a.dart', 'p'), 'apps/mobile/lib/a.dart');
  for (const unsafe of ['', '/etc/passwd', 'C:/x.dart', 'a\\b.dart', 'a/../b.dart', 'a//b.dart', 'a/\nb.dart']) {
    assert.throws(() => safeRelativePath(unsafe, 'p'), GateError, unsafe);
  }
});

test('the rule catalog requires unique, prefixed ids with a declared risk', () => {
  const rules = catalog();
  assert.deepEqual([...rules.keys()], ['dart-sample-logged', 'dart-sample-secret']);
  assert.equal(rules.get('dart-sample-logged').redact, false);
  assert.equal(rules.get('dart-sample-secret').redact, true);
  assert.equal(rules.get('dart-sample-secret').risk, 'secrets');
  assert.throws(
    () => parseRuleCatalog([{ name: 'x.yaml', text: `${RULES}  - id: dart-sample-logged\n    metadata:\n      certigo-risk: logging\n` }]),
    /duplicate rule id/,
  );
  assert.throws(
    () => parseRuleCatalog([{ name: 'x.yaml', text: 'rules:\n  - id: other.rule\n    metadata:\n      certigo-risk: tls\n' }]),
    /must match/,
  );
  assert.throws(
    () => parseRuleCatalog([{ name: 'x.yaml', text: 'rules:\n  - id: dart-no-risk\n    pattern: x\n' }]),
    /certigo-risk/,
  );
  assert.throws(() => parseRuleCatalog([{ name: 'x.yaml', text: 'rules: []\n' }]), /no rule found/);
});

test('the scope selects mobile files and every Dart file, minus fixtures and binaries', () => {
  const tracked = [
    'apps/mobile/lib/a.dart',
    'apps/mobile/android/app/src/main/AndroidManifest.xml',
    'apps/mobile/assets/logo.png',
    'apps/mobile/assets/raw.bin',
    'packages/core/lib/b.dart',
    'tools/generator.dart',
    'tools/generator.py',
    'backend/src/Api.cs',
    '.github/sast/tests/dart/fixture.dart',
  ];
  const selected = selectScopeTargets(tracked, validateScope(scope()), (file) => file.endsWith('.bin'));
  assert.deepEqual(selected, [
    'apps/mobile/android/app/src/main/AndroidManifest.xml',
    'apps/mobile/lib/a.dart',
    'packages/core/lib/b.dart',
    'tools/generator.dart',
  ]);
  assert.throws(() => validateScope(scope({ roots: [] })), /at least one root/);
  assert.throws(() => validateScope(scope({ excludePrefixes: ['.github/sast'] })), /must end with/);
  assert.throws(() => validateScope(scope({ binaryExtensions: ['png'] })), /invalid extension/);
  assert.throws(() => validateScope({ ...scope(), extra: true }), /unexpected key/);
});

test('Semgrep runs offline, without inline suppressions or ignore files, on explicit targets', () => {
  const args = semgrepArguments({ rulesDir: '/trusted/rules', output: '/state/out.json', targets: ['-x.dart', 'a.dart'] });
  for (const flag of [
    '--metrics=off',
    '--disable-version-check',
    '--oss-only',
    '--disable-nosem',
    '--no-rewrite-rule-ids',
    '--x-ignore-semgrepignore-files',
    '--no-git-ignore',
    '--max-target-bytes=0',
  ]) {
    assert.ok(args.includes(flag), flag);
  }
  const separator = args.indexOf('--');
  assert.ok(separator > 0);
  assert.deepEqual(args.slice(separator + 1), ['./-x.dart', './a.dart']);
  assert.equal(args[args.indexOf('--config') + 1], '/trusted/rules');
});

test('the Semgrep environment drops inherited Semgrep settings and credentials', (context) => {
  const state = fs.mkdtempSync(path.join(os.tmpdir(), 'dart-sast-env-'));
  context.after(() => fs.rmSync(state, { recursive: true, force: true }));
  const environment = semgrepEnvironment(state, {
    PATH: '/usr/bin',
    HOME: '/home/runner',
    SEMGREP_APP_TOKEN: 'leaked',
    SEMGREP_RULES: 'p/default',
    GITHUB_TOKEN: 'leaked',
  });
  assert.equal(environment.PATH, '/usr/bin');
  assert.equal(environment.SEMGREP_SEND_METRICS, 'off');
  assert.equal(environment.SEMGREP_ENABLE_VERSION_CHECK, '0');
  assert.equal(environment.HOME, path.join(state, 'home'));
  for (const key of ['SEMGREP_APP_TOKEN', 'SEMGREP_RULES', 'GITHUB_TOKEN']) {
    assert.equal(environment[key], undefined, key);
  }
});

test('the pinned Semgrep version is read from the hash-locked requirements', (context) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'dart-sast-lock-'));
  context.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const lock = path.join(directory, 'lock.txt');
  fs.writeFileSync(lock, 'rich==15.0.0 \\\n    --hash=sha256:00\nsemgrep==1.178.0 \\\n    --hash=sha256:11\n');
  assert.equal(readPinnedVersion(lock), '1.178.0');
  fs.writeFileSync(lock, 'semgrep>=1.0\n');
  assert.throws(() => readPinnedVersion(lock), /exactly one pinned/);
});

test('scanner output is rejected when incomplete, foreign or from another version', () => {
  const rules = catalog();
  const valid = validateSemgrepOutput(output(), { expectedVersion: '1.178.0', targets, catalog: rules });
  assert.equal(valid.problems.length, 0);
  assert.equal(valid.results[0].path, 'apps/mobile/lib/a.dart');

  assert.throws(
    () => validateSemgrepOutput(output({ version: '1.177.0' }), { expectedVersion: '1.178.0', targets, catalog: rules }),
    /differs from the pinned/,
  );
  const incomplete = validateSemgrepOutput(
    output({
      errors: [{ type: ['PartialParsing', []], path: 'apps/mobile/lib/a.dart', message: 'Syntax error\nat line 2' }],
      paths: { scanned: ['./apps/mobile/lib/a.dart', 'extra/c.dart'] },
    }),
    { expectedVersion: '1.178.0', targets, catalog: rules },
  );
  assert.deepEqual(incomplete.problems, [
    'Semgrep reported PartialParsing in apps/mobile/lib/a.dart: Syntax error',
    'target was not analysed by any rule: packages/core/lib/b.dart',
    'Semgrep analysed a file outside the requested targets: extra/c.dart',
  ]);
  assert.throws(
    () => validateSemgrepOutput(output({ results: [result({ check_id: 'registry.rule' })] }), { targets, catalog: rules }),
    /unknown rule/,
  );
  assert.throws(
    () => validateSemgrepOutput(output({ results: [result({ path: 'backend/x.cs' })] }), { targets, catalog: rules }),
    /not a requested target/,
  );
  assert.throws(
    () => validateSemgrepOutput(output({ results: [result({ extra: { severity: 'CRITICAL' } })] }), { targets, catalog: rules }),
    /invalid severity/,
  );
  assert.throws(() => validateSemgrepOutput({ results: [] }, { targets, catalog: rules }), /must be arrays/);
});

test('fingerprints survive line shifts and reformatting but change with the code', () => {
  const rules = catalog();
  const original = 'void main() {\n  print(token);\n}\n';
  const shifted = '// header\n\nvoid main() {\n    print(token);\n}\n';
  const changed = 'void main() {\n  print(password);\n}\n';
  const at = (line) => [{ ...validateSemgrepOutput(output(), { targets, catalog: rules }).results[0], start: { line, col: 3, offset: 0 }, end: { line, col: 15, offset: 12 } }];
  const [first] = buildFindings(at(2), () => original, rules);
  const [moved] = buildFindings(at(4), () => shifted, rules);
  const [edited] = buildFindings(at(2), () => changed, rules);
  assert.equal(first.snippet, 'print(token);');
  assert.equal(moved.fingerprint, first.fingerprint);
  assert.notEqual(edited.fingerprint, first.fingerprint);
  assert.equal(first.fingerprint, fingerprintFor('dart-sample-logged', 'apps/mobile/lib/a.dart', 'print(token);'));
  assert.equal(snippetFor('a\r\n  b  \r\nc', 1, 2), 'a b');
});

test('identical findings in one file get distinct occurrences and duplicates collapse', () => {
  const rules = catalog();
  const source = 'print(token);\nprint(token);\n';
  const base = validateSemgrepOutput(output(), { targets, catalog: rules }).results[0];
  const results = [
    { ...base, start: { line: 2, col: 1, offset: 14 }, end: { line: 2, col: 13, offset: 26 } },
    { ...base, start: { line: 1, col: 1, offset: 0 }, end: { line: 1, col: 13, offset: 12 } },
    { ...base, start: { line: 1, col: 1, offset: 0 }, end: { line: 1, col: 13, offset: 12 } },
  ];
  const findings = buildFindings(results, () => source, rules);
  assert.equal(findings.length, 2);
  assert.deepEqual(findings.map((finding) => [finding.line, finding.occurrence]), [[1, 1], [2, 2]]);
  assert.equal(findings[0].fingerprint, findings[1].fingerprint);
});

test('baseline entries must be dated, justified, unique and name known rules', () => {
  const rules = catalog();
  const baseline = { schema: BASELINE_SCHEMA, entries: [entry()] };
  assert.equal(validateBaseline(baseline, rules).length, 1);
  const invalid = [
    [{ ...baseline, schema: 'other' }, /unsupported schema/],
    [{ ...baseline, entries: [entry({ rule: 'dart-unknown' })] }, /unknown rule/],
    [{ ...baseline, entries: [entry({ classification: 'wontfix' })] }, /classification/],
    [{ ...baseline, entries: [entry({ reviewedAt: '2026-02-30' })] }, /real YYYY-MM-DD/],
    [{ ...baseline, entries: [entry({ justification: 'ok' })] }, /justification/],
    [{ ...baseline, entries: [entry({ revisitWhen: '' })] }, /revisitWhen/],
    [{ ...baseline, entries: [entry({ fingerprint: 'sha256:ABC' })] }, /fingerprint/],
    [{ ...baseline, entries: [entry({ occurrence: 0 })] }, /occurrence/],
    [{ ...baseline, entries: [entry(), entry()] }, /duplicate/],
    [{ ...baseline, entries: [{ ...entry(), expires: '2027-01-01' }] }, /unexpected key/],
  ];
  for (const [value, message] of invalid) {
    assert.throws(() => validateBaseline(value, rules), message);
  }
});

test('only findings absent from the baseline are new; unmatched entries are stale', () => {
  const finding = {
    rule: 'dart-sample-logged',
    path: 'apps/mobile/lib/a.dart',
    fingerprint: `sha256:${'a'.repeat(64)}`,
    occurrence: 1,
  };
  const other = { ...finding, fingerprint: `sha256:${'b'.repeat(64)}` };
  const movedFile = { ...finding, path: 'apps/mobile/lib/moved.dart' };
  const staleEntry = entry({ fingerprint: `sha256:${'c'.repeat(64)}` });
  const comparison = compareWithBaseline([finding, other, movedFile], [entry(), staleEntry]);
  assert.deepEqual(comparison.accepted.map(({ finding: accepted }) => accepted), [finding]);
  assert.deepEqual(comparison.fresh, [other, movedFile]);
  assert.deepEqual(comparison.stale, [staleEntry]);
});

test('reports redact secret rules and escape workflow commands and markdown', () => {
  const finding = {
    rule: 'dart-sample-secret',
    path: 'apps/mobile/lib/a,b:c%.dart',
    line: 3,
    column: 5,
    severity: 'ERROR',
    message: 'secret\nfound',
    snippet: 'final apiKey = "real-secret-value-123";',
    fingerprint: `sha256:${'d'.repeat(64)}`,
    occurrence: 1,
    redact: true,
  };
  const comparison = { fresh: [finding], accepted: [], stale: [] };
  const report = renderReport({ label: 'trusted', targets: ['x'], findings: [finding], comparison, problems: [] });
  assert.ok(!report.includes('real-secret-value-123'));
  assert.match(report, /<redacted: secret rule>/);
  assert.match(report, /secret found/);
  assert.equal(
    renderAnnotations([finding]),
    '::error file=apps/mobile/lib/a%2Cb%3Ac%25.dart,line=3,col=5,title=Dart SAST dart-sample-secret::'
      + 'dart-sample-secret (new error finding, details in the job log)',
  );
  const summary = renderSummary({
    label: 'trusted',
    targets: ['x'],
    findings: [{ ...finding, path: 'a|b`<img>`.dart' }],
    comparison: { fresh: [{ ...finding, path: 'a|b`<img>`.dart' }], accepted: [], stale: [] },
    problems: [],
    version: '1.178.0',
  });
  assert.match(summary, /a\\\|b\\`\\<img\\>\\`\.dart:3/);
  assert.ok(!summary.includes('real-secret-value-123'));
});

test('fixture annotations target the next code line in any comment style', () => {
  const text = [
    '// ruleid: dart-sample-logged, dart-sample-secret',
    '',
    'print(secret(x));',
    '<!-- ok: dart-sample-logged -->',
    '# ok: dart-sample-secret',
    'safe();',
    'ruleid: dart-sample-secret',
    'secret(y);',
  ].join('\n');
  const parsed = parseFixtureAnnotations('f.dart', text);
  assert.deepEqual(parsed.expected, [
    { file: 'f.dart', line: 3, rule: 'dart-sample-logged' },
    { file: 'f.dart', line: 3, rule: 'dart-sample-secret' },
    { file: 'f.dart', line: 8, rule: 'dart-sample-secret' },
  ]);
  assert.deepEqual(parsed.forbidden, [
    { file: 'f.dart', line: 6, rule: 'dart-sample-logged' },
    { file: 'f.dart', line: 6, rule: 'dart-sample-secret' },
  ]);
  assert.throws(() => parseFixtureAnnotations('f.dart', 'x();\n// ok: dart-sample-logged\n'), /no following code line/);
});

test('rule tests fail on misses, false positives, unexpected hits and untested rules', () => {
  const rules = catalog();
  const annotations = {
    expected: [
      { file: 'f.dart', line: 3, rule: 'dart-sample-logged' },
      { file: 'f.dart', line: 9, rule: 'dart-sample-logged' },
    ],
    forbidden: [
      { file: 'f.dart', line: 6, rule: 'dart-sample-logged' },
      { file: 'f.dart', line: 7, rule: 'dart-unknown' },
    ],
  };
  const hit = (line, rule = 'dart-sample-logged') => ({ path: 'f.dart', start: { line }, rule });
  const failures = evaluateFixtures({
    catalog: rules,
    annotations,
    results: [hit(3), hit(6), hit(12)],
    problems: ['target was not analysed by any rule: g.dart'],
  });
  assert.deepEqual(failures, [
    'target was not analysed by any rule: g.dart',
    'f.dart:7: annotation names unknown rule dart-unknown',
    'missed: f.dart:9:dart-sample-logged (expected by a ruleid annotation)',
    'false positive: f.dart:6:dart-sample-logged (forbidden by an ok annotation)',
    'unexpected: f.dart:12:dart-sample-logged (no ruleid annotation)',
    'rule dart-sample-secret has no positive fixture (ruleid)',
    'rule dart-sample-secret has no negative fixture (ok)',
  ]);
  const clean = evaluateFixtures({
    catalog: rules,
    annotations: {
      expected: [{ file: 'f.dart', line: 1, rule: 'dart-sample-logged' }, { file: 'f.dart', line: 2, rule: 'dart-sample-secret' }],
      forbidden: [{ file: 'f.dart', line: 3, rule: 'dart-sample-logged' }, { file: 'f.dart', line: 3, rule: 'dart-sample-secret' }],
    },
    results: [hit(1), hit(2, 'dart-sample-secret')],
    problems: [],
  });
  assert.deepEqual(clean, []);
});

test('command-line arguments are strict key/value pairs', () => {
  assert.deepEqual([...parseArguments(['--root', '.', '--github'])], [['root', '.'], ['github', true]]);
  assert.throws(() => parseArguments(['root']), /unexpected argument/);
  assert.throws(() => parseArguments(['--root']), /expects a value/);
  assert.throws(() => parseArguments(['--root', '--rules', 'x']), /expects a value/);
});

function git(cwd, args) {
  const run = spawnSync('git', ['-c', 'core.hooksPath=/dev/null', ...args], { cwd, encoding: 'utf8' });
  assert.equal(run.status, 0, run.stderr);
  return run.stdout;
}

function repository(context, files) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'dart-sast-repo-'));
  context.after(() => fs.rmSync(root, { recursive: true, force: true }));
  for (const [file, content] of Object.entries(files)) {
    fs.mkdirSync(path.dirname(path.join(root, file)), { recursive: true });
    fs.writeFileSync(path.join(root, file), content);
  }
  git(root, ['init', '-q']);
  git(root, ['add', '-A']);
  git(root, ['-c', 'user.email=ci@example.invalid', '-c', 'user.name=ci', 'commit', '-qm', 'fixture']);
  return root;
}

test('targets come from tracked files only and binaries are skipped by content', (context) => {
  const root = repository(context, {
    'apps/mobile/lib/a.dart': 'void a() {}\n',
    'apps/mobile/assets/blob.dat': Buffer.from([0x41, 0x00, 0x42]),
    'apps/mobile/README.md': '# mobile\n',
    'backend/src/x.cs': 'class X {}\n',
  });
  fs.writeFileSync(path.join(root, 'apps/mobile/lib/untracked.dart'), 'void b() {}\n');
  assert.deepEqual(computeTargets(root, validateScope(scope())), ['apps/mobile/README.md', 'apps/mobile/lib/a.dart']);
});

test('a tracked symbolic link inside the scope fails closed', { skip: process.platform === 'win32' }, (context) => {
  const root = repository(context, { 'apps/mobile/lib/a.dart': 'void a() {}\n' });
  fs.symlinkSync('/etc/hostname', path.join(root, 'apps/mobile/lib/link.dart'));
  git(root, ['add', '-A']);
  assert.throws(() => computeTargets(root, validateScope(scope())), /symbolic link/);
});

test('an empty or Dart-free scope is refused', (context) => {
  const root = repository(context, { 'apps/mobile/README.md': '# only docs\n' });
  assert.throws(() => computeTargets(root, validateScope(scope())), /no Dart file selected/);
  const empty = repository(context, { 'backend/x.cs': 'class X {}\n' });
  assert.throws(() => computeTargets(empty, validateScope(scope())), /no target selected/);
});

function fakeSemgrep(context, body) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'dart-sast-fake-'));
  context.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const implementation = path.join(directory, 'fake.mjs');
  fs.writeFileSync(implementation, body);
  const launcher = path.join(directory, 'semgrep');
  fs.writeFileSync(launcher, `#!/bin/sh\nexec "${process.execPath}" "${implementation}" "$@"\n`, { mode: 0o755 });
  return launcher;
}

function writeControls(root, baselineEntries = []) {
  fs.mkdirSync(path.join(root, 'controls', 'rules'), { recursive: true });
  fs.writeFileSync(path.join(root, 'controls', 'rules', 'sample.yaml'), RULES);
  fs.writeFileSync(path.join(root, 'controls', 'scope.json'), JSON.stringify(scope()));
  fs.writeFileSync(path.join(root, 'controls', 'lock.txt'), 'semgrep==1.178.0 \\\n    --hash=sha256:00\n');
  fs.writeFileSync(
    path.join(root, 'controls', 'baseline.json'),
    JSON.stringify({ schema: BASELINE_SCHEMA, entries: baselineEntries }),
  );
}

const FAKE_SEMGREP = `
import fs from 'node:fs';
const args = process.argv.slice(2);
const output = args[args.indexOf('--output') + 1];
const targets = args.slice(args.indexOf('--') + 1).map((target) => target.replace(/^\\.\\//, ''));
const results = [];
for (const target of targets) {
  const lines = fs.readFileSync(target, 'utf8').split('\\n');
  let offset = 0;
  lines.forEach((line, index) => {
    const column = line.indexOf('print(token)');
    if (column >= 0) {
      results.push({
        check_id: 'dart-sample-logged',
        path: target,
        start: { line: index + 1, col: column + 1, offset: offset + column },
        end: { line: index + 1, col: column + 13, offset: offset + column + 12 },
        extra: { severity: 'ERROR', message: 'token logged' },
      });
    }
    offset += line.length + 1;
  });
}
fs.writeFileSync(output, JSON.stringify({ version: '1.178.0', results, errors: [], paths: { scanned: targets } }));
`;

function runCheck(root, semgrep, extra = []) {
  return spawnSync(process.execPath, [
    scriptPath,
    'check',
    '--semgrep', semgrep,
    '--rules', path.join(root, 'controls', 'rules'),
    '--scope', path.join(root, 'controls', 'scope.json'),
    '--lock', path.join(root, 'controls', 'lock.txt'),
    '--baseline', path.join(root, 'controls', 'baseline.json'),
    '--root', path.join(root, 'tree'),
    '--state', path.join(root, 'state'),
    ...extra,
  ], { encoding: 'utf8' });
}

test('check exits 1 on a new finding and 0 once it is baselined', { skip: process.platform === 'win32' }, (context) => {
  const workspace = fs.mkdtempSync(path.join(os.tmpdir(), 'dart-sast-e2e-'));
  context.after(() => fs.rmSync(workspace, { recursive: true, force: true }));
  const tree = path.join(workspace, 'tree');
  fs.mkdirSync(path.join(tree, 'apps/mobile/lib'), { recursive: true });
  fs.writeFileSync(path.join(tree, 'apps/mobile/lib/a.dart'), 'void a(String token) {\n  print(token);\n}\n');
  git(tree, ['init', '-q']);
  git(tree, ['add', '-A']);
  const semgrep = fakeSemgrep(context, FAKE_SEMGREP);
  writeControls(workspace);

  const summary = path.join(workspace, 'summary.md');
  const blocked = runCheck(workspace, semgrep, ['--github', '--summary', summary]);
  assert.equal(blocked.status, 1, blocked.stderr);
  assert.match(blocked.stdout, /NEW ERROR dart-sample-logged apps\/mobile\/lib\/a\.dart:2:3/);
  assert.match(blocked.stdout, /::stop-commands::/);
  assert.match(blocked.stdout, /::error file=apps\/mobile\/lib\/a\.dart,line=2,col=3/);
  assert.match(fs.readFileSync(summary, 'utf8'), /new \*\*1\*\*/);

  const fingerprint = /fingerprint (sha256:[0-9a-f]{64}) occurrence 1/.exec(blocked.stdout)[1];
  writeControls(workspace, [entry({ fingerprint })]);
  const accepted = runCheck(workspace, semgrep);
  assert.equal(accepted.status, 0, accepted.stdout + accepted.stderr);
  assert.match(accepted.stdout, /BASELINED dart-sample-logged apps\/mobile\/lib\/a\.dart:2/);
});

test('check exits 2 when Semgrep fails, omits a target or reports an error', { skip: process.platform === 'win32' }, (context) => {
  const workspace = fs.mkdtempSync(path.join(os.tmpdir(), 'dart-sast-e2e-'));
  context.after(() => fs.rmSync(workspace, { recursive: true, force: true }));
  const tree = path.join(workspace, 'tree');
  fs.mkdirSync(path.join(tree, 'apps/mobile/lib'), { recursive: true });
  fs.writeFileSync(path.join(tree, 'apps/mobile/lib/a.dart'), 'void a() {}\n');
  fs.writeFileSync(path.join(tree, 'apps/mobile/lib/b.dart'), 'void b() {}\n');
  git(tree, ['init', '-q']);
  git(tree, ['add', '-A']);
  writeControls(workspace);

  const crashing = fakeSemgrep(context, 'process.exit(7);\n');
  const crashed = runCheck(workspace, crashing);
  assert.equal(crashed.status, 2);
  assert.match(crashed.stderr, /Semgrep exited with status 7/);

  const partial = fakeSemgrep(context, `
import fs from 'node:fs';
const args = process.argv.slice(2);
fs.writeFileSync(args[args.indexOf('--output') + 1], JSON.stringify({
  version: '1.178.0',
  results: [],
  errors: [{ type: ['PartialParsing', []], path: 'apps/mobile/lib/a.dart', message: 'Syntax error' }],
  paths: { scanned: ['apps/mobile/lib/a.dart'] },
}));
`);
  const incomplete = runCheck(workspace, partial);
  assert.equal(incomplete.status, 2);
  assert.match(incomplete.stdout, /INCOMPLETE Semgrep reported PartialParsing in apps\/mobile\/lib\/a\.dart/);
  assert.match(incomplete.stdout, /INCOMPLETE target was not analysed by any rule: apps\/mobile\/lib\/b\.dart/);
});
