"""Create a new ignored, user-local Debug scheme without changing shared files."""

import argparse
import getpass
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import xml.etree.ElementTree as ET


KEYS = {
    "CERTIGO_CIAM_" + name
    for name in (
        "ENABLED", "CLIENT_ID", "TENANT_ID", "AUTHORITY", "ISSUER",
        "AUTHORITY_KIND", "API_BASE_URL", "API_SCOPE", "API_AUDIENCE", "REDIRECT_URI",
    )
}
DEFAULT_PROJECT = (
    Path(__file__).resolve().parents[1]
    / "apps/apple/CertigoNative/CertigoNative.xcodeproj"
)


def load_values(path):
    def unique_pairs(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError("Duplicate configuration key; no scheme created.")
            result[key] = value
        return result

    values = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique_pairs)
    if not isinstance(values, dict) or set(values) != KEYS:
        raise ValueError("Supply exactly the ten documented CERTIGO_CIAM keys, no secrets.")
    for key, value in values.items():
        if (
            not isinstance(value, str) or not value
            or any(c.isspace() or ord(c) < 32 for c in value)
            or any(c in value for c in ('\\', '"', "'", "$", "`"))
        ):
            raise ValueError(f"Invalid literal value for {key}; values are not printed.")
    if values["CERTIGO_CIAM_ENABLED"] != "true":
        raise ValueError("This opt-in scheme requires ENABLED to be exactly true.")
    if values["CERTIGO_CIAM_AUTHORITY_KIND"] not in ("standard", "customDomain"):
        raise ValueError("AUTHORITY_KIND must be standard or customDomain.")
    if values["CERTIGO_CIAM_REDIRECT_URI"] != "msauth.com.certigo.native.dev://auth":
        raise ValueError("Use the documented native development callback without a final slash.")
    return values


def create_scheme(project, values, username):
    if not re.fullmatch(r"[A-Za-z0-9_][A-Za-z0-9_.-]*", username):
        raise ValueError("Unsupported local username.")
    source = project / "xcshareddata/xcschemes/CertigoNative.xcscheme"
    target = project / "xcuserdata" / (username + ".xcuserdatad") / "xcschemes" / (
        "CertigoNative Local.xcscheme"
    )
    for relative in target.relative_to(project).parents:
        if (project / relative).is_symlink():
            raise ValueError("Refusing a symlink in the local scheme destination.")
    ignored = subprocess.run(
        ["git", "check-ignore", "--quiet", "--", str(target.absolute())],
        cwd=project, check=False, capture_output=True,
    )
    if ignored.returncode != 0:
        raise ValueError("Destination must be ignored and untracked in Git; no scheme created.")
    data = source.read_bytes()
    if b"<!DOCTYPE" in data or b"<!ENTITY" in data:
        raise ValueError("Unexpected shared scheme XML declaration.")
    root = ET.fromstring(data)
    launches = root.findall("LaunchAction")
    if root.tag != "Scheme" or len(launches) != 1:
        raise ValueError("Expected exactly one shared scheme Run action.")
    launch = launches[0]
    if launch.get("buildConfiguration") != "Debug":
        raise ValueError("Only a Debug Run action can be configured.")
    if launch.find("BuildableProductRunnable/BuildableReference") is None:
        raise ValueError("Shared Run action does not reference an application.")
    environments = launch.findall("EnvironmentVariables")
    if len(environments) > 1:
        raise ValueError("Ambiguous shared Run environment.")
    environment = environments[0] if environments else ET.SubElement(launch, "EnvironmentVariables")
    if any(
        element.get("key", "").startswith("CERTIGO_CIAM_")
        for element in environment
    ):
        raise ValueError("Shared scheme already contains CIAM values; review before proceeding.")
    for key in sorted(values):
        ET.SubElement(environment, "EnvironmentVariable", {
            "key": key, "value": values[key], "isEnabled": "YES",
        })
    ET.indent(root, space="   ")
    result = ET.tostring(root, encoding="utf-8", xml_declaration=True) + b"\n"
    target.parent.mkdir(parents=True, exist_ok=True)
    # Exclusive creation protects an existing user's scheme, including a dangling symlink.
    fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(fd, "wb") as output:
            output.write(result)
            output.flush()
            os.fsync(output.fileno())
    except OSError:
        target.unlink()
        raise
    return target


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True, type=Path, help="Local JSON, not committed")
    parser.add_argument("--project", type=Path, default=DEFAULT_PROJECT)
    args = parser.parse_args()
    try:
        values = load_values(args.config)
        target = create_scheme(args.project.resolve(), values, getpass.getuser())
    except (json.JSONDecodeError, UnicodeError, ET.ParseError):
        print(
            "STOP: invalid JSON encoding/syntax or shared scheme XML. No values are printed.",
            file=sys.stderr,
        )
        return 1
    except FileExistsError:
        print("STOP: local scheme already exists; keep using it. Nothing overwritten.", file=sys.stderr)
        return 1
    except ValueError as error:
        print(f"STOP: {error}", file=sys.stderr)
        return 1
    except OSError as error:
        print(
            f"STOP: filesystem or Git operation failed (errno={error.errno}). "
            "Check permissions and Git availability; no usable new scheme confirmed.",
            file=sys.stderr,
        )
        return 1
    print(f"Created local scheme: {target}")
    print("Select CertigoNative Local in Xcode. No build, sign-in or cloud verification performed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
