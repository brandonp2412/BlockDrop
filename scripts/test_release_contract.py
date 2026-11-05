#!/usr/bin/env python3
"""Regression tests for the immutable BlockDrop release/update contract."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import release_contract as contract


REPO = Path(__file__).resolve().parent.parent


class ReleaseContractTests(unittest.TestCase):
    def setUp(self) -> None:
        self.gradle = (REPO / "android/app/build.gradle.kts").read_text()
        self.workflow = (REPO / ".github/workflows/release.yml").read_text()
        self.quality = (REPO / ".github/workflows/quality.yml").read_text()

    def test_current_source_contract(self) -> None:
        contract.validate_source_text(self.gradle, self.workflow)
        contract.validate_quality_ci_text(self.quality)

    def test_pr_and_main_quality_gates_cannot_drop_release_checks(self) -> None:
        expected = (
            "python3 -m unittest discover -s scripts -p 'test_release_contract.py' -v",
            "python3 scripts/release_contract.py source",
            "python3 scripts/release_contract.py version",
        )
        for check in expected:
            with self.subTest(command=check):
                changed = self.quality.replace(check, "echo skipped", 1)
                with self.assertRaisesRegex(contract.ContractError, "PR quality guard"):
                    contract.validate_quality_ci_text(changed)
        with self.assertRaisesRegex(contract.ContractError, "PRs and main"):
            contract.validate_quality_ci_text(
                self.quality.replace("  pull_request:", "  workflow_dispatch:", 1)
            )

    def test_original_package_id_cannot_be_replaced(self) -> None:
        changed = self.gradle.replace(
            'applicationId = "com.blockdrop.game"',
            'applicationId = "com.presley.blockdrop"', 1
        )
        with self.assertRaisesRegex(contract.ContractError, "default"):
            contract.validate_source_text(changed, self.workflow)

    def test_play_package_must_remain_explicit(self) -> None:
        changed = self.gradle.replace(
            'if (providers.gradleProperty("playStoreBuild").orNull == "true")',
            'if (true)'
        )
        with self.assertRaisesRegex(contract.ContractError, "explicit"):
            contract.validate_source_text(changed, self.workflow)

    def test_apk_build_cannot_inherit_play_override(self) -> None:
        changed = self.workflow.replace(
            "- name: Build APK for arm64\n",
            '- name: Build APK for arm64\n        env:\n'
            '          ORG_GRADLE_PROJECT_playStoreBuild: "true"\n',
            1
        )
        with self.assertRaisesRegex(contract.ContractError, "Only the Google Play"):
            contract.validate_source_text(self.gradle, changed)

    def test_missing_artifact_verification_is_rejected(self) -> None:
        changed = self.workflow.replace("scripts/release_contract.py apk", "echo apk")
        with self.assertRaisesRegex(contract.ContractError, "CI guard missing"):
            contract.validate_source_text(self.gradle, changed)

    def test_version_and_build_must_both_increase(self) -> None:
        previous = contract.parse_version("version: 1.0.73+70\n")
        contract.verify_version_progression(
            previous, contract.parse_version("version: 1.0.74+71\n"), True
        )
        for newer in ("version: 1.0.73+71\n", "version: 1.0.74+70\n",
                      "version: 1.0.72+71\n", "version: 1.0.73+70\n"):
            with self.subTest(newer=newer), self.assertRaises(contract.ContractError):
                contract.verify_version_progression(
                    previous, contract.parse_version(newer), True
                )

    def test_current_branch_cannot_regress_version(self) -> None:
        old = contract.parse_version("version: 1.0.74+71\n")
        with self.assertRaises(contract.ContractError):
            contract.verify_version_progression(
                old, contract.parse_version("version: 1.0.73+72\n"), False
            )
        with self.assertRaises(contract.ContractError):
            contract.verify_version_progression(
                old, contract.parse_version("version: 1.0.75+70\n"), False
            )

    def test_apk_manifest_parsing_and_exact_package(self) -> None:
        name, version, code = contract.parse_apk_badging(
            "package: name='com.blockdrop.game' versionCode='702' "
            "versionName='1.0.73' platformBuildVersionCode='37'"
        )
        self.assertEqual((name, version, code), ("com.blockdrop.game", "1.0.73", 702))
        with self.assertRaises(contract.ContractError):
            contract.parse_apk_badging("package: name='com.presley.blockdrop'")

    def test_release_cannot_use_play_signer_for_github_apks(self) -> None:
        changed = self.workflow.replace(
            'ORG_GRADLE_PROJECT_androidSigningProperties: github-apk-signing.properties',
            'ORG_GRADLE_PROJECT_androidSigningProperties: play-signing.properties', 1
        )
        with self.assertRaisesRegex(contract.ContractError, "GitHub APK"):
            contract.validate_source_text(self.gradle, changed)
        changed = self.workflow.replace(
            contract.GITHUB_SIGNING_SHA256.upper(),
            contract.PLAY_SIGNING_SHA256.upper(), 1
        )
        with self.assertRaisesRegex(contract.ContractError, "GitHub signer"):
            contract.validate_source_text(self.gradle, changed)
        changed = self.workflow.replace(
            'needs: [release-gate, quality-checks, generate-screenshots, signing-preflight]',
            'needs: [release-gate, quality-checks, generate-screenshots]', 1
        )
        with self.assertRaisesRegex(contract.ContractError, "preflight"):
            contract.validate_source_text(self.gradle, changed)
        changed = self.gradle.replace(
            'signingConfig = signingConfigs.findByName("release")',
            'signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")', 1
        )
        with self.assertRaisesRegex(contract.ContractError, "debug signing"):
            contract.validate_source_text(changed, self.workflow)

    def test_signing_key_is_pinned(self) -> None:
        for expected, wrong in ((contract.GITHUB_SIGNING_SHA256, contract.PLAY_SIGNING_SHA256),
                                (contract.PLAY_SIGNING_SHA256, contract.GITHUB_SIGNING_SHA256)):
            contract.verify_signing_digest(
                f"Signer #1 certificate SHA-256 digest: {expected}", "fixture.apk", expected
            )
            with self.assertRaisesRegex(contract.ContractError, "signing certificates"):
                contract.verify_signing_digest(
                    f"Signer #1 certificate SHA-256 digest: {wrong}", "fixture.apk", expected
                )

    def test_wrong_binary_package_fails_even_when_source_is_correct(self) -> None:
        with tempfile.TemporaryDirectory() as dirname:
            directory = Path(dirname)
            for abi in contract.ABI_SUFFIXES:
                (directory / f"app-{abi}-release.apk").touch()
            def fake_run(args, cwd=None):
                if args[1:3] == ["dump", "badging"]:
                    return ("package: name='com.presley.blockdrop' "
                            "versionName='1.0.74' versionCode='712'")
                return "Signer #1 certificate SHA-256 digest: " + contract.GITHUB_SIGNING_SHA256
            with patch.object(contract, "find_android_tool", return_value="/tool"), \
                 patch.object(contract, "run_checked", side_effect=fake_run), \
                 self.assertRaisesRegex(contract.ContractError, "PACKAGE ID REGRESSION"):
                contract.verify_apks(directory, "1.0.74", 71)

    def test_all_abi_outputs_and_codes_must_match(self) -> None:
        with tempfile.TemporaryDirectory() as dirname:
            directory = Path(dirname)
            for abi in contract.ABI_SUFFIXES:
                (directory / f"app-{abi}-release.apk").touch()
            def fake_run(args, cwd=None):
                if args[1:3] == ["dump", "badging"]:
                    abi = Path(args[-1]).name.removeprefix("app-").removesuffix("-release.apk")
                    code = 710 + contract.ABI_SUFFIXES[abi]
                    return (f"package: name='com.blockdrop.game' "
                            f"versionName='1.0.74' versionCode='{code}'")
                return "Signer #1 certificate SHA-256 digest: " + contract.GITHUB_SIGNING_SHA256
            with patch.object(contract, "find_android_tool", return_value="/tool"), \
                 patch.object(contract, "run_checked", side_effect=fake_run):
                contract.verify_apks(directory, "1.0.74", 71)
            (directory / "app-x86_64-release.apk").unlink()
            with self.assertRaisesRegex(contract.ContractError, "three ABI"):
                contract.verify_apks(directory, "1.0.74", 71)


if __name__ == "__main__":
    unittest.main()
