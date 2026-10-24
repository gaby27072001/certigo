"""Build the pinned Checkov conditional-body and resource-rule fixes, offline."""

import argparse
import base64
import csv
import hashlib
import io
import os
from pathlib import Path
import subprocess
import tempfile
import zipfile

from build_parser_wheel import checked_bytes


UPSTREAM_SHA256 = "737f39cbab5987d49204cd5e62cfca72ffab3f01fa3314471624e1c4256268ac"
SOURCE = "checkov/arm/base_resource_check.py"
SOURCE_SHA256 = "41731d508a51a8eeda346bbd1b456187d44c3e3d6e3cbebc3b563aa4e7a58541"
PATCH_SHA256 = "2e08c1cd70c1127e708219b9c92ec132f80d157c0cfa1634af055e60385fac0f"
PATCHED_SOURCE_SHA256 = "c23a87b3d77f84e144a187aa3d9f540d757627062ddb50828a682833ee0327a2"
RULE_FIXES = {
    "identity": (
        "checkov/arm/checks/resource/AppServiceIdentity.py",
        "bec5f57a89ca81598736c1a02925a2c2ead99d4e304f8ca203d8cbd43fb6181c",
        "4f449ea7fd4cf99f55a9dac1672e5b17e0d6482618fb08aecf7419249ef2fc64",
        "f36911729b239513c83641ed171b86518227e92af0b97b618821143189a4010d",
    ),
    "cosmos": (
        "checkov/arm/checks/resource/CosmosDBAccountsRestrictedAccess.py",
        "86aeb6941e76526497db6db689281ca29562acd02d62eaeca1969265f8052e70",
        "9e53cde9e2ba94003be11049fa20f8d7537220b9054c3e4862664646cdc86ba3",
        "2a5d260ab48a02032dfed01f14ba9c4fb4d806f23414f4c12c6d1a031b1c0384",
    ),
}
VERSION = "3.2.495+certigo.4"
OLD_INFO = "checkov-3.2.495.dist-info/"
NEW_INFO = f"checkov-{VERSION}.dist-info/"


def build(upstream, destination):
    with zipfile.ZipFile(io.BytesIO(checked_bytes(upstream, UPSTREAM_SHA256))) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise ValueError("Duplicate upstream wheel entries")
        files = {name: archive.read(name) for name in names if not name.endswith("/")}
    fixes = {"conditional": (SOURCE, SOURCE_SHA256, PATCH_SHA256, PATCHED_SOURCE_SHA256), **RULE_FIXES}
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        for name, (relative, original_digest, patch_digest, result_digest) in fixes.items():
            patch_file = Path(__file__).with_name(f"checkov-3.2.495-{name}.patch")
            patch = patch_file.read_bytes().replace(b"\r\n", b"\n")
            if hashlib.sha256(patch).hexdigest() != patch_digest:
                raise ValueError(f"Unexpected canonical LF patch SHA-256: {name}")
            if hashlib.sha256(files[relative]).hexdigest() != original_digest:
                raise ValueError(f"Unexpected upstream source: {relative}")
            source = root / relative
            source.parent.mkdir(parents=True, exist_ok=True)
            source.write_bytes(files[relative])
            reviewed_patch = root / f"{name}.patch"
            reviewed_patch.write_bytes(patch)
            for options in (["--check"], []):
                subprocess.run(
                    [
                        "git", "-c", "core.autocrlf=false", "-c", "core.eol=lf",
                        "-c", f"core.attributesFile={os.devnull}",
                        "apply", *options, str(reviewed_patch),
                    ],
                    cwd=root, check=True, text=True,
                )
            files[relative] = checked_bytes(source, result_digest)
    metadata = files[OLD_INFO + "METADATA"]
    if metadata.count(b"\nVersion: 3.2.495\n") != 1:
        raise ValueError("Unexpected upstream version metadata")
    files[OLD_INFO + "METADATA"] = metadata.replace(
        b"\nVersion: 3.2.495\n", f"\nVersion: {VERSION}\n".encode(), 1
    )
    files.pop(OLD_INFO + "RECORD")
    files = {
        name.replace(OLD_INFO, NEW_INFO, 1) if name.startswith(OLD_INFO) else name: data
        for name, data in files.items()
    }
    files[NEW_INFO + "CERTIGO-PATCH-NOTICE"] = (
        "Modified Checkov 3.2.495, https://github.com/bridgecrewio/checkov.\n"
        "Apache-2.0; upstream license and notices remain included.\n"
        "Change: analyze the body of conditional Bicep resources in the ARM check adapter;\n"
        "retain explicit blocking results when those checks return UNKNOWN.\n"
        "Resource checks: recognize literal combined managed identities and disabled\n"
        "Cosmos public access; keep unresolved identity/network configuration blocking.\n"
        "Identity: discard only bounded ARM loader line markers when validating\n"
        "nonempty user-assigned identity maps and their empty configuration objects.\n"
    ).encode()
    records = io.StringIO(newline="")
    writer = csv.writer(records, lineterminator="\n")
    for name, data in sorted(files.items()):
        digest = base64.urlsafe_b64encode(hashlib.sha256(data).digest()).rstrip(b"=").decode()
        writer.writerow((name, "sha256=" + digest, len(data)))
    writer.writerow((NEW_INFO + "RECORD", "", ""))
    files[NEW_INFO + "RECORD"] = records.getvalue().encode()
    destination.mkdir(parents=True, exist_ok=True)
    output = destination / f"checkov-{VERSION}-py3-none-any.whl"
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_STORED) as archive:
        for name, data in sorted(files.items()):
            info = zipfile.ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            info.compress_type = zipfile.ZIP_STORED
            archive.writestr(info, data)
    print(f"{hashlib.sha256(output.read_bytes()).hexdigest()}  {output.name}")
    return output


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("upstream", type=Path)
    parser.add_argument("destination", type=Path)
    arguments = parser.parse_args()
    build(arguments.upstream, arguments.destination)
