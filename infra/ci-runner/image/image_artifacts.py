"""Closed set of network artifacts consumed by the offline image installer (#341).

The set is derived only from reviewed, digest-pinned files: the toolchain
manifest, the APT lock, the Flutter lock and the Python wheel lock. Artifacts
already contained in the verified Flutter SDK archive ("bundled-current") are
not downloaded and therefore not part of the set.

`acquire` is the single network step. It fetches the exact locked URLs over
HTTPS, ignores proxy environment variables, refuses every redirect except the
documented one-hop GitHub release asset redirect, and publishes a file only
after its digest and size match. `verify` is offline and exact: a missing,
altered, resized, non-regular or additional store entry fails before any
installation step.
"""

import argparse
import concurrent.futures
import hashlib
import json
import os
import re
import stat
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from lock_inputs import ROOT, read_json, require

MANIFEST = "toolchain-manifest.json"
APT_LOCK = "apt-packages.lock.json"
FLUTTER_LOCK = "flutter-engine-artifacts.lock.json"
WHEEL_LOCK = "python-wheels.lock.json"
DIGEST_LENGTH = {"sha256": 64, "sha512": 128}
GITHUB_RELEASE = re.compile(r"/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/releases/download/[^/]+/[^/]+")
GITHUB_ASSET_HOSTS = frozenset({"release-assets.githubusercontent.com",
                                "objects.githubusercontent.com"})
SAFE_FILENAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9._+~-]*")
PARTIAL_PREFIX = ".partial-"


def _artifact(kind, ident, url, algorithm, digest, size, filename):
    parts = urllib.parse.urlsplit(url)
    require(parts.scheme == "https" and parts.hostname and not parts.query and
            not parts.fragment and parts.username is None and parts.port is None,
            f"Artifact URL must be a plain HTTPS URL: {url}")
    require(algorithm in DIGEST_LENGTH and
            re.fullmatch(f"[0-9a-f]{{{DIGEST_LENGTH[algorithm]}}}", digest or ""),
            f"Invalid {algorithm} digest for {kind}:{ident}")
    require(size is None or (type(size) is int and size > 0), f"Invalid size for {kind}:{ident}")
    require(SAFE_FILENAME.fullmatch(filename) and filename not in (".", ".."),
            f"Unsafe artifact filename for {kind}:{ident}: {filename}")
    return {"kind": kind, "id": ident, "url": url, "algorithm": algorithm,
            "digest": digest, "bytes": size, "filename": filename}


def store_name(item):
    return f"{item['algorithm']}-{item['digest']}"


def closed_set(root=ROOT):
    root = Path(root)
    manifest = read_json(root / MANIFEST)
    items = []
    for component in manifest["baseComponents"] + manifest["tools"]:
        source = component.get("source")
        if source is None:
            # Bundled tools, the Python lock and the APT-installed Azure CLI are
            # covered by their parent artifact or lock, never fetched separately.
            continue
        filename = urllib.parse.urlsplit(source["url"]).path.rsplit("/", 1)[-1]
        items.append(_artifact("toolchain", component["id"], source["url"],
                               source["digest"]["algorithm"], source["digest"]["value"],
                               None, filename))
    apt = read_json(root / APT_LOCK)
    for package in apt["packages"]:
        name, architecture = package["package"].split(":")
        version = package["version"].split(":", 1)[-1]
        items.append(_artifact("deb", package["package"], package["url"], "sha256",
                               package["sha256"], package["bytes"],
                               f"{name}_{version}_{architecture}.deb"))
    flutter = read_json(root / FLUTTER_LOCK)
    for artifact in flutter["artifacts"]:
        if artifact["cacheState"] == "bundled-current":
            continue
        require(artifact["cacheState"] == "download-required" and
                artifact["requiredBy"] == "PubDependencies",
                "Only Pub archives may be downloaded for the Flutter SDK")
        ident = f"{artifact['package']}-{artifact['version']}"
        items.append(_artifact("pub", ident, artifact["url"], "sha256", artifact["sha256"],
                               artifact["bytes"], f"{ident}.tar.gz"))
    wheels = read_json(root / WHEEL_LOCK)
    for wheel in wheels["wheels"]:
        items.append(_artifact("wheel", f"{wheel['name']}-{wheel['version']}", wheel["url"],
                               "sha256", wheel["sha256"], wheel["bytes"], wheel["filename"]))
    keys = [store_name(item) for item in items]
    require(len(set(keys)) == len(keys), "Duplicate digest in the closed artifact set")
    identities = [(item["kind"], item["id"]) for item in items]
    require(len(set(identities)) == len(identities), "Duplicate identity in the closed artifact set")
    return items


def closed_set_sha256(items):
    canonical = json.dumps(sorted(items, key=store_name), sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canonical.encode()).hexdigest()


def digest_file(path, algorithm):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, algorithm).hexdigest()


