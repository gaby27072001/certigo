import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const defaultContractPath = path.join(scriptDirectory, 'scopes.json');
const placeholderValues = new Set(['n/a', 'none', 'tbd', 'unknown']);

function normalizedTagValue(tags, key) {
  const matchingKey = Object.keys(tags ?? {}).find(
    (candidate) => candidate.toLowerCase() === key.toLowerCase(),
  );
  return matchingKey === undefined ? '' : String(tags[matchingKey]).trim();
}

export function validateInventory(contract, inventory) {
  const violations = [];

  for (const scope of contract.scopes) {
    const scopedResources = inventory[scope.resourceGroupName];
    if (!Array.isArray(scopedResources) || scopedResources.length === 0) {
      violations.push(`${scope.resourceGroupName}: resource group or inventory is missing`);
      continue;
    }

    for (const resource of scopedResources) {
      const resourceId = resource.id ?? `${scope.resourceGroupName}/unknown-resource`;
      for (const key of contract.requiredTagKeys) {
        const value = normalizedTagValue(resource.tags, key);
        if (value === '' || placeholderValues.has(value.toLowerCase())) {
          violations.push(`${resourceId}: tag ${key} must be present and non-placeholder`);
        }
      }

      const expectedTags = {
        product: 'Certigo',
        env: scope.environment,
        managedBy: 'bicep',
      };
      for (const [key, expected] of Object.entries(expectedTags)) {
        const actual = normalizedTagValue(resource.tags, key);
        if (actual !== '' && actual !== expected) {
          violations.push(`${resourceId}: tag ${key} is "${actual}", expected "${expected}"`);
        }
      }
    }
  }

  return violations;
}

function azJson(args) {
  const executable = process.platform === 'win32' ? process.env.ComSpec : 'az';
  const executableArgs =
    process.platform === 'win32' ? ['/d', '/s', '/c', 'az', ...args] : args;
  return JSON.parse(
    execFileSync(
      executable,
      [...executableArgs, '--only-show-errors', '--output', 'json'],
      {
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'inherit'],
      },
    ),
  );
}

export function readAzureInventory(contract, subscription) {
  const inventory = {};

  for (const scope of contract.scopes) {
    if (!/^[A-Za-z0-9._()-]+$/.test(scope.resourceGroupName)) {
      throw new Error(`Invalid resource group name in tag contract: ${scope.resourceGroupName}`);
    }
    const commonArgs = ['--subscription', subscription];
    const group = azJson([
      'group',
      'show',
      '--name',
      scope.resourceGroupName,
      ...commonArgs,
      '--query',
      '{id:id,tags:tags}',
    ]);
    const resources = azJson([
      'resource',
      'list',
      '--resource-group',
      scope.resourceGroupName,
      ...commonArgs,
      '--query',
      '[].{id:id,tags:tags}',
    ]);
    inventory[scope.resourceGroupName] = [group, ...resources];
  }

  return inventory;
}

function parseArguments(argv) {
  const subscriptionIndex = argv.indexOf('--subscription');
  if (subscriptionIndex === -1 || !argv[subscriptionIndex + 1]) {
    throw new Error('Usage: node infra/finops/verify-tags.mjs --subscription <subscription-id>');
  }
  const subscription = argv[subscriptionIndex + 1];
  if (
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
      subscription,
    )
  ) {
    throw new Error('--subscription must be an Azure subscription GUID.');
  }
  return { subscription };
}

function main() {
  const { subscription } = parseArguments(process.argv.slice(2));
  const contract = JSON.parse(readFileSync(defaultContractPath, 'utf8'));
  const violations = validateInventory(
    contract,
    readAzureInventory(contract, subscription),
  );

  if (violations.length > 0) {
    console.error(`FinOps tag verification failed (${violations.length} violation(s)):\n`);
    const displayedViolations = violations.slice(0, 100);
    console.error(displayedViolations.map((violation) => `- ${violation}`).join('\n'));
    if (violations.length > displayedViolations.length) {
      console.error(
        `\n... ${violations.length - displayedViolations.length} additional violation(s) omitted.`,
      );
    }
    process.exitCode = 1;
    return;
  }

  console.log(`FinOps tags verified across ${contract.scopes.length} resource groups.`);
}

const invokedPath = process.argv[1] ? pathToFileURL(path.resolve(process.argv[1])).href : '';
if (import.meta.url === invokedPath) {
  main();
}
