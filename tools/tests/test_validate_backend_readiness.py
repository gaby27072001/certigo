from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


MODULE_PATH = Path(__file__).resolve().parents[1] / "validate_backend_readiness.py"
SPEC = importlib.util.spec_from_file_location("validate_backend_readiness", MODULE_PATH)
assert SPEC and SPEC.loader
validator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(validator)


class BackendReadinessTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.api = "backend/src/Certigo.Api/"
        self.project = (
            '<Project Sdk="Azure.Functions.Sdk/1.0.0">'
            "<PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup>"
            '<ItemGroup><PackageReference Include="Microsoft.Azure.Functions.Worker" '
            'Version="2.52.0" /></ItemGroup></Project>'
        )
        self.write(self.api + "Certigo.Api.csproj", self.project)
        self.write("infra/modules/functionApp.bicep",
                   "runtime: {\n name: 'dotnet-isolated'\n version: '10.0'\n}")
        self.write(self.api + "host.json", '{"version":"2.0"}')
        self.write(self.api + "local.settings.json.example",
                   '{"Values":{"FUNCTIONS_WORKER_RUNTIME":"dotnet-isolated"}}')
        self.publish = self.root / "publish"
        self.write("publish/Certigo.Api.dll", "fixture-only-not-an-assembly")
        self.write("publish/host.json", '{"version":"2.0"}')
        self.write("publish/Certigo.Api.deps.json", "{}")
        self.runtime = {
            "runtimeOptions": {
                "tfm": "net10.0",
                "frameworks": [
                    {"name": "Microsoft.NETCore.App", "version": "10.0.0"},
                    {"name": "Microsoft.AspNetCore.App", "version": "10.0.0"},
                ],
            },
        }
        self.write("publish/Certigo.Api.runtimeconfig.json", json.dumps(self.runtime))
        self.worker = {"description": {
            "language": "dotnet-isolated", "defaultExecutablePath": "dotnet",
            "defaultWorkerPath": "Certigo.Api.dll", "workerIndexing": "true",
        }}
        self.write("publish/worker.config.json", json.dumps(self.worker))

    def tearDown(self) -> None:
        self.temp.cleanup()

    def write(self, relative: str, value: str) -> None:
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value, encoding="utf-8")

    def test_accepts_source_and_worker_indexed_publish_without_static_metadata(self) -> None:
        self.assertEqual(validator.validate_source(self.root), 1)
        validator.validate_sdk("10.0.401\n")
        validator.validate_publish(self.publish)

    def test_rejects_sdk8_preview_or_malformed_versions(self) -> None:
        for value in ("8.0.426", "10.0.401-preview.1", "", "10.0"):
            with self.subTest(value=value), self.assertRaises(validator.ReadinessError):
                validator.validate_sdk(value)

    def test_rejects_project_drift_and_conditional_or_multiple_targets(self) -> None:
        for old, new in (
            ("net10.0", "net8.0"),
            ("<PropertyGroup>", '<PropertyGroup Condition="true">'),
            ("</PropertyGroup>", "<TargetFramework>net10.0</TargetFramework></PropertyGroup>"),
            ("</PropertyGroup>", "<TargetFrameworks>net10.0;net8.0</TargetFrameworks></PropertyGroup>"),
            ("Azure.Functions.Sdk/1.0.0", "Microsoft.NET.Sdk"),
            ('Version="2.52.0"', 'Version="1.0.0"'),
        ):
            self.write(self.api + "Certigo.Api.csproj", self.project.replace(old, new))
            with self.subTest(change=new), self.assertRaises(validator.ReadinessError):
                validator.validate_source(self.root)

    def test_checks_non_api_projects_too(self) -> None:
        self.write("backend/tests/Example.Tests/Example.Tests.csproj",
                   "<Project><PropertyGroup><TargetFramework>net8.0</TargetFramework>"
                   "</PropertyGroup></Project>")
        with self.assertRaises(validator.ReadinessError):
            validator.validate_source(self.root)

    def test_fails_when_api_is_missing(self) -> None:
        (self.root / self.api / "Certigo.Api.csproj").unlink()
        with self.assertRaises(validator.ReadinessError):
            validator.validate_source(self.root)

    def test_rejects_runtime_drift_even_if_comment_claims_net10(self) -> None:
        self.write("infra/modules/functionApp.bicep",
                   "// runtime: {name: 'dotnet-isolated' version: '10.0'}\n"
                   "runtime: {name: 'dotnet-isolated' version: '8.0'}")
        with self.assertRaises(validator.ReadinessError):
            validator.validate_source(self.root)

    def test_rejects_host_and_worker_source_drift(self) -> None:
        self.write(self.api + "host.json", '{"version":"4.0"}')
        with self.assertRaises(validator.ReadinessError):
            validator.validate_source(self.root)
        self.write(self.api + "host.json", '{"version":"2.0"}')
        self.write(self.api + "local.settings.json.example", '{"Values":{}}')
        with self.assertRaises(validator.ReadinessError):
            validator.validate_source(self.root)

    def test_rejects_missing_empty_or_malformed_artifacts(self) -> None:
        path = self.publish / "Certigo.Api.dll"
        path.unlink()
        with self.assertRaises(validator.ReadinessError):
            validator.validate_publish(self.publish)
        path.write_bytes(b"")
        with self.assertRaises(validator.ReadinessError):
            validator.validate_publish(self.publish)
        path.write_bytes(b"fixture")
        self.write("publish/host.json", "[1]")
        with self.assertRaises(validator.ReadinessError):
            validator.validate_publish(self.publish)

    def test_rejects_local_settings_in_publish(self) -> None:
        self.write("publish/local.settings.json", "{}")
        with self.assertRaises(validator.ReadinessError):
            validator.validate_publish(self.publish)

    def test_rejects_wrong_published_runtime_and_frameworks(self) -> None:
        for options in (
            {"tfm": "net8.0"},
            {"tfm": "net10.0", "frameworks": []},
            {"tfm": "net10.0", "frameworks": [None, None]},
            {"tfm": "net10.0", "frameworks": [
                {"name": [], "version": "10.0.0"}, {"name": "x", "version": {}},
            ]},
            {"tfm": "net10.0", "frameworks": [
                {"name": "Microsoft.NETCore.App", "version": "8.0.0"},
                {"name": "Microsoft.AspNetCore.App", "version": "8.0.0"},
            ]},
        ):
            self.write("publish/Certigo.Api.runtimeconfig.json",
                       json.dumps({"runtimeOptions": options}))
            with self.subTest(options=options), self.assertRaises(validator.ReadinessError):
                validator.validate_publish(self.publish)

    def test_rejects_published_worker_drift(self) -> None:
        for key in self.worker["description"]:
            value = {"description": {**self.worker["description"], key: "wrong"}}
            self.write("publish/worker.config.json", json.dumps(value))
            with self.subTest(key=key), self.assertRaises(validator.ReadinessError):
                validator.validate_publish(self.publish)

    def test_rejects_symlinked_artifact(self) -> None:
        path = self.publish / "Certigo.Api.dll"
        with patch.object(Path, "is_symlink", side_effect=lambda: True):
            with self.assertRaises(validator.ReadinessError):
                validator.validate_publish(self.publish)
        self.assertTrue(path.exists())

    def test_cli_does_not_install_or_deploy_and_reports_unchecked_publish(self) -> None:
        with patch.object(sys, "argv", ["validator", "--root", str(self.root)]), \
                patch.object(validator.subprocess, "run") as run, \
                patch("builtins.print") as output:
            run.return_value = subprocess.CompletedProcess(["dotnet", "--version"], 0, "10.0.401\n")
            self.assertEqual(validator.main(), 0)
            self.assertEqual(run.call_args.args[0], ["dotnet", "--version"])
            self.assertEqual(run.call_count, 1)
            self.assertIn("publish=NOT CHECKED", output.call_args.args[0])

    def test_cli_fails_closed_for_missing_or_failed_sdk(self) -> None:
        for error in (FileNotFoundError("missing"), subprocess.CalledProcessError(1, "dotnet")):
            with self.subTest(error=error), \
                    patch.object(sys, "argv", ["validator", "--root", str(self.root)]), \
                    patch.object(validator.subprocess, "run", side_effect=error), \
                    patch("builtins.print"):
                self.assertEqual(validator.main(), 1)


if __name__ == "__main__":
    unittest.main()
