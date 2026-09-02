import YAML from 'yaml';

const expectedCloudJobs = new Map([
  ['build-release', 'dev'],
  ['resolve-release', 'dev'],
  ['deploy-infra', '${{ needs.validate-target.outputs.target }}'],
  ['deploy-backend', '${{ needs.validate-target.outputs.target }}'],
]);
const expectedCloudNeeds = new Map([
  [
    'build-release',
    ['validate-target', 'validate-release-source', 'validate-public-domain'],
  ],
  [
    'resolve-release',
    ['validate-target', 'validate-public-domain', 'validate-release-source', 'build-release'],
  ],
  ['deploy-infra', ['validate-target', 'resolve-release']],
  ['deploy-backend', ['validate-target', 'resolve-release', 'deploy-infra']],
]);
const cloudMarkers = [
  'azure/login@',
  'az ',
  'management.azure.com',
  '.azurewebsites.net',
  'transfer-backend-release.sh',
  'deploy-flex-onedeploy.sh',
];

function needsList(job) {
  if (!job?.needs) {
    return [];
  }
  return Array.isArray(job.needs) ? job.needs : [job.needs];
}

function normalized(value) {
  return String(value ?? '').replace(/\s+/g, ' ').trim();
}

function sameMembers(actual, expected) {
  return JSON.stringify([...actual].sort()) === JSON.stringify([...expected].sort());
}

function hasCloudCapability(job) {
  const serialized = JSON.stringify(job);
  return job?.permissions?.['id-token'] === 'write'
    || cloudMarkers.some((marker) => serialized.includes(marker));
}

function ancestorJobs(jobs, jobId, errors, visiting = new Set()) {
  if (visiting.has(jobId)) {
    errors.push(`cd-backend.yml: job dependency cycle reaches ${jobId}`);
    return new Set();
  }
  visiting.add(jobId);
  const ancestors = new Set();
  for (const dependency of needsList(jobs[jobId])) {
    if (!jobs[dependency]) {
      errors.push(`cd-backend.yml: job ${jobId} needs missing job ${dependency}`);
      continue;
    }
    ancestors.add(dependency);
    for (const ancestor of ancestorJobs(jobs, dependency, errors, new Set(visiting))) {
      ancestors.add(ancestor);
    }
  }
  return ancestors;
}

