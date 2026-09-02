import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const apiVersion = '2020-10-01';
const defaultResourceType = 'roleAssignmentScheduleInstances';
const allowedResourceTypes = new Set([
  defaultResourceType,
  'roleEligibilityScheduleInstances',
]);

function normalize(value) {
  return String(value ?? '').toLowerCase();
}

function requirePrincipalId(value) {
  if (
    typeof value !== 'string' ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
      value,
    )
  ) {
    throw new Error('role schedule principal ID must be a UUID');
  }
  return normalize(value);
}

function canonicalJson(value) {
  if (Array.isArray(value)) {
    return value.map(canonicalJson);
  }
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((key) => [key, canonicalJson(value[key])]),
    );
  }
  return value;
}

function requireResourceType(resourceType) {
  if (!allowedResourceTypes.has(resourceType)) {
    throw new Error('unsupported role schedule resource type');
  }
  return resourceType;
}

function defaultScopes(subscriptionId) {
  const subscription = `/subscriptions/${subscriptionId}`;
  return [
    subscription,
    `${subscription}/resourceGroups/rg-certigo-ci`,
    `${subscription}/resourceGroups/rg-certigo-dev`,
    `${subscription}/resourceGroups/rg-certigo-staging`,
    `${subscription}/resourceGroups/rg-certigo-prod`,
  ];
}

function requireScopes(subscriptionId, scopes) {
  if (!Array.isArray(scopes) || scopes.length === 0) {
    throw new Error('role schedule scopes must be a non-empty array');
  }
  const subscriptionScope = `/subscriptions/${subscriptionId}`.toLowerCase();
  const normalizedScopes = scopes.map((scope) => String(scope).toLowerCase());
  if (
    new Set(normalizedScopes).size !== normalizedScopes.length ||
    !normalizedScopes.includes(subscriptionScope) ||
    normalizedScopes.some(
      (scope) =>
        !(
          scope === subscriptionScope ||
          /^\/providers\/microsoft\.management\/managementgroups\/[^/]+$/.test(
            scope,
          ) ||
          new RegExp(
            `^${subscriptionScope}/resourcegroups/rg-certigo-(ci|dev|staging|prod)$`,
          ).test(scope)
        ),
    )
  ) {
    throw new Error('role schedule scopes escape the approved hierarchy');
  }
  return normalizedScopes;
}

function expectedPaths(subscriptionId, resourceType, scopes) {
  requireResourceType(resourceType);
  return new Set(
    requireScopes(subscriptionId, scopes).map(
      (scope) =>
        `${scope}/providers/Microsoft.Authorization/${resourceType}`.toLowerCase(),
    ),
  );
}

export function validateScheduleUrl(
  value,
  subscriptionId,
  principalId,
  requireSkipToken = false,
  expectedPath = null,
  resourceType = defaultResourceType,
  scopes = defaultScopes(subscriptionId),
) {
  let url;
  try {
    url = new URL(value);
  } catch {
    throw new Error('schedule nextLink is not a valid URL');
  }
  if (
    url.protocol !== 'https:' ||
    url.hostname.toLowerCase() !== 'management.azure.com' ||
    url.port ||
    url.username ||
    url.password ||
    url.hash ||
    !expectedPaths(subscriptionId, resourceType, scopes).has(
      url.pathname.toLowerCase(),
    ) ||
    (expectedPath !== null &&
      url.pathname.toLowerCase() !== expectedPath.toLowerCase())
  ) {
    throw new Error('schedule nextLink escapes the approved Azure endpoint');
  }
  const expectedFilter = `principalId eq '${principalId}'`;
  const apiVersionValues = url.searchParams.getAll('api-version');
  const filterValues = url.searchParams.getAll('$filter');
  const skipTokenValues = url.searchParams.getAll('$skiptoken');
  if (
    apiVersionValues.length !== 1 ||
    apiVersionValues[0] !== apiVersion ||
    filterValues.length !== 1 ||
    filterValues[0] !== expectedFilter ||
    skipTokenValues.length !== (requireSkipToken ? 1 : 0) ||
    (requireSkipToken && skipTokenValues[0] === '')
  ) {
    throw new Error('schedule nextLink changes the approved query');
  }
  const allowedQueryFields = new Set(['api-version', '$filter', '$skiptoken']);
  for (const key of url.searchParams.keys()) {
    if (!allowedQueryFields.has(key)) {
      throw new Error('schedule nextLink contains an unexpected query field');
    }
  }
  return url.href;
}

export function scheduleInstanceKey(schedule) {
  const properties = schedule?.properties ?? {};
  const values = [
    properties.principalId,
    properties.roleDefinitionId,
    properties.scope,
    schedule?.id,
  ].map(normalize);
  if (values.some((value) => value === '')) {
    throw new Error('schedule instance lacks its stable identity fields');
  }
  return values.join('|');
}

function scheduleFingerprint(schedule) {
  const properties = schedule.properties ?? {};
  return JSON.stringify(
    canonicalJson({
      id: normalize(schedule.id),
      principalId: normalize(properties.principalId),
      principalType: properties.principalType,
      roleDefinitionId: normalize(properties.roleDefinitionId),
      scope: normalize(properties.scope),
      roleAssignmentScheduleId: normalize(properties.roleAssignmentScheduleId),
      originRoleAssignmentId: normalize(properties.originRoleAssignmentId),
      roleEligibilityScheduleId: normalize(properties.roleEligibilityScheduleId),
      originRoleEligibilityScheduleId: normalize(
        properties.originRoleEligibilityScheduleId,
      ),
      startDateTime: properties.startDateTime,
      endDateTime: properties.endDateTime,
      assignmentType: properties.assignmentType,
      memberType: properties.memberType,
      status: properties.status,
      condition: properties.condition ?? null,
      conditionVersion: properties.conditionVersion ?? null,
    }),
  );
}

