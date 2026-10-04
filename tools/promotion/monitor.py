"""One-hour read-only monitoring with immutable, hash-chained observations."""
from __future__ import annotations

from contextlib import contextmanager
from datetime import timedelta
import os
from pathlib import Path
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, build_opener

from .common import (PromotionError, binding, bundle, decode, digest, equal, instant, match,
                     object_keys, positive, require, utc, verified)


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def health(url, timeout=30):
    parsed = urlsplit(url)
    require(parsed.scheme == "https" and parsed.hostname and not parsed.username
            and not parsed.password and not parsed.query and not parsed.fragment,
            "Health probes require credential-free HTTPS URLs.")
    try:
        with build_opener(NoRedirect).open(url, timeout=timeout) as response:
            body = response.read(1024 * 1024 + 1)
            require(len(body) <= 1024 * 1024, "Health response too large.")
            return {"status": response.status, "bodySha256": digest(body)}
    except HTTPError as error:
        return {"status": error.code, "error": "http-error"}
    except (URLError, TimeoutError, OSError):
        return {"status": None, "error": "transport-error"}


def monitor_config(value, context):
    object_keys(value, ("resourceId", "workspaceId", "healthUrls", "ingestionSeconds", "pollSeconds"))
    context.resource(value["resourceId"])
    require(match(r"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}", value["workspaceId"]),
            "Invalid workspace ID.")
    object_keys(value["healthUrls"], ("live", "ready"))
    for url in value["healthUrls"].values():
        require(isinstance(url, str), "Invalid health URL.")
        parsed = urlsplit(url)
        require(parsed.scheme == "https" and parsed.hostname and not parsed.username
                and not parsed.password and not parsed.query and not parsed.fragment,
                "Health URLs must be credential-free HTTPS.")
    require(positive(value["ingestionSeconds"]) and value["ingestionSeconds"] <= 900
            and positive(value["pollSeconds"]) and value["pollSeconds"] <= 180,
            "Use 1..900 ingestion seconds and 1..180 polling seconds.")
    return value


def telemetry(commands, config, start, end):
    require(start < end and end - start <= timedelta(hours=24), "Telemetry window must be <=24 hours.")
    # No arbitrary KQL substitution: every source is explicitly scoped and time-bounded.
    rid = config["resourceId"]
    require('"' not in rid and "\\" not in rid and "\n" not in rid, "Unsafe resource literal.")
    sources = []
    for table, metric, grouping, failed in (
        ("AppRequests", "requests", 'Name=""', 'toint(ResultCode) >= 500'),
        ("AppAvailabilityResults", "availability", 'Name=strcat(Name, "@", Location)', 'Success == false'),
        ("AppExceptions", "exceptions", "Name=ExceptionType", "true"),
    ):
        sources.append(f'({table} | where _ResourceId =~ "{rid}"'
                       f" | where TimeGenerated between (datetime({start.isoformat()}) .. datetime({end.isoformat()}))"
                       f" | summarize Count=count(), Failed=countif({failed}), Last=max(TimeGenerated) by {grouping}"
                       f' | extend Metric="{metric}" | project Metric, Name, Count, Failed, Last)')
    query = "union " + ",\n".join(sources)
    payload = {"query": query, "timespan": start.isoformat() + "/" + end.isoformat()}
    result = decode(commands.run([
        *commands.context.value["azureCommand"], "rest", "--method", "post",
        "--url", f"https://api.loganalytics.io/v1/workspaces/{config['workspaceId']}/query",
        "--resource", "https://api.loganalytics.io", "--body", encoded_payload(payload),
        "--output", "json", "--only-show-errors",
    ]))
    rows = telemetry_rows(result, start, end)
    return {"query": payload, "result": result, "rows": rows}


def encoded_payload(value):
    from .common import encoded
    return encoded(value).decode("utf-8").strip()


def telemetry_rows(result, start, end):
    require(type(result) is dict and set(result) == {"tables"} and type(result["tables"]) is list
            and len(result["tables"]) == 1, "Partial or malformed telemetry.")
    table = result["tables"][0]
    require(type(table) is dict and type(table.get("columns")) is list
            and type(table.get("rows")) is list, "Invalid telemetry table.")
    columns = table["columns"]
    require(all(type(c) is dict for c in columns)
            and [c.get("name") for c in columns] == ["Metric", "Name", "Count", "Failed", "Last"]
            and [c.get("type") for c in columns] == ["string", "string", "long", "long", "datetime"],
            "Unexpected telemetry columns.")
    rows, seen = [], set()
    for row in table["rows"]:
        require(type(row) is list and len(row) == 5, "Invalid telemetry row.")
        metric, name, count, failed, last = row
        require(metric in ("requests", "availability", "exceptions") and isinstance(name, str),
                "Unknown telemetry metric.")
        require(type(count) is int and type(failed) is int and 0 <= failed <= count,
                "Invalid telemetry counts.")
        require((count == 0 and last is None) or (count > 0 and start <= instant(last) <= end),
                "Invalid telemetry freshness.")
        require((metric, name) not in seen, "Duplicate telemetry aggregate.")
        seen.add((metric, name))
        rows.append({"metric": metric, "name": name, "count": count, "failed": failed, "last": last})
    return rows


