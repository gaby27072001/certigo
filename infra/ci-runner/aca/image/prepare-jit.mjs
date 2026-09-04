#!/usr/bin/env node

import {
  createSign,
  randomUUID,
} from 'node:crypto';
import {
  chmod,
  mkdir,
  writeFile,
} from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const githubApiVersion = '2022-11-28';
const requiredRunnerLabels = Object.freeze([
  'self-hosted',
  'Linux',
  'X64',
  'certigo-pr-aca',
]);

function required(name, value) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new Error(`${name} is required`);
  }
  return value.trim();
}

function numeric(name, value) {
  const normalized = required(name, value);
  if (!/^[1-9][0-9]*$/.test(normalized)) {
    throw new Error(`${name} must be a positive integer`);
  }
  return normalized;
}

function base64UrlJson(value) {
  return Buffer.from(JSON.stringify(value)).toString('base64url');
}

export function createAppJwt(appId, privateKey, nowSeconds = Math.floor(Date.now() / 1000)) {
  const header = base64UrlJson({ alg: 'RS256', typ: 'JWT' });
  const payload = base64UrlJson({
    iat: nowSeconds - 60,
    exp: nowSeconds + 540,
    iss: numeric('GITHUB_APP_ID', appId),
  });
  const unsigned = `${header}.${payload}`;
  const signer = createSign('RSA-SHA256');
  signer.update(unsigned);
  signer.end();
  const signature = signer.sign(privateKey.replaceAll('\\n', '\n'), 'base64url');
  return `${unsigned}.${signature}`;
}

async function githubRequest(fetchImpl, url, authorization, options = {}) {
  const response = await fetchImpl(url, {
    ...options,
    headers: {
      accept: 'application/vnd.github+json',
      authorization,
      'content-type': 'application/json',
      'x-github-api-version': githubApiVersion,
      ...options.headers,
    },
  });
  if (!response.ok) {
    const requestId = response.headers.get('x-github-request-id') ?? 'unavailable';
    throw new Error(`GitHub API ${response.status} (${requestId}) for ${new URL(url).pathname}`);
  }
  return response.json();
}

export async function requestJitConfiguration(config, fetchImpl = fetch) {
  const apiUrl = new URL(required('GITHUB_API_URL', config.apiUrl));
  if (apiUrl.protocol !== 'https:' || apiUrl.origin !== 'https://api.github.com') {
    throw new Error('GITHUB_API_URL must be exactly https://api.github.com');
  }

  const owner = required('GITHUB_OWNER', config.owner);
  const repository = required('GITHUB_REPOSITORY', config.repository);
  const installationId = numeric(
    'GITHUB_APP_INSTALLATION_ID',
    config.installationId,
  );
  const runnerGroupId = Number(numeric('RUNNER_GROUP_ID', config.runnerGroupId));
  const runnerLabel = required('RUNNER_LABEL', config.runnerLabel);
  if (runnerLabel !== 'certigo-pr-aca') {
    throw new Error('RUNNER_LABEL must be exactly certigo-pr-aca');
  }

  const appJwt = createAppJwt(config.appId, required(
    'GITHUB_APP_PRIVATE_KEY',
    config.privateKey,
  ));
  const installation = await githubRequest(
    fetchImpl,
    new URL(`/app/installations/${installationId}/access_tokens`, apiUrl),
    `Bearer ${appJwt}`,
    {
      method: 'POST',
      body: JSON.stringify({
        repositories: [repository],
        permissions: {
          actions: 'read',
          administration: 'write',
        },
      }),
    },
  );
  let installationToken = required('installation token', installation.token);
  const runnerName = `certigo-aca-${randomUUID().replaceAll('-', '').slice(0, 16)}`;

  try {
    const jit = await githubRequest(
      fetchImpl,
      new URL(
        `/repos/${encodeURIComponent(owner)}/${encodeURIComponent(repository)}/actions/runners/generate-jitconfig`,
        apiUrl,
      ),
      `Bearer ${installationToken}`,
      {
        method: 'POST',
        body: JSON.stringify({
          name: runnerName,
          runner_group_id: runnerGroupId,
          labels: requiredRunnerLabels,
          work_folder: '_work',
        }),
      },
    );
    if (jit.runner?.ephemeral !== true) {
      throw new Error('GitHub did not create an ephemeral JIT runner');
    }
    const responseLabels = new Set(
      (jit.runner.labels ?? []).map((label) => label.name),
    );
    if (
      responseLabels.size !== requiredRunnerLabels.length
      || !requiredRunnerLabels.every((label) => responseLabels.has(label))
      || responseLabels.has('certigo-pr')
      || responseLabels.has('certigo-trusted')
    ) {
      throw new Error('GitHub returned a runner outside the certigo-pr-aca trust boundary');
    }
    return {
      encodedJitConfig: required('encoded_jit_config', jit.encoded_jit_config),
      runnerId: jit.runner.id,
      runnerName,
    };
  } finally {
    installationToken = '';
  }
}

export async function main(environment = process.env) {
  const jitPath = path.resolve(required('JIT_CONFIG_PATH', environment.JIT_CONFIG_PATH));
  const result = await requestJitConfiguration({
    apiUrl: environment.GITHUB_API_URL,
    owner: environment.GITHUB_OWNER,
    repository: environment.GITHUB_REPOSITORY,
    appId: environment.GITHUB_APP_ID,
    installationId: environment.GITHUB_APP_INSTALLATION_ID,
    privateKey: environment.GITHUB_APP_PRIVATE_KEY,
    runnerGroupId: environment.RUNNER_GROUP_ID,
    runnerLabel: environment.RUNNER_LABEL,
  });

  await mkdir(path.dirname(jitPath), { recursive: true, mode: 0o700 });
  await writeFile(jitPath, result.encodedJitConfig, {
    encoding: 'utf8',
    flag: 'wx',
    mode: 0o600,
  });
  await chmod(jitPath, 0o600);
  console.log(JSON.stringify({
    event: 'jit_config_prepared',
    runnerId: result.runnerId,
    runnerName: result.runnerName,
    label: 'certigo-pr-aca',
  }));
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(`JIT preparation failed: ${error.message}`);
    process.exitCode = 1;
  });
}
