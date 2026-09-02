import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const supportedDirectoryObjectTypes = new Set([
  '#microsoft.graph.administrativeUnit',
  '#microsoft.graph.directoryRole',
  '#microsoft.graph.group',
]);

function requireUuid(value, label) {
  if (
    typeof value !== 'string' ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
      value,
    )
  ) {
    throw new Error(`${label} must be a UUID`);
  }
  return value.toLowerCase();
}

function initialUrl(principalId) {
  return (
    `https://graph.microsoft.com/v1.0/servicePrincipals/${principalId}/` +
    'transitiveMemberOf?$select=id&$top=999'
  );
}

export function validateGroupPageUrl(
  value,
  principalId,
  requireSkipToken = false,
) {
  let url;
  try {
    url = new URL(value);
  } catch {
    throw new Error('group membership nextLink is not a valid URL');
  }
  const expectedPath =
    `/v1.0/servicePrincipals/${principalId}/` +
    'transitiveMemberOf';
  const selectValues = url.searchParams.getAll('$select');
  const topValues = url.searchParams.getAll('$top');
  const skipTokenValues = url.searchParams.getAll('$skiptoken');
  if (
    url.protocol !== 'https:' ||
    url.hostname.toLowerCase() !== 'graph.microsoft.com' ||
    url.port ||
    url.username ||
    url.password ||
    url.hash ||
    url.pathname.toLowerCase() !== expectedPath.toLowerCase() ||
    selectValues.length !== 1 ||
    selectValues[0] !== 'id' ||
    topValues.length !== 1 ||
    topValues[0] !== '999' ||
    skipTokenValues.length !== (requireSkipToken ? 1 : 0) ||
    (requireSkipToken && skipTokenValues[0] === '')
  ) {
    throw new Error('group membership nextLink escapes the approved Graph query');
  }
  const allowedQueryFields = new Set(['$select', '$top', '$skiptoken']);
  for (const key of url.searchParams.keys()) {
    if (!allowedQueryFields.has(key)) {
      throw new Error('group membership nextLink contains an unexpected query field');
    }
  }
  return url.href;
}

export async function collectTransitiveGroupIds({ principalId, fetchPage }) {
  const normalizedPrincipalId = requireUuid(principalId, 'legacy principal ID');
  const groupIds = new Set();
  const visitedUrls = new Set();
  let url = validateGroupPageUrl(
    initialUrl(normalizedPrincipalId),
    normalizedPrincipalId,
  );
  while (url) {
    if (visitedUrls.has(url)) {
      throw new Error('group membership pagination contains a nextLink cycle');
    }
    visitedUrls.add(url);
    const page = await fetchPage(url);
    if (!page || !Array.isArray(page.value)) {
      throw new Error('group membership response has no value array');
    }
    for (const directoryObject of page.value) {
      const objectKeys =
        directoryObject &&
        typeof directoryObject === 'object' &&
        !Array.isArray(directoryObject)
          ? Object.keys(directoryObject).sort()
          : [];
      if (
        !directoryObject ||
        typeof directoryObject !== 'object' ||
        Array.isArray(directoryObject) ||
        JSON.stringify(objectKeys) !==
          JSON.stringify(['@odata.type', 'id']) ||
        !supportedDirectoryObjectTypes.has(directoryObject['@odata.type'])
      ) {
        throw new Error('group membership response has missing or extra fields');
      }
      const objectId = requireUuid(
        directoryObject.id,
        'transitive directory object ID',
      );
      if (directoryObject['@odata.type'] !== '#microsoft.graph.group') {
        continue;
      }
      if (objectId === normalizedPrincipalId || groupIds.has(objectId)) {
        throw new Error('group membership response contains a duplicate identity');
      }
      groupIds.add(objectId);
    }
    const nextLink = page['@odata.nextLink'] ?? page.nextLink ?? '';
    url = nextLink
      ? validateGroupPageUrl(nextLink, normalizedPrincipalId, true)
      : '';
  }
  return [...groupIds].sort();
}

async function main() {
  const [outputPath, principalId, ...extra] = process.argv.slice(2);
  if (!outputPath || !principalId || extra.length !== 0) {
    throw new Error(
      'Usage: collect-transitive-groups.mjs <output.json> <principal-id>',
    );
  }
  const groupIds = await collectTransitiveGroupIds({
    principalId,
    fetchPage: (url) =>
      JSON.parse(
        execFileSync(
          'az',
          ['rest', '--method', 'get', '--url', url, '--output', 'json'],
          { encoding: 'utf8' },
        ),
      ),
  });
  fs.writeFileSync(path.resolve(outputPath), JSON.stringify(groupIds), {
    mode: 0o600,
  });
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  await main();
}
