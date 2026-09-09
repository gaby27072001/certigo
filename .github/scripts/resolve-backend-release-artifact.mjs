import fs from 'node:fs';
import process from 'node:process';

const canonicalRepository = 'gchambaud_microsoft/Certigo';
const artifactName = 'backend-release-bundle.tar';
const runIdPattern = /^[1-9][0-9]{0,19}$/;
const shaPattern = /^[0-9a-f]{40}$/;
const digestPattern = /^sha256:([0-9a-f]{64})$/;

function fail(message) {
  throw new Error(message);
}

function writeOutput(name, value) {
  if (process.env.GITHUB_OUTPUT) {
    fs.appendFileSync(process.env.GITHUB_OUTPUT, `${name}=${value}\n`, 'utf8');
  } else {
    console.log(`${name}=${value}`);
  }
}

async function loadArtifacts(runId) {
  const token = process.env.GITHUB_TOKEN;
  const apiUrl = process.env.GITHUB_API_URL;
  if (!token || apiUrl !== 'https://api.github.com') {
    fail('Canonical GITHUB_TOKEN and GITHUB_API_URL are required.');
  }
  const response = await fetch(
    `${apiUrl}/repos/${canonicalRepository}/actions/runs/${runId}/artifacts?per_page=100`,
    {
      headers: {
        Accept: 'application/vnd.github+json',
        Authorization: `Bearer ${token}`,
        'X-GitHub-Api-Version': '2022-11-28',
      },
    },
  );
  if (!response.ok) {
    fail(`Cannot resolve release artifact: GitHub returned ${response.status}.`);
  }
  return response.json();
}

async function main() {
  const repository = process.env.GITHUB_REPOSITORY ?? '';
  const runId = process.env.GITHUB_RUN_ID ?? '';
  const workflowSha = process.env.GITHUB_SHA ?? '';
  if (repository !== canonicalRepository) {
    fail('Release artifacts may only be resolved in the canonical repository.');
  }
  if (!runIdPattern.test(runId)) {
    fail('GITHUB_RUN_ID must be a positive GitHub Actions run id.');
  }
  if (!shaPattern.test(workflowSha)) {
    fail('GITHUB_SHA must be a lowercase 40-character Git SHA.');
  }

  const metadata = await loadArtifacts(runId);
  if (
    metadata?.total_count !== 1
    || !Array.isArray(metadata.artifacts)
    || metadata.artifacts.length !== 1
  ) {
    fail('Current workflow run must contain exactly one release artifact.');
  }
  const artifact = metadata.artifacts[0];
  const digestMatch = digestPattern.exec(artifact?.digest ?? '');
  if (
    !Number.isSafeInteger(artifact?.id)
    || artifact.id < 1
    || artifact.name !== artifactName
    || artifact.expired !== false
    || !Number.isSafeInteger(artifact.size_in_bytes)
    || artifact.size_in_bytes < 1
    || !digestMatch
    || artifact.workflow_run?.id !== Number(runId)
    || artifact.workflow_run?.head_branch !== 'main'
    || artifact.workflow_run?.head_sha !== workflowSha
  ) {
    fail('Release artifact metadata does not match the current canonical workflow run.');
  }

  writeOutput('artifact-id', String(artifact.id));
  writeOutput('artifact-digest', digestMatch[1]);
}

try {
  await main();
} catch (error) {
  console.error(`::error::${error.message}`);
  process.exitCode = 1;
}
