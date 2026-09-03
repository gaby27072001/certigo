export const RUNNER_CLASSES = Object.freeze([
  'certigo-pr',
  'certigo-backend-builder',
  'certigo-backend-deployer',
  'certigo-trusted',
]);

export function labelsOf(runner) {
  return new Set((runner.labels ?? []).map((label) => label.name ?? label));
}

export function isCertigoRunner(runner, runnerClasses = RUNNER_CLASSES) {
  const labels = labelsOf(runner);
  return runnerClasses.some((runnerClass) => labels.has(runnerClass));
}

export function runnerClassOf(runner, runnerClasses = RUNNER_CLASSES) {
  const labels = labelsOf(runner);
  const matchingClasses = runnerClasses.filter((runnerClass) =>
    labels.has(runnerClass)
  );
  if (matchingClasses.length > 1) {
    return 'dual';
  }
  return matchingClasses[0] ?? null;
}

export function trustClassOfRunner(runner, runnerClasses = RUNNER_CLASSES) {
  return runnerClassOf(runner, runnerClasses);
}

export function machineNameForRunner(runnerName) {
  return String(runnerName).replace(/-Certigo$/i, '');
}

export function scaleSetNameOf(virtualMachine) {
  const scaleSetId = virtualMachine.virtualMachineScaleSet?.id;
  if (!scaleSetId) {
    return null;
  }
  const segments = String(scaleSetId).split('/').filter(Boolean);
  return segments.at(-1)?.toLowerCase() ?? null;
}

export function identitiesOf(scaleSet) {
  if (!Object.hasOwn(scaleSet ?? {}, 'identity')) {
    return [];
  }
  return [
    ...Object.keys(scaleSet.identity?.userAssignedIdentities ?? {}),
    ...(scaleSet.identity?.principalId
      ? [scaleSet.identity.principalId]
      : []),
  ].map((identity) => String(identity).toLowerCase());
}

function identityEvidenceOf(scaleSet) {
  if (!Object.hasOwn(scaleSet ?? {}, 'identity')) {
    return { known: false, identities: [] };
  }
  const identity = scaleSet.identity;
  if (identity === null) {
    return { known: true, identities: [] };
  }
  if (typeof identity !== 'object' || Array.isArray(identity)) {
    return { known: false, identities: [] };
  }

  const identities = identitiesOf(scaleSet);
  const identityType = String(identity.type ?? '').toLowerCase();
  if (identityType === 'none') {
    return {
      known: identities.length === 0,
      identities,
    };
  }
  if (identities.length > 0) {
    return { known: true, identities };
  }
  return {
    known: Object.keys(identity).length === 0,
    identities,
  };
}

export function subnetIdsOf(scaleSet) {
  const networkProfile =
    scaleSet.virtualMachineProfile?.networkProfile ??
    scaleSet.networkProfile ??
    {};
  return (networkProfile.networkInterfaceConfigurations ?? [])
    .flatMap(
      (networkInterface) =>
        networkInterface.ipConfigurations ??
        networkInterface.properties?.ipConfigurations ??
        [],
    )
    .map(
      (ipConfiguration) =>
        ipConfiguration.subnet?.id ??
        ipConfiguration.properties?.subnet?.id ??
        null,
    )
    .filter(Boolean)
    .map((subnetId) => String(subnetId).toLowerCase());
}

function duplicateValues(collections) {
  const owners = new Map();
  for (const [owner, values] of collections) {
    for (const value of new Set(values)) {
      const valueOwners = owners.get(value) ?? [];
      valueOwners.push(owner);
      owners.set(value, valueOwners);
    }
  }
  return [...owners.entries()]
    .filter(([, valueOwners]) => valueOwners.length > 1)
    .map(([value]) => value)
    .sort();
}

