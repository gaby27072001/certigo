import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

import {
  expectedPhaseBContracts,
  validatePhaseAProof,
  validatePhaseBResource,
  validateWhatIf,
} from './validate-what-if.mjs';
import {
  collectArtifactFiles,
  normalizeEvidencePath,
  relativeEvidenceFile,
  requireRegularFile,
  resolveEvidenceFile,
  sha256File,
  validateEvidenceEntries,
} from './evidence-files.mjs';
import { normalizePrincipalTypes } from './normalize-principal-types.mjs';

function parseArguments(argv) {
  const result = {};
  for (let index = 1; index < argv.length; index += 2) {
    result[argv[index]] = argv[index + 1];
  }
  return result;
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(path.resolve(filePath), 'utf8'));
}

function requireEqual(actual, expected, message) {
  if (actual !== expected) {
    throw new Error(`${message}: expected ${expected}, received ${actual}`);
  }
}

function requireExactFields(value, expected, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error(`${label} must be an object`);
  }
  const actual = Object.keys(value).sort();
  const required = [...expected].sort();
  if (JSON.stringify(actual) !== JSON.stringify(required)) {
    throw new Error(`${label} has missing or extra fields`);
  }
}

function requireSha256(value, label) {
  if (typeof value !== 'string' || !/^[0-9a-f]{64}$/.test(value)) {
    throw new Error(`${label} is not a lowercase SHA-256`);
  }
}

function validateManifestSchema(manifest) {
  const topLevelFields = [
    'artifacts',
    'context',
    'deploymentExecuted',
    'parameters',
    'phase',
    'plan',
    'schemaVersion',
    'sourceCommit',
    'sources',
    'subscriptionId',
    'template',
    'tenantId',
  ];
  if (manifest.phaseA !== undefined) {
    topLevelFields.push('phaseA');
  }
  if (manifest.normalization !== undefined) {
    topLevelFields.push('normalization');
  }
  if (['B1a', 'B1b', 'B2'].includes(manifest.phase)) {
    topLevelFields.push('legacyTransition');
  }
  requireExactFields(manifest, topLevelFields, 'evidence manifest');
  requireExactFields(manifest.context, ['ref', 'repository', 'runId'], 'manifest context');
  requireExactFields(
    manifest.template,
    ['armTemplateHash', 'compiledSha256', 'path', 'sha256'],
    'manifest template',
  );
  requireExactFields(manifest.parameters, ['path', 'sha256'], 'manifest parameters');
  requireExactFields(
    manifest.plan,
    [
      'counts',
      'diagnostics',
      'error',
      'path',
      'potentialChanges',
      'sha256',
      'status',
      'total',
    ],
    'manifest plan',
  );
  if (manifest.phaseA) {
    requireExactFields(
      manifest.phaseA,
      [
        'bindingSha256',
        'deploymentId',
        'deploymentName',
        'deploymentTemplateHash',
        'evidenceManifestSha256',
      ],
      'manifest Phase A binding',
    );
    requireSha256(manifest.phaseA.bindingSha256, 'manifest Phase A binding hash');
    requireSha256(
      manifest.phaseA.evidenceManifestSha256,
      'manifest Phase A evidence hash',
    );
  }
  if (manifest.normalization) {
    requireExactFields(
      manifest.normalization,
      [
        'effectivePrincipalType',
        'normalizedCount',
        'normalizedPlanSha256',
        'provenance',
        'provenanceSha256',
      ],
      'manifest normalization',
    );
    requireSha256(
      manifest.normalization.normalizedPlanSha256,
      'manifest normalized plan hash',
    );
    requireSha256(
      manifest.normalization.provenanceSha256,
      'manifest provenance hash',
    );
  }
  if (['B1a', 'B1b', 'B2'].includes(manifest.phase)) {
    requireExactFields(
      manifest.legacyTransition,
      ['path', 'sha256'],
      'manifest legacy transition',
    );
    requireSha256(
      manifest.legacyTransition.sha256,
      'manifest legacy transition hash',
    );
    normalizeEvidencePath(
      manifest.legacyTransition.path,
      'manifest legacy transition path',
    );
  }
  if (manifest.schemaVersion !== 2 || manifest.deploymentExecuted !== false) {
    throw new Error('unsupported evidence schema');
  }
  normalizeEvidencePath(manifest.template.path, 'manifest template path');
  normalizeEvidencePath(manifest.parameters.path, 'manifest parameters path');
  normalizeEvidencePath(manifest.plan.path, 'manifest plan path');
  requireSha256(manifest.template.sha256, 'manifest template source hash');
  requireSha256(manifest.template.compiledSha256, 'manifest compiled template hash');
  requireSha256(manifest.parameters.sha256, 'manifest parameters hash');
  requireSha256(manifest.plan.sha256, 'manifest plan hash');
  const artifacts = validateEvidenceEntries(
    manifest.artifacts,
    'manifest artifacts',
  );
  if (['B1a', 'B1b', 'B2'].includes(manifest.phase)) {
    const legacyTransitionArtifact = artifacts.find(
      ({ path: artifactPath }) =>
        artifactPath === manifest.legacyTransition.path,
    );
    if (
      !legacyTransitionArtifact ||
      legacyTransitionArtifact.sha256 !== manifest.legacyTransition.sha256
    ) {
      throw new Error(
        'manifest legacy transition is not bound to its inventoried artifact',
      );
    }
  }
  return {
    artifacts,
    sources: validateEvidenceEntries(manifest.sources, 'manifest sources'),
  };
}

