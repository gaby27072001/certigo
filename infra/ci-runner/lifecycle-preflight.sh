#!/usr/bin/env bash
set -euo pipefail

operation="${1:-}"
if [[ "${operation}" != "start" && "${operation}" != "deallocate" ]]; then
  echo "Usage: lifecycle-preflight.sh <start|deallocate>" >&2
  exit 64
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
subscription_id="${AZURE_SUBSCRIPTION_ID:?Set AZURE_SUBSCRIPTION_ID explicitly.}"
resource_group="${CERTIGO_CI_RESOURCE_GROUP:-rg-certigo-ci}"
vmss_name="${CERTIGO_RUNNER_VMSS:-vmss-certigo-runner-zonal}"
state_file="${LIFECYCLE_STATE_FILE:-}"
config_file="${root}/infra/ci-runner/capacity-controller.config.json"

work_dir="$(mktemp -d)"
trap 'rm -rf -- "${work_dir}"' EXIT
chmod 700 "${work_dir}"

if [[ -n "${state_file}" && ! -f "${state_file}" ]]; then
  echo "LIFECYCLE_STATE_FILE must reference an existing read-only state snapshot." >&2
  exit 66
fi

mapfile -t repositories < <(
  node -e '
    const config = JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8"));
    for (const repository of config.repositories ?? []) console.log(repository);
  ' "${config_file}"
)
if [[ "${#repositories[@]}" -eq 0 ]]; then
  echo "capacity-controller.config.json must declare repositories." >&2
  exit 65
fi

collect_runners() {
  local output="${1}"
  local pages=()
  local repository
  for repository in "${repositories[@]}"; do
    local page_file="${work_dir}/runners-${#pages[@]}.json"
    local raw_file="${page_file}.raw"
    gh api --paginate --slurp \
      "repos/${repository}/actions/runners?per_page=100" \
      > "${raw_file}"
    node -e '
      const fs = require("node:fs");
      const runners = JSON.parse(
        fs.readFileSync(process.argv[1], "utf8"),
      ).flatMap((page) => page.runners ?? [])
        .map((runner) => ({ ...runner, repository: process.argv[2] }));
      process.stdout.write(JSON.stringify({ runners }));
    ' "${raw_file}" "${repository}" > "${page_file}"
    pages+=("${page_file}")
  done
  node -e '
    const fs = require("node:fs");
    const runners = process.argv.slice(1).flatMap(
      (file) => JSON.parse(fs.readFileSync(file, "utf8")).runners,
    );
    process.stdout.write(JSON.stringify({
      total_count: runners.length,
      runners,
    }));
  ' "${pages[@]}" > "${output}"
}

collect_runs() {
  local output="${1}"
  shift
  local statuses=("$@")
  local pages=()
  local repository
  local status
  for repository in "${repositories[@]}"; do
    for status in "${statuses[@]}"; do
      local page_file="${work_dir}/runs-${status}-${#pages[@]}.json"
      local raw_file="${page_file}.raw"
      gh api --paginate --slurp \
        "repos/${repository}/actions/runs?status=${status}&per_page=100" \
        > "${raw_file}"
      node -e '
        const fs = require("node:fs");
        const workflow_runs = JSON.parse(
          fs.readFileSync(process.argv[1], "utf8"),
        ).flatMap((page) => page.workflow_runs ?? [])
          .map((run) => ({ ...run, repository: process.argv[2] }));
        process.stdout.write(JSON.stringify({ workflow_runs }));
      ' "${raw_file}" "${repository}" > "${page_file}"
      pages+=("${page_file}")
    done
  done

  node -e '
    const fs = require("node:fs");
    const runsByKey = new Map();
    for (const file of process.argv.slice(1)) {
      const { workflow_runs: runs } = JSON.parse(
        fs.readFileSync(file, "utf8"),
      );
      for (const run of runs) {
        runsByKey.set(`${run.repository}#${run.id}`, run);
      }
    }
    const workflow_runs = [...runsByKey.values()];
    process.stdout.write(JSON.stringify({
      total_count: workflow_runs.length,
      workflow_runs,
    }));
  ' "${pages[@]}" > "${output}"

  while IFS=$'\t' read -r repository run_id; do
    local jobs_file="${work_dir}/jobs-${repository##*/}-${run_id}.json"
    local enriched="${output}.enriched"
    gh api --paginate --slurp \
      "repos/${repository}/actions/runs/${run_id}/jobs?per_page=100" \
      > "${jobs_file}"
    node -e '
      const fs = require("node:fs");
      const [output, jobsFile, repository, runId] =
        process.argv.slice(1);
      const collection = JSON.parse(fs.readFileSync(output, "utf8"));
      const run = collection.workflow_runs.find(
        (candidate) =>
          candidate.repository === repository &&
          Number(candidate.id) === Number(runId),
      );
      if (!run) {
        throw new Error(`Cannot enrich missing run ${repository}#${runId}`);
      }
      run.jobs = JSON.parse(
        fs.readFileSync(jobsFile, "utf8"),
      ).flatMap((page) => page.jobs ?? []);
      process.stdout.write(JSON.stringify(collection));
    ' "${output}" "${jobs_file}" "${repository}" "${run_id}" \
      > "${enriched}"
    mv "${enriched}" "${output}"
  done < <(
    node -e '
      const fs = require("node:fs");
      const { workflow_runs: runs } = JSON.parse(
        fs.readFileSync(process.argv[1], "utf8"),
      );
      for (const run of runs) {
        if (
          run.actor?.login === "dependabot[bot]" &&
          run.event === "dynamic"
        ) {
          console.log(`${run.repository}\t${run.id}`);
        }
      }
    ' "${output}"
  )
}

collect_runners "${work_dir}/runners.json"
collect_runs "${work_dir}/queued-runs.json" queued
collect_runs \
  "${work_dir}/active-runs.json" \
  in_progress waiting pending requested

az monitor autoscale show \
  --subscription "${subscription_id}" \
  --resource-group "${resource_group}" \
  --name "autoscale-${vmss_name}" \
  --output json > "${work_dir}/autoscale.json"

az vm list \
  --subscription "${subscription_id}" \
  --resource-group "${resource_group}" \
  --show-details \
  --output json > "${work_dir}/virtual-machines.json"

az vmss list \
  --subscription "${subscription_id}" \
  --resource-group "${resource_group}" \
  --output json > "${work_dir}/vm-scale-sets.json"

arguments=(
  --config "${config_file}"
  --operation "${operation}"
  --runners "${work_dir}/runners.json"
  --queued-runs "${work_dir}/queued-runs.json"
  --active-runs "${work_dir}/active-runs.json"
  --autoscale "${work_dir}/autoscale.json"
  --virtual-machines "${work_dir}/virtual-machines.json"
  --vm-scale-sets "${work_dir}/vm-scale-sets.json"
)
if [[ -n "${state_file}" ]]; then
  arguments+=(--state "${state_file}")
fi

node "${root}/infra/ci-runner/evaluate-lifecycle.mjs" "${arguments[@]}"
