#!/usr/bin/env node

import { pathToFileURL } from 'node:url';

const placeholderPattern = /(placeholder|example|change-?me|todo|microlingo)/i;
const guidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const zeroGuid = '00000000-0000-0000-0000-000000000000';
const productionApiHostPattern =
  /^func-certigo-prod-[a-z0-9]{13}\.azurewebsites\.net$/;

// Seule autorité à hôte nommé acceptée en plus de la forme GUID. Elle est écrite
// en dur et n'est jamais lue d'une variable : le Services ID « Sign in with
// Apple » n'enregistre que certigoapp.ciamlogin.com comme URL de retour, et Apple
// refuse celle de l'hôte GUID (« Invalid web redirect url », mesuré le
// 2026-09-27). Les jetons obtenus par cet hôte portent le même issuer, en forme
// GUID, que le document de découverte, seule valeur que comparent AppAuth et le
// backend (mesuré le 2026-10-04, voir docs/RELEASE_MOBILE.md §2.3).
export const pinnedCiamTenantId = 'af721be8-5901-422a-b299-b9c57847b968';
export const pinnedNamedAuthorityHost = 'certigoapp.ciamlogin.com';
export const pinnedNamedAuthority =
  `https://${pinnedNamedAuthorityHost}/${pinnedCiamTenantId}/v2.0`;

function readArguments(argv) {
  const values = new Map();
  for (let index = 0; index < argv.length; index += 2) {
    const name = argv[index];
    const value = argv[index + 1];
    if (!name?.startsWith('--') || value === undefined) {
      throw new Error('Expected named arguments with values.');
    }
    values.set(name.slice(2), value);
  }
  return values;
}

function parseHttpsUrl(value, label) {
  let url;
  try {
    url = new URL(value);
  } catch {
    throw new Error(`${label} must be a valid HTTPS URL.`);
  }
  if (
    url.protocol !== 'https:'
    || url.username
    || url.password
    || url.search
    || url.hash
  ) {
    throw new Error(`${label} must be a plain HTTPS URL without credentials, query or fragment.`);
  }
  return url;
}

// Vrai seulement pour l'autorité nommée épinglée, sous sa forme canonique exacte.
// L'analyseur WHATWG efface sans bruit `:443`, les espaces autour, les segments
// `.`/`..`, les antislashs et la casse de l'hôte, et garde un `?` ou `#` vide :
// une valeur qui n'égale l'épingle qu'après normalisation est refusée, pas
// réparée. Les contrôles par composant documentent chaque exigence.
export function isPinnedNamedAuthority(value) {
  if (typeof value !== 'string') {
    return false;
  }
  let url;
  try {
    url = new URL(value);
  } catch {
    return false;
  }
  return url.protocol === 'https:'
    && url.username === ''
    && url.password === ''
    && url.port === ''
    && url.search === ''
    && url.hash === ''
    && url.hostname === pinnedNamedAuthorityHost
    && url.pathname === `/${pinnedCiamTenantId}/v2.0`
    && value === pinnedNamedAuthority;
}

export function validateMobileReleaseConfig(config) {
  const errors = [];

  if (config.certigoEnv !== 'prod') {
    errors.push('MOBILE_CERTIGO_ENV must be prod for every release build.');
  }

  try {
    const apiUrl = parseHttpsUrl(config.apiBaseUrl, 'MOBILE_API_BASE_URL');
    const host = apiUrl.hostname.toLowerCase();
    if (!/^\/api\/?$/.test(apiUrl.pathname)) {
      errors.push('MOBILE_API_BASE_URL must end with /api.');
    }
    if (
      placeholderPattern.test(config.apiBaseUrl)
      || host === 'localhost'
      || !productionApiHostPattern.test(host)
    ) {
      errors.push('MOBILE_API_BASE_URL must identify the production Certigo backend.');
    }
  } catch (error) {
    errors.push(error.message);
  }

  if (!guidPattern.test(config.entraClientId) || config.entraClientId === zeroGuid) {
    errors.push('MOBILE_ENTRA_CLIENT_ID must be a non-placeholder GUID.');
  }

  try {
    if (!isPinnedNamedAuthority(config.entraAuthority)) {
      const authority = parseHttpsUrl(config.entraAuthority, 'MOBILE_ENTRA_AUTHORITY');
      const authorityMatch = authority.pathname.match(
        /^\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\/v2\.0\/?$/i,
      );
      const authorityHostMatch = authority.hostname.match(
        /^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\.ciamlogin\.com$/i,
      );
      if (
        !authorityHostMatch
        || !authorityMatch
        || authorityMatch[1].toLowerCase() === zeroGuid
        || authorityHostMatch[1].toLowerCase() !== authorityMatch[1].toLowerCase()
        || placeholderPattern.test(config.entraAuthority)
      ) {
        errors.push(
          'MOBILE_ENTRA_AUTHORITY must use the matching canonical tenant GUID in its host and path, '
          + `or be exactly ${pinnedNamedAuthority}.`,
        );
      }
    }
  } catch (error) {
    errors.push(error.message);
  }

  const scopeMatch = config.entraApiScope.match(
    /^api:\/\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\/user_impersonation$/i,
  );
  if (
    !scopeMatch
    || scopeMatch[1].toLowerCase() === zeroGuid
    || placeholderPattern.test(config.entraApiScope)
  ) {
    errors.push(
      'MOBILE_ENTRA_API_SCOPE must be a non-placeholder api://<GUID>/user_impersonation scope.',
    );
  }

  return errors;
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const args = readArguments(process.argv.slice(2));
    const errors = validateMobileReleaseConfig({
      apiBaseUrl: args.get('api-base-url') ?? '',
      entraClientId: args.get('entra-client-id') ?? '',
      entraAuthority: args.get('entra-authority') ?? '',
      entraApiScope: args.get('entra-api-scope') ?? '',
      certigoEnv: args.get('certigo-env') ?? '',
    });
    if (errors.length > 0) {
      for (const error of errors) {
        console.error(`::error::${error}`);
      }
      process.exitCode = 1;
    }
  } catch (error) {
    console.error(`::error::${error.message}`);
    process.exitCode = 1;
  }
}
