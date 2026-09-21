from __future__ import annotations

import json
import unittest
from copy import deepcopy
from datetime import datetime

from tools.news_macro_lab.causal import build_causal_regime_package
from tools.news_macro_lab.core import ROOT, Refused, macro_context, sha256, stable_hash
from tools.news_macro_lab.monitor_handoff import build_monitor_handoff
from tools.news_macro_lab.placebo import build_week_shift_placebos
from tools.news_macro_lab.planning import experiment_preflight, global_readiness
from tools.news_macro_lab.results import compare_guard_ab

RAW_BUNDLE = b"SYNTHETIC RAW BUNDLE - NOT MARKET DATA"
CLASSIFIER = sha256(b"synthetic classifier")
CLOCK = {
    "version": "SYNTH-CLOCK-v2",
    "source_timezone": "UTC",
    "broker_timezone": "SYNTHETIC_ONLY",
    "mapping_basis": "MECHANICS_ONLY",
}


def source_input(source_id, available):
    return {
        "source_id": source_id,
        "source_snapshot_sha256": sha256(source_id.encode()),
        "available_at_utc": available,
    }


def causal_row(**changes):
    row = {
        "record_id": "SYN-STATE-1",
        "revision_id": "v1",
        "effective_at_utc": "2025-03-04T10:05:00Z",
        "available_at_utc": "2025-03-04T10:05:00Z",
        "valid_until_utc": "2025-03-05T10:05:00Z",
        "regime_state": "RISK_OFF",
        "risk_index": -0.55,
        "source_inputs": [
            source_input("AUDJPY", "2025-03-04T10:00:00Z"),
            source_input("VIX", "2025-03-04T10:05:00Z"),
        ],
    }
    row.update(changes)
    return row


def causal_package(rows=None):
    return build_causal_regime_package(
        rows or [causal_row()],
        RAW_BUNDLE,
        dataset_id="SYN-CAUSAL",
        dataset_version="v1",
        series_id="SYN-MRIS",
        classifier_sha256=CLASSIFIER,
        required_source_ids=["AUDJPY", "VIX"],
        coverage_start_utc="2025-03-01T00:00:00Z",
        coverage_end_utc="2025-03-10T00:00:00Z",
        clock_mapping=CLOCK,
    )


class CausalTimelineTests(unittest.TestCase):
    def test_package_never_self_qualifies(self):
        p = causal_package()
        self.assertFalse(p["historical_dataset_qualified"])
        self.assertFalse(p["derivation_verified"])
        self.assertFalse(p["can_execute"])

    def test_state_visible_only_after_latest_input(self):
        p = causal_package()
        before = macro_context(
            p, RAW_BUNDLE, "2025-03-04T10:04:59Z",
            series_id="SYN-MRIS", classifier_sha256=CLASSIFIER,
            max_source_age_seconds=7200, synthetic=True,
        )
        after = macro_context(
            p, RAW_BUNDLE, "2025-03-04T10:05:00Z",
            series_id="SYN-MRIS", classifier_sha256=CLASSIFIER,
            max_source_age_seconds=7200, synthetic=True,
        )
        self.assertEqual(before["macro_state"], "UNKNOWN")
        self.assertEqual(after["macro_state"], "RISK_OFF")

    def test_visibility_before_input_refused(self):
        row = causal_row(effective_at_utc="2025-03-04T10:00:00Z",
                         available_at_utc="2025-03-04T10:10:00Z")
        with self.assertRaisesRegex(Refused, "EFFECTIVE_BEFORE_INPUT"):
            causal_package([row])

    def test_effective_after_available_refused(self):
        row = causal_row(effective_at_utc="2025-03-04T11:00:00Z")
        with self.assertRaisesRegex(Refused, "CAUSAL_CLOCK"):
            causal_package([row])

    def test_exact_source_set_required(self):
        row = causal_row(source_inputs=[source_input("AUDJPY", "2025-03-04T10:00:00Z")])
        with self.assertRaisesRegex(Refused, "EXACT_SOURCE_INPUT_SET"):
            causal_package([row])

    def test_unknown_regime_refused(self):
        with self.assertRaisesRegex(Refused, "UNKNOWN_REGIME"):
            causal_package([causal_row(regime_state="BULL")])

    def test_duplicate_effective_refused(self):
        other = causal_row(record_id="SYN-STATE-2", revision_id="v2")
        with self.assertRaisesRegex(Refused, "DUPLICATE_REGIME_EFFECTIVE"):
            causal_package([causal_row(), other])

    def test_raw_bundle_hash_is_exact(self):
        self.assertEqual(causal_package()["source_snapshot_sha256"], sha256(RAW_BUNDLE))


