import path from 'node:path';

const pullRequestEvents = new Set(['pull_request', 'pull_request_target']);

export const pullRequestGroupExpression =
  "${{ (github.event_name == 'pull_request' || github.event_name == 'pull_request_target') && (github.event.action == 'opened' || github.event.action == 'synchronize') && github.run_attempt == 1 && github.event.pull_request.number > 0 && github.event.pull_request.head.sha != '' && format('pr-{0}', github.event.pull_request.number) || format('{0}-{1}-{2}', github.event_name, github.run_id, github.run_attempt) }}";

export const pullRequestCancellationExpression =
  "${{ (github.event_name == 'pull_request' || github.event_name == 'pull_request_target') && github.event.action == 'synchronize' && github.run_attempt == 1 && github.event.pull_request.number > 0 && github.event.pull_request.head.sha != '' }}";

function workflowKey(file) {
  return path.basename(file).replace(/\.ya?ml$/u, '');
}

function concurrencyBlock(text) {
  return text.match(/^concurrency:\r?\n(?<body>(?: {2}\S.*(?:\r?\n|$))*)/mu)?.groups?.body ?? '';
}

export function resolveWorkflowConcurrency(workflow, event) {
  const isPullRequest = pullRequestEvents.has(event.name);
  const runAttempt = event.runAttempt ?? 1;
  const joinsSupersessionGroup =
    isPullRequest
    && (event.action === 'opened' || event.action === 'synchronize')
    && runAttempt === 1
    && Number.isInteger(event.pullRequestNumber)
    && event.pullRequestNumber > 0
    && Boolean(event.headSha);
  const suffix = joinsSupersessionGroup
    ? `pr-${event.pullRequestNumber}`
    : `${event.name || 'missing'}-${event.runId || 'missing'}-${runAttempt}`;

  return {
    group: `${workflow}-${suffix}`,
    cancelInProgress:
      isPullRequest
      && event.action === 'synchronize'
      && Number.isInteger(event.pullRequestNumber)
      && event.pullRequestNumber > 0
      && runAttempt === 1
      && Boolean(event.headSha),
  };
}

export function shouldSchedulePullRequestWork(eventHeadSha, currentHeadSha) {
  return Boolean(eventHeadSha) && eventHeadSha === currentHeadSha;
}

export function validateWorkflowConcurrency(text, file) {
  const errors = [];
  const block = concurrencyBlock(text);
  const hasPullRequestTrigger = /^ {2}pull_request(?:_target)?:\s*$/mu.test(text);

  if (hasPullRequestTrigger) {
    const expectedGroup = `group: ${workflowKey(file)}-${pullRequestGroupExpression}`;
    const expectedCancellation =
      `cancel-in-progress: ${pullRequestCancellationExpression}`;

    if (!block.includes(expectedGroup)) {
      errors.push(
        `${file}: pull request concurrency group must isolate the workflow and numeric PR`,
      );
    }
    if (!block.includes(expectedCancellation)) {
      errors.push(
        `${file}: pull request cancellation must require a synchronize event and head SHA`,
      );
    }
    for (const marker of [
      'freshness:',
      'uses: ./.github/workflows/pr-head-freshness.yml',
      'needs: freshness',
      "needs.freshness.outputs.current != 'false'",
      'name: Enforce initial PR freshness validation',
      'needs.freshness.result',
      'name: Recheck current PR head after assignment',
    ]) {
      if (!text.includes(marker)) {
        errors.push(`${file}: superseded PR orchestration guard is missing ${marker}`);
      }
    }
    for (const attackerControlledContext of [
      'github.head_ref',
      'github.event.pull_request.head.ref',
      'github.event.pull_request.head.label',
    ]) {
      if (block.includes(attackerControlledContext)) {
        errors.push(
          `${file}: concurrency must not use attacker-controlled context ${attackerControlledContext}`,
        );
      }
    }
  } else if (block && !/^\s*cancel-in-progress:\s*false\s*$/mu.test(block)) {
    errors.push(`${file}: non-PR workflows must never cancel in-progress runs`);
  }

  return errors;
}
