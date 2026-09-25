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
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from lock_apt import LOCK as APT_LOCK, load_indexes
from lock_inputs import ROOT, checked_file, paragraphs, read_json, require, serialize

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
    expected = sorted(f"{p['package']}\t{p['version']}\tii " for p in base_packages())
    actual = dpkg_state(rootfs)
    require(actual == expected, "Harness base differs from the reconstructed base inventory")
    sources = rootfs / "etc/apt/sources.list.d"
    sources.mkdir(parents=True, exist_ok=True)
    for entry in sources.iterdir():
        entry.unlink()
    (sources / "ubuntu.sources").write_text(AZURE_SOURCES, encoding="utf-8")
    (rootfs / "etc/apt/sources.list").write_text(
        "# Ubuntu sources have moved to /etc/apt/sources.list.d/ubuntu.sources\n",
        encoding="utf-8")
    print(f"Harness base rebuilt: {len(actual)} packages equal the reconstructed base.")


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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    build = sub.add_parser("build-base")
    build.add_argument("--store", type=Path, required=True)
    build.add_argument("--apt-cache", type=Path, required=True)
    build.add_argument("--rootfs", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "build-base":
        build_base(args.store.resolve(), args.apt_cache.resolve(), args.rootfs.resolve())


if __name__ == "__main__":
    main()
