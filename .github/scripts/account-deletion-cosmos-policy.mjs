import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { isAlias, isMap, isPair, isSeq, parseDocument } from 'yaml';
import {
  fingerprintWorkflow,
  isPreApprovalActive,
  legacyWorkflowName,
  loadWorkflowManifest,
  oneShotWorkflowName,
} from './workflow-semantic-fingerprint.mjs';

const legacyWorkflow = legacyWorkflowName;
const oneShotWorkflow = oneShotWorkflowName;
const manifestName = 'workflow-semantic-manifest.json';
const trustedManifestPath = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  manifestName,
);

// Le validateur lit toujours le manifeste du contrôle trusted (la base), jamais celui du checkout
// de PR : une PR ne peut donc pas s'auto-approuver. Le seul chemin légitime est la pré-approbation,
// qui garde `main` cohérent après chaque fusion. Faire tourner `states` sans le workflow
// correspondant laisserait `main` incohérent et bloquerait toutes les PR (#497).
const preApprovalRemedy = 'The validator always reads the manifest of the trusted control (the '
  + 'base branch), never the one in this checkout, so regenerating it here cannot unblock this '
  + 'pull request. A workflow change takes two pull requests, and main stays consistent after '
  + 'each: (1) pre-approval: apply the change locally, run `node '
  + '.github/scripts/generate-workflow-semantic-manifest.mjs --pre-approve`, restore the workflow '
  + 'files, update manifestGoldenDigest, and merge the manifest alone; (2) landing: apply the '
  + 'same change on the updated main, run the generator with `--write` (it consumes the '
  + 'pre-approval), and update manifestGoldenDigest. Never rotate the manifest states without '
  + 'the workflow change: a main whose manifest disagrees with its own workflows blocks every '
  + 'pull request (#497). See docs/runbooks/CI_WORKFLOW_CHANGES.md.';

// Both exact forms are needed during the reviewed two-PR repository migration.
// The trusted semantic manifest still decides which workflow may actually land.
const oneShotConditions = new Set([
  'gchambaud_microsoft/Certigo',
  'gaby27072001/certigo',
].map((repository) => [
  "github.event_name == 'workflow_dispatch'",
  `github.repository == '${repository}'`,
  "github.ref == 'refs/heads/main'",
  "vars.CERTIGO_COSMOS_EMULATOR_ENABLED == 'true'",
].join(' && ')));

const pinnedAction = /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+@[0-9a-f]{40}$/;
const expectedRunner = ['self-hosted', 'Linux', 'X64', 'certigo-cosmos-emulator'];
const expectedRun = 'bash infra/ci-runner/cosmos-emulator/run-account-deletion.sh';
const cloudCredentialKey = /^(?:AZURE|ARM|AWS|GCP|GOOGLE|GCLOUD)_[A-Z0-9_]+$|(?:CLIENT_SECRET|ACCESS_TOKEN|TENANT_ID|SUBSCRIPTION_ID)$/i;
const forbiddenCloudCommand = /\baz\s+login\b|https?:\/\/[^\s]*(?:token|oauth|identity|metadata)|\bcurl\b[^\n]*(?:token|oauth|identity|metadata)/i;
const contractValue = /certigo-cosmos-emulator|CERTIGO_COSMOS_EMULATOR_ENABLED|infra\/ci-runner\/cosmos-emulator|backend\/run-account-deletion|run-account-deletion(?:-cosmos-emulator)?\.sh/i;

const expectedProvenanceRun = `set -euo pipefail
branch="$(git branch --show-current)"
checked_out="$(git rev-parse HEAD)"
remote_main="$(git rev-parse refs/remotes/origin/main)"
if [ "$branch" != "main" ] || [ "$checked_out" != "$remote_main" ]; then
  echo "::error::The emulator gate must run the current merged main checkout."
  exit 1
fi
echo "sha=$checked_out" >> "$GITHUB_OUTPUT"
`;

