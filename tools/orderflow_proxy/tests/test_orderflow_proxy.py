from __future__ import annotations

import math
import copy
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "orderflow_proxy"))

import offline_reference as proxy


def _bar(open_time: int, open_: float, high: float, low: float, close: float, *,
         tick_volume: int = 100, mids: list[float] | None = None) -> dict[str, object]:
    quote_mids = list(mids if mids is not None else [close, close + 0.01])
    return {
        "record_id": f"m5-{open_time}",
        "open_time": open_time,
        "close_time": open_time + 300,
        "available_at": open_time + 300,
        "period_seconds": 300,
        "completed": True,
        "open": open_,
        "high": high,
        "low": low,
        "close": close,
        "tick_volume": tick_volume,
        "quote_ticks": [
            {
                "time_msc": open_time * 1_000 + index,
                "bid": mid,
                "ask": mid,
                "last": 999.0,
            }
            for index, mid in enumerate(quote_mids)
        ],
    }


def _set_bar_mids(bar: dict[str, object], mids: list[float]) -> None:
    open_time = int(bar["open_time"])
    bar["quote_ticks"] = [
        {
            "time_msc": open_time * 1_000 + index,
            "bid": mid,
            "ask": mid,
            "last": 999.0,
            "instrument_id": bar.get("instrument_id"),
            "source_id": bar.get("source_id"),
        }
        for index, mid in enumerate(mids)
    ]


def _ratio_mids(direction: str, *, threshold: bool = True) -> list[float]:
    if threshold:
        values = [100.0, 101.0, 102.0, 101.0, 102.0, 101.0]
    else:
        values = [100.0, 101.0, 100.0]
    return values if direction == "long" else list(reversed(values))


def build_variant_case(variant: str, direction: str, *, gate_pass: bool = True) -> dict[str, object]:
    family = variant[:4]
    start = 87_301
    bars = [
        _bar(start + i * 300, 105.0, 105.5, 104.5, 105.0)
        for i in range(20)
    ]
    is_long = direction == "long"
    level = int(variant[-2:])
    activity = 150 if gate_pass or level == 0 else 149
    evidence_direction = (
        ("short" if is_long else "long") if family == "OFPR" else direction
    )
    required_mids = _ratio_mids(evidence_direction, threshold=gate_pass)
    wrong_mids = _ratio_mids(
        "short" if evidence_direction == "long" else "long", threshold=True
    )

    if family == "OFPR":
        if is_long:
            test = _bar(start + 20 * 300, 100.3, 100.8, 99.7, 100.4,
                        tick_volume=activity, mids=required_mids if level == 2 else wrong_mids)
            trigger = _bar(start + 21 * 300, 100.5, 101.0, 100.2, 100.9)
            context_close = 105.0
            bid, ask = 100.85, 100.90
        else:
            test = _bar(start + 20 * 300, 109.7, 110.3, 109.2, 109.6,
                        tick_volume=activity, mids=required_mids if level == 2 else wrong_mids)
            trigger = _bar(start + 21 * 300, 109.5, 109.8, 109.0, 109.1)
            context_close = 105.0
            bid, ask = 109.10, 109.15
        if level == 0 and not gate_pass:
            if is_long:
                test["low"] = 100.3  # no overlap with the frozen VAL zone
            else:
                test["high"] = 109.7  # no overlap with the frozen VAH zone
        bars.extend([test, trigger])
    else:
        if is_long:
            first = _bar(start + 20 * 300, 110.0, 110.5, 109.9, 110.3)
            second = _bar(start + 21 * 300, 110.2, 110.6, 110.1, 110.4,
                          tick_volume=activity, mids=required_mids if level == 2 else wrong_mids)
            retest = _bar(start + 22 * 300, 110.3, 110.4, 109.9, 110.1)
            confirm = _bar(start + 23 * 300, 110.2, 110.7, 110.1, 110.5,
                           mids=[100.0, 101.0] if level == 2 else wrong_mids)
            context_close = 111.0
            bid, ask = 110.45, 110.50
        else:
            first = _bar(start + 20 * 300, 100.0, 100.1, 99.5, 99.7)
            second = _bar(start + 21 * 300, 99.8, 99.9, 99.4, 99.6,
                          tick_volume=activity, mids=required_mids if level == 2 else wrong_mids)
            retest = _bar(start + 22 * 300, 99.7, 100.1, 99.6, 99.9)
            confirm = _bar(start + 23 * 300, 99.8, 99.9, 99.3, 99.5,
                           mids=[101.0, 100.0] if level == 2 else wrong_mids)
            context_close = 99.0
            bid, ask = 99.50, 99.55
        if level == 0 and not gate_pass:
            second["close"] = 110.0 if is_long else 100.0
            second["high"] = max(float(second["high"]), float(second["close"]))
            second["low"] = min(float(second["low"]), float(second["close"]))
        bars.extend([first, second, retest, confirm])

    final_close = int(bars[-1]["close_time"])
    case = {
        "variant": variant,
        "labels": {
            "data_identity": "MT5_ACTIVITY_QUOTE_PROXY",
            "profile_identity": "TICK_ACTIVITY_PROFILE",
            "imbalance_identity": "QUOTE_DIRECTION_IMBALANCE_PROXY",
            "session_id": "MT5_BROKER_D1_BAR_V1",
        },
        "profile": {
            "record_id": "profile-1",
            "session_start": 1,
            "session_end": 86_401,
            "available_at": 86_401,
            "completed": True,
            "val": 100.0,
            "poc": 105.0,
            "vah": 110.0,
        },
        "contexts": [{
            "record_id": "m15-1",
            "open_time": 86_401,
            "close_time": 87_301,
            "available_at": 87_301,
            "period_seconds": 900,
            "completed": True,
            "close": context_close,
        }],
        "bars": bars,
        "quote": {
            "record_id": "quote-1",
            "observed_at": final_close + 1,
            "available_at": final_close + 1,
            "bid": bid,
            "ask": ask,
            "all_in_cost_price": 0.0,
        },
        "evaluation_time": final_close + 2,
    }
    return _bind_case_provenance(case)


