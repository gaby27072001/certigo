"""GitHub provenance and the only remote mutation: explicit repository_dispatch."""
from __future__ import annotations

from datetime import timedelta
from pathlib import Path
import re

from .common import (PromotionError, binding, digest, encoded, equal, exclusive, instant, match,
                     object_keys, positive, require, utc, verified)
from .monitor import rollback_allowed
from .preflight import approval, analyze


def endpoint(commands):
    return "repos/" + commands.context.value["repository"]


def run_state(commands, run_id):
    require(match(r"[1-9][0-9]{0,19}", run_id), "Invalid source run ID.")
    result = commands.gh(f"{endpoint(commands)}/actions/runs/{run_id}")
    require(type(result) is dict and str(result.get("id")) == run_id, "Run ID mismatch.")
    return result


def paged(commands, path, key, total_key="total_count"):
    results, total = [], None
    for page in range(1, 101):
        result = commands.gh(f"{path}{'&' if '?' in path else '?'}per_page=100&page={page}")
        require(type(result) is dict and type(result.get(key)) is list
                and type(result.get(total_key)) is int and result[total_key] >= 0,
                "Malformed GitHub pagination.")
        total = result[total_key] if total is None else total
        require(total == result[total_key], "GitHub result changed while paging; repeat read.")
        values = result[key]
        require(all(type(v) is dict and positive(v.get("id")) for v in values), "Malformed GitHub items.")
        results.extend(values)
        require(len({v["id"] for v in results}) == len(results), "Duplicate GitHub page.")
        if len(results) == total:
            return results
        require(values and len(results) < total, "Incomplete GitHub pagination.")
    raise PromotionError("GitHub pagination limit reached.")


def executed_job(jobs, name, steps):
    require(type(jobs) is list and steps, "Required jobs and steps must be explicit.")
    matches = [job for job in jobs if type(job) is dict and job.get("name") == name]
    require(len(matches) == 1, "Required job absent or ambiguous.")
    job = matches[0]
    require(job.get("status") == "completed" and job.get("conclusion") == "success",
            "Required job failed, pending, or skipped.")
    start, end = instant(job.get("started_at")), instant(job.get("completed_at"))
    require(start < end, "Required job has no executed interval.")
    require(type(job.get("steps")) is list, "Required job has no step evidence.")
    for name in steps:
        found = [step for step in job["steps"] if type(step) is dict and step.get("name") == name]
        require(len(found) == 1, "Required step absent or ambiguous.")
        step = found[0]
        require(step.get("status") == "completed" and step.get("conclusion") == "success",
                "Required step failed, pending, or skipped.")
        require(start <= instant(step.get("started_at")) <= instant(step.get("completed_at")) <= end,
                "Required step timestamps not within executed job.")
    return job


def source_proof(commands, run_id, sha):
    commands.context.scope(sha)
    run = run_state(commands, run_id)
    repo = commands.context.value["repository"]
    require(run.get("status") == "completed" and run.get("conclusion") == "success"
            and run.get("event") == "push" and run.get("head_branch") == "main"
            and run.get("head_sha") == sha and run.get("path") == ".github/workflows/cd-backend.yml"
            and isinstance(run.get("repository"), dict)
            and run["repository"].get("full_name") == repo and positive(run.get("run_attempt")),
            "Source is not a successful exact-SHA main-push CD run.")
    jobs = paged(commands, f"{endpoint(commands)}/actions/runs/{run_id}/attempts/{run['run_attempt']}/jobs",
                 "jobs")
    job = executed_job(jobs, "Build immutable backend release",
                       ["Create deterministic ZIP and release manifest", "Record trusted package digest",
                        "Retain build-once release in private dev storage"])
    raw = commands.run([*commands.context.value["githubCommand"], "run", "view", run_id,
                        "--repo", repo, "--attempt", str(run["run_attempt"]),
                        "--job", str(job["id"]), "--log"])
    try:
        log = raw.decode("utf-8-sig")
    except UnicodeError:
        raise PromotionError("Source log is not UTF-8.") from None
    digests = set(re.findall(r"(?<![A-Za-z_])CERTIGO_RELEASE_PACKAGE_SHA256=([0-9a-f]{64})(?![0-9a-f])", log))
    require(len(digests) == 1, "Missing or ambiguous trusted package digest.")
    return {"runId": run_id, "sha": sha, "attempt": run["run_attempt"], "packageSha256": digests.pop(),
            "sourceLogSha256": digest(raw), "observedUtc": utc().isoformat(),
            "provenance": "successful-main-push-CD",
            "runtimeZipBytesVerified": False}


