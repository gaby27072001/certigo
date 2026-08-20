export function labelsOf(runner) {
  return new Set((runner.labels ?? []).map((label) => label.name ?? label));
}

export function isCertigoRunner(runner) {
  const labels = labelsOf(runner);
  return labels.has('certigo-pr') || labels.has('certigo-trusted');
}

export function trustClassOfRunner(runner) {
  const labels = labelsOf(runner);
  const hasPr = labels.has('certigo-pr');
  const hasTrusted = labels.has('certigo-trusted');
  if (hasPr && hasTrusted) {
    return 'dual';
  }
  if (hasPr) {
    return 'certigo-pr';
  }
  if (hasTrusted) {
    return 'certigo-trusted';
  }
  return null;
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
  return [
    ...Object.keys(scaleSet.identity?.userAssignedIdentities ?? {}),
    ...(scaleSet.identity?.principalId
      ? [scaleSet.identity.principalId]
      : []),
  ].map((identity) => String(identity).toLowerCase());
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

export function summarizePoolBoundaries(scaleSets, managedInstances = null) {
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
      const trustClass = trustClassOfRunner(runner);
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
  const identityCollections = boundaryScaleSets.map((scaleSet) => [
    scaleSet.name,
    identitiesOf(scaleSet),
  ]);
  const subnetCollections = boundaryScaleSets.map((scaleSet) => [
    scaleSet.name,
    subnetIdsOf(scaleSet),
  ]);
  const identityProfiles = identityCollections.map(([, identities]) =>
    [...new Set(identities)].sort().join('|') || 'none',
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
    trustClassPoolCounts: {
      'certigo-pr': [...trustClassesByPool.values()].filter((trustClasses) =>
        trustClasses.has('certigo-pr'),
      ).length,
      'certigo-trusted': [...trustClassesByPool.values()].filter(
        (trustClasses) => trustClasses.has('certigo-trusted'),
      ).length,
    },
    distinctIdentityBoundaryCount: new Set(identityProfiles).size,
    distinctSubnetCount: distinctSubnetIds.size,
    poolsWithoutSubnet: subnetCollections
      .filter(([, subnetIds]) => subnetIds.length === 0)
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
  { externalVirtualMachines = [] } = {},
) {
  const azureByName = new Map(
    (virtualMachines ?? []).map((virtualMachine) => [
      String(virtualMachine.name).toLowerCase(),
      virtualMachine,
    ]),
  );
  const certigoRunners = (runners ?? []).filter(isCertigoRunner);
  const runnerByMachineName = new Map(
    certigoRunners.map((runner) => [
      machineNameForRunner(runner.name).toLowerCase(),
      runner,
    ]),
  );

  const managedInstances = [];
  const absentRunners = [];
  for (const [machineName, runner] of runnerByMachineName) {
    const virtualMachine = azureByName.get(machineName);
    if (virtualMachine) {
      managedInstances.push({ virtualMachine, runner });
    } else {
      absentRunners.push(runner.name);
    }
  }

  const externalNames = new Set(
    externalVirtualMachines.map((name) => String(name).toLowerCase()),
  );
  const classifiedExternalVirtualMachines = [];
  const unclassifiedVirtualMachines = [];
  for (const [machineName, virtualMachine] of azureByName) {
    if (!runnerByMachineName.has(machineName)) {
      if (externalNames.has(machineName)) {
        classifiedExternalVirtualMachines.push(virtualMachine.name);
      } else {
        unclassifiedVirtualMachines.push(virtualMachine.name);
      }
    }
  }

  return {
    absentRunners: absentRunners.sort(),
    certigoRunners,
    externalVirtualMachines: classifiedExternalVirtualMachines.sort(),
    managedInstances,
    managedMachineNames: managedInstances
      .map(({ virtualMachine }) => virtualMachine.name)
      .sort(),
    unclassifiedVirtualMachines: unclassifiedVirtualMachines.sort(),
  };
}
