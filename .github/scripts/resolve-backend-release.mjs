import fs from 'node:fs';
import process from 'node:process';

const shaPattern = /^[0-9a-f]{40}$/;

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

async function loadRunMetadata(sourceRunId) {
  if (process.env.SOURCE_RUN_METADATA_FILE) {
    return JSON.parse(fs.readFileSync(process.env.SOURCE_RUN_METADATA_FILE, 'utf8'));
  }
  const token = process.env.GITHUB_TOKEN;
  const apiUrl = process.env.GITHUB_API_URL;
  const repository = process.env.GITHUB_REPOSITORY;
  if (!token || !apiUrl || !repository) {
    fail('GITHUB_TOKEN, GITHUB_API_URL and GITHUB_REPOSITORY are required.');
  }
  const response = await fetch(`${apiUrl}/repos/${repository}/actions/runs/${sourceRunId}`, {
    headers: {
      Accept: 'application/vnd.github+json',
      Authorization: `Bearer ${token}`,
      'X-GitHub-Api-Version': '2022-11-28',
    },
  });
  if (!response.ok) {
    fail(`Cannot resolve source workflow run ${sourceRunId}: GitHub returned ${response.status}.`);
  }
  return response.json();
}

async function main() {
  const sourceRunId = process.env.SOURCE_RUN_ID ?? '';
  if (!/^[1-9][0-9]{0,19}$/.test(sourceRunId)) {
    fail('SOURCE_RUN_ID must be a positive GitHub Actions run id.');
  }

  if (
    sourceRunId === process.env.GITHUB_RUN_ID
    && process.env.GITHUB_EVENT_NAME === 'push'
    && process.env.GITHUB_REF === 'refs/heads/main'
  ) {
    if (!shaPattern.test(process.env.GITHUB_SHA ?? '')) {
      fail('GITHUB_SHA must be a lowercase 40-character Git SHA.');
    }
    writeOutput('commit-sha', process.env.GITHUB_SHA);
    return;
  }

  const metadata = await loadRunMetadata(sourceRunId);
  const repository = process.env.GITHUB_REPOSITORY;
  const errors = [];
  if (metadata.repository?.full_name !== repository) {
    errors.push('repository');
  }
  if (metadata.path !== '.github/workflows/cd-backend.yml') {
    errors.push('workflow path');
  }
  if (metadata.event !== 'push' || metadata.head_branch !== 'main') {
    errors.push('main push provenance');
  }
  if (metadata.conclusion !== 'success') {
    errors.push('successful conclusion');
  }
  if (!shaPattern.test(metadata.head_sha ?? '')) {
    errors.push('commit SHA');
  }
  if (errors.length > 0) {
    fail(`Source workflow run ${sourceRunId} failed validation: ${errors.join(', ')}.`);
  }
  writeOutput('commit-sha', metadata.head_sha);
}

try {
  await main();
} catch (error) {
  console.error(`::error::${error.message}`);
  process.exitCode = 1;
}
