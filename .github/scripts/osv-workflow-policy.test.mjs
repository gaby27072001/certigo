import assert from 'node:assert/strict';
import test from 'node:test';

import { validateOsvWorkflowPolicy } from './osv-workflow-policy.mjs';

const activePolicy = String.raw`
run: |
  node "$TRUSTED_CONTROL_DIR/.github/scripts/run-osv-scan.mjs" \
    --format=json \
    --no-ignore \
    --forbid-argument=--all-packages \
    --forbid-argument=--recursive \
    --config="$TRUSTED_CONTROL_DIR/.github/osv-scanner.toml" \
    --output-file "$output_temp"
`;

test('accepts an executable strict OSV workflow policy', () => {
  assert.deepEqual(validateOsvWorkflowPolicy(activePolicy), []);
});

test('rejects historical markers present only in comments', () => {
  const markerOnly = String.raw`
run: |
  # --format=json --no-ignore --all-packages
  # --config="$TRUSTED_CONTROL_DIR/.github/osv-scanner.toml"
  # --output-file="$output_temp"
  node "$TRUSTED_CONTROL_DIR/.github/scripts/run-osv-scan.mjs"
`;
  assert.deepEqual(
    validateOsvWorkflowPolicy(markerOnly),
    [
      'OSV workflow lacks executable policy --format=json',
      'OSV workflow lacks executable policy --no-ignore',
      'OSV workflow lacks executable policy --forbid-argument=--all-packages',
      'OSV workflow lacks executable policy --forbid-argument=--recursive',
      'OSV workflow lacks executable policy --config="$TRUSTED_CONTROL_DIR/.github/osv-scanner.toml"',
      'OSV workflow lacks executable policy --output-file "$output_temp"',
    ],
  );
});

test('rejects an executable legacy all-package argument', () => {
  const legacy = `${activePolicy}\n  --all-packages \\\n`;
  assert.match(
    validateOsvWorkflowPolicy(legacy).join('\n'),
    /must not execute recursive all-package discovery/u,
  );
});
