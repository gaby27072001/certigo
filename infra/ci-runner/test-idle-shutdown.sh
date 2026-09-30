#!/usr/bin/env bash
# Tests hors ligne de infra/ci-runner/idle-shutdown.sh : systemctl, pgrep, l'horloge et
# l'uptime sont simulés ; aucune commande n'est jamais envoyée au système hôte.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
agent="${repo_root}/infra/ci-runner/idle-shutdown.sh"
work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT
bin_dir="${work_dir}/bin"
mkdir -p "${bin_dir}"

# pgrep is only used for package maintenance: apt/dpkg run as root when ${FAKE_DIR}/apt-root
# exists and as the runner account when ${FAKE_DIR}/apt-user exists.
cat > "${bin_dir}/pgrep" <<'EOF'
#!/usr/bin/env bash
pattern="${*: -1}"
case "${pattern}" in
  *dpkg*)
    if [[ " $* " == *" -u root "* ]]; then
      [[ -e "${FAKE_DIR}/apt-root" ]]
    else
      [[ -e "${FAKE_DIR}/apt-root" || -e "${FAKE_DIR}/apt-user" ]]
    fi
    ;;
  *) exit 1 ;;
esac
EOF
# systemctl: records every call. Two active runner units, as on a trusted VM, whose main
# processes are 100 and 110. `stop` can start package maintenance (the final-guard case).
cat > "${bin_dir}/systemctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${FAKE_DIR}/systemctl.log"
case "$1" in
  list-units)
    printf 'actions.runner.gchambaud_microsoft-Certigo.pr1.service loaded active running Runner\n'
    printf 'actions.runner.gchambaud_microsoft-certigo-content.pr1.service loaded active running Runner\n'
    ;;
  list-unit-files)
    [[ -e "${FAKE_DIR}/no-units" ]] && exit 0
    printf 'actions.runner.gchambaud_microsoft-Certigo.pr1.service enabled enabled\n'
    printf 'actions.runner.gchambaud_microsoft-certigo-content.pr1.service enabled enabled\n'
    ;;
  show)
    case "${*: -1}" in
      *-Certigo.*) echo 100 ;;
      *-certigo-content.*) echo 110 ;;
      *) echo 0 ;;
    esac
    ;;
  stop)
    [[ -e "${FAKE_DIR}/apt-after-stop" ]] && touch "${FAKE_DIR}/apt-root"
    exit "${FAKE_STOP_RC:-0}"
    ;;
  poweroff) exit "${FAKE_POWEROFF_RC:-0}" ;;
  is-active) echo active ;;
  *) exit 0 ;;
esac
EOF
chmod +x "${bin_dir}/pgrep" "${bin_dir}/systemctl"

# process <pid> <ppid> <command>: one entry of the fake /proc.
process() {
  mkdir -p "${FAKE_DIR}/proc/$1"
  printf '%s (%s) S %s %s %s 0 -1\n' "$1" "$3" "$2" "$1" "$1" > "${FAKE_DIR}/proc/$1/stat"
}

# The measured service tree: runsvc.sh (MainPID) -> node -> Runner.Listener, per unit.
runner_services() {
  process 1 0 systemd
  process 100 1 runsvc.sh
  process 200 100 node
  process 300 200 Runner.Listener
  process 110 1 runsvc.sh
  process 210 110 node
  process 310 210 Runner.Listener
}
epoch() { date -u -d "$1" +%s; }
afternoon="$(epoch '2026-09-30T14:00:00Z')"
recovery_time="$(epoch '2026-09-30T01:30:00Z')"

fresh_case() {
  export FAKE_DIR="${work_dir}/case-$1"
  rm -rf "${FAKE_DIR}"
  mkdir -p "${FAKE_DIR}/state" "${FAKE_DIR}/proc"
  runner_services
  printf 'QUIET_PERIOD_SECONDS=900\nNO_SHUTDOWN_WINDOW_UTC=0115-0150\n' > "${FAKE_DIR}/config"
  # Up for 2 hours by default: the boot itself is long past the quiet period.
  printf '7200.42 1000.00\n' > "${FAKE_DIR}/uptime"
  : > "${FAKE_DIR}/systemctl.log"
}

run_check() {
  local now="$1"
  CERTIGO_IDLE_NOW="${now}" \
    CERTIGO_IDLE_CONFIG_FILE="${FAKE_DIR}/config" \
    CERTIGO_IDLE_STATE_DIR="${FAKE_DIR}/state" \
    CERTIGO_IDLE_HOLD_FILE="${FAKE_DIR}/hold" \
    CERTIGO_IDLE_SYSTEMCTL="${bin_dir}/systemctl" \
    CERTIGO_IDLE_PGREP="${bin_dir}/pgrep" \
    CERTIGO_IDLE_PROC_ROOT="${FAKE_DIR}/proc" \
    CERTIGO_IDLE_UPTIME_FILE="${FAKE_DIR}/uptime" \
    CERTIGO_IDLE_DRAIN_SECONDS="${FAKE_DRAIN_SECONDS:-1}" \
    bash "${agent}" check
}