const expectedSummaryRun = `set -euo pipefail
{
  echo "## Cosmos account-deletion validation"
  echo
  echo "| Field | Value |"
  echo "| --- | --- |"
  echo "| Source | merged \\\`main\\\` |"
  echo "| Commit | \\\`\${CHECKED_OUT_SHA:-unavailable}\\\` |"
  echo "| Runner | \\\`\${RUNNER_NAME}\\\` |"
  echo "| Emulator | local, digest-pinned |"
  echo "| Result | **\${GATE_OUTCOME}** |"
  echo
  echo "No artifact or live Cosmos data was produced."
} >> "$GITHUB_STEP_SUMMARY"
`;

const expectedEnforceRun = `set -euo pipefail
test "$GATE_OUTCOME" = "success"
`;

const neutralCloudEnv = {
  ACTIONS_ID_TOKEN_REQUEST_TOKEN: '',
  ACTIONS_ID_TOKEN_REQUEST_URL: '',
  AZURE_CLIENT_ID: '',
  AZURE_CLIENT_SECRET: '',
  AZURE_FEDERATED_TOKEN_FILE: '',
  AZURE_SUBSCRIPTION_ID: '',
  AZURE_TENANT_ID: '',
  ARM_CLIENT_ID: '',
  ARM_CLIENT_SECRET: '',
  ARM_SUBSCRIPTION_ID: '',
  ARM_TENANT_ID: '',
  COSMOS_EMULATOR_CONNECTION_STRING: '',
  IDENTITY_ENDPOINT: '',
  IMDS_ENDPOINT: '',
  MSI_ENDPOINT: '',
};

const expectedSteps = [
  {
    uses: 'actions/checkout@11d5960a326750d5838078e36cf38b85af677262',
    with: {
      ref: 'refs/heads/main',
      'fetch-depth': 1,
      'persist-credentials': false,
    },
  },
  {
    name: 'Verify merged-main provenance',
    id: 'provenance',
    shell: 'bash',
    run: expectedProvenanceRun,
  },
  {
    uses: 'actions/setup-dotnet@67a3573c9a986a3f9c594539f4ab511d57bb3ce9',
    with: { 'dotnet-version': '8.0.424' },
  },
  {
    name: 'Restore locked test dependencies',
    run: 'dotnet restore backend/tests/Certigo.Infrastructure.Tests/Certigo.Infrastructure.Tests.csproj --locked-mode',
  },
  {
    name: 'Run account-deletion integration against local Cosmos',
    id: 'cosmos-gate',
    'continue-on-error': true,
    env: neutralCloudEnv,
    run: expectedRun,
  },
  {
    name: 'Clean local emulator state',
    if: '${{ always() }}',
    run: `${expectedRun} --cleanup-only`,
  },
  {
    name: 'Publish result summary',
    if: '${{ always() }}',
    env: {
      CHECKED_OUT_SHA: '${{ steps.provenance.outputs.sha }}',
      GATE_OUTCOME: '${{ steps.cosmos-gate.outcome }}',
      RUNNER_NAME: '${{ runner.name }}',
    },
    shell: 'bash',
    run: expectedSummaryRun,
  },
  {
    name: 'Enforce emulator result',
    if: '${{ always() }}',
    env: { GATE_OUTCOME: '${{ steps.cosmos-gate.outcome }}' },
    shell: 'bash',
    run: expectedEnforceRun,
  },
];

const ltsSteps = structuredClone(expectedSteps);
ltsSteps[2].with['dotnet-version'] = '10.0.401';
const approvedStepContracts = new Set([expectedSteps, ltsSteps].map((steps) => JSON.stringify(steps)));

