"""Local amd64 execution harness for the offline image installer (#341).

This is test tooling, never an image input. It rebuilds the reconstructed
Marketplace base (656 exact .deb files, verified by the APT lock and the signed
snapshot indexes) as an amd64 root filesystem, then runs install_offline.py in
it through qemu-user binfmt, chroot and an empty network namespace.

It is not a boot: systemd is not PID 1, so `systemctl` is replaced inside the
disposable overlay by a recorder that performs offline unit-file operations
with `--root=/` and simulates runtime ones. Requires root, mmdebstrap,
overlayfs, unshare and a registered amd64 binfmt handler.
"""

import argparse
import contextlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from lock_apt import LOCK as APT_LOCK, load_indexes
from lock_inputs import (
    ROOT, checked_file, file_hash, paragraphs, read_json, require, serialize, sha256, write_json,
)

REPOSITORY = ROOT.parents[2]
INPUT_DIR = "/tmp/certigo-image-input"
STORE_DIR = "/tmp/certigo-image-store"
AZURE_SOURCES = """Types: deb
URIs: http://azure.archive.ubuntu.com/ubuntu/
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://azure.archive.ubuntu.com/ubuntu/
Suites: noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
"""
SYSTEMCTL_RECORDER = r"""#!/bin/sh
# Harness only: systemd is not PID 1 in this chroot.
printf '%s\n' "$*" >> /var/log/certigo-harness-systemctl.log
case "$1" in
  enable|disable|mask|unmask|is-enabled|preset)
    exec /usr/bin/systemctl.certigo-real --root=/ "$@" ;;
  daemon-reload|start|stop|restart|reload|try-restart|reset-failed)
    exit 0 ;;
  is-active)
    exit 3 ;;
  list-unit-files)
    exec /usr/bin/systemctl.certigo-real --root=/ "$@" ;;
  *)
    echo "harness systemctl: unsupported verb $1" >&2
    exit 1 ;;
esac
"""


def run(args, **kwargs):
    print("+", " ".join(str(a) for a in args), flush=True)
    return subprocess.run([str(a) for a in args], check=True, **kwargs)


def base_packages():
    lock = read_json(APT_LOCK)
    base = [p for p in lock["snapshotResolvedPackages"] if p["origin"] == "reconstructed-base"]
    require(len(base) == 656, "Reconstructed base cardinality changed")
    return base


def build_repository(store, cache, repository):
    """Publish only the 656 verified base archives with their signed metadata."""
    _, indexes = load_indexes(cache)
    records = {}
    for _, index, text in indexes:
        if "binary-amd64/" not in index["path"]:
            continue
        for fields in paragraphs(text):
            records[(fields["Package"] + ":" + fields["Architecture"], fields["Version"])] = fields
    pool = repository / "pool"
    pool.mkdir(parents=True)
    stanzas = []
    for package in base_packages():
        fields = dict(records[(package["package"], package["version"])])
        require(fields["SHA256"] == package["sha256"], "Base metadata identity mismatch")
        source = checked_file(store / f"sha256-{package['sha256']}", package["sha256"], package["bytes"])
        target = pool / f"{package['sha256']}.deb"
        os.link(source, target)
        fields["Filename"] = f"pool/{target.name}"
        stanzas.append(serialize(fields))
    (repository / "Packages").write_text("".join(stanzas), encoding="utf-8")
    return [p["package"].split(":")[0] for p in base_packages()]


def dpkg_state(rootfs):
    output = subprocess.run(
        ["dpkg-query", "--admindir", str(rootfs / "var/lib/dpkg"), "-W",
         "-f", "${Package}:${Architecture}\t${Version}\t${db:Status-Abbrev}\n"],
        check=True, capture_output=True, text=True).stdout
    return sorted(line.rstrip() for line in output.splitlines() if line.strip())


