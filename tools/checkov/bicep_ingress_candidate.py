"""Inactive Bicep applicability qualification with explicit local-module provenance."""

import argparse
from fnmatch import fnmatchcase
import hashlib
from importlib import import_module
from importlib.metadata import version
import json
from pathlib import Path
import re
import sys
import tempfile

import checkov.arm
from checkov.bicep.runner import Runner
from checkov.runner_filter import RunnerFilter
from pycep import BicepParser
from pycep.transformer import BicepElement

from build_checkov_wheel import PATCHED_SOURCE_SHA256, SOURCE as CHECKOV_BASE_SOURCE, VERSION
from build_parser_wheel import PATCHED_FILES, VERSION as COMPAT_PARSER_VERSION


SITE = "Microsoft.Web/sites"
CONFIG = SITE + "/config"
COSMOS = "Microsoft.DocumentDB/databaseAccounts"
COSMOS_DATABASE = COSMOS + "/sqlDatabases"
COSMOS_CONTAINER = COSMOS_DATABASE + "/containers"
COSMOS_CHECKS = ("CKV_AZURE_99", "CKV_AZURE_101", "CKV_AZURE_132", "CKV_AZURE_140")
COSMOS_INPUTS = {
    "CKV_AZURE_99": (
        "publicNetworkAccess", "isVirtualNetworkFilterEnabled", "virtualNetworkRules", "ipRules",
    ),
    "CKV_AZURE_101": ("publicNetworkAccess",),
    "CKV_AZURE_132": ("disableKeyBasedMetadataWriteAccess",),
    "CKV_AZURE_140": ("disableLocalAuth",),
}
SITE_CHECKS = ("CKV_AZURE_16", "CKV_AZURE_222")
CONFIG_CHECKS = {
    "CKV_AZURE_13": "authsettings",
    "CKV_AZURE_80": "web",
    "CKV_AZURE_66": "web",
    "CKV_AZURE_63": "web",
    "CKV_AZURE_222": "web",
    "CKV_AZURE_88": "web",
}
CHECKS = tuple(sorted({*SITE_CHECKS, *CONFIG_CHECKS, *COSMOS_CHECKS}))
API_VERSION = "2024-04-01"
COSMOS_API_VERSION = "2024-11-15"

RULE_SOURCES = {
    CHECKOV_BASE_SOURCE: PATCHED_SOURCE_SHA256,
    "checkov/arm/checks/resource/AppServiceIdentity.py":
        "f36911729b239513c83641ed171b86518227e92af0b97b618821143189a4010d",
    "checkov/arm/checks/resource/AppServiceAuthentication.py":
        "af80cdbff008b91ae1c051dbaec6eaa3801deb3f20217d3c6fb49d32404c86bb",
    "checkov/arm/checks/resource/AppServiceDotnetFrameworkVersion.py":
        "9725066ac8de44b476dea83cacdedb1588881e629cbe62f19c85860adeefdaa2",
    "checkov/arm/checks/resource/AppServiceEnableFailedRequest.py":
        "e84a6a67111f1bd450221688a4ef74f97f608d53e189d435c204ab81ede53849",
    "checkov/arm/checks/resource/AppServiceHttpLoggingEnabled.py":
        "e4121eed5a46c54078f0299091bd2baa9bc71f208be6437c88be523f7729e5af",
    "checkov/arm/checks/resource/AppServicePublicAccessDisabled.py":
        "e618b4d8ee177117986c07f4a9b0f96d1b122dfe0fe89d88103db9d3f930c431",
    "checkov/arm/checks/resource/AppServiceUsedAzureFiles.py":
        "1e9c1452bed550c63b48a973abe164b9d011b9de102ce652c09b6a7f450f1b48",
    "checkov/arm/checks/resource/CosmosDBAccountsRestrictedAccess.py":
        "2a5d260ab48a02032dfed01f14ba9c4fb4d806f23414f4c12c6d1a031b1c0384",
    "checkov/arm/checks/resource/CosmosDBDisablesPublicNetwork.py":
        "38ab0e3f9cc81dc49d7f46651c82599d31887e54fe0cd34d69356a5b8b331cd4",
    "checkov/arm/checks/resource/CosmosDBDisableAccessKeyWrite.py":
        "98f3ee479408dd484baf0f69daec580ae388fb18cb2eef0051f4b671e4a7ae50",
    "checkov/arm/checks/resource/CosmosDBLocalAuthDisabled.py":
        "9926eb784559162b38b115c49a720f13a2c53cc9226b1272f05539bd3547e67e",
}
REGISTRY_SHA256 = "35a84e2225433f4529efcfdeebc6fe872e8ebca50674ab03717aff3d33d44fd0"
UPSTREAM_PARSER_SOURCES = {
    "pycep/__init__.py": "c5ccf5905df50eeaf2b58dc53dc3e693db54ada95c38f7c7cdb63b16a643230d",
    "pycep/bicep.lark": "e40d0cc7b84e1a324acac120171a475adb9fdcc8770ad0c249e4906caf1277f2",
    "pycep/main.py": "3de04e7ce87e3ab105f20e829fb17b3394952a76cd4452bc4625c24733e4ae85",
    "pycep/transformer.py": "c09329a9902e1ca70fa8a9c7ea1112b746ec816b66e22c48f00b0769181b6bbd",
    "pycep/typing.py": "7602ebb3c2c6fc08da78aec2efea81ed9089c904f59b392e36ca3dba10dfe9ae",
    "pycep/validator.py": "d5c93e51755c313cd279905ef625b2cbb219fe9a7cab4175d52e90f8a46854c4",
}


def _verify_parser():
    import pycep

    parser_version = version("pycep-parser")
    if parser_version not in ("0.5.1", COMPAT_PARSER_VERSION):
        raise ValueError("requires pinned upstream or reviewed compatibility parser")
    sources = dict(UPSTREAM_PARSER_SOURCES)
    if parser_version == COMPAT_PARSER_VERSION:
        sources.update(PATCHED_FILES)
    package_root = Path(pycep.__file__).parent.parent
    for relative, expected in sources.items():
        if hashlib.sha256((package_root / relative).read_bytes()).hexdigest() != expected:
            raise ValueError("unexpected installed parser source: " + relative)
    return {"version": parser_version, "source_sha256": sources}


class BindingResolutionError(ValueError):
    """An authored Bicep expression is outside the bounded static resolver."""


def _literal_string(value):
    return type(value) is str and "${" not in value


def _contains_comment(text):
    quote = None
    index = 0
    while index < len(text):
        character = text[index]
        if quote is not None:
            if character == quote:
                if index + 1 < len(text) and text[index + 1] == quote:
                    index += 2
                    continue
                quote = None
        elif character in ("'", '"'):
            quote = character
        elif text.startswith("//", index) or text.startswith("/*", index):
            return True
        index += 1
    return False


def _parser_source(source):
    """Join Bicep's line-wrapped ternary punctuation without changing scanner input."""
    lines = source.splitlines(keepends=True)
    normalized = []
    for line in lines:
        stripped = line.lstrip(" \t")
        if (
            normalized
            and stripped.startswith(("?", ":"))
            and not _contains_comment(normalized[-1])
        ):
            previous = normalized.pop().rstrip("\r\n")
            newline = "\r\n" if line.endswith("\r\n") else "\n" if line.endswith("\n") else ""
            normalized.append(previous + " " + stripped.rstrip("\r\n") + newline)
        else:
            normalized.append(line)
    return "".join(normalized)


def _parse_source(source):
    parser = _verify_parser()
    text = source if parser["version"] == COMPAT_PARSER_VERSION else _parser_source(source)
    return BicepParser().parse(text=text)


