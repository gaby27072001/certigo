import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import YAML from 'yaml';

export const backendDeployTrustedFiles = Object.freeze([
  '.github/scripts/backend-deploy-workflow-policy.mjs',
  '.github/scripts/backend-deploy-gate.test.mjs',
  '.github/scripts/validate-backend-deploy-dispatch.mjs',
]);

const workflowPath = '.github/workflows/cd-backend.yml';
const capacityDocumentPath = 'docs/deployment-runbook.md';
const legacyWorkflowSize = 37710;
const legacyWorkflowSha256 =
  '48738b01264e33f1f15d8b358e5a5feaad35a09808d8838ec96c8336821fab9b';
// Legacy A hardened with explicit `if:` on deploy-infra and deploy-backend
// so a promotion dispatch (repository_dispatch promote-backend) cannot silently
// skip both deploy jobs when build-release is skipped. The exact bytes below
// pin the only accepted hardened variant; any other content still triggers
// the strict B checks. See `docs/adr/` if you plan to widen the allow-list.
const hardenedLegacyWorkflowSize = 38066;
const hardenedLegacyWorkflowSha256 =
  '586addcce22fbbc86d660e601f5e331cd267c334edf4947bc490a5ba3b68a541';
const strictWorkflowSize = 62593;
const strictWorkflowSha256 =
  '1fac1d96d892080af55348b4253bd319a33cdbbec4ac1575e6dde28c4924e28d';
const strictCapacityDocumentSize = 55424;
const strictCapacityDocumentSha256 =
  '29c7380c31a87dfbf0eea0b4574cc4066cff0bdbe2fcfa4c33b4d79627600ae5';
const circularCapacityDigest =
  '179931e8129ea4d70494a02215288d91525af454907846d205eadedebbda4085';
const revisionLocalPrivilegedInputs = Object.freeze([
  '.github/scripts/backend-deployment-state.mjs',
  '.github/scripts/deploy-flex-onedeploy.sh',
  '.github/scripts/public-domain-contract.mjs',
  '.github/scripts/update-backend-deployment-state.mjs',
  '.github/scripts/verify-backend-deployment-state.mjs',
  '.github/scripts/write-secure-bicep-parameters.mjs',
]);
const revisionLocalPrivilegedTrees = Object.freeze(['infra']);
const canonicalCapacityPrecondition = Buffer.from(
  [
    '<!-- BEGIN BACKEND CAPACITY PRECONDITION -->',
    '### Précondition capacité backend canonique',
    '',
    'État de capacité : **UNKNOWN/NO-GO**.',
    '',
    'Les pools doivent porter exclusivement les labels `certigo-backend-builder` et',
    '`certigo-backend-deployer`, sans alias, suffixe, fallback ni double label. Ils',
    'doivent être physiquement distincts, mono-job et éphémères, sans hôte, disque,',
    'utilisateur de service, cache de projet, état Docker ou segment réseau partagé.',
    '',
    'Aucun digest, fichier session-local ou texte de cette PR ne constitue une preuve',
    'de ces propriétés. Avant toute activation ou planification, un artefact de preuve',
    'séparément approuvé, immutable et versionné doit définir son schéma, son chemin',
    'canonique, la canonicalisation de ses octets, sa provenance et son approbation',
    "indépendante. Jusqu'à l'existence et la validation trusted de cet artefact, les",
    'jobs non planifiables constituent le comportement fail-closed attendu.',
    '<!-- END BACKEND CAPACITY PRECONDITION -->',
  ].join('\n'),
  'utf8',
);

