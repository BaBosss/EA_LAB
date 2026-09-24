from __future__ import annotations

import json
import unittest
from copy import deepcopy
from datetime import datetime

from tools.news_macro_lab.causal import build_causal_regime_package
from tools.news_macro_lab.core import ROOT, Refused, macro_context, sha256, stable_hash
from tools.news_macro_lab.monitor_handoff import (
    build_monitor_handoff,
    build_production_monitor_handoff,
)
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


FIXTURE_ROOT = ROOT / "tools/news_macro_lab/tests/fixtures"
VALID_HANDOFF = json.loads((FIXTURE_ROOT / "monitor_handoff_valid.json").read_text("utf-8"))
INVALID_HANDOFF = json.loads((FIXTURE_ROOT / "monitor_handoff_invalid.json").read_text("utf-8"))


def completed_experiment_contract():
    proposal = json.loads(
        (ROOT / "tools/news_macro_lab/experiment_proposal.json").read_text("utf-8")
    )
    proposal["gate_receipt_sha256"] = {
        gate: sha256(("receipt-" + gate).encode())
        for gate in proposal["gate_receipt_sha256"]
    }
    proposal["windows"] = {
        "MAIN": {"start_utc": "2023-01-01T00:00:00Z", "end_utc": "2026-01-01T00:00:00Z"},
        "BWD": {"start_utc": "2020-01-01T00:00:00Z", "end_utc": "2023-01-01T00:00:00Z"},
    }
    proposal["placebo_seeds"] = [11, 22]
    proposal["evaluation_unit"] = "BASKET_EPISODE"
    proposal["frozen_identity"] = deepcopy(VALID_HANDOFF["declared_identity"])
    return proposal


EXPERIMENT_CONTRACT = completed_experiment_contract()
IDENTITY = {
    **VALID_HANDOFF["declared_identity"],
    "experiment_contract_sha256": stable_hash(EXPERIMENT_CONTRACT),
}
_USE_COMPLETE_CONTRACT = object()
_USE_CONTRACT_HASH = object()
_USE_CONTROLLER_CONTRACT = object()


def handoff_readiness():
    data = json.loads(
        (ROOT / "tools/news_macro_lab/global_source_catalog.json").read_text("utf-8")
    )
    return global_readiness(data)


def metrics(**changes):
    row = {
        "net": 100.0,
        "pf_value": 1.2,
        "pf_status": "FINITE",
        "eq_dd_pct": 10.0,
        "eq_dd_definition": "MAX_EQUITY_PEAK_TO_TROUGH_PCT",
        "closed_trades": 200,
        "episodes": 150,
        "max_exposure": 0.2,
        "max_exposure_definition": "MAX_AGGREGATE_LOTS",
        "tail_loss_value": 50.0,
        "tail_loss_definition": "WORST_EPISODE_NET_LOSS_ABS",
        "hard_kills": 0,
        "guard_firings": 2,
        "attempts_blocked": 3,
        "contact_seconds": 3600,
        "time_in_market_seconds": 50000,
    }
    row.update(changes)
    return row


def arm(arm_id, kind, seed=None, *, identity=None, **metric_changes):
    identity = IDENTITY if identity is None else identity
    return {
        "arm_id": arm_id,
        "arm_kind": kind,
        "frozen_identity_sha256": stable_hash(identity),
        "placebo_seed": seed,
        "report_sha256": sha256(("report-" + arm_id).encode()),
        "native_receipt_sha256": sha256(("receipt-" + arm_id).encode()),
        "year_split_sha256": sha256(("year-" + arm_id).encode()),
        "regime_split_sha256": sha256(("regime-" + arm_id).encode()),
        "source_coverage_sha256": sha256(("coverage-" + arm_id).encode()),
        "transaction_economics_sha256": sha256(("economics-" + arm_id).encode()),
        "metrics": metrics(**metric_changes),
    }


def result_package(identity=None):
    identity = deepcopy(IDENTITY if identity is None else identity)
    return {
        "schema_version": "guard_ab_result_package/2",
        "changed_dimension": "NEWS_FIXED_WINDOW",
        "evaluation_unit": "BASKET_EPISODE",
        "holdout_used": False,
        "frozen_identity": identity,
        "placebo_seeds": [11, 22],
        "arms": [
            arm("base", "BASE", identity=identity, guard_firings=0, attempts_blocked=0),
            arm("real", "REAL_GUARD", identity=identity, net=120.0),
            arm("p11", "PLACEBO", 11, identity=identity, net=105.0),
            arm("p22", "PLACEBO", 22, identity=identity, net=90.0),
        ],
    }


