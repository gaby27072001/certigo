import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
KIT = ROOT / "apps/apple/CertigoNative/Docs/APP_STORE_TESTFLIGHT_KIT.md"
SCRIPT = ROOT / "tools/validate_apple_mac_one_shot.sh"


class SubmissionMetadataTests(unittest.TestCase):
    def test_all_eight_locales_have_complete_fields_within_apple_limits(self):
        text = KIT.read_text(encoding="utf-8")
        sections = re.findall(
            r"^### (fr|en|hi|zh-Hans|ko|es|it|de)\n(.*?)(?=^### |^## |\Z)",
            text,
            re.MULTILINE | re.DOTALL,
        )
        self.assertEqual([locale for locale, _ in sections],
                         ["fr", "en", "hi", "zh-Hans", "ko", "es", "it", "de"])
        for locale, section in sections:
            with self.subTest(locale=locale):
                for label, limit in (("Name", 30), ("Subtitle", 30),
                                     ("Promotional text", 170), ("Keywords", 100)):
                    match = re.search(rf"^{label}: (.+)$", section, re.MULTILINE)
                    self.assertIsNotNone(match, label)
                    value = match.group(1)
                    size = len(value.encode("utf-8")) if label == "Keywords" else len(value)
                    self.assertLessEqual(size, limit, (label, size))
                    self.assertGreater(size, 0)
                description, notes = section.split("Description:\n", 1)[1].split(
                    "\nWhat to Test:\n", 1)
                self.assertGreater(len(description.strip()), 200)
                self.assertLessEqual(len(description.strip()), 4000)
                self.assertGreater(len(notes.strip()), 100)

    def test_release_gaps_are_explicit_instead_of_false_availability_claims(self):
        text = KIT.read_text(encoding="utf-8")
        for phrase in ("do not advertise six phases yet", "100 UTF-8 bytes",
                       "not an uploadable TestFlight build", "no native UI-test target",
                       "not evidence of 35 providers", "never put passwords"):
            self.assertIn(phrase, text)


@unittest.skipUnless(os.name == "posix" and shutil.which("bash"),
                     "Shell orchestration uses POSIX stubs, not Apple SDK execution")
class MacOneShotOrchestrationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.repo = self.root / "repo"
        self.bin = self.root / "bin"
        (self.repo / "tools").mkdir(parents=True)
        self.bin.mkdir()
        shutil.copyfile(SCRIPT, self.repo / "tools" / SCRIPT.name)
        shutil.copyfile(ROOT / "tools/validate_native_distribution.sh",
                        self.repo / "tools/validate_native_distribution.sh")
        (self.repo / "tools/project_state.py").write_text("print('state checked')\n")
        self.trace = self.root / "trace"
        self.env = dict(os.environ,
                        PATH=str(self.bin) + os.pathsep + os.environ["PATH"],
                        TRACE=str(self.trace),
                        CERTIGO_APPLE_LOG_ROOT=str(self.root / "logs"),
                        CERTIGO_SIMULATOR_ID="11111111-1111-1111-1111-111111111111")
        self.stub("uname", "printf '%s\\n' \"${TEST_OS:-Darwin}\"\n")
        self.stub("plutil", 'cp "${@: -1}" "$4"\n')
        self.stub("git", """printf 'git %s\\n' "$*" >> "$TRACE"
case "$1" in
status) printf '%s' "${TEST_DIRTY-}" ;;
branch) printf '%s\\n' "${TEST_BRANCH:-main}" ;;
rev-parse)
  case "$*" in *upstream*) echo origin/main ;; *) echo 1234abcd ;; esac ;;
pull) exit "${TEST_PULL_FAILURE:-0}" ;;
*) exit 9 ;;
esac
""")
        self.stub("swift", """printf 'swift %s\\n' "$*" >> "$TRACE"
[[ "$1" != test ]] || exit "${TEST_SWIFT_FAILURE:-0}"
echo 'Swift mock; no SDK validation'
""")
        self.stub("xcodebuild", """printf 'xcodebuild %s\\n' "$*" >> "$TRACE"
if [[ "$1" == -version ]]; then echo 'Xcode 26.0'; exit 0; fi
[[ "$1" != build ]] || exit "${TEST_BUILD_FAILURE:-0}"
action=$1
while [[ $# -gt 0 ]]; do
  case "$1" in
    -resultBundlePath) mkdir -p "$2"; shift ;;
    -archivePath) mkdir -p "$2/Products/Applications/CertigoNative.app"; shift ;;
  esac
  shift
done
echo "$action completed by mock"
""")
        self.stub("xcrun", """printf 'xcrun %s\\n' "$*" >> "$TRACE"
if [[ "$1" == simctl ]]; then
  printf '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-0":[{"udid":"%s","isAvailable":true}]}}\\n' "$CERTIGO_SIMULATOR_ID"
else
  printf '{"result":"Passed","passedTests":%s,"failedTests":0,"skippedTests":%s}\\n' "${TEST_PASSED:-3}" "${TEST_SKIPPED:-0}"
fi
""")

    def stub(self, name, body):
        path = self.bin / name
        path.write_text("#!/usr/bin/env bash\nset -eu\n" + body, encoding="utf-8")
        path.chmod(0o755)

    def run_script(self, *args, **values):
        return subprocess.run(
            ["bash", str(self.repo / "tools" / SCRIPT.name), *args],
            cwd=self.repo, env=dict(self.env, **values),
            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            timeout=20,
        )

    def calls(self):
        return self.trace.read_text() if self.trace.exists() else ""

    def test_help_and_non_mac_do_not_touch_git(self):
        self.assertEqual(self.run_script("--help").returncode, 0)
        result = self.run_script(TEST_OS="Linux")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("requires macOS", result.stdout)
        self.assertNotIn("git ", self.calls())

    def test_dirty_or_wrong_branch_refuses_pull(self):
        for values in ({"TEST_DIRTY": " M local-file"}, {"TEST_BRANCH": "feature"}):
            with self.subTest(values=values):
                self.assertNotEqual(self.run_script(**values).returncode, 0)
                self.assertNotIn("git pull", self.calls())

    def test_missing_distribution_parameters_refuses_update(self):
        result = self.run_script("--prepare-archive")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("CERTIGO_DISTRIBUTION_VERSION", result.stdout)
        self.assertNotIn("git pull", self.calls())

    def test_build_and_swift_failures_stop_later_steps(self):
        result = self.run_script(TEST_SWIFT_FAILURE="17")
        self.assertEqual(result.returncode, 17, result.stdout)
        self.assertNotIn("xcodebuild build", self.calls())
        self.trace.unlink()
        result = self.run_script(TEST_BUILD_FAILURE="18")
        self.assertEqual(result.returncode, 18, result.stdout)
        self.assertNotIn("xcodebuild test", self.calls())

    def test_zero_or_skipped_tests_are_not_a_pass(self):
        for values in ({"TEST_PASSED": "0"}, {"TEST_SKIPPED": "1"}):
            result = self.run_script(**values)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Require executed passing tests", result.stdout)

    def test_unsigned_archive_preserves_missing_ui_blocker(self):
        result = self.run_script("--prepare-archive",
                                 CERTIGO_DISTRIBUTION_VERSION="1.2.3",
                                 CERTIGO_DISTRIBUTION_BUILD="123")
        self.assertEqual(result.returncode, 3, result.stdout)
        calls = self.calls()
        self.assertIn("git pull --ff-only", calls)
        self.assertIn("swift test --package-path apps/apple/CertigoKit", calls)
        self.assertIn("xcodebuild archive", calls)
        self.assertIn("CODE_SIGNING_ALLOWED=NO", calls)
        self.assertIn("NOT an uploadable TestFlight build", result.stdout)
        self.assertNotIn("-allowProvisioningUpdates", calls)
        self.assertNotIn("-exportArchive", calls)
        summaries = list((self.root / "logs").glob("*/summary.txt"))
        self.assertEqual(len(summaries), 1)
        self.assertIn("BLOCKED", summaries[0].read_text())

    def test_configured_ui_scheme_must_have_real_testables_and_target(self):
        project = self.repo / "UITests.xcodeproj"
        schemes = project / "xcshareddata/xcschemes"
        schemes.mkdir(parents=True)
        (project / "project.pbxproj").write_text(json.dumps({
            "objects": {"UI": {"productType": "com.apple.product-type.bundle.ui-testing",
                               "name": "NativeUITests"}}
        }))
        (schemes / "UITests.xcscheme").write_text(
            '<Scheme><TestAction><Testables><TestableReference skipped="NO">'
            '<BuildableReference BlueprintIdentifier="UI" '
            'ReferencedContainer="container:UITests.xcodeproj"/>'
            '</TestableReference></Testables></TestAction></Scheme>')
        result = self.run_script(CERTIGO_UI_TEST_PROJECT="UITests.xcodeproj",
                                 CERTIGO_UI_TEST_SCHEME="UITests")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("UITests.xcresult", self.calls())
        self.assertIn("-only-testing:NativeUITests", self.calls())
        (project / "project.pbxproj").write_text(json.dumps({
            "objects": {"UI": {"productType": "com.apple.product-type.bundle.unit-test",
                               "name": "NativeUnitTests"}}
        }))
        result = self.run_script(CERTIGO_UI_TEST_PROJECT="UITests.xcodeproj",
                                 CERTIGO_UI_TEST_SCHEME="UITests")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no enabled UI-testing target", result.stdout)


if __name__ == "__main__":
    unittest.main()
