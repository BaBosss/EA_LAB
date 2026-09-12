"""Behavioral cages using synthetic inputs only. Run directly with portable Python."""
import json
import random
import subprocess
import sys
import tempfile
import unittest
from copy import deepcopy
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from audit import Refusal, analyze, canonical, config_digest, digest, freeze, read_json, validate_contract, verify_bwd
from fixtures import bwd_fixture, receipt, scenario, stable_plateau

CLI = Path(__file__).with_name("audit.py")


class SurfaceTests(unittest.TestCase):
    def refusal(self, code, fn, *args):
        with self.assertRaises(Refusal) as ctx:
            fn(*args)
        self.assertEqual(code, ctx.exception.code)

    def test_stable_plateau(self):
        result = analyze(*scenario("stable_plateau"))
        self.assertEqual("FIXTURE_ACCEPTED", result["status"])
        self.assertEqual(9, len(result["eligible_centers"]))
        self.assertEqual({"p0": "1", "p1": "1"}, result["selected_center"])

    def test_isolated_spike(self):
        self.assertEqual("NO_ELIGIBLE_INTERIOR_CENTER", analyze(*scenario("isolated_spike"))["code"])

    def test_boundary_winner(self):
        result = analyze(*scenario("boundary_winner"))
        self.assertEqual({"p0": "1", "p1": "1"}, result["selected_center"])
        self.assertNotIn({"p0": "0", "p1": "0"}, result["eligible_centers"])

    def test_missing_neighbour(self):
        c, rows = scenario("missing_neighbour")
        self.assertEqual("MISSING_REQUIRED_NEIGHBORS", analyze(c, rows)["code"])
        self.assertEqual(1, analyze(c, rows)["missing_cells"])
        self.refusal("MISSING_REQUIRED_NEIGHBORS", freeze, c, rows)

    def test_sparse_genetic(self):
        c, rows = scenario("sparse_genetic_surface")
        self.assertEqual("REGION_MAP_ONLY", analyze(c, rows)["status"])
        self.refusal("GENETIC_CANNOT_FREEZE", freeze, c, rows)

    def test_complete_genetic_still_cannot_freeze(self):
        c, rows = stable_plateau()
        c["search"] = {"method": "FAST_GENETIC", "stage": "COARSE", "small_grid_max_cells": 9}
        self.refusal("GENETIC_CANNOT_FREEZE", freeze, c, rows)

    def test_small_grid_requires_complete(self):
        c, rows = scenario("sparse_genetic_surface")
        c["search"]["small_grid_max_cells"] = 25
        self.refusal("SMALL_GRID_REQUIRES_COMPLETE", analyze, c, rows)

    def test_named_refusal_scenarios(self):
        for name, code in (
            ("holdout_contamination", "HOLDOUT_CONTAMINATION"),
            ("duplicate_parameter_coordinates", "DUPLICATE_COORDINATE"),
            ("malformed_metric", "METRIC"), ("mismatched_config_identity", "CONFIG_MISMATCH"),
            ("mismatched_source_identity", "IDENTITY_MISMATCH")):
            with self.subTest(name=name):
                self.refusal(code, analyze, *scenario(name))

    def test_no_default_policy(self):
        c, rows = stable_plateau()
        del c["policy"]
        self.refusal("SCHEMA", analyze, c, rows)

    def test_contract_changes_eligibility(self):
        c, rows = stable_plateau()
        c["policy"]["eligibility"][0]["value"] = 11
        self.assertEqual("NO_ELIGIBLE_INTERIOR_CENTER", analyze(c, rows)["code"])

    def test_contract_changes_tie_break(self):
        c, rows = stable_plateau()
        for tie in c["policy"]["coordinate_tie_break"]:
            tie["direction"] = "desc"
        self.assertEqual({"p0": "3", "p1": "3"}, analyze(c, rows)["selected_center"])

    def test_rank_is_neighborhood_score(self):
        c, rows = stable_plateau()
        for row in rows:
            x, y = map(int, row["parameters"].values())
            row["metrics"]["net"] = 100 - abs(x - 2) - abs(y - 2)
        self.assertEqual({"p0": "2", "p1": "2"}, analyze(c, rows)["selected_center"])

    def test_rank_secondary_and_direction(self):
        c, rows = stable_plateau()
        for row in rows:
            x, y = map(int, row["parameters"].values())
            row["metrics"]["trades"] = 300 - abs(x - 2) - abs(y - 2)
        self.assertEqual({"p0": "2", "p1": "2"}, analyze(c, rows)["selected_center"])
        c["policy"]["rank"][1]["direction"] = "asc"
        self.assertEqual({"p0": "1", "p1": "1"}, analyze(c, rows)["selected_center"])

    def test_row_order_deterministic(self):
        c, rows = stable_plateau()
        expected, locked = canonical(analyze(c, rows)), canonical(freeze(c, rows))
        for seed in range(5):
            random.Random(seed).shuffle(rows)
            self.assertEqual(expected, canonical(analyze(c, rows)))
            self.assertEqual(locked, canonical(freeze(c, rows)))

    def test_failed_neighbor_disqualifies_center(self):
        c, rows = stable_plateau(3)
        rows[1]["accepted"] = False
        self.assertEqual("NO_ELIGIBLE_INTERIOR_CENTER", analyze(c, rows)["code"])

    def test_three_dimensions(self):
        c, rows = stable_plateau(3, 3)
        self.assertEqual([{"p0": "1", "p1": "1", "p2": "1"}], analyze(c, rows)["eligible_centers"])
        self.assertEqual(6, analyze(c, rows)["neighbor_lookups"])

    def test_exact_parameter_spelling(self):
        c, rows = stable_plateau()
        rows[0]["parameters"]["p0"] = "0.0"
        self.refusal("PARAMETER_IDENTITY", analyze, c, rows)

    def test_numeric_axis_aliases_refused(self):
        c, rows = stable_plateau()
        c["axes"][0]["values"] = ["0", "0.0", "1"]
        self.refusal("AXES", analyze, c, rows)

    def test_metric_validation(self):
        for value in (True, None, "10", float("nan"), float("inf"), -float("inf")):
            with self.subTest(value=value):
                c, rows = stable_plateau()
                rows[0]["metrics"]["net"] = value
                self.refusal("METRIC", analyze, c, rows)

    def test_bwd_cannot_enter_search(self):
        c, rows = stable_plateau()
        rows[0]["phase"], rows[0]["window"] = "BWD", c["windows"]["BWD"]
        self.refusal("PHASE", analyze, c, rows)

    def test_declared_holdout_label(self):
        c, rows = stable_plateau()
        rows[0]["phase"] = "HOLDOUT"
        self.refusal("HOLDOUT_CONTAMINATION", analyze, c, rows)

    def test_holdout_contract_overlap(self):
        c, rows = stable_plateau()
        c["windows"]["MAIN"][1] = "2026-01-01"
        self.refusal("HOLDOUT_CONTAMINATION", analyze, c, rows)

    def test_diagnostic_models(self):
        for model in ("M2", "OPEN_PRICES", "MATH"):
            c, rows = stable_plateau()
            c["identity"]["model"] = model
            self.refusal("DIAGNOSTIC_MODEL", analyze, c, rows)

    def test_production_scope_refused(self):
        c, rows = stable_plateau()
        c["scope"] = "PRODUCTION"
        self.refusal("SCOPE", analyze, c, rows)

    def test_production_row_refused(self):
        c, rows = stable_plateau()
        rows[0]["scope"] = "PRODUCTION"
        self.refusal("SCOPE", analyze, c, rows)

    def test_resource_ceiling(self):
        c, _ = stable_plateau(3)
        c['axes'] = [{'name': f'p{i}', 'values': ['0', '1', '2']} for i in range(13)]
        # 3^13 > one million; do not materialize the grid in the test.
        self.refusal("RESOURCE_LIMIT", validate_contract, c)