export function initialScheduleUrls(
  subscriptionId,
  principalId,
  resourceType = defaultResourceType,
  scopes = defaultScopes(subscriptionId),
) {
  const normalizedPrincipalId = requirePrincipalId(principalId);
  const filter = encodeURIComponent(
    `principalId eq '${normalizedPrincipalId}'`,
  );
  return [...expectedPaths(subscriptionId, resourceType, scopes)].map(
    (endpoint) =>
      `https://management.azure.com${endpoint}` +
      `?api-version=${apiVersion}&%24filter=${filter}`,
  );
}

export async function collectScheduleInstances({
  subscriptionId,
  principalId,
  fetchPage,
  resourceType = defaultResourceType,
  scopes = defaultScopes(subscriptionId),
}) {
  const normalizedPrincipalId = requirePrincipalId(principalId);
  const schedulesByKey = new Map();
  const keysById = new Map();
  const visitedUrls = new Set();
  for (const initialUrl of initialScheduleUrls(
    subscriptionId,
    normalizedPrincipalId,
    resourceType,
    scopes,
  )) {
    const chainPath = new URL(initialUrl).pathname;
    let url = validateScheduleUrl(
      initialUrl,
      subscriptionId,
      normalizedPrincipalId,
      false,
      null,
      resourceType,
      scopes,
    );
    while (url) {
      if (visitedUrls.has(url)) {
        throw new Error('schedule pagination contains a nextLink cycle');
      }
      visitedUrls.add(url);
      const page = await fetchPage(url);
      if (!page || !Array.isArray(page.value)) {
        throw new Error('schedule response has no value array');
      }
      for (const schedule of page.value) {
        if (
          normalize(schedule?.properties?.principalId) !== normalizedPrincipalId
        ) {
          throw new Error('schedule response escaped the requested principal');
        }
        const key = scheduleInstanceKey(schedule);
        const id = normalize(schedule.id);
        const existingKey = keysById.get(id);
        if (existingKey && existingKey !== key) {
          throw new Error('schedule response contains a conflicting duplicate ID');
        }
        const fingerprint = scheduleFingerprint(schedule);
        const existing = schedulesByKey.get(key);
        if (existing && existing.fingerprint !== fingerprint) {
          throw new Error('schedule response contains a conflicting duplicate contract');
        }
        keysById.set(id, key);
        schedulesByKey.set(key, { fingerprint, schedule });
      }
      url = page.nextLink
        ? validateScheduleUrl(
            page.nextLink,
            subscriptionId,
            normalizedPrincipalId,
            true,
            chainPath,
            resourceType,
            scopes,
          )
        : '';
    }
  }
  return [...schedulesByKey.entries()]
    .sort(([left], [right]) => (left < right ? -1 : left > right ? 1 : 0))
    .map(([, value]) => value.schedule);
}

export async function collectScheduleInstancesForPrincipals({
  subscriptionId,
  principalIds,
  fetchPage,
  resourceType = defaultResourceType,
  scopes = defaultScopes(subscriptionId),
}) {
  if (!Array.isArray(principalIds) || principalIds.length === 0) {
    throw new Error('role schedule principal IDs must be a non-empty unique array');
  }
  const normalizedPrincipalIds = principalIds.map(requirePrincipalId);
  if (new Set(normalizedPrincipalIds).size !== normalizedPrincipalIds.length) {
    throw new Error('role schedule principal IDs must be a non-empty unique array');
  }
  const schedulesByKey = new Map();
  for (const principalId of normalizedPrincipalIds) {
    const schedules = await collectScheduleInstances({
      subscriptionId,
      principalId,
      fetchPage,
      resourceType,
      scopes,
    });
    for (const schedule of schedules) {
      const key = scheduleInstanceKey(schedule);
      if (schedulesByKey.has(key)) {
        throw new Error('role schedule inventory overlaps principal queries');
      }
      schedulesByKey.set(key, schedule);
    }
  }
  return [...schedulesByKey.entries()]
    .sort(([left], [right]) => (left < right ? -1 : left > right ? 1 : 0))
    .map(([, schedule]) => schedule);
}

async function main() {
  const [outputPath, subscriptionId, resourceType, scopesPath, ...principalIds] =
    process.argv.slice(2);
  if (
    !outputPath ||
    !subscriptionId ||
    !resourceType ||
    !scopesPath ||
    principalIds.length === 0
  ) {
    throw new Error(
      'Usage: collect-role-assignment-schedules.mjs ' +
        '<output.json> <subscription-id> <resource-type> ' +
        '<scopes.json> <principal-id...>',
    );
  }
  const schedules = await collectScheduleInstancesForPrincipals({
    subscriptionId,
    principalIds,
    resourceType,
    scopes: JSON.parse(fs.readFileSync(path.resolve(scopesPath), 'utf8')),
    fetchPage: (url) =>
      JSON.parse(
        execFileSync(
          'az',
          ['rest', '--method', 'get', '--url', url, '--output', 'json'],
          { encoding: 'utf8' },
        ),
      ),
  });
  fs.writeFileSync(path.resolve(outputPath), JSON.stringify(schedules), {
    mode: 0o600,
  });
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  await main();
}
