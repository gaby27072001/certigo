from __future__ import annotations

import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any, Mapping

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import content_release_drill as drill  # noqa: E402

PREVIOUS = "sha256:" + "a" * 64
LATEST = "sha256:" + "b" * 64
MANIFESTS = {PREVIOUS: "sha256:" + "c" * 64, LATEST: "sha256:" + "d" * 64}
TOKEN = "secret-admin-token-value"
API = "https://func-certigo-staging.example/api"


class FakeContentApi:
    """Mirrors the pointer semantics of CosmosContentReleaseStore behind the HTTP routes."""

    def __init__(self, active: str | None = None, previous: str | None = None) -> None:
        self.receipts: set[str] = set()
        self.pointer: dict[str, Any] | None = None
        self.version = 0
        self.rollback_restores_previous = True
        self.second_rollback_status = 409
        self.leak_key: str | None = None
        self.seen_tokens: set[str] = set()
        if active is not None:
            self.receipts.update(value for value in (active, previous) if value)
            self._write(active, previous)

    def _write(self, active: str, previous: str | None) -> None:
        self.version += 1
        self.pointer = {
            "id": "active",
            "activeReleaseId": active,
            "activePublicManifestId": MANIFESTS[active],
            "previousReleaseId": previous,
            "previousPublicManifestId": MANIFESTS[previous] if previous else None,
            "updatedAt": "2026-09-23T20:00:00Z",
            "updatedBy": "operator",
        }

    @property
    def etag(self) -> str:
        return f'"etag-{self.version}"'

    def _json(self, status: int, body: dict[str, Any], **headers: str) -> drill.HttpResponse:
        return drill.HttpResponse(status, {key.lower(): value for key, value in headers.items()}, json.dumps(body).encode())

    def __call__(self, method: str, url: str, headers: Mapping[str, str]) -> drill.HttpResponse:
        self.seen_tokens.add(headers.get("Authorization", ""))
        path = url.removeprefix(API + "/")
        if_match = headers.get("If-Match")
        parts = path.split("/")
        if method == "POST" and path.endswith("/import"):
            release = parts[3]
            created = release not in self.receipts
            self.receipts.add(release)
            return self._json(201 if created else 200, {"alreadyImported": not created})
        if method == "GET" and path == "content/admin/releases/pointer":
            if self.pointer is None:
                return self._json(503, {"title": "Content unavailable"})
            return self._json(200, self.pointer, ETag=self.etag)
        if method == "POST" and path.endswith("/promote"):
            release = parts[3]
            if if_match is None:
                return self._json(428, {"title": "Precondition required"})
            if release not in self.receipts:
                return self._json(404, {"title": "Not found"})
            if self.pointer is not None and if_match != self.etag:
                return self._json(412, {"title": "Precondition failed"})
            if self.pointer is None and if_match != "*":
                return self._json(412, {"title": "Precondition failed"})
            if self.pointer is not None and self.pointer["activeReleaseId"] == release:
                return self._json(200, self.pointer, ETag=self.etag)
            current = self.pointer["activeReleaseId"] if self.pointer else None
            self._write(release, current)
            return self._json(200, self.pointer, ETag=self.etag)
        if method == "POST" and path == "content/admin/releases/rollback":
            if self.pointer is None:
                return self._json(409, {"title": "Conflict"})
            if if_match != self.etag:
                return self._json(412, {"title": "Precondition failed"})
            if self.pointer["previousReleaseId"] is None:
                if self.second_rollback_status != 409:
                    return self._json(self.second_rollback_status, self.pointer, ETag=self.etag)
                return self._json(409, {"title": "Conflict"})
            if self.rollback_restores_previous:
                self._write(self.pointer["previousReleaseId"], None)
            else:
                self._write(self.pointer["activeReleaseId"], None)
            return self._json(200, self.pointer, ETag=self.etag)
        if method == "GET" and path == "content/releases/active/manifest":
            if self.pointer is None:
                return self._json(503, {"title": "Content unavailable"})
            manifest_id = self.pointer["activePublicManifestId"]
            quoted = f'"{manifest_id}"'
            if headers.get("If-None-Match") == quoted:
                return drill.HttpResponse(304, {"etag": quoted}, b"")
            body: dict[str, Any] = {
                "manifestId": manifest_id,
                "releaseId": self.pointer["activeReleaseId"],
                "files": [{"id": "catalog", "path": "catalog/certifications.json"}],
            }
            if self.leak_key:
                body["files"][0][self.leak_key] = True
            return self._json(
                200,
                body,
                ETag=quoted,
                **{
                    "X-Content-Release-Id": self.pointer["activeReleaseId"],
                    "X-Content-Manifest-Id": manifest_id,
                },
            )
        return drill.HttpResponse(404, {}, b"")