class ResultContractTests(unittest.TestCase):
    def test_descriptive_only(self):
        r = compare_guard_ab(result_package())
        self.assertIsNone(r["verdict"])
        self.assertFalse(r["can_promote"])
        self.assertTrue(r["all_placebo_seeds_reported"])
        self.assertEqual(r["real_delta_vs_base"]["net"], 20.0)
        self.assertEqual(r["frozen_identity"], IDENTITY)

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
        r = compare_guard_ab(p)
        self.assertEqual(r["real_pf_delta_vs_base"],
                         {"status": "UNAVAILABLE_NONFINITE_PF", "value": None})
        self.assertEqual(r["arms"][1]["metrics"]["pf_status"], "UNDEFINED_NO_GROSS_LOSS")
        self.assertIsNone(r["arms"][1]["metrics"]["pf_value"])

    def test_placebo_pf_status_and_evidence_are_preserved(self):
        p = result_package()
        p["arms"][2]["metrics"]["pf_status"] = "UNAVAILABLE"
        p["arms"][2]["metrics"]["pf_value"] = None
        r = compare_guard_ab(p)
        p11 = next(a for a in r["arms"] if a["arm_id"] == "p11")
        self.assertEqual(p11["metrics"]["pf_status"], "UNAVAILABLE")
        self.assertIsNone(p11["metrics"]["pf_value"])
        self.assertEqual(r["placebo_deltas"][0]["pf_delta_vs_base"],
                         {"status": "UNAVAILABLE_NONFINITE_PF", "value": None})
        self.assertEqual(p11["source_coverage_sha256"], p["arms"][2]["source_coverage_sha256"])
        self.assertEqual(p11["transaction_economics_sha256"],
                         p["arms"][2]["transaction_economics_sha256"])

    def test_tail_metric_and_definition_are_preserved(self):
        r = compare_guard_ab(result_package())
        self.assertEqual(r["arms"][0]["metrics"]["tail_loss_definition"],
                         "WORST_EPISODE_NET_LOSS_ABS")
        self.assertEqual(r["real_delta_vs_base"]["tail_loss_value"], 0.0)

    def test_metric_definition_drift_refused(self):
        p = result_package()
        p["arms"][1]["metrics"]["tail_loss_definition"] = "OTHER_TAIL_RULE"
        with self.assertRaisesRegex(Refused, "METRIC_DEFINITION_DRIFT"):
            compare_guard_ab(p)

    def test_missing_required_evidence_hash_refused(self):
        p = result_package()
        del p["arms"][2]["year_split_sha256"]
        with self.assertRaisesRegex(Refused, "RESULT_ARM_SCHEMA_MISMATCH"):
            compare_guard_ab(p)


