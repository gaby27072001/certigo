from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "project_state.py"
REPO_ROOT = MODULE_PATH.parents[1]
SPEC = importlib.util.spec_from_file_location("project_state", MODULE_PATH)
assert SPEC and SPEC.loader
project_state = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = project_state
SPEC.loader.exec_module(project_state)


class Fixture:
    def __init__(self, root: Path) -> None:
        self.root = root

    def write(self, relative: str, content: str = "") -> None:
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    def json(self, relative: str, value: object) -> None:
        self.write(relative, json.dumps(value, indent=2) + "\n")

    def git(self, *args: str, date: str | None = None) -> str:
        env = os.environ.copy()
        if date:
            env["GIT_AUTHOR_DATE"] = date
            env["GIT_COMMITTER_DATE"] = date
        result = subprocess.run(
            ["git", *args],
            cwd=self.root,
            check=True,
            capture_output=True,
            text=True,
            env=env,
        )
        return result.stdout.strip()

    def commit(self, message: str, date: str) -> str:
        self.git("add", ".")
        self.git("commit", "-m", message, date=date)
        return self.git("rev-parse", "HEAD")

    def build(self) -> None:
        self.write(
            "docs/ETAT_DU_PROJET.md",
            "avant\n"
            f"{project_state.START_MARKER}\nancien\n{project_state.END_MARKER}\n"
            "après\n",
        )
        self.write(
            ".github/workflows/ci-mobile.yml",
            'env:\n  FLUTTER_VERSION: "3.44.4"\n',
        )
        self.write(
            ".github/workflows/release-android.yml",
            'env:\n  FLUTTER_VERSION: "3.44.4"\n',
        )
        self.write(
            ".github/workflows/ci-backend.yml",
            'steps:\n  - with:\n      dotnet-version: "8.0.x"\n',
        )
        self.write(
            "codemagic.yaml",
            "workflows:\n"
            "  ios-release:\n"
            "    environment:\n"
            "      flutter: 3.44.4\n"
            "  ios-release-dry:\n"
            "    environment:\n"
            "      flutter: 3.44.4\n",
        )
        self.write(
            "README.md",
            "| Flutter SDK | **3.44.4** | app et tests |\n",
        )
        self.json("package.json", {"engines": {"node": ">=20"}})
        self.json(
            "content/schema/lesson.schema.json",
            {
                "$defs": {
                    "item": {
                        "properties": {
                            "type": {"enum": ["mcq", "multi", "matchPairs"]}
                        }
                    }
                }
            },
        )
        self.write(
            "backend/src/Certigo.Domain/Content/ContentModels.cs",
            "public enum ItemType { Mcq, Multi, MatchPairs }\n",
        )
        self.write("content/one/track.yaml", "id: one\n")
        self.write("content/one/lessons/a.lesson.yaml", "id: a\n")
        self.write("backend/tests/Domain/Domain.Tests.csproj", "<Project />\n")
        self.write("backend/tests/Domain/RuleTests.cs", "class RuleTests {}\n")
        self.write("apps/mobile/test/widget_test.dart", "void main() {}\n")
        self.write(".gitignore", "__pycache__/\n*.pyc\n")
        self.write(".gitattributes", "* text=auto eol=lf\n*.png binary\n")
        self.json(
            "docs/active-content-reference.json",
            {
                "schema": "certigo.active-content-reference/v1",
                "repository": "example/active-content",
                "branch": "main",
                "revision": "1" * 40,
                "date": "2026-08-06",
                "committedAt": "2026-08-06T12:00:00Z",
                "packageContract": {
                    "schema": project_state.PACKAGE_MANIFEST_SCHEMA,
                    "algorithm": project_state.PACKAGE_MANIFEST_ALGORITHM,
                    "serialization": project_state.PACKAGE_MANIFEST_SERIALIZATION,
                    "canonicalBodyFields": list(
                        project_state.PACKAGE_MANIFEST_BODY_FIELDS
                    ),
                    "excludedDigestFields": list(
                        project_state.PACKAGE_MANIFEST_DIGEST_FIELDS
                    ),
                },
                "manifests": {
                    "public": {
                        "path": "dist/public/manifest.json",
                        "channel": "public",
                        "artifact": "public",
                        "manifestId": f"sha256:{'2' * 64}",
                        "fileCount": 1,
                        "fileSha256": "3" * 64,
                    },
                    "private": {
                        "path": "dist/private/manifest.json",
                        "channel": "answerKey",
                        "artifact": "private",
                        "manifestId": f"sha256:{'4' * 64}",
                        "fileCount": 1,
                        "fileSha256": "5" * 64,
                    },
                },
            },
        )
        self.write("tools/project_state.py", "# fixture generator source\n")
        self.write("tools/tests/test_generator.py", "def test_placeholder(): pass\n")
        self.git("init")
        self.git("config", "user.email", "project-state@example.test")
        self.git("config", "user.name", "Project State Tests")
        commit = self.commit("fixture baseline", "2026-08-06T12:00:00+00:00")
        self.json(
            "docs/project-state-reference.json",
            {
                "commit": commit,
                "date": "2026-08-06",
                "observableSha256": project_state.observable_sha256(self.root),
                "semantics": "fixture reference",
            },
        )


class ProjectStateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.fixture = Fixture(self.root)
        self.fixture.build()

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_generation_is_deterministic_and_reference_is_exact(self) -> None:
        first = project_state.collect(self.root)
        second = project_state.collect(self.root)
        self.assertEqual(first, second)
        self.assertEqual("2026-08-06", first.reference_date)
        self.assertEqual(self.fixture.git("rev-parse", "HEAD"), first.reference_commit)
        self.assertEqual(project_state.render(first), project_state.render(second))

    def test_observable_hash_normalizes_declared_lf_text(self) -> None:
        source = self.root / ".github/workflows/ci-mobile.yml"
        original = source.read_bytes().replace(b"\r\n", b"\n")
        source.write_bytes(original)
        expected = project_state.observable_sha256(self.root)

        source.write_bytes(original.replace(b"\n", b"\r\n"))
        self.assertEqual(expected, project_state.observable_sha256(self.root))

        source.write_bytes(original + b"# semantic change\n")
        self.assertNotEqual(expected, project_state.observable_sha256(self.root))

    def test_equivalent_root_commit_does_not_require_reference_ancestry(self) -> None:
        captured_commit = project_state.load_reference(self.root)[1]
        self.fixture.git("checkout", "--orphan", "equivalent-root")
        equivalent_commit = self.fixture.commit(
            "equivalent squashed root",
            "2026-08-07T12:00:00+00:00",
        )
        ancestor = subprocess.run(
            ["git", "merge-base", "--is-ancestor", captured_commit, equivalent_commit],
            cwd=self.root,
            check=False,
        )
        self.assertNotEqual(0, ancestor.returncode)
        state = project_state.collect(self.root)
        self.assertEqual(captured_commit, state.reference_commit)
        self.assertEqual("2026-08-06", state.reference_date)

    def test_reference_commit_object_is_not_required(self) -> None:
        reference_path = self.root / project_state.REFERENCE_FILE
        reference = json.loads(reference_path.read_text(encoding="utf-8"))
        reference["commit"] = "f" * 40
        reference_path.write_text(
            json.dumps(reference, indent=2) + "\n", encoding="utf-8"
        )
        self.assertEqual("f" * 40, project_state.collect(self.root).reference_commit)

    def test_ignored_transient_files_do_not_change_observable_hash(self) -> None:
        baseline = project_state.observable_sha256(self.root)
        self.fixture.write("tools/tests/__pycache__/test_generator.pyc", "transient")
        self.assertEqual(baseline, project_state.observable_sha256(self.root))

    def test_check_detects_stale_output(self) -> None:
        self.assertTrue(project_state.update(self.root, check=False))
        self.assertFalse(project_state.update(self.root, check=True))
        document = self.root / "docs/ETAT_DU_PROJET.md"
        document.write_text(
            document.read_text(encoding="utf-8").replace("**>=20**", "**stale**"),
            encoding="utf-8",
        )
        with self.assertRaisesRegex(project_state.ProjectStateError, "is stale"):
            project_state.update(self.root, check=True)

    def test_source_change_requires_a_new_exact_reference(self) -> None:
        project_state.update(self.root, check=False)
        self.fixture.json("package.json", {"engines": {"node": ">=22"}})
        with self.assertRaisesRegex(project_state.ProjectStateError, "differ"):
            project_state.update(self.root, check=True)

        source_commit = self.fixture.commit(
            "update observable source",
            "2026-08-07T12:00:00+00:00",
        )
        project_state.refresh_reference(self.root)
        project_state.update(self.root, check=False)
        state = project_state.collect(self.root)
        self.assertEqual(source_commit, state.reference_commit)
        self.assertEqual("2026-08-07", state.reference_date)
        self.assertEqual(">=22", state.node)

    def test_reference_does_not_self_reference_generated_commit(self) -> None:
        project_state.update(self.root, check=False)
        document = self.root / "docs/ETAT_DU_PROJET.md"
        document.write_text(
            document.read_text(encoding="utf-8") + "narration du commit générateur\n",
            encoding="utf-8",
        )
        self.assertFalse(project_state.update(self.root, check=True))

    def test_refresh_after_generated_commit_keeps_observable_source_commit(self) -> None:
        source_commit = self.fixture.git("rev-parse", "HEAD")
        project_state.update(self.root, check=False)
        generated_commit = self.fixture.commit(
            "commit generated state",
            "2026-08-07T12:00:00+00:00",
        )
        self.assertNotEqual(source_commit, generated_commit)

        project_state.refresh_reference(self.root)

        self.assertEqual(source_commit, project_state.load_reference(self.root)[1])
        self.assertFalse(project_state.update(self.root, check=True))

    def test_missing_and_multiple_markers_are_rejected(self) -> None:
        with self.assertRaisesRegex(project_state.ProjectStateError, "start=0, end=0"):
            project_state.replace_generated("aucun marqueur", "generated")
        duplicate = (
            f"{project_state.START_MARKER}{project_state.END_MARKER}"
            f"{project_state.START_MARKER}{project_state.END_MARKER}"
        )
        with self.assertRaisesRegex(project_state.ProjectStateError, "start=2, end=2"):
            project_state.replace_generated(duplicate, "generated")

    def test_source_parsing_and_flutter_alignment(self) -> None:
        flutter, dotnet, node = project_state.parse_versions(self.root)
        self.assertEqual(("3.44.4", "8.0.x", ">=20"), (flutter, dotnet, node))
        self.fixture.write(
            ".github/workflows/release-android.yml",
            'env:\n  FLUTTER_VERSION: "3.30.0"\n',
        )
        with self.assertRaisesRegex(project_state.ProjectStateError, "misaligned"):
            project_state.parse_versions(self.root)

    def test_corpus_metrics(self) -> None:
        self.fixture.write("content/two/track.yaml", "id: two\n")
        self.fixture.write("content/two/lessons/b.lesson.yaml", "id: b\n")
        self.fixture.write("content/two/lessons/c.lesson.yaml", "id: c\n")
        self.assertEqual((2, 3), project_state.discover_corpus(self.root))

    def test_test_discovery(self) -> None:
        self.fixture.write("packages/core/test/core_test.dart", "void main() {}\n")
        result = project_state.discover_tests(self.root)
        self.assertEqual((1, 1, 2, 2, 1, 1), result)

    def test_every_observable_input_family_changes_output(self) -> None:
        baseline = project_state.render(project_state.collect(self.root))

        mutations = [
            lambda: self.fixture.write(".github/workflows/new-gate.yaml", "name: new\n"),
            lambda: self.fixture.write("content/one/lessons/b.lesson.yaml", "id: b\n"),
            lambda: self.fixture.write("apps/mobile/test/new_test.dart", "void main() {}\n"),
            lambda: self.fixture.write(
                "tools/tests/test_additional.py", "def test_additional(): pass\n"
            ),
            self._add_aligned_type,
        ]
        for index, mutation in enumerate(mutations, start=1):
            with self.subTest(mutation=mutation):
                mutation()
                self.fixture.commit(
                    f"observable mutation {index}",
                    f"2026-08-{6 + index:02d}T12:00:00+00:00",
                )
                project_state.refresh_reference(self.root)
                changed = project_state.render(project_state.collect(self.root))
                self.assertNotEqual(baseline, changed)
                baseline = changed

    def _add_aligned_type(self) -> None:
        self.fixture.json(
            "content/schema/lesson.schema.json",
            {
                "$defs": {
                    "item": {
                        "properties": {
                            "type": {
                                "enum": ["mcq", "multi", "matchPairs", "scenario"]
                            }
                        }
                    }
                }
            },
        )
        self.fixture.write(
            "backend/src/Certigo.Domain/Content/ContentModels.cs",
            "public enum ItemType { Mcq, Multi, MatchPairs, Scenario }\n",
        )

    def test_schema_and_csharp_type_mismatch_is_rejected(self) -> None:
        self.fixture.write(
            "backend/src/Certigo.Domain/Content/ContentModels.cs",
            "public enum ItemType { Mcq, Multi }\n",
        )
        with self.assertRaisesRegex(project_state.ProjectStateError, "misaligned"):
            project_state.parse_pedagogical_types(self.root)

    def test_active_content_reference_is_pinned_exactly(self) -> None:
        active = project_state.load_active_content_reference(REPO_ROOT)
        self.assertEqual(
            "663f32b4818964e307cf7e084cd09a9c6af91429", active.revision
        )
        self.assertEqual("2026-08-06", active.date)
        self.assertEqual("2026-08-06T15:59:29Z", active.committed_at)
        self.assertEqual(146, active.public.file_count)
        self.assertEqual(
            "sha256:335fb7c1538739cf2a1f2ac9629ed3d355dca851215fed61d60a28c166807dff",
            active.public.manifest_id,
        )
        self.assertEqual(
            "d067b47b9d96593ea58e5dbb22289e6abeef48fcc960ca74f74905c71644ed02",
            active.public.file_sha256,
        )
        self.assertEqual(146, active.private.file_count)
        self.assertEqual(
            "sha256:6e0ce2ef6ac799e3298e7e78ce23ad181a94961c979bef305e384898196f023b",
            active.private.manifest_id,
        )
        self.assertEqual(
            "06c42204be85737f149c1aff9c21da393c3dbdc6eeeeebe5621fa83777b2c102",
            active.private.file_sha256,
        )

    def test_active_content_revision_and_manifests_are_validated(self) -> None:
        with tempfile.TemporaryDirectory() as active_temp:
            active_root = Path(active_temp)
            active_fixture = Fixture(active_root)
            active_fixture.git("init")
            active_fixture.git("config", "user.email", "active-content@example.test")
            active_fixture.git("config", "user.name", "Active Content Tests")

            manifest_references: dict[str, dict[str, object]] = {}
            for name, channel, artifact in (
                ("public", "public", "public"),
                ("private", "answerKey", "private"),
            ):
                manifest: dict[str, object] = {
                    "schema": project_state.PACKAGE_MANIFEST_SCHEMA,
                    "channel": channel,
                    "artifact": artifact,
                    "algorithm": project_state.PACKAGE_MANIFEST_ALGORITHM,
                    "serialization": project_state.PACKAGE_MANIFEST_SERIALIZATION,
                    "fileCount": 1,
                    "files": [
                        {
                            "id": "lesson",
                            "path": (
                                "questions/lesson.json"
                                if channel == "public"
                                else "solutions/lesson.json"
                            ),
                            "hash": "6" * 64,
                            "size": 123,
                        }
                    ],
                    "manifestId": "",
                    "rootHash": "",
                }
                manifest["manifestId"] = project_state._canonical_manifest_id(manifest)
                manifest["rootHash"] = str(manifest["manifestId"]).removeprefix(
                    "sha256:"
                )
                relative = f"dist/{name}/manifest.json"
                active_fixture.write(
                    relative,
                    json.dumps(manifest, indent=2) + "\n",
                )
                raw = (active_root / relative).read_bytes()
                manifest_references[name] = {
                    "path": relative,
                    "channel": channel,
                    "artifact": artifact,
                    "manifestId": manifest["manifestId"],
                    "fileCount": 1,
                    "fileSha256": hashlib.sha256(raw).hexdigest(),
                }

            revision = active_fixture.commit(
                "package active content",
                "2026-08-06T09:57:19+00:00",
            )
            active_reference_path = (
                self.root / project_state.ACTIVE_CONTENT_REFERENCE_FILE
            )
            active_reference = json.loads(
                active_reference_path.read_text(encoding="utf-8")
            )
            active_reference["revision"] = revision
            active_reference["committedAt"] = "2026-08-06T09:57:19Z"
            active_reference["manifests"] = manifest_references
            active_reference_path.write_text(
                json.dumps(active_reference, indent=2) + "\n",
                encoding="utf-8",
            )

            project_state.validate_active_content_repository(self.root, active_root)
            public_manifest = active_root / "dist/public/manifest.json"
            public_manifest.write_text(
                public_manifest.read_text(encoding="utf-8") + "\n",
                encoding="utf-8",
            )
            with self.assertRaisesRegex(
                project_state.ProjectStateError, "file SHA-256"
            ):
                project_state.validate_active_content_repository(
                    self.root, active_root
                )

    def test_manifest_id_matches_upstream_canonical_body_without_newline(self) -> None:
        manifest: dict[str, object] = {
            "schema": project_state.PACKAGE_MANIFEST_SCHEMA,
            "channel": "public",
            "artifact": "public",
            "algorithm": project_state.PACKAGE_MANIFEST_ALGORITHM,
            "serialization": project_state.PACKAGE_MANIFEST_SERIALIZATION,
            "fileCount": 0,
            "files": [],
            "manifestId": "",
            "rootHash": "",
        }
        body = {
            field: manifest[field]
            for field in project_state.PACKAGE_MANIFEST_BODY_FIELDS
        }
        canonical = json.dumps(
            body,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
        expected = f"sha256:{hashlib.sha256(canonical).hexdigest()}"
        self.assertEqual(expected, project_state._canonical_manifest_id(manifest))

    def test_project_state_workflow_and_branch_protection_contract(self) -> None:
        workflow = (REPO_ROOT / ".github/workflows/ci-project-state.yml").read_text(
            encoding="utf-8"
        )
        self.assertIn("pull_request_target:", workflow)
        self.assertNotIn("\n  pull_request:\n", workflow)
        self.assertNotIn("paths:", workflow)
        self.assertIn("schedule:", workflow)
        self.assertIn('cron: "17 4 * * *"', workflow)
        self.assertIn("name: Generated state equals committed state", workflow)
        self.assertIn(
            "github.event.pull_request.head.repo.full_name == github.repository",
            workflow,
        )
        self.assertIn(
            "environment: ${{ github.event_name == 'pull_request_target' && 'pr-ci' || '' }}",
            workflow,
        )
        self.assertIn(
            "runs-on: [self-hosted, Linux, X64, certigo-ci]",
            workflow,
        )
        self.assertIn(
            "ref: ${{ github.event_name == 'pull_request_target' && "
            "github.event.pull_request.head.sha || github.sha }}",
            workflow,
        )
        self.assertNotIn("-latest", workflow)
        self.assertIn('node-version: "20.20.2"', workflow)
        self.assertIn("persist-credentials: false", workflow)
        self.assertIn(
            "CONTENT_DEPLOY_KEY: ${{ secrets.CERTIGO_CONTENT_DEPLOY_KEY }}",
            workflow,
        )
        self.assertIn(
            'if [ -z "${CONTENT_DEPLOY_KEY//[[:space:]]/}" ]',
            workflow,
        )
        self.assertIn(
            "ssh-key: ${{ secrets.CERTIGO_CONTENT_DEPLOY_KEY }}",
            workflow,
        )
        self.assertIn("ssh-strict: true", workflow)
        self.assertIn("ssh-known-hosts: |", workflow)
        self.assertIn("github.com ssh-ed25519 ", workflow)
        self.assertIn("github.com ecdsa-sha2-nistp256 ", workflow)
        self.assertIn("github.com ssh-rsa ", workflow)
        self.assertNotIn("CERTIGO_CONTENT_APP_ID", workflow)
        self.assertNotIn("CERTIGO_CONTENT_APP_PRIVATE_KEY", workflow)
        self.assertNotIn("CERTIGO_CONTENT_READ_TOKEN", workflow)
        self.assertNotIn("create-github-app-token", workflow)
        self.assertNotIn("token: ${{", workflow)
        self.assertIn("npm ci", workflow)
        self.assertIn("npm run package", workflow)
        self.assertIn("--validate-active-content .active-content", workflow)

        protection = json.loads(
            (REPO_ROOT / ".github/branch-protection-main.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(
            [
                "Build & test",
                "Flutter app + UI packages",
                "Generated state equals committed state",
                "Validate workflow YAML",
                "CodeQL / Security gate",
                "Security / Required gate",
                "Fork PR policy / Required gate",
            ],
            protection["required_status_checks"]["contexts"],
        )

    def test_codeql_covers_github_security_scripts(self) -> None:
        workflow = (REPO_ROOT / ".github/workflows/codeql.yml").read_text(
            encoding="utf-8"
        )
        self.assertIn("- '.github/scripts/**/*.js'", workflow)
        self.assertIn("- '.github/scripts/**/*.mjs'", workflow)


if __name__ == "__main__":
    unittest.main()
