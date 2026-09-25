"""Pin one PyPI wheel per hash-locked requirement for the Noble amd64 target.

`toolchain-requirements.lock` authorizes every published artifact of each exact
version, for all platforms. The offline installer needs exactly one archive
per requirement: the best-ranked wheel whose tags the target supports, in the
order produced by the target pip's own `packaging.tags.sys_tags()` (CPython
3.12.3, glibc 2.39, x86_64). Source distributions are never selected.

`capture` reads the PyPI JSON API without redirects and writes a proposed
lock. `verify` is offline: it re-derives the selection from the committed
target tags and the recorded compatible candidates, and requires every hash to
be authorized by the requirements lock.
"""

import argparse
import json
import re
import sys
import urllib.parse
import urllib.request
from pathlib import Path

from lock_inputs import NoRedirect, ROOT, file_hash, read_json, require, write_json

REQUIREMENTS = ROOT / "toolchain-requirements.lock"
TAGS = ROOT / "python-target-tags.txt"
LOCK = ROOT / "python-wheels.lock.json"
PYPI = "https://pypi.org/pypi/"
FILES_HOST = "files.pythonhosted.org"
REQUIREMENT = re.compile(
    r"^([A-Za-z0-9][A-Za-z0-9._-]*)==([^\s\\;]+) \\\n((?:    --hash=sha256:[0-9a-f]{64}(?: \\)?\n)+)",
    re.M)
WHEEL = re.compile(r"^(?P<name>[^-]+)-(?P<version>[^-]+)(?:-(?P<build>\d[^-]*))?-"
                   r"(?P<python>[^-]+)-(?P<abi>[^-]+)-(?P<platform>[^-]+)\.whl$")


def normalize(name):
    return re.sub(r"[-_.]+", "-", name).lower()


def requirements(text):
    parsed = {}
    for match in REQUIREMENT.finditer(text):
        name = normalize(match[1])
        require(name not in parsed, f"Duplicate requirement: {name}")
        parsed[name] = {"version": match[2],
                        "hashes": set(re.findall(r"sha256:([0-9a-f]{64})", match[3]))}
    declared = [line for line in text.splitlines()
                if line and not line.startswith((" ", "#"))]
    require(len(declared) == len(parsed), "Unparsed or unpinned requirement line")
    return parsed


def wheel_tags(filename):
    match = WHEEL.match(filename)
    require(match is not None, f"Invalid wheel filename: {filename}")
    return match, {f"{python}-{abi}-{plat}"
                   for python in match["python"].split(".")
                   for abi in match["abi"].split(".")
                   for plat in match["platform"].split(".")}


def rank(filename, order):
    _, tags = wheel_tags(filename)
    ranks = [order[tag] for tag in tags if tag in order]
    return min(ranks) if ranks else None


def select(name, requirement, candidates, order):
    """Return (selected, compatible candidates) exactly as pip would rank them."""
    compatible = []
    for candidate in candidates:
        require(candidate["sha256"] in requirement["hashes"],
                f"Unauthorized artifact hash for {name}: {candidate['filename']}")
        match, _ = wheel_tags(candidate["filename"])
        require(normalize(match["name"]) == name and match["version"] == requirement["version"],
                f"Wheel identity differs from the requirement: {candidate['filename']}")
        position = rank(candidate["filename"], order)
        if position is not None:
            compatible.append({**candidate, "tagRank": position})
    require(compatible, f"No wheel compatible with the target for {name}")
    compatible.sort(key=lambda item: (item["tagRank"], item["filename"]))
    require(len(compatible) == 1 or compatible[0]["tagRank"] < compatible[1]["tagRank"],
            f"Ambiguous best-ranked wheel for {name}")
    return compatible[0], compatible


def load_order(path=TAGS):
    tags = [line.strip() for line in Path(path).read_text().splitlines() if line.strip()]
    require(len(tags) == len(set(tags)), "Duplicate target tag")
    return {tag: position for position, tag in enumerate(tags)}


def pypi_files(name, version):
    url = f"{PYPI}{urllib.parse.quote(name)}/{urllib.parse.quote(version)}/json"
    with urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect).open(
            url, timeout=60) as response:
        require(response.geturl() == url, f"URL changed: {url}")
        data = json.load(response)
    return [{"filename": item["filename"], "url": item["url"], "sha256": item["digests"]["sha256"],
             "bytes": item["size"]} for item in data["urls"] if item["packagetype"] == "bdist_wheel"]