class MonitorHandoffTests(unittest.TestCase):
    def preflight(self):
        return experiment_preflight(completed_experiment_contract())

    def test_payload_cannot_claim_live(self):
        r = build_monitor_handoff(
            source_head=VALID_HANDOFF["source_head"],
            canonical_sha=VALID_HANDOFF["canonical_sha"],
            expected_source_head=VALID_HANDOFF["source_head"],
            expected_canonical_sha=VALID_HANDOFF["canonical_sha"],
            readiness=handoff_readiness(), preflight=self.preflight(),
            experiment_contract=completed_experiment_contract(),
        )
        self.assertFalse(r["installed"])
        self.assertFalse(r["live_publish_allowed"])
        self.assertEqual(r["runtime_effectiveness"]["NewsGuard"], "UNKNOWN")
        self.assertEqual(r["global_regime"], "UNKNOWN")

    def test_falsey_non_list_result_container_is_refused(self):
        with self.assertRaisesRegex(Refused, "RESULT_SUMMARY_LIST_REQUIRED"):
            build_monitor_handoff(
                source_head=VALID_HANDOFF["source_head"],
                canonical_sha=VALID_HANDOFF["canonical_sha"],
                expected_source_head=VALID_HANDOFF["source_head"],
                expected_canonical_sha=VALID_HANDOFF["canonical_sha"],
                readiness=handoff_readiness(), preflight=self.preflight(),
                experiment_contract=completed_experiment_contract(),
                result_summaries={},
            )

    def test_placeholder_git_heads_are_refused(self):
        with self.assertRaisesRegex(Refused, "EXACT_SOURCE_HEAD_REQUIRED"):
            build_monitor_handoff(
                source_head="1" * 40,
                canonical_sha=VALID_HANDOFF["canonical_sha"],
                expected_source_head=VALID_HANDOFF["source_head"],
                expected_canonical_sha=VALID_HANDOFF["canonical_sha"],
                readiness=handoff_readiness(), preflight=self.preflight(),
                experiment_contract=completed_experiment_contract(),
            )

    def test_readiness_regime_leak_refused(self):
        ready = handoff_readiness(); ready["world_regime"] = "RISK_ON"
        with self.assertRaisesRegex(Refused, "READINESS_MUST_REMAIN_UNKNOWN"):
            build_monitor_handoff(
                source_head=VALID_HANDOFF["source_head"],
                canonical_sha=VALID_HANDOFF["canonical_sha"],
                expected_source_head=VALID_HANDOFF["source_head"],
                expected_canonical_sha=VALID_HANDOFF["canonical_sha"],
                readiness=ready, preflight=self.preflight(),
                experiment_contract=completed_experiment_contract(),
            )

    def test_result_authority_leak_refused(self):
        summary = compare_guard_ab(result_package())
        summary["verdict"] = "PASS"
        with self.assertRaisesRegex(Refused, "RESULT_SUMMARY_AUTHORITY_LEAK"):
            build_monitor_handoff(
                source_head=VALID_HANDOFF["source_head"],
                canonical_sha=VALID_HANDOFF["canonical_sha"],
                expected_source_head=VALID_HANDOFF["source_head"],
                expected_canonical_sha=VALID_HANDOFF["canonical_sha"],
                readiness=handoff_readiness(), preflight=self.preflight(),
                experiment_contract=completed_experiment_contract(),
                result_summaries=[summary],
            )

    def handoff(self, summary, experiment_contract=None, preflight=None):
        contract = completed_experiment_contract() if experiment_contract is None else experiment_contract
        return build_monitor_handoff(
            source_head=VALID_HANDOFF["source_head"],
            canonical_sha=VALID_HANDOFF["canonical_sha"],
            expected_source_head=VALID_HANDOFF["source_head"],
            expected_canonical_sha=VALID_HANDOFF["canonical_sha"],
            readiness=handoff_readiness(),
            preflight=experiment_preflight(contract) if preflight is None else preflight,
            experiment_contract=contract,
            result_summaries=[summary],
        )

    def test_complete_identity_valid_regression(self):
        summary = compare_guard_ab(result_package())
        handoff = self.handoff(summary)
        self.assertEqual(handoff["schema_version"], "news_macro_monitor_handoff/2")
        self.assertEqual(handoff["result_summaries"][0]["frozen_identity"], IDENTITY)
        self.assertEqual(
            handoff["result_summaries"][0]["frozen_identity_sha256"],
            stable_hash(IDENTITY),
        )
        self.assertFalse(handoff["result_summaries"][0]["holdout_used"])

    def test_invalid_identity_hash_fixtures_are_refused(self):
        for case in INVALID_HANDOFF["identity_hash_cases"]:
            with self.subTest(case=case["name"]):
                summary = compare_guard_ab(result_package())
                summary["frozen_identity"][case["field"]] = case["value"]
                with self.assertRaisesRegex(Refused, case["error"]):
                    self.handoff(summary)

    def test_identity_digest_mismatch_is_refused(self):
        summary = compare_guard_ab(result_package())
        summary["frozen_identity"]["config_id"] = "CFG-NEWS-OTHER"
        with self.assertRaisesRegex(Refused, "RESULT_IDENTITY_MISMATCH"):
            self.handoff(summary)

    def test_partial_identity_is_refused(self):
        summary = compare_guard_ab(result_package())
        del summary["frozen_identity"]["classifier_sha256"]
        with self.assertRaisesRegex(Refused, "FROZEN_IDENTITY_SCHEMA_MISMATCH"):
            self.handoff(summary)

    def test_missing_required_handoff_field_is_refused(self):
        summary = compare_guard_ab(result_package())
        del summary["frozen_identity"]
        with self.assertRaisesRegex(Refused, "UNQUALIFIED_RESULT_SUMMARY"):
            self.handoff(summary)

    def test_experiment_contract_mismatch_is_refused(self):
        summary = compare_guard_ab(result_package())
        other = completed_experiment_contract()
        other["classification"] = "COORDINATED_FAKE_CONTRACT"
        with self.assertRaisesRegex(Refused, "PREFLIGHT_CONTRACT_MISMATCH"):
            self.handoff(summary, experiment_contract=other, preflight=self.preflight())

    def test_exact_experiment_contract_is_required_for_results(self):
        summary = compare_guard_ab(result_package())
        with self.assertRaisesRegex(Refused, "EXACT_EXPERIMENT_CONTRACT_REQUIRED"):
            build_monitor_handoff(
                source_head=VALID_HANDOFF["source_head"],
                canonical_sha=VALID_HANDOFF["canonical_sha"],
                expected_source_head=VALID_HANDOFF["source_head"],
                expected_canonical_sha=VALID_HANDOFF["canonical_sha"],
                readiness=handoff_readiness(), preflight=self.preflight(),
                result_summaries=[summary],
            )

    def test_valid_looking_identity_mismatches_are_refused(self):
        for case in INVALID_HANDOFF["mismatched_identity_cases"]:
            with self.subTest(field=case["field"]):
                other = deepcopy(IDENTITY)
                other[case["field"]] = case["value"]
                summary = compare_guard_ab(result_package(other))
                with self.assertRaisesRegex(Refused, "RESULT_IDENTITY_MISMATCH"):
                    self.handoff(summary)

    def test_recognized_but_wrong_contract_semantics_are_refused(self):
        for field, value in (("changed_dimension", "MACRO_FROZEN_RULES"),
                             ("evaluation_unit", "TRADE")):
            with self.subTest(field=field):
                summary = compare_guard_ab(result_package())
                summary[field] = value
                with self.assertRaisesRegex(Refused, "RESULT_CONTRACT_SEMANTICS_MISMATCH"):
                    self.handoff(summary)

    def test_placeholder_identity_labels_are_refused(self):
        for value in INVALID_HANDOFF["placeholder_label_cases"]:
            with self.subTest(value=value):
                summary = compare_guard_ab(result_package())
                summary["frozen_identity"]["config_id"] = value
                summary["frozen_identity_sha256"] = stable_hash(summary["frozen_identity"])
                with self.assertRaisesRegex(Refused, "PLACEHOLDER_IDENTITY_REFUSED"):
                    self.handoff(summary)

    def test_unsupported_mechanism_statuses_are_refused(self):
        for status in INVALID_HANDOFF["mechanism_status_cases"]:
            with self.subTest(status=status):
                summary = compare_guard_ab(result_package())
                summary["mechanism_status"] = status
                with self.assertRaisesRegex(Refused, "MECHANISM_STATUS_UNSUPPORTED"):
                    self.handoff(summary)

    def test_holdout_must_be_false(self):
        summary = compare_guard_ab(result_package())
        summary["holdout_used"] = True
        with self.assertRaisesRegex(Refused, "HOLDOUT_AUTHORITY_REFUSED"):
            self.handoff(summary)

    def test_unknown_result_enums_are_refused(self):
        for field, value in (("changed_dimension", "NEWS_MAGIC"),
                             ("evaluation_unit", "ACCOUNT")):
            with self.subTest(field=field):
                summary = compare_guard_ab(result_package())
                summary[field] = value
                with self.assertRaisesRegex(Refused, "RESULT_ENUM_UNSUPPORTED"):
                    self.handoff(summary)


