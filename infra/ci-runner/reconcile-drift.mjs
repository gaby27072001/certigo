import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

import {
  isPoweredCapacity,
  labelsOf,
  reconcileRunnerInstances,
  summarizePoolBoundaries,
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

function aggregateCapacity(capacityByTrust) {
  return (
    capacityByTrust['certigo-pr'] +
    capacityByTrust['certigo-trusted']
  );
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
  const instanceInventory = reconcileRunnerInstances(
    inventory.runners?.virtualMachines ?? [],
    inventory.runners?.github?.runners ?? [],
    config.inventory,
  );
  const poolBoundaries = summarizePoolBoundaries(
    liveVmScaleSets,
    instanceInventory.managedInstances,
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
  if (instanceInventory.absentRunners.length > 0) {
    findings.push({
      severity: 'blocking',
      code: 'ABSENT_RUNNER_DRIFT',
      detail: `GitHub runners without an Azure VM: ${instanceInventory.absentRunners.join(', ')}.`,
    });
  }
  if (instanceInventory.externalVirtualMachines.length > 0) {
    findings.push({
      severity: 'informational',
      code: 'EXTERNAL_INSTANCE_OBSERVED',
      detail: `Azure VMs outside controller ownership: ${instanceInventory.externalVirtualMachines.join(', ')}. They must not be adopted, relabelled, or changed implicitly.`,
    });
  }
  if (instanceInventory.unclassifiedVirtualMachines.length > 0) {
    findings.push({
      severity: 'blocking',
      code: 'UNCLASSIFIED_INSTANCE_DRIFT',
      detail: `Azure VMs without a runner or explicit external classification: ${instanceInventory.unclassifiedVirtualMachines.join(', ')}.`,
    });
  }
  if (
    instanceInventory.bindingMismatches.length > 0 ||
    instanceInventory.missingManagedRunnerVirtualMachines.length > 0 ||
    instanceInventory.unboundRunnerVirtualMachinePairs.length > 0
  ) {
    findings.push({
      severity: 'blocking',
      code: 'MANAGED_BINDING_DRIFT',
      detail:
        `Managed binding mismatches: ${instanceInventory.bindingMismatches.join(', ') || 'none'}; ` +
        `VMs without the bound runner: ${instanceInventory.missingManagedRunnerVirtualMachines.join(', ') || 'none'}; ` +
        `unbound pairs: ${instanceInventory.unboundRunnerVirtualMachinePairs.join(', ') || 'none'}.`,
    });
  }
  if (instanceInventory.forbiddenVirtualMachinesPresent.length > 0) {
    findings.push({
      severity: 'blocking',
      code: 'FORBIDDEN_INSTANCE_PRESENT',
      detail: `Forbidden Azure VMs are present: ${instanceInventory.forbiddenVirtualMachinesPresent.join(', ')}.`,
    });
  }
  const poweredManagedInstances = instanceInventory.managedInstances.filter(
    ({ virtualMachine }) => isPoweredCapacity(virtualMachine),
  );
  const usableCapacity = poweredManagedInstances.filter(
    ({ runner }) => runner.status === 'online',
  ).length;
  const normalTarget = aggregateCapacity(config.modes.normal);
  if (usableCapacity < normalTarget) {
    findings.push({
      severity: 'blocking',
      code: 'REDUNDANCY_DRIFT',
      detail: `Usable managed capacity is ${usableCapacity}; normal target is ${normalTarget}.`,
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
    poolBoundaries.managedPoolCount < config.minimumExclusivePools ||
    poolBoundaries.managedInstancesWithoutPool.length > 0 ||
    poolBoundaries.missingManagedScaleSets.length > 0 ||
    poolBoundaries.distinctIdentityBoundaryCount <
      config.minimumExclusivePools ||
    poolBoundaries.sharedIdentityIds.length > 0
  ) {
    findings.push({
      severity: 'blocking',
      code: 'POOL_IDENTITY_DRIFT',
      detail: `Expected ${config.minimumExclusivePools} managed pools with exclusive identity boundaries; observed ${poolBoundaries.managedPoolCount} managed pools and ${poolBoundaries.distinctIdentityBoundaryCount} boundaries.`,
    });
  }
  if (
    poolBoundaries.distinctSubnetCount < config.minimumExclusiveSubnets ||
    poolBoundaries.poolsWithoutSubnet.length > 0 ||
    poolBoundaries.sharedSubnetIds.length > 0
  ) {
    findings.push({
      severity: 'blocking',
      code: 'POOL_SUBNET_DRIFT',
      detail: `Expected ${config.minimumExclusiveSubnets} exclusive runner subnets; observed ${poolBoundaries.distinctSubnetCount}.`,
    });
  }
  if (
    poolBoundaries.poolsWithMixedTrustLabels.length > 0 ||
    poolBoundaries.trustClassPoolCounts['certigo-pr'] === 0 ||
    poolBoundaries.trustClassPoolCounts['certigo-trusted'] === 0
  ) {
    findings.push({
      severity: 'blocking',
      code: 'POOL_TRUST_BOUNDARY_DRIFT',
      detail: `Managed pools do not map one trust class per pool: ${poolBoundaries.poolsWithMixedTrustLabels.join(', ') || 'missing class pool'}.`,
    });
  }

  const dualTrustRunners = instanceInventory.managedInstances
    .filter(({ runner }) => {
      const labels = labelsOf(runner);
      return labels.has('certigo-pr') && labels.has('certigo-trusted');
    })
    .map(({ runner }) => runner.name);
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
      minimumExclusivePools: config.minimumExclusivePools,
      minimumExclusiveSubnets: config.minimumExclusiveSubnets,
      pilotTarget: config.pilotTarget,
      pilotTargetCapacity: aggregateCapacity(config.pilotTarget),
      quietPeriodSeconds: config.quietPeriodSeconds,
      requiredPostQuietGuards: config.requiredPostQuietGuards,
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
      absentRunners: instanceInventory.absentRunners,
      bindingMismatches: instanceInventory.bindingMismatches,
      distinctIdentityBoundaryCount:
        poolBoundaries.distinctIdentityBoundaryCount,
      distinctSubnetCount: poolBoundaries.distinctSubnetCount,
      externalVirtualMachines: instanceInventory.externalVirtualMachines,
      forbiddenVirtualMachinesPresent:
        instanceInventory.forbiddenVirtualMachinesPresent,
      managedMachineNames: instanceInventory.managedMachineNames,
      managedPoolCount: poolBoundaries.managedPoolCount,
      managedPoolNames: poolBoundaries.managedPoolNames,
      missingManagedRunnerVirtualMachines:
        instanceInventory.missingManagedRunnerVirtualMachines,
      poolsWithMixedTrustLabels:
        poolBoundaries.poolsWithMixedTrustLabels,
      physicalManagedCapacity: instanceInventory.managedInstances.length,
      poweredManagedCapacity: poweredManagedInstances.length,
      sharedIdentityIds: poolBoundaries.sharedIdentityIds,
      sharedSubnetIds: poolBoundaries.sharedSubnetIds,
      unboundRunnerVirtualMachinePairs:
        instanceInventory.unboundRunnerVirtualMachinePairs,
      unclassifiedVirtualMachines:
        instanceInventory.unclassifiedVirtualMachines,
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
