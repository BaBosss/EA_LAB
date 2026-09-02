import csv
import importlib.util
import json
import subprocess
import sys
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
            "status": "BLOCKED(EVIDENCE_UNSUITABLE_FOR_UNIT_ATTRIBUTION)",
            "blocker_reason": "NO_DURABLE_REALIZED_DEAL_TO_OPENING_TIMESTAMP_LINKAGE_IN_H3_REPORT_BYTES",
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
            self.assertEqual(gate["execution_action"], "PROCEED_BROAD36_SOURCE_BOUND_EXECUTION")
            self.assertNotIn("roi_decision", gate)
            self.assertIn("RUNTIME_CONTEXT_IS_NOT_A_NUMERIC_GATE", gate["decision_basis"])
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
            self.assertEqual(runtime["planning_projection_minutes_rounded"]["historical_interval_median_rate"], 36)
            self.assertEqual(runtime["planning_projection_minutes_rounded"]["single_pilot_rate"], 23)
            self.assertEqual(runtime["forecast_role"], "INFORMATIONAL_PLANNING_ONLY_NOT_A_DECISION_CONDITION")
            self.assertEqual(runtime["repair03_pilot_sample_count"], 1)
            self.assertIn("heterogeneous", runtime["sample_heterogeneity"])

    def test_timeline_identity_drift_refuses(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            repair, run, suitability, matrix, progress = self.make_inputs(root)
            value = json.loads(suitability.read_text())
            value["provenance"]["timeline_rows"] = 1
            suitability.write_text(json.dumps(value), encoding="utf-8")
            with self.assertRaisesRegex(roi.Refusal, "timeline row count"):
                roi.build_gate(repair, run, suitability, matrix, progress, "f" * 40)

    def test_cli_build_emits_current_execution_action(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            repair, run, suitability, matrix, progress = self.make_inputs(root)
            out_json = root / "gate.json"
            out_md = root / "gate.md"
            cmd = [sys.executable, str(SCRIPT),
                   "--repair03-result", str(repair), "--repair03-run-manifest", str(run),
                   "--h3-unit-suitability", str(suitability), "--h3-matrix", str(matrix),
                   "--h3-progress", str(progress), "--base-sha", "f" * 40,
                   "--out-json", str(out_json), "--out-md", str(out_md)]
            completed = subprocess.run(cmd, text=True, capture_output=True, check=False)
            self.assertEqual(completed.returncode, 0, completed.stderr)
            payload = json.loads(completed.stdout.strip())
            self.assertEqual(payload["decision"], "PROCEED_BROAD36_SOURCE_BOUND_EXECUTION")
            gate = json.loads(out_json.read_text(encoding="utf-8"))
            self.assertEqual(gate["execution_action"], payload["decision"])
            self.assertNotIn("roi_decision", gate)
            self.assertTrue(out_md.is_file())

    def test_same_inputs_render_deterministically(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            gate1 = self.build(root)
            gate2 = self.build(root)
            self.assertEqual(json.dumps(gate1, sort_keys=True), json.dumps(gate2, sort_keys=True))
            self.assertEqual(roi.render_markdown(gate1), roi.render_markdown(gate2))

    def test_matrix_content_drifts_refuse(self):
        cases = [
            ("duplicate cell", lambda rows: rows[0].__setitem__("cell_id", rows[1]["cell_id"]), "cell IDs"),
            ("model", lambda rows: rows[0].__setitem__("model", "4"), "model drift"),
            ("holdout", lambda rows: rows[0].__setitem__("holdout", "YES"), "HOLDOUT drift"),
            ("optimization", lambda rows: rows[0].__setitem__("optimization", "YES"), "optimization drift"),
            ("window", lambda rows: rows[0].__setitem__("window", "OTHER"), "window drift"),
            ("symbol count", lambda rows: [r.__setitem__("symbol", "XAUUSD") for r in rows if r["symbol"] == "BTCUSD"], "symbol-count drift"),
            ("tf", lambda rows: [r.__setitem__("tf", "H1") for r in rows if r["tf"] == "H4"], "TF drift"),
        ]
        for name, mutate, message in cases:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as td:
                root = Path(td)
                repair, run, suitability, matrix, progress = self.make_inputs(root)
                with matrix.open("r", newline="", encoding="utf-8") as fh:
                    rows = list(csv.DictReader(fh))
                    fields = list(rows[0].keys())
                mutate(rows)
                with matrix.open("w", newline="", encoding="utf-8") as fh:
                    writer = csv.DictWriter(fh, fieldnames=fields)
                    writer.writeheader(); writer.writerows(rows)
                with self.assertRaisesRegex(roi.Refusal, message):
                    roi.build_gate(repair, run, suitability, matrix, progress, "f" * 40)

    def test_repair03_subgate_drifts_refuse(self):
        cases = [("mechanical_gate", "Repair03 mechanical gate"), ("source_magic_gate", "Repair03 source-magic gate")]
        for key, message in cases:
            with self.subTest(key=key), tempfile.TemporaryDirectory() as td:
                root = Path(td)
                repair, run, suitability, matrix, progress = self.make_inputs(root)
                value = json.loads(repair.read_text())
                value[key]["status"] = "BLOCKED"
                repair.write_text(json.dumps(value), encoding="utf-8")
                with self.assertRaisesRegex(roi.Refusal, message):
                    roi.build_gate(repair, run, suitability, matrix, progress, "f" * 40)

    def test_run_identity_and_provenance_drifts_refuse(self):
        cases = [
            ("cell_id", "H3-C04-MAIN", "pilot cell drift"),
            ("model", 4, "run model drift"),
            ("linkage_basis", "HEURISTIC", "linkage drift"),
            ("source_magic_provenance", "CONFIGURED_MAGIC_ONLY", "source-magic provenance drift"),
        ]
        for key, changed, message in cases:
            with self.subTest(key=key), tempfile.TemporaryDirectory() as td:
                root = Path(td)
                repair, run, suitability, matrix, progress = self.make_inputs(root)
                value = json.loads(run.read_text())
                value[key] = changed
                run.write_text(json.dumps(value), encoding="utf-8")
                with self.assertRaisesRegex(roi.Refusal, message):
                    roi.build_gate(repair, run, suitability, matrix, progress, "f" * 40)

    def test_suitability_status_and_audit_drifts_refuse(self):
        cases = [
            (("status",), "PASS", "suitability status drift"),
            (("blocker_reason",), "OTHER", "blocker reason drift"),
            (("report_audit", "reports_verified"), 35, "verifies 36 reports"),
            (("report_audit", "total_realized_out_deals"), 1548, "deal population drift"),
        ]
        for path, changed, message in cases:
            with self.subTest(path=path), tempfile.TemporaryDirectory() as td:
                root = Path(td)
                repair, run, suitability, matrix, progress = self.make_inputs(root)
                value = json.loads(suitability.read_text())
                target = value
                for part in path[:-1]: target = target[part]
                target[path[-1]] = changed
                suitability.write_text(json.dumps(value), encoding="utf-8")
                with self.assertRaisesRegex(roi.Refusal, message):
                    roi.build_gate(repair, run, suitability, matrix, progress, "f" * 40)

    def test_progress_shape_and_incident_edge_cases_refuse(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            repair, run, suitability, matrix, progress = self.make_inputs(root)
            lines = progress.read_text(encoding="utf-8").splitlines()
            progress.write_text("\n".join(lines[:-1]) + "\n", encoding="utf-8")
            with self.assertRaisesRegex(roi.Refusal, "36 completions"):
                roi.build_gate(repair, run, suitability, matrix, progress, "f" * 40)
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            repair, run, suitability, matrix, progress = self.make_inputs(root)
            start = datetime(2026, 8, 29, 12, 0, tzinfo=timezone.utc)
            with progress.open("w", encoding="utf-8") as fh:
                for i in range(36):
                    fh.write(json.dumps({"recorded_at": (start + timedelta(seconds=i * 600)).isoformat(), "cell_id": f"cell-{i}"}) + "\n")
            with self.assertRaisesRegex(roi.Refusal, "no usable non-incident"):
                roi.build_gate(repair, run, suitability, matrix, progress, "f" * 40)



if __name__ == "__main__":
    unittest.main()
