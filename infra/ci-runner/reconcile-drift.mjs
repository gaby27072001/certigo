import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

import {
  labelsOf,
  reconcileRunnerInstances,
} from './runner-inventory.mjs';

function scaleInRules(autoscaleSettings) {
  return (autoscaleSettings ?? []).flatMap((autoscale) =>
    (autoscale.profiles ?? []).flatMap((profile) =>
      (profile.rules ?? []).filter(
        (rule) => rule.scaleAction?.direction === 'Decrease',
      ),
    ),
  );
}

function identitiesOf(scaleSet) {
  return [
    ...Object.keys(scaleSet.identity?.userAssignedIdentities ?? {}),
    ...(scaleSet.identity?.principalId
      ? [scaleSet.identity.principalId]
      : []),
  ];
}

export function reconcileRunnerDrift(inventory, runnerTemplate, config) {
  const findings = [];
  const expectedVmSize =
    runnerTemplate.match(/param vmSize string = '([^']+)'/)?.[1] ?? null;
  const liveVmScaleSets = inventory.runners?.vmScaleSets ?? [];
  const liveVmSizes = [
    ...new Set(
      liveVmScaleSets
        .map((scaleSet) => scaleSet.sku?.name)
        .filter(Boolean),
    ),
  ];
  const orchestrationModes = [
    ...new Set(
      liveVmScaleSets
        .map((scaleSet) => scaleSet.orchestrationMode)
        .filter(Boolean),
    ),
  ];
  const distinctPoolIdentities = new Set(
    liveVmScaleSets.flatMap((scaleSet) => identitiesOf(scaleSet)),
  );
  const instanceInventory = reconcileRunnerInstances(
    inventory.runners?.virtualMachines ?? [],
    inventory.runners?.github?.runners ?? [],
  );

  if (
    runnerTemplate.includes('Microsoft.Compute/virtualMachines@') &&
    liveVmScaleSets.length > 0
  ) {
    findings.push({
      severity: 'blocking',
      code: 'COMPUTE_MODEL_DRIFT',
      detail: 'IaC models standalone VMs while Azure runs a VMSS.',
    });
  }
  if (
    instanceInventory.missingAzureForRunners.length > 0 ||
    instanceInventory.unregisteredAzureMachines.length > 0
  ) {
    findings.push({
      severity: 'blocking',
      code: 'INSTANCE_REGISTRATION_DRIFT',
      detail: `Missing Azure for runners: ${instanceInventory.missingAzureForRunners.join(', ') || 'none'}; Azure VM without runner: ${instanceInventory.unregisteredAzureMachines.join(', ') || 'none'}.`,
    });
  }
  const usableCapacity = instanceInventory.reconciled.filter(
    ({ runner }) => runner.status === 'online',
  ).length;
  if (usableCapacity < config.modes.normal.aggregateCapacity) {
    findings.push({
      severity: 'blocking',
      code: 'REDUNDANCY_DRIFT',
      detail: `Usable reconciled capacity is ${usableCapacity}; normal target is ${config.modes.normal.aggregateCapacity}.`,
    });
  }
  if (
    expectedVmSize &&
    liveVmSizes.length > 0 &&
    !liveVmSizes.includes(expectedVmSize)
  ) {
    findings.push({
      severity: 'blocking',
      code: 'VM_SIZE_DRIFT',
      detail: `IaC uses ${expectedVmSize}; live VMSS uses ${liveVmSizes.join(', ')}.`,
    });
  }
  if (scaleInRules(inventory.runners?.autoscaleSettings).length > 0) {
    findings.push({
      severity: 'blocking',
      code: 'CPU_SCALE_IN_DRIFT',
      detail: 'Live CPU autoscale can scale in without GitHub queue/busy state.',
    });
  }
  if (
    liveVmScaleSets.length < config.minimumExclusivePools ||
    distinctPoolIdentities.size < config.minimumExclusivePools
  ) {
    findings.push({
      severity: 'blocking',
      code: 'POOL_IDENTITY_DRIFT',
      detail: `Expected ${config.minimumExclusivePools} pools with distinct identities; observed ${liveVmScaleSets.length} pools and ${distinctPoolIdentities.size} identities.`,
    });
  }

  const dualTrustRunners = (inventory.runners?.github?.runners ?? [])
    .filter((runner) => {
      const labels = labelsOf(runner);
      return labels.has('certigo-pr') && labels.has('certigo-trusted');
    })
    .map((runner) => runner.name);
  if (dualTrustRunners.length > 0) {
    findings.push({
      severity: 'blocking',
      code: 'TRUST_LABEL_DRIFT',
      detail: `Runners carry both trust labels: ${dualTrustRunners.join(', ')}.`,
    });
  }

  return {
    readOnly: true,
    driftDetected: findings.length > 0,
    findings,
    expected: {
      controllerEnabled: false,
      maxAggregateCapacity: config.maxAggregateCapacity,
      minimumExclusivePools: config.minimumExclusivePools,
      trigger: config.trigger,
      vmSize: expectedVmSize,
    },
    observed: {
      orchestrationModes,
      vmScaleSetCount: liveVmScaleSets.length,
      vmSizes: liveVmSizes,
      virtualMachineCount:
        inventory.runners?.virtualMachines?.length ?? 0,
      githubRunnerCount:
        inventory.runners?.github?.runners?.length ?? 0,
      distinctPoolIdentityCount: distinctPoolIdentities.size,
      missingAzureForRunners: instanceInventory.missingAzureForRunners,
      unregisteredAzureMachines: instanceInventory.unregisteredAzureMachines,
      usableCapacity,
    },
    baseline30Days: config.observedBaseline30Days,
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
  for (const argument of ['--config', '--inventory', '--runner-template']) {
    if (!args[argument]) {
      throw new Error(`Missing ${argument}`);
    }
  }

  const result = reconcileRunnerDrift(
    JSON.parse(fs.readFileSync(args['--inventory'], 'utf8')),
    fs.readFileSync(args['--runner-template'], 'utf8'),
    JSON.parse(fs.readFileSync(args['--config'], 'utf8')),
  );
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
}
