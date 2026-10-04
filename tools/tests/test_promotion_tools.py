"""Synthetic offline promotion tests. No real executable, HTTP, Azure or GitHub calls."""
from __future__ import annotations

import contextlib
import copy
from datetime import datetime, timedelta, timezone
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from promotion import common as c
from promotion import monitor as m
from promotion import observability as o
from promotion import preflight as p
from promotion import release as r
from promotion.__main__ import main

NOW = datetime(2030, 1, 1, 12, tzinfo=timezone.utc)
SHA = "a" * 40
DIGEST = "b" * 64
SUB = "00000000-0000-0000-0000-000000000001"
TENANT = "00000000-0000-0000-0000-000000000002"
RID = f"/subscriptions/{SUB}/resourceGroups/synthetic/providers/Microsoft.Storage/storageAccounts/fake"
URL = f"https://management.azure.com{RID}?api-version=2030-01-01"
CONFIG = {"repository": "example/synthetic", "environment": "staging",
          "tenantId": TENANT, "subscriptionId": SUB,
          "azureCommand": ["never-execute-azure", "-IBm", "azure.cli"],
          "githubCommand": ["never-execute-gh"], "timeoutSeconds": 30}


def context():
    return c.Context(copy.deepcopy(CONFIG))


def scope():
    return context().scope(SHA)


def approval():
    return {"id": "synthetic-approval", "scope": scope(), "approvedUtc": NOW.isoformat(),
            "expiresUtc": (NOW + timedelta(hours=1)).isoformat(), "reason": "Synthetic unit test"}


def resources(value=1):
    return {URL: [{"url": URL, "body": {"id": RID, "etag": "synthetic-etag",
                                       "properties": {"value": value}}}]}


def whatif(kind="Modify"):
    return {"status": "Succeeded", "changes": [{"resourceId": RID, "changeType": kind,
            "before": {"properties": {"value": 1}}, "after": {"properties": {"value": 2}},
            "delta": [{"path": "properties.value", "propertyChangeType": "Modify", "before": 1, "after": 2}]}]}


def decision():
    return {"resourceId": RID, "resourceType": "Microsoft.Storage/storageAccounts",
            "path": "properties.value", "changeType": "Modify",
            "before": {"present": True, "value": 1}, "after": {"present": True, "value": 2},
            "approval": approval(), "liveUrl": URL, "livePointer": "/properties/value",
            "liveState": {"present": True, "value": 1}}


def telemetry_table(rows):
    return {"tables": [{"name": "PrimaryResult",
                        "columns": [{"name": name, "type": kind} for name, kind in zip(
                            ["Metric", "Name", "Count", "Failed", "Last"],
                            ["string", "string", "long", "long", "datetime"])],
                        "rows": rows}]}


def monitor_config():
    return {"resourceId": RID, "workspaceId": TENANT,
            "healthUrls": {"live": "https://synthetic.invalid/api/health/live",
                           "ready": "https://synthetic.invalid/api/health/ready"},
            "ingestionSeconds": 60, "pollSeconds": 180}


def healthy_query(commands, config, start, end):
    result = telemetry_table([["requests", "", 1, 0, end.isoformat()],
                              ["availability", "test@place", 1, 0, end.isoformat()]])
    return {"query": {"timespan": start.isoformat() + "/" + end.isoformat()},
            "result": result, "rows": m.telemetry_rows(result, start, end)}


def job(name, steps, job_id=1):
    return {"id": job_id, "name": name, "status": "completed", "conclusion": "success",
            "started_at": (NOW - timedelta(minutes=2)).isoformat(), "completed_at": NOW.isoformat(),
            "steps": [{"name": name, "status": "completed", "conclusion": "success",
                       "started_at": (NOW - timedelta(minutes=1)).isoformat(),
                       "completed_at": NOW.isoformat()} for name in steps]}


class Clock:
    def __init__(self, now=NOW):
        self.now = now

    def __call__(self):
        return self.now

    def sleep(self, seconds):
        self.now += timedelta(seconds=seconds)