const actions = Object.freeze({
  attest: 'actions/attest@1e69f48acb82d1966a394da916b4c1698aa569d6',
  azureLogin: 'azure/login@f5d393ae46f8fde4be8b75f32e3fc50e654ad0ca',
  checkout: 'actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1',
  download: 'actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c',
  setupDotnet: 'actions/setup-dotnet@26b0ec14cb23fa6904739307f278c14f94c95bf1',
  upload: 'actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a',
});
const actionPrefixes = new Map([
  ['actions/attest@', actions.attest],
  ['azure/login@', actions.azureLogin],
  ['actions/checkout@', actions.checkout],
  ['actions/download-artifact@', actions.download],
  ['actions/setup-dotnet@', actions.setupDotnet],
  ['actions/upload-artifact@', actions.upload],
]);
const builderLabels = ['self-hosted', 'Linux', 'X64', 'certigo-backend-builder'];
const deployerLabels = ['self-hosted', 'Linux', 'X64', 'certigo-backend-deployer'];
const expectedJobs = [
  'validate-target',
  'validate-release-source',
  'validate-public-domain',
  'build-release',
  'attest-release',
  'verify-release-attestation',
  'retain-release',
  'resolve-release',
  'deploy-infra',
  'deploy-backend',
];
const expectedNeeds = new Map([
  ['validate-target', []],
  ['validate-release-source', ['validate-target']],
  ['validate-public-domain', ['validate-target']],
  [
    'build-release',
    ['validate-target', 'validate-release-source', 'validate-public-domain'],
  ],
  [
    'attest-release',
    [
      'validate-target',
      'validate-release-source',
      'validate-public-domain',
      'build-release',
    ],
  ],
  [
    'verify-release-attestation',
    [
      'validate-target',
      'validate-release-source',
      'validate-public-domain',
      'build-release',
      'attest-release',
    ],
  ],
  [
    'retain-release',
    [
      'validate-target',
      'validate-release-source',
      'validate-public-domain',
      'build-release',
      'attest-release',
      'verify-release-attestation',
    ],
  ],
  [
    'resolve-release',
    [
      'validate-target',
      'validate-public-domain',
      'validate-release-source',
      'build-release',
      'attest-release',
      'verify-release-attestation',
      'retain-release',
    ],
  ],
  ['deploy-infra', ['validate-target', 'resolve-release']],
  ['deploy-backend', ['validate-target', 'resolve-release', 'deploy-infra']],
]);
const expectedPermissions = new Map([
  ['validate-target', { contents: 'read' }],
  ['validate-release-source', { actions: 'read', contents: 'read' }],
  ['validate-public-domain', { contents: 'read' }],
  ['build-release', { contents: 'read' }],
  [
    'attest-release',
    {
      actions: 'read',
      'artifact-metadata': 'write',
      attestations: 'write',
      contents: 'read',
      'id-token': 'write',
    },
  ],
  [
    'verify-release-attestation',
    { actions: 'read', attestations: 'read', contents: 'read' },
  ],
  [
    'retain-release',
    {
      actions: 'read',
      attestations: 'read',
      contents: 'read',
      'id-token': 'write',
    },
  ],
  ['resolve-release', { actions: 'read', contents: 'read', 'id-token': 'write' }],
  ['deploy-infra', { contents: 'read', 'id-token': 'write' }],
  ['deploy-backend', { contents: 'read', 'id-token': 'write' }],
]);
const expectedEnvironments = new Map([
  ['validate-public-domain', '${{ needs.validate-target.outputs.target }}'],
  ['attest-release', 'dev'],
  ['retain-release', 'dev'],
  ['resolve-release', 'dev'],
  ['deploy-infra', '${{ needs.validate-target.outputs.target }}'],
  ['deploy-backend', '${{ needs.validate-target.outputs.target }}'],
]);
const expectedTargetOutputs = {
  operation: '${{ steps.target.outputs.operation }}',
  requestedSourceRunId: '${{ steps.target.outputs.requested-source-run-id }}',
  sourceRunId: '${{ steps.target.outputs.source-run-id }}',
  target: '${{ steps.target.outputs.environment }}',
};
const expectedTargetEnvironment = {
  AUTHORIZED_OPERATORS_JSON: '${{ vars.BACKEND_DEPLOY_OPERATORS }}',
  CLIENT_PAYLOAD_JSON: '${{ toJSON(github.event.client_payload) }}',
  EVENT_ACTION: '${{ github.event.action }}',
  EVENT_ACTOR: '${{ github.actor }}',
  EVENT_NAME: '${{ github.event_name }}',
  EVENT_SENDER_LOGIN: '${{ github.event.sender.login }}',
  EVENT_SENDER_TYPE: '${{ github.event.sender.type }}',
  GITHUB_API_URL: '${{ github.api_url }}',
  GITHUB_REF: '${{ github.ref }}',
  GITHUB_REPOSITORY: '${{ github.repository }}',
  GITHUB_RUN_ID: '${{ github.run_id }}',
  GITHUB_TOKEN: '${{ github.token }}',
};
const supportingControls = new Map([
  [
    '.github/scripts/backend-release-manifest.mjs',
    'af3f8c22fc6138c15eb50a9cdf5662ad4165f2f34ea3679839b8b422f00afbba',
  ],
  [
    '.github/scripts/verify-backend-release-transport.sh',
    'd7a866468a9fd3f12c2b4e11ba0a139351b450f62434e58f49f71edb532f9c9a',
  ],
  [
    '.github/scripts/backend-release-attestation.mjs',
    '5b1bae351036f552217ec260c1061c597b557e013965d0b62803bdbc203979e3',
  ],
  [
    '.github/scripts/resolve-backend-release-artifact.mjs',
    '0f494386f14b97446b3a16fe42b567c3fb70fc1fe2d26d419558aa9ce4eb7cad',
  ],
  [
    '.github/scripts/resolve-backend-release.mjs',
    'ccd0d02ea652020ccd129886a6da3ee60861e3324e763f885a034e9976d707d8',
  ],
  [
    '.github/scripts/transfer-backend-release.sh',
    '68b76c4359d18240406df2ea4dc3172f8440840944fe8b061919c0d4130f43a2',
  ],
  [
    '.github/scripts/validate-backend-deploy-dispatch.mjs',
    'e97b668c91459f8ffb4ee265ff2c8d897fbefee3d651620379dac2f5e620c109',
  ],
]);
const artifactJobs = [
  'attest-release',
  'verify-release-attestation',
  'retain-release',
];
const azureJobs = [
  'retain-release',
  'resolve-release',
  'deploy-infra',
  'deploy-backend',
];
const artifactStepNames = new Map([
  [
    'attest-release',
    [
      'Fetch and verify immutable trusted attestation controls',
      'Resolve the only current-run release artifact',
      'Download exact sealed release transport',
      'Verify artifact bytes and complete producer provenance',
      'Create exact signed handoff predicate',
      'Sign exact release handoff',
    ],
  ],
  [
    'verify-release-attestation',
    [
      'Fetch and verify immutable trusted verification controls',
      'Resolve the only current-run release artifact',
      'Download exact attested release transport',
      'Verify artifact bytes and complete producer provenance',
      'Cryptographically verify release attestation identity',
      'Verify every signed release handoff binding',
    ],
  ],
  [
    'retain-release',
    [
      'Fetch and verify immutable trusted retention controls',
      'Independently resolve the only current-run release artifact',
      'Download exact verified release transport',
      'Reverify artifact bytes and complete producer provenance',
      'Reverify signed release attestation before Azure login',
      'Reverify every signed release handoff binding',
      'Azure login for private release retention (OIDC)',
      'Retain build-once release in private dev storage',
    ],
  ],
]);
const sealedRunHashes = new Map([
  [
    'attest-release:Fetch and verify immutable trusted attestation controls',
    '8128236049f338c92557fe1236fdf4d1190c7b3de64cd13cc6bcd68721e50d96',
  ],
  [
    'attest-release:Resolve the only current-run release artifact',
    '9e6b9b115c7d5d43f88a6eb4bb41f3b712c008d50bbd86e86a0a5124653bd1ff',
  ],
  [
    'attest-release:Verify artifact bytes and complete producer provenance',
    'a615f8c840166719ac083743e446857ee5870b4686dc9021bf3006c1ff714bc3',
  ],
  [
    'attest-release:Create exact signed handoff predicate',
    '80def3402f3aa8316826e4f0803fa79b6146c3636de8e8deb2c9aa617eb3a729',
  ],
  [
    'verify-release-attestation:Fetch and verify immutable trusted verification controls',
    '8128236049f338c92557fe1236fdf4d1190c7b3de64cd13cc6bcd68721e50d96',
  ],
  [
    'verify-release-attestation:Resolve the only current-run release artifact',
    '9e6b9b115c7d5d43f88a6eb4bb41f3b712c008d50bbd86e86a0a5124653bd1ff',
  ],
  [
    'verify-release-attestation:Verify artifact bytes and complete producer provenance',
    'a615f8c840166719ac083743e446857ee5870b4686dc9021bf3006c1ff714bc3',
  ],
  [
    'verify-release-attestation:Cryptographically verify release attestation identity',
    'c0de73133f585d2605732fef43aa8aacbcd6ac2c0ec5d4cd55e0265d157ed386',
  ],
  [
    'verify-release-attestation:Verify every signed release handoff binding',
    'a945faff6ca50af59fbd17e579946b8a421219141962c7b2aa4c422bc7eaa848',
  ],
  [
    'retain-release:Fetch and verify immutable trusted retention controls',
    '9b5e4aa34ea667b892c2474df04bba710e3dbaecef5588ec41cadd97000c5e7b',
  ],
  [
    'retain-release:Independently resolve the only current-run release artifact',
    '9e6b9b115c7d5d43f88a6eb4bb41f3b712c008d50bbd86e86a0a5124653bd1ff',
  ],
  [
    'retain-release:Reverify artifact bytes and complete producer provenance',
    'a615f8c840166719ac083743e446857ee5870b4686dc9021bf3006c1ff714bc3',
  ],
  [
    'retain-release:Reverify signed release attestation before Azure login',
    'c0de73133f585d2605732fef43aa8aacbcd6ac2c0ec5d4cd55e0265d157ed386',
  ],
  [
    'retain-release:Reverify every signed release handoff binding',
    'a945faff6ca50af59fbd17e579946b8a421219141962c7b2aa4c422bc7eaa848',
  ],
  [
    'retain-release:Retain build-once release in private dev storage',
    '6ceacd17ce89341cc43dc5e13fc57f2496d544055be2e1e4ffcd4e23f840f119',
  ],
]);
const sealedStepListHashes = new Map([
  ['validate-target', '50b1fb4c3a117b59e66fa7ee2dffb1410f1416f06688967575d0e1d706cb83b6'],
  ['validate-release-source', '395b8349b072720755c19b8434086b4c2b74c2a68665e4fe0742369f2a49ba43'],
  ['validate-public-domain', '80f14a69356857fc6441fa8afc8cea30f140ecc398223d9442021a41ed1f3407'],
  ['build-release', '887f9409e2c57ee0d6471677825cf8a33bf982b36e7e84feeaccc2cbce770eb3'],
  ['attest-release', '6218bf9ef2c2068c3510d5b2863d390e6fb2d08581d635b9ffb09472b50f9f06'],
  ['verify-release-attestation', 'b15e9761259eba3d083da9dca32ff72f6639e0c9319c24324fbfdc3d8059eccf'],
  ['retain-release', 'e5973474ae99b11ab07fb6b81699eca4ea03e4375a94991d7e4faa4e6e25ce77'],
  ['resolve-release', '31e6aa61e55495d3fb6bf820429eabd321d90dfa0538d3078ccabe35cd7253f9'],
  ['deploy-infra', 'c4ee6f9f0ea3aa67e5fa2f41f0bdb246a8beb80351a62a289a7010416805aabf'],
  ['deploy-backend', '1d9da204df39dc1830c99f83cffd69f1f55b30beb86f7a0fd5491cb45b126f8a'],
]);
const expectedArtifactResolverEnvironment = {
  GITHUB_TOKEN: '${{ github.token }}',
};
const expectedTransportEnvironment = {
  EXPECTED_ARTIFACT_DIGEST: '${{ steps.artifact.outputs.artifact-digest }}',
  EXPECTED_ARTIFACT_ID: '${{ steps.artifact.outputs.artifact-id }}',
  EXPECTED_BUILD_SOURCE_RUN_ID: '${{ needs.validate-target.outputs.sourceRunId }}',
  EXPECTED_BUNDLE_SHA256: '${{ steps.artifact.outputs.artifact-digest }}',
  EXPECTED_SOURCE_COMMIT: '${{ needs.validate-release-source.outputs.commitSha }}',
  EXPECTED_WORKFLOW_RUN_ATTEMPT: '${{ github.run_attempt }}',
  EXPECTED_WORKFLOW_RUN_ID: '${{ github.run_id }}',
  EXPECTED_WORKFLOW_SHA: '${{ github.sha }}',
  MANIFEST_SCRIPT:
    '${{ runner.temp }}/certigo-backend-controls/backend-release-manifest.mjs',
  RELEASE_DIRECTORY: '${{ runner.temp }}/certigo-backend-release',
  TRANSPORT_DIRECTORY: '${{ steps.download.outputs.download-path }}',
};
const expectedAttestationEnvironment = {
  ARTIFACT_DIGEST: '${{ steps.verify-transport.outputs.artifact-digest }}',
  ARTIFACT_ID: '${{ steps.verify-transport.outputs.artifact-id }}',
  BUILD_SOURCE_RUN_ID: '${{ steps.verify-transport.outputs.build-source-run-id }}',
  BUNDLE_SHA256: '${{ steps.verify-transport.outputs.bundle-sha256 }}',
  PACKAGE_SHA256: '${{ steps.verify-transport.outputs.package-sha256 }}',
  SBOM_SHA256: '${{ steps.verify-transport.outputs.sbom-sha256 }}',
  SOURCE_COMMIT: '${{ steps.verify-transport.outputs.source-commit }}',
  WORKFLOW_RUN_ATTEMPT:
    '${{ steps.verify-transport.outputs.workflow-run-attempt }}',
  WORKFLOW_RUN_ID: '${{ steps.verify-transport.outputs.workflow-run-id }}',
  WORKFLOW_SHA: '${{ steps.verify-transport.outputs.workflow-sha }}',
};
const expectedResolveOutputs = {
  packageSha256: '${{ steps.verify.outputs.package-sha256 }}',
  sourceCommit: '${{ steps.verify.outputs.commit-sha }}',
  workflowRunAttempt: '${{ steps.verify.outputs.source-run-attempt }}',
  workflowSha: '${{ steps.verify.outputs.workflow-sha }}',
};
const expectedDeployEnvironment = {
  COMMIT_SHA: '${{ needs.resolve-release.outputs.sourceCommit }}',
  DEPLOYMENT_CONTAINER: '${{ needs.deploy-infra.outputs.deploymentContainerName }}',
  DEPLOYMENT_OPERATION: '${{ needs.validate-target.outputs.operation }}',
  EXPECTED_PACKAGE_SHA256: '${{ needs.resolve-release.outputs.packageSha256 }}',
  EXPECTED_RUN_ATTEMPT: '${{ needs.resolve-release.outputs.workflowRunAttempt }}',
  EXPECTED_WORKFLOW_SHA: '${{ needs.resolve-release.outputs.workflowSha }}',
  FUNCTION_APP_NAME: '${{ needs.deploy-infra.outputs.functionAppName }}',
  FUNCTION_INTEGRATION_SUBNET_NAME:
    '${{ needs.deploy-infra.outputs.functionIntegrationSubnetName }}',
  SOURCE_RUN_ID: '${{ needs.validate-target.outputs.sourceRunId }}',
  STORAGE_ACCOUNT: '${{ needs.deploy-infra.outputs.storageAccount }}',
  STORAGE_BLOB_ENDPOINT: '${{ needs.deploy-infra.outputs.storageBlobEndpoint }}',
  SUBSCRIPTION_ID: '${{ secrets.AZURE_SUBSCRIPTION_ID }}',
  TARGET_ENV: '${{ needs.validate-target.outputs.target }}',
};

