#!/usr/bin/env bash
# Certigo — extinction locale d'un runner CI inactif (côté VM).
#
# Ce script est la SEULE autorité qui décide qu'une VM de runner est inactive. Il lit l'état
# du runner là où il est exact, sur la machine même (un processus `Runner.Worker` existe tant
# qu'un job tourne), au lieu de le déduire d'un CPU Azure ou d'un compteur de webhooks.
#
# Il ne désalloue rien et ne détient aucune identité : il arrête l'OS. La VM passe alors en
# `PowerState/stopped`, encore facturée, et le Logic App `logic-certigo-ci-runner-idle-deallocation`
# désalloue ensuite uniquement les VM dont l'OS s'est déjà arrêté. Le réveil est fait par le
# Logic App `logic-certigo-ci-runner-wake` sur webhook `workflow_job`. Voir
# docs/adr/ADR-022-runners-ci-a-la-demande.md.
#
# Contrat d'extinction (celui du contrôleur de capacité, appliqué localement) :
#   1. période calme réinitialisable : aucune activité depuis QUIET_PERIOD_SECONDS (>= 300 s),
#      comptée depuis max(démarrage, dernière activité, installation) ;
#   2. deux gardes : deux passages consécutifs du timer (15 s) toujours inactifs ;
#   3. garde finale : les services `actions.runner.*` sont arrêtés (le listener ferme sa session,
#      GitHub cesse de lui attribuer des jobs), puis l'absence de job est relue ; un job apparu
#      entre-temps annule l'extinction et relance les services ;
#   4. jamais d'extinction dans la fenêtre de la reprise nocturne (01:15-01:50 UTC par défaut),
#      pour que la vérification de power state de la reprise ne puisse pas être faussée ;
#   5. jamais d'extinction d'une machine sans service `actions.runner.*` (provisionnement ou
#      réenregistrement en cours).
# Toute activité remet la période calme et les gardes à zéro. N'est une activité qu'un signal
# que le code d'une PR ne peut pas imiter : un `Runner.Worker` dont le parent est un
# `Runner.Listener` (le listener est le seul à lancer un worker), ou apt/dpkg exécuté par root.
#
# Limite assumée : un job attribué par GitHub dans la fraction de seconde entre la dernière
# lecture et l'arrêt du listener est annulé par cet arrêt. GitHub ne garantit pas l'absence
# d'attribution à un runner persistant qui s'arrête ; seuls des runners éphémères l'éliminent
# (ADR-018). Estimation et mesure : docs/adr/ADR-022-runners-ci-a-la-demande.md.
if [ -z "${BASH_VERSION:-}" ]; then
  exec /bin/bash "$0" "$@"
fi
set -euo pipefail

readonly INSTALL_PATH='/usr/local/sbin/certigo-idle-shutdown'
readonly SERVICE_NAME='certigo-idle-shutdown.service'
readonly TIMER_NAME='certigo-idle-shutdown.timer'
readonly UNIT_DIR="${CERTIGO_IDLE_UNIT_DIR:-/etc/systemd/system}"
readonly IMDS_UNIT='certigo-block-imds.service'
readonly IMDS_DROP_IN_NAME='10-certigo-before-cloud-init.conf'
readonly MINIMUM_QUIET_PERIOD_SECONDS=300
readonly REQUIRED_GUARDS=2
readonly DEFAULT_NO_SHUTDOWN_WINDOW_UTC='0115-0150'

CONFIG_FILE="${CERTIGO_IDLE_CONFIG_FILE:-/etc/certigo-idle-shutdown.env}"
STATE_DIR="${CERTIGO_IDLE_STATE_DIR:-/run/certigo-idle-shutdown}"
HOLD_FILE="${CERTIGO_IDLE_HOLD_FILE:-/etc/certigo-idle-shutdown.hold}"
SYSTEMCTL="${CERTIGO_IDLE_SYSTEMCTL:-/usr/bin/systemctl}"
PGREP="${CERTIGO_IDLE_PGREP:-/usr/bin/pgrep}"
PROC_ROOT="${CERTIGO_IDLE_PROC_ROOT:-/proc}"
UPTIME_FILE="${CERTIGO_IDLE_UPTIME_FILE:-/proc/uptime}"

log() {
  printf 'certigo-idle-shutdown: %s\n' "$*"
}

usage() {
  cat >&2 <<'EOF'
Usage:
  idle-shutdown.sh install <quiet-period-seconds>   (root) installe ou met à jour l'agent
  idle-shutdown.sh uninstall                        (root) retire l'agent (rollback)
  idle-shutdown.sh check                            passage du timer (15 s)
  idle-shutdown.sh status                           état lisible par l'opérateur
EOF
  exit 64
}

