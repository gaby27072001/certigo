"""Full-payload what-if: no inherited noise exemptions or ARM expression evaluation."""
from __future__ import annotations

from datetime import timedelta
from pathlib import Path

from .common import (bundle, decode, digest, equal, instant, load, object_keys, pointer,
                     require, resource_type, state, text, utc, verified, binding)


def approval(value, scope, now):
    object_keys(value, ("id", "scope", "approvedUtc", "expiresUtc", "reason"))
    require(text(value["id"]) and text(value["reason"]), "Approval ID and reason are required.")
    require(equal(value["scope"], scope), "Approval scope mismatch.")
    start, end = instant(value["approvedUtc"]), instant(value["expiresUtc"])
    require(start <= now < end and end - start <= timedelta(hours=2),
            "Approval expired, future-dated, or longer than two hours.")


def transition(value):
    return {name: {"present": True, "value": value[name]} if name in value else {"present": False}
            for name in ("before", "after")}


def leaves(deltas, prefix=""):
    require(type(deltas) is list, "Missing or null what-if deltas.")
    for delta in deltas:
        require(type(delta) is dict and text(delta.get("path")), "Malformed property delta.")
        path = prefix + "." + delta["path"] if prefix else delta["path"]
        kind = delta.get("propertyChangeType")
        require(kind in ("Create", "Delete", "Modify", "Array", "NoEffect"), "Unknown property change.")
        children = delta.get("children", [])
        require(type(children) is list, "Malformed child deltas.")
        # A deleted parent cannot be hidden behind child metadata.
        if children and kind not in ("Delete", "Create"):
            yield from leaves(children, path)
        else:
            yield path, delta


def analyze(result, decisions, scope, resources, now):
    require(type(result) is dict and result.get("status") == "Succeeded"
            and type(result.get("changes")) is list and not result.get("error"),
            "What-if incomplete or malformed.")
    require(type(decisions) is list, "Explicit decision list required.")
    for decision in decisions:
        object_keys(decision, ("resourceId", "resourceType", "path", "changeType", "before",
                               "after", "approval", "liveUrl", "livePointer", "liveState"))
        approval(decision["approval"], scope, now)
        require(resource_type(decision["resourceId"]) == decision["resourceType"],
                "Decision type differs from exact resource.")
        for key in ("before", "after", "liveState"):
            state(decision[key])
        require(text(decision["liveUrl"]) and decision["liveUrl"] in resources,
                "Decision requires a fresh complete GET.")
        require(decision["liveUrl"].split("?", 1)[0] ==
                "https://management.azure.com" + decision["resourceId"],
                "Decision GET must target that exact resource.")
        pages = resources[decision["liveUrl"]]
        require(len(pages) == 1, "Property decisions require a singular resource GET.")
        require(equal(pointer(pages[0]["body"], decision["livePointer"]), decision["liveState"]),
                "Live property changed since approval.")
    rows, used, seen = [], set(), set()
    for change in result["changes"]:
        require(type(change) is dict, "Malformed resource change.")
        rid, kind = change.get("resourceId"), change.get("changeType")
        rtype = resource_type(rid)
        require(rid.lower().startswith("/subscriptions/" + scope["subscriptionId"].lower() + "/"),
                "What-if resource outside approved subscription.")
        require(rid.lower() not in seen, "Duplicate what-if resource.")
        seen.add(rid.lower())
        require(kind in ("NoChange", "Ignore", "Create", "Delete", "Modify", "Deploy"),
                "Unknown resource change.")
        if kind == "NoChange":
            require(change.get("delta", []) == [], "NoChange contains deltas.")
            require("before" in change and "after" in change and equal(change["before"], change["after"]),
                    "NoChange needs identical full payloads; otherwise review explicitly.")
            rows.append({"resourceId": rid, "path": "", "verdict": "unchanged"})
            continue
        changes = list(leaves(change.get("delta"))) if kind == "Modify" else [("", change)]
        require(changes, "Modify without analyzable deltas.")
        for path, delta in changes:
            dtype = delta.get("propertyChangeType", kind)
            values = transition(delta)
            candidates = [index for index, d in enumerate(decisions)
                          if (d["resourceId"], d["resourceType"], d["path"], d["changeType"]) ==
                          (rid, rtype, path, dtype) and equal(d["before"], values["before"])
                          and equal(d["after"], values["after"])]
            require(len(candidates) <= 1, "Ambiguous duplicate approvals.")
            accepted = len(candidates) == 1
            if accepted:
                used.add(candidates[0])
            rows.append({"resourceId": rid, "path": path, "changeType": dtype,
                         "verdict": "approved" if accepted else "blocked"})
    require(used == set(range(len(decisions))), "Unused decisions: approval does not match this what-if.")
    return {"scope": scope, "rows": rows, "safe": all(r["verdict"] != "blocked" for r in rows)}


