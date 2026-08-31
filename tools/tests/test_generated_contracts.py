from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "generated_contracts.py"
SPEC = importlib.util.spec_from_file_location("generated_contracts", MODULE_PATH)
assert SPEC and SPEC.loader
generated_contracts = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = generated_contracts
SPEC.loader.exec_module(generated_contracts)


class GeneratedContractsTests(unittest.TestCase):
    def test_committed_outputs_are_current(self) -> None:
        root = MODULE_PATH.parents[1]
        self.assertFalse(generated_contracts.refresh(root, check=True))

    def test_refresh_is_deterministic_and_check_detects_stale_output(self) -> None:
        source_root = MODULE_PATH.parents[1]
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for relative in (
                generated_contracts.CONTENT_PACKAGE_CONTRACT,
                generated_contracts.COSMOS_CONTRACT,
                generated_contracts.ACTIVE_CONTENT_REFERENCE,
            ):
                destination = root / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes((source_root / relative).read_bytes())

            self.assertTrue(generated_contracts.refresh(root, check=False))
            first = generated_contracts.expected_outputs(root)
            self.assertFalse(generated_contracts.refresh(root, check=True))
            self.assertEqual(first, generated_contracts.expected_outputs(root))

            output = root / generated_contracts.COSMOS_CSHARP
            output.write_text(output.read_text(encoding="utf-8") + "// stale\n")
            with self.assertRaisesRegex(
                generated_contracts.ContractError, "generated contracts are stale"
            ):
                generated_contracts.refresh(root, check=True)

    def test_cosmos_source_maps_one_to_one_to_generated_definitions(self) -> None:
        root = MODULE_PATH.parents[1]
        contract = json.loads(
            (root / generated_contracts.COSMOS_CONTRACT).read_text(encoding="utf-8")
        )
        output = generated_contracts._cosmos_csharp_output(root)
        for container in contract["containers"]:
            self.assertEqual(
                1,
                output.count(
                    f'public const string {container["symbol"]} = "{container["name"]}";'
                ),
            )
            self.assertEqual(1, output.count(f'new({container["symbol"]}, "'))

    def test_package_contract_maps_one_to_one_to_active_reference(self) -> None:
        root = MODULE_PATH.parents[1]
        source = json.loads(
            (root / generated_contracts.CONTENT_PACKAGE_CONTRACT).read_text(
                encoding="utf-8"
            )
        )
        active = json.loads(
            generated_contracts._active_content_output(root)
        )
        self.assertEqual(source["activeReferenceSchema"], active["schema"])
        self.assertEqual(source["packageContract"], active["packageContract"])


if __name__ == "__main__":
    unittest.main()