def _resolve_expression(expression, resolve_symbol, environment, json_loader=None):
    def resolve(value):
        return _resolve_expression(value, resolve_symbol, environment, json_loader)

    if isinstance(expression, BicepElement):
        return resolve_symbol(str(expression))
    if type(expression) is str:
        if "${" not in expression:
            return expression

        def replace(match):
            value = resolve_symbol(match.group(1))
            if type(value) is bool:
                return "true" if value else "false"
            if type(value) not in (str, int):
                raise BindingResolutionError("interpolation is not a scalar literal")
            return str(value)

        rendered = re.sub(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}", replace, expression)
        if "${" in rendered:
            raise BindingResolutionError("interpolation is not a simple symbol")
        return rendered
    if type(expression) in (bool, int):
        return expression
    if isinstance(expression, list):
        return [resolve(value) for value in expression]
    if isinstance(expression, dict):
        if "function" in expression:
            function = expression["function"]
            if set(expression) != {"function"} or not isinstance(function, dict):
                raise BindingResolutionError("malformed bounded function")
            kind = function.get("type")
            params = function.get("parameters")
            if not isinstance(params, dict) or set(function) - {"type", "parameters", "property_name"}:
                raise BindingResolutionError("malformed bounded function arguments")
            if kind == "empty" and set(params) == {"item_to_test"} and "property_name" not in function:
                value = resolve(params["item_to_test"])
                if type(value) not in (str, list, dict):
                    raise BindingResolutionError("empty requires a resolved string, array or object")
                return not value
            if kind == "union" and set(params) == {"arg_1", "arg_2"} and "property_name" not in function:
                left, right = resolve(params["arg_1"]), resolve(params["arg_2"])
                if not isinstance(left, dict) or not isinstance(right, dict):
                    raise BindingResolutionError("only literal object union is supported")

                def merge(first, second):
                    result = dict(first)
                    for key, value in second.items():
                        if key in result and isinstance(result[key], dict) and isinstance(value, dict):
                            result[key] = merge(result[key], value)
                        else:
                            result[key] = value
                    return result

                return merge(left, right)
            if (
                kind == "load_json_content" and json_loader is not None
                and set(params) == {"file_path", "json_path", "encoding"}
                and _literal_string(params["file_path"])
                and params["json_path"] is None and params["encoding"] is None
            ):
                value = json_loader(params["file_path"])
                if "property_name" in function:
                    member = function["property_name"]
                    if type(member) is not str or not isinstance(value, dict) or member not in value:
                        raise BindingResolutionError("JSON member is not explicitly present")
                    value = value[member]
                return value
            raise BindingResolutionError("function calls are outside the static binding contract")
        operator = expression.get("operator")
        if isinstance(operator, dict):
            operands = operator.get("operands")
            kind = operator.get("type")
            if (
                set(expression) != {"operator"} or set(operator) != {"type", "operands"}
                or not isinstance(operands, dict)
            ):
                raise BindingResolutionError("malformed bounded operator")
            if (
                kind == "minus" and set(operands) == {"integer_value"}
                and type(operands["integer_value"]) is int and operands["integer_value"] >= 0
            ):
                return -operands["integer_value"]
            if kind == "conditional" and set(operands) == {"condition", "true_value", "false_value"}:
                condition = resolve(operands["condition"])
                if type(condition) is not bool:
                    raise BindingResolutionError("conditional requires an explicit boolean")
                return resolve(operands["true_value" if condition else "false_value"])
            if set(operands) == {"operand_1", "operand_2"}:
                left, right = operands["operand_1"], operands["operand_2"]
                nested = right.get("operator") if isinstance(right, dict) else None
                # pycep associates a trailing ternary with the RHS of equality/access.
                if kind in ("equals", "not_equals") and isinstance(nested, dict) and nested.get("type") == "conditional":
                    branches = nested.get("operands", {})
                    if set(branches) == {"condition", "true_value", "false_value"}:
                        return resolve({"operator": {
                            "type": "conditional", "operands": {
                                **branches,
                                "condition": {"operator": {"type": kind, "operands": {
                                    "operand_1": left, "operand_2": branches["condition"],
                                }}},
                            },
                        }})
                if kind == "property_accessor":
                    if isinstance(nested, dict) and nested.get("type") in ("equals", "not_equals"):
                        comparison = nested.get("operands", {})
                        if set(comparison) == {"operand_1", "operand_2"}:
                            return resolve({"operator": {
                                "type": nested["type"], "operands": {
                                    **comparison,
                                    "operand_1": {"operator": {"type": kind, "operands": {
                                        "operand_1": left, "operand_2": comparison["operand_1"],
                                    }}},
                                },
                            }})
                    value = resolve(left)
                    if (
                        type(right) not in (str, BicepElement)
                        or re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", right) is None
                        or not isinstance(value, dict) or right not in value
                    ):
                        raise BindingResolutionError("property access requires an explicit object member")
                    return value[right]
                if kind in ("equals", "not_equals"):
                    first, second = resolve(left), resolve(right)
                    if type(first) not in (str, bool, int, type(None)) or type(second) not in (
                        str, bool, int, type(None),
                    ):
                        raise BindingResolutionError("equality requires literal scalars")
                    equal = type(first) is type(second) and first == second
                    return equal if kind == "equals" else not equal
            raise BindingResolutionError("operator is outside the literal/environment contract")
        return {
            key: resolve(value)
            for key, value in expression.items()
        }
    if expression is None:
        return None
    raise BindingResolutionError("value is outside the literal/environment contract")


def _matches_parameter_type(value, type_name):
    if type_name == "string":
        return type(value) is str
    if type_name == "bool":
        return type(value) is bool
    if type_name == "int":
        return type(value) is int
    if type_name == "array":
        return isinstance(value, list)
    if type_name == "object":
        return isinstance(value, dict)
    return False


def _raise_unresolved_symbol(name):
    raise BindingResolutionError("module symbol has no explicit binding: " + name)


def _cosmos_contract_loader(root_path, source_path, snapshots, evidence):
    """Only the repository's non-secret authored Cosmos contract may be loaded."""
    expected = root_path.parent.parent / "contracts" / "cosmos-containers.json"

    def unique_object(pairs):
        value = {}
        for key, item in pairs:
            if key in value:
                raise ValueError("duplicate JSON member")
            value[key] = item
        return value

    def load(relative):
        candidate = source_path.parent / relative
        if (
            candidate.resolve() != expected
            or expected.is_symlink() or expected.parent.is_symlink()
        ):
            raise BindingResolutionError("only the local Cosmos source contract is supported")
        if expected not in snapshots:
            try:
                with expected.open("rb") as stream:
                    contents = stream.read(1024 * 1024 + 1)
                if len(contents) > 1024 * 1024:
                    raise ValueError("oversized source contract")
                contract = json.loads(contents, object_pairs_hook=unique_object)
                if (
                    not isinstance(contract, dict)
                    or set(contract) != {"schema", "databaseName", "containers"}
                    or contract["schema"] != "certigo.source-contract/cosmos-containers/v1"
                    or not _literal_string(contract["databaseName"]) or not contract["databaseName"]
                    or not isinstance(contract["containers"], list) or not contract["containers"]
                ):
                    raise ValueError("unsupported Cosmos contract")
                names, symbols = set(), set()
                for item in contract["containers"]:
                    if (
                        not isinstance(item, dict)
                        or set(item) != {"symbol", "name", "partitionKeyPath", "defaultTimeToLive"}
                        or any(not _literal_string(item[k]) or not item[k] for k in (
                            "symbol", "name", "partitionKeyPath",
                        ))
                        or not item["partitionKeyPath"].startswith("/")
                        or item["name"] in names or item["symbol"] in symbols
                        or not (
                            item["defaultTimeToLive"] is None
                            or (type(item["defaultTimeToLive"]) is int and (
                                item["defaultTimeToLive"] == -1 or item["defaultTimeToLive"] > 0
                            ))
                        )
                    ):
                        raise ValueError("malformed or duplicate Cosmos container")
                    names.add(item["name"])
                    symbols.add(item["symbol"])
                snapshots[expected] = (contents, contract)
            except (OSError, UnicodeError, ValueError) as error:
                raise BindingResolutionError("Cosmos contract unavailable or invalid: " + type(error).__name__) from error
        contents, contract = snapshots[expected]
        evidence[str(expected)] = {
            "source": str(expected), "sha256": hashlib.sha256(contents).hexdigest(),
            "schema": contract["schema"], "container_count": len(contract["containers"]),
        }
        return contract

    return load


def _bounded_cosmos_outputs(tree):
    outputs = tree.get("outputs", {})
    if not outputs:
        return True

    def access(first, second):
        return {"operator": {"type": "property_accessor", "operands": {
            "operand_1": first, "operand_2": second,
        }}}

    expected = {
        "endpoint": access(BicepElement("account"), access("properties", "documentEndpoint")),
        "accountName": access(BicepElement("account"), "name"),
        "backupMode": BicepElement("backupMode"),
    }
    account = tree.get("resources", {}).get("account", {})
    if (
        account.get("type") != COSMOS
        or not isinstance(outputs, dict) or set(outputs) != set(expected)
    ):
        return False
    for name, expression in expected.items():
        item = outputs[name]
        if (
            not isinstance(item, dict) or set(item) != {"decorators", "type", "value"}
            or item["decorators"] != [] or item["type"] != "string"
            or item["value"] != expression
        ):
            return False
        # BicepElement inherits str; reject a quoted pseudo-reference.
        value = item["value"]
        root = value if name == "backupMode" else value["operator"]["operands"]["operand_1"]
        if type(root) is not BicepElement:
            return False
    return True


