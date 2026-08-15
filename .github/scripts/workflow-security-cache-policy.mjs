import { parseDocument } from 'yaml';

export function validateTrustedCachePolicy(text, file) {
  if (!text.includes('certigo-trusted')) {
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
    for (const step of job?.steps ?? []) {
      const action = typeof step?.uses === 'string' ? step.uses : '';
      const normalizedAction = action.toLowerCase();
      if (
        /^actions\/cache(?:\/|@)/.test(normalizedAction)
        || normalizedAction.startsWith('subosito/flutter-action@')
      ) {
        errors.push(
          `${file}: certigo-trusted workflow uses forbidden cache surface ${action}`,
        );
      }
      for (const [inputName, inputValue] of Object.entries(step?.with ?? {})) {
        const cacheInput = inputName.toLowerCase();
        if (
          ['cache', 'pub-cache'].includes(cacheInput)
          && inputValue !== false
        ) {
          errors.push(
            `${file}: certigo-trusted ${cacheInput} must be the literal false value`,
          );
        }
      }
    }
  }
  return errors;
}
