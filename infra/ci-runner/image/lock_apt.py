"""Capture authenticated indexes, then replay the runner APT transactions offline.

No installation, apt update, dpkg status modification or host APT configuration.
The resolver executable and libapt are extracted from verified Noble packages.
"""

import argparse
import gzip
import lzma
import platform
import re
import shutil
import socket
import subprocess
import tarfile
import tempfile
import urllib.parse
import sys
from pathlib import Path

from lock_inputs import (
    MICROSOFT, MICROSOFT_KEY, ROOT, SNAPSHOT, UBUNTU_KEY, artifact_url,
    checked_file, compare_lock, fetch, file_hash, paragraphs, read_json,
    release_index, require, run, serialize, sha256, signature, write_json,
)

EVIDENCE = ROOT / "apt-index-evidence"
BASE = ROOT / "base-image-evidence" / "base-image-reconstruction.json"
LOCK = ROOT / "apt-packages.lock.json"
HOST_ARCH = {"aarch64": "arm64", "x86_64": "amd64"}


def metadata(path):
    data = path.read_bytes()
    if path.suffix == ".xz":
        data = lzma.decompress(data)
    elif path.suffix == ".gz":
        data = gzip.decompress(data)
    return data.decode()


def capture(cache):
    base = read_json(BASE)
    EVIDENCE.mkdir(exist_ok=True)
    home = cache / "gnupg"
    home.mkdir(exist_ok=True, mode=0o700)
    keyring = Path("/usr/share/keyrings/ubuntu-archive-keyring.gpg")
    require(keyring.is_file(), "Ubuntu trusted archive keyring is required")
    sources = []
    for item in base["sources"]:
        suite = item["suite"]
        release = fetch(SNAPSHOT + f"dists/{suite}/InRelease",
                        cache / f"dists_{suite}_InRelease", item["inReleaseSha256"])
        signed = signature(release, keyring, UBUNTU_KEY, home)
        require(signed["Codename"] == "noble" and signed["Suite"] == suite,
                "Unexpected Ubuntu suite")
        indexes = []
        # ARM64 is needed only to run the identical Noble solver on an ARM64 host.
        for index in item["indexes"] + [{
            "path": f"dists/{suite}/main/binary-arm64/Packages.xz",
        }]:
            path = index["path"]
            digest, size = release_index(signed, path.split("/", 2)[2])
            if "sha256" in index:
                require((digest, size) == (index["sha256"], index["bytes"]),
                        "Base evidence index differs from authenticated release")
            fetch(SNAPSHOT + path, cache / path.replace("/", "_"), digest, size)
            indexes.append({"path": path, "sha256": digest, "bytes": size})
        sources.append({"url": SNAPSHOT, "suite": suite, "signer": UBUNTU_KEY,
                        "inReleaseSha256": file_hash(release), "indexes": indexes})
    key = fetch("https://packages.microsoft.com/keys/microsoft.asc",
                EVIDENCE / "microsoft.asc")
    fingerprints = re.findall(r"^fpr:::::::::([A-F0-9]+):",
                             run(["gpg", "--batch", "--homedir", str(home),
                                  "--show-keys", "--with-colons", str(key)]), re.M)
    require(fingerprints == [MICROSOFT_KEY], "Unexpected Microsoft public key")
    ms_ring = cache / "microsoft.gpg"
    run(["gpg", "--batch", "--yes", "--homedir", str(home), "--dearmor",
         "--output", str(ms_ring), str(key)])
    release = fetch(MICROSOFT + "dists/noble/InRelease", EVIDENCE / "microsoft-InRelease")
    signed = signature(release, ms_ring, MICROSOFT_KEY, home)
    require(signed["Codename"] == "noble" and signed["Suite"] == "noble",
            "Unexpected Microsoft suite")
    path = "main/binary-amd64/Packages"
    digest, size = release_index(signed, path)
    fetch(MICROSOFT + "dists/noble/" + path, EVIDENCE / "microsoft-Packages", digest, size)
    sources.append({"url": MICROSOFT, "suite": "noble", "signer": MICROSOFT_KEY,
                    "inReleaseSha256": file_hash(release), "indexes": [{
                        "path": "dists/noble/" + path, "sha256": digest, "bytes": size,
                    }]})
    evidence = {"schemaVersion": 1, "baseEvidenceSha256": file_hash(BASE),
                "microsoftKeySha256": file_hash(key), "sources": sources}
    write_json(EVIDENCE / "indexes.json", evidence)
    print("Authenticated Ubuntu snapshot and retained Microsoft indexes.")


