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
import time
from pathlib import Path

import image_artifacts
from image_artifacts import closed_set, store_name
from lock_apt import LOCK as APT_LOCK, load_indexes
from lock_inputs import (
    ROOT, checked_file, file_hash, paragraphs, read_json, require, serialize, sha256, write_json,
)

REPOSITORY = ROOT.parents[2]
CONTRACT = "image-build-contract.json"
CHILD_PATH = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
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
SYSTEMCTL_RECORDER = r"""#!/bin/bash
# Harness only: systemd is not PID 1 in this chroot. Unit-file verbs act on the
# image offline; runtime verbs are recorded and simulated.
printf '%s\n' "$*" >> /var/log/certigo-harness-systemctl.log
verb="$1"
shift
args=()
for arg in "$@"; do
  [[ "${arg}" == "--now" || "${arg}" == "--quiet" ]] || args+=("${arg}")
done
case "${verb}" in
  enable|disable|mask|unmask|is-enabled|preset|list-unit-files)
    exec /usr/bin/systemctl.certigo-real --root=/ "${verb}" "${args[@]}" ;;
  daemon-reload|start|stop|restart|reload|try-restart|reset-failed)
    exit 0 ;;
  is-active)
    exit 3 ;;
  *)
    echo "harness systemctl: unsupported verb ${verb}" >&2
    exit 1 ;;
esac
"""


def run(args, **kwargs):
    print("+", " ".join(str(a) for a in args), flush=True)
    return subprocess.run([str(a) for a in args], check=True, **kwargs)


def acquire_base(store):
    """Fetch the 656 reconstructed base archives with the installer's fetch policy."""
    items = [image_artifacts._artifact("deb", p["package"], p["url"], "sha256", p["sha256"],
                                       p["bytes"], p["sha256"] + ".deb") for p in base_packages()]
    store.mkdir(parents=True, exist_ok=True)
    for item in items:
        image_artifacts.fetch(item, store)
    for item in items:
        checked_file(store / image_artifacts.store_name(item), item["digest"], item["bytes"])
    print(f"Base archives verified: {len(items)}.")


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


STUB_RESOLV_CONF = "nameserver 127.0.0.53\noptions edns0 trust-ad\nsearch .\n"


def prepare_chroot(merged, store, inputs):
    real = merged / "usr/bin/systemctl.certigo-real"
    if not real.exists():
        os.rename(merged / "usr/bin/systemctl", real)
    (merged / "usr/bin/systemctl").write_text(SYSTEMCTL_RECORDER, encoding="utf-8")
    os.chmod(merged / "usr/bin/systemctl", 0o755)
    # Keep the image's systemd-resolved stub link; /run is a fresh tmpfs here.
    resolv = merged / "etc/resolv.conf"
    if resolv.is_symlink():
        target = Path(os.path.normpath(Path("/etc") / os.readlink(resolv)))
        resolv = merged / target.relative_to("/")
        resolv.parent.mkdir(parents=True, exist_ok=True)
    resolv.write_text(STUB_RESOLV_CONF, encoding="utf-8")
    input_target = merged / INPUT_DIR.lstrip("/")
    store_target = merged / STORE_DIR.lstrip("/")
    shutil.copytree(inputs, input_target, symlinks=False)
    store_target.mkdir(parents=True)
    run(["mount", "--bind", "-o", "ro", store, store_target])
    return store_target


def stage_inputs(destination):
    """Copy the contract and its inputs, as the image template delivers them."""
    contract = read_json(ROOT / CONTRACT)
    destination.mkdir(parents=True)
    for item in contract["inputs"]:
        shutil.copyfile(REPOSITORY / item["path"], destination / item["destination"])
    shutil.copyfile(ROOT / CONTRACT, destination / CONTRACT)
    return file_hash(destination / CONTRACT)


def rebind_contract(inputs):
    """Attacker model: the mutated inputs come with a matching contract."""
    contract = read_json(inputs / CONTRACT)
    for item in contract["inputs"]:
        item["sha256"] = file_hash(inputs / item["destination"])
    write_json(inputs / CONTRACT, contract)
    return file_hash(inputs / CONTRACT)


def chroot_env(**extra):
    return {"PATH": CHILD_PATH, "LANG": "C.UTF-8", **extra}