def _bind_case_provenance(case: dict[str, object]) -> dict[str, object]:
    instrument_id = "XAUUSD.fixture"
    source_id = "fixture-source-1"
    labels = case["labels"]
    assert isinstance(labels, dict)
    labels["signal_instrument_id"] = instrument_id
    labels["signal_source_id"] = source_id

    profile = case["profile"]
    assert isinstance(profile, dict)
    profile.update({
        "instrument_id": instrument_id,
        "source_id": source_id,
        "previous_d1_record_id": "d1-100",
        "previous_d1_sequence": 100,
        "previous_d1_open_time": profile["session_start"],
        "current_d1_record_id": "d1-101",
        "current_d1_sequence": 101,
        "current_d1_open_time": profile["session_end"],
    })

    for record in [*case["contexts"], *case["bars"], case["quote"]]:
        record.update({
            "instrument_id": instrument_id,
            "source_id": source_id,
            "d1_record_id": "d1-101",
            "d1_sequence": 101,
            "d1_open_time": profile["session_end"],
        })
    for bar in case["bars"]:
        for tick in bar["quote_ticks"]:
            tick["instrument_id"] = instrument_id
            tick["source_id"] = source_id
    return case


def _build_tick_activity_profile(
    ticks: list[dict[str, object]],
    *,
    session_start_msc: int,
    session_end_msc: int,
    trade_tick_size: float,
    point: float,
) -> dict[str, object]:
    instrument_id = "XAUUSD.fixture"
    source_id = "fixture-source-1"
    bound_ticks = copy.deepcopy(ticks)
    for tick in bound_ticks:
        tick["instrument_id"] = instrument_id
        tick["source_id"] = source_id
    previous_d1 = {
        "record_id": "d1-100",
        "sequence": 100,
        "open_time_msc": session_start_msc,
        "available_at_msc": session_end_msc,
        "completed": True,
        "instrument_id": instrument_id,
        "source_id": source_id,
    }
    current_d1 = {
        "record_id": "d1-101",
        "sequence": 101,
        "open_time_msc": session_end_msc,
        "available_at_msc": session_end_msc,
        "completed": False,
        "instrument_id": instrument_id,
        "source_id": source_id,
    }
    return proxy.build_tick_activity_profile(
        bound_ticks,
        previous_d1=previous_d1,
        current_d1=current_d1,
        available_at_msc=session_end_msc,
        trade_tick_size=trade_tick_size,
        point=point,
    )