def check_origin(name, url, filename):
    parts = urllib.parse.urlsplit(url)
    require(parts.scheme == "https" and parts.hostname == FILES_HOST and parts.port is None and
            not parts.query and not parts.fragment and
            parts.path.rsplit("/", 1)[-1] == filename,
            f"Unexpected wheel origin for {name}: {url}")


def build_lock(files_by_name, requirements_path=REQUIREMENTS, tags_path=TAGS):
    parsed = requirements(Path(requirements_path).read_text())
    order = load_order(tags_path)
    wheels = []
    for name, requirement in sorted(parsed.items()):
        authorized = [item for item in files_by_name[name] if item["sha256"] in requirement["hashes"]]
        selected, compatible = select(name, requirement, authorized, order)
        check_origin(name, selected["url"], selected["filename"])
        wheels.append({
            "name": name, "version": requirement["version"], "filename": selected["filename"],
            "url": selected["url"], "sha256": selected["sha256"], "bytes": selected["bytes"],
            "tagRank": selected["tagRank"],
            "compatibleCandidates": [{"filename": c["filename"], "sha256": c["sha256"],
                                      "tagRank": c["tagRank"]} for c in compatible],
        })
    return {
        "schemaVersion": 1,
        "target": "cpython-3.12.3-glibc-2.39-x86_64",
        "selection": "best-ranked authorized wheel by target sys_tags(); no source distribution",
        "requirementsSha256": file_hash(requirements_path),
        "targetTagsSha256": file_hash(tags_path),
        "wheels": wheels,
    }


def verify(lock_path=LOCK, requirements_path=REQUIREMENTS, tags_path=TAGS):
    """Offline: re-rank the recorded candidates; PyPI completeness needs capture."""
    lock = read_json(lock_path)
    parsed = requirements(Path(requirements_path).read_text())
    order = load_order(tags_path)
    require(lock["requirementsSha256"] == file_hash(requirements_path),
            "Wheel lock is stale: the requirements lock changed")
    require(lock["targetTagsSha256"] == file_hash(tags_path),
            "Wheel lock is stale: the target tags changed")
    require([wheel["name"] for wheel in lock["wheels"]] == sorted(parsed),
            "Wheel lock requirement set differs (omission or addition)")
    for wheel in lock["wheels"]:
        name = wheel["name"]
        require(wheel["version"] == parsed[name]["version"], f"Wheel version differs: {name}")
        candidates = [{"filename": c["filename"], "sha256": c["sha256"], "url": wheel["url"],
                       "bytes": wheel["bytes"]} for c in wheel["compatibleCandidates"]]
        selected, compatible = select(name, parsed[name], candidates, order)
        recorded = [(c["filename"], c["sha256"], c["tagRank"]) for c in wheel["compatibleCandidates"]]
        require([(c["filename"], c["sha256"], c["tagRank"]) for c in compatible] == recorded,
                f"Recorded candidate ranking differs for {name}")
        require((selected["filename"], selected["sha256"], selected["tagRank"]) ==
                (wheel["filename"], wheel["sha256"], wheel["tagRank"]),
                f"Recorded wheel is not the best-ranked authorized candidate: {name}")
        check_origin(name, wheel["url"], wheel["filename"])
        require(type(wheel["bytes"]) is int and wheel["bytes"] > 0, f"Invalid wheel size: {name}")
    return lock


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("capture", "verify"))
    parser.add_argument("--output", type=Path, default=LOCK)
    args = parser.parse_args()
    if args.command == "capture":
        parsed = requirements(REQUIREMENTS.read_text())
        files = {name: pypi_files(name, requirement["version"])
                 for name, requirement in parsed.items()}
        write_json(args.output, build_lock(files))
        print(f"Captured {len(parsed)} wheels into {args.output}.")
    else:
        lock = verify(args.output)
        print(f"Verified {len(lock['wheels'])} wheels offline against the requirements lock.")


if __name__ == "__main__":
    try:
        main()
    except ValueError as error:
        print(error, file=sys.stderr)
        sys.exit(1)
