import argparse
import json
import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from module import (  # noqa: E402
    AUTHORITY,
    EXPECTED_ZIPLIME_VERSION,
    ModuleError,
    evaluate_environment,
    prepare_dataset,
    verify_dataset,
)


class ZiplimeModuleTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        self.source = self.root / "bars.csv"
        self.column_map = self.root / "column_map.json"
        self.out = self.root / "out"
        self.source.write_text(
            "Time,O,H,L,C,V\n"
            "2026-01-01T00:00:00Z,100,110,90,105,10\n"
            "2026-01-01T04:00:00Z,105,112,101,108,12\n",
            encoding="utf-8",
        )
        self.write_map()

    def tearDown(self):
        self.tmp.cleanup()

    def write_map(self, columns=None):
        if columns is None:
            columns = {
                "timestamp": "Time",
                "open": "O",
                "high": "H",
                "low": "L",
                "close": "C",
                "volume": "V",
            }
        self.column_map.write_text(
            json.dumps({"timezone": "UTC", "columns": columns}, sort_keys=True),
            encoding="utf-8",
        )

    def args(self, output=None, symbol="BTCUSD", tf="H4"):
        return argparse.Namespace(
            input=str(self.source),
            column_map=str(self.column_map),
            output_dir=str(output or self.out),
            source_commit="a" * 40,
            concept="SuperTrendFlip",
            logical_symbol=symbol,
            execution_tf=tf,
            home_contract_id="STF-BTCUSD-H4",
            window_contract_id="W-2026Q1",
            profile_id="BASELINE",
            parameter_set_id="P0",
            run_id="RUN-001",
        )

    def verify_args(self, output=None):
        return argparse.Namespace(
            output_dir=str(output or self.out),
            source=str(self.source),
            column_map=str(self.column_map),
        )

    def test_prepare_and_verify_positive(self):
        manifest = prepare_dataset(self.args())
        self.assertEqual(AUTHORITY, manifest["authority"])
        self.assertEqual(2, manifest["row_count"])
        verified = verify_dataset(self.verify_args())
        self.assertEqual("RUN-001", verified["run_id"])

    def test_reproducibility_is_byte_identical(self):
        out1 = self.root / "out1"
        out2 = self.root / "out2"
        prepare_dataset(self.args(out1))
        prepare_dataset(self.args(out2))
        for name in ("normalized_dataset.csv", "dataset_manifest.json"):
            self.assertEqual((out1 / name).read_bytes(), (out2 / name).read_bytes())

    def test_wrong_symbol_fails_visible(self):
        with self.assertRaisesRegex(ModuleError, "OUTSIDE_VALIDATED_CONTRACT"):
            prepare_dataset(self.args(symbol="ETHUSD"))

    def test_wrong_timeframe_fails_visible(self):
        with self.assertRaisesRegex(ModuleError, "OUTSIDE_VALIDATED_CONTRACT"):
            prepare_dataset(self.args(tf="M15"))

    def test_missing_explicit_column_map_field_fails(self):
        self.write_map({
            "timestamp": "Time", "open": "O", "high": "H",
            "low": "L", "close": "C",
        })
        with self.assertRaisesRegex(ModuleError, "missing explicit fields: volume"):
            prepare_dataset(self.args())

    def test_missing_source_header_fails(self):
        self.source.write_text("Time,O,H,L,C\n2026-01-01T00:00:00Z,1,2,0,1\n", encoding="utf-8")
        with self.assertRaisesRegex(ModuleError, "missing mapped columns"):
            prepare_dataset(self.args())

    def test_bad_ohlc_fails(self):
        self.source.write_text(
            "Time,O,H,L,C,V\n2026-01-01T00:00:00Z,100,99,90,105,10\n",
            encoding="utf-8",
        )
        with self.assertRaisesRegex(ModuleError, "high violates OHLC"):
            prepare_dataset(self.args())

    def test_negative_volume_fails(self):
        self.source.write_text(
            "Time,O,H,L,C,V\n2026-01-01T00:00:00Z,100,110,90,105,-1\n",
            encoding="utf-8",
        )
        with self.assertRaisesRegex(ModuleError, "volume must be non-negative"):
            prepare_dataset(self.args())

    def test_duplicate_timestamp_fails(self):
        self.source.write_text(
            "Time,O,H,L,C,V\n"
            "2026-01-01T00:00:00Z,100,110,90,105,10\n"
            "2026-01-01T00:00:00Z,105,112,101,108,12\n",
            encoding="utf-8",
        )
        with self.assertRaisesRegex(ModuleError, "strictly increasing"):
            prepare_dataset(self.args())

    def test_non_monotonic_timestamp_fails(self):
        self.source.write_text(
            "Time,O,H,L,C,V\n"
            "2026-01-01T04:00:00Z,100,110,90,105,10\n"
            "2026-01-01T00:00:00Z,105,112,101,108,12\n",
            encoding="utf-8",
        )
        with self.assertRaisesRegex(ModuleError, "strictly increasing"):
            prepare_dataset(self.args())

    def test_normalized_tamper_is_detected(self):
        prepare_dataset(self.args())
        normalized = self.out / "normalized_dataset.csv"
        normalized.write_text(normalized.read_text(encoding="utf-8") + "x", encoding="utf-8")
        with self.assertRaisesRegex(ModuleError, "artifact hash mismatch"):
            verify_dataset(self.verify_args())

    def test_source_tamper_is_detected(self):
        prepare_dataset(self.args())
        self.source.write_text(self.source.read_text(encoding="utf-8") + "\n", encoding="utf-8")
        with self.assertRaisesRegex(ModuleError, "source_sha256"):
            verify_dataset(self.verify_args())

    def test_manifest_authority_tamper_is_detected(self):
        prepare_dataset(self.args())
        path = self.out / "dataset_manifest.json"
        payload = json.loads(path.read_text(encoding="utf-8"))
        payload["authority"] = "CANDIDATE_AUTHORITY"
        path.write_text(json.dumps(payload), encoding="utf-8")
        with self.assertRaisesRegex(ModuleError, "authority mismatch"):
            verify_dataset(self.verify_args())

    def test_bad_source_commit_fails(self):
        args = self.args()
        args.source_commit = "ABC"
        with self.assertRaisesRegex(ModuleError, "source_commit"):
            prepare_dataset(args)

    def test_runtime_contract(self):
        ok = evaluate_environment((3, 12), EXPECTED_ZIPLIME_VERSION)
        self.assertTrue(ok["ok"])
        self.assertFalse(evaluate_environment((3, 11), EXPECTED_ZIPLIME_VERSION)["ok"])
        self.assertFalse(evaluate_environment((3, 14), EXPECTED_ZIPLIME_VERSION)["ok"])
        self.assertFalse(evaluate_environment((3, 12), "0.0.0")["ok"])
        self.assertFalse(evaluate_environment((3, 12), None)["ok"])


if __name__ == "__main__":
    unittest.main()