def load_indexes(cache):
    evidence = read_json(EVIDENCE / "indexes.json")
    checked_file(BASE, evidence["baseEvidenceSha256"])
    base = read_json(BASE)
    require([(s["url"], s["suite"]) for s in evidence["sources"]] ==
            [(SNAPSHOT, s["suite"]) for s in base["sources"]] + [(MICROSOFT, "noble")],
            "Missing or unexpected repository")
    home = cache / "gnupg"
    home.mkdir(exist_ok=True, mode=0o700)
    checked_file(EVIDENCE / "microsoft.asc", evidence["microsoftKeySha256"])
    ms_ring = cache / "microsoft.gpg"
    run(["gpg", "--batch", "--yes", "--homedir", str(home), "--dearmor",
         "--output", str(ms_ring), str(EVIDENCE / "microsoft.asc")])
    indexes = []
    for source in evidence["sources"]:
        ubuntu = source["url"] == SNAPSHOT
        require(source["url"] in (SNAPSHOT, MICROSOFT), "Unexpected APT origin")
        require(source["signer"] == (UBUNTU_KEY if ubuntu else MICROSOFT_KEY),
                "Unexpected signing identity")
        suite = source["suite"]
        expected_paths = ([i["path"] for i in next(s for s in base["sources"]
                                                  if s["suite"] == suite)["indexes"]] +
                          [f"dists/{suite}/main/binary-arm64/Packages.xz"] if ubuntu else
                          ["dists/noble/main/binary-amd64/Packages"])
        require([i["path"] for i in source["indexes"]] == expected_paths,
                "Missing or unexpected repository index")
        release = checked_file(
            cache / f"dists_{suite}_InRelease" if ubuntu else EVIDENCE / "microsoft-InRelease",
            source["inReleaseSha256"])
        signed = signature(release, Path("/usr/share/keyrings/ubuntu-archive-keyring.gpg")
                           if ubuntu else ms_ring, source["signer"], home)
        for item in source["indexes"]:
            digest, size = release_index(signed, item["path"].split("/", 2)[2])
            require((digest, size) == (item["sha256"], item["bytes"]),
                    "Index not covered by signature")
            path = checked_file(cache / item["path"].replace("/", "_") if ubuntu else
                                EVIDENCE / "microsoft-Packages", digest, size)
            indexes.append((source, item, metadata(path)))
    return evidence, indexes


def restore_indexes(cache):
    """Restore only the immutable Ubuntu bytes; never refresh Microsoft on replay."""
    evidence = read_json(EVIDENCE / "indexes.json")
    for source in evidence["sources"]:
        if source["url"] == SNAPSHOT:
            suite = source["suite"]
            fetch(SNAPSHOT + f"dists/{suite}/InRelease", cache / f"dists_{suite}_InRelease",
                  source["inReleaseSha256"])
            for item in source["indexes"]:
                fetch(artifact_url(SNAPSHOT, item["path"]),
                      cache / item["path"].replace("/", "_"), item["sha256"], item["bytes"])
    load_indexes(cache)


def identity(fields):
    return fields["Package"] + ":" + fields["Architecture"], fields["Version"]


def solver_packages(indexes, arch):
    needed = {"apt", "libapt-pkg6.0t64"}
    found = {}
    for source, item, text in indexes:
        if f"binary-{arch}/" not in item["path"] or source["url"] != SNAPSHOT:
            continue
        for fields in paragraphs(text):
            if fields["Package"] in needed and fields["Version"] == "2.8.3":
                found[fields["Package"]] = {
                    "url": artifact_url(SNAPSHOT, fields["Filename"]),
                    "sha256": fields["SHA256"], "bytes": int(fields["Size"]),
                }
    require(set(found) == needed, "Pinned Noble APT 2.8.3 is missing")
    return found


def capture_solver(cache):
    _, indexes = load_indexes(cache)
    arch = HOST_ARCH[platform.machine()]
    for item in solver_packages(indexes, arch).values():
        fetch(item["url"], cache / item["sha256"], item["sha256"], item["bytes"])


