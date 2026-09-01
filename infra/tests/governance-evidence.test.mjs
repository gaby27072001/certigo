import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  validateDeploymentParameters,
  validateExistingPhaseBAssignments,
  validatePhaseAOperations,
  validatePhaseBTransition,
  validatePriorDeployment,
  verifyManifestFiles,
  verifyDeploymentApproval,
} from
  '../governance/validate-evidence.mjs';
import { createManifest, sha256File } from
  '../governance/write-what-if-manifest.mjs';
import { normalizePrincipalTypes } from
  '../governance/normalize-principal-types.mjs';
import {
  armGuid,
  contentPlanCondition,
  runtimeWriterCondition,
  validatePhaseAResource,
  validateWhatIf,
} from '../governance/validate-what-if.mjs';

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
  '..',
);
const subscription = '00000000-0000-0000-0000-000000000001';
const tenant = '00000000-0000-0000-0000-000000000002';

function tempDirectory() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-governance-evidence-'));
}

function writeJson(directory, name, value) {
  const file = path.join(directory, name);
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
  return file;
}

function compileTemplate(relativePath, outputPath) {
  execFileSync(
    process.env.BICEP_CLI || 'bicep',
    ['build', path.join(repositoryRoot, relativePath), '--outfile', outputPath],
  );
}

function makePhaseAProof() {
  const identity = (name, suffix, extra = {}) => ({
    clientId: `10000000-0000-0000-0000-0000000000${suffix}`,
    name,
    principalId: `20000000-0000-0000-0000-0000000000${suffix}`,
    resourceId:
      `/subscriptions/${subscription}/resourceGroups/rg-certigo-identities/` +
      `providers/Microsoft.ManagedIdentity/userAssignedIdentities/${name}`,
    ...extra,
  });
  const role = (seed) =>
    `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
    `roleDefinitions/${armGuid(`/subscriptions/${subscription}`, seed)}`;
  return {
    schemaVersion: 2,
    subscriptionId: subscription,
    tenantId: tenant,
    contentResourceGroupId:
      `/subscriptions/${subscription}/resourceGroups/rg-certigo-content`,
    identityResourceGroupId:
      `/subscriptions/${subscription}/resourceGroups/rg-certigo-identities`,
    identities: {
      contentAnswerKey: identity('id-certigo-content-answer-key', '01'),
      contentInfrastructurePlan: identity(
        'id-certigo-content-infra-plan',
        '02',
        {
          federatedSubject:
            'repo:gchambaud_microsoft/Certigo:environment:azure-content-infra-plan',
        },
      ),
      contentPublic: identity('id-certigo-content-public', '03'),
      contentReader: identity('id-certigo-content-reader', '04'),
      contentRelease: identity('id-certigo-content-release', '05'),
      deployDev: identity('id-certigo-deploy-dev', '06'),
      deployProd: identity('id-certigo-deploy-prod', '07'),
      deployStaging: identity('id-certigo-deploy-staging', '08'),
    },
    policyDefinitionId: role('certigo-privileged-ci-role-assignments').replace(
      '/roleDefinitions/',
      '/policyDefinitions/',
    ),
    roleDefinitionIds: {
      contentInfrastructurePlanExecutor: role(
        'certigo-content-infrastructure-plan-executor',
      ),
      contentInfrastructurePlanExternalJoin: role(
        'certigo-content-infrastructure-plan-external-join',
      ),
      contentPublisher:
        `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
        'roleDefinitions/c8a9d1bb-39d7-4f4f-9a4c-17b4c81aa5de',
      runtimeRoleAssignmentWriter: role(
        'certigo-runtime-role-assignment-writer',
      ),
      sharedNetworkDeployment: role('certigo-shared-network-deployment'),
      subscriptionDeploymentLauncher: role(
        'certigo-subscription-deployment-launcher',
      ),
    },
  };
}