def build_base(store, cache, rootfs):
    require(os.geteuid() == 0, "The harness base build requires root")
    require(not rootfs.exists(), f"Refusing to reuse an existing root filesystem: {rootfs}")
    with tempfile.TemporaryDirectory(prefix="certigo-base-repo-", dir=store.parent) as tmp:
        repository = Path(tmp)
        names = build_repository(store, cache, repository)
        run(["mmdebstrap", "--mode=root", "--variant=custom", "--architectures=amd64",
             "--include=" + ",".join(names),
             "--aptopt=Acquire::Languages \"none\"",
             "--dpkgopt=force-unsafe-io",
             "--customize-hook=rm -f \"$1/etc/apt/sources.list\"",
             "noble", str(rootfs), f"deb [trusted=yes] copy://{repository} ./"])
    finalize_base(rootfs)


def finalize_base(rootfs):
    """Verify the rebuilt base, drop harness-only settings, add Marketplace-like sources."""
    expected = sorted(f"{p['package']}\t{p['version']}\tii" for p in base_packages())
    actual = dpkg_state(rootfs)
    require(actual == expected, "Harness base differs from the reconstructed base inventory")
    for leftover in ("etc/apt/apt.conf.d/99mmdebstrap", "etc/dpkg/dpkg.cfg.d/99mmdebstrap"):
        (rootfs / leftover).unlink(missing_ok=True)
    sources = rootfs / "etc/apt/sources.list.d"
    sources.mkdir(parents=True, exist_ok=True)
    for entry in sources.iterdir():
        entry.unlink()
    (sources / "ubuntu.sources").write_text(AZURE_SOURCES, encoding="utf-8")
    (rootfs / "etc/apt/sources.list").write_text(
        "# Ubuntu sources have moved to /etc/apt/sources.list.d/ubuntu.sources\n",
        encoding="utf-8")
    state = "\n".join(actual) + "\n"
    marker = {"packages": len(actual), "dpkgStateSha256": sha256(state.encode()),
              "aptLockSha256": file_hash(APT_LOCK)}
    write_json(rootfs.with_name(rootfs.name + ".verified.json"), marker)
    print(f"Harness base verified: {len(actual)} packages equal the reconstructed base.")


def verified_base(rootfs):
    marker = read_json(rootfs.with_name(rootfs.name + ".verified.json"))
    state = "\n".join(dpkg_state(rootfs)) + "\n"
    require(marker["dpkgStateSha256"] == sha256(state.encode()) and
            marker["aptLockSha256"] == file_hash(APT_LOCK),
            "Harness base changed since its verification; rebuild it")
    return rootfs


@contextlib.contextmanager
def overlay(base, work):
    upper, workdir, merged = work / "upper", work / "work", work / "merged"
    for path in (upper, workdir, merged):
        path.mkdir(parents=True)
    run(["mount", "-t", "overlay", "overlay", "-o",
         f"lowerdir={base},upperdir={upper},workdir={workdir}", merged])
    mounts = [merged]
    try:
        for source, target, options in (
            ("proc", "proc", ["-t", "proc"]),
            ("sysfs", "sys", ["-t", "sysfs", "-o", "ro"]),
            ("/dev", "dev", ["--rbind"]),
            ("tmpfs", "run", ["-t", "tmpfs"]),
        ):
            destination = merged / target
            destination.mkdir(exist_ok=True)
            run(["mount", *options, source, destination])
            mounts.append(destination)
        yield merged, mounts
    finally:
        for mount in reversed(mounts):
            subprocess.run(["umount", "--lazy", "--recursive", str(mount)], check=False)


def prepare_chroot(merged, store, inputs):
    real = merged / "usr/bin/systemctl.certigo-real"
    if not real.exists():
        os.rename(merged / "usr/bin/systemctl", real)
    (merged / "usr/bin/systemctl").write_text(SYSTEMCTL_RECORDER, encoding="utf-8")
    os.chmod(merged / "usr/bin/systemctl", 0o755)
    shutil.copy2("/etc/resolv.conf", merged / "etc/resolv.conf", follow_symlinks=True)
    input_target = merged / INPUT_DIR.lstrip("/")
    store_target = merged / STORE_DIR.lstrip("/")
    shutil.copytree(inputs, input_target, symlinks=False)
    store_target.mkdir(parents=True)
    run(["mount", "--bind", "-o", "ro", store, store_target])
    return store_target