def input_recipe(cache, runner_archive):
    contract = read_json(ROOT / "image-build-contract.json")
    for name in ("bootstrap", "prewarm", "toolchain-manifest"):
        item = next(i for i in contract["inputs"] if i["id"] == name)
        checked_file(ROOT.parents[2] / item["path"], item["sha256"])
    manifest = read_json(ROOT / "toolchain-manifest.json")
    runner = next(i for i in manifest["baseComponents"] if i["id"] == "github-actions-runner")
    checked_file(runner_archive, runner["source"]["digest"]["value"])
    with tarfile.open(runner_archive, "r:gz") as archive:
        member = archive.getmember("./bin/installdependencies.sh")
        require(member.isfile(), "Runner dependency script is not a regular file")
        script = archive.extractfile(member).read().decode()
    bootstrap = (ROOT.parent / "bootstrap.sh").read_text()
    prewarm = (ROOT / "prewarm-toolchain.sh").read_text()

    def install_line(text):
        matches = re.findall(r"apt-get install -y --no-install-recommends \\\n((?:  .+\n)+)", text)
        require(len(matches) == 1, "Installer package list changed or duplicated")
        return matches[0].replace("\\\n", " ").split()

    azure = re.findall(r'^AZURE_CLI_VERSION="([^"]+)"', bootstrap, re.M)
    initial = re.findall(r"\$apt_get update && \$apt_get install -y (.+)", script)
    require(len(azure) == len(initial) == 1, "Azure pin or runner core recipe changed")
    fallbacks = re.findall(r"^        apt_get_with_fallbacks (.+)$", script, re.M)
    require(len(fallbacks) == 3, "Runner fallback graph changed")
    stages = [
        {"id": "bootstrap", "options": ["--no-install-recommends"],
         "alternatives": [install_line(bootstrap)], "microsoft": False},
        {"id": "azure-cli", "options": ["--allow-downgrades", "--no-install-recommends"],
         "alternatives": [["azure-cli=" + azure[0]]], "microsoft": True},
        {"id": "runner-core", "options": [], "alternatives": [initial[0].split()], "microsoft": True},
    ]
    stages.extend({"id": f"runner-fallback-{i}", "options": [],
                   "alternatives": [[name] for name in line.split()], "microsoft": True}
                  for i, line in enumerate(fallbacks))
    stages.append({"id": "prewarm", "options": ["--no-install-recommends"],
                   "alternatives": [install_line(prewarm)], "microsoft": True})
    return stages, {"bootstrapSha256": file_hash(ROOT.parent / "bootstrap.sh"),
                    "prewarmSha256": file_hash(ROOT / "prewarm-toolchain.sh"),
                    "manifestSha256": file_hash(ROOT / "toolchain-manifest.json"),
                    "runnerArchiveSha256": file_hash(runner_archive),
                    "runnerDependencyScriptSha256": sha256(script.encode())}


def isolated_config(directory):
    for name in ("lists/partial", "archives/partial", "empty", "log"):
        (directory / name).mkdir(parents=True)
    config = directory / "apt.conf"
    config.write_text(
        f'Dir "{directory}";\n'
        f'Dir::Etc "{directory}";\nDir::Etc::parts "empty";\n'
        'Dir::Etc::main "-";\nDir::Etc::sourcelist "sources.list";\n'
        'Dir::Etc::sourceparts "empty";\nDir::Etc::preferences "-";\n'
        'Dir::Etc::preferencesparts "empty";\nDir::Etc::trusted "-";\n'
        'Dir::Etc::trustedparts "empty";\n'
        f'Dir::State "{directory}";\nDir::State::status "{directory}/status";\n'
        f'Dir::State::lists "{directory}/lists";\n'
        f'Dir::Cache "{directory}";\nDir::Cache::archives "{directory}/archives";\n'
        'Dir::Cache::pkgcache "";\nDir::Cache::srcpkgcache "";\n'
        f'Dir::Log "{directory}/log";\n'
        'APT::Architecture "amd64";\nAPT::Architectures { "amd64"; };\n'
        'APT::Install-Recommends "true";\nAPT::Install-Suggests "false";\n'
        'Acquire::ForceHash "sha256";\nDebug::NoLocking "true";\n',
        encoding="utf-8")
    return config


