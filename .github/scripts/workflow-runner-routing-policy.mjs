import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { parseDocument } from 'yaml';

const prRunner = ['self-hosted', 'Linux', 'X64', 'certigo-pr'];
const trustedLinuxRunner = ['self-hosted', 'Linux', 'X64', 'certigo-trusted'];
const trustedMacRunner = ['self-hosted', 'macOS', 'certigo-trusted'];
const opsProbeRunner = ['self-hosted', 'Linux', 'X64', 'certigo-ops-probe'];

// TEMPORARY BOOTSTRAP CONTRACT: the baseline entries exist only so this policy-only
// PR can pass the immutable validator on main. PR #356 must remove the baseline
// state and its tests after resyncing onto this PR, before #356 is merged.
// Sizes and SHA-256 values come from raw Git blobs at main 3600ce6d5c1601fb0a247bf07b11d74ff43f02b2
// and PR #356 447a18de80bedba494f8a94c2a8f05e2af29f7f9, never from worktree bytes.
const transitionWorkflowBlobs = new Map([
  [
    'ci-project-state.yml',
    {
      baseline: {
        bytes: 4895,
        sha256: 'a3faa6b5fe8ec55eb06df7d82a3f0dbed286f95d8a48d3fbd90cedba39893d36',
      },
      target: {
        bytes: 4872,
        sha256: '5f19fe0b702f069c948b9e51b007a14660402ab30b73280230a70abbefa27b43',
      },
    },
  ],
  [
    'codeql.yml',
    {
      baseline: {
        bytes: 11806,
        sha256: '30cb9b1ab2d3a8d440530194b593e34bdc2623ac28b04f3fa46c391a58afa124',
      },
      target: {
        bytes: 11801,
        sha256: 'ec61f428308fdba1805469d705ce5ee475d347f018b855b7d9f7e9dde2cb1f01',
      },
    },
  ],
  [
    'security-gate.yml',
    {
      baseline: {
        bytes: 8677,
        sha256: 'f8b0c946071b40068f89e4c04a6bb3c41e260086325651788632788a1c6dbab6',
      },
      target: {
        bytes: 8672,
        sha256: '90d66febf6307910ccd36719acfea66c4117f63f9907fe622780d08e2c540ead',
      },
    },
  ],
  [
    'runner-health.yml',
    {
      baseline: {
        bytes: 4561,
        sha256: '5226081f595cda87df354ab2eaf59393476f5b96fcb2ebd56f19ac5eb958ed1d',
      },
      target: {
        bytes: 4558,
        sha256: 'a051d1eae7b51aebabee3fd2157fcd3da247cefd6304e13fd23caaee15d2303e',
      },
    },
  ],
]);