EVENTS = [
    {"event_id": "E1", "scheduled_at_utc": "2025-02-05T12:00:00Z",
     "currency": "USD", "importance": "High"},
    {"event_id": "E2", "scheduled_at_utc": "2025-02-12T15:00:00Z",
     "currency": "EUR", "importance": "High"},
]


class PlaceboTests(unittest.TestCase):
    def call(self, **changes):
        kw = dict(
            events=EVENTS,
            coverage_start_utc="2025-01-01T00:00:00Z",
            coverage_end_utc="2025-04-30T23:59:59Z",
            pre_minutes=30,
            post_minutes=15,
            seeds=[11, 22],
            allowed_shift_weeks=[-4, -3, -2, -1, 1, 2, 3, 4],
        )
        kw.update(changes)
        return build_week_shift_placebos(**kw)

    def test_all_seeds_retained_no_selection(self):
        r = self.call()
        self.assertEqual([x["seed"] for x in r["schedules"]], [11, 22])
        self.assertTrue(r["all_seeds_retained"])
        self.assertFalse(r["selection_performed"])
        self.assertFalse(r["can_execute"])

    def test_weekday_and_clock_preserved(self):
        r = self.call()
        originals = {e["event_id"]: datetime.fromisoformat(e["scheduled_at_utc"].replace("Z", "+00:00"))
                     for e in EVENTS}
        for sched in r["schedules"]:
            for e in sched["events"]:
                new = datetime.fromisoformat(e["scheduled_at_utc"].replace("Z", "+00:00"))
                old = originals[e["source_event_id"]]
                self.assertEqual(new.weekday(), old.weekday())
                self.assertEqual(new.time(), old.time())

    def test_deterministic(self):
        self.assertEqual(self.call(), self.call())

    def test_zero_shift_refused(self):
        with self.assertRaisesRegex(Refused, "NONZERO_SHIFTS"):
            self.call(allowed_shift_weeks=[0, 1])

    def test_duplicate_seed_refused(self):
        with self.assertRaisesRegex(Refused, "UNIQUE_PLACEBO_SEEDS"):
            self.call(seeds=[1, 1])

    def test_collision_infeasible_refused(self):
        real = [
            {"event_id": "E1", "scheduled_at_utc": "2025-02-05T12:00:00Z",
             "currency": "USD", "importance": "High"},
            {"event_id": "E2", "scheduled_at_utc": "2025-02-12T12:00:00Z",
             "currency": "USD", "importance": "High"},
        ]
        with self.assertRaisesRegex(Refused, "PLACEBO_CONSTRUCTION_INFEASIBLE"):
            self.call(events=real, seeds=[1], allowed_shift_weeks=[1])

    def test_no_performance_is_created(self):
        self.assertEqual(self.call()["performance"], "NOT_RUN")


IDENTITY = {
    "ea_source_sha256": "a" * 64,
    "ex5_sha256": "b" * 64,
    "set_sha256": "c" * 64,
    "dataset_sha256": "d" * 64,
    "broker_clock_sha256": "e" * 64,
    "install_id": "D:/Meta 5",
    "tester_model": "M1_M1_OHLC_RESEARCH",
    "symbol": "XAUUSD",
    "timeframe": "H1",
    "window_id": "MAIN-2023-2025",
    "config_id": "CFG-SYN",
}


def metrics(**changes):
    row = {
        "net": 100.0,
        "pf_value": 1.2,
        "pf_status": "FINITE",
        "eq_dd_pct": 10.0,
        "closed_trades": 200,
        "episodes": 150,
        "max_exposure": 0.2,
        "hard_kills": 0,
        "guard_firings": 2,
        "attempts_blocked": 3,
        "contact_seconds": 3600,
        "time_in_market_seconds": 50000,
    }
    row.update(changes)
    return row


def arm(arm_id, kind, seed=None, **metric_changes):
    return {
        "arm_id": arm_id,
        "arm_kind": kind,
        "frozen_identity_sha256": stable_hash(IDENTITY),
        "placebo_seed": seed,
        "report_sha256": sha256(("report-" + arm_id).encode()),
        "native_receipt_sha256": sha256(("receipt-" + arm_id).encode()),
        "metrics": metrics(**metric_changes),
    }


def result_package():
    return {
        "schema_version": "guard_ab_result_package/1",
        "changed_dimension": "NEWS_FIXED_WINDOW",
        "evaluation_unit": "BASKET_EPISODE",
        "holdout_used": False,
        "frozen_identity": deepcopy(IDENTITY),
        "placebo_seeds": [11, 22],
        "arms": [
            arm("base", "BASE", guard_firings=0, attempts_blocked=0),
            arm("real", "REAL_GUARD", net=120.0),
            arm("p11", "PLACEBO", 11, net=105.0),
            arm("p22", "PLACEBO", 22, net=90.0),
        ],
    }