function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

function normalized(value) {
  return String(value ?? '').replace(/\s+/gu, ' ').trim();
}

function exactArray(actual, expected) {
  return Array.isArray(actual) && JSON.stringify(actual) === JSON.stringify(expected);
}

function exactObject(actual, expected) {
  if (!actual || typeof actual !== 'object' || Array.isArray(actual)) {
    return false;
  }
  const actualKeys = Object.keys(actual).sort();
  const expectedKeys = Object.keys(expected).sort();
  return JSON.stringify(actualKeys) === JSON.stringify(expectedKeys)
    && expectedKeys.every((key) => actual[key] === expected[key]);
}

function needsList(job) {
  if (job?.needs === undefined) {
    return [];
  }
  return Array.isArray(job.needs) ? job.needs : [job.needs];
}

function jobText(job) {
  return JSON.stringify(job ?? {});
}

function stepIndex(job, name) {
  return job?.steps?.findIndex((step) => step?.name === name) ?? -1;
}

function stepsUsing(jobs, action) {
  return Object.entries(jobs).flatMap(([jobId, job]) => (
    (job?.steps ?? [])
      .filter((step) => step?.uses === action)
      .map((step) => ({ jobId, step }))
  ));
}

function parseWorkflow(text, label) {
  if (typeof text !== 'string') {
    return { error: `${label}: workflow policy input is missing` };
  }
  try {
    const workflow = YAML.parse(text);
    if (!workflow || typeof workflow !== 'object' || Array.isArray(workflow)) {
      return { error: `${label}: workflow policy input must be a YAML object` };
    }
    return { workflow };
  } catch (error) {
    return { error: `${label}: cannot parse workflow policy input: ${error.message}` };
  }
}

function workflowInput(input) {
  if (Buffer.isBuffer(input)) {
    return { bytes: input, text: input.toString('utf8') };
  }
  if (typeof input === 'string') {
    return { bytes: Buffer.from(input, 'utf8'), text: input };
  }
  return undefined;
}

