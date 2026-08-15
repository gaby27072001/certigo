from __future__ import annotations

import base64
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "validate_nuget_locks.py"
SPEC = importlib.util.spec_from_file_location("validate_nuget_locks", MODULE_PATH)
assert SPEC and SPEC.loader
validate_nuget_locks = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = validate_nuget_locks
SPEC.loader.exec_module(validate_nuget_locks)


class NuGetLockValidatorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        subprocess.run(["git", "init", "-q"], cwd=self.root, check=True)

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def write(self, relative: str, content: str) -> None:
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    def add(self, *paths: str) -> None:
        subprocess.run(["git", "add", "--", *paths], cwd=self.root, check=True)

    @staticmethod
    def project(version: str = "1.2.3", condition: str = "") -> str:
        condition_attribute = f' Condition="{condition}"' if condition else ""
        return (
            '<Project Sdk="Microsoft.NET.Sdk">\n'
            "  <ItemGroup>\n"
            f'    <PackageReference Include="Example.Package" Version="{version}"'
            f"{condition_attribute} />\n"
            "  </ItemGroup>\n"
            "</Project>\n"
        )

    @staticmethod
    def lock(
        *,
        requested: str = "[1.2.3, )",
        resolved: str = "1.2.3",
        transitive_dependency: str = "Example.Dependency",
    ) -> str:
        value = {
            "version": 1,
            "dependencies": {
                "net8.0": {
                    "Example.Package": {
                        "type": "Direct",
                        "requested": requested,
                        "resolved": resolved,
                        "contentHash": base64.b64encode(b"a" * 64).decode(),
                        "dependencies": {transitive_dependency: "4.5.6"},
                    },
                    "Example.Dependency": {
                        "type": "Transitive",
                        "resolved": "4.5.6",
                        "contentHash": base64.b64encode(b"b" * 64).decode(),
                    },
                }
            },
        }
        return json.dumps(value, indent=2) + "\n"

    def valid_fixture(self) -> None:
        self.write("backend/App/App.csproj", self.project())
        self.write("backend/App/packages.lock.json", self.lock())
        self.add("backend/App/App.csproj", "backend/App/packages.lock.json")

    def test_accepts_one_valid_lock_per_tracked_project(self) -> None:
        self.valid_fixture()

        self.assertEqual(
            (1, 1, 2),
            validate_nuget_locks.validate_repository(self.root),
        )

    def test_rejects_missing_and_orphaned_locks(self) -> None:
        self.write("backend/App/App.csproj", self.project())
        self.add("backend/App/App.csproj")
        with self.assertRaisesRegex(
            validate_nuget_locks.NuGetLockError, "missing=.*packages.lock.json"
        ):
            validate_nuget_locks.validate_repository(self.root)

        self.write("backend/Orphan/packages.lock.json", self.lock())
        self.add("backend/Orphan/packages.lock.json")
        with self.assertRaisesRegex(
            validate_nuget_locks.NuGetLockError, "orphaned=.*packages.lock.json"
        ):
            validate_nuget_locks.validate_repository(self.root)

    def test_rejects_stale_direct_package_versions(self) -> None:
        self.write("backend/App/App.csproj", self.project("2.0.0"))
        self.write("backend/App/packages.lock.json", self.lock())
        self.add("backend/App/App.csproj", "backend/App/packages.lock.json")

        with self.assertRaisesRegex(
            validate_nuget_locks.NuGetLockError, "expected requested"
        ):
            validate_nuget_locks.validate_repository(self.root)

    def test_rejects_missing_transitive_graph_targets(self) -> None:
        self.write("backend/App/App.csproj", self.project())
        self.write(
            "backend/App/packages.lock.json",
            self.lock(transitive_dependency="Missing.Dependency"),
        )
        self.add("backend/App/App.csproj", "backend/App/packages.lock.json")

        with self.assertRaisesRegex(
            validate_nuget_locks.NuGetLockError, "absent from the target graph"
        ):
            validate_nuget_locks.validate_repository(self.root)

    def test_rejects_invalid_hash_lengths_and_unreachable_entries(self) -> None:
        self.valid_fixture()
        lock_path = self.root / "backend/App/packages.lock.json"
        value = json.loads(lock_path.read_text(encoding="utf-8"))
        value["dependencies"]["net8.0"]["Example.Package"]["contentHash"] = "YWJj"
        lock_path.write_text(json.dumps(value), encoding="utf-8")
        with self.assertRaisesRegex(
            validate_nuget_locks.NuGetLockError, "64-byte SHA-512"
        ):
            validate_nuget_locks.validate_repository(self.root)

        value["dependencies"]["net8.0"]["Example.Package"][
            "contentHash"
        ] = base64.b64encode(b"a" * 64).decode()
        value["dependencies"]["net8.0"]["Orphan.Package"] = {
            "type": "Transitive",
            "resolved": "9.9.9",
            "contentHash": base64.b64encode(b"c" * 64).decode(),
        }
        lock_path.write_text(json.dumps(value), encoding="utf-8")
        with self.assertRaisesRegex(
            validate_nuget_locks.NuGetLockError, "unreachable from Direct/Project"
        ):
            validate_nuget_locks.validate_repository(self.root)

    def test_rejects_duplicate_json_keys_and_wrong_schema(self) -> None:
        self.write("backend/App/App.csproj", self.project())
        self.write(
            "backend/App/packages.lock.json",
            '{"version":1,"version":1,"dependencies":{"net8.0":{}}}',
        )
        self.add("backend/App/App.csproj", "backend/App/packages.lock.json")
        with self.assertRaisesRegex(
            validate_nuget_locks.NuGetLockError, "Duplicate JSON key"
        ):
            validate_nuget_locks.validate_repository(self.root)

        self.write(
            "backend/App/packages.lock.json",
            '{"version":2,"dependencies":{"net8.0":{}}}',
        )
        with self.assertRaisesRegex(
            validate_nuget_locks.NuGetLockError, "schema version 1"
        ):
            validate_nuget_locks.validate_repository(self.root)

    def test_rejects_conditional_or_non_literal_package_references(self) -> None:
        self.write(
            "backend/App/App.csproj",
            self.project(condition="'$(Configuration)' == 'Release'"),
        )
        self.write("backend/App/packages.lock.json", self.lock())
        self.add("backend/App/App.csproj", "backend/App/packages.lock.json")
        with self.assertRaisesRegex(
            validate_nuget_locks.NuGetLockError,
            "conditional PackageReference elements are unsupported",
        ):
            validate_nuget_locks.validate_repository(self.root)

        self.write("backend/App/App.csproj", self.project("$(PackageVersion)"))
        with self.assertRaisesRegex(
            validate_nuget_locks.NuGetLockError, "literal exact Version"
        ):
            validate_nuget_locks.validate_repository(self.root)

    def test_rejects_imports_custom_sdks_and_central_configuration(self) -> None:
        self.valid_fixture()
        self.write(
            "backend/App/App.csproj",
            '<Project Sdk="Custom.Sdk/1.0.0"><Import Project="deps.props" /></Project>',
        )
        with self.assertRaisesRegex(
            validate_nuget_locks.NuGetLockError,
            "Project Sdk must be exactly Microsoft.NET.Sdk",
        ):
            validate_nuget_locks.validate_repository(self.root)

        self.write(
            "backend/App/App.csproj",
            '<Project Sdk="Microsoft.NET.Sdk"><Import Project="deps.props" /></Project>',
        )
        with self.assertRaisesRegex(
            validate_nuget_locks.NuGetLockError, "Import elements are unsupported"
        ):
            validate_nuget_locks.validate_repository(self.root)

        self.write("backend/App/App.csproj", self.project())
        self.write(
            "Directory.Packages.props",
            "<Project><ItemGroup /></Project>",
        )
        self.add("Directory.Packages.props")
        with self.assertRaisesRegex(
            validate_nuget_locks.NuGetLockError,
            "Central/imported MSBuild dependency configuration is unsupported",
        ):
            validate_nuget_locks.validate_repository(self.root)


if __name__ == "__main__":
    unittest.main()