class ResultContractTests(unittest.TestCase):
    def test_descriptive_only(self):
        r = compare_guard_ab(result_package())
        self.assertIsNone(r["verdict"])
        self.assertFalse(r["can_promote"])
        self.assertTrue(r["all_placebo_seeds_reported"])
        self.assertEqual(r["real_delta_vs_base"]["net"], 20.0)

    def test_missing_placebo_refused(self):
        p = result_package(); p["arms"].pop()
        with self.assertRaisesRegex(Refused, "EXACT_RESULT_ARM_SET"):
            compare_guard_ab(p)

    def test_identity_drift_refused(self):
        p = result_package(); p["arms"][1]["frozen_identity_sha256"] = "f" * 64
        with self.assertRaisesRegex(Refused, "ARM_IDENTITY_MISMATCH"):
            compare_guard_ab(p)

    def test_holdout_refused(self):
        p = result_package(); p["holdout_used"] = True
        with self.assertRaisesRegex(Refused, "HOLDOUT"):
            compare_guard_ab(p)

    def test_base_guard_action_refused(self):
        p = result_package(); p["arms"][0]["metrics"]["guard_firings"] = 1
        with self.assertRaisesRegex(Refused, "BASE_ARM_GUARD_ACTION"):
            compare_guard_ab(p)

    def test_no_firing_is_unproven(self):
        p = result_package(); p["arms"][1]["metrics"]["guard_firings"] = 0
        self.assertEqual(compare_guard_ab(p)["mechanism_status"], "UNTESTED_NO_GUARD_FIRINGS")

    def test_undefined_pf_never_becomes_zero(self):
        p = result_package()
        p["arms"][1]["metrics"]["pf_status"] = "UNDEFINED_NO_GROSS_LOSS"
        p["arms"][1]["metrics"]["pf_value"] = None
        self.assertIsNone(compare_guard_ab(p)["real_pf_delta_vs_base"])


class MonitorHandoffTests(unittest.TestCase):
    def readiness(self):
        data = json.loads((ROOT / "tools/news_macro_lab/global_source_catalog.json").read_text("utf-8"))
        return global_readiness(data)

    def preflight(self):
        data = json.loads((ROOT / "tools/news_macro_lab/experiment_proposal.json").read_text("utf-8"))
        return experiment_preflight(data)

    def test_payload_cannot_claim_live(self):
        r = build_monitor_handoff(
            source_head="1" * 40, canonical_sha="2" * 40,
            readiness=self.readiness(), preflight=self.preflight(),
        )
        self.assertFalse(r["installed"])
        self.assertFalse(r["live_publish_allowed"])
        self.assertEqual(r["runtime_effectiveness"]["NewsGuard"], "UNKNOWN")
        self.assertEqual(r["global_regime"], "UNKNOWN")

    def test_readiness_regime_leak_refused(self):
        ready = self.readiness(); ready["world_regime"] = "RISK_ON"
        with self.assertRaisesRegex(Refused, "READINESS_MUST_REMAIN_UNKNOWN"):
            build_monitor_handoff(
                source_head="1" * 40, canonical_sha="2" * 40,
                readiness=ready, preflight=self.preflight(),
            )

    def test_result_authority_leak_refused(self):
        summary = compare_guard_ab(result_package())
        summary["verdict"] = "PASS"
        with self.assertRaisesRegex(Refused, "RESULT_SUMMARY_AUTHORITY_LEAK"):
            build_monitor_handoff(
                source_head="1" * 40, canonical_sha="2" * 40,
                readiness=self.readiness(), preflight=self.preflight(),
                result_summaries=[summary],
            )



class ContinuationSkeletonTests(unittest.TestCase):
    def test_macro_proposal_remains_blocked(self):
        data = json.loads((ROOT / "tools/news_macro_lab/experiment_macro_proposal.json").read_text("utf-8"))
        r = experiment_preflight(data)
        self.assertEqual(data["changed_dimensions"], ["MACRO_FROZEN_RULES"])
        self.assertEqual(r["status"], "BLOCKED_CONTRACT_INCOMPLETE")
        self.assertFalse(r["can_execute"])

    def test_native_manifest_is_inert(self):
        data = json.loads((ROOT / "tools/news_macro_lab/native_backtest_manifest_skeleton.json").read_text("utf-8"))
        self.assertFalse(data["can_execute"])
        self.assertEqual(data["windows"]["HOLDOUT"], "LOCKED_UNSPENT")
        self.assertEqual(data["performance"], "NOT_RUN")

    def test_source_contract_is_inert(self):
        data = json.loads((ROOT / "tools/news_macro_lab/causal_source_contract.json").read_text("utf-8"))
        self.assertFalse(data["can_execute"])
        self.assertFalse(data["historical_dataset_qualified"])
        self.assertEqual(data["performance"], "NOT_RUN")


if __name__ == "__main__":
    unittest.main()
