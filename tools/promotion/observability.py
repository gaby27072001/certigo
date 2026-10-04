"""Independent health, rule routing, and runtime observations, never conflated."""
from .common import bundle, equal, object_keys, pointer, require, state, text, utc
from .monitor import health


def receivers(group, required_names):
    require(type(group) is dict and type(group.get("properties")) is dict,
            "Malformed action group.")
    props = group["properties"]
    require(props.get("enabled") is True, "Action group disabled.")
    values = props.get("emailReceivers")
    require(type(values) is list and values and type(required_names) is list
            and required_names and all(text(name) for name in required_names),
            "Explicit required receiver names needed.")
    require(all(type(value) is dict for value in values), "Malformed receivers.")
    names = [value.get("name") for value in values]
    require(all(text(name) for name in names) and len(set(names)) == len(names)
            and set(required_names) <= set(names), "Required receivers absent or ambiguous.")
    require(all(value.get("status") == "Enabled" and value.get("verificationStatus") == "Verified"
                and text(value.get("emailAddress")) for value in values),
            "Receiver disabled, unverified, or unknown.")
    return {"receiverEnabledVerified": True, "emailDeliveryProven": False}


def runtime(status, deployment_id):
    require(type(status) is dict and type(status.get("properties")) is dict,
            "Malformed deployment status.")
    props = status["properties"]
    require(props.get("deploymentId") == deployment_id, "Wrong deployment status ID.")
    label = props.get("status")
    require(text(label), "Missing runtime status.")
    failed = props.get("numberOfInstancesFailed")
    errors = props.get("errors")
    require(type(failed) is int and failed >= 0 and type(errors) is list,
            "Incomplete runtime status evidence.")
    if errors or failed or "failed" in label.lower():
        verdict = "failed"
    elif label == "RuntimeSuccessful":
        verdict = "observed-runtime-success"
    else:
        verdict = "unconfirmed"
    return {"reportedStatus": label, "verdict": verdict, "runtimeZipBytesVerified": False,
            "observedUtc": utc().isoformat()}


def observe(commands, spec, root, *, probe=health):
    object_keys(spec, ("sha", "ruleUrl", "groupUrl", "ruleProperties", "requiredReceivers",
                       "healthUrls", "deploymentStatusUrl", "deploymentId"))
    scope = commands.context.scope(spec["sha"])
    require(type(spec["ruleProperties"]) is dict and spec["ruleProperties"],
            "Exact expected rule properties required.")
    require(spec["ruleProperties"].get("/properties/enabled") == {"present": True, "value": True},
            "Rule must be explicitly enabled in the expected contract.")
    require({"/properties/criteria", "/properties/scopes", "/properties/actions",
             "/properties/evaluationFrequency", "/properties/windowSize", "/properties/autoMitigate"}
            <= spec["ruleProperties"].keys(), "Complete explicit rule contract required.")
    object_keys(spec["healthUrls"], ("live", "ready"))
    commands.account()
    rule, group = commands.get(spec["ruleUrl"]), commands.get(spec["groupUrl"])
    require(type(rule) is dict and type(group) is dict, "Malformed rule/group.")
    for url, body in ((spec["ruleUrl"], rule), (spec["groupUrl"], group)):
        require(text(body.get("id")) and
                ("https://management.azure.com" + body["id"]).lower() == url.split("?", 1)[0].lower(),
                "Returned rule/group ID differs from requested resource.")
    for path, expected in spec["ruleProperties"].items():
        require(equal(pointer(rule, path), state(expected)), "Rule differs from exact approved contract.")
    receiver = receivers(group, spec["requiredReceivers"])
    actions = pointer(rule, "/properties/actions/actionGroups")
    require(actions.get("present") is True and type(actions["value"]) is list
            and all(text(value) for value in actions["value"])
            and text(group.get("id")) and group["id"].lower() in [s.lower() for s in actions["value"]],
            "Rule does not route to the verified receiver group.")
    runtime_result = runtime(commands.get(spec["deploymentStatusUrl"]), spec["deploymentId"])
    probes = {name: probe(url) for name, url in spec["healthUrls"].items()}
    healthy = all(value["status"] == 200 for value in probes.values())
    report = {"scope": scope, "receivers": receiver, "health": probes, "healthPassed": healthy,
              "ruleMatched": True, "runtime": runtime_result,
              "safe": healthy and runtime_result["verdict"] == "observed-runtime-success"}
    return bundle(root, "observability", report), report["safe"]
