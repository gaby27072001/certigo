#!/usr/bin/env python3
"""Seed a throwaway demo learner on a Certigo **development** backend.

Why this exists
---------------
Reaching Accueil / Parcours / Ligue / Profil / Boutique requires an account that
has finished onboarding *and* carries some progression: a brand-new account
renders the empty state of every one of those screens, not the screen itself.
This script drives the **public dev API only** — register, pick a track, answer
real quizzes — so the progression it produces is graded server-side and is
therefore genuine, not injected.

Deliberate non-goals
--------------------
* No Cosmos access, no Azure credentials, no VNet, no managed identity. Content
  already exists on dev; this seeds a *learner*, never content.
* No secret is generated, written to disk, or printed. The demo account's
  password is supplied by the operator through ``CERTIGO_DEV_SEED_PASSWORD`` and
  never echoed back, so it cannot leak into terminal scrollback or CI logs.

Refuses to run against anything that is not a development host (see
``assert_development_target``): production must never be touched.

Usage:
    $env:CERTIGO_DEV_SEED_PASSWORD = 'choose-a-throwaway-password'
    python tools/seed_dev_demo_account.py
    python tools/seed_dev_demo_account.py --lessons 3 --json
    python tools/seed_dev_demo_account.py --api-base https://<dev-host>/api
"""
from __future__ import annotations

import argparse
import json
import os
import secrets
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid
from datetime import datetime, timezone

# Same dev endpoint the Flutter app falls back to (packages/core/lib/src/app_env.dart).
# A public hostname, not a credential.
DEFAULT_API_BASE = "https://func-certigo-dev-bk3j5ja6vw23s.azurewebsites.net/api"

# Exam code of the track to study. Resolved against the live catalog rather than
# hard-coded as an id: the catalog id namespace depends on the backend's
# CONTENT_REPOSITORY_MODE ("az-900" in legacy, "microsoft.az-900.track.main" in
# versioned). The exam code is stable in both.
DEFAULT_TRACK_CODE = "AZ-900"

TIMEOUT_SECONDS = 90

# The operator supplies the demo account's password here. It is never generated,
# never written to disk and never echoed back — see read_password().
PASSWORD_ENV_VAR = "CERTIGO_DEV_SEED_PASSWORD"
MIN_PASSWORD_LENGTH = 8


class SeedError(RuntimeError):
    """A seeding step failed in a way the operator must see."""


def assert_development_target(api_base: str) -> None:
    """Refuse any host that is not unambiguously a development backend.

    Production and staging are out of bounds for this tool. The check is a
    denylist *and* an allowlist so that a typo cannot silently point a seeding
    run at a real environment.
    """
    host = urllib.parse.urlsplit(api_base).hostname or ""
    lowered = host.lower()
    for forbidden in ("prod", "staging", "stg"):
        if forbidden in lowered:
            raise SeedError(
                f"Refusing to seed '{host}': it looks like a {forbidden} host. "
                "This tool is development-only."
            )
    is_local = lowered in {"localhost", "127.0.0.1", "::1"}
    if not is_local and "-dev-" not in lowered and not lowered.startswith("dev"):
        raise SeedError(
            f"Refusing to seed '{host}': the hostname does not identify a development "
            "backend. Pass an explicit --api-base for a dev host, or use localhost."
        )


def request(
    api_base: str,
    method: str,
    path: str,
    *,
    token: str | None = None,
    body: dict | None = None,
    with_headers: bool = False,
) -> dict | tuple[dict, dict]:
    url = f"{api_base.rstrip('/')}/{path.lstrip('/')}"
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Accept", "application/json")
    if data is not None:
        req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_SECONDS) as response:
            payload = response.read().decode("utf-8")
            headers = {key.lower(): value for key, value in response.headers.items()}
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")[:400]
        raise SeedError(f"{method} {path} -> HTTP {error.code}: {detail}") from error
    except urllib.error.URLError as error:
        raise SeedError(f"{method} {path} -> unreachable: {error.reason}") from error
    parsed = json.loads(payload) if payload.strip() else {}
    return (parsed, headers) if with_headers else parsed