class FreezeTests(unittest.TestCase):
    refusal = SurfaceTests.refusal
    def test_bwd_temptation(self):
        c, rows, locked, pin, main, bwd = bwd_fixture()
        bwd["row"]["metrics"]["net"] = -100000
        before = canonical(locked)
        result = verify_bwd(c, rows, locked, pin, main, bwd)
        self.assertEqual("NOT_ASSESSED", result["strategy_verdict"])
        self.assertEqual(before, canonical(locked))
        other = next(r for r in rows if r["parameters"] == {"p0": "2", "p1": "2"})
        tempting = receipt(c, other, pin, "BWD", main)
        tempting["row"]["metrics"]["net"] = 1_000_000
        self.refusal("FROZEN_CENTER_CHANGED", verify_bwd, c, rows, locked, pin, main, tempting)

    def test_tampered_freeze(self):
        c, rows, locked, pin, main, bwd = bwd_fixture()
        locked["selected_center"]["p0"] = "2"
        self.refusal("FREEZE_TAMPERED", verify_bwd, c, rows, locked, pin, main, bwd)

    def test_changed_surface(self):
        c, rows, locked, pin, main, bwd = bwd_fixture()
        rows[0]["metrics"]["net"] += 1
        self.refusal("FREEZE_MISMATCH", verify_bwd, c, rows, locked, pin, main, bwd)

    def test_changed_contract(self):
        c, rows, locked, pin, main, bwd = bwd_fixture()
        c["contract_id"] += "-retune"
        self.refusal("FREEZE_MISMATCH", verify_bwd, c, rows, locked, pin, main, bwd)

    def test_fixed_main_required(self):
        c, rows, locked, pin, main, bwd = bwd_fixture()
        bwd["after_main_sha256"] = "0" * 64
        self.refusal("LINEAGE", verify_bwd, c, rows, locked, pin, main, bwd)

    def test_main_center_changed(self):
        c, rows, locked, pin, main, bwd = bwd_fixture()
        main["row"]["parameters"] = rows[0]["parameters"]
        main["row"]["fixture_config_sha256"] = rows[0]["fixture_config_sha256"]
        self.refusal("FROZEN_CENTER_CHANGED", verify_bwd, c, rows, locked, pin, main, bwd)

    def test_bwd_identity_changes(self):
        for field in ("install_id", "source_sha256", "build_sha256", "locked_config_sha256", "model"):
            c, rows, locked, pin, main, bwd = bwd_fixture()
            bwd["row"]["identity"][field] = "changed"
            self.refusal("IDENTITY_MISMATCH", verify_bwd, c, rows, locked, pin, main, bwd)

    def test_mechanical_failure(self):
        c, rows, locked, pin, main, bwd = bwd_fixture()
        bwd["row"]["accepted"] = False
        self.refusal("MECHANICAL_EVIDENCE_INCOMPLETE", verify_bwd, c, rows, locked, pin, main, bwd)


