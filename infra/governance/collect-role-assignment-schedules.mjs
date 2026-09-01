import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const apiVersion = '2020-10-01';
const resourceType = 'roleAssignmentScheduleInstances';

function normalize(value) {
  return String(value ?? '').toLowerCase();
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

function expectedPaths(subscriptionId) {
  const subscription = `/subscriptions/${subscriptionId}`;
  return new Set(
    [
      subscription,
      `${subscription}/resourceGroups/rg-certigo-ci`,
      `${subscription}/resourceGroups/rg-certigo-dev`,
      `${subscription}/resourceGroups/rg-certigo-staging`,
      `${subscription}/resourceGroups/rg-certigo-prod`,
    ].map(
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
    !expectedPaths(subscriptionId).has(url.pathname.toLowerCase()) ||
    (expectedPath !== null &&
      url.pathname.toLowerCase() !== expectedPath.toLowerCase())
  ) {
    throw new Error('schedule nextLink escapes the approved Azure endpoint');
  }
  const expectedFilter = `principalId eq '${principalId}'`;
  if (
    url.searchParams.get('api-version') !== apiVersion ||
    url.searchParams.get('$filter') !== expectedFilter
  ) {
    throw new Error('schedule nextLink changes the approved query');
  }
  const allowedQueryFields = new Set(['api-version', '$filter', '$skiptoken']);
  for (const key of url.searchParams.keys()) {
    if (!allowedQueryFields.has(key)) {
      throw new Error('schedule nextLink contains an unexpected query field');
    }
  }
  if (requireSkipToken && !url.searchParams.get('$skiptoken')) {
    throw new Error('schedule nextLink does not advance pagination');
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

export function initialScheduleUrls(subscriptionId, principalId) {
  const filter = encodeURIComponent(`principalId eq '${principalId}'`);
  return [...expectedPaths(subscriptionId)].map(
    (endpoint) =>
      `https://management.azure.com${endpoint}` +
      `?api-version=${apiVersion}&%24filter=${filter}`,
  );
}

export async function collectScheduleInstances({
  subscriptionId,
  principalId,
  fetchPage,
}) {
  const schedulesByKey = new Map();
  const keysById = new Map();
  const visitedUrls = new Set();
  for (const initialUrl of initialScheduleUrls(subscriptionId, principalId)) {
    const chainPath = new URL(initialUrl).pathname;
    let url = validateScheduleUrl(
      initialUrl,
      subscriptionId,
      principalId,
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
            principalId,
            true,
            chainPath,
          )
        : '';
    }
  }
  return [...schedulesByKey.entries()]
    .sort(([left], [right]) => (left < right ? -1 : left > right ? 1 : 0))
    .map(([, value]) => value.schedule);
}

async function main() {
  const [outputPath, subscriptionId, principalId] = process.argv.slice(2);
  if (!outputPath || !subscriptionId || !principalId) {
    throw new Error(
      'Usage: collect-role-assignment-schedules.mjs ' +
        '<output.json> <subscription-id> <principal-id>',
    );
  }
  const schedules = await collectScheduleInstances({
    subscriptionId,
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
  fs.writeFileSync(path.resolve(outputPath), JSON.stringify(schedules), {
    mode: 0o600,
  });
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  await main();
}
