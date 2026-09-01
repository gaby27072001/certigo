import assert from 'node:assert/strict';
import test from 'node:test';
import {
  pullRequestCancellationExpression,
  pullRequestGroupExpression,
  resolveWorkflowConcurrency,
  shouldSchedulePullRequestWork,
  validateWorkflowConcurrency,
} from './workflow-concurrency-policy.mjs';

function workflow(event = 'pull_request_target', key = 'ci-backend') {
  return `name: test
on:
  ${event}:

concurrency:
  group: ${key}-${pullRequestGroupExpression}
  cancel-in-progress: ${pullRequestCancellationExpression}

permissions: {}

jobs:
  freshness:
    uses: ./.github/workflows/pr-head-freshness.yml
  validate:
    needs: freshness
    if: \${{ needs.freshness.outputs.current != 'false' }}
    steps:
      - name: Enforce initial PR freshness validation
        env:
          FRESHNESS_RESULT: \${{ needs.freshness.result }}
      - name: Recheck current PR head after assignment
`;
}

test('a new head SHA supersedes only the previous run for the same PR', () => {
  const opened = resolveWorkflowConcurrency('ci-backend', {
    name: 'pull_request_target',
    action: 'opened',
    pullRequestNumber: 41,
    headSha: 'a'.repeat(40),
    runId: 1001,
  });
  const synchronized = resolveWorkflowConcurrency('ci-backend', {
    name: 'pull_request_target',
    action: 'synchronize',
    pullRequestNumber: 41,
    headSha: 'b'.repeat(40),
    runId: 1002,
  });

  assert.equal(opened.group, synchronized.group);
  assert.equal(opened.cancelInProgress, false);
  assert.equal(synchronized.cancelInProgress, true);
});

test('two pull requests and two workflows cannot cancel each other', () => {
  const event = {
    name: 'pull_request_target',
    action: 'synchronize',
    headSha: 'c'.repeat(40),
    runId: 2001,
  };
  const firstPr = resolveWorkflowConcurrency('ci-backend', {
    ...event,
    pullRequestNumber: 41,
  });
  const secondPr = resolveWorkflowConcurrency('ci-backend', {
    ...event,
    pullRequestNumber: 42,
  });
  const dependabotDynamic = resolveWorkflowConcurrency('dependabot-dynamic', {
    ...event,
    pullRequestNumber: 41,
  });

  assert.notEqual(firstPr.group, secondPr.group);
  assert.notEqual(firstPr.group, dependabotDynamic.group);
});

test('push main, schedules, manual and governance runs never cancel', () => {
  for (const [workflowName, eventName] of [
    ['ci-backend', 'push'],
    ['codeql', 'schedule'],
    ['ci-backend', 'workflow_dispatch'],
    ['governance-bootstrap-phase-a-what-if', 'repository_dispatch'],
    ['publish-verified-public-pages', 'repository_dispatch'],
    ['merge-queue', 'merge_group'],
  ]) {
    const result = resolveWorkflowConcurrency(workflowName, {
      name: eventName,
      action: 'synchronize',
      pullRequestNumber: 41,
      headSha: 'd'.repeat(40),
      runId: 3001,
    });

    assert.equal(result.cancelInProgress, false, `${workflowName}/${eventName}`);
    assert.equal(result.group, `${workflowName}-${eventName}-3001-1`);
  }
});

test('missing PR number or head SHA fails safe', () => {
  const missingNumber = resolveWorkflowConcurrency('ci-backend', {
    name: 'pull_request_target',
    action: 'synchronize',
    headSha: 'e'.repeat(40),
    runId: 4001,
  });
  const missingHead = resolveWorkflowConcurrency('ci-backend', {
    name: 'pull_request_target',
    action: 'synchronize',
    pullRequestNumber: 41,
    runId: 4002,
  });

  assert.equal(missingNumber.group, 'ci-backend-pull_request_target-4001-1');
  assert.equal(missingNumber.cancelInProgress, false);
  assert.equal(missingHead.group, 'ci-backend-pull_request_target-4002-1');
  assert.equal(missingHead.cancelInProgress, false);
});

test('an accepted cancellation is not terminal when the queued run is assigned later', () => {
  const racedRun = {
    cancellationAccepted: true,
    statesAfterAcceptance: ['assigned', 'in_progress', 'completed', 'cancelled'],
    completedJobs: ['changes', 'build-test'],
    eventHeadSha: 'e'.repeat(40),
  };
  const currentHeadSha = 'f'.repeat(40);

  assert.equal(racedRun.cancellationAccepted, true);
  assert.deepEqual(
    racedRun.statesAfterAcceptance,
    ['assigned', 'in_progress', 'completed', 'cancelled'],
  );
  assert.equal(racedRun.completedJobs.length, 2);
  assert.equal(
    shouldSchedulePullRequestWork(racedRun.eventHeadSha, currentHeadSha),
    false,
  );
});

test('rerunning an old synchronize event cannot cancel the current head run', () => {
  const oldRerun = resolveWorkflowConcurrency('ci-backend', {
    name: 'pull_request_target',
    action: 'synchronize',
    runAttempt: 2,
    pullRequestNumber: 41,
    headSha: 'e'.repeat(40),
    runId: 4003,
  });

  assert.equal(oldRerun.group, 'ci-backend-pull_request_target-4003-2');
  assert.equal(oldRerun.cancelInProgress, false);
});

test('an obsolete rerun cannot evict the current-head pending run', () => {
  const currentHead = resolveWorkflowConcurrency('ci-backend', {
    name: 'pull_request_target',
    action: 'synchronize',
    runAttempt: 1,
    pullRequestNumber: 41,
    headSha: 'f'.repeat(40),
    runId: 4004,
  });
  const obsoleteRerun = resolveWorkflowConcurrency('ci-backend', {
    name: 'pull_request_target',
    action: 'synchronize',
    runAttempt: 2,
    pullRequestNumber: 41,
    headSha: 'e'.repeat(40),
    runId: 4003,
  });

  assert.notEqual(obsoleteRerun.group, currentHead.group);
  assert.equal(obsoleteRerun.cancelInProgress, false);
});

test('the orchestration guard schedules work only for the current event head', () => {
  const headSha = 'a'.repeat(40);

  assert.equal(shouldSchedulePullRequestWork(headSha, headSha), true);
  assert.equal(shouldSchedulePullRequestWork('', headSha), false);
  assert.equal(shouldSchedulePullRequestWork(headSha, ''), false);
});

test('static policy accepts the canonical non-injectable PR expressions', () => {
  assert.deepEqual(
    validateWorkflowConcurrency(workflow(), '.github/workflows/ci-backend.yml'),
    [],
  );
});

test('static policy rejects cross-PR, injectable and operational cancellation', () => {
  const unsafePr = workflow()
    .replace(`ci-backend-${pullRequestGroupExpression}`, 'ci-backend-${{ github.head_ref }}')
    .replace(pullRequestCancellationExpression, 'true');
  const unsafeGovernance = `name: governance
on:
  repository_dispatch:
concurrency:
  group: governance
  cancel-in-progress: true
permissions: {}
`;

  assert.equal(
    validateWorkflowConcurrency(
      unsafePr,
      '.github/workflows/ci-backend.yml',
    ).length,
    3,
  );
  assert.deepEqual(
    validateWorkflowConcurrency(
      unsafeGovernance,
      '.github/workflows/governance.yml',
    ),
    [
      '.github/workflows/governance.yml: non-PR workflows must never cancel in-progress runs',
    ],
  );
});
