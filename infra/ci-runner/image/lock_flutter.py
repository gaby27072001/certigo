"""Replay the reviewed Flutter 3.44.4 Linux x64 cache graph without executing it.

This is deliberately version-specific, not a general Dart interpreter. A different
SDK archive requires a new source review. Capture measures HTTPS bytes; verify
is offline and checks both the source-derived graph and every downloaded byte.
"""

import argparse
import concurrent.futures
import json
import re
import tarfile
from pathlib import Path

from lock_inputs import (
    ROOT, checked_file, compare_lock, fetch, file_hash, read_json, require,
    sha256, write_json,
)

SDK_SHA = "c853cda0312a162854c481fe6a1bc286d84fbb74bfab7037c39750061dc9b466"
FRAMEWORK = "ad70ec4617166f1c38e5d2bfd388af71fda14f06"
ENGINE = "a10d8ac38de835021c8d2f920dbf50a920ccc030"
STORAGE = "https://storage.googleapis.com/"
LOCK = ROOT / "flutter-engine-artifacts.lock.json"
SOURCES = [
    "packages/flutter_tools/lib/src/cache.dart",
    "packages/flutter_tools/lib/src/flutter_cache.dart",
    "packages/flutter_tools/lib/src/features.dart",
    "packages/flutter_tools/lib/src/commands/precache.dart",
    "packages/flutter_tools/lib/src/commands/config.dart",
    "packages/flutter_tools/lib/src/runner/flutter_command_runner.dart",
    "packages/flutter_tools/lib/src/dart/pub.dart",
    "packages/flutter_tools/pubspec.yaml",
    "packages/flutter_tools/pubspec.lock",
    "bin/internal/engine.version",
    "bin/internal/material_fonts.version",
    "bin/internal/gradle_wrapper.version",
    "bin/internal/shared.sh",
    "bin/internal/update_dart_sdk.sh",
    "bin/internal/update_engine_version.sh",
    "bin/cache/flutter.version.json",
    "bin/cache/engine.realm",
    ".git/HEAD",
    ".git/packed-refs",
    ".git/index",
]


def entrypoint_preconditions(files, directories, contents, mtimes):
    require("bin/cache/flutter_tools.snapshot" in files and
            "bin/cache/dart-sdk" in directories, "Bundled executable cache is incomplete")
    require(contents.get("bin/cache/flutter_tools.stamp", b"").decode().strip() == FRAMEWORK + ":",
            "Flutter tool rebuild would resolve an unbounded pub upgrade")
    for stamp in ("engine", "engine-dart-sdk"):
        require(contents.get(f"bin/cache/{stamp}.stamp", b"").decode().strip() == ENGINE,
                "Dart SDK download branch is not closed")
    require(mtimes["packages/flutter_tools/pubspec.yaml"] <=
            mtimes["packages/flutter_tools/pubspec.lock"],
            "Newer pubspec would rebuild Flutter tools")
    require(contents[".git/HEAD"].decode().strip() == "ref: refs/heads/stable" and
            f"{FRAMEWORK} refs/heads/stable" in contents[".git/packed-refs"].decode().splitlines() and
            ".git/refs/heads/stable" not in files, "SDK Git HEAD differs from tool stamp")
    index = contents.get(".git/index", b"")
    require(".git/index" in files and index.startswith(b"DIRC\x00\x00\x00\x02") and
            b"bin/internal/engine.version\x00" in index,
            "engine.version must stay Git-tracked to avoid the content-hash engine fallback")
    require(re.search(r"const flutterLinuxDesktopFeature = Feature\.fullyEnabled\(",
                      contents["packages/flutter_tools/lib/src/features.dart"].decode()),
            "Linux desktop default requires a new source review")
    return {
        "gitHead": FRAMEWORK, "engineVersionTracked": True, "flutterToolArgs": "",
        "pubspecMtime": mtimes["packages/flutter_tools/pubspec.yaml"],
        "pubspecLockMtime": mtimes["packages/flutter_tools/pubspec.lock"],
        "toolSnapshot": "bundled-current", "dartSdk": "bundled-current",
        "linuxDesktopDefault": "fully-enabled",
        "environment": "clean home/config; no Flutter, Pub, engine or Git overrides",
        "archiveState": "unmodified SDK including Git metadata and preserved mtimes",
    }


