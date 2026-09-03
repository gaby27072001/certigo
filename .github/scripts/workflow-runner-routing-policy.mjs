import fs from 'node:fs';
import path from 'node:path';
import { parseDocument } from 'yaml';

const prRunner = ['self-hosted', 'Linux', 'X64', 'certigo-pr'];
const trustedLinuxRunner = ['self-hosted', 'Linux', 'X64', 'certigo-trusted'];
const trustedMacRunner = ['self-hosted', 'macOS', 'certigo-trusted'];
const opsProbeRunner = ['self-hosted', 'Linux', 'X64', 'certigo-ops-probe'];

const aggregateJobs = new Map([
  [
    'ci-project-state.yml/validate',
    {
      name: 'Generated state equals committed state',
      needs: 'validate-source',
    },
  ],
  [
    'codeql.yml/security-gate',
    {
      name: 'CodeQL / Security gate',
      needs: ['freshness', 'changes', 'analyze'],
    },
  ],
  [
    'security-gate.yml/security-gate',
    {
      name: 'Security / Required gate',
      needs: ['changes', 'osv', 'checkov'],
    },
  ],
]);

const trustedJobs = new Map([
  ['cd-backend.yml/validate-target', trustedLinuxRunner],
  ['cd-backend.yml/validate-public-domain', trustedLinuxRunner],
  ['cd-backend.yml/build-release', trustedLinuxRunner],
  ['cd-backend.yml/resolve-release', trustedLinuxRunner],
  ['cd-backend.yml/deploy-infra', trustedLinuxRunner],
  ['cd-backend.yml/deploy-backend', trustedLinuxRunner],
  ['content-infra-what-if.yml/what-if', trustedLinuxRunner],
  ['deploy-privacy-policy.yml/build', trustedLinuxRunner],
  ['deploy-privacy-policy.yml/deploy', trustedLinuxRunner],
  ['governance-bootstrap-phase-a-what-if.yml/what-if', trustedLinuxRunner],
  ['governance-bootstrap-phase-b-what-if.yml/what-if', trustedLinuxRunner],
  ['promote-backend-staging-prod.yml/validate-dispatch', trustedLinuxRunner],
  ['promote-backend-staging-prod.yml/deploy-staging', trustedLinuxRunner],
  ['promote-backend-staging-prod.yml/deploy-prod', trustedLinuxRunner],
  ['publish-verified-public-pages.yml/build', trustedLinuxRunner],
  ['publish-verified-public-pages.yml/deploy', trustedLinuxRunner],
  ['release-android.yml/release', trustedLinuxRunner],
  ['release-ios.yml/release', trustedMacRunner],
  ['runner-resilience-drill.yml/probe', trustedLinuxRunner],
  ['sync-ios-certs.yml/sync', trustedMacRunner],
]);

const requiredChecks = [
  'Build & test',
  'Flutter app + UI packages',
  'Generated state equals committed state',
  'Validate workflow YAML',
  'CodeQL / Security gate',
  'Security / Required gate',
  'Fork PR policy / Required gate',
];

const aggregateJobKeys = new Set([
  'name',
  'needs',
  'if',
  'runs-on',
  'permissions',
  'steps',
]);
const aggregateStepKeys = new Set(['name', 'shell', 'env', 'run']);
const aggregateEnvironmentValue =
  /^\$\{\{\s*(?:needs\.[A-Za-z0-9_.-]+|github\.event_name)\s*\}\}$/u;
const forbiddenAggregateCommand =
  /(?:^|\n)\s*(?:source(?:\s|$)|\.\s+|bash(?:\s|$)|sh(?:\s|$)|node(?:\s|$)|python(?:3)?(?:\s|$)|pwsh(?:\s|$)|powershell(?:\s|$)|curl(?:\s|$)|wget(?:\s|$)|git(?:\s|$)|gh(?:\s|$)|az(?:\s|$))/iu;
const forbiddenCredentialReference =
  /secrets\.|github\.token|GITHUB_TOKEN|ACTIONS_ID_TOKEN|id-token/iu;

function exactLabels(actual, expected) {
  return Array.isArray(actual)
    && actual.length === expected.length
    && actual.every((label, index) => label === expected[index]);
}

function emptyRecord(value) {
  return value !== null
    && typeof value === 'object'
    && !Array.isArray(value)
    && Object.keys(value).length === 0;
}

function exactValue(actual, expected) {
  return JSON.stringify(actual) === JSON.stringify(expected);
}

function readWorkflows(repositoryRoot, errors) {
  const workflowsDirectory = path.join(repositoryRoot, '.github', 'workflows');
  const workflows = new Map();
  let entries;
  try {
    entries = fs.readdirSync(workflowsDirectory, { withFileTypes: true });
  } catch (error) {
    errors.push(`runner routing: cannot read workflows (${error.message})`);
    return workflows;
  }

  for (const entry of entries) {
    if (!entry.isFile() || !/\.ya?ml$/u.test(entry.name)) {
      continue;
    }
    const workflowPath = path.join(workflowsDirectory, entry.name);
    try {
      const document = parseDocument(fs.readFileSync(workflowPath, 'utf8'), {
        uniqueKeys: true,
      });
      if (document.errors.length > 0) {
        throw document.errors[0];
      }
      workflows.set(entry.name, document.toJS());
    } catch (error) {
      errors.push(`${entry.name}: runner routing cannot parse workflow (${error.message})`);
    }
  }
  return workflows;
}

