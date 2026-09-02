import csv
import importlib.util
import json
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "scripts" / "research" / "boss19_p4b" / "build_broad36_roi_gate.py"
spec = importlib.util.spec_from_file_location("roi_gate", SCRIPT)
roi = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(roi)


class Broad36RoiGateTests(unittest.TestCase):
    def make_inputs(self, root: Path):
        repair = root / "repair.json"
        run = root / "run.json"
        suitability = root / "suitability.json"
        matrix = root / "matrix.csv"
        progress = root / "progress.jsonl"
        repair.write_text(json.dumps({
            "status": "PASS", "broad_rerun": "LOCKED_PENDING_CONTROL_TOWER_ROI_GATE",
            "holdout": "UNSPENT", "optimization": "NONE",
            "mechanical_gate": {"status": "PASS"}, "source_magic_gate": {"status": "PASS"},
        }), encoding="utf-8")
        run.write_text(json.dumps({
            "status": "PASS_SOURCE_BOUND_UNIT_RUN", "cell_id": "H3-C03-MAIN", "model": 1,
            "holdout": "UNSPENT", "optimization": "NONE",
            "linkage_basis": "EXACT_DEAL_POSITION_ID_ONE_IN_ONE_OUT",
            "source_magic_provenance": "PER_DEAL_HISTORY_DEAL_MAGIC",
            "started_utc": "2026-09-02T05:48:53Z", "completed_utc": "2026-09-02T05:49:31Z",
        }), encoding="utf-8")
        suitability.write_text(json.dumps({
            "provenance": {"holdout": "UNSPENT", "optimization": "NONE", "timeline_rows": 1242682,
                           "timeline_sha256": "a" * 64},
            "report_audit": {"reports_verified": 36, "total_realized_out_deals": 1549},
        }), encoding="utf-8")
        fields = ["cell_id", "symbol", "tf", "window", "model", "holdout", "optimization"]
        symbols = ["XAUUSD", "EURUSD", "GBPUSD", "AUDUSD", "USDJPY", "BTCUSD"]
        with matrix.open("w", newline="", encoding="utf-8") as fh:
            writer = csv.DictWriter(fh, fieldnames=fields)
            writer.writeheader()
            n = 0
            for symbol in symbols:
                for tf in ("M15", "H1", "H4"):
                    n += 1
                    for window in ("MAIN", "BWD"):
                        writer.writerow({"cell_id": f"H3-C{n:02d}-{window}", "symbol": symbol, "tf": tf,
                                         "window": window, "model": "1", "holdout": "NO", "optimization": "NO"})
        start = datetime(2026, 8, 29, 12, 0, tzinfo=timezone.utc)
        with progress.open("w", encoding="utf-8") as fh:
            for i in range(36):
                seconds = i * 60 + (600 if i >= 20 else 0)
                row = {"recorded_at": (start + timedelta(seconds=seconds)).isoformat(), "cell_id": f"cell-{i}"}
                fh.write(json.dumps(row) + "\n")
        return repair, run, suitability, matrix, progress

    def build(self, root: Path):
        args = self.make_inputs(root)
        return roi.build_gate(*args, "f" * 40)

    def test_valid_gate_proceeds_without_new_authority(self):
        with tempfile.TemporaryDirectory() as td:
            gate = self.build(Path(td))
            self.assertEqual(gate["roi_decision"], "PROCEED_BROAD36_SOURCE_BOUND_EXECUTION")
            self.assertEqual(gate["runtime_forecast"]["broad_runs_assumed"], 36)
            self.assertEqual(gate["evidence"]["historical_h3_realized_deals"], 1549)
            self.assertEqual(gate["evidence"]["selection_surface"], "NONE_FULL_FROZEN_36_CELL_MATRIX")
            self.assertIn("NO_HOLDOUT", gate["authority"])

    def test_repair03_failure_refuses(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            repair, *rest = self.make_inputs(root)
            value = json.loads(repair.read_text())
            value["status"] = "BLOCKED"
            repair.write_text(json.dumps(value), encoding="utf-8")
            with self.assertRaisesRegex(roi.Refusal, "Repair03 status"):
                roi.build_gate(repair, *rest, "f" * 40)

    def test_matrix_count_drift_refuses(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            repair, run, suitability, matrix, progress = self.make_inputs(root)
            lines = matrix.read_text(encoding="utf-8").splitlines()
            matrix.write_text("\n".join(lines[:-1]) + "\n", encoding="utf-8")
            with self.assertRaisesRegex(roi.Refusal, "exactly 36"):
                roi.build_gate(repair, run, suitability, matrix, progress, "f" * 40)

    def test_holdout_or_optimization_drift_refuses(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            repair, run, suitability, matrix, progress = self.make_inputs(root)
            value = json.loads(repair.read_text())
            value["holdout"] = "SPENT"
            repair.write_text(json.dumps(value), encoding="utf-8")
            with self.assertRaisesRegex(roi.Refusal, "HOLDOUT"):
                roi.build_gate(repair, run, suitability, matrix, progress, "f" * 40)

    def test_runtime_incident_is_not_treated_as_normal_cost(self):
        with tempfile.TemporaryDirectory() as td:
            gate = self.build(Path(td))
            runtime = gate["runtime_forecast"]
            self.assertEqual(runtime["historical_incident_interval_count"], 1)
            self.assertEqual(runtime["historical_normal_median_projection_minutes"], 36.0)
            self.assertEqual(runtime["pilot_rate_projection_minutes"], 22.8)

    def test_timeline_identity_drift_refuses(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            repair, run, suitability, matrix, progress = self.make_inputs(root)
            value = json.loads(suitability.read_text())
            value["provenance"]["timeline_rows"] = 1
            suitability.write_text(json.dumps(value), encoding="utf-8")
            with self.assertRaisesRegex(roi.Refusal, "timeline row count"):
                roi.build_gate(repair, run, suitability, matrix, progress, "f" * 40)

    def test_same_inputs_render_deterministically(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            gate1 = self.build(root)
            gate2 = self.build(root)
            self.assertEqual(json.dumps(gate1, sort_keys=True), json.dumps(gate2, sort_keys=True))
            self.assertEqual(roi.render_markdown(gate1), roi.render_markdown(gate2))


if __name__ == "__main__":
    unittest.main()