fail() {
  echo "idle-shutdown test failed: $*" >&2
  exit 1
}

assert_no_poweroff() {
  if grep -q '^poweroff' "${FAKE_DIR}/systemctl.log"; then
    fail "$1: poweroff must not be requested"
  fi
}

assert_poweroff() {
  grep -q '^poweroff$' "${FAKE_DIR}/systemctl.log" || fail "$1: poweroff was expected"
}

# 1. A running job is activity: it is recorded and nothing is stopped.
fresh_case busy
process 400 300 Runner.Worker
run_check "${afternoon}" >/dev/null
[[ "$(cat "${FAKE_DIR}/state/last-activity")" == "${afternoon}" ]] || fail "busy: activity not recorded"
! grep -Eq '^(stop|start|poweroff)' "${FAKE_DIR}/systemctl.log" || fail "busy: no runner or power action may be taken"

# 2. The quiet period counts from the last activity, and resets the guards.
fresh_case quiet
printf '%s\n' "$(( afternoon - 899 ))" > "${FAKE_DIR}/state/last-activity"
run_check "${afternoon}" >/dev/null
[[ "$(cat "${FAKE_DIR}/state/guards")" == 0 ]] || fail "quiet: guards must stay at 0"
assert_no_poweroff quiet

# 3. The quiet period also counts from boot: a fresh start is never shut down at once.
fresh_case boot
printf '120.00 10.00\n' > "${FAKE_DIR}/uptime"
run_check "${afternoon}" >/dev/null
run_check "$(( afternoon + 60 ))" >/dev/null
assert_no_poweroff boot

# 4. Quiet period elapsed: guard 1 does nothing, guard 2 stops the runners then powers off.
fresh_case idle
printf '%s\n' "$(( afternoon - 900 ))" > "${FAKE_DIR}/state/last-activity"
output="$(run_check "${afternoon}")"
grep -F 'guard 1/2' <<<"${output}" >/dev/null || fail "idle: first guard not reported"
assert_no_poweroff "idle guard 1"
run_check "$(( afternoon + 60 ))" >/dev/null
grep -q '^stop actions.runner.gchambaud_microsoft-Certigo.pr1.service actions.runner.gchambaud_microsoft-certigo-content.pr1.service$' \
  "${FAKE_DIR}/systemctl.log" || fail "idle: every runner unit must be stopped before poweroff"
assert_poweroff idle
[[ "$(grep -n '^stop' "${FAKE_DIR}/systemctl.log" | cut -d: -f1)" -lt \
  "$(grep -n '^poweroff' "${FAKE_DIR}/systemctl.log" | cut -d: -f1)" ]] ||
  fail "idle: the runners must be stopped before the poweroff"

# 5. Activity between the two guards resets everything.
fresh_case reset
printf '%s\n' "$(( afternoon - 900 ))" > "${FAKE_DIR}/state/last-activity"
run_check "${afternoon}" >/dev/null
process 410 310 Runner.Worker
run_check "$(( afternoon + 60 ))" >/dev/null
rm -r "${FAKE_DIR}/proc/410"
run_check "$(( afternoon + 120 ))" >/dev/null
assert_no_poweroff reset
[[ "$(cat "${FAKE_DIR}/state/guards")" == 0 ]] || fail "reset: guards must restart from 0"

# 6. Package maintenance by root counts as activity.
fresh_case apt
touch "${FAKE_DIR}/apt-root"
run_check "${afternoon}" >/dev/null
run_check "$(( afternoon + 60 ))" >/dev/null
assert_no_poweroff apt

# 6b. Signals that job code can fake are not activity: a Runner.Worker left behind (reparented
#     to init), a renamed pair "Runner.Listener" -> "Runner.Worker" outside the service tree,
#     and an apt/dpkg process run by the runner account.
fresh_case spoof
process 901 1 Runner.Worker
process 910 1 Runner.Listener
process 911 910 Runner.Worker
process 920 400 Runner.Listener
process 921 920 Runner.Worker
touch "${FAKE_DIR}/apt-user"
printf '%s\n' "$(( afternoon - 900 ))" > "${FAKE_DIR}/state/last-activity"
run_check "${afternoon}" >/dev/null
run_check "$(( afternoon + 60 ))" >/dev/null
assert_poweroff spoof

# 6c. A machine without any configured runner service (provisioning) is never shut down.
fresh_case no-runner
touch "${FAKE_DIR}/no-units"
printf '%s\n' "$(( afternoon - 3600 ))" > "${FAKE_DIR}/state/last-activity"
run_check "${afternoon}" >/dev/null
run_check "$(( afternoon + 60 ))" >/dev/null
assert_no_poweroff no-runner

