"""Run with Checkov 3.2.495 and the built compatibility wheel, without network access."""

import json
from importlib.metadata import version
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile

import checkov.arm
from checkov.bicep.runner import Runner
from checkov.runner_filter import RunnerFilter
from pycep import BicepParser

from build_parser_wheel import PATCHED_FILES, UPSTREAM_SHA256, VERSION, checked_bytes


REPOSITORY = Path(__file__).resolve().parents[2]
PARSER = BicepParser(add_line_numbers=True)


def expressions(tree, kind):
    found = []
    if isinstance(tree, dict):
        if tree.get("type") == kind and "parameters" in tree:
            found.append(tree)
        for value in tree.values():
            found.extend(expressions(value, kind))
    elif isinstance(tree, list):
        for value in tree:
            found.extend(expressions(value, kind))
    return found


class CompatibilityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if version("checkov") != "3.2.495" or version("pycep-parser") != VERSION:
            raise ValueError("Tests require Checkov 3.2.495 and the pinned compatibility wheel")
        import pycep

        package_root = Path(pycep.__file__).parent.parent
        for relative, expected in PATCHED_FILES.items():
            checked_bytes(package_root / relative, expected)
        cls.upstream = Path(os.environ["CHECKOV_UPSTREAM_WHEEL"])
        checked_bytes(cls.upstream, UPSTREAM_SHA256)

    def test_every_current_bicep_source_parses(self):
        sources = sorted((REPOSITORY / "infra").rglob("*.bicep"))
        self.assertGreater(len(sources), 0)
        for path in sources:
            with self.subTest(path=str(path.relative_to(REPOSITORY))):
                PARSER.parse(file_path=path)

    def test_original_accepted_ast_is_identical(self):
        script = (
            "import json; from pathlib import Path; from pycep import BicepParser; "
            "p=BicepParser(add_line_numbers=True); rows={}; "
            "root=Path(__import__('sys').argv[1]); "
            "exec(\"for f in sorted(root.rglob('*.bicep')):\\n"
            " try: rows[str(f.relative_to(root))]=p.parse(file_path=f)\\n"
            " except Exception: pass\"); print(json.dumps(rows))"
        )
        with tempfile.TemporaryDirectory() as temporary:
            with zipfile.ZipFile(self.upstream) as archive:
                archive.extractall(temporary)
            environment = dict(os.environ, PYTHONPATH=temporary)
            root = REPOSITORY / "infra"
            run = subprocess.run(
                [sys.executable, "-c", script, str(root)], capture_output=True,
                text=True, env=environment, cwd=temporary, check=True,
            )
        baseline = json.loads(run.stdout)
        self.assertGreater(len(baseline), 0)
        for relative, expected in baseline.items():
            with self.subTest(path=relative):
                self.assertEqual(PARSER.parse(file_path=root / relative), expected)

    def test_range_map_reduce_to_object_and_fail_preserve_symbolic_arguments(self):
        tree = PARSER.parse(text="""
param values array = range(2, 3)
var mapped = map(values, value => { enabled: value })
var reduced = reduce(values, false, (acc, value) => acc || value)
var lookup = toObject(values, value => string(value), value => { enabled: value })
var rejected = fail('not configured')
""")
        for name in ("range", "map", "reduce", "toObject", "fail"):
            self.assertEqual(len(expressions(tree, name)), 1, name)
        self.assertEqual(expressions(tree, "range")[0]["parameters"], {"start": 2, "count": 3})
        self.assertEqual(expressions(tree, "map")[0]["parameters"]["input_element"], "value")
        self.assertEqual(expressions(tree, "fail")[0]["parameters"]["message"], "not configured")

    def test_range_loop_keeps_original_loop_shape(self):
        tree = PARSER.parse(text="var values = [for index in range(2, 3): index]\n")
        self.assertEqual(tree["variables"]["values"]["value"]["loop_type"]["type"], "range")

    def test_multiline_expressions_preserve_single_line_ast(self):
        for source in (
            "var value = flag\n  ? true\n  : false\n",
            "var value = subscriptionResourceId(\n 'provider/type',\n 'name'\n)\n",
        ):
            compact = " ".join(source.splitlines()) + "\n"
            self.assertEqual(BicepParser().parse(text=source), BicepParser().parse(text=compact))

    def test_invalid_syntax_and_unknown_functions_are_not_accepted(self):
        for source in (
            "var value = map([false], value => )",
            "var value = range(1)",
            "var value = unreviewedFunction(true)",
            "var value = flag ? true",
            "var value = reduce([false], false, (a, b) => )",
        ):
            with self.subTest(source=source), self.assertRaises(Exception):
                PARSER.parse(text=source)

    def test_real_checkov_insecure_and_unresolved_values_never_pass(self):
        cases = {
            "literal": ("", "false"),
            "conditional": ("param enabled bool\n", "enabled\n    ? true\n    : false"),
            "map_range": (
                "var indexes = range(0, 1)\n"
                "var settings = map(indexes, index => { enabled: false })\n",
                "settings[0].enabled",
            ),
            "unknown_parameter": ("param enabled bool\n", "enabled"),
        }
        with tempfile.TemporaryDirectory() as temporary:
            for name, (prefix, expression) in cases.items():
                source = prefix + (
                    "resource site 'Microsoft.Web/sites@2022-03-01' = {\n"
                    "  name: 'fixture'\n  location: 'westeurope'\n"
                    "  properties: {\n    httpsOnly: " + expression + "\n  }\n}\n"
                )
                path = Path(temporary) / f"{name}.bicep"
                path.write_text(source)
                report = Runner().run(
                    root_folder=None, files=[str(path)],
                    runner_filter=RunnerFilter(checks=["CKV_AZURE_14"], show_progress_bar=False),
                )
                self.assertFalse(report.parsing_errors, name)
                self.assertEqual(len(report.passed_checks), 0, name)
                self.assertEqual(len(report.failed_checks), 1, name)

if __name__ == "__main__":
    unittest.main(verbosity=2)