def _symbolic_cosmos_name(root, module, passed, environment, resolve_root, root_sha256):
    expected_suffix = {"function": {"type": "unique_string", "parameters": {
        "base_string": {"function": {
            "type": "subscription", "parameters": {"subscription_id": None}, "property_name": "id",
        }},
        "extra_string_1": BicepElement("appName"), "extra_string_2": BicepElement("env"),
    }}}
    actual = root.get("variables", {}).get("suffix", {}).get("value")
    params = actual.get("function", {}).get("parameters", {}) if isinstance(actual, dict) else {}
    if (
        passed.get("accountName") != "cosmos-${appName}-${env}-${suffix}"
        or actual != expected_suffix
        or type(params.get("extra_string_1")) is not BicepElement
        or type(params.get("extra_string_2")) is not BicepElement
    ):
        raise BindingResolutionError("account name is not the reviewed symbolic subscription expression")
    usages = []

    def visit(value, path=()):
        if type(value) is BicepElement and str(value) == "accountName":
            usages.append(path)
        elif type(value) is str and "${accountName}" in value:
            usages.append(path)
        elif isinstance(value, dict):
            for key, item in value.items():
                if isinstance(key, str) and "${accountName}" in key:
                    usages.append(path + (str(key),))
                visit(item, path + (str(key),))
        elif isinstance(value, list):
            for index, item in enumerate(value):
                visit(item, path + (index,))

    visit(module)
    if usages != [("resources", "account", "config", "name")]:
        raise BindingResolutionError("symbolic accountName may only populate the account's non-security name")
    app_name = resolve_root("appName")
    if not _literal_string(app_name) or not app_name:
        raise BindingResolutionError("symbolic name appName must be an explicit non-secret literal")
    token = "symbolic-" + hashlib.sha256(
        (root_sha256 + ":" + app_name + ":" + environment).encode("utf-8")
    ).hexdigest()[:24]
    return token, {
        "parameter": "accountName", "kind": "symbolic-non-network-name/v1",
        "authored_expression": passed["accountName"],
        "dependency": "uniqueString(subscription().id, appName, env)",
        "snapshot_token": token, "actual_azure_name_known": False,
        "allowed_usage": "resources.account.config.name",
    }


def resolve_local_module_bindings(
    root_path, environment, module_symbol="api", *, _snapshot=None, _module_snapshots=None,
    _json_snapshots=None,
    _root_values=None, _symbolic_name=False,
):
    """Resolve one local call using bounded literals, expressions and Cosmos JSON."""
    root_path = Path(root_path).resolve(strict=True)
    root_bytes = root_path.read_bytes() if _snapshot is None else _snapshot[0]
    result = {
        "root_source": str(root_path),
        "root_sha256": hashlib.sha256(root_bytes).hexdigest(),
        "environment": environment,
        "module_symbol": module_symbol,
        "module_source": None,
        "module_sha256": None,
        "module_name": None,
        "module_scope": None,
        "dependencies": [],
        "parameters": [],
        "values": {},
        "source_inputs": {},
        "explicit_root_parameters": dict(_root_values or {}),
        "explicit_root_parameters_used": [],
        "symbolic_inputs": [],
        "blockers": [],
    }
    if environment not in ("dev", "staging", "prod"):
        result["blockers"].append("only dev, staging or prod can be resolved")
        return result
    try:
        root = _parse_source(root_bytes.decode("utf-8")) if _snapshot is None else _snapshot[1]
    except Exception as error:
        result["blockers"].append("root source parsing failed: " + type(error).__name__)
        return result
    if not isinstance(root, dict):
        result["blockers"].append("root source AST is malformed")
        return result
    env_parameter = root.get("parameters", {}).get("env")
    allowed = [
        tuple(decorator["argument"])
        for decorator in env_parameter.get("decorators", [])
        if decorator.get("type") == "allowed"
        and isinstance(decorator.get("argument"), list)
    ] if isinstance(env_parameter, dict) else []
    if (
        not isinstance(env_parameter, dict)
        or env_parameter.get("type") != "string"
        or allowed != [("dev", "staging", "prod")]
    ):
        result["blockers"].append("root env must be a string with exactly dev/staging/prod allowed")
        return result

    modules = root.get("modules")
    node = modules.get(module_symbol) if isinstance(modules, dict) else None
    if not isinstance(node, dict) or node.get("type") != "local":
        result["blockers"].append("requested local module call is absent or unsupported")
        return result
    config = node.get("config")
    detail = node.get("detail")
    if (
        not isinstance(config, dict)
        or not isinstance(detail, dict)
        or not isinstance(detail.get("path"), str)
        or not isinstance(config.get("name"), str)
    ):
        result["blockers"].append("module call has malformed source or configuration")
        return result
    unsupported_module_fields = set(config) - {"name", "params", "scope", "dependsOn"}
    if unsupported_module_fields:
        result["blockers"].append(
            "module condition, loop or unknown fields are outside the binding contract"
        )
    relative_module = Path(detail["path"])
    if relative_module.is_absolute() or ".." in relative_module.parts:
        result["blockers"].append("local module path must remain below the root source directory")
        return result
    try:
        module_path = (root_path.parent / relative_module).resolve(strict=True)
    except OSError as error:
        result["blockers"].append("local module source is unavailable: " + type(error).__name__)
        return result
    if not module_path.is_relative_to(root_path.parent):
        result["blockers"].append("local module path escapes the root source directory")
        return result
    result["module_source"] = str(module_path)
    if _module_snapshots is None:
        module_bytes = module_path.read_bytes()
    else:
        if module_path not in _module_snapshots:
            _module_snapshots[module_path] = module_path.read_bytes()
        module_bytes = _module_snapshots[module_path]
    result["_module_bytes"] = module_bytes
    result["module_sha256"] = hashlib.sha256(module_bytes).hexdigest()
    try:
        module = _parse_source(module_bytes.decode("utf-8"))
    except Exception as error:
        result["blockers"].append("module source parsing failed: " + type(error).__name__)
        return result
    if not isinstance(module, dict):
        result["blockers"].append("module source AST is malformed")
        return result
    if (
        set(module) - {"globals", "parameters", "variables", "resources", "outputs"}
        or not _bounded_cosmos_outputs(module)
    ):
        result["blockers"].append("nested modules and outputs are outside this module contract")
    if not isinstance(module.get("resources"), dict) or not module["resources"]:
        result["blockers"].append("module has no statically inventoried resources")

    root_parameters = root.get("parameters", {})
    root_variables = root.get("variables", {})
    json_snapshots = {} if _json_snapshots is None else _json_snapshots
    root_loader = _cosmos_contract_loader(
        root_path, root_path, json_snapshots, result["source_inputs"],
    )
    module_loader = _cosmos_contract_loader(
        root_path, module_path, json_snapshots, result["source_inputs"],
    )

    def resolve_root_symbol(name, active=()):
        if name == "env":
            return environment
        if name in active:
            raise BindingResolutionError("cyclic root parameter/variable reference")
        spec = None
        if name in root_parameters:
            spec = root_parameters[name]
            if any(item.get("type") == "secure" for item in spec.get("decorators", [])):
                raise BindingResolutionError("secure root parameters need external deployment evidence")
            if name in (_root_values or {}):
                allowed_values = [
                    item.get("argument") for item in spec.get("decorators", [])
                    if item.get("type") == "allowed"
                ]
                if (
                    name != "cosmosBackupMode"
                    or allowed_values != [["Periodic", "Continuous"]]
                ):
                    raise BindingResolutionError("explicit input is outside the bounded Cosmos backup contract")
                if name not in result["explicit_root_parameters_used"]:
                    result["explicit_root_parameters_used"].append(name)
            default = (_root_values or {}).get(name, spec.get("default"))
            if default is None:
                raise BindingResolutionError("root parameter has no literal deployment value")
            value = default
        elif name in root_variables:
            value = root_variables[name].get("value")
        else:
            raise BindingResolutionError("root symbol is not a literal parameter or variable")
        resolved = _resolve_expression(
            value, lambda nested: resolve_root_symbol(nested, active + (name,)), environment,
            root_loader,
        )
        if spec is not None and not _matches_parameter_type(resolved, spec.get("type")):
            raise BindingResolutionError("root default does not match its declared parameter type")
        return resolved

    try:
        name = _resolve_expression(config["name"], resolve_root_symbol, environment)
        if not _literal_string(name) or not name:
            raise BindingResolutionError("module deployment name is not a literal")
        result["module_name"] = name
    except BindingResolutionError as error:
        result["blockers"].append("unresolved module deployment name: " + str(error))

    scope = config.get("scope")
    if scope is None:
        if root.get("globals", {}).get("scope", {}).get("value") != "resourceGroup":
            result["blockers"].append("module has no explicit resource-group scope")
        else:
            result["module_scope"] = {"kind": "inherited-resource-group"}
    elif type(scope) is BicepElement:
        scope_resource = root.get("resources", {}).get(str(scope), {})
        scope_config = scope_resource.get("config", {})
        if (
            scope_resource.get("type") != "Microsoft.Resources/resourceGroups"
            or scope_resource.get("existing") is not True
            or scope_resource.get("api_version") != "2024-03-01"
            or set(scope_resource) != {"decorators", "type", "api_version", "existing", "config"}
            or set(scope_config) != {"name"}
            or root.get("globals", {}).get("scope", {}).get("value") not in (
                "resourceGroup", "subscription",
            )
        ):
            result["blockers"].append("module scope is not a bounded existing resource-group symbol")
        else:
            try:
                name = _resolve_expression(scope_config["name"], resolve_root_symbol, environment)
                if not _literal_string(name) or not name:
                    raise BindingResolutionError("resource-group name is not a literal")
                result["module_scope"] = {
                    "kind": "existing-resource-group", "symbol": str(scope), "name": name,
                }
            except BindingResolutionError as error:
                result["blockers"].append("unresolved module scope: " + str(error))
    else:
        result["blockers"].append("dynamic module scopes are outside the binding contract")
    dependencies = config.get("dependsOn", [])
    root_symbols = set(root.get("modules", {})) | set(root.get("resources", {}))
    if not isinstance(dependencies, list) or any(
        type(item) is not BicepElement or str(item) not in root_symbols for item in dependencies
    ):
        result["blockers"].append("module dependency is not an explicit root symbol")
    else:
        result["dependencies"] = [str(item) for item in dependencies]

    module_parameters = module.get("parameters", {})
    passed = config.get("params", {})
    if not isinstance(module_parameters, dict) or not isinstance(passed, dict):
        result["blockers"].append("module parameter declarations or arguments are malformed")
        return result
    for name in sorted(set(passed) - set(module_parameters)):
        result["blockers"].append("root passes an undeclared module parameter: " + name)

    values = {}
    resolving = set()

    def resolve_module_symbol(name):
        if name in values:
            return values[name]
        if name in resolving:
            raise BindingResolutionError("cyclic module parameter/variable reference")
        if name in module_parameters:
            resolving.add(name)
            spec = module_parameters[name]
            if any(item.get("type") == "secure" for item in spec.get("decorators", [])):
                resolving.remove(name)
                raise BindingResolutionError("secure module parameters need external deployment evidence")
            if name in passed:
                expression = passed[name]
                resolver = resolve_root_symbol
            else:
                expression = spec.get("default")
                resolver = resolve_module_symbol
            if expression is None:
                resolving.remove(name)
                raise BindingResolutionError("required module parameter is not explicitly bound")
            if (
                _symbolic_name and name == "accountName"
                and type(expression) is str and "${suffix}" in expression
            ):
                value, proof = _symbolic_cosmos_name(
                    root, module, passed, environment, resolve_root_symbol, result["root_sha256"],
                )
                result["symbolic_inputs"].append(proof)
            else:
                value = _resolve_expression(
                    expression, resolver, environment, root_loader if name in passed else module_loader,
                )
            if not _matches_parameter_type(value, spec.get("type")):
                resolving.remove(name)
                raise BindingResolutionError("resolved value does not match the declared module type")
            values[name] = value
            resolving.remove(name)
            return value
        if name in module.get("variables", {}):
            resolving.add(name)
            value = _resolve_expression(
                module["variables"][name].get("value"), resolve_module_symbol, environment,
                module_loader,
            )
            values[name] = value
            resolving.remove(name)
            return value
        raise BindingResolutionError("module symbol has no explicit literal binding")

    for name in sorted(module_parameters):
        spec = module_parameters[name]
        secure = any(
            decorator.get("type") == "secure"
            for decorator in spec.get("decorators", [])
        )
        item = {"parameter": name, "type": spec.get("type"), "secure": secure}
        try:
            value = resolve_module_symbol(name)
            item["resolved"] = True
            if not secure:
                item["value"] = value
            result["values"][name] = value
        except BindingResolutionError as error:
            item["resolved"] = False
            item["reason"] = str(error)
            result["blockers"].append("module parameter " + name + ": " + str(error))
        result["parameters"].append(item)
    for name in sorted(module.get("variables", {})):
        try:
            resolve_module_symbol(name)
        except BindingResolutionError as error:
            result["blockers"].append("module variable " + name + ": " + str(error))
    result["values"] = values
    if set(_root_values or {}) != set(result["explicit_root_parameters_used"]):
        result["blockers"].append("an explicit root input is absent, unresolved or not consumed by this module")
    return result


