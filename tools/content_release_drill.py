#!/usr/bin/env python3
"""Replay the N-1 rollback drill for runtime content releases against one environment.

This is the machine-checkable form of the « Rollback N-1 » procedure in
`docs/runbooks/CONTENT_RELEASES.md`. Against one Function App it:

1. imports the N-1 and N releases and proves that an exact replay is idempotent;
2. proves the pointer guards: no `If-Match` is 428, a stale ETag is 412;
3. activates N-1, promotes N, then rolls back and proves that N-1 is served again;
4. proves that a second rollback without a new promotion is refused (409);
5. promotes N again, so the environment ends on the latest release, and proves it.

Every expectation is asserted; the first unmet one stops the drill with a non-zero exit.
The evidence file records status codes, pointer states, manifest identities and
durations. It never records the token, request headers or response bodies beyond the
pointer fields.

The administrator token (app role `Content.Release.Admin`) is read from the
`CERTIGO_CONTENT_ADMIN_TOKEN` environment variable only, so it never reaches a shell
history, an argument list or a log.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable, Mapping, Protocol, Sequence

ADMIN_ENV_NAME = "CERTIGO_CONTENT_ADMIN_TOKEN"
EVIDENCE_SCHEMA = "certigo.content-release-drill/v1"
STALE_ETAG = '"00000000-0000-0000-0000-000000000000"'
FORBIDDEN_PUBLIC_KEYS = frozenset(
    {
        "privateManifestId",
        "correct",
        "correctOptionIds",
        "explanation",
        "rationale",
        "answerKey",
        "solution",
    }
)
RECORDED_HEADERS = ("etag", "x-content-release-id", "x-content-manifest-id")
_RELEASE_PREFIX = "sha256:"


@dataclass(frozen=True)
class HttpResponse:
    status: int
    headers: Mapping[str, str]
    body: bytes


class Transport(Protocol):
    def __call__(
        self, method: str, url: str, headers: Mapping[str, str]
    ) -> HttpResponse: ...


class DrillFailure(Exception):
    """An expectation of the drill was not met."""


@dataclass
class Step:
    name: str
    method: str
    path: str
    status: int
    expected: tuple[int, ...]
    duration_ms: int
    detail: dict[str, Any] = field(default_factory=dict)

    def to_json(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "method": self.method,
            "path": self.path,
            "status": self.status,
            "expected": list(self.expected),
            "durationMs": self.duration_ms,
            "detail": self.detail,
        }


def urllib_transport(timeout_seconds: float) -> Transport:
    def send(method: str, url: str, headers: Mapping[str, str]) -> HttpResponse:
        request = urllib.request.Request(url, method=method, headers=dict(headers))
        if method == "POST":
            request.data = b""
        try:
            with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
                return HttpResponse(
                    response.status,
                    {key.lower(): value for key, value in response.headers.items()},
                    response.read(),
                )
        except urllib.error.HTTPError as error:
            return HttpResponse(
                error.code,
                {key.lower(): value for key, value in error.headers.items()},
                error.read(),
            )

    return send


def require_release_id(value: str) -> str:
    digest = value[len(_RELEASE_PREFIX) :]
    if (
        not value.startswith(_RELEASE_PREFIX)
        or len(digest) != 64
        or any(character not in "0123456789abcdef" for character in digest)
    ):
        raise argparse.ArgumentTypeError(f"not a lowercase sha256 release id: {value!r}")
    return value


def _forbidden_keys(value: Any) -> set[str]:
    if isinstance(value, dict):
        found = {key for key in value if key in FORBIDDEN_PUBLIC_KEYS}
        for nested in value.values():
            found |= _forbidden_keys(nested)
        return found
    if isinstance(value, list):
        found: set[str] = set()
        for nested in value:
            found |= _forbidden_keys(nested)
        return found
    return set()


class ContentReleaseDrill:
    def __init__(
        self,
        api: str,
        token: str,
        transport: Transport,
        clock: Callable[[], float] = time.monotonic,
        report: Callable[[str], None] = print,
    ) -> None:
        self._api = api.rstrip("/")
        self._token = token
        self._transport = transport
        self._clock = clock
        self._report = report
        self.steps: list[Step] = []

    def run(self, previous: str, latest: str) -> dict[str, Any]:
        if previous == latest:
            raise DrillFailure("The N-1 and N releases must differ.")

        self._import_twice("import N-1", previous)
        self._import_twice("import N", latest)
        self._call(
            "promotion without If-Match is refused",
            "POST",
            f"content/admin/releases/{previous}/promote",
            (428,),
        )
        self._call(
            "promotion with a stale ETag is refused",
            "POST",
            f"content/admin/releases/{previous}/promote",
            (412,),
            if_match=STALE_ETAG,
        )

        pointer = self._read_pointer("initial pointer")
        if pointer is None:
            pointer = self._promote("activate N-1 (first activation)", previous, "*")
        elif pointer["activeReleaseId"] != previous:
            pointer = self._promote("activate N-1", previous, pointer["etag"])
        self._expect_active(pointer, previous, "N-1 is active before the drill")

        before_promotion = pointer["etag"]
        pointer = self._promote("promote N", latest, before_promotion)
        self._expect_active(pointer, latest, "N is active after promotion")
        self._expect_previous(pointer, previous, "N-1 is kept as previous")

        self._call(
            "rollback with a stale ETag is refused",
            "POST",
            "content/admin/releases/rollback",
            (412,),
            if_match=before_promotion,
        )
        pointer = self._rollback("rollback to N-1", pointer["etag"])
        self._expect_active(pointer, previous, "N-1 is active after rollback")
        self._expect_previous(pointer, None, "rollback clears previous")
        self._expect_served("N-1 is served after rollback", previous, pointer)

        self._call(
            "second rollback without promotion is refused",
            "POST",
            "content/admin/releases/rollback",
            (409,),
            if_match=pointer["etag"],
        )

        pointer = self._promote("promote N again (final state)", latest, pointer["etag"])
        self._expect_active(pointer, latest, "environment ends on the latest release")
        self._expect_previous(pointer, previous, "N-1 stays available for rollback")
        manifest_etag = self._expect_served("N is served at the end", latest, pointer)
        self._call(
            "active manifest honors If-None-Match",
            "GET",
            "content/releases/active/manifest",
            (304,),
            extra_headers={"If-None-Match": manifest_etag},
        )
        final = self._read_pointer("final pointer")
        if final is None or final["activeReleaseId"] != latest:
            raise DrillFailure("final pointer: the latest release is not active.")
        return final

    def _import_twice(self, name: str, release_id: str) -> None:
        path = f"content/admin/releases/{release_id}/import"
        self._call(name, "POST", path, (200, 201))
        self._call(f"{name} replay is idempotent", "POST", path, (200,))

    def _read_pointer(self, name: str) -> dict[str, Any] | None:
        response, step = self._call(name, "GET", "content/admin/releases/pointer", (200, 503))
        if response.status == 503:
            step.detail["pointer"] = None
            return None
        pointer = self._pointer(response)
        step.detail["pointer"] = pointer
        return pointer

    def _promote(self, name: str, release_id: str, etag: str) -> dict[str, Any]:
        response, step = self._call(
            name,
            "POST",
            f"content/admin/releases/{release_id}/promote",
            (200,),
            if_match=etag,
        )
        pointer = self._pointer(response)
        step.detail["pointer"] = pointer
        return pointer

    def _rollback(self, name: str, etag: str) -> dict[str, Any]:
        response, step = self._call(
            name, "POST", "content/admin/releases/rollback", (200,), if_match=etag
        )
        pointer = self._pointer(response)
        step.detail["pointer"] = pointer
        return pointer

    def _expect_served(self, name: str, release_id: str, pointer: dict[str, Any]) -> str:
        response, step = self._call(name, "GET", "content/releases/active/manifest", (200,))
        manifest_id = pointer["activePublicManifestId"]
        expected_etag = f'"{manifest_id}"'
        served_release = response.headers.get("x-content-release-id")
        served_etag = response.headers.get("etag")
        if served_release != release_id or served_etag != expected_etag:
            raise DrillFailure(
                f"{name}: served release {served_release!r} with ETag {served_etag!r}, "
                f"expected {release_id!r} with ETag {expected_etag!r}."
            )
        leaked = sorted(_forbidden_keys(json.loads(response.body)))
        step.detail["forbiddenKeys"] = leaked
        if leaked:
            raise DrillFailure(f"{name}: the public manifest exposes {leaked}.")
        return expected_etag

    @staticmethod
    def _pointer(response: HttpResponse) -> dict[str, Any]:
        document = json.loads(response.body)
        etag = response.headers.get("etag") or document.get("_etag")
        if not isinstance(etag, str) or not etag:
            raise DrillFailure("A pointer response carried no ETag.")
        return {
            "activeReleaseId": document.get("activeReleaseId"),
            "activePublicManifestId": document.get("activePublicManifestId"),
            "previousReleaseId": document.get("previousReleaseId"),
            "previousPublicManifestId": document.get("previousPublicManifestId"),
            "updatedAt": document.get("updatedAt"),
            "etag": etag,
        }

    @staticmethod
    def _expect_active(pointer: dict[str, Any], release_id: str, name: str) -> None:
        if pointer["activeReleaseId"] != release_id:
            raise DrillFailure(
                f"{name}: active release is {pointer['activeReleaseId']!r}, expected {release_id!r}."
            )

    @staticmethod
    def _expect_previous(pointer: dict[str, Any], release_id: str | None, name: str) -> None:
        if pointer["previousReleaseId"] != release_id:
            raise DrillFailure(
                f"{name}: previous release is {pointer['previousReleaseId']!r}, "
                f"expected {release_id!r}."
            )

    def _call(
        self,
        name: str,
        method: str,
        path: str,
        expected: Sequence[int],
        if_match: str | None = None,
        extra_headers: Mapping[str, str] | None = None,
    ) -> tuple[HttpResponse, Step]:
        headers = {"Authorization": f"Bearer {self._token}", "Accept": "application/json"}
        if if_match is not None:
            headers["If-Match"] = if_match
        headers.update(extra_headers or {})
        started = self._clock()
        response = self._transport(method, f"{self._api}/{path}", headers)
        duration_ms = round((self._clock() - started) * 1000)
        step = Step(
            name,
            method,
            path,
            response.status,
            tuple(expected),
            duration_ms,
            {key: response.headers[key] for key in RECORDED_HEADERS if key in response.headers},
        )
        self.steps.append(step)
        verdict = "OK " if response.status in expected else "KO "
        self._report(f"{verdict}{name}: {method} {path} -> {response.status} ({duration_ms} ms)")
        if response.status not in expected:
            raise DrillFailure(
                f"{name}: {method} {path} returned {response.status}, expected {list(expected)}."
            )
        return response, step


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def main(
    argv: Sequence[str] | None = None,
    environ: Mapping[str, str] | None = None,
    transport: Transport | None = None,
) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--api", required=True, help="Function App base URL ending in /api.")
    parser.add_argument("--previous", required=True, type=require_release_id, help="N-1 release id.")
    parser.add_argument("--latest", required=True, type=require_release_id, help="N release id.")
    parser.add_argument("--evidence", type=Path, help="Write the JSON evidence to this file.")
    parser.add_argument("--timeout", type=float, default=330.0, help="Per-request timeout (s).")
    arguments = parser.parse_args(argv)

    token = (environ if environ is not None else os.environ).get(ADMIN_ENV_NAME, "").strip()
    if not token:
        print(f"{ADMIN_ENV_NAME} is not set; refusing to run.", file=sys.stderr)
        return 2

    drill = ContentReleaseDrill(
        arguments.api, token, transport or urllib_transport(arguments.timeout)
    )
    evidence: dict[str, Any] = {
        "schema": EVIDENCE_SCHEMA,
        "api": arguments.api.rstrip("/"),
        "previousReleaseId": arguments.previous,
        "latestReleaseId": arguments.latest,
        "startedAt": _utc_now(),
    }
    exit_code = 0
    try:
        evidence["finalPointer"] = drill.run(arguments.previous, arguments.latest)
        evidence["result"] = "passed"
    except DrillFailure as failure:
        evidence["result"] = "failed"
        evidence["failure"] = str(failure)
        print(f"Drill failed: {failure}", file=sys.stderr)
        exit_code = 1
    evidence["finishedAt"] = _utc_now()
    evidence["steps"] = [step.to_json() for step in drill.steps]
    if arguments.evidence is not None:
        arguments.evidence.write_text(
            json.dumps(evidence, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
    if exit_code == 0:
        print(f"Drill passed: {len(drill.steps)} checks, latest release active.")
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
