#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const absoluteUtcTimestamp = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/;
const alertEmailPattern =
  /^[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$/;
const refreshOverlapMilliseconds = (90 * 24 * 60 + 2) * 60 * 1000;

function requirePair(value, expiresOn, valueName, expiresOnName) {
  const hasValue = typeof value === 'string' && value.trim().length > 0;
  const hasExpiration = typeof expiresOn === 'string' && expiresOn.trim().length > 0;
  if (hasValue !== hasExpiration) {
    throw new Error(`${valueName} and ${expiresOnName} must be configured together.`);
  }
  if (hasExpiration && (
    !absoluteUtcTimestamp.test(expiresOn)
    || !Number.isFinite(Date.parse(expiresOn))
  )) {
    throw new Error(`${expiresOnName} must be an absolute UTC timestamp (YYYY-MM-DDTHH:mm:ssZ).`);
  }
  return hasValue;
}

function requireRefreshOverlap(expiresOn, name, now) {
  const expiration = Date.parse(expiresOn);
  if (expiration < now.getTime() + refreshOverlapMilliseconds) {
    throw new Error(`${name} must preserve at least the 90-day refresh lifetime plus 2 minutes.`);
  }
}

function validateAlertEmail(value, environment) {
  const email = typeof value === 'string' ? value : '';
  if (environment !== 'dev' && email.length === 0) {
    throw new Error('ALERT_EMAIL is required for staging and production.');
  }
  if (
    email.length > 0
    && (
      email.length > 254
      || email !== email.trim()
      || /[\u0000-\u001f\u007f]/.test(email)
      || !alertEmailPattern.test(email)
    )
  ) {
    throw new Error('ALERT_EMAIL must be a valid email address of at most 254 characters.');
  }
  return email;
}

export function writeSecureParameters({
  environment,
  alertEmail,
  jwtSigningKey,
  jwtSigningKeyExpiresOn,
  jwtPreviousSigningKey,
  jwtPreviousSigningKeyExpiresOn,
  inputFile,
  outputFile,
  now = new Date(),
}) {
  if (!['dev', 'staging', 'prod'].includes(environment)) {
    throw new Error('Deployment environment must be dev, staging or prod.');
  }
  if (!inputFile || !outputFile) {
    throw new Error('Input and output deployment parameter file paths are required.');
  }
  const validatedAlertEmail = validateAlertEmail(alertEmail, environment);

  const hasActiveKey = requirePair(
    jwtSigningKey,
    jwtSigningKeyExpiresOn,
    'AUTH_JWT_SIGNING_KEY',
    'AUTH_JWT_SIGNING_KEY_EXPIRES_ON',
  );
  if (environment !== 'dev' && !hasActiveKey) {
    throw new Error(
      'AUTH_JWT_SIGNING_KEY and AUTH_JWT_SIGNING_KEY_EXPIRES_ON are required for staging and production.',
    );
  }
  const hasPreviousKey = requirePair(
    jwtPreviousSigningKey,
    jwtPreviousSigningKeyExpiresOn,
    'AUTH_JWT_PREVIOUS_SIGNING_KEY',
    'AUTH_JWT_PREVIOUS_SIGNING_KEY_EXPIRES_ON',
  );
  if (hasActiveKey && hasPreviousKey && jwtSigningKey === jwtPreviousSigningKey) {
    throw new Error('The active and previous JWT signing keys must differ.');
  }

  const compiled = JSON.parse(fs.readFileSync(inputFile, 'utf8'));
  if (
    typeof compiled !== 'object'
    || compiled === null
    || typeof compiled.parameters !== 'object'
    || compiled.parameters === null
    || Array.isArray(compiled.parameters)
  ) {
    throw new Error('The compiled Bicep parameter document is invalid.');
  }

  const activeExpiration = hasActiveKey
    ? jwtSigningKeyExpiresOn
    : compiled.parameters.authJwtSigningKeyExpiresOn?.value;
  if (
    typeof activeExpiration !== 'string'
    || !absoluteUtcTimestamp.test(activeExpiration)
    || !Number.isFinite(Date.parse(activeExpiration))
  ) {
    throw new Error(
      'authJwtSigningKeyExpiresOn must be an absolute UTC timestamp (YYYY-MM-DDTHH:mm:ssZ).',
    );
  }
  requireRefreshOverlap(activeExpiration, 'AUTH_JWT_SIGNING_KEY_EXPIRES_ON', now);
  if (hasPreviousKey) {
    requireRefreshOverlap(
      jwtPreviousSigningKeyExpiresOn,
      'AUTH_JWT_PREVIOUS_SIGNING_KEY_EXPIRES_ON',
      now,
    );
  }
  if (validatedAlertEmail.length > 0) {
    compiled.parameters.alertEmail = { value: validatedAlertEmail };
  }

  if (hasActiveKey) {
    compiled.parameters.authJwtSigningKey = { value: jwtSigningKey };
    compiled.parameters.authJwtSigningKeyExpiresOn = { value: jwtSigningKeyExpiresOn };
  }
  if (hasPreviousKey) {
    compiled.parameters.authJwtPreviousSigningKey = { value: jwtPreviousSigningKey };
    compiled.parameters.authJwtPreviousSigningKeyExpiresOn = {
      value: jwtPreviousSigningKeyExpiresOn,
    };
  }

  fs.writeFileSync(
    outputFile,
    JSON.stringify(compiled),
    { encoding: 'utf8', mode: 0o600, flag: 'wx' },
  );
  return { hasActiveKey, hasPreviousKey };
}

function main() {
  try {
    writeSecureParameters({
      environment: process.env.TARGET_ENV,
      alertEmail: process.env.ALERT_EMAIL,
      jwtSigningKey: process.env.AUTH_JWT_SIGNING_KEY,
      jwtSigningKeyExpiresOn: process.env.AUTH_JWT_SIGNING_KEY_EXPIRES_ON,
      jwtPreviousSigningKey: process.env.AUTH_JWT_PREVIOUS_SIGNING_KEY,
      jwtPreviousSigningKeyExpiresOn:
        process.env.AUTH_JWT_PREVIOUS_SIGNING_KEY_EXPIRES_ON,
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