def baseline(commands, config, scope, root, *, clock=utc, query=telemetry):
    monitor_config(config, commands.context)
    end = clock()
    commands.account()
    evidence = query(commands, config, end - timedelta(hours=24), end)
    for metric in ("requests", "availability"):
        require(sum(r["count"] for r in evidence["rows"] if r["metric"] == metric) > 0,
                "Baseline lacks requests or availability.")
    return bundle(root, "baseline", {"scope": scope, "config": config, "endUtc": end.isoformat(),
                                     "evidence": evidence}, now=end)


def create_monitor(commands, config, scope, baseline_dir, start, root, *, clock=utc):
    monitor_config(config, commands.context)
    require(equal(scope, commands.context.scope(scope["sha"])), "Monitor scope mismatch.")
    data = verified(baseline_dir, "baseline")
    now = clock()
    start = instant(start)
    require(start <= now <= start + timedelta(minutes=10), "Live monitor must start within ten minutes.")
    require(equal(data["scope"], scope) and equal(data["config"], config), "Baseline scope/config changed.")
    require(timedelta(0) <= start - instant(data["endUtc"]) <= timedelta(hours=2),
            "Baseline is stale or after deployment.")
    directory = bundle(root, "monitor", {
        "scope": scope, "config": config, "startUtc": start.isoformat(),
        "endUtc": (start + timedelta(hours=1)).isoformat(), "baseline": data,
        "baselineHash": binding(baseline_dir), "mode": "live",
    }, now=now)
    (directory / "events").mkdir(mode=0o700)
    return directory


@contextmanager
def monitor_lock(directory):
    lock = (Path(directory) / "owner.lock").open("a+b")
    try:
        if os.name == "nt":
            import msvcrt
            if os.fstat(lock.fileno()).st_size == 0:
                lock.write(b"0")
                lock.flush()
            lock.seek(0)
            try:
                msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
            except OSError:
                raise PromotionError("Monitor is already owned by another process.") from None
        else:
            import fcntl
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except OSError:
                raise PromotionError("Monitor is already owned by another process.") from None
        yield
    finally:
        lock.close()


def history(directory):
    header = verified(directory, "monitor")
    root_hash = binding(directory)
    entries = []
    for path in (Path(directory) / "events").iterdir():
        require(path.is_dir(), "Unexpected monitor event entry.")
        event = verified(path, "monitor-event")
        require(type(event.get("sequence")) is int, "Invalid monitor sequence.")
        entries.append((event, binding(path)))
    entries.sort(key=lambda item: item[0]["sequence"])
    previous = root_hash
    for index, (event, event_hash) in enumerate(entries):
        require(event["sequence"] == index and event["previousHash"] == previous,
                "Monitor event chain incomplete or modified.")
        previous = event_hash
    return header, entries


def monitor_status(directory):
    _, entries = history(directory)
    if not entries:
        return "not-started"
    phase = entries[-1][0]["phase"]
    return phase if phase in ("complete", "complete-with-gaps", "blocked", "interrupted") else "incomplete-or-running"


def append_event(directory, entries, value, now):
    value = value | {"sequence": len(entries),
                     "previousHash": entries[-1][1] if entries else binding(directory),
                     "observedUtc": now.isoformat()}
    target = bundle(Path(directory) / "events", "monitor-event", value, now=now)
    entries.append((value, binding(target)))


def evaluate(rows, known, now, end):
    reasons = []
    for metric in ("requests", "availability"):
        selected = [r for r in rows if r["metric"] == metric]
        if not selected or not sum(r["count"] for r in selected):
            reasons.append("empty-" + metric)
        elif min(now, end) - max(instant(r["last"]) for r in selected if r["count"]) > timedelta(minutes=15):
            reasons.append("stale-" + metric)
        if any(r["failed"] > 0 for r in selected):
            reasons.append("failed-" + metric)
    if any(r["metric"] == "exceptions" and r["count"] > 0 and r["name"] not in known for r in rows):
        reasons.append("new-exception-type")
    return reasons


