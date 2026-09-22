from __future__ import annotations

import csv
import json
import tempfile
import unittest
from pathlib import Path

from tools.news_macro_lab.macrogate_replay import (
    CLASSIFIER_ID, CLASSIFIER_VERSION, EXPECTED_FIELDS, Refused,
    extract_macro_replay, sha256_file, write_artifacts,
)


def macro(state, asof, source_date, ri="0.600", conf="HIGH"):
    return {
        "macro_state": state,
        "macro_as_of_utc": asof,
        "macro_source_date": source_date,
        "macro_ri": ri,
        "macro_confidence": conf,
        "macro_coverage": "8/8",
        "macro_missing_inputs": "",
        "macro_partial": "false",
        "macro_flags": "",
    }


def row(symbol, tf, start, end, values):
    out = {
        "valid_from_utc": start,
        "valid_to_utc": end,
        "symbol": symbol,
        "tf": tf,
        "classifier_id": CLASSIFIER_ID,
        "classifier_version": CLASSIFIER_VERSION,
    }
    out.update(values)
    return out
class ReplayFixture:
    def __init__(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.timeline = self.root / "classifier_timeline.csv"
        self.manifest = self.root / "classifier_timeline_manifest.json"
        a = macro("RISK_ON", "2025-01-02T00:00:00Z", "2025-01-01")
        b = macro("RISK_OFF", "2025-01-03T00:00:00Z", "2025-01-02", "-0.500", "MED")
        self.rows = []
        for symbol, tf in [("XAUUSD", "H1"), ("EURUSD", "H1")]:
            self.rows += [
                row(symbol, tf, "2025-01-02T00:00:00Z", "2025-01-02T12:00:00Z", a),
                row(symbol, tf, "2025-01-02T12:00:00Z", "2025-01-03T00:00:00Z", a),
                row(symbol, tf, "2025-01-03T00:00:00Z", "2025-01-04T00:00:00Z", b),
            ]
        self.macro_manifest_sha = "a" * 64
        self.write()

    def write(self):
        with self.timeline.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=EXPECTED_FIELDS, lineterminator="\n")
            writer.writeheader()
            writer.writerows(self.rows)
        timeline_sha = sha256_file(self.timeline)
        manifest = {
            "schema_version": "BOSS19_P4_CLASSIFIER_TIMELINE_MANIFEST_V1",
            "classifier_id": CLASSIFIER_ID,
            "classifier_version": CLASSIFIER_VERSION,
            "timeline_sha256": timeline_sha,
            "macro_manifest_sha256": self.macro_manifest_sha,
            "first_timestamp": "2025-01-02T00:00:00Z",
            "last_timestamp": "2025-01-04T00:00:00Z",
            "row_count": len(self.rows),
            "h3_outcome_content_opened": False,
            "holdout_included": False,
            "cell_coverage": [
                {"symbol": "XAUUSD", "tf": "H1"},
                {"symbol": "EURUSD", "tf": "H1"},
            ],
        }
        self.manifest.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        self.timeline_sha = timeline_sha
        self.manifest_sha = sha256_file(self.manifest)

    def call(self):
        return extract_macro_replay(
            self.timeline, self.manifest,
            expected_timeline_sha256=self.timeline_sha,
            expected_manifest_sha256=self.manifest_sha,
            expected_macro_manifest_sha256=self.macro_manifest_sha,
        )

    def close(self):
        self.temp.cleanup()
