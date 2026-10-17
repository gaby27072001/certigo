import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const root = new URL('../../', import.meta.url);
const read = (relativePath) => fs.readFileSync(new URL(relativePath, root), 'utf8');

test('solo protection target avoids self-review deadlock without removing stable gates', () => {
  const target = JSON.parse(read('.github/branch-protection-main.json'));
  assert.deepEqual(target.required_status_checks, {
    strict: true,
    contexts: [
      'Build & test',
      'Flutter app + UI packages',
      'Generated state equals committed state',
      'Validate workflow YAML',
      'CodeQL / Security gate',
      'Security / Required gate',
      'Fork PR policy / Required gate',
    ],
  });
  assert.equal(target.enforce_admins, true);
  assert.equal(target.allow_force_pushes, false);
  assert.equal(target.allow_deletions, false);
  assert.equal(target.required_conversation_resolution, true);
  assert.equal(target.required_pull_request_reviews.required_approving_review_count, 0);
  assert.equal(target.required_pull_request_reviews.require_code_owner_reviews, false);
  assert.equal(target.required_pull_request_reviews.require_last_push_approval, false);
  assert.equal(target.required_pull_request_reviews.dismiss_stale_reviews, true);
});

test('solo CODEOWNERS routes every existing domain to the actual repository owner', () => {
  const entries = read('.github/CODEOWNERS').split(/\r?\n/)
    .filter((line) => line.trim() && !line.trim().startsWith('#'))
    .map((line) => line.trim().split(/\s+/));
  assert.deepEqual(entries, [
    '*', '/.github/', '/backend/', '/apps/mobile/', '/packages/', '/infra/',
    '/tools/', '/content/', '/docs/', '/docs/migration/',
  ].map((pattern) => [pattern, '@gaby27072001']));
});
