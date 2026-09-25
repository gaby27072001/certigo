"""Offline installer of the Certigo runner image (#341).

Runs as root on the pinned Ubuntu 24.04 amd64 base inside an empty network
namespace (`unshare --net`). It consumes only the verified input files and the
closed artifact store produced by image_artifacts.py: no step may resolve,
download or substitute anything. Every byte is verified before it is used.

An in-namespace sentinel records every DNS query and every TCP connection to
the usual service ports. Any recorded attempt fails the installation, as does
any difference between the installed package set and the APT lock.

The legacy bootstrap is not modified. It runs confined once its packages are
already installed, the runner is already extracted and no APT source remains:
its `apt-get update/install` then resolve nothing and its downloads are skipped.
`installdependencies.sh` is never executed; its postconditions are verified.
"""

import argparse
import fcntl
import json
import os
import platform
import pwd
import re
import shutil
import socket
import stat
import struct
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

from image_artifacts import closed_set, closed_set_sha256, store_name, verify_store
from lock_flutter import ENGINE, FRAMEWORK, SOURCES, entrypoint_preconditions
from lock_inputs import file_hash, read_json, require

IMAGE_ROOT = Path("/opt/certigo/runner-image")
TOOLCHAIN_ROOT = Path("/opt/certigo/toolchains")
RUNNER_HOME = Path("/opt/actions-runner")
CONTRACT = "image-build-contract.json"
CHILD_PATH = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
RUNNER_LABELS = "certigo-pr-image-canary"
SENTINEL_PROBE = "certigo-sentinel-self-test.invalid"
TEST_NET = "192.0.2.1"
APT_AUTOMATION_UNITS = (
    "apt-daily.timer", "apt-daily-upgrade.timer", "apt-daily.service",
    "apt-daily-upgrade.service", "unattended-upgrades.service",
    # snap-repair fetches and runs vendor repair scripts from the network.
    "snapd.snap-repair.timer", "snapd.snap-repair.service",
)
DPKG_LOCKS = (
    "/var/lib/dpkg/lock-frontend", "/var/lib/dpkg/lock",
    "/var/lib/apt/lists/lock", "/var/cache/apt/archives/lock",
)
RESOLVER_OVERRIDES = re.compile(
    r"(?i)^(http_proxy|https_proxy|all_proxy|ftp_proxy|no_proxy|apt_config|"
    r"pip_.+|pub_.+|flutter_.+|dart_.+|npm_config_.+|nuget_.+|git_.+|"
    r"dotnet_install_dir|azure_cli_.+)$")
AUTO_UPGRADES = ('APT::Periodic::Update-Package-Lists "0";\n'
                 'APT::Periodic::Unattended-Upgrade "0";\n')
APT_PERIODIC = ('// Certigo immutable runner image (#341): no periodic APT activity.\n'
                'APT::Periodic::Enable "0";\n'
                'APT::Periodic::Update-Package-Lists "0";\n'
                'APT::Periodic::Download-Upgradeable-Packages "0";\n'
                'APT::Periodic::Unattended-Upgrade "0";\n'
                'APT::Periodic::AutocleanInterval "0";\n')
CLOUD_INIT_APT = ("# Certigo immutable runner image (#341): never regenerate APT sources.\n"
                  "apt:\n"
                  "  preserve_sources_list: true\n"
                  "package_update: false\n"
                  "package_upgrade: false\n"
                  "package_reboot_if_required: false\n")
SOURCES_LIST = "# Certigo immutable runner image (#341): no remote APT source.\n"
PATCHING_FILES = {
    Path("/etc/apt/apt.conf.d/20auto-upgrades"): AUTO_UPGRADES,
    Path("/etc/apt/apt.conf.d/99certigo-immutable-image"): APT_PERIODIC,
    Path("/etc/cloud/cloud.cfg.d/99-certigo-immutable-image.cfg"): CLOUD_INIT_APT,
    Path("/etc/apt/sources.list"): SOURCES_LIST,
}


