import csv
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import batch_executor as batch


class BatchTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.state = self.root / "state"
        self.setfile = self.root / batch.safe.EXPECTED_SET_REL
        self.setfile.parent.mkdir(parents=True)
        self.setfile.write_text("fixture set")
        (self.root / "artifact.ex5").write_bytes(b"not executable: fixture")
        artifact_sha = batch.safe.sha256_path(self.root / "artifact.ex5")
        (self.root / "receipt.jsonl").write_text(json.dumps({
            "ea_logical_identity": "Probe_19_AdaptiveTrendGrid", "artifact_sha256": artifact_sha}))
        self.rows = [dict(cell_id=f"C{i}", symbol="XAUUSD", tf="H4", window="MAIN",
                          from_date="2023.01.01", to_date="2025.12.31", model="1",
                          set_path=batch.safe.EXPECTED_SET_REL, report_name=f"report{i}",
                          holdout="NO", optimization="NO") for i in range(3)]
        self.contract = dict(schema="hermes-batch/1", mode="FIXTURE_ONLY", head="a" * 40,
                             manifest="manifest.csv", manifest_sha256="", receipt="receipt.jsonl",
                             receipt_sha256=batch.safe.sha256_path(self.root / "receipt.jsonl"),
                             set_sha256=batch.safe.sha256_path(self.setfile), artifact="artifact.ex5",
                             artifact_sha256=artifact_sha, lane="FIXTURE_NO_MT5")
        self.write_manifest()
        self.calls = []

    def write_manifest(self):
        path = self.root / "manifest.csv"
        with path.open("w", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(self.rows[0]))
            writer.writeheader()
            writer.writerows(self.rows)
        self.contract["manifest_sha256"] = batch.safe.sha256_path(path)

    def runner(self, row, state):
        self.calls.append(row["cell_id"])
        return batch.fixture_runner(row, state)

    def run_batch(self, **kwargs):
        kwargs.setdefault("runner", self.runner)
        kwargs.setdefault("head_reader", lambda root: "a" * 40)
        return batch.run_batch(self.root, self.contract, self.state, **kwargs)

    def checkpoint_sha(self):
        return batch.safe.sha256_path(self.state / "checkpoint.jsonl")

    def test_serial_manifest_and_verified_noop_resume(self):
        result = self.run_batch()
        self.assertEqual(self.calls, ["C0", "C1", "C2"])
        self.assertFalse(result["authority_granted"])
        self.assertEqual(len((self.state / "checkpoint.jsonl").read_text().splitlines()), 6)
        self.run_batch(resume_sha=result["checkpoint_sha256"])
        self.assertEqual(self.calls, ["C0", "C1", "C2"])

    def test_wrong_manifest_sha(self):
        self.contract["manifest_sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "manifest SHA256"):
            self.run_batch()
        self.assertEqual(self.calls, [])

    def test_wrong_set_sha(self):
        self.contract["set_sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "set SHA256"):
            self.run_batch()

    def test_wrong_receipt_sha(self):
        self.contract["receipt_sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "receipt registry SHA256"):
            self.run_batch()

    def test_wrong_artifact_sha(self):
        (self.root / "artifact.ex5").write_bytes(b"changed")
        with self.assertRaisesRegex(ValueError, "artifact SHA256"):
            self.run_batch()

    def test_duplicate_cell(self):
        self.rows[2]["cell_id"] = "c0"
        self.write_manifest()
        with self.assertRaisesRegex(ValueError, "duplicate cell"):
            self.run_batch()

    def test_duplicate_report(self):
        self.rows[2]["report_name"] = "REPORT0"
        self.write_manifest()
        with self.assertRaisesRegex(ValueError, "duplicate report"):
            self.run_batch()

    def test_holdout(self):
        self.rows[2]["holdout"] = "YES"
        self.write_manifest()
        with self.assertRaisesRegex(ValueError, "HOLDOUT"):
            self.run_batch()
        self.assertEqual(self.calls, [])

    def test_optimization(self):
        self.rows[2]["optimization"] = "YES"
        self.write_manifest()
        with self.assertRaisesRegex(ValueError, "optimization"):
            self.run_batch()

    def test_out_of_contract(self):
        self.rows[2]["tf"] = "M5"
        self.write_manifest()
        with self.assertRaisesRegex(ValueError, "authorization"):
            self.run_batch()

    def test_wrong_head(self):
        with self.assertRaisesRegex(ValueError, "HEAD"):
            self.run_batch(head_reader=lambda root: "b" * 40)

    def test_checkpoint_different_contract_head(self):
        self.run_batch()
        self.contract["head"] = "b" * 40
        with self.assertRaisesRegex(ValueError, "checkpoint identity"):
            self.run_batch(resume_sha=self.checkpoint_sha(), head_reader=lambda root: "b" * 40)

    def test_checkpoint_tampering(self):
        result = self.run_batch()
        path = self.state / "checkpoint.jsonl"
        path.write_bytes(path.read_bytes().replace(b"COMPLETE", b"REJECTED"))
        with self.assertRaisesRegex(ValueError, "checkpoint SHA256"):
            self.run_batch(resume_sha=result["checkpoint_sha256"])

    def test_checkpoint_chain_tampering(self):
        self.run_batch()
        path = self.state / "checkpoint.jsonl"
        path.write_bytes(path.read_bytes().replace(b"COMPLETE", b"REJECTED"))
        with self.assertRaisesRegex(ValueError, "checkpoint identity/hash"):
            self.run_batch(resume_sha=self.checkpoint_sha())

    def test_checkpoint_truncation(self):
        result = self.run_batch()
        path = self.state / "checkpoint.jsonl"
        path.write_bytes(b"\n".join(path.read_bytes().splitlines()[:2]) + b"\n")
        with self.assertRaisesRegex(ValueError, "checkpoint SHA256"):
            self.run_batch(resume_sha=result["checkpoint_sha256"])

    def test_report_hash_tampering(self):
        self.run_batch()
        (self.state / "C0.fixture.json").write_text("tampered")
        with self.assertRaisesRegex(ValueError, "report artifact SHA256"):
            self.run_batch(resume_sha=self.checkpoint_sha())

    def test_output_hash_tampering(self):
        self.run_batch()
        (self.state / "C0.output.json").write_text("{}")
        with self.assertRaisesRegex(ValueError, "output SHA256"):
            self.run_batch(resume_sha=self.checkpoint_sha())

    def test_completed_replay_request(self):
        self.run_batch()
        with self.assertRaisesRegex(ValueError, "replay denied"):
            self.run_batch(resume_sha=self.checkpoint_sha(), replay_cells=["C0"])
        self.assertEqual(len(self.calls), 3)

    def test_implicit_replay_denied(self):
        self.run_batch()
        with self.assertRaisesRegex(ValueError, "explicit verified resume"):
            self.run_batch()

    def test_partial_resume_only_unstarted(self):
        # Interrupt before next STARTED, after durable completion of C0.
        reads = []
        receipts = []
        def head(root):
            reads.append(1)
            if len(reads) == 3:
                raise KeyboardInterrupt()
            return "a" * 40
        with self.assertRaises(KeyboardInterrupt):
            self.run_batch(head_reader=head, on_checkpoint=receipts.append)
        self.assertEqual(self.calls, ["C0"])
        self.assertEqual(receipts[-1]["status"], "COMPLETE")
        self.run_batch(resume_sha=receipts[-1]["checkpoint_sha256"])
        self.assertEqual(self.calls, ["C0", "C1", "C2"])

    def test_ambiguous_started_never_replayed(self):
        def interrupted(row, state):
            raise KeyboardInterrupt()
        with self.assertRaises(KeyboardInterrupt):
            self.run_batch(runner=interrupted)
        with self.assertRaisesRegex(ValueError, "AMBIGUOUS_STARTED"):
            self.run_batch(resume_sha=self.checkpoint_sha())
        self.assertEqual(self.calls, [])

    def test_mechanical_failure_is_terminal_and_preserved(self):
        def failed(row, state):
            self.calls.append(row["cell_id"])
            raise OSError("environment unavailable")
        result = self.run_batch(runner=failed)
        self.assertEqual(set(result["cells"].values()), {"MECHANICAL_FAIL"})
        self.run_batch(resume_sha=result["checkpoint_sha256"])
        self.assertEqual(len(self.calls), 3)
        self.assertNotIn("strategy", json.dumps(result))

    def test_strategy_result_denied(self):
        def bad(row, state):
            return dict(cell_id=row["cell_id"], status="STRATEGY_FAIL", reason="FIXTURE_OK", artifacts=[])
        with self.assertRaisesRegex(ValueError, "nonmechanical"):
            self.run_batch(runner=bad)

    def test_changed_manifest_between_cells(self):
        def mutate(row, state):
            result = self.runner(row, state)
            (self.root / "manifest.csv").write_text("changed")
            return result
        with self.assertRaisesRegex(ValueError, "manifest SHA256"):
            self.run_batch(runner=mutate)
        self.assertEqual(self.calls, ["C0"])

    def test_final_contract_reverified(self):
        def mutate(row, state):
            result = self.runner(row, state)
            if row["cell_id"] == "C2":
                self.setfile.write_text("changed")
            return result
        with self.assertRaisesRegex(ValueError, "set SHA256"):
            self.run_batch(runner=mutate)

    def test_final_prior_artifacts_reverified(self):
        def mutate(row, state):
            result = self.runner(row, state)
            if row["cell_id"] == "C2":
                (state / "C0.fixture.json").write_text("changed")
            return result
        with self.assertRaisesRegex(ValueError, "report artifact SHA256"):
            self.run_batch(runner=mutate)

    def test_checkpoint_symlink_refused_before_read(self):
        from unittest.mock import patch
        self.run_batch()
        with patch.object(Path, "is_symlink", return_value=True):
            with self.assertRaisesRegex(ValueError, "checkpoint path escape"):
                self.run_batch(resume_sha=self.checkpoint_sha())

    def test_checkpoint_hardlink_refused(self):
        import os
        self.run_batch()
        os.link(self.state / "checkpoint.jsonl", self.root / "alias.jsonl")
        with self.assertRaisesRegex(ValueError, "checkpoint path escape"):
            self.run_batch(resume_sha=self.checkpoint_sha())

    def test_runner_cannot_rewrite_valid_checkpoint_prefix(self):
        def mutate(row, state):
            result = self.runner(row, state)
            if row["cell_id"] == "C2":
                path = state / "checkpoint.jsonl"
                path.write_bytes(b"\n".join(path.read_bytes().splitlines()[:2]) + b"\n")
            return result
        with self.assertRaisesRegex(ValueError, "checkpoint SHA256"):
            self.run_batch(runner=mutate)

    def test_receipt_consumer_interruption_resumes_completed_prefix(self):
        receipts = []
        def stop(receipt):
            receipts.append(receipt)
            if receipt["status"] == "COMPLETE":
                raise KeyboardInterrupt()
        with self.assertRaises(KeyboardInterrupt):
            self.run_batch(on_checkpoint=stop)
        self.run_batch(resume_sha=receipts[-1]["checkpoint_sha256"])
        self.assertEqual(self.calls, ["C0", "C1", "C2"])

    def test_lock_blocks_concurrent_or_abandoned_run(self):
        self.state.mkdir()
        (self.state / "batch.lock").write_text("owned")
        with self.assertRaises(FileExistsError):
            self.run_batch()

    def test_real_mode_denied(self):
        self.contract["mode"] = "TESTER_EXECUTE"
        with self.assertRaisesRegex(ValueError, "fixture"):
            self.run_batch()

    def test_state_escape_denied(self):
        self.state = self.root.parent / "outside"
        with self.assertRaises(ValueError):
            self.run_batch()

    def test_cli_streams_receipts_with_fixture_only_runner(self):
        import contextlib
        import io
        from unittest.mock import patch
        contract_path = self.root / "contract.json"
        contract_path.write_bytes(batch.encoded(self.contract))
        argv = ["batch_executor.py", "--workspace", str(self.root), "--contract", str(contract_path),
                "--contract-sha256", batch.safe.sha256_path(contract_path), "--state", str(self.state)]
        stream = io.StringIO()
        with patch.object(sys, "argv", argv), patch.object(batch.subprocess, "check_output", return_value="a" * 40), contextlib.redirect_stdout(stream):
            self.assertEqual(batch.main(), 0)
        lines = [json.loads(line) for line in stream.getvalue().splitlines()]
        self.assertEqual(len(lines), 7)
        self.assertEqual(lines[0]["checkpoint_receipt"]["status"], "STARTED")
        self.assertEqual(lines[-1]["checkpoint_sha256"], lines[-2]["checkpoint_receipt"]["checkpoint_sha256"])

    def test_cli_wrong_contract_pin_is_visible(self):
        import contextlib
        import io
        from unittest.mock import patch
        path = self.root / "contract.json"
        path.write_bytes(batch.encoded(self.contract))
        argv = ["batch_executor.py", "--workspace", str(self.root), "--contract", str(path),
                "--contract-sha256", "0" * 64, "--state", str(self.state)]
        stream = io.StringIO()
        with patch.object(sys, "argv", argv), contextlib.redirect_stdout(stream):
            self.assertEqual(batch.main(), 2)
        self.assertEqual(json.loads(stream.getvalue())["status"], "BLOCKED_MECHANICAL")
        self.assertFalse(self.state.exists())


if __name__ == "__main__":
    unittest.main()
