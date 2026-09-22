from __future__ import annotations

import csv
import json
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

from tools.news_macro_lab import macrogate_native as m


class Fixture:
    def __init__(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        self.timeline = self.root / "timeline.csv"
        self.manifest = self.root / "manifest.json"
        self._write_repo()
        self.rows = [
            self.row("2025-03-08T00:00:00Z", "2025-03-09T00:00:00Z", "RISK_OFF", "2025-03-08T00:00:00Z", "2025-03-07", "-0.500"),
            self.row("2025-03-09T00:00:00Z", "2025-03-10T00:00:00Z", "STRESS", "2025-03-09T00:00:00Z", "2025-03-08", "-1.200"),
            self.row("2025-03-10T00:00:00Z", "2025-03-11T00:00:00Z", "RISK_ON", "2025-03-10T00:00:00Z", "2025-03-09", "0.600"),
        ]
        self.write_data()

    @staticmethod
    def row(start, end, state, asof, source_date, ri):
        return {
            "valid_from_utc": start,
            "valid_to_utc": end,
            "macro_state": state,
            "macro_as_of_utc": asof,
            "macro_source_date": source_date,
            "macro_ri": ri,
            "macro_confidence": "HIGH",
            "macro_coverage": "8/8",
            "macro_missing_inputs": "",
            "macro_partial": "false",
            "macro_flags": "",
        }

    def _write(self, rel, text):
        p = self.repo / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding="utf-8", newline="\n")
        return p

    def _write_repo(self):
        core = self._write(
            "ea_template/core/MacroGate_Core.mqh",
            'if(st == MG_ST_UNKNOWN) { skipped++; continue; }\n'
            'if(mg_rowTime[i] <= nowServer) idx = i;\n'
            'if(mg_rowStaleMaxHours > 0 && rowAgeH > (double)mg_rowStaleMaxHours)\n',
        )
        lab = self._write(
            "ea_template/core/LabCore.mqh",
            "MG_Setup(_MG_LotMult, _MG_BlockNew, _MG_TriggerRiskOff, _MG_OffsetHours, 8760, 168);\n",
        )
        clock = self._write("docs/research/HISTORICAL_BROKER_CLOCK_CONTRACT_20260907.md", "clock\n")
        norm = self._write("tools/P4BMarketDataExporter/normalize_ohlc.py", "normalizer\n")
        self.old_hashes = (
            m.EXPECTED_MACRO_CORE_SHA,
            m.EXPECTED_LABCORE_SHA,
            m.EXPECTED_CLOCK_CONTRACT_SHA,
            m.EXPECTED_NORMALIZER_SHA,
        )
        m.EXPECTED_MACRO_CORE_SHA = m.sha256_file(core)
        m.EXPECTED_LABCORE_SHA = m.sha256_file(lab)
        m.EXPECTED_CLOCK_CONTRACT_SHA = m.sha256_file(clock)
        m.EXPECTED_NORMALIZER_SHA = m.sha256_file(norm)

    def write_data(self):
        fields = list(self.rows[0])
        with self.timeline.open("w", encoding="utf-8", newline="") as handle:
            w = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
            w.writeheader()
            w.writerows(self.rows)
        old_t, old_m = m.EXPECTED_CAUSAL_TIMELINE_SHA, m.EXPECTED_CAUSAL_MANIFEST_SHA
        self.old_data_hashes = (old_t, old_m)
        m.EXPECTED_CAUSAL_TIMELINE_SHA = m.sha256_file(self.timeline)
        meta = {
            "schema_version": "ea_lab_macrogate_causal_replay_extract/1",
            "classification": "CAUSAL_MACRO_REPLAY_RESEARCH_ONLY",
            "timeline_sha256": m.EXPECTED_CAUSAL_TIMELINE_SHA,
            "macro_interval_count": len(self.rows),
            "can_execute": False,
            "performance": "NOT_RUN",
        }
        self.manifest.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
        m.EXPECTED_CAUSAL_MANIFEST_SHA = m.sha256_file(self.manifest)

    def close(self):
        (
            m.EXPECTED_MACRO_CORE_SHA,
            m.EXPECTED_LABCORE_SHA,
            m.EXPECTED_CLOCK_CONTRACT_SHA,
            m.EXPECTED_NORMALIZER_SHA,
        ) = self.old_hashes
        m.EXPECTED_CAUSAL_TIMELINE_SHA, m.EXPECTED_CAUSAL_MANIFEST_SHA = self.old_data_hashes
        self.tmp.cleanup()