def _literal_identity(identity):
    if not isinstance(identity, dict) or set(identity) - {"type", "userAssignedIdentities"}:
        return False
    kind = identity.get("type")
    if type(kind) is not str or kind not in {
        "None", "SystemAssigned", "UserAssigned",
        "SystemAssigned, UserAssigned", "UserAssigned,SystemAssigned",
    }:
        return False
    assignments = identity.get("userAssignedIdentities")
    if "userAssignedIdentities" in identity and (
        not isinstance(assignments, dict)
        or any(
            type(resource_id) is not str
            or not resource_id.startswith("'/") or not resource_id.endswith("'")
            or "${" in resource_id
            or not isinstance(config, dict) or config
            for resource_id, config in assignments.items()
        )
    ):
        return False
    return True


def _literal_web(properties):
    expected = {
        "netFrameworkVersion", "requestTracingEnabled", "httpLoggingEnabled",
        "publicNetworkAccess", "azureStorageAccounts",
    }
    if not isinstance(properties, dict) or set(properties) != expected:
        return False
    if (
        not _literal_string(properties["netFrameworkVersion"])
        or type(properties["requestTracingEnabled"]) is not bool
        or type(properties["httpLoggingEnabled"]) is not bool
        or type(properties["publicNetworkAccess"]) is not str
        or properties["publicNetworkAccess"] not in ("Enabled", "Disabled")
    ):
        return False
    storage = properties["azureStorageAccounts"]
    return isinstance(storage, dict) and all(
        _literal_string(name)
        and isinstance(value, dict)
        and set(value) == {"type"}
        and _literal_string(value["type"])
        for name, value in storage.items()
    )


def _literal_cosmos(properties):
    allowed = {
        "publicNetworkAccess", "enableMultipleWriteLocations",
        "isVirtualNetworkFilterEnabled", "virtualNetworkRules", "ipRules",
        "disableLocalAuth", "disableKeyBasedMetadataWriteAccess",
        "databaseAccountOfferType", "enableAutomaticFailover", "capabilities",
        "consistencyPolicy", "locations", "minimalTlsVersion", "backupPolicy",
    }
    if (
        not isinstance(properties, dict)
        or set(properties) - allowed
        or type(properties.get("publicNetworkAccess")) is not str
        or properties["publicNetworkAccess"] not in ("Enabled", "Disabled")
    ):
        return False
    for key in (
        "enableMultipleWriteLocations", "isVirtualNetworkFilterEnabled",
        "disableLocalAuth", "disableKeyBasedMetadataWriteAccess", "enableAutomaticFailover",
    ):
        if key in properties and type(properties[key]) is not bool:
            return False
    for key, value_key in (
        ("virtualNetworkRules", "id"), ("ipRules", "ipAddressOrRange"),
    ):
        if key in properties and (
            not isinstance(properties[key], list)
            or any(
                not isinstance(rule, dict)
                or set(rule) != {value_key}
                or not _literal_string(rule[value_key])
                for rule in properties[key]
            )
        ):
            return False
    try:
        _resolve_expression(properties, _raise_unresolved_symbol, None)
    except BindingResolutionError:
        return False
    return True