def sdk_contents(archive):
    manifest = read_json(ROOT / "toolchain-manifest.json")
    flutter = next(tool for tool in manifest["tools"] if tool["id"] == "flutter")
    require(flutter["source"]["digest"] == {"algorithm": "sha256", "value": SDK_SHA},
            "Unreviewed Flutter SDK: update the graph evaluator explicitly")
    checked_file(archive, SDK_SHA)
    files, directories, contents, mtimes = set(), set(), {}, {}
    with tarfile.open(archive, "r|xz") as stream:
        for member in stream:
            if member.name == "flutter" and member.isdir():
                continue
            require(member.name.startswith("flutter/") and
                    ".." not in member.name.split("/"), "Unsafe SDK archive member")
            name = member.name.removeprefix("flutter/").rstrip("/")
            if member.isdir():
                directories.add(name)
            elif member.isfile():
                files.add(name)
                if name in ("packages/flutter_tools/pubspec.yaml", "packages/flutter_tools/pubspec.lock"):
                    mtimes[name] = member.mtime
                if name in SOURCES or re.fullmatch(r"bin/cache/[^/]+\.stamp", name):
                    contents[name] = stream.extractfile(member).read()
    require(set(SOURCES) <= contents.keys(), "Missing SDK graph input")
    require(contents["bin/internal/engine.version"].decode().strip() == ENGINE,
            "Unexpected engine revision")
    version = json.loads(contents["bin/cache/flutter.version.json"])
    require(version["frameworkRevision"] == FRAMEWORK and
            version["engineRevision"] == ENGINE, "SDK revision mismatch")
    require(contents["bin/cache/engine.realm"].strip() == b"", "Unexpected storage realm")
    preconditions = entrypoint_preconditions(files, directories, contents, mtimes)
    return flutter, files, directories, contents, preconditions


def pub_graph(lock):
    entries = re.findall(r"^  ([a-z0-9_]+):\n(.*?)(?=^  [a-z0-9_]+:|^sdks:|\Z)",
                         lock, re.M | re.S)
    result = []
    for name, body in entries:
        require("\n    source: hosted\n" in body, f"Unexpected Pub source: {name}")
        digest = re.search(r'^      sha256: "?([a-f0-9]{64})"?$', body, re.M)
        version = re.search(r'^    version: "([^"]+)"$', body, re.M)
        require(digest and version and '      url: "https://pub.dev"' in body,
                f"Incomplete Pub archive identity: {name}")
        result.append({"requiredBy": "PubDependencies", "package": name,
                       "version": version[1], "cacheState": "download-required",
                       "url": f"https://pub.dev/api/archives/{name}-{version[1]}.tar.gz",
                       "expectedSha256": digest[1]})
    require(len(result) == lock.count("    source:"), "Unparsed Pub dependency")
    return result