now_epoch() {
  if [[ -n "${CERTIGO_IDLE_NOW:-}" ]]; then
    printf '%s\n' "${CERTIGO_IDLE_NOW}"
  else
    date -u +%s
  fi
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "Run this command as root." >&2
    exit 1
  fi
}

is_non_negative_integer() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

read_integer_file() {
  local file="$1" fallback="$2" value
  if [[ -r "${file}" ]]; then
    value="$(tr -d '[:space:]' < "${file}")"
    if is_non_negative_integer "${value}"; then
      printf '%s\n' "${value}"
      return
    fi
  fi
  printf '%s\n' "${fallback}"
}

validate_quiet_period() {
  local value="$1"
  if ! is_non_negative_integer "${value}" ||
    (( value < MINIMUM_QUIET_PERIOD_SECONDS || value > 86400 )); then
    echo "The quiet period must be an integer between ${MINIMUM_QUIET_PERIOD_SECONDS} and 86400 seconds; got '${value}'." >&2
    return 1
  fi
}

validate_window() {
  local window="$1"
  if [[ ! "${window}" =~ ^([01][0-9]|2[0-3])[0-5][0-9]-([01][0-9]|2[0-3])[0-5][0-9]$ ]]; then
    echo "NO_SHUTDOWN_WINDOW_UTC must look like HHMM-HHMM; got '${window}'." >&2
    return 1
  fi
}

load_config() {
  if [[ ! -r "${CONFIG_FILE}" ]]; then
    echo "Missing configuration ${CONFIG_FILE}; refusing to decide anything." >&2
    return 1
  fi
  local key value
  QUIET_PERIOD_SECONDS=''
  NO_SHUTDOWN_WINDOW_UTC="${DEFAULT_NO_SHUTDOWN_WINDOW_UTC}"
  # The file is parsed, never sourced: only two known keys are accepted.
  while IFS='=' read -r key value; do
    case "${key}" in
      QUIET_PERIOD_SECONDS) QUIET_PERIOD_SECONDS="${value}" ;;
      NO_SHUTDOWN_WINDOW_UTC) NO_SHUTDOWN_WINDOW_UTC="${value}" ;;
      ''|'#'*) ;;
      *) echo "Unknown configuration key '${key}' in ${CONFIG_FILE}." >&2; return 1 ;;
    esac
  done < "${CONFIG_FILE}"
  validate_quiet_period "${QUIET_PERIOD_SECONDS}"
  validate_window "${NO_SHUTDOWN_WINDOW_UTC}"
}

uptime_seconds() {
  local uptime
  uptime="$(awk '{ print int($1) }' "${UPTIME_FILE}")"
  if ! is_non_negative_integer "${uptime}"; then
    echo "Cannot read the uptime from ${UPTIME_FILE}." >&2
    return 1
  fi
  printf '%s\n' "${uptime}"
}

parent_command_of() {
  local stat rest ppid
  stat="$(cat "${PROC_ROOT}/$1/stat" 2>/dev/null)" || return 1
  # The command name is parenthesised and may itself contain spaces or parentheses.
  rest="${stat##*) }"
  ppid="$(awk '{ print $2 }' <<<"${rest}")"
  is_non_negative_integer "${ppid}" || return 1
  cat "${PROC_ROOT}/${ppid}/comm" 2>/dev/null
}

# A job in progress is the only reason a runner VM must stay up. Only the listener spawns a
# worker, so a `Runner.Worker` process left behind by job code (reparented, or merely renamed)
# is not activity. Package maintenance by root is activity too, so that an OS update is never
# cut in the middle; the runner account cannot start a root apt/dpkg beyond its sudo allow-list.
activity_description() {
  local pid
  while read -r pid; do
    [[ -n "${pid}" ]] || continue
    if [[ "$(parent_command_of "${pid}")" == 'Runner.Listener' ]]; then
      printf 'job\n'
      return 0
    fi
  done < <("${PGREP}" -x 'Runner\.Worker' 2>/dev/null || true)
  if "${PGREP}" -u root -x 'apt|apt-get|dpkg|unattended-upgr' >/dev/null 2>&1; then
    printf 'package-maintenance\n'
    return 0
  fi
  return 1
}

configured_runner_units() {
  "${SYSTEMCTL}" list-unit-files --type=service --no-legend 'actions.runner.*' |
    awk '$1 ~ /^actions\.runner\./ && $2 != "masked" { print $1 }'
}

