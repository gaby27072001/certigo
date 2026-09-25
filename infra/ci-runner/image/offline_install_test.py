"""Tests of the offline image installer, its closed artifact set and wheel lock (#341).

The short tests run everywhere without root, network or large inputs. The
execution tests rebuild nothing: they need a harness base produced by
`offline_harness.py build-base` and the acquired closed store, and run the
real installer as root in an empty network namespace through qemu-user.
"""

import copy
import hashlib
import io
import json
import os
import random
import shutil
import socket
import stat
import struct
import subprocess
import sys
import tempfile
import time
import unittest
import urllib.request
from pathlib import Path
from unittest import mock

import image_artifacts
import install_offline
import lock_python
from lock_inputs import ROOT, file_hash, read_json, write_json

REPOSITORY = ROOT.parents[2]


def small_item(name, content, kind="deb", size=True):
    digest = hashlib.sha256(content).hexdigest()
    return image_artifacts._artifact(kind, name, f"https://example.invalid/{name}", "sha256",
                                     digest, len(content) if size else None, f"{name}.deb")


class ClosedSetTests(unittest.TestCase):
    def test_closed_set_is_exactly_the_non_bundled_locked_artifacts(self):
        items = image_artifacts.closed_set()
        kinds = {kind: sum(item["kind"] == kind for item in items)
                 for kind in ("toolchain", "deb", "pub", "wheel")}
        self.assertEqual(kinds, {"toolchain": 7, "deb": 9, "pub": 102, "wheel": 94})
        self.assertEqual(len(items), 212)
        flutter = read_json(ROOT / "flutter-engine-artifacts.lock.json")
        bundled = {a["url"] for a in flutter["artifacts"] if a["cacheState"] == "bundled-current"}
        self.assertEqual(len(bundled), 12)
        self.assertFalse(bundled & {item["url"] for item in items})
        for item in items:
            self.assertTrue(item["url"].startswith("https://"), item["id"])
        apt = read_json(ROOT / "apt-packages.lock.json")
        self.assertEqual({i["id"] for i in items if i["kind"] == "deb"},
                         {p["package"] for p in apt["packages"]})

    def test_store_must_equal_the_closed_set(self):
        items = [small_item("a", b"alpha"), small_item("b", b"bravo", size=False)]
        with tempfile.TemporaryDirectory() as tmp:
            store = Path(tmp)
            for item, content in zip(items, (b"alpha", b"bravo")):
                (store / image_artifacts.store_name(item)).write_bytes(content)
            image_artifacts.verify_store(store, items)
            first = store / image_artifacts.store_name(items[0])
            cases = {
                "addition": (lambda: (store / "extra").write_bytes(b"x"),
                             lambda: (store / "extra").unlink(),
                             "Unexpected file in the closed artifact store: extra"),
                "alteration": (lambda: first.write_bytes(b"alphX"),
                               lambda: first.write_bytes(b"alpha"), "Digest mismatch for deb:a"),
                "resize": (lambda: first.write_bytes(b"alpha!"),
                           lambda: first.write_bytes(b"alpha"), "Size mismatch for deb:a"),
                "omission": (lambda: first.unlink(),
                             lambda: first.write_bytes(b"alpha"), "Missing artifact deb:a"),
            }
            for name, (mutate, restore, message) in cases.items():
                with self.subTest(mutation=name):
                    mutate()
                    with self.assertRaisesRegex(ValueError, message):
                        image_artifacts.verify_store(store, items)
                    restore()
            target = store / "real"
            first.rename(target)
            first.symlink_to(target)
            with self.assertRaisesRegex(ValueError, "Unexpected file|not a regular file"):
                image_artifacts.verify_store(store, items)

    def test_only_the_github_release_asset_hop_is_followed(self):
        handler = image_artifacts.GithubReleaseRedirect()
        release = "https://github.com/actions/runner/releases/download/v2.336.0/runner.tar.gz"

        def attempt(source, target):
            request = urllib.request.Request(source)
            return handler.redirect_request(request, io.BytesIO(), 302, "Found", {}, target)

        self.assertIsNotNone(attempt(release, "https://release-assets.githubusercontent.com/x?sig=1"))
        for source, target in (
            (release, "https://evil.invalid/runner.tar.gz"),
            (release, "http://release-assets.githubusercontent.com/x"),
            (release, "https://release-assets.githubusercontent.com:8443/x"),
            ("https://github.com/actions/runner/archive/main.tar.gz",
             "https://release-assets.githubusercontent.com/x"),
            ("https://pub.dev/api/archives/args-2.7.0.tar.gz", "https://storage.googleapis.com/x"),
            ("https://snapshot.ubuntu.com/ubuntu/x.deb", "https://archive.ubuntu.com/ubuntu/x.deb"),
        ):
            with self.subTest(source=source, target=target):
                with self.assertRaisesRegex(ValueError, "Unexpected redirect"):
                    attempt(source, target)

    def test_proxy_environment_cannot_redirect_acquisition(self):
        proxy = "http://proxy.invalid:3128"
        with mock.patch.dict(os.environ, {"https_proxy": proxy, "HTTPS_PROXY": proxy}):
            default = urllib.request.build_opener().handlers
            handlers = image_artifacts.opener().handlers
        # Positive control: the default opener would route through the proxy.
        self.assertIn({"https": proxy},
                      [h.proxies for h in default if isinstance(h, urllib.request.ProxyHandler)])
        self.assertEqual([h for h in handlers if isinstance(h, urllib.request.ProxyHandler)], [])

    def test_fetch_publishes_only_verified_bytes(self):
        class Response(io.BytesIO):
            def __enter__(self):
                return self

            def __exit__(self, *args):
                self.close()

        payload = b"verified-bytes"
        item = small_item("fetched", payload)
        for served, message in ((payload, None), (payload + b"!", "Size mismatch"),
                                (b"x" * len(payload), "Digest mismatch")):
            with self.subTest(message=message), tempfile.TemporaryDirectory() as tmp:
                fake = mock.Mock()
                fake.open.return_value = Response(served)
                with mock.patch.object(image_artifacts, "opener", return_value=fake):
                    if message is None:
                        self.assertEqual(image_artifacts.fetch(item, tmp), "fetched")
                        self.assertEqual((Path(tmp) / image_artifacts.store_name(item)).read_bytes(),
                                         payload)
                    else:
                        with self.assertRaisesRegex(ValueError, message):
                            image_artifacts.fetch(item, tmp)
                        self.assertEqual(os.listdir(tmp), [])
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / image_artifacts.store_name(item)).write_bytes(b"tampered")
            with self.assertRaisesRegex(ValueError, "Existing store entry is altered"):
                image_artifacts.fetch(item, tmp)


