"""Build a deterministic, reviewed pycep compatibility wheel without network access."""

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


UPSTREAM_SHA256 = "8c3f99c0dc1301193b1bcbe0a44c6b2763f6d2daf24964ca48dcdfbb73087fa0"
PATCH_SHA256 = "c1e982fb9409ca182343665023adc439160dd0ea9a0135b5a745094e8af0cdf6"
PATCHED_FILES = {
    "pycep/bicep.lark": "3d0e617dc2a068948d95c40e1e5e978a86500fa382cd29a681aa8e3043fb8160",
    "pycep/transformer.py": "9f5c29a3b5716d2e79dd90a6e6ef5a4757f765140d27c048f920497f995b488d",
}
VERSION = "0.5.1+certigo.1"
WHEEL_NAME = f"pycep_parser-{VERSION}-py3-none-any.whl"
OLD_INFO = "pycep_parser-0.5.1.dist-info/"
NEW_INFO = f"pycep_parser-{VERSION}.dist-info/"


def checked_bytes(path, expected):
    content = path.read_bytes()
    if hashlib.sha256(content).hexdigest() != expected:
        raise ValueError(f"Unexpected SHA-256 for {path.name}")
    return content


def build(upstream, destination):
    patch_path = Path(__file__).with_name("pycep-0.5.1-certigo.1.patch")
    patch = checked_bytes(patch_path, PATCH_SHA256)
    with zipfile.ZipFile(io.BytesIO(checked_bytes(upstream, UPSTREAM_SHA256))) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise ValueError("Upstream wheel contains duplicate entries")
        files = {name: archive.read(name) for name in names if not name.endswith("/")}
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        for name in PATCHED_FILES:
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(files[name])
        patch_file = root / "compat.patch"
        patch_file.write_bytes(patch)
        for options in (["--check"], []):
            subprocess.run(
                [
                    "git", "-c", "core.autocrlf=false", "-c", "core.eol=lf",
                    "-c", f"core.attributesFile={os.devnull}",
                    "apply", *options, str(patch_file),
                ],
                cwd=root, check=True, capture_output=True, text=True,
            )
        for name, expected in PATCHED_FILES.items():
            files[name] = checked_bytes(root / name, expected)
    metadata = files[OLD_INFO + "METADATA"]
    if metadata.count(b"\nVersion: 0.5.1\n") != 1:
        raise ValueError("Unexpected upstream version metadata")
    files[OLD_INFO + "METADATA"] = metadata.replace(
        b"\nVersion: 0.5.1\n", f"\nVersion: {VERSION}\n".encode(), 1
    )
    files.pop(OLD_INFO + "RECORD")
    files = {
        name.replace(OLD_INFO, NEW_INFO, 1) if name.startswith(OLD_INFO) else name: data
        for name, data in files.items()
    }
    files[NEW_INFO + "CERTIGO-PATCH-NOTICE"] = (
        "Modified pycep-parser 0.5.1 (https://github.com/gruebel/pycep).\n"
        "Upstream license: Apache-2.0; the original LICENSE remains included.\n"
        "Certigo compatibility changes: multiline expressions, comments and symbolic\n"
        "range/map/reduce/toObject/fail AST support. No source preprocessor or evaluator.\n"
        f"Reviewed patch SHA-256: {PATCH_SHA256}\n"
    ).encode()
    records = io.StringIO(newline="")
    writer = csv.writer(records, lineterminator="\n")
    for name, data in sorted(files.items()):
        digest = base64.urlsafe_b64encode(hashlib.sha256(data).digest()).rstrip(b"=").decode()
        writer.writerow((name, "sha256=" + digest, len(data)))
    writer.writerow((NEW_INFO + "RECORD", "", ""))
    files[NEW_INFO + "RECORD"] = records.getvalue().encode()
    destination.mkdir(parents=True, exist_ok=True)
    output = destination / WHEEL_NAME
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
    args = parser.parse_args()
    build(args.upstream, args.destination)
