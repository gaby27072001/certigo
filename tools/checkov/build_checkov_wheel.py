"""Build the pinned Checkov conditional-body adapter wheel, offline."""

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
VERSION = "3.2.495+certigo.1"
OLD_INFO = "checkov-3.2.495.dist-info/"
NEW_INFO = f"checkov-{VERSION}.dist-info/"


def build(upstream, destination):
    patch_file = Path(__file__).with_name("checkov-3.2.495-conditional.patch")
    patch = patch_file.read_bytes().replace(b"\r\n", b"\n")
    if hashlib.sha256(patch).hexdigest() != PATCH_SHA256:
        raise ValueError("Unexpected canonical LF patch SHA-256")
    with zipfile.ZipFile(io.BytesIO(checked_bytes(upstream, UPSTREAM_SHA256))) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise ValueError("Duplicate upstream wheel entries")
        files = {name: archive.read(name) for name in names if not name.endswith("/")}
    if hashlib.sha256(files[SOURCE]).hexdigest() != SOURCE_SHA256:
        raise ValueError("Unexpected upstream adapter source")
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        source = root / SOURCE
        source.parent.mkdir(parents=True)
        source.write_bytes(files[SOURCE])
        reviewed_patch = root / "conditional.patch"
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
        files[SOURCE] = checked_bytes(source, PATCHED_SOURCE_SHA256)
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
