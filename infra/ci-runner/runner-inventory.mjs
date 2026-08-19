export function labelsOf(runner) {
  return new Set((runner.labels ?? []).map((label) => label.name ?? label));
}

export function isCertigoRunner(runner) {
  const labels = labelsOf(runner);
  return labels.has('certigo-pr') || labels.has('certigo-trusted');
}

export function machineNameForRunner(runnerName) {
  return String(runnerName).replace(/-Certigo$/i, '');
}

export function reconcileRunnerInstances(virtualMachines, runners) {
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

  const reconciled = [];
  const missingAzureForRunners = [];
  for (const [machineName, runner] of runnerByMachineName) {
    const virtualMachine = azureByName.get(machineName);
    if (virtualMachine) {
      reconciled.push({ virtualMachine, runner });
    } else {
      missingAzureForRunners.push(runner.name);
    }
  }

  const unregisteredAzureMachines = [];
  for (const [machineName, virtualMachine] of azureByName) {
    if (!runnerByMachineName.has(machineName)) {
      unregisteredAzureMachines.push(virtualMachine.name);
    }
  }

  return {
    certigoRunners,
    missingAzureForRunners: missingAzureForRunners.sort(),
    reconciled,
    unregisteredAzureMachines: unregisteredAzureMachines.sort(),
  };
}
