import assert from 'node:assert/strict';
import test from 'node:test';
import { validatePersistentCachePolicy } from './workflow-security-cache-policy.mjs';

function workflow(step, runner = 'certigo-trusted') {
  return `
on: push
jobs:
  release:
    runs-on: [self-hosted, Linux, X64, ${runner}]
    steps:
      ${step}
`;
}

test('accepts only explicitly disabled cache inputs', () => {
  const errors = validatePersistentCachePolicy(
    workflow('- uses: example/action@0123456789012345678901234567890123456789\n'
      + '        with: { cache: false, pub-cache: false }'),
    'fixture.yml',
  );
  assert.deepEqual(errors, []);
});

test('accepts Flutter setup with explicit cache opt-out on persistent PR runners', () => {
  const errors = validatePersistentCachePolicy(
    workflow(
      '- uses: subosito/flutter-action@0123456789012345678901234567890123456789\n'
      + '        with: { cache: false }',
      'certigo-pr',
    ),
    'fixture.yml',
  );
  assert.deepEqual(errors, []);
});

test('ignores cache inputs on non-persistent runner jobs', () => {
  const errors = validatePersistentCachePolicy(
    workflow(
      '- uses: example/action@0123456789012345678901234567890123456789\n'
      + '        with: { cache: true }',
      'ephemeral',
    ),
    'fixture.yml',
  );
  assert.deepEqual(errors, []);
});

for (const [name, step] of [
  ['direct cache action', '- uses: actions/cache@0123456789012345678901234567890123456789'],
  ['cache restore action', '- uses: Actions/cache/restore@0123456789012345678901234567890123456789'],
  ['cache save action', '- uses: actions/cache/save@0123456789012345678901234567890123456789'],
  [
    'Flutter action with implicit cache input',
    '- uses: subosito/flutter-action@0123456789012345678901234567890123456789',
  ],
  ['enabled cache', '- uses: example/action@0123456789012345678901234567890123456789\n'
    + '        with:\n          cache: true'],
  ['case-variant cache', '- uses: example/action@0123456789012345678901234567890123456789\n'
    + '        with:\n          CACHE: true'],
  ['dynamic Pub cache', '- uses: example/action@0123456789012345678901234567890123456789\n'
    + '        with: { pub-cache: "${{ inputs.cache }}" }'],
]) {
  test(`rejects ${name}`, () => {
    const errors = validatePersistentCachePolicy(workflow(step), 'fixture.yml');
    assert.equal(errors.length, 1);
  });
}

test('rejects enabled Flutter cache on persistent PR runners', () => {
  const errors = validatePersistentCachePolicy(
    workflow(
      '- uses: subosito/flutter-action@0123456789012345678901234567890123456789\n'
      + '        with: { cache: true }',
      'certigo-pr',
    ),
    'fixture.yml',
  );
  assert.equal(errors.length, 1);
});

test('the job parser refuses to report an empty result instead of passing silently', async () => {
  // Asserted on the source, following the marker convention used elsewhere for
  // validate-workflow-security.mjs, because that module runs its checks at import
  // time and cannot be imported from a test.
  //
  // The failure this guards is silent: a CRLF workflow makes the '\njobs:\n' probe
  // miss, jobBlocks returns nothing, and every job-level rule below it is skipped
  // while the validator still exits 0. Measured on a CRLF copy of runner-health.yml:
  // exit 0 "Workflow security policy passed." before this guard, exit 1 naming the
  // unreadable file after it. .gitattributes normalises line endings today, so the
  // guard closes the class - CRLF, a byte order mark, an indented `jobs:` - rather
  // than relying on that one defence staying in place.
  const { readFileSync } = await import('node:fs');
  const { join, dirname } = await import('node:path');
  const { fileURLToPath } = await import('node:url');

  const source = readFileSync(
    join(dirname(fileURLToPath(import.meta.url)), 'validate-workflow-security.mjs'),
    'utf8',
  );

  // Positive control: prove this read can see a construct that has always been
  // there, so a missing match below means an absent guard, not an unreadable file.
  assert.ok(
    source.includes('function jobBlocks(text) {'),
    'expected to still see jobBlocks; otherwise the assertions below prove nothing',
  );

  assert.ok(
    /if \(matches\.length === 0\) \{\s*throw new Error\(/.test(source),
    'jobBlocks must raise when it finds no jobs rather than return an empty list',
  );
  assert.ok(
    source.includes('the job parser found no jobs'),
    'the raised error must say the parser cannot read the file',
  );
  assert.ok(
    /catch \(error\) \{\s*errors\.push\(`\$\{file\}: \$\{error\.message\}`\);/.test(source),
    'the raised error must surface as a validation error, not as a crash',
  );
});
