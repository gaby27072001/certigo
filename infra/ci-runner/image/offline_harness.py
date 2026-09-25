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
import json, socket, subprocess, sys, time
sys.path.insert(0, {INPUT_DIR!r})
from install_offline import NetworkSentinel
subprocess.run(["ip", "link", "set", "lo", "up"], check=True)
subprocess.run(["ip", "route", "add", "local", "0.0.0.0/0", "dev", "lo"], check=True)
sentinel = NetworkSentinel().start(families=(socket.AF_INET,))
result = subprocess.run(sys.argv[1:], capture_output=True, text=True, errors="replace",
                        env={{"PATH": {CHILD_PATH!r}, "LANG": "C.UTF-8",
                             "DEBIAN_FRONTEND": "noninteractive"}})
time.sleep(1)
events = sentinel.stop()
print(json.dumps({{"returncode": result.returncode, "output": (result.stdout + result.stderr)[-3000:],
                  "events": events[:20], "eventCount": len(events)}}))
"""
DRIFT_PACKAGE = """Package: certigo-drift-probe
Version: 1.0
Architecture: all
Maintainer: Certigo harness <noreply@example.invalid>
Description: Harness-only package simulating guest patching drift
"""
CONTROL_SOURCE = "deb http://azure.archive.ubuntu.com/ubuntu/ noble main\n"


def validate_boot(merged):
    return chroot_run(merged, "/usr/local/sbin/certigo-validate-toolchain", "--boot")


def expect_validation(merged, message):
    result = validate_boot(merged)
    output = result.stdout + result.stderr
    if message is None:
        require(result.returncode == 0, f"Boot validation failed: {output[-2000:]}")
    else:
        require(result.returncode != 0 and message in output,
                f"Boot validation did not refuse for the expected reason ({message}): {output[-2000:]}")
    return {"returncode": result.returncode, "reason": message or "valid"}


def post_install_checks(merged, legacy_inventory):
    """Guest patching simulation, drift detection at boot and runtime measurements."""
    (merged / OBSERVER.lstrip("/")).write_text(OBSERVER_SOURCE, encoding="utf-8")
    report = {"patching": {}, "drift": {}, "runtime": {}}
    commands = {
        "lpe.refresh": ["apt-get", "-q", "update"],
        "lpe.assessment": ["apt-get", "-s", "dist-upgrade"],
        "lpe.pro-client": ["apt-get", "install", "ubuntu-advantage-tools", "-y"],
        "lpe.mokutil": ["apt-get", "install", "-y", "-qq", "mokutil"],
        "unattended-upgrade": ["unattended-upgrade", "--dry-run", "-d"],
    }
    for name, command in commands.items():
        report["patching"][name] = observe(merged, *command)
        require(report["patching"][name]["eventCount"] == 0,
                f"{name} attempted network access in the final image")
    require(report["patching"]["lpe.refresh"]["returncode"] == 0, "apt-get update failed")
    require("0 upgraded, 0 newly installed" in report["patching"]["lpe.assessment"]["output"],
            "The assessment found an upgrade candidate")
    require(report["patching"]["lpe.pro-client"]["returncode"] != 0 and
            "Unable to locate package ubuntu-advantage-tools" in
            report["patching"]["lpe.pro-client"]["output"],
            "The platform Pro client installation did not fail for lack of source")
    control = merged / "etc/apt/sources.list.d/certigo-harness-control.list"
    control.write_text(CONTROL_SOURCE, encoding="utf-8")
    report["patching"]["control.refresh-with-source"] = observe(merged, "apt-get", "-q", "update")
    require(report["patching"]["control.refresh-with-source"]["eventCount"] > 0,
            "Positive control failed: the sentinel missed a refresh with a remote source")
    report["drift"]["valid"] = expect_validation(merged, None)
    report["drift"]["remote-source"] = expect_validation(merged, "a remote APT source is configured")
    control.unlink()
    for directory in ("var/lib/apt/lists",):
        for entry in (merged / directory).iterdir():
            if entry.is_file() and entry.name != "lock":
                entry.unlink()
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
    runtime = {
        "flutter": ["/usr/local/bin/flutter", "--version"],
        "dart": ["/usr/local/bin/dart", "--version"],
        "dotnet": ["/usr/local/bin/dotnet", "--version"],
        "node": ["/usr/local/bin/node", "--version"],
        "checkov": ["/usr/local/bin/checkov", "--version"],
    }
    for name, command in runtime.items():
        result = chroot_run(merged, "runuser", "-u", "runner", "--", "env",
                            "HOME=/tmp/certigo-runner-home", "CI=true",
                            "FLUTTER_ALREADY_LOCKED=true", "DOTNET_CLI_HOME=/tmp/certigo-dotnet",
                            "DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1", "DOTNET_NOLOGO=1",
                            "DOTNET_CLI_TELEMETRY_OPTOUT=1", *command, timeout=900)
        report["runtime"][name] = {"returncode": result.returncode,
                                   "output": (result.stdout + result.stderr)[-1500:]}
    if legacy_inventory:
        (merged / "tmp/legacy-inventory.sh").write_bytes(Path(legacy_inventory).read_bytes())
        outputs = {}
        for name, script in (("legacy", "/tmp/legacy-inventory.sh"),
                             ("batched", "/usr/local/sbin/certigo-inventory-toolchain")):
            started = time.monotonic()
            result = chroot_run(merged, "bash", script, f"/tmp/inventory-{name}.tsv",
                                env=chroot_env(LC_ALL="C"), timeout=14400)
            require(result.returncode == 0, f"{name} inventory failed: {result.stderr[-2000:]}")
            outputs[name] = {"seconds": round(time.monotonic() - started, 1),
                             "sha256": file_hash(merged / f"tmp/inventory-{name}.tsv"),
                             "records": len((merged / f"tmp/inventory-{name}.tsv").read_text().splitlines())}
        outputs["identical"] = outputs["legacy"]["sha256"] == outputs["batched"]["sha256"]
        report["inventoryEquivalence"] = outputs
        require(outputs["identical"], "Batched inventory differs from the legacy inventory")
    return report


def install(base, store, inputs, digest, work, extra_env=None, after=None):
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
            if after is not None:
                outcome["postInstall"] = after(merged)
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
                            "expect_pattern": r"Unexpected network attempt during flutter\.precache: "
                                              r"dns/(udp|tcp) pub\.dev"},
}


def run_scenario(name, base, store, work_root, legacy_inventory):
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
    outcome = install(base, scenario_store, inputs, digest, work / "overlay", spec.get("env"), after)
    if spec.get("positive"):
        passed = outcome["returncode"] == 0 and outcome["dpkgPackages"] == 665
        reason = "installed offline, zero network attempt" if passed else outcome["output"][-600:]
    else:
        expected = spec.get("expect")
        found = (expected in outcome["output"] if expected else
                 re.search(spec["expect_pattern"], outcome["output"]) is not None)
        passed = outcome["returncode"] != 0 and found
        reason = expected or spec["expect_pattern"]
    outcome.update({"scenario": name, "passed": passed, "expectedReason": reason})
    return outcome


def run_suite(rootfs, store, report_path, scenarios, legacy_inventory):
    base = verified_base(rootfs)
    image_artifacts.verify_store(store, closed_set())
    results = []
    with tempfile.TemporaryDirectory(prefix="certigo-suite-", dir=rootfs.parent) as tmp:
        for name in scenarios:
            print(f"=== scenario {name}", flush=True)
            outcome = run_scenario(name, base, store, Path(tmp), legacy_inventory)
            results.append(outcome)
            print(f"=== {name}: {'PASS' if outcome['passed'] else 'FAIL'} "
                  f"(exit {outcome['returncode']}, {outcome['seconds']} s)", flush=True)
            write_json(report_path, {"measuredAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                                     "qemu": qemu_version(), "results": results})
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
    args = parser.parse_args()
    if args.command == "build-base":
        build_base(args.store.resolve(), args.apt_cache.resolve(), args.rootfs.resolve())
    elif args.command == "finalize-base":
        finalize_base(args.rootfs.resolve())
    elif args.command == "capture-python-tags":
        capture_python_tags(args.rootfs.resolve(), args.store.resolve(), args.output)
    elif args.command == "run-suite":
        run_suite(args.rootfs.resolve(), args.store.resolve(), args.report.resolve(),
                  args.scenario or list(SCENARIOS), args.legacy_inventory)


if __name__ == "__main__":
    main()