def read_password() -> str:
    """Read the demo account's password from the environment.

    Deliberately never generated and never printed. An earlier revision invented
    a password and echoed it so the operator could sign in; CodeQL flagged that
    as `py/clear-text-logging-sensitive-data` (severity 7.0) and was right to —
    a tool that prints a credential leaks it into terminal scrollback, CI logs
    and shell history. The operator supplies it, so it never needs disclosing
    back.
    """
    password = os.environ.get(PASSWORD_ENV_VAR, "")
    if len(password) < MIN_PASSWORD_LENGTH:
        raise SeedError(
            f"Set {PASSWORD_ENV_VAR} to the password to give the demo account "
            f"(at least {MIN_PASSWORD_LENGTH} characters), then re-run. "
            "This tool never generates or prints a credential.\n"
            f"  PowerShell: $env:{PASSWORD_ENV_VAR} = 'choose-a-throwaway-password'\n"
            f"  bash:       export {PASSWORD_ENV_VAR}='choose-a-throwaway-password'"
        )
    return password


def resolve_track(catalog: dict, wanted_code: str) -> dict:
    """Find the catalog entry for an exam code, in either id namespace.

    Mirrors `TargetCertification.matchesTrack` in the Flutter app: match on the
    exam code / slug, never on a hard-coded bare id.
    """
    wanted = wanted_code.strip().lower()
    tracks = catalog.get("tracks") or []
    playable = [
        track
        for track in tracks
        if track.get("lessonCount", 0) > 0 and track.get("contentStatus", "available") == "available"
    ]
    for track in playable:
        candidates = {
            str(track.get("code") or "").lower(),
            str(track.get("officialCode") or "").lower(),
            str(track.get("slug") or "").lower(),
            str(track.get("id") or "").lower(),
        }
        if wanted in candidates:
            return track
    if not playable:
        raise SeedError(
            "The catalog exposes no track with lessons. The backend has no published "
            "content — seed content before seeding a learner."
        )
    fallback = max(playable, key=lambda track: track.get("lessonCount", 0))
    print(
        f"[warn] No track matched '{wanted_code}'. Falling back to "
        f"{fallback.get('code') or fallback.get('id')} "
        f"({fallback.get('lessonCount')} lessons).",
        file=sys.stderr,
    )
    return fallback


def lessons_in_path(path: dict) -> list[dict]:
    found: list[dict] = []
    for unit in path.get("units") or []:
        for lesson in unit.get("lessons") or []:
            found.append(lesson)
    return found


def answer_lesson(api_base: str, token: str, track_id: str, lesson: dict) -> dict:
    """Answer every check in one lesson and let the server grade it.

    Answers are picked deterministically (first option). Grading, XP, streak and
    gems are all decided server-side — this script never asserts a score.

    The lesson response carries `X-Content-Manifest-Id`; a backend running in
    `versioned` mode rejects a submission that omits it
    ("publicManifestId is required for a versioned quiz submission"). Echoing the
    header back is exactly what the Flutter client does.
    """
    lesson_id = lesson["id"]
    detail, headers = request(
        api_base,
        "GET",
        f"tracks/{track_id}/lessons/{lesson_id}",
        token=token,
        with_headers=True,
    )
    public_manifest_id = headers.get("x-content-manifest-id")
    answers = []
    for block in detail.get("blocks") or []:
        check = block.get("check")
        if not check:
            continue
        options = check.get("options") or []
        if not options:
            continue
        answers.append(
            {
                "itemId": check["id"],
                "itemType": check.get("type", "mcq"),
                "selected": [options[0]["id"]],
                "latencyMs": 4200,
            }
        )
    if not answers:
        raise SeedError(f"Lesson '{lesson_id}' carries no answerable check.")
    submission = {
        "clientAttemptId": str(uuid.uuid4()),
        "trackId": track_id,
        "startedAt": datetime.now(timezone.utc).isoformat(),
        "answers": answers,
    }
    if public_manifest_id:
        submission["publicManifestId"] = public_manifest_id
    return request(api_base, "POST", f"quiz/{lesson_id}/submit", token=token, body=submission)


