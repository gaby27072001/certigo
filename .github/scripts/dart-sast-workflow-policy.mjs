import { parseDocument } from 'yaml';

// Invariants de dart-sast.yml (finding D10, docs/runbooks/DART_SAST.md) :
// - le verdict vient de la copie de BASE de dart-sast.mjs, qui lit ses contrôles à côté d'elle ;
//   l'arbre de la PR n'y entre que comme données (`--root`) ;
// - Semgrep s'installe depuis le verrou de BASE, empreintes exigées, sans compilation ;
// - le job agrégé, futur contexte requis, ne touche jamais la source PR et tourne sur le pool
//   de confiance, comme les autres gates agrégés (docs/runbooks/CI_RUNNERS.md §10).
// S'applique aussi à la proposition d'une pré-approbation (même nom de fichier).
export const dartSastWorkflowFile = 'dart-sast.yml';
export const dartSastGateJobId = 'gate';
export const dartSastGateName = 'Dart SAST / Security gate';

const prRunner = ['self-hosted', 'Linux', 'X64', 'certigo-pr'];
const trustedRunner = ['self-hosted', 'Linux', 'X64', 'certigo-trusted'];
const readOnly = { contents: 'read', 'pull-requests': 'read' };
const headRef = "${{ github.event_name == 'pull_request_target' "
  + '&& github.event.pull_request.head.sha || github.sha }}';
const baseRef = "${{ github.event_name == 'pull_request_target' "
  + '&& github.event.pull_request.base.sha || github.sha }}';
const trustedLock = '-r "$TRUSTED_CONTROL_DIR/.github/sast/semgrep-requirements.lock"';
const pipFlags = ['--isolated', '--no-cache-dir', '--require-hashes', '--only-binary=:all:', '--no-deps'];
const scanCommand = 'node "$TRUSTED_CONTROL_DIR/.github/scripts/dart-sast.mjs" check';
const sourceAsData = '--root "$UNTRUSTED_SOURCE_DIR"';
const controlOverrides = /(?:^|\s)--(?:rules|scope|baseline|lock|fixtures)(?:[\s=]|$)/u;
const untrustedReference = /UNTRUSTED_SOURCE_DIR|\.untrusted-source/u;

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
    return { error: `${label}: the Dart SAST workflow cannot be checked on invalid YAML` };
  }
  try {
    return { workflow: document.toJS({ maxAliasCount: 0 }) };
  } catch {
    return { error: `${label}: the Dart SAST workflow cannot be checked on unsafe YAML` };
  }
}

function stepsOf(job) {
  return Array.isArray(job?.steps) ? job.steps.filter(isPlainObject) : [];
}

function checkoutInto(steps, directory) {
  return steps.findIndex((step) => (
    typeof step.uses === 'string'
    && step.uses.startsWith('actions/checkout@')
    && step.with?.path === directory
  ));
}

function validateScan(job, problem) {
  const errors = [];
  if (!isPlainObject(job)) {
    return [problem('scan', 'is missing')];
  }
  if (!sameJson(job['runs-on'], prRunner)) {
    errors.push(problem('scan', 'must run on the untrusted certigo-pr pool'));
  }
  if (!sameJson(job.permissions, readOnly)) {
    errors.push(problem('scan', 'must keep exactly read-only contents and pull-requests permissions'));
  }
  if (Object.hasOwn(job, 'strategy') || Object.hasOwn(job, 'continue-on-error')) {
    errors.push(problem('scan', 'must not fan out or tolerate failures'));
  }
  const steps = stepsOf(job);
  const source = checkoutInto(steps, '.untrusted-source');
  const trusted = checkoutInto(steps, '.trusted-control');
  if (
    source < 0
    || steps[source].with?.ref !== headRef
    || steps[source].with?.['persist-credentials'] !== false
  ) {
    errors.push(problem('scan', 'must check out the pull request head into .untrusted-source without credentials'));
  }
  if (
    trusted < 0
    || steps[trusted].with?.ref !== baseRef
    || steps[trusted].with?.['persist-credentials'] !== false
  ) {
    errors.push(problem('scan', 'must check out the base SHA into .trusted-control without credentials'));
  }
  const runs = steps.map((step) => (typeof step.run === 'string' ? step.run : ''));
  const install = runs.findIndex((run) => run.includes(trustedLock));
  if (install < 0 || pipFlags.some((flag) => !runs[install].includes(flag))) {
    errors.push(problem(
      'scan',
      `must install Semgrep from the trusted lock with ${pipFlags.join(' ')}`,
    ));
  }
  const scans = runs
    .map((run, index) => ({ run: run.trim(), index }))
    .filter(({ run }) => run.includes('dart-sast.mjs'));
  const scan = scans[0];
  if (
    scans.length !== 1
    || !scan.run.startsWith(scanCommand)
    || !scan.run.includes(sourceAsData)
    || !scan.run.includes('--summary "$GITHUB_STEP_SUMMARY"')
    || !/(?:^|\s)--github(?:\s|$)/u.test(scan.run)
    || controlOverrides.test(scan.run)
    || Object.hasOwn(steps[scan.index], 'if')
    || Object.hasOwn(steps[scan.index], 'continue-on-error')
  ) {
    errors.push(problem(
      'scan',
      `must run exactly one unconditional \`${scanCommand}\` with ${sourceAsData}, `
        + '--summary "$GITHUB_STEP_SUMMARY" and --github, without overriding its controls',
    ));
  } else if (
    install < 0
    || Math.max(source, trusted, install) > scan.index
  ) {
    errors.push(problem('scan', 'must check out both trees and install Semgrep before scanning'));
  }
  if (runs.some((run) => untrustedReference.test(run.replace(sourceAsData, '')))) {
    errors.push(problem('scan', 'must read the pull request tree only as scan data (--root)'));
  }
  return errors;
}

