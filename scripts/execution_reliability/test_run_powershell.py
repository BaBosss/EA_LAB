"""Windows stdlib integration tests; fixtures stay under this script's directory.

Default exercises the real trusted temp/log roots. --local-storage tests the
same implementation with isolated storage here if external ACLs block access.
"""

import ctypes
from ctypes import wintypes
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run_powershell as runner

LOCAL_STORAGE = "--local-storage" in sys.argv
if LOCAL_STORAGE:
    sys.argv.remove("--local-storage")


class RunnerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.workspace = tempfile.TemporaryDirectory(
            prefix="watchdog-tests-", dir=Path(__file__).parent)
        cls.fixtures = Path(cls.workspace.name)
        cls.root = cls.fixtures / "storage" if LOCAL_STORAGE else runner.TRUSTED_ROOT

    @classmethod
    def tearDownClass(cls):
        cls.workspace.cleanup()

    def execute(self, body, args=(), timeout=15):
        target = self.fixtures / (self._testMethodName + " target.ps1")
        target.write_text(body, encoding="utf-8")
        result = runner.run(target, list(args), timeout, _root=self.root)
        print("EVIDENCE", self._testMethodName, result["classification"], result["logs_path"])
        for attempt in result["attempts"]:
            self.assertTrue(attempt["tree_cleanup_confirmed"], result)
            self.assertTrue(attempt["temp_cleaned"], result)
            self.assertFalse(Path(attempt["temp_path"]).exists())
            self.assertEqual(Path(attempt["temp_path"]).parent, self.root / "temp")
            self.assertIsNotNone(attempt["child_pid"])
            for field in ("stdout_path", "stderr_path"):
                self.assertTrue(json.loads(Path(attempt[field]).read_text())["complete"])
        self.assertEqual(json.loads((Path(result["logs_path"]) / "summary.json").read_text()), result)
        return result

    def test_temp_inheritance_success(self):
        # Expected parent is passed as a literal argument, never interpolated code.
        result = self.execute(r'''
param([string]$ExpectedParent)
$ErrorActionPreference = 'Stop'
if ($env:TEMP -cne $env:TMP -or $env:TEMP -cne $env:TMPDIR) { exit 31 }
if ([IO.Path]::GetDirectoryName($env:TEMP) -cne $ExpectedParent) { exit 32 }
if (-not [IO.Path]::GetFileName($env:TEMP).StartsWith('attempt-')) { exit 33 }
if ([IO.Path]::GetTempPath().TrimEnd('\') -cne $env:TEMP) { exit 34 }
[IO.File]::WriteAllText((Join-Path $env:TEMP 'owned.txt'), 'fixture')
Write-Output 'TEMP_INHERITANCE_PASS'
exit 0
''', [str(self.root / "temp")])
        self.assertEqual(result["classification"], "SUCCESS")
        self.assertEqual(result["retry_count"], 0)

    def test_silent_normal_failure_never_retries(self):
        result = self.execute("exit 7")
        self.assertEqual(result["classification"], "SCRIPT_FAILED")
        self.assertEqual(result["retry_count"], 0)
        self.assertEqual(result["attempts"][0]["exit_code"], 7)

    def test_error_output_never_retries(self):
        result = self.execute("throw 'ordinary failure'")
        self.assertEqual(result["classification"], "SCRIPT_FAILED")
        self.assertEqual(result["retry_count"], 0)

    def test_arguments_and_output_privacy(self):
        values = ["argument-secret-39274", "a b", 'a"b', "$(exit 99); & | ` % !", "trailing\\", ""]
        # Compare against a JSON fixture; target prints both argv and an env secret.
        expected = self.fixtures / "expected.json"
        expected.write_text(json.dumps(values), encoding="utf-8")
        with mock.patch.dict(os.environ, {"WATCHDOG_SECRET_TEST": "env-secret-28473"}):
            result = self.execute(r'''
$ErrorActionPreference = 'Stop'
$expected = [IO.File]::ReadAllText($args[0]) | ConvertFrom-Json
if ($args.Count -ne ($expected.Count + 1)) { exit 40 }
for ($i = 0; $i -lt $expected.Count; $i++) {
    if ($args[$i + 1] -cne $expected[$i]) { exit 41 }
}
[Console]::Out.WriteLine(($args -join ','))
[Console]::Error.WriteLine($env:WATCHDOG_SECRET_TEST)
exit 0
''', [str(expected), *values])
        self.assertEqual(result["classification"], "SUCCESS")
        self.assertEqual(result["argument_count"], len(values) + 1)
        all_logs = "".join(p.read_text() for p in Path(result["logs_path"]).iterdir())
        self.assertNotIn(values[0], all_logs)
        self.assertNotIn("env-secret-28473", all_logs)
        self.assertNotIn("WATCHDOG_SECRET_TEST", all_logs)

    def test_timeout_kills_descendant_only(self):
        pid_file = self.fixtures / "descendant.pid"
        sentinel = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"],
                                    creationflags=subprocess.CREATE_NO_WINDOW)
        self.addCleanup(self.stop_sentinel, sentinel)
        result = self.execute(r'''
param([string]$PidFile)
$ErrorActionPreference = 'Stop'
$child = Start-Process -FilePath "$env:SystemRoot\System32\ping.exe" -ArgumentList @('-t', '127.0.0.1') -WindowStyle Hidden -PassThru
[IO.File]::WriteAllText($PidFile, [string]$child.Id)
Start-Sleep -Seconds 60
''', [str(pid_file)], timeout=4)
        self.assertEqual(result["classification"], "TIMEOUT")
        self.assertEqual(result["retry_count"], 0)
        self.assertLess(result["attempts"][0]["duration_seconds"], 20)
        self.assertTrue(pid_file.exists(), "descendant must start before the timeout")
        api = ctypes.WinDLL("kernel32", use_last_error=True)
        api.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
        api.OpenProcess.restype = wintypes.HANDLE
        api.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
        api.WaitForSingleObject.restype = wintypes.DWORD
        api.CloseHandle.argtypes = [wintypes.HANDLE]
        handle = api.OpenProcess(0x100000, False, int(pid_file.read_text()))
        if handle:
            try:
                self.assertEqual(api.WaitForSingleObject(handle, 0), 0)
            finally:
                api.CloseHandle(handle)
        else:
            self.assertEqual(ctypes.get_last_error(), 87)  # process no longer exists
        self.assertEqual(os.getpid(), result["runner_pid"])
        self.assertIsNone(sentinel.poll(), "unrelated owned fixture must remain alive")

    @staticmethod
    def stop_sentinel(proc):
        if proc.poll() is None:
            proc.kill()
        proc.wait(timeout=5)

    def test_assignment_failure_does_not_run_target(self):
        marker = self.fixtures / "must-not-run.txt"
        with mock.patch.object(runner.Job, "assign_and_resume", side_effect=OSError("fixture failure")):
            result = self.execute("[IO.File]::WriteAllText($args[0], 'unexpected')", [str(marker)])
        self.assertEqual(result["classification"], "BLOCKED_C_ENVIRONMENT_DEPENDENCY")
        self.assertEqual(result["retry_count"], 0)
        self.assertFalse(marker.exists())

    def test_simulated_abrupt_then_success(self):
        marker = self.fixtures / "retry.marker"
        result = self.execute(r'''
param([string]$Marker)
if (-not [IO.File]::Exists($Marker)) {
    [IO.File]::WriteAllText($Marker, 'first attempt')
    [Environment]::Exit(-1073741510)
}
exit 0
''', [str(marker)])
        self.assertEqual(result["classification"], "RETRY_SUCCESS_AFTER_ABRUPT_TERMINATION")
        self.assertEqual(result["retry_count"], 1)
        self.assertEqual(result["attempts"][0]["classification"], "ABRUPT_TERMINATION_SUSPECTED")
        self.assertNotEqual(*[a["temp_path"] for a in result["attempts"]])

    def test_simulated_abrupt_twice_is_blocked(self):
        result = self.execute("[Environment]::Exit(-1073741510)")
        self.assertEqual(result["classification"], "BLOCKED_C_ENVIRONMENT_DEPENDENCY")
        self.assertEqual(len(result["attempts"]), 2)

    def test_timeout_unconfirmed_cleanup_blocks(self):
        target = self.fixtures / "timeout-unconfirmed-cleanup.ps1"
        target.write_text("Start-Sleep -Seconds 60", encoding="utf-8")
        with mock.patch.object(runner.Job, "terminate_and_wait", return_value=False):
            result = runner.run(target, [], 0.1, _root=self.root)
        print("EVIDENCE", self._testMethodName, result["classification"], result["logs_path"])
        attempt = result["attempts"][0]
        try:
            self.assertEqual(result["classification"], "BLOCKED_C_ENVIRONMENT_DEPENDENCY")
            self.assertFalse(attempt["tree_cleanup_confirmed"])
            self.assertFalse(attempt["temp_cleaned"])
            self.assertTrue(Path(attempt["temp_path"]).exists())
        finally:
            runner.clean_attempt(Path(attempt["temp_path"]), self.root / "temp")

    def test_status_policy_and_finite_timeout(self):
        for code in (1, 2, 7, 255, 12345, 0xC0000001):
            self.assertEqual(runner.classification(code), "SCRIPT_FAILED")
        self.assertEqual(runner.classification(-1073741510), "ABRUPT_TERMINATION_SUSPECTED")
        self.assertEqual(runner.classification(0xC000013A, True), "TIMEOUT")
        for state in ("SCRIPT_FAILED", "TIMEOUT", "ABRUPT_TERMINATION_SUSPECTED"):
            self.assertEqual(runner.final_classification([
                {"classification": "ABRUPT_TERMINATION_SUSPECTED"}, {"classification": state}]),
                "BLOCKED_C_ENVIRONMENT_DEPENDENCY")
        for value in (0, -1, float("inf"), float("nan"), 86401):
            with self.assertRaises(ValueError):
                runner.run("unused.ps1", [], value, _root=self.root)

    def test_cleanup_boundary(self):
        boundary = self.fixtures / "cleanup"
        boundary.mkdir()
        sibling = boundary / "preserve"
        sibling.mkdir()
        owned = boundary / "attempt-fixture"
        owned.mkdir()
        runner.clean_attempt(owned, boundary)
        self.assertTrue(sibling.exists())
        with self.assertRaises(OSError):
            runner.clean_attempt(sibling, boundary)
        with self.assertRaises(OSError):
            runner.clean_attempt(boundary, boundary)


if __name__ == "__main__":
    unittest.main(verbosity=2)