def observed_transactions(log, history):
    excluded = "2026-09-19 12:53:09 install ubuntu-advantage-tools:all <none> 37.2ubuntu~24.04.1"
    excluded_history = (
        "Start-Date: 2026-09-19  12:53:07\n"
        "Commandline: apt-get install ubuntu-advantage-tools -y\n"
        "Install: ubuntu-advantage-tools:amd64 (37.2ubuntu~24.04.1)\n"
        "End-Date: 2026-09-19  12:53:11")
    require(history.count(excluded_history) == 1 and log.splitlines().count(excluded) == 1,
            "Platform transaction exception does not match retained evidence")
    transactions = []
    packages = set()
    for line in log.splitlines():
        if not line.strip():
            continue
        date, time, action, *fields = line.split()
        require(action in ("startup", "status", "configure", "trigproc", "install", "upgrade"),
                f"Unexpected dpkg action: {line}")
        if action not in ("install", "upgrade"):
            continue
        if line == excluded:
            continue
        require(date == "2026-09-14" and "09:26:06" <= time <= "09:26:59",
                f"Unexpected version transaction outside bootstrap: {line}")
        require(len(fields) == 3 and fields[0] not in packages and
                ((fields[1] == "<none>") == (action == "install")),
                "Unexpected bootstrap transaction")
        packages.add(fields[0])
        transactions.append({"timestamp": f"{date}T{time}Z", "action": action,
                             "package": fields[0], "previousVersion": fields[1],
                             "observedVersion": fields[2]})
    require(sum(t["action"] == "install" for t in transactions) == 6,
            "Observed bootstrap installation count changed")
    return transactions


def observed_inputs(base, directory=BASE.parent):
    texts, digests = {}, {}
    for kind, key in (("dpkg", "dpkgLogSha256"), ("apt-history", "aptHistorySha256")):
        name = f"2026-09-23-pr31-{kind}.txt"
        path = checked_file(directory / name, base["sourceSha256"][name])
        texts[kind] = path.read_text()
        digests[key] = file_hash(path)
    return observed_transactions(texts["dpkg"], texts["apt-history"]), digests


def reconcile_observation(base, observed, installed, transactions):
    base_versions = {p["package"]: p["version"] for p in base["packages"]}
    additions = {t["package"] for t in observed if t["action"] == "install"}
    require(len(observed) + 1 == base["versionTransactionCount"],
            "Observed version transaction count differs from base reconstruction")
    require(len(base_versions) + len(additions) + 1 == base["observedPackageCount"],
            "Observed package count differs from base reconstruction")
    before_prewarm = {p for t in transactions if t["id"] != "prewarm" for p in t["packages"]}
    require(before_prewarm - base_versions.keys() == additions,
            "Missing or unexpected bootstrap addition")
    prewarm_only = set(transactions[-1]["packages"]) - base_versions.keys() - additions
    require(set(installed) == base_versions.keys() | additions | prewarm_only,
            "Snapshot inventory contains missing or unexplained packages")
    compared = []
    for item in observed:
        package = item["package"]
        if item["action"] == "upgrade":
            require(base_versions.get(package) == item["previousVersion"],
                    "Observed upgrade does not start from reconstructed base")
        snapshot_version = installed[package]["Version"]
        compared.append({**item, "snapshotVersion": snapshot_version,
                         "reproduced": snapshot_version == item["observedVersion"]})
    require(len(installed) == base["observedPackageCount"] - 1 + len(prewarm_only),
            "Snapshot and observed cardinalities do not reconcile")
    return {
        "scope": "snapshot resolution is not the observed live final inventory",
        "observedPackageCount": base["observedPackageCount"],
        "excludedPlatformTransaction": {
            "timestamp": "2026-09-19T12:53:09Z", "package": "ubuntu-advantage-tools:all",
            "version": "37.2ubuntu~24.04.1", "action": "install",
        },
        "bootstrapVersionTransactions": compared,
        "unreproducedVersionTransactions": [t for t in compared if not t["reproduced"]],
        "prewarmOnlyAdditions": sorted(prewarm_only),
        "snapshotResolvedPackageCount": len(installed),
    }


