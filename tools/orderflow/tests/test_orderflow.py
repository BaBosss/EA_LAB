from __future__ import annotations

import copy
import json
import math
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
MODULE_DIR = ROOT / "tools" / "orderflow"
sys.path.insert(0, str(MODULE_DIR))

from offline_reference import (  # noqa: E402
    ContractError,
    expand_case,
    load_fixture,
    pinned_state_changed,
    replay_case,
    validate_contract,
    validate_records,
)


FIXTURE = MODULE_DIR / "fixtures" / "positive_cases.json"


class OrderFlowReferenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.package = load_fixture(FIXTURE)

    def case(self, case_id: str) -> dict:
        item = next(item for item in self.package["cases"] if item["id"] == case_id)
        return expand_case(self.package, item)

    def assert_rejected(self, case: dict, code: str) -> None:
        with self.assertRaises(ContractError) as raised:
            validate_records(case)
        self.assertEqual(code, raised.exception.code)

    def append_bar(self, case: dict, *, open_: float, high: float, low: float, close: float,
                   ask_volume: float = 50.0, bid_volume: float = 50.0) -> None:
        previous = case["bars"][-1]
        bar = {
            "record_id": f"appended-{len(case['bars']) + 1}",
            "source_revision": case["contract"]["source_revision"],
            "sequence": previous["sequence"] + 1,
            "period_seconds": 300,
            "open_time": previous["open_time"] + 300,
            "close_time": previous["close_time"] + 300,
            "available_at": previous["available_at"] + 300,
            "completed": True,
            "open": open_,
            "high": high,
            "low": low,
            "close": close,
            "executed_ask_volume": ask_volume,
            "executed_bid_volume": bid_volume,
            "total_executed_volume": ask_volume + bid_volume,
        }
        case["bars"].append(bar)
        case["quote"]["observed_at"] = bar["close_time"] + 1
        case["quote"]["available_at"] = bar["close_time"] + 2
        case["as_of"] = case["quote"]["available_at"]
        case["decision_envelope"] = {
            "evaluation_time": case["as_of"],
            "current_closed_bar_record_id": bar["record_id"],
            "current_closed_bar_close_time": bar["close_time"],
        }

    def test_all_four_mirrored_positive_cases(self) -> None:
        for case_id, direction in (
            ("OF01_LONG", 1),
            ("OF01_SHORT", -1),
            ("OF02_LONG", 1),
            ("OF02_SHORT", -1),
        ):
            with self.subTest(case_id=case_id):
                result = replay_case(self.case(case_id))
                self.assertEqual("SIGNAL", result["decision"])
                self.assertEqual(direction, result["direction"])
                self.assertTrue(result["prospective_quote_not_fill"])
                self.assertEqual("TEMPLATE_EXIT_BINDING_REQUIRED", result["template_exit_binding"])

    def test_positive_geometry_matches_fixture(self) -> None:
        for item in self.package["cases"]:
            result = replay_case(expand_case(self.package, item))
            expected = item["expected"]
            self.assertEqual(expected["direction"], result["direction"])
            self.assertTrue(math.isclose(expected["stop_price"], result["stop_price"], abs_tol=1e-9))
            self.assertTrue(math.isclose(expected["target_price"], result["target_price"], abs_tol=1e-9))

    def test_proxy_cannot_masquerade_as_real_orderflow(self) -> None:
        package = copy.deepcopy(self.package)
        package["contract"]["data_identity"] = "PRICE_ACTION_PROXY"
        with self.assertRaisesRegex(ContractError, "PROXY_NOT_TRUE_ORDERFLOW"):
            validate_contract(package, "FIXTURE")

    def test_tick_count_volume_cannot_masquerade_as_executed_sides(self) -> None:
        package = copy.deepcopy(self.package)
        package["contract"]["volume_provenance"] = "TICK_COUNT_PROXY"
        with self.assertRaisesRegex(ContractError, "EXECUTED_ASK_BID_REQUIRED"):
            validate_contract(package, "FIXTURE")

    def test_missing_pin_fails_closed(self) -> None:
        package = copy.deepcopy(self.package)
        package["contract"]["timezone_ruleset_id"] = ""
        with self.assertRaisesRegex(ContractError, "MISSING_REQUIRED_PIN"):
            validate_contract(package, "FIXTURE")

    def test_missing_explicit_freshness_fails_closed(self) -> None:
        package = copy.deepcopy(self.package)
        package["freshness_policy"]["max_m5_age_seconds"] = 0
        with self.assertRaisesRegex(ContractError, "MISSING_EXPLICIT_FRESHNESS_POLICY"):
            validate_contract(package, "FIXTURE")

    def test_freshness_numeric_types_are_strict(self) -> None:
        for invalid in (True, False, 60.0, "60", None):
            with self.subTest(invalid=invalid):
                package = copy.deepcopy(self.package)
                package["freshness_policy"]["max_m5_age_seconds"] = invalid
                with self.assertRaisesRegex(ContractError, "MISSING_EXPLICIT_FRESHNESS_POLICY"):
                    validate_contract(package, "FIXTURE")

        package = copy.deepcopy(self.package)
        package["freshness_policy"]["max_m5_age_seconds"] = 60
        validate_contract(package, "FIXTURE")

    def test_other_integer_contract_fields_reject_boolean_values(self) -> None:
        package = copy.deepcopy(self.package)
        package["history"]["count"] = True
        with self.assertRaisesRegex(ContractError, "INVALID_FIXTURE_HISTORY"):
            validate_contract(package, "FIXTURE")

        case = self.case("OF01_LONG")
        case["context"]["sequence"] = True
        self.assert_rejected(case, "M15_PIN_MISMATCH")

        case = self.case("OF01_LONG")
        case["profile"]["session_start"] = True
        self.assert_rejected(case, "PROFILE_SESSION_NOT_COMPLETED")

    def test_unqualified_instrument_mapping_fails_closed(self) -> None:
        package = copy.deepcopy(self.package)
        package["contract"]["profile_instrument_id"] = "OTHER.INSTRUMENT"
        with self.assertRaisesRegex(ContractError, "UNQUALIFIED_INSTRUMENT_MAPPING"):
            validate_contract(package, "FIXTURE")

    def test_explicit_qualified_mapping_is_accepted(self) -> None:
        package = copy.deepcopy(self.package)
        package["contract"]["profile_instrument_id"] = "OTHER.INSTRUMENT"
        package["contract"]["instrument_mapping_id"] = "fixture-map-v1"
        package["contract"]["instrument_mapping_qualified"] = True
        validate_contract(package, "FIXTURE")

    def test_fixture_schema_cannot_be_claimed_as_qualified(self) -> None:
        with self.assertRaisesRegex(ContractError, "RECORD_CLASS_MISMATCH"):
            validate_contract(self.package, "QUALIFIED")

    def test_qualified_schema_rejects_fixture_history_generator(self) -> None:
        package = copy.deepcopy(self.package)
        package["schema_id"] = "orderflow_qualified/v1"
        package["record_class"] = "QUALIFIED"
        package["synthetic"] = False
        package["contract"]["source_qualified"] = True
        package["freshness_policy"]["required_record_class"] = "QUALIFIED"
        with self.assertRaisesRegex(ContractError, "QUALIFIED_DATA_CANNOT_USE_FIXTURE_GENERATOR"):
            validate_contract(package, "QUALIFIED")

    def test_qualified_schema_requires_qualified_source(self) -> None:
        package = copy.deepcopy(self.package)
        package["schema_id"] = "orderflow_qualified/v1"
        package["record_class"] = "QUALIFIED"
        package["synthetic"] = False
        package.pop("history")
        package["freshness_policy"]["required_record_class"] = "QUALIFIED"
        with self.assertRaisesRegex(ContractError, "UNQUALIFIED_SOURCE"):
            validate_contract(package, "QUALIFIED")

    def test_stale_profile_rejected(self) -> None:
        case = self.case("OF01_LONG")
        case["freshness_policy"]["max_profile_age_seconds"] = 10
        self.assert_rejected(case, "STALE_PROFILE")

    def test_future_profile_rejected(self) -> None:
        case = self.case("OF01_LONG")
        case["profile"]["available_at"] = case["as_of"] + 1
        self.assert_rejected(case, "PROFILE_FUTURE_OR_CLOCK_CONTRADICTION")

    def test_contradictory_profile_levels_rejected(self) -> None:
        case = self.case("OF01_LONG")
        case["profile"]["poc"] = case["profile"]["vah"]
        self.assert_rejected(case, "CONTRADICTORY_PROFILE_LEVELS")

    def test_profile_must_precede_context(self) -> None:
        case = self.case("OF01_LONG")
        case["profile"]["session_end"] = case["context"]["close_time"]
        case["profile"]["available_at"] = case["profile"]["session_end"]
        self.assert_rejected(case, "PROFILE_NOT_PRIOR_TO_CONTEXT")

    def test_incomplete_m5_bar_rejected(self) -> None:
        case = self.case("OF01_LONG")
        case["bars"][-1]["completed"] = False
        self.assert_rejected(case, "M5_INCOMPLETE_OR_FUTURE")

    def test_future_m5_availability_rejected(self) -> None:
        case = self.case("OF01_LONG")
        case["bars"][-1]["available_at"] = case["as_of"] + 1
        self.assert_rejected(case, "M5_INCOMPLETE_OR_FUTURE")

    def test_wrong_m5_duration_rejected(self) -> None:
        case = self.case("OF01_LONG")
        case["bars"][-1]["close_time"] -= 1
        self.assert_rejected(case, "M5_INCOMPLETE_OR_FUTURE")

    def test_nonmonotonic_available_at_rejected(self) -> None:
        case = self.case("OF01_LONG")
        delayed = case["bars"][-1]["close_time"] + 1
        case["bars"][-2]["available_at"] = delayed
        case["bars"][-1]["available_at"] = delayed
        case["quote"]["available_at"] = delayed
        case["as_of"] = delayed
        self.assert_rejected(case, "M5_NON_MONOTONIC_OR_DUPLICATE")

    def test_overlapping_bar_time_rejected(self) -> None:
        case = self.case("OF01_LONG")
        case["bars"][-1]["open_time"] = case["bars"][-2]["close_time"] - 1
        case["bars"][-1]["close_time"] = case["bars"][-1]["open_time"] + 300
        self.assert_rejected(case, "M5_NON_MONOTONIC_OR_DUPLICATE")

    def test_duplicate_sequence_rejected(self) -> None:
        case = self.case("OF01_LONG")
        case["bars"][-1]["sequence"] = case["bars"][-2]["sequence"]
        self.assert_rejected(case, "M5_NON_MONOTONIC_OR_DUPLICATE")

    def test_duplicate_record_id_rejected(self) -> None:
        case = self.case("OF01_LONG")
        case["bars"][-1]["record_id"] = case["bars"][-2]["record_id"]
        self.assert_rejected(case, "M5_DUPLICATE_RECORD_ID")

    def test_zero_total_volume_rejected(self) -> None:
        case = self.case("OF01_LONG")
        case["bars"][-1]["executed_ask_volume"] = 0.0
        case["bars"][-1]["executed_bid_volume"] = 0.0
        case["bars"][-1]["total_executed_volume"] = 0.0
        self.assert_rejected(case, "INVALID_EXECUTED_VOLUME")

    def test_negative_side_volume_rejected(self) -> None:
        case = self.case("OF01_LONG")
        case["bars"][-1]["executed_ask_volume"] = -1.0
        self.assert_rejected(case, "INVALID_EXECUTED_VOLUME")

    def test_nan_volume_rejected(self) -> None:
        case = self.case("OF01_LONG")
        case["bars"][-1]["executed_ask_volume"] = float("nan")
        self.assert_rejected(case, "INVALID_EXECUTED_VOLUME")

    def test_contradictory_total_volume_rejected(self) -> None:
        case = self.case("OF01_LONG")
        case["bars"][-1]["total_executed_volume"] += 1.0
        self.assert_rejected(case, "CONTRADICTORY_EXECUTED_VOLUME")

    def test_stale_m5_history_rejected(self) -> None:
        case = self.case("OF01_LONG")
        case["freshness_policy"]["max_m5_age_seconds"] = 1
        case["as_of"] += 100
        case["quote"]["observed_at"] = case["as_of"]
        case["quote"]["available_at"] = case["as_of"]
        self.assert_rejected(case, "STALE_M5_HISTORY")

    def test_stale_quote_rejected(self) -> None:
        case = self.case("OF01_LONG")
        case["freshness_policy"]["max_quote_age_seconds"] = 1
        case["as_of"] += 100
        case["decision_envelope"]["evaluation_time"] = case["as_of"]
        case["freshness_policy"]["max_m5_age_seconds"] = 1000
        self.assert_rejected(case, "STALE_QUOTE")

    def test_pretrigger_quote_is_no_lookahead_rejection(self) -> None:
        case = self.case("OF01_LONG")
        case["quote"]["observed_at"] = case["bars"][-1]["close_time"] - 1
        case["quote"]["available_at"] = case["bars"][-1]["close_time"]
        with self.assertRaisesRegex(ContractError, "QUOTE_FUTURE_OR_PRE_TRIGGER"):
            replay_case(case)

    def test_quote_requires_explicit_execution_identity_and_units(self) -> None:
        case = self.case("OF01_LONG")
        replay_case(case)
        case["quote"]["instrument_id"] = "OTHER.INSTRUMENT"
        with self.assertRaisesRegex(ContractError, "QUOTE_EXECUTION_PIN_MISMATCH"):
            replay_case(case)

    def test_cross_instrument_quote_requires_qualified_normalization_mapping(self) -> None:
        package = copy.deepcopy(self.package)
        package["contract"]["execution_instrument_id"] = "OTHER.INSTRUMENT"
        with self.assertRaisesRegex(ContractError, "UNQUALIFIED_EXECUTION_MAPPING"):
            validate_contract(package, "FIXTURE")

        package["contract"]["execution_mapping_id"] = "fixture-execution-map-v1"
        package["contract"]["execution_mapping_qualified"] = True
        package["contract"]["execution_normalization_id"] = "fixture-normalization-v1"
        package["contract"]["execution_normalization_qualified"] = True
        validate_contract(package, "FIXTURE")

    def test_quote_price_and_cost_units_must_match_signal_unit(self) -> None:
        case = self.case("OF02_SHORT")
        case["quote"]["cost_price_unit_id"] = "OTHER.UNIT"
        with self.assertRaisesRegex(ContractError, "QUOTE_PRICE_COST_UNIT_MISMATCH"):
            replay_case(case)

    def test_quote_after_confirmation_within_current_bar_envelope_is_accepted(self) -> None:
        case = self.case("OF01_LONG")
        self.assertGreater(case["quote"]["observed_at"], case["bars"][-1]["close_time"])
        self.assertEqual("SIGNAL", replay_case(case)["decision"])

    def test_late_quote_with_omitted_closed_bar_is_rejected(self) -> None:
        for delay in (300, 301):
            with self.subTest(delay=delay):
                case = self.case("OF01_LONG")
                trigger_close = case["bars"][-1]["close_time"]
                case["quote"]["observed_at"] = trigger_close + delay
                case["quote"]["available_at"] = trigger_close + delay + 1
                case["as_of"] = case["quote"]["available_at"]
                case["decision_envelope"]["evaluation_time"] = case["as_of"]
                with self.assertRaisesRegex(ContractError, "DECISION_WINDOW_MISSING_CLOSED_BAR"):
                    replay_case(case)

    def test_decision_envelope_must_bind_current_closed_bar(self) -> None:
        case = self.case("OF02_LONG")
        case["decision_envelope"]["current_closed_bar_record_id"] = case["bars"][-2]["record_id"]
        with self.assertRaisesRegex(ContractError, "DECISION_ENVELOPE_MISMATCH"):
            replay_case(case)

    def test_of01_threshold_boundaries_are_inclusive(self) -> None:
        case = self.case("OF01_LONG")
        setup = case["bars"][-2]
        setup.update(
            {
                "low": 99.7,
                "executed_ask_volume": 60.0,
                "executed_bid_volume": 90.0,
                "total_executed_volume": 150.0,
            }
        )
        result = replay_case(case)
        self.assertEqual("SIGNAL", result["decision"])

    def test_of01_zone_overlap_does_not_require_exact_edge_center_touch(self) -> None:
        long_case = self.case("OF01_LONG")
        long_case["bars"][-2].update({"open": 100.5, "high": 100.6, "low": 100.1, "close": 100.35})
        self.assertEqual("SIGNAL", replay_case(long_case)["decision"])

        short_case = self.case("OF01_SHORT")
        short_case["bars"][-2].update({"open": 111.5, "high": 111.9, "low": 111.4, "close": 111.65})
        self.assertEqual("SIGNAL", replay_case(short_case)["decision"])

    def test_of01_bar_outside_zone_still_does_not_arm(self) -> None:
        for case_id, update in (
            ("OF01_LONG", {"open": 100.7, "high": 100.8, "low": 100.3, "close": 100.55}),
            ("OF01_SHORT", {"open": 111.3, "high": 111.7, "low": 111.2, "close": 111.45}),
        ):
            with self.subTest(case_id=case_id):
                case = self.case(case_id)
                case["bars"][-2].update(update)
                self.assertEqual("NONE", replay_case(case)["decision"])

    def test_of01_context_is_strictly_inside_value(self) -> None:
        case = self.case("OF01_LONG")
        case["context"].update({"open": 100.0, "high": 101.0, "low": 99.0, "close": 100.0})
        result = replay_case(case)
        self.assertEqual("NONE", result["decision"])

    def test_of01_net_rr_gate_uses_supplied_quote_and_cost(self) -> None:
        case = self.case("OF01_LONG")
        case["quote"].update({"bid": 103.9, "ask": 104.0, "all_in_cost_price": 0.1})
        result = replay_case(case)
        self.assertEqual("OF01_NET_RR_BELOW_1_5", result["code"])

    def test_of01_two_outer_closes_cancel(self) -> None:
        case = self.case("OF01_LONG")
        case["bars"] = case["bars"][:-1]
        self.append_bar(case, open_=100.0, high=100.1, low=99.5, close=99.7)
        self.append_bar(case, open_=99.8, high=99.9, low=99.3, close=99.6)
        result = replay_case(case)
        self.assertEqual("OF01_TWO_CLOSES_BEYOND_OUTER_EDGE", result["code"])

    def test_of01_trigger_expires_after_three_bars(self) -> None:
        case = self.case("OF01_LONG")
        case["bars"] = case["bars"][:-1]
        for _ in range(3):
            self.append_bar(case, open_=100.4, high=100.9, low=100.1, close=100.5)
        result = replay_case(case)
        self.assertEqual("OF01_TRIGGER_EXPIRED", result["code"])

    def test_of02_retest_expires_after_six_bars(self) -> None:
        case = self.case("OF02_LONG")
        case["bars"] = case["bars"][:-2]
        for _ in range(6):
            self.append_bar(case, open_=112.8, high=113.2, low=112.7, close=113.0)
        result = replay_case(case)
        self.assertEqual("OF02_RETEST_EXPIRED", result["code"])

    def test_of02_confirmation_expires_after_three_bars(self) -> None:
        case = self.case("OF02_LONG")
        case["bars"] = case["bars"][:-1]
        for _ in range(3):
            self.append_bar(case, open_=112.2, high=112.4, low=112.0, close=112.3, ask_volume=50, bid_volume=50)
        result = replay_case(case)
        self.assertEqual("OF02_CONFIRM_EXPIRED", result["code"])

    def test_of02_opposite_outer_close_cancels(self) -> None:
        case = self.case("OF02_LONG")
        case["bars"] = case["bars"][:-2]
        self.append_bar(case, open_=112.0, high=112.1, low=111.5, close=111.7)
        result = replay_case(case)
        self.assertEqual("OF02_CLOSE_PAST_OPPOSITE_OUTER_EDGE", result["code"])

    def test_of02_time_exit_remains_consumer_owned(self) -> None:
        result = replay_case(self.case("OF02_LONG"))
        self.assertEqual("CONSUMER_OWNED_12_M5_AFTER_ACTUAL_FILL", result["time_exit"])
        self.assertEqual(12, result["consumer_time_exit_m5_bars_after_fill"])

    def test_expiry_geometry_uses_completed_bar_counts_not_wall_clock(self) -> None:
        of01 = replay_case(self.case("OF01_LONG"))
        of02 = replay_case(self.case("OF02_LONG"))
        self.assertEqual(3, of01["confirmation_window_completed_m5_bars"])
        self.assertEqual(6, of02["retest_window_completed_m5_bars"])
        self.assertEqual(3, of02["confirmation_window_completed_m5_bars"])

    def test_source_revision_change_invalidates_armed_pins(self) -> None:
        case = self.case("OF01_LONG")
        pins = (
            case["contract"]["dataset_id"],
            case["contract"]["source_revision"],
            case["profile"]["profile_id"],
            case["profile"]["profile_revision"],
            case["context"]["record_id"],
        )
        case["contract"]["source_revision"] = "fixture-r2"
        self.assertTrue(pinned_state_changed(pins, case))

    def test_profile_revision_change_invalidates_armed_pins(self) -> None:
        case = self.case("OF02_LONG")
        pins = (
            case["contract"]["dataset_id"],
            case["contract"]["source_revision"],
            case["profile"]["profile_id"],
            case["profile"]["profile_revision"],
            case["context"]["record_id"],
        )
        case["profile"]["profile_revision"] = "profile-r2"
        self.assertTrue(pinned_state_changed(pins, case))

    def test_context_record_progression_does_not_invalidate_armed_pins(self) -> None:
        case = self.case("OF02_SHORT")
        pins = (
            case["contract"]["dataset_id"],
            case["contract"]["source_revision"],
            case["profile"]["profile_id"],
            case["profile"]["profile_revision"],
            case["context"]["record_id"],
        )
        case["context"]["record_id"] = "m15-new"
        case["context"]["sequence"] += 1
        self.assertFalse(pinned_state_changed(pins, case))

    def test_late_context_and_profile_do_not_retroactively_create_setup(self) -> None:
        for case_id, setup_offset in (("OF01_LONG", -2), ("OF02_LONG", -4)):
            for field in ("context", "profile"):
                with self.subTest(case_id=case_id, field=field):
                    case = self.case(case_id)
                    case[field]["available_at"] = case["bars"][setup_offset]["available_at"] + 1
                    self.assertEqual("NONE", replay_case(case)["decision"])

    def test_chronological_context_progression_is_causal_and_does_not_reset(self) -> None:
        case = self.case("OF01_LONG")
        setup_context = copy.deepcopy(case.pop("context"))
        setup_context["record_id"] = "m15-setup"
        setup_context["available_at"] = case["bars"][-2]["available_at"] - 1
        progressed = copy.deepcopy(setup_context)
        progressed["record_id"] = "m15-next-completed"
        progressed["sequence"] += 1
        progressed["open_time"] += 900
        progressed["close_time"] += 900
        progressed["available_at"] = case["bars"][-1]["available_at"] - 1
        case["contexts"] = [setup_context, progressed]
        result = replay_case(case)
        self.assertEqual("SIGNAL", result["decision"])
        self.assertEqual("m15-setup", result["setup_context_record_id"])

    def test_m15_context_history_rejects_overlap_and_accepts_adjacency(self) -> None:
        adjacent_case = self.case("OF01_LONG")
        first = copy.deepcopy(adjacent_case.pop("context"))
        adjacent = copy.deepcopy(first)
        adjacent["record_id"] = "m15-adjacent"
        adjacent["sequence"] += 1
        adjacent["open_time"] = first["close_time"]
        adjacent["close_time"] = adjacent["open_time"] + adjacent["period_seconds"]
        adjacent["available_at"] = adjacent["close_time"] + 1
        adjacent_case["contexts"] = [first, adjacent]
        validate_records(adjacent_case)

        overlapping_case = self.case("OF01_LONG")
        first = copy.deepcopy(overlapping_case.pop("context"))
        overlapping = copy.deepcopy(first)
        overlapping["record_id"] = "m15-overlapping"
        overlapping["sequence"] += 1
        overlapping["open_time"] = first["close_time"] - 600
        overlapping["close_time"] = overlapping["open_time"] + overlapping["period_seconds"]
        overlapping["available_at"] = overlapping["close_time"] + 1
        overlapping_case["contexts"] = [first, overlapping]
        self.assert_rejected(overlapping_case, "M15_NON_MONOTONIC_OR_DUPLICATE")

    def test_of02_chronological_context_progression_does_not_reset(self) -> None:
        case = self.case("OF02_LONG")
        setup_context = copy.deepcopy(case.pop("context"))
        setup_context["record_id"] = "m15-of02-setup"
        setup_context["available_at"] = case["bars"][-4]["available_at"] - 1
        progressed = copy.deepcopy(setup_context)
        progressed["record_id"] = "m15-of02-next-completed"
        progressed["sequence"] += 1
        progressed["open_time"] += 900
        progressed["close_time"] += 900
        progressed["available_at"] = case["bars"][-2]["available_at"] - 1
        case["contexts"] = [setup_context, progressed]
        result = replay_case(case)
        self.assertEqual("SIGNAL", result["decision"])
        self.assertEqual("m15-of02-setup", result["setup_context_record_id"])

    def test_unknown_historical_context_is_not_copied_backward(self) -> None:
        case = self.case("OF02_LONG")
        latest = copy.deepcopy(case.pop("context"))
        latest["available_at"] = case["bars"][-1]["available_at"] - 1
        case["contexts"] = [latest]
        self.assertEqual("NONE", replay_case(case)["decision"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
