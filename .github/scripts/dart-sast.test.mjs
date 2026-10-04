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
  DirectiveScanError,
  GateError,
  buildFindings,
  compareWithBaseline,
  computeTargets,
  dartDirectiveUris,
  directiveProblems,
  evaluateFixtures,
  fingerprintFor,
  fingerprintTextFor,
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
  scopeIntegrityProblems,
  selectScopeTargets,
  semgrepArguments,
  semgrepEnvironment,
  snippetFor,
  textTargetProblems,
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

test('the scope selects mobile files and every Dart file, minus fixtures and binary extensions', () => {
  const tracked = [
    'apps/mobile/lib/a.dart',
    'apps/mobile/android/app/src/main/AndroidManifest.xml',
    'apps/mobile/assets/logo.png',
    'apps/mobile/assets/LOGO.PNG',
    'apps/mobile/assets/raw.bin',
    'packages/core/lib/b.dart',
    'tools/generator.dart',
    'tools/generator.py',
    'backend/src/Api.cs',
    '.github/sast/tests/dart/fixture.dart',
  ];
  const selected = selectScopeTargets(tracked, validateScope(scope()));
  assert.deepEqual(selected, [
    'apps/mobile/android/app/src/main/AndroidManifest.xml',
    'apps/mobile/assets/raw.bin',
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

test('the fingerprint covers the whole finding, even past the shortened snippet', () => {
  const rules = catalog();
  const body = Array.from({ length: 30 }, (_, index) => `  check${index}();`);
  const source = ['bool onBadCertificate() {', ...body, '  return false;', '}'].join('\n');
  const edited = source.replace('  return false;', '  return true;');
  const base = validateSemgrepOutput(output(), { targets, catalog: rules }).results[0];
  const span = [{ ...base, start: { line: 1, col: 1, offset: 0 }, end: { line: 33, col: 2, offset: 0 } }];
  const [original] = buildFindings(span, () => source, rules);
  const [changed] = buildFindings(span, () => edited, rules);
  assert.notEqual(changed.fingerprint, original.fingerprint);
  assert.equal(changed.snippet, original.snippet);
  assert.ok(original.snippet.endsWith('check18(); …'), original.snippet);
  assert.equal(
    original.fingerprint,
    fingerprintFor('dart-sample-logged', 'apps/mobile/lib/a.dart', fingerprintTextFor(source, 1, 33)),
  );
  assert.equal(fingerprintTextFor('a\n  b\nc', 1, 9), 'a b c');
  assert.equal(snippetFor('a\nb', 1, 2), 'a b');
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

test('a match nested in another match of the same rule is reported once', () => {
  const rules = catalog();
  const source = 'debugPrint(session.accessToken);\n';
  const base = validateSemgrepOutput(output(), { targets, catalog: rules }).results[0];
  const outer = { ...base, start: { line: 1, col: 12, offset: 11 }, end: { line: 1, col: 31, offset: 30 } };
  const inner = { ...base, start: { line: 1, col: 12, offset: 11 }, end: { line: 1, col: 19, offset: 18 } };
  const otherRule = { ...inner, rule: 'dart-sample-secret' };
  const findings = buildFindings([inner, outer, otherRule], () => source, rules);
  assert.deepEqual(
    findings.map((finding) => [finding.rule, finding.start.offset, finding.end.offset]),
    [['dart-sample-secret', 11, 18], ['dart-sample-logged', 11, 30]],
  );
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
  // A repeated option would silently replace the first one, a second --root for instance.
  assert.throws(() => parseArguments(['--root', 'pr', '--root', 'base']), /--root is given more than once/);
  assert.throws(() => parseArguments(['--github', '--github']), /--github is given more than once/);
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

test('targets come from tracked files only and binaries are recognised by extension, never by content', (context) => {
  // Dart compiles a file that holds a NUL byte in a comment (measured with Dart 3.12): sniffing
  // content would let one NUL hide a source file from the scan.
  const root = repository(context, {
    'apps/mobile/lib/a.dart': 'void a() {}\n',
    'apps/mobile/lib/nul.dart': Buffer.from('void n() {}\n// \u0000 hides nothing\n', 'utf8'),
    'apps/mobile/assets/blob.dat': Buffer.from([0x41, 0x00, 0x42]),
    'apps/mobile/assets/logo.png': Buffer.from([0x89, 0x50, 0x4e, 0x47]),
    'apps/mobile/README.md': '# mobile\n',
    'backend/src/x.cs': 'class X {}\n',
  });
  fs.writeFileSync(path.join(root, 'apps/mobile/lib/untracked.dart'), 'void b() {}\n');
  const { targets, tracked } = computeTargets(root, validateScope(scope()));
  assert.deepEqual(targets, [
    'apps/mobile/README.md',
    'apps/mobile/assets/blob.dat',
    'apps/mobile/lib/a.dart',
    'apps/mobile/lib/nul.dart',
  ]);
  assert.ok(tracked.includes('backend/src/x.cs'));
  assert.ok(!tracked.includes('apps/mobile/lib/untracked.dart'));
});

test('a text target must be valid UTF-8 without NUL bytes', () => {
  assert.deepEqual(textTargetProblems('a.dart', Buffer.from('void a() {} // é ✓ 🔒\n', 'utf8')), []);
  assert.deepEqual(textTargetProblems('a.dart', Buffer.from('\ufeffvoid a() {}\n', 'utf8')), []);
  assert.match(
    textTargetProblems('n.dart', Buffer.from('void a() {}\n// \u0000\nvoid b() {}\n', 'utf8')).join(),
    /^n\.dart contains a NUL byte/u,
  );
  const invalid = {
    latin1: [0x2f, 0x2f, 0x20, 0x63, 0x61, 0x66, 0xe9, 0x0a],
    truncated: [0x2f, 0x2f, 0x20, 0xe2, 0x9c],
    overlong: [0x2f, 0x2f, 0xc0, 0xaf],
    surrogate: [0x2f, 0x2f, 0xed, 0xa0, 0x80],
  };
  for (const [name, bytes] of Object.entries(invalid)) {
    assert.match(textTargetProblems(`${name}.dart`, Buffer.from(bytes)).join(), /is not valid UTF-8/u, name);
  }
});

test('directives are read whatever their spelling, as Dart reads them', () => {
  const uris = (text) => dartDirectiveUris(text).map(({ keyword, uri }) => `${keyword} ${uri}`);
  const source = [
    '\uFEFF#!/usr/bin/env dart',
    '@TestOn(\'vm\') library sample;',
    "import 'package:flutter/material.dart';",
    "import 'dart:math' as math show Random hide max;",
    "import /* a /* nested */ comment */ 'hidden1.png';",
    'import',
    "  'hidden2.png'; // line comment 'not.png'",
    "import r'hidden3.png';",
    "import 'other.dart' /* between */ '.png';",
    "import '''hidden4.png''';",
    "import 'x.\\x70ng';",
    "import 'y.\\u{70}ng';",
    "import 'z.\\u0070ng';",
    "import 'a.dart' if (dart.library.io == 'true') 'b.png' if (dart.library.html) 'c.dart';",
    "import 'lazy.dart' deferred as lazy;",
    "import augment 'augmented.png';",
    "export 'exported.png' show A;",
    "part 'part.png';",
    "part of 'library.dart';",
    "final import = 'import \\'not_a_directive.png\\'';",
    "final note = '${call({'export': 'not.png'})} \"part\" ' \"import 'neither.png'\";",
    'class C { void import(String part) {} }',
    "var later = r'''",
    "import 'inside_raw_string.png';",
    "''';",
  ].join('\n');
  assert.deepEqual(uris(source), [
    'import package:flutter/material.dart',
    'import dart:math',
    'import hidden1.png',
    'import hidden2.png',
    'import hidden3.png',
    'import other.dart.png',
    'import hidden4.png',
    'import x.png',
    'import y.png',
    'import z.png',
    'import a.dart',
    'import b.png',
    'import c.dart',
    'import lazy.dart',
    'import augmented.png',
    'export exported.png',
    'part part.png',
  ]);
  for (const broken of [
    "import 'open.dart;\n",
    '/* never closed\nimport \'x.dart\';',
    "final s = '${call(",
    "import 'a.dart' show A",
    "import 'x\\x7';",
  ]) {
    assert.throws(() => dartDirectiveUris(broken), DirectiveScanError, broken);
  }
});

test('only .dart files of the analysed tree may be loaded by a directive', () => {
  const sast = validateScope(scope());
  const problems = (file, text) => directiveProblems(file, text, sast);
  assert.deepEqual(problems('apps/mobile/lib/a.dart', [
    "import 'dart:io';",
    "import 'package:data/data.dart';",
    "import 'src/b.dart';",
    "import '../../../packages/core/lib/core.dart';",
    "export 'src/c.dart' show C;",
    "part 'a.g.dart';",
  ].join('\n')), []);
  const cases = new Map([
    ["import 'hidden.png';", /loads Dart code from a file the scan does not analyse as Dart/u],
    ["import 'b.DART';", /does not analyse as Dart/u],
    ["import 'package:evil/evil.png';", /does not analyse as Dart/u],
    ["part 'p.dart.txt';", /does not analyse as Dart/u],
    ["import 'file:///etc/x.dart';", /unsupported URI scheme/u],
    ["import 'https://evil.example/x.dart';", /unsupported URI scheme/u],
    ["import '../../../../outside.dart';", /resolves outside the analysed tree/u],
    ["import '../../../.github/sast/tests/dart/tls.dart';", /resolves outside the analysed tree/u],
    ["import '%2e%2e/%2e%2e/%2e%2e/%2e%2e/outside.dart';", /resolves outside the analysed tree/u],
    ["import '/abs/x.dart';", /resolves outside the analysed tree/u],
    ["import 'a\\\\b.dart';", /resolves outside the analysed tree/u],
    ["import '%E0%A4%A.dart';", /not a valid relative URI/u],
    ["import 'dart:io$x';", /uses string interpolation/u],
    ["import 'unterminated.dart", /cannot read the directives/u],
  ]);
  for (const [text, pattern] of cases) {
    const found = problems('apps/mobile/lib/a.dart', text);
    assert.equal(found.length, 1, `${text}: ${found.join(' | ')}`);
    assert.match(found[0], pattern, text);
    assert.match(found[0], /^(?:apps\/mobile\/lib\/a\.dart:1: |scan evasion check cannot read the directives of apps\/mobile\/lib\/a\.dart)/u, text);
  }
});

test('no excluded directory may hold a pub package that a path dependency could load', () => {
  const sast = validateScope(scope());
  assert.deepEqual(scopeIntegrityProblems([
    'apps/mobile/pubspec.yaml',
    'packages/core/pubspec.yaml',
    '.github/sast/tests/dart/tls.dart',
  ], sast), []);
  assert.deepEqual(scopeIntegrityProblems([
    '.github/sast/tests/evil/pubspec.yaml',
    '.github/sast/tests/evil/pubspec_overrides.yaml',
    '.github/sast/tests/evil/lib/evil.dart',
  ], sast), [
    '.github/sast/tests/evil/pubspec.yaml would let a path dependency load code the scan excludes',
    '.github/sast/tests/evil/pubspec_overrides.yaml would let a path dependency load code the scan excludes',
  ]);
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

test('check exits 2 when a Dart directive loads code the scan cannot see', { skip: process.platform === 'win32' }, (context) => {
  const workspace = fs.mkdtempSync(path.join(os.tmpdir(), 'dart-sast-e2e-'));
  context.after(() => fs.rmSync(workspace, { recursive: true, force: true }));
  const tree = path.join(workspace, 'tree');
  fs.mkdirSync(path.join(tree, 'apps/mobile/lib'), { recursive: true });
  fs.mkdirSync(path.join(tree, 'apps/mobile/assets'), { recursive: true });
  fs.writeFileSync(
    path.join(tree, 'apps/mobile/lib/a.dart'),
    "import /* looks like an asset */ '../assets/logo.png';\nvoid a() => hidden();\n",
  );
  fs.writeFileSync(path.join(tree, 'apps/mobile/assets/logo.png'), "void hidden() => print('token');\n");
  git(tree, ['init', '-q']);
  git(tree, ['add', '-A']);
  writeControls(workspace);

  const evaded = runCheck(workspace, fakeSemgrep(context, FAKE_SEMGREP), ['--github']);
  assert.equal(evaded.status, 2, evaded.stdout + evaded.stderr);
  assert.match(
    evaded.stdout,
    /INCOMPLETE apps\/mobile\/lib\/a\.dart:1: import "\.\.\/assets\/logo\.png" loads Dart code from a file the scan does not analyse as Dart/u,
  );
  assert.match(evaded.stdout, /::error title=Dart SAST::Dart SAST scan invalid or incomplete/u);
});

test('check exits 2 when a text target holds a NUL byte or invalid UTF-8', { skip: process.platform === 'win32' }, (context) => {
  // Measured: Dart 3.12 compiles both files, and the code after the bad byte runs.
  const hidden = 'void b(String token) {\n  print(token);\n}\n';
  const cases = [
    ['nul.dart', Buffer.from(`void a() {}\n// \u0000\n${hidden}`, 'utf8'), /contains a NUL byte/u],
    ['latin1.dart', Buffer.concat([Buffer.from('// caf'), Buffer.from([0xe9]), Buffer.from(`\n${hidden}`)]), /is not valid UTF-8/u],
  ];
  for (const [name, bytes, problem] of cases) {
    const workspace = fs.mkdtempSync(path.join(os.tmpdir(), 'dart-sast-e2e-'));
    context.after(() => fs.rmSync(workspace, { recursive: true, force: true }));
    const tree = path.join(workspace, 'tree');
    fs.mkdirSync(path.join(tree, 'apps/mobile/lib'), { recursive: true });
    fs.writeFileSync(path.join(tree, 'apps/mobile/lib', name), bytes);
    git(tree, ['init', '-q']);
    git(tree, ['add', '-A']);
    writeControls(workspace);

    const result = runCheck(workspace, fakeSemgrep(context, FAKE_SEMGREP), ['--github']);
    assert.equal(result.status, 2, result.stdout + result.stderr);
    assert.match(result.stdout, new RegExp(`INCOMPLETE apps/mobile/lib/${name.replace('.', '\\.')} ${problem.source}`, 'u'));
    assert.match(result.stdout, /::error title=Dart SAST::Dart SAST scan invalid or incomplete/u);
  }
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
