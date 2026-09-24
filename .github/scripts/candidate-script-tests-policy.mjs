import { parseDocument } from 'yaml';

// Invariant de lint-workflows.yml : le job qui exécute les tests .github/scripts DE LA PR sur son
// propre arbre doit rester en place et mordre. Sans lui, un test cassé apporté par une PR ne
// s'exécute qu'après la fusion, sur l'arbre de `main`, et bloque alors toutes les PR (#497).
export const candidateJobId = 'candidate-script-tests';
export const candidateJobName = 'Candidate workflow security script tests';
const expectedRunner = ['self-hosted', 'Linux', 'X64', 'certigo-pr'];
const expectedCondition = "${{ always() && needs.freshness.outputs.current != 'false' "
  + '&& github.event.pull_request.head.repo.full_name == github.repository }}';

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function sameJson(left, right) {
  return JSON.stringify(left) === JSON.stringify(right);
}

function parse(text, label) {
  const document = parseDocument(text, {
    merge: false,
    strict: true,
    stringKeys: true,
    uniqueKeys: true,
  });
  if (document.errors.length > 0) {
    return { error: `${label}: the candidate script tests job cannot be checked on invalid YAML` };
  }
  try {
    return { workflow: document.toJS({ maxAliasCount: 0 }) };
  } catch {
    return { error: `${label}: the candidate script tests job cannot be checked on unsafe YAML` };
  }
}

function stepRuns(step, run) {
  return isPlainObject(step)
    && step.run === run
    && step['working-directory'] === '.untrusted-source'
    && !Object.hasOwn(step, 'if')
    && !Object.hasOwn(step, 'continue-on-error');
}

export function validateCandidateScriptTestsJob(text, label = 'lint-workflows.yml') {
  const parsed = parse(text, label);
  if (parsed.error) {
    return [parsed.error];
  }
  const job = parsed.workflow?.jobs?.[candidateJobId];
  const problem = (detail) => `${label}: job ${candidateJobId} ${detail}; the tests of each pull `
    + 'request must keep running on its own tree before the merge (#497)';
  if (!isPlainObject(job)) {
    return [problem('is missing')];
  }
  const errors = [];
  if (job.name !== candidateJobName) {
    errors.push(problem(`must be named "${candidateJobName}"`));
  }
  if (job.needs !== 'freshness' || job.if !== expectedCondition) {
    errors.push(problem('must depend on freshness with the standard same-repository condition'));
  }
  if (!sameJson(job['runs-on'], expectedRunner)) {
    errors.push(problem('must run on the untrusted certigo-pr pool'));
  }
  if (!sameJson(job.permissions, { contents: 'read', 'pull-requests': 'read' })) {
    errors.push(problem('must keep exactly read-only contents and pull-requests permissions'));
  }
  if (Object.hasOwn(job, 'continue-on-error') || Object.hasOwn(job, 'strategy')) {
    errors.push(problem('must not tolerate failures or fan out'));
  }
  const steps = Array.isArray(job.steps) ? job.steps : [];
  const serialized = JSON.stringify(job);
  if (/trusted-control|TRUSTED_CONTROL_DIR|secrets/iu.test(serialized)) {
    errors.push(problem('must never touch trusted controls or secrets'));
  }
  const checkout = steps.find((step) => (
    isPlainObject(step)
    && typeof step.uses === 'string'
    && step.uses.startsWith('actions/checkout@')
  ));
  if (
    !checkout
    || checkout.with?.ref !== '${{ github.event.pull_request.head.sha }}'
    || checkout.with?.path !== '.untrusted-source'
    || checkout.with?.['persist-credentials'] !== false
  ) {
    errors.push(problem('must check out the pull request head into .untrusted-source without credentials'));
  }
  const install = steps.findIndex((step) => stepRuns(step, 'npm ci --ignore-scripts'));
  const tests = steps.findIndex((step) => stepRuns(step, 'node --test .github/scripts/*.test.mjs'));
  if (install < 0 || tests < 0 || install > tests) {
    errors.push(problem(
      'must run `npm ci --ignore-scripts` then `node --test .github/scripts/*.test.mjs` in '
      + '.untrusted-source, unconditionally',
    ));
  }
  return errors;
}
