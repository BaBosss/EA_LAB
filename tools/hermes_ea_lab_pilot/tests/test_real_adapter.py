"""Synthetic V2-B qualification. All process entry points are forbidden."""
import contextlib
import io
import json
import os
import runpy
import shutil
import subprocess
import sys
import tempfile
import unittest
import warnings
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import batch_executor as batch
import real_adapter as adapter

REPO = Path(__file__).resolve().parents[3]


class QualificationTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name).resolve()
        self.state = self.root / "state"
        (self.root / "scripts").mkdir()
        shutil.copyfile(REPO / "scripts/report_year_split.py", self.root / "scripts/report_year_split.py")
        self.calls = []
        self.mutate = lambda paths, result: None
        self.parsed_change = {}
        self.year_calls = 0
        self.year_mode = "ok"
        self.runner_error = None
        self.report_bytes = b"<html>INERT NO-MT5 QUALIFICATION</html>"
        self.head = "a" * 40
        self.rows = [dict(cell_id=f"Q{i}", expert=r"Fixture\InertProbe", build_receipt="br-fixture",
                          artifact_sha256="", set_sha256="", symbol="XAUUSD", tester_symbol="XAUUSDm",
                          tf="H4", window="MAIN", from_date="2023.01.01", to_date="2025.12.31",
                          model="1", deposit="10000", leverage="100", report_name=f"synthetic{i}",
                          lane="MT5_PRIMARY") for i in range(3)]
        self.contract = dict(schema="hermes-adapter/1", mode="QUALIFICATION_NO_MT5", head=self.head,
                             manifest="manifest.json", manifest_sha256="", lane="MT5_PRIMARY")
        for name, data in (("set", b"inert configuration"), ("artifact", b"NONEXECUTABLE FIXTURE")):
            (self.root / name).write_bytes(data)
            self.contract[name] = dict(path=name, sha256=adapter.sha(data))
        for row in self.rows:
            row["set_sha256"] = self.contract["set"]["sha256"]
            row["artifact_sha256"] = self.contract["artifact"]["sha256"]
        receipt = dict(build_receipt="br-fixture", ea_logical_identity="InertProbe",
                       artifact_sha256=self.rows[0]["artifact_sha256"])
        (self.root / "receipt").write_bytes(adapter.encoded(receipt))
        self.contract["receipt"] = dict(path="receipt", sha256=batch.safe.sha256_path(self.root / "receipt"))
        self.write_contract()
        # Zero real child processes, including git and the canonical year splitter.
        self.launches = []
        for name in ("Popen", "run", "call", "check_call", "check_output"):
            mock = self.enterContext(patch.object(subprocess, name, side_effect=AssertionError("NO subprocess")))
            self.launches.append(mock)
        self.launches.append(self.enterContext(patch.object(os, "system", side_effect=AssertionError("NO shell"))))
        self.addCleanup(self.assert_no_launch)

    def assert_no_launch(self):
        for launch in self.launches:
            launch.assert_not_called()

    def write_contract(self):
        (self.root / "manifest.json").write_bytes(adapter.encoded(self.rows))
        self.contract["manifest_sha256"] = batch.safe.sha256_path(self.root / "manifest.json")
        (self.root / "contract.json").write_bytes(adapter.encoded(self.contract))
        self.contract_sha = batch.safe.sha256_path(self.root / "contract.json")

    def head_reader(self, root):
        return self.head

    def build(self):
        return adapter.QualificationAdapter(self.root, "contract.json", self.contract_sha,
                                           executor=self.execute, parse_report=self.parse,
                                           year_split=self.years, head_reader=self.head_reader)

    def execute(self, cell, evidence):
        self.calls.append(cell.identity()["cell_id"])
        if self.runner_error:
            raise self.runner_error
        identity = cell.identity()
        report = evidence / (identity["report_name"] + ".htm")
        # No trades or performance claim: canonical splitter receives empty synthetic HTML.
        report.write_bytes(self.report_bytes)
        report_sha = batch.safe.sha256_path(report)
        values = {
            "execution": {"identity": identity, "report_sha256": report_sha},
            "leverage_check": dict(report_name=identity["report_name"], requested_leverage=100,
                                   actual_leverage=100, match=True, status="MATCH"),
            "truncation_check": dict(schema_version=2, check_status="CHECK_PASS", checker_exit_code=0,
                                     truncated=False, report_name=identity["report_name"], report_sha256=report_sha),
            "lane": dict(lane=identity["lane"], install=adapter.LANES[identity["lane"]]),
        }
        paths = {"report": report}
        for kind, value in values.items():
            path = evidence / (identity["report_name"] + "." + kind + ".json")
            path.write_bytes(adapter.encoded(value))
            paths[kind] = path
        result = dict(exit_code=0, report_sha256=report_sha)
        self.mutate(paths, result)
        return result

    def parse(self, report):
        row = next(r for r in self.rows if r["report_name"] == report.stem)
        return {**{k: row[k] for k in ("expert", "tester_symbol", "tf", "from_date", "to_date",
                                      "model", "deposit", "leverage")}, **self.parsed_change}

    def years(self, report):
        self.year_calls += 1
        if self.year_mode == "missing":
            return b""
        if self.year_mode == "unparsable":
            return b"deterministic but not canonical year output"
        if self.year_mode == "wrong_report":
            return b"=== wrong.htm\n  FULL   trades=   0  PF=  inf  net=     +0.00  balDD= 0.00%\n"
        if self.year_mode == "nonzero_no_years":
            return (f"=== {report.name}\n  FULL   trades=  10  PF= 1.50  net=    +10.00  balDD= 1.00%\n").encode()
        if self.year_mode == "year_count_mismatch":
            return (f"=== {report.name}\n  FULL   trades=  10  PF= 1.50  net=    +10.00  balDD= 1.00%\n"
                    "  2023   trades=   9  PF= 1.50  net=     +9.00  balDD= 1.00%\n").encode()
        stream = io.StringIO()
        with patch.object(sys, "argv", ["report_year_split.py", str(report)]), contextlib.redirect_stdout(stream), warnings.catch_warnings():
            # Existing canonical reader uses open(...).read(); leave that out-of-scope source unchanged.
            warnings.filterwarnings("ignore", category=ResourceWarning, message="unclosed file.*")
            runpy.run_path(str(self.root / "scripts/report_year_split.py"), run_name="__main__")
        data = stream.getvalue().encode()
        if self.year_mode == "changed":
            return data.replace(b"+0.00", f"+{self.year_calls}.00".encode())
        return data

    def run_batch(self, runner=None, **kwargs):
        return batch.run_batch(self.root, self.contract, self.state, runner=runner or self.build(),
                               head_reader=self.head_reader, **kwargs)

    def one(self, runner=None):
        runner = runner or self.build()
        self.state.mkdir(exist_ok=True)
        return runner(runner.freeze(self.rows[0]), self.state)

    def test_complete_all_hashes_serial_resume_zero_launch(self):
        result = self.run_batch()
        self.assertEqual(result["cells"], {f"Q{i}": "COMPLETE" for i in range(3)})
        for i in range(3):
            output = adapter.read_json(self.state / f"Q{i}.output.json")
            self.assertEqual(set(output), {"cell_id", "status", "reason", "artifacts"})
            self.assertEqual(len(output["artifacts"]), 9)
            batch.validate_result(self.state, f"Q{i}", output)
        self.run_batch(resume_sha=result["checkpoint_sha256"])
        self.assertEqual(self.calls, ["Q0", "Q1", "Q2"])
        self.assertEqual(self.year_calls, 6)

    def test_canonical_calendar_years_are_retained_in_order(self):
        rows = []
        for year in (2025, 2023, 2024):
            cells = [f"{year}.02.01 00:00:00", "1", "XAUUSDm", "buy", "out", "0", "0", "0", "0", "0", "0", "0", "fixture"]
            rows.append("<tr>" + "".join(f"<td>{c}</td>" for c in cells) + "</tr>")
        self.report_bytes = ("<html>INERT SYNTHETIC ROWS" + "".join(rows) + "</html>").encode()
        result = self.one()
        self.assertEqual(result["status"], "COMPLETE")
        text = (self.state / "Q0.evidence/synthetic0.years.txt").read_text()
        self.assertLess(text.index("2023"), text.index("2024"))
        self.assertLess(text.index("2024"), text.index("2025"))

    def test_each_frozen_identity_mismatch_refused_before_dispatch(self):
        runner = self.build()
        cell = runner.freeze(self.rows[0])
        self.state.mkdir()
        for key in cell.identity():
            with self.subTest(field=key):
                bad = adapter.FrozenCell(adapter.encoded({**cell.identity(), key: "WRONG"}))
                with self.assertRaisesRegex(ValueError, "controller-built"):
                    runner(bad, self.state)
        self.assertEqual(self.calls, [])

    def test_plain_dict_and_unknown_fields_refused(self):
        runner = self.build()
        for value in (self.rows[0], {"argv": ["terminal64.exe"]}, None):
            with self.assertRaises(ValueError):
                runner(value, self.state)

    def test_forbidden_manifest_fields_refused(self):
        for key in ("executable", "argv", "path", "optimization", "holdout", "Force", "parameters"):
            with self.subTest(field=key):
                self.rows[0][key] = "YES"
                self.write_contract()
                with self.assertRaises(ValueError):
                    self.build()
                del self.rows[0][key]
        self.assertEqual(self.calls, [])

    def test_holdout_and_bad_models_refused(self):
        for key, value in (("window", "HOLDOUT"), ("model", "2"), ("tf", "H99"),
                           ("lane", "UNKNOWN"), ("from_date", "2025.1.1"), ("deposit", "0")):
            old = self.rows[0][key]
            self.rows[0][key] = value
            self.write_contract()
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.build()
            self.rows[0][key] = old

    def test_duplicate_case_colliding_ids_refused(self):
        for key in ("cell_id", "report_name"):
            old = self.rows[1][key]
            self.rows[1][key] = self.rows[0][key].lower()
            self.write_contract()
            with self.assertRaisesRegex(ValueError, "duplicate"):
                self.build()
            self.rows[1][key] = old

    def test_wrong_head_refused(self):
        self.head = "b" * 40
        with self.assertRaisesRegex(ValueError, "HEAD"):
            self.run_batch()
        self.assertEqual(self.calls, [])

    def test_changed_frozen_resources_refused(self):
        runner = self.build()
        for name in ("manifest.json", "contract.json", "set", "artifact", "receipt"):
            path = self.root / name
            original = path.read_bytes()
            path.write_bytes(original + b"changed")
            with self.subTest(name=name), self.assertRaises(ValueError):
                self.run_batch(runner)
            path.write_bytes(original)
        self.assertEqual(self.calls, [])

    def test_receipt_expert_and_artifact_mismatch_refused(self):
        for key in ("expert", "build_receipt", "artifact_sha256", "set_sha256"):
            old = self.rows[0][key]
            self.rows[0][key] = "wrong"
            self.write_contract()
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.build()
            self.rows[0][key] = old

    def test_missing_stale_unparsable_artifacts_fail(self):
        for kind in ("report", "execution", "leverage_check", "truncation_check", "lane"):
            for mode in ("missing", "stale", "unparsable"):
                def mutate(paths, result, kind=kind, mode=mode):
                    if mode == "missing":
                        paths[kind].unlink()
                    elif mode == "stale":
                        os.utime(paths[kind], ns=(1, 1))
                    else:
                        paths[kind].write_bytes(b"bad bytes")
                self.mutate = mutate
                self.state = self.root / (kind + mode)
                with self.subTest(kind=kind, mode=mode):
                    self.assertEqual(self.one()["status"], "MECHANICAL_FAIL")

    def test_parsed_identity_mismatches_fail(self):
        for key in ("expert", "tester_symbol", "tf", "from_date", "to_date", "model", "deposit", "leverage"):
            self.parsed_change = {key: "wrong"}
            self.state = self.root / key
            with self.subTest(key=key):
                self.assertEqual(self.one()["status"], "MECHANICAL_FAIL")

    def test_cross_bound_sidecars_fail(self):
        cases = [("execution", "report_sha256", "0" * 64), ("lane", "install", r"D:\Meta 5b"),
                 ("lane", "lane", "MT5_AGENT"), ("leverage_check", "actual_leverage", 50),
                 ("leverage_check", "match", 1), ("truncation_check", "truncated", True),
                 ("truncation_check", "truncated", "false"), ("truncation_check", "schema_version", 1),
                 ("truncation_check", "checker_exit_code", False), ("truncation_check", "checker_exit_code", 2),
                 ("truncation_check", "check_status", "CHECK_ERROR"),
                 ("truncation_check", "status", "FAIL"),
                 ("truncation_check", "report_sha256", "0" * 64), ("truncation_check", "report_name", "wrong")]
        for i, (kind, key, value) in enumerate(cases):
            def mutate(paths, result, kind=kind, key=key, value=value):
                data = adapter.read_json(paths[kind])
                data[key] = value
                paths[kind].write_bytes(adapter.encoded(data))
            self.mutate = mutate
            self.state = self.root / f"bad{i}"
            with self.subTest(kind=kind, key=key, value=value):
                self.assertEqual(self.one()["status"], "MECHANICAL_FAIL")

    def test_runner_nonzero_timeout_exception_terminal_no_replay(self):
        for i, error in enumerate((None, subprocess.TimeoutExpired("injected", 1), OSError("injected"))):
            self.runner_error = error
            self.mutate = lambda paths, result: result.update(exit_code=3)
            self.state = self.root / f"error{i}"
            result = self.run_batch()
            self.assertEqual(set(result["cells"].values()), {"MECHANICAL_FAIL"})
            count = len(self.calls)
            self.run_batch(resume_sha=result["checkpoint_sha256"])
            self.assertEqual(len(self.calls), count)

    def test_wrong_report_hash_fails(self):
        self.mutate = lambda paths, result: result.update(report_sha256="0" * 64)
        self.assertEqual(self.one()["status"], "MECHANICAL_FAIL")

    def test_missing_changed_year_split_fails(self):
        for mode in ("missing", "changed", "unparsable", "wrong_report"):
            self.year_mode = mode
            self.state = self.root / mode
            self.assertEqual(self.one()["status"], "MECHANICAL_FAIL")

    def test_incomplete_year_split_trade_reconciliation_fails(self):
        for mode in ("nonzero_no_years", "year_count_mismatch"):
            self.year_mode = mode
            self.state = self.root / mode
            self.assertEqual(self.one()["status"], "MECHANICAL_FAIL")

    def test_year_split_artifact_changed_invalidates_resume(self):
        result = self.run_batch()
        (self.state / "Q0.evidence/synthetic0.years.txt").write_bytes(b"changed")
        with self.assertRaisesRegex(ValueError, "SHA256"):
            self.run_batch(resume_sha=result["checkpoint_sha256"])
        self.assertEqual(self.calls, ["Q0", "Q1", "Q2"])

    def test_ambiguous_started_no_retry(self):
        receipts = []
        def interrupt(receipt):
            receipts.append(receipt)
            raise KeyboardInterrupt()
        with self.assertRaises(KeyboardInterrupt):
            self.run_batch(on_checkpoint=interrupt)
        with self.assertRaisesRegex(ValueError, "AMBIGUOUS_STARTED"):
            self.run_batch(resume_sha=receipts[-1]["checkpoint_sha256"])
        self.assertEqual(self.calls, [])

    def test_partial_resume_skips_completed_prefix(self):
        receipts = []
        def interrupt(receipt):
            receipts.append(receipt)
            if receipt["status"] == "COMPLETE":
                raise KeyboardInterrupt()
        with self.assertRaises(KeyboardInterrupt):
            self.run_batch(on_checkpoint=interrupt)
        self.run_batch(resume_sha=receipts[-1]["checkpoint_sha256"])
        self.assertEqual(self.calls, ["Q0", "Q1", "Q2"])

    def test_explicit_replay_denied(self):
        result = self.run_batch()
        with self.assertRaisesRegex(ValueError, "replay denied"):
            self.run_batch(resume_sha=result["checkpoint_sha256"], replay_cells=["Q0"])

    def test_lock_is_exclusive_during_executor(self):
        def reenter(paths, result):
            with self.assertRaises(FileExistsError):
                self.run_batch()
        self.mutate = reenter
        result = self.run_batch()
        self.assertEqual(set(result["cells"].values()), {"COMPLETE"})
        self.assertEqual(self.calls, ["Q0", "Q1", "Q2"])

    def test_duplicate_json_sidecar_refused(self):
        def mutate(paths, result):
            data = paths["truncation_check"].read_bytes()
            paths["truncation_check"].write_bytes(data[:-1] + b',"truncated":false}')
        self.mutate = mutate
        self.assertEqual(self.one()["status"], "MECHANICAL_FAIL")

    def test_existing_evidence_refused_without_dispatch(self):
        self.state.mkdir()
        (self.state / "Q0.evidence").mkdir()
        with self.assertRaises(FileExistsError):
            self.one()
        self.assertEqual(self.calls, [])

    def test_nonimmutable_cell_refused(self):
        with self.assertRaisesRegex(ValueError, "immutable"):
            adapter.FrozenCell(bytearray(b"{}"))

    def test_changed_seam_same_source_invalidates_resume(self):
        result = self.run_batch()
        runner = self.build()
        runner.parse_report = self.head_reader
        with self.assertRaisesRegex(ValueError, "checkpoint identity/hash"):
            self.run_batch(runner, resume_sha=result["checkpoint_sha256"])
        self.assertEqual(self.calls, ["Q0", "Q1", "Q2"])

    def test_changed_adapter_before_dispatch_blocks(self):
        replacement = self.root / "changed.py"
        replacement.write_text("# changed")
        def change(receipt):
            if receipt["status"] == "STARTED":
                adapter.__file__ = str(replacement)
        with patch.object(adapter, "__file__", adapter.__file__):
            with self.assertRaisesRegex(ValueError, "fingerprint changed before dispatch"):
                self.run_batch(on_checkpoint=change)
        self.assertEqual(self.calls, [])

    def test_changed_prior_evidence_blocks_final_accounting(self):
        def change(receipt):
            if receipt["cell_id"] == "Q2" and receipt["status"] == "COMPLETE":
                (self.state / "Q0.evidence/synthetic0.lane.json").write_bytes(b"changed")
        with self.assertRaisesRegex(ValueError, "SHA256"):
            self.run_batch(on_checkpoint=change)

    def test_changed_adapter_executor_year_source_invalidates_resume(self):
        result = self.run_batch()
        replacement = self.root / "changed.py"
        replacement.write_text("# changed source")
        for module in (adapter, batch.safe, batch):
            with self.subTest(module=module.__name__), patch.object(module, "__file__", str(replacement)):
                with self.assertRaisesRegex(ValueError, "checkpoint identity/hash"):
                    self.run_batch(resume_sha=result["checkpoint_sha256"])
        (self.root / "scripts/report_year_split.py").write_text("# changed")
        with self.assertRaisesRegex(ValueError, "checkpoint identity/hash"):
            self.run_batch(resume_sha=result["checkpoint_sha256"])
        self.assertEqual(self.calls, ["Q0", "Q1", "Q2"])

    def test_changed_adapter_invalidates_final_accounting(self):
        replacement = self.root / "changed.py"
        replacement.write_text("# changed")
        def change(receipt):
            if receipt["cell_id"] == "Q2" and receipt["status"] == "COMPLETE":
                adapter.__file__ = str(replacement)
        with patch.object(adapter, "__file__", adapter.__file__):
            with self.assertRaisesRegex(ValueError, "fingerprint changed"):
                self.run_batch(on_checkpoint=change)


if __name__ == "__main__":
    unittest.main()
