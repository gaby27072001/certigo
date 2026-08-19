#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const absoluteUtcTimestamp = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/;
const guidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
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

function validateGuid(value, name) {
  if (!guidPattern.test(value)) {
    throw new Error(`${name} must be a canonical Entra GUID.`);
  }
}

function validateAccountDeletionIdentityConfiguration({
  environment,
  entraGraphTenantId,
  entraGraphClientId,
  entraGraphClientSecret,
  entraReauthAudience,
}) {
  const values = [
    entraGraphTenantId,
    entraGraphClientId,
    entraGraphClientSecret,
    entraReauthAudience,
  ].map((value) => (typeof value === 'string' ? value : ''));
  if (environment === 'dev') {
    return null;
  }
  if (values.some((value) => value !== value.trim())) {
    throw new Error('Account deletion Entra configuration must not contain surrounding whitespace.');
  }
  const configured = values.filter((value) => value.length > 0).length;
  if (configured !== values.length) {
    throw new Error(
      'ENTRA_GRAPH_TENANT_ID, ENTRA_GRAPH_CLIENT_ID, '
      + 'ENTRA_GRAPH_CLIENT_SECRET and ENTRA_REAUTH_AUDIENCE '
      + 'are required for staging and production.',
    );
  }
  validateGuid(values[0], 'ENTRA_GRAPH_TENANT_ID');
  validateGuid(values[1], 'ENTRA_GRAPH_CLIENT_ID');
  validateGuid(values[3], 'ENTRA_REAUTH_AUDIENCE');
  return {
    entraGraphTenantId: values[0],
    entraGraphClientId: values[1],
    entraGraphClientSecret: values[2],
    entraReauthAudience: values[3],
  };
}

export function writeSecureParameters({
  environment,
  alertEmail,
  jwtSigningKey,
  jwtSigningKeyExpiresOn,
  jwtPreviousSigningKey,
  jwtPreviousSigningKeyExpiresOn,
  entraGraphTenantId,
  entraGraphClientId,
  entraGraphClientSecret,
  entraReauthAudience,
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
  const accountDeletionIdentityConfiguration =
    validateAccountDeletionIdentityConfiguration({
      environment,
      entraGraphTenantId,
      entraGraphClientId,
      entraGraphClientSecret,
      entraReauthAudience,
    });

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
  if (accountDeletionIdentityConfiguration !== null) {
    compiled.parameters.entraGraphTenantId = {
      value: accountDeletionIdentityConfiguration.entraGraphTenantId,
    };
    compiled.parameters.entraGraphClientId = {
      value: accountDeletionIdentityConfiguration.entraGraphClientId,
    };
    compiled.parameters.entraGraphClientSecret = {
      value: accountDeletionIdentityConfiguration.entraGraphClientSecret,
    };
    compiled.parameters.entraReauthAudience = {
      value: accountDeletionIdentityConfiguration.entraReauthAudience,
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
      entraGraphTenantId: process.env.ENTRA_GRAPH_TENANT_ID,
      entraGraphClientId: process.env.ENTRA_GRAPH_CLIENT_ID,
      entraGraphClientSecret: process.env.ENTRA_GRAPH_CLIENT_SECRET,
      entraReauthAudience: process.env.ENTRA_REAUTH_AUDIENCE,
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
