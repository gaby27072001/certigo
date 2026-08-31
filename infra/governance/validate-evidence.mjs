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
import { sha256File } from './write-what-if-manifest.mjs';
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
  const filePath = path.resolve(root, source.path);
  requireEqual(
    sha256File(filePath),
    source.sha256,
    `source hash mismatch for ${source.path}`,
  );
}

function artifactFiles(directory) {
  return fs
    .readdirSync(directory, { recursive: true, withFileTypes: true })
    .filter((entry) => entry.isFile())
    .map((entry) => path.join(entry.parentPath, entry.name))
    .filter(
      (file) =>
        !['manifest.json', 'manifest.sha256'].includes(path.basename(file)),
    )
    .map((file) => ({
      path: path.relative(directory, file).replaceAll('\\', '/'),
      sha256: sha256File(file),
    }))
    .sort((left, right) => left.path.localeCompare(right.path));
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
  requireEqual(manifest.schemaVersion, 2, 'unsupported evidence schema');
  requireEqual(
    JSON.stringify(manifest.artifacts),
    JSON.stringify(artifactFiles(path.dirname(manifestPath))),
    'artifact inventory mismatch',
  );
  if (expectedManifestSha256) {
    requireEqual(
      sha256File(manifestPath),
      expectedManifestSha256.toLowerCase(),
      'evidence manifest hash mismatch',
    );
  }
  requireEqual(
    sha256File(planPath),
    manifest.plan.sha256,
    'raw plan hash mismatch',
  );
  requireEqual(
    sha256File(parametersPath),
    manifest.parameters.sha256,
    'parameter hash mismatch',
  );
  requireEqual(
    sha256File(compiledTemplatePath),
    manifest.template.compiledSha256,
    'compiled template hash mismatch',
  );
  for (const source of manifest.sources) {
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
  requireEqual(
    String(deployment.properties?.templateHash ?? ''),
    manifest.template.armTemplateHash,
    'Phase A deployment template hash mismatch',
  );
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
    const phase = assignment.scope?.toLowerCase().includes(
      '/providers/microsoft.network/',
    )
      ? 'B2'
      : assignment.description?.startsWith('Launches the ')
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
  if (manifest.phase === 'B1a' && manifest.normalization) {
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
  if (expectedPhase === 'B1a' && manifest.normalization) {
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
