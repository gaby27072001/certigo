import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const reportFiles = {
  activeRuns: 'active-runs.json',
  autoscaleSettings: 'autoscale-settings.json',
  disks: 'disks.json',
  groups: 'groups.json',
  legacyFederation: 'legacy-federation.json',
  legacyRbac: 'legacy-rbac.json',
  nsgs: 'nsgs.json',
  policies: 'policies.json',
  publicIps: 'public-ips.json',
  queuedRuns: 'queued-runs.json',
  resources: 'resources.json',
  runners: 'runners.json',
  virtualMachines: 'vms.json',
  vmScaleSets: 'vm-scale-sets.json',
};

function readJson(directory, fileName) {
  return JSON.parse(fs.readFileSync(path.join(directory, fileName), 'utf8'));
}

export function renderInventory(directory, generatedAt, subscriptionId) {
  const data = Object.fromEntries(
    Object.entries(reportFiles).map(([key, fileName]) => [
      key,
      readJson(directory, fileName),
    ]),
  );

  return {
    generatedAt,
    subscriptionId,
    resourceGroups: data.groups,
    resources: data.resources,
    legacyIdentity: {
      roleAssignments: data.legacyRbac,
      federatedCredentials: data.legacyFederation,
    },
    policyAssignments: data.policies,
    runners: {
      autoscaleSettings: data.autoscaleSettings,
      virtualMachines: data.virtualMachines,
      vmScaleSets: data.vmScaleSets,
      github: data.runners,
      queuedRuns: data.queuedRuns,
      activeRuns: data.activeRuns,
    },
    orphanEvidence: {
      publicIps: data.publicIps,
      networkSecurityGroups: data.nsgs,
      disks: data.disks,
    },
  };
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
  for (const argument of ['--directory', '--generated-at', '--subscription']) {
    if (!args[argument]) {
      throw new Error(`Missing ${argument}`);
    }
  }

  process.stdout.write(
    `${JSON.stringify(
      renderInventory(
        args['--directory'],
        args['--generated-at'],
        args['--subscription'],
      ),
      null,
      2,
    )}\n`,
  );
}