class OfflineCase(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.api = Mock()
        self.api.context = context()
        self.api.get_many.return_value = resources()
        self.api.account.return_value = None
        # Even accidental non-injected I/O is forbidden by the test harness.
        self.addCleanup(patch.stopall)
        patch("subprocess.Popen", side_effect=AssertionError("Real subprocess forbidden")).start()
        patch("urllib.request.OpenerDirector.open", side_effect=AssertionError("Real HTTP forbidden")).start()

    def preflight_pair(self):
        result = p.analyze(whatif(), [decision()], scope(), resources(), NOW)
        result.update(mode="Incremental", startedUtc=NOW.isoformat(), completedUtc=NOW.isoformat(),
                      whatIf=whatif(), decisions=[decision()], resources=resources())
        before = c.bundle(self.root, "preflight", result, now=NOW)
        after = c.bundle(self.root, "snapshot", {
            "scope": scope(), "phase": "before", "preflightHash": c.binding(before),
            "completedUtc": NOW.isoformat(), "resources": resources()}, now=NOW)
        return before, after

    def authorization(self, before, after):
        return {"approval": approval(), "operation": "promotion", "sourceRunId": "123",
                "sourceSha": SHA, "packageSha256": DIGEST, "preflightHash": c.binding(before),
                "beforeHash": c.binding(after), "monitorHash": None}

    def make_monitor(self, clock=None):
        clock = clock or Clock()
        baseline = m.baseline(self.api, monitor_config(), scope(), self.root,
                              clock=clock, query=healthy_query)
        return m.create_monitor(self.api, monitor_config(), scope(), baseline,
                                NOW.isoformat(), self.root, clock=clock)


class CommonTests(OfflineCase):
    def test_strict_json_rejects_duplicates_nonfinite_suffix_and_bom(self):
        for raw in ('{"x":1,"x":2}', '{"x":NaN}', '{"x":1e999}', '{}<html>', '\ufeff{}'):
            with self.subTest(raw=raw), self.assertRaises(c.PromotionError):
                c.decode(raw)

    def test_comparison_keeps_boolean_integer_and_absent_null_distinct(self):
        self.assertFalse(c.equal(True, 1))
        self.assertFalse(c.equal(1, 1.0))
        self.assertNotEqual(c.pointer({}, "/x"), c.pointer({"x": None}, "/x"))
        self.assertEqual(c.pointer({"a/b": [False]}, "/a~1b/0"), {"present": True, "value": False})
        with self.assertRaises(c.PromotionError):
            c.pointer({}, "/a~2b")

    def test_context_requires_explicit_words_scope_and_timeout(self):
        for key, value in (("azureCommand", "az"), ("azureCommand", []), ("timeoutSeconds", True),
                           ("timeoutSeconds", 0), ("timeoutSeconds", 901), ("environment", "dev"),
                           ("subscriptionId", None)):
            config = copy.deepcopy(CONFIG)
            config[key] = value
            with self.subTest(key=key, value=value), self.assertRaises(c.PromotionError):
                c.Context(config)

    def test_immutable_bundle_unique_at_same_time_and_tampering_detected(self):
        first = c.bundle(self.root, "sample", {"n": 1}, now=NOW)
        second = c.bundle(self.root, "sample", {"n": 2}, now=NOW)
        self.assertNotEqual(first, second)
        self.assertEqual(c.verified(first, "sample"), {"n": 1})
        with self.assertRaises(c.PromotionError):
            c.exclusive(first / "evidence.json", {})
        (first / "evidence.json").write_bytes(b"{}")
        with self.assertRaises(c.PromotionError):
            c.verified(first)

    def test_command_timeout_and_stderr_are_sanitized(self):
        secret = "DO-NOT-LEAK-SYNTHETIC"
        runner = Mock(return_value=subprocess.CompletedProcess([], 1, secret.encode(), secret.encode()))
        api = c.Commands(context(), runner=runner)
        with self.assertRaises(c.PromotionError) as error:
            api.run(["fake"])
        self.assertNotIn(secret, str(error.exception))
        self.assertEqual(runner.call_args.kwargs["timeout"], 30)
        self.assertFalse(runner.call_args.kwargs["shell"])
        runner.side_effect = subprocess.TimeoutExpired(secret, 30, stderr=secret)
        with self.assertRaises(c.PromotionError) as error:
            api.run(["fake"])
        self.assertNotIn(secret, str(error.exception))

    def test_arm_scope_pagination_and_null_shapes_fail_closed(self):
        api = c.Commands(context(), runner=Mock())
        next_url = URL + "&$skiptoken=second"
        api.get = Mock(side_effect=[{"value": [1], "nextLink": next_url}, {"value": [2]}])
        self.assertEqual(len(api.pages(URL)), 2)
        for body in (None, [], {"nextLink": ""}, {"value": [], "nextLink": URL},
                     {"value": [], "nextLink": "https://evil.invalid/"}):
            api.get = Mock(return_value=body)
            with self.subTest(body=body), self.assertRaises(c.PromotionError):
                api.pages(URL)
        for url in (URL.replace(SUB, TENANT), URL + "&api-version=2030-02-02",
                    URL.replace("https:", "http:"), URL.replace("/fake?", "/../fake?"),
                    URL + "&arbitrary=x"):
            with self.subTest(url=url), self.assertRaises(c.PromotionError):
                api.arm_url(url)

    def test_account_null_or_wrong_tenant_rejected(self):
        api = c.Commands(context(), runner=Mock())
        for value in (None, {"id": None, "tenantId": TENANT}, {"id": SUB, "tenantId": SUB}):
            api.run = Mock(return_value=c.encoded(value))
            with self.subTest(value=value), self.assertRaises(c.PromotionError):
                api.account()

    def test_parallel_gets_cap_workers_and_cancel_pending(self):
        api = c.Commands(context(), runner=Mock())
        urls = [URL.replace("/fake?", f"/fake{i}?") for i in range(8)]
        api.pages = Mock(side_effect=c.PromotionError("synthetic failure"))
        with patch("promotion.common.ThreadPoolExecutor", wraps=c.ThreadPoolExecutor) as pool:
            with self.assertRaises(c.PromotionError):
                api.get_many(urls)
            self.assertEqual(pool.call_args.kwargs["max_workers"], 4)


class PreflightTests(OfflineCase):
    def test_exact_decision_matches_all_fields(self):
        result = p.analyze(whatif(), [decision()], scope(), resources(), NOW)
        self.assertTrue(result["safe"])
        for key, value in (("resourceType", "Microsoft.Fake/fake"), ("path", "properties.other"),
                           ("changeType", "Delete"), ("before", {"present": True, "value": True}),
                           ("after", {"present": True, "value": 3}),
                           ("liveState", {"present": True, "value": 2})):
            d = decision()
            d[key] = value
            with self.subTest(key=key), self.assertRaises(c.PromotionError):
                p.analyze(whatif(), [d], scope(), resources(), NOW)

    def test_approval_scope_expiry_future_and_missing_reason(self):
        for change in ({"reason": ""}, {"scope": scope() | {"environment": "prod"}},
                       {"expiresUtc": NOW.isoformat()},
                       {"approvedUtc": (NOW + timedelta(seconds=1)).isoformat()},
                       {"expiresUtc": (NOW + timedelta(hours=3)).isoformat()}):
            d = decision()
            d["approval"].update(change)
            with self.subTest(change=change), self.assertRaises(c.PromotionError):
                p.analyze(whatif(), [d], scope(), resources(), NOW)

    def test_unapproved_delete_ignore_and_noeffect_are_blocked(self):
        for kind in ("Ignore", "Create", "Delete", "Deploy"):
            result = p.analyze(whatif(kind), [], scope(), resources(), NOW)
            self.assertFalse(result["safe"])
        result = whatif()
        result["changes"][0]["delta"][0]["propertyChangeType"] = "NoEffect"
        self.assertFalse(p.analyze(result, [], scope(), resources(), NOW)["safe"])

    def test_nochange_requires_identical_payloads_and_no_hidden_delta(self):
        data = whatif("NoChange")
        with self.assertRaises(c.PromotionError):
            p.analyze(data, [], scope(), resources(), NOW)
        data["changes"][0]["delta"] = []
        data["changes"][0]["after"] = data["changes"][0]["before"]
        self.assertTrue(p.analyze(data, [], scope(), resources(), NOW)["safe"])
        del data["changes"][0]["before"]
        with self.assertRaises(c.PromotionError):
            p.analyze(data, [], scope(), resources(), NOW)

    def test_nested_delete_preserves_parent(self):
        values = [{"path": "properties", "propertyChangeType": "Modify", "children": [
            {"path": "value", "propertyChangeType": "Delete", "before": None, "children": [
                {"path": "child", "propertyChangeType": "NoEffect"}]}]}]
        self.assertEqual([(path, d["propertyChangeType"]) for path, d in p.leaves(values)],
                         [("properties.value", "Delete")])

    def test_missing_null_and_duplicate_changes_rejected(self):
        for data in (None, {"status": "Succeeded", "changes": None},
                     {"status": "Failed", "changes": []}):
            with self.subTest(data=data), self.assertRaises(c.PromotionError):
                p.analyze(data, [], scope(), resources(), NOW)
        data = whatif()
        data["changes"] *= 2
        with self.assertRaises(c.PromotionError):
            p.analyze(data, [decision()], scope(), resources(), NOW)
        with self.assertRaises(c.PromotionError):
            p.analyze(whatif(), [decision(), decision()], scope(), resources(), NOW)

    def test_preflight_command_is_whatif_never_create_and_inputs_hashed(self):
        template, parameters = self.root / "template.json", self.root / "parameters.json"
        template.write_text('{"resources":[]}')
        parameters.write_text('{"parameters":{}}')
        plan = {"sha": SHA, "template": str(template), "parameters": str(parameters),
                "location": "synthetic", "deploymentName": "synthetic",
                "snapshotUrls": [URL], "decisions": [decision()]}
        self.api.run.return_value = c.encoded(whatif())
        path, safe = p.run_preflight(self.api, plan, self.root, now=NOW)
        self.assertTrue(safe)
        words = self.api.run.call_args.args[0]
        self.assertIn("what-if", words)
        self.assertNotIn("create", words)
        self.assertEqual(c.verified(path)["inputHashes"]["template"], c.digest(template.read_bytes()))
        template.write_text('{"resources":[{"type":"Microsoft.Resources/deployments",'
                            '"properties":{"mode":"Complete"}}]}')
        self.api.reset_mock()
        with self.assertRaises(c.PromotionError):
            p.run_preflight(self.api, plan, self.root, now=NOW)
        self.api.account.assert_not_called()

    def test_snapshot_compares_complete_payload_including_etag(self):
        before, _ = self.preflight_pair()
        path = p.snapshot(self.api, before, "before", self.root)
        self.api.get_many.return_value = resources(2)
        after = p.snapshot(self.api, before, "final", self.root)
        report = p.compare(path, after)
        self.assertEqual(report["changedUrls"], [URL])
        self.assertIn("never", report["policy"])
        changed = resources()
        changed[URL][0]["body"]["etag"] = "another"
        self.api.get_many.return_value = changed
        with self.assertRaises(c.PromotionError):
            p.snapshot(self.api, before, "before", self.root)


class ReleaseTests(OfflineCase):
    def prepare_dispatch(self):
        first, second = self.preflight_pair()
        auth = self.authorization(first, second)
        self.api.gh.return_value = {"sha": SHA}
        patch("promotion.release.source_proof", return_value={"packageSha256": DIGEST}).start()
        patch("promotion.release.paged", return_value=[]).start()
        return first, second, auth

    def test_dispatch_requires_execute_and_exact_three_field_payload(self):
        first, second, auth = self.prepare_dispatch()
        with self.assertRaises(c.PromotionError):
            r.dispatch(self.api, auth, first, second, self.root / "receipts", clock=lambda: NOW)
        self.api.gh.assert_not_called()
        path = r.dispatch(self.api, auth, first, second, self.root / "receipts",
                          execute=True, clock=lambda: NOW)
        receipt = c.load(path)
        self.assertEqual(receipt["payload"], {"event_type": "promote-backend", "client_payload": {
            "environment": "staging", "operation": "promotion", "source_run_id": "123"}})
        self.assertEqual(receipt["state"], "requested-outcome-unknown")
        self.assertEqual(len(list(path.parent.glob("*.accepted.json"))), 1)
        with self.assertRaises(c.PromotionError):
            r.dispatch(self.api, auth, first, second, path.parent, execute=True, clock=lambda: NOW)

    def test_receipt_is_durable_before_post_and_uncertain_dispatch_never_retried(self):
        first, second, auth = self.prepare_dispatch()
        ledger = self.root / "receipts"
        def fake_gh(endpoint, *, body=None):
            if body is not None:
                self.assertEqual(len(list(ledger.glob("*.requested.json"))), 1)
                self.assertEqual(len(list(ledger.glob("approval-*.json"))), 1)
                raise c.PromotionError("timeout")
            return {"sha": SHA}
        self.api.gh.side_effect = fake_gh
        for _ in range(2):
            with self.assertRaises(c.PromotionError):
                r.dispatch(self.api, auth, first, second, ledger, execute=True, clock=lambda: NOW)
        posts = [call for call in self.api.gh.call_args_list if call.kwargs.get("body") is not None]
        self.assertEqual(len(posts), 1)
        self.assertFalse(list(ledger.glob("*.accepted.json")))

    def test_dispatch_rejects_stale_future_changed_main_and_false_preflight(self):
        first, second, auth = self.prepare_dispatch()
        for now in (NOW - timedelta(seconds=1), NOW + timedelta(minutes=6)):
            with self.subTest(now=now), self.assertRaises(c.PromotionError):
                r.dispatch(self.api, auth, first, second, self.root / "receipts",
                           execute=True, clock=lambda: now)
        self.api.gh.return_value = {"sha": "c" * 40}
        with self.assertRaises(c.PromotionError):
            r.dispatch(self.api, auth, first, second, self.root / "receipts",
                       execute=True, clock=lambda: NOW)
        self.assertFalse((self.root / "receipts").exists())

    def test_source_proof_needs_actual_build_steps_and_unique_digest(self):
        self.api.gh.side_effect = [
            {"id": 123, "status": "completed", "conclusion": "success", "event": "push",
             "head_branch": "main", "head_sha": SHA, "path": ".github/workflows/cd-backend.yml",
             "run_attempt": 1, "repository": {"full_name": CONFIG["repository"]}},
            {"total_count": 1, "jobs": [job("Build immutable backend release",
                ["Create deterministic ZIP and release manifest", "Record trusted package digest",
                 "Retain build-once release in private dev storage"])]}]
        self.api.run.return_value = f"CERTIGO_RELEASE_PACKAGE_SHA256={DIGEST}\n".encode()
        proof = r.source_proof(self.api, "123", SHA)
        self.assertEqual(proof["packageSha256"], DIGEST)
        self.assertFalse(proof["runtimeZipBytesVerified"])

    def test_required_jobs_or_steps_skipped_never_prove_deployment(self):
        original = job("Deploy", ["Deploy once"])
        for target in ("job", "step"):
            for status in ("skipped", "failure", None):
                candidate = copy.deepcopy(original)
                (candidate if target == "job" else candidate["steps"][0])["conclusion"] = status
                with self.subTest(target=target, status=status), self.assertRaises(c.PromotionError):
                    r.executed_job([candidate], "Deploy", ["Deploy once"])
        for jobs in ([], [original, original]):
            with self.assertRaises(c.PromotionError):
                r.executed_job(jobs, "Deploy", ["Deploy once"])
        original["completed_at"] = original["started_at"]
        with self.assertRaises(c.PromotionError):
            r.executed_job([original], "Deploy", ["Deploy once"])

    def test_github_pagination_duplicate_null_and_changed_total(self):
        self.api.gh.side_effect = [{"total_count": 2, "jobs": [{"id": 1}]},
                                   {"total_count": 2, "jobs": [{"id": 2}]}]
        self.assertEqual(len(r.paged(self.api, "repos/example/synthetic/jobs", "jobs")), 2)
        for responses in ([None], [{"total_count": True, "jobs": []}],
                          [{"total_count": 2, "jobs": [{"id": 1}]},
                           {"total_count": 2, "jobs": [{"id": 1}]}],
                          [{"total_count": 2, "jobs": [{"id": 1}]},
                           {"total_count": 3, "jobs": [{"id": 2}]}]):
            self.api.gh.side_effect = responses
            with self.subTest(responses=responses), self.assertRaises(c.PromotionError):
                r.paged(self.api, "repos/example/synthetic/jobs", "jobs")

    def test_source_rejects_wrong_event_branch_sha_workflow_or_repo(self):
        valid = {"id": 123, "status": "completed", "conclusion": "success", "event": "push",
                 "head_branch": "main", "head_sha": SHA, "path": ".github/workflows/cd-backend.yml",
                 "run_attempt": 1, "repository": {"full_name": CONFIG["repository"]}}
        for key, value in (("event", "pull_request"), ("head_branch", "feature"),
                           ("head_sha", "c" * 40), ("path", ".github/workflows/other.yml"),
                           ("run_attempt", True), ("status", "in_progress"),
                           ("repository", {"full_name": "example/other"})):
            self.api.gh.return_value = valid | {key: value}
            with self.subTest(key=key), self.assertRaises(c.PromotionError):
                r.source_proof(self.api, "123", SHA)
        self.api.run.assert_not_called()

    def test_source_missing_or_conflicting_digest_rejected(self):
        valid = {"id": 123, "status": "completed", "conclusion": "success", "event": "push",
                 "head_branch": "main", "head_sha": SHA, "path": ".github/workflows/cd-backend.yml",
                 "run_attempt": 1, "repository": {"full_name": CONFIG["repository"]}}
        build = job("Build immutable backend release",
                    ["Create deterministic ZIP and release manifest", "Record trusted package digest",
                     "Retain build-once release in private dev storage"])
        for raw in (b"", b"exit 0",
                    (f"CERTIGO_RELEASE_PACKAGE_SHA256={DIGEST}\n"
                     f"CERTIGO_RELEASE_PACKAGE_SHA256={'c' * 64}").encode()):
            self.api.gh.side_effect = [valid, {"total_count": 1, "jobs": [build]}]
            self.api.run.return_value = raw
            with self.subTest(raw=raw), self.assertRaises(c.PromotionError):
                r.source_proof(self.api, "123", SHA)

    def test_deployment_actual_steps_and_provenance_without_runtime_claim(self):
        run = {"id": 456, "head_sha": SHA, "status": "completed", "conclusion": "success",
               "event": "repository_dispatch", "path": ".github/workflows/cd-backend.yml",
               "run_attempt": 1}
        jobs = [job("Prepare infrastructure (staging)", [
            "Deploy current infrastructure", "Verify private networking before code deployment"]),
            job("Deploy verified backend (staging)", [
                "Reverify release before deployment",
                "Deploy once and run liveness/readiness smoke tests"], job_id=2)]
        log = (f"COMMIT_SHA: {SHA}\nEXPECTED_PACKAGE_SHA256: {DIGEST}\nSOURCE_RUN_ID: 123\n"
               "DEPLOYMENT_OPERATION: promotion\nTARGET_ENV: staging\n").encode()
        source = {"sha": SHA, "packageSha256": DIGEST, "runId": "123"}
        self.api.gh.side_effect = [run, {"total_count": 2, "jobs": jobs}]
        self.api.run.return_value = log
        proof = r.deployment_proof(self.api, "456", SHA, source, "promotion")
        self.assertTrue(proof["cdJobsExecuted"])
        self.assertEqual(proof["runtimeStatus"], "not-observed")
        self.assertFalse(proof["runtimeZipBytesVerified"])
        self.api.gh.side_effect = [run, {"total_count": 2, "jobs": jobs}]
        self.api.run.return_value = log.replace(b"SOURCE_RUN_ID: 123", b"SOURCE_RUN_ID: 999")
        with self.assertRaises(c.PromotionError):
            r.deployment_proof(self.api, "456", SHA, source, "promotion")

    def test_rollback_dispatch_deadline_rechecked_before_post(self):
        first, second, auth = self.prepare_dispatch()
        directory = self.make_monitor()
        _, events = m.history(directory)
        m.append_event(directory, events, {"phase": "blocked", "reasons": ["failed-requests"]}, NOW)
        auth.update(operation="rollback", monitorHash=c.binding(directory))
        clock = Mock(side_effect=[NOW, NOW, NOW, NOW, NOW + timedelta(hours=1)])
        with self.assertRaises(c.PromotionError):
            r.dispatch(self.api, auth, first, second, self.root / "receipts",
                       execute=True, clock=clock, monitor_dir=directory)
        self.assertFalse([call for call in self.api.gh.call_args_list if call.kwargs.get("body")])
        self.assertTrue(list((self.root / "receipts").glob("*.requested.json")))

    def test_rollback_dispatch_succeeds_once_only_in_original_live_window(self):
        first, second, auth = self.prepare_dispatch()
        directory = self.make_monitor()
        _, events = m.history(directory)
        m.append_event(directory, events, {"phase": "blocked", "reasons": ["failed-requests"]}, NOW)
        auth.update(operation="rollback", monitorHash=c.binding(directory), sourceSha="c" * 40)
        path = r.dispatch(self.api, auth, first, second, self.root / "receipts",
                          execute=True, clock=lambda: NOW, monitor_dir=directory)
        self.assertEqual(c.load(path)["payload"]["client_payload"]["operation"], "rollback")
        with self.assertRaises(c.PromotionError):
            r.dispatch(self.api, auth, first, second, self.root / "receipts",
                       execute=True, clock=lambda: NOW, monitor_dir=directory)

    def test_same_approval_cannot_authorize_different_payload(self):
        first, second, auth = self.prepare_dispatch()
        r.dispatch(self.api, auth, first, second, self.root / "receipts",
                   execute=True, clock=lambda: NOW)
        auth["sourceRunId"] = "999"
        with self.assertRaises(c.PromotionError):
            r.dispatch(self.api, auth, first, second, self.root / "receipts",
                       execute=True, clock=lambda: NOW)
        posts = [call for call in self.api.gh.call_args_list if call.kwargs.get("body")]
        self.assertEqual(len(posts), 1)


class MonitorTests(OfflineCase):
    def test_partial_http200_missing_column_wrong_type_and_null_fail(self):
        good = telemetry_table([["requests", "", 1, 0, NOW.isoformat()]])
        cases = [None, good | {"error": {"code": "PartialError"}}, {"tables": []}]
        wrong = copy.deepcopy(good)
        wrong["tables"][0]["columns"][2]["type"] = "string"
        cases.append(wrong)
        for row in (["requests", "", True, 0, NOW.isoformat()],
                    ["requests", "", 1, 0, None], ["requests", "", 1, 2, NOW.isoformat()],
                    ["requests", "", 0, 0, NOW.isoformat()], ["requests", "", 1],
                    ["requests", "", "1", 0, NOW.isoformat()]):
            cases.append(telemetry_table([row]))
        for data in cases:
            with self.subTest(data=data), self.assertRaises(c.PromotionError):
                m.telemetry_rows(data, NOW - timedelta(hours=1), NOW)

    def test_query_bounds_all_sources_without_general_exemptions(self):
        self.api.run.return_value = c.encoded(telemetry_table([]))
        m.telemetry(self.api, monitor_config(), NOW, NOW + timedelta(hours=1))
        words = self.api.run.call_args.args[0]
        payload = c.decode(words[words.index("--body") + 1])
        self.assertEqual(payload["query"].count("TimeGenerated between"), 3)
        self.assertEqual(payload["query"].count("_ResourceId =~"), 3)
        self.assertNotIn("GetAccountDeletion", payload["query"])
        self.assertNotIn("CIAM", payload["query"])

    def test_full_live_hour_and_ingestion_preserve_unique_hashes(self):
        clock = Clock()
        directory = self.make_monitor(clock)
        self.assertTrue(m.run_monitor(self.api, directory, clock=clock, sleep=clock.sleep,
                                     query=healthy_query, probe=lambda _: {"status": 200}))
        header, events = m.history(directory)
        self.assertEqual(m.monitor_status(directory), "complete")
        self.assertGreaterEqual(clock(), NOW + timedelta(hours=1, seconds=60))
        self.assertGreater(len(events), 20)
        self.assertEqual(len({digest for _, digest in events}), len(events))
        self.assertEqual(header["endUtc"], (NOW + timedelta(hours=1)).isoformat())
        with self.assertRaises(c.PromotionError):
            m.run_monitor(self.api, directory, resume=True, clock=clock)

    def test_collection_failure_never_restores_continuous_coverage(self):
        clock = Clock()
        directory = self.make_monitor(clock)
        calls = 0
        def query(*args):
            nonlocal calls
            calls += 1
            if calls == 1:
                raise c.PromotionError("429 or timeout")
            return healthy_query(*args)
        self.assertFalse(m.run_monitor(self.api, directory, clock=clock, sleep=clock.sleep,
                                      query=query, probe=lambda _: {"status": 200}))
        self.assertEqual(m.monitor_status(directory), "complete-with-gaps")
        self.assertTrue(m.history(directory)[1][-1][0]["coverageGaps"])

    def test_repeated_collection_failure_blocks_without_mutation(self):
        directory = self.make_monitor()
        clock = Clock()
        self.assertFalse(m.run_monitor(self.api, directory, clock=clock, sleep=clock.sleep,
                         query=Mock(side_effect=c.PromotionError("partial")),
                         probe=lambda _: {"status": 200}))
        self.assertEqual(m.monitor_status(directory), "blocked")
        self.api.gh.assert_not_called()
        self.assertEqual(m.history(directory)[1][-1][0]["telemetryFailures"], 2)

    def test_resume_keeps_original_window_baseline_failures_and_gaps(self):
        directory = self.make_monitor()
        clock = Clock()
        with self.assertRaises(KeyboardInterrupt):
            m.run_monitor(self.api, directory, clock=clock,
                          sleep=Mock(side_effect=KeyboardInterrupt), query=healthy_query,
                          probe=lambda _: {"status": 503})
        before_header = c.verified(directory)
        self.assertEqual(m.monitor_status(directory), "interrupted")
        clock.sleep(300)
        with self.assertRaises(c.PromotionError):
            m.run_monitor(self.api, directory, clock=clock, query=healthy_query)
        self.assertFalse(m.run_monitor(self.api, directory, resume=True, clock=clock,
                         sleep=clock.sleep, query=healthy_query, probe=lambda _: {"status": 503}))
        self.assertEqual(c.verified(directory), before_header)
        last = m.history(directory)[1][-1][0]
        self.assertEqual(last["healthFailures"], {"live": 2, "ready": 2})
        self.assertTrue(last["coverageGaps"])

    def test_process_loss_or_deleted_event_never_becomes_complete(self):
        directory = self.make_monitor()
        _, events = m.history(directory)
        m.append_event(directory, events, {"phase": "sample", "healthFailures": {"live": 0, "ready": 0},
                       "telemetryFailures": 0, "sampleStartedUtc": NOW.isoformat()}, NOW)
        self.assertEqual(m.monitor_status(directory), "incomplete-or-running")
        event = next((directory / "events").iterdir())
        (event / "manifest.json").unlink()
        with self.assertRaises(c.PromotionError):
            m.monitor_status(directory)

    def test_expired_live_resume_forbidden_retrospective_cannot_enable_rollback(self):
        directory = self.make_monitor()
        clock = Clock(NOW + timedelta(hours=2))
        with self.assertRaises(c.PromotionError):
            m.run_monitor(self.api, directory, resume=True, clock=clock)
        path, healthy = m.retrospective(self.api, directory, self.root, query=healthy_query, clock=clock)
        self.assertTrue(healthy)
        proof = c.verified(path)
        self.assertFalse(proof["rollbackAllowed"])
        self.assertFalse(proof["continuousMonitoringProven"])
        self.assertEqual(m.monitor_status(directory), "not-started")
        with self.assertRaises(c.PromotionError):
            m.rollback_allowed(directory, c.binding(directory), scope(), clock())

    def test_rollback_only_blocked_live_window_and_bound_hash(self):
        directory = self.make_monitor()
        _, events = m.history(directory)
        m.append_event(directory, events, {"phase": "blocked", "reasons": ["failed-requests"]}, NOW)
        m.rollback_allowed(directory, c.binding(directory), scope(), NOW)
        for now in (NOW - timedelta(seconds=1), NOW + timedelta(minutes=6),
                    NOW + timedelta(hours=1), NOW + timedelta(hours=1, seconds=30)):
            with self.subTest(now=now), self.assertRaises(c.PromotionError):
                m.rollback_allowed(directory, c.binding(directory), scope(), now)

    def test_concurrent_monitor_owner_rejected(self):
        directory = self.make_monitor()
        with m.monitor_lock(directory):
            with self.assertRaises(c.PromotionError):
                with m.monitor_lock(directory):
                    self.fail("second owner admitted")

    def test_runtime_build_success_never_masks_later_failure(self):
        for status, expected in (("BuildSuccessful", "unconfirmed"), ("RuntimeStarting", "unconfirmed"),
                                 ("RuntimeFailed", "failed"), ("RuntimeSuccessful", "observed-runtime-success")):
            proof = o.runtime({"properties": {"deploymentId": "synthetic", "status": status,
                              "errors": [], "numberOfInstancesFailed": 0}}, "synthetic")
            self.assertEqual(proof["verdict"], expected)
            self.assertFalse(proof["runtimeZipBytesVerified"])
        with self.assertRaises(c.PromotionError):
            o.runtime({"properties": {"deploymentId": "synthetic", "status": "BuildSuccessful"}}, "synthetic")

    def test_receiver_enabled_is_not_verified_or_delivery_proof(self):
        group = {"properties": {"enabled": True, "emailReceivers": [
            {"name": "synthetic", "status": "Enabled", "verificationStatus": "Verified",
             "emailAddress": "nobody@example.invalid"}]}}
        self.assertFalse(o.receivers(group, ["synthetic"])["emailDeliveryProven"])
        for value in (None, "Pending", False):
            group["properties"]["emailReceivers"][0]["verificationStatus"] = value
            with self.assertRaises(c.PromotionError):
                o.receivers(group, ["synthetic"])

    def test_observability_healthy_http_never_masks_failed_runtime(self):
        rule_id = RID.replace("Microsoft.Storage/storageAccounts/fake",
                              "Microsoft.Insights/scheduledQueryRules/rule")
        group_id = RID.replace("Microsoft.Storage/storageAccounts/fake",
                               "Microsoft.Insights/actionGroups/group")
        props = {"enabled": True, "criteria": {"allOf": [{"query": "synthetic", "threshold": 0}]},
                 "scopes": [RID], "actions": {"actionGroups": [group_id]},
                 "evaluationFrequency": "PT5M", "windowSize": "PT15M", "autoMitigate": True}
        group = {"id": group_id, "properties": {"enabled": True, "emailReceivers": [
            {"name": "synthetic", "status": "Enabled", "verificationStatus": "Verified",
             "emailAddress": "nobody@example.invalid"}]}}
        spec = {"sha": SHA, "ruleUrl": "https://management.azure.com" + rule_id + "?api-version=2030-01-01",
                "groupUrl": "https://management.azure.com" + group_id + "?api-version=2030-01-01",
                "ruleProperties": {"/properties/" + k: {"present": True, "value": v}
                                   for k, v in props.items()},
                "requiredReceivers": ["synthetic"], "healthUrls": monitor_config()["healthUrls"],
                "deploymentStatusUrl": URL, "deploymentId": "synthetic"}
        self.api.get.side_effect = [{"id": rule_id, "properties": props}, group,
            {"properties": {"deploymentId": "synthetic", "status": "RuntimeFailed",
                            "numberOfInstancesFailed": 1, "errors": [{"code": "04916"}]}}]
        path, safe = o.observe(self.api, spec, self.root, probe=lambda _: {"status": 200})
        self.assertFalse(safe)
        report = c.verified(path)
        self.assertTrue(report["healthPassed"])
        self.assertEqual(report["runtime"]["verdict"], "failed")
        self.assertNotIn("nobody@", (path / "evidence.json").read_text())

    def test_final_health_failure_cannot_complete_after_prior_success(self):
        clock = Clock()
        directory = self.make_monitor()
        def probe(_):
            return {"status": 503 if clock() >= NOW + timedelta(hours=1) else 200}
        self.assertFalse(m.run_monitor(self.api, directory, clock=clock, sleep=clock.sleep,
                         query=healthy_query, probe=probe))
        self.assertEqual(m.monitor_status(directory), "blocked")

    def test_freshness_empty_and_new_exception_criteria(self):
        rows = healthy_query(self.api, monitor_config(), NOW - timedelta(hours=1), NOW)["rows"]
        self.assertFalse(m.evaluate(rows, set(), NOW, NOW))
        self.assertIn("empty-requests", m.evaluate([], set(), NOW, NOW))
        self.assertIn("stale-requests", m.evaluate(rows, set(), NOW + timedelta(minutes=16),
                                                 NOW + timedelta(hours=1)))
        rows.append({"metric": "exceptions", "name": "SyntheticException", "count": 1})
        self.assertIn("new-exception-type", m.evaluate(rows, set(), NOW, NOW))
        self.assertNotIn("new-exception-type", m.evaluate(rows, {"SyntheticException"}, NOW, NOW))


class CliTests(OfflineCase):
    def call(self, args):
        with contextlib.redirect_stdout(io.StringIO()) as out, contextlib.redirect_stderr(io.StringIO()) as err:
            code = main(args)
        return code, out.getvalue(), err.getvalue()

    def test_help_is_offline(self):
        with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(SystemExit) as result:
            main(["--help"])
        self.assertEqual(result.exception.code, 0)

    def test_status_incomplete_nonzero(self):
        directory = self.make_monitor()
        code, output, _ = self.call(["status", "--monitor", str(directory)])
        self.assertEqual(code, 2)
        self.assertEqual(json.loads(output)["state"], "not-started")

    def test_invalid_context_is_nonzero_without_network_or_secrets(self):
        path = self.root / "context.json"
        path.write_text('{"secret":"NEVER-PRINT-ME"}')
        code, output, error = self.call(["--context", str(path), "--output", str(self.root),
                                       "source", "--run", "123", "--sha", SHA])
        self.assertEqual(code, 2)
        self.assertNotIn("NEVER-PRINT-ME", output + error)

    def test_cli_monitor_blocked_not_success_shaped(self):
        config = self.root / "context.json"
        config.write_bytes(c.encoded(CONFIG))
        directory = self.make_monitor()
        with patch("promotion.__main__.Commands", return_value=self.api), \
                patch("promotion.monitor.run_monitor", return_value=False):
            code, output, _ = self.call(["--context", str(config), "--output", str(self.root),
                                       "monitor", "--monitor", str(directory)])
        self.assertEqual(code, 2)
        self.assertEqual(json.loads(output)["result"], "blocked-or-unconfirmed")

    def test_cli_dispatch_never_defaults_execute(self):
        first, second = self.preflight_pair()
        config, auth = self.root / "context.json", self.root / "authorization.json"
        config.write_bytes(c.encoded(CONFIG))
        auth.write_bytes(c.encoded(self.authorization(first, second)))
        with patch("promotion.__main__.Commands", return_value=self.api):
            code, _, _ = self.call(["--context", str(config), "--output", str(self.root),
                "dispatch", "--authorization", str(auth), "--preflight", str(first),
                "--before", str(second), "--receipts", str(self.root / "ledger")])
        self.assertEqual(code, 2)
        self.api.gh.assert_not_called()


if __name__ == "__main__":
    unittest.main()
