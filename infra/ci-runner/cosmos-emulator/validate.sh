#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
runner_dir="${root}/infra/ci-runner/cosmos-emulator"

bash -n "${runner_dir}/bootstrap.sh"
bash -n "${runner_dir}/run-account-deletion.sh"
node --test "${runner_dir}/validate.test.mjs"
