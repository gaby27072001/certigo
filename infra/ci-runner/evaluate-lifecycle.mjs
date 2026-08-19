import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

import {
  labelsOf,
  reconcileRunnerInstances,
} from './runner-inventory.mjs';

function scaleInRules(autoscale) {
  return (autoscale.profiles ?? []).flatMap((profile) =>
    (profile.rules ?? []).filter(
      (rule) => rule.scaleAction?.direction === 'Decrease',
    ),
  );
}

export function evaluateLifecycle({
  operation,
  runners,
  queuedRuns,
  activeRuns,
  autoscale,
  virtualMachines,
}) {
  if (!['start', 'deallocate'].includes(operation)) {
    throw new Error(`Unsupported lifecycle operation: ${operation}`);
  }

  const reasons = [];
  const repositoryRunners = runners.runners ?? [];
  const certigoRunners = repositoryRunners.filter((runner) => {
    const labels = labelsOf(runner);
    return labels.has('certigo-pr') || labels.has('certigo-trusted');
  });
  const dualTrustRunners = certigoRunners.filter((runner) => {
    const labels = labelsOf(runner);
    return labels.has('certigo-pr') && labels.has('certigo-trusted');
  });
  const prRunners = certigoRunners.filter((runner) => {
    const labels = labelsOf(runner);
    return labels.has('certigo-pr') && !labels.has('certigo-trusted');
  });
  const trustedRunners = certigoRunners.filter((runner) => {
    const labels = labelsOf(runner);
    return labels.has('certigo-trusted') && !labels.has('certigo-pr');
  });

  if (dualTrustRunners.length > 0) {
    reasons.push(
      `dual trust labels: ${dualTrustRunners.map((runner) => runner.name).join(', ')}`,
    );
  }
  if (prRunners.length === 0 || trustedRunners.length === 0) {
    reasons.push('at least one exclusive certigo-pr and certigo-trusted runner is required');
  }

  if (operation === 'deallocate') {
    const busyRunners = certigoRunners.filter((runner) => runner.busy);
    if (busyRunners.length > 0) {
      reasons.push(
        `busy runners: ${busyRunners.map((runner) => runner.name).join(', ')}`,
      );
    }
    if ((queuedRuns.total_count ?? 0) > 0) {
      reasons.push(`queued workflow runs: ${queuedRuns.total_count}`);
    }
    if ((activeRuns.total_count ?? 0) > 0) {
      reasons.push(`active workflow runs: ${activeRuns.total_count}`);
    }
    if (autoscale.enabled && scaleInRules(autoscale).length > 0) {
      reasons.push('CPU autoscale contains an unsafe scale-in rule');
    }
    const instanceInventory = reconcileRunnerInstances(
      virtualMachines,
      certigoRunners,
    );
    if (
      instanceInventory.missingAzureForRunners.length > 0 ||
      instanceInventory.unregisteredAzureMachines.length > 0 ||
      certigoRunners.some((runner) => runner.status !== 'online')
    ) {
      reasons.push(
        `Azure VM and GitHub runner inventory is not reconciled (missing Azure: ${instanceInventory.missingAzureForRunners.join(', ') || 'none'}; unregistered Azure: ${instanceInventory.unregisteredAzureMachines.join(', ') || 'none'})`,
      );
    }
  }

  return {
    operation,
    preflightOnly: true,
    safeToRequestChange: reasons.length === 0,
    reasons,
    observed: {
      activeRuns: activeRuns.total_count ?? 0,
      azureVirtualMachines: (virtualMachines ?? []).length,
      certigoRunners: certigoRunners.length,
      dualTrustRunners: dualTrustRunners.length,
      prRunners: prRunners.length,
      queuedRuns: queuedRuns.total_count ?? 0,
      trustedRunners: trustedRunners.length,
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
  const required = [
    '--operation',
    '--runners',
    '--queued-runs',
    '--active-runs',
    '--autoscale',
    '--virtual-machines',
  ];
  for (const argument of required) {
    if (!args[argument]) {
      throw new Error(`Missing ${argument}`);
    }
  }

  const result = evaluateLifecycle({
    operation: args['--operation'],
    runners: JSON.parse(fs.readFileSync(args['--runners'], 'utf8')),
    queuedRuns: JSON.parse(fs.readFileSync(args['--queued-runs'], 'utf8')),
    activeRuns: JSON.parse(fs.readFileSync(args['--active-runs'], 'utf8')),
    autoscale: JSON.parse(fs.readFileSync(args['--autoscale'], 'utf8')),
    virtualMachines: JSON.parse(
      fs.readFileSync(args['--virtual-machines'], 'utf8'),
    ),
  });

  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  if (!result.safeToRequestChange) {
    process.exitCode = 2;
  }
}