def inventory(source, environment, instance, resolved_values=None, *, _materialized=None):
    """Derive exact obligations from authored AST before running Checkov."""
    problems = []
    entries = []
    module_instance = instance.startswith("root/") if type(instance) is str else False
    if (
        environment not in ("dev", "staging", "prod")
        or (instance != "root" and (not module_instance or resolved_values is None))
    ):
        problems.append("only root sources or explicitly bound local module instances are qualified")
    try:
        tree = _parse_source(source)
    except Exception as error:
        return [], 0, ["source parsing failed: " + type(error).__name__]
    if not isinstance(tree, dict):
        return [], 0, ["malformed source AST"]
    allowed_tree_keys = {"globals", "resources"}
    if resolved_values is not None:
        allowed_tree_keys |= {"parameters", "variables", "outputs"}
    if set(tree) - allowed_tree_keys:
        problems.append("outputs and nested modules are outside this qualification")
    if not _bounded_cosmos_outputs(tree):
        problems.append("outputs are outside the bounded Cosmos provenance contract")
    if resolved_values is not None:
        declared_parameters = tree.get("parameters", {})
        declared_variables = tree.get("variables", {})
        if (
            not isinstance(declared_parameters, dict)
            or not isinstance(declared_variables, dict)
            or set(declared_parameters) - set(resolved_values)
            or set(declared_variables) - set(resolved_values)
        ):
            problems.append("module parameter/variable provenance is incomplete")

    def resolve(value, resource_key):
        if resolved_values is None:
            return value
        try:
            return _resolve_expression(
                value,
                lambda name: resolved_values[name]
                if name in resolved_values
                else _raise_unresolved_symbol(name),
                environment,
            )
        except (BindingResolutionError, KeyError) as error:
            problems.append("unresolved module expression in " + resource_key)
            return None

    if tree.get("globals", {}).get("scope", {}).get("value") != "resourceGroup":
        problems.append("only resource-group scope is qualified")
    resources = tree.get("resources", {})
    if not isinstance(resources, dict) or not resources:
        return [], 0, problems + ["empty or malformed source inventory"]

    parents = {}
    children = []
    cosmos_parents = {}
    cosmos_children = []
    no_policy_symbols = set()
    cosmos_names = set()
    site_names = set()
    for symbol, resource in resources.items():
        if not isinstance(resource, dict):
            problems.append("malformed resource AST")
            continue
        kind = resource.get("type")
        conf = resource.get("config")
        key = str(kind) + "." + str(symbol)
        if set(resource) != {"decorators", "type", "api_version", "existing", "config"}:
            problems.append("conditions and loops are outside the resource contract: " + key)
        if not isinstance(conf, dict) or resource.get("existing") is not False:
            problems.append("unsupported or malformed resource: " + key)
            continue
        if kind == SITE:
            if resource.get("api_version") != API_VERSION:
                problems.append("unsupported site API version: " + key)
            name = resolve(conf.get("name"), key)
            properties = resolve(conf.get("properties"), key)
            identity = resolve(conf.get("identity"), key)
            valid_site_properties = isinstance(properties, dict) and (
                set(properties) == {"publicNetworkAccess"}
                or set(properties) == {"publicNetworkAccess", "siteConfig"}
            )
            if valid_site_properties and "siteConfig" in properties:
                site_config = properties["siteConfig"]
                cors = site_config.get("cors") if isinstance(site_config, dict) else None
                valid_site_properties = (
                    set(site_config) == {"cors"}
                    and isinstance(cors, dict)
                    and set(cors) == {"allowedOrigins"}
                    and isinstance(cors["allowedOrigins"], list)
                    and all(_literal_string(origin) for origin in cors["allowedOrigins"])
                )
            if (
                set(conf) != {"name", "properties", "identity"}
                or type(name) is not str or not name or "${" in name
                or not valid_site_properties
                or type(properties.get("publicNetworkAccess")) is not str
                or properties["publicNetworkAccess"] not in ("Enabled", "Disabled")
                or not _literal_identity(identity)
            ):
                problems.append("site is outside the literal ingress/identity contract: " + key)
            if type(name) is str and name in site_names:
                problems.append("duplicate authored site name: " + key)
            if type(name) is str:
                site_names.add(name)
            parents[symbol] = key
            entries.extend(
                dict(resource=key, check=check, expected="APPLICABLE", parent=None)
                for check in SITE_CHECKS
            )
        elif kind == CONFIG:
            if resource.get("api_version") != API_VERSION:
                problems.append("unsupported site config API version: " + key)
            name = resolve(conf.get("name"), key)
            parent = conf.get("parent")
            properties = resolve(conf.get("properties"), key)
            if (
                set(conf) != {"name", "parent", "properties"}
                or type(name) is not str or name not in ("appsettings", "authsettings", "web")
                or type(parent) is not BicepElement
                or not isinstance(properties, dict)
            ):
                problems.append("unknown config subtype or nonliteral parent: " + key)
            elif name == "appsettings":
                if any(type(k) is not str or type(v) is not str or "${" in k or "${" in v
                       for k, v in properties.items()):
                    problems.append("appsettings must be a literal StringDictionary: " + key)
            elif name == "authsettings":
                if set(properties) != {"enabled"} or type(properties.get("enabled")) is not bool:
                    problems.append("authsettings must contain only literal enabled: " + key)
            elif not _literal_web(properties):
                problems.append("web config is outside the literal property contract: " + key)
            children.append((symbol, key, name, parent))
        elif kind == COSMOS:
            if resource.get("api_version") != COSMOS_API_VERSION:
                problems.append("unsupported Cosmos API version: " + key)
            name = resolve(conf.get("name"), key)
            properties = resolve(conf.get("properties"), key)
            location = resolve(conf.get("location"), key) if "location" in conf else None
            tags = resolve(conf.get("tags"), key) if "tags" in conf else None
            if (
                set(conf) - {"name", "properties", "location", "tags", "kind"}
                or not _literal_string(conf.get("kind")) or conf["kind"] != "GlobalDocumentDB"
                or ("location" in conf and (not _literal_string(location) or not location))
                or ("tags" in conf and (
                    not isinstance(tags, dict)
                    or any(not _literal_string(k) or not _literal_string(v) for k, v in tags.items())
                ))
                or type(name) is not str or not name or "${" in name
                or not _literal_cosmos(properties)
            ):
                problems.append("Cosmos resource is outside the literal network contract: " + key)
            if type(name) is str and name in cosmos_names:
                problems.append("duplicate authored Cosmos account name: " + key)
            if type(name) is str:
                cosmos_names.add(name)
            cosmos_parents[symbol] = key
            entries.extend(
                dict(
                    resource=key, check=check, expected="APPLICABLE", parent=None,
                    policy_inputs={
                        **({"kind": conf.get("kind")} if check == "CKV_AZURE_140" else {}),
                        "properties": {
                            field: properties[field] for field in COSMOS_INPUTS[check]
                            if isinstance(properties, dict) and field in properties
                        },
                    },
                )
                for check in COSMOS_CHECKS
            )
            if _materialized is not None:
                materialized = {"name": name, "kind": conf.get("kind"), "properties": properties}
                if "location" in conf:
                    materialized["location"] = location
                if "tags" in conf:
                    materialized["tags"] = tags
                _materialized.append({
                    "symbol": symbol, "type": kind, "api_version": resource.get("api_version"),
                    "config": materialized, "source_identity": key,
                })
        elif kind in (COSMOS_DATABASE, COSMOS_CONTAINER):
            no_policy_symbols.add(symbol)
            if resource.get("api_version") != COSMOS_API_VERSION:
                problems.append("unsupported Cosmos child API version: " + key)
            loop = conf.get("loop_type")
            if loop is None:
                configurations = [(key, conf)]
            elif kind == COSMOS_CONTAINER:
                detail = loop.get("detail") if isinstance(loop, dict) else None
                values = resolved_values or {}
                if (
                    set(conf) != {"loop_type", "condition", "config"}
                    or conf["condition"] is not None
                    or not isinstance(loop, dict) or set(loop) != {"type", "detail"}
                    or loop["type"] != "array" or not isinstance(detail, dict)
                    or set(detail) != {"item_name", "array_name"}
                    or type(detail["item_name"]) is not str
                    or type(detail["array_name"]) is not BicepElement
                    or not isinstance(values.get(str(detail["array_name"])), list)
                    or not 0 < len(values[str(detail["array_name"])]) <= 1000
                ):
                    problems.append("unresolved or unsupported Cosmos container loop: " + key)
                    continue
                configurations = []
                for index, item in enumerate(values[str(detail["array_name"])]):
                    instance_key = key + "[" + str(index) + "]"
                    body = conf["config"]
                    if not isinstance(body, dict):
                        problems.append("malformed Cosmos loop body: " + key)
                        break
                    try:
                        resolved = _resolve_expression(
                            {k: v for k, v in body.items() if k != "parent"},
                            lambda name: item if name == detail["item_name"] else (
                                values[name] if name in values else _raise_unresolved_symbol(name)
                            ),
                            environment,
                        )
                        configurations.append((instance_key, {**resolved, "parent": body.get("parent")}))
                    except BindingResolutionError:
                        problems.append("unresolved Cosmos container body: " + instance_key)
            else:
                problems.append("Cosmos database loops are outside this contract: " + key)
                continue
            for instance_key, body in configurations:
                if not isinstance(body, dict):
                    problems.append("malformed Cosmos child body: " + instance_key)
                    continue
                name = resolve(body.get("name"), instance_key)
                properties = resolve(body.get("properties"), instance_key)
                parent = body.get("parent")
                if (
                    set(body) != {"name", "parent", "properties"}
                    or type(parent) is not BicepElement
                    or not _literal_string(name) or not name
                    or not isinstance(properties, dict) or set(properties) != {"resource"}
                    or not isinstance(properties["resource"], dict)
                    or properties["resource"].get("id") != name
                    or (kind == COSMOS_DATABASE and set(properties["resource"]) != {"id"})
                    or (kind == COSMOS_CONTAINER and set(properties["resource"]) - {
                        "id", "partitionKey", "indexingPolicy", "defaultTtl",
                    })
                ):
                    problems.append("Cosmos child is outside the bounded literal contract: " + instance_key)
                cosmos_children.append((symbol, instance_key, kind, name, parent))
                if _materialized is not None:
                    suffix = instance_key.removeprefix(key)
                    rendered_symbol = symbol + ("_" + suffix[1:-1] if suffix else "")
                    _materialized.append({
                        "symbol": rendered_symbol, "type": kind,
                        "api_version": resource.get("api_version"),
                        "config": {"parent": parent, "name": name, "properties": properties},
                        "source_identity": instance_key,
                    })
        else:
            problems.append("resource type has no qualified mapping: " + key)

    databases = {
        symbol: key for symbol, key, kind, _, _ in cosmos_children
        if kind == COSMOS_DATABASE
    }
    child_identities = set()
    for symbol, key, kind, name, parent in cosmos_children:
        parent_map = cosmos_parents if kind == COSMOS_DATABASE else databases
        if type(parent) is not BicepElement or str(parent) not in parent_map:
            problems.append("missing or unresolved Cosmos child parent: " + key)
            continue
        if type(name) is str:
            identity = (kind, str(parent), name)
            if identity in child_identities:
                problems.append("duplicate Cosmos child name: " + key)
            child_identities.add(identity)
        entries.append(dict(
            resource=key, check=None, expected="NO_POLICY_IN_PINNED_RUNNER",
            parent=parent_map[str(parent)], source_symbol=symbol, name=name,
        ))

    child_names = set()
    for symbol, key, name, parent in children:
        if type(parent) is not BicepElement or parent not in parents:
            problems.append("missing or unresolved site parent: " + key)
            continue
        if type(name) is not str:
            continue
        identity = (parent, name)
        if identity in child_names:
            problems.append("duplicate site config subtype: " + key)
        child_names.add(identity)
        parent_key = parents[parent]
        entries.extend(
            dict(
                resource=key,
                check=check,
                expected="APPLICABLE" if CONFIG_CHECKS[check] == name else "NOT_APPLICABLE",
                parent=parent_key,
                subtype=name,
            )
            for check in sorted(CONFIG_CHECKS)
        )
    return entries, len(resources) - len(no_policy_symbols), problems


