#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { validatePublicDomainConfiguration } from './public-domain-contract.mjs';

const absoluteUtcTimestamp = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/;
const guidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const alertEmailPattern =
  /^[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$/;
const blobEndpointPattern = /^https:\/\/[a-z0-9]{3,24}\.blob\.core\.windows\.net\/$/;
const containerNamePattern = /^[a-z0-9](?:[a-z0-9-]{1,61}[a-z0-9])$/;
const readerResourceIdPattern =
  /^\/subscriptions\/[0-9a-f-]{36}\/resourceGroups\/[^/]+\/providers\/Microsoft\.ManagedIdentity\/userAssignedIdentities\/[^/]+$/i;
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
  enabled,
  environment,
  entraGraphTenantId,
  entraGraphClientId,
  entraGraphClientSecret,
  entraGraphClientSecretExpiresOn,
  entraReauthAudience,
  now,
}) {
  const values = [
    entraGraphTenantId,
    entraGraphClientId,
    entraGraphClientSecret,
    entraGraphClientSecretExpiresOn,
    entraReauthAudience,
  ].map((value) => (typeof value === 'string' ? value : ''));
  if (!enabled || environment === 'dev') {
    return null;
  }
  if (values.some((value) => value !== value.trim())) {
    throw new Error('Account deletion Entra configuration must not contain surrounding whitespace.');
  }
  const configured = values.filter((value) => value.length > 0).length;
  if (configured !== values.length) {
    throw new Error(
      'ENTRA_GRAPH_TENANT_ID, ENTRA_GRAPH_CLIENT_ID, '
      + 'ENTRA_GRAPH_CLIENT_SECRET, ENTRA_GRAPH_CLIENT_SECRET_EXPIRES_ON '
      + 'and ENTRA_REAUTH_AUDIENCE '
      + 'are required for staging and production.',
    );
  }
  validateGuid(values[0], 'ENTRA_GRAPH_TENANT_ID');
  validateGuid(values[1], 'ENTRA_GRAPH_CLIENT_ID');
  if (
    !absoluteUtcTimestamp.test(values[3])
    || !Number.isFinite(Date.parse(values[3]))
    || Date.parse(values[3]) <= now.getTime()
  ) {
    throw new Error(
      'ENTRA_GRAPH_CLIENT_SECRET_EXPIRES_ON must be a future absolute UTC timestamp.',
    );
  }
  validateGuid(values[4], 'ENTRA_REAUTH_AUDIENCE');
  return {
    entraGraphTenantId: values[0],
    entraGraphClientId: values[1],
    entraGraphClientSecret: values[2],
    entraGraphClientSecretExpiresOn: values[3],
    entraReauthAudience: values[4],
  };
}

function validateContentConfiguration({
  blobEndpoint,
  readerClientId,
  readerResourceId,
  descriptorContainer,
  publicContainer,
  privateContainer,
}) {
  const values = [
    blobEndpoint,
    readerClientId,
    readerResourceId,
    descriptorContainer,
    publicContainer,
    privateContainer,
  ].map((value) => (typeof value === 'string' ? value : ''));
  if (values.every((value) => value.length === 0)) {
    return null;
  }
  if (values.some((value) => value.length === 0 || value !== value.trim())) {
    // The names are listed in the same order as `values` above. Naming which side of the
    // all-or-nothing rule each value fell on is not cosmetic: the usual cause is a single value
    // defined at REPOSITORY scope, which every environment inherits, so an environment that never
    // configured content still reads a partial set. Without that hint the reader has no path from
    // this message back to the cause.
    const names = [
      'AZURE_BLOB_ENDPOINT',
      'AZURE_CONTENT_READER_CLIENT_ID',
      'AZURE_CONTENT_READER_RESOURCE_ID',
      'AZURE_DESCRIPTOR_CONTAINER',
      'AZURE_PUBLIC_CONTAINER',
      'AZURE_PRIVATE_CONTAINER',
    ];
    const configured = names.filter((_, index) => values[index].length > 0);
    const missing = names.filter((_, index) => values[index].length === 0);
    const untrimmed = names.filter(
      (_, index) => values[index].length > 0 && values[index] !== values[index].trim(),
    );
    const details = [
      `Configured (${configured.length} of 6): ${configured.join(', ') || 'none'}.`,
      `Missing: ${missing.join(', ') || 'none'}.`,
    ];
    if (untrimmed.length > 0) {
      details.push(`Set but padded with whitespace: ${untrimmed.join(', ')}.`);
    }
    details.push(
      'Either configure all six for this environment or clear all six; clearing all six is the'
      + ' safe default and leaves the deployment on legacy content.',
      'Note that repository-scope Actions variables are visible to EVERY environment, so a value'
      + ' defined at repository scope counts as configured here even if this environment never set'
      + ' it. Check repository scope as well as this environment before concluding a value is unset.',
    );
    throw new Error(
      `All immutable content outputs from PR #290 must be configured together without surrounding whitespace. ${details.join(' ')}`,
    );
  }
  if (!blobEndpointPattern.test(values[0])) {
    throw new Error('AZURE_BLOB_ENDPOINT must be a canonical Azure Blob endpoint ending in /.');
  }
  validateGuid(values[1], 'AZURE_CONTENT_READER_CLIENT_ID');
  if (!readerResourceIdPattern.test(values[2])) {
    throw new Error('AZURE_CONTENT_READER_RESOURCE_ID must identify a user-assigned managed identity.');
  }
  for (const [name, value] of [
    ['AZURE_DESCRIPTOR_CONTAINER', values[3]],
    ['AZURE_PUBLIC_CONTAINER', values[4]],
    ['AZURE_PRIVATE_CONTAINER', values[5]],
  ]) {
    if (!containerNamePattern.test(value)) {
      throw new Error(`${name} must be a canonical Azure Blob container name.`);
    }
  }
  return {
    contentBlobEndpoint: values[0],
    contentReaderClientId: values[1],
    contentReaderResourceId: values[2],
    contentDescriptorContainerName: values[3],
    contentPublicContainerName: values[4],
    contentPrivateContainerName: values[5],
  };
}

