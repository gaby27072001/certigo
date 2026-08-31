import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export function sha256File(filePath) {
  return createHash('sha256').update(fs.readFileSync(filePath)).digest('hex');
}

function parseArguments(argv) {
  const result = {};
  for (let index = 0; index < argv.length; index += 2) {
    result[argv[index]] = argv[index + 1];
  }
  return result;
}

function relativeFile(sourceRoot, filePath) {
  const resolved = path.resolve(filePath);
  const relative = path.relative(sourceRoot, resolved).replaceAll('\\', '/');
  if (relative.startsWith('../') || path.isAbsolute(relative)) {
    throw new Error(`evidence source is outside the repository: ${filePath}`);
  }
  return {
    path: relative,
    sha256: sha256File(resolved),
  };
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
    artifactDirectory,
  } = options;
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
    sources: sourceFiles.map((file) => relativeFile(sourceRoot, file)),
    template: {
      ...relativeFile(sourceRoot, templatePath),
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
      sha256: planRaw
        ? createHash('sha256').update(planRaw).digest('hex')
        : null,
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
  manifest.artifacts = fs
    .readdirSync(artifactDirectory, { recursive: true, withFileTypes: true })
    .filter((entry) => entry.isFile())
    .map((entry) => path.join(entry.parentPath, entry.name))
    .filter(
      (file) =>
        path.resolve(file) !== path.resolve(outputPath) &&
        path.basename(file) !== 'manifest.sha256',
    )
    .map((file) => ({
      path: path.relative(artifactDirectory, file).replaceAll('\\', '/'),
      sha256: sha256File(file),
    }))
    .sort((left, right) => left.path.localeCompare(right.path));
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
    artifactDirectory: path.resolve(args['--artifact-dir']),
  });
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  main();
}