function makeB1Plan(proof) {
  const changes = [];
  const contributor =
    `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
    'roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c';
  const add = (scope, seed, properties) => {
    changes.push({
      changeType: 'Create',
      resourceId:
        `${scope}/providers/Microsoft.Authorization/roleAssignments/` +
        armGuid(scope, seed, properties.roleDefinitionId),
      after: {
        type: 'Microsoft.Authorization/roleAssignments',
        properties,
      },
    });
  };
  for (const environment of ['dev', 'staging', 'prod']) {
    const key = `deploy${environment[0].toUpperCase()}${environment.slice(1)}`;
    const identity = proof.identities[key];
    add(`/subscriptions/${subscription}`, identity.name, {
      description:
        `Launches the ${environment} subscription deployment without general ` +
        'subscription access.',
      principalId: identity.principalId,
      principalType: 'ServicePrincipal',
      roleDefinitionId: proof.roleDefinitionIds.subscriptionDeploymentLauncher,
    });
    add(
      `/subscriptions/${subscription}/resourceGroups/rg-certigo-${environment}`,
      identity.name,
      {
        description:
          'Certigo environment deployment; no role-assignment administration.',
        principalId: identity.principalId,
        principalType: 'ServicePrincipal',
        roleDefinitionId: contributor,
      },
    );
    add(
      `/subscriptions/${subscription}/resourceGroups/rg-certigo-${environment}`,
      identity.name,
      {
        condition: runtimeWriterCondition(),
        conditionVersion: '2.0',
        description:
          'May create only approved runtime roles for service principals in this environment.',
        principalId: identity.principalId,
        principalType: 'ServicePrincipal',
        roleDefinitionId: proof.roleDefinitionIds.runtimeRoleAssignmentWriter,
      },
    );
    add(
      `/subscriptions/${subscription}/resourceGroups/rg-certigo-ci`,
      identity.name,
      {
        description:
          `Allows ${environment} to reconcile only shared DNS links and VNet peerings.`,
        principalId: identity.principalId,
        principalType: 'ServicePrincipal',
        roleDefinitionId: proof.roleDefinitionIds.sharedNetworkDeployment,
      },
    );
  }

  add(
    `/subscriptions/${subscription}/resourceGroups/rg-certigo-content`,
    proof.identities.contentInfrastructurePlan.name,
    {
      condition: contentPlanCondition(proof),
      conditionVersion: '2.0',
      description:
        'Plans the content stack and may assign only approved content roles to service principals.',
      principalId: proof.identities.contentInfrastructurePlan.principalId,
      principalType: 'ServicePrincipal',
      roleDefinitionId:
        proof.roleDefinitionIds.contentInfrastructurePlanExecutor,
    },
  );
  changes.push({
    changeType: 'Create',
    resourceId:
      `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
      'policyAssignments/certigo-privileged-ci-rbac',
    after: {
      properties: {
        enforcementMode: 'Default',
        parameters: { effect: { value: 'Audit' } },
        policyDefinitionId: proof.policyDefinitionId,
      },
    },
  });
  return {
    changes: changes.filter(
      (change) =>
        !change.resourceId.includes('/policyAssignments/') &&
        !change.after?.properties?.description?.startsWith('Launches the ') &&
        ![
          proof.roleDefinitionIds.runtimeRoleAssignmentWriter,
          proof.roleDefinitionIds.contentInfrastructurePlanExecutor,
        ].includes(change.after?.properties?.roleDefinitionId),
    ),
    diagnostics: null,
    error: null,
    potentialChanges: null,
    status: 'Succeeded',
  };
}

function compiledB1PrincipalTypes(principalType = 'ServicePrincipal') {
  return {
    resources: [
      {
        type: 'Microsoft.Resources/deployments',
        properties: {
          template: {
            resources: [
              {
                type: 'Microsoft.Authorization/roleAssignments',
                properties: {
                  description:
                    'Certigo environment deployment; no role-assignment administration.',
                  principalType,
                },
              },
              {
                type: 'Microsoft.Authorization/roleAssignments',
                properties: {
                  description:
                    'May create only approved runtime roles for service principals in this environment.',
                  principalType,
                },
              },
              {
                type: 'Microsoft.Authorization/roleAssignments',
                properties: {
                  description: "[parameters('assignmentDescription')]",
                  principalType,
                },
              },
              {
                type: 'Microsoft.Authorization/roleAssignments',
                properties: {
                  description:
                    'Plans the content stack and may assign only approved content roles to service principals.',
                  principalType,
                },
              },
            ],
          },
        },
      },
    ],
  };
}