class NetworkSentinel:
    """Record DNS queries and TCP connections attempted inside the namespace.

    With AnyIP routes, every IPv4/IPv6 destination is local to the namespace,
    so connections reach these listeners instead of failing silently.
    """

    TCP_PORTS = (22, 53, 80, 443, 9418, 11371)

    def __init__(self):
        self.events = []
        self._lock = threading.Lock()
        self._sockets = []
        self._stopping = threading.Event()

    def record(self, **event):
        with self._lock:
            self.events.append(event)

    def snapshot(self):
        with self._lock:
            return list(self.events)

    def clear(self):
        with self._lock:
            self.events.clear()

    def _bind(self, family, kind, port):
        sock = socket.socket(family, kind)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        if family == socket.AF_INET6:
            sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 1)
        if family == socket.AF_INET and kind == socket.SOCK_DGRAM:
            sock.setsockopt(socket.IPPROTO_IP, socket.IP_PKTINFO, 1)
        sock.bind(("::" if family == socket.AF_INET6 else "0.0.0.0", port))
        if kind == socket.SOCK_STREAM:
            sock.listen(64)
        self._sockets.append(sock)
        return sock

    def start(self, families=(socket.AF_INET, socket.AF_INET6), port_offset=0):
        for family in families:
            udp = self._bind(family, socket.SOCK_DGRAM, 53 + port_offset)
            threading.Thread(target=self._dns_udp, args=(udp,), daemon=True).start()
            for port in self.TCP_PORTS:
                tcp = self._bind(family, socket.SOCK_STREAM, port + port_offset)
                threading.Thread(target=self._tcp, args=(tcp, port), daemon=True).start()
        return self

    def stop(self):
        self._stopping.set()
        events = self.snapshot()
        for sock in self._sockets:
            try:
                sock.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            sock.close()
        return events

    @staticmethod
    def question_end(message):
        offset = 12
        while offset < len(message):
            length = message[offset]
            if length == 0:
                return offset + 5 if offset + 5 <= len(message) else None
            if length & 0xC0:
                return None
            offset += 1 + length
        return None

    @staticmethod
    def query_name(message):
        if len(message) < 12:
            return None
        labels, offset = [], 12
        while offset < len(message):
            length = message[offset]
            if length == 0:
                return ".".join(labels)
            if length & 0xC0 or offset + 1 + length > len(message):
                return None
            labels.append(message[offset + 1:offset + 1 + length].decode("ascii", "replace"))
            offset += 1 + length
        return None

    @classmethod
    def refused(cls, message):
        end = cls.question_end(message) if len(message) >= 12 else None
        if end is None:
            return message[:2] + struct.pack("!HHHHH", 0x8005, 0, 0, 0, 0) if len(message) >= 2 else b""
        flags = 0x8000 | (message[2] & 0x79) << 8 | 0x0005
        return message[:2] + struct.pack("!HHHHH", flags, 1, 0, 0, 0) + message[12:end]

    def _dns_udp(self, sock):
        while not self._stopping.is_set():
            try:
                message, ancillary, _, peer = sock.recvmsg(4096, socket.CMSG_SPACE(12))
            except OSError:
                return
            if self._stopping.is_set() or peer is None:
                # A shut-down socket returns an empty datagram: not an attempt.
                return
            destination = None
            for level, kind, data in ancillary:
                if level == socket.IPPROTO_IP and kind == socket.IP_PKTINFO and len(data) >= 12:
                    destination = socket.inet_ntoa(data[8:12])
            self.record(protocol="dns/udp", destination=destination,
                        query=self.query_name(message))
            try:
                sock.sendto(self.refused(message), peer)
            except OSError:
                pass

    def _tcp(self, sock, port):
        while not self._stopping.is_set():
            try:
                connection, _ = sock.accept()
            except OSError:
                return
            if self._stopping.is_set():
                connection.close()
                return
            with connection:
                destination = connection.getsockname()[0]
                if port == 53:
                    connection.settimeout(2)
                    try:
                        size = struct.unpack("!H", connection.recv(2))[0]
                        message = connection.recv(size)
                        self.record(protocol="dns/tcp", destination=destination,
                                    query=self.query_name(message))
                        reply = self.refused(message)
                        connection.sendall(struct.pack("!H", len(reply)) + reply)
                    except (OSError, struct.error):
                        self.record(protocol="dns/tcp", destination=destination, query=None)
                else:
                    self.record(protocol="tcp", destination=destination, port=port)


