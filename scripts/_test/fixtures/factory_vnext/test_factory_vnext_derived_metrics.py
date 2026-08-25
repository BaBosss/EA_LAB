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
from _triage.factory_vnext.derived_metrics import (
    DerivedMetricsError,
    derive_metric_bundle,
    validate_metric_bundle,
)
from _triage.factory_vnext.telemetry import make_event


class FactoryVNextDerivedMetricsTests(unittest.TestCase):
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
            make_component("CMP_REC_REV", "RECOVERY", "PG_REVERSAL", capabilities=["CAP_RECOVERY"], recovery_scope_position_group_id="PG_REVERSAL"),
            make_component("CMP_HEDGE", "HEDGE", "PG_HEDGE", capabilities=["CAP_HEDGE"], parent_position_group_id="PG_MAIN"),
        ]
        self.variant = make_strategy_variant(family, "B11-V01", "1.0", groups, components)

    def _event(self, **overrides):
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

    def _context_event(self, **overrides):
        kwargs = dict(
            run_id="RUN-TEST0001",
            variant=self.variant,
            event_family="CONTEXT_EVENTS",
            evidence_label="DERIVED",
            scope="VARIANT",
            sequence=1,
            payload={"regime": "trend"},
        )
        kwargs.update(overrides)
        return make_event(**kwargs)

    def test_reorder_invariance_and_stable_metric_bundle_id(self):
        e1 = self._event(sequence=1)
        e2 = make_event(
            run_id="RUN-TEST0001",
            variant=self.variant,
            event_family="OPTIMIZATION_PASSES",
            evidence_label="DERIVED",
            scope="COMPONENT",
            component_id="CMP_MAIN",
            position_group_id="PG_MAIN",
            intent_id="INTENT-OPT-1",
            sequence=2,
            payload={"pass_count": 4, "runtime_seconds": 18.5, "score": 1.23, "surface_score": 0.77},
        )
        b1 = derive_metric_bundle([e1, e2])
        b2 = derive_metric_bundle([e2, e1])
        self.assertEqual(b1["MetricBundleID"], b2["MetricBundleID"])
        self.assertEqual(b1["sections"], b2["sections"])
        validate_metric_bundle(b1)

    def test_mixed_run_refusal(self):
        e1 = self._event(sequence=1)
        e2 = self._event(sequence=2, run_id="RUN-TEST0002")
        with self.assertRaisesRegex(DerivedMetricsError, "exactly one RunID and one VariantID"):
            derive_metric_bundle([e1, e2])

    def test_zero_family_visibility(self):
        bundle = derive_metric_bundle([self._context_event()])
        overview = bundle["sections"]["Overview"]
        by_id = {metric["MetricID"]: metric for metric in overview}
        self.assertEqual(by_id["overview.signal_events.count"]["Status"], "UNTESTED")
        self.assertEqual(by_id["overview.trade_events.count"]["Status"], "UNTESTED")
        self.assertEqual(by_id["overview.basket_events.count"]["Status"], "UNAVAILABLE")
        self.assertEqual(by_id["overview.hedge_events.count"]["Status"], "UNAVAILABLE")
        self.assertEqual(by_id["overview.total_event_count"]["Value"], 1)

    def test_simulated_provenance_not_upgraded(self):
        e1 = self._event(evidence_label="SIMULATED")
        bundle = derive_metric_bundle([e1])
        by_id = {metric["MetricID"]: metric for metric in bundle["sections"]["Overview"]}
        self.assertEqual(by_id["overview.trade_events.count"]["evidence_label"], "SIMULATED")
        self.assertNotEqual(by_id["overview.trade_events.count"]["evidence_label"], "MEASURED")

    def test_trade_aggregates_and_traceability(self):
        e1 = self._event(sequence=1, payload={"mfe": 10.0, "mae": -2.0, "holding_seconds": 100.0, "giveback": 1.0, "exit_reason": "TP"})
        e2 = self._event(sequence=2, payload={"mfe": 14.0, "mae": -4.0, "holding_seconds": 140.0, "giveback": 2.0, "exit_reason": "SL"})
        bundle = derive_metric_bundle([e1, e2])
        trade = {metric["MetricID"]: metric for metric in bundle["sections"]["TradeDiagnostic"]}
        self.assertEqual(trade["trade.mfe.sum"]["Value"], 24.0)
        self.assertEqual(trade["trade.mae.sum"]["Value"], -6.0)
        self.assertEqual(trade["trade.holding_seconds.sum"]["Value"], 240.0)
        self.assertEqual(trade["trade.giveback.sum"]["Value"], 3.0)
        self.assertEqual(trade["trade.exit_reason.SL"]["Value"], 1)
        self.assertEqual(trade["trade.exit_reason.TP"]["Value"], 1)
        self.assertEqual(set(trade["trade.mfe.sum"]["source_event_ids"]), {e1["EventID"], e2["EventID"]})

    def test_missing_trade_dimensions_are_null_and_unavailable(self):
        e1 = self._event(sequence=1, payload={"exit_reason": "TP"})
        bundle = derive_metric_bundle([e1])
        trade = {metric["MetricID"]: metric for metric in bundle["sections"]["TradeDiagnostic"]}
        self.assertIsNone(trade["trade.mfe.sum"]["Value"])
        self.assertEqual(trade["trade.mfe.sum"]["Status"], "UNAVAILABLE")
        self.assertIsNone(trade["trade.mae.sum"]["Value"])

    def test_optimization_aggregates(self):
        e1 = make_event(
            run_id="RUN-TEST0001",
            variant=self.variant,
            event_family="OPTIMIZATION_PASSES",
            evidence_label="DERIVED",
            scope="COMPONENT",
            component_id="CMP_MAIN",
            position_group_id="PG_MAIN",
            sequence=1,
            payload={"pass_count": 2, "runtime_seconds": 10.0, "score": 1.5, "surface_score": 0.9},
        )
        e2 = make_event(
            run_id="RUN-TEST0001",
            variant=self.variant,
            event_family="OPTIMIZATION_PASSES",
            evidence_label="DERIVED",
            scope="COMPONENT",
            component_id="CMP_MAIN",
            position_group_id="PG_MAIN",
            sequence=2,
            payload={"pass_count": 3, "runtime_seconds": 20.0, "score": 2.5, "surface_score": 0.7},
        )
        bundle = derive_metric_bundle([e1, e2])
        opt = {metric["MetricID"]: metric for metric in bundle["sections"]["Optimization"]}
        self.assertEqual(opt["optimization.pass_count.sum"]["Value"], 5.0)
        self.assertEqual(opt["optimization.runtime_seconds.sum"]["Value"], 30.0)
        self.assertEqual(opt["optimization.score.sum"]["Value"], 4.0)
        self.assertEqual(set(opt["optimization.score.sum"]["source_event_ids"]), {e1["EventID"], e2["EventID"]})

    def test_metric_bundle_id_changes_with_exact_payload_value(self):
        e1 = self._event(sequence=1, payload={"mfe": 10.0, "mae": -2.0, "holding_seconds": 100.0, "giveback": 1.0, "exit_reason": "TP"})
        e2 = self._event(sequence=2, payload={"mfe": 14.0, "mae": -4.0, "holding_seconds": 140.0, "giveback": 2.0, "exit_reason": "SL"})
        b1 = derive_metric_bundle([e1, e2])
        b2 = derive_metric_bundle([self._event(sequence=1, payload={"mfe": 10.0, "mae": -2.0, "holding_seconds": 100.0, "giveback": 1.0, "exit_reason": "TP"}),
                                   self._event(sequence=2, payload={"mfe": 15.0, "mae": -4.0, "holding_seconds": 140.0, "giveback": 2.0, "exit_reason": "SL"})])
        self.assertNotEqual(b1["MetricBundleID"], b2["MetricBundleID"])

    def test_payload_numeric_type_refusal(self):
        bad = self._event(payload={"mfe": "oops"})
        with self.assertRaisesRegex(DerivedMetricsError, "must be numeric"):
            derive_metric_bundle([bad])

    def test_validate_bundle_rejects_unsorted_metrics(self):
        bundle = derive_metric_bundle([self._context_event()])
        broken = dict(bundle)
        broken_sections = dict(bundle["sections"])
        broken_sections["Overview"] = list(reversed(broken_sections["Overview"]))
        broken["sections"] = broken_sections
        with self.assertRaisesRegex(DerivedMetricsError, "must be sorted by MetricID"):
            validate_metric_bundle(broken)


if __name__ == "__main__":
    unittest.main(verbosity=2)
