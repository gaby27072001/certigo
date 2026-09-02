#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
evidence_root="${PHASE_B_EVIDENCE_DIR:-}"

if [[ -n "${evidence_root}" ]]; then
  mkdir -p "${evidence_root}"
  chmod 700 "${evidence_root}"
  export PHASE_B1_EVIDENCE_DIR="${evidence_root}/b1"
  export PHASE_B2_EVIDENCE_DIR="${evidence_root}/b2"
  mkdir -p "${PHASE_B1_EVIDENCE_DIR}" "${PHASE_B2_EVIDENCE_DIR}"
  chmod 700 "${PHASE_B1_EVIDENCE_DIR}" "${PHASE_B2_EVIDENCE_DIR}"
fi

bash "${root}/infra/governance/what-if-phase-b1.sh"