class WheelLockTests(unittest.TestCase):
    def test_committed_lock_reranks_offline(self):
        lock = lock_python.verify()
        self.assertEqual(len(lock["wheels"]), 94)
        self.assertTrue(all(w["filename"].endswith(".whl") for w in lock["wheels"]))

    def test_mutations_fail_for_their_reason(self):
        original = read_json(lock_python.LOCK)
        mutations = {
            "omission": (lambda lock: lock["wheels"].pop(), "omission or addition"),
            "addition": (lambda lock: lock["wheels"].append(copy.deepcopy(lock["wheels"][0])),
                         "omission or addition"),
            "redirection": (lambda lock: lock["wheels"][0].update(
                url="https://example.invalid/" + lock["wheels"][0]["filename"]),
                "Unexpected wheel origin"),
            "alteration": (lambda lock: lock["wheels"][0].update(sha256="a" * 64),
                           "Unauthorized artifact hash|best-ranked"),
            "stale": (lambda lock: lock.update(requirementsSha256="b" * 64),
                      "requirements lock changed"),
        }
        with tempfile.TemporaryDirectory() as tmp:
            for name, (mutate, message) in mutations.items():
                with self.subTest(mutation=name):
                    changed = copy.deepcopy(original)
                    mutate(changed)
                    path = Path(tmp) / f"{name}.json"
                    write_json(path, changed)
                    with self.assertRaisesRegex(ValueError, message):
                        lock_python.verify(path)

    def test_selection_is_pip_ranked_and_never_ambiguous(self):
        order = {"cp312-cp312-manylinux_2_28_x86_64": 0, "cp312-cp312-manylinux_2_17_x86_64": 1,
                 "py3-none-any": 2}
        requirement = {"version": "1.0", "hashes": {"a" * 64, "b" * 64, "c" * 64}}
        candidates = [
            {"filename": "demo-1.0-cp312-cp312-manylinux_2_17_x86_64.manylinux2014_x86_64.whl",
             "sha256": "a" * 64, "url": "u", "bytes": 1},
            {"filename": "demo-1.0-cp312-cp312-manylinux_2_28_x86_64.whl", "sha256": "b" * 64,
             "url": "u", "bytes": 1},
            {"filename": "demo-1.0-cp312-cp312-win_amd64.whl", "sha256": "c" * 64,
             "url": "u", "bytes": 1},
        ]
        selected, compatible = lock_python.select("demo", requirement, candidates, order)
        self.assertEqual(selected["sha256"], "b" * 64)
        self.assertEqual(len(compatible), 2)
        twin = dict(candidates[1], filename="demo-1.0-1-cp312-cp312-manylinux_2_28_x86_64.whl",
                    sha256="c" * 64)
        with self.assertRaisesRegex(ValueError, "Ambiguous"):
            lock_python.select("demo", requirement, [candidates[1], twin], order)
        with self.assertRaisesRegex(ValueError, "Unauthorized"):
            lock_python.select("demo", {"version": "1.0", "hashes": set()}, candidates, order)
        with self.assertRaisesRegex(ValueError, "Unparsed or unpinned"):
            lock_python.requirements("demo>=1.0\n")