class MacroNativeTests(unittest.TestCase):
    def setUp(self):
        self.fx = Fixture()

    def tearDown(self):
        self.fx.close()

    def test_transition_calendar_matches_contract(self):
        self.assertEqual(m.nth_sunday(2025, 3, 2).isoformat(), "2025-03-09")
        self.assertEqual(m.nth_sunday(2025, 11, 1).isoformat(), "2025-11-02")
        self.assertTrue(m.is_transition_server_date(m.nth_sunday(2025, 3, 2)))
        self.assertTrue(m.is_transition_server_date(m.nth_sunday(2025, 11, 1)))

    def test_stable_offsets(self):
        self.assertEqual(m.server_offset_hours_for_date(datetime(2025, 1, 15).date()), 2)
        self.assertEqual(m.server_offset_hours_for_date(datetime(2025, 7, 15).date()), 3)

    def test_transition_offset_refused(self):
        with self.assertRaisesRegex(m.Refused, "UNKNOWN_DST_TRANSITION"):
            m.server_offset_hours_for_date(datetime(2025, 3, 9).date())

    def test_clock_roundtrip_stable(self):
        source = datetime(2025, 7, 15, 0, 0, tzinfo=timezone.utc)
        server, offset = m.utc_to_server(source)
        self.assertEqual(offset, 3)
        self.assertEqual(m.server_to_utc(server), source)

    def test_transition_utc_mapping_refused(self):
        with self.assertRaisesRegex(m.Refused, "UTC_TO_SERVER_UNRESOLVED"):
            m.utc_to_server(datetime(2025, 3, 9, 0, 0, tzinfo=timezone.utc))

    def test_native_candidate_exposes_transition_hazard(self):
        result = m.build_native_candidate(self.fx.timeline, self.fx.manifest, self.fx.repo)
        self.assertEqual(result["stable_native_row_count"], 2)
        self.assertEqual(result["quarantine_row_count"], 1)
        self.assertFalse(result["native_parity_qualified"])
        self.assertEqual(result["blocker"], "CORE_SEAM_REQUIRED_UNKNOWN_TRANSITION_CANNOT_CLEAR_GATE")
        hazard = result["quarantine_hazards"][0]
        self.assertEqual(hazard["current_core_asof_state"], "RISK_OFF")
        self.assertEqual(hazard["expected_state"], "UNKNOWN_DST_TRANSITION")
        self.assertLess(hazard["current_core_row_age_hours"], 168)

    def test_transition_state_not_relabelled_neutral(self):
        result = m.build_native_candidate(self.fx.timeline, self.fx.manifest, self.fx.repo)
        self.assertEqual(result["quarantine_rows"][0]["state"], "STRESS")
        self.assertNotIn("NEUTRAL", [r["state"] for r in result["native_candidate_rows"]])
        self.assertEqual(result["quarantine_state_value_mismatch_count"], 1)
        self.assertEqual(result["quarantine_trigger_behavior_mismatch_count"], 0)

    def test_transition_trigger_behavior_mismatch_counted(self):
        self.fx.rows[1]["macro_state"] = "RISK_ON"
        self.fx.rows[1]["macro_ri"] = "0.800"
        self.fx.write_data()
        result = m.build_native_candidate(self.fx.timeline, self.fx.manifest, self.fx.repo)
        self.assertEqual(result["quarantine_trigger_behavior_mismatch_count"], 1)

    def test_source_unknown_also_blocks_native_parity(self):
        self.fx.rows[0]["macro_state"] = "UNKNOWN"
        self.fx.rows[0]["macro_as_of_utc"] = ""
        self.fx.rows[0]["macro_source_date"] = ""
        self.fx.write_data()
        result = m.build_native_candidate(self.fx.timeline, self.fx.manifest, self.fx.repo)
        self.assertFalse(result["native_parity_qualified"])
        self.assertTrue(any(q["reason"] == "SOURCE_UNKNOWN" for q in result["quarantine_rows"]))
    def test_causal_gap_refused(self):
        self.fx.rows[1]["valid_from_utc"] = "2025-03-09T00:01:00Z"
        self.fx.write_data()
        with self.assertRaisesRegex(m.Refused, "CAUSAL_INTERVAL_GAP_OR_OVERLAP"):
            m.build_native_candidate(self.fx.timeline, self.fx.manifest, self.fx.repo)

    def test_future_asof_refused(self):
        self.fx.rows[0]["macro_as_of_utc"] = "2025-03-08T00:00:01Z"
        self.fx.write_data()
        with self.assertRaisesRegex(m.Refused, "CAUSAL_VISIBLE_BEFORE_ASOF"):
            m.build_native_candidate(self.fx.timeline, self.fx.manifest, self.fx.repo)

    def test_core_semantic_drift_refused(self):
        p = self.fx.repo / "ea_template/core/MacroGate_Core.mqh"
        p.write_text("changed\n", encoding="utf-8")
        m.EXPECTED_MACRO_CORE_SHA = m.sha256_file(p)
        with self.assertRaisesRegex(m.Refused, "MACRO_CORE_SEMANTICS_DRIFT"):
            m.build_native_candidate(self.fx.timeline, self.fx.manifest, self.fx.repo)

    def test_upstream_authority_expansion_refused(self):
        data = json.loads(self.fx.manifest.read_text(encoding="utf-8"))
        data["performance"] = "PASS"
        self.fx.manifest.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        m.EXPECTED_CAUSAL_MANIFEST_SHA = m.sha256_file(self.fx.manifest)
        with self.assertRaisesRegex(m.Refused, "UPSTREAM_AUTHORITY_EXPANDED"):
            m.build_native_candidate(self.fx.timeline, self.fx.manifest, self.fx.repo)

    def test_hash_mismatch_refused(self):
        m.EXPECTED_CAUSAL_TIMELINE_SHA = "0" * 64
        with self.assertRaisesRegex(m.Refused, "CAUSAL_TIMELINE_HASH_MISMATCH"):
            m.build_native_candidate(self.fx.timeline, self.fx.manifest, self.fx.repo)

    def test_output_is_nonexecuting(self):
        result = m.build_native_candidate(self.fx.timeline, self.fx.manifest, self.fx.repo)
        self.assertFalse(result["can_execute"])
        self.assertEqual(result["performance"], "NOT_RUN")
        self.assertFalse(result["holdout_used"])
        self.assertIsNone(result["probability"])

    def test_write_artifacts_deterministic(self):
        result = m.build_native_candidate(self.fx.timeline, self.fx.manifest, self.fx.repo)
        a = m.write_artifacts(result, self.fx.root / "a")
        b = m.write_artifacts(result, self.fx.root / "b")
        self.assertEqual(a["manifest_sha256"], b["manifest_sha256"])
        self.assertEqual(a["native_candidate_sha256"], b["native_candidate_sha256"])
        self.assertEqual(a["quarantine_sha256"], b["quarantine_sha256"])


if __name__ == "__main__":
    unittest.main()