function canonicalJson(value) {
    if (Array.isArray(value)) {
      return value.map(canonicalJson);
    }
    if (value && typeof value === 'object') {
      return Object.fromEntries(
        Object.keys(value)
          .sort()
          .map((key) => [key, canonicalJson(value[key])]),
      );
    }
    return value;
}

function parameterValues(value) {
    return Object.fromEntries(
      Object.entries(value?.parameters ?? value ?? {})
        .sort(([left], [right]) => left.localeCompare(right))
        .map(([key, parameter]) => [key, canonicalJson(parameter?.value)]),
    );
}

export function validateDeploymentParameters(deployment, approvedParameters) {
    requireEqual(
      JSON.stringify(parameterValues(deployment.properties?.parameters)),
      JSON.stringify(parameterValues(approvedParameters)),
      'deployment parameter mismatch',
    );
}

function verifySource(root, source) {
  const filePath = resolveEvidenceFile(root, source.path, 'manifest source');
  requireEqual(
    sha256File(filePath),
    source.sha256,
    `source hash mismatch for ${source.path}`,
  );
}

export function verifyManifestFiles(manifest, options) {
  const {
    manifestPath,
    planPath,
    parametersPath,
    compiledTemplatePath,
    sourceRoot,
    expectedManifestSha256,
    requireHead = false,
  } = options;
  const manifestFile = requireRegularFile(manifestPath, 'evidence manifest');
  const artifactDirectory = path.dirname(manifestFile);
  const normalizedManifest = validateManifestSchema(manifest);
  requireEqual(
    JSON.stringify(normalizedManifest.artifacts),
    JSON.stringify(
      collectArtifactFiles(artifactDirectory, [
        path.basename(manifestFile),
        'manifest.sha256',
      ]),
    ),
    'artifact inventory mismatch',
  );
  if (expectedManifestSha256) {
    requireEqual(
      sha256File(manifestFile),
      expectedManifestSha256.toLowerCase(),
      'evidence manifest hash mismatch',
    );
  }
  requireEqual(
    relativeEvidenceFile(artifactDirectory, planPath, 'raw plan').path,
    normalizeEvidencePath(manifest.plan.path),
    'raw plan path mismatch',
  );
  requireEqual(
    sha256File(planPath),
    manifest.plan.sha256,
    'raw plan hash mismatch',
  );
  requireEqual(
    relativeEvidenceFile(
      artifactDirectory,
      parametersPath,
      'deployment parameters',
    ).path,
    normalizeEvidencePath(manifest.parameters.path),
    'parameter path mismatch',
  );
  requireEqual(
    sha256File(parametersPath),
    manifest.parameters.sha256,
    'parameter hash mismatch',
  );
  relativeEvidenceFile(
    artifactDirectory,
    compiledTemplatePath,
    'compiled template',
  );
  requireEqual(
    sha256File(compiledTemplatePath),
    manifest.template.compiledSha256,
    'compiled template hash mismatch',
  );
  const templateSource = relativeEvidenceFile(
    sourceRoot,
    resolveEvidenceFile(sourceRoot, manifest.template.path, 'manifest template'),
    'manifest template',
  );
  requireEqual(
    templateSource.sha256,
    manifest.template.sha256,
    'template source hash mismatch',
  );
  for (const source of normalizedManifest.sources) {
    verifySource(sourceRoot, source);
  }
  const head = execFileSync('git', ['rev-parse', 'HEAD'], {
    cwd: sourceRoot,
    encoding: 'utf8',
  }).trim();
  if (requireHead) {
    requireEqual(head, manifest.sourceCommit, 'source commit mismatch');
  } else {
    try {
      execFileSync(
        'git',
        ['merge-base', '--is-ancestor', manifest.sourceCommit, head],
        { cwd: sourceRoot, stdio: 'ignore' },
      );
    } catch {
      throw new Error('Phase A evidence commit is not an ancestor of HEAD');
    }
  }
}

