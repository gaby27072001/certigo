#!/usr/bin/env node

// Fails when the runner executing a trusted job is absent from the versioned
// inventory. An instance that no artefact records is an instance no operator
// restarts: that is how the zone-1 trusted runner stayed offline long enough
// for GitHub to garbage-collect its registration.

import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

export function assertRunnerInventoried(runnerName, config) {
  const errors = [];
  const name = String(runnerName ?? '').trim();
  if (name === '') {
    errors.push('runner name was empty; cannot verify inventory membership');
    return errors;
  }

  const bindings = config?.inventory?.managedRunnerBindings;
  if (!Array.isArray(bindings) || bindings.length === 0) {
    errors.push('capacity controller inventory declares no managed runners');
    return errors;
  }

  const inventoried = new Set(
    bindings.map((binding) => String(binding.runnerName).toLowerCase()),
  );
  if (!inventoried.has(name.toLowerCase())) {
    errors.push(
      `runner ${name} is not in capacity-controller.config.json; ` +
        'add its managed binding so lifecycle tooling can never skip it',
    );
  }
  return errors;
}

function main(argv) {
  const [runnerName, configPath] = argv;
  const resolvedConfigPath =
    configPath ?? 'infra/ci-runner/capacity-controller.config.json';
  const config = JSON.parse(readFileSync(resolvedConfigPath, 'utf8'));
  const errors = assertRunnerInventoried(runnerName, config);
  for (const error of errors) {
    console.error(`::error::${error}`);
  }
  if (errors.length > 0) {
    process.exitCode = 1;
    return;
  }
  console.log(`Runner ${runnerName} is present in the versioned inventory.`);
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  main(process.argv.slice(2));
}