ensure_state_dir() {
  if [[ ! -d "${STATE_DIR}" ]]; then
    install -d -m 0700 "${STATE_DIR}"
  fi
}

record_activity() {
  printf '%s\n' "$1" > "${STATE_DIR}/last-activity"
  printf '0\n' > "${STATE_DIR}/guards"
}

reset_guards() {
  printf '0\n' > "${STATE_DIR}/guards"
}

inside_no_shutdown_window() {
  local now="$1" window_start window_end hhmm
  window_start="${NO_SHUTDOWN_WINDOW_UTC%-*}"
  window_end="${NO_SHUTDOWN_WINDOW_UTC#*-}"
  hhmm="$(date -u -d "@${now}" +%H%M)"
  if [[ "${window_start}" < "${window_end}" ]]; then
    [[ ! "${hhmm}" < "${window_start}" && "${hhmm}" < "${window_end}" ]]
  else
    [[ ! "${hhmm}" < "${window_start}" || "${hhmm}" < "${window_end}" ]]
  fi
}

active_runner_units() {
  "${SYSTEMCTL}" list-units --type=service --state=active --no-legend --plain 'actions.runner.*' |
    awk '$1 ~ /^actions\.runner\./ { print $1 }'
}

restart_runner_units() {
  if (( $# > 0 )); then
    "${SYSTEMCTL}" start "$@" || log "could not restart runner unit(s): $*"
  fi
}

check() {
  load_config
  ensure_state_dir

  local now boot last idle_since idle guards activity
  now="$(now_epoch)"
  if [[ -e "${HOLD_FILE}" ]]; then
    reset_guards
    log "hold file ${HOLD_FILE} present; shutdown suspended"
    return 0
  fi

  if activity="$(activity_description)"; then
    record_activity "${now}"
    return 0
  fi

  boot=$(( now - $(uptime_seconds) ))
  last="$(read_integer_file "${STATE_DIR}/last-activity" 0)"
  idle_since=$(( boot > last ? boot : last ))
  idle=$(( now - idle_since ))
  if (( idle < QUIET_PERIOD_SECONDS )); then
    reset_guards
    return 0
  fi

  if [[ -z "$(configured_runner_units)" ]]; then
    reset_guards
    log "no actions.runner.* service is configured; a machine being provisioned is never shut down"
    return 0
  fi

  if inside_no_shutdown_window "${now}"; then
    reset_guards
    log "idle for ${idle}s but inside the recovery window ${NO_SHUTDOWN_WINDOW_UTC} UTC; waiting"
    return 0
  fi

  guards=$(( $(read_integer_file "${STATE_DIR}/guards" 0) + 1 ))
  printf '%s\n' "${guards}" > "${STATE_DIR}/guards"
  if (( guards < REQUIRED_GUARDS )); then
    log "idle for ${idle}s; guard ${guards}/${REQUIRED_GUARDS}"
    return 0
  fi

  # Final guard: close every runner session first, so that GitHub stops assigning jobs, then
  # re-read the job state. Only an idle machine with no listener left is powered off.
  local -a units=()
  mapfile -t units < <(active_runner_units)
  log "idle for ${idle}s after ${guards} guards; stopping ${#units[@]} runner unit(s)"
  if (( ${#units[@]} > 0 )) && ! "${SYSTEMCTL}" stop "${units[@]}"; then
    restart_runner_units "${units[@]}"
    record_activity "${now}"
    log "could not stop the runner units; shutdown abandoned"
    return 1
  fi
  if activity="$(activity_description)"; then
    restart_runner_units "${units[@]}"
    record_activity "${now}"
    log "${activity} appeared during the final guard; runners restarted, shutdown abandoned"
    return 0
  fi

  log "powering off for deallocation (PowerState/stopped, then deallocated by logic-certigo-ci-runner-idle-deallocation)"
  if ! "${SYSTEMCTL}" poweroff; then
    restart_runner_units "${units[@]}"
    record_activity "${now}"
    log "poweroff failed; runners restarted"
    return 1
  fi
}

write_units() {
  cat > "${UNIT_DIR}/${SERVICE_NAME}" <<EOF
[Unit]
Description=Certigo idle CI runner shutdown check
Documentation=file://${INSTALL_PATH}

[Service]
Type=oneshot
ExecStart=${INSTALL_PATH} check
EOF
  cat > "${UNIT_DIR}/${TIMER_NAME}" <<'EOF'
[Unit]
Description=Certigo idle CI runner shutdown check (every 15 seconds)

[Timer]
OnBootSec=60
OnUnitActiveSec=15
AccuracySec=1

[Install]
WantedBy=timers.target
EOF
  chmod 0644 "${UNIT_DIR}/${SERVICE_NAME}" "${UNIT_DIR}/${TIMER_NAME}"
}

# PR runners block IMDS twice: the NSG drops the packets, and certigo-block-imds.service
# rejects them in the OS. Instances created before the current bootstrap load that unit only
# after cloud-init, whose Azure datasource then waits 10 x 30 s on the dropped packets at
# every boot (measured 2026-09-30: runner online 5 min 13 s after boot). Ordering the OS
# block before cloud-init makes those requests fail at once and closes IMDS earlier in boot.
harden_imds_boot_order() {
  if [[ ! -f "${UNIT_DIR}/${IMDS_UNIT}" ]]; then
    return 0
  fi
  install -d -m 0755 "${UNIT_DIR}/${IMDS_UNIT}.d"
  cat > "${UNIT_DIR}/${IMDS_UNIT}.d/${IMDS_DROP_IN_NAME}" <<'EOF'
[Unit]
DefaultDependencies=no
After=local-fs.target
Before=network-pre.target cloud-init-local.service
Wants=network-pre.target
EOF
  chmod 0644 "${UNIT_DIR}/${IMDS_UNIT}.d/${IMDS_DROP_IN_NAME}"
  log "IMDS block ordered before cloud-init-local.service"
}

install_agent() {
  (( $# == 1 )) || usage
  local quiet_period="$1"
  validate_quiet_period "${quiet_period}"
  require_root

  local source_path
  source_path="$(readlink -f "$0")"
  if [[ "${source_path}" != "${INSTALL_PATH}" ]]; then
    install -m 0755 -o root -g root "${source_path}" "${INSTALL_PATH}"
  fi
  umask 022
  cat > "${CONFIG_FILE}" <<EOF
QUIET_PERIOD_SECONDS=${quiet_period}
NO_SHUTDOWN_WINDOW_UTC=${DEFAULT_NO_SHUTDOWN_WINDOW_UTC}
EOF
  chmod 0644 "${CONFIG_FILE}"
  write_units
  harden_imds_boot_order
  "${SYSTEMCTL}" daemon-reload
  ensure_state_dir
  # Installing counts as activity: an agent installed on a machine that has been up and idle
  # for hours must still wait a full quiet period before its first shutdown.
  record_activity "$(now_epoch)"
  "${SYSTEMCTL}" enable --now "${TIMER_NAME}"
  status
  echo "certigo-idle-shutdown installed"
}

uninstall_agent() {
  require_root
  "${SYSTEMCTL}" disable --now "${TIMER_NAME}" || true
  rm -f "${UNIT_DIR}/${SERVICE_NAME}" "${UNIT_DIR}/${TIMER_NAME}" "${CONFIG_FILE}" "${INSTALL_PATH}"
  rm -rf "${STATE_DIR}"
  "${SYSTEMCTL}" daemon-reload
  # The IMDS boot-order drop-in is deliberately kept: it is a hardening, not part of the
  # shutdown mechanism.
  echo "certigo-idle-shutdown uninstalled"
}

status() {
  local sha='absent'
  if [[ -f "${INSTALL_PATH}" ]]; then
    sha="$(sha256sum "${INSTALL_PATH}" | awk '{ print $1 }')"
  fi
  printf 'script_sha256=%s\n' "${sha}"
  printf 'timer=%s\n' "$("${SYSTEMCTL}" is-active "${TIMER_NAME}" 2>/dev/null || true)"
  if [[ -r "${CONFIG_FILE}" ]]; then
    sed 's/^/config./' "${CONFIG_FILE}"
  else
    printf 'config=absent\n'
  fi
  printf 'hold=%s\n' "$([[ -e "${HOLD_FILE}" ]] && echo present || echo absent)"
  printf 'last_activity=%s\n' "$(read_integer_file "${STATE_DIR}/last-activity" 0)"
  printf 'guards=%s\n' "$(read_integer_file "${STATE_DIR}/guards" 0)"
  printf 'imds_drop_in=%s\n' "$([[ -f "${UNIT_DIR}/${IMDS_UNIT}.d/${IMDS_DROP_IN_NAME}" ]] && echo present || echo absent)"
  printf 'uptime_seconds=%s\n' "$(uptime_seconds)"
}

main() {
  (( $# >= 1 )) || usage
  local command="$1"
  shift
  case "${command}" in
    install) install_agent "$@" ;;
    uninstall) (( $# == 0 )) || usage; uninstall_agent ;;
    check) (( $# == 0 )) || usage; check ;;
    status) (( $# == 0 )) || usage; status ;;
    *) usage ;;
  esac
}

main "$@"