class ContentReleaseDrillTests(unittest.TestCase):
    def run_drill(self, api: FakeContentApi) -> tuple[int, dict[str, Any], list[str]]:
        output: list[str] = []
        stdout = io.StringIO()
        stderr = io.StringIO()
        with tempfile.TemporaryDirectory() as directory:
            evidence_path = Path(directory) / "evidence.json"
            with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                code = drill.main(
                    [
                        "--api",
                        API,
                        "--previous",
                        PREVIOUS,
                        "--latest",
                        LATEST,
                        "--evidence",
                        str(evidence_path),
                    ],
                    environ={drill.ADMIN_ENV_NAME: TOKEN},
                    transport=api,
                )
            text = evidence_path.read_text(encoding="utf-8")
        output.extend([text, stdout.getvalue(), stderr.getvalue()])
        return code, json.loads(text), output

    def test_fresh_environment_proves_n1_rollback_and_ends_on_latest(self) -> None:
        api = FakeContentApi()

        code, evidence, _ = self.run_drill(api)

        self.assertEqual(code, 0)
        self.assertEqual(evidence["result"], "passed")
        self.assertEqual(evidence["finalPointer"]["activeReleaseId"], LATEST)
        self.assertEqual(evidence["finalPointer"]["previousReleaseId"], PREVIOUS)
        statuses = [(step["name"], step["status"]) for step in evidence["steps"]]
        self.assertIn(("import N-1", 201), statuses)
        self.assertIn(("import N-1 replay is idempotent", 200), statuses)
        self.assertIn(("promotion without If-Match is refused", 428), statuses)
        self.assertIn(("promotion with a stale ETag is refused", 412), statuses)
        self.assertIn(("initial pointer", 503), statuses)
        self.assertIn(("rollback to N-1", 200), statuses)
        self.assertIn(("second rollback without promotion is refused", 409), statuses)
        self.assertIn(("active manifest honors If-None-Match", 304), statuses)
        rollback = next(step for step in evidence["steps"] if step["name"] == "rollback to N-1")
        self.assertEqual(rollback["detail"]["pointer"]["activeReleaseId"], PREVIOUS)
        self.assertIsNone(rollback["detail"]["pointer"]["previousReleaseId"])

    def test_rerun_on_an_environment_already_on_latest_still_passes(self) -> None:
        api = FakeContentApi(active=LATEST, previous=PREVIOUS)

        code, evidence, _ = self.run_drill(api)

        self.assertEqual(code, 0)
        self.assertEqual(evidence["finalPointer"]["activeReleaseId"], LATEST)

    def test_a_rollback_that_does_not_restore_n1_fails_the_drill(self) -> None:
        api = FakeContentApi()
        api.rollback_restores_previous = False

        code, evidence, _ = self.run_drill(api)

        self.assertEqual(code, 1)
        self.assertEqual(evidence["result"], "failed")
        self.assertIn("N-1 is active after rollback", evidence["failure"])

    def test_a_second_rollback_that_succeeds_fails_the_drill(self) -> None:
        api = FakeContentApi()
        api.second_rollback_status = 200

        code, evidence, _ = self.run_drill(api)

        self.assertEqual(code, 1)
        self.assertIn("second rollback without promotion is refused", evidence["failure"])

    def test_an_answer_key_in_the_public_manifest_fails_the_drill(self) -> None:
        api = FakeContentApi()
        api.leak_key = "correctOptionIds"

        code, evidence, _ = self.run_drill(api)

        self.assertEqual(code, 1)
        self.assertIn("correctOptionIds", evidence["failure"])

    def test_evidence_never_contains_the_token(self) -> None:
        api = FakeContentApi()

        _, _, output = self.run_drill(api)

        self.assertEqual(api.seen_tokens, {f"Bearer {TOKEN}"})
        self.assertNotIn(TOKEN, "".join(output))

    def test_missing_token_refuses_to_run(self) -> None:
        api = FakeContentApi()

        with contextlib.redirect_stderr(io.StringIO()):
            code = drill.main(
                ["--api", API, "--previous", PREVIOUS, "--latest", LATEST],
                environ={},
                transport=api,
            )

        self.assertEqual(code, 2)
        self.assertEqual(api.seen_tokens, set())

    def test_release_ids_must_be_lowercase_sha256(self) -> None:
        for value in ("sha256:" + "A" * 64, "sha256:" + "a" * 63, "md5:" + "a" * 64):
            with self.subTest(value=value), self.assertRaises(Exception):
                drill.require_release_id(value)
        self.assertEqual(drill.require_release_id(PREVIOUS), PREVIOUS)


if __name__ == "__main__":
    unittest.main()