class SentinelTests(unittest.TestCase):
    def start_sentinel(self):
        # Shared persistent runners: retry on another high port range if one is taken.
        for _ in range(8):
            sentinel = install_offline.NetworkSentinel()
            offset = random.randint(20000, 40000)
            try:
                return sentinel.start(families=(socket.AF_INET,), port_offset=offset), offset
            except OSError:
                sentinel.stop()
        self.fail("No free port range for the sentinel test")

    def test_dns_and_tcp_attempts_are_recorded_and_refused(self):
        sentinel, offset = self.start_sentinel()
        try:
            query = (b"\x12\x34\x01\x00\x00\x01\x00\x00\x00\x00\x00\x00" +
                     b"\x03pub\x03dev\x00\x00\x01\x00\x01")
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as udp:
                udp.settimeout(2)
                udp.sendto(query, ("127.0.0.1", 53 + offset))
                reply = udp.recv(512)
            self.assertEqual(reply[:2], b"\x12\x34")
            self.assertEqual(struct.unpack("!H", reply[2:4])[0] & 0x000F, 5)
            with socket.create_connection(("127.0.0.1", 443 + offset), timeout=2):
                pass
            for _ in range(50):
                events = sentinel.snapshot()
                if len(events) >= 2:
                    break
                time.sleep(0.05)
        finally:
            events = sentinel.stop()
        self.assertIn({"protocol": "dns/udp", "destination": "127.0.0.1", "query": "pub.dev"}, events)
        self.assertIn({"protocol": "tcp", "destination": "127.0.0.1", "port": 443}, events)

    def test_malformed_dns_is_recorded_without_name(self):
        self.assertIsNone(install_offline.NetworkSentinel.query_name(b"\x00\x01"))
        self.assertIsNone(install_offline.NetworkSentinel.query_name(b"\x00" * 12 + b"\xc0\x0c"))


