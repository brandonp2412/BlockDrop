#!/usr/bin/env python3
"""Fail-closed release identity and version checks for BlockDrop."""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

GITHUB_PACKAGE = "com.blockdrop.game"
PLAY_PACKAGE = "com.presley.blockdrop"
GITHUB_SIGNING_SHA256 = "011ee1a6e4e5ecd675f67fbf3d78ad82614a7a7a3f24ed71cc9c417154a0f0fd"
PLAY_SIGNING_SHA256 = "c5afe55b3b7c50f43aaa1f14f8e38e922c0ffc814324b3a5009bc1c070e4284b"
ABI_SUFFIXES = {"armeabi-v7a": 1, "arm64-v8a": 2, "x86_64": 3}
BUNDLETOOL_SHA256 = "a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29"


class ContractError(RuntimeError):
    """A release would break existing distribution or upgrade contracts."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ContractError(message)


def run_checked(arguments: list[str], cwd: Path | None = None) -> str:
    result = subprocess.run(
        arguments, cwd=cwd, capture_output=True, text=True, check=False
    )
    require(result.returncode == 0, f"{arguments[0]} failed: {result.stderr.strip()}")
    return result.stdout.strip()


def parse_version(pubspec: str) -> tuple[tuple[int, int, int], int]:
    match = re.search(r"^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$", pubspec, re.M)
    require(match is not None, "pubspec.yaml must contain a semver+integer build number")
    major, minor, patch, build = (int(part) for part in match.groups())
    return (major, minor, patch), build


def verify_version_progression(
    previous: tuple[tuple[int, int, int], int],
    current: tuple[tuple[int, int, int], int],
    strict: bool,
) -> None:
    old_version, old_build = previous
    new_version, new_build = current
    require(new_version >= old_version, "Release version must never decrease")
    require(new_build >= old_build, "Build number/versionCode must never decrease")
    if strict:
        require(new_version > old_version, "New release version must strictly increase")
        require(new_build > old_build, "New release build number must strictly increase")
    for abi, suffix in ABI_SUFFIXES.items():
        old_code = old_build * 10 + suffix
        new_code = new_build * 10 + suffix
        require(new_code >= old_code, f"{abi} versionCode would decrease")
        if strict:
            require(new_code > old_code, f"{abi} versionCode must increase")


def validate_source_text(gradle: str, workflow: str) -> None:
    app_ids = re.findall(r'^\s*applicationId\s*=\s*"([^"]+)"', gradle, re.M)
    require(app_ids == [GITHUB_PACKAGE, PLAY_PACKAGE],
            "Gradle must default to the historic GitHub/F-Droid ID, then override only for Play")
    require('if (providers.gradleProperty("playStoreBuild").orNull == "true")' in gradle,
            "Play package override must require the explicit playStoreBuild=true property")
    require('namespace = "com.blockdrop.game"' in gradle, "Android namespace changed")
    require('signingConfigs.getByName("debug")' not in gradle,
            "Release build must never fall back to debug signing")
    marker = 'ORG_GRADLE_PROJECT_playStoreBuild: "true"'
    require(workflow.count(marker) == 1,
            "Only the Google Play App Bundle step may set the Play package override")
    chunks = re.split(r'\n\s+- name:', workflow)
    bundle_steps = [chunk for chunk in chunks if chunk.lstrip().startswith("Build App Bundle")]
    require(len(bundle_steps) == 1 and marker in bundle_steps[0]
            and "flutter build appbundle" in bundle_steps[0],
            "Play override must be scoped to the App Bundle build step")
    apk_steps = [chunk for chunk in chunks if chunk.lstrip().startswith("Build APK for ")]
    require(len(apk_steps) == 3 and all("flutter build apk" in chunk and marker not in chunk
                                       for chunk in apk_steps),
            "Three GitHub APK ABI steps must not receive a Play package override")
    require('needs: [release-gate, quality-checks, generate-screenshots, signing-preflight]' in workflow,
            "Signing preflight must block tag/version creation")
    require(workflow.count(GITHUB_SIGNING_SHA256.upper()) == 2,
            "GitHub signer must be pinned at preflight and at artifact build")
    require(workflow.count(PLAY_SIGNING_SHA256.upper()) == 3,
            "Play upload signer must be pinned at preflight, build and publishing")
    require(workflow.count('ORG_GRADLE_PROJECT_androidSigningProperties: github-apk-signing.properties') == 3,
            "Each GitHub APK must use the historical APK signing properties")
    require(workflow.count('ORG_GRADLE_PROJECT_androidSigningProperties: play-signing.properties') == 1,
            "Only the Play bundle may use the Play signing properties")
    require("secrets.GITHUB_APK_" not in workflow,
            "GitHub Actions reserves the GITHUB_ secret prefix")
    for suffix in ("KEYSTORE_BASE64", "STORE_PASSWORD", "KEY_PASSWORD", "KEY_ALIAS"):
        name = f"BLOCKDROP_APK_{suffix}"
        require(workflow.count(f"secrets.{name}") == 2,
                f"Missing GitHub APK secret mapping: {name}")
    for check in ("scripts/release_contract.py apk", "scripts/release_contract.py aab",
                  "BLOCKDROP_APK_KEYSTORE_BASE64", "ANDROID_KEYSTORE_BASE64",
                  "ORG_GRADLE_PROJECT_androidSigningProperties: github-apk-signing.properties",
                  "ORG_GRADLE_PROJECT_androidSigningProperties: play-signing.properties",
                  "signing-preflight", "011EE1A6E4E5ECD675F67FBF3D78AD82614A7A7A3F24ED71CC9C417154A0F0FD",
                  "scripts/release_contract.py version", "test_release_contract.py"):
        require(check in workflow, f"Required release CI guard missing: {check}")


def validate_quality_ci_text(quality: str) -> None:
    require("pull_request:" in quality and "branches: [main]" in quality,
            "Release contract quality checks must run on PRs and main")
    for command in (
        "python3 -m unittest discover -s scripts -p 'test_release_contract.py' -v",
        "python3 scripts/release_contract.py source",
        "python3 scripts/release_contract.py version",
    ):
        require(command in quality, f"Required PR quality guard missing: {command}")


def find_android_tool(tool: str) -> str:
    locations: list[Path] = []
    for env in ("ANDROID_HOME", "ANDROID_SDK_ROOT"):
        if os.environ.get(env):
            locations.append(Path(os.environ[env]))
    locations.append(Path("/opt/android-sdk"))
    for sdk in locations:
        for build_tools in sorted((sdk / "build-tools").glob("*"), reverse=True):
            candidate = build_tools / tool
            if candidate.is_file():
                return str(candidate)
    found = shutil.which(tool)
    require(found is not None, f"Android SDK tool {tool} is required")
    return found


def parse_apk_badging(output: str) -> tuple[str, str, int]:
    first = output.splitlines()[0] if output else ""
    require(first.startswith("package:"), "aapt did not return APK package metadata")
    values = dict(re.findall(r"(\w+)='([^']+)'", first))
    require(all(name in values for name in ("name", "versionName", "versionCode")),
            "Incomplete APK package/version metadata")
    return values["name"], values["versionName"], int(values["versionCode"])


def normalize_digest(value: str) -> str:
    return re.sub(r"[^0-9a-f]", "", value.lower())


def verify_signing_digest(output: str, label: str, expected_sha256: str) -> None:
    hashes = re.findall(r"certificate SHA-256 digest:\s*([0-9a-f:]+)", output, re.I)
    if not hashes:
        hashes = re.findall(r"SHA256:\s*([0-9a-f:]+)", output, re.I)
    require(len(hashes) == 1 and normalize_digest(hashes[0]) == expected_sha256,
            f"{label} has unexpected or multiple signing certificates")


def verify_apks(directory: Path, version: str, build: int) -> None:
    files = sorted(directory.glob("app-*-release.apk"))
    expected = {f"app-{abi}-release.apk" for abi in ABI_SUFFIXES}
    require({path.name for path in files} == expected,
            f"Expected exactly the three ABI APKs {sorted(expected)}")
    aapt = find_android_tool("aapt")
    apksigner = find_android_tool("apksigner")
    for path in files:
        abi = path.name.removeprefix("app-").removesuffix("-release.apk")
        package, actual_version, code = parse_apk_badging(
            run_checked([aapt, "dump", "badging", str(path)])
        )
        require(package == GITHUB_PACKAGE,
                f"{path.name} PACKAGE ID REGRESSION: {package} != {GITHUB_PACKAGE}")
        require(actual_version == version,
                f"{path.name} versionName {actual_version} != {version}")
        require(code == build * 10 + ABI_SUFFIXES[abi],
                f"{path.name} versionCode {code} != {build * 10 + ABI_SUFFIXES[abi]}")
        verify_signing_digest(
            run_checked([apksigner, "verify", "--print-certs", str(path)]),
            path.name, GITHUB_SIGNING_SHA256
        )
        print(f"PASS {path.name}: {package} {actual_version} code={code} signed")


def verify_aab(bundle: Path, bundletool: Path, version: str, build: int) -> None:
    import hashlib

    require(bundle.is_file() and bundletool.is_file(), "App Bundle and bundletool are required")
    require(hashlib.sha256(bundletool.read_bytes()).hexdigest() == BUNDLETOOL_SHA256,
            "bundletool binary checksum mismatch")
    def attribute(xpath: str) -> str:
        return run_checked([
            "java", "-jar", str(bundletool), "dump", "manifest",
            f"--bundle={bundle}", f"--xpath={xpath}"
        ])
    package = attribute("/manifest/@package")
    require(package == PLAY_PACKAGE,
            f"Play AAB PACKAGE ID REGRESSION: {package} != {PLAY_PACKAGE}")
    actual_name = attribute("/manifest/@android:versionName")
    actual_code = attribute("/manifest/@android:versionCode")
    require(actual_name == version, f"Play AAB versionName {actual_name} != {version}")
    require(actual_code == str(build), f"Play AAB versionCode {actual_code} != {build}")
    verify_signing_digest(
        run_checked(["keytool", "-printcert", "-jarfile", str(bundle)]),
        bundle.name, PLAY_SIGNING_SHA256
    )
    print(f"PASS {bundle.name}: {package} {actual_name} code={actual_code} signed")


def verify_version_against_tag(repo: Path, strict: bool) -> None:
    tag = run_checked(["git", "describe", "--tags", "--abbrev=0", "--match", "v[0-9]*"], repo)
    previous = parse_version(run_checked(["git", "show", f"{tag}:pubspec.yaml"], repo))
    current = parse_version((repo / "pubspec.yaml").read_text())
    verify_version_progression(previous, current, strict)
    if strict:
        required_msix = ".".join(str(part) for part in current[0]) + ".0"
        require(re.search(r"^\s*msix_version:\s*" + re.escape(required_msix) + r"\s*$",
                          (repo / "pubspec.yaml").read_text(), re.M) is not None,
                "Windows MSIX version must track the new release version")
    print(f"PASS version progression from {tag}: {previous} -> {current}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="check", required=True)
    source = sub.add_parser("source")
    source.add_argument("--repo", type=Path, default=Path("."))
    version = sub.add_parser("version")
    version.add_argument("--repo", type=Path, default=Path("."))
    version.add_argument("--strict", action="store_true")
    apk = sub.add_parser("apk")
    apk.add_argument("--dir", type=Path, required=True)
    apk.add_argument("--version", required=True)
    apk.add_argument("--build", type=int, required=True)
    aab = sub.add_parser("aab")
    aab.add_argument("--file", type=Path, required=True)
    aab.add_argument("--bundletool", type=Path, required=True)
    aab.add_argument("--version", required=True)
    aab.add_argument("--build", type=int, required=True)
    arguments = parser.parse_args()
    if arguments.check == "source":
        validate_source_text(
            (arguments.repo / "android/app/build.gradle.kts").read_text(),
            (arguments.repo / ".github/workflows/release.yml").read_text()
        )
        validate_quality_ci_text(
            (arguments.repo / ".github/workflows/quality.yml").read_text()
        )
        print("PASS source package identity and release workflow scope")
    elif arguments.check == "version":
        verify_version_against_tag(arguments.repo, arguments.strict)
    elif arguments.check == "apk":
        verify_apks(arguments.dir, arguments.version, arguments.build)
    elif arguments.check == "aab":
        verify_aab(arguments.file, arguments.bundletool, arguments.version, arguments.build)


if __name__ == "__main__":
    try:
        main()
    except (ContractError, OSError, ValueError) as error:
        print(f"RELEASE CONTRACT FAILED: {error}", file=sys.stderr)
        sys.exit(1)
