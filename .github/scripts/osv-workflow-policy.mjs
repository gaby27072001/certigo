function executableLines(workflow) {
  return workflow
    .split(/\r?\n/u)
    .filter((line) => !line.trimStart().startsWith('#'))
    .join('\n');
}

export function validateOsvWorkflowPolicy(workflow) {
  const executable = executableLines(workflow);
  const errors = [];
  const required = [
    'node "$TRUSTED_CONTROL_DIR/.github/scripts/run-osv-scan.mjs"',
    '--format=json',
    '--no-ignore',
    '--forbid-argument=--all-packages',
    '--forbid-argument=--recursive',
    '--config="$TRUSTED_CONTROL_DIR/.github/osv-scanner.toml"',
    '--output-file "$output_temp"',
  ];
  for (const marker of required) {
    if (!executable.includes(marker)) {
      errors.push(`OSV workflow lacks executable policy ${marker}`);
    }
  }
  if (/^\s*--all-packages(?:\s|\\|$)/mu.test(executable)) {
    errors.push('OSV workflow must not execute recursive all-package discovery');
  }
  return errors;
}
