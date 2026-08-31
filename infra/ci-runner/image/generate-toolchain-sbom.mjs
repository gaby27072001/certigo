import { readFile, writeFile } from 'node:fs/promises';

const imageRoot = new URL('./', import.meta.url);
const sbomPath = new URL('toolchain-sbom.cdx.json', imageRoot);
const lock = await readFile(
  new URL('toolchain-requirements.lock', imageRoot),
  'utf8',
);
const current = JSON.parse(await readFile(sbomPath, 'utf8'));
const packages = [...lock.matchAll(/^([a-z0-9][a-z0-9._-]*)==([^\s\\]+)\s*\\/gim)]
  .map((match) => ({ name: match[1].toLowerCase(), version: match[2] }))
  .sort((left, right) => left.name.localeCompare(right.name));

if (packages.length === 0) {
  throw new Error('The Python lock did not contain any exact package versions.');
}

const nonPythonComponents = current.components.filter(
  (component) => !component.purl?.startsWith('pkg:pypi/'),
);
const pythonComponents = packages.map(({ name, version }) => ({
  type: name === 'pyyaml' ? 'library' : 'application',
  'bom-ref': `pkg:pypi/${name}@${version}`,
  name,
  version,
  purl: `pkg:pypi/${name}@${version}`,
}));
const pythonRefs = pythonComponents.map((component) => component['bom-ref']);
const dependencies = [
  {
    ref: `pkg:pypi/checkov@${
      packages.find((candidate) => candidate.name === 'checkov')?.version
    }`,
    dependsOn: pythonRefs.filter((ref) => !ref.startsWith('pkg:pypi/checkov@')),
  },
  ...pythonRefs
    .filter((ref) => !ref.startsWith('pkg:pypi/checkov@'))
    .map((ref) => ({ ref, dependsOn: [] })),
];
const generated = `${JSON.stringify(
  {
    ...current,
    components: [...nonPythonComponents, ...pythonComponents],
    dependencies,
  },
  null,
  2,
)}\n`;

if (process.argv[2] === '--check') {
  const existing = await readFile(sbomPath, 'utf8');
  if (existing !== generated) {
    throw new Error('toolchain-sbom.cdx.json is stale; regenerate it.');
  }
} else if (process.argv.length === 2) {
  await writeFile(sbomPath, generated, 'utf8');
} else {
  throw new Error('Usage: node generate-toolchain-sbom.mjs [--check]');
}