function ancestorJobs(jobs, jobId, errors, visiting = new Set()) {
  if (visiting.has(jobId)) {
    errors.push(`cd-backend.yml: job dependency cycle reaches ${jobId}`);
    return new Set();
  }
  const nextVisiting = new Set(visiting);
  nextVisiting.add(jobId);
  const ancestors = new Set();
  for (const dependency of needsList(jobs[jobId])) {
    if (!jobs[dependency]) {
      errors.push(`cd-backend.yml: job ${jobId} needs missing job ${dependency}`);
      continue;
    }
    ancestors.add(dependency);
    for (const ancestor of ancestorJobs(jobs, dependency, errors, nextVisiting)) {
      ancestors.add(ancestor);
    }
  }
  return ancestors;
}

function exactReleaseCondition(dependency = '') {
  return normalized(`
    \${{
      needs.validate-target.outputs.operation == 'release'
      && needs.validate-release-source.result == 'success'
      && needs.validate-public-domain.result == 'success'
      && needs.build-release.result == 'success'
      ${dependency ? `&& needs.${dependency}.result == 'success'` : ''}
    }}
  `);
}

function validateSupportingControls(controls, errors) {
  if (controls === undefined) {
    return;
  }
  for (const [relativePath, expectedHash] of supportingControls) {
    const bytes = controls.get(relativePath);
    if (!Buffer.isBuffer(bytes)) {
      errors.push(`candidate supporting control: missing ${relativePath}`);
      continue;
    }
    if (sha256(bytes) !== expectedHash) {
      errors.push(
        `candidate supporting control: ${relativePath} must match its literal SHA256`,
      );
    }
    if (bytes.includes(Buffer.from(circularCapacityDigest, 'utf8'))) {
      errors.push(
        `candidate supporting control: ${relativePath} contains the forbidden circular capacity digest`,
      );
    }
  }
  const capacityDocument = controls.get(capacityDocumentPath);
  if (!Buffer.isBuffer(capacityDocument)) {
    errors.push(`candidate capacity contract: missing ${capacityDocumentPath}`);
  } else {
    if (
      capacityDocument.length !== strictCapacityDocumentSize
      || sha256(capacityDocument) !== strictCapacityDocumentSha256
    ) {
      errors.push(`${capacityDocumentPath}: must match the reviewed raw Git blob`);
    }
    const firstMatch = capacityDocument.indexOf(canonicalCapacityPrecondition);
    const secondMatch = firstMatch < 0
      ? -1
      : capacityDocument.indexOf(canonicalCapacityPrecondition, firstMatch + 1);
    if (firstMatch < 0 || secondMatch >= 0) {
      errors.push(
        `${capacityDocumentPath}: must contain exactly one canonical UNKNOWN/NO-GO capacity section`,
      );
    }
    const text = capacityDocument.toString('utf8');
    if (
      (text.match(/<!-- BEGIN BACKEND CAPACITY PRECONDITION -->/gu) ?? []).length !== 1
      || (text.match(/<!-- END BACKEND CAPACITY PRECONDITION -->/gu) ?? []).length !== 1
      || (text.match(/État de capacité\s*:/gu) ?? []).length !== 1
      || /(?:État de capacité|capacity state)\s*:[^\r\n]*(?:PROVEN|(?<!NO-)GO)/iu.test(text)
    ) {
      errors.push(`${capacityDocumentPath}: competing or permissive capacity claims are forbidden`);
    }
    if (capacityDocument.includes(Buffer.from(circularCapacityDigest, 'utf8'))) {
      errors.push(`${capacityDocumentPath}: forbidden circular physical-capacity digest is present`);
    }
  }
}

function requireHashMarkers(jobId, job, relativePaths, errors) {
  const serialized = jobText(job);
  for (const relativePath of relativePaths) {
    const marker = `${supportingControls.get(relativePath)}  ${path.basename(relativePath)}`;
    if (!serialized.includes(marker)) {
      errors.push(
        `cd-backend.yml: ${jobId} must bind ${path.basename(relativePath)} to its literal SHA256`,
      );
    }
  }
}