export function validateBackendDeployWorkflow(text) {
  const errors = [];
  let workflow;
  try {
    workflow = YAML.parse(text);
  } catch (error) {
    return [`cd-backend.yml: cannot parse workflow policy input: ${error.message}`];
  }

  const triggers = workflow?.on;
  if (
    !triggers
    || typeof triggers !== 'object'
    || Array.isArray(triggers)
    || JSON.stringify(Object.keys(triggers).sort()) !== JSON.stringify(['repository_dispatch'])
  ) {
    errors.push('cd-backend.yml: deployment workflow must only use repository_dispatch');
  }
  const dispatchTypes = triggers?.repository_dispatch?.types;
  if (
    !Array.isArray(dispatchTypes)
    || dispatchTypes.length !== 1
    || dispatchTypes[0] !== 'promote-backend'
  ) {
    errors.push('cd-backend.yml: repository_dispatch type must be exactly promote-backend');
  }
  if (
    !workflow?.permissions
    || typeof workflow.permissions !== 'object'
    || Array.isArray(workflow.permissions)
    || Object.keys(workflow.permissions).length !== 0
  ) {
    errors.push('cd-backend.yml: top-level permissions must remain empty');
  }

  const jobs = workflow?.jobs ?? {};
  const validateTarget = jobs['validate-target'];
  if (!validateTarget) {
    errors.push('cd-backend.yml: validate-target job is required');
    return errors;
  }
  const targetCondition = normalized(validateTarget.if);
  if (targetCondition !== "${{ github.ref == 'refs/heads/main' }}") {
    errors.push('cd-backend.yml: validate-target condition must be exactly refs/heads/main');
  }
  if (validateTarget.environment) {
    errors.push('cd-backend.yml: validate-target must not receive an Environment');
  }
  if (validateTarget.permissions?.['id-token'] === 'write') {
    errors.push('cd-backend.yml: validate-target must not request an OIDC token');
  }
  const targetText = JSON.stringify(validateTarget);
  if (targetText.includes('secrets.')) {
    errors.push('cd-backend.yml: validate-target must not receive secrets');
  }
  for (const marker of [
    'validate-backend-deploy-dispatch.mjs',
    'EVENT_NAME',
    'EVENT_ACTION',
    'CLIENT_PAYLOAD_JSON',
  ]) {
    if (!targetText.includes(marker)) {
      errors.push(`cd-backend.yml: validate-target is missing ${marker}`);
    }
  }

  const validateReleaseSource = jobs['validate-release-source'];
  if (!validateReleaseSource) {
    errors.push('cd-backend.yml: validate-release-source job is required');
  } else {
    if (!sameMembers(needsList(validateReleaseSource), ['validate-target'])) {
      errors.push('cd-backend.yml: validate-release-source must need only validate-target');
    }
    if (
      normalized(validateReleaseSource.if)
        !== "${{ needs.validate-target.outputs.operation == 'release' }}"
    ) {
      errors.push('cd-backend.yml: validate-release-source condition must be exactly release-only');
    }
    if (
      validateReleaseSource.environment
      || hasCloudCapability(validateReleaseSource)
      || JSON.stringify(validateReleaseSource).includes('secrets.')
    ) {
      errors.push(
        'cd-backend.yml: validate-release-source must be local, secret-free and without Azure identity',
      );
    }
  }

  const publicDomain = jobs['validate-public-domain'];
  if (
    !publicDomain
    || normalized(publicDomain.environment)
      !== '${{ needs.validate-target.outputs.target }}'
    || !sameMembers(needsList(publicDomain), ['validate-target'])
  ) {
    errors.push(
      'cd-backend.yml: validate-public-domain must gate the validated target Environment',
    );
  }
  if (
    publicDomain
    && (
      hasCloudCapability(publicDomain)
      || JSON.stringify(publicDomain).includes('secrets.')
    )
  ) {
    errors.push(
      'cd-backend.yml: validate-public-domain must run without secrets or Azure identity',
    );
  }

  const cloudJobs = Object.entries(jobs)
    .filter(([, job]) => hasCloudCapability(job))
    .map(([jobId]) => jobId);
  if (
    cloudJobs.length !== expectedCloudJobs.size
    || cloudJobs.some((jobId) => !expectedCloudJobs.has(jobId))
  ) {
    errors.push(
      `cd-backend.yml: Azure-capable jobs must be exactly ${[...expectedCloudJobs.keys()].join(', ')}`,
    );
  }

  for (const jobId of cloudJobs) {
    const job = jobs[jobId];
    const expectedEnvironment = expectedCloudJobs.get(jobId);
    if (!job.environment) {
      errors.push(`cd-backend.yml: Azure-capable job ${jobId} must use an Environment`);
    } else if (expectedEnvironment && normalized(job.environment) !== expectedEnvironment) {
      errors.push(
        `cd-backend.yml: Azure-capable job ${jobId} must use Environment ${expectedEnvironment}`,
      );
    }
    const expectedNeeds = expectedCloudNeeds.get(jobId);
    if (expectedNeeds && !sameMembers(needsList(job), expectedNeeds)) {
      errors.push(
        `cd-backend.yml: Azure-capable job ${jobId} must keep its exact fail-closed needs`,
      );
    }
    const ancestors = ancestorJobs(jobs, jobId, errors);
    for (const requiredGate of ['validate-target', 'validate-public-domain']) {
      if (!ancestors.has(requiredGate)) {
        errors.push(
          `cd-backend.yml: Azure-capable job ${jobId} must transitively need ${requiredGate}`,
        );
      }
    }
  }

  const buildRelease = jobs['build-release'];
  if (
    buildRelease
    && normalized(buildRelease.if)
      !== "${{ needs.validate-target.outputs.operation == 'release' && needs.validate-release-source.result == 'success' }}"
  ) {
    errors.push(
      'cd-backend.yml: build-release condition must exactly require release and source success',
    );
  }

  const resolveRelease = jobs['resolve-release'];
  const resolveCondition = normalized(resolveRelease?.if);
  const expectedResolveCondition = normalized(`
    \${{
      always()
      && needs.validate-target.result == 'success'
      && needs.validate-public-domain.result == 'success'
      && (
        (
          needs.validate-target.outputs.operation == 'release'
          && needs.validate-release-source.result == 'success'
          && needs.build-release.result == 'success'
        )
        || (
          needs.validate-target.outputs.operation != 'release'
          && needs.validate-release-source.result == 'skipped'
          && needs.build-release.result == 'skipped'
        )
      )
    }}
  `);
  if (resolveCondition !== expectedResolveCondition) {
    errors.push('cd-backend.yml: resolve-release condition must exactly match the fail-closed truth table');
  }

  for (const jobId of ['deploy-infra', 'deploy-backend']) {
    if (jobs[jobId]?.if !== undefined) {
      errors.push(`cd-backend.yml: ${jobId} must rely on the default success gate`);
    }
  }

  return errors;
}