def _required_proofs(entry, entries):
    check = entry["check"]
    parent = entry["parent"]
    if check == "CKV_AZURE_222":
        return [
            (parent, "CKV_AZURE_222"),
            *(
                (candidate["resource"], check)
                for candidate in entries
                if candidate.get("parent") == parent and candidate.get("subtype") == "web"
                and candidate["check"] == check
            ),
        ]
    proof_subtype = CONFIG_CHECKS[check]
    return [
        (candidate["resource"], check)
        for candidate in entries
        if candidate.get("parent") == parent and candidate.get("subtype") == proof_subtype
        and candidate["check"] == check
    ]


def reconcile(entries, resource_count, report):
    """Keep raw Checkov evidence intact; qualify NA only with passed sibling proof."""
    problems = []
    raw = {}
    if not isinstance(report, dict):
        return [], ["malformed scanner report"]
    results = report.get("results")
    summary = report.get("summary")
    if not isinstance(results, dict) or not isinstance(summary, dict):
        return [], ["missing scanner results or summary"]
    if report.get("check_type") != "bicep" or summary.get("checkov_version") != "3.2.495":
        problems.append("unexpected framework or candidate version")
    paths = []
    for key, status in (("passed_checks", "PASSED"), ("failed_checks", "FAILED")):
        records = results.get(key)
        if not isinstance(records, list):
            problems.append("missing result list")
            continue
        count = summary.get("passed" if status == "PASSED" else "failed")
        if type(count) is not int or count != len(records):
            problems.append("summary/evidence mismatch")
        for record in records:
            if not isinstance(record, dict):
                problems.append("malformed scanner record")
                continue
            result = record.get("check_result")
            if not isinstance(result, dict):
                problems.append("malformed scanner result status")
                continue
            pair = (record.get("resource"), record.get("check_id"))
            if any(type(value) is not str or not value for value in pair):
                problems.append("malformed scanner resource/check identity")
                continue
            if pair in raw:
                problems.append("duplicate result")
            if result.get("result") != status:
                problems.append("inconsistent result status")
            raw[pair] = status
            paths.append(record.get("file_path"))
    if len(paths) == 0 or any(not isinstance(path, str) or not path for path in paths) or len(set(paths)) != 1:
        problems.append("single-file effective coverage required")
    for key, count_key in (("parsing_errors", "parsing_errors"), ("skipped_checks", "skipped")):
        count = summary.get(count_key)
        if results.get(key) != [] or type(count) is not int or count != 0:
            problems.append("parsing or skipped evidence")
    checked = [entry for entry in entries if entry["expected"] != "NO_POLICY_IN_PINNED_RUNNER"]
    expected = {(entry["resource"], entry["check"]) for entry in checked}
    if not expected or len(expected) != len(checked) or set(raw) != expected:
        problems.append("missing, duplicate or unexpected resource/check obligation")
    if type(summary.get("resource_count")) is not int or summary["resource_count"] != resource_count:
        problems.append("source/report resource cardinality mismatch")

    qualified = []
    for entry in entries:
        if entry["expected"] == "NO_POLICY_IN_PINNED_RUNNER":
            qualified.append({
                **entry, "status": "NO_POLICY_IN_PINNED_RUNNER", "scanner_status": None,
                "reason": "sealed dispatch has no Python/graph policy for this type; not a security verdict",
            })
            continue
        pair = (entry["resource"], entry["check"])
        outcome = raw.get(pair)
        if outcome is None:
            status, reason = "BLOCKED", "expected scanner evidence absent, including possible UNKNOWN"
        elif entry["expected"] == "NOT_APPLICABLE":
            required = _required_proofs(entry, entries)
            evidence = [
                {"resource": resource, "check": check, "scanner_status": raw.get((resource, check))}
                for resource, check in required
            ]
            if not required or any(item["scanner_status"] != "PASSED" for item in evidence):
                status, reason = "BLOCKED", "applicable same-site parent verdict missing or not PASSED"
                problems.append("non-applicable check lacks a passed same-site parent proof")
            else:
                status, reason = "NOT_APPLICABLE", "the authored config subtype does not own this property"
            qualified.append({**entry, "status": status, "reason": reason, "scanner_status": outcome,
                              "applicability_evidence": evidence})
            continue
        else:
            status, reason = outcome, "unmodified Checkov verdict for an applicable resource"
            if status == "FAILED":
                problems.append("applicable check failed: " + entry["check"])
        qualified.append({**entry, "status": status, "reason": reason, "scanner_status": outcome})
    return qualified, problems


def _verify_runtime():
    if version("checkov") != VERSION:
        raise ValueError("requires existing pinned Checkov candidate")
    _verify_parser()
    import checkov.bicep.checks.resource.base_registry as registry

    if hashlib.sha256(Path(registry.__file__).read_bytes()).hexdigest() != REGISTRY_SHA256:
        raise ValueError("unexpected installed Bicep dispatch implementation")
    for relative, expected in RULE_SOURCES.items():
        module_name = relative.removesuffix(".py").replace("/", ".")
        path = Path(import_module(module_name).__file__)
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise ValueError("unexpected installed Checkov resource rule: " + relative)
    _verify_cosmos_dispatch()


def _verify_cosmos_dispatch():
    """Reject new/wildcard dispatch before a pinned no-policy child can be claimed."""
    from checkov.bicep.checks.resource.registry import registry

    def graph_matches(check, kind):
        return (
            any(fnmatchcase(kind, pattern) for pattern in (
                *check.resource_types, *check.connected_resources_types,
            ))
            or any(graph_matches(child, kind) for child in check.sub_checks)
        )

    for kind, expected in (
        (COSMOS, set(COSMOS_CHECKS)), (COSMOS_DATABASE, set()), (COSMOS_CONTAINER, set()),
    ):
        actual = [check.id for check in registry.get_checks(kind)]
        if len(actual) != len(set(actual)) or set(actual) != expected or any(
            graph_matches(check, kind) for check in registry.graph_registry.checks
        ):
            raise ValueError("unqualified Cosmos policy dispatch: " + kind)


def _same_literal(left, right, allow_symbols=False):
    if type(left) is not type(right):
        return False
    if type(left) is dict:
        return set(left) == set(right) and all(
            _same_literal(left[k], right[k], allow_symbols) for k in left
        )
    if type(left) is list:
        return len(left) == len(right) and all(
            _same_literal(a, b, allow_symbols) for a, b in zip(left, right)
        )
    return (
        type(left) in (str, bool, int, type(None))
        or (allow_symbols and type(left) is BicepElement)
    ) and left == right


