import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

import {
  collectArtifactFiles,
  normalizeEvidencePath,
  relativeEvidenceFile,
  sha256File,
  validateEvidenceEntries,
} from './evidence-files.mjs';

export { sha256File } from './evidence-files.mjs';

function parseArguments(argv) {
  const result = {};
  for (let index = 0; index < argv.length; index += 2) {
    result[argv[index]] = argv[index + 1];
  }
  return result;
}

export function createManifest(options) {
  const {
    phase,
    planPath,
    outputPath,
    templatePath,
    compiledTemplatePath,
    parametersPath,
    sourceRoot,
    sourceCommit,
    subscriptionId,
    tenantId,
    repository,
    runId,
    ref,
    sourceFiles,
    phaseADeploymentPath,
    phaseAEvidenceManifestPath,
    phaseABindingPath,
    legacyTransitionPath,
    artifactDirectory,
  } = options;
  if (
    ['B1a', 'B1b', 'B2'].includes(phase) &&
    !legacyTransitionPath
  ) {
    throw new Error('Phase B manifest requires legacy transition evidence');
  }
  const planRaw = fs.existsSync(planPath) ? fs.readFileSync(planPath) : null;
  let plan = null;
  try {
    plan = planRaw ? JSON.parse(planRaw) : null;
  } catch {
    plan = null;
  }
  let compiled = null;
  try {
    compiled = fs.existsSync(compiledTemplatePath)
      ? JSON.parse(fs.readFileSync(compiledTemplatePath, 'utf8'))
      : null;
  } catch {
    compiled = null;
  }
  const counts = {};
  for (const change of plan?.changes ?? []) {
    const changeType = change.changeType ?? 'Unknown';
    counts[changeType] = (counts[changeType] ?? 0) + 1;
  }
  const manifest = {
    schemaVersion: 2,
    phase,
    deploymentExecuted: false,
    sourceCommit,
    subscriptionId,
    tenantId,
    context: {
      repository: repository ?? null,
      runId: runId ?? null,
      ref: ref ?? null,
    },
    sources: validateEvidenceEntries(
      sourceFiles.map((file) =>
        relativeEvidenceFile(sourceRoot, file, 'evidence source')
      ),
      'manifest sources',
    ),
    template: {
      ...relativeEvidenceFile(sourceRoot, templatePath, 'evidence template'),
      compiledSha256: fs.existsSync(compiledTemplatePath)
        ? sha256File(compiledTemplatePath)
        : null,
      armTemplateHash: String(compiled?.metadata?._generator?.templateHash ?? ''),
    },
    parameters: {
      path: path.basename(parametersPath),
      sha256: fs.existsSync(parametersPath) ? sha256File(parametersPath) : null,
    },
    plan: {
      path: 'plan.json',
      sha256: planRaw ? sha256File(planPath) : null,
      status: plan?.status ?? null,
      error: plan?.error ?? null,
      diagnostics: plan?.diagnostics ?? null,
      potentialChanges: plan?.potentialChanges ?? null,
      counts,
      total: plan?.changes?.length ?? null,
    },
  };
  if (phaseADeploymentPath) {
    const deployment = JSON.parse(
      fs.readFileSync(phaseADeploymentPath, 'utf8'),
    );
    manifest.phaseA = {
      deploymentId: deployment.id,
      deploymentName: deployment.name,
      deploymentTemplateHash: String(
        deployment.properties?.templateHash ?? '',
      ),
      evidenceManifestSha256: sha256File(phaseAEvidenceManifestPath),
      bindingSha256: sha256File(phaseABindingPath),
    };
  }
  if (legacyTransitionPath) {
    manifest.legacyTransition = relativeEvidenceFile(
      artifactDirectory,
      legacyTransitionPath,
      'legacy transition evidence',
    );
  }
  const normalizedPlanPath = path.join(
    artifactDirectory,
    'normalized-plan.json',
  );
  const provenancePath = path.join(
    artifactDirectory,
    'principal-type-provenance.json',
  );
  if (fs.existsSync(normalizedPlanPath) || fs.existsSync(provenancePath)) {
    if (!fs.existsSync(normalizedPlanPath) || !fs.existsSync(provenancePath)) {
      throw new Error('principalType normalization evidence is incomplete');
    }
    const provenance = JSON.parse(fs.readFileSync(provenancePath, 'utf8'));
    manifest.normalization = {
      normalizedPlanSha256: sha256File(normalizedPlanPath),
      provenanceSha256: sha256File(provenancePath),
      effectivePrincipalType: 'ServicePrincipal',
      provenance: 'compiled-template+live-uami',
      normalizedCount: provenance.normalizedCount,
    };
  }
  const outputRelativePath = normalizeEvidencePath(
    path.relative(artifactDirectory, outputPath),
    'manifest output path',
  );
  manifest.artifacts = collectArtifactFiles(artifactDirectory, [
    outputRelativePath,
    'manifest.sha256',
  ]);
  fs.writeFileSync(outputPath, `${JSON.stringify(manifest, null, 2)}\n`, {
    mode: 0o600,
  });
  return manifest;
}

function main() {
  const args = parseArguments(process.argv.slice(2));
  const required = [
    '--phase',
    '--plan',
    '--output',
    '--template',
    '--compiled-template',
    '--parameters',
    '--source-root',
    '--source-commit',
    '--subscription',
    '--tenant',
    '--sources',
    '--artifact-dir',
  ];
  for (const key of required) {
    if (!args[key]) {
      throw new Error(`Missing required argument ${key}`);
    }
  }
  if (
    ['B1a', 'B1b', 'B2'].includes(args['--phase']) &&
    !args['--legacy-transition']
  ) {
    throw new Error('Missing required argument --legacy-transition');
  }
  createManifest({
    phase: args['--phase'],
    planPath: path.resolve(args['--plan']),
    outputPath: path.resolve(args['--output']),
    templatePath: path.resolve(args['--template']),
    compiledTemplatePath: path.resolve(args['--compiled-template']),
    parametersPath: path.resolve(args['--parameters']),
    sourceRoot: path.resolve(args['--source-root']),
    sourceCommit: args['--source-commit'],
    subscriptionId: args['--subscription'],
    tenantId: args['--tenant'],
    repository: process.env.GITHUB_REPOSITORY,
    runId: process.env.GITHUB_RUN_ID,
    ref: process.env.GITHUB_REF,
    sourceFiles: args['--sources'].split(',').map((entry) => path.resolve(entry)),
    phaseADeploymentPath: args['--phase-a-deployment']
      ? path.resolve(args['--phase-a-deployment'])
      : null,
    phaseAEvidenceManifestPath: args['--phase-a-evidence-manifest']
      ? path.resolve(args['--phase-a-evidence-manifest'])
      : null,
    phaseABindingPath: args['--phase-a-binding']
      ? path.resolve(args['--phase-a-binding'])
      : null,
    legacyTransitionPath: args['--legacy-transition']
      ? path.resolve(args['--legacy-transition'])
      : null,
    artifactDirectory: path.resolve(args['--artifact-dir']),
  });
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  main();
}