function validateGate(workflow, problem) {
  const jobs = workflow.jobs;
  const gate = jobs[dartSastGateJobId];
  if (!isPlainObject(gate)) {
    return [problem(dartSastGateJobId, 'is missing')];
  }
  const errors = [];
  if (gate.name !== dartSastGateName) {
    errors.push(problem(dartSastGateJobId, `must be named "${dartSastGateName}"`));
  }
  const namesakes = Object.entries(jobs)
    .filter(([id, job]) => id !== dartSastGateJobId && isPlainObject(job) && job.name === dartSastGateName);
  if (namesakes.length > 0) {
    errors.push(problem(dartSastGateJobId, `must be the only job named "${dartSastGateName}"`));
  }
  if (!sameJson(gate['runs-on'], trustedRunner)) {
    errors.push(problem(dartSastGateJobId, 'must run on the certigo-trusted pool, like every aggregate gate'));
  }
  if (!sameJson(gate.permissions, {})) {
    errors.push(problem(dartSastGateJobId, 'must not receive any token permission'));
  }
  const needs = Array.isArray(gate.needs) ? gate.needs : [gate.needs];
  const expectedNeeds = ['scan', ...(isPlainObject(jobs.candidate) ? ['candidate'] : [])];
  if (
    expectedNeeds.some((job) => !needs.includes(job))
    || typeof gate.if !== 'string'
    || !gate.if.startsWith('${{ always()')
    || Object.hasOwn(gate, 'continue-on-error')
    || Object.hasOwn(gate, 'strategy')
  ) {
    errors.push(problem(
      dartSastGateJobId,
      `must need ${expectedNeeds.join(' and ')}, run under always() and not tolerate failures`,
    ));
  }
  const serialized = JSON.stringify(gate);
  if (/actions\/checkout@|untrusted|\.head\.sha|secrets/iu.test(serialized)) {
    errors.push(problem(dartSastGateJobId, 'must never check out or read pull request source or secrets'));
  }
  const enforcing = stepsOf(gate).filter((step) => (
    isPlainObject(step.env)
    && step.env.SCAN_RESULT === '${{ needs.scan.result }}'
    && typeof step.run === 'string'
    && step.run.includes('if [ "$SCAN_RESULT" != "success" ]; then')
    && (!isPlainObject(jobs.candidate)
      || (step.env.CANDIDATE_RESULT === '${{ needs.candidate.result }}'
        && step.run.includes('"$CANDIDATE_RESULT"')))
    && !Object.hasOwn(step, 'if')
    && !Object.hasOwn(step, 'continue-on-error')
  ));
  if (enforcing.length !== 1) {
    errors.push(problem(
      dartSastGateJobId,
      'must keep exactly one unconditional step that fails unless the scan (and candidate) results are expected',
    ));
  }
  return errors;
}

export function validateDartSastWorkflow(text, label = dartSastWorkflowFile) {
  const parsed = parse(text, label);
  if (parsed.error) {
    return [parsed.error];
  }
  const { workflow } = parsed;
  const problem = (job, detail) => `${label}: job ${job} ${detail}; the Dart SAST verdict must come `
    + 'from the base controls (docs/runbooks/DART_SAST.md)';
  if (!isPlainObject(workflow) || !isPlainObject(workflow.jobs)) {
    return [`${label}: the Dart SAST workflow has no jobs`];
  }
  const errors = [];
  const triggers = isPlainObject(workflow.on) ? workflow.on : {};
  if (!Object.hasOwn(triggers, 'pull_request_target') || !Object.hasOwn(triggers, 'push')) {
    errors.push(`${label}: the Dart SAST workflow must run for pull_request_target and push`);
  }
  if (Object.values(triggers).some((trigger) => (
    isPlainObject(trigger) && (Object.hasOwn(trigger, 'paths') || Object.hasOwn(trigger, 'paths-ignore'))
  ))) {
    errors.push(`${label}: the Dart SAST workflow must not be path-scoped (it must always report)`);
  }
  if (!sameJson(workflow.permissions, {})) {
    errors.push(`${label}: the Dart SAST workflow must declare empty top-level permissions`);
  }
  if (/continue-on-error:\s*true|actions\/upload-artifact@|upload-sarif@/u.test(text)) {
    errors.push(`${label}: the Dart SAST workflow must fail on findings and never publish artifacts or SARIF`);
  }
  errors.push(...validateScan(workflow.jobs.scan, problem));
  errors.push(...validateGate(workflow, problem));
  return errors;
}