def _cosmos_runner_inputs(entries, definitions):
    """Compare input provenance, not policy outcomes, with type-strict literals."""
    resources = {}
    for source in definitions.values():
        for symbol, node in source.get("resources", {}).items():
            if node.get("type") == COSMOS:
                resources.setdefault(COSMOS + "." + symbol, []).append(node.get("config"))
    proofs = []
    for entry in entries:
        if "policy_inputs" not in entry:
            continue
        candidates = resources.get(entry["resource"], [])
        config = candidates[0] if len(candidates) == 1 and isinstance(candidates[0], dict) else {}
        properties = config.get("properties")
        actual = {
            **({"kind": config.get("kind")} if entry["check"] == "CKV_AZURE_140" else {}),
            "properties": {
                field: properties[field] for field in COSMOS_INPUTS[entry["check"]]
                if isinstance(properties, dict) and field in properties
            },
        }
        proofs.append({
            "resource": entry["resource"], "check": entry["check"],
            "matches_bound_ast": len(candidates) == 1 and isinstance(properties, dict)
            and _same_literal(entry["policy_inputs"], actual),
        })
    return proofs


def qualify(path, environment, instance="root"):
    """Parse independent obligations, execute real Runner on the same bytes, reconcile."""
    _verify_runtime()
    contents = path.read_bytes()
    provenance = dict(
        source=str(path.resolve()),
        sha256=hashlib.sha256(contents).hexdigest(),
        environment=environment,
        module_instance=instance,
        parameters="none; declarations rejected",
        candidate_version=VERSION,
        parser=_verify_parser(),
    )
    try:
        source = contents.decode("utf-8")
    except UnicodeError as error:
        return dict(
            schema="certigo.bicep-appservice-qualification/v2",
            scope="bounded App Service controls and all pinned Cosmos account rules",
            production_adoptable=False,
            provenance=provenance,
            obligations=[],
            status="BLOCKED",
            blockers=["source is not UTF-8: " + type(error).__name__],
            applicability=[],
            scanner_report=None,
        )
    entries, resource_count, problems = inventory(source, environment, instance)
    raw = None
    qualified = []
    if not problems:
        with tempfile.TemporaryDirectory(prefix="certigo-bicep-appservice-") as temporary:
            snapshot = Path(temporary) / "source.bicep"
            snapshot.write_bytes(contents)
            report = Runner().run(
                root_folder=temporary,
                files=[str(snapshot)],
                runner_filter=RunnerFilter(checks=list(CHECKS), show_progress_bar=False),
            )
            raw = report.get_dict()
        qualified, problems = reconcile(entries, resource_count, raw)
    return dict(
        schema="certigo.bicep-appservice-qualification/v2",
        scope="bounded App Service controls and all pinned Cosmos account rules; not global compliance",
        production_adoptable=False,
        provenance=provenance,
        obligations=entries,
        status="BLOCKED" if problems else "QUALIFIED_SUBSET",
        blockers=problems,
        applicability=qualified,
        scanner_report=raw,
    )


def qualify_local_module(path, environment, module_symbol="api"):
    """Qualify one local module call without flattening or rewriting its source."""
    _verify_runtime()
    binding = resolve_local_module_bindings(path, environment, module_symbol)
    return _qualify_bound_module(binding)


def _qualify_bound_module(binding):
    environment = binding["environment"]
    module_symbol = binding["module_symbol"]
    binding_summary = {
        key: value for key, value in binding.items() if key != "values" and not key.startswith("_")
    }
    blockers = list(binding["blockers"])
    module_source = binding.get("module_source")
    if module_source is None:
        return {
            "schema": "certigo.bicep-appservice-qualification/v3",
            "scope": "one local binding, bounded App Service/Cosmos resources and explicit no-policy children",
            "production_adoptable": False,
            "provenance": {
                "root_source": binding["root_source"],
                "root_sha256": binding["root_sha256"],
                "environment": environment,
                "module_instance": "root/" + module_symbol,
                "candidate_version": VERSION,
                "parser": _verify_parser(),
            },
            "binding_resolution": binding_summary,
            "obligations": [],
            "status": "BLOCKED",
            "blockers": blockers,
            "applicability": [],
            "scanner_report": None,
        }
    module_path = Path(module_source)
    module_bytes = binding["_module_bytes"]
    try:
        source = module_bytes.decode("utf-8")
    except UnicodeError as error:
        blockers.append("module source is not UTF-8: " + type(error).__name__)
        source = ""
    entries, resource_count, inventory_problems = (
        binding["_inventory"] if "_inventory" in binding else inventory(
            source, environment, "root/" + module_symbol, binding["values"]
        )
    )
    blockers.extend(inventory_problems)
    raw = None
    qualified = []
    input_proofs = []
    if not blockers:
        with tempfile.TemporaryDirectory(prefix="certigo-bicep-module-") as temporary:
            snapshot = Path(temporary) / module_path.name
            snapshot.write_bytes(module_bytes)
            runner = Runner()
            report = runner.run(
                root_folder=temporary,
                files=[str(snapshot)],
                runner_filter=RunnerFilter(checks=list(CHECKS), show_progress_bar=False),
            )
            raw = report.get_dict()
            input_proofs = _cosmos_runner_inputs(entries, runner.definitions)
        qualified, report_problems = reconcile(entries, resource_count, raw)
        blockers.extend(report_problems)
        mismatched = {
            (proof["resource"], proof["check"]) for proof in input_proofs
            if not proof["matches_bound_ast"]
        }
        blockers.extend(
            "Runner inputs differ from bound AST: " + resource + "/" + check
            for resource, check in sorted(mismatched)
        )
        for row in qualified:
            if (row["resource"], row["check"]) in mismatched and row["status"] == "PASSED":
                row["status"] = "BLOCKED"
                row["reason"] = "raw PASSED does not prove the explicitly bound policy inputs"
    return {
        "schema": "certigo.bicep-appservice-qualification/v3",
        "scope": "one local binding, bounded App Service/Cosmos resources and explicit no-policy children; not root-wide",
        "production_adoptable": False,
        "provenance": {
            "root_source": binding["root_source"],
            "root_sha256": binding["root_sha256"],
            "module_source": str(module_path),
            "module_sha256": binding["module_sha256"],
            "environment": environment,
            "module_instance": "root/" + module_symbol,
            "candidate_version": VERSION,
            "parser": _verify_parser(),
        },
        "binding_resolution": binding_summary,
        "obligations": entries,
        "status": "BLOCKED" if blockers else "QUALIFIED_SUBSET",
        "blockers": list(dict.fromkeys(blockers)),
        "applicability": qualified,
        "scanner_input_provenance": input_proofs,
        "scanner_report": raw,
    }


def qualify_local_modules(path, environment, module_symbols):
    """Inventory all root calls; bind every selected instance before any Runner."""
    _verify_runtime()
    path = Path(path).resolve(strict=True)
    contents = path.read_bytes()
    result = {
        "schema": "certigo.bicep-appservice-qualification/v4",
        "scope": "explicit selected local module instances; not root-wide or deployment compliance",
        "production_adoptable": False,
        "provenance": {
            "root_source": str(path),
            "root_sha256": hashlib.sha256(contents).hexdigest(),
            "environment": environment,
            "candidate_version": VERSION,
            "parser": _verify_parser(),
        },
        "root_inventory": {"module_calls": [], "resources": []},
        "modules": [],
        "status": "BLOCKED",
        "blockers": [],
    }
    if not module_symbols or len(set(module_symbols)) != len(module_symbols):
        result["blockers"].append("an explicit nonempty unique module selection is required")
        return result
    try:
        root = _parse_source(contents.decode("utf-8"))
    except Exception as error:
        result["blockers"].append("root source parsing failed: " + type(error).__name__)
        return result
    calls = root.get("modules", {})
    result["root_inventory"]["module_calls"] = [
        {
            "symbol": symbol,
            "type": node.get("type"),
            "path": node.get("detail", {}).get("path"),
            "selected": symbol in module_symbols,
        }
        for symbol, node in calls.items()
    ]
    result["root_inventory"]["resources"] = [
        {"symbol": symbol, "type": node.get("type"), "qualified": False}
        for symbol, node in root.get("resources", {}).items()
    ]
    module_snapshots = {}
    json_snapshots = {}
    bindings = [
        resolve_local_module_bindings(
            path, environment, symbol, _snapshot=(contents, root), _module_snapshots=module_snapshots,
            _json_snapshots=json_snapshots,
        )
        for symbol in module_symbols
    ]
    for binding in bindings:
        if "_module_bytes" in binding:
            try:
                source = binding["_module_bytes"].decode("utf-8")
            except UnicodeError:
                source = ""
            binding["_inventory"] = inventory(
                source, environment, "root/" + binding["module_symbol"], binding["values"]
            )
    # A selected module cannot disappear behind a different module's passing records.
    result["modules"] = [_qualify_bound_module(binding) for binding in bindings]
    for module in result["modules"]:
        instance = module["provenance"]["module_instance"]
        result["blockers"].extend(instance + ": " + reason for reason in module["blockers"])
    if not result["blockers"]:
        result["status"] = "QUALIFIED_SUBSET"
    return result


