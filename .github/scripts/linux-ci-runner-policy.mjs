import path from 'node:path';

export const hostedLinuxRunner = 'ubuntu-24.04';
export const linuxCiJobs = Object.freeze({
  'ci-backend.yml': Object.freeze(['changes', 'build-test']),
  'ci-content.yml': Object.freeze(['validate']),
  'ci-cortex-parity.yml': Object.freeze(['changes', 'parity']),
  'ci-migration-registry.yml': Object.freeze(['validate']),
  'ci-mobile.yml': Object.freeze(['changes', 'packages', 'app', 'prism-goldens']),
  'ci-preflight.yml': Object.freeze(['preflight']),
  'ci-project-state.yml': Object.freeze(['validate-source', 'validate']),
  'lint-workflows.yml': Object.freeze(['candidate-script-tests', 'validate']),
  'fork-pr-policy.yml': Object.freeze(['trust-gate']),
  'pr-head-freshness.yml': Object.freeze(['freshness']),
  'dependency-vuln-scan.yml': Object.freeze(['osv-scan', 'locked-restore']),
  'security-scan.yml': Object.freeze(['iac-scan']),
});

export function isHostedLinuxCiRunner(file, jobId, runner) {
  return runner === hostedLinuxRunner
    && linuxCiJobs[path.basename(file)]?.includes(jobId) === true;
}

export function isPrLinuxCiRunner(file, jobId, runner) {
  return isHostedLinuxCiRunner(file, jobId, runner)
    || JSON.stringify(runner) === JSON.stringify(['self-hosted', 'Linux', 'X64', 'certigo-pr']);
}

// Apply to decoded YAML, including quoted keys and inherited workflow permissions.
export function validateHostedLinuxJob(workflow, job, jobId, file) {
  if (job?.['runs-on'] !== hostedLinuxRunner) {
    return [];
  }
  const errors = [];
  if (!isHostedLinuxCiRunner(file, jobId, job['runs-on'])) {
    errors.push(`${file}: job ${jobId} is outside the fixed hosted Linux CI scope`);
  }
  for (const permissions of [workflow.permissions, job.permissions]) {
    if (permissions !== undefined && (
      permissions === null
      || typeof permissions !== 'object'
      || Array.isArray(permissions)
      || Object.entries(permissions).some(([name, value]) => (
        !['read', 'none'].includes(value) || name.toLowerCase() === 'id-token'
      ))
    )) {
      errors.push(`${file}: hosted Linux job ${jobId} must keep read-only permissions without OIDC`);
    }
  }
  if (
    Object.hasOwn(job, 'environment')
    || Object.hasOwn(job, 'secrets')
    || /secrets\s*[.[]|azure\/login@|key\s*vault|keyvault|core\.getidtoken|az login|connect-azaccount/iu
      .test(JSON.stringify([workflow.env, job]))
  ) {
    errors.push(`${file}: hosted Linux job ${jobId} must not receive secrets, environments, or cloud identity`);
  }
  if (
    path.basename(file) === 'ci-project-state.yml'
    && jobId === 'validate'
    && /github\.event\.pull_request\.head\.(?:sha|ref)|\.untrusted-source|\.untrusted-restore/iu
      .test(JSON.stringify(job))
  ) {
    errors.push(`${file}: aggregate job ${jobId} must not checkout or parse PR source`);
  }
  return errors;
}
