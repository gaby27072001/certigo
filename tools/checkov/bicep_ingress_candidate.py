"""Inactive Bicep applicability qualification with explicit local-module provenance."""

import argparse
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

from build_checkov_wheel import VERSION
from build_parser_wheel import PATCHED_FILES, VERSION as COMPAT_PARSER_VERSION


SITE = "Microsoft.Web/sites"
CONFIG = SITE + "/config"
COSMOS = "Microsoft.DocumentDB/databaseAccounts"
SITE_CHECKS = ("CKV_AZURE_16", "CKV_AZURE_222")
CONFIG_CHECKS = {
    "CKV_AZURE_13": "authsettings",
    "CKV_AZURE_80": "web",
    "CKV_AZURE_66": "web",
    "CKV_AZURE_63": "web",
    "CKV_AZURE_222": "web",
    "CKV_AZURE_88": "web",
}
CHECKS = tuple(sorted({*SITE_CHECKS, *CONFIG_CHECKS, "CKV_AZURE_99"}))
API_VERSION = "2024-04-01"
COSMOS_API_VERSION = "2024-11-15"

RULE_SOURCES = {
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


def _resolve_expression(expression, resolve_symbol, environment):
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
        return [_resolve_expression(value, resolve_symbol, environment) for value in expression]
    if isinstance(expression, dict):
        if "function" in expression:
            raise BindingResolutionError("function calls are outside the static binding contract")
        operator = expression.get("operator")
        if isinstance(operator, dict):
            operands = operator.get("operands")
            if (
                operator.get("type") == "equals"
                and isinstance(operands, dict)
                and set(operands) == {"operand_1", "operand_2"}
                and isinstance(operands["operand_1"], BicepElement)
                and str(operands["operand_1"]) == "env"
                and isinstance(operands["operand_2"], dict)
            ):
                conditional = operands["operand_2"].get("operator")
                branches = conditional.get("operands") if isinstance(conditional, dict) else None
                if (
                    isinstance(conditional, dict)
                    and conditional.get("type") == "conditional"
                    and isinstance(branches, dict)
                    and set(branches) == {"condition", "true_value", "false_value"}
                    and type(branches["condition"]) is str
                    and branches["condition"] in ("dev", "staging", "prod")
                ):
                    branch = "true_value" if environment == branches["condition"] else "false_value"
                    return _resolve_expression(branches[branch], resolve_symbol, environment)
            raise BindingResolutionError("operator is outside the literal/environment contract")
        return {
            key: _resolve_expression(value, resolve_symbol, environment)
            for key, value in expression.items()
        }
    if expression is None:
        raise BindingResolutionError("null is not a resolved parameter value")
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


def resolve_local_module_bindings(
    root_path, environment, module_symbol="api", *, _snapshot=None, _module_snapshots=None,
):
    """Resolve one local module call using only literals and bounded env ternaries."""
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
    if set(module) - {"globals", "parameters", "variables", "resources"}:
        result["blockers"].append("nested modules and outputs are outside this module contract")
    if not isinstance(module.get("resources"), dict) or not module["resources"]:
        result["blockers"].append("module has no statically inventoried resources")

    root_parameters = root.get("parameters", {})
    root_variables = root.get("variables", {})

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
            default = spec.get("default")
            if default is None:
                raise BindingResolutionError("root parameter has no literal deployment value")
            value = default
        elif name in root_variables:
            value = root_variables[name].get("value")
        else:
            raise BindingResolutionError("root symbol is not a literal parameter or variable")
        resolved = _resolve_expression(
            value, lambda nested: resolve_root_symbol(nested, active + (name,)), environment
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
            value = _resolve_expression(expression, resolver, environment)
            if not _matches_parameter_type(value, spec.get("type")):
                resolving.remove(name)
                raise BindingResolutionError("resolved value does not match the declared module type")
            values[name] = value
            resolving.remove(name)
            return value
        if name in module.get("variables", {}):
            resolving.add(name)
            value = _resolve_expression(
                module["variables"][name].get("value"), resolve_module_symbol, environment
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
    }
    if (
        not isinstance(properties, dict)
        or set(properties) - allowed
        or type(properties.get("publicNetworkAccess")) is not str
        or properties["publicNetworkAccess"] not in ("Enabled", "Disabled")
    ):
        return False
    for key in ("enableMultipleWriteLocations", "isVirtualNetworkFilterEnabled"):
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
    return True


def inventory(source, environment, instance, resolved_values=None):
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
        allowed_tree_keys |= {"parameters", "variables"}
    if set(tree) - allowed_tree_keys:
        problems.append("outputs and nested modules are outside this qualification")
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
            if (
                set(conf) != {"name", "properties"}
                or type(name) is not str or not name or "${" in name
                or not _literal_cosmos(properties)
            ):
                problems.append("Cosmos resource is outside the literal network contract: " + key)
            if type(name) is str and name in cosmos_names:
                problems.append("duplicate authored Cosmos account name: " + key)
            if type(name) is str:
                cosmos_names.add(name)
            entries.append(dict(resource=key, check="CKV_AZURE_99", expected="APPLICABLE", parent=None))
        else:
            problems.append("resource type has no qualified mapping: " + key)

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
    return entries, len(resources), problems


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
    expected = {(entry["resource"], entry["check"]) for entry in entries}
    if not expected or len(expected) != len(entries) or set(raw) != expected:
        problems.append("missing, duplicate or unexpected resource/check obligation")
    if type(summary.get("resource_count")) is not int or summary["resource_count"] != resource_count:
        problems.append("source/report resource cardinality mismatch")

    qualified = []
    for entry in entries:
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
            scope="literal root App Service applicability, managed identity and Cosmos network rules",
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
        scope="literal root App Service subtype applicability, identity and Cosmos network controls only",
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
            "scope": "one local root-to-module binding and literal resource subset",
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
    if not blockers:
        with tempfile.TemporaryDirectory(prefix="certigo-bicep-module-") as temporary:
            snapshot = Path(temporary) / module_path.name
            snapshot.write_bytes(module_bytes)
            report = Runner().run(
                root_folder=temporary,
                files=[str(snapshot)],
                runner_filter=RunnerFilter(checks=list(CHECKS), show_progress_bar=False),
            )
            raw = report.get_dict()
        qualified, report_problems = reconcile(entries, resource_count, raw)
        blockers.extend(report_problems)
    return {
        "schema": "certigo.bicep-appservice-qualification/v3",
        "scope": "one local root-to-module binding and literal resource subset; not root-wide",
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
    bindings = [
        resolve_local_module_bindings(
            path, environment, symbol, _snapshot=(contents, root), _module_snapshots=module_snapshots
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--environment", required=True, choices=("dev", "staging", "prod"))
    parser.add_argument("--module-symbol", action="append")
    args = parser.parse_args()
    if args.module_symbol and len(args.module_symbol) > 1:
        result = qualify_local_modules(args.source, args.environment, args.module_symbol)
    elif args.module_symbol:
        result = qualify_local_module(args.source, args.environment, args.module_symbol[0])
    else:
        result = qualify(args.source, args.environment)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 1 if result["status"] == "BLOCKED" else 0


if __name__ == "__main__":
    sys.exit(main())
