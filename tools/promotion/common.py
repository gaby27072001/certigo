"""Strict inputs, bounded subprocesses, and append-only private evidence."""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
from urllib.parse import parse_qs, urlsplit
from uuid import uuid4


class PromotionError(Exception):
    """A safe diagnostic: never include command output, response bodies, or secrets."""


def require(condition, message):
    if not condition:
        raise PromotionError(message)


def utc():
    return datetime.now(timezone.utc)


def instant(value):
    require(isinstance(value, str), "Timestamp must be an offset-aware string.")
    try:
        result = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        raise PromotionError("Invalid timestamp.") from None
    require(result.tzinfo is not None, "Timestamp needs a UTC offset.")
    return result.astimezone(timezone.utc)


def text(value):
    return isinstance(value, str) and bool(value.strip())


def match(pattern, value):
    return isinstance(value, str) and re.fullmatch(pattern, value) is not None


def object_keys(value, keys):
    require(type(value) is dict and set(value) == set(keys), "Unexpected object fields.")


def positive(value):
    return type(value) is int and value > 0


def encoded(value):
    try:
        return (json.dumps(value, sort_keys=True, ensure_ascii=True, allow_nan=False,
                           separators=(",", ":")) + "\n").encode("utf-8")
    except (TypeError, ValueError):
        raise PromotionError("Not a finite JSON value.") from None


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def equal(left, right):
    return encoded(left) == encoded(right)


def decode(raw):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, "Duplicate JSON key.")
            result[key] = value
        return result

    def invalid_constant(_):
        raise PromotionError("Non-finite JSON number.")

    try:
        value = json.loads(raw, object_pairs_hook=pairs, parse_constant=invalid_constant)
        encoded(value)
        return value
    except (ValueError, UnicodeError):
        raise PromotionError("Invalid JSON response or file.") from None


def load(path):
    try:
        return decode(Path(path).read_bytes())
    except OSError:
        raise PromotionError("Cannot read input file.") from None


def exclusive(path, value):
    """An incomplete write is deliberately not recoverable by overwriting it."""
    try:
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "wb") as output:
            output.write(encoded(value))
            output.flush()
            os.fsync(output.fileno())
    except OSError:
        raise PromotionError("Evidence exists or cannot be written; inspect it, never retry a write.") from None


def bundle(root, kind, value, now=None):
    require(match(r"[a-z][a-z0-9-]*", kind), "Invalid evidence kind.")
    now = now or utc()
    directory = Path(root) / (now.strftime("%Y%m%dT%H%M%S%fZ") + "-" + uuid4().hex)
    directory.mkdir(parents=True, mode=0o700)
    exclusive(directory / "evidence.json", value)
    exclusive(directory / "manifest.json", {
        "schema": 1, "kind": kind, "observedUtc": now.isoformat(),
        "files": {"evidence.json": digest((directory / "evidence.json").read_bytes())},
    })
    return directory


def verified(directory, kind=None):
    directory = Path(directory)
    manifest = load(directory / "manifest.json")
    object_keys(manifest, ("schema", "kind", "observedUtc", "files"))
    require(type(manifest["schema"]) is int and manifest["schema"] == 1,
            "Unknown evidence schema.")
    instant(manifest["observedUtc"])
    require(kind is None or manifest["kind"] == kind, "Wrong evidence kind.")
    require(type(manifest["files"]) is dict and set(manifest["files"]) == {"evidence.json"},
            "Incomplete evidence manifest.")
    try:
        raw = (directory / "evidence.json").read_bytes()
    except OSError:
        raise PromotionError("Incomplete evidence bundle.") from None
    require(digest(raw) == manifest["files"]["evidence.json"], "Evidence hash mismatch.")
    return decode(raw)


def binding(directory):
    verified(directory)
    return digest((Path(directory) / "manifest.json").read_bytes())


def pointer(document, path):
    require(isinstance(path, str) and (path == "" or path.startswith("/")), "Use JSON pointers.")
    current = document
    for raw in path.split("/")[1:] if path else []:
        require(not re.search(r"~(?![01])", raw), "Invalid JSON pointer escape.")
        token = raw.replace("~1", "/").replace("~0", "~")
        if isinstance(current, dict) and token in current:
            current = current[token]
        elif isinstance(current, list) and match(r"0|[1-9][0-9]*", token) and int(token) < len(current):
            current = current[int(token)]
        else:
            return {"present": False}
    return {"present": True, "value": current}


def state(value):
    require(type(value) is dict, "Property state must distinguish absent from null.")
    require((set(value) == {"present"} and value["present"] is False)
            or (set(value) == {"present", "value"} and value["present"] is True),
            "Invalid property state.")
    encoded(value)
    return value


def resource_type(rid):
    require(match(r"/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/?#%]+"
                  r"(?:/providers/[A-Za-z0-9.]+(?:/[^/?#%]+/[^/?#%]+)+)?", rid),
            "Expected an exact resource-group-scoped ARM ID.")
    parts = re.split("/providers/", rid, flags=re.I)
    if len(parts) == 1:
        return "Microsoft.Resources/resourceGroups"
    require(len(parts) == 2, "Extension resource IDs are not supported.")
    tail = parts[1].split("/")
    return tail[0] + "/" + "/".join(tail[1::2])


