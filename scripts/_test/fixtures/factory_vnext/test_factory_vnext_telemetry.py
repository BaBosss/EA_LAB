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
from _triage.factory_vnext.telemetry import (
    TelemetryError,
    build_attribution_index,
    make_event,
    summarize_family_availability,
    validate_event,
)


class FactoryVNextTelemetryTests(unittest.TestCase):
    def setUp(self) -> None:
        master = make_master_mold(
            "MOLD1", "1", ["CAP_ENTRY", "CAP_RECOVERY", "CAP_HEDGE", "CAP_FILTER"]
        )
        family = make_strategy_family(
            master, "B11", "Boss11", ["CAP_ENTRY", "CAP_RECOVERY", "CAP_HEDGE"], "11"
        )
        groups = [
            make_position_group("PG_MAIN", "MAIN"),
            make_position_group("PG_REVERSAL", "REVERSAL"),
            make_position_group("PG_HEDGE", "HEDGE", "PG_MAIN"),
        ]
        components = [
            make_component("CMP_MAIN", "ENTRY", "PG_MAIN", capabilities=["CAP_ENTRY"]),
            make_component("CMP_REV", "REVERSAL", "PG_REVERSAL", capabilities=["CAP_ENTRY"]),
            make_component(
                "CMP_REC_REV", "RECOVERY", "PG_REVERSAL",
                capabilities=["CAP_RECOVERY"],
                recovery_scope_position_group_id="PG_REVERSAL",
            ),
            make_component(
                "CMP_HEDGE", "HEDGE", "PG_HEDGE", capabilities=["CAP_HEDGE"],
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
            payload={"price": 1.2345},
        )
        kwargs.update(overrides)
        return make_event(**kwargs)

    def test_event_id_is_deterministic_and_payload_sensitive(self):
        e1 = self._trade_event()
        e2 = self._trade_event()
        self.assertEqual(e1["EventID"], e2["EventID"])
        e3 = self._trade_event(payload={"price": 9.9999})
        self.assertNotEqual(e1["EventID"], e3["EventID"])
        validate_event(e1, self.variant)

    def test_invalid_evidence_label_refused(self):
        with self.assertRaisesRegex(TelemetryError, "invalid evidence label"):
            self._trade_event(evidence_label="CONFIRMED")

    def test_unknown_family_refused(self):
        with self.assertRaisesRegex(TelemetryError, "unknown event family"):
            self._trade_event(event_family="MYSTERY_EVENTS")
        with self.assertRaisesRegex(TelemetryError, "unknown event family"):
            summarize_family_availability([], families=["MYSTERY_EVENTS"])

    def test_component_group_mismatch_refused(self):
        with self.assertRaisesRegex(TelemetryError, "component/group mismatch"):
            self._trade_event(component_id="CMP_MAIN", position_group_id="PG_REVERSAL")

    def test_recovery_and_hedge_cross_group_contamination_refused(self):
        with self.assertRaisesRegex(TelemetryError, "component/group mismatch"):
            self._trade_event(
                event_family="BASKET_EVENTS",
                component_id="CMP_REC_REV",
                position_group_id="PG_MAIN",
                intent_id="INTENT-RECOVERY-1",
            )
        with self.assertRaisesRegex(TelemetryError, "component/group mismatch"):
            self._trade_event(
                event_family="HEDGE_EVENTS",
                component_id="CMP_HEDGE",
                position_group_id="PG_MAIN",
                intent_id="INTENT-HEDGE-1",
            )

    def test_variant_wide_context_must_be_explicit(self):
        ctx = make_event(
            run_id="RUN-TEST0001",
            variant=self.variant,
            event_family="CONTEXT_EVENTS",
            evidence_label="DERIVED",
            scope="VARIANT",
            sequence=1,
            payload={"regime": "trend"},
        )
        self.assertEqual(ctx["Scope"], "VARIANT")
        self.assertIsNone(ctx["ComponentID"])
        self.assertIsNone(ctx["PositionGroupID"])

        with self.assertRaisesRegex(TelemetryError, "VARIANT scope is only valid for CONTEXT_EVENTS"):
            self._trade_event(scope="VARIANT", component_id=None, position_group_id=None)

    def test_zero_event_family_is_untested_or_unavailable_not_measured(self):
        summary = summarize_family_availability([])
        self.assertEqual(summary["SIGNAL_EVENTS"]["SummaryEvidenceLabel"], "UNTESTED")
        self.assertEqual(summary["TRADE_EVENTS"]["SummaryEvidenceLabel"], "UNTESTED")
        self.assertEqual(summary["HEDGE_EVENTS"]["SummaryEvidenceLabel"], "UNAVAILABLE")
        self.assertEqual(summary["BASKET_EVENTS"]["SummaryEvidenceLabel"], "UNAVAILABLE")
        for family_summary in summary.values():
            self.assertNotEqual(family_summary["SummaryEvidenceLabel"], "MEASURED")
            self.assertEqual(family_summary["count"], 0)

    def test_simulated_events_cannot_be_relabeled_measured(self):
        simulated = self._trade_event(evidence_label="SIMULATED", sequence=1)
        summary = summarize_family_availability([simulated], families=["TRADE_EVENTS"])
        self.assertEqual(summary["TRADE_EVENTS"]["SummaryEvidenceLabel"], "SIMULATED")
        self.assertEqual(summary["TRADE_EVENTS"]["EvidenceLabels"], ("SIMULATED",))
        self.assertNotEqual(summary["TRADE_EVENTS"]["SummaryEvidenceLabel"], "MEASURED")

    def test_intent_required_for_action_families(self):
        with self.assertRaisesRegex(TelemetryError, "IntentID is required"):
            self._trade_event(intent_id=None)

    def test_attribution_index_groups_by_variant_component_group_intent(self):
        e1 = self._trade_event(sequence=1)
        e2 = self._trade_event(sequence=2, component_id="CMP_REV", position_group_id="PG_REVERSAL",
                                intent_id="INTENT-ENTRY-2")
        index = build_attribution_index([e1, e2])
        self.assertEqual(index["by_variant"]["B11-V01"], sorted([e1["EventID"], e2["EventID"]]))
        self.assertEqual(index["by_component"]["CMP_MAIN"], [e1["EventID"]])
        self.assertEqual(index["by_component"]["CMP_REV"], [e2["EventID"]])
        self.assertEqual(index["by_position_group"]["PG_REVERSAL"], [e2["EventID"]])
        self.assertEqual(index["by_intent"]["INTENT-ENTRY-2"], [e2["EventID"]])


if __name__ == "__main__":
    unittest.main(verbosity=2)
