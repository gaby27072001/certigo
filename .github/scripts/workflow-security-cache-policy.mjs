import { parseDocument } from 'yaml';

const persistentRunnerLabels = new Set(['certigo-pr', 'certigo-trusted']);

function persistentRunner(job) {
  const labels = Array.isArray(job?.['runs-on']) ? job['runs-on'] : [job?.['runs-on']];
  return labels.find((label) => persistentRunnerLabels.has(label));
}

export function validatePersistentCachePolicy(text, file) {
  if (![...persistentRunnerLabels].some((label) => text.includes(label))) {
    return [];
  }

  let workflow;
  try {
    const document = parseDocument(text, { uniqueKeys: true });
    if (document.errors.length > 0) {
      throw document.errors[0];
    }
    workflow = document.toJS();
  } catch (error) {
    return [`${file}: invalid workflow YAML: ${error.message}`];
  }

  const errors = [];
  for (const job of Object.values(workflow?.jobs ?? {})) {
    const runnerLabel = persistentRunner(job);
    if (!runnerLabel) {
      continue;
    }
    for (const step of job?.steps ?? []) {
      const action = typeof step?.uses === 'string' ? step.uses : '';
      const normalizedAction = action.toLowerCase();
      if (/^actions\/cache(?:\/|@)/.test(normalizedAction)) {
        errors.push(
          `${file}: ${runnerLabel} job uses forbidden cache surface ${action}`,
        );
      }
      const inputs = step?.with ?? {};
      if (
        normalizedAction.startsWith('subosito/flutter-action@')
        && !Object.hasOwn(inputs, 'cache')
      ) {
        errors.push(
          `${file}: ${runnerLabel} Flutter action must set cache to the literal false value`,
        );
      }
      for (const [inputName, inputValue] of Object.entries(inputs)) {
        const cacheInput = inputName.toLowerCase();
        if (
          ['cache', 'pub-cache'].includes(cacheInput)
          && inputValue !== false
        ) {
          errors.push(
            `${file}: ${runnerLabel} ${cacheInput} must be the literal false value`,
          );
        }
      }
    }
  }
  return errors;
}