function phaseADeploymentWrappers(subscriptionId) {
  const prefix =
    `/subscriptions/${subscriptionId}/resourceGroups/rg-certigo-identities/` +
    'providers/Microsoft.Resources/deployments/';
  return [
    'identity-dev',
    'identity-staging',
    'identity-prod',
    'identity-content-infra-plan',
    'content-release-publisher-identity',
    'content-public-publisher-identity',
    'content-private-publisher-identity',
    'content-reader-identity',
  ].map((name) => `${prefix}${name}`.toLowerCase());
}

export function validatePhaseABinding(input) {
  const {
    manifest,
    plan,
    deployment,
    operations,
    roleAssignments,
    policyAssignments,
    sourceRoot,
    manifestPath,
    planPath,
    parametersPath,
    compiledTemplatePath,
    expectedManifestSha256,
    approvedParameters,
  } = input;
  verifyManifestFiles(manifest, {
    manifestPath,
    planPath,
    parametersPath,
    compiledTemplatePath,
    sourceRoot,
    expectedManifestSha256,
  });
  requireEqual(manifest.phase, 'A', 'Phase A evidence phase mismatch');
  validateWhatIf(plan, manifest.subscriptionId, { phase: 'A' });
  requireEqual(
    deployment.properties?.provisioningState,
    'Succeeded',
    'Phase A deployment state mismatch',
  );
  if (
    String(deployment.properties?.templateHash ?? '') !==
    manifest.template.armTemplateHash
  ) {
    throw new Error(
      'Phase A deployment template hash mismatch. Never substitute local proof; ' +
        'run and approve a separate repair what-if/deployment tied to the current template.',
    );
  }
  validateDeploymentParameters(deployment, approvedParameters);
  const proof = validatePhaseAProof(
    deployment.properties?.outputs?.phaseA?.value,
    manifest.subscriptionId,
  );
  validatePhaseAOperations(plan, operations, manifest.subscriptionId);
  const existingContracts = validateExistingPhaseBAssignments(
    roleAssignments,
    policyAssignments,
    manifest.subscriptionId,
    proof,
  );
  return { proof, existingContracts };
}

export function validatePhaseBTransition(
  existingContracts,
  subscriptionId,
  proof,
  stage,
) {
  const observed = new Set(existingContracts);
  const b1a = expectedPhaseBContracts(subscriptionId, proof, 'B1a');
  const b1b = expectedPhaseBContracts(subscriptionId, proof, 'B1b');
  const b2 = expectedPhaseBContracts(subscriptionId, proof, 'B2');
  const allowed = new Set(
    stage === 'B1a'
      ? b1a
      : stage === 'B1b'
        ? [...b1a, ...b1b]
        : [...b1a, ...b1b, ...b2],
  );
  for (const contract of observed) {
    if (!allowed.has(contract)) {
      throw new Error(`unexpected live assignment before ${stage}: ${contract}`);
    }
  }
  if (stage === 'B1b' || stage === 'B2') {
    for (const contract of b1a) {
      if (!observed.has(contract)) {
        throw new Error(`B1a transition is incomplete: ${contract}`);
      }
    }
  }
  if (stage === 'B2') {
    for (const contract of b1b) {
      if (!observed.has(contract)) {
        throw new Error(`B1b transition is incomplete: ${contract}`);
      }
    }
  }
  return {
    b1aComplete: b1a.every((contract) => observed.has(contract)),
    b1bComplete: b1b.every((contract) => observed.has(contract)),
    existingB2Count: b2.filter((contract) => observed.has(contract)).length,
  };
}