function validateArtifactJobs(workflow, errors) {
  const jobs = workflow.jobs ?? {};
  const artifactConditions = new Map([
    ['attest-release', exactReleaseCondition()],
    ['verify-release-attestation', exactReleaseCondition('attest-release')],
    [
      'retain-release',
      normalized(`
        \${{
          needs.validate-target.outputs.operation == 'release'
          && needs.validate-release-source.result == 'success'
          && needs.validate-public-domain.result == 'success'
          && needs.build-release.result == 'success'
          && needs.attest-release.result == 'success'
          && needs.verify-release-attestation.result == 'success'
        }}
      `),
    ],
  ]);
  for (const jobId of artifactJobs) {
    const job = jobs[jobId];
    const serialized = jobText(job);
    const steps = job?.steps ?? [];
    if (
      !Array.isArray(steps)
      || JSON.stringify(steps.map((step) => step?.name))
        !== JSON.stringify(artifactStepNames.get(jobId))
    ) {
      errors.push(`cd-backend.yml: ${jobId} must keep its exact sealed step sequence`);
    }
    for (const step of steps) {
      if (typeof step?.run !== 'string') {
        continue;
      }
      const expectedHash = sealedRunHashes.get(`${jobId}:${step.name}`);
      if (!expectedHash || sha256(step.run) !== expectedHash) {
        errors.push(`cd-backend.yml: ${jobId} step ${step.name} must keep sealed bytes`);
      }
    }
    if (
      normalized(job?.if) !== artifactConditions.get(jobId)
      || serialized.includes('actions/checkout@')
      || serialized.includes('.release-source')
      || serialized.includes('setup-dotnet@')
      || serialized.includes('dotnet ')
      || serialized.includes('dotnet-tool')
      || serialized.includes('npm ')
      || serialized.includes('exec ')
      || serialized.includes('eval ')
      || serialized.includes('ARTIFACTS_METADATA_FILE')
    ) {
      errors.push(
        `cd-backend.yml: ${jobId} must verify immutable bytes without checkout, build, source execution, exec or eval`,
      );
    }
    requireHashMarkers(
      jobId,
      job,
      [
        '.github/scripts/backend-release-manifest.mjs',
        '.github/scripts/verify-backend-release-transport.sh',
        '.github/scripts/backend-release-attestation.mjs',
        '.github/scripts/resolve-backend-release-artifact.mjs',
      ],
      errors,
    );

    const resolveName = jobId === 'retain-release'
      ? 'Independently resolve the only current-run release artifact'
      : 'Resolve the only current-run release artifact';
    const downloadName = {
      'attest-release': 'Download exact sealed release transport',
      'retain-release': 'Download exact verified release transport',
      'verify-release-attestation': 'Download exact attested release transport',
    }[jobId];
    const transportName = jobId === 'retain-release'
      ? 'Reverify artifact bytes and complete producer provenance'
      : 'Verify artifact bytes and complete producer provenance';
    const resolveIndex = stepIndex(job, resolveName);
    const downloadIndex = stepIndex(job, downloadName);
    const transportIndex = stepIndex(job, transportName);
    if (!(resolveIndex >= 0 && resolveIndex < downloadIndex && downloadIndex < transportIndex)) {
      errors.push(`cd-backend.yml: ${jobId} must resolve, download, then verify the artifact`);
    }
    const artifactStep = steps[resolveIndex];
    if (
      artifactStep?.id !== 'artifact'
      || !exactObject(artifactStep?.env, expectedArtifactResolverEnvironment)
      || normalized(artifactStep?.run)
        !== normalized(`
          node
          "$RUNNER_TEMP/certigo-backend-controls/resolve-backend-release-artifact.mjs"
        `)
    ) {
      errors.push(`cd-backend.yml: ${jobId} must execute the sealed artifact resolver`);
    }
    const download = steps[downloadIndex];
    if (
      download?.uses !== actions.download
      || download?.id !== 'download'
      || !exactObject(download?.with, {
        'artifact-ids': '${{ steps.artifact.outputs.artifact-id }}',
        'digest-mismatch': 'error',
        path: '${{ runner.temp }}/certigo-backend-transport',
        'skip-decompress': true,
      })
    ) {
      errors.push(
        `cd-backend.yml: ${jobId} artifact download must use one resolved raw id and fail on digest mismatch`,
      );
    }
    const transport = steps[transportIndex];
    if (
      transport?.id !== 'verify-transport'
      || !exactObject(transport?.env, expectedTransportEnvironment)
      || normalized(transport?.run)
        !== normalized(`
          bash
          "$RUNNER_TEMP/certigo-backend-controls/verify-backend-release-transport.sh"
        `)
    ) {
      errors.push(`cd-backend.yml: ${jobId} must execute the sealed transport verifier`);
    }
  }

  const predicate = jobs['attest-release']?.steps?.[4];
  if (
    !exactObject(predicate?.env, expectedAttestationEnvironment)
    || normalized(predicate?.run)
      !== normalized(`
        node
        "$RUNNER_TEMP/certigo-backend-controls/backend-release-attestation.mjs"
        create
        "$RUNNER_TEMP/certigo-backend-attestation-predicate.json"
      `)
  ) {
    errors.push('cd-backend.yml: attest-release must create the exact signed predicate');
  }
  for (const [jobId, stepPosition] of [
    ['verify-release-attestation', 5],
    ['retain-release', 5],
  ]) {
    const step = jobs[jobId]?.steps?.[stepPosition];
    if (
      !exactObject(step?.env, expectedAttestationEnvironment)
      || normalized(step?.run)
        !== normalized(`
          node
          "$RUNNER_TEMP/certigo-backend-controls/backend-release-attestation.mjs"
          verify
          "$RUNNER_TEMP/certigo-backend-verified-attestation.json"
        `)
    ) {
      errors.push(`cd-backend.yml: ${jobId} must verify every signed predicate binding`);
    }
  }

  const attestSteps = stepsUsing(jobs, actions.attest);
  if (attestSteps.length !== 1 || attestSteps[0]?.jobId !== 'attest-release') {
    errors.push('cd-backend.yml: attest-release must be the sole attestation signer');
  } else if (!exactObject(attestSteps[0].step.with, {
    'predicate-path':
      '${{ runner.temp }}/certigo-backend-attestation-predicate.json',
    'predicate-type': 'https://certigo.dev/attestations/backend-release/v1',
    'show-summary': false,
    'subject-digest': 'sha256:${{ steps.verify-transport.outputs.bundle-sha256 }}',
    'subject-name': 'backend-release-bundle.tar',
  })) {
    errors.push('cd-backend.yml: signed release attestation contract must remain exact');
  }

  const verify = jobs['verify-release-attestation'];
  if (
    verify?.environment !== undefined
    || verify?.permissions?.['id-token'] === 'write'
    || jobText(verify).includes('secrets.')
    || jobText(verify).includes('azure/login@')
  ) {
    errors.push(
      'cd-backend.yml: verify-release-attestation must complete before Environment, OIDC and Azure',
    );
  }
  for (const jobId of ['verify-release-attestation', 'retain-release']) {
    const runs = (jobs[jobId]?.steps ?? [])
      .map((step) => step?.run)
      .filter((run) => typeof run === 'string')
      .join('\n');
    for (const marker of [
      'gh attestation verify',
      '--repo "$GITHUB_REPOSITORY"',
      '$GITHUB_REPOSITORY/.github/workflows/cd-backend.yml',
      '--signer-digest "$GITHUB_SHA"',
      '--source-digest "$GITHUB_SHA"',
      '--source-ref refs/heads/main',
      'https://certigo.dev/attestations/backend-release/v1',
      '--limit 2',
      '--format json',
      'backend-release-attestation.mjs',
    ]) {
      if (!runs.includes(marker)) {
        errors.push(`cd-backend.yml: ${jobId} must enforce attestation marker ${marker}`);
      }
    }
  }

  const retain = jobs['retain-release'];
  requireHashMarkers(
    'retain-release',
    retain,
    ['.github/scripts/transfer-backend-release.sh'],
    errors,
  );
  const orderedNames = [
    'Independently resolve the only current-run release artifact',
    'Download exact verified release transport',
    'Reverify artifact bytes and complete producer provenance',
    'Reverify signed release attestation before Azure login',
    'Reverify every signed release handoff binding',
    'Azure login for private release retention (OIDC)',
    'Retain build-once release in private dev storage',
  ];
  const indexes = orderedNames.map((name) => stepIndex(retain, name));
  if (
    indexes.some((index) => index < 0)
    || indexes.some((index, position) => position > 0 && index <= indexes[position - 1])
  ) {
    errors.push(
      'cd-backend.yml: retention must finish all independent verification before Azure login',
    );
  }
  if (
    jobText(jobs['attest-release']).includes('azure/login@')
    || jobText(jobs['attest-release']).includes('secrets.AZURE_')
    || jobText(jobs['attest-release']).includes('transfer-backend-release.sh')
    || jobText(jobs['attest-release']).includes('az ')
  ) {
    errors.push('cd-backend.yml: attest-release must have signing but no Azure capability');
  }
}