class ProductionMonitorHandoffTests(unittest.TestCase):
    def controller_contract(self, experiment_contract):
        return {
            "schema_version": "news_macro_handoff_controller/1",
            "expected_source_head": VALID_HANDOFF["source_head"],
            "expected_canonical_sha": VALID_HANDOFF["canonical_sha"],
            "experiment_contract_sha256": stable_hash(experiment_contract),
        }

    def build(self, *, contract=_USE_COMPLETE_CONTRACT, summaries=None,
              source_head=None, canonical_sha=None,
              expected_contract_sha=_USE_CONTRACT_HASH,
              controller_contract=_USE_CONTROLLER_CONTRACT,
              accepted_controller_sha=None):
        contract = (
            completed_experiment_contract()
            if contract is _USE_COMPLETE_CONTRACT else contract
        )
        if controller_contract is _USE_CONTROLLER_CONTRACT:
            controller_contract = self.controller_contract(contract)
        if (expected_contract_sha is not _USE_CONTRACT_HASH and
                isinstance(controller_contract, dict)):
            controller_contract = deepcopy(controller_contract)
            controller_contract["experiment_contract_sha256"] = expected_contract_sha
        if accepted_controller_sha is None and isinstance(controller_contract, dict):
            accepted_controller_sha = stable_hash(controller_contract)
        return build_production_monitor_handoff(
            source_head=VALID_HANDOFF["source_head"] if source_head is None else source_head,
            canonical_sha=VALID_HANDOFF["canonical_sha"] if canonical_sha is None else canonical_sha,
            controller_contract=controller_contract,
            accepted_controller_contract_sha256=accepted_controller_sha,
            readiness=handoff_readiness(),
            experiment_contract=contract,
            result_summaries=summaries,
        )

    def test_happy_path_uses_validated_result(self):
        result = self.build(summaries=[compare_guard_ab(result_package())])
        self.assertEqual(result["schema_version"], "news_macro_monitor_handoff/2")
        self.assertEqual(result["source_head"], VALID_HANDOFF["source_head"])
        self.assertEqual(result["canonical_sha_at_handoff"], VALID_HANDOFF["canonical_sha"])
        self.assertEqual(result["result_summaries"][0]["frozen_identity"], IDENTITY)

    def test_zero_results_with_complete_identity_is_truthful(self):
        result = self.build(summaries=[])
        self.assertEqual(result["result_summaries"], [])
        self.assertEqual(
            result["expected_experimental_identity_sha256"],
            stable_hash(IDENTITY),
        )
        self.assertEqual(result["experiment_preflight"]["native_runs"], 0)

    def test_zero_results_without_identity_is_refused(self):
        contract = completed_experiment_contract()
        contract["frozen_identity"] = None
        with self.assertRaisesRegex(Refused, "EXACT_EXPERIMENT_IDENTITY_REQUIRED"):
            self.build(contract=contract, summaries=[])

    def test_zero_results_without_contract_is_refused(self):
        with self.assertRaisesRegex(Refused, "EXACT_EXPERIMENT_CONTRACT_REQUIRED"):
            self.build(
                contract=None,
                controller_contract={"not": "used"},
                accepted_controller_sha="0" * 64,
                summaries=[],
            )

    def test_fabricated_source_head_is_refused(self):
        with self.assertRaisesRegex(Refused, "SOURCE_HEAD_BINDING_MISMATCH"):
            self.build(source_head="0123456789abcdef0123456789abcdef01234567", summaries=[])

    def test_fabricated_canonical_sha_is_refused(self):
        with self.assertRaisesRegex(Refused, "CANONICAL_SHA_BINDING_MISMATCH"):
            self.build(canonical_sha="89abcdef0123456789abcdef0123456789abcdef", summaries=[])

    def test_correct_format_wrong_result_identity_is_refused(self):
        accepted_contract = completed_experiment_contract()
        wrong_contract = deepcopy(accepted_contract)
        wrong_contract["frozen_identity"]["classifier_sha256"] = sha256(
            b"different valid classifier"
        )
        with self.assertRaisesRegex(Refused, "EXPERIMENT_CONTRACT_BINDING_MISMATCH"):
            self.build(
                contract=wrong_contract,
                expected_contract_sha=stable_hash(accepted_contract),
                summaries=[],
            )

    def test_self_consistent_fabricated_git_pins_are_refused(self):
        contract = completed_experiment_contract()
        accepted_controller = self.controller_contract(contract)
        fabricated_controller = deepcopy(accepted_controller)
        fabricated_source = "0123456789abcdef0123456789abcdef01234567"
        fabricated_canonical = "89abcdef0123456789abcdef0123456789abcdef"
        fabricated_controller["expected_source_head"] = fabricated_source
        fabricated_controller["expected_canonical_sha"] = fabricated_canonical
        with self.assertRaisesRegex(Refused, "CONTROLLER_CONTRACT_BINDING_MISMATCH"):
            self.build(
                contract=contract,
                source_head=fabricated_source,
                canonical_sha=fabricated_canonical,
                controller_contract=fabricated_controller,
                accepted_controller_sha=stable_hash(accepted_controller),
                summaries=[],
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
