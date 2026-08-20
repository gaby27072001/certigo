#!/usr/bin/env node

import { isIP } from 'node:net';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const featuresRequiringApple = new Set([
  'account-deletion-url',
  'apple-ciam',
  'infrastructure',
  'link-associations',
  'redirects',
]);

const placeholderHosts = new Set([
  'example.com',
  'example.net',
  'example.org',
  'localhost',
]);
const unownedLegacyHost = ['certigo', 'app'].join('.');

function explicitBoolean(value, name) {
  if (value === true || value === 'true') {
    return true;
  }
  if (value === false || value === 'false' || value === '' || value === undefined) {
    return false;
  }
  throw new Error(`${name} must be explicitly true or false.`);
}

function canonicalHttpsOrigin(value) {
  if (typeof value !== 'string' || value.length === 0) {
    throw new Error('PUBLIC_WEB_ORIGIN is required before public-domain activation.');
  }
  if (value !== value.trim() || /[\u0000-\u001f\u007f]/.test(value)) {
    throw new Error('PUBLIC_WEB_ORIGIN must not contain whitespace or control characters.');
  }

  let parsed;
  try {
    parsed = new URL(value);
  } catch {
    throw new Error('PUBLIC_WEB_ORIGIN must be a valid URL.');
  }
  if (
    parsed.protocol !== 'https:'
    || parsed.username.length > 0
    || parsed.password.length > 0
    || parsed.port.length > 0
    || parsed.pathname !== '/'
    || parsed.search.length > 0
    || parsed.hash.length > 0
    || parsed.origin !== value
  ) {
    throw new Error(
      'PUBLIC_WEB_ORIGIN must be a canonical HTTPS origin without credentials, port, path, query or fragment.',
    );
  }

  const host = parsed.hostname.toLowerCase();
  const isPlaceholder = placeholderHosts.has(host)
    || host.endsWith('.example')
    || host.endsWith('.invalid')
    || host.endsWith('.localhost')
    || host.endsWith('.test');
  const isUnownedLegacyHost = host === unownedLegacyHost
    || host.endsWith(`.${unownedLegacyHost}`);
  if (
    host !== parsed.hostname
    || host.endsWith('.')
    || !host.includes('.')
    || isIP(host) !== 0
    || isPlaceholder
    || isUnownedLegacyHost
  ) {
    throw new Error(
      'PUBLIC_WEB_ORIGIN must use a non-placeholder, publicly routable domain controlled by Certigo.',
    );
  }
  return parsed.origin;
}

export function validatePublicDomainConfiguration({
  environment,
  feature,
  publicWebOrigin,
  publicDomainVerified,
  appleCiamDomainReconfigured,
  activationRequested = true,
}) {
  if (!['dev', 'staging', 'prod'].includes(environment)) {
    throw new Error('Public-domain environment must be dev, staging or prod.');
  }
  if (
    feature !== 'legal-pages'
    && !featuresRequiringApple.has(feature)
  ) {
    throw new Error('Unknown public-domain feature.');
  }

  const verified = explicitBoolean(publicDomainVerified, 'PUBLIC_DOMAIN_VERIFIED');
  const appleReconfigured = explicitBoolean(
    appleCiamDomainReconfigured,
    'APPLE_CIAM_DOMAIN_RECONFIGURED',
  );
  const configuredOrigin = typeof publicWebOrigin === 'string' ? publicWebOrigin : '';
  const requested = environment !== 'dev' && (
    activationRequested
    || configuredOrigin.length > 0
    || verified
    || appleReconfigured
  );
  if (!requested) {
    return {
      appleCiamDomainReconfigured: false,
      publicDomainVerified: false,
      publicWebOrigin: '',
      ready: false,
    };
  }

  const origin = canonicalHttpsOrigin(configuredOrigin);
  if (!verified) {
    throw new Error('PUBLIC_DOMAIN_VERIFIED must be explicitly true before activation.');
  }
  if (featuresRequiringApple.has(feature) && !appleReconfigured) {
    throw new Error(
      'APPLE_CIAM_DOMAIN_RECONFIGURED must be explicitly true for this feature.',
    );
  }

  return {
    appleCiamDomainReconfigured: appleReconfigured,
    publicDomainVerified: true,
    publicWebOrigin: origin,
    ready: true,
  };
}

function main() {
  const [feature] = process.argv.slice(2);
  validatePublicDomainConfiguration({
    environment: process.env.TARGET_ENV || 'prod',
    feature,
    publicWebOrigin: process.env.PUBLIC_WEB_ORIGIN,
    publicDomainVerified: process.env.PUBLIC_DOMAIN_VERIFIED,
    appleCiamDomainReconfigured: process.env.APPLE_CIAM_DOMAIN_RECONFIGURED,
  });
  console.log(`Public-domain gate passed for ${feature}.`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    main();
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  }
}
