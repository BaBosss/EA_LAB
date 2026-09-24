from __future__ import annotations

import csv
import json
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
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
        self.old_hashes = (
            m.EXPECTED_CAUSAL_TIMELINE_SHA,
            m.EXPECTED_CAUSAL_MANIFEST_SHA,
            m.EXPECTED_MACRO_CORE_SHA,
            m.EXPECTED_LABCORE_SHA,
            m.EXPECTED_CLOCK_CONTRACT_SHA,
            m.EXPECTED_NORMALIZER_SHA,
        )
        self._write_repo()
        self.rows = [
            self.row(
                "2025-03-08T00:00:00Z",
                "2025-03-09T00:00:00Z",
                "RISK_OFF",
                "2025-03-08T00:00:00Z",
                "2025-03-07",
                "-0.500",
                "PRIOR_FLAG",
            ),
            self.row(
                "2025-03-09T00:00:00Z",
                "2025-03-10T00:00:00Z",
                "STRESS",
                "2025-03-09T00:00:00Z",
                "2025-03-08",
                "-1.200",
                "VIX_STRESS",
            ),
            self.row(
                "2025-03-10T00:00:00Z",
                "2025-03-11T00:00:00Z",
                "RISK_ON",
                "2025-03-10T00:00:00Z",
                "2025-03-09",
                "0.600",
            ),
        ]
        self.write_data()

    @staticmethod
    def row(start, end, state, asof, source_date, ri, flags=""):
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
            "macro_flags": flags,
        }

    def _write(self, rel, text):
        path = self.repo / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8", newline="\n")
        return path

    def _write_repo(self):
        core = self._write(
            "ea_template/core/MacroGate_Core.mqh",
            '#define MG_ST_UNKNOWN  (-99)\n'
            '#define MG_ST_INVALID  (-100)\n'
            'if(s == "UNKNOWN")  return MG_ST_UNKNOWN;\n'
            'return MG_ST_INVALID;\n'
            'if(st == MG_ST_INVALID) { skipped++; continue; }\n'
            'if(st == MG_ST_UNKNOWN && !MQLInfoInteger(MQL_TESTER)) { skipped++; continue; }\n'
            'if(mg_rowTime[i] <= nowServer) idx = i;\n'
            'if(GlobalVariableCheck(bgv)) GlobalVariableDel(bgv);\n'
            'if(GlobalVariableCheck(lgv)) GlobalVariableDel(lgv);\n'
            'if(st == MG_ST_UNKNOWN)\n'
            'MG_ClearAll("explicit UNKNOWN quarantine marker");\n'
            'bool trig = MG_StateTriggers(st);\n',
        )
        lab = self._write(
            "ea_template/core/LabCore.mqh",
            "MG_Setup(_MG_LotMult, _MG_BlockNew, _MG_TriggerRiskOff, _MG_OffsetHours, 8760, 168);\n",
        )
        clock = self._write("docs/research/HISTORICAL_BROKER_CLOCK_CONTRACT_20260907.md", "clock\n")
        normalizer = self._write("tools/P4BMarketDataExporter/normalize_ohlc.py", "normalizer\n")
        self._write("tools/news_macro_lab/macrogate_native.py", "exporter fixture\n")
        self._write("tools/news_macro_lab/tests/test_macrogate_native.py", "tests fixture\n")
        m.EXPECTED_MACRO_CORE_SHA = m.sha256_file(core)
        m.EXPECTED_LABCORE_SHA = m.sha256_file(lab)
        m.EXPECTED_CLOCK_CONTRACT_SHA = m.sha256_file(clock)
        m.EXPECTED_NORMALIZER_SHA = m.sha256_file(normalizer)

    def write_data(self):
        fields = list(self.rows[0])
        with self.timeline.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
            writer.writeheader()
            writer.writerows(self.rows)
        m.EXPECTED_CAUSAL_TIMELINE_SHA = m.sha256_file(self.timeline)
        meta = {
            "schema_version": "ea_lab_macrogate_causal_replay_extract/1",
            "classification": "CAUSAL_MACRO_REPLAY_RESEARCH_ONLY",
            "timeline_sha256": m.EXPECTED_CAUSAL_TIMELINE_SHA,
            "macro_interval_count": len(self.rows),
            "first_timestamp": self.rows[0]["valid_from_utc"],
            "last_timestamp": self.rows[-1]["valid_to_utc"],
            "can_execute": False,
            "performance": "NOT_RUN",
            "probability": None,
        }
        self.manifest.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
        m.EXPECTED_CAUSAL_MANIFEST_SHA = m.sha256_file(self.manifest)

    def use_full_frozen_window(self):
        rows = []
        current = datetime(2020, 1, 1, tzinfo=timezone.utc)
        end = datetime(2026, 1, 1, tzinfo=timezone.utc)
        while current < end:
            next_day = current + timedelta(days=1)
            day = current.date().isoformat()
            state = "RISK_OFF" if day in {"2024-11-03", "2024-11-04"} else "NEUTRAL"
            rows.append(
                self.row(
                    current.strftime("%Y-%m-%dT%H:%M:%SZ"),
                    next_day.strftime("%Y-%m-%dT%H:%M:%SZ"),
                    state,
                    current.strftime("%Y-%m-%dT%H:%M:%SZ"),
                    (current.date() - timedelta(days=1)).isoformat(),
                    "-0.269" if state == "RISK_OFF" else "0.231",
                )
            )
            current = next_day
        self.rows = rows
        self.write_data()

    def close(self):
        (
            m.EXPECTED_CAUSAL_TIMELINE_SHA,
            m.EXPECTED_CAUSAL_MANIFEST_SHA,
            m.EXPECTED_MACRO_CORE_SHA,
            m.EXPECTED_LABCORE_SHA,
            m.EXPECTED_CLOCK_CONTRACT_SHA,
            m.EXPECTED_NORMALIZER_SHA,
        ) = self.old_hashes
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

    def test_stable_offsets_and_roundtrip(self):
        self.assertEqual(m.server_offset_hours_for_date(datetime(2025, 1, 15).date()), 2)
        self.assertEqual(m.server_offset_hours_for_date(datetime(2025, 7, 15).date()), 3)
        source = datetime(2025, 7, 15, 0, 0, tzinfo=timezone.utc)
        server, offset = m.utc_to_server(source)
        self.assertEqual(offset, 3)
        self.assertEqual(m.server_to_utc(server), source)

    def test_transition_mapping_and_offset_are_refused(self):
        with self.assertRaisesRegex(m.Refused, "UNKNOWN_DST_TRANSITION"):
            m.server_offset_hours_for_date(datetime(2025, 3, 9).date())
        with self.assertRaisesRegex(m.Refused, "UTC_TO_SERVER_UNRESOLVED"):
            m.utc_to_server(datetime(2025, 3, 9, 0, 0, tzinfo=timezone.utc))

    def test_transition_exports_unknown_boundary_and_resumes_at_actual_time(self):
        result = m.build_native_candidate(self.fx.timeline, self.fx.manifest, self.fx.repo)
        self.assertEqual(result["native_row_count"], 3)
        self.assertEqual(result["stable_native_row_count"], 2)
        self.assertEqual(result["transition_quarantine_count"], 1)
        self.assertTrue(result["native_parity_qualified"])
        self.assertEqual(result["blocker"], "")
        self.assertEqual(
            [(row["datetime"], row["state"]) for row in result["native_candidate_rows"]],
            [
                ("2025.03.08 02:00", "RISK_OFF"),
                ("2025.03.09 00:00", "UNKNOWN"),
                ("2025.03.10 03:00", "RISK_ON"),
            ],
        )
        evidence = result["quarantine_rows"][0]
        self.assertEqual(evidence["pre_resume_selected_state"], "UNKNOWN")
        self.assertEqual(evidence["at_resume_selected_state"], "RISK_ON")
        self.assertEqual(evidence["resume_native_datetime"], "2025.03.10 03:00")

    def test_transition_evidence_preserves_source_without_fabricating_state(self):
        result = m.build_native_candidate(self.fx.timeline, self.fx.manifest, self.fx.repo)
        evidence = result["quarantine_rows"][0]
        self.assertEqual(evidence["source_valid_from_utc"], "2025-03-09T00:00:00Z")
        self.assertEqual(evidence["source_state"], "STRESS")
        self.assertEqual(evidence["source_ri"], "-1.200")
        self.assertEqual(evidence["source_flags"], "VIX_STRESS")
        self.assertEqual(evidence["native_marker_state"], "UNKNOWN")
        self.assertEqual(evidence["marker_semantics"], "SERVER_DATE_BOUNDARY_NOT_SWITCH_INSTANT")
        self.assertEqual(
            result["native_candidate_rows"][1]["representation"],
            "TRANSITION_UNKNOWN_BOUNDARY_MARKER",
        )

    def test_bound_core_proves_block_and_lotmult_clear_then_resume(self):
        core = m.build_native_candidate(self.fx.timeline, self.fx.manifest, self.fx.repo)["core_binding"]
        self.assertTrue(core["explicit_unknown_retained_in_tester"])
        self.assertTrue(core["unknown_clears_block"])
        self.assertTrue(core["unknown_clears_lotmult"])
        self.assertTrue(core["malformed_invalid_skipped"])
        self.assertTrue(core["next_recognized_row_resumes_normal_trigger_logic"])

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

    def test_malformed_source_state_refused(self):
        self.fx.rows[0]["macro_state"] = "CLEAR"
        self.fx.write_data()
        with self.assertRaisesRegex(m.Refused, "CAUSAL_STATE_INVALID"):
            m.build_native_candidate(self.fx.timeline, self.fx.manifest, self.fx.repo)

    def test_every_dependency_hash_drift_is_refused(self):
        cases = (
            ("EXPECTED_CAUSAL_TIMELINE_SHA", "CAUSAL_TIMELINE_HASH_MISMATCH"),
            ("EXPECTED_CAUSAL_MANIFEST_SHA", "CAUSAL_MANIFEST_HASH_MISMATCH"),
            ("EXPECTED_MACRO_CORE_SHA", "MACRO_CORE_HASH_MISMATCH"),
            ("EXPECTED_LABCORE_SHA", "LABCORE_HASH_MISMATCH"),
            ("EXPECTED_CLOCK_CONTRACT_SHA", "CLOCK_CONTRACT_HASH_MISMATCH"),
            ("EXPECTED_NORMALIZER_SHA", "NORMALIZER_HASH_MISMATCH"),
        )
        for constant, error in cases:
            with self.subTest(constant=constant):
                original = getattr(m, constant)
                setattr(m, constant, "0" * 64)
                try:
                    with self.assertRaisesRegex(m.Refused, error):
                        m.build_native_candidate(self.fx.timeline, self.fx.manifest, self.fx.repo)
                finally:
                    setattr(m, constant, original)

    def test_core_semantic_drift_refused_even_if_hash_is_rebound(self):
        core = self.fx.repo / "ea_template/core/MacroGate_Core.mqh"
        core.write_text("changed\n", encoding="utf-8")
        m.EXPECTED_MACRO_CORE_SHA = m.sha256_file(core)
        with self.assertRaisesRegex(m.Refused, "MACRO_CORE_SEMANTICS_DRIFT"):
            m.build_native_candidate(self.fx.timeline, self.fx.manifest, self.fx.repo)

    def test_upstream_authority_expansion_refused(self):
        data = json.loads(self.fx.manifest.read_text(encoding="utf-8"))
        data["performance"] = "PASS"
        self.fx.manifest.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        m.EXPECTED_CAUSAL_MANIFEST_SHA = m.sha256_file(self.fx.manifest)
        with self.assertRaisesRegex(m.Refused, "UPSTREAM_AUTHORITY_EXPANDED"):
            m.build_native_candidate(self.fx.timeline, self.fx.manifest, self.fx.repo)

    def test_frozen_12_case_contract_and_2024_adversarial_case(self):
        self.fx.use_full_frozen_window()
        result = m.build_native_candidate(self.fx.timeline, self.fx.manifest, self.fx.repo)
        validation = m.validate_frozen_contract(result)
        self.assertEqual(validation["transition_cases"], "12/12")
        self.assertEqual(validation["adversarial_2024_11_03"], "PASS")
        self.assertEqual(result["offset_counts"], {"UTC_PLUS_2": 758, "UTC_PLUS_3": 1422})
        self.assertEqual(
            tuple(row["transition_server_date"] for row in result["quarantine_rows"]),
            m.REQUIRED_TRANSITION_DATES,
        )
        adversarial = next(
            row for row in result["quarantine_rows"] if row["transition_server_date"] == "2024-11-03"
        )
        self.assertEqual(adversarial["prior_native_state"], "NEUTRAL")
        self.assertEqual(adversarial["source_state"], "RISK_OFF")
        self.assertEqual(adversarial["native_marker_state"], "UNKNOWN")
        self.assertEqual(adversarial["resume_native_datetime"], "2024.11.04 02:00")

    def test_output_has_no_performance_authority(self):
        result = m.build_native_candidate(self.fx.timeline, self.fx.manifest, self.fx.repo)
        self.assertFalse(result["can_execute"])
        self.assertEqual(result["performance"], "NOT_RUN")
        self.assertFalse(result["holdout_used"])
        self.assertIsNone(result["probability"])

    def test_write_artifacts_is_byte_deterministic_and_source_bound(self):
        result = m.build_native_candidate(self.fx.timeline, self.fx.manifest, self.fx.repo)
        first = m.write_artifacts(result, self.fx.root / "first")
        second = m.write_artifacts(result, self.fx.root / "second")
        self.assertEqual(first["manifest_sha256"], second["manifest_sha256"])
        self.assertEqual(first["native_candidate_sha256"], second["native_candidate_sha256"])
        self.assertEqual(first["quarantine_sha256"], second["quarantine_sha256"])
        manifest = json.loads(Path(first["manifest"]).read_text(encoding="utf-8"))
        self.assertEqual(manifest["core_binding"]["macro_core_sha256"], m.EXPECTED_MACRO_CORE_SHA)
        self.assertIsNotNone(manifest["implementation_binding"]["exporter_sha256"])
        self.assertIsNone(manifest["probability"])


if __name__ == "__main__":
    unittest.main()
