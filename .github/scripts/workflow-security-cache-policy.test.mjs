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
