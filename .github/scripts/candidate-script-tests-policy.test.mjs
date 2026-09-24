import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { stringify } from 'yaml';
import {
  candidateJobId,
  candidateJobName,
  validateCandidateScriptTestsJob,
} from './candidate-script-tests-policy.mjs';

// Fixture synthétique : aucune assertion négative ne dépend du contenu courant de
// lint-workflows.yml, qui peut évoluer par une pré-approbation.
function job() {
  return {
    name: candidateJobName,
    needs: 'freshness',
    if: "${{ always() && needs.freshness.outputs.current != 'false' "
      + '&& github.event.pull_request.head.repo.full_name == github.repository }}',
    'runs-on': ['self-hosted', 'Linux', 'X64', 'certigo-pr'],
    'timeout-minutes': 20,
    permissions: { contents: 'read', 'pull-requests': 'read' },
    steps: [
      {
        uses: 'actions/checkout@11d5960a326750d5838078e36cf38b85af677262',
        with: {
          ref: '${{ github.event.pull_request.head.sha }}',
          path: '.untrusted-source',
          'persist-credentials': false,
        },
      },
      { 'working-directory': '.untrusted-source', run: 'npm ci --ignore-scripts' },
      { 'working-directory': '.untrusted-source', run: 'node --test .github/scripts/*.test.mjs' },
    ],
  };
}

function workflowWith(mutate = () => {}) {
  const candidate = job();
  mutate(candidate);
  return stringify({ name: 'lint', on: { pull_request_target: null }, jobs: { [candidateJobId]: candidate } });
}

test('accepts the candidate script tests job', () => {
  assert.deepEqual(validateCandidateScriptTestsJob(workflowWith()), []);
});

test('the lint workflow of this tree keeps the candidate script tests job', () => {
  // Contrôle positif sur le fichier réel : le validateur de la base impose le même invariant avant
  // toute fusion, donc un lint-workflows.yml fusionné le satisfait toujours.
  const text = fs.readFileSync(path.resolve('.github', 'workflows', 'lint-workflows.yml'), 'utf8');
  assert.deepEqual(validateCandidateScriptTestsJob(text), []);
});

test('refuses every way of removing or neutralising the candidate tests', () => {
  const cases = [
    [(candidate) => { candidate.name = 'Renamed'; }, /must be named/],
    [(candidate) => { candidate.if = '${{ false }}'; }, /standard same-repository condition/],
    [(candidate) => { candidate.needs = ['freshness', 'other']; }, /standard same-repository condition/],
    [(candidate) => { candidate['runs-on'] = ['self-hosted', 'Linux', 'X64', 'certigo-trusted']; }, /untrusted certigo-pr pool/],
    [(candidate) => { candidate.permissions = { contents: 'write', 'pull-requests': 'read' }; }, /read-only/],
    [(candidate) => { candidate['continue-on-error'] = true; }, /must not tolerate failures/],
    [(candidate) => { candidate.strategy = { matrix: { shard: [1, 2] } }; }, /must not tolerate failures or fan out/],
    [(candidate) => { candidate.steps[2]['continue-on-error'] = true; }, /unconditionally/],
    [(candidate) => { candidate.steps[2].if = '${{ false }}'; }, /unconditionally/],
    [(candidate) => { candidate.steps[2].run = 'node --test .github/scripts/ci-impact.test.mjs'; }, /unconditionally/],
    [(candidate) => { candidate.steps[2]['working-directory'] = '.trusted-control'; }, /never touch trusted controls/],
    [(candidate) => { candidate.steps.splice(1, 1); }, /unconditionally/],
    [(candidate) => { candidate.steps.reverse(); }, /unconditionally/],
    [(candidate) => { candidate.steps[0].with.ref = '${{ github.event.pull_request.base.sha }}'; }, /pull request head/],
    [(candidate) => { candidate.steps[0].with['persist-credentials'] = true; }, /without credentials/],
    [(candidate) => { candidate.env = { TOKEN: '${{ secrets.ANY }}' }; }, /never touch trusted controls or secrets/],
  ];
  for (const [mutate, expected] of cases) {
    const errors = validateCandidateScriptTestsJob(workflowWith(mutate));
    assert.ok(errors.some((error) => expected.test(error)), `${expected}: ${errors.join(' | ')}`);
  }
  assert.match(
    validateCandidateScriptTestsJob(stringify({ jobs: { validate: job() } }))[0],
    /job candidate-script-tests is missing/,
  );
});

test('refuses to vouch for a workflow it cannot parse', () => {
  assert.match(
    validateCandidateScriptTestsJob('jobs:\n  a: 1\n  a: 2\n')[0],
    /cannot be checked on invalid YAML/,
  );
});