def run_monitor(commands, directory, *, resume=False, clock=utc, sleep=time.sleep,
                query=telemetry, probe=health):
    with monitor_lock(directory):
        header, entries = history(directory)
        config = monitor_config(header["config"], commands.context)
        require(equal(header["scope"], commands.context.scope(header["scope"]["sha"])), "Monitor scope changed.")
        start, end = instant(header["startUtc"]), instant(header["endUtc"])
        deadline = end + timedelta(seconds=config["ingestionSeconds"])
        require(header["mode"] == "live" and start <= clock() < deadline,
                "Expired monitor: use retrospective, which cannot roll back.")
        require(not entries or resume, "Existing monitor requires explicit --resume.")
        require(not entries or entries[-1][0]["phase"] not in ("complete", "complete-with-gaps", "blocked"),
                "Monitor already terminal; use retrospective.")
        failures = entries[-1][0]["healthFailures"].copy() if entries else {"live": 0, "ready": 0}
        errors = entries[-1][0]["telemetryFailures"] if entries else 0
        gaps = list(entries[-1][0].get("coverageGaps", [])) if entries else []
        previous_sample = (instant(entries[-1][0]["sampleStartedUtc"])
                           if entries and "sampleStartedUtc" in entries[-1][0] else start)
        if entries:
            gaps.append("explicit-resumption")
        known = {row["name"] for row in header["baseline"]["evidence"]["rows"]
                 if row["metric"] == "exceptions" and row["count"] > 0}
        commands.account()
        try:
            while True:
                now = clock()
                require(now >= start, "Clock moved before original window.")
                if now - previous_sample > timedelta(seconds=config["pollSeconds"] + 60):
                    gaps.append("sample-gap-before-" + str(len(entries)))
                previous_sample = now
                health_evidence = {name: probe(url) for name, url in config["healthUrls"].items()}
                for name, observation in health_evidence.items():
                    failures[name] = 0 if observation["status"] == 200 else failures[name] + 1
                reasons = ["health-" + name for name, count in failures.items() if count >= 2]
                evidence = None
                diagnostic = None
                try:
                    evidence = query(commands, config, start, end)
                    if now >= start + timedelta(minutes=10):
                        reasons += evaluate(evidence["rows"], known, now, end)
                    else:
                        reasons += [r for r in evaluate(evidence["rows"], known, now, end)
                                    if not r.startswith(("empty-", "stale-"))]
                    errors = 0
                except PromotionError:
                    errors += 1
                    gaps.append("collection-failed-at-" + str(len(entries)))
                    diagnostic = "telemetry-unavailable-or-invalid"
                    if errors >= 2 or now >= end:
                        reasons.append("telemetry-unavailable")
                observed = clock()
                if observed >= deadline and any(value["status"] != 200 for value in health_evidence.values()):
                    reasons.append("final-health-unconfirmed")
                if observed - now > timedelta(seconds=config["pollSeconds"] + 60):
                    gaps.append("collection-overran-at-" + str(len(entries)))
                phase = ("blocked" if reasons else "complete"
                         if observed >= deadline and evidence is not None and now >= deadline
                         else "sample")
                if phase == "complete" and gaps:
                    phase = "complete-with-gaps"
                append_event(directory, entries, {
                    "phase": phase, "health": health_evidence, "healthFailures": failures.copy(),
                    "telemetryFailures": errors, "diagnostic": diagnostic,
                    "evidence": evidence, "reasons": reasons, "coverageGaps": gaps.copy(),
                    "sampleStartedUtc": now.isoformat(),
                }, observed)
                if phase in ("complete", "complete-with-gaps", "blocked"):
                    return phase == "complete"
                sleep(min(config["pollSeconds"], max(0.01, (deadline - observed).total_seconds())))
        except (KeyboardInterrupt, PromotionError, OSError):
            append_event(directory, entries, {"phase": "interrupted", "healthFailures": failures.copy(),
                         "telemetryFailures": errors, "diagnostic": "monitor-interrupted",
                         "coverageGaps": gaps.copy(), "sampleStartedUtc": previous_sample.isoformat()}, clock())
            raise


def rollback_allowed(directory, expected_hash, scope, now):
    header, entries = history(directory)
    require(binding(directory) == expected_hash and equal(header["scope"], scope),
            "Rollback monitor binding mismatch.")
    require(header["mode"] == "live"
            and instant(header["startUtc"]) <= now < instant(header["endUtc"]),
            "Rollback forbidden outside original live hour, including ingestion and retrospective.")
    require(entries and entries[-1][0]["phase"] == "blocked", "Rollback requires recorded blocking evidence.")
    require(timedelta(0) <= now - instant(entries[-1][0]["observedUtc"]) <= timedelta(minutes=5),
            "Rollback evidence stale.")


def retrospective(commands, directory, root, *, query=telemetry, clock=utc):
    header, _ = history(directory)
    config = monitor_config(header["config"], commands.context)
    require(equal(header["scope"], commands.context.scope(header["scope"]["sha"])), "Retrospective scope mismatch.")
    start, end = instant(header["startUtc"]), instant(header["endUtc"])
    require(clock() >= end, "Retrospective requires a finished window.")
    commands.account()
    evidence = query(commands, config, start, end)
    reasons = evaluate(evidence["rows"],
                       {r["name"] for r in header["baseline"]["evidence"]["rows"]
                        if r["metric"] == "exceptions" and r["count"] > 0}, end, end)
    return bundle(root, "retrospective", {"originalMonitorHash": binding(directory),
                  "mode": "retrospective", "rollbackAllowed": False, "startUtc": start.isoformat(),
                  "endUtc": end.isoformat(), "evidence": evidence, "reasons": reasons,
                  "continuousMonitoringProven": False}), not reasons