class InstallerTests(unittest.TestCase):
    def inputs(self, tmp):
        contract = read_json(ROOT / "image-build-contract.json")
        directory = Path(tmp) / "inputs"
        directory.mkdir()
        shutil.copyfile(ROOT / "image-build-contract.json", directory / "image-build-contract.json")
        for item in contract["inputs"]:
            shutil.copyfile(REPOSITORY / item["path"], directory / item["destination"])
        return directory

    def installer(self, directory, digest=None):
        return install_offline.Installer(directory, directory / "store",
                                         digest or file_hash(directory / "image-build-contract.json"),
                                         directory.parent)

    def test_inputs_are_closed_and_cross_checked(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = self.inputs(tmp)
            self.installer(directory).verify_inputs()
            with self.assertRaisesRegex(ValueError, "template contract digest"):
                self.installer(directory, "0" * 64).verify_inputs()
            bootstrap = directory / "bootstrap.sh"
            original = bootstrap.read_bytes()
            bootstrap.write_bytes(original + b"\n")
            with self.assertRaisesRegex(ValueError, "Image input digest mismatch: bootstrap.sh"):
                self.installer(directory).verify_inputs()
            bootstrap.unlink()
            with self.assertRaisesRegex(ValueError, "Missing or non-regular image input: bootstrap.sh"):
                self.installer(directory).verify_inputs()
            bootstrap.write_bytes(original)
            (directory / "unexpected.sh").write_text("exit 0\n")
            with self.assertRaisesRegex(ValueError, "Unexpected file in the image inputs"):
                self.installer(directory).verify_inputs()

    def test_resolver_overrides_are_refused_by_name(self):
        for name in ("https_proxy", "HTTP_PROXY", "PIP_INDEX_URL", "PUB_HOSTED_URL",
                     "FLUTTER_STORAGE_BASE_URL", "npm_config_registry", "APT_CONFIG",
                     "GIT_CONFIG_GLOBAL", "NUGET_PACKAGES"):
            self.assertTrue(install_offline.RESOLVER_OVERRIDES.match(name), name)
        for name in ("PATH", "HOME", "LANG", "SUDO_USER"):
            self.assertFalse(install_offline.RESOLVER_OVERRIDES.match(name), name)

    def test_expected_package_states_come_from_the_lock(self):
        installer = self.installer(Path(tempfile.gettempdir()) / "unused", "0" * 64)
        installer.apt = read_json(ROOT / "apt-packages.lock.json")
        base = installer.expected_state(False)
        final = installer.expected_state(True, held={"azure-cli"})
        self.assertEqual((len(base), len(final)), (656, 665))
        self.assertIn("azure-cli:amd64\t2.89.0-1~noble\thi", final)
        self.assertLessEqual(set(base), set(final))
        self.assertEqual(len(set(final) - set(base)), 9)

    @unittest.skipUnless(hasattr(os, "killpg"), "requires POSIX process groups")
    def test_watchdog_kills_a_step_at_its_first_network_attempt(self):
        class Sentinel:
            def __init__(self):
                self.started = time.monotonic()

            def snapshot(self):
                if time.monotonic() - self.started > 1:
                    return [{"protocol": "dns/udp", "destination": "127.0.0.53", "query": "pub.dev"}]
                return []

            def counters(self):
                return {"ipv4/udp": 0}

        with tempfile.TemporaryDirectory() as tmp:
            installer = install_offline.Installer(Path(tmp), Path(tmp), "0" * 64, Path(tmp))
            installer.sentinel = Sentinel()
            started = time.monotonic()
            with self.assertRaisesRegex(ValueError,
                                        "Unexpected network attempt during retrying: dns/udp pub.dev"):
                installer.run("retrying", ["sh", "-c", "sleep 60; echo late-output-$((1 + 1))"])
            self.assertLess(time.monotonic() - started, 20)
            self.assertNotIn("late-output-2", (Path(tmp) / "install.log").read_text())

    def test_precache_and_config_may_only_create_the_lock_file(self):
        installer = self.installer(Path(tempfile.gettempdir()) / "unused", "0" * 64)
        before = {"bin/cache/engine.stamp": ("f", 41, "a"), "bin/cache/linux-sdk.stamp": ("f", 41, "b")}
        installer.require_precache_noop(before, dict(before, **{"bin/cache/lockfile": ("f", 0, "c")}))
        for after, reason in (
            (dict(before, **{"bin/cache/downloads": ("d",)}), "bin/cache/downloads"),
            (dict(before, **{"bin/cache/linux-sdk.stamp": ("f", 41, "z")}), "linux-sdk.stamp"),
            ({"bin/cache/engine.stamp": ("f", 41, "a")}, "linux-sdk.stamp"),
        ):
            with self.subTest(reason=reason), self.assertRaisesRegex(ValueError, reason):
                installer.require_precache_noop(before, after)


class InventoryTests(unittest.TestCase):
    EXCLUDED = (".runner", ".credentials", ".credentials_rsaparams", ".service", ".env", ".path")

    @staticmethod
    def reference(roots, runner_home):
        """Independent statement of the inventory format for the three roots."""
        pruned = {runner_home / "_diag", runner_home / "_work"}
        pruned |= {runner_home / name for name in InventoryTests.EXCLUDED}
        paths = []

        def walk(path):
            if path in pruned:
                return
            paths.append(path)
            if path.is_dir() and not path.is_symlink():
                for child in path.iterdir():
                    walk(child)

        for root in roots:
            walk(root)
        lines = []
        for path in sorted(paths, key=os.fsencode):
            status = os.lstat(path)
            prefix = f"{format(stat.S_IMODE(status.st_mode), 'o')}\t{status.st_uid}:{status.st_gid}"
            if stat.S_ISLNK(status.st_mode):
                lines.append(f"l\t{prefix}\t{path}\t{os.readlink(path)}\n")
            elif stat.S_ISREG(status.st_mode):
                lines.append(f"f\t{prefix}\t{path}\t{hashlib.sha256(path.read_bytes()).hexdigest()}\n")
            else:
                lines.append(f"d\t{prefix}\t{path}\t-\n")
        return "".join(lines)

    @unittest.skipUnless(sys.platform == "linux", "requires bash, GNU find and coreutils")
    def test_batched_inventory_matches_an_independent_reference(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            toolchains, runner, azure = root / "toolchains", root / "runner", root / "az"
            apt, cloud = root / "apt", root / "cloud.cfg.d"
            for directory in (toolchains / "a" / "b", runner / "bin", runner / "_diag" / "x",
                              runner / "_work" / "y", azure / "lib", apt / "sources.list.d", cloud):
                directory.mkdir(parents=True)
            (apt / "sources.list").write_text("# no remote source\n")
            (cloud / "99-certigo.cfg").write_text("apt:\n  preserve_sources_list: true\n")
            (toolchains / "a" / "file one.txt").write_bytes(b"alpha")
            executable = toolchains / "a" / "b" / "setuid-exec"
            executable.write_bytes(b"#!/bin/sh\n")
            os.chmod(executable, 0o4755)
            (toolchains / "a" / "empty").write_bytes(b"")
            (toolchains / "relative-link").symlink_to("a/file one.txt")
            (toolchains / "dangling-link").symlink_to("missing")
            (toolchains / "directory-link").symlink_to("a")
            (runner / "bin" / "Runner.Listener").write_bytes(b"runner")
            for name in self.EXCLUDED:
                (runner / name).write_text("registration state")
            (runner / ".runner.backup").write_text("not excluded")
            (runner / "_diag" / "x" / "log").write_text("log")
            (runner / "_work" / "y" / "w").write_text("work")
            # A PR can leave any name in its pruned workspace: it must not deny the next job.
            (runner / "_work" / "y" / "tab\tname").write_text("work")
            (azure / "lib" / "é-unicode").write_bytes(b"unicode")
            output = root / "inventory.tsv"
            environment = dict(os.environ, CERTIGO_TOOLCHAIN_ROOT=str(toolchains),
                               CERTIGO_RUNNER_HOME=str(runner), CERTIGO_AZURE_CLI_ROOT=str(azure),
                               CERTIGO_APT_ROOT=str(apt), CERTIGO_CLOUD_CONFIG_ROOT=str(cloud))
            script = str(ROOT / "inventory-toolchain.sh")
            subprocess.run(["bash", script, "--roots-only", str(output)], env=environment, check=True)
            self.assertEqual(output.read_text(encoding="utf-8"),
                             self.reference((toolchains, runner, azure, apt, cloud), runner))
            (apt / "sources.list.d" / "added.sources").write_text("Types: deb\n")
            subprocess.run(["bash", script, "--roots-only", str(output)], env=environment, check=True)
            self.assertIn(f"{apt}/sources.list.d/added.sources\t", output.read_text(encoding="utf-8"))
            (apt / "sources.list.d" / "added.sources").unlink()
            (toolchains / "a" / "tab\tname").write_text("ambiguous")
            result = subprocess.run(["bash", script, "--roots-only", str(output)], env=environment,
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Unsupported file name in immutable toolchain", result.stderr)
            (toolchains / "a" / "tab\tname").unlink()
            os.mkfifo(toolchains / "a" / "fifo")
            result = subprocess.run(["bash", script, "--roots-only", str(output)], env=environment,
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Unsupported filesystem entry in immutable toolchain", result.stderr)

    def test_masked_units_are_attested_and_verified(self):
        validator = (ROOT / "validate-toolchain.sh").read_text()
        inventory = (ROOT / "inventory-toolchain.sh").read_text()
        for unit in install_offline.APT_AUTOMATION_UNITS:
            self.assertIn(unit, validator)
            self.assertIn(f"/etc/systemd/system/{unit}\n", inventory)
        roots = ('${CERTIGO_APT_ROOT:-/etc/apt}', '${CERTIGO_CLOUD_CONFIG_ROOT:-/etc/cloud/cloud.cfg.d}')
        for root in roots:
            self.assertIn(root, inventory)
        for path in install_offline.PATCHING_FILES:
            self.assertTrue(str(path).startswith(("/etc/apt/", "/etc/cloud/cloud.cfg.d/")), path)
        self.assertIn("--no-release-info", validator)
        self.assertIn("/var/lib/snapd/seed/snaps/*.snap", validator)
        self.assertNotIn("az version", validator)


class ExecutionEvidenceTests(unittest.TestCase):
    """The qemu suite cannot run on the persistent CI runners; its report is bound instead."""

    def test_committed_execution_evidence_matches_the_current_inputs(self):
        import offline_harness
        evidence = read_json(ROOT / "offline-execution-evidence.json")
        self.assertEqual(evidence["boundDigests"], offline_harness.bound_digests(),
                         "Execution evidence is stale: rerun offline_harness.py run-suite, "
                         "then offline_harness.py evidence")
        names = [scenario["scenario"] for scenario in evidence["scenarios"]]
        self.assertEqual(sorted(names), sorted(offline_harness.SCENARIOS))
        self.assertTrue(all(scenario["passed"] for scenario in evidence["scenarios"]))
        for scenario in evidence["scenarios"]:
            if scenario["scenario"] == "positive":
                continue
            self.assertIsNotNone(scenario["observedReason"], scenario["scenario"])
            if scenario["scenario"] == "unexpected-download":
                self.assertRegex(scenario["observedReason"], scenario["expectedReason"])
            else:
                self.assertIn(scenario["expectedReason"], scenario["observedReason"])
        positive = next(item for item in evidence["scenarios"] if item["scenario"] == "positive")
        self.assertEqual(positive["dpkgPackages"], 665)
        self.assertEqual(positive["attestation"]["networkAttempts"], [])
        self.assertTrue(positive["inventoryEquivalence"]["identical"])
        self.assertTrue(positive["runnerRuntime"].startswith("blocked by defect 6"))


@unittest.skipUnless(os.environ.get("CERTIGO_OFFLINE_ROOTFS"), "requires the qemu harness base")
class OfflineExecutionTests(unittest.TestCase):
    """Real installer runs; see offline_harness.py for the environment."""

    def test_harness(self):
        report = Path(tempfile.gettempdir()) / "certigo-offline-suite.json"
        command = [sys.executable, str(ROOT / "offline_harness.py"), "run-suite",
                   "--rootfs", os.environ["CERTIGO_OFFLINE_ROOTFS"],
                   "--store", os.environ["CERTIGO_OFFLINE_STORE"], "--report", str(report)]
        subprocess.run(command, check=True)


if __name__ == "__main__":
    unittest.main()