def resolve(cache, runner_archive, output):
    require([name for _, name in socket.if_nameindex()] == ["lo"],
            "Resolution must run in an empty network namespace (unshare -n)")
    evidence, indexes = load_indexes(cache)
    stages, inputs = input_recipe(cache, runner_archive)
    records = {}
    for source, index, text in indexes:
        if "binary-amd64/" not in index["path"]:
            continue
        for fields in paragraphs(text):
            records[identity(fields)] = (fields, source, index)
    base = read_json(BASE)
    observed, observation_hashes = observed_inputs(base)
    inputs.update(observation_hashes)
    installed = {}
    for entry in base["packages"]:
        fields, _, _ = records[(entry["package"], entry["version"])]
        require(fields["SHA256"] == entry["sha256"], "Base metadata identity mismatch")
        installed[entry["package"]] = dict(fields)
    require(len(installed) == 656, "Base inventory cardinality changed")
    arch = HOST_ARCH[platform.machine()]
    solver_inputs = solver_packages(indexes, arch)
    with tempfile.TemporaryDirectory(prefix="certigo-apt-") as tmp:
        directory = Path(tmp)
        config = isolated_config(directory)
        solver = directory / "solver"
        for artifact in solver_inputs.values():
            path = checked_file(cache / artifact["sha256"], artifact["sha256"], artifact["bytes"])
            run(["dpkg-deb", "--extract", str(path), str(solver)])
        library_dir = solver / "usr/lib" / ("aarch64-linux-gnu" if arch == "arm64" else "x86_64-linux-gnu")
        env = {"PATH": "/usr/bin:/bin", "LC_ALL": "C", "HOME": str(directory),
               "APT_CONFIG": str(config), "LD_LIBRARY_PATH": str(library_dir)}
        apt = str(solver / "usr/bin/apt-get")
        require(run([apt, "--version"], env=env).splitlines()[0] == f"apt 2.8.3 ({arch})",
                "Unexpected resolver version")
        artifacts = {}
        transactions = []
        def write_status():
            status = "".join(serialize({**fields, "Status":
                                       ("hold" if fields["Package"] == "azure-cli" else "install") +
                                       " ok installed"}) for _, fields in sorted(installed.items()))
            (directory / "status").write_text(status, encoding="utf-8")
            return status

        for stage in stages:
            sources = []
            for source, item, text in indexes:
                if "binary-amd64/" not in item["path"]:
                    continue
                if source["url"] == MICROSOFT and not stage["microsoft"]:
                    continue
                component = item["path"].split("/")[2]
                sources.append(f'deb [arch=amd64] {source["url"]} {source["suite"]} {component}\n')
                prefix = (source["url"].split("://", 1)[1] + item["path"]).replace("/", "_")
                prefix = re.sub(r"\.(xz|gz)$", "", prefix)
                (directory / "lists" / prefix).write_text(text, encoding="utf-8")
                release_name = (source["url"].split("://", 1)[1] +
                                f'dists/{source["suite"]}/InRelease').replace("/", "_")
                shutil.copyfile(cache / f'dists_{source["suite"]}_InRelease'
                                if source["url"] == SNAPSHOT else EVIDENCE / "microsoft-InRelease",
                                directory / "lists" / release_name)
            (directory / "sources.list").write_text("".join(sources))
            status = write_status()
            run([apt, "check"], env=env)
            rejected = []
            for requested in stage["alternatives"]:
                command = [apt, "-o", f"Dir::State::status={directory}/status",
                           "install", "-y", *stage["options"], *requested]
                simulation = subprocess.run(command + ["--simulate"], env=env,
                                            capture_output=True, text=True)
                if simulation.returncode:
                    # Only an unavailable fallback is admissible, never a broken solver.
                    require(len(stage["alternatives"]) > 1 and
                            all(f"Unable to locate package {name.rstrip('$')}" in simulation.stderr
                                for name in requested),
                            f"APT failed: {simulation.stdout}\n{simulation.stderr}")
                    rejected.append(requested)
                    continue
                require(not re.search(r"^Remv ", simulation.stdout, re.M),
                        "Unexpected package removal")
                uris = run(command + ["--print-uris"], env=env)
                selected = []
                for line in uris.splitlines():
                    if not line.startswith("'"):
                        continue
                    match = re.fullmatch(r"'([^']+)' (\S+) (\d+) SHA256:([0-9a-f]{64})", line)
                    require(match is not None, f"Unexpected --print-uris line: {line}")
                    url, filename, size, digest = match.groups()
                    matches = [(key, value) for key, value in records.items()
                               if value[0]["SHA256"] == digest and
                               artifact_url(value[1]["url"], value[0]["Filename"]) ==
                               urllib.parse.unquote(url)]
                    require(len(matches) == 1, f"Unexpected APT artifact: {url}")
                    key, (fields, source, index) = matches[0]
                    require(int(size) == int(fields["Size"]), "APT size mismatch")
                    item = {"package": key[0], "version": key[1], "url": url,
                            "sha256": digest, "bytes": int(size),
                            "indexSha256": index["sha256"]}
                    artifacts[key] = item
                    selected.append(key[0])
                    installed[key[0]] = dict(fields)
                actual = re.findall(r"^Inst (\S+)", simulation.stdout, re.M)
                require({p.split(":")[0] for p in selected} == {p.split(":")[0] for p in actual},
                        "Simulation and --print-uris disagree")
                for name in requested:
                    if name.endswith("$"):
                        require(any(p.split(":")[0] == name[:-1] for p in installed),
                                "Runner dpkg postcondition failed after regex fallback")
                transactions.append({"id": stage["id"], "options": stage["options"],
                                     "requested": requested, "unavailableFallbacks": rejected,
                                     "statusSha256": sha256(status.encode()),
                                     "packages": sorted(selected)})
                break
            else:
                raise ValueError(f"No successful fallback: {stage['id']}")
        write_status()
        run([apt, "check"], env=env)
        reconciliation = reconcile_observation(base, observed, installed, transactions)
        final_packages = []
        for name, fields in sorted(installed.items()):
            _, source, index = records[identity(fields)]
            final_packages.append({
                "package": name, "version": fields["Version"],
                "sha256": fields["SHA256"], "bytes": int(fields["Size"]),
                "url": artifact_url(source["url"], fields["Filename"]),
                "indexSha256": index["sha256"], "controlSha256": sha256(serialize(fields).encode()),
                "origin": "transaction" if identity(fields) in artifacts else "reconstructed-base",
            })
        result = {"schemaVersion": 1, "target": "ubuntu-noble-amd64",
                  "baseEvidenceSha256": file_hash(BASE),
                  "indexesSha256": file_hash(EVIDENCE / "indexes.json"),
                  "resolver": "apt 2.8.3", "networkDuringResolution": "isolated-namespace",
                  "solverPackages": {a: solver_packages(indexes, a) for a in ("amd64", "arm64")},
                  "inputs": inputs, "transactions": transactions,
                  "packages": [value for _, value in sorted(artifacts.items())],
                  "snapshotResolvedPackages": final_packages,
                  "observationReconciliation": reconciliation}
        write_json(output, result)
        print(f"Resolved {len(artifacts)} .deb artifacts through {len(transactions)} transactions.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("capture", "restore-indexes", "capture-solver",
                                           "resolve", "verify", "download"))
    parser.add_argument("--cache", type=Path, required=True)
    parser.add_argument("--runner-archive", type=Path)
    parser.add_argument("--output", type=Path, default=LOCK)
    args = parser.parse_args()
    args.cache = args.cache.resolve()
    args.cache.mkdir(parents=True, exist_ok=True)
    if args.command == "capture":
        capture(args.cache)
    elif args.command == "restore-indexes":
        restore_indexes(args.cache)
    elif args.command == "capture-solver":
        capture_solver(args.cache)
    elif args.command == "resolve":
        resolve(args.cache, args.runner_archive.resolve(), args.output)
    elif args.command == "download":
        run(["unshare", "-n", sys.executable, str(Path(__file__).resolve()), "verify",
             "--cache", str(args.cache), "--runner-archive", str(args.runner_archive.resolve()),
             "--output", str(args.output.resolve())])
        for item in read_json(args.output)["packages"]:
            fetch(item["url"], args.cache / item["sha256"], item["sha256"], item["bytes"])
        print("All transaction .deb files downloaded and verified against signed indexes.")
    else:
        with tempfile.TemporaryDirectory(prefix="certigo-replay-") as tmp:
            path = Path(tmp) / "lock.json"
            resolve(args.cache, args.runner_archive.resolve(), path)
            compare_lock(read_json(args.output), read_json(path))


if __name__ == "__main__":
    main()