export function validateBackendDeployWorkflow(candidateInput, trustedInput, controls) {
  const trustedSource = workflowInput(trustedInput);
  if (!trustedSource) {
    return ['trusted cd-backend.yml: workflow policy input is missing'];
  }
  const { bytes: trustedBytes, text: trustedText } = trustedSource;
  const trusted = parseWorkflow(trustedText, 'trusted cd-backend.yml');
  if (trusted.error) {
    return [trusted.error];
  }
  const candidateSource = workflowInput(candidateInput);
  if (!candidateSource) {
    return ['cd-backend.yml: workflow policy input is missing'];
  }
  const { bytes: candidateBytes, text: candidateText } = candidateSource;
  const candidateDigest = sha256(candidateBytes);
  if (
    candidateBytes.equals(trustedBytes)
    && candidateBytes.length === legacyWorkflowSize
    && candidateDigest === legacyWorkflowSha256
  ) {
    return [];
  }
  if (
    candidateBytes.equals(trustedBytes)
    && candidateBytes.length === hardenedLegacyWorkflowSize
    && candidateDigest === hardenedLegacyWorkflowSha256
  ) {
    return [];
  }
  const parsed = parseWorkflow(candidateText, 'cd-backend.yml');
  if (parsed.error) {
    return [parsed.error];
  }
  const workflow = parsed.workflow;
  const errors = [];
  if (candidateBytes.length !== strictWorkflowSize || candidateDigest !== strictWorkflowSha256) {
    errors.push('cd-backend.yml: strict workflow bytes do not match the reviewed B object');
  }
  if (candidateText.includes(circularCapacityDigest)) {
    errors.push('cd-backend.yml: forbidden circular physical-capacity digest is present');
  }
  validateSupportingControls(controls, errors);

  if (
    !workflow.on
    || typeof workflow.on !== 'object'
    || Array.isArray(workflow.on)
    || !exactArray(Object.keys(workflow.on), ['repository_dispatch'])
    || !workflow.on.repository_dispatch
    || typeof workflow.on.repository_dispatch !== 'object'
    || Array.isArray(workflow.on.repository_dispatch)
    || !exactArray(Object.keys(workflow.on.repository_dispatch), ['types'])
    || !exactArray(workflow.on.repository_dispatch.types, ['promote-backend'])
  ) {
    errors.push('cd-backend.yml: trigger must be only repository_dispatch promote-backend');
  }
  if (!exactObject(workflow.permissions, {})) {
    errors.push('cd-backend.yml: top-level permissions must remain empty');
  }
  if (!exactObject(workflow.concurrency, {
    'cancel-in-progress': false,
    group: 'cd-backend-${{ github.event.client_payload.environment }}',
  })) {
    errors.push('cd-backend.yml: concurrency contract must remain exact and non-cancelling');
  }
  if (JSON.stringify(workflow).includes('continue-on-error')) {
    errors.push('cd-backend.yml: continue-on-error is forbidden');
  }

  const jobs = workflow.jobs ?? {};
  if (jobs['validate-public-domain']?.if !== undefined) {
    errors.push('cd-backend.yml: validate-public-domain must use the default success gate');
  }
  if (JSON.stringify(Object.keys(jobs)) !== JSON.stringify(expectedJobs)) {
    errors.push('cd-backend.yml: deployment workflow job order and set must remain exact');
  }
  for (const jobId of expectedJobs) {
    const job = jobs[jobId];
    if (!job) {
      errors.push(`cd-backend.yml: required job ${jobId} is missing`);
      continue;
    }
    if (!exactArray(needsList(job), expectedNeeds.get(jobId))) {
      errors.push(`cd-backend.yml: job ${jobId} must keep its exact ordered needs`);
    }
    if (!exactObject(job.permissions, expectedPermissions.get(jobId))) {
      errors.push(`cd-backend.yml: job ${jobId} must keep exact least privilege`);
    }
    const environment = expectedEnvironments.get(jobId);
    if (environment === undefined) {
      if (job.environment !== undefined) {
        errors.push(`cd-backend.yml: job ${jobId} must not receive an Environment`);
      }
    } else if (normalized(job.environment) !== environment) {
      errors.push(`cd-backend.yml: job ${jobId} must use Environment ${environment}`);
    }
    const labels = jobId === 'build-release' ? builderLabels : deployerLabels;
    if (!exactArray(job['runs-on'], labels)) {
      errors.push(`cd-backend.yml: ${jobId} must use its sole exact backend runner role`);
    }
    const backendLabels = Array.isArray(job['runs-on'])
      ? job['runs-on'].filter((label) => String(label).startsWith('certigo-'))
      : [];
    if (
      backendLabels.length !== 1
      || backendLabels[0] !== labels[3]
      || backendLabels.some((label) => (
        label === 'certigo-trusted'
        || !['certigo-backend-builder', 'certigo-backend-deployer'].includes(label)
      ))
    ) {
      errors.push(`cd-backend.yml: ${jobId} uses an alias, fallback or dual runner label`);
    }
    if (sha256(JSON.stringify(job.steps ?? null)) !== sealedStepListHashes.get(jobId)) {
      errors.push(`cd-backend.yml: job ${jobId} must keep its exact ordered step allowlist`);
    }
  }

  for (const [jobId, job] of Object.entries(jobs)) {
    for (const step of job?.steps ?? []) {
      if (typeof step?.uses !== 'string') {
        continue;
      }
      for (const [prefix, pin] of actionPrefixes) {
        if (step.uses.startsWith(prefix) && step.uses !== pin) {
          errors.push(`cd-backend.yml: ${jobId} must pin ${prefix} to ${pin}`);
        }
      }
    }
  }

  const target = jobs['validate-target'];
  if (normalized(target?.if) !== "${{ github.ref == 'refs/heads/main' }}") {
    errors.push('cd-backend.yml: validate-target condition must be exactly main ref');
  }
  if (!exactObject(target?.outputs, expectedTargetOutputs)) {
    errors.push('cd-backend.yml: validate-target outputs must match the exact gate contract');
  }
  if (
    target?.steps?.length !== 2
    || target.steps[0]?.uses !== actions.checkout
    || !exactObject(target.steps[0]?.with, {
      ref: '${{ github.sha }}',
      'persist-credentials': false,
    })
    || target.steps[1]?.id !== 'target'
    || !exactObject(target.steps[1]?.env, expectedTargetEnvironment)
  ) {
    errors.push('cd-backend.yml: validate-target checkout and dispatch gate must remain exact');
  }
  if (jobText(target).includes('secrets.') || jobText(target).includes('ENVIRONMENT_METADATA_FILE')) {
    errors.push('cd-backend.yml: validate-target must be secret-free and inspect live Environment');
  }
  if (
    normalized(jobs['validate-release-source']?.if)
      !== "${{ needs.validate-target.outputs.operation == 'release' }}"
  ) {
    errors.push('cd-backend.yml: validate-release-source must be exactly release-only');
  }
  for (const jobId of ['validate-release-source', 'validate-public-domain']) {
    const text = jobText(jobs[jobId]);
    if (
      text.includes('secrets.')
      || text.includes('azure/login@')
      || jobs[jobId]?.permissions?.['id-token'] === 'write'
    ) {
      errors.push(`cd-backend.yml: ${jobId} must have no secret, Azure or OIDC capability`);
    }
  }

  const build = jobs['build-release'];
  const buildText = jobText(build);
  if (
    normalized(build?.if)
      !== "${{ needs.validate-target.outputs.operation == 'release' && needs.validate-release-source.result == 'success' }}"
  ) {
    errors.push('cd-backend.yml: build-release condition must require release and source success');
  }
  if (
    build?.outputs !== undefined
    || build?.environment !== undefined
    || buildText.includes('secrets.')
    || buildText.includes('id-token')
    || buildText.includes('azure/login@')
    || buildText.includes('az ')
    || buildText.includes('transfer-backend-release.sh')
    || buildText.includes('gh attestation')
    || buildText.includes('actions/attest@')
  ) {
    errors.push(
      'cd-backend.yml: builder must have no outputs, Environment, secret, OIDC, Azure or signing capability',
    );
  }
  if (candidateText.includes('needs.build-release.outputs')) {
    errors.push('cd-backend.yml: downstream jobs must not trust builder outputs');
  }
  const uploads = stepsUsing(jobs, actions.upload);
  if (
    uploads.length !== 1
    || uploads[0]?.jobId !== 'build-release'
    || uploads[0]?.step?.id !== 'transport'
    || !exactObject(uploads[0]?.step?.with, {
      archive: false,
      'if-no-files-found': 'error',
      'include-hidden-files': false,
      overwrite: false,
      path: './backend-release-bundle.tar',
      'retention-days': 1,
    })
  ) {
    errors.push('cd-backend.yml: builder must be the sole exact raw artifact uploader');
  }

  validateArtifactJobs(workflow, errors);

  const resolveCondition = normalized(`
    \${{
      always()
      && needs.validate-target.result == 'success'
      && needs.validate-public-domain.result == 'success'
      && (
        (
          needs.validate-target.outputs.operation == 'release'
          && needs.validate-release-source.result == 'success'
          && needs.build-release.result == 'success'
          && needs.attest-release.result == 'success'
          && needs.verify-release-attestation.result == 'success'
          && needs.retain-release.result == 'success'
        )
        || (
          needs.validate-target.outputs.operation != 'release'
          && needs.validate-release-source.result == 'skipped'
          && needs.build-release.result == 'skipped'
          && needs.attest-release.result == 'skipped'
          && needs.verify-release-attestation.result == 'skipped'
          && needs.retain-release.result == 'skipped'
        )
      )
    }}
  `);
  if (normalized(jobs['resolve-release']?.if) !== resolveCondition) {
    errors.push('cd-backend.yml: resolver must keep the exact release success/non-release skip table');
  }
  requireHashMarkers(
    'resolve-release',
    jobs['resolve-release'],
    [
      '.github/scripts/backend-release-manifest.mjs',
      '.github/scripts/resolve-backend-release.mjs',
      '.github/scripts/transfer-backend-release.sh',
    ],
    errors,
  );
  if (!exactObject(jobs['resolve-release']?.outputs, expectedResolveOutputs)) {
    errors.push(
      'cd-backend.yml: resolve-release must expose every verified manifest provenance binding',
    );
  }
  const alwaysJobs = Object.entries(jobs)
    .filter(([, job]) => normalized(job?.if).includes('always()'))
    .map(([jobId]) => jobId);
  if (!exactArray(alwaysJobs, ['resolve-release'])) {
    errors.push('cd-backend.yml: always() is allowed only in the sealed resolver');
  }
  for (const jobId of ['deploy-infra', 'deploy-backend']) {
    if (jobs[jobId]?.if !== undefined) {
      errors.push(`cd-backend.yml: ${jobId} must use the default success gate`);
    }
    const checkouts = (jobs[jobId]?.steps ?? [])
      .filter((step) => step?.uses === actions.checkout);
    if (
      checkouts.length !== 1
      || !exactObject(checkouts[0]?.with, {
        ref: '${{ github.sha }}',
        'persist-credentials': false,
      })
      || jobText(jobs[jobId]).includes('.release-source')
    ) {
      errors.push(`cd-backend.yml: ${jobId} may checkout only the immutable workflow SHA`);
    }
  }

  const oidcJobs = Object.entries(jobs)
    .filter(([, job]) => job?.permissions?.['id-token'] === 'write')
    .map(([jobId]) => jobId);
  if (!exactArray(
    oidcJobs,
    ['attest-release', 'retain-release', 'resolve-release', 'deploy-infra', 'deploy-backend'],
  )) {
    errors.push('cd-backend.yml: OIDC-capable job set must remain exact');
  }
  const azureLogins = stepsUsing(jobs, actions.azureLogin);
  if (
    !exactArray(azureLogins.map(({ jobId }) => jobId), azureJobs)
    || azureLogins.some(({ step }) => !exactObject(step.with, {
      'client-id': '${{ secrets.AZURE_CLIENT_ID }}',
      'subscription-id': '${{ secrets.AZURE_SUBSCRIPTION_ID }}',
      'tenant-id': '${{ secrets.AZURE_TENANT_ID }}',
    }))
  ) {
    errors.push('cd-backend.yml: Azure login jobs and inputs must remain exact');
  }
  for (const jobId of azureJobs) {
    const ancestors = ancestorJobs(jobs, jobId, errors);
    for (const gate of ['validate-target', 'validate-public-domain']) {
      if (!ancestors.has(gate)) {
        errors.push(`cd-backend.yml: ${jobId} must transitively need ${gate}`);
      }
    }
  }
  const deployBackend = jobs['deploy-backend'];
  const finalManifestVerification = (deployBackend?.steps ?? [])
    .find((step) => step?.name === 'Reverify release before deployment');
  if (
    !exactObject(deployBackend?.env, expectedDeployEnvironment)
    || typeof finalManifestVerification?.run !== 'string'
    || !normalized(finalManifestVerification.run).includes(
      '--expected-workflow-sha "$EXPECTED_WORKFLOW_SHA"',
    )
    || !normalized(finalManifestVerification.run).includes(
      '--expected-run-attempt "$EXPECTED_RUN_ATTEMPT"',
    )
  ) {
    errors.push(
      'cd-backend.yml: deploy-backend must reverify the exact trusted workflow SHA and run attempt',
    );
  }
  return errors;
}