def chroot_run(merged, *command, env=None, network=False, timeout=None):
    prefix = [] if network else ["unshare", "--net", "--"]
    return subprocess.run([*prefix, "chroot", str(merged), *command], env=env or chroot_env(),
                          capture_output=True, text=True, errors="replace", timeout=timeout)


def observe(merged, *command):
    """Run a command under the installer's network sentinel (harness only)."""
    result = chroot_run(merged, "python3", "-E", "-s", "-B", OBSERVER, *command)
    require(result.returncode == 0, f"Observer failed: {result.stderr[-2000:]}")
    return json.loads(result.stdout.splitlines()[-1])


OBSERVER = "/tmp/certigo-harness-observe.py"
OBSERVER_SOURCE = f"""
import json, os, socket, subprocess, sys, time
sys.path.insert(0, {INPUT_DIR!r})
from install_offline import NetworkSentinel, self_test
subprocess.run(["ip", "link", "set", "lo", "up"], check=True)
subprocess.run(["ip", "route", "add", "local", "0.0.0.0/0", "dev", "lo"], check=True)
ipv6 = os.path.exists("/proc/net/if_inet6")
families = [socket.AF_INET]
if ipv6:
    subprocess.run(["ip", "-6", "route", "add", "local", "::/0", "dev", "lo"], check=True)
    families.append(socket.AF_INET6)
sentinel = NetworkSentinel().start(families=families)
self_test(sentinel, ipv6)
result = subprocess.run(sys.argv[1:], capture_output=True, text=True, errors="replace",
                        env={{"PATH": {CHILD_PATH!r}, "LANG": "C.UTF-8",
                             "DEBIAN_FRONTEND": "noninteractive"}})
time.sleep(1)
flows = {{name: count for name, count in sentinel.counters().items() if count}}
events = sentinel.stop()
print(json.dumps({{"returncode": result.returncode, "output": (result.stdout + result.stderr)[-3000:],
                  "events": events[:20], "eventCount": len(events), "flows": flows,
                  "attempts": len(events) + sum(flows.values())}}))
"""
DRIFT_PACKAGE = """Package: certigo-drift-probe
Version: 1.0
Architecture: all
Maintainer: Certigo harness <noreply@example.invalid>
Description: Harness-only package simulating guest patching drift
"""
CONTROL_SOURCE = "deb http://azure.archive.ubuntu.com/ubuntu/ noble main\n"
# Flows the listeners cannot name: only the connection-tracking counters see them.
SENTINEL_CONTROLS = {
    "udp-quic-443": ["python3", "-c", "import socket; s = socket.socket(socket.AF_INET, "
                     "socket.SOCK_DGRAM); s.sendto(b'x', ('198.51.100.7', 443))"],
    "tcp-8443": ["python3", "-c", "import socket\ntry:\n socket.create_connection("
                 "('198.51.100.7', 8443), timeout=2)\nexcept OSError:\n pass"],
    "ipv6-tcp-443": ["python3", "-c", "import socket\ntry:\n socket.create_connection("
                     "('2001:db8::7', 443), timeout=2)\nexcept OSError:\n pass"],
    "icmp-echo": ["ping", "-c", "1", "-W", "1", "198.51.100.7"],
    "raw-ip-253": ["python3", "-c", "import socket; s = socket.socket(socket.AF_INET, "
                   "socket.SOCK_RAW, 253); s.sendto(b'x', ('198.51.100.7', 0))"],
}


def validate_boot(merged):
    return observe(merged, "/usr/local/sbin/certigo-validate-toolchain", "--boot")


def expect_validation(merged, message):
    result = validate_boot(merged)
    output = result["output"]
    require(result["attempts"] == 0,
            f"Boot validation attempted network access: {result['events'][:3]} {result['flows']}")
    if message is None:
        require(result["returncode"] == 0, f"Boot validation failed: {output[-2000:]}")
    else:
        require(result["returncode"] != 0 and message in output,
                f"Boot validation did not refuse for the expected reason ({message}): {output[-2000:]}")
    return {"returncode": result["returncode"], "reason": message or "valid", "attempts": 0}