export function validatePhaseAOperations(plan, operations, subscriptionId) {
  const allowedTargets = new Set([
    ...plan.changes.map((change) => String(change.resourceId).toLowerCase()),
    ...phaseADeploymentWrappers(subscriptionId),
  ]);
  const observedTargets = new Set();
  for (const operation of operations) {
    requireEqual(
      operation.properties?.provisioningState,
      'Succeeded',
      `Phase A operation failed: ${operation.operationId}`,
    );
    const id = String(operation.properties?.targetResource?.id ?? '').toLowerCase();
    if (!id) {
      continue;
    }
    if (
      id.includes('/microsoft.authorization/roleassignments/') ||
      id.includes('/microsoft.authorization/policyassignments/')
    ) {
      throw new Error(`Phase A operation created an assignment: ${id}`);
    }
    if (!allowedTargets.has(id)) {
      throw new Error(`Phase A operation target is outside evidence: ${id}`);
    }
    observedTargets.add(id);
  }
  for (const id of allowedTargets) {
    if (!observedTargets.has(id)) {
      throw new Error(`Phase A operation evidence is incomplete: ${id}`);
    }
  }
  return [...observedTargets].sort();
}

export function validateExistingPhaseBAssignments(
  roleAssignments,
  policyAssignments,
  subscriptionId,
  proof,
) {
  const contracts = new Set();
  for (const assignment of roleAssignments) {
    const roleDefinitionId = String(assignment.roleDefinitionId).toLowerCase();
    const managedIdentityOperatorRoleId =
      `/subscriptions/${subscriptionId}/providers/Microsoft.Authorization/` +
      'roleDefinitions/f1a07417-d97a-45cb-824c-7a7467783830';
    const isDelegator = [
      proof.roleDefinitionIds.runtimeRoleAssignmentWriter,
      proof.roleDefinitionIds.contentInfrastructurePlanExecutor,
      managedIdentityOperatorRoleId,
    ].some(
      (expected) => String(expected).toLowerCase() === roleDefinitionId,
    );
    const phase = assignment.scope?.toLowerCase().includes(
      '/providers/microsoft.network/',
    )
      ? 'B2'
      : assignment.description?.startsWith('Launches the ') || isDelegator
        ? 'B1b'
        : 'B1a';
    const contract = validatePhaseBResource(
      {
        id: assignment.id,
        name: assignment.name,
        type: 'Microsoft.Authorization/roleAssignments',
        properties: {
          condition: assignment.condition ?? null,
          conditionVersion: assignment.conditionVersion ?? null,
          description: assignment.description,
          principalId: assignment.principalId,
          principalType: assignment.principalType,
          roleDefinitionId: assignment.roleDefinitionId,
        },
      },
      subscriptionId,
      proof,
      phase,
    );
    if (contracts.has(contract)) {
      throw new Error(`duplicate live Phase B assignment: ${contract}`);
    }
    contracts.add(contract);
  }
  for (const assignment of policyAssignments) {
    const contract = validatePhaseBResource(
      {
        id: assignment.id,
        name: assignment.name,
        type: 'Microsoft.Authorization/policyAssignments',
        properties: {
          enforcementMode: assignment.enforcementMode,
          parameters: assignment.parameters,
          policyDefinitionId: assignment.policyDefinitionId,
        },
      },
      subscriptionId,
      proof,
      'B1b',
    );
    if (contracts.has(contract)) {
      throw new Error(`duplicate live Phase B assignment: ${contract}`);
    }
    contracts.add(contract);
  }
  return [...contracts].sort();
}