# 7. The hold file suspends every shutdown.
fresh_case hold
touch "${FAKE_DIR}/hold"
printf '%s\n' "$(( afternoon - 3600 ))" > "${FAKE_DIR}/state/last-activity"
run_check "${afternoon}" >/dev/null
run_check "$(( afternoon + 60 ))" >/dev/null
assert_no_poweroff hold

# 8. Never inside the nightly recovery window, so its power-state check cannot be falsified.
fresh_case window
printf '%s\n' "$(( recovery_time - 3600 ))" > "${FAKE_DIR}/state/last-activity"
run_check "${recovery_time}" >/dev/null
run_check "$(( recovery_time + 60 ))" >/dev/null
assert_no_poweroff window
[[ "$(cat "${FAKE_DIR}/state/guards")" == 0 ]] || fail "window: no guard may be counted"
# ...and shutdown resumes after the window closes (01:50 UTC).
after_window="$(epoch '2026-09-30T01:50:00Z')"
run_check "${after_window}" >/dev/null
run_check "$(( after_window + 60 ))" >/dev/null
assert_poweroff "after window"

# 9. After the stop, a worker still reporting a cancellation is given the drain bound, then the
#    machine halts anyway: the bound is never a reason to stay up.
fresh_case drain
printf '%s\n' "$(( afternoon - 900 ))" > "${FAKE_DIR}/state/last-activity"
run_check "${afternoon}" >/dev/null
process 950 1 Runner.Worker
output="$(run_check "$(( afternoon + 60 ))")"
grep -F 'still present after 1s' <<<"${output}" >/dev/null || fail "drain: the bounded wait is not reported"
assert_poweroff drain

# 9b. Package maintenance that starts during the final guard cancels the shutdown.
fresh_case apt-during-guard
printf '%s\n' "$(( afternoon - 900 ))" > "${FAKE_DIR}/state/last-activity"
touch "${FAKE_DIR}/apt-after-stop"
run_check "${afternoon}" >/dev/null
output="$(run_check "$(( afternoon + 60 ))")"
assert_no_poweroff apt-during-guard
grep -q '^start actions.runner.gchambaud_microsoft-Certigo.pr1.service actions.runner.gchambaud_microsoft-certigo-content.pr1.service$' \
  "${FAKE_DIR}/systemctl.log" || fail "apt-during-guard: runners must be restarted"
grep -F 'package maintenance started during the final guard' <<<"${output}" >/dev/null ||
  fail "apt-during-guard: not reported"
# 10. A failed poweroff restarts the runners and fails the check.
fresh_case poweroff-failure
printf '%s\n' "$(( afternoon - 900 ))" > "${FAKE_DIR}/state/last-activity"
run_check "${afternoon}" >/dev/null
if FAKE_POWEROFF_RC=1 run_check "$(( afternoon + 60 ))" >/dev/null 2>&1; then
  fail "poweroff-failure: the check must fail"
fi
grep -q '^start actions.runner' "${FAKE_DIR}/systemctl.log" || fail "poweroff-failure: runners not restarted"

# 11. A failed stop never powers off and restarts what it could.
fresh_case stop-failure
printf '%s\n' "$(( afternoon - 900 ))" > "${FAKE_DIR}/state/last-activity"
run_check "${afternoon}" >/dev/null
if FAKE_STOP_RC=1 run_check "$(( afternoon + 60 ))" >/dev/null 2>&1; then
  fail "stop-failure: the check must fail"
fi
assert_no_poweroff stop-failure
grep -q '^start actions.runner' "${FAKE_DIR}/systemctl.log" || fail "stop-failure: runners not restarted"

# 12. Configuration is parsed strictly and a short quiet period is refused.
for bad_config in 'QUIET_PERIOD_SECONDS=299' 'QUIET_PERIOD_SECONDS=abc' \
  $'QUIET_PERIOD_SECONDS=900\nNO_SHUTDOWN_WINDOW_UTC=25:00' \
  $'QUIET_PERIOD_SECONDS=900\nPATH=/tmp'; do
  fresh_case "bad-config"
  printf '%s\n' "${bad_config}" > "${FAKE_DIR}/config"
  printf '%s\n' "$(( afternoon - 3600 ))" > "${FAKE_DIR}/state/last-activity"
  if run_check "${afternoon}" >/dev/null 2>&1; then
    fail "bad-config: '${bad_config}' must be refused"
  fi
  assert_no_poweroff "bad-config"
done
fresh_case missing-config
rm "${FAKE_DIR}/config"
if run_check "${afternoon}" >/dev/null 2>&1; then
  fail "missing-config: the check must fail closed"
fi

# 13. The installer validates the quiet period before touching anything.
if install_output="$(bash "${agent}" install 299 2>&1)"; then
  fail "install: a 299-second quiet period must be refused"
fi
grep -F 'between 300 and 86400' <<<"${install_output}" >/dev/null || fail "install: wrong refusal"
if bash "${agent}" unknown >/dev/null 2>&1; then
  fail "an unknown command must be refused"
fi

echo "idle-shutdown tests passed"