RUNNER_ENV = ["HOME=/tmp/certigo-runner-home", "CI=true", "FLUTTER_ALREADY_LOCKED=true",
              "FLUTTER_SUPPRESS_ANALYTICS=true", "DOTNET_CLI_HOME=/tmp/certigo-dotnet",
              "DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1", "DOTNET_NOLOGO=1", "DOTNET_CLI_TELEMETRY_OPTOUT=1",
              "NPM_CONFIG_UPDATE_NOTIFIER=false", "CKV_SKIP_PACKAGE_UPDATE_CHECK=true",
              "PYTHONDONTWRITEBYTECODE=1"]
# probe -> (command, expected output fragment)
RUNNER_PROBES = {
    "dotnet": (["/usr/local/bin/dotnet", "--version"], "8.0.424"),
    "node": (["/usr/local/bin/node", "--version"], "v20.20.2"),
    "npm": (["/usr/local/bin/npm", "--version"], "10.8.2"),
    "checkov": (["/usr/local/bin/checkov", "--version"], "3.2.495"),
    "python3": (["/usr/local/bin/python3", "--version"], "Python 3.12.3"),
    "bicep": (["/usr/local/bin/bicep", "--version"], "Bicep CLI version 0.44.1"),
    "actionlint": (["/usr/local/bin/actionlint", "-version"], "1.7.12"),
    "dart-format-3.6.0": (["/usr/local/bin/dart-format-3.6.0", "--version"], "Dart SDK version: 3.6.0"),
    # --job verifies the attested Flutter SDK bytes without executing it.
    "validate-job": (["/usr/local/sbin/certigo-validate-toolchain", "--job"],
                     "Immutable Certigo toolchain valid for job admission."),
}
# Defect 6 (README): the sealed SDK is read-only for runner. Kept red on purpose, with
# the exact failure, so that any other cause or a silent fix is noticed.
KNOWN_DEFECT_6 = {
    "flutter": (["/usr/local/bin/flutter", "--version"],
                ("bin/cache/engine.stamp.tmp.", "Permission denied")),
    "dart": (["/usr/local/bin/dart", "--version"],
             ("bin/cache/engine.stamp.tmp.", "Permission denied")),
}
LEGACY_ROOTS = ("opt/certigo/toolchains", "opt/actions-runner", "opt/az")
INVENTORY_ROOTS = {"CERTIGO_TOOLCHAIN_ROOT": "opt/certigo/toolchains",
                   "CERTIGO_RUNNER_HOME": "opt/actions-runner", "CERTIGO_AZURE_CLI_ROOT": "opt/az",
                   "CERTIGO_APT_ROOT": "etc/apt", "CERTIGO_CLOUD_CONFIG_ROOT": "etc/cloud/cloud.cfg.d"}


def gnu_coreutils_path(directory):
    """PATH preferring GNU coreutils: the host defaults to uutils, the image uses GNU."""
    listing = subprocess.run(["dpkg-query", "-L", "gnu-coreutils"], capture_output=True, text=True,
                             check=True).stdout.split()
    directory.mkdir()
    for path in listing:
        name = Path(path).name
        if path.startswith("/usr/bin/gnu") and len(name) > 3 and Path(path).is_file():
            (directory / name[3:]).symlink_to(path)
    require((directory / "stat").exists() and (directory / "sha256sum").exists(),
            "GNU coreutils are required on the harness host (package gnu-coreutils)")
    return f"{directory}:{os.environ['PATH']}"