export function verifyDeploymentApproval(input) {
  const {
    approval,
    manifest,
    phaseAProof,
    phaseABindingPath,
    manifestPath,
    planPath,
    parametersPath,
    compiledTemplatePath,
    sourceRoot,
    subscriptionId,
    tenantId,
    legacyTransitionPath,
  } = input;
  requireEqual(approval.schemaVersion, 1, 'unsupported approval schema');
  requireEqual(approval.approved, true, 'evidence is not approved');
  requireEqual(approval.phase, manifest.phase, 'approval phase mismatch');
  requireEqual(
    approval.manifestSha256,
    sha256File(manifestPath),
    'approved manifest hash mismatch',
  );
  requireEqual(
    approval.planSha256,
    manifest.plan.sha256,
    'approved plan hash mismatch',
  );
  requireEqual(
    approval.sourceCommit,
    manifest.sourceCommit,
    'approved source commit mismatch',
  );
  if (manifest.phase === 'A') {
    if (approval.phaseAEvidenceManifestSha256 != null) {
      throw new Error('Phase A approval must not reference prior Phase A evidence');
    }
  } else {
    requireEqual(
      approval.phaseAEvidenceManifestSha256,
      manifest.phaseA.evidenceManifestSha256,
      'approved Phase A evidence mismatch',
    );
    requireEqual(
      sha256File(phaseABindingPath),
      manifest.phaseA.bindingSha256,
      'Phase A binding hash mismatch',
    );
  }
  requireEqual(
    manifest.subscriptionId,
    subscriptionId,
    'deployment subscription mismatch',
  );
  requireEqual(manifest.tenantId, tenantId, 'deployment tenant mismatch');
  validateManifestSchema(manifest);
  if (['B1a', 'B1b', 'B2'].includes(manifest.phase)) {
    if (!legacyTransitionPath) {
      throw new Error('fresh legacy transition evidence is required');
    }
    requireEqual(
      sha256File(legacyTransitionPath),
      manifest.legacyTransition.sha256,
      'approved legacy transition hash mismatch',
    );
  }
  verifyManifestFiles(manifest, {
    manifestPath,
    planPath,
    parametersPath,
    compiledTemplatePath,
    sourceRoot,
    requireHead: true,
  });
  const rawPlan = readJson(planPath);
  let effectivePlan = rawPlan;
  if (['B1a', 'B1b'].includes(manifest.phase) && manifest.normalization) {
    const normalized = normalizePrincipalTypes(
      rawPlan,
      readJson(compiledTemplatePath),
      phaseAProof,
    );
    const artifactDirectory = path.dirname(manifestPath);
    const normalizedPlanPath = path.join(
      artifactDirectory,
      'normalized-plan.json',
    );
    const provenancePath = path.join(
      artifactDirectory,
      'principal-type-provenance.json',
    );
    requireEqual(
      JSON.stringify(normalized.plan),
      JSON.stringify(readJson(normalizedPlanPath)),
      'normalized plan mismatch',
    );
    requireEqual(
      JSON.stringify(normalized.provenance),
      JSON.stringify(readJson(provenancePath)),
      'principalType provenance mismatch',
    );
    requireEqual(
      sha256File(normalizedPlanPath),
      manifest.normalization.normalizedPlanSha256,
      'normalized plan hash mismatch',
    );
    requireEqual(
      sha256File(provenancePath),
      manifest.normalization.provenanceSha256,
      'principalType provenance hash mismatch',
    );
    effectivePlan = normalized.plan;
  }
  validateWhatIf(effectivePlan, manifest.subscriptionId, {
    phase: manifest.phase,
    phaseA: manifest.phase === 'A' ? null : phaseAProof,
  });
}

export function validatePriorDeployment(input) {
  const {
    manifest,
    plan,
    deployment,
    approvedParameters,
    manifestPath,
    planPath,
    parametersPath,
    compiledTemplatePath,
    sourceRoot,
    expectedManifestSha256,
    phaseAProof,
    expectedPhase,
  } = input;
  verifyManifestFiles(manifest, {
    manifestPath,
    planPath,
    parametersPath,
    compiledTemplatePath,
    sourceRoot,
    expectedManifestSha256,
  });
  requireEqual(manifest.phase, expectedPhase, 'prior deployment phase mismatch');
  let effectivePlan = plan;
  if (['B1a', 'B1b'].includes(expectedPhase) && manifest.normalization) {
    const normalized = normalizePrincipalTypes(
      plan,
      readJson(compiledTemplatePath),
      phaseAProof,
    );
    const artifactDirectory = path.dirname(manifestPath);
    const normalizedPlanPath = path.join(artifactDirectory, 'normalized-plan.json');
    const provenancePath = path.join(
      artifactDirectory,
      'principal-type-provenance.json',
    );
    requireEqual(
      JSON.stringify(normalized.plan),
      JSON.stringify(readJson(normalizedPlanPath)),
      'normalized plan mismatch',
    );
    requireEqual(
      JSON.stringify(normalized.provenance),
      JSON.stringify(readJson(provenancePath)),
      'principalType provenance mismatch',
    );
    requireEqual(
      sha256File(normalizedPlanPath),
      manifest.normalization.normalizedPlanSha256,
      'normalized plan hash mismatch',
    );
    requireEqual(
      sha256File(provenancePath),
      manifest.normalization.provenanceSha256,
      'principalType provenance hash mismatch',
    );
    effectivePlan = normalized.plan;
  }
  validateWhatIf(effectivePlan, manifest.subscriptionId, {
    phase: expectedPhase,
    phaseA: phaseAProof,
  });
  requireEqual(
    deployment.properties?.provisioningState,
    'Succeeded',
    'B1 deployment state mismatch',
  );
  requireEqual(
    String(deployment.properties?.templateHash ?? ''),
    manifest.template.armTemplateHash,
    'B1 deployment template hash mismatch',
  );
  validateDeploymentParameters(deployment, approvedParameters);
}