const expectedLegacyWorkflow = {
  name: 'test-account-deletion-cosmos',
  on: {
    repository_dispatch: {
      types: ['test-account-deletion-cosmos'],
    },
  },
  permissions: {},
  jobs: {
    preflight: {
      name: 'Validate empty dispatch payload',
      'runs-on': ['self-hosted', 'Linux', 'X64', 'certigo-pr'],
      permissions: {},
      steps: [
        {
          name: 'Reject payload fields',
          shell: 'bash',
          env: {
            CLIENT_PAYLOAD_JSON: '${{ toJSON(github.event.client_payload) }}',
          },
          run: `set -euo pipefail
if ! jq -e 'type == "object" and length == 0' \\
    <<< "$CLIENT_PAYLOAD_JSON" >/dev/null; then
  echo "::error::The emulator gate does not accept payload fields."
  exit 1
fi
`,
        },
      ],
    },
    emulator: {
      name: 'Account deletion / local emulator',
      needs: 'preflight',
      if: "${{ github.ref == 'refs/heads/main' }}",
      'runs-on': ['self-hosted', 'Linux', 'X64', 'certigo-trusted'],
      permissions: { contents: 'read' },
      steps: [
        {
          uses: 'actions/checkout@11d5960a326750d5838078e36cf38b85af677262',
          with: {
            ref: '${{ github.sha }}',
            'persist-credentials': false,
          },
        },
        {
          uses: 'actions/setup-dotnet@67a3573c9a986a3f9c594539f4ab511d57bb3ce9',
          with: { 'dotnet-version': '8.0.x' },
        },
        {
          name: 'Require a local container runtime',
          shell: 'bash',
          run: `set -euo pipefail
command -v docker >/dev/null
docker info >/dev/null
command -v openssl >/dev/null
command -v curl >/dev/null
`,
        },
        {
          name: 'Restore locked dependencies',
          run: 'dotnet restore backend/tests/Certigo.Infrastructure.Tests/Certigo.Infrastructure.Tests.csproj --locked-mode',
        },
        {
          name: 'Run destructive test against an ephemeral local database',
          env: {
            ACTIONS_ID_TOKEN_REQUEST_TOKEN: '',
            ACTIONS_ID_TOKEN_REQUEST_URL: '',
          },
          run: 'bash backend/run-account-deletion-cosmos-emulator.sh',
        },
      ],
    },
  },
};

function inspectYamlNode(node, errors, label = oneShotWorkflow) {
  if (!node) {
    return;
  }
  if (isAlias(node)) {
    errors.push(`${label}: YAML aliases and merge indirection are forbidden`);
    return;
  }
  if (node.anchor || node.tag) {
    errors.push(`${label}: YAML anchors and explicit tags are forbidden`);
  }
  if (isPair(node)) {
    if (node.key?.value === '<<') {
      errors.push(`${label}: YAML aliases and merge indirection are forbidden`);
    }
    inspectYamlNode(node.key, errors, label);
    inspectYamlNode(node.value, errors, label);
    return;
  }
  if (isMap(node) || isSeq(node)) {
    for (const item of node.items) {
      inspectYamlNode(item, errors, label);
    }
  }
}

function parseWorkflow(content, errors, label) {
  const document = parseDocument(content, {
    merge: false,
    strict: true,
    stringKeys: true,
    uniqueKeys: true,
  });
  for (const issue of [...document.errors, ...document.warnings]) {
    errors.push(`${label}: invalid YAML: ${issue.message}`);
  }
  inspectYamlNode(document.contents, errors, label);
  if (errors.some((error) => error.startsWith(`${label}: invalid YAML`))) {
    return null;
  }
  try {
    return document.toJS({ maxAliasCount: 0 });
  } catch (error) {
    errors.push(`${label}: unsafe YAML structure: ${error.message}`);
    return null;
  }
}

function validateLegacy(content, errors) {
  const workflow = parseWorkflow(content, errors, legacyWorkflow);
  if (
    workflow
    && JSON.stringify(workflow) !== JSON.stringify(expectedLegacyWorkflow)
  ) {
    errors.push(`${legacyWorkflow}: workflow contract must match exactly`);
  }
}

