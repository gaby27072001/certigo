import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { access, readFile } from 'node:fs/promises';
import { test } from 'node:test';

const imageRoot = new URL('./', import.meta.url);
const manifest = JSON.parse(
  await readFile(new URL('toolchain-manifest.json', imageRoot), 'utf8'),
);
const sbom = JSON.parse(
  await readFile(new URL('toolchain-sbom.cyclonedx.document', imageRoot), 'utf8'),
);
const prewarm = await readFile(new URL('prewarm-toolchain.sh', imageRoot), 'utf8');
const validator = await readFile(new URL('validate-toolchain.sh', imageRoot), 'utf8');
const jobTemp = await readFile(new URL('job-temp.sh', imageRoot), 'utf8');
const generator = await readFile(
  new URL('certigo-toolchain-guard-generator', imageRoot),
  'utf8',
);
const runnerEnvironment = await readFile(
  new URL('runner-ephemeral.conf', imageRoot),
  'utf8',
);
const pythonLock = await readFile(
  new URL('toolchain-requirements.lock', imageRoot),
  'utf8',
);
const evidence = JSON.parse(
  await readFile(new URL('runner-image-evidence.json', imageRoot), 'utf8'),
);
const repositoryRoot = new URL('../../../', imageRoot);

test('manifest pins every downloaded artifact and forbids project caches', () => {
  assert.equal(manifest.schemaVersion, 1);
  assert.equal(manifest.target.osVersion, '24.04');
  assert.equal(manifest.target.architecture, 'x86_64');
  assert.equal(manifest.policy.exactVersionMatch, true);
  assert.equal(manifest.policy.projectDependencyCachesPersisted, false);
  assert.deepEqual(manifest.policy.dotnetWorkloads, []);
  assert.deepEqual(manifest.contentTools.prewarmedProjectDependencies, []);

  for (const tool of manifest.tools.filter((candidate) => candidate.source)) {
    assert.match(tool.source.url, /^https:\/\//);
    assert.doesNotMatch(tool.source.url, /\/latest\//i);
    const lengths = { sha256: 64, sha512: 128 };
    assert.equal(
      tool.source.digest.value.length,
      lengths[tool.source.digest.algorithm],
      `${tool.id} digest length`,
    );
    assert.match(tool.source.digest.value, /^[0-9a-f]+$/);
  }
});

test('CycloneDX SBOM covers every manifest component version', () => {
  assert.equal(manifest.artifacts.cycloneDxSbom, 'toolchain-sbom.cyclonedx.document');
  assert.equal(sbom.bomFormat, 'CycloneDX');
  assert.equal(sbom.specVersion, '1.6');
  const versions = new Set(
    sbom.components.map((component) => component.version),
  );
  for (const component of [...manifest.baseComponents, ...manifest.tools]) {
    assert.ok(versions.has(component.version), `${component.id} ${component.version}`);
  }
  assert.equal(
    sbom.metadata.properties.find(
      (property) => property.name === 'certigo:project-dependency-caches-persisted',
    ).value,
    'false',
  );
  const lockedPackages = new Set(
    [...pythonLock.matchAll(/^([a-z0-9][a-z0-9._-]*)==([^\s\\]+)\s*\\/gim)].map(
      (match) => `${match[1].toLowerCase()}==${match[2]}`,
    ),
  );
  const sbomPythonPackages = new Set(
    sbom.components
      .filter((component) => component.purl?.startsWith('pkg:pypi/'))
      .map((component) => `${component.name.toLowerCase()}==${component.version}`),
  );
  assert.deepEqual(sbomPythonPackages, lockedPackages);
  const checkovDependency = sbom.dependencies.find(
    (dependency) => dependency.ref === `pkg:pypi/checkov@3.2.495`,
  );
  assert.equal(checkovDependency.dependsOn.length, lockedPackages.size - 1);
});

test('repository SBOM name is explicit but not auto-detected by legacy recursive scanners', async () => {
  await assert.rejects(
    access(new URL('toolchain-sbom.cdx.json', imageRoot)),
    { code: 'ENOENT' },
  );
  assert.doesNotMatch(
    manifest.artifacts.cycloneDxSbom,
    /(?:^|[.])(?:cdx|spdx)[.]json$/u,
  );
  assert.match(manifest.artifacts.cycloneDxSbom, /cyclonedx[.]document$/u);
});

test('prewarm verifies downloads and never resolves project dependencies', () => {
  assert.match(prewarm, /sha256sum/);
  assert.match(prewarm, /sha512sum/);
  assert.match(prewarm, /--require-hashes/);
  assert.match(prewarm, /flutter" precache --linux/);
  assert.doesNotMatch(prewarm, /\bnpm (ci|install)\b/);
  assert.doesNotMatch(prewarm, /\bdotnet restore\b/);
  assert.doesNotMatch(prewarm, /\bflutter pub get\b/);
});

test('boot validation and generated runner dependency fail closed', () => {
  assert.match(validator, /rm -f \/run\/certigo-toolchain\.valid/);
  assert.match(validator, /GitHub Actions runner version mismatch/);
  assert.match(validator, /Azure CLI version mismatch/);
  assert.match(validator, /unexpected \.NET workload installed/);
  assert.match(validator, /complete toolchain inventory mismatch/);
  assert.match(validator, /certigo-inventory-toolchain/);
  assert.match(validator, /persistent project\/tool cache is not empty/);
  assert.match(validator, /registered runner state is not sealed/);
  assert.match(generator, /Requires=certigo-toolchain-validate\.service/);
  assert.match(generator, /Requires=certigo-job-temp-mount\.service/);
  assert.match(generator, /After=certigo-toolchain-validate\.service/);
  assert.doesNotMatch(generator, /Wants=/);
});

test('job hooks require a dedicated mount and isolate dependency caches', () => {
  assert.match(jobTemp, /mountpoint -q "\$\{resource_mount\}"/);
  assert.match(jobTemp, /\/dev\/disk\/azure\/resource-part1/);
  assert.match(jobTemp, /nodev nosuid/);
  assert.match(jobTemp, /mount --bind "\$\{runner_work\}" "\$\{configured_work\}"/);
  assert.match(jobTemp, /stat -c '%d:%i'/);
  assert.match(jobTemp, /certigo-validate-toolchain --job/);
  assert.match(jobTemp, /configured runner workspace is not on the temporary disk/);
  assert.doesNotMatch(jobTemp, /Run the job temp hook as root/);
  assert.match(runnerEnvironment, /ACTIONS_RUNNER_HOOK_JOB_STARTED=/);
  assert.match(runnerEnvironment, /ACTIONS_RUNNER_HOOK_JOB_COMPLETED=/);
  for (const name of [
    'RUNNER_TEMP',
    'NUGET_PACKAGES',
    'npm_config_cache',
    'PUB_CACHE',
    'DOTNET_CLI_HOME',
  ]) {
    assert.match(runnerEnvironment, new RegExp(`^${name}=\\/mnt\\/certigo-job\\/`, 'm'));
  }
  assert.match(runnerEnvironment, /^FLUTTER_ALREADY_LOCKED=true$/m);
});

test('prewarm does not alter Azure trust, network, labels, or capacity', () => {
  for (const forbidden of [
    'az deployment',
    'az vmss',
    'managed identity',
    'certigo-pr',
    'certigo-trusted',
    'publicIPAddress',
    'capacity',
  ]) {
    assert.doesNotMatch(prewarm, new RegExp(forbidden, 'i'));
  }
});

test('manifest versions remain aligned with current workflow project state', async () => {
  const [mobile, backendCd, infra, security, lint] = await Promise.all([
    readFile(new URL('.github/workflows/ci-mobile.yml', repositoryRoot), 'utf8'),
    readFile(new URL('.github/workflows/cd-backend.yml', repositoryRoot), 'utf8'),
    readFile(new URL('.github/workflows/ci-infra.yml', repositoryRoot), 'utf8'),
    readFile(new URL('.github/workflows/security-scan.yml', repositoryRoot), 'utf8'),
    readFile(new URL('.github/workflows/lint-workflows.yml', repositoryRoot), 'utf8'),
  ]);
  assert.match(mobile, /FLUTTER_VERSION: "3\.44\.4"/);
  assert.match(mobile, /sdk: "3\.12\.2"/);
  assert.match(mobile, /sdk: "3\.6\.0"/);
  assert.match(backendCd, /dotnet-version: "8\.0\.424"/);
  assert.match(infra, /node-version: "20\.20\.2"/);
  assert.match(infra, /releases\/download\/v0\.44\.1\/bicep-linux-x64/);
  assert.match(security, /checkov==3\.2\.495/);
  assert.match(lint, /releases\/download\/v1\.7\.12\/actionlint_1\.7\.12_linux_amd64/);
});

test('content tooling lock is pinned without prewarming project dependencies', async () => {
  const contentLock = await readFile(
    new URL(manifest.contentTools.nodeLockfile, imageRoot),
  );
  assert.equal(
    createHash('sha256').update(contentLock).digest('hex'),
    manifest.contentTools.nodeLockfileSha256,
  );
  assert.deepEqual(manifest.contentTools.prewarmedProjectDependencies, []);
});

test('PR1 has no Azure image or VMSS deployment wiring', async () => {
  const [runnerBicep, pilotBicep] = await Promise.all([
    readFile(new URL('infra/ci-runner/runner.bicep', repositoryRoot), 'utf8'),
    readFile(new URL('infra/ci-runner/pilot.bicep', repositoryRoot), 'utf8'),
  ]);
  for (const template of [runnerBicep, pilotBicep]) {
    assert.doesNotMatch(template, /toolchain-manifest|runner-image-evidence|galleryImage/i);
  }
});

test('timing evidence is traceable and does not invent immutable VM boot data', () => {
  assert.equal(evidence.currentRunnerColdAdmission.seconds, 3);
  assert.equal(evidence.estimatedAvoidedInstallSeconds.runnerHealthColdPath, 102);
  assert.equal(evidence.immutableVmBootColdStart.status, 'not-measured');
  assert.match(evidence.immutableVmBootColdStart.reason, /does not build or deploy/i);
});