function main() {
  const command = process.argv[2];
  const args = parseArguments(process.argv.slice(2));
  if (command === 'phase-a-binding') {
    const manifest = readJson(args['--manifest']);
    const deployment = readJson(args['--deployment']);
    const result = validatePhaseABinding({
      manifest,
      plan: readJson(args['--plan']),
      deployment,
      operations: readJson(args['--operations']),
      roleAssignments: readJson(args['--role-assignments']),
      policyAssignments: readJson(args['--policy-assignments']),
      sourceRoot: path.resolve(args['--source-root']),
      manifestPath: path.resolve(args['--manifest']),
      planPath: path.resolve(args['--plan']),
      parametersPath: path.resolve(args['--parameters']),
      compiledTemplatePath: path.resolve(args['--compiled-template']),
      expectedManifestSha256: args['--expected-manifest-sha256'],
      approvedParameters: readJson(args['--approved-parameters']),
    });
    fs.writeFileSync(
      args['--output'],
      `${JSON.stringify(
        {
          schemaVersion: 1,
          deploymentId: deployment.id,
          deploymentName: deployment.name,
          deploymentTemplateHash: deployment.properties.templateHash,
          phaseAEvidenceManifestSha256: sha256File(args['--manifest']),
          phaseAPlanSha256: manifest.plan.sha256,
          sourceCommit: manifest.sourceCommit,
          existingContracts: result.existingContracts,
          transition: validatePhaseBTransition(
            result.existingContracts,
            manifest.subscriptionId,
            result.proof,
            args['--stage'],
          ),
        },
        null,
        2,
      )}\n`,
      { mode: 0o600 },
    );
    return;
  }
  if (command === 'deployment-approval') {
    verifyDeploymentApproval({
      approval: readJson(args['--approval']),
      manifest: readJson(args['--manifest']),
      phaseAProof: args['--phase-a-proof']
        ? readJson(args['--phase-a-proof'])
        : null,
      manifestPath: path.resolve(args['--manifest']),
      planPath: path.resolve(args['--plan']),
      parametersPath: path.resolve(args['--parameters']),
      compiledTemplatePath: path.resolve(args['--compiled-template']),
      phaseABindingPath: args['--phase-a-binding']
        ? path.resolve(args['--phase-a-binding'])
        : null,
      sourceRoot: path.resolve(args['--source-root']),
      subscriptionId: args['--subscription'],
      tenantId: args['--tenant'],
      legacyTransitionPath: args['--legacy-transition']
        ? path.resolve(args['--legacy-transition'])
        : null,
    });
    return;
  }
  if (command === 'prior-b1-deployment') {
    validatePriorDeployment({
      manifest: readJson(args['--manifest']),
      plan: readJson(args['--plan']),
      deployment: readJson(args['--deployment']),
      approvedParameters: readJson(args['--parameters']),
      manifestPath: path.resolve(args['--manifest']),
      planPath: path.resolve(args['--plan']),
      parametersPath: path.resolve(args['--parameters']),
      compiledTemplatePath: path.resolve(args['--compiled-template']),
      sourceRoot: path.resolve(args['--source-root']),
      expectedManifestSha256: args['--expected-manifest-sha256'],
      phaseAProof: readJson(args['--phase-a-proof']),
      expectedPhase: args['--phase'],
    });
    return;
  }
  throw new Error(
    'command must be phase-a-binding, deployment-approval, or prior-b1-deployment',
  );
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  main();
}
