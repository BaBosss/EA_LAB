import csv
import hashlib
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools" / "p4b_unit_attribution" / "validate_broad36_prejoin.py"
spec = importlib.util.spec_from_file_location("prejoin", SCRIPT)
prejoin = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(prejoin)

RUNTIME_HEAD = "a" * 40
SYMBOLS = ["XAUUSD", "EURUSD", "GBPUSD", "AUDUSD", "USDJPY", "BTCUSD"]
TFS = ["M15", "H1", "H4"]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class Broad36PrejoinTests(unittest.TestCase):
    def make_matrix(self, root: Path) -> Path:
        path = root / "H3_BROAD_MATRIX_MANIFEST.csv"
        fields = ["cell_id", "symbol", "tf", "window", "from_date", "to_date", "model", "set_path", "report_name", "holdout", "optimization"]
        with path.open("w", encoding="utf-8", newline="") as fh:
            writer = csv.DictWriter(fh, fieldnames=fields, lineterminator="\n")
            writer.writeheader()
            n = 0
            for symbol in SYMBOLS:
                for tf in TFS:
                    n += 1
                    for window in ("MAIN", "BWD"):
                        writer.writerow({
                            "cell_id": f"H3-C{n:02d}-{window}", "symbol": symbol, "tf": tf, "window": window,
                            "from_date": "2023.01.01" if window == "MAIN" else "2020.01.01",
                            "to_date": "2025.12.31" if window == "MAIN" else "2022.12.31",
                            "model": "1", "set_path": "frozen.set", "report_name": "r", "holdout": "NO", "optimization": "NO",
                        })
        return path

    def unit_row(self, cell: str, symbol: str, tf: str, deal_id: str = "2") -> dict[str, str]:
        period = {"M15":"15", "H1":"60", "H4":"240"}[tf]
        return {
            "schema_version": prejoin.UNIT_SCHEMA, "h3_run_id": cell, "symbol": symbol,
            "period": period, "period_name": f"PERIOD_{tf}", "configured_run_magic": "990001",
            "source_open_deal_magic": "990001", "source_close_deal_magic": "990001", "account_margin_mode": "2",
            "source_position_id": "10", "source_open_deal_id": "1", "source_deal_id": deal_id,
            "source_open_order_id": "11", "source_close_order_id": "12",
            "entry_time_server": "2023.01.01 02:00:00", "exit_time_server": "2023.01.01 03:00:00",
            "entry_time_msc": "1672538400000", "exit_time_msc": "1672542000000",
            "entry_utc": "2023-01-01T00:00:00Z", "exit_utc": "2023-01-01T01:00:00Z",
            "time_status": "COMPLETE", "time_unknown_reason": "", "entry_volume": "0.01", "exit_volume": "0.01",
            "entry_price": "100", "exit_price": "101", "entry_commission": "0", "entry_swap": "0",
            "entry_profit": "0", "exit_commission": "0", "exit_swap": "0", "exit_profit": "1.25",
            "source_net_realized": "1.25",
        }
    def write_units(self, path: Path, rows: list[dict[str, str]]) -> None:
        with path.open("w", encoding="utf-8", newline="") as fh:
            writer = csv.DictWriter(fh, fieldnames=list(prejoin.REQUIRED_UNIT_FIELDS), lineterminator="\n")
            writer.writeheader()
            writer.writerows(rows)

    def make_fixture(self, root: Path) -> tuple[Path, Path]:
        matrix = self.make_matrix(root)
        matrix_sha = sha(matrix)
        evidence = root / "evidence"
        with matrix.open("r", encoding="utf-8", newline="") as fh:
            rows = list(csv.DictReader(fh))
        for row in rows:
            cell = row["cell_id"]
            run_dir = evidence / cell
            run_dir.mkdir(parents=True)
            (run_dir / "report.htm").write_text(f"report {cell}\n", encoding="utf-8")
            (run_dir / "source.csv").write_text(f"source {cell}\n", encoding="utf-8")
            self.write_units(run_dir / "units.csv", [self.unit_row(cell, row["symbol"], row["tf"])])
            unit = self.unit_manifest(run_dir, row)
            (run_dir / "unit_manifest.json").write_text(json.dumps(unit), encoding="utf-8")
            run = self.run_manifest(run_dir, row, matrix_sha)
            (run_dir / "run_manifest.json").write_text(json.dumps(run), encoding="utf-8")
        return evidence, matrix
    def unit_manifest(self, run_dir: Path, row: dict[str, str]) -> dict:
        return {
            "schema_version": prejoin.UNIT_MANIFEST_SCHEMA, "h3_run_id": row["cell_id"], "window": row["window"],
            "configured_run_magic": 990001, "source_magic_values": [0, 990001],
            "source_magic_provenance": prejoin.MAGIC_PROVENANCE,
            "source_in_count": 1, "source_out_count": 1, "source_position_count": 1,
            "source_owned_position_count": 1, "realized_unit_count": 1, "open_position_count": 0,
            "unknown_time_unit_count": 0, "linkage_basis": prejoin.LINKAGE,
            "forbidden_inference_used": False, "basket_status": "UNAVAILABLE_NO_SOURCE_BASKET_ID",
            "source_file": "source.csv", "source_sha256": sha(run_dir / "source.csv"),
            "unit_file": "units.csv", "unit_sha256": sha(run_dir / "units.csv"),
        }

    def run_manifest(self, run_dir: Path, row: dict[str, str], matrix_sha: str) -> dict:
        return {
            "schema": prejoin.RUN_SCHEMA, "status": prejoin.RUN_STATUS, "canonical_head": RUNTIME_HEAD,
            "cell_id": row["cell_id"], "symbol": row["symbol"], "tf": row["tf"], "window": row["window"],
            "from_date": row["from_date"], "to_date": row["to_date"], "model": 1,
            "holdout": "UNSPENT", "optimization": "NONE", "set_sha256": "b" * 64,
            "h3_manifest_sha256": matrix_sha, "build_receipt": "br-test", "build_receipt_registry_sha256": "c" * 64,
            "diagnostic_ex5_sha256": "d" * 64, "diagnostic_source_sha256": "e" * 64,
            "report_sha256": sha(run_dir / "report.htm"), "source_sha256": sha(run_dir / "source.csv"),
            "unit_sha256": sha(run_dir / "units.csv"), "report_trades": 1,
            "source_in_count": 1, "source_out_count": 1, "source_position_count": 1,
            "source_owned_position_count": 1, "realized_unit_count": 1, "open_position_count": 0,
            "configured_run_magic": 990001, "source_magic_values": [0, 990001],
            "source_magic_provenance": prejoin.MAGIC_PROVENANCE,
        }

    def update_json(self, path: Path, fn) -> dict:
        value = json.loads(path.read_text(encoding="utf-8"))
        fn(value)
        path.write_text(json.dumps(value), encoding="utf-8")
        return value

    def refresh_hashes(self, run_dir: Path) -> None:
        unit_path = run_dir / "unit_manifest.json"
        unit = json.loads(unit_path.read_text())
        unit["source_sha256"] = sha(run_dir / "source.csv")
        unit["unit_sha256"] = sha(run_dir / "units.csv")
        unit_path.write_text(json.dumps(unit), encoding="utf-8")
        run_path = run_dir / "run_manifest.json"
        run = json.loads(run_path.read_text())
        run["report_sha256"] = sha(run_dir / "report.htm")
        run["source_sha256"] = sha(run_dir / "source.csv")
        run["unit_sha256"] = sha(run_dir / "units.csv")
        run_path.write_text(json.dumps(run), encoding="utf-8")

    def make_package_fixture(self, root: Path):
        repo = root / "repo"; repo.mkdir()
        matrix = self.make_matrix(repo)
        (repo / "frozen.set").write_text("set\n", encoding="utf-8")
        source = repo / "ea_template" / "Probe_19_AdaptiveTrendGrid_P4BUnitExport.mq5"
        source.parent.mkdir(parents=True); source.write_text("source\n", encoding="utf-8")
        runner = repo / "scripts" / "research" / "boss19_p4b" / "run_unit_export_cell.ps1"
        runner.parent.mkdir(parents=True)
        units_path = repo / "aggregate_units.csv"
        with matrix.open("r", encoding="utf-8", newline="") as fh:
            matrix_rows = list(csv.DictReader(fh))
        unit_rows = [self.unit_row(r["cell_id"], r["symbol"], r["tf"], str(i+1)) for i,r in enumerate(matrix_rows)]
        self.write_units(units_path, unit_rows)
        expected = dict(prejoin.ACCEPTED)
        expected.update({
            "runtime_head": RUNTIME_HEAD, "h3_manifest_sha256": sha(matrix), "set_sha256": sha(repo / "frozen.set"),
            "diagnostic_source_sha256": sha(source), "diagnostic_ex5_sha256": "d"*64,
            "build_receipt": "br-test", "build_receipt_registry_sha256": "c"*64,
            "aggregate_units_sha256": sha(units_path),
        })
        runner.write_text("\n".join([
            f"$ExpectedManifestSha='{expected['h3_manifest_sha256']}'", f"$ExpectedSourceSha='{expected['diagnostic_source_sha256']}'",
            f"$ExpectedEx5Sha='{expected['diagnostic_ex5_sha256']}'", f"$ExpectedBuildReceipt='{expected['build_receipt']}'",
            f"$ExpectedReceiptRegistrySha='{expected['build_receipt_registry_sha256']}'", "-Model 1",
        ])+"\n", encoding="utf-8")
        cells=[]
        for i,r in enumerate(matrix_rows,1):
            cells.append({"cell_id":r["cell_id"],"index":i,"realized_unit_count":1,"report_trades":1,
                          "run_manifest_sha256":f"{i:064x}"[-64:],"report_sha256":"1"*64,"source_sha256":"2"*64,
                          "unit_sha256":"3"*64,"source_magic_nonmatch_count":0,"symbol":r["symbol"],"tf":r["tf"],"window":r["window"]})
        package={"schema_version":prejoin.PACKAGE_SCHEMA,"status":prejoin.PACKAGE_STATUS,"authority":prejoin.PACKAGE_AUTHORITY,
                 "canonical_head":RUNTIME_HEAD,"cell_count":36,"unique_cell_count":36,"configured_run_magic":990001,
                 "execution":"SERIAL_MODEL1_D_META5","h3_manifest_sha256":expected["h3_manifest_sha256"],"holdout":"UNSPENT",
                 "optimization":"NONE","linkage_basis":prejoin.LINKAGE,"open_position_count":0,"unknown_time_unit_count":0,
                 "aggregate_units_sha256":expected["aggregate_units_sha256"],"source_magic_values":[0,990001],
                 "source_magic_nonmatch_count":0,"realized_unit_count":36,"cells":cells}
        package_path=repo/"package.json"; package_path.write_text(json.dumps(package,sort_keys=True,indent=2)+"\n",encoding="utf-8")
        expected["package_sha256"]=sha(package_path)
        report=repo/"result.md"
        self.write_result_report(report, expected)
        return package_path, units_path, matrix, report, runner, expected

    def write_result_report(self, report: Path, expected: dict) -> None:
        report.write_text("\n".join([
            f"Runtime canonical head: `{expected['runtime_head']}`", f"Aggregate units SHA-256: `{expected['aggregate_units_sha256']}`.",
            f"Package manifest SHA-256: `{expected['package_sha256']}`.", f"H3 matrix SHA-256: `{expected['h3_manifest_sha256']}`.",
            f"Fixed set SHA-256: `{expected['set_sha256']}`.", f"Diagnostic source SHA-256: `{expected['diagnostic_source_sha256']}`.",
            f"Diagnostic EX5 SHA-256: `{expected['diagnostic_ex5_sha256']}`.", f"Build receipt: `{expected['build_receipt']}`.",
            "HOLDOUT `2026H1` remained UNSPENT and optimization remained NONE.",
        ])+"\n",encoding="utf-8")

    def test_valid_broad36_raw_mode_is_forensic_only(self):
        with tempfile.TemporaryDirectory() as td:
            evidence, matrix = self.make_fixture(Path(td))
            result = prejoin.validate(evidence, matrix, RUNTIME_HEAD)
            self.assertEqual(result["status"], "PASS_FORENSIC_RAW_EVIDENCE_VALIDATION")
            self.assertEqual(result["observed_cell_count"], 36)
            self.assertEqual(result["total_realized_units"], 36)
            self.assertFalse(result["prejoin_schema_ready"])
            self.assertFalse(result["canonical_prejoin_acceptance"])
            self.assertEqual(result["next_required_gate"], "VALIDATE_FROZEN_PACKAGE_MODE")
            self.assertTrue(result["package_review_required_before_regime_join"])
            self.assertIn("REGIME_INTERPRETATION", result["does_not_authorize"])

    def test_missing_cell_refuses(self):
        with tempfile.TemporaryDirectory() as td:
            evidence, matrix = self.make_fixture(Path(td))
            (evidence / "H3-C18-BWD" / "run_manifest.json").unlink()
            with self.assertRaisesRegex(prejoin.Refusal, "missing broad36 run manifests"):
                prejoin.validate(evidence, matrix, RUNTIME_HEAD)
    def test_unexpected_duplicate_manifest_refuses(self):
        with tempfile.TemporaryDirectory() as td:
            evidence, matrix = self.make_fixture(Path(td))
            extra = evidence / "alias"; extra.mkdir()
            (extra / "run_manifest.json").write_bytes((evidence / "H3-C01-MAIN" / "run_manifest.json").read_bytes())
            with self.assertRaisesRegex(prejoin.Refusal, "unexpected/duplicate"):
                prejoin.validate(evidence, matrix, RUNTIME_HEAD)

    def test_run_identity_and_authority_drift_refuses(self):
        for key, value, message in (("symbol", "WRONG", "symbol"), ("model", 4, "model"), ("holdout", "SPENT", "HOLDOUT"), ("optimization", "FAST", "optimization")):
            with self.subTest(key=key), tempfile.TemporaryDirectory() as td:
                evidence, matrix = self.make_fixture(Path(td)); p = evidence / "H3-C01-MAIN" / "run_manifest.json"
                self.update_json(p, lambda x, k=key, v=value: x.__setitem__(k, v))
                with self.assertRaisesRegex(prejoin.Refusal, message):
                    prejoin.validate(evidence, matrix, RUNTIME_HEAD)

    def test_report_source_or_unit_tamper_refuses(self):
        for filename, label in (("report.htm", "report"), ("source.csv", "source"), ("units.csv", "unit")):
            with self.subTest(filename=filename), tempfile.TemporaryDirectory() as td:
                evidence, matrix = self.make_fixture(Path(td)); p = evidence / "H3-C01-MAIN" / filename
                p.write_bytes(p.read_bytes() + b"tamper")
                with self.assertRaisesRegex(prejoin.Refusal, f"{label} hash mismatch"):
                    prejoin.validate(evidence, matrix, RUNTIME_HEAD)
    def test_unit_manifest_provenance_and_count_drifts_refuse(self):
        cases = (("linkage_basis", "HEURISTIC", "linkage"), ("source_magic_provenance", "INFERRED", "magic provenance"), ("unknown_time_unit_count", 1, "unknown-time"), ("realized_unit_count", 2, "count drift"))
        for key, value, message in cases:
            with self.subTest(key=key), tempfile.TemporaryDirectory() as td:
                evidence, matrix = self.make_fixture(Path(td)); p = evidence / "H3-C01-MAIN" / "unit_manifest.json"
                self.update_json(p, lambda x, k=key, v=value: x.__setitem__(k, v))
                with self.assertRaisesRegex(prejoin.Refusal, message):
                    prejoin.validate(evidence, matrix, RUNTIME_HEAD)

    def test_missing_entry_timestamp_refuses_after_hash_refresh(self):
        with tempfile.TemporaryDirectory() as td:
            evidence, matrix = self.make_fixture(Path(td)); run_dir = evidence / "H3-C01-MAIN"
            unit_path = run_dir / "units.csv"
            with unit_path.open("r", encoding="utf-8", newline="") as fh:
                rows = list(csv.DictReader(fh))
            rows[0]["entry_utc"] = ""
            self.write_units(unit_path, rows); self.refresh_hashes(run_dir)
            with self.assertRaisesRegex(prejoin.Refusal, "UTC timestamp missing"):
                prejoin.validate(evidence, matrix, RUNTIME_HEAD)

    def test_duplicate_join_key_refuses(self):
        with tempfile.TemporaryDirectory() as td:
            evidence, matrix = self.make_fixture(Path(td)); run_dir = evidence / "H3-C01-MAIN"
            row = self.unit_row("H3-C01-MAIN", "XAUUSD", "M15")
            self.write_units(run_dir / "units.csv", [row, dict(row)])
            self.update_json(run_dir / "unit_manifest.json", lambda x: x.update({"realized_unit_count": 2}))
            self.update_json(run_dir / "run_manifest.json", lambda x: x.update({"realized_unit_count": 2, "report_trades": 2}))
            self.refresh_hashes(run_dir)
            with self.assertRaisesRegex(prejoin.Refusal, "duplicate P4 join key"):
                prejoin.validate(evidence, matrix, RUNTIME_HEAD)

    def test_identity_consistency_refuses(self):
        with tempfile.TemporaryDirectory() as td:
            evidence, matrix = self.make_fixture(Path(td)); p = evidence / "H3-C02-MAIN" / "run_manifest.json"
            self.update_json(p, lambda x: x.__setitem__("build_receipt", "different-receipt"))
            with self.assertRaisesRegex(prejoin.Refusal, "identity inconsistent: build_receipt"):
                prejoin.validate(evidence, matrix, RUNTIME_HEAD)

    def test_same_inputs_are_deterministic(self):
        with tempfile.TemporaryDirectory() as td:
            evidence, matrix = self.make_fixture(Path(td))
            a = prejoin.validate(evidence, matrix, RUNTIME_HEAD)
            b = prejoin.validate(evidence, matrix, RUNTIME_HEAD)
            self.assertEqual(json.dumps(a, sort_keys=True), json.dumps(b, sort_keys=True))

    def test_valid_frozen_package_is_prejoin_ready(self):
        with tempfile.TemporaryDirectory() as td:
            pkg, units, matrix, report, runner, expected = self.make_package_fixture(Path(td))
            result = prejoin.validate_frozen_package(pkg, units, matrix, report, runner, expected)
            self.assertEqual(result["status"], "PASS_FROZEN_PACKAGE_PREJOIN_READINESS")
            self.assertEqual(result["observed_cell_count"], 36)
            self.assertEqual(result["unique_deal_join_key_count"], 36)
            self.assertFalse(result["raw_cell_manifest_bytes_tracked"])
            self.assertTrue(result["package_review_required_before_regime_join"])

    def test_frozen_package_or_units_tamper_refuses(self):
        for target, message in (("package", "frozen package SHA drift"), ("units", "aggregate units SHA drift")):
            with self.subTest(target=target), tempfile.TemporaryDirectory() as td:
                pkg, units, matrix, report, runner, expected = self.make_package_fixture(Path(td))
                p = pkg if target == "package" else units
                p.write_bytes(p.read_bytes() + b"tamper")
                with self.assertRaisesRegex(prejoin.Refusal, message):
                    prejoin.validate_frozen_package(pkg, units, matrix, report, runner, expected)

    def test_frozen_package_scope_or_authority_drift_refuses(self):
        for key, value, message in (("cell_count",35,"cell_count"),("holdout","SPENT","holdout"),("optimization","FAST","optimization")):
            with self.subTest(key=key), tempfile.TemporaryDirectory() as td:
                pkg, units, matrix, report, runner, expected = self.make_package_fixture(Path(td))
                data=json.loads(pkg.read_text()); data[key]=value
                pkg.write_text(json.dumps(data,sort_keys=True,indent=2)+"\n", encoding="utf-8")
                expected["package_sha256"]=sha(pkg); self.write_result_report(report, expected)
                with self.assertRaisesRegex(prejoin.Refusal, message):
                    prejoin.validate_frozen_package(pkg, units, matrix, report, runner, expected)

    def test_frozen_package_join_key_or_time_drift_refuses(self):
        for kind, message in (("duplicate","duplicate P4 join key"),("time","aggregate UTC timestamp missing")):
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as td:
                pkg, units, matrix, report, runner, expected = self.make_package_fixture(Path(td))
                with units.open("r",encoding="utf-8",newline="") as fh:
                    rows=list(csv.DictReader(fh))
                if kind=="duplicate":
                    rows[1]["h3_run_id"]=rows[0]["h3_run_id"]; rows[1]["source_deal_id"]=rows[0]["source_deal_id"]
                    rows[1]["symbol"]=rows[0]["symbol"]; rows[1]["period_name"]=rows[0]["period_name"]
                else:
                    rows[0]["entry_utc"]=""
                self.write_units(units,rows); expected["aggregate_units_sha256"]=sha(units)
                data=json.loads(pkg.read_text()); data["aggregate_units_sha256"]=expected["aggregate_units_sha256"]
                pkg.write_text(json.dumps(data,sort_keys=True,indent=2)+"\n", encoding="utf-8")
                expected["package_sha256"]=sha(pkg); self.write_result_report(report, expected)
                with self.assertRaisesRegex(prejoin.Refusal, message):
                    prejoin.validate_frozen_package(pkg,units,matrix,report,runner,expected)

    def test_result_report_or_runner_pin_drift_refuses(self):
        for target, message in (("report","result-report"),("runner","runner pin drift")):
            with self.subTest(target=target), tempfile.TemporaryDirectory() as td:
                pkg, units, matrix, report, runner, expected = self.make_package_fixture(Path(td))
                p=report if target=="report" else runner
                p.write_text(p.read_text().replace(expected["build_receipt"],"wrong"),encoding="utf-8")
                with self.assertRaisesRegex(prejoin.Refusal, message):
                    prejoin.validate_frozen_package(pkg,units,matrix,report,runner,expected)


if __name__ == "__main__":
    unittest.main()