function regularFile(root, relativePath, label) {
  const declared = path.resolve(root, ...relativePath.split('/'));
  let rootReal;
  let stats;
  let real;
  try {
    rootReal = fs.realpathSync(root);
    stats = fs.lstatSync(declared);
    real = fs.realpathSync(declared);
  } catch (error) {
    return { error: `${label}: missing ${relativePath} (${error.message})` };
  }
  const relation = path.relative(rootReal, real);
  if (
    stats.isSymbolicLink()
    || !stats.isFile()
    || relation === '..'
    || relation.startsWith(`..${path.sep}`)
    || path.isAbsolute(relation)
  ) {
    return { error: `${label}: ${relativePath} must be a contained regular non-symlink file` };
  }
  return { path: real };
}

function revisionLocalTree(root, relativeRoot, label, errors) {
  const treeRoot = path.resolve(root, ...relativeRoot.split('/'));
  const files = new Map();
  let rootReal;
  try {
    rootReal = fs.realpathSync(root);
  } catch (error) {
    errors.push(`${label}: cannot resolve root (${error.message})`);
    return files;
  }

  function visit(current) {
    let entries;
    try {
      entries = fs.readdirSync(current, { withFileTypes: true });
    } catch (error) {
      errors.push(`${label}: missing ${relativeRoot} (${error.message})`);
      return;
    }
    for (const entry of entries) {
      const declared = path.join(current, entry.name);
      let stats;
      let real;
      try {
        stats = fs.lstatSync(declared);
        real = fs.realpathSync(declared);
      } catch (error) {
        errors.push(`${label}: cannot inspect ${declared} (${error.message})`);
        continue;
      }
      const relation = path.relative(rootReal, real);
      if (
        stats.isSymbolicLink()
        || relation === '..'
        || relation.startsWith(`..${path.sep}`)
        || path.isAbsolute(relation)
      ) {
        errors.push(`${label}: ${declared} must remain inside a non-symlink tree`);
        continue;
      }
      if (stats.isDirectory()) {
        visit(declared);
      } else if (stats.isFile()) {
        files.set(path.relative(root, declared).split(path.sep).join('/'), fs.readFileSync(declared));
      } else {
        errors.push(`${label}: ${declared} must be a regular file or directory`);
      }
    }
  }

  visit(treeRoot);
  return files;
}