export function summarizePoolBoundaries(
  scaleSets,
  managedInstances = null,
  runnerClasses = RUNNER_CLASSES,
) {
  const scaleSetByName = new Map(
    (scaleSets ?? []).map((scaleSet) => [
      String(scaleSet.name).toLowerCase(),
      scaleSet,
    ]),
  );
  const managedPoolNames = new Set();
  const managedInstancesWithoutPool = [];
  const trustClassesByPool = new Map();
  if (managedInstances !== null) {
    for (const { runner, virtualMachine } of managedInstances) {
      const poolName = scaleSetNameOf(virtualMachine);
      if (!poolName) {
        managedInstancesWithoutPool.push(virtualMachine.name);
        continue;
      }
      managedPoolNames.add(poolName);
      const trustClasses = trustClassesByPool.get(poolName) ?? new Set();
      const trustClass = runnerClassOf(runner, runnerClasses);
      if (trustClass) {
        trustClasses.add(trustClass);
      }
      trustClassesByPool.set(poolName, trustClasses);
    }
  }

  const boundaryScaleSets =
    managedInstances === null
      ? scaleSets ?? []
      : [...managedPoolNames]
          .map((name) => scaleSetByName.get(name))
          .filter(Boolean);
  const identityEvidence = boundaryScaleSets.map((scaleSet) => [
    scaleSet.name,
    identityEvidenceOf(scaleSet),
  ]);
  const identityCollections = identityEvidence.map(([name, evidence]) => [
    name,
    evidence.identities,
  ]);
  const subnetCollections = boundaryScaleSets.map((scaleSet) => [
    scaleSet.name,
    subnetIdsOf(scaleSet),
  ]);
  const identityProfiles = identityEvidence
    .filter(([, evidence]) => evidence.known)
    .map(
      ([name, evidence]) =>
        [...new Set(evidence.identities)].sort().join('|') ||
        `none:${String(name).toLowerCase()}`,
    );
  const distinctSubnetIds = new Set(
    subnetCollections.flatMap(([, subnetIds]) => subnetIds),
  );

  return {
    managedInstancesWithoutPool: managedInstancesWithoutPool.sort(),
    managedPoolCount: boundaryScaleSets.length,
    managedPoolNames: boundaryScaleSets
      .map((scaleSet) => scaleSet.name)
      .sort(),
    missingManagedScaleSets: [...managedPoolNames]
      .filter((name) => !scaleSetByName.has(name))
      .sort(),
    poolsWithMixedTrustLabels: [...trustClassesByPool.entries()]
      .filter(
        ([, trustClasses]) =>
          trustClasses.size !== 1 || trustClasses.has('dual'),
      )
      .map(([name]) => name)
      .sort(),
    trustClassPoolCounts: Object.fromEntries(
      runnerClasses.map((runnerClass) => [
        runnerClass,
        [...trustClassesByPool.values()].filter((trustClasses) =>
          trustClasses.has(runnerClass)
        ).length,
      ]),
    ),
    distinctIdentityBoundaryCount: new Set(identityProfiles).size,
    distinctSubnetCount: distinctSubnetIds.size,
    poolsWithoutSubnet: subnetCollections
      .filter(([, subnetIds]) => subnetIds.length === 0)
      .map(([name]) => name)
      .sort(),
    poolsWithoutIdentityEvidence: identityEvidence
      .filter(([, evidence]) => !evidence.known)
      .map(([name]) => name)
      .sort(),
    sharedIdentityIds: duplicateValues(identityCollections),
    sharedSubnetIds: duplicateValues(subnetCollections),
  };
}

export function isPoweredCapacity(virtualMachine) {
  const powerState = String(virtualMachine.powerState ?? '').toLowerCase();
  if (!powerState) {
    return false;
  }
  return powerState.includes('running') || powerState.includes('starting');
}

