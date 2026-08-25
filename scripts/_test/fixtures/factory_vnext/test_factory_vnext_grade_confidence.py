from __future__ import annotations

import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))

from _triage.factory_vnext.architecture import (
    make_component,
    make_master_mold,
    make_position_group,
    make_strategy_family,
    make_strategy_variant,
)
from _triage.factory_vnext.derived_metrics import derive_metric_bundle
from _triage.factory_vnext.grade_confidence import (
    GradeConfidenceError,
    build_grade_evidence,
    validate_grade_evidence,
)
from _triage.factory_vnext.telemetry import make_event


class FactoryVNextGradeConfidenceTests(unittest.TestCase):
    def setUp(self) -> None:
        master = make_master_mold("MOLD1", "1", ["CAP_ENTRY", "CAP_RECOVERY", "CAP_HEDGE", "CAP_FILTER"])
        family = make_strategy_family(master, "B11", "Boss11", ["CAP_ENTRY", "CAP_RECOVERY", "CAP_HEDGE"], "11")
        groups = [
            make_position_group("PG_MAIN", "MAIN"),
            make_position_group("PG_REVERSAL", "REVERSAL"),
            make_position_group("PG_HEDGE", "HEDGE", "PG_MAIN"),
        ]
        components = [
            make_component("CMP_MAIN", "ENTRY", "PG_MAIN", capabilities=["CAP_ENTRY"]),
            make_component("CMP_REV", "REVERSAL", "PG_REVERSAL", capabilities=["CAP_ENTRY"]),
            make_component(
                "CMP_REC_REV",
                "RECOVERY",
                "PG_REVERSAL",
                capabilities=["CAP_RECOVERY"],
                recovery_scope_position_group_id="PG_REVERSAL",
            ),
            make_component(
                "CMP_HEDGE",
                "HEDGE",
                "PG_HEDGE",
                capabilities=["CAP_HEDGE"],
                parent_position_group_id="PG_MAIN",
            ),
        ]
        self.variant = make_strategy_variant(family, "B11-V01", "1.0", groups, components)

    def _trade_event(self, **overrides):
        kwargs = dict(
            run_id="RUN-TEST0001",
            variant=self.variant,
            event_family="TRADE_EVENTS",
            evidence_label="MEASURED",
            scope="COMPONENT",
            component_id="CMP_MAIN",
            position_group_id="PG_MAIN",
            intent_id="INTENT-ENTRY-1",
            sequence=1,
            payload={"mfe": 12.5, "mae": -3.0, "holding_seconds": 120.0, "giveback": 1.25, "exit_reason": "TP"},
        )
        kwargs.update(overrides)
        return make_event(**kwargs)

    def _bundle(self, events):
        return derive_metric_bundle(events)

    def test_deterministic_reorder_and_identity_binding(self):
        e1 = self._trade_event(sequence=1)
        e2 = self._trade_event(sequence=2, payload={"mfe": 14.0, "mae": -4.0, "holding_seconds": 140.0, "giveback": 2.0, "exit_reason": "SL"})
        bundle_a = self._bundle([e1, e2])
        bundle_b = self._bundle([e2, e1])
        rec_a = build_grade_evidence(bundle_a, home_status="INSIDE_VALIDATED_CONTRACT")
        rec_b = build_grade_evidence(bundle_b, home_status="INSIDE_VALIDATED_CONTRACT")
        self.assertEqual(rec_a["GradeEvidenceID"], rec_b["GradeEvidenceID"])
        self.assertEqual(rec_a["category_records"], rec_b["category_records"])
        self.assertEqual(rec_a["RunID"], bundle_a["RunID"])
        self.assertEqual(rec_a["MetricBundleID"], bundle_a["MetricBundleID"])
        validate_grade_evidence(rec_a)

    def test_metric_value_change_changes_grade_evidence_id(self):
        e1 = self._trade_event(sequence=1)
        e2 = self._trade_event(sequence=2, payload={"mfe": 14.0, "mae": -4.0, "holding_seconds": 140.0, "giveback": 2.0, "exit_reason": "SL"})
        e3 = self._trade_event(sequence=2, payload={"mfe": 15.0, "mae": -4.0, "holding_seconds": 140.0, "giveback": 2.0, "exit_reason": "SL"})
        rec_a = build_grade_evidence(self._bundle([e1, e2]), home_status="INSIDE_VALIDATED_CONTRACT")
        rec_b = build_grade_evidence(self._bundle([e1, e3]), home_status="INSIDE_VALIDATED_CONTRACT")
        self.assertNotEqual(rec_a["GradeEvidenceID"], rec_b["GradeEvidenceID"])

    def test_invalid_metric_bundle_refused(self):
        with self.assertRaisesRegex(GradeConfidenceError, "metric_bundle must be a mapping"):
            build_grade_evidence(None, home_status="INSIDE_VALIDATED_CONTRACT")  # type: ignore[arg-type]

    def test_outside_home_blocks_all_axes(self):
        e1 = self._trade_event(sequence=1)
        rec = build_grade_evidence(self._bundle([e1]), home_status="OUTSIDE_VALIDATED_CONTRACT")
        self.assertEqual(rec["home_status"], "OUTSIDE_VALIDATED_CONTRACT")
        self.assertTrue(all(value is None for value in rec["top_level"].values()))
        self.assertEqual(rec["top_level"]["VERDICT"], None)

    def test_no_automatic_grade_or_build_potential(self):
        e1 = self._trade_event(sequence=1)
        rec = build_grade_evidence(self._bundle([e1]), home_status="INSIDE_VALIDATED_CONTRACT")
        self.assertEqual(set(rec["top_level"].keys()), {"VERDICT", "QUALITY_GRADE", "EVIDENCE_CONFIDENCE", "BUILD_POTENTIAL"})
        self.assertTrue(all(value is None for value in rec["top_level"].values()))
        self.assertNotIn("PASS", rec["top_level"].values())
        self.assertNotIn("A", rec["top_level"].values())
        self.assertNotIn("BUILD_POTENTIAL", rec.get("metrics", {}))

    def test_kint_001_remains_open_and_placeholders_are_provisional(self):
        e1 = self._trade_event(sequence=1)
        rec = build_grade_evidence(self._bundle([e1]), home_status="INSIDE_VALIDATED_CONTRACT")
        self.assertEqual(rec["KINT_001"]["state"], "OPEN")
        self.assertIsNone(rec["critical_floor_placeholders"]["sample_adequacy_floor"])
        self.assertIn("provisional", rec["critical_floor_placeholders"]["note"].lower())

    def test_missing_evidence_visible_and_traceable(self):
        e1 = self._trade_event(sequence=1, payload={"exit_reason": "TP"})
        rec = build_grade_evidence(self._bundle([e1]), home_status="INSIDE_VALIDATED_CONTRACT")
        categories = {item["Category"]: item for item in rec["category_records"]}
        self.assertEqual(categories["Edge"]["Status"], "UNTESTED")
        self.assertEqual(categories["Edge"]["source_metric_ids"], [])
        self.assertEqual(categories["Edge"]["source_event_ids"], [])
        self.assertEqual(categories["Recovery/Hedge Safety"]["Status"], "N/A")
        self.assertEqual(categories["Recovery/Hedge Safety"]["source_metric_ids"], [])

    def test_recovery_and_hedge_are_conditional(self):
        e1 = self._trade_event(sequence=1)
        rec = build_grade_evidence(self._bundle([e1]), home_status="INSIDE_VALIDATED_CONTRACT", recovery_active=True, hedge_active=True)
        categories = {item["Category"]: item for item in rec["category_records"]}
        self.assertEqual(categories["Recovery/Hedge Safety"]["Status"], "UNTESTED")
        self.assertEqual(categories["Recovery/Hedge Safety"]["WHY"], "No exact metrics for this category were present")

    def test_exact_source_metric_traceability(self):
        e1 = self._trade_event(sequence=1)
        rec = build_grade_evidence(self._bundle([e1]), home_status="INSIDE_VALIDATED_CONTRACT")
        categories = {item["Category"]: item for item in rec["category_records"]}
        self.assertTrue(categories["Risk/Tail"]["source_metric_ids"])
        self.assertIn(e1["EventID"], categories["Risk/Tail"]["source_event_ids"])

    def test_no_numeric_threshold_or_risk_fields_present(self):
        e1 = self._trade_event(sequence=1)
        rec = build_grade_evidence(self._bundle([e1]), home_status="INSIDE_VALIDATED_CONTRACT")
        text = repr(rec)
        self.assertNotIn("risk_capacity", text)
        self.assertNotIn("deployment_multiplier", text)
        self.assertNotIn("threshold", text.lower())
        self.assertNotIn("score_band", text.lower())


if __name__ == "__main__":
    unittest.main(verbosity=2)