def run_consumer(base, store, inputs, work, command, stdout):
    with overlay(base, work) as (merged, mounts):
        mounts.append(prepare_chroot(merged, store, inputs))
        env = {"PATH": "/usr/sbin:/usr/bin:/sbin:/bin", "LANG": "C.UTF-8"}
        process = subprocess.run(
            ["unshare", "--net", "--", "chroot", str(merged), *command],
            env=env, stdout=stdout, stderr=subprocess.STDOUT, check=False)
        return process.returncode, merged


def capture_python_tags(rootfs, store, output):
    """Record the ordered tags supported by the target pip (maintenance step)."""
    lock = read_json(APT_LOCK)
    prewarm = next(t for t in lock["transactions"] if t["id"] == "prewarm")
    packages = {p["package"]: p for p in lock["packages"]}
    with tempfile.TemporaryDirectory(prefix="certigo-tags-", dir=rootfs.parent) as tmp:
        with overlay(verified_base(rootfs), Path(tmp)) as (merged, _):
            debs = merged / "tmp/certigo-tags"
            debs.mkdir()
            for name in prewarm["packages"]:
                item = packages[name]
                checked_file(store / f"sha256-{item['sha256']}", item["sha256"], item["bytes"])
                shutil.copyfile(store / f"sha256-{item['sha256']}", debs / f"{item['sha256']}.deb")
            script = ("set -eu; dpkg -i /tmp/certigo-tags/*.deb >/dev/null; "
                      "python3.12 -m venv /tmp/certigo-tags/venv; "
                      "/tmp/certigo-tags/venv/bin/python -m pip --version; "
                      "/tmp/certigo-tags/venv/bin/python -m pip debug --verbose")
            result = subprocess.run(["unshare", "--net", "--", "chroot", str(merged),
                                     "/bin/sh", "-c", script],
                                    env={"PATH": "/usr/sbin:/usr/bin:/sbin:/bin",
                                         "LANG": "C.UTF-8", "PIP_NO_INPUT": "1",
                                         "PIP_DISABLE_PIP_VERSION_CHECK": "1"},
                                    capture_output=True, text=True, check=True)
    lines = result.stdout.splitlines()
    version = lines[0]
    header = next(i for i, line in enumerate(lines) if line.startswith("Compatible tags: "))
    count = int(lines[header].split(": ", 1)[1])
    tags = [line.strip() for line in lines[header + 1:header + 1 + count]]
    require(len(tags) == count and all(re.fullmatch(r"[a-z0-9_.]+-[a-z0-9_.]+-[a-z0-9_.]+", t)
                                       for t in tags), "Unexpected pip debug output")
    require(version.startswith("pip 24.0 ") and "python 3.12" in version,
            f"Unexpected target pip: {version}")
    Path(output).write_text("\n".join(tags) + "\n", encoding="utf-8")
    print(f"Captured {count} target tags from {version.split(' from ')[0]}.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    build = sub.add_parser("build-base")
    build.add_argument("--store", type=Path, required=True)
    build.add_argument("--apt-cache", type=Path, required=True)
    build.add_argument("--rootfs", type=Path, required=True)
    finalize = sub.add_parser("finalize-base")
    finalize.add_argument("--rootfs", type=Path, required=True)
    tags = sub.add_parser("capture-python-tags")
    tags.add_argument("--rootfs", type=Path, required=True)
    tags.add_argument("--store", type=Path, required=True)
    tags.add_argument("--output", type=Path, default=ROOT / "python-target-tags.txt")
    args = parser.parse_args()
    if args.command == "build-base":
        build_base(args.store.resolve(), args.apt_cache.resolve(), args.rootfs.resolve())
    elif args.command == "finalize-base":
        finalize_base(args.rootfs.resolve())
    elif args.command == "capture-python-tags":
        capture_python_tags(args.rootfs.resolve(), args.store.resolve(), args.output)


if __name__ == "__main__":
    main()