class Installer:
    def __init__(self, inputs, store, contract_sha256, work):
        self.inputs = Path(inputs)
        self.store = Path(store)
        self.contract_sha256 = contract_sha256
        self.work = Path(work)
        self.timings = []
        self.sentinel = None
        self.log = self.work / "install.log"

    # ------------------------------------------------------------------ helpers
    def env(self, **extra):
        home = self.work / "home"
        home.mkdir(mode=0o700, exist_ok=True)
        base = {
            "PATH": CHILD_PATH, "LANG": "C.UTF-8", "LC_ALL": "C.UTF-8", "HOME": str(home),
            "DEBIAN_FRONTEND": "noninteractive",
            # Flutter/Pub bot detection: no Azure IMDS probe and no remote
            # version check (bot_detector.dart, flutter_command_runner.dart).
            "CI": "true",
            "DOTNET_CLI_TELEMETRY_OPTOUT": "1", "DOTNET_NOLOGO": "1",
            "DOTNET_SKIP_FIRST_TIME_EXPERIENCE": "1",
            "DOTNET_CLI_WORKLOAD_UPDATE_NOTIFY_DISABLE": "1",
            "DOTNET_GENERATE_ASPNET_CERTIFICATE": "false",
            "AZURE_CORE_COLLECT_TELEMETRY": "false",
            # Seeded by seed_azure_cli_versions(): see its docstring.
            "AZURE_CONFIG_DIR": str(self.work / "azure"),
            "NPM_CONFIG_UPDATE_NOTIFIER": "false",
        }
        base.update(extra)
        return base

    def run(self, step, args, env=None, cwd=None, check=True):
        started = time.monotonic()
        with self.log.open("a", encoding="utf-8") as log:
            log.write(f"\n### {step}: {' '.join(str(a) for a in args)}\n")
        result = subprocess.run([str(a) for a in args], env=env or self.env(), cwd=cwd,
                                capture_output=True, text=True, errors="replace",
                                stdin=subprocess.DEVNULL)
        with self.log.open("a", encoding="utf-8") as log:
            log.write(result.stdout)
            log.write(result.stderr)
        self.timings.append({"step": step, "seconds": round(time.monotonic() - started, 3)})
        # A network attempt is the reported cause even when the tool then fails.
        self.assert_no_network_attempt(step)
        if check and result.returncode != 0:
            tail = "\n".join((result.stdout + result.stderr).splitlines()[-25:])
            raise ValueError(f"{step} failed ({result.returncode}):\n{tail}")
        return result

    def input(self, name):
        return self.inputs / name

    # ---------------------------------------------------------------- preflight
    def preflight(self):
        require(os.geteuid() == 0, "Run the offline image installer as root")
        require(platform.machine() == "x86_64", "The pinned runner image supports x86_64 only")
        release = dict(line.split("=", 1) for line in
                       Path("/etc/os-release").read_text().splitlines() if "=" in line)
        require(release.get("ID") == "ubuntu" and release.get("VERSION_ID") == '"24.04"',
                "The pinned runner image requires Ubuntu 24.04")
        overrides = sorted(name for name in os.environ if RESOLVER_OVERRIDES.match(name))
        if overrides:
            raise ValueError(f"Resolver override present in the installer environment: {overrides[0]}")
        interfaces = [name for _, name in socket.if_nameindex()]
        require(interfaces == ["lo"],
                "Offline installation must run in an empty network namespace (unshare --net)")
        for directory in (Path("/var/lib/snapd/snaps"), Path("/var/lib/snapd/seed/snaps")):
            found = sorted(directory.glob("*.snap")) if directory.exists() else []
            if found:
                raise ValueError(f"Snap package present; it would refresh from the network: {found[0]}")

    def verify_inputs(self):
        contract_path = self.input(CONTRACT)
        require(contract_path.is_file() and not contract_path.is_symlink(),
                "The build contract is missing")
        require(file_hash(contract_path) == self.contract_sha256,
                "The build contract does not match the template contract digest")
        contract = read_json(contract_path)
        expected = {CONTRACT}
        for item in contract["inputs"]:
            path = self.input(item["destination"])
            require(path.is_file() and not path.is_symlink(),
                    f"Missing or non-regular image input: {item['destination']}")
            require(file_hash(path) == item["sha256"],
                    f"Image input digest mismatch: {item['destination']}")
            expected.add(item["destination"])
        present = {entry.name for entry in self.inputs.iterdir()}
        unexpected = sorted(present - expected)
        if unexpected:
            raise ValueError(f"Unexpected file in the image inputs: {unexpected[0]}")
        loaded = [Path(__file__)] + [Path(sys.modules[name].__file__) for name in
                                     ("image_artifacts", "lock_flutter", "lock_inputs")]
        for path in loaded:
            require(path.name in expected and file_hash(path) == file_hash(self.input(path.name)),
                    f"The running installer differs from the verified input: {path.name}")
        self.contract = contract
        self.manifest = read_json(self.input("toolchain-manifest.json"))
        self.apt = read_json(self.input("apt-packages.lock.json"))
        self.flutter = read_json(self.input("flutter-engine-artifacts.lock.json"))
        self.wheels = read_json(self.input("python-wheels.lock.json"))
        reproducibility = contract["reproducibility"]
        checks = (
            (self.apt["inputs"]["bootstrapSha256"], "bootstrap.sh"),
            (self.apt["inputs"]["prewarmSha256"], "prewarm-toolchain.sh"),
            (self.apt["inputs"]["manifestSha256"], "toolchain-manifest.json"),
            (self.flutter["manifestSha256"], "toolchain-manifest.json"),
            (self.wheels["requirementsSha256"], "toolchain-requirements.lock"),
            (self.manifest["artifacts"]["pythonLockSha256"], "toolchain-requirements.lock"),
            (self.manifest["artifacts"]["sbomSha256"], "toolchain-sbom.cyclonedx.document"),
            (reproducibility["aptPackageLockSha256"], "apt-packages.lock.json"),
            (reproducibility["flutterEngineArtifactLockSha256"],
             "flutter-engine-artifacts.lock.json"),
        )
        for digest, name in checks:
            require(digest == file_hash(self.input(name)), f"Lock input is stale: {name}")
        require(self.apt["baseEvidenceSha256"] == reproducibility["baseImageInventory"]["sha256"],
                "APT lock and contract disagree on the base image evidence")
        flutter_tool = next(t for t in self.manifest["tools"] if t["id"] == "flutter")
        require(self.flutter["sdkArchive"] == flutter_tool["source"],
                "Flutter lock and manifest disagree on the SDK archive")
        require(self.manifest["contentTools"]["prewarmedProjectDependencies"] == [],
                "Project dependencies must never be prewarmed into the image")

    def verify_closed_store(self):
        self.items = closed_set(self.inputs)
        self.entries = verify_store(self.store, self.items)
        self.by_identity = {(item["kind"], item["id"]): self.store / store_name(item)
                            for item in self.items}

    def artifact(self, kind, ident):
        return self.by_identity[(kind, ident)]

    def stage(self, kind, directory):
        """Name verified store entries as their tools expect, without copying."""
        target = self.work / directory
        target.mkdir()
        for item in self.items:
            if item["kind"] == kind:
                (target / item["filename"]).symlink_to(self.store / store_name(item))
        return target

    # ----------------------------------------------------------------- network
    def isolate_network(self):
        self.run("network.loopback", ["ip", "link", "set", "lo", "up"])
        self.run("network.anyip4", ["ip", "route", "add", "local", "0.0.0.0/0", "dev", "lo"])
        families = [socket.AF_INET]
        if Path("/proc/net/if_inet6").exists():
            self.run("network.anyip6", ["ip", "-6", "route", "add", "local", "::/0", "dev", "lo"])
            families.append(socket.AF_INET6)
        self.sentinel = NetworkSentinel().start(families=families)
        try:
            socket.getaddrinfo(SENTINEL_PROBE, 443)
        except socket.gaierror:
            pass
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
            probe.settimeout(2)
            try:
                probe.connect((TEST_NET, 443))
            except OSError:
                pass
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            events = self.sentinel.snapshot()
            dns = any((e.get("query") or "").startswith(SENTINEL_PROBE) for e in events)
            tcp = any(e.get("protocol") == "tcp" and e.get("destination") == TEST_NET
                      for e in events)
            if dns and tcp:
                break
            time.sleep(0.1)
        require(dns, "Network sentinel did not observe its DNS self-test")
        require(tcp, "Network sentinel did not observe its TCP self-test")
        self.sentinel.clear()

    def assert_no_network_attempt(self, step):
        events = self.sentinel.snapshot() if self.sentinel else []
        if events:
            first = events[0]
            target = first.get("query") or f"{first.get('destination')}:{first.get('port')}"
            raise ValueError(f"Unexpected network attempt during {step}: "
                             f"{first['protocol']} {target} ({len(events)} recorded)")

    # --------------------------------------------------------------------- APT
    def dpkg_state(self):
        output = self.run("dpkg.state", ["dpkg-query", "-W", "-f",
                                         "${Package}:${Architecture}\t${Version}\t${db:Status-Abbrev}\n"]).stdout
        return sorted(line.rstrip() for line in output.splitlines() if line.strip())

    def expected_state(self, include_transactions, held=()):
        rows = []
        for package in self.apt["snapshotResolvedPackages"]:
            if package["origin"] != "reconstructed-base" and not include_transactions:
                continue
            flag = "hi" if package["package"].split(":")[0] in held else "ii"
            rows.append(f"{package['package']}\t{package['version']}\t{flag}")
        return sorted(rows)

    def require_state(self, expected, reason):
        actual = self.dpkg_state()
        if actual != expected:
            missing = sorted(set(expected) - set(actual))
            extra = sorted(set(actual) - set(expected))
            detail = (f"missing {missing[0]}" if missing else f"unexpected {extra[0]}")
            raise ValueError(f"{reason}: {detail} ({len(missing)} missing, {len(extra)} unexpected)")

    def wait_for_package_locks(self, timeout=600):
        deadline = time.monotonic() + timeout
        for path in DPKG_LOCKS:
            if not os.path.exists(path):
                continue
            while True:
                with open(path, "a+") as handle:
                    try:
                        fcntl.lockf(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
                        fcntl.lockf(handle, fcntl.LOCK_UN)
                        break
                    except OSError:
                        require(time.monotonic() < deadline,
                                f"Package manager lock is still held: {path}")
                time.sleep(2)

    def neutralize_apt_automation(self):
        self.run("apt-automation.stop", ["systemctl", "stop", *APT_AUTOMATION_UNITS], check=False)
        self.run("apt-automation.mask", ["systemctl", "mask", *APT_AUTOMATION_UNITS])
        self.wait_for_package_locks()

    def remove_apt_sources(self):
        parts = Path("/etc/apt/sources.list.d")
        if parts.exists():
            for entry in parts.iterdir():
                require(entry.is_file() or entry.is_symlink(),
                        f"Unexpected APT source entry: {entry}")
                entry.unlink()
        Path("/etc/apt/sources.list").write_text(SOURCES_LIST, encoding="utf-8")
        lists = Path("/var/lib/apt/lists")
        if lists.exists():
            for entry in lists.iterdir():
                if entry.name in ("lock", "partial"):
                    continue
                if entry.is_dir() and not entry.is_symlink():
                    shutil.rmtree(entry)
                else:
                    entry.unlink()
        self.require_no_apt_source("after source removal")

    def require_no_apt_source(self, when):
        targets = self.run("apt.indextargets", ["apt-get", "indextargets", "--format", "$(URI)"]).stdout
        if targets.strip():
            raise ValueError(f"Remote APT source configured {when}: {targets.split()[0]}")

    def install_debs(self):
        staged = self.stage("deb", "debs")
        filenames = {item["id"]: staged / item["filename"] for item in self.items
                     if item["kind"] == "deb"}
        versions = {p["package"]: p["version"] for p in self.apt["packages"]}
        for transaction in self.apt["transactions"]:
            if not transaction["packages"]:
                continue
            files = [filenames[name] for name in transaction["packages"]]
            self.run(f"apt.install.{transaction['id']}",
                     ["apt-get", "install", "-y", *transaction["options"], *files])
            self.assert_no_network_attempt(f"APT transaction {transaction['id']}")
            for name in transaction["packages"]:
                version = self.run("dpkg.version", ["dpkg-query", "-W", "-f",
                                                    "${Version}\t${db:Status-Abbrev}", name]).stdout
                require(version.split("\t")[0] == versions[name] and
                        version.split("\t")[1].startswith("ii"),
                        f"Locked package was not installed exactly: {name}")
        self.run("apt.hold", ["apt-mark", "hold", "azure-cli"])
        self.require_state(self.expected_state(True, held={"azure-cli"}),
                           "Installed packages differ from the APT lock")
        self.run("apt.check", ["apt-get", "check"])
        audit = self.run("dpkg.audit", ["dpkg", "--audit"]).stdout
        require(not audit.strip(), "dpkg reports half-installed packages")
        self.seed_azure_cli_versions()

    def seed_azure_cli_versions(self):
        """Keep Azure CLI from checking its latest version during installation.

        Azure CLI 2.89.0 runs handle_version_update() in AzCli.__init__, before any
        command: with an empty versionCheck.json it sends a HEAD request to
        azcliprod.blob.core.windows.net (util.py get_cached_latest_versions ->
        check_connectivity), whatever the command and with telemetry disabled. The
        installer's private configuration directory is seeded offline with the
        locally installed versions, computed by Azure CLI's own code.
        """
        config = self.work / "azure"
        config.mkdir(mode=0o700, exist_ok=True)
        code = ("import datetime, json, sys\n"
                "from azure.cli.core.util import _get_local_versions\n"
                "versions = _get_local_versions()\n"
                "assert versions['core']['local'], versions\n"
                "json.dump({'versions': versions, 'update_time': str(datetime.datetime.now())},\n"
                "          open(sys.argv[1], 'w'))\n")
        self.run("azure-cli.version-cache", ["/opt/az/bin/python3", "-E", "-s", "-c", code,
                                             config / "versionCheck.json"])

    # ------------------------------------------------------------------ runner
    def install_runner(self):
        RUNNER_HOME.mkdir(mode=0o755, exist_ok=True)
        archive = self.artifact("toolchain", "github-actions-runner")
        self.run("runner.extract", ["tar", "--extract", "--gzip", "--file", archive,
                                    "--directory", RUNNER_HOME])
        script = RUNNER_HOME / "bin/installdependencies.sh"
        require(file_hash(script) == self.apt["inputs"]["runnerDependencyScriptSha256"],
                "Runner dependency recipe differs from the one resolved by the APT lock")
        for transaction in self.apt["transactions"]:
            if not transaction["id"].startswith("runner-"):
                continue
            for requested in transaction["requested"]:
                name = requested.rstrip("$")
                state = self.run("runner.dependency", ["dpkg-query", "-W", "-f",
                                                       "${db:Status-Abbrev}", name]).stdout
                require(state.startswith("ii") or state.startswith("hi"),
                        f"installdependencies.sh postcondition failed: {name}")

    def run_confined_bootstrap(self):
        before = self.dpkg_state()
        result = self.run("bootstrap.confined", ["bash", self.input("bootstrap.sh")],
                          env=self.env(CERTIGO_RUNNER_LABELS=RUNNER_LABELS,
                                       CERTIGO_BLOCK_IMDS="true"),
                          cwd=self.inputs)
        require("Base image prepared." in result.stdout,
                "The confined bootstrap did not stop at base preparation")
        self.assert_no_network_attempt("the confined bootstrap")
        require(self.dpkg_state() == before, "The confined bootstrap changed installed packages")
        self.require_no_apt_source("after the confined bootstrap")
        installed = Path("/usr/local/sbin/certigo-runner-bootstrap")
        require(file_hash(installed) == file_hash(self.input("bootstrap.sh")),
                "Installed bootstrap differs from the verified input")
        for path in ("/usr/local/sbin/certigo-runner-restart", "/etc/sudoers.d/certigo-runner",
                     "/usr/local/sbin/certigo-block-imds",
                     "/etc/systemd/system/certigo-block-imds.service",
                     "/etc/certigo-runner-bootstrap.env"):
            require(Path(path).is_file(), f"Confined bootstrap did not produce {path}")
        pwd.getpwnam("runner")

    # -------------------------------------------------------------- toolchains
    def version_of(self, ident):
        return next(t["version"] for t in self.manifest["tools"] if t["id"] == ident)

    def replace_directory(self, path):
        if path.exists():
            shutil.rmtree(path)
        path.mkdir(mode=0o755, parents=True)
        return path

    def install_archives(self):
        TOOLCHAIN_ROOT.mkdir(mode=0o755, parents=True, exist_ok=True)
        node = self.replace_directory(TOOLCHAIN_ROOT / f"node-{self.version_of('node')}")
        self.run("node.extract", ["tar", "-xJf", self.artifact("toolchain", "node"),
                                  "--strip-components=1", "-C", node])
        dotnet = self.replace_directory(TOOLCHAIN_ROOT / f"dotnet-{self.version_of('dotnet-sdk')}")
        self.run("dotnet-sdk.extract", ["tar", "-xzf", self.artifact("toolchain", "dotnet-sdk"),
                                        "-C", dotnet])
        dart = self.replace_directory(TOOLCHAIN_ROOT / f"dart-{self.version_of('dart-formatter')}")
        self.run("dart-formatter.extract", ["unzip", "-q", self.artifact("toolchain", "dart-formatter"),
                                            "-d", dart])
        bicep = self.replace_directory(TOOLCHAIN_ROOT / f"bicep-{self.version_of('bicep')}")
        shutil.copyfile(self.artifact("toolchain", "bicep"), bicep / "bicep")
        os.chmod(bicep / "bicep", 0o755)
        actionlint = self.replace_directory(
            TOOLCHAIN_ROOT / f"actionlint-{self.version_of('actionlint')}")
        self.run("actionlint.extract", ["tar", "-xzf", self.artifact("toolchain", "actionlint"),
                                        "-C", actionlint, "actionlint"])
        os.chmod(actionlint / "actionlint", 0o755)
        self.assert_no_network_attempt("toolchain archive extraction")

    # ----------------------------------------------------------------- Flutter
    def flutter_root(self):
        return TOOLCHAIN_ROOT / f"flutter-{self.version_of('flutter')}"

    def sdk_tree(self, sdk):
        """Regular files and directories, as tar members were classified by the lock."""
        files, directories = set(), set()
        for current, dirs, names in os.walk(sdk):
            relative = os.path.relpath(current, sdk)
            prefix = "" if relative == "." else relative + "/"
            for name in dirs:
                if not (Path(current) / name).is_symlink():
                    directories.add(prefix + name)
            for name in names:
                path = Path(current) / name
                if not path.is_symlink() and path.is_file():
                    files.add(prefix + name)
        return files, directories

    def verify_flutter_preconditions(self, sdk):
        files, directories = self.sdk_tree(sdk)
        contents = {}
        for relative in files:
            if relative in SOURCES or re.fullmatch(r"bin/cache/[^/]+\.stamp", relative):
                contents[relative] = (sdk / relative).read_bytes()
        for relative, digest in self.flutter["sdkSourceSha256"].items():
            require(relative in contents and file_hash(sdk / relative) == digest,
                    f"Extracted Flutter SDK differs from the evaluated graph: {relative}")
        mtimes = {name: int(os.stat(sdk / name).st_mtime) for name in
                  ("packages/flutter_tools/pubspec.yaml", "packages/flutter_tools/pubspec.lock")}
        observed = entrypoint_preconditions(files, directories, contents, mtimes)
        recorded = self.flutter["entrypointPreconditions"]
        require(observed == recorded, "Flutter entrypoint preconditions differ from the lock")
        return files

    def pub_environment(self, sdk, pub_cache):
        return self.env(PUB_CACHE=str(pub_cache), FLUTTER_ROOT=str(sdk),
                        PUB_ENVIRONMENT="flutter_bot:flutter_cli:get")

    def install_flutter(self):
        target = self.replace_directory(self.flutter_root())
        # Root-owned from the start: git refuses a repository owned by another uid.
        self.run("flutter.extract", ["tar", "--no-same-owner", "-xJf",
                                     self.artifact("toolchain", "flutter"), "-C", target])
        sdk = target / "flutter"
        self.verify_flutter_preconditions(sdk)
        # bin/flutter runs `git rev-parse HEAD`; since git 2.35.2 a repository owned by
        # another user is refused ("dubious ownership"). The runner user must run the
        # root-owned SDK: trust exactly this path, system-wide, and attest the file.
        self.run("flutter.git-safe-directory", ["git", "config", "--system", "--add",
                                                "safe.directory", sdk])
        self.resolve_pub_offline(sdk, target / "pub-cache")
        before = self.sdk_snapshot(sdk)
        flutter = sdk / "bin/flutter"
        flutter_env = self.env()
        self.run("flutter.config", [flutter, "config", "--no-analytics"], env=flutter_env, cwd=sdk)
        self.run("flutter.precache", [flutter, "precache", "--linux"], env=flutter_env, cwd=sdk)
        self.require_precache_noop(before, self.sdk_snapshot(sdk))

    def resolve_pub_offline(self, sdk, pub_cache):
        """Fill a private Pub cache from the locked archives, then resolve offline.

        The cache lives in the read-only toolchain tree. A cache under /root
        (the SDK default when PUB_CACHE is unset) is unreadable by the runner
        user, which would make PubDependencies stale and trigger an online
        `pub get` on the first job.
        """
        dart = sdk / "bin/cache/dart-sdk/bin/dart"
        pub_cache.mkdir(mode=0o755)
        archives = self.stage("pub", "pub")
        environment = self.pub_environment(sdk, pub_cache)
        self.run("pub.preload", [dart, "pub", "--suppress-analytics", "cache", "preload",
                                 *sorted(archives.iterdir())], env=environment, cwd=sdk)
        locked = {f"{a['package']}-{a['version']}": a["sha256"]
                  for a in self.flutter["artifacts"] if a["cacheState"] == "download-required"}
        hosted = pub_cache / "hosted/pub.dev"
        require({entry.name for entry in hosted.iterdir()} == set(locked),
                "Pub cache differs from the locked Pub archives")
        for ident, digest in locked.items():
            recorded = (pub_cache / "hosted-hashes/pub.dev" / f"{ident}.sha256").read_text().strip()
            require(recorded == digest, f"Pub cache hash differs from the lock: {ident}")
        lock_digest = self.flutter["sdkSourceSha256"]["packages/flutter_tools/pubspec.lock"]
        self.run("pub.get", [dart, "pub", "--suppress-analytics", "--directory",
                             "packages/flutter_tools", "get", "--offline", "--example",
                             "--enforce-lockfile"], env=environment, cwd=sdk)
        require(file_hash(sdk / "packages/flutter_tools/pubspec.lock") == lock_digest,
                "Pub rewrote the Flutter tool lockfile")
        self.verify_package_config(sdk, pub_cache, locked)
        version = json.loads((sdk / "bin/cache/flutter.version.json").read_text())
        (sdk / "packages/flutter_tools/.dart_tool/version").write_text(version["frameworkVersion"])

    def verify_package_config(self, sdk, pub_cache, locked):
        config = json.loads((sdk / "packages/flutter_tools/.dart_tool/package_config.json").read_text())
        prefix = (pub_cache / "hosted/pub.dev").as_uri() + "/"
        hosted = set()
        for package in config["packages"]:
            uri = package["rootUri"]
            if package["name"] == "flutter_tools":
                require(uri == "../", "Unexpected root package location")
                continue
            require(uri.startswith(prefix), f"Package outside the private Pub cache: {package['name']}")
            hosted.add(uri[len(prefix):].rstrip("/"))
        require(hosted == set(locked), "Flutter tool package configuration differs from the lock")

    def sdk_snapshot(self, sdk):
        """Type, size and digest of every SDK entry, Git metadata included."""
        snapshot = {}
        for current, dirs, names in os.walk(sdk):
            for name in dirs + names:
                path = Path(current) / name
                relative = str(path.relative_to(sdk))
                status = os.lstat(path)
                if stat.S_ISREG(status.st_mode):
                    snapshot[relative] = ("f", status.st_size, file_hash(path))
                elif stat.S_ISLNK(status.st_mode):
                    snapshot[relative] = ("l", os.readlink(path))
                else:
                    snapshot[relative] = ("d",)
        return snapshot

    def require_precache_noop(self, before, after):
        """Every bundled artifact must already be current: nothing may be fetched."""
        created = {"bin/cache/lockfile"}
        for path in sorted(set(before) | set(after)):
            if before.get(path) == after.get(path):
                continue
            if path in created and path not in before:
                continue
            raise ValueError(f"flutter config/precache changed the Flutter SDK: {path}")

    # ------------------------------------------------------------------ Python
    def install_python(self):
        python_version = self.manifest["target"]["pythonVersion"]
        reported = self.run("python.version", ["python3.12", "--version"]).stdout.strip()
        require(reported == f"Python {python_version}", "Ubuntu Python does not match the manifest")
        target = TOOLCHAIN_ROOT / f"python-{python_version}"
        if target.exists():
            shutil.rmtree(target)
        self.run("python.venv", ["python3.12", "-m", "venv", target])
        wheels = self.stage("wheel", "wheels")
        pip_env = self.env(PIP_CONFIG_FILE=os.devnull, PIP_NO_INPUT="1",
                           PIP_DISABLE_PIP_VERSION_CHECK="1")
        python = target / "bin/python"
        self.run("python.install", [python, "-m", "pip", "install", "--no-index",
                                    "--find-links", wheels, "--no-deps", "--require-hashes",
                                    "--only-binary=:all:", "--no-cache-dir",
                                    "-r", self.input("toolchain-requirements.lock")], env=pip_env)
        listed = json.loads(self.run("python.list", [python, "-m", "pip", "list",
                                                     "--format=json"], env=pip_env).stdout)
        normalize = lambda name: re.sub(r"[-_.]+", "-", name).lower()
        installed = {(normalize(p["name"]), p["version"]) for p in listed}
        expected = {(normalize(w["name"]), w["version"]) for w in self.wheels["wheels"]}
        require(expected <= installed, "Locked Python packages are missing from the toolchain")
        extra = sorted(installed - expected)
        require([name for name, _ in extra] == ["pip"],
                f"Unexpected Python package in the toolchain: {extra}")
        self.run("python.check", [python, "-m", "pip", "check"], env=pip_env)
        self.assert_no_network_attempt("offline pip installation")

    # --------------------------------------------------------------- image files
    def install_links_and_files(self):
        v = self.version_of
        python_version = self.manifest["target"]["pythonVersion"]
        links = {
            "/usr/local/bin/node": f"node-{v('node')}/bin/node",
            "/usr/local/bin/npm": f"node-{v('node')}/bin/npm",
            "/usr/local/bin/npx": f"node-{v('node')}/bin/npx",
            "/usr/local/bin/dotnet": f"dotnet-{v('dotnet-sdk')}/dotnet",
            "/usr/local/bin/flutter": f"flutter-{v('flutter')}/flutter/bin/flutter",
            "/usr/local/bin/dart": f"flutter-{v('flutter')}/flutter/bin/dart",
            "/usr/local/bin/dart-format-3.6.0": f"dart-{v('dart-formatter')}/dart-sdk/bin/dart",
            "/usr/local/bin/bicep": f"bicep-{v('bicep')}/bicep",
            "/usr/local/bin/actionlint": f"actionlint-{v('actionlint')}/actionlint",
            "/usr/local/bin/checkov": f"python-{python_version}/bin/checkov",
            "/usr/local/bin/python3": f"python-{python_version}/bin/python",
        }
        for link, relative in links.items():
            path = Path(link)
            if path.is_symlink() or path.exists():
                path.unlink()
            path.symlink_to(TOOLCHAIN_ROOT / relative)
        IMAGE_ROOT.mkdir(mode=0o755, parents=True, exist_ok=True)
        files = (
            ("toolchain-manifest.json", IMAGE_ROOT / "toolchain-manifest.json", 0o644),
            ("toolchain-sbom.cyclonedx.document", IMAGE_ROOT / "toolchain-sbom.cyclonedx.document", 0o644),
            ("toolchain-requirements.lock", IMAGE_ROOT / "toolchain-requirements.lock", 0o644),
            ("runner-ephemeral.conf", IMAGE_ROOT / "runner-ephemeral.conf", 0o644),
            ("validate-toolchain.sh", Path("/usr/local/sbin/certigo-validate-toolchain"), 0o755),
            ("inventory-toolchain.sh", Path("/usr/local/sbin/certigo-inventory-toolchain"), 0o755),
            ("seal-runner-state.sh", Path("/usr/local/sbin/certigo-seal-runner-state"), 0o755),
            ("job-temp.sh", Path("/usr/local/sbin/certigo-job-temp"), 0o755),
            ("certigo-toolchain-guard-generator",
             Path("/usr/lib/systemd/system-generators/certigo-toolchain-guard"), 0o755),
            ("certigo-toolchain-validate.service",
             Path("/etc/systemd/system/certigo-toolchain-validate.service"), 0o644),
            ("certigo-job-temp-mount.service",
             Path("/etc/systemd/system/certigo-job-temp-mount.service"), 0o644),
        )
        for source, destination, mode in files:
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(self.input(source), destination)
            os.chown(destination, 0, 0)
            os.chmod(destination, mode)
        for alias in ("certigo-job-start", "certigo-job-complete"):
            path = Path("/usr/local/sbin") / alias
            if path.is_symlink() or path.exists():
                path.unlink()
            path.symlink_to("/usr/local/sbin/certigo-job-temp")

    # ------------------------------------------------------- guest patching (#341)
    def neutralize_guest_patching(self):
        for path, content in PATCHING_FILES.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")
            os.chmod(path, 0o644)
        self.require_no_apt_source("in the final image")
        dump = self.run("apt.config", ["apt-config", "dump"]).stdout
        for key in ("APT::Periodic::Update-Package-Lists", "APT::Periodic::Unattended-Upgrade"):
            values = re.findall(rf'^{re.escape(key)} "([^"]*)";$', dump, re.M)
            require(values and values[-1] == "0", f"{key} is not disabled")
        for unit in APT_AUTOMATION_UNITS:
            state = self.run("apt-automation.state", ["systemctl", "is-enabled", unit],
                             check=False).stdout.strip()
            require(state == "masked", f"{unit} is not masked")

    # ------------------------------------------------------------ attestation
    def seal_and_attest(self):
        state = "\n".join(self.dpkg_state()) + "\n"
        (IMAGE_ROOT / "dpkg-state.tsv").write_text(state, encoding="utf-8")
        runner = RUNNER_HOME
        self.run("seal.owner", ["chown", "-R", "root:root", TOOLCHAIN_ROOT, runner])
        self.run("seal.mode", ["chmod", "-R", "a-w", TOOLCHAIN_ROOT, runner])
        os.chmod(runner, 0o755)
        inventory = IMAGE_ROOT / "toolchain-inventory.tsv"
        self.run("inventory", ["/usr/local/sbin/certigo-inventory-toolchain", inventory])
        binaries = {name: file_hash(Path("/usr/local/bin") / name)
                    for name in ("node", "dotnet", "flutter", "dart", "bicep", "actionlint")}
        python_package = self.run("python.package", ["dpkg-query", "-W", "-f", "${Version}",
                                                     "python3.12"]).stdout
        attestation = {
            "schemaVersion": 2,
            "builtAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "manifestSha256": file_hash(IMAGE_ROOT / "toolchain-manifest.json"),
            "sbomSha256": file_hash(IMAGE_ROOT / "toolchain-sbom.cyclonedx.document"),
            "pythonLockSha256": file_hash(IMAGE_ROOT / "toolchain-requirements.lock"),
            "toolchainInventorySha256": file_hash(inventory),
            "dpkgStateSha256": file_hash(IMAGE_ROOT / "dpkg-state.tsv"),
            "closedArtifactSetSha256": closed_set_sha256(self.items),
            "offlineInstallerSha256": file_hash(self.input("install_offline.py")),
            "contractSha256": self.contract_sha256,
            "networkAttempts": [],
            "pythonPackageVersion": python_package,
            "installTimings": self.timings,
            "binarySha256": binaries,
        }
        (IMAGE_ROOT / "attestation.json").write_text(json.dumps(attestation, indent=2) + "\n")
        self.run("seal.image-root", ["chmod", "-R", "a-w", IMAGE_ROOT])
        self.run("systemd.reload", ["systemctl", "daemon-reload"])
        self.run("systemd.enable", ["systemctl", "enable", "certigo-toolchain-validate.service",
                                    "certigo-job-temp-mount.service"])

    def validate(self):
        self.run("validate.boot", ["/usr/local/sbin/certigo-validate-toolchain", "--boot"])
        self.assert_no_network_attempt("boot validation")

    # --------------------------------------------------------------------- main
    def install(self):
        self.preflight()
        self.verify_inputs()
        self.verify_closed_store()
        self.isolate_network()
        self.neutralize_apt_automation()
        self.require_state(self.expected_state(False),
                           "Base image packages differ from the reconstructed base")
        self.remove_apt_sources()
        self.install_debs()
        self.install_runner()
        self.run_confined_bootstrap()
        self.install_archives()
        self.install_flutter()
        self.install_python()
        self.install_links_and_files()
        self.neutralize_guest_patching()
        self.seal_and_attest()
        self.validate()
        events = self.sentinel.stop()
        require(not events, f"Unexpected network attempts: {events[:3]}")
        print(f"Offline image installation completed: {len(self.items)} verified artifacts, "
              "no network attempt.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    install = sub.add_parser("install")
    install.add_argument("--inputs", type=Path, required=True)
    install.add_argument("--store", type=Path, required=True)
    install.add_argument("--contract-sha256", required=True)
    args = parser.parse_args()
    work = Path(tempfile.mkdtemp(prefix="certigo-offline-install-", dir="/var/tmp"))
    installer = Installer(args.inputs.resolve(), args.store.resolve(), args.contract_sha256, work)
    try:
        installer.install()
    except ValueError as error:
        print(f"Offline image installation refused: {error}", file=sys.stderr)
        print(f"Installer log: {installer.log}", file=sys.stderr)
        sys.exit(1)
    shutil.rmtree(work)


if __name__ == "__main__":
    main()
