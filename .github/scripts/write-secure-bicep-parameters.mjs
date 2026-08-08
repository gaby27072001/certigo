#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export function writeSecureParameters({
  environment,
  jwtSigningKey,
  inputFile,
  outputFile,
}) {
  if (!['dev', 'staging', 'prod'].includes(environment)) {
    throw new Error('Deployment environment must be dev, staging or prod.');
  }
  if (
    environment !== 'dev' &&
    (typeof jwtSigningKey !== 'string' || jwtSigningKey.trim().length === 0)
  ) {
    throw new Error('AUTH_JWT_SIGNING_KEY is required for staging and production.');
  }
  if (!inputFile || !outputFile) {
    throw new Error('Input and output deployment parameter file paths are required.');
  }

  const compiled = JSON.parse(fs.readFileSync(inputFile, 'utf8'));
  if (
    typeof compiled !== 'object' ||
    compiled === null ||
    typeof compiled.parameters !== 'object' ||
    compiled.parameters === null ||
    Array.isArray(compiled.parameters)
  ) {
    throw new Error('The compiled Bicep parameter document is invalid.');
  }
  if (environment !== 'dev') {
    compiled.parameters.authJwtSigningKey = {
      value: jwtSigningKey,
    };
  }

  fs.writeFileSync(
    outputFile,
    JSON.stringify(compiled),
    { encoding: 'utf8', mode: 0o600, flag: 'wx' },
  );
  return environment !== 'dev';
}

function main() {
  try {
    writeSecureParameters({
      environment: process.env.TARGET_ENV,
      jwtSigningKey: process.env.AUTH_JWT_SIGNING_KEY,
      inputFile: process.env.BASE_PARAMETERS_FILE,
      outputFile: process.env.AUTH_PARAMETERS_FILE,
    });
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main();
}