class CLITests(unittest.TestCase):
    def test_exported_scenarios(self):
        with tempfile.TemporaryDirectory() as tmp:
            destination = Path(tmp) / "fixtures"
            exported = subprocess.run([sys.executable, str(CLI.with_name("fixtures.py")), str(destination)],
                                      capture_output=True, text=True)
            self.assertEqual(0, exported.returncode, exported.stderr)
            self.assertEqual(11, len(list(destination.iterdir())))
            for folder in sorted(destination.iterdir()):
                if folder.name == "bwd_temptation":
                    continue
                result = subprocess.run([sys.executable, str(CLI), "audit", str(folder / "contract.json"),
                                         "--surface", str(folder / "surface.json")],
                                        capture_output=True, text=True)
                expected = 0 if folder.name in ("stable_plateau", "boundary_winner") else 2
                self.assertEqual(expected, result.returncode, result.stdout + result.stderr)
                self.assertFalse(json.loads(result.stdout)["candidate_authority"])

    def test_file_workflow_and_overwrite_refusal(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            c, rows, locked, pin, main, bwd = bwd_fixture()
            for name, value in (("contract", c), ("surface", rows), ("frozen", locked),
                                ("fixed-main", main), ("bwd", bwd)):
                (root / name).write_bytes(canonical(value))
            def call(*args):
                return subprocess.run([sys.executable, str(CLI), *map(str, args)],
                                      capture_output=True, text=True)
            self.assertEqual(0, call("preflight", root / "contract").returncode)
            out = root / "output"
            args = ("freeze", root / "contract", "--surface", root / "surface", "--output", out)
            self.assertEqual(0, call(*args).returncode)
            self.assertEqual(locked, read_json(out))
            before = out.read_bytes()
            self.assertEqual(2, call(*args).returncode)
            self.assertEqual(before, out.read_bytes())
            result = call("verify-bwd", root / "contract", "--surface", root / "surface",
                          "--frozen", root / "frozen", "--freeze-sha256", pin,
                          "--fixed-main", root / "fixed-main", "--bwd", root / "bwd")
            self.assertEqual(0, result.returncode, result.stdout)
            self.assertEqual("FIXTURE_LINEAGE_VALID", json.loads(result.stdout)["status"])
            self.assertFalse(json.loads(result.stdout)["candidate_authority"])

    def test_malformed_json_refusal(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "bad.json"
            for text in ('{"scope":"FIXTURE_ONLY","scope":"PRODUCTION"}', '{"metric":NaN}', '{'):
                path.write_text(text)
                result = subprocess.run([sys.executable, str(CLI), "preflight", str(path)],
                                        capture_output=True, text=True)
                self.assertEqual(2, result.returncode)
                self.assertEqual("REFUSED", json.loads(result.stdout)["status"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