def inventory_equivalence(merged, legacy_inventory, work):
    """Compare the batched inventory with the previous per-file one on the installed tree.

    The per-file version spawns several processes per file: hours under qemu. Both
    run natively with GNU coreutils against the installed overlay; a third, in-image
    run of the batched version proves that the image's own tools agree.
    """
    legacy = work / "legacy-inventory-roots-only.sh"
    text = Path(legacy_inventory).read_text(encoding="utf-8")
    for loop in ('for path in "${entries[@]}"; do', 'for path in "${optional_entries[@]}"; do'):
        require(text.count(loop) == 1, f"Unexpected legacy inventory shape: {loop}")
        text = text.replace(loop, "for path in; do")  # fixed entries are outside the roots
    legacy.write_text(text, encoding="utf-8")
    env = dict(os.environ, LC_ALL="C", PATH=gnu_coreutils_path(work / "gnu"),
               **{name: str(merged / relative) for name, relative in INVENTORY_ROOTS.items()})
    outputs, timings = {}, {}
    for name, command in (("legacy-native", ["bash", str(legacy)]),
                          ("batched-native", ["bash", str(ROOT / "inventory-toolchain.sh"),
                                              "--roots-only"])):
        started = time.monotonic()
        target = work / f"{name}.tsv"
        result = subprocess.run([*command, str(target)], env=env, capture_output=True, text=True,
                                timeout=14400)
        require(result.returncode == 0, f"{name} inventory failed: {result.stderr[-2000:]}")
        timings[name] = round(time.monotonic() - started, 1)
        outputs[name] = target.read_bytes().splitlines(keepends=True)
    started = time.monotonic()
    result = chroot_run(merged, "bash", "/usr/local/sbin/certigo-inventory-toolchain", "--roots-only",
                        "/tmp/inventory-batched-image.tsv", env=chroot_env(LC_ALL="C"), timeout=14400)
    require(result.returncode == 0, f"in-image inventory failed: {result.stderr[-2000:]}")
    timings["batched-image"] = round(time.monotonic() - started, 1)
    outputs["batched-image"] = (merged / "tmp/inventory-batched-image.tsv").read_bytes().splitlines(
        keepends=True)
    prefix = str(merged).encode()
    legacy_roots = tuple(prefix + b"/" + root.encode() for root in LEGACY_ROOTS)
    in_legacy_roots = [line for line in outputs["batched-native"]
                       if any(line.split(b"\t")[3] == root or line.split(b"\t")[3].startswith(root + b"/")
                              for root in legacy_roots)]
    unprefixed = [b"\t".join(fields[:3] + [fields[3][len(prefix):]] + fields[4:])
                  for fields in (line.split(b"\t") for line in outputs["batched-native"])]
    comparison = {
        "legacyRecords": len(outputs["legacy-native"]),
        "batchedRecords": len(outputs["batched-native"]),
        "legacyEqualsBatchedOnLegacyRoots": outputs["legacy-native"] == in_legacy_roots,
        "imageToolsEqualHostGnuTools": outputs["batched-image"] == unprefixed,
        "seconds": timings,
    }
    comparison["identical"] = (comparison["legacyEqualsBatchedOnLegacyRoots"] and
                               comparison["imageToolsEqualHostGnuTools"])
    require(comparison["identical"], f"Batched inventory differs: {comparison}")
    return comparison