def run_preflight(commands, plan, root, now=None):
    now = now or utc()
    object_keys(plan, ("sha", "template", "parameters", "location", "deploymentName",
                       "snapshotUrls", "decisions"))
    scope = commands.context.scope(plan["sha"])
    for name in ("location", "deploymentName"):
        require(text(plan[name]) and not plan[name].startswith("-"), "Invalid what-if argument.")
    # Only compiled JSON is accepted. Secure values are never printed or bundled.
    template, parameters = load(plan["template"]), load(plan["parameters"])
    require(type(template) is dict and "resources" in template, "Compiled ARM template required.")
    require(type(parameters) is dict and type(parameters.get("parameters")) is dict,
            "Compiled ARM parameters required.")
    def validate_nested(value):
        if isinstance(value, dict):
            if str(value.get("type", "")).lower() == "microsoft.resources/deployments":
                require(type(value.get("properties")) is dict
                        and value["properties"].get("mode") == "Incremental"
                        and "templateLink" not in value["properties"],
                        "Only inline Incremental nested templates are supported.")
            for child in value.values():
                validate_nested(child)
        elif isinstance(value, list):
            for child in value:
                validate_nested(child)
    validate_nested(template)
    require(type(plan["snapshotUrls"]) is list and plan["snapshotUrls"],
            "Explicit nonempty snapshot coverage required.")
    for url in plan["snapshotUrls"]:
        commands.arm_url(url)
    require(type(plan["decisions"]) is list, "Explicit decision list required.")
    for decision in plan["decisions"]:
        require(type(decision) is dict and "approval" in decision, "Invalid decision.")
        approval(decision["approval"], scope, now)
    input_hashes = {"template": digest(encoded_file(plan["template"])),
                    "parameters": digest(encoded_file(plan["parameters"]))}
    commands.account()
    result = decode(commands.run([
        *commands.context.value["azureCommand"], "deployment", "sub", "what-if",
        "--subscription", commands.context.value["subscriptionId"],
        "--name", plan["deploymentName"], "--location", plan["location"],
        "--template-file", str(Path(plan["template"]).resolve()), "--parameters",
        "@" + str(Path(plan["parameters"]).resolve()), "--validation-level", "Provider",
        "--result-format", "FullResourcePayloads", "--no-pretty-print", "--no-prompt",
        "--output", "json", "--only-show-errors",
    ]))
    resources = commands.get_many(plan["snapshotUrls"])
    require(input_hashes == {"template": digest(encoded_file(plan["template"])),
                             "parameters": digest(encoded_file(plan["parameters"]))},
            "Compiled inputs changed during what-if.")
    report = analyze(result, plan["decisions"], scope, resources, now)
    report.update(startedUtc=now.isoformat(), completedUtc=utc().isoformat(),
                  mode="Incremental", inputHashes=input_hashes, decisions=plan["decisions"],
                  whatIf=result, resources=resources,
                  limitation="Input hashes identify operator-prepared JSON, not proof of compilation from SHA.")
    target = bundle(root, "preflight", report)
    return target, report["safe"]


def encoded_file(path):
    try:
        return Path(path).read_bytes()
    except OSError:
        from .common import PromotionError
        raise PromotionError("Cannot read compiled input.") from None


def snapshot(commands, preflight_dir, phase, root):
    require(phase in ("before", "after-infra", "final"), "Invalid snapshot phase.")
    preflight = verified(preflight_dir, "preflight")
    require(equal(preflight["scope"], commands.context.scope(preflight["scope"]["sha"])),
            "Snapshot scope mismatch.")
    commands.account()
    resources = commands.get_many(list(preflight["resources"]))
    if phase == "before":
        require(equal(resources, preflight["resources"]), "State or ETag changed; repeat preflight.")
    return bundle(root, "snapshot", {
        "scope": preflight["scope"], "phase": phase, "preflightHash": binding(preflight_dir),
        "completedUtc": utc().isoformat(), "resources": resources,
    })


def compare(before_dir, after_dir):
    before, after = verified(before_dir, "snapshot"), verified(after_dir, "snapshot")
    require(before["phase"] == "before" and after["phase"] in ("after-infra", "final"),
            "Compare before with an after snapshot.")
    require(equal(before["scope"], after["scope"]) and before["preflightHash"] == after["preflightHash"],
            "Snapshots do not share a preflight.")
    require(instant(before["completedUtc"]) <= instant(after["completedUtc"]), "Snapshot order invalid.")
    left, right = before["resources"], after["resources"]
    require(left and left.keys() == right.keys(), "Incomplete snapshot resource set.")
    return {"policy": "informational-only; never authorizes remediation or rollback",
            "changedUrls": [url for url in sorted(left) if not equal(left[url], right[url])],
            "beforeHash": binding(before_dir), "afterHash": binding(after_dir)}