function validateRevisionLocalPrivilegedInputs(candidateRoot, trustedRoot) {
  const errors = [];
  for (const relativePath of revisionLocalPrivilegedInputs) {
    const candidate = regularFile(candidateRoot, relativePath, 'candidate privileged input');
    const trusted = regularFile(trustedRoot, relativePath, 'revision-local privileged input');
    if (candidate.error) {
      errors.push(candidate.error);
      continue;
    }
    if (trusted.error) {
      errors.push(trusted.error);
      continue;
    }
    if (!fs.readFileSync(candidate.path).equals(fs.readFileSync(trusted.path))) {
      errors.push(
        `candidate privileged input: ${relativePath} must match the immutable base revision`,
      );
    }
  }
  for (const relativeRoot of revisionLocalPrivilegedTrees) {
    const candidate = revisionLocalTree(
      candidateRoot,
      relativeRoot,
      'candidate privileged tree',
      errors,
    );
    const trusted = revisionLocalTree(
      trustedRoot,
      relativeRoot,
      'revision-local privileged tree',
      errors,
    );
    const paths = new Set([...candidate.keys(), ...trusted.keys()]);
    for (const relativePath of paths) {
      if (!candidate.get(relativePath)?.equals(trusted.get(relativePath))) {
        errors.push(
          `candidate privileged input: ${relativePath} must match the immutable base revision`,
        );
      }
    }
  }
  return errors;
}

function hasWritePermission(value) {
  return typeof value === 'string' && value.toLowerCase() === 'write-all'
    || (
      value
      && typeof value === 'object'
      && !Array.isArray(value)
      && Object.values(value).some(
        (permission) => typeof permission === 'string' && permission.toLowerCase() === 'write',
      )
    );
}

function containsScalar(value, marker) {
  if (typeof value === 'string') {
    return value.toLowerCase().includes(marker.toLowerCase());
  }
  if (Array.isArray(value)) {
    return value.some((entry) => containsScalar(entry, marker));
  }
  if (value && typeof value === 'object') {
    return Object.values(value).some((entry) => containsScalar(entry, marker));
  }
  return false;
}

function privilegedWorkflow(workflow) {
  return hasWritePermission(workflow?.permissions)
    || Object.values(workflow?.jobs ?? {}).some((job) => (
      hasWritePermission(job?.permissions)
      || Object.entries(job?.permissions ?? {}).some(
        ([name, value]) => name.toLowerCase() === 'id-token'
          && typeof value === 'string'
          && value.toLowerCase() === 'write',
      )
      || job?.environment !== undefined
      || job?.secrets !== undefined
    ))
    || [
      'azure/login@',
      'secrets.',
      'secrets[',
      'core.getidtoken',
      'connect-azaccount',
      'invoke-az',
      'management.azure.com',
      '.azurewebsites.net',
      'az deployment',
      'az functionapp',
      'az resource',
      'az storage',
      'transfer-backend-release.sh',
      'deploy-flex-onedeploy.sh',
      'write-secure-bicep-parameters.mjs',
      'backend/src/Certigo.Api',
      'backend\\src\\Certigo.Api',
    ].some((marker) => containsScalar(workflow, marker));
}

function validateNoncanonicalWorkflows(candidateRoot, trustedRoot) {
  const errors = [];
  const directory = path.join(candidateRoot, '.github', 'workflows');
  let entries;
  try {
    entries = fs.readdirSync(directory, { withFileTypes: true });
  } catch (error) {
    return [`candidate workflows: cannot enumerate .github/workflows (${error.message})`];
  }
  for (const entry of entries) {
    if (!/\.ya?ml$/u.test(entry.name) || entry.name === 'cd-backend.yml') {
      continue;
    }
    const relativePath = `.github/workflows/${entry.name}`;
    const candidate = regularFile(candidateRoot, relativePath, 'candidate workflow');
    if (candidate.error) {
      errors.push(candidate.error);
      continue;
    }
    const trusted = regularFile(trustedRoot, relativePath, 'revision-local workflow');
    if (!trusted.error && fs.readFileSync(candidate.path).equals(fs.readFileSync(trusted.path))) {
      continue;
    }
    const parsed = parseWorkflow(fs.readFileSync(candidate.path, 'utf8'), relativePath);
    if (parsed.error) {
      errors.push(parsed.error);
    } else if (privilegedWorkflow(parsed.workflow)) {
      errors.push(
        `${relativePath}: changed or new privileged capability is forbidden outside cd-backend.yml`,
      );
    }
  }
  return errors;
}

export function validateBackendDeployWorkspace(candidateRoot, trustedRoot) {
  const errors = [];
  for (const relativePath of backendDeployTrustedFiles) {
    const candidate = regularFile(candidateRoot, relativePath, 'candidate trusted control');
    const trusted = regularFile(trustedRoot, relativePath, 'revision-local trusted control');
    if (candidate.error) {
      errors.push(candidate.error);
      continue;
    }
    if (trusted.error) {
      errors.push(trusted.error);
      continue;
    }
    if (!fs.readFileSync(candidate.path).equals(fs.readFileSync(trusted.path))) {
      errors.push(
        `candidate trusted control: ${relativePath} must match the immutable base revision`,
      );
    }
  }

  const candidateWorkflow = regularFile(candidateRoot, workflowPath, 'candidate workflow');
  const trustedWorkflow = regularFile(trustedRoot, workflowPath, 'revision-local workflow');
  if (candidateWorkflow.error) {
    errors.push(candidateWorkflow.error);
  }
  if (trustedWorkflow.error) {
    errors.push(trustedWorkflow.error);
  }
  if (!candidateWorkflow.error && !trustedWorkflow.error) {
    const candidateBytes = fs.readFileSync(candidateWorkflow.path);
    const trustedBytes = fs.readFileSync(trustedWorkflow.path);
    const bytes = candidateBytes;
    const isLegacy = bytes.length === legacyWorkflowSize
      && sha256(bytes) === legacyWorkflowSha256
      && candidateBytes.equals(trustedBytes);
    const isHardenedLegacy = bytes.length === hardenedLegacyWorkflowSize
      && sha256(bytes) === hardenedLegacyWorkflowSha256
      && candidateBytes.equals(trustedBytes);
    let controls;
    if (!isLegacy && !isHardenedLegacy) {
      errors.push(...validateRevisionLocalPrivilegedInputs(candidateRoot, trustedRoot));
      controls = new Map();
      for (const relativePath of supportingControls.keys()) {
        const file = regularFile(
          candidateRoot,
          relativePath,
          'candidate supporting control',
        );
        if (file.error) {
          errors.push(file.error);
        } else {
          controls.set(relativePath, fs.readFileSync(file.path));
        }
      }
      const capacityDocument = regularFile(
        candidateRoot,
        capacityDocumentPath,
        'candidate capacity contract',
      );
      if (capacityDocument.error) {
        errors.push(capacityDocument.error);
      } else {
        controls.set(capacityDocumentPath, fs.readFileSync(capacityDocument.path));
      }
    }
    errors.push(
      ...validateBackendDeployWorkflow(
        candidateBytes,
        trustedBytes,
        controls,
      ),
    );
  }
  errors.push(...validateNoncanonicalWorkflows(candidateRoot, trustedRoot));
  return errors;
}
