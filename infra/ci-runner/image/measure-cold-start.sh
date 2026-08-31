#!/usr/bin/env bash
set -euo pipefail

if ((EUID != 0)); then
  echo "Run the boot measurement as root." >&2
  exit 1
fi

validation_unit="certigo-toolchain-validate.service"
mapfile -t runner_units < <(
  systemctl list-unit-files --type=service --no-legend 'actions.runner.*' |
    awk '$2 != "masked" {print $1}'
)
if ((${#runner_units[@]} != 1)); then
  echo "Expected exactly one runner service; found ${#runner_units[@]}." >&2
  exit 1
fi

boot_finished_us="$(
  systemctl show "${runner_units[0]}" -p ActiveEnterTimestampMonotonic --value
)"
validation_finished_us="$(
  systemctl show "${validation_unit}" -p ActiveEnterTimestampMonotonic --value
)"
for value in "${boot_finished_us}" "${validation_finished_us}"; do
  [[ "${value}" =~ ^[0-9]+$ ]] || {
    echo "systemd did not expose a monotonic activation timestamp." >&2
    exit 1
  }
done
((boot_finished_us > 0 && validation_finished_us > 0)) || {
  echo "Validation and runner services must both be active." >&2
  exit 1
}
((validation_finished_us <= boot_finished_us)) || {
  echo "Runner started before immutable toolchain validation completed." >&2
  exit 1
}

jq -n \
  --arg measuredAt "$(date --utc +%Y-%m-%dT%H:%M:%SZ)" \
  --arg runnerUnit "${runner_units[0]}" \
  --argjson validationReadyMilliseconds "$((validation_finished_us / 1000))" \
  --argjson runnerReadyMilliseconds "$((boot_finished_us / 1000))" \
  '{
    measuredAt: $measuredAt,
    runnerUnit: $runnerUnit,
    validationReadyMilliseconds: $validationReadyMilliseconds,
    runnerReadyMilliseconds: $runnerReadyMilliseconds
  }'