class TickActivityProfileTests(unittest.TestCase):
    def test_lower_price_bin_wins_exact_poc_tie(self) -> None:
        ticks = [
            {"time_msc": 1_000, "bid": 100.0, "ask": 100.0, "last": 999.0},
            {"time_msc": 2_000, "bid": 101.0, "ask": 101.0, "last": 999.0},
        ]

        profile = _build_tick_activity_profile(
            ticks,
            session_start_msc=1_000,
            session_end_msc=3_000,
            trade_tick_size=1.0,
            point=0.1,
        )

        self.assertEqual(profile["profile_identity"], "TICK_ACTIVITY_PROFILE")
        self.assertEqual(profile["poc_bin_index"], 100)
        self.assertEqual(profile["poc"], 100.5)
        self.assertEqual(profile["total_activity"], 2)

    def test_equal_adjacent_counts_include_both_before_stopping(self) -> None:
        ticks = [
            {"time_msc": 1_000 + i, "bid": price, "ask": price}
            for i, price in enumerate([100.0, 100.0, 99.0, 101.0])
        ]

        profile = _build_tick_activity_profile(
            ticks,
            session_start_msc=1_000,
            session_end_msc=2_000,
            trade_tick_size=1.0,
            point=0.1,
        )

        self.assertEqual(profile["included_bin_indices"], [99, 100, 101])
        self.assertEqual(profile["value_area_activity"], 4)
        self.assertEqual(profile["val"], 99.0)
        self.assertEqual(profile["vah"], 102.0)

    def test_point_is_used_only_when_trade_tick_size_is_not_positive(self) -> None:
        profile = _build_tick_activity_profile(
            [{"time_msc": 1_000, "bid": 1.234, "ask": 1.234}],
            session_start_msc=1_000,
            session_end_msc=2_000,
            trade_tick_size=0.0,
            point=0.001,
        )
        self.assertEqual(profile["bin_size_source"], "SYMBOL_POINT")
        self.assertEqual(profile["bin_size"], 0.001)

        with self.assertRaisesRegex(proxy.ProxyContractError, "NO_POSITIVE_BIN_SIZE"):
            _build_tick_activity_profile(
                [{"time_msc": 1_000, "bid": 1.0, "ask": 1.0}],
                session_start_msc=1_000,
                session_end_msc=2_000,
                trade_tick_size=0.0,
                point=0.0,
            )

    def test_invalid_bid_ask_is_not_replaced_by_last(self) -> None:
        ticks = [
            {"time_msc": 1_000, "bid": math.nan, "ask": 100.0, "last": 100.0},
            {"time_msc": 1_001, "bid": 0.0, "ask": 100.0, "last": 100.0},
        ]
        with self.assertRaisesRegex(proxy.ProxyContractError, "NO_QUALIFYING_QUOTE_TICKS"):
            _build_tick_activity_profile(
                ticks,
                session_start_msc=1_000,
                session_end_msc=2_000,
                trade_tick_size=1.0,
                point=0.1,
            )

    def test_session_is_half_open_and_does_not_leak_next_d1_tick(self) -> None:
        profile = _build_tick_activity_profile(
            [
                {"time_msc": 1_000, "bid": 100.0, "ask": 100.0},
                {"time_msc": 2_000, "bid": 999.0, "ask": 999.0},
            ],
            session_start_msc=1_000,
            session_end_msc=2_000,
            trade_tick_size=1.0,
            point=0.1,
        )
        self.assertEqual(profile["total_activity"], 1)
        self.assertEqual(profile["poc_bin_index"], 100)
        self.assertEqual(profile["poc"], 100.5)

    def test_profile_refuses_interval_without_adjacent_d1_identity(self) -> None:
        ticks = [{
            "time_msc": 1_000,
            "bid": 100.0,
            "ask": 100.0,
            "instrument_id": "XAUUSD.fixture",
            "source_id": "fixture-source-1",
        }]
        previous_d1 = {
            "record_id": "d1-100",
            "sequence": 100,
            "open_time_msc": 1_000,
            "available_at_msc": 2_000,
            "completed": True,
            "instrument_id": "XAUUSD.fixture",
            "source_id": "fixture-source-1",
        }
        current_d1 = {
            "record_id": "d1-102",
            "sequence": 102,
            "open_time_msc": 2_000,
            "available_at_msc": 2_000,
            "completed": False,
            "instrument_id": "XAUUSD.fixture",
            "source_id": "fixture-source-1",
        }
        with self.assertRaisesRegex(proxy.ProxyContractError, "NON_ADJACENT_D1_RECORDS"):
            proxy.build_tick_activity_profile(
                ticks,
                previous_d1=previous_d1,
                current_d1=current_d1,
                available_at_msc=2_000,
                trade_tick_size=1.0,
                point=0.1,
            )


class CompletedBarProxyMetricTests(unittest.TestCase):
    def test_relative_activity_uses_previous_twenty_completed_bars_only(self) -> None:
        bars = [{"tick_volume": 100, "completed": True} for _ in range(20)]
        bars.append({"tick_volume": 150, "completed": True})
        self.assertTrue(proxy.relative_activity_passes(bars, 20))
        bars[20]["tick_volume"] = 149
        self.assertFalse(proxy.relative_activity_passes(bars, 20))

    def test_activity_refuses_warmup_or_incomplete_bar(self) -> None:
        with self.assertRaisesRegex(proxy.ProxyContractError, "PREVIOUS20_REQUIRED"):
            proxy.relative_activity_passes(
                [{"tick_volume": 100, "completed": True} for _ in range(20)], 19
            )
        bars = [{"tick_volume": 100, "completed": True} for _ in range(21)]
        bars[20]["completed"] = False
        with self.assertRaisesRegex(proxy.ProxyContractError, "COMPLETED_M5_REQUIRED"):
            proxy.relative_activity_passes(bars, 20)

    def test_zero_previous20_median_does_not_create_free_activity_pass(self) -> None:
        bars = [{"tick_volume": 0, "completed": True} for _ in range(20)]
        bars.append({"tick_volume": 0, "completed": True})
        self.assertFalse(proxy.relative_activity_passes(bars, 20))

    def test_quote_direction_imbalance_counts_strict_moves_and_ignores_unchanged(self) -> None:
        result = proxy.quote_direction_imbalance([100.0, 101.0, 101.0, 100.0, 102.0])
        self.assertEqual(result["up_count"], 2)
        self.assertEqual(result["down_count"], 1)
        self.assertEqual(result["unchanged_count"], 1)
        self.assertAlmostEqual(result["ratio"], 1.0 / 3.0)
        self.assertEqual(result["imbalance_identity"], "QUOTE_DIRECTION_IMBALANCE_PROXY")

    def test_quote_direction_imbalance_refuses_zero_denominator(self) -> None:
        with self.assertRaisesRegex(proxy.ProxyContractError, "QUOTE_IMBALANCE_DENOMINATOR_ZERO"):
            proxy.quote_direction_imbalance([100.0, 100.0, 100.0])

    def test_proxy_contract_rejects_true_orderflow_or_delta_labels(self) -> None:
        valid = {
            "data_identity": "MT5_ACTIVITY_QUOTE_PROXY",
            "profile_identity": "TICK_ACTIVITY_PROFILE",
            "imbalance_identity": "QUOTE_DIRECTION_IMBALANCE_PROXY",
            "session_id": "MT5_BROKER_D1_BAR_V1",
            "signal_instrument_id": "XAUUSD.fixture",
            "signal_source_id": "fixture-source-1",
        }
        proxy.validate_proxy_labels(valid)
        for key, forbidden in (
            ("data_identity", "TRUE_ORDERFLOW"),
            ("profile_identity", "EXECUTED_VOLUME_PROFILE"),
            ("imbalance_identity", "DELTA"),
        ):
            bad = dict(valid)
            bad[key] = forbidden
            with self.assertRaisesRegex(proxy.ProxyContractError, "PROXY_LABEL_REQUIRED"):
                proxy.validate_proxy_labels(bad)


