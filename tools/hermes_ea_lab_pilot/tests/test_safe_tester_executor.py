from __future__ import annotations

import csv
import hashlib
import importlib.util
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "safe_tester_executor_mcp.py"
spec = importlib.util.spec_from_file_location("safe_tester_executor_mcp", SCRIPT)
module = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(module)

SET_REL = "ea_template/sets/probe/Boss_19_AdaptiveTrendGrid_V0_STOP_VALIDATION_CENTER.set"


class SafeTesterExecutorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name).resolve()
        (self.root / "scripts").mkdir(parents=True)
        (self.root / "scripts" / "mt5_run.ps1").write_text("# fixture\n", encoding="utf-8")
        (self.root / "scripts" / "parse_mt5_report.py").write_text("# fixture\n", encoding="utf-8")
        set_path = self.root / SET_REL
        set_path.parent.mkdir(parents=True)
        set_path.write_text("_9_StepATRmult=0.30\n", encoding="utf-8")
        self.set_sha = hashlib.sha256(set_path.read_bytes()).hexdigest()
        self.manifest = self.root / "h2_manifest.csv"
        self.columns = [
            "cell_id", "symbol", "tf", "window", "from_date", "to_date", "model",
            "set_path", "report_name", "holdout", "optimization",
        ]
        self.rows = [
            {
                "cell_id": "H2-C01-MAIN", "symbol": "XAUUSD", "tf": "H4", "window": "MAIN",
                "from_date": "2023.01.01", "to_date": "2025.12.31", "model": "1",
                "set_path": SET_REL, "report_name": "H2_XAU_H4_MAIN", "holdout": "NO", "optimization": "NO",
            },
            {
                "cell_id": "H2-C01-BWD", "symbol": "XAUUSD", "tf": "H4", "window": "BWD",
                "from_date": "2020.01.01", "to_date": "2022.12.31", "model": "1",
                "set_path": SET_REL, "report_name": "H2_XAU_H4_BWD", "holdout": "NO", "optimization": "NO",
            },
        ]
        self._write_manifest(self.rows)
        self.manifest_sha = hashlib.sha256(self.manifest.read_bytes()).hexdigest()
        self.receipt = self.root / "receipt.jsonl"
        self.receipt.write_text(json.dumps({
            "schema": "build_receipt/1",
            "build_receipt": "br-test",
            "ea_logical_identity": "Probe_19_AdaptiveTrendGrid",
            "artifact_sha256": "a" * 64,
        }) + "\n", encoding="utf-8")
        self.receipt_sha = hashlib.sha256(self.receipt.read_bytes()).hexdigest()

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def _write_manifest(self, rows: list[dict[str, str]]) -> None:
        with self.manifest.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=self.columns)
            writer.writeheader()
            writer.writerows(rows)
    def test_authorized_cell_builds_only_expected_runner_argv(self) -> None:
        row = module.load_bound_cell(
            self.root, self.manifest, self.manifest_sha, "H2-C01-MAIN", self.set_sha
        )
        argv = module.build_runner_argv(self.root, row, self.receipt)
        joined = " ".join(argv)
        self.assertIn("scripts\\mt5_run.ps1", joined)
        self.assertIn("EALabTpl\\Probe_19_AdaptiveTrendGrid", joined)
        self.assertIn("-Symbol XAUUSD", joined)
        self.assertIn("-Period H4", joined)
        self.assertIn("-Model 1", joined)
        self.assertIn("-Deposit 10000", joined)
        self.assertIn("-Leverage 100", joined)
        self.assertNotIn("-Force", argv)
        self.assertNotIn("-AllowLegacyIdentity", argv)

    def test_unknown_cell_is_refused(self) -> None:
        with self.assertRaisesRegex(ValueError, "cell_id not authorized"):
            module.load_bound_cell(self.root, self.manifest, self.manifest_sha, "NOPE", self.set_sha)

    def test_manifest_sha_mismatch_is_refused(self) -> None:
        with self.assertRaisesRegex(ValueError, "manifest SHA256 mismatch"):
            module.load_bound_cell(self.root, self.manifest, "0" * 64, "H2-C01-MAIN", self.set_sha)

    def test_absolute_or_escape_set_path_is_refused(self) -> None:
        for bad in (str(self.root / "outside.set"), "../outside.set"):
            rows = [dict(self.rows[0], set_path=bad)]
            self._write_manifest(rows)
            sha = hashlib.sha256(self.manifest.read_bytes()).hexdigest()
            with self.assertRaisesRegex(ValueError, "set_path"):
                module.load_bound_cell(self.root, self.manifest, sha, "H2-C01-MAIN", self.set_sha)

    def test_holdout_date_is_refused(self) -> None:
        rows = [dict(self.rows[0], to_date="2026.06.30")]
        self._write_manifest(rows)
        sha = hashlib.sha256(self.manifest.read_bytes()).hexdigest()
        with self.assertRaisesRegex(ValueError, "HOLDOUT"):
            module.load_bound_cell(self.root, self.manifest, sha, "H2-C01-MAIN", self.set_sha)
    def test_optimization_or_wrong_model_is_refused(self) -> None:
        for patch, pattern in [({"optimization": "YES"}, "optimization"), ({"model": "4"}, "Model=1")]:
            rows = [dict(self.rows[0], **patch)]
            self._write_manifest(rows)
            sha = hashlib.sha256(self.manifest.read_bytes()).hexdigest()
            with self.assertRaisesRegex(ValueError, pattern):
                module.load_bound_cell(self.root, self.manifest, sha, "H2-C01-MAIN", self.set_sha)

    def test_set_hash_mismatch_is_refused(self) -> None:
        with self.assertRaisesRegex(ValueError, "set SHA256 mismatch"):
            module.load_bound_cell(self.root, self.manifest, self.manifest_sha, "H2-C01-MAIN", "0" * 64)

    def test_receipt_registry_hash_mismatch_is_refused(self) -> None:
        with self.assertRaisesRegex(ValueError, "receipt registry SHA256 mismatch"):
            module.verify_receipt_registry(self.receipt, "0" * 64)

    def test_server_exposes_no_arbitrary_execution_surface(self) -> None:
        import anyio

        async def names() -> list[str]:
            return [tool.name for tool in await module.create_server(self.root).list_tools()]

        tools = anyio.run(names)
        self.assertEqual(sorted(tools), ["run_fixed_backtest"])
        for prohibited in ("terminal", "shell", "exec", "command", "file", "write", "git", "optimize"):
            self.assertFalse(any(prohibited in name.lower() for name in tools), tools)

    def test_runner_failure_is_mechanical_not_strategy_red(self) -> None:
        def fake_run(*args, **kwargs):
            return subprocess.CompletedProcess(args[0], 2, stdout="ABORT identity", stderr="")

        result = module.run_cell_impl(
            self.root, self.manifest, self.manifest_sha, self.receipt, self.receipt_sha,
            "H2-C01-MAIN", self.set_sha, run_process=fake_run,
        )
        self.assertEqual(result["status"], "MECHANICAL_FAIL")
        self.assertEqual(result["runner_exit_code"], 2)
        self.assertNotIn("RED", json.dumps(result))
    def test_stale_report_is_refused(self) -> None:
        report_dir = self.root / "_mt5_auto" / "reports"
        report_dir.mkdir(parents=True)
        report = report_dir / "H2_XAU_H4_MAIN.htm"
        report.write_text("old", encoding="utf-8")
        old = report.stat().st_mtime_ns

        def fake_run(*args, **kwargs):
            return subprocess.CompletedProcess(args[0], 0, stdout="symbol preflight: logical=XAUUSD tester=XAUUSD status=EXACT economics=PINNED source=fixture", stderr="")

        result = module.run_cell_impl(
            self.root, self.manifest, self.manifest_sha, self.receipt, self.receipt_sha,
            "H2-C01-MAIN", self.set_sha, run_process=fake_run, start_time_ns=old + 1,
        )
        self.assertEqual(result["status"], "MECHANICAL_FAIL")
        self.assertEqual(result["reason"], "STALE_OR_MISSING_REPORT")

    def test_fresh_report_is_hash_bound_and_parsed(self) -> None:
        report_dir = self.root / "_mt5_auto" / "reports"
        report_dir.mkdir(parents=True)
        report = report_dir / "H2_XAU_H4_MAIN.htm"

        def fake_run(*args, **kwargs):
            report.write_bytes(b"fresh-report")
            return subprocess.CompletedProcess(args[0], 0, stdout="symbol preflight: logical=XAUUSD tester=XAUUSD status=EXACT economics=PINNED source=fixture", stderr="")

        def fake_parse(path: Path) -> dict[str, object]:
            self.assertEqual(path, report)
            return {
                "ea_name": "Probe_19_AdaptiveTrendGrid", "symbol": "XAUUSD",
                "period": "H4", "from_date": "2023.01.01", "to_date": "2025.12.31",
                "leverage": "1:100", "profit_factor": 1.23, "total_trades": 42, "net_profit": 10.0,
            }

        result = module.run_cell_impl(
            self.root, self.manifest, self.manifest_sha, self.receipt, self.receipt_sha,
            "H2-C01-MAIN", self.set_sha, run_process=fake_run, parse_report=fake_parse, start_time_ns=0,
        )
        self.assertEqual(result["status"], "COMPLETE")
        self.assertEqual(result["metrics"]["profit_factor"], 1.23)
        self.assertEqual(result["report_sha256"], hashlib.sha256(b"fresh-report").hexdigest())

    def test_report_identity_mismatch_is_mechanical_fail(self) -> None:
        report_dir = self.root / "_mt5_auto" / "reports"
        report_dir.mkdir(parents=True)
        report = report_dir / "H2_XAU_H4_MAIN.htm"
        def fake_run(*args, **kwargs):
            report.write_bytes(b"fresh-report")
            return subprocess.CompletedProcess(args[0], 0, stdout="symbol preflight: logical=XAUUSD tester=XAUUSD status=EXACT economics=PINNED source=fixture", stderr="")
        def fake_parse(path: Path) -> dict[str, object]:
            return {
                "ea_name": "Probe_19_AdaptiveTrendGrid", "symbol": "XAUUSD",
                "period": "M15", "from_date": "2023.01.01", "to_date": "2025.12.31",
                "leverage": "1:100", "profit_factor": 1.23, "total_trades": 42, "net_profit": 10.0,
            }
        result = module.run_cell_impl(
            self.root, self.manifest, self.manifest_sha, self.receipt, self.receipt_sha,
            "H2-C01-MAIN", self.set_sha, run_process=fake_run, parse_report=fake_parse, start_time_ns=0,
        )
        self.assertEqual(result["status"], "MECHANICAL_FAIL")
        self.assertEqual(result["reason"], "REPORT_IDENTITY_MISMATCH")

    def test_unsafe_report_name_and_tf_are_refused(self) -> None:
        for patch, pattern in [({"report_name": "../escape"}, "report_name"), ({"tf": "D1"}, "tf")]:
            rows = [dict(self.rows[0], **patch)]
            self._write_manifest(rows)
            sha = hashlib.sha256(self.manifest.read_bytes()).hexdigest()
            with self.assertRaisesRegex(ValueError, pattern):
                module.load_bound_cell(self.root, self.manifest, sha, "H2-C01-MAIN", self.set_sha)

    def test_profile_manifest_keeps_generic_execution_toolsets_forbidden(self) -> None:
        module_root = SCRIPT.parents[1]
        manifest = json.loads((module_root / "profile_manifest.json").read_text(encoding="utf-8"))
        spec = manifest["tester_execution_mcp"]
        self.assertEqual(spec["profile"], "ea-tester")
        self.assertEqual(spec["tools"], ["run_fixed_backtest"])
        for prohibited in ("terminal", "file", "code_execution", "computer_use", "delegation"):
            self.assertIn(prohibited, manifest["forbidden_persistent_toolsets"])
            tester = next(p for p in manifest["profiles"] if p["name"] == "ea-tester")
            self.assertNotIn(prohibited, tester["enabled_toolsets"])

    def test_wrapper_tester_execute_is_sha_bound_without_terminal_enablement(self) -> None:
        wrapper = (SCRIPT.parent / "run_profile_task.ps1").read_text(encoding="utf-8")
        self.assertIn("'tester-execute'", wrapper)
        self.assertIn("tester-execute is restricted to ea-tester", wrapper)
        for binding in (
            "EA_LAB_TESTER_MANIFEST", "EA_LAB_TESTER_MANIFEST_SHA256",
            "EA_LAB_TESTER_RECEIPT_REGISTRY", "EA_LAB_TESTER_RECEIPT_SHA256",
            "EA_LAB_TESTER_SET_SHA256",
        ):
            self.assertIn(binding, wrapper)
        self.assertEqual(wrapper.count("if ($Mode -eq 'bounded-write') { $args += @('-t','file') }"), 1)
        self.assertNotIn("@('-t','terminal')", wrapper)
        self.assertNotIn("@('-t','code_execution')", wrapper)

    def test_missing_task_binding_fails_closed(self) -> None:
        old = os.environ.pop("EA_LAB_TESTER_MANIFEST", None)
        try:
            with self.assertRaisesRegex(ValueError, "missing task-scoped binding"):
                module._required_env("EA_LAB_TESTER_MANIFEST")
        finally:
            if old is not None:
                os.environ["EA_LAB_TESTER_MANIFEST"] = old


if __name__ == "__main__":
    unittest.main(verbosity=2)