class MacroReplayTests(unittest.TestCase):
    def setUp(self):
        self.fx = ReplayFixture()

    def tearDown(self):
        self.fx.close()

    def test_extracts_cell_independent_macro_intervals(self):
        result = self.fx.call()
        self.assertEqual(result["source_cell_count_verified"], 2)
        self.assertEqual(result["source_row_count_verified"], 6)
        self.assertEqual(result["macro_interval_count"], 2)
        self.assertEqual(result["intervals"][0]["macro_state"], "RISK_ON")
        self.assertEqual(result["intervals"][1]["macro_state"], "RISK_OFF")

    def test_probability_is_not_fabricated(self):
        result = self.fx.call()
        self.assertIsNone(result["probability"])
        self.assertEqual(
            result["confidence_semantics"],
            "MRIS_AGREEMENT_NOT_CALIBRATED_PROBABILITY",
        )
        self.assertFalse(result["can_execute"])
        self.assertEqual(result["performance"], "NOT_RUN")

    def test_cell_macro_disagreement_refused(self):
        self.fx.rows[-1]["macro_state"] = "NEUTRAL"
        self.fx.write()
        with self.assertRaisesRegex(Refused, "CELL_MACRO_SEQUENCE_MISMATCH"):
            self.fx.call()

    def test_interval_gap_refused(self):
        self.fx.rows[1]["valid_from_utc"] = "2025-01-02T12:01:00Z"
        self.fx.write()
        with self.assertRaisesRegex(Refused, "CELL_INTERVAL_GAP_OR_OVERLAP"):
            self.fx.call()

    def test_future_macro_asof_refused(self):
        self.fx.rows[0]["macro_as_of_utc"] = "2025-01-02T00:00:01Z"
        self.fx.write()
        with self.assertRaisesRegex(Refused, "MACRO_VISIBLE_BEFORE_ASOF"):
            self.fx.call()

    def test_non_d_plus_one_rule_refused(self):
        for item in self.fx.rows:
            if item["macro_source_date"] == "2025-01-01":
                item["macro_as_of_utc"] = "2025-01-01T23:59:59Z"
        self.fx.write()
        with self.assertRaisesRegex(Refused, "NONCAUSAL_D_PLUS_ONE_RULE"):
            self.fx.call()
    def test_unknown_state_refused(self):
        self.fx.rows[0]["macro_state"] = "BULLISH"
        self.fx.write()
        with self.assertRaisesRegex(Refused, "UNKNOWN_MACRO_STATE"):
            self.fx.call()

    def test_timeline_hash_mismatch_refused(self):
        with self.assertRaisesRegex(Refused, "TIMELINE_HASH_MISMATCH"):
            extract_macro_replay(
                self.fx.timeline, self.fx.manifest,
                expected_timeline_sha256="b" * 64,
                expected_manifest_sha256=self.fx.manifest_sha,
                expected_macro_manifest_sha256=self.fx.macro_manifest_sha,
            )

    def test_manifest_hash_mismatch_refused(self):
        with self.assertRaisesRegex(Refused, "TIMELINE_MANIFEST_HASH_MISMATCH"):
            extract_macro_replay(
                self.fx.timeline, self.fx.manifest,
                expected_timeline_sha256=self.fx.timeline_sha,
                expected_manifest_sha256="b" * 64,
                expected_macro_manifest_sha256=self.fx.macro_manifest_sha,
            )

    def test_macro_manifest_binding_mismatch_refused(self):
        with self.assertRaisesRegex(Refused, "MACRO_MANIFEST_BINDING_MISMATCH"):
            extract_macro_replay(
                self.fx.timeline, self.fx.manifest,
                expected_timeline_sha256=self.fx.timeline_sha,
                expected_manifest_sha256=self.fx.manifest_sha,
                expected_macro_manifest_sha256="b" * 64,
            )

    def test_holdout_upstream_refused(self):
        data = json.loads(self.fx.manifest.read_text(encoding="utf-8"))
        data["holdout_included"] = True
        self.fx.manifest.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        self.fx.manifest_sha = sha256_file(self.fx.manifest)
        with self.assertRaisesRegex(Refused, "UPSTREAM_AUTHORITY_MISMATCH"):
            self.fx.call()

    def test_outcome_opened_upstream_refused(self):
        data = json.loads(self.fx.manifest.read_text(encoding="utf-8"))
        data["h3_outcome_content_opened"] = True
        self.fx.manifest.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        self.fx.manifest_sha = sha256_file(self.fx.manifest)
        with self.assertRaisesRegex(Refused, "UPSTREAM_AUTHORITY_MISMATCH"):
            self.fx.call()
    def test_missing_cell_refused(self):
        self.fx.rows = self.fx.rows[:3]
        self.fx.write()
        data = json.loads(self.fx.manifest.read_text(encoding="utf-8"))
        data["cell_coverage"] = [
            {"symbol": "XAUUSD", "tf": "H1"},
            {"symbol": "EURUSD", "tf": "H1"},
        ]
        self.fx.manifest.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        self.fx.manifest_sha = sha256_file(self.fx.manifest)
        with self.assertRaisesRegex(Refused, "TIMELINE_CELL_ORDER_OR_SET_MISMATCH"):
            self.fx.call()

    def test_write_artifacts_is_deterministic(self):
        result = self.fx.call()
        out1 = self.fx.root / "out1"
        out2 = self.fx.root / "out2"
        a = write_artifacts(result, out1)
        b = write_artifacts(result, out2)
        self.assertEqual(a["timeline_sha256"], b["timeline_sha256"])
        self.assertEqual(a["manifest_sha256"], b["manifest_sha256"])

    def test_output_last_interval_uses_manifest_end(self):
        result = self.fx.call()
        self.assertEqual(result["intervals"][-1]["valid_to_utc"], "2025-01-04T00:00:00Z")

    def test_legacy_timeline_remains_blocked(self):
        result = self.fx.call()
        self.assertEqual(
            result["legacy_mris_backtest_timeline"],
            "BLOCKED_FOR_NEW_CAUSAL_INTRADAY_CLAIMS",
        )


if __name__ == "__main__":
    unittest.main()