class Context:
    def __init__(self, value):
        object_keys(value, ("repository", "environment", "tenantId", "subscriptionId",
                            "azureCommand", "githubCommand", "timeoutSeconds"))
        require(match(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", value["repository"]),
                "Invalid repository.")
        require(value["environment"] in ("staging", "prod"), "Invalid environment.")
        for field in ("tenantId", "subscriptionId"):
            require(match(r"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}", value[field]),
                    "Invalid Azure scope.")
        for field in ("azureCommand", "githubCommand"):
            require(type(value[field]) is list and value[field] and all(text(x) for x in value[field]),
                    "CLI must be a nonempty list of executable words.")
        require(positive(value["timeoutSeconds"]) and value["timeoutSeconds"] <= 900,
                "Timeout must be 1..900 seconds.")
        self.value = value

    def scope(self, sha):
        require(match(r"[0-9a-f]{40}", sha), "Expected full lowercase commit SHA.")
        return {key: self.value[key] for key in
                ("repository", "environment", "tenantId", "subscriptionId")} | {"sha": sha}

    def resource(self, rid):
        resource_type(rid)
        require(rid.lower().startswith("/subscriptions/" + self.value["subscriptionId"].lower() + "/"),
                "Resource outside configured subscription.")
        return rid


class Commands:
    def __init__(self, context, runner=subprocess.run):
        self.context, self.runner = context, runner

    def run(self, words, *, body=None):
        try:
            result = self.runner(words, input=None if body is None else encoded(body),
                                 capture_output=True, timeout=self.context.value["timeoutSeconds"],
                                 shell=False)
        except (OSError, subprocess.TimeoutExpired):
            raise PromotionError("Command unavailable or timed out; outcome may be uncertain.") from None
        require(result.returncode == 0, "Command failed; sensitive stdout/stderr suppressed.")
        return result.stdout

    def gh(self, endpoint, *, body=None):
        require(endpoint.startswith("repos/" + self.context.value["repository"] + "/"),
                "GitHub endpoint outside configured repository.")
        args = [*self.context.value["githubCommand"], "api", "--method",
                "GET" if body is None else "POST", endpoint]
        if body is not None:
            args += ["--input", "-"]
        raw = self.run(args, body=body)
        return decode(raw) if body is None else None

    def account(self):
        result = decode(self.run([*self.context.value["azureCommand"], "account", "show",
                                  "--output", "json", "--only-show-errors"]))
        require(isinstance(result, dict)
                and text(result.get("id")) and text(result.get("tenantId"))
                and result["id"].lower() == self.context.value["subscriptionId"].lower()
                and result["tenantId"].lower() == self.context.value["tenantId"].lower(),
                "Azure account does not match configured tenant/subscription.")

    def arm_url(self, url):
        require(isinstance(url, str), "Invalid ARM URL.")
        parsed = urlsplit(url)
        require(parsed.scheme == "https" and parsed.netloc == "management.azure.com"
                and not parsed.fragment and "%" not in parsed.path and ".." not in parsed.path,
                "Only exact public ARM HTTPS URLs are supported.")
        self.context.resource(parsed.path)
        query = parse_qs(parsed.query, keep_blank_values=True)
        require(set(query) <= {"api-version", "$skiptoken"} and len(query.get("api-version", [])) == 1
                and match(r"\d{4}-\d{2}-\d{2}(?:-preview)?", query["api-version"][0]),
                "ARM URL needs one explicit API version.")
        return parsed

    def get(self, url):
        self.arm_url(url)
        return decode(self.run([*self.context.value["azureCommand"], "rest", "--method", "get",
                                "--url", url, "--output", "json", "--only-show-errors"]))

    def pages(self, url):
        initial = self.arm_url(url)
        pages, seen = [], set()
        while url is not None:
            current = self.arm_url(url)
            require(current.path == initial.path
                    and parse_qs(current.query)["api-version"] == parse_qs(initial.query)["api-version"],
                    "Pagination changed resource or API version.")
            require(url not in seen and len(seen) < 100, "Pagination cycle or limit.")
            seen.add(url)
            body = self.get(url)
            require(type(body) is dict, "Expected complete ARM object.")
            pages.append({"url": url, "body": body})
            if "nextLink" in body:
                require(type(body.get("value")) is list, "Paginated response has no value array.")
                url = body["nextLink"]
                require(url is None or text(url), "Invalid continuation link.")
            else:
                url = None
        return pages

    def get_many(self, urls):
        require(type(urls) is list and urls and len(set(urls)) == len(urls), "Unique GET URLs required.")
        for url in urls:
            self.arm_url(url)
        results = {}
        with ThreadPoolExecutor(max_workers=4) as executor:
            futures = {executor.submit(self.pages, url): url for url in urls}
            try:
                for future in as_completed(futures):
                    results[futures[future]] = future.result()
            finally:
                for future in futures:
                    future.cancel()
        return results