class SixVariantMechanicsTests(unittest.TestCase):
    def test_all_six_variants_are_mirrored_and_emit_proxy_only_geometry(self) -> None:
        for variant in ("OFPR-00", "OFPR-01", "OFPR-02", "OFPC-00", "OFPC-01", "OFPC-02"):
            for direction, expected_direction in (("long", 1), ("short", -1)):
                with self.subTest(variant=variant, direction=direction):
                    result = proxy.evaluate_variant(build_variant_case(variant, direction))
                    self.assertEqual(result["status"], "SIGNAL")
                    self.assertEqual(result["variant"], variant)
                    self.assertEqual(result["geometry"]["direction"], expected_direction)
                    self.assertTrue(result["geometry"]["prospective_quote_not_fill"])
                    self.assertFalse(result["geometry"]["fill_simulated"])
                    self.assertEqual(result["data_identity"], "MT5_ACTIVITY_QUOTE_PROXY")
                    self.assertNotIn("TRUE_ORDERFLOW", str(result))

    def test_each_variant_has_a_negative_mechanics_or_one_change_gate_case(self) -> None:
        for variant in ("OFPR-00", "OFPR-01", "OFPR-02", "OFPC-00", "OFPC-01", "OFPC-02"):
            for direction in ("long", "short"):
                with self.subTest(variant=variant, direction=direction):
                    result = proxy.evaluate_variant(
                        build_variant_case(variant, direction, gate_pass=False)
                    )
                    self.assertEqual(result["status"], "NO_SIGNAL")

    def test_p0_ignores_activity_and_quote_imbalance(self) -> None:
        for variant in ("OFPR-00", "OFPC-00"):
            case = build_variant_case(variant, "long")
            gate_index = 20 if variant == "OFPR-00" else 21
            case["bars"][gate_index]["tick_volume"] = 0
            _set_bar_mids(case["bars"][gate_index], [100.0, 99.0])
            self.assertEqual(proxy.evaluate_variant(case)["status"], "SIGNAL")

    def test_p1_adds_activity_but_not_quote_imbalance(self) -> None:
        for variant in ("OFPR-01", "OFPC-01"):
            case = build_variant_case(variant, "long")
            gate_index = 20 if variant == "OFPR-01" else 21
            _set_bar_mids(case["bars"][gate_index], [100.0, 99.0])
            self.assertEqual(proxy.evaluate_variant(case)["status"], "SIGNAL")
            case["bars"][gate_index]["tick_volume"] = 149
            self.assertEqual(proxy.evaluate_variant(case)["status"], "NO_SIGNAL")

    def test_p2_thresholds_are_inclusive_but_confirmation_is_strict(self) -> None:
        for variant in ("OFPR-02", "OFPC-02"):
            self.assertEqual(
                proxy.evaluate_variant(build_variant_case(variant, "long"))["status"],
                "SIGNAL",
            )
        case = build_variant_case("OFPC-02", "long")
        _set_bar_mids(case["bars"][-1], [100.0, 101.0, 100.0])
        self.assertEqual(proxy.evaluate_variant(case)["status"], "NO_SIGNAL")

    def test_forming_bar_is_rejected(self) -> None:
        case = build_variant_case("OFPR-00", "long")
        case["bars"][-1]["completed"] = False
        with self.assertRaisesRegex(proxy.ProxyContractError, "COMPLETED_M5_REQUIRED"):
            proxy.evaluate_variant(case)

    def test_future_context_is_not_copied_backward(self) -> None:
        case = build_variant_case("OFPR-00", "long")
        case["contexts"][0]["available_at"] = case["bars"][-1]["available_at"]
        result = proxy.evaluate_variant(case)
        self.assertEqual(result["status"], "NO_SIGNAL")

    def test_quote_after_current_bar_boundary_is_rejected(self) -> None:
        case = build_variant_case("OFPR-00", "long")
        case["evaluation_time"] = case["bars"][-1]["close_time"] + 300
        case["quote"]["observed_at"] = case["evaluation_time"]
        case["quote"]["available_at"] = case["evaluation_time"]
        with self.assertRaisesRegex(proxy.ProxyContractError, "DECISION_WINDOW_MISSING_CLOSED_BAR"):
            proxy.evaluate_variant(case)

    def test_duplicate_or_overlapping_m5_history_fails_closed(self) -> None:
        duplicate = build_variant_case("OFPR-00", "long")
        duplicate["bars"][1]["record_id"] = duplicate["bars"][0]["record_id"]
        with self.assertRaisesRegex(proxy.ProxyContractError, "DUPLICATE_OR_MISSING_M5_RECORD_ID"):
            proxy.evaluate_variant(duplicate)

        overlap = build_variant_case("OFPR-00", "long")
        overlap["bars"][1]["open_time"] = overlap["bars"][0]["close_time"] - 1
        overlap["bars"][1]["close_time"] = overlap["bars"][1]["open_time"] + 300
        overlap["bars"][1]["available_at"] = overlap["bars"][1]["close_time"]
        with self.assertRaisesRegex(proxy.ProxyContractError, "INVALID_OR_NONCAUSAL_M5_BAR"):
            proxy.evaluate_variant(overlap)

    def test_p2_refuses_zero_directional_move_denominator(self) -> None:
        case = build_variant_case("OFPR-02", "long")
        _set_bar_mids(case["bars"][20], [100.0, 100.0, 100.0])
        with self.assertRaisesRegex(proxy.ProxyContractError, "QUOTE_IMBALANCE_DENOMINATOR_ZERO"):
            proxy.evaluate_variant(case)

    def test_quote_tick_at_bar_close_is_excluded_from_bar_imbalance(self) -> None:
        case = build_variant_case("OFPR-02", "long")
        test_bar = case["bars"][20]
        test_bar["quote_ticks"] = [
            {"time_msc": test_bar["open_time"] * 1_000, "bid": 100.0, "ask": 100.0,
             "instrument_id": test_bar["instrument_id"], "source_id": test_bar["source_id"]},
            {"time_msc": test_bar["open_time"] * 1_000 + 1, "bid": 99.0, "ask": 99.0,
             "instrument_id": test_bar["instrument_id"], "source_id": test_bar["source_id"]},
            {
                "time_msc": test_bar["close_time"] * 1_000,
                "bid": 1_000.0,
                "ask": 1_000.0,
                "instrument_id": test_bar["instrument_id"],
                "source_id": test_bar["source_id"],
            },
        ]
        self.assertEqual(proxy.evaluate_variant(case)["status"], "SIGNAL")

    def test_future_bar_cannot_change_previous20_activity_threshold(self) -> None:
        case = build_variant_case("OFPR-01", "long")
        case["bars"][20]["tick_volume"] = 149
        future = copy.deepcopy(case["bars"][-1])
        future["tick_volume"] = 10_000_000
        self.assertFalse(proxy.relative_activity_passes(case["bars"] + [future], 20))

    def test_ofpr_replay_continues_after_earlier_expiry_to_current_signal(self) -> None:
        case = _bind_case_provenance(build_variant_case("OFPR-00", "long"))
        case["bars"][15].update({
            "open": 100.3,
            "high": 106.0,
            "low": 96.5,
            "close": 100.4,
        })
        result = proxy.evaluate_variant(case)
        self.assertEqual(result["status"], "SIGNAL", result)
        self.assertEqual(result["geometry"]["setup_time"], case["bars"][20]["close_time"])

    def test_ofpc_replay_continues_after_earlier_cancellation_to_current_signal(self) -> None:
        case = _bind_case_provenance(build_variant_case("OFPC-00", "long"))
        case["bars"][15].update({"open": 110.0, "high": 110.5, "low": 109.9, "close": 110.3})
        case["bars"][16].update({"open": 110.2, "high": 110.6, "low": 110.1, "close": 110.4})
        case["bars"][17].update({"open": 110.3, "high": 110.4, "low": 109.9, "close": 110.1})
        case["bars"][18].update({"open": 109.5, "high": 109.7, "low": 108.8, "close": 109.0})
        case["bars"][20].update({"open": 110.3, "high": 110.8, "low": 110.2, "close": 110.6})
        case["bars"][21].update({"open": 110.5, "high": 110.9, "low": 110.4, "close": 110.7})
        case["bars"][22].update({"open": 110.4, "high": 110.6, "low": 109.9, "close": 110.2})
        case["bars"][23].update({"open": 110.5, "high": 111.0, "low": 110.1, "close": 110.8})
        case["quote"]["bid"] = 110.75
        case["quote"]["ask"] = 110.80
        result = proxy.evaluate_variant(case)
        self.assertEqual(result["status"], "SIGNAL", result)
        self.assertEqual(result["geometry"]["setup_time"], case["bars"][21]["close_time"])

    def test_cross_symbol_chronology_is_rejected(self) -> None:
        case = _bind_case_provenance(build_variant_case("OFPR-00", "long"))
        case["bars"][-1]["instrument_id"] = "EURUSD.fixture"
        with self.assertRaisesRegex(proxy.ProxyContractError, "CROSS_INSTRUMENT_OR_SOURCE"):
            proxy.evaluate_variant(case)

    def test_stale_profile_session_is_rejected(self) -> None:
        case = _bind_case_provenance(build_variant_case("OFPR-00", "long"))
        case["bars"][-1]["d1_record_id"] = "d1-102"
        case["bars"][-1]["d1_sequence"] = 102
        with self.assertRaisesRegex(proxy.ProxyContractError, "STALE_OR_MIXED_D1_SESSION"):
            proxy.evaluate_variant(case)

    def test_overlapping_d1_boundary_is_rejected(self) -> None:
        case = _bind_case_provenance(build_variant_case("OFPR-00", "long"))
        case["profile"]["current_d1_open_time"] = case["profile"]["session_start"]
        with self.assertRaisesRegex(proxy.ProxyContractError, "INVALID_D1_BOUNDARY"):
            proxy.evaluate_variant(case)


