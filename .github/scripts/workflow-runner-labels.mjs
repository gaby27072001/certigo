import { parseDocument } from 'yaml';
import { isReviewedGenerationJob } from './backend-deploy-workflow-policy.mjs';

// Ensembles de labels autorisés, sur le YAML analysé. La règle textuelle de
// validate-workflow-security.mjs ne lit que les lignes qui commencent par `runs-on:` : une clé
// entre guillemets (`"runs-on": [self-hosted, Linux, X64]`) lui échappait, et un tel job pouvait
// atterrir sur n'importe quel runner auto-hébergé, y compris un runner de confiance.
export const allowedRunnerLabelSets = Object.freeze([
  Object.freeze(['self-hosted', 'Linux', 'X64', 'certigo-pr']),
  Object.freeze(['self-hosted', 'Linux', 'X64', 'certigo-trusted']),
  Object.freeze(['self-hosted', 'Linux', 'X64', 'certigo-cosmos-emulator']),
  Object.freeze(['self-hosted', 'macOS', 'certigo-trusted']),
]);

function isAllowedLabelSet(labels) {
  return Array.isArray(labels) && allowedRunnerLabelSets.some((allowed) => (
    labels.length === allowed.length && allowed.every((entry, index) => labels[index] === entry)
  ));
}

export function validateRunnerLabels(text, label, { trustedRoot } = {}) {
  const document = parseDocument(text, {
    merge: false,
    strict: true,
    stringKeys: true,
    uniqueKeys: true,
  });
  if (document.errors.length > 0) {
    return [`${label}: runner labels cannot be checked on invalid YAML`];
  }
  let workflow;
  try {
    workflow = document.toJS({ maxAliasCount: 0 });
  } catch {
    return [`${label}: runner labels cannot be checked on unsafe YAML`];
  }
  const jobs = workflow?.jobs;
  if (jobs === null || typeof jobs !== 'object' || Array.isArray(jobs)) {
    return [];
  }
  const errors = [];
  for (const [jobId, job] of Object.entries(jobs)) {
    if (
      job === null
      || typeof job !== 'object'
      || Array.isArray(job)
      || !Object.hasOwn(job, 'runs-on')
    ) {
      continue;
    }
    if (isReviewedGenerationJob(text, label, jobId, trustedRoot)) {
      continue;
    }
    if (!isAllowedLabelSet(job['runs-on'])) {
      errors.push(
        `${label}: job ${jobId} must run on a fixed Azure self-hosted label set, `
        + `not ${JSON.stringify(job['runs-on'])}`,
      );
    }
  }
  return errors;
}