def seed(api_base: str, track_code: str, lesson_budget: int, email: str | None) -> dict:
    assert_development_target(api_base)

    password = read_password()
    address = email or f"demo+{secrets.token_hex(4)}@certigo.test"
    print(f"[1/5] Registering {address}", file=sys.stderr)
    credentials = request(
        api_base,
        "POST",
        "auth/register",
        body={"email": address, "password": password, "displayName": "Démo Certigo"},
    )
    token = credentials.get("accessToken")
    if not token:
        raise SeedError("Registration returned no access token.")

    print("[2/5] Resolving a playable track from the live catalog", file=sys.stderr)
    catalog = request(api_base, "GET", "catalog/tracks", token=token)
    track = resolve_track(catalog, track_code)
    track_id = track["id"]
    print(f"      -> {track.get('code')} ({track_id})", file=sys.stderr)

    print("[3/5] Selecting it as the active track", file=sys.stderr)
    request(api_base, "POST", "me/active-track", token=token, body={"trackId": track_id})

    print("[4/5] Answering lessons so progression is real", file=sys.stderr)
    path = request(api_base, "GET", f"me/paths/{track_id}", token=token)
    available = [
        lesson for lesson in lessons_in_path(path) if lesson.get("status") != "locked"
    ]
    completed = 0
    for lesson in available[:lesson_budget]:
        result = answer_lesson(api_base, token, track_id, lesson)
        completed += 1
        rewards = result.get("rewards") or {}
        print(
            f"      lesson {completed}: score={result.get('scorePct')}% "
            f"xp=+{rewards.get('xp', 0)} gems=+{rewards.get('gems', 0)}",
            file=sys.stderr,
        )

    print("[5/5] Reading back the resulting learner state", file=sys.stderr)
    profile = request(api_base, "GET", "me", token=token)
    # The password is deliberately absent: the operator already knows it, and a
    # summary that carries it would end up in logs, pipes and shell history.
    summary = {
        "email": address,
        "userId": profile.get("id"),
        "trackId": track_id,
        "trackCode": track.get("code"),
        "lessonsCompleted": completed,
        "xp": profile.get("xp"),
        "level": profile.get("level"),
        "gems": profile.get("gems"),
        "streakDays": profile.get("streakDays"),
        "activeTrackId": profile.get("activeTrackId"),
    }
    if completed and not summary["xp"]:
        print(
            "[warn] Lessons were submitted but the profile reports 0 XP. The five "
            "screens will still render their empty state.",
            file=sys.stderr,
        )
    return summary


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--api-base", default=DEFAULT_API_BASE, help="Dev API base URL.")
    parser.add_argument("--track-code", default=DEFAULT_TRACK_CODE, help="Exam code to study.")
    parser.add_argument("--lessons", type=int, default=2, help="How many lessons to answer.")
    parser.add_argument("--email", default=None, help="Reuse a fixed address instead of a random one.")
    parser.add_argument("--json", action="store_true", help="Print the summary as JSON on stdout.")
    args = parser.parse_args()

    try:
        summary = seed(args.api_base, args.track_code, args.lessons, args.email)
    except SeedError as error:
        print(f"[fail] {error}", file=sys.stderr)
        raise SystemExit(1) from error

    if args.json:
        print(json.dumps(summary, ensure_ascii=False, indent=2))
        return
    print("")
    # Nothing about the credential is printed. The operator supplied it, so
    # restating it — or even naming the variable that holds its env key — only
    # risks pushing it into scrollback. CodeQL flags the interpolation too.
    print("  Demo learner ready — sign in with the e-mail below.")
    print(f"    email    : {summary['email']}")
    print(
        f"    progress : {summary['lessonsCompleted']} lesson(s), {summary['xp']} XP, "
        f"{summary['gems']} gems, level {summary['level']}"
    )
    print(f"    track    : {summary['trackCode']} ({summary['trackId']})")


if __name__ == "__main__":
    main()