class AvailabilityAuditReferenceTests(unittest.TestCase):
    FIXTURE_BASIS = "FIXTURE_EXACT_NATIVE_EVENT_COUNT"
    UNQUALIFIED_BASIS = "UNQUALIFIED_COPY_TICKS_ALL_VS_MQLRATES_TICK_VOLUME"

    def _records(self, *, tick_volume: int = 2) -> tuple[dict, dict, list[dict]]:
        prior_d1 = {
            "record_id": "d1-100",
            "sequence": 100,
            "open_time": 1,
            "tick_volume": tick_volume,
            "instrument_id": "EURUSD.fixture",
            "source_id": "fixture.source",
        }
        current_d1 = {
            "record_id": "d1-101",
            "sequence": 101,
            "open_time": 86_401,
            "tick_volume": tick_volume,
            "instrument_id": "EURUSD.fixture",
            "source_id": "fixture.source",
        }
        completed_m5 = [
            {
                "record_id": f"m5-{index}",
                "sequence": 200 + index,
                "open_time": 90_000 + index * 300,
                "tick_volume": tick_volume,
                "instrument_id": "EURUSD.fixture",
                "source_id": "fixture.source",
            }
            for index in range(21)
        ]
        return prior_d1, current_d1, completed_m5

    def _copy(
        self,
        start: int,
        end: int,
        mids: list[float],
        *,
        expected: int = 2,
        returned: int | float | bool | None = None,
        array_size: int | float | bool | None = None,
        last_error: int | float | bool = 0,
        count_basis: str | None = None,
        record_class: str = "FIXTURE",
        rate_snapshot_stable: bool = True,
        synchronized_before: bool = True,
        synchronized_after: bool = True,
        instrument_id: str = "EURUSD.fixture",
        source_id: str = "fixture.source",
    ) -> dict:
        returned_count = len(mids) if returned is None else returned
        copied_array_size = len(mids) if array_size is None else array_size
        span = max(1, end * 1000 - start * 1000)
        ticks = [
            {
                "time_msc": start * 1000 + min(index + 1, span - 1),
                "mid": mid,
                "instrument_id": instrument_id,
                "source_id": source_id,
            }
            for index, mid in enumerate(mids)
        ]
        return {
            "record_class": record_class,
            "count_basis": count_basis or self.FIXTURE_BASIS,
            "interval_start_msc": start * 1000,
            "interval_end_msc": end * 1000,
            "expected_native_count": expected,
            "returned_count": returned_count,
            "array_size": copied_array_size,
            "last_error": last_error,
            "rate_snapshot_stable": rate_snapshot_stable,
            "series_synchronized_before": synchronized_before,
            "series_synchronized_after": synchronized_after,
            "instrument_id": instrument_id,
            "source_id": source_id,
            "ticks": ticks,
        }

    def _qualified_inputs(self) -> tuple[dict, dict, list[dict], dict, list[dict]]:
        prior_d1, current_d1, completed_m5 = self._records()
        profile = self._copy(1, 86_401, [100.0, 101.0])
        copies = [
            self._copy(bar["open_time"], bar["open_time"] + 300, [100.0, 101.0])
            for bar in completed_m5
        ]
        return prior_d1, current_d1, completed_m5, profile, copies

    def _classify(self, **changes: object) -> dict:
        prior_d1, current_d1, completed_m5, profile, copies = self._qualified_inputs()
        values = {
            "prior_d1": prior_d1,
            "current_d1": current_d1,
            "profile_tick_mids": None,
            "completed_m5": completed_m5,
            "ticks_by_bar": [None] * 21,
            "bin_size_available": True,
            "profile_copy_evidence": profile,
            "m5_copy_evidence": copies,
        }
        values.update(changes)
        return proxy.classify_availability_audit(**values)

    def test_naked_lists_are_data_presence_not_completion_evidence(self) -> None:
        prior_d1, current_d1, completed_m5 = self._records(tick_volume=1)
        result = proxy.classify_availability_audit(
            prior_d1=prior_d1,
            current_d1=current_d1,
            profile_tick_mids=[100.0],
            completed_m5=completed_m5,
            ticks_by_bar=[[100.0, 101.0]] * 21,
            bin_size_available=True,
        )
        self.assertEqual(result["capability"], "BLOCKED_DATA")
        self.assertEqual(result["raw_observed_capability"], "P2_PREREQUISITES_OBSERVED_UNQUALIFIED")
        self.assertIn("PROFILE_COMPLETION_EVIDENCE_MISSING", result["blockers"])
        self.assertIn("M5_COMPLETION_EVIDENCE_MISSING", result["blockers"])

    def test_twenty_empty_copies_plus_directional_candidate_is_blocked(self) -> None:
        prior_d1, current_d1, completed_m5, profile, copies = self._qualified_inputs()
        copies = [
            self._copy(bar["open_time"], bar["open_time"] + 300, [], expected=2)
            for bar in completed_m5[:-1]
        ] + [copies[-1]]
        result = self._classify(m5_copy_evidence=copies)
        self.assertEqual(result["capability"], "BLOCKED_DATA")
        self.assertEqual(result["candidate_directional_denominator"], 1)
        self.assertEqual(result["m5_complete_intervals"], 1)
        self.assertEqual(result["m5_refused_intervals"], 20)
        self.assertEqual(result["m5_interval_receipts"][0]["reason"], "COPY_COUNT_UNDER_EXPECTED")

    def test_partial_d1_copy_is_blocked_with_counts(self) -> None:
        prior_d1, current_d1, completed_m5, profile, copies = self._qualified_inputs()
        profile = self._copy(1, 86_401, [100.0], expected=2)
        result = self._classify(profile_copy_evidence=profile)
        receipt = result["profile_interval_receipt"]
        self.assertEqual(result["capability"], "BLOCKED_DATA")
        self.assertEqual(receipt["expected_native_count"], 2)
        self.assertEqual(receipt["returned_count"], 1)
        self.assertEqual(receipt["reason"], "COPY_COUNT_UNDER_EXPECTED")

    def test_positive_count_with_error_is_blocked(self) -> None:
        prior_d1, current_d1, completed_m5, profile, copies = self._qualified_inputs()
        copies[-1] = self._copy(
            completed_m5[-1]["open_time"],
            completed_m5[-1]["open_time"] + 300,
            [100.0, 101.0],
            last_error=4403,
        )
        result = self._classify(m5_copy_evidence=copies)
        self.assertEqual(result["capability"], "BLOCKED_DATA")
        self.assertEqual(result["m5_interval_receipts"][-1]["reason"], "COPY_ERROR_4403")

    def test_excess_copy_is_blocked(self) -> None:
        prior_d1, current_d1, completed_m5, profile, copies = self._qualified_inputs()
        copies[5] = self._copy(
            completed_m5[5]["open_time"],
            completed_m5[5]["open_time"] + 300,
            [100.0, 101.0, 102.0],
            expected=2,
        )
        result = self._classify(m5_copy_evidence=copies)
        self.assertEqual(result["m5_interval_receipts"][5]["reason"], "COPY_COUNT_OVER_EXPECTED")

    def test_count_array_disagreement_is_blocked(self) -> None:
        prior_d1, current_d1, completed_m5, profile, copies = self._qualified_inputs()
        copies[4]["array_size"] = 1
        result = self._classify(m5_copy_evidence=copies)
        self.assertEqual(result["m5_interval_receipts"][4]["reason"], "COPY_COUNT_ARRAY_DISAGREEMENT")

    def test_malformed_count_fields_are_rejected(self) -> None:
        malformed = (True, -1, 1.5, float("inf"))
        for field in ("expected_native_count", "returned_count", "array_size", "last_error"):
            for value in malformed:
                with self.subTest(field=field, value=value):
                    prior_d1, current_d1, completed_m5, profile, copies = self._qualified_inputs()
                    copies[0][field] = value
                    result = self._classify(m5_copy_evidence=copies)
                    self.assertEqual(result["m5_interval_receipts"][0]["reason"], f"MALFORMED_{field.upper()}")

    def test_malformed_time_fields_and_records_are_rejected(self) -> None:
        malformed = (True, -1, 1.5, float("inf"))
        for field in ("interval_start_msc", "interval_end_msc"):
            for value in malformed:
                with self.subTest(field=field, value=value):
                    prior_d1, current_d1, completed_m5, profile, copies = self._qualified_inputs()
                    copies[0][field] = value
                    result = self._classify(m5_copy_evidence=copies)
                    self.assertEqual(result["m5_interval_receipts"][0]["reason"], f"MALFORMED_{field.upper()}")
        prior_d1, current_d1, completed_m5, profile, copies = self._qualified_inputs()
        copies[0]["ticks"][0] = "not-a-tick-record"
        result = self._classify(m5_copy_evidence=copies)
        self.assertEqual(result["m5_interval_receipts"][0]["reason"], "MALFORMED_TICK_RECORD")

    def test_boundary_nonmonotonic_out_of_window_and_price_fail_closed(self) -> None:
        mutations = {
            "INTERVAL_BOUNDARY_MISMATCH": lambda item: item.__setitem__("interval_end_msc", item["interval_end_msc"] + 1),
            "NONMONOTONIC_TICK_TIMESTAMPS": lambda item: item["ticks"].reverse(),
            "TICK_OUTSIDE_INTERVAL": lambda item: item["ticks"][0].__setitem__("time_msc", item["interval_end_msc"]),
            "INVALID_TICK_PRICE": lambda item: item["ticks"][0].__setitem__("mid", 0.0),
        }
        for reason, mutate in mutations.items():
            with self.subTest(reason=reason):
                prior_d1, current_d1, completed_m5, profile, copies = self._qualified_inputs()
                mutate(copies[3])
                result = self._classify(m5_copy_evidence=copies)
                self.assertEqual(result["m5_interval_receipts"][3]["reason"], reason)

    def test_wrong_source_or_symbol_fails_closed(self) -> None:
        for field, value in (("instrument_id", "GBPUSD.fixture"), ("source_id", "other.source")):
            with self.subTest(field=field):
                prior_d1, current_d1, completed_m5, profile, copies = self._qualified_inputs()
                copies[2]["ticks"][0][field] = value
                result = self._classify(m5_copy_evidence=copies)
                self.assertEqual(result["m5_interval_receipts"][2]["reason"], "COPY_PROVENANCE_MISMATCH")

    def test_changed_snapshot_and_unsynchronized_interval_fail_closed(self) -> None:
        for field, reason in (
            ("rate_snapshot_stable", "RATE_SNAPSHOT_CHANGED"),
            ("series_synchronized_before", "SERIES_UNSYNCHRONIZED_BEFORE"),
            ("series_synchronized_after", "SERIES_UNSYNCHRONIZED_AFTER"),
        ):
            with self.subTest(field=field):
                prior_d1, current_d1, completed_m5, profile, copies = self._qualified_inputs()
                copies[1][field] = False
                result = self._classify(m5_copy_evidence=copies)
                self.assertEqual(result["m5_interval_receipts"][1]["reason"], reason)

    def test_duplicate_record_identity_is_blocked(self) -> None:
        prior_d1, current_d1, completed_m5, profile, copies = self._qualified_inputs()
        completed_m5[10]["record_id"] = completed_m5[9]["record_id"]
        result = self._classify(completed_m5=completed_m5)
        self.assertEqual(result["capability"], "BLOCKED_DATA")
        self.assertIn("M5_WINDOW_INVALID", result["blockers"])

    def test_missing_interval_receipt_is_blocked(self) -> None:
        prior_d1, current_d1, completed_m5, profile, copies = self._qualified_inputs()
        result = self._classify(m5_copy_evidence=copies[:-1])
        self.assertEqual(result["capability"], "BLOCKED_DATA")
        self.assertIn("M5_COMPLETION_EVIDENCE_MISSING", result["blockers"])

    def test_fixture_exact_count_basis_exercises_positive_complete_branch(self) -> None:
        result = self._classify()
        self.assertEqual(result["capability"], "P2_READY")
        self.assertTrue(result["profile_interval_receipt"]["complete"])
        self.assertEqual(result["m5_complete_intervals"], 21)
        self.assertEqual(result["m5_refused_intervals"], 0)

    def test_constant_price_history_is_complete_and_candidate_direction_is_separate(self) -> None:
        prior_d1, current_d1, completed_m5, profile, copies = self._qualified_inputs()
        copies = [
            self._copy(bar["open_time"], bar["open_time"] + 300, [100.0, 100.0])
            for bar in completed_m5[:-1]
        ] + [copies[-1]]
        result = self._classify(m5_copy_evidence=copies)
        self.assertEqual(result["capability"], "P2_READY")
        self.assertEqual(result["m5_complete_intervals"], 21)
        self.assertEqual(result["history_zero_direction_intervals"], 20)

    def test_constant_price_candidate_is_complete_but_not_p2_directional(self) -> None:
        prior_d1, current_d1, completed_m5, profile, copies = self._qualified_inputs()
        copies[-1] = self._copy(
            completed_m5[-1]["open_time"], completed_m5[-1]["open_time"] + 300, [100.0, 100.0]
        )
        result = self._classify(m5_copy_evidence=copies)
        self.assertEqual(result["capability"], "P1_READY")
        self.assertEqual(result["candidate_directional_denominator"], 0)
        self.assertTrue(result["m5_interval_receipts"][-1]["complete"])

    def test_unqualified_real_count_basis_never_certifies_completeness(self) -> None:
        prior_d1, current_d1, completed_m5, profile, copies = self._qualified_inputs()
        profile["record_class"] = "OBSERVATION"
        profile["count_basis"] = self.UNQUALIFIED_BASIS
        for item in copies:
            item["record_class"] = "OBSERVATION"
            item["count_basis"] = self.UNQUALIFIED_BASIS
        result = self._classify(profile_copy_evidence=profile, m5_copy_evidence=copies)
        self.assertEqual(result["capability"], "BLOCKED_DATA")
        self.assertEqual(result["raw_observed_capability"], "P2_PREREQUISITES_OBSERVED_UNQUALIFIED")
        self.assertTrue(result["profile_interval_receipt"]["count_consistent"])
        self.assertFalse(result["profile_interval_receipt"]["complete"])
        self.assertEqual(result["profile_interval_receipt"]["reason"], "COUNT_BASIS_UNQUALIFIED")
        self.assertIn("COMPLETENESS_UNQUALIFIED", result["blockers"])


class FixtureReplayTests(unittest.TestCase):
    def test_mirrored_positive_negative_fixture_replay(self) -> None:
        fixture = ROOT / "tools" / "orderflow_proxy" / "fixtures" / "mirrored_cases.json"
        summary = proxy.replay_fixture(fixture, expected_class="FIXTURE")
        self.assertEqual(summary["case_count"], 24)
        self.assertEqual(summary["passed"], 24)
        self.assertEqual(summary["failed"], 0)
        self.assertEqual(set(summary["variant_counts"]), set(proxy.VARIANTS))


if __name__ == "__main__":
    unittest.main()
