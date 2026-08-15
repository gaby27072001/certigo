import assert from 'node:assert/strict';
import test from 'node:test';
import { validateTrustedCachePolicy } from './workflow-security-cache-policy.mjs';

function workflow(step) {
  return `
on: push
jobs:
  release:
    runs-on: [self-hosted, Linux, X64, certigo-trusted]
    steps:
      ${step}
`;
}

test('accepts only explicitly disabled cache inputs', () => {
  const errors = validateTrustedCachePolicy(
    workflow('- uses: example/action@0123456789012345678901234567890123456789\n'
      + '        with: { cache: false, pub-cache: false }'),
    'fixture.yml',
  );
  assert.deepEqual(errors, []);
});

for (const [name, step] of [
  ['direct cache action', '- uses: actions/cache@0123456789012345678901234567890123456789'],
  ['cache restore action', '- uses: Actions/cache/restore@0123456789012345678901234567890123456789'],
  ['cache save action', '- uses: actions/cache/save@0123456789012345678901234567890123456789'],
  ['Flutter tool cache action', '- uses: subosito/flutter-action@0123456789012345678901234567890123456789'],
  ['enabled cache', '- uses: example/action@0123456789012345678901234567890123456789\n'
    + '        with:\n          cache: true'],
  ['case-variant cache', '- uses: example/action@0123456789012345678901234567890123456789\n'
    + '        with:\n          CACHE: true'],
  ['dynamic Pub cache', '- uses: example/action@0123456789012345678901234567890123456789\n'
    + '        with: { pub-cache: "${{ inputs.cache }}" }'],
]) {
  test(`rejects ${name}`, () => {
    const errors = validateTrustedCachePolicy(workflow(step), 'fixture.yml');
    assert.equal(errors.length, 1);
  });
}