def post_install_checks(merged, legacy_inventory):
    """Guest patching simulation, sentinel controls, runner probes, then drift at boot."""
    (merged / OBSERVER.lstrip("/")).write_text(OBSERVER_SOURCE, encoding="utf-8")
    report = {"patching": {}, "sentinelControls": {}, "drift": {}, "runtime": {},
              "knownDefects": {}}
    commands = {
        "lpe.refresh": ["apt-get", "-q", "update"],
        "lpe.assessment": ["apt-get", "-s", "dist-upgrade"],
        "lpe.pro-client": ["apt-get", "install", "ubuntu-advantage-tools", "-y"],
        "lpe.mokutil": ["apt-get", "install", "-y", "-qq", "mokutil"],
        "unattended-upgrade": ["unattended-upgrade", "--dry-run", "-d"],
    }
    for name, command in commands.items():
        report["patching"][name] = observe(merged, *command)
        require(report["patching"][name]["attempts"] == 0,
                f"{name} attempted network access in the final image")
    require(report["patching"]["lpe.refresh"]["returncode"] == 0, "apt-get update failed")
    require("0 upgraded, 0 newly installed" in report["patching"]["lpe.assessment"]["output"],
            "The assessment found an upgrade candidate")
    require(report["patching"]["lpe.pro-client"]["returncode"] != 0 and
            "Unable to locate package ubuntu-advantage-tools" in
            report["patching"]["lpe.pro-client"]["output"],
            "The platform Pro client installation did not fail for lack of source")
    for name, command in SENTINEL_CONTROLS.items():
        control = observe(merged, *command)
        report["sentinelControls"][name] = {"flows": control["flows"], "events": control["eventCount"]}
        require(control["attempts"] > 0, f"Sentinel control not observed: {name}")
    report["drift"]["valid"] = expect_validation(merged, None)
    def as_runner(command):
        result = chroot_run(merged, "runuser", "-u", "runner", "--", "env", *RUNNER_ENV, *command,
                            timeout=1800)
        output = (result.stdout + result.stderr).strip()
        return result.returncode, output, {"returncode": result.returncode, "output": output[-1500:]}

    for name, (command, expected) in RUNNER_PROBES.items():
        returncode, output, entry = as_runner(command)
        require(returncode == 0 and expected in output,
                f"Runner probe {name} failed or reported an unexpected version: {output[-800:]}")
        report["runtime"][name] = entry
    for name, (command, markers) in KNOWN_DEFECT_6.items():
        returncode, output, entry = as_runner(command)
        require(returncode != 0 and all(marker in output for marker in markers),
                f"{name}: known defect 6 changed, update the harness and README: {output[-800:]}")
        report["knownDefects"][name] = entry
    report["runnerRuntime"] = "blocked by defect 6: Flutter and Dart unusable by runner"
    control = merged / "etc/apt/sources.list.d/certigo-harness-control.list"
    control.write_text(CONTROL_SOURCE, encoding="utf-8")
    # Refused BEFORE any refresh could contact the new source.
    report["drift"]["remote-source-before-update"] = expect_validation(
        merged, "a remote APT source is configured")
    report["patching"]["control.refresh-with-source"] = observe(merged, "apt-get", "-q", "update")
    require(report["patching"]["control.refresh-with-source"]["attempts"] > 0,
            "Positive control failed: the sentinel missed a refresh with a remote source")
    control.unlink()
    for entry in (merged / "var/lib/apt/lists").iterdir():
        if entry.is_file() and entry.name != "lock":
            entry.unlink()
    report["drift"]["valid-after-source-removal"] = expect_validation(merged, None)
    seed = merged / "var/lib/snapd/seed/snaps"
    seed.mkdir(parents=True, exist_ok=True)
    (seed / "certigo-drift_1.snap").write_bytes(b"harness drift probe\n")
    report["drift"]["seeded-snap"] = expect_validation(
        merged, "a snap package is installed or seeded")
    (seed / "certigo-drift_1.snap").unlink()
    unmask = chroot_run(merged, "systemctl", "unmask", "apt-daily.timer")
    require(unmask.returncode == 0, f"unmask failed: {unmask.stderr}")
    report["drift"]["unmasked-timer"] = expect_validation(merged, "apt-daily.timer is not masked")
    chroot_run(merged, "systemctl", "mask", "apt-daily.timer")
    report["drift"]["valid-again"] = expect_validation(merged, None)
    probe = merged / "tmp/certigo-drift-probe"
    (probe / "DEBIAN").mkdir(parents=True)
    (probe / "DEBIAN/control").write_text(DRIFT_PACKAGE, encoding="utf-8")
    built = chroot_run(merged, "dpkg-deb", "--root-owner-group", "--build", "/tmp/certigo-drift-probe",
                       "/tmp/certigo-drift-probe.deb")
    require(built.returncode == 0, f"dpkg-deb failed: {built.stderr}")
    installed = chroot_run(merged, "dpkg", "-i", "/tmp/certigo-drift-probe.deb")
    require(installed.returncode == 0, f"dpkg -i failed: {installed.stderr}")
    report["drift"]["installed-package"] = expect_validation(
        merged, "installed package set differs from the attested image")
    if legacy_inventory:
        with tempfile.TemporaryDirectory(prefix="certigo-inventory-", dir=merged.parent.parent) as tmp:
            report["inventoryEquivalence"] = inventory_equivalence(merged, legacy_inventory, Path(tmp))
    return report


def install(base, store, inputs, digest, work, extra_env=None, after=None, keep=None):
    with overlay(base, work) as (merged, mounts):
        mounts.append(prepare_chroot(merged, store, inputs))
        started = time.monotonic()
        result = chroot_run(merged, "python3", "-E", "-s", "-B", f"{INPUT_DIR}/install_offline.py",
                            "install", "--inputs", INPUT_DIR, "--store", STORE_DIR,
                            "--contract-sha256", digest, env=chroot_env(**(extra_env or {})))
        outcome = {"returncode": result.returncode,
                   "seconds": round(time.monotonic() - started, 1),
                   "output": (result.stdout + result.stderr)[-4000:]}
        if result.returncode == 0:
            attestation = merged / "opt/certigo/runner-image/attestation.json"
            outcome["attestation"] = read_json(attestation)
            outcome["dpkgPackages"] = len(dpkg_state(merged))
            if keep is not None:
                # Development aid only: evidence always comes from one complete run.
                run(["cp", "-a", "--", str(work / "upper"), str(keep)])
            if after is not None:
                try:
                    outcome["postInstall"] = after(merged)
                except (ValueError, subprocess.TimeoutExpired) as error:
                    outcome["postInstallError"] = str(error)[-3000:]
        return outcome


