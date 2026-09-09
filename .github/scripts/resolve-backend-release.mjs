import fs from 'node:fs';
import process from 'node:process';

const canonicalApiUrl = 'https://api.github.com';
const canonicalRepository = 'gchambaud_microsoft/Certigo';
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
  const token = process.env.GITHUB_TOKEN;
  const apiUrl = process.env.GITHUB_API_URL;
  const repository = process.env.GITHUB_REPOSITORY;
  if (
    !token
    || apiUrl !== canonicalApiUrl
    || repository !== canonicalRepository
  ) {
    fail('Canonical GITHUB_TOKEN, GITHUB_API_URL and GITHUB_REPOSITORY are required.');
  }
  const response = await fetch(
    `${canonicalApiUrl}/repos/${canonicalRepository}/actions/runs/${sourceRunId}`,
    {
      headers: {
        Accept: 'application/vnd.github+json',
        Authorization: `Bearer ${token}`,
        'X-GitHub-Api-Version': '2022-11-28',
      },
    },
  );
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

  const sourceKind = process.env.SOURCE_RUN_KIND ?? 'release';
  const expected = {
    build: {
      path: '.github/workflows/ci-backend.yml',
      event: 'push',
      label: 'successful main backend CI',
    },
    release: {
      path: '.github/workflows/cd-backend.yml',
      event: 'repository_dispatch',
      label: 'successful explicit backend release',
    },
  }[sourceKind];
  if (!expected) {
    fail('SOURCE_RUN_KIND must be build or release.');
  }

  const metadata = await loadRunMetadata(sourceRunId);
  const repository = process.env.GITHUB_REPOSITORY;
  const errors = [];
  if (metadata.repository?.full_name !== repository) {
    errors.push('repository');
  }
  if (metadata.path !== expected.path) {
    errors.push('workflow path');
  }
  if (metadata.event !== expected.event || metadata.head_branch !== 'main') {
    errors.push(`${expected.label} provenance`);
  }
  if (metadata.conclusion !== 'success') {
    errors.push('successful conclusion');
  }
  if (!shaPattern.test(metadata.head_sha ?? '')) {
    errors.push('commit SHA');
  }
  if (!Number.isSafeInteger(metadata.run_attempt) || metadata.run_attempt < 1) {
    errors.push('run attempt');
  }
  if (errors.length > 0) {
    fail(`Source workflow run ${sourceRunId} failed validation: ${errors.join(', ')}.`);
  }
  writeOutput('commit-sha', metadata.head_sha);
  writeOutput('run-attempt', String(metadata.run_attempt));
}

try {
  await main();
} catch (error) {
  console.error(`::error::${error.message}`);
  process.exitCode = 1;
}