def _render_literal(value, depth=0):
    indent = "  " * depth
    if type(value) is BicepElement:
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", value) is None:
            raise BindingResolutionError("snapshot parent is not a literal symbol")
        return str(value)
    if type(value) is str:
        if "${" in value or any(character in value for character in "\\'\r\n\t"):
            raise BindingResolutionError("snapshot strings requiring escaping are outside this contract")
        return "'" + value + "'"
    if value is None:
        return "null"
    if type(value) is bool:
        return "true" if value else "false"
    if type(value) is int:
        return str(value)
    if type(value) is list:
        return "[\n" + "\n".join(
            indent + "  " + _render_literal(item, depth + 1) for item in value
        ) + "\n" + indent + "]"
    if type(value) is dict:
        lines = []
        for key, item in value.items():
            if type(key) is not str:
                raise BindingResolutionError("snapshot object key is not literal")
            rendered = key if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key) else _render_literal(key)
            lines.append(indent + "  " + rendered + ": " + _render_literal(item, depth + 1))
        return "{\n" + "\n".join(lines) + "\n" + indent + "}"
    raise BindingResolutionError("snapshot contains an unresolved or unsupported value")


def qualify_cosmos_snapshot(path, environment, backup_mode):
    """Opt-in, separately reported Runner pass over proven literal Cosmos inputs."""
    _verify_runtime()
    if backup_mode not in ("Periodic", "Continuous"):
        raise ValueError("an explicit Periodic or Continuous Cosmos backup mode is required")
    binding = resolve_local_module_bindings(
        path, environment, "data", _root_values={"cosmosBackupMode": backup_mode},
        _symbolic_name=True,
    )
    materialized = []
    try:
        source = binding.get("_module_bytes", b"").decode("utf-8")
    except UnicodeError:
        source = ""
        binding["blockers"].append("module source is not UTF-8")
    binding["_inventory"] = inventory(
        source, environment, "root/data", binding["values"], _materialized=materialized,
    )
    entries, count, problems = binding["_inventory"]
    if (
        not materialized
        or any(item["type"] not in (COSMOS, COSMOS_DATABASE, COSMOS_CONTAINER) for item in materialized)
        or sum(item["type"] == COSMOS for item in materialized) != 1
        or len({item["symbol"] for item in materialized}) != len(materialized)
    ):
        problems.append("resolved snapshot only supports one account and its explicit Cosmos children")
    authored = _qualify_bound_module(binding)
    result = {
        "schema": "certigo.bicep-cosmos-resolved-qualification/v5",
        "scope": "explicit Cosmos scenario; symbolic non-network name; not deployment evidence",
        "production_adoptable": False,
        "provenance": authored["provenance"],
        "binding_resolution": authored["binding_resolution"],
        "obligations": entries,
        "authored_report": authored["scanner_report"],
        "authored_applicability": authored["applicability"],
        "authored_blockers": authored["blockers"],
        "resolved_snapshot": None,
        "resolved_report": None,
        "resolved_applicability": [],
        "resolved_input_provenance": [],
        "status": "BLOCKED", "blockers": [],
    }
    if binding["blockers"] or problems or authored["scanner_report"] is None:
        result["blockers"] = list(dict.fromkeys(binding["blockers"] + problems + authored["blockers"]))
        return result
    # An approved second pass may resolve a raw failure, never missing/UNKNOWN coverage.
    _, raw_problems = reconcile(entries, count, authored["scanner_report"])
    allowed_failures = {"applicable check failed: " + check for check in COSMOS_CHECKS}
    result["blockers"] = [problem for problem in raw_problems if problem not in allowed_failures]
    if result["blockers"]:
        return result
    lines = []
    source_map = []
    try:
        for item in materialized:
            rendered = (
                "resource " + item["symbol"] + " '"
                + item["type"] + "@" + item["api_version"] + "' = "
                + _render_literal(item["config"])
            ).splitlines()
            source_map.append({
                "source_identity": item["source_identity"],
                "snapshot_symbol": item["symbol"],
                "snapshot_line_range": [len(lines) + 1, len(lines) + len(rendered)],
            })
            lines.extend(rendered)
    except BindingResolutionError as error:
        result["blockers"].append("snapshot rendering blocked: " + str(error))
        return result
    snapshot_bytes = ("\n".join(lines) + "\n").encode("utf-8")
    try:
        snapshot_ast = _parse_source(snapshot_bytes.decode("utf-8"))
        for node in snapshot_ast.get("resources", {}).values():
            config = node["config"]
            node["config"] = {
                **_resolve_expression(
                    {k: v for k, v in config.items() if k != "parent"},
                    _raise_unresolved_symbol, environment,
                ),
                **({"parent": config["parent"]} if "parent" in config else {}),
            }
    except Exception as error:
        result["blockers"].append("snapshot parsing failed: " + type(error).__name__)
        return result
    expected_resources = {
        item["symbol"]: {
            "decorators": [], "type": item["type"], "api_version": item["api_version"],
            "existing": False, "config": item["config"],
        } for item in materialized
    }
    if (
        set(snapshot_ast) - {"globals", "resources"}
        or not _same_literal(snapshot_ast.get("resources"), expected_resources, allow_symbols=True)
    ):
        result["blockers"].append("snapshot AST does not exactly reproduce the independent resource inventory")
        return result
    result["resolved_snapshot"] = {
        "sha256": hashlib.sha256(snapshot_bytes).hexdigest(),
        "source_text": snapshot_bytes.decode("utf-8"),
        "source_map": source_map,
        "symbolic_inputs": binding["symbolic_inputs"],
        "explicit_root_parameters": binding["explicit_root_parameters"],
        "actual_deployment_parameters_verified": False,
        "ast_round_trip_verified": True,
    }
    with tempfile.TemporaryDirectory(prefix="certigo-cosmos-resolved-") as temporary:
        snapshot = Path(temporary) / "resolved.bicep"
        snapshot.write_bytes(snapshot_bytes)
        runner = Runner()
        raw = runner.run(
            root_folder=temporary, files=[str(snapshot)],
            runner_filter=RunnerFilter(checks=list(COSMOS_CHECKS), show_progress_bar=False),
        ).get_dict()
        proofs = _cosmos_runner_inputs(entries, runner.definitions)
    result["resolved_report"] = raw
    result["resolved_input_provenance"] = proofs
    result["resolved_applicability"], blockers = reconcile(entries, count, raw)
    result["blockers"].extend(blockers)
    for proof in proofs:
        if not proof["matches_bound_ast"]:
            result["blockers"].append("resolved Runner inputs differ: " + proof["check"])
            for row in result["resolved_applicability"]:
                if (
                    row["resource"] == proof["resource"] and row["check"] == proof["check"]
                    and row["status"] == "PASSED"
                ):
                    row["status"] = "BLOCKED"
                    row["reason"] = "raw PASSED does not prove the explicitly bound policy inputs"
    if not result["blockers"]:
        result["status"] = "QUALIFIED_SUBSET"
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--environment", required=True, choices=("dev", "staging", "prod"))
    parser.add_argument("--module-symbol", action="append")
    parser.add_argument("--resolved-cosmos-snapshot", action="store_true")
    parser.add_argument("--cosmos-backup-mode", choices=("Periodic", "Continuous"))
    args = parser.parse_args()
    if args.resolved_cosmos_snapshot:
        if args.module_symbol != ["data"] or args.cosmos_backup_mode is None:
            parser.error("resolved Cosmos mode requires --module-symbol data and an explicit --cosmos-backup-mode")
        result = qualify_cosmos_snapshot(args.source, args.environment, args.cosmos_backup_mode)
    elif args.cosmos_backup_mode is not None:
        parser.error("--cosmos-backup-mode requires --resolved-cosmos-snapshot")
    elif args.module_symbol and len(args.module_symbol) > 1:
        result = qualify_local_modules(args.source, args.environment, args.module_symbol)
    elif args.module_symbol:
        result = qualify_local_module(args.source, args.environment, args.module_symbol[0])
    else:
        result = qualify(args.source, args.environment)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 1 if result["status"] == "BLOCKED" else 0


if __name__ == "__main__":
    sys.exit(main())