def mutated_store(store, work, mutation):
    target = work / "store"
    run(["cp", "-al", store, target])
    if mutation == "store-addition":
        (target / ("sha256-" + "0" * 64)).write_bytes(b"unexpected artifact\n")
    elif mutation == "store-omission":
        entry = next(i for i in closed_set() if (i["kind"], i["id"]) == ("toolchain", "actionlint"))
        (target / store_name(entry)).unlink()
    elif mutation == "store-alteration":
        entry = next(i for i in closed_set() if (i["kind"], i["id"]) == ("deb", "zip:amd64"))
        path = target / store_name(entry)
        data = bytearray(path.read_bytes())
        data[len(data) // 2] ^= 0x01
        path.unlink()
        path.write_bytes(bytes(data))
    return target


def redirect_wheel(inputs):
    path = inputs / "python-wheels.lock.json"
    lock = read_json(path)
    wheel = lock["wheels"][0]
    wheel["url"] = "https://files.pythonhosted.org.evil.invalid/" + wheel["filename"]
    write_json(path, lock)


def skip_offline_pub(inputs):
    path = inputs / "install_offline.py"
    text = path.read_text()
    call = '        self.resolve_pub_offline(sdk, target / "pub-cache")\n'
    require(text.count(call) == 1, "Unexpected installer shape for the download mutation")
    path.write_text(text.replace(call, "        pass  # harness mutation: no offline Pub resolution\n"))


SCENARIOS = {
    "resolver-override": {"env": {"PUB_HOSTED_URL": "https://pub.evil.invalid"},
                          "expect": "Resolver override present in the installer environment: PUB_HOSTED_URL"},
    "lock-redirection": {"inputs": redirect_wheel,
                         "expect": "Image input digest mismatch: python-wheels.lock.json"},
    "contract-substitution": {"inputs": redirect_wheel, "rebind": True, "template_digest": True,
                              "expect": "The build contract does not match the template contract digest"},
    "store-addition": {"store": "store-addition",
                       "expect": "Unexpected file in the closed artifact store: sha256-" + "0" * 64},
    "store-omission": {"store": "store-omission", "expect": "Missing artifact toolchain:actionlint"},
    "store-alteration": {"store": "store-alteration", "expect": "Digest mismatch for deb:zip:amd64"},
    "positive": {"positive": True},
    "unexpected-download": {"inputs": skip_offline_pub, "rebind": True,
                            "expect_pattern": r"Unexpected network attempt during flutter\.(config|precache): "
                                              r"dns/(udp|tcp) pub\.dev"},
}


def run_scenario(name, base, store, work_root, legacy_inventory, keep=None):
    spec = SCENARIOS[name]
    work = work_root / name
    work.mkdir()
    inputs = work / "inputs"
    template_digest = stage_inputs(inputs)
    if "inputs" in spec:
        spec["inputs"](inputs)
    digest = rebind_contract(inputs) if spec.get("rebind") else template_digest
    if spec.get("template_digest"):
        digest = template_digest
    scenario_store = mutated_store(store, work, spec["store"]) if "store" in spec else store
    after = (lambda merged: post_install_checks(merged, legacy_inventory)) if spec.get("positive") else None
    outcome = install(base, scenario_store, inputs, digest, work / "overlay", spec.get("env"), after,
                      keep if spec.get("positive") else None)
    if spec.get("positive"):
        passed = (outcome["returncode"] == 0 and outcome.get("dpkgPackages") == 665 and
                  "postInstall" in outcome)
        reason = ("installed offline, zero network attempt, patching and drift checks passed"
                  if passed else outcome.get("postInstallError") or outcome["output"][-600:])
    else:
        expected = spec.get("expect")
        found = (expected in outcome["output"] if expected else
                 re.search(spec["expect_pattern"], outcome["output"]) is not None)
        passed = outcome["returncode"] != 0 and found
        reason = expected or spec["expect_pattern"]
    outcome.update({"scenario": name, "passed": passed, "expectedReason": reason})
    return outcome


def bound_digests():
    """Digests that a committed execution report must match to stay valid."""
    contract = read_json(ROOT / CONTRACT)
    inputs = [{key: item[key] for key in ("id", "path", "destination", "sha256")}
              for item in contract["inputs"]]
    canonical = json.dumps(inputs, sort_keys=True, separators=(",", ":")).encode()
    return {
        "contractInputsSha256": sha256(canonical),
        "reproducibility": {key: contract["reproducibility"][key] for key in (
            "aptPackageLockSha256", "flutterEngineArtifactLockSha256", "pythonWheelLockSha256")},
        "closedArtifactSetSha256": image_artifacts.closed_set_sha256(closed_set()),
        "harnessSha256": file_hash(Path(__file__).resolve()),
    }


def summarize(outcome):
    summary = {key: outcome[key] for key in ("scenario", "passed", "returncode", "seconds",
                                             "expectedReason")}
    refusal = [line for line in outcome["output"].splitlines() if "refused:" in line]
    summary["observedReason"] = refusal[0].split("refused: ", 1)[1] if refusal else None
    post = outcome.get("postInstall")
    if post:
        summary["dpkgPackages"] = outcome["dpkgPackages"]
        summary["attestation"] = {key: outcome["attestation"][key] for key in (
            "dpkgStateSha256", "closedArtifactSetSha256", "networkAttempts",
            "networkFlowCounters", "toolchainInventorySha256")}
        summary["installSeconds"] = round(sum(t["seconds"] for t in
                                              outcome["attestation"]["installTimings"]), 1)
        summary["patching"] = {name: {"returncode": item["returncode"], "attempts": item["attempts"]}
                               for name, item in post["patching"].items()}
        summary["sentinelControls"] = post["sentinelControls"]
        summary["drift"] = post["drift"]
        summary["runtime"] = {name: item["output"].splitlines()[-1] if item["output"] else ""
                              for name, item in post["runtime"].items()}
        summary["knownDefects"] = {name: item["returncode"] for name, item in
                                   post["knownDefects"].items()}
        summary["runnerRuntime"] = post["runnerRuntime"]
        summary["inventoryEquivalence"] = post.get("inventoryEquivalence")
    if outcome.get("postInstallError"):
        summary["postInstallError"] = outcome["postInstallError"][-800:]
    return summary


def write_evidence(reports, output):
    current = bound_digests()
    scenarios, environments = [], set()
    for path in reports:
        report = read_json(path)
        require(report.get("boundDigests") == current,
                f"Harness report {path} does not match the current inputs, locks or harness")
        environments.add(report["qemu"])
        scenarios.extend(summarize(result) for result in report["results"])
    names = [scenario["scenario"] for scenario in scenarios]
    require(sorted(names) == sorted(SCENARIOS), f"Evidence must cover every scenario once: {names}")
    require(all(scenario["passed"] for scenario in scenarios), "A scenario did not pass")
    write_json(output, {"schemaVersion": 1, "measuredAt": time.strftime("%Y-%m-%d", time.gmtime()),
                        "environment": {"host": "WSL2 Ubuntu 26.04 ARM64, amd64 through qemu-user",
                                        "qemu": sorted(environments)},
                        "boundDigests": current,
                        "scenarios": sorted(scenarios,
                                            key=lambda item: list(SCENARIOS).index(item["scenario"]))})
    print(f"Execution evidence written for {len(scenarios)} scenarios.")


def check_installed(rootfs, store, installed, report_path, legacy_inventory):
    """Development aid: rerun the post-install checks on a kept installation."""
    base = verified_base(rootfs)
    with tempfile.TemporaryDirectory(prefix="certigo-installed-", dir=rootfs.parent) as tmp:
        work = Path(tmp)
        run(["cp", "-a", "--", str(installed), str(work / "upper")])
        (work / "work").mkdir()
        (work / "merged").mkdir()
        run(["mount", "-t", "overlay", "overlay", "-o",
             f"lowerdir={base},upperdir={work / 'upper'},workdir={work / 'work'}", work / "merged"])
        merged = work / "merged"
        mounts = [merged]
        try:
            for source, target, options in (("proc", "proc", ["-t", "proc"]),
                                            ("sysfs", "sys", ["-t", "sysfs", "-o", "ro"]),
                                            ("/dev", "dev", ["--rbind"]), ("tmpfs", "run", ["-t", "tmpfs"])):
                run(["mount", *options, source, merged / target])
                mounts.append(merged / target)
            store_target = merged / STORE_DIR.lstrip("/")
            store_target.mkdir(parents=True, exist_ok=True)
            run(["mount", "--bind", "-o", "ro", store, store_target])
            mounts.append(store_target)
            try:
                report = {"postInstall": post_install_checks(merged, legacy_inventory)}
            except (ValueError, subprocess.TimeoutExpired) as error:
                report = {"postInstallError": str(error)[-3000:]}
        finally:
            for mount in reversed(mounts):
                subprocess.run(["umount", "--lazy", "--recursive", str(mount)], check=False)
    # Deliberately not a run-suite report: `evidence` refuses it.
    write_json(report_path, {"developmentOnly": True, **report})
    print("post-install checks:", "PASS" if "postInstall" in report else "FAIL")


def run_suite(rootfs, store, report_path, scenarios, legacy_inventory, keep=None):
    base = verified_base(rootfs)
    image_artifacts.verify_store(store, closed_set())
    digests = bound_digests()
    results = []
    with tempfile.TemporaryDirectory(prefix="certigo-suite-", dir=rootfs.parent) as tmp:
        for name in scenarios:
            print(f"=== scenario {name}", flush=True)
            outcome = run_scenario(name, base, store, Path(tmp), legacy_inventory, keep)
            results.append(outcome)
            print(f"=== {name}: {'PASS' if outcome['passed'] else 'FAIL'} "
                  f"(exit {outcome['returncode']}, {outcome['seconds']} s)", flush=True)
            write_json(report_path, {"measuredAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                                     "qemu": qemu_version(), "boundDigests": digests,
                                     "results": results})
    require(all(result["passed"] for result in results), "At least one scenario failed")
    print(f"All {len(results)} scenarios passed.")


def qemu_version():
    result = subprocess.run(["qemu-x86_64", "--version"], capture_output=True, text=True)
    return result.stdout.splitlines()[0] if result.returncode == 0 else "unknown"


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
    base = sub.add_parser("acquire-base")
    base.add_argument("--store", type=Path, required=True)
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
    suite = sub.add_parser("run-suite")
    suite.add_argument("--rootfs", type=Path, required=True)
    suite.add_argument("--store", type=Path, required=True)
    suite.add_argument("--report", type=Path, required=True)
    suite.add_argument("--scenario", action="append", choices=sorted(SCENARIOS))
    suite.add_argument("--legacy-inventory", type=Path,
                       help="Previous inventory-toolchain.sh, compared on the installed image")
    suite.add_argument("--keep-installed", type=Path,
                       help="Development aid: copy the positive installation's overlay here")
    checked = sub.add_parser("check-installed")
    checked.add_argument("--rootfs", type=Path, required=True)
    checked.add_argument("--store", type=Path, required=True)
    checked.add_argument("--installed", type=Path, required=True)
    checked.add_argument("--report", type=Path, required=True)
    checked.add_argument("--legacy-inventory", type=Path)
    evidence = sub.add_parser("evidence")
    evidence.add_argument("--report", type=Path, action="append", required=True)
    evidence.add_argument("--output", type=Path, default=ROOT / "offline-execution-evidence.json")
    args = parser.parse_args()
    if args.command == "acquire-base":
        acquire_base(args.store.resolve())
    elif args.command == "build-base":
        build_base(args.store.resolve(), args.apt_cache.resolve(), args.rootfs.resolve())
    elif args.command == "finalize-base":
        finalize_base(args.rootfs.resolve())
    elif args.command == "capture-python-tags":
        capture_python_tags(args.rootfs.resolve(), args.store.resolve(), args.output)
    elif args.command == "run-suite":
        run_suite(args.rootfs.resolve(), args.store.resolve(), args.report.resolve(),
                  args.scenario or list(SCENARIOS), args.legacy_inventory,
                  args.keep_installed.resolve() if args.keep_installed else None)
    elif args.command == "check-installed":
        check_installed(args.rootfs.resolve(), args.store.resolve(), args.installed.resolve(),
                        args.report.resolve(), args.legacy_inventory)
    elif args.command == "evidence":
        write_evidence(args.report, args.output)


if __name__ == "__main__":
    main()
