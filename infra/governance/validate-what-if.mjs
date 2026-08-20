import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const allowedResourceGroups = new Set([
  'rg-certigo-ci',
  'rg-certigo-dev',
  'rg-certigo-staging',
  'rg-certigo-prod',
]);

const allowedSubscriptionTypes = new Set([
  'microsoft.authorization/policyassignments',
  'microsoft.authorization/policydefinitions',
  'microsoft.authorization/roleassignments',
  'microsoft.authorization/roledefinitions',
  'microsoft.resources/deployments',
]);

const allowedResourceGroupTypes = new Map([
  [
    'rg-certigo-ci',
    new Set([
      'microsoft.authorization/roleassignments',
      'microsoft.managedidentity/userassignedidentities',
      'microsoft.managedidentity/userassignedidentities/federatedidentitycredentials',
      'microsoft.resources/deployments',
    ]),
  ],
  ...['rg-certigo-dev', 'rg-certigo-staging', 'rg-certigo-prod'].map(
    (resourceGroup) => [
      resourceGroup,
      new Set([
        'microsoft.authorization/roleassignments',
        'microsoft.resources/deployments',
      ]),
    ],
  ),
]);

function parseResourceId(resourceId) {
  const parts = resourceId.split('/').filter(Boolean);
  const resourceGroupIndex = parts.findIndex(
    (part) => part.toLowerCase() === 'resourcegroups',
  );
  const providerIndex = parts.findIndex(
    (part) => part.toLowerCase() === 'providers',
  );
  const resourceTypes = [];
  if (providerIndex >= 0) {
    for (let index = providerIndex + 2; index < parts.length; index += 2) {
      resourceTypes.push(parts[index]);
    }
  }

  return {
    resourceGroup:
      resourceGroupIndex >= 0 ? parts[resourceGroupIndex + 1]?.toLowerCase() : null,
    type:
      providerIndex >= 0
        ? `${parts[providerIndex + 1]}/${resourceTypes.join('/')}`.toLowerCase()
        : null,
  };
}

export function validateWhatIf(plan, subscriptionId) {
  const changes = plan.changes ?? [];
  const errors = [];
  const counts = {};

  for (const change of changes) {
    const changeType = change.changeType ?? 'Unknown';
    const resourceId = change.resourceId ?? '';
    counts[changeType] = (counts[changeType] ?? 0) + 1;

    if (changeType === 'Ignore') {
      continue;
    }

    if (changeType === 'Delete') {
      errors.push(`delete is forbidden: ${resourceId}`);
      continue;
    }

    const expectedPrefix = `/subscriptions/${subscriptionId}/`;
    if (!resourceId.toLowerCase().startsWith(expectedPrefix.toLowerCase())) {
      errors.push(`resource is outside subscription ${subscriptionId}: ${resourceId}`);
      continue;
    }

    const { resourceGroup, type } = parseResourceId(resourceId);
    if (resourceGroup !== null && !allowedResourceGroups.has(resourceGroup)) {
      errors.push(`resource group is outside the approved set: ${resourceId}`);
    } else if (
      resourceGroup !== null &&
      type !== null &&
      !allowedResourceGroupTypes.get(resourceGroup)?.has(type)
    ) {
      errors.push(
        `resource type is not approved in ${resourceGroup}: ${resourceId}`,
      );
    } else if (
      resourceGroup === null &&
      type !== null &&
      !allowedSubscriptionTypes.has(type)
    ) {
      errors.push(`subscription resource type is not approved: ${resourceId}`);
    }
  }

  if (errors.length > 0) {
    throw new Error(errors.join('\n'));
  }

  return { counts, total: changes.length };
}

function parseArguments(argv) {
  const result = {};
  for (let index = 0; index < argv.length; index += 2) {
    result[argv[index]] = argv[index + 1];
  }
  return result;
}

const isMain =
  process.argv[1] &&
  import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href;

if (isMain) {
  const args = parseArguments(process.argv.slice(2));
  if (!args['--plan'] || !args['--subscription']) {
    throw new Error(
      'Usage: node validate-what-if.mjs --plan <path> --subscription <id>',
    );
  }

  const plan = JSON.parse(fs.readFileSync(args['--plan'], 'utf8'));
  const summary = validateWhatIf(plan, args['--subscription']);
  const markdown =
    `## Least-privilege governance what-if\n\n` +
    `No deployment was executed. No deletes or out-of-scope resources were found.\n\n` +
    `\`\`\`json\n${JSON.stringify(summary, null, 2)}\n\`\`\`\n`;

  process.stdout.write(markdown);
  if (process.env.GITHUB_STEP_SUMMARY) {
    fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, markdown);
  }
}
