import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

import {
  isPoweredCapacity,
  labelsOf,
  reconcileRunnerInstances,
  summarizePoolBoundaries,
  trustClassOfRunner,
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

function bicepStringParameter(template, name) {
  return (
    template.match(new RegExp(`param ${name} string = '([^']+)'`))?.[1] ??
    null
  );
}

function bicepIntParameter(template, name) {
  const value = template.match(
    new RegExp(`param ${name} int = ([0-9]+)`),
  )?.[1];
  return value === undefined ? null : Number(value);
}

function normalizeResourceId(value) {
  return typeof value === 'string'
    ? value.replace(/\/+$/, '').toLowerCase()
    : null;
}

function matchesRequiredScaleOut(rule, targetResourceId) {
  const metric = rule?.metricTrigger;
  const action = rule?.scaleAction;
  return (
    metric?.metricName === 'Percentage CPU' &&
    metric?.metricNamespace === '' &&
    normalizeResourceId(metric?.metricResourceUri) ===
      normalizeResourceId(targetResourceId) &&
    metric?.operator === 'GreaterThan' &&
    metric?.statistic === 'Average' &&
    Number(metric?.threshold) === 70 &&
    metric?.timeAggregation === 'Average' &&
    metric?.timeGrain === 'PT1M' &&
    metric?.timeWindow === 'PT10M' &&
    metric?.dividePerInstance === false &&
    action?.cooldown === 'PT10M' &&
    action?.direction === 'Increase' &&
    action?.type === 'ChangeCount' &&
    action?.value === '1'
  );
}

function validateAutoscaleContract(
  autoscaleSettings,
  capacityTemplate,
  liveVmScaleSets,
) {
  const expectedName = bicepStringParameter(
    capacityTemplate,
    'autoscaleSettingName',
  );
  if (!expectedName) {
    return [];
  }

  const issues = [];
  const expectedLegacyName = bicepStringParameter(
    capacityTemplate,
    'legacyVmScaleSetName',
  );
  const expectedMinimum = bicepIntParameter(
    capacityTemplate,
    'legacyMinimumCapacity',
  );
  const expectedMaximum = bicepIntParameter(
    capacityTemplate,
    'legacyMaximumCapacity',
  );
  const settings = autoscaleSettings ?? [];
  const autoscale = settings.find((setting) => setting.name === expectedName);
  const unexpectedNames = settings
    .map((setting) => setting.name)
    .filter((name) => name && name !== expectedName);

  if (!autoscale) {
    issues.push(`missing ${expectedName}`);
  }
  if (unexpectedNames.length > 0) {
    issues.push(`unexpected settings: ${unexpectedNames.join(', ')}`);
  }
  if (!autoscale) {
    return issues;
  }

  const legacyVmScaleSet = liveVmScaleSets.find(
    (scaleSet) => scaleSet.name === expectedLegacyName,
  );
  const expectedTarget = legacyVmScaleSet?.id;
  if (!expectedTarget) {
    issues.push(`missing ARM id for ${expectedLegacyName}`);
  }
  if (autoscale.enabled !== true) {
    issues.push('autoscale is not enabled');
  }
  if (
    expectedTarget &&
    normalizeResourceId(autoscale.targetResourceUri) !==
      normalizeResourceId(expectedTarget)
  ) {
    issues.push('targetResourceUri does not target the legacy VMSS');
  }
  if (autoscale.predictiveAutoscalePolicy?.scaleMode !== 'Disabled') {
    issues.push('predictive autoscale is not disabled');
  }

  const profiles = autoscale.profiles ?? [];
  if (profiles.length !== 1 || profiles[0]?.name !== 'default') {
    issues.push('the default autoscale profile is missing or not unique');
    return issues;
  }

  const profile = profiles[0];
  if (
    expectedMinimum !== null &&
    (String(profile.capacity?.minimum) !== String(expectedMinimum) ||
      String(profile.capacity?.default) !== String(expectedMinimum))
  ) {
    issues.push(`minimum/default capacity is not ${expectedMinimum}`);
  }
  if (
    expectedMaximum !== null &&
    String(profile.capacity?.maximum) !== String(expectedMaximum)
  ) {
    issues.push(`maximum capacity is not ${expectedMaximum}`);
  }

  const rules = profile.rules ?? [];
  if (
    !expectedTarget ||
    rules.filter((rule) => matchesRequiredScaleOut(rule, expectedTarget))
      .length !== 1
  ) {
    issues.push('the required CPU scale-out rule is missing or duplicated');
  }
  if (rules.length !== 1) {
    issues.push(`expected exactly one autoscale rule; observed ${rules.length}`);
  }

  return issues;
}

function aggregateCapacity(capacityByTrust) {
  return (
    capacityByTrust['certigo-pr'] +
    capacityByTrust['certigo-trusted']
  );
}

export function reconcileRunnerDrift(inventory, capacityTemplate, config) {
  const findings = [];
  const expectedVmSize =
    bicepStringParameter(capacityTemplate, 'vmSize');
  const expectedVmScaleSetNames = [
    ...capacityTemplate.matchAll(
      /param (?:legacy|pilot)VmScaleSetName string = '([^']+)'/g,
    ),
  ].map((match) => match[1]);
  const liveVmScaleSets = inventory.runners?.vmScaleSets ?? [];
  const liveVmScaleSetNames = liveVmScaleSets
    .map((scaleSet) => scaleSet.name)
    .filter(Boolean);
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
    capacityTemplate.includes('Microsoft.Compute/virtualMachines@') &&
    liveVmScaleSets.length > 0
  ) {
    findings.push({
      severity: 'blocking',
      code: 'COMPUTE_MODEL_DRIFT',
      detail: 'IaC models standalone VMs while Azure runs a VMSS.',
    });
  }
  const missingVmScaleSets = expectedVmScaleSetNames.filter(
    (name) => !liveVmScaleSetNames.includes(name),
  );
  const unexpectedVmScaleSets = liveVmScaleSetNames.filter(
    (name) => !expectedVmScaleSetNames.includes(name),
  );
  if (
    expectedVmScaleSetNames.length > 0 &&
    (missingVmScaleSets.length > 0 || unexpectedVmScaleSets.length > 0)
  ) {
    findings.push({
      severity: 'blocking',
      code: 'VMSS_CONTRACT_DRIFT',
      detail:
        `Missing VMSS: ${missingVmScaleSets.join(', ') || 'none'}; ` +
        `unexpected VMSS: ${unexpectedVmScaleSets.join(', ') || 'none'}.`,
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
  // The aggregate above cannot see a trust class collapsing on its own: a
  // surplus in one class hides a shortfall in the other, and each class carries
  // required checks the other cannot run. On 2026-09-08 one of the two
  // certigo-pr runners stayed deallocated after the nightly teardown; usable
  // capacity was still 3 against an aggregate target of 2, so nothing fired.
  const usableCapacityByTrust = { 'certigo-pr': 0, 'certigo-trusted': 0 };
  for (const { runner } of poweredManagedInstances) {
    if (runner.status !== 'online') {
      continue;
    }
    const trustClass = trustClassOfRunner(runner);
    if (trustClass in usableCapacityByTrust) {
      usableCapacityByTrust[trustClass] += 1;
    }
  }
  for (const trustClass of ['certigo-pr', 'certigo-trusted']) {
    const required = config.minimumOnlineByTrust?.[trustClass];
    // A missing floor must not read as a satisfied floor: without it this check
    // would silently cover nothing.
    if (!Number.isInteger(required)) {
      findings.push({
        severity: 'blocking',
        code: 'TRUST_CLASS_FLOOR_MISSING',
        detail: `minimumOnlineByTrust.${trustClass} is absent from the capacity controller config, so its redundancy cannot be checked.`,
      });
      continue;
    }
    const online = usableCapacityByTrust[trustClass];
    if (online < required) {
      findings.push({
        severity: 'blocking',
        code: 'TRUST_CLASS_REDUNDANCY_DRIFT',
        detail: `Usable ${trustClass} capacity is ${online}; minimumOnlineByTrust requires ${required}.`,
      });
    }
  }
  if (
    expectedVmSize &&
    (expectedVmScaleSetNames.length > 0
      ? expectedVmScaleSetNames
          .map((name) =>
            liveVmScaleSets.find((scaleSet) => scaleSet.name === name),
          )
          .filter(Boolean)
      : liveVmScaleSets
    ).some((scaleSet) => scaleSet.sku?.name !== expectedVmSize)
  ) {
    findings.push({
      severity: 'blocking',
      code: 'VM_SIZE_DRIFT',
      detail: `IaC uses ${expectedVmSize}; live VMSS uses ${liveVmSizes.join(', ')}.`,
    });
  }
  const autoscaleContractIssues = validateAutoscaleContract(
    inventory.runners?.autoscaleSettings,
    capacityTemplate,
    liveVmScaleSets,
  );
  if (autoscaleContractIssues.length > 0) {
    findings.push({
      severity: 'blocking',
      code: 'AUTOSCALE_CONTRACT_DRIFT',
      detail: `Live autoscale does not match the bounded IaC contract: ${autoscaleContractIssues.join('; ')}.`,
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
      vmScaleSetNames: expectedVmScaleSetNames,
      autoscaleSettingName: bicepStringParameter(
        capacityTemplate,
        'autoscaleSettingName',
      ),
      legacyMinimumCapacity: bicepIntParameter(
        capacityTemplate,
        'legacyMinimumCapacity',
      ),
      legacyMaximumCapacity: bicepIntParameter(
        capacityTemplate,
        'legacyMaximumCapacity',
      ),
    },
    observed: {
      orchestrationModes,
      vmScaleSetCount: liveVmScaleSets.length,
      vmScaleSetNames: liveVmScaleSetNames,
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
  for (const argument of ['--config', '--inventory']) {
    if (!args[argument]) {
      throw new Error(`Missing ${argument}`);
    }
  }
  const capacityTemplatePath =
    args['--capacity-template'] ?? args['--runner-template'];
  if (!capacityTemplatePath) {
    throw new Error('Missing --capacity-template');
  }

  const result = reconcileRunnerDrift(
    JSON.parse(fs.readFileSync(args['--inventory'], 'utf8')),
    fs.readFileSync(capacityTemplatePath, 'utf8'),
    JSON.parse(fs.readFileSync(args['--config'], 'utf8')),
  );
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
}
