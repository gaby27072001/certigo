"""Small offline gates; optional real-capture replay via CERTIGO_* environment."""

import copy
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from lock_apt import (
    BASE, EVIDENCE, isolated_config, observed_inputs, observed_transactions, reconcile_observation,
)
from lock_flutter import ENGINE, FRAMEWORK, entrypoint_preconditions, pub_graph
from lock_inputs import (
    MICROSOFT_KEY, NoRedirect, ROOT, artifact_url, checked_file, compare_lock,
    fetch, paragraphs, read_json, release_index, serialize, sha256, signature, write_json,
)


def mutations(original, field):
    for mutation in ("omit", "add", "redirect", "alter"):
        changed = copy.deepcopy(original)
        if mutation == "omit":
            changed[field].pop()
        elif mutation == "add":
            changed[field].append(changed[field][0])
        elif mutation == "redirect":
            changed[field][0]["url"] = "https://example.invalid/replacement"
        else:
            changed[field][0]["sha256"] = "a" * 64
        yield mutation, changed


class InputTests(unittest.TestCase):
    def test_control_metadata_roundtrip_preserves_solver_fields(self):
        text = ("Package: example\nVersion: 1\nArchitecture: amd64\n"
                "Multi-Arch: same\nDepends: libc6 (>= 2), alt-a | alt-b\n"
                "Pre-Depends: base\nProvides: virtual (= 1)\nConflicts: old\n"
                "Breaks: incompatible (<< 2)\nReplaces: old\nEssential: yes\n"
                "Recommends: suggested\nDescription: summary\n continuation\n\n")
        self.assertEqual(serialize(next(paragraphs(text))), text)
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            list(paragraphs(text.replace("Version: 1", "Version: 1\nVersion: 2")))

    def test_signed_index_requires_exact_name_size_and_sha(self):
        release = {"SHA256": "\n " + "a" * 64 + " 123 main/binary-amd64/Packages"}
        self.assertEqual(release_index(release, "main/binary-amd64/Packages"), ("a" * 64, 123))
        with self.assertRaisesRegex(ValueError, "Missing/duplicate"):
            release_index(release, "main/binary-arm64/Packages")

    def test_apt_configuration_does_not_inherit_host_sources_status_or_hooks(self):
        with tempfile.TemporaryDirectory() as tmp:
            config = isolated_config(Path(tmp)).read_text()
            self.assertIn(f'Dir::State::status "{tmp}/status"', config)
            self.assertIn('Dir::Etc::parts "empty"', config)
            self.assertIn('APT::Architectures { "amd64"; }', config)
            self.assertNotIn("/var/lib", config)

    def test_exact_observed_bootstrap_oracle_and_platform_exception(self):
        log = (BASE.parent / "2026-09-23-pr31-dpkg.txt").read_text()
        history = (BASE.parent / "2026-09-23-pr31-apt-history.txt").read_text()
        observed = observed_transactions(log, history)
        additions = {p["package"] for p in observed if p["action"] == "install"}
        self.assertEqual(len(additions), 6)
        self.assertNotIn("ubuntu-advantage-tools:all", additions)
        lock = read_json(ROOT / "apt-packages.lock.json")
        self.assertLessEqual(additions, {p["package"] for p in lock["packages"]})
        for changed in (
            log + "\n2026-09-20 12:00:00 install unexpected:amd64 <none> 1\n",
            log + "\n2026-09-20 12:00:00 install ubuntu-advantage-tools:all <none> 1\n",
            log + "\n2026-09-20 12:00:00 upgrade curl:amd64 1 2\n",
            log + "\n2026-09-20 12:00:00 remove curl:amd64 1 <none>\n",
            log + "\n2026-09-20 12:00:00 purge curl:amd64 1 <none>\n",
            log.replace("2026-09-19 12:53:09 install", "2026-09-19 12:53:08 install"),
        ):
            with self.assertRaises(ValueError):
                observed_transactions(changed, history)
        with self.assertRaises(ValueError):
            observed_transactions(log, history.replace("12:53:07", "12:53:08"))

    def test_oracle_authenticates_both_logs_before_parsing(self):
        base = read_json(BASE)
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            for kind in ("dpkg", "apt-history"):
                for name in base["sourceSha256"]:
                    (directory / name).write_bytes((BASE.parent / name).read_bytes())
                observed_inputs(base, directory)
                path = directory / f"2026-09-23-pr31-{kind}.txt"
                path.write_bytes(path.read_bytes() + b"\n")
                with self.assertRaisesRegex(ValueError, "SHA256 mismatch"):
                    observed_inputs(base, directory)

    def test_observed_differences_and_prewarm_cardinality_are_explicit(self):
        base = read_json(BASE)
        lock = read_json(ROOT / "apt-packages.lock.json")
        observed, _ = observed_inputs(base)
        installed = {p["package"]: {"Version": p["version"]} for p in lock["snapshotResolvedPackages"]}
        result = reconcile_observation(base, observed, installed, lock["transactions"])
        self.assertEqual(result, lock["observationReconciliation"])
        self.assertEqual(result["unreproducedVersionTransactions"],
                         [t for t in result["bootstrapVersionTransactions"] if not t["reproduced"]])
        for change in ("extra", "omit"):
            altered = copy.deepcopy(installed)
            if change == "extra":
                altered["unexpected:amd64"] = {"Version": "1"}
            else:
                altered.pop("curl:amd64")
            with self.assertRaises(ValueError):
                reconcile_observation(base, observed, altered, lock["transactions"])

    def test_all_base_dependencies_remain_explicitly_bound(self):
        base = read_json(BASE)
        lock = read_json(ROOT / "apt-packages.lock.json")
        installed = {p["package"]: p for p in lock["snapshotResolvedPackages"]}
        delta = {p["package"]: p for p in lock["packages"]}
        self.assertEqual(len(installed), len(lock["snapshotResolvedPackages"]))
        for package in base["packages"]:
            entry = installed[package["package"]]
            expected = delta.get(package["package"], package)
            self.assertEqual(entry["version"], expected["version"])
            self.assertEqual(entry["sha256"], expected["sha256"])
            self.assertEqual(entry["origin"],
                             "transaction" if package["package"] in delta else "reconstructed-base")
        self.assertEqual(set(installed), {p["package"] for p in base["packages"]} | delta.keys())
        self.assertEqual(lock["baseEvidenceSha256"], sha256(BASE.read_bytes()))
        self.assertEqual(lock["indexesSha256"], sha256((EVIDENCE / "indexes.json").read_bytes()))

    def test_both_locks_reject_omission_addition_redirection_and_hash_change(self):
        for filename, field in (("apt-packages.lock.json", "packages"),
                                ("flutter-engine-artifacts.lock.json", "artifacts")):
            original = read_json(ROOT / filename)
            for mutation, changed in mutations(original, field):
                with self.subTest(lock=filename, mutation=mutation):
                    with self.assertRaisesRegex(ValueError, "replayed artifact graph"):
                        compare_lock(changed, original)

    def test_flutter_entrypoint_rejects_unmodelled_rebuild_download_and_feature_branches(self):
        files = {"bin/cache/flutter_tools.snapshot"}
        directories = {"bin/cache/dart-sdk"}
        contents = {
            "bin/cache/flutter_tools.stamp": (FRAMEWORK + ":").encode(),
            "bin/cache/engine.stamp": ENGINE.encode(),
            "bin/cache/engine-dart-sdk.stamp": ENGINE.encode(),
            ".git/HEAD": b"ref: refs/heads/stable",
            ".git/packed-refs": (FRAMEWORK + " refs/heads/stable").encode(),
            "packages/flutter_tools/lib/src/features.dart":
                b"const flutterLinuxDesktopFeature = Feature.fullyEnabled(",
        }
        mtimes = {"packages/flutter_tools/pubspec.yaml": 1, "packages/flutter_tools/pubspec.lock": 2}
        entrypoint_preconditions(files, directories, contents, mtimes)
        for name in contents:
            altered = {**contents, name: b"changed"}
            with self.subTest(input=name), self.assertRaises(ValueError):
                entrypoint_preconditions(files, directories, altered, mtimes)
        with self.assertRaises(ValueError):
            entrypoint_preconditions(set(), directories, contents, mtimes)
        with self.assertRaises(ValueError):
            entrypoint_preconditions(files, set(), contents, mtimes)
        with self.assertRaises(ValueError):
            entrypoint_preconditions(files, directories, contents, dict.fromkeys(mtimes, 0) |
                                    {"packages/flutter_tools/pubspec.yaml": 1})

    def test_bytes_omission_alteration_and_symlink_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "artifact"
            path.write_bytes(b"verified")
            digest = sha256(b"verified")
            checked_file(path, digest, 8)
            path.write_bytes(b"altered!")
            with self.assertRaisesRegex(ValueError, "SHA256"):
                checked_file(path, digest)
            path.unlink()
            with self.assertRaisesRegex(ValueError, "Missing/nonregular"):
                checked_file(path, digest)
            target = Path(tmp) / "real"
            target.write_bytes(b"verified")
            path.symlink_to(target)
            with self.assertRaisesRegex(ValueError, "Missing/nonregular"):
                checked_file(path, digest)

    def test_http_redirect_and_path_escape_are_rejected(self):
        class Request:
            full_url = "https://pub.dev/api/archives/pinned.tar.gz"
        with self.assertRaisesRegex(ValueError, "Unexpected redirect"):
            NoRedirect().redirect_request(Request(), None, 302, "", {}, "https://evil.invalid/")
        for filename in ("../outside", "/absolute", "path?redirect=1", "path#fragment"):
            with self.assertRaises(ValueError):
                artifact_url("https://snapshot.ubuntu.com/", filename)
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(ValueError, "HTTPS required"):
                fetch("http://example.invalid/archive", Path(tmp) / "archive")

    def test_pub_rejects_nonhosted_missing_hash_or_repointed_repository(self):
        text = ('packages:\n  args:\n    description:\n      sha256: "' + "a" * 64 +
                '"\n      url: "https://pub.dev"\n    source: hosted\n    version: "2.7.0"\nsdks:\n')
        self.assertEqual(pub_graph(text)[0]["package"], "args")
        for changed in (text.replace("hosted", "git"), text.replace("pub.dev", "example.invalid"),
                        text.replace("sha256:", "digest:")):
            with self.assertRaises(ValueError):
                pub_graph(changed)

    @unittest.skipUnless(sys.platform == "linux", "gpgv capture test requires Linux")
    def test_retained_microsoft_signature_and_tampered_index(self):
        with tempfile.TemporaryDirectory() as tmp:
            ring = Path(tmp) / "key.gpg"
            subprocess.run(["gpg", "--batch", "--dearmor", "--output", str(ring),
                            str(EVIDENCE / "microsoft.asc")], check=True, capture_output=True)
            release = signature(EVIDENCE / "microsoft-InRelease", ring, MICROSOFT_KEY, tmp)
            digest, size = release_index(release, "main/binary-amd64/Packages")
            checked_file(EVIDENCE / "microsoft-Packages", digest, size)
            altered = Path(tmp) / "Packages"
            altered.write_bytes((EVIDENCE / "microsoft-Packages").read_bytes() + b"\n")
            with self.assertRaises(ValueError):
                checked_file(altered, digest, size)
            release_path = Path(tmp) / "InRelease"
            release_path.write_bytes((EVIDENCE / "microsoft-InRelease").read_bytes()
                                     .replace(b"Suite: noble", b"Suite: other"))
            with self.assertRaises(ValueError):
                signature(release_path, ring, MICROSOFT_KEY, tmp)