function jobFor(workflows, reference, errors) {
  const separator = reference.indexOf('/');
  const fileName = reference.slice(0, separator);
  const jobId = reference.slice(separator + 1);
  const workflow = workflows.get(fileName);
  if (!workflow) {
    errors.push(`${reference}: workflow is missing`);
    return null;
  }
  const job = workflow?.jobs?.[jobId];
  if (!job) {
    errors.push(`${reference}: job is missing`);
    return null;
  }
  return job;
}

function validateAggregate(reference, contract, job, errors) {
  if (job.name !== contract.name) {
    errors.push(`${reference}: required check name must remain "${contract.name}"`);
  }
  if (!exactValue(job.needs, contract.needs)) {
    errors.push(`${reference}: needs must remain ${JSON.stringify(contract.needs)}`);
  }
  if (!exactLabels(job['runs-on'], prRunner)) {
    errors.push(`${reference}: aggregate must use exact runner labels ${JSON.stringify(prRunner)}`);
  }
  if (!emptyRecord(job.permissions)) {
    errors.push(`${reference}: aggregate permissions must be empty`);
  }
  for (const key of Object.keys(job)) {
    if (!aggregateJobKeys.has(key)) {
      errors.push(`${reference}: aggregate job key ${key} is forbidden`);
    }
  }
  if (Object.hasOwn(job, 'environment')) {
    errors.push(`${reference}: aggregate must not use an environment`);
  }

  const serialized = JSON.stringify(job);
  if (forbiddenCredentialReference.test(serialized)) {
    errors.push(`${reference}: aggregate must not reference secrets, tokens, or OIDC`);
  }

  if (!Array.isArray(job.steps) || job.steps.length !== 1) {
    errors.push(`${reference}: aggregate must contain exactly one inline enforcement step`);
    return;
  }
  const [step] = job.steps;
  for (const key of Object.keys(step)) {
    if (!aggregateStepKeys.has(key)) {
      errors.push(`${reference}: aggregate step key ${key} is forbidden`);
    }
  }
  if (Object.hasOwn(step, 'uses')) {
    errors.push(`${reference}: aggregate must not invoke actions or checkout source`);
  }
  if (step.shell !== 'bash' || typeof step.run !== 'string') {
    errors.push(`${reference}: aggregate enforcement must be an inline bash script`);
  } else if (forbiddenAggregateCommand.test(step.run)) {
    errors.push(`${reference}: aggregate must not load source or invoke external scripts`);
  }
  if (
    step.env === null
    || typeof step.env !== 'object'
    || Array.isArray(step.env)
  ) {
    errors.push(`${reference}: aggregate environment must contain only needs metadata`);
    return;
  }
  for (const [name, value] of Object.entries(step.env)) {
    if (typeof value !== 'string' || !aggregateEnvironmentValue.test(value)) {
      errors.push(`${reference}: aggregate env ${name} must come only from needs or event metadata`);
    }
  }
}

function validateRequiredChecks(repositoryRoot, errors) {
  const contractPath = path.join(
    repositoryRoot,
    '.github',
    'branch-protection-main.json',
  );
  let branchProtection;
  try {
    branchProtection = JSON.parse(fs.readFileSync(contractPath, 'utf8'));
  } catch (error) {
    errors.push(`branch-protection-main.json: cannot read required checks (${error.message})`);
    return;
  }
  const contexts = branchProtection?.required_status_checks?.contexts;
  if (!exactValue(contexts, requiredChecks)) {
    errors.push('branch-protection-main.json: required check names or order changed');
  }
}

export function validateRunnerRouting(repositoryRoot) {
  const errors = [];
  const workflows = readWorkflows(repositoryRoot, errors);

  for (const [reference, contract] of aggregateJobs) {
    const job = jobFor(workflows, reference, errors);
    if (job) {
      validateAggregate(reference, contract, job, errors);
    }
  }

  const healthReference = 'runner-health.yml/probe';
  const health = jobFor(workflows, healthReference, errors);
  if (health) {
    if (health.name !== 'Egress, disk and SDK probe') {
      errors.push(`${healthReference}: health check name must remain unchanged`);
    }
    if (!exactLabels(health['runs-on'], opsProbeRunner)) {
      errors.push(
        `${healthReference}: health probe must use exact isolated labels ${JSON.stringify(opsProbeRunner)}`,
      );
    }
  }

  for (const [reference, expectedLabels] of trustedJobs) {
    const job = jobFor(workflows, reference, errors);
    if (job && !exactLabels(job['runs-on'], expectedLabels)) {
      errors.push(
        `${reference}: privileged job must retain exact trusted labels ${JSON.stringify(expectedLabels)}`,
      );
    }
  }

  for (const [fileName, workflow] of workflows) {
    for (const [jobId, job] of Object.entries(workflow?.jobs ?? {})) {
      const reference = `${fileName}/${jobId}`;
      const labels = Array.isArray(job?.['runs-on'])
        ? job['runs-on']
        : [job?.['runs-on']];
      if (labels.includes('certigo-trusted') && !trustedJobs.has(reference)) {
        errors.push(`${reference}: unexpected job on certigo-trusted`);
      }
      if (
        labels.includes('certigo-ops-probe')
        && reference !== healthReference
      ) {
        errors.push(`${reference}: certigo-ops-probe is reserved for runner health`);
      }
      if (
        (labels.includes('certigo-pr') || labels.includes('certigo-ops-probe'))
        && /secrets\.|azure\/login@|id-token|"environment":/iu.test(
          JSON.stringify(job),
        )
      ) {
        errors.push(`${reference}: non-privileged runner job has a cloud trust surface`);
      }
    }
  }

  validateRequiredChecks(repositoryRoot, errors);
  return errors;
}