function makeB1Evidence() {
  const directory = tempDirectory();
  const proof = makePhaseAProof();
  const planPath = writeJson(directory, 'plan.json', makeB1Plan(proof));
  const parametersPath = writeJson(directory, 'parameters.json', {
    parameters: { phaseA: { value: proof } },
  });
  const compiledTemplatePath = path.join(directory, 'compiled-template.json');
  compileTemplate(
    'infra/governance/bootstrap-rbac.bicep',
    compiledTemplatePath,
  );
  const manifestPath = path.join(directory, 'manifest.json');
  const sourceCommit = execFileSync('git', ['rev-parse', 'HEAD'], {
    cwd: repositoryRoot,
    encoding: 'utf8',
  }).trim();
  createManifest({
    phase: 'B1a',
    planPath,
    outputPath: manifestPath,
    templatePath: path.join(
      repositoryRoot,
      'infra/governance/bootstrap-rbac.bicep',
    ),
    compiledTemplatePath,
    parametersPath,
    sourceRoot: repositoryRoot,
    sourceCommit,
    subscriptionId: subscription,
    tenantId: tenant,
    sourceFiles: [
      path.join(repositoryRoot, 'infra/governance/bootstrap-rbac.bicep'),
    ],
    artifactDirectory: directory,
  });
  return {
    directory,
    proof,
    planPath,
    parametersPath,
    compiledTemplatePath,
    manifestPath,
    manifest: JSON.parse(fs.readFileSync(manifestPath, 'utf8')),
    sourceCommit,
  };
}

test('deployment approval rejects missing, tampered, and wrong-commit evidence', () => {
  const evidence = makeB1Evidence();
  const phaseABindingPath = writeJson(evidence.directory, 'phase-a-binding.json', {
    schemaVersion: 1,
  });
  const approval = {
    schemaVersion: 1,
    approved: true,
    phase: 'B1a',
    manifestSha256: sha256File(evidence.manifestPath),
    planSha256: evidence.manifest.plan.sha256,
    sourceCommit: evidence.sourceCommit,
    phaseAEvidenceManifestSha256: 'a'.repeat(64),
  };
  evidence.manifest.phaseA = {
    evidenceManifestSha256: 'a'.repeat(64),
    bindingSha256: sha256File(phaseABindingPath),
  };
  evidence.manifest.artifacts.push({
    path: 'phase-a-binding.json',
    sha256: sha256File(phaseABindingPath),
  });
  evidence.manifest.artifacts.sort((left, right) =>
    left.path.localeCompare(right.path),
  );
  fs.writeFileSync(
    evidence.manifestPath,
    `${JSON.stringify(evidence.manifest, null, 2)}\n`,
  );
  approval.manifestSha256 = sha256File(evidence.manifestPath);
  assert.doesNotThrow(() =>
    verifyDeploymentApproval({
      approval,
      manifest: evidence.manifest,
      phaseAProof: evidence.proof,
      manifestPath: evidence.manifestPath,
      planPath: evidence.planPath,
      parametersPath: evidence.parametersPath,
      compiledTemplatePath: evidence.compiledTemplatePath,
      phaseABindingPath,
      sourceRoot: repositoryRoot,
      subscriptionId: subscription,
      tenantId: tenant,
    }),
  );
  assert.throws(
    () =>
      verifyDeploymentApproval({
        approval: { ...approval, sourceCommit: 'f'.repeat(40) },
        manifest: evidence.manifest,
        phaseAProof: evidence.proof,
        manifestPath: evidence.manifestPath,
        planPath: evidence.planPath,
        parametersPath: evidence.parametersPath,
        compiledTemplatePath: evidence.compiledTemplatePath,
        phaseABindingPath,
        sourceRoot: repositoryRoot,
        subscriptionId: subscription,
        tenantId: tenant,
      }),
    /approved source commit mismatch/,
  );
  fs.appendFileSync(evidence.planPath, '\n');
  assert.throws(
    () =>
      verifyDeploymentApproval({
        approval,
        manifest: evidence.manifest,
        phaseAProof: evidence.proof,
        manifestPath: evidence.manifestPath,
        planPath: evidence.planPath,
        parametersPath: evidence.parametersPath,
        compiledTemplatePath: evidence.compiledTemplatePath,
        phaseABindingPath,
        sourceRoot: repositoryRoot,
        subscriptionId: subscription,
        tenantId: tenant,
      }),
    /artifact inventory mismatch|raw plan hash mismatch/,
  );
  assert.throws(
    () => fs.readFileSync(path.join(evidence.directory, 'missing.json')),
    /ENOENT/,
  );
});