function inspectParsedSecurity(value, errors, currentKey = '') {
  if (Array.isArray(value)) {
    for (const item of value) {
      inspectParsedSecurity(item, errors, currentKey);
    }
    return;
  }
  if (value === null || typeof value !== 'object') {
    if (typeof value !== 'string') {
      return;
    }
    if (/\bsecrets\b/i.test(value)) {
      errors.push(`${oneShotWorkflow}: secret expressions are forbidden`);
    }
    if (/\bgetIDToken\s*\(/i.test(value)) {
      errors.push(`${oneShotWorkflow}: OIDC token requests are forbidden`);
    }
    if (forbiddenCloudCommand.test(value)) {
      errors.push(`${oneShotWorkflow}: cloud login and token endpoint commands are forbidden`);
    }
    if (currentKey === 'runs-on' && /\$\{\{/.test(value)) {
      errors.push(`${oneShotWorkflow}: dynamic runner selection is forbidden`);
    }
    if (currentKey === 'uses') {
      if (/^azure\/login@/i.test(value)) {
        errors.push(`${oneShotWorkflow}: Azure login is forbidden`);
      }
      if (!pinnedAction.test(value)) {
        errors.push(`${oneShotWorkflow}: every action must use an exact 40-character commit SHA`);
      }
    }
    return;
  }

  for (const [rawKey, child] of Object.entries(value)) {
    const key = rawKey.trim().toLowerCase();
    if (key === 'environment') {
      errors.push(`${oneShotWorkflow}: GitHub environments are forbidden`);
    }
    if (key === 'id-token' && String(child).trim().toLowerCase() === 'write') {
      errors.push(`${oneShotWorkflow}: id-token write permission is forbidden`);
    }
    if (key.startsWith('actions_id_token_request_') && child !== '') {
      errors.push(`${oneShotWorkflow}: OIDC request variables are forbidden`);
    }
    if (cloudCredentialKey.test(rawKey) && child !== '') {
      errors.push(`${oneShotWorkflow}: cloud credential variables must be empty or absent`);
    }
    inspectParsedSecurity(child, errors, key);
  }
}

function parseOneShot(content, errors) {
  return parseWorkflow(content, errors, oneShotWorkflow);
}

function validateOneShotStructure(content, errors) {
  const workflow = parseOneShot(content, errors);
  if (!workflow) {
    return;
  }
  inspectParsedSecurity(workflow, errors);

  const triggers = workflow.on;
  if (
    triggers === null
    || typeof triggers !== 'object'
    || Array.isArray(triggers)
    || Object.keys(triggers).length !== 1
    || !Object.hasOwn(triggers, 'workflow_dispatch')
    || triggers.workflow_dispatch !== null
  ) {
    errors.push(`${oneShotWorkflow}: workflow_dispatch must be the only trigger`);
  }
  if (
    JSON.stringify(Object.keys(workflow)) !== JSON.stringify([
      'name',
      'on',
      'concurrency',
      'permissions',
      'jobs',
    ])
    || workflow.name !== 'post-merge-cosmos-account-deletion'
    || JSON.stringify(workflow.concurrency) !== JSON.stringify({
      group: 'post-merge-cosmos-account-deletion-main',
      'cancel-in-progress': false,
    })
  ) {
    errors.push(`${oneShotWorkflow}: top-level workflow contract must match exactly`);
  }

  const jobs = workflow.jobs;
  if (
    jobs === null
    || typeof jobs !== 'object'
    || Array.isArray(jobs)
    || JSON.stringify(Object.keys(jobs)) !== JSON.stringify(['account-deletion'])
  ) {
    errors.push(`${oneShotWorkflow}: jobs must contain only account-deletion`);
  }
  const job = jobs?.['account-deletion'];
  if (
    job === null
    || typeof job !== 'object'
    || Array.isArray(job)
    || Object.hasOwn(job, 'services')
    || Object.hasOwn(job, 'container')
    || Object.hasOwn(job, 'uses')
    || !Array.isArray(job.steps)
  ) {
    errors.push(`${oneShotWorkflow}: account-deletion must be a single service-free steps job`);
  }
  if (
    JSON.stringify(Object.keys(job ?? {})) !== JSON.stringify([
      'name',
      'if',
      'runs-on',
      'timeout-minutes',
      'permissions',
      'env',
      'steps',
    ])
    || job?.name !== 'Account deletion / Cosmos emulator'
    || job?.['timeout-minutes'] !== 30
    || JSON.stringify(job?.env) !== JSON.stringify({
      DOTNET_INSTALL_DIR: '${{ github.workspace }}/.dotnet',
    })
  ) {
    errors.push(`${oneShotWorkflow}: account-deletion job contract must match exactly`);
  }
  if (
    workflow.permissions === null
    || typeof workflow.permissions !== 'object'
    || Array.isArray(workflow.permissions)
    || Object.keys(workflow.permissions).length !== 0
    || JSON.stringify(job?.permissions) !== JSON.stringify({ contents: 'read' })
  ) {
    errors.push(`${oneShotWorkflow}: permissions must be empty globally and contents-read on the job`);
  }
  const condition = typeof job?.if === 'string' ? job.if.replace(/\s+/g, ' ').trim() : '';
  if (!oneShotConditions.has(condition)) {
    errors.push(`${oneShotWorkflow}: account-deletion if condition must be the exact gated conjunction`);
  }

  if (
    !Array.isArray(job?.['runs-on'])
    || JSON.stringify(job['runs-on']) !== JSON.stringify(expectedRunner)
  ) {
    errors.push(`${oneShotWorkflow}: account-deletion must use only the dedicated runner labels`);
  }

  const checkoutSteps = Array.isArray(job?.steps)
    ? job.steps.filter((step) => (
      typeof step?.uses === 'string' && /^actions\/checkout@/i.test(step.uses)
    ))
    : [];
  if (
    checkoutSteps.length !== 1
    || !/^actions\/checkout@[0-9a-f]{40}$/.test(checkoutSteps[0]?.uses ?? '')
    || checkoutSteps[0]?.with?.ref !== 'refs/heads/main'
    || checkoutSteps[0]?.with?.['persist-credentials'] !== false
  ) {
    errors.push(`${oneShotWorkflow}: checkout must pin main with credentials disabled`);
  }

  const runSteps = Array.isArray(job?.steps)
    ? job.steps.filter((step) => step?.run === expectedRun)
    : [];
  if (runSteps.length !== 1) {
    errors.push(`${oneShotWorkflow}: account-deletion must invoke the exact local emulator script`);
  }
  if (!approvedStepContracts.has(JSON.stringify(job?.steps))) {
    errors.push(`${oneShotWorkflow}: steps must exactly match the reviewed one-shot contract`);
  }
}

function validateOneShot(content, active, errors) {
  const lifecycleMarker = active ? '# ACTIVATION-GATED:' : '# FEATURE-OFF:';
  const forbiddenLifecycleMarker = active ? '# FEATURE-OFF:' : '# ACTIVATION-GATED:';
  if (!content.includes(lifecycleMarker)) {
    errors.push(`${oneShotWorkflow}: missing lifecycle marker ${lifecycleMarker}`);
  }
  if (content.includes(forbiddenLifecycleMarker)) {
    errors.push(
      `${oneShotWorkflow}: lifecycle marker must match whether the one-shot gate is active`,
    );
  }

  validateOneShotStructure(content, errors);
}

function hasComposedCosmosContract(job) {
  const executionView = {
    'runs-on': job?.['runs-on'],
    if: job?.if,
    env: job?.env,
    steps: Array.isArray(job?.steps)
      ? job.steps.map((step) => ({
        uses: step?.uses,
        if: step?.if,
        env: step?.env,
        run: step?.run,
      }))
      : [],
  };
  const decoded = JSON.stringify(executionView).toLowerCase();
  const withoutAllowedValidator = decoded.replaceAll(
    'bash infra/ci-runner/cosmos-emulator/validate.sh',
    '',
  );
  if (contractValue.test(withoutAllowedValidator)) {
    return true;
  }
  const runnerContract = withoutAllowedValidator.includes('certigo')
    && withoutAllowedValidator.includes('cosmos')
    && withoutAllowedValidator.includes('emulator');
  const scriptContract = withoutAllowedValidator.includes('infra/ci-runner')
    && withoutAllowedValidator.includes('cosmos')
    && withoutAllowedValidator.includes('emulator')
    && withoutAllowedValidator.includes('account')
    && withoutAllowedValidator.includes('deletion');
  return runnerContract || scriptContract;
}

function inspectShadowNode(node, findings, currentKey = '', inRunsOn = false) {
  if (!node) {
    return;
  }
  if (isAlias(node) || node.anchor || node.tag) {
    findings.add('YAML indirection');
  }
  if (isPair(node)) {
    const key = String(node.key?.value ?? '').trim().toLowerCase();
    const childInRunsOn = inRunsOn || key === 'runs-on';
    inspectShadowNode(node.key, findings, key, childInRunsOn);
    inspectShadowNode(node.value, findings, key, childInRunsOn);
    return;
  }
  if (isMap(node) || isSeq(node)) {
    for (const item of node.items) {
      inspectShadowNode(item, findings, currentKey, inRunsOn);
    }
    return;
  }
  const value = typeof node.value === 'string' ? node.value : '';
  if (inRunsOn && /\$\{\{/.test(value)) {
    findings.add('dynamic runs-on');
  }
}

function inspectActiveWorkflow(content, label) {
  const findings = new Set();
  const document = parseDocument(content, {
    merge: false,
    strict: true,
    stringKeys: true,
    uniqueKeys: true,
  });
  if (document.errors.length > 0 || document.warnings.length > 0) {
    findings.add('invalid YAML');
  }
  inspectShadowNode(document.contents, findings);
  let workflow = null;
  try {
    workflow = document.toJS({ maxAliasCount: 0 });
  } catch {
    findings.add('unsafe YAML');
  }
  for (const job of Object.values(workflow?.jobs ?? {})) {
    if (hasComposedCosmosContract(job)) {
      findings.add('composed Cosmos contract');
    }
  }
  return findings.size > 0
    ? [`${label}: ${[...findings].join(', ')}`]
    : [];
}

function validateControlledWorkflowFile(filePath, label, errors) {
  const stat = fs.lstatSync(filePath);
  if (!stat.isFile() || stat.isSymbolicLink()) {
    errors.push(`${label}: must be a real regular non-symlink file`);
    return;
  }
  if (fs.realpathSync(filePath) !== path.resolve(filePath)) {
    errors.push(`${label}: must resolve to its exact repository path`);
  }
}

function validateActiveWorkflowSet(root, workflows, state, errors, manifestPath, now) {
  let loaded;
  try {
    loaded = loadWorkflowManifest(manifestPath);
  } catch (error) {
    errors.push(`workflow semantic manifest: ${error.message}`);
    return;
  }
  errors.push(...loaded.errors);
  if (loaded.errors.length > 0) {
    return;
  }
  let directoryStat;
  try {
    directoryStat = fs.lstatSync(workflows);
  } catch (error) {
    errors.push(`.github/workflows: ${error.message}`);
    return;
  }
  if (!directoryStat.isDirectory() || directoryStat.isSymbolicLink()) {
    errors.push('.github/workflows must be a real non-symlink directory');
    return;
  }
  if (fs.realpathSync(workflows) !== path.resolve(workflows)) {
    errors.push('.github/workflows must resolve to its exact repository path');
    return;
  }

  // Un chemin est accepté s'il porte l'empreinte revue de `states` ou l'empreinte d'une
  // pré-approbation non expirée de la base ; une pré-approbation `null` autorise le retrait, et
  // l'absence d'un chemin hors `states` est l'état revu (ajout pas encore fusionné).
  const expected = loaded.manifest.states[state];
  const preApproved = loaded.manifest.preApproved;
  const acceptedValues = new Map();
  const expiredApprovals = new Map();
  for (const canonicalPath of new Set([...Object.keys(expected), ...Object.keys(preApproved)])) {
    const accepted = new Set([
      Object.hasOwn(expected, canonicalPath) ? expected[canonicalPath] : null,
    ]);
    const entry = preApproved[canonicalPath];
    if (entry && isPreApprovalActive(entry, now)) {
      accepted.add(entry.digest);
    } else if (entry) {
      expiredApprovals.set(canonicalPath, entry.expires);
    }
    acceptedValues.set(canonicalPath, accepted);
  }
  const pathsByName = new Map(
    [...acceptedValues.keys()].map((canonicalPath) => [
      path.posix.basename(canonicalPath),
      canonicalPath,
    ]),
  );
  const entries = fs.readdirSync(workflows, { withFileTypes: true });
  const actualNames = new Set(entries.map((entry) => entry.name));
  const unexpected = [...actualNames].filter((name) => !pathsByName.has(name)).sort();
  const missing = [...pathsByName]
    .filter(([name, canonicalPath]) => (
      !actualNames.has(name) && !acceptedValues.get(canonicalPath).has(null)
    ))
    .map(([name]) => name)
    .sort();
  if (unexpected.length > 0 || missing.length > 0) {
    const expectedNames = Object.keys(expected).map((entry) => path.posix.basename(entry)).sort();
    const pending = Object.keys(preApproved)
      .map((entry) => (
        expiredApprovals.has(entry)
          ? `${path.posix.basename(entry)} (expired ${expiredApprovals.get(entry)})`
          : path.posix.basename(entry)
      ))
      .sort();
    errors.push(
      `.github/workflows must contain the exact reviewed state ${state} set`
      + `${missing.length > 0 ? `; missing ${missing.join(', ')}` : ''}`
      + `${unexpected.length > 0 ? `; unexpected ${unexpected.join(', ')}` : ''}`
      + `; expected ${expectedNames.join(', ') || 'none'}`
      + `; pre-approved ${pending.join(', ') || 'none'}. `
      + preApprovalRemedy,
    );
  }

  for (const [expectedName, canonicalPath] of [...pathsByName].sort()) {
    const entry = entries.find((candidate) => candidate.name === expectedName);
    if (!entry) {
      continue;
    }
    const filePath = path.join(workflows, entry.name);
    let fileStat;
    try {
      fileStat = fs.lstatSync(filePath);
    } catch (error) {
      errors.push(`${canonicalPath}: ${error.message}`);
      continue;
    }
    if (!entry.isFile() || !fileStat.isFile() || fileStat.isSymbolicLink()) {
      errors.push(`${canonicalPath}: must be a real regular non-symlink file`);
      continue;
    }
    if (fs.realpathSync(filePath) !== path.resolve(filePath)) {
      errors.push(`${canonicalPath}: must resolve to its exact repository path`);
      continue;
    }
    const content = fs.readFileSync(filePath, 'utf8');
    const result = fingerprintWorkflow(canonicalPath, content);
    errors.push(...result.errors);
    if (result.errors.length === 0 && !acceptedValues.get(canonicalPath).has(result.digest)) {
      const approval = expiredApprovals.has(canonicalPath)
        ? `; its pre-approval expired on ${expiredApprovals.get(canonicalPath)} and must be renewed`
        : Object.hasOwn(preApproved, canonicalPath)
          ? ' and from its pre-approved digest'
          : '';
      errors.push(
        `${canonicalPath}: differs from reviewed semantic manifest${approval} `
        + `(found ${result.digest}). `
        + preApprovalRemedy,
      );
    }
    if (
      expectedName !== legacyWorkflow
      && expectedName !== oneShotWorkflow
    ) {
      errors.push(...inspectActiveWorkflow(content, canonicalPath));
    }
  }
}

function findUnexpectedActiveCosmosWorkflows(workflows, allowedFiles) {
  if (!fs.existsSync(workflows)) {
    return [];
  }
  const unexpected = [];
  for (const entry of fs.readdirSync(workflows, { withFileTypes: true })) {
    if (!entry.isFile() || !/\.ya?ml$/i.test(entry.name) || allowedFiles.has(entry.name)) {
      continue;
    }
    const content = fs.readFileSync(path.join(workflows, entry.name), 'utf8');
    const findings = new Set(inspectActiveWorkflow(content, entry.name));
    if (findings.size > 0 || /cosmos.*account-deletion|account-deletion.*cosmos/i.test(entry.name)) {
      unexpected.push(entry.name);
    }
  }
  return unexpected;
}

// `manifestPath` et `now` n'existent que pour les tests : le validateur CLI lit toujours le
// manifeste trusted, situé à côté de ce module, à l'heure courante.
export function validateAccountDeletionCosmosLayout(
  root,
  { manifestPath = trustedManifestPath, now = new Date() } = {},
) {
  const errors = [];
  const workflows = path.join(root, '.github', 'workflows');
  const disabled = path.join(root, '.github', 'workflows-disabled');
  const paths = {
    activeLegacy: path.join(workflows, legacyWorkflow),
    activeOneShot: path.join(workflows, oneShotWorkflow),
    archivedLegacy: path.join(disabled, legacyWorkflow),
    archivedOneShot: path.join(disabled, oneShotWorkflow),
  };
  const present = Object.fromEntries(
    Object.entries(paths).map(([label, file]) => [label, fs.existsSync(file)]),
  );
  for (const [label, file] of Object.entries(paths)) {
    if (present[label]) {
      validateControlledWorkflowFile(file, label, errors);
    }
  }
  const legacyState = present.activeLegacy
    && !present.activeOneShot
    && !present.archivedLegacy
    && !present.archivedOneShot;
  const archivedState = !present.activeLegacy
    && !present.activeOneShot
    && present.archivedLegacy
    && present.archivedOneShot;
  const availableState = !present.activeLegacy
    && present.activeOneShot
    && present.archivedLegacy
    && !present.archivedOneShot;
  const allowedActiveFiles = new Set(
    legacyState ? [legacyWorkflow] : availableState ? [oneShotWorkflow] : [],
  );
  if (!legacyState && !archivedState && !availableState) {
    const layout = Object.entries(present)
      .filter(([, exists]) => exists)
      .map(([label]) => label)
      .join(', ') || 'none';
    return [
      'account-deletion Cosmos workflow layout must be exactly state A (legacy active), '
      + 'state B (both archived), or state C (one-shot active and legacy archived); '
      + `found: ${layout}`,
    ];
  }
  if (errors.length > 0) {
    return errors;
  }

  validateActiveWorkflowSet(
    root,
    workflows,
    legacyState ? 'A' : archivedState ? 'B' : 'C',
    errors,
    manifestPath,
    now,
  );
  if (
    !errors.some((error) => error.startsWith('.github/workflows must be a real'))
  ) {
    const unexpectedActive = findUnexpectedActiveCosmosWorkflows(workflows, allowedActiveFiles);
    if (unexpectedActive.length > 0) {
      errors.push(
        'unexpected active Cosmos account-deletion workflow contract: '
        + unexpectedActive.join(', '),
      );
    }
  }

  if (legacyState) {
    validateLegacy(fs.readFileSync(paths.activeLegacy, 'utf8'), errors);
    return errors;
  }

  validateLegacy(fs.readFileSync(paths.archivedLegacy, 'utf8'), errors);
  validateOneShot(
    fs.readFileSync(availableState ? paths.activeOneShot : paths.archivedOneShot, 'utf8'),
    availableState,
    errors,
  );
  return errors;
}