def deployment_proof(commands, run_id, sha, source, operation):
    require(operation in ("promotion", "rollback"), "Invalid deployment operation.")
    run = run_state(commands, run_id)
    require(run.get("head_sha") == sha and run.get("status") == "completed"
            and run.get("conclusion") == "success" and run.get("event") == "repository_dispatch"
            and run.get("path") == ".github/workflows/cd-backend.yml"
            and positive(run.get("run_attempt")), "Promotion run not successful on approved main.")
    jobs = paged(commands, f"{endpoint(commands)}/actions/runs/{run_id}/attempts/{run['run_attempt']}/jobs",
                 "jobs")
    env = commands.context.value["environment"]
    infra_step = ("Deploy current infrastructure" if operation == "promotion"
                  else "Resolve existing infrastructure for code-only rollback")
    infra = executed_job(jobs, f"Prepare infrastructure ({env})", [infra_step,
                         "Verify private networking before code deployment"])
    backend = executed_job(jobs, f"Deploy verified backend ({env})",
                           ["Reverify release before deployment",
                            "Deploy once and run liveness/readiness smoke tests"])
    raw = commands.run([*commands.context.value["githubCommand"], "run", "view", run_id,
                        "--repo", commands.context.value["repository"], "--attempt", str(run["run_attempt"]),
                        "--job", str(backend["id"]), "--log"])
    try:
        log = raw.decode("utf-8-sig")
    except UnicodeError:
        raise PromotionError("Deployment log is not UTF-8.") from None
    for name, expected in {"COMMIT_SHA": source["sha"], "EXPECTED_PACKAGE_SHA256": source["packageSha256"],
                           "SOURCE_RUN_ID": source["runId"], "DEPLOYMENT_OPERATION": operation,
                           "TARGET_ENV": env}.items():
        require(set(re.findall(r"\b" + name + r": ([^\s]+)", log)) == {expected},
                "Deployment log provenance mismatch.")
    return {"scope": commands.context.scope(sha), "runId": run_id, "source": source,
            "infraJobId": infra["id"], "backendJobId": backend["id"], "cdJobsExecuted": True,
            "deploymentLogSha256": digest(raw), "runtimeZipBytesVerified": False,
            "runtimeStatus": "not-observed"}


def dispatch(commands, authorization, preflight_dir, before_dir, receipts, *,
             execute=False, monitor_dir=None, clock=utc):
    object_keys(authorization, ("approval", "operation", "sourceRunId", "sourceSha", "packageSha256",
                                "preflightHash", "beforeHash", "monitorHash"))
    require(execute is True, "Dispatch requires --execute and a bounded explicit authorization.")
    scope = authorization["approval"]["scope"]
    require(type(scope) is dict and "sha" in scope, "Invalid dispatch scope.")
    require(equal(scope, commands.context.scope(scope["sha"])), "Dispatch scope mismatch.")
    approval(authorization["approval"], scope, clock())
    operation = authorization["operation"]
    require(operation in ("promotion", "rollback"), "Invalid dispatch operation.")
    require(match(r"[1-9][0-9]{0,19}", authorization["sourceRunId"])
            and match(r"[0-9a-f]{40}", authorization["sourceSha"])
            and match(r"[0-9a-f]{64}", authorization["packageSha256"]), "Invalid release provenance.")
    preflight, before = verified(preflight_dir, "preflight"), verified(before_dir, "snapshot")
    require(equal(preflight["scope"], scope) and equal(before["scope"], scope), "Evidence scope mismatch.")
    require(preflight["safe"] is True and preflight["mode"] == "Incremental", "Preflight blocks promotion.")
    # Recompute rather than trusting a saved boolean or a zero process exit code.
    checked = analyze(preflight["whatIf"], preflight["decisions"], scope,
                      preflight["resources"], clock())
    require(checked["safe"] is True, "Preflight decisions no longer valid.")
    require(binding(preflight_dir) == authorization["preflightHash"] == before["preflightHash"]
            and binding(before_dir) == authorization["beforeHash"] and before["phase"] == "before"
            and equal(before["resources"], preflight["resources"]), "Evidence binding mismatch.")
    require(operation != "promotion" or authorization["sourceSha"] == scope["sha"],
            "Promotion source must be the exact approved main.")
    if operation == "rollback":
        require(monitor_dir is not None, "Rollback requires original live monitor evidence.")
        rollback_allowed(monitor_dir, authorization["monitorHash"], scope, clock())
    else:
        require(authorization["monitorHash"] is None and monitor_dir is None,
                "Promotion cannot borrow a monitor authorization.")
    source = source_proof(commands, authorization["sourceRunId"], authorization["sourceSha"])
    require(source["packageSha256"] == authorization["packageSha256"], "Source digest changed.")
    current = commands.gh(f"{endpoint(commands)}/commits/main")
    require(type(current) is dict and current.get("sha") == scope["sha"], "Main advanced; repeat preflight.")
    runs = paged(commands, f"{endpoint(commands)}/actions/workflows/cd-backend.yml/runs?event=repository_dispatch",
                 "workflow_runs")
    require(all(run.get("status") == "completed" for run in runs), "Another dispatch is active.")
    now = clock()
    approval(authorization["approval"], scope, now)
    for timestamp, age in ((preflight["startedUtc"], 30), (before["completedUtc"], 5)):
        require(timedelta(0) <= now - instant(timestamp) <= timedelta(minutes=age),
                "Evidence stale or future-dated.")
    if operation == "rollback":
        rollback_allowed(monitor_dir, authorization["monitorHash"], scope, now)
    root = Path(receipts)
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    payload = {"event_type": "promote-backend", "client_payload": {
        "environment": scope["environment"], "operation": operation,
        "source_run_id": authorization["sourceRunId"],
    }}
    key = digest(encoded({"scope": scope, "payload": payload}))
    approval_key = digest(encoded(authorization["approval"]["id"]))
    receipt = root / (key + ".requested.json")
    # Both records are permanent and fail closed even on a crash between writes.
    exclusive(root / ("approval-" + approval_key + ".json"), {"requestKey": key})
    exclusive(receipt, {"state": "requested-outcome-unknown", "requestedUtc": now.isoformat(),
                        "authorizationHash": digest(encoded(authorization)), "payload": payload,
                        "scope": scope, "previousRunIds": [run["id"] for run in runs]})
    approval(authorization["approval"], scope, clock())
    if operation == "rollback":
        rollback_allowed(monitor_dir, authorization["monitorHash"], scope, clock())
    commands.gh(f"{endpoint(commands)}/dispatches", body=payload)
    exclusive(root / (key + ".accepted.json"), {
        "state": "accepted-not-deployed", "acceptedUtc": clock().isoformat(),
        "requestHash": digest(receipt.read_bytes()),
    })
    return receipt