def graph(files, directories, contents):
    source = contents["packages/flutter_tools/lib/src/flutter_cache.dart"].decode()
    # Exact archive pin above makes these source selectors fail closed on SDK changes.
    classes = dict(re.findall(r"^class (\w+) .*?\{(.*?)(?=^class |^abstract class |\Z)",
                              source, re.M | re.S))
    selected = {name for name, body in classes.items()
                if re.search(r"DevelopmentArtifact\.(universal|informative|linux)\b", body)}
    require(selected == {"MaterialFonts", "GradleWrapper", "FlutterEngineStamp",
                         "FlutterSdk", "LinuxEngineArtifacts", "FontSubsetArtifacts",
                         "IosUsbArtifacts", "PubDependencies"}, "Cache registration graph changed")
    engine_base = STORAGE + f"flutter_infra_release/flutter/{ENGINE}/"
    artifacts = []

    def current(stamp, version, required_dirs=(), required_files=()):
        return (contents.get(f"bin/cache/{stamp}.stamp", b"").decode().strip() == version
                and all(path in directories for path in required_dirs)
                and all(path in files for path in required_files))

    def append(name, url, bundled):
        artifacts.append({"requiredBy": name, "url": url,
                          "cacheState": "bundled-current" if bundled else "download-required"})

    for name, stamp in (("MaterialFonts", "material_fonts"), ("GradleWrapper", "gradle_wrapper")):
        version = contents[f"bin/internal/{stamp}.version"].decode().strip()
        require(re.fullmatch(r"flutter_infra_release/[a-z0-9/_-]+\.(zip|tgz)", version),
                "Unexpected universal artifact path")
        required_files = () if name == "MaterialFonts" else tuple(
            f"bin/cache/artifacts/gradle_wrapper/{path}"
            for path in ("gradlew", "gradlew.bat", "gradle/wrapper/gradle-wrapper.jar"))
        append(name, STORAGE + version, current(
            stamp, version, (f"bin/cache/artifacts/{stamp}",), required_files))
    append("FlutterEngineStamp", engine_base + "engine_stamp.json",
           current("engine_stamp", ENGINE, ("bin/cache",)))
    packages = re.search(r"getPackageDirs\(\) => const <String>\[(.*?)\];",
                         classes["FlutterSdk"], re.S)
    require(packages is not None, "Flutter SDK package directories changed")
    packages = re.findall(r"'([^']+)'", packages[1])
    tuples = re.findall(r"<String>\['([^']+)', '([^']+)'\]", classes["FlutterSdk"])
    tuples = [(a.replace("$arch", "x64"), b.replace("$arch", "x64")) for a, b in tuples
              if a == "common" or a == "linux-$arch"]
    tuples = list(dict.fromkeys(tuples))
    sdk_current = current("flutter_sdk", ENGINE,
                          tuple(f"bin/cache/pkg/{name}" for name in packages) +
                          tuple(f"bin/cache/artifacts/engine/{name}" for name, _ in tuples))
    for package in packages:
        append("FlutterSdk", engine_base + package + ".zip", sdk_current)
    for _, path in tuples:
        append("FlutterSdk", engine_base + path, sdk_current)
    linux = [(a.replace("$arch", "x64"), b.replace("$arch", "x64")) for a, b in
             re.findall(r"<String>\['([^']+)', '([^']+)'\]", classes["LinuxEngineArtifacts"])]
    linux_current = current("linux-sdk", ENGINE,
                            tuple(f"bin/cache/artifacts/engine/{name}" for name, _ in linux))
    for _, path in linux:
        append("LinuxEngineArtifacts", engine_base + path, linux_current)
    font = re.search(r"'linux': <String>\['([^']+)', '([^']+)'\]",
                     classes["FontSubsetArtifacts"])
    require(font is not None, "Font subset Linux artifact changed")
    path = font[2].replace("$arch", "x64").replace("$artifactName", "font-subset")
    append("FontSubsetArtifacts", engine_base + path, current(
        "font-subset", ENGINE, ("bin/cache/artifacts/engine", "bin/cache/artifacts/engine/linux-x64")))
    require(len(artifacts) == 12 and len({a["url"] for a in artifacts}) == 12,
            "Unexpected engine/universal graph")
    require("packages/flutter_tools/.dart_tool/package_config.json" not in files and
            "packages/flutter_tools/.dart_tool/pub/workspace_ref.json" not in files,
            "Pub cache state requires a new review")
    require("resolution: workspace" not in contents["packages/flutter_tools/pubspec.yaml"].decode(),
            "Flutter tools now uses workspace resolution")
    artifacts.extend(pub_graph(contents["packages/flutter_tools/pubspec.lock"].decode()))
    return artifacts


def build_lock(archive, cache, capture):
    flutter, files, directories, contents, preconditions = sdk_contents(archive)
    candidates = graph(files, directories, contents)

    def measure(item):
        item = dict(item)
        expected = item.pop("expectedSha256", None)
        path = cache / sha256(item["url"].encode())
        if capture:
            fetch(item["url"], path, expected)
        else:
            require(path.is_file() and not path.is_symlink(), f"Missing artifact: {item['url']}")
        digest = file_hash(path)
        if expected:
            require(digest == expected, f"Pub archive hash mismatch: {item['url']}")
        return {**item, "sha256": digest, "bytes": path.stat().st_size}

    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as executor:
        artifacts = list(executor.map(measure, candidates))
    return {"schemaVersion": 1, "target": "linux-x64", "command": ["precache", "--linux"],
            "evaluation": "source-derived; SDK binaries were not executed",
            "frameworkRevision": FRAMEWORK, "engineRevision": ENGINE,
            "sdkArchive": flutter["source"],
            "manifestSha256": file_hash(ROOT / "toolchain-manifest.json"),
            "sdkSourceSha256": {path: sha256(contents[path]) for path in SOURCES},
            "entrypointPreconditions": preconditions,
            "selectedDevelopmentArtifacts": ["universal", "informative", "linux"],
            "noDownloadBranches": {
                "IosUsbArtifacts": "Linux host; no all-platforms or universal platform override",
                "otherPlatforms": "Explicit --linux suppresses implicit default-platform selection",
            },
            "artifacts": artifacts}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("capture", "resolve", "verify"))
    parser.add_argument("--sdk-archive", type=Path, required=True)
    parser.add_argument("--cache", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=LOCK)
    args = parser.parse_args()
    args.cache.mkdir(parents=True, exist_ok=True)
    result = build_lock(args.sdk_archive, args.cache, args.command == "capture")
    if args.command in ("capture", "resolve"):
        write_json(args.output, result)
    else:
        compare_lock(read_json(args.output), result)
    print(f"Verified {len(result['artifacts'])} Flutter artifacts (Linux x64, not host ARM64).")


if __name__ == "__main__":
    main()
