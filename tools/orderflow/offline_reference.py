#!/usr/bin/env python3
"""Offline OF01/OF02 validator and deterministic replay reference.

This is a reference oracle for fixture/data-contract review.  It is not an
execution adapter, not proof of MQL runtime parity, and never opens orders.
"""

from __future__ import annotations

import argparse
import copy
import json
import math
import statistics
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


TRUE_ORDERFLOW = "TRUE_ORDERFLOW"
PRICE_ACTION_PROXY = "PRICE_ACTION_PROXY"
EXECUTED_ASK_BID = "EXECUTED_ASK_BID"
FIXTURE_SCHEMA = "orderflow_fixture/v1"
QUALIFIED_SCHEMA = "orderflow_qualified/v1"


class ContractError(ValueError):
    def __init__(self, code: str):
        super().__init__(code)
        self.code = code


def _finite(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def _required_text(record: dict[str, Any], names: tuple[str, ...]) -> None:
    if any(not isinstance(record.get(name), str) or not record[name] for name in names):
        raise ContractError("MISSING_REQUIRED_PIN")


def validate_contract(package: dict[str, Any], expected_class: str | None = None) -> None:
    schema_id = package.get("schema_id")
    record_class = package.get("record_class")
    synthetic = package.get("synthetic")
    contract = package.get("contract", {})
    policy = package.get("freshness_policy", {})

    if schema_id not in (FIXTURE_SCHEMA, QUALIFIED_SCHEMA):
        raise ContractError("UNKNOWN_SCHEMA")
    schema_class = "FIXTURE" if schema_id == FIXTURE_SCHEMA else "QUALIFIED"
    if record_class != schema_class or synthetic is not (schema_class == "FIXTURE"):
        raise ContractError("SCHEMA_RECORD_CLASS_CONTRADICTION")
    if expected_class is not None and record_class != expected_class:
        raise ContractError("RECORD_CLASS_MISMATCH")
    if schema_class == "QUALIFIED" and "history" in package:
        raise ContractError("QUALIFIED_DATA_CANNOT_USE_FIXTURE_GENERATOR")

    _required_text(
        contract,
        (
            "dataset_id",
            "source_id",
            "source_revision",
            "signal_instrument_id",
            "profile_instrument_id",
            "session_definition_id",
            "timezone_ruleset_id",
            "profile_algorithm_id",
            "value_area_algorithm_id",
            "volume_provenance_id",
        ),
    )
    if policy.get("required_record_class") != record_class:
        raise ContractError("RECORD_CLASS_MISMATCH")
    for name in (
        "max_m5_age_seconds",
        "max_m15_age_seconds",
        "max_profile_age_seconds",
        "max_quote_age_seconds",
    ):
        if not isinstance(policy.get(name), int) or policy[name] <= 0:
            raise ContractError("MISSING_EXPLICIT_FRESHNESS_POLICY")
    if schema_class == "QUALIFIED" and contract.get("source_qualified") is not True:
        raise ContractError("UNQUALIFIED_SOURCE")
    if contract.get("data_identity") != TRUE_ORDERFLOW:
        if contract.get("data_identity") == PRICE_ACTION_PROXY:
            raise ContractError("PROXY_NOT_TRUE_ORDERFLOW")
        raise ContractError("INVALID_DATA_IDENTITY")
    if contract.get("volume_provenance") != EXECUTED_ASK_BID:
        raise ContractError("EXECUTED_ASK_BID_REQUIRED")

    same_instrument = contract["signal_instrument_id"] == contract["profile_instrument_id"]
    if not same_instrument and not (
        contract.get("instrument_mapping_qualified") is True
        and isinstance(contract.get("instrument_mapping_id"), str)
        and contract["instrument_mapping_id"]
    ):
        raise ContractError("UNQUALIFIED_INSTRUMENT_MAPPING")
    if same_instrument and contract.get("instrument_mapping_qualified") is True and not contract.get(
        "instrument_mapping_id"
    ):
        raise ContractError("CONTRADICTORY_MAPPING_PIN")


def _validate_ohlc(record: dict[str, Any], prefix: str) -> None:
    values = [record.get(name) for name in ("open", "high", "low", "close")]
    if not all(_finite(value) and value > 0 for value in values):
        raise ContractError(f"INVALID_{prefix}_OHLC")
    open_, high, low, close = values
    if high < low or high < max(open_, close) or low > min(open_, close):
        raise ContractError(f"INVALID_{prefix}_OHLC")


def expand_case(package: dict[str, Any], case: dict[str, Any]) -> dict[str, Any]:
    expanded = {
        "schema_id": package["schema_id"],
        "record_class": package["record_class"],
        "synthetic": package["synthetic"],
        "contract": copy.deepcopy(package["contract"]),
        "freshness_policy": copy.deepcopy(package["freshness_policy"]),
        "profile": copy.deepcopy(package["profile"]),
        "component": case["component"],
        "case_id": case["id"],
        "expected": copy.deepcopy(case.get("expected", {})),
    }
    contract = expanded["contract"]
    history = package["history"]
    bars: list[dict[str, Any]] = []
    for index in range(history["count"]):
        open_time = history["start_time"] + index * 300
        bars.append(
            {
                "record_id": f"{case['id']}-history-{index + 1}",
                "source_revision": contract["source_revision"],
                "sequence": index + 1,
                "period_seconds": 300,
                "open_time": open_time,
                "close_time": open_time + 300,
                "available_at": open_time + 301,
                "completed": True,
                "open": history["open"],
                "high": history["high"],
                "low": history["low"],
                "close": history["close"],
                "executed_ask_volume": history["executed_ask_volume"],
                "executed_bid_volume": history["executed_bid_volume"],
                "total_executed_volume": history["executed_ask_volume"]
                + history["executed_bid_volume"],
            }
        )
    next_time = history["start_time"] + history["count"] * 300
    for offset, event in enumerate(case["events"]):
        open_time = next_time + offset * 300
        event_bar = copy.deepcopy(event)
        event_bar.update(
            {
                "record_id": f"{case['id']}-event-{offset + 1}",
                "source_revision": contract["source_revision"],
                "sequence": len(bars) + 1,
                "period_seconds": 300,
                "open_time": open_time,
                "close_time": open_time + 300,
                "available_at": open_time + 301,
                "completed": True,
            }
        )
        event_bar["total_executed_volume"] = (
            event_bar["executed_ask_volume"] + event_bar["executed_bid_volume"]
        )
        bars.append(event_bar)
    expanded["bars"] = bars

    context = copy.deepcopy(case["context"])
    context["source_revision"] = contract["source_revision"]
    expanded["context"] = context

    quote = copy.deepcopy(case["quote"])
    quote.update(
        {
            "source_id": contract["source_id"],
            "source_revision": contract["source_revision"],
            "observed_at": bars[-1]["close_time"],
            "available_at": bars[-1]["close_time"] + 1,
        }
    )
    expanded["quote"] = quote
    expanded["as_of"] = quote["available_at"]
    return expanded


def validate_records(case: dict[str, Any]) -> None:
    validate_contract(case, case["record_class"])
    contract = case["contract"]
    policy = case["freshness_policy"]
    profile = case["profile"]
    context = case["context"]
    bars = case["bars"]
    quote = case["quote"]
    as_of = case["as_of"]

    if (
        not profile.get("record_id")
        or not profile.get("profile_id")
        or not profile.get("profile_revision")
        or profile.get("source_revision") != contract["source_revision"]
    ):
        raise ContractError("PROFILE_PIN_MISMATCH")
    if (
        profile.get("completed") is not True
        or profile.get("session_start", 0) <= 0
        or profile.get("session_end", 0) <= profile.get("session_start", 0)
    ):
        raise ContractError("PROFILE_SESSION_NOT_COMPLETED")
    if profile["available_at"] < profile["session_end"] or profile["available_at"] > as_of:
        raise ContractError("PROFILE_FUTURE_OR_CLOCK_CONTRADICTION")
    if as_of - profile["available_at"] > policy["max_profile_age_seconds"]:
        raise ContractError("STALE_PROFILE")
    if not all(_finite(profile.get(name)) for name in ("val", "poc", "vah")) or not (
        profile["val"] < profile["poc"] < profile["vah"]
    ):
        raise ContractError("CONTRADICTORY_PROFILE_LEVELS")

    if (
        not context.get("record_id")
        or context.get("source_revision") != contract["source_revision"]
        or context.get("sequence", 0) <= 0
    ):
        raise ContractError("M15_PIN_MISMATCH")
    if (
        context.get("period_seconds") != 900
        or context.get("completed") is not True
        or context.get("close_time", 0) - context.get("open_time", 0) != context.get("period_seconds")
        or context.get("available_at", 0) < context.get("close_time", 0)
        or context.get("available_at", 0) > as_of
    ):
        raise ContractError("M15_INCOMPLETE_OR_FUTURE")
    if profile["session_end"] >= context["close_time"]:
        raise ContractError("PROFILE_NOT_PRIOR_TO_CONTEXT")
    if as_of - context["available_at"] > policy["max_m15_age_seconds"]:
        raise ContractError("STALE_M15_CONTEXT")
    _validate_ohlc(context, "M15")

    if not bars:
        raise ContractError("MISSING_M5_HISTORY")
    seen: set[str] = set()
    previous: dict[str, Any] | None = None
    for bar in bars:
        if (
            not bar.get("record_id")
            or bar.get("source_revision") != contract["source_revision"]
            or bar.get("sequence", 0) <= 0
        ):
            raise ContractError("M5_PIN_MISMATCH")
        if bar["record_id"] in seen:
            raise ContractError("M5_DUPLICATE_RECORD_ID")
        seen.add(bar["record_id"])
        if (
            bar.get("period_seconds") != 300
            or bar.get("completed") is not True
            or bar.get("close_time", 0) - bar.get("open_time", 0) != bar.get("period_seconds")
            or bar.get("available_at", 0) < bar.get("close_time", 0)
            or bar.get("available_at", 0) > as_of
        ):
            raise ContractError("M5_INCOMPLETE_OR_FUTURE")
        _validate_ohlc(bar, "M5")
        volumes = [
            bar.get("executed_ask_volume"),
            bar.get("executed_bid_volume"),
            bar.get("total_executed_volume"),
        ]
        if not all(_finite(value) for value in volumes) or any(value < 0 for value in volumes[:2]) or volumes[2] <= 0:
            raise ContractError("INVALID_EXECUTED_VOLUME")
        if volumes[0] + volumes[1] <= 0 or not math.isclose(
            volumes[0] + volumes[1], volumes[2], rel_tol=1e-9, abs_tol=1e-9
        ):
            raise ContractError("CONTRADICTORY_EXECUTED_VOLUME")
        if previous is not None and not (
            bar["sequence"] > previous["sequence"]
            and bar["open_time"] >= previous["close_time"]
            and bar["close_time"] > previous["close_time"]
            and bar["available_at"] > previous["available_at"]
        ):
            raise ContractError("M5_NON_MONOTONIC_OR_DUPLICATE")
        previous = bar
    if as_of - bars[-1]["available_at"] > policy["max_m5_age_seconds"]:
        raise ContractError("STALE_M5_HISTORY")

    if (
        not quote.get("record_id")
        or quote.get("source_id") != contract["source_id"]
        or quote.get("source_revision") != contract["source_revision"]
    ):
        raise ContractError("QUOTE_PIN_MISMATCH")
    if quote.get("available_at", 0) < quote.get("observed_at", 0) or quote.get("available_at", 0) > as_of:
        raise ContractError("QUOTE_FUTURE_OR_PRE_TRIGGER")
    if as_of - quote["available_at"] > policy["max_quote_age_seconds"]:
        raise ContractError("STALE_QUOTE")
    if not all(_finite(quote.get(name)) for name in ("bid", "ask", "all_in_cost_price")) or not (
        quote["bid"] > 0 and quote["ask"] >= quote["bid"] and quote["all_in_cost_price"] >= 0
    ):
        raise ContractError("INVALID_QUOTE_OR_COST")


def _delta(bar: dict[str, Any]) -> float:
    return (bar["executed_ask_volume"] - bar["executed_bid_volume"]) / bar["total_executed_volume"]


def _atr14_preceding(bars: list[dict[str, Any]], index: int) -> float | None:
    if index < 15:
        return None
    values = []
    for cursor in range(index - 14, index):
        bar = bars[cursor]
        previous_close = bars[cursor - 1]["close"]
        values.append(
            max(
                bar["high"] - bar["low"],
                abs(bar["high"] - previous_close),
                abs(bar["low"] - previous_close),
            )
        )
    return sum(values) / 14


def _median20(bars: list[dict[str, Any]], index: int) -> float | None:
    if index < 20:
        return None
    return statistics.median(bar["total_executed_volume"] for bar in bars[index - 20 : index])


def _overlap(low_a: float, high_a: float, low_b: float, high_b: float) -> bool:
    return high_a >= low_b and low_a <= high_b


def _validate_quote_trigger(case: dict[str, Any], trigger: dict[str, Any]) -> None:
    quote = case["quote"]
    if quote["observed_at"] < trigger["close_time"]:
        raise ContractError("QUOTE_FUTURE_OR_PRE_TRIGGER")


def replay_of01(case: dict[str, Any]) -> dict[str, Any]:
    bars, profile, context, quote = case["bars"], case["profile"], case["context"], case["quote"]
    if not profile["val"] < context["close"] < profile["vah"]:
        return {"decision": "NONE", "code": "OF01_CONTEXT_NOT_INSIDE_VALUE"}
    state: dict[str, Any] | None = None
    for index, bar in enumerate(bars):
        if state is None:
            median, atr = _median20(bars, index), _atr14_preceding(bars, index)
            if median is None or atr is None or bar["total_executed_volume"] < 1.5 * median:
                continue
            buffer = 0.2 * atr
            range_ = bar["high"] - bar["low"]
            long_test = (
                _overlap(bar["low"], bar["high"], profile["val"] - buffer, profile["val"] + buffer)
                and bar["low"] <= profile["val"]
                and profile["val"] < bar["close"] < profile["vah"]
                and _delta(bar) <= -0.2
                and (min(bar["open"], bar["close"]) - bar["low"]) / range_ >= 0.4
            )
            short_test = (
                _overlap(bar["low"], bar["high"], profile["vah"] - buffer, profile["vah"] + buffer)
                and bar["high"] >= profile["vah"]
                and profile["val"] < bar["close"] < profile["vah"]
                and _delta(bar) >= 0.2
                and (bar["high"] - max(bar["open"], bar["close"])) / range_ >= 0.4
            )
            if long_test != short_test:
                state = {
                    "direction": 1 if long_test else -1,
                    "setup": index,
                    "buffer": buffer,
                    "edge": profile["val"] if long_test else profile["vah"],
                    "test_low": bar["low"],
                    "test_high": bar["high"],
                    "outside": 0,
                }
            continue
        elapsed = index - state["setup"]
        beyond_outer = (
            bar["close"] < state["edge"] - state["buffer"]
            if state["direction"] == 1
            else bar["close"] > state["edge"] + state["buffer"]
        )
        state["outside"] = state["outside"] + 1 if beyond_outer else 0
        if state["outside"] >= 2:
            return {"decision": "CANCELLED", "code": "OF01_TWO_CLOSES_BEYOND_OUTER_EDGE"}
        if elapsed > 3:
            return {"decision": "EXPIRED", "code": "OF01_TRIGGER_EXPIRED"}
        triggered = bar["close"] > state["test_high"] if state["direction"] == 1 else bar["close"] < state["test_low"]
        if not triggered and elapsed >= 3:
            return {"decision": "EXPIRED", "code": "OF01_TRIGGER_EXPIRED"}
        if not triggered:
            continue
        _validate_quote_trigger(case, bar)
        window = bars[state["setup"] : index + 1]
        entry = quote["ask"] if state["direction"] == 1 else quote["bid"]
        stop = (
            min(item["low"] for item in window) - state["buffer"]
            if state["direction"] == 1
            else max(item["high"] for item in window) + state["buffer"]
        )
        gross_risk = entry - stop if state["direction"] == 1 else stop - entry
        gross_reward = profile["poc"] - entry if state["direction"] == 1 else entry - profile["poc"]
        net_risk = gross_risk + quote["all_in_cost_price"]
        net_reward = gross_reward - quote["all_in_cost_price"]
        if gross_risk <= 0 or net_risk <= 0 or net_reward <= 0:
            return {"decision": "REJECTED", "code": "OF01_INVALID_GEOMETRY"}
        net_rr = net_reward / net_risk
        if net_rr < 1.5:
            return {"decision": "REJECTED", "code": "OF01_NET_RR_BELOW_1_5"}
        return {
            "decision": "SIGNAL",
            "code": "OF01_SIGNAL_GEOMETRY_READY",
            "direction": state["direction"],
            "prospective_entry": entry,
            "stop_price": stop,
            "target_price": profile["poc"],
            "net_rr": net_rr,
            "quote_record_id": quote["record_id"],
            "prospective_quote_not_fill": True,
            "confirmation_window_completed_m5_bars": 3,
            "template_exit_binding": "TEMPLATE_EXIT_BINDING_REQUIRED",
        }
    return {"decision": "NONE", "code": "OF01_NO_SIGNAL"}


def replay_of02(case: dict[str, Any]) -> dict[str, Any]:
    bars, profile, context, quote = case["bars"], case["profile"], case["context"], case["quote"]
    direction = 1 if context["close"] > profile["vah"] else -1 if context["close"] < profile["val"] else 0
    if direction == 0:
        return {"decision": "NONE", "code": "OF02_CONTEXT_NOT_BEYOND_EDGE"}
    edge = profile["vah"] if direction == 1 else profile["val"]
    phase, state = "IDLE", {}
    for index, bar in enumerate(bars):
        if phase == "IDLE":
            atr = _atr14_preceding(bars, index)
            if atr is None:
                continue
            buffer = 0.2 * atr
            beyond = bar["close"] > edge + buffer if direction == 1 else bar["close"] < edge - buffer
            if beyond:
                phase, state = "SECOND", {"first": index, "buffer": buffer}
            continue
        opposite = bar["close"] < edge - state["buffer"] if direction == 1 else bar["close"] > edge + state["buffer"]
        if opposite:
            return {"decision": "CANCELLED", "code": "OF02_CLOSE_PAST_OPPOSITE_OUTER_EDGE"}
        if phase == "SECOND":
            beyond = bar["close"] > edge + state["buffer"] if direction == 1 else bar["close"] < edge - state["buffer"]
            median = _median20(bars, index)
            directional = _delta(bar) >= 0.2 if direction == 1 else _delta(bar) <= -0.2
            if index == state["first"] + 1 and beyond and median is not None and bar["total_executed_volume"] >= 1.5 * median and directional:
                phase, state["setup"] = "RETEST", index
                continue
            if beyond:
                atr = _atr14_preceding(bars, index)
                state = {"first": index, "buffer": 0.2 * atr}
            else:
                phase, state = "IDLE", {}
            continue
        if phase == "RETEST":
            if index - state["setup"] > 6:
                return {"decision": "EXPIRED", "code": "OF02_RETEST_EXPIRED"}
            overlaps = _overlap(bar["low"], bar["high"], edge - state["buffer"], edge + state["buffer"])
            closes_side = bar["close"] > edge if direction == 1 else bar["close"] < edge
            if not (overlaps and closes_side) and index - state["setup"] >= 6:
                return {"decision": "EXPIRED", "code": "OF02_RETEST_EXPIRED"}
            if overlaps and closes_side:
                phase = "CONFIRM"
                state.update({"retest": index, "low": bar["low"], "high": bar["high"]})
            continue
        state["low"] = min(state["low"], bar["low"])
        state["high"] = max(state["high"], bar["high"])
        if index - state["retest"] > 3:
            return {"decision": "EXPIRED", "code": "OF02_CONFIRM_EXPIRED"}
        directional = _delta(bar) > 0 if direction == 1 else _delta(bar) < 0
        beyond_retest = bar["close"] > bars[state["retest"]]["high"] if direction == 1 else bar["close"] < bars[state["retest"]]["low"]
        if not (directional and beyond_retest) and index - state["retest"] >= 3:
            return {"decision": "EXPIRED", "code": "OF02_CONFIRM_EXPIRED"}
        if not (directional and beyond_retest):
            continue
        _validate_quote_trigger(case, bar)
        entry = quote["ask"] if direction == 1 else quote["bid"]
        stop = state["low"] - state["buffer"] if direction == 1 else state["high"] + state["buffer"]
        risk = entry - stop if direction == 1 else stop - entry
        if risk <= 0:
            return {"decision": "REJECTED", "code": "OF02_INVALID_GEOMETRY"}
        target = entry + 2 * risk if direction == 1 else entry - 2 * risk
        net_risk = risk + quote["all_in_cost_price"]
        net_reward = 2 * risk - quote["all_in_cost_price"]
        if net_risk <= 0 or net_reward <= 0:
            return {"decision": "REJECTED", "code": "OF02_COST_CONSUMES_GEOMETRY"}
        return {
            "decision": "SIGNAL",
            "code": "OF02_SIGNAL_GEOMETRY_READY",
            "direction": direction,
            "prospective_entry": entry,
            "stop_price": stop,
            "target_price": target,
            "net_rr": net_reward / net_risk,
            "quote_record_id": quote["record_id"],
            "prospective_quote_not_fill": True,
            "retest_window_completed_m5_bars": 6,
            "confirmation_window_completed_m5_bars": 3,
            "consumer_time_exit_m5_bars_after_fill": 12,
            "time_exit": "CONSUMER_OWNED_12_M5_AFTER_ACTUAL_FILL",
            "template_exit_binding": "TEMPLATE_EXIT_BINDING_REQUIRED",
        }
    return {"decision": "NONE", "code": "OF02_NO_SIGNAL"}


def replay_case(case: dict[str, Any]) -> dict[str, Any]:
    validate_records(case)
    if case["component"] == "OF01":
        return replay_of01(case)
    if case["component"] == "OF02":
        return replay_of02(case)
    raise ContractError("UNKNOWN_COMPONENT")


def pinned_state_changed(
    state_pins: tuple[str, str, str, str, str], case: dict[str, Any]
) -> bool:
    contract, profile, context = case["contract"], case["profile"], case["context"]
    current = (
        contract["dataset_id"],
        contract["source_revision"],
        profile["profile_id"],
        profile["profile_revision"],
        context["record_id"],
    )
    return current != state_pins


def load_fixture(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--expect-class", choices=("FIXTURE", "QUALIFIED"))
    args = parser.parse_args(argv)
    try:
        package = load_fixture(args.input)
        validate_contract(package, args.expect_class)
        results = []
        for item in package.get("cases", []):
            case = expand_case(package, item)
            results.append({"case_id": item["id"], **replay_case(case)})
        print(json.dumps({"status": "PASS", "results": results}, sort_keys=True))
        return 0
    except (ContractError, KeyError, TypeError, json.JSONDecodeError) as exc:
        code = exc.code if isinstance(exc, ContractError) else "MALFORMED_PACKAGE"
        print(json.dumps({"status": "REJECTED", "code": code}, sort_keys=True))
        return 2


if __name__ == "__main__":
    sys.exit(main())