const aggregateJobs = new Map([
  [
    'ci-project-state.yml/validate',
    {
      name: 'Generated state equals committed state',
      needs: 'validate-source',
      baselinePermissions: { contents: 'read' },
    },
  ],
  [
    'codeql.yml/security-gate',
    {
      name: 'CodeQL / Security gate',
      needs: ['freshness', 'changes', 'analyze'],
      baselinePermissions: {},
    },
  ],
  [
    'security-gate.yml/security-gate',
    {
      name: 'Security / Required gate',
      needs: ['changes', 'osv', 'checkov'],
      baselinePermissions: {},
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

function sha256(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

function exactLabels(actual, expected) {
  return Array.isArray(actual)
    && actual.length === expected.length
    && actual.every((label, index) => label === expected[index]);
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
      const bytes = fs.readFileSync(workflowPath);
      const document = parseDocument(bytes.toString('utf8'), { uniqueKeys: true });
      if (document.errors.length > 0) {
        throw document.errors[0];
      }
      workflows.set(entry.name, { bytes, workflow: document.toJS() });
    } catch (error) {
      errors.push(`${entry.name}: runner routing cannot parse workflow (${error.message})`);
    }
  }
  return workflows;
}

function transitionState(workflows, errors) {
  const matches = new Map();
  for (const [fileName, states] of transitionWorkflowBlobs) {
    const candidate = workflows.get(fileName);
    if (!candidate) {
      errors.push(`${fileName}: reviewed runner-routing workflow is missing`);
      continue;
    }
    const actual = {
      bytes: candidate.bytes.length,
      sha256: sha256(candidate.bytes),
    };
    const match = Object.entries(states).find(([, expected]) => (
      actual.bytes === expected.bytes && actual.sha256 === expected.sha256
    ));
    if (!match) {
      errors.push(
        `${fileName}: byte/hash ${actual.bytes}/${actual.sha256} must match one reviewed Git blob`,
      );
      continue;
    }
    matches.set(fileName, match[0]);
  }

  if (matches.size !== transitionWorkflowBlobs.size) {
    return { matches, state: null };
  }
  const states = new Set(matches.values());
  if (states.size !== 1) {
    const detail = [...matches]
      .map(([fileName, state]) => `${fileName}=${state}`)
      .join(', ');
    errors.push(
      `runner routing: temporary bootstrap contract forbids mixed baseline/target blobs (${detail})`,
    );
    return { matches, state: null };
  }
  return { matches, state: states.values().next().value };
}

function jobFor(workflows, reference, errors) {
  const separator = reference.indexOf('/');
  const fileName = reference.slice(0, separator);
  const jobId = reference.slice(separator + 1);
  const workflow = workflows.get(fileName)?.workflow;
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

function validateAggregate(reference, contract, state, job, errors) {
  if (job.name !== contract.name) {
    errors.push(`${reference}: required check name must remain "${contract.name}"`);
  }
  if (!exactValue(job.needs, contract.needs)) {
    errors.push(`${reference}: needs must remain ${JSON.stringify(contract.needs)}`);
  }
  const expectedRunner = state === 'baseline' ? trustedLinuxRunner : prRunner;
  if (!exactLabels(job['runs-on'], expectedRunner)) {
    errors.push(
      `${reference}: ${state} aggregate must use exact labels ${JSON.stringify(expectedRunner)}`,
    );
  }
  const expectedPermissions = state === 'baseline'
    ? contract.baselinePermissions
    : {};
  if (!exactValue(job.permissions, expectedPermissions)) {
    errors.push(
      `${reference}: ${state} aggregate permissions must remain ${JSON.stringify(expectedPermissions)}`,
    );
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
  const transition = transitionState(workflows, errors);

  if (transition.state) {
    for (const [reference, contract] of aggregateJobs) {
      const job = jobFor(workflows, reference, errors);
      if (job) {
        validateAggregate(reference, contract, transition.state, job, errors);
      }
    }

    const healthReference = 'runner-health.yml/probe';
    const health = jobFor(workflows, healthReference, errors);
    if (health) {
      if (health.name !== 'Egress, disk and SDK probe') {
        errors.push(`${healthReference}: health check name must remain unchanged`);
      }
      const expectedRunner = transition.state === 'baseline'
        ? trustedLinuxRunner
        : opsProbeRunner;
      if (!exactLabels(health['runs-on'], expectedRunner)) {
        errors.push(
          `${healthReference}: ${transition.state} health probe must use exact labels ${JSON.stringify(expectedRunner)}`,
        );
      }
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

  const allowedTrustedJobs = new Set(trustedJobs.keys());
  for (const reference of aggregateJobs.keys()) {
    const fileName = reference.slice(0, reference.indexOf('/'));
    if (transition.matches.get(fileName) === 'baseline') {
      allowedTrustedJobs.add(reference);
    }
  }
  if (transition.matches.get('runner-health.yml') === 'baseline') {
    allowedTrustedJobs.add('runner-health.yml/probe');
  }

  const healthReference = 'runner-health.yml/probe';
  for (const [fileName, entry] of workflows) {
    for (const [jobId, job] of Object.entries(entry.workflow?.jobs ?? {})) {
      const reference = `${fileName}/${jobId}`;
      const labels = Array.isArray(job?.['runs-on'])
        ? job['runs-on']
        : [job?.['runs-on']];
      if (labels.includes('certigo-trusted') && !allowedTrustedJobs.has(reference)) {
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