test('Phase A binding rejects extra and out-of-contract assignments', () => {
  const evidence = makeB1Evidence();
  const extra = makeB1Plan(evidence.proof).changes[0];
  assert.deepEqual(
    validateExistingPhaseBAssignments(
      [
        {
          id: extra.resourceId,
          name: extra.resourceId.split('/').at(-1),
          scope: `/subscriptions/${subscription}`,
          ...extra.after.properties,
        },
      ],
      [],
      subscription,
      evidence.proof,
    ),
    [
      `role-assignment:/subscriptions/${subscription}/resourcegroups/` +
        'rg-certigo-dev:Certigo environment deployment; ' +
        'no role-assignment administration.',
    ],
  );
  extra.after.properties.principalId =
    '90000000-0000-0000-0000-000000000001';
  assert.throws(
    () =>
      validateExistingPhaseBAssignments(
        [
          {
            id: extra.resourceId,
            name: extra.resourceId.split('/').at(-1),
            scope: `/subscriptions/${subscription}`,
            ...extra.after.properties,
          },
        ],
        [],
        subscription,
        evidence.proof,
      ),
    /live resource violates/,
  );
});

test('Phase A operation binding rejects missing and assignment operations', () => {
  const resourceId =
    `/subscriptions/${subscription}/resourceGroups/rg-certigo-content`;
  const plan = { changes: [{ resourceId }] };
  const operation = (id) => ({
    operationId: 'operation',
    properties: {
      provisioningState: 'Succeeded',
      targetResource: { id },
    },
  });
  assert.throws(
    () => validatePhaseAOperations(plan, [], subscription),
    /operation evidence is incomplete/,
  );
  assert.throws(
    () =>
      validatePhaseAOperations(
        plan,
        [
          operation(resourceId),
          operation(
            `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
              'roleAssignments/90000000-0000-0000-0000-000000000001',
          ),
        ],
        subscription,
      ),
    /created an assignment/,
  );
});

test('deployment parameters, locations, and B1 transition are exact', () => {
    assert.doesNotThrow(() =>
      validateDeploymentParameters(
        { properties: { parameters: { location: { value: 'westeurope' } } } },
        { parameters: { location: { value: 'westeurope' } } },
      ),
    );
    assert.throws(
      () =>
        validateDeploymentParameters(
          { properties: { parameters: { location: { value: 'eastus' } } } },
          { parameters: { location: { value: 'westeurope' } } },
        ),
      /deployment parameter mismatch/,
    );
    const proof = makePhaseAProof();
    const identity = proof.identities.deployDev;
    assert.throws(
      () =>
        validatePhaseAResource(
          {
            id: identity.resourceId,
            name: identity.name,
            type: 'Microsoft.ManagedIdentity/userAssignedIdentities',
            location: 'eastus',
            properties: {
              clientId: identity.clientId,
              principalId: identity.principalId,
            },
          },
          subscription,
        ),
      /live resource violates/,
    );
    assert.throws(
      () => validatePhaseBTransition([], subscription, proof, 'B2'),
      /B1a transition is incomplete/,
    );
});

test('live Phase B binding classifies delegator roles as human B1b', () => {
  const proof = makePhaseAProof();
  const all = makeB1Plan(proof).changes;
  const delegators = [];
  for (const environment of ['dev', 'staging', 'prod']) {
    const key = `deploy${environment[0].toUpperCase()}${environment.slice(1)}`;
    const identity = proof.identities[key];
    const scope =
      `/subscriptions/${subscription}/resourceGroups/rg-certigo-${environment}`;
    delegators.push({
      id:
        `${scope}/providers/Microsoft.Authorization/roleAssignments/` +
        armGuid(
          scope,
          identity.name,
          proof.roleDefinitionIds.runtimeRoleAssignmentWriter,
        ),
      name: 'runtime-writer',
      scope,
      condition: runtimeWriterCondition(),
      conditionVersion: '2.0',
      description:
        'May create only approved runtime roles for service principals in this environment.',
      principalId: identity.principalId,
      principalType: 'ServicePrincipal',
      roleDefinitionId: proof.roleDefinitionIds.runtimeRoleAssignmentWriter,
    });
  }
  const contentScope =
    `/subscriptions/${subscription}/resourceGroups/rg-certigo-content`;
  delegators.push({
    id:
      `${contentScope}/providers/Microsoft.Authorization/roleAssignments/` +
      armGuid(
        contentScope,
        proof.identities.contentInfrastructurePlan.name,
        proof.roleDefinitionIds.contentInfrastructurePlanExecutor,
      ),
    name: 'content-executor',
    scope: contentScope,
    condition: contentPlanCondition(proof),
    conditionVersion: '2.0',
    description:
      'Plans the content stack and may assign only approved content roles to service principals.',
    principalId: proof.identities.contentInfrastructurePlan.principalId,
    principalType: 'ServicePrincipal',
    roleDefinitionId: proof.roleDefinitionIds.contentInfrastructurePlanExecutor,
  });
  const managedIdentityOperatorRoleId =
    `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
    'roleDefinitions/f1a07417-d97a-45cb-824c-7a7467783830';
  for (const environment of ['dev', 'staging', 'prod']) {
    const key = `deploy${environment[0].toUpperCase()}${environment.slice(1)}`;
    const identity = proof.identities[key];
    const scope = proof.identities.contentReader.resourceId;
    delegators.push({
      id:
        `${scope}/providers/Microsoft.Authorization/roleAssignments/` +
        armGuid(scope, identity.name, managedIdentityOperatorRoleId),
      name: `reader-attach-${environment}`,
      scope,
      condition: null,
      conditionVersion: null,
      description:
        `Allows ${environment} deployment to attach only the immutable content reader identity.`,
      principalId: identity.principalId,
      principalType: 'ServicePrincipal',
      roleDefinitionId: managedIdentityOperatorRoleId,
    });
  }
  const b1a = all.map((change) => ({
    id: change.resourceId,
    name: change.resourceId.split('/').at(-1),
    scope: change.resourceId.split('/providers/Microsoft.Authorization/')[0],
    ...change.after.properties,
  }));
  assert.doesNotThrow(() =>
    validateExistingPhaseBAssignments(
      [...b1a, ...delegators],
      [],
      subscription,
      proof,
    ),
  );
});

test('omitted principalType requires compiled literal and live Phase A UAMI', () => {
  const proof = makePhaseAProof();
  const raw = makeB1Plan(proof);
  for (const change of raw.changes) {
    if (change.after?.type === 'Microsoft.Authorization/roleAssignments') {
      change.after.properties.principalType = null;
    }
  }
  const normalized = normalizePrincipalTypes(
    raw,
    compiledB1PrincipalTypes(),
    proof,
  );
  assert.equal(normalized.provenance.normalizedCount, 6);
  assert.ok(
    normalized.provenance.entries.every(
      ({ effectivePrincipalType, provenance }) =>
        effectivePrincipalType === 'ServicePrincipal' &&
        provenance === 'compiled-template+live-uami',
    ),
  );
  assert.equal(
    validateWhatIf(normalized.plan, subscription, {
      phase: 'B1a',
      phaseA: proof,
    }).total,
    6,
  );

  for (const compiled of [
    { resources: [] },
    compiledB1PrincipalTypes("[parameters('principalType')]"),
  ]) {
    assert.throws(
      () => normalizePrincipalTypes(raw, compiled, proof),
      /compiled assignment declaration is missing|not literal ServicePrincipal/,
    );
  }
  const nonUami = structuredClone(raw);
  nonUami.changes.find(
    ({ after }) => after?.type === 'Microsoft.Authorization/roleAssignments',
  ).after.properties.principalId =
    '90000000-0000-0000-0000-000000000001';
  assert.throws(
    () =>
      normalizePrincipalTypes(nonUami, compiledB1PrincipalTypes(), proof),
    /does not match a Phase A UAMI/,
  );
  for (const principalType of ['User', 'Group']) {
    const wrongType = structuredClone(raw);
    wrongType.changes.find(
      ({ after }) => after?.type === 'Microsoft.Authorization/roleAssignments',
    ).after.properties.principalType = principalType;
    assert.throws(
      () =>
        validateWhatIf(wrongType, subscription, {
          phase: 'B1a',
          phaseA: proof,
        }),
      /outside the exact Phase B1a contract/,
    );
  }
});

test('deployment approval recomputes normalized principalType evidence', () => {
  const evidence = makeB1Evidence();
  const rawPlan = JSON.parse(fs.readFileSync(evidence.planPath, 'utf8'));
  for (const change of rawPlan.changes) {
    if (change.after?.type === 'Microsoft.Authorization/roleAssignments') {
      change.after.properties.principalType = null;
    }
  }
  fs.writeFileSync(evidence.planPath, `${JSON.stringify(rawPlan)}\n`);
  const compiled = JSON.parse(
    fs.readFileSync(evidence.compiledTemplatePath, 'utf8'),
  );
  const normalized = normalizePrincipalTypes(rawPlan, compiled, evidence.proof);
  const normalizedPlanPath = writeJson(
    evidence.directory,
    'normalized-plan.json',
    normalized.plan,
  );
  const provenancePath = writeJson(
    evidence.directory,
    'principal-type-provenance.json',
    normalized.provenance,
  );
  const bindingPath = writeJson(evidence.directory, 'phase-a-binding.json', {
    schemaVersion: 1,
  });
  evidence.manifest.plan.sha256 = sha256File(evidence.planPath);
  evidence.manifest.normalization = {
    normalizedPlanSha256: sha256File(normalizedPlanPath),
    provenanceSha256: sha256File(provenancePath),
    effectivePrincipalType: 'ServicePrincipal',
    provenance: 'compiled-template+live-uami',
    normalizedCount: 6,
  };
  evidence.manifest.phaseA = {
    evidenceManifestSha256: 'a'.repeat(64),
    bindingSha256: sha256File(bindingPath),
  };
  evidence.manifest.artifacts = [
    evidence.compiledTemplatePath,
    evidence.parametersPath,
    bindingPath,
    normalizedPlanPath,
    evidence.planPath,
    provenancePath,
  ]
    .map((file) => ({
      path: path.basename(file),
      sha256: sha256File(file),
    }))
    .sort((left, right) => left.path.localeCompare(right.path));
  fs.writeFileSync(
    evidence.manifestPath,
    `${JSON.stringify(evidence.manifest, null, 2)}\n`,
  );
  const approval = {
    schemaVersion: 1,
    approved: true,
    phase: 'B1a',
    manifestSha256: sha256File(evidence.manifestPath),
    planSha256: evidence.manifest.plan.sha256,
    sourceCommit: evidence.sourceCommit,
    phaseAEvidenceManifestSha256: 'a'.repeat(64),
  };
  const verify = () =>
    verifyDeploymentApproval({
      approval,
      manifest: evidence.manifest,
      phaseAProof: evidence.proof,
      phaseABindingPath: bindingPath,
      manifestPath: evidence.manifestPath,
      planPath: evidence.planPath,
      parametersPath: evidence.parametersPath,
      compiledTemplatePath: evidence.compiledTemplatePath,
      sourceRoot: repositoryRoot,
      subscriptionId: subscription,
      tenantId: tenant,
    });
  assert.doesNotThrow(verify);
  const approvedParameters = JSON.parse(
    fs.readFileSync(evidence.parametersPath, 'utf8'),
  );
  assert.doesNotThrow(() =>
    validatePriorDeployment({
      manifest: evidence.manifest,
      plan: rawPlan,
      deployment: {
        properties: {
          provisioningState: 'Succeeded',
          templateHash: evidence.manifest.template.armTemplateHash,
          parameters: approvedParameters.parameters,
        },
      },
      approvedParameters,
      manifestPath: evidence.manifestPath,
      planPath: evidence.planPath,
      parametersPath: evidence.parametersPath,
      compiledTemplatePath: evidence.compiledTemplatePath,
      sourceRoot: repositoryRoot,
      expectedManifestSha256: sha256File(evidence.manifestPath),
      phaseAProof: evidence.proof,
      expectedPhase: 'B1a',
    }),
  );
  fs.appendFileSync(provenancePath, '\n');
  assert.throws(
    verify,
    /artifact inventory mismatch|principalType provenance mismatch/,
  );
  assert.throws(
    () =>
      validatePriorDeployment({
        manifest: evidence.manifest,
        plan: rawPlan,
        deployment: {},
        approvedParameters,
        manifestPath: evidence.manifestPath,
        planPath: evidence.planPath,
        parametersPath: evidence.parametersPath,
        compiledTemplatePath: evidence.compiledTemplatePath,
        sourceRoot: repositoryRoot,
        expectedManifestSha256: sha256File(evidence.manifestPath),
        phaseAProof: evidence.proof,
        expectedPhase: 'B1a',
      }),
    /artifact inventory mismatch|principalType provenance mismatch/,
  );
});

test('manifest verification rejects omitted and renamed artifacts', () => {
    const evidence = makeB1Evidence();
    const options = {
      manifestPath: evidence.manifestPath,
      planPath: evidence.planPath,
      parametersPath: evidence.parametersPath,
      compiledTemplatePath: evidence.compiledTemplatePath,
      sourceRoot: repositoryRoot,
    };
    assert.doesNotThrow(() => verifyManifestFiles(evidence.manifest, options));
    fs.renameSync(
      evidence.parametersPath,
      path.join(evidence.directory, 'renamed-parameters.json'),
    );
    assert.throws(
      () => verifyManifestFiles(evidence.manifest, options),
      /artifact inventory mismatch/,
    );
});

test('governance workflows persist evidence and deploy tools require approvals', () => {
  const phaseAWorkflow = fs.readFileSync(
    path.join(
      repositoryRoot,
      '.github/workflows/governance-bootstrap-phase-a-what-if.yml',
    ),
    'utf8',
  );
  const phaseBWorkflow = fs.readFileSync(
    path.join(
      repositoryRoot,
      '.github/workflows/governance-bootstrap-phase-b-what-if.yml',
    ),
    'utf8',
  );
  assert.match(phaseAWorkflow, /governance-phase-a-evidence/);
  assert.match(
    phaseAWorkflow,
    /Upload immutable Phase A evidence\s+if: \$\{\{ always\(\) \}\}/,
  );
  assert.match(phaseBWorkflow, /phase_a_evidence_manifest_sha256/);
  assert.match(phaseBWorkflow, /governance-phase-b1-evidence/);
  assert.match(phaseBWorkflow, /PHASE_B1_EVIDENCE_DIR/);
  assert.match(phaseBWorkflow, /what-if-phase-b1\.sh/);
  assert.doesNotMatch(phaseBWorkflow, /PHASE_B_EVIDENCE_DIR/);
  assert.equal(
    fs.existsSync(
      path.join(
        repositoryRoot,
        '.github/workflows/governance-bootstrap-phase-b2-what-if.yml',
      ),
    ),
    false,
  );
  const orchestrator = fs.readFileSync(
    path.join(repositoryRoot, 'infra/governance/what-if-phase-b.sh'),
    'utf8',
  );
  assert.match(orchestrator, /what-if-phase-b1\.sh/);
  assert.doesNotMatch(orchestrator, /what-if-phase-b2\.sh/);
  for (const script of ['what-if-phase-a.sh', 'what-if-phase-b1.sh', 'what-if-phase-b2.sh']) {
    const source = fs.readFileSync(
      path.join(repositoryRoot, 'infra/governance', script),
      'utf8',
    );
    assert.match(source, /trap finalize EXIT/);
    assert.match(source, /what-if-exit-code\.txt/);
    assert.ok(
      source.indexOf('metadata.json') <
        source.indexOf('write-what-if-manifest.mjs'),
    );
    assert.match(source, /--artifact-dir/);
  }
  for (const script of ['deploy-phase-b1.sh', 'deploy-phase-b2.sh']) {
    const source = fs.readFileSync(
      path.join(repositoryRoot, 'infra/governance', script),
      'utf8',
    );
    assert.match(source, /validate-evidence\.mjs" deployment-approval/);
    assert.ok(
      source.indexOf('deployment-approval') < source.lastIndexOf('az deployment '),
    );
    assert.match(source, /APPROVAL_FILE/);
    assert.match(source, /fresh-compiled-template\.json/);
    assert.match(source, /template\.compiledSha256/);
    assert.match(source, /parameters\.sha256/);
    assert.match(source, /--template-file "\$\{work_dir\}\/template\.json"/);
    assert.ok(
      source.lastIndexOf('sha256sum') < source.lastIndexOf('az deployment '),
    );
  }
  const phaseADeploy = fs.readFileSync(
    path.join(repositoryRoot, 'infra/governance/deploy-phase-a.sh'),
    'utf8',
  );
  assert.match(phaseADeploy, /PHASE_A_APPROVAL_FILE/);
  assert.match(phaseADeploy, /deployment-approval/);
  assert.match(phaseADeploy, /--template-file "\$\{work_dir\}\/template\.json"/);
  assert.doesNotMatch(phaseADeploy, /bootstrap-identities\.bicep" \\\n  --parameters/);
  for (const workflow of [phaseAWorkflow, phaseBWorkflow]) {
    assert.match(workflow, /fetch-depth: 0/);
  }
  const runbook = fs.readFileSync(
    path.join(repositoryRoot, 'docs/runbooks/CLOUD_LEAST_PRIVILEGE.md'),
    'utf8',
  );
  for (const variable of [
    'PHASE_B1_EVIDENCE_DIR',
    'PHASE_B1_EVIDENCE_MANIFEST_SHA256',
    'PHASE_B1_DEPLOYMENT_NAME',
  ]) {
    assert.match(runbook, new RegExp(variable));
  }
  assert.match(runbook, /deploy-phase-a\.sh/);
});

test('Phase A writes evidence before validation and manifest CLI handles spaces', () => {
  const script = fs.readFileSync(
    path.join(repositoryRoot, 'infra/governance/what-if-phase-a.sh'),
    'utf8',
  );
  assert.ok(
    script.indexOf('write-what-if-manifest.mjs') <
      script.indexOf('validate-what-if.mjs'),
  );
  const directory = path.join(tempDirectory(), 'directory with spaces');
  fs.mkdirSync(directory);
  const scriptPath = path.join(directory, 'write-what-if-manifest.mjs');
  fs.copyFileSync(
    path.join(
      repositoryRoot,
      'infra/governance/write-what-if-manifest.mjs',
    ),
    scriptPath,
  );
  assert.throws(
    () => execFileSync(process.execPath, [scriptPath], { encoding: 'utf8' }),
    /Missing required argument --phase/,
  );
});