export function reconcileRunnerInstances(
  virtualMachines,
  runners,
  {
    externalGithubRunnerIds = [],
    externalVirtualMachines = [],
    forbiddenVirtualMachines = [],
    managedRunnerBindings = [],
    runnerClasses = RUNNER_CLASSES,
  } = {},
) {
  const azureByName = new Map(
    (virtualMachines ?? []).map((virtualMachine) => [
      String(virtualMachine.name).toLowerCase(),
      virtualMachine,
    ]),
  );
  const externalRunnerIds = new Set(
    externalGithubRunnerIds.map((id) => Number(id)),
  );
  const allCertigoRunners = (runners ?? []).filter((runner) =>
    isCertigoRunner(runner, runnerClasses)
  );
  const externalGitHubRunners = allCertigoRunners.filter((runner) =>
    externalRunnerIds.has(Number(runner.id)),
  );
  const certigoRunners = allCertigoRunners.filter(
    (runner) => !externalRunnerIds.has(Number(runner.id)),
  );
  const runnerByName = new Map(
    certigoRunners.map((runner) => [
      String(runner.name).toLowerCase(),
      runner,
    ]),
  );

  const consumedMachineNames = new Set();
  const consumedRunnerNames = new Set();
  const managedInstances = [];
  const absentRunners = [];
  const bindingMismatches = [];
  const missingManagedRunnerVirtualMachines = [];
  for (const binding of managedRunnerBindings) {
    const machineName = String(binding.virtualMachineName).toLowerCase();
    const runnerName = String(binding.runnerName).toLowerCase();
    const virtualMachine = azureByName.get(machineName);
    const runner = runnerByName.get(runnerName);
    if (!virtualMachine && !runner) {
      continue;
    }
    if (virtualMachine) {
      consumedMachineNames.add(machineName);
    }
    if (runner) {
      consumedRunnerNames.add(runnerName);
    }
    if (!virtualMachine) {
      absentRunners.push(runner.name);
      continue;
    }
    if (!runner) {
      missingManagedRunnerVirtualMachines.push(virtualMachine.name);
      continue;
    }

    const mismatches = [];
    if (Number(runner.id) !== binding.githubRunnerId) {
      mismatches.push(
        `runner id ${runner.id ?? 'missing'} != ${binding.githubRunnerId}`,
      );
    }
    if (
      String(virtualMachine.id ?? '').toLowerCase() !==
      String(binding.virtualMachineId).toLowerCase()
    ) {
      mismatches.push('Azure virtual machine resource id differs');
    }
    if (mismatches.length > 0) {
      bindingMismatches.push(
        `${binding.runnerName} -> ${binding.virtualMachineName}: ${mismatches.join('; ')}`,
      );
      continue;
    }
    managedInstances.push({
      binding: 'explicit',
      runner,
      virtualMachine,
    });
  }

  const externalNames = new Set(
    externalVirtualMachines.map((name) => String(name).toLowerCase()),
  );
  const forbiddenNames = new Set(
    forbiddenVirtualMachines.map((name) => String(name).toLowerCase()),
  );
  const forbiddenVirtualMachinesPresent = [];
  const unboundRunnerVirtualMachinePairs = [];
  for (const runner of certigoRunners) {
    const runnerName = String(runner.name).toLowerCase();
    if (consumedRunnerNames.has(runnerName)) {
      continue;
    }
    const machineName = machineNameForRunner(runner.name).toLowerCase();
    const virtualMachine = azureByName.get(machineName);
    if (!virtualMachine) {
      absentRunners.push(runner.name);
      continue;
    }
    consumedMachineNames.add(machineName);
    if (forbiddenNames.has(machineName)) {
      forbiddenVirtualMachinesPresent.push(virtualMachine.name);
      continue;
    }
    if (managedRunnerBindings.length > 0) {
      unboundRunnerVirtualMachinePairs.push(
        `${runner.name} -> ${virtualMachine.name}`,
      );
      continue;
    }
    managedInstances.push({
      binding: 'name',
      runner,
      virtualMachine,
    });
  }

  const classifiedExternalVirtualMachines = [];
  const unclassifiedVirtualMachines = [];
  for (const [machineName, virtualMachine] of azureByName) {
    if (consumedMachineNames.has(machineName)) {
      continue;
    }
    if (forbiddenNames.has(machineName)) {
      forbiddenVirtualMachinesPresent.push(virtualMachine.name);
    } else if (externalNames.has(machineName)) {
      classifiedExternalVirtualMachines.push(virtualMachine.name);
    } else {
      unclassifiedVirtualMachines.push(virtualMachine.name);
    }
  }

  return {
    absentRunners: absentRunners.sort(),
    bindingMismatches: bindingMismatches.sort(),
    certigoRunners,
    externalGitHubRunners: externalGitHubRunners.sort(
      (left, right) => Number(left.id) - Number(right.id),
    ),
    externalVirtualMachines: classifiedExternalVirtualMachines.sort(),
    forbiddenVirtualMachinesPresent:
      forbiddenVirtualMachinesPresent.sort(),
    managedInstances,
    managedMachineNames: managedInstances
      .map(({ virtualMachine }) => virtualMachine.name)
      .sort(),
    missingManagedRunnerVirtualMachines:
      missingManagedRunnerVirtualMachines.sort(),
    unboundRunnerVirtualMachinePairs:
      unboundRunnerVirtualMachinePairs.sort(),
    unclassifiedVirtualMachines: unclassifiedVirtualMachines.sort(),
  };
}