@unittest.skipUnless(os.environ.get("CERTIGO_APT_CACHE"), "requires acquired replay inputs")
class CapturedReplayTests(unittest.TestCase):
    def verify_and_reject_mutations(self, script, filename, field, arguments):
        command = ["unshare", "-n", sys.executable, str(ROOT / script), "verify", *arguments]
        subprocess.run(command, check=True)
        with tempfile.TemporaryDirectory() as tmp:
            for mutation, changed in mutations(read_json(ROOT / filename), field):
                with self.subTest(lock=filename, mutation=mutation):
                    path = Path(tmp) / f"{mutation}.json"
                    write_json(path, changed)
                    result = subprocess.run(command + ["--output", str(path)],
                                            capture_output=True, text=True)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("Lock differs from the replayed artifact graph", result.stderr)

    def test_real_apt_replay_without_network(self):
        self.verify_and_reject_mutations("lock_apt.py", "apt-packages.lock.json", "packages", [
            "--cache", os.environ["CERTIGO_APT_CACHE"],
            "--runner-archive", os.environ["CERTIGO_RUNNER_ARCHIVE"],
        ])

    def test_real_flutter_replay_without_network(self):
        self.verify_and_reject_mutations("lock_flutter.py", "flutter-engine-artifacts.lock.json", "artifacts", [
            "--cache", os.environ["CERTIGO_FLUTTER_CACHE"],
            "--sdk-archive", os.environ["CERTIGO_FLUTTER_ARCHIVE"],
        ])


if __name__ == "__main__":
    unittest.main()