function validateContentRepositoryMode(value, contentConfiguration) {
  const mode = typeof value === 'string' ? value : '';
  if (mode.length === 0) {
    return null;
  }
  if (!['legacy', 'versioned'].includes(mode)) {
    throw new Error('CONTENT_REPOSITORY_MODE must be legacy or versioned.');
  }
  if (mode === 'versioned' && contentConfiguration === null) {
    throw new Error('CONTENT_REPOSITORY_MODE=versioned requires the complete PR #290 outputs.');
  }
  return mode;
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
  entraGraphClientSecretExpiresOn,
  entraReauthAudience,
  publicWebOrigin,
  publicDomainVerified,
  appleCiamDomainReconfigured,
  contentBlobEndpoint,
  contentReaderClientId,
  contentReaderResourceId,
  contentDescriptorContainerName,
  contentPublicContainerName,
  contentPrivateContainerName,
  contentRepositoryMode,
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
  const validatedAlertEmail = validateAlertEmail(alertEmail, environment);
  const accountDeletionIdentityConfiguration =
    validateAccountDeletionIdentityConfiguration({
      enabled: compiled.parameters.accountDeletionEnabled?.value === true,
      environment,
      entraGraphTenantId,
      entraGraphClientId,
      entraGraphClientSecret,
      entraGraphClientSecretExpiresOn,
      entraReauthAudience,
      now,
    });
  const publicDomainConfiguration = validatePublicDomainConfiguration({
    environment,
    feature: 'infrastructure',
    publicWebOrigin,
    publicDomainVerified,
    appleCiamDomainReconfigured,
    activationRequested: environment !== 'dev',
  });
  const contentConfiguration = validateContentConfiguration({
    blobEndpoint: contentBlobEndpoint,
    readerClientId: contentReaderClientId,
    readerResourceId: contentReaderResourceId,
    descriptorContainer: contentDescriptorContainerName,
    publicContainer: contentPublicContainerName,
    privateContainer: contentPrivateContainerName,
  });
  const validatedContentRepositoryMode = validateContentRepositoryMode(
    contentRepositoryMode,
    contentConfiguration,
  );

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
  compiled.parameters.publicWebOrigin = {
    value: publicDomainConfiguration.publicWebOrigin,
  };
  compiled.parameters.publicDomainVerified = {
    value: publicDomainConfiguration.publicDomainVerified,
  };
  compiled.parameters.appleCiamDomainReconfigured = {
    value: publicDomainConfiguration.appleCiamDomainReconfigured,
  };

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
    compiled.parameters.entraGraphClientSecretExpiresOn = {
      value: accountDeletionIdentityConfiguration.entraGraphClientSecretExpiresOn,
    };
    compiled.parameters.entraReauthAudience = {
      value: accountDeletionIdentityConfiguration.entraReauthAudience,
    };
  }
  if (contentConfiguration !== null) {
    for (const [name, value] of Object.entries(contentConfiguration)) {
      compiled.parameters[name] = { value };
    }
    if (validatedContentRepositoryMode !== null) {
      compiled.parameters.contentRepositoryMode = {
        value: validatedContentRepositoryMode,
      };
    }
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
      entraGraphClientSecretExpiresOn:
        process.env.ENTRA_GRAPH_CLIENT_SECRET_EXPIRES_ON,
      entraReauthAudience: process.env.ENTRA_REAUTH_AUDIENCE,
      publicWebOrigin: process.env.PUBLIC_WEB_ORIGIN,
      publicDomainVerified: process.env.PUBLIC_DOMAIN_VERIFIED,
      appleCiamDomainReconfigured: process.env.APPLE_CIAM_DOMAIN_RECONFIGURED,
      contentBlobEndpoint: process.env.AZURE_BLOB_ENDPOINT,
      contentReaderClientId: process.env.AZURE_CONTENT_READER_CLIENT_ID,
      contentReaderResourceId: process.env.AZURE_CONTENT_READER_RESOURCE_ID,
      contentDescriptorContainerName: process.env.AZURE_DESCRIPTOR_CONTAINER,
      contentPublicContainerName: process.env.AZURE_PUBLIC_CONTAINER,
      contentPrivateContainerName: process.env.AZURE_PRIVATE_CONTAINER,
      contentRepositoryMode: process.env.CONTENT_REPOSITORY_MODE,
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