def verify_store(store, items):
    """Return {store entry name: item} after proving the store equals the set."""
    store = Path(store)
    require(store.is_dir() and not store.is_symlink(),
            f"Closed artifact store must be a real directory: {store}")
    expected = {store_name(item): item for item in items}
    present = set(os.listdir(store))
    unexpected = sorted(present - expected.keys())
    require(not unexpected, f"Unexpected file in the closed artifact store: {unexpected[0]}")
    for name, item in sorted(expected.items(), key=lambda entry: (entry[1]["kind"], entry[1]["id"])):
        label = f"{item['kind']}:{item['id']}"
        require(name in present, f"Missing artifact {label} ({item['url']})")
        status = os.lstat(store / name)
        require(stat.S_ISREG(status.st_mode), f"Artifact is not a regular file: {label}")
        if item["bytes"] is not None:
            require(status.st_size == item["bytes"], f"Size mismatch for {label}")
        require(digest_file(store / name, item["algorithm"]) == item["digest"],
                f"Digest mismatch for {label}")
    return expected


class GithubReleaseRedirect(urllib.request.HTTPRedirectHandler):
    """Allow only the single documented GitHub release-asset redirect."""

    max_redirections = 1

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        source = urllib.parse.urlsplit(req.full_url)
        target = urllib.parse.urlsplit(newurl)
        allowed = (source.scheme == "https" and source.hostname == "github.com" and
                   source.port is None and GITHUB_RELEASE.fullmatch(source.path) and
                   target.scheme == "https" and target.hostname in GITHUB_ASSET_HOSTS and
                   target.port is None and target.username is None)
        if not allowed:
            raise ValueError(f"Unexpected redirect: {req.full_url} -> {newurl}")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def opener():
    # An empty ProxyHandler disables *_proxy environment variables: no implicit
    # intermediary may choose where locked bytes come from.
    return urllib.request.build_opener(urllib.request.ProxyHandler({}), GithubReleaseRedirect)


def fetch(item, store, attempts=3):
    destination = Path(store) / store_name(item)
    label = f"{item['kind']}:{item['id']}"
    if destination.exists() or destination.is_symlink():
        status = os.lstat(destination)
        require(stat.S_ISREG(status.st_mode) and
                digest_file(destination, item["algorithm"]) == item["digest"],
                f"Existing store entry is altered, remove it explicitly: {label}")
        return "present"
    descriptor, temporary = tempfile.mkstemp(prefix=PARTIAL_PREFIX, dir=store)
    os.close(descriptor)
    temporary = Path(temporary)
    try:
        for attempt in range(attempts):
            digest = hashlib.new(item["algorithm"])
            size = 0
            try:
                with opener().open(item["url"], timeout=60) as response, temporary.open("wb") as out:
                    while block := response.read(1 << 20):
                        digest.update(block)
                        size += len(block)
                        out.write(block)
                    out.flush()
                    os.fsync(out.fileno())
                break
            except urllib.error.HTTPError as error:
                raise ValueError(f"Download failed for {label}: HTTP {error.code}") from error
            except (urllib.error.URLError, TimeoutError, ConnectionError) as error:
                if isinstance(getattr(error, "reason", None), ValueError):
                    raise error.reason from error
                if attempt == attempts - 1:
                    raise ValueError(f"Download failed for {label}: {error}") from error
                time.sleep(2 * (attempt + 1))
        require(size > 0, f"Empty artifact: {label}")
        if item["bytes"] is not None:
            require(size == item["bytes"], f"Size mismatch for {label}")
        require(digest.hexdigest() == item["digest"], f"Digest mismatch for {label}")
        os.chmod(temporary, 0o644)
        os.replace(temporary, destination)
        return "fetched"
    finally:
        temporary.unlink(missing_ok=True)


def acquire(store, items, workers=6):
    store = Path(store)
    store.mkdir(mode=0o700, parents=True, exist_ok=True)
    for stale in store.glob(PARTIAL_PREFIX + "*"):
        stale.unlink()
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
        results = list(executor.map(lambda item: fetch(item, store), items))
    verify_store(store, items)
    return {state: results.count(state) for state in ("fetched", "present")}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("list", "acquire", "verify"))
    parser.add_argument("--store", type=Path)
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args()
    items = closed_set(args.root)
    if args.command == "list":
        for item in items:
            print(f"{item['kind']}\t{item['id']}\t{item['algorithm']}:{item['digest']}\t{item['url']}")
        print(f"{len(items)} artifacts, closed-set sha256 {closed_set_sha256(items)}")
        return
    require(args.store is not None, "--store is required")
    if args.command == "acquire":
        counts = acquire(args.store, items)
        print(f"Closed artifact set acquired: {counts['fetched']} fetched, "
              f"{counts['present']} already verified, {len(items)} total.")
    else:
        verify_store(args.store, items)
        print(f"Closed artifact store verified: {len(items)} artifacts, no addition.")


if __name__ == "__main__":
    try:
        main()
    except ValueError as error:
        print(error, file=sys.stderr)
        sys.exit(1)
