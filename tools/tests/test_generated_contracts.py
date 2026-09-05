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
    def copy_contract_inputs(self, root: Path) -> None:
        source_root = MODULE_PATH.parents[1]
        for relative in (
            generated_contracts.content_package_contract_path(source_root),
            generated_contracts.COSMOS_CONTRACT,
            generated_contracts.ACTIVE_CONTENT_REFERENCE,
        ):
            destination = root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes((source_root / relative).read_bytes())

    def read_cosmos_contract(self, root: Path) -> dict[str, object]:
        return json.loads(
            (root / generated_contracts.COSMOS_CONTRACT).read_text(encoding="utf-8")
        )

    def write_cosmos_contract(self, root: Path, contract: dict[str, object]) -> None:
        (root / generated_contracts.COSMOS_CONTRACT).write_text(
            json.dumps(contract, indent=2) + "\n",
            encoding="utf-8",
        )

    def test_committed_outputs_are_current(self) -> None:
        root = MODULE_PATH.parents[1]
        self.assertFalse(generated_contracts.refresh(root, check=True))

    def test_refresh_is_deterministic_and_check_detects_stale_output(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.copy_contract_inputs(root)

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

    def test_cosmos_names_accept_service_valid_hyphens_and_spaces(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.copy_contract_inputs(root)
            contract = self.read_cosmos_contract(root)
            contract["databaseName"] = " certigo-db"
            containers = contract["containers"]
            assert isinstance(containers, list)
            containers[0]["name"] = "content-public"
            containers[1]["name"] = "x" * 255
            containers[2]["name"] = "content private"
            self.write_cosmos_contract(root, contract)

            database_name, validated = generated_contracts._cosmos_contract(root)

            self.assertEqual(" certigo-db", database_name)
            self.assertEqual("content-public", validated[0]["name"])
            self.assertEqual("x" * 255, validated[1]["name"])
            self.assertEqual("content private", validated[2]["name"])

    def test_cosmos_names_reject_service_invalid_values(self) -> None:
        invalid_names = (
            "",
            " ",
            "\t",
            "a" * 256,
            "content/public",
            "content\\public",
            "content?public",
            "content#public",
            "content-public ",
            "\ud800",
        )
        for invalid_name in invalid_names:
            with self.subTest(name=repr(invalid_name)):
                with tempfile.TemporaryDirectory() as temporary:
                    root = Path(temporary)
                    self.copy_contract_inputs(root)
                    contract = self.read_cosmos_contract(root)
                    containers = contract["containers"]
                    assert isinstance(containers, list)
                    containers[0]["name"] = invalid_name
                    self.write_cosmos_contract(root, contract)

                    with self.assertRaises(generated_contracts.ContractError):
                        generated_contracts._cosmos_contract(root)

    def test_cosmos_database_name_uses_the_same_service_validation(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.copy_contract_inputs(root)
            contract = self.read_cosmos_contract(root)
            contract["databaseName"] = "certigo/db"
            self.write_cosmos_contract(root, contract)

            with self.assertRaisesRegex(
                generated_contracts.ContractError,
                "databaseName: Cosmos resource names cannot contain",
            ):
                generated_contracts._cosmos_contract(root)

    def test_cosmos_container_names_reject_exact_and_case_collisions(self) -> None:
        for duplicate_name in ("users", "USERS"):
            with self.subTest(name=duplicate_name):
                with tempfile.TemporaryDirectory() as temporary:
                    root = Path(temporary)
                    self.copy_contract_inputs(root)
                    contract = self.read_cosmos_contract(root)
                    containers = contract["containers"]
                    assert isinstance(containers, list)
                    containers[1]["name"] = duplicate_name
                    self.write_cosmos_contract(root, contract)

                    with self.assertRaisesRegex(
                        generated_contracts.ContractError,
                        "container names must be unique ignoring case",
                    ):
                        generated_contracts._cosmos_contract(root)

    def test_cosmos_container_symbols_reject_duplicates(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.copy_contract_inputs(root)
            contract = self.read_cosmos_contract(root)
            containers = contract["containers"]
            assert isinstance(containers, list)
            containers[1]["symbol"] = containers[0]["symbol"]
            self.write_cosmos_contract(root, contract)

            with self.assertRaisesRegex(
                generated_contracts.ContractError,
                "container symbols must be unique",
            ):
                generated_contracts._cosmos_contract(root)

    def test_cosmos_names_are_safely_escaped_in_generated_csharp(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.copy_contract_inputs(root)
            contract = self.read_cosmos_contract(root)
            contract["databaseName"] = 'certigo"db'
            containers = contract["containers"]
            assert isinstance(containers, list)
            containers[0]["name"] = 'content-"public"'
            self.write_cosmos_contract(root, contract)

            output = generated_contracts._cosmos_csharp_output(root)

            self.assertIn('DatabaseName = "certigo\\"db";', output)
            self.assertIn('Users = "content-\\"public\\"";', output)

    def test_cosmos_source_maps_one_to_one_to_generated_definitions(self) -> None:
        root = MODULE_PATH.parents[1]
        contract = json.loads(
            (root / generated_contracts.COSMOS_CONTRACT).read_text(encoding="utf-8")
        )
        output = generated_contracts._cosmos_csharp_output(root)
        for container in contract["containers"]:
            name_literal = generated_contracts._csharp_string_literal(container["name"])
            self.assertEqual(
                1,
                output.count(
                    f'public const string {container["symbol"]} = {name_literal};'
                ),
            )
            self.assertEqual(1, output.count(f'new({container["symbol"]}, "'))

        bicep = (root / "infra/modules/cosmos.bicep").read_text(encoding="utf-8")
        self.assertEqual(
            1,
            bicep.count(
                "loadJsonContent('../../contracts/cosmos-containers.json').containers"
            ),
        )
        self.assertEqual(1, bicep.count("for c in containers:"))
        self.assertEqual(1, bicep.count("name: c.name"))
        self.assertEqual(1, bicep.count("id: c.name"))

    def test_package_contract_maps_one_to_one_to_active_reference(self) -> None:
        root = MODULE_PATH.parents[1]
        source = json.loads(
            (root / generated_contracts.content_package_contract_path(root)).read_text(
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
