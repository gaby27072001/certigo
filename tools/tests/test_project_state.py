from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import re
import shlex
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "project_state.py"
REPO_ROOT = Path(os.environ.get("CERTIGO_WORKSPACE", MODULE_PATH.parents[1])).resolve()
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
        for relative in (
            project_state.CONTENT_PACKAGE_CONTRACT_FILE,
            Path("contracts/cosmos-containers.json"),
        ):
            self.write(
                relative.as_posix(),
                (REPO_ROOT / relative).read_text(encoding="utf-8"),
            )
        subprocess.run(
            [
                sys.executable,
                str(MODULE_PATH.with_name("generated_contracts.py")),
                "--root",
                str(self.root),
                "--refresh",
            ],
            check=True,
            capture_output=True,
            text=True,
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

    def test_uncontrolled_domain_references_are_rejected(self) -> None:
        domain = "certigo" + ".app"
        self.fixture.write(
            "docs/unsafe-domain.md",
            f"https://api.{domain}/api\nsupport@{domain}\n",
        )

        with self.assertRaisesRegex(
            project_state.ProjectStateError,
            r"unsafe-domain\.md:1.*unsafe-domain\.md:2",
        ):
            project_state.validate_forbidden_domain_references(self.root)

    def test_namespaces_and_historical_protocol_ids_are_not_domains(self) -> None:
        self.fixture.write(
            "docs/safe-identifiers.md",
            "Certigo.Application\ncertigo.app-certification-catalog/v2\n",
        )

        project_state.validate_forbidden_domain_references(self.root)

    def test_explicit_third_party_audit_mention_is_the_only_allowlist(self) -> None:
        domain = "certigo" + ".app"
        self.fixture.write(
            project_state.ALLOWED_DOMAIN_AUDIT_PATH.as_posix(),
            f"Le domaine {domain} est tiers et non controle. Il est explicitement interdit.\n",
        )
        project_state.validate_forbidden_domain_references(self.root)

        self.fixture.write(
            "docs/other.md",
            f"Le domaine {domain} est tiers et explicitement interdit.\n",
        )
        with self.assertRaisesRegex(
            project_state.ProjectStateError,
            r"docs/other\.md:1",
        ):
            project_state.validate_forbidden_domain_references(self.root)

    def test_observable_hash_normalizes_declared_lf_text(self) -> None:
        source = self.root / ".github/workflows/ci-mobile.yml"
        original = source.read_bytes().replace(b"\r\n", b"\n")
        source.write_bytes(original)
        expected = project_state.observable_sha256(self.root)

        source.write_bytes(original.replace(b"\n", b"\r\n"))
        self.assertEqual(expected, project_state.observable_sha256(self.root))

        source.write_bytes(original + b"# semantic change\n")
        self.assertNotEqual(expected, project_state.observable_sha256(self.root))

    def test_observable_hash_does_not_normalize_auto_detected_binary(self) -> None:
        source = self.root / "content/binary.dat"
        source.write_bytes(b"\0binary\r\npayload")
        crlf_hash = project_state.observable_sha256(self.root)

        source.write_bytes(b"\0binary\npayload")
        self.assertNotEqual(crlf_hash, project_state.observable_sha256(self.root))

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

    def test_project_state_check_rejects_stale_generated_contracts(self) -> None:
        self.assertTrue(project_state.update(self.root, check=False))
        generated = self.root / "backend/src/Certigo.Infrastructure/Cosmos/CosmosContainers.cs"
        generated.write_text(
            generated.read_text(encoding="utf-8") + "// stale\n",
            encoding="utf-8",
        )
        with self.assertRaisesRegex(project_state.ProjectStateError, "generated contracts are stale"):
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
        reference = json.loads(
            (REPO_ROOT / project_state.ACTIVE_CONTENT_REFERENCE_FILE).read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(reference["revision"], active.revision)
        self.assertEqual(reference["date"], active.date)
        self.assertEqual(reference["committedAt"], active.committed_at)
        for name, manifest in (("public", active.public), ("private", active.private)):
            expected = reference["manifests"][name]
            self.assertEqual(expected["manifestId"], manifest.manifest_id)
            self.assertEqual(expected["fileCount"], manifest.file_count)
            self.assertEqual(expected["fileSha256"], manifest.file_sha256)

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

    def test_manifest_reference_rejects_paths_outside_active_content(self) -> None:
        reference_path = self.root / project_state.ACTIVE_CONTENT_REFERENCE_FILE
        reference = json.loads(reference_path.read_text(encoding="utf-8"))
        reference["manifests"]["public"]["path"] = "../manifest.json"
        reference_path.write_text(json.dumps(reference), encoding="utf-8")
        with self.assertRaisesRegex(
            project_state.ProjectStateError, "expected a manifest.json path"
        ):
            project_state.load_active_content_reference(self.root)

    def test_cli_uses_explicit_repository_root(self) -> None:
        project_state.update(self.root, check=False)
        self.assertEqual(
            0,
            project_state.main(["--root", str(self.root), "--check"]),
        )

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
        self.assertNotIn("environment:", workflow)
        self.assertIn("runs-on: [self-hosted, Linux, X64, certigo-pr]", workflow)
        self.assertIn(
            "runs-on: [self-hosted, Linux, X64, certigo-trusted]",
            workflow,
        )
        self.assertIn(
            "ref: ${{ github.event_name == 'pull_request_target' && "
            "github.event.pull_request.head.sha || github.sha }}",
            workflow,
        )
        self.assertIn(
            "ref: ${{ github.event_name == 'pull_request_target' && "
            "github.event.pull_request.base.sha || github.sha }}",
            workflow,
        )
        self.assertIn("path: .untrusted-source", workflow)
        self.assertIn("path: .trusted-control", workflow)
        self.assertIn("validate-source:", workflow)
        self.assertIn("needs: validate-source", workflow)
        self.assertIn("uses: ./.github/workflows/pr-head-freshness.yml", workflow)
        self.assertIn("needs.freshness.outputs.current != 'false'", workflow)
        source_job = workflow[
            workflow.index("  validate-source:") : workflow.index(
                "  validate:\n", workflow.index("  validate-source:")
            )
        ]
        self.assertNotIn("secrets.", source_job)
        self.assertNotIn("-latest", workflow)
        self.assertIn("persist-credentials: false", workflow)
        self.assertIn(
            "name: Validate committed active-content reference and generated state",
            workflow,
        )
        self.assertNotIn("secrets.", workflow)
        self.assertNotIn("repository:", workflow)
        self.assertNotIn("ssh-key:", workflow)
        self.assertNotIn("ssh-known-hosts:", workflow)
        self.assertNotIn("CERTIGO_CONTENT_", workflow)
        self.assertNotIn("create-github-app-token", workflow)
        self.assertNotIn("token: ${{", workflow)
        self.assertNotIn("actions/setup-node@", workflow)
        self.assertNotIn("npm ci", workflow)
        self.assertNotIn("npm run", workflow)
        self.assertIn(
            'python -P tools/project_state.py --root "$PROJECT_WORKSPACE" --check',
            workflow,
        )
        gate_job = workflow[
            workflow.index("  validate:\n", workflow.index("  validate-source:"))
        :]
        self.assertNotIn("actions/checkout@", gate_job)

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
        self.assertNotIn("actions/upload-artifact@", workflow)
        self.assertIn("upload: always", workflow)
        self.assertIn("source-root: .untrusted-source", workflow)
        self.assertIn(
            "config-file: ./.trusted-control/.github/codeql/codeql-config.yml",
            workflow,
        )
        self.assertIn(
            'node "$TRUSTED_CONTROL_DIR/.github/scripts/enforce-codeql-sarif.mjs"',
            workflow,
        )
        self.assertNotIn(
            "run: node .github/scripts/enforce-codeql-sarif.mjs",
            workflow,
        )
        enforcer = (
            REPO_ROOT / ".github/scripts/enforce-codeql-sarif.mjs"
        ).read_text(encoding="utf-8")
        self.assertIn("GITHUB_STEP_SUMMARY", enforcer)

    def test_trusted_control_references_are_revision_local_and_sealed(self) -> None:
        preflight = (REPO_ROOT / ".github/workflows/ci-preflight.yml").read_text(
            encoding="utf-8"
        )
        install_start = preflight.index(
            "      - name: Install trusted validator dependencies"
        )
        step_start = preflight.index(
            "      - name: Run adversarial selector and security-policy tests"
        )
        step_end = preflight.index(
            "      - name: Validate project-state source", step_start
        )
        install_step = preflight[install_start:step_start]
        self.assertIn("working-directory: .trusted-control", install_step)
        self.assertIn("run: npm ci --ignore-scripts", install_step)
        self.assertNotIn("UNTRUSTED_SOURCE_DIR", install_step)
        self.assertNotIn("--prefix", install_step)
        policy_step = preflight[step_start:step_end]
        self.assertIn("working-directory: .trusted-control", policy_step)
        self.assertIn("npm --ignore-scripts run test:ci-impact", policy_step)
        self.assertNotIn("node --test", policy_step)
        self.assertNotRegex(
            policy_step,
            r"\$(?:\{TRUSTED_CONTROL_DIR\}|TRUSTED_CONTROL_DIR)"
            r"/[A-Za-z0-9._/-]+\.test\.mjs",
        )

        package = json.loads((REPO_ROOT / "package.json").read_text(encoding="utf-8"))
        self.assertNotIn("pretest:ci-impact", package["scripts"])
        self.assertNotIn("posttest:ci-impact", package["scripts"])
        manifest = shlex.split(package["scripts"]["test:ci-impact"])
        self.assertEqual(["node", "--test"], manifest[:2])
        test_paths = manifest[2:]
        self.assertTrue(
            {
                ".github/scripts/ci-impact.test.mjs",
                ".github/scripts/workflow-concurrency-policy.test.mjs",
                ".github/scripts/workflow-runner-routing-policy.test.mjs",
                ".github/scripts/workflow-security-cache-policy.test.mjs",
            }.issubset(test_paths)
        )
        for test_path in test_paths:
            self.assertRegex(
                test_path,
                r"^\.github/scripts/[A-Za-z0-9._-]+\.test\.mjs$",
            )

        references = set(test_paths)
        for workflow_path in (REPO_ROOT / ".github/workflows").glob("*.y*ml"):
            references.update(
                re.findall(
                    r"\$(?:\{TRUSTED_CONTROL_DIR\}|TRUSTED_CONTROL_DIR)"
                    r"/([A-Za-z0-9._/-]+)",
                    workflow_path.read_text(encoding="utf-8"),
                )
            )

        canonical_root = REPO_ROOT.resolve(strict=True)
        for relative in sorted(references):
            with self.subTest(relative=relative):
                relative_path = Path(relative)
                self.assertFalse(relative_path.is_absolute())
                self.assertNotIn("..", relative_path.parts)
                control_file = REPO_ROOT / relative_path
                self.assertFalse(control_file.is_symlink())
                self.assertTrue(control_file.is_file())
                self.assertTrue(
                    control_file.resolve(strict=True).is_relative_to(canonical_root)
                )
                tracked = subprocess.run(
                    ["git", "ls-files", "--error-unmatch", "--", relative],
                    cwd=REPO_ROOT,
                    check=False,
                    capture_output=True,
                    text=True,
                )
                self.assertEqual(0, tracked.returncode, tracked.stderr)

    def test_trusted_workflows_use_default_branch_dispatch_only(self) -> None:
        workflows = REPO_ROOT / ".github/workflows"
        dispatch_types = {
            "deploy-privacy-policy.yml": "deploy-privacy-policy",
            "promote-backend-staging-prod.yml": "promote-backend-staging-prod",
            "release-android.yml": "release-android",
            "release-ios.yml": "release-ios-legacy",
            "runner-health.yml": "runner-health",
            "runner-resilience-drill.yml": "runner-resilience-drill",
            "sync-ios-certs.yml": "sync-ios-certs-legacy",
        }

        trusted_workflows = []
        persistent_runner_workflows = []
        for workflow_path in workflows.glob("*.yml"):
            workflow = workflow_path.read_text(encoding="utf-8")
            if "certigo-trusted" in workflow or "certigo-pr" in workflow:
                persistent_runner_workflows.append(workflow_path.name)
                self.assertNotRegex(
                    workflow,
                    r"(?m)^\s+(?:cache|pub-cache):[ \t]*(?!false[ \t]*$)\S.*$",
                    f"{workflow_path.name} must not enable or dynamically select caches",
                )
                self.assertNotRegex(
                    workflow,
                    r"(?i)uses:\s*actions/cache(?:/[^@\s]+)?@",
                    f"{workflow_path.name} must not invoke GitHub cache actions",
                )
            if "certigo-trusted" not in workflow:
                continue
            trusted_workflows.append(workflow_path.name)
            self.assertNotIn(
                "\n  workflow_dispatch:",
                workflow,
                f"{workflow_path.name} must load privileged runs from main",
            )
            self.assertNotRegex(
                workflow,
                r"(?m)^ {4}tags(?:-ignore)?:",
                f"{workflow_path.name} must not run privileged jobs from tags",
            )
            self.assertNotIn("subosito/flutter-action@", workflow)
            if "\n  push:" in workflow:
                self.assertIn(
                    "\n    branches:",
                    workflow,
                    f"{workflow_path.name} push must be branch restricted",
                )

        self.assertGreater(len(trusted_workflows), 0)
        self.assertGreater(len(persistent_runner_workflows), len(trusted_workflows))
        for workflow_name, event_type in dispatch_types.items():
            workflow = (workflows / workflow_name).read_text(encoding="utf-8")
            self.assertIn(
                f"repository_dispatch:\n    types: [{event_type}]",
                workflow,
            )
            self.assertIn("CLIENT_PAYLOAD_JSON:", workflow)
            self.assertIn("github.event.client_payload", workflow)

        for workflow_name in [
            "ci-project-state.yml",
            "codeql.yml",
            "security-gate.yml",
        ]:
            workflow = (workflows / workflow_name).read_text(encoding="utf-8")
            self.assertNotIn("repository_dispatch:", workflow)
            self.assertNotIn("workflow_dispatch:", workflow)

        android = (workflows / "release-android.yml").read_text(encoding="utf-8")
        self.assertNotIn("github.ref_type", android)
        self.assertNotIn("github.ref_name", android)
        self.assertNotIn("refs/tags/", android)
        self.assertIn('has("dry_run")', android)
        self.assertIn('has("track")', android)
        self.assertIn("install-verified-flutter.sh", android)
        self.assertNotIn("subosito/flutter-action@", android)
        ios = (workflows / "release-ios.yml").read_text(encoding="utf-8")
        self.assertIn("install-verified-flutter.sh", ios)
        self.assertNotIn("subosito/flutter-action@", ios)
        mobile = (workflows / "ci-mobile.yml").read_text(encoding="utf-8")
        self.assertEqual(mobile.count("uses: subosito/flutter-action@"), 2)
        self.assertEqual(mobile.count("cache: false"), 2)

        installer = (
            REPO_ROOT / ".github/scripts/install-verified-flutter.sh"
        ).read_text(encoding="utf-8")
        for digest in [
            "c853cda0312a162854c481fe6a1bc286d84fbb74bfab7037c39750061dc9b466",
            "32bca4386121042e827ff2d90edbd7c7fb47c514fc04d5a87db6e3202dafde5d",
            "eac833fe956c670d1f27946f25de8bc4fe4fb86146d5ef8d53e79a971a3ba042",
        ]:
            self.assertIn(digest, installer)
        self.assertIn("sha256sum --check --strict", installer)
        self.assertIn("shasum -a 256", installer)
        self.assertNotIn("releases_linux.json", installer)
        self.assertNotIn("releases_macos.json", installer)

    def test_security_scanners_are_independent_from_artifact_storage(self) -> None:
        expected_markers = {
            "dependency-vuln-scan.yml": [
                "OSV-Scanner output is missing or malformed.",
                'node "$TRUSTED_CONTROL_DIR/.github/scripts/run-osv-scan.mjs"',
                'python -P "$TRUSTED_CONTROL_DIR/tools/validate_dependency_locks.py"',
                '--root "$UNTRUSTED_SOURCE_DIR"',
                '--write-expected-sources "$EXPECTED_LOCKS_FILE"',
                "path: .untrusted-pub-restore",
                "name: Reset isolated dependency state",
                "name: Install digest-verified Flutter without shared caches",
                'bash "$TRUSTED_CONTROL_DIR/.github/scripts/install-verified-flutter.sh"',
                'python -P "$TRUSTED_CONTROL_DIR/tools/verify_pub_locks.py"',
                '--root "$UNTRUSTED_PUB_DIR"',
                '--contract "$EXPECTED_LOCKS_FILE"',
                '--pub-cache "$PUB_CACHE"',
                'FLUTTER_EXECUTABLE="$FLUTTER_INSTALL_DIR/flutter/bin/flutter"',
                "name: Verify trusted controls remain immutable",
                'node "$TRUSTED_CONTROL_DIR/.github/scripts/enforce-osv-json.mjs"',
                '"$EXPECTED_LOCKS_FILE"',
                '"$UNTRUSTED_SOURCE_DIR" 2> "$OSV_ENFORCE_LOG"',
                "name: NuGet locked restore (no secrets)",
                '"$DOTNET_EXECUTABLE" restore "$RESTORE_SOLUTION" --locked-mode',
                "finding_count",
            ],
            "security-scan.yml": [
                "Checkov output is missing or malformed.",
                "Passed checks: [0-9]+, Failed checks: [0-9]+",
                '--directory "$UNTRUSTED_SOURCE_DIR/infra"',
                '--config-file "$TRUSTED_CONTROL_DIR/.checkov.yaml"',
                "failed_checks",
            ],
        }
        for file_name, markers in expected_markers.items():
            with self.subTest(file_name=file_name):
                workflow = (
                    REPO_ROOT / ".github/workflows" / file_name
                ).read_text(encoding="utf-8")
                self.assertNotIn("actions/upload-artifact@", workflow)
                self.assertNotIn("continue-on-error: true", workflow)
                self.assertIn("$GITHUB_STEP_SUMMARY", workflow)
                self.assertNotIn("environment:", workflow)
                self.assertIn(
                    "runs-on: [self-hosted, Linux, X64, certigo-pr]",
                    workflow,
                )
                self.assertIn(
                    "ref: ${{ github.event_name == 'pull_request_target' && "
                    "github.event.pull_request.base.sha || github.sha }}",
                    workflow,
                )
                self.assertIn("path: .untrusted-source", workflow)
                self.assertIn("path: .trusted-control", workflow)
                for marker in markers:
                    self.assertIn(marker, workflow)
        security_gate = (
            REPO_ROOT / ".github/workflows/security-gate.yml"
        ).read_text(encoding="utf-8")
        self.assertIn("needs: [changes, osv, checkov]", security_gate)
        self.assertIn(
            "uses: ./.github/workflows/pr-head-freshness.yml", security_gate
        )
        self.assertIn(
            "needs.changes.result == 'success'",
            security_gate,
        )
        self.assertIn("- '.gitignore'", security_gate)
        self.assertIn("- '**/.gitignore'", security_gate)
        self.assertIn("- 'tools/validate_nuget_locks.py'", security_gate)
        self.assertIn("- 'tools/validate_dependency_locks.py'", security_gate)
        self.assertIn("- 'tools/verify_pub_locks.py'", security_gate)
        self.assertIn(
            "- 'tools/tests/test_validate_nuget_locks.py'", security_gate
        )
        self.assertIn(
            "- 'tools/tests/test_validate_dependency_locks.py'", security_gate
        )
        self.assertIn("- 'tools/tests/test_verify_pub_locks.py'", security_gate)
        self.assertNotIn("nuget-vuln-scan", security_gate)
        self.assertNotIn("NUGET_RESULT", security_gate)
        self.assertFalse(
            (REPO_ROOT / ".github/workflows/nuget-vuln-scan.yml").exists()
        )
        self.assertFalse((REPO_ROOT / ".github/nuget-scanner.config").exists())


if __name__ == "__main__":
    unittest.main()
