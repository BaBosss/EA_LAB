#!/usr/bin/env python3
"""Deterministic offline reference for the MT5 activity/quote proxy family.

This module is research-only.  It never treats tick activity or quote-direction
movement as executed volume, Delta, or TRUE_ORDERFLOW.
"""

from __future__ import annotations

import argparse
import json
import math
import statistics
from collections import Counter
from pathlib import Path
from typing import Any, Iterable


PROFILE_IDENTITY = "TICK_ACTIVITY_PROFILE"
PROXY_DATA_IDENTITY = "MT5_ACTIVITY_QUOTE_PROXY"
QUOTE_IMBALANCE_IDENTITY = "QUOTE_DIRECTION_IMBALANCE_PROXY"
SESSION_IDENTITY = "MT5_BROKER_D1_BAR_V1"
VARIANTS = ("OFPR-00", "OFPR-01", "OFPR-02", "OFPC-00", "OFPC-01", "OFPC-02")
EPSILON = 1.0e-9
FIXTURE_EXACT_COUNT_BASIS = "FIXTURE_EXACT_NATIVE_EVENT_COUNT"
UNQUALIFIED_COUNT_BASIS = "UNQUALIFIED_COPY_TICKS_ALL_VS_MQLRATES_TICK_VOLUME"


class ProxyContractError(ValueError):
    """Raised when source data cannot satisfy the frozen proxy contract."""


def _finite_positive(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value) and value > 0.0


def _quote_mid(tick: dict[str, Any]) -> float | None:
    bid = tick.get("bid")
    ask = tick.get("ask")
    if not _finite_positive(bid) or not _finite_positive(ask):
        return None
    return (float(bid) + float(ask)) * 0.5


def validate_proxy_labels(contract: dict[str, Any]) -> None:
    expected = {
        "data_identity": PROXY_DATA_IDENTITY,
        "profile_identity": PROFILE_IDENTITY,
        "imbalance_identity": QUOTE_IMBALANCE_IDENTITY,
        "session_id": SESSION_IDENTITY,
    }
    if any(contract.get(name) != value for name, value in expected.items()):
        raise ProxyContractError("PROXY_LABEL_REQUIRED")
    for name in ("signal_instrument_id", "signal_source_id"):
        if not isinstance(contract.get(name), str) or not contract[name]:
            raise ProxyContractError("PROXY_PROVENANCE_REQUIRED")


def _require_identity(record: dict[str, Any], instrument_id: str, source_id: str) -> None:
    if record.get("instrument_id") != instrument_id or record.get("source_id") != source_id:
        raise ProxyContractError("CROSS_INSTRUMENT_OR_SOURCE")


def _validate_d1_record(record: dict[str, Any], *, completed: bool) -> None:
    if (
        not isinstance(record.get("record_id"), str)
        or not record["record_id"]
        or not isinstance(record.get("sequence"), int)
        or isinstance(record.get("sequence"), bool)
        or record["sequence"] <= 0
        or not isinstance(record.get("open_time_msc"), int)
        or isinstance(record.get("open_time_msc"), bool)
        or record["open_time_msc"] <= 0
        or not isinstance(record.get("available_at_msc"), int)
        or isinstance(record.get("available_at_msc"), bool)
        or record["available_at_msc"] < record["open_time_msc"]
        or record.get("completed") is not completed
        or not isinstance(record.get("instrument_id"), str)
        or not record["instrument_id"]
        or not isinstance(record.get("source_id"), str)
        or not record["source_id"]
    ):
        raise ProxyContractError("INVALID_D1_RECORD_IDENTITY")


def _tick_volume(bar: dict[str, Any]) -> int:
    value = bar.get("tick_volume")
    if not isinstance(value, int) or isinstance(value, bool) or value < 0:
        raise ProxyContractError("INVALID_M5_TICK_VOLUME")
    return value


def relative_activity_passes(
    bars: list[dict[str, Any]], index: int, *, multiplier: float = 1.50
) -> bool:
    if index < 20 or index >= len(bars):
        raise ProxyContractError("PREVIOUS20_REQUIRED")
    if not _finite_positive(multiplier):
        raise ProxyContractError("INVALID_ACTIVITY_MULTIPLIER")
    window = bars[index - 20 : index]
    if not bars[index].get("completed") or any(not bar.get("completed") for bar in window):
        raise ProxyContractError("COMPLETED_M5_REQUIRED")
    previous = [_tick_volume(bar) for bar in window]
    current = _tick_volume(bars[index])
    median = float(statistics.median(previous))
    if median <= 0.0:
        return False
    return current >= float(multiplier) * median


def quote_direction_imbalance(mids: Iterable[float]) -> dict[str, Any]:
    values = list(mids)
    if any(not _finite_positive(value) for value in values):
        raise ProxyContractError("INVALID_QUOTE_MID")
    up_count = 0
    down_count = 0
    unchanged_count = 0
    for previous, current in zip(values, values[1:]):
        if current > previous:
            up_count += 1
        elif current < previous:
            down_count += 1
        else:
            unchanged_count += 1
    denominator = up_count + down_count
    if denominator == 0:
        raise ProxyContractError("QUOTE_IMBALANCE_DENOMINATOR_ZERO")
    return {
        "imbalance_identity": QUOTE_IMBALANCE_IDENTITY,
        "up_count": up_count,
        "down_count": down_count,
        "unchanged_count": unchanged_count,
        "ratio": (up_count - down_count) / denominator,
    }


def _strict_nonnegative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _copy_interval_receipt(
    evidence: Any,
    *,
    expected_native_count: Any,
    expected_start_msc: Any,
    expected_end_msc: Any,
    instrument_id: str,
    source_id: str,
) -> dict[str, Any]:
    """Validate one half-open native copy receipt without inventing count equivalence."""

    receipt: dict[str, Any] = {
        "data_present": False,
        "count_consistent": False,
        "complete": False,
        "reason": "COMPLETION_EVIDENCE_MISSING",
        "record_class": None,
        "count_basis": None,
        "expected_native_count": expected_native_count,
        "returned_count": None,
        "array_size": None,
        "last_error": None,
        "interval_start_msc": None,
        "interval_end_msc": None,
        "first_time_msc": None,
        "last_time_msc": None,
        "up_count": 0,
        "down_count": 0,
        "unchanged_count": 0,
        "directional_denominator": 0,
    }
    if not isinstance(evidence, dict):
        return receipt

    for name in (
        "expected_native_count",
        "returned_count",
        "array_size",
        "last_error",
        "interval_start_msc",
        "interval_end_msc",
    ):
        value = evidence.get(name)
        receipt[name] = value
        if not _strict_nonnegative_int(value):
            receipt["reason"] = f"MALFORMED_{name.upper()}"
            return receipt

    receipt["record_class"] = evidence.get("record_class")
    receipt["count_basis"] = evidence.get("count_basis")
    if not isinstance(receipt["record_class"], str) or not receipt["record_class"]:
        receipt["reason"] = "MALFORMED_RECORD_CLASS"
        return receipt
    if not isinstance(receipt["count_basis"], str) or not receipt["count_basis"]:
        receipt["reason"] = "MALFORMED_COUNT_BASIS"
        return receipt
    if not _strict_nonnegative_int(expected_native_count) or expected_native_count <= 0:
        receipt["reason"] = "INVALID_EXPECTED_NATIVE_COUNT"
        return receipt
    if evidence["expected_native_count"] != expected_native_count:
        receipt["reason"] = "EXPECTED_NATIVE_COUNT_MISMATCH"
        return receipt
    if (
        not _strict_nonnegative_int(expected_start_msc)
        or not _strict_nonnegative_int(expected_end_msc)
        or expected_end_msc <= expected_start_msc
        or evidence["interval_start_msc"] != expected_start_msc
        or evidence["interval_end_msc"] != expected_end_msc
    ):
        receipt["reason"] = "INTERVAL_BOUNDARY_MISMATCH"
        return receipt
    if evidence.get("instrument_id") != instrument_id or evidence.get("source_id") != source_id:
        receipt["reason"] = "COPY_PROVENANCE_MISMATCH"
        return receipt
    if evidence["last_error"] != 0:
        receipt["data_present"] = evidence["returned_count"] > 0
        receipt["reason"] = f"COPY_ERROR_{evidence['last_error']}"
        return receipt
    if evidence["returned_count"] != evidence["array_size"]:
        receipt["data_present"] = evidence["returned_count"] > 0 or evidence["array_size"] > 0
        receipt["reason"] = "COPY_COUNT_ARRAY_DISAGREEMENT"
        return receipt

    ticks = evidence.get("ticks")
    if not isinstance(ticks, list):
        receipt["reason"] = "MALFORMED_TICK_ARRAY"
        return receipt
    if len(ticks) != evidence["array_size"]:
        receipt["data_present"] = bool(ticks) or evidence["array_size"] > 0
        receipt["reason"] = "COPY_COUNT_ARRAY_DISAGREEMENT"
        return receipt
    receipt["data_present"] = bool(ticks)
    if evidence["returned_count"] < expected_native_count:
        receipt["reason"] = "COPY_COUNT_UNDER_EXPECTED"
        return receipt
    if evidence["returned_count"] > expected_native_count:
        receipt["reason"] = "COPY_COUNT_OVER_EXPECTED"
        return receipt

    for name, reason in (
        ("series_synchronized_before", "SERIES_UNSYNCHRONIZED_BEFORE"),
        ("series_synchronized_after", "SERIES_UNSYNCHRONIZED_AFTER"),
        ("rate_snapshot_stable", "RATE_SNAPSHOT_CHANGED"),
    ):
        if not isinstance(evidence.get(name), bool):
            receipt["reason"] = f"MALFORMED_{name.upper()}"
            return receipt
        if not evidence[name]:
            receipt["reason"] = reason
            return receipt

    previous_time = -1
    mids: list[float] = []
    for tick in ticks:
        if not isinstance(tick, dict):
            receipt["reason"] = "MALFORMED_TICK_RECORD"
            return receipt
        time_msc = tick.get("time_msc")
        if not _strict_nonnegative_int(time_msc):
            receipt["reason"] = "MALFORMED_TICK_TIME_MSC"
            return receipt
        if time_msc < previous_time:
            receipt["reason"] = "NONMONOTONIC_TICK_TIMESTAMPS"
            return receipt
        if time_msc < expected_start_msc or time_msc >= expected_end_msc:
            receipt["reason"] = "TICK_OUTSIDE_INTERVAL"
            return receipt
        if tick.get("instrument_id") != instrument_id or tick.get("source_id") != source_id:
            receipt["reason"] = "COPY_PROVENANCE_MISMATCH"
            return receipt
        mid = tick.get("mid")
        if not _finite_positive(mid):
            receipt["reason"] = "INVALID_TICK_PRICE"
            return receipt
        previous_time = time_msc
        mids.append(float(mid))

    receipt["first_time_msc"] = ticks[0]["time_msc"]
    receipt["last_time_msc"] = ticks[-1]["time_msc"]
    receipt["up_count"] = sum(current > previous for previous, current in zip(mids, mids[1:]))
    receipt["down_count"] = sum(current < previous for previous, current in zip(mids, mids[1:]))
    receipt["unchanged_count"] = sum(current == previous for previous, current in zip(mids, mids[1:]))
    receipt["directional_denominator"] = receipt["up_count"] + receipt["down_count"]
    receipt["count_consistent"] = True

    fixture_qualified = (
        evidence["record_class"] == "FIXTURE"
        and evidence["count_basis"] == FIXTURE_EXACT_COUNT_BASIS
    )
    if not fixture_qualified:
        receipt["reason"] = "COUNT_BASIS_UNQUALIFIED"
        return receipt
    receipt["complete"] = True
    receipt["reason"] = "COMPLETE_FIXTURE_EXACT_COUNT"
    return receipt


def classify_availability_audit(
    *,
    prior_d1: dict[str, Any],
    current_d1: dict[str, Any],
    profile_tick_mids: list[float] | None,
    completed_m5: list[dict[str, Any]],
    ticks_by_bar: list[list[float] | None],
    bin_size_available: bool,
    profile_copy_evidence: dict[str, Any] | None = None,
    m5_copy_evidence: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """Separate copied-data presence from qualified interval completeness.

    Production COPY_TICKS_ALL observations remain unqualified because this source
    contract has no provider-specific proof that their count equals
    MqlRates.tick_volume.  Only deterministic FIXTURE receipts exercise the
    positive completeness branch.
    """

    instrument_id = prior_d1.get("instrument_id")
    source_id = prior_d1.get("source_id")

    d1_ready = (
        isinstance(prior_d1.get("record_id"), str)
        and bool(prior_d1["record_id"])
        and isinstance(current_d1.get("record_id"), str)
        and bool(current_d1["record_id"])
        and prior_d1["record_id"] != current_d1["record_id"]
        and isinstance(prior_d1.get("sequence"), int)
        and not isinstance(prior_d1.get("sequence"), bool)
        and isinstance(current_d1.get("sequence"), int)
        and not isinstance(current_d1.get("sequence"), bool)
        and current_d1["sequence"] == prior_d1["sequence"] + 1
        and isinstance(prior_d1.get("open_time"), int)
        and not isinstance(prior_d1.get("open_time"), bool)
        and isinstance(current_d1.get("open_time"), int)
        and not isinstance(current_d1.get("open_time"), bool)
        and prior_d1["open_time"] > 0
        and current_d1["open_time"] > prior_d1["open_time"]
        and _strict_nonnegative_int(prior_d1.get("tick_volume"))
        and prior_d1["tick_volume"] > 0
        and isinstance(instrument_id, str)
        and bool(instrument_id)
        and isinstance(source_id, str)
        and bool(source_id)
        and current_d1.get("instrument_id") == instrument_id
        and current_d1.get("source_id") == source_id
    )

    record_ids: set[str] = set()
    exact_m5_window = len(completed_m5) == 21
    if exact_m5_window:
        for index, bar in enumerate(completed_m5):
            record_id = bar.get("record_id")
            if (
                not isinstance(record_id, str)
                or not record_id
                or record_id in record_ids
                or not isinstance(bar.get("sequence"), int)
                or isinstance(bar.get("sequence"), bool)
                or (index > 0 and bar["sequence"] != completed_m5[index - 1]["sequence"] + 1)
                or not isinstance(bar.get("open_time"), int)
                or isinstance(bar.get("open_time"), bool)
                or bar["open_time"] <= 0
                or (index > 0 and bar["open_time"] != completed_m5[index - 1]["open_time"] + 300)
                or not _strict_nonnegative_int(bar.get("tick_volume"))
                or bar["tick_volume"] <= 0
                or bar.get("instrument_id") != instrument_id
                or bar.get("source_id") != source_id
            ):
                exact_m5_window = False
                break
            record_ids.add(record_id)

    prior_open = prior_d1.get("open_time")
    current_open = current_d1.get("open_time")
    expected_profile_start = prior_open * 1000 if _strict_nonnegative_int(prior_open) else -1
    expected_profile_end = current_open * 1000 if _strict_nonnegative_int(current_open) else -1
    profile_receipt = _copy_interval_receipt(
        profile_copy_evidence,
        expected_native_count=prior_d1.get("tick_volume"),
        expected_start_msc=expected_profile_start,
        expected_end_msc=expected_profile_end,
        instrument_id=instrument_id,
        source_id=source_id,
    )

    interval_receipts: list[dict[str, Any]] = []
    if exact_m5_window and isinstance(m5_copy_evidence, list) and len(m5_copy_evidence) == 21:
        for bar, evidence in zip(completed_m5, m5_copy_evidence):
            interval_receipts.append(
                _copy_interval_receipt(
                    evidence,
                    expected_native_count=bar["tick_volume"],
                    expected_start_msc=bar["open_time"] * 1000,
                    expected_end_msc=(bar["open_time"] + 300) * 1000,
                    instrument_id=instrument_id,
                    source_id=source_id,
                )
            )

    naked_profile_present = (
        isinstance(profile_tick_mids, list)
        and bool(profile_tick_mids)
        and all(_finite_positive(mid) for mid in profile_tick_mids)
    )
    naked_m5_present = (
        len(ticks_by_bar) == 21
        and all(isinstance(mids, list) and bool(mids) for mids in ticks_by_bar)
    )
    candidate_denominator = 0
    if len(interval_receipts) == 21:
        candidate_denominator = interval_receipts[-1]["directional_denominator"]
    elif len(ticks_by_bar) == 21 and isinstance(ticks_by_bar[-1], list):
        mids = ticks_by_bar[-1]
        if all(_finite_positive(mid) for mid in mids):
            up = sum(current > previous for previous, current in zip(mids, mids[1:]))
            down = sum(current < previous for previous, current in zip(mids, mids[1:]))
            candidate_denominator = up + down

    profile_complete = d1_ready and bin_size_available and profile_receipt["complete"]
    m5_complete = exact_m5_window and len(interval_receipts) == 21 and all(
        receipt["complete"] for receipt in interval_receipts
    )
    capability = "BLOCKED_DATA"
    if profile_complete and m5_complete:
        capability = "P2_READY" if candidate_denominator > 0 else "P1_READY"

    observed_profile = profile_receipt["data_present"] or naked_profile_present
    observed_m5 = (
        len(interval_receipts) == 21 and all(receipt["data_present"] for receipt in interval_receipts)
    ) or naked_m5_present
    observed_profile_consistent = profile_receipt["count_consistent"] or (
        not isinstance(profile_copy_evidence, dict) and naked_profile_present
    )
    observed_m5_consistent = (
        len(interval_receipts) == 21
        and all(receipt["count_consistent"] for receipt in interval_receipts)
    ) or (not isinstance(m5_copy_evidence, list) and naked_m5_present)
    raw_observed = "NO_PROFILE_DATA"
    if d1_ready and bin_size_available and observed_profile:
        raw_observed = "PROFILE_DATA_PRESENT_NOT_COUNT_CONSISTENT"
        if observed_profile_consistent:
            raw_observed = "P0_PREREQUISITES_OBSERVED_UNQUALIFIED"
        if exact_m5_window and observed_m5 and observed_m5_consistent:
            raw_observed = (
                "P2_PREREQUISITES_OBSERVED_UNQUALIFIED"
                if candidate_denominator > 0
                else "P1_PREREQUISITES_OBSERVED_UNQUALIFIED"
            )

    blockers: list[str] = []
    if not d1_ready:
        blockers.append("D1_PAIR_INVALID")
    if not bin_size_available:
        blockers.append("BIN_SIZE_UNAVAILABLE")
    if not isinstance(profile_copy_evidence, dict):
        blockers.append("PROFILE_COMPLETION_EVIDENCE_MISSING")
    elif not profile_receipt["complete"]:
        blockers.append(f"PROFILE_{profile_receipt['reason']}")
    if not exact_m5_window:
        blockers.append("M5_WINDOW_INVALID")
    if not isinstance(m5_copy_evidence, list) or len(m5_copy_evidence) != 21:
        blockers.append("M5_COMPLETION_EVIDENCE_MISSING")
    elif any(not receipt["complete"] for receipt in interval_receipts):
        blockers.append("M5_INTERVAL_COMPLETENESS_REFUSED")
    if (
        profile_receipt["reason"] == "COUNT_BASIS_UNQUALIFIED"
        or any(receipt["reason"] == "COUNT_BASIS_UNQUALIFIED" for receipt in interval_receipts)
    ):
        blockers.append("COMPLETENESS_UNQUALIFIED")

    m5_complete_count = sum(receipt["complete"] for receipt in interval_receipts)
    m5_refused_count = 21 - m5_complete_count
    return {
        "capability": capability,
        "raw_observed_capability": raw_observed,
        "prior_d1_interval_proven": d1_ready,
        "profile_data_present": observed_profile,
        "profile_completeness_qualified": profile_receipt["complete"],
        "profile_interval_receipt": profile_receipt,
        "m5_exact_window_proven": exact_m5_window,
        "m5_complete_intervals": m5_complete_count,
        "m5_refused_intervals": m5_refused_count,
        "m5_interval_receipts": interval_receipts,
        "quote_copy_failures": m5_refused_count,
        "history_zero_direction_intervals": sum(
            receipt["directional_denominator"] == 0 for receipt in interval_receipts[:-1]
        ),
        "candidate_directional_denominator": candidate_denominator,
        "blockers": blockers,
    }


def build_tick_activity_profile(
    ticks: Iterable[dict[str, Any]],
    *,
    previous_d1: dict[str, Any],
    current_d1: dict[str, Any],
    available_at_msc: int,
    trade_tick_size: float,
    point: float,
) -> dict[str, Any]:
    """Build MT5_TICK_ACTIVITY_PROFILE_V1 from one completed broker-D1 interval."""

    _validate_d1_record(previous_d1, completed=True)
    _validate_d1_record(current_d1, completed=False)
    instrument_id = previous_d1["instrument_id"]
    source_id = previous_d1["source_id"]
    _require_identity(current_d1, instrument_id, source_id)
    if current_d1["sequence"] != previous_d1["sequence"] + 1:
        raise ProxyContractError("NON_ADJACENT_D1_RECORDS")
    session_start_msc = previous_d1["open_time_msc"]
    session_end_msc = current_d1["open_time_msc"]
    if (
        session_end_msc <= session_start_msc
        or previous_d1["available_at_msc"] < session_end_msc
        or current_d1["available_at_msc"] < session_end_msc
        or not isinstance(available_at_msc, int)
        or isinstance(available_at_msc, bool)
        or available_at_msc < max(previous_d1["available_at_msc"], current_d1["available_at_msc"])
    ):
        raise ProxyContractError("INVALID_D1_BOUNDARY")

    if _finite_positive(trade_tick_size):
        bin_size = float(trade_tick_size)
        bin_size_source = "SYMBOL_TRADE_TICK_SIZE"
    elif _finite_positive(point):
        bin_size = float(point)
        bin_size_source = "SYMBOL_POINT"
    else:
        raise ProxyContractError("NO_POSITIVE_BIN_SIZE")

    counts: Counter[int] = Counter()
    qualifying_ticks = 0
    for tick in ticks:
        _require_identity(tick, instrument_id, source_id)
        time_msc = tick.get("time_msc")
        if not isinstance(time_msc, int) or isinstance(time_msc, bool):
            raise ProxyContractError("INVALID_TICK_TIMESTAMP")
        if time_msc < session_start_msc or time_msc >= session_end_msc:
            continue
        mid = _quote_mid(tick)
        if mid is None:
            continue
        bin_index = math.floor(mid / bin_size + 1.0e-12)
        counts[bin_index] += 1
        qualifying_ticks += 1

    if qualifying_ticks == 0:
        raise ProxyContractError("NO_QUALIFYING_QUOTE_TICKS")

    max_count = max(counts.values())
    poc_bin = min(index for index, count in counts.items() if count == max_count)
    target = 0.70 * qualifying_ticks
    included = {poc_bin}
    accumulated = counts[poc_bin]
    lower = poc_bin - 1
    upper = poc_bin + 1
    minimum_observed = min(counts)
    maximum_observed = max(counts)

    while accumulated < target:
        if lower < minimum_observed and upper > maximum_observed:
            break
        lower_count = counts.get(lower, 0) if lower >= minimum_observed else -1
        upper_count = counts.get(upper, 0) if upper <= maximum_observed else -1
        if lower_count > upper_count:
            included.add(lower)
            accumulated += lower_count
            lower -= 1
        elif upper_count > lower_count:
            included.add(upper)
            accumulated += upper_count
            upper += 1
        else:
            if lower_count >= 0:
                included.add(lower)
                accumulated += lower_count
                lower -= 1
            if upper_count >= 0:
                included.add(upper)
                accumulated += upper_count
                upper += 1

    included_bins = sorted(included)
    return {
        "profile_id": "MT5_TICK_ACTIVITY_PROFILE_V1",
        "profile_identity": PROFILE_IDENTITY,
        "session_id": SESSION_IDENTITY,
        "instrument_id": instrument_id,
        "source_id": source_id,
        "previous_d1_record_id": previous_d1["record_id"],
        "previous_d1_sequence": previous_d1["sequence"],
        "previous_d1_open_time_msc": session_start_msc,
        "current_d1_record_id": current_d1["record_id"],
        "current_d1_sequence": current_d1["sequence"],
        "current_d1_open_time_msc": session_end_msc,
        "available_at_msc": available_at_msc,
        "session_start_msc": session_start_msc,
        "session_end_msc": session_end_msc,
        "bin_size": bin_size,
        "bin_size_source": bin_size_source,
        "poc_bin_index": poc_bin,
        "poc": (poc_bin + 0.5) * bin_size,
        "included_bin_indices": included_bins,
        "val": included_bins[0] * bin_size,
        "vah": (included_bins[-1] + 1) * bin_size,
        "total_activity": qualifying_ticks,
        "value_area_activity": accumulated,
        "bin_counts": {str(index): counts[index] for index in sorted(counts)},
    }


def _valid_ohlc(bar: dict[str, Any]) -> bool:
    values = [bar.get(name) for name in ("open", "high", "low", "close")]
    if any(not _finite_positive(value) for value in values):
        return False
    open_, high, low, close = map(float, values)
    return high >= max(open_, close) and low <= min(open_, close) and high >= low


def _validate_case(case: dict[str, Any]) -> None:
    variant = case.get("variant")
    if variant not in VARIANTS:
        raise ProxyContractError("UNKNOWN_PROXY_VARIANT")
    labels = case.get("labels", {})
    validate_proxy_labels(labels)
    instrument_id = labels["signal_instrument_id"]
    source_id = labels["signal_source_id"]

    profile = case.get("profile", {})
    if (
        not profile.get("completed")
        or not isinstance(profile.get("session_start"), int)
        or not isinstance(profile.get("session_end"), int)
        or profile["session_end"] <= profile["session_start"]
        or profile.get("available_at", 0) < profile["session_end"]
        or not all(_finite_positive(profile.get(name)) for name in ("val", "poc", "vah"))
        or not (profile["val"] < profile["poc"] < profile["vah"])
    ):
        raise ProxyContractError("INVALID_COMPLETED_PROXY_PROFILE")
    _require_identity(profile, instrument_id, source_id)
    if (
        not isinstance(profile.get("previous_d1_record_id"), str)
        or not profile["previous_d1_record_id"]
        or not isinstance(profile.get("current_d1_record_id"), str)
        or not profile["current_d1_record_id"]
        or profile["previous_d1_record_id"] == profile["current_d1_record_id"]
        or not isinstance(profile.get("previous_d1_sequence"), int)
        or isinstance(profile.get("previous_d1_sequence"), bool)
        or not isinstance(profile.get("current_d1_sequence"), int)
        or isinstance(profile.get("current_d1_sequence"), bool)
        or profile["current_d1_sequence"] != profile["previous_d1_sequence"] + 1
        or profile.get("previous_d1_open_time") != profile["session_start"]
        or profile.get("current_d1_open_time") != profile["session_end"]
        or profile["session_end"] <= profile["session_start"]
    ):
        raise ProxyContractError("INVALID_D1_BOUNDARY")

    evaluation_time = case.get("evaluation_time")
    if not isinstance(evaluation_time, int) or isinstance(evaluation_time, bool):
        raise ProxyContractError("INVALID_EVALUATION_TIME")
    if profile["available_at"] > evaluation_time:
        raise ProxyContractError("FUTURE_PROXY_PROFILE")

    contexts = case.get("contexts")
    if not isinstance(contexts, list) or not contexts:
        raise ProxyContractError("M15_CONTEXT_REQUIRED")
    previous_close = -1
    previous_available = -1
    for context in contexts:
        _require_identity(context, instrument_id, source_id)
        if (
            context.get("d1_record_id") != profile["current_d1_record_id"]
            or context.get("d1_sequence") != profile["current_d1_sequence"]
            or context.get("d1_open_time") != profile["current_d1_open_time"]
        ):
            raise ProxyContractError("STALE_OR_MIXED_D1_SESSION")
        if (
            not context.get("completed")
            or context.get("period_seconds") != 900
            or context.get("close_time", 0) - context.get("open_time", 0) != 900
            or context.get("available_at", 0) < context.get("close_time", 0)
            or context.get("available_at", 0) > evaluation_time
            or context.get("open_time", 0) < profile["current_d1_open_time"]
            or not _finite_positive(context.get("close"))
            or context.get("open_time", 0) < previous_close
            or context.get("close_time", 0) <= previous_close
            or context.get("available_at", 0) <= previous_available
            or profile["session_end"] >= context.get("close_time", 0)
        ):
            raise ProxyContractError("INVALID_OR_NONCAUSAL_M15_CONTEXT")
        previous_close = context["close_time"]
        previous_available = context["available_at"]

    bars = case.get("bars")
    if not isinstance(bars, list) or not bars:
        raise ProxyContractError("M5_HISTORY_REQUIRED")
    previous_close = -1
    previous_available = -1
    record_ids: set[str] = set()
    for bar in bars:
        _require_identity(bar, instrument_id, source_id)
        if (
            bar.get("d1_record_id") != profile["current_d1_record_id"]
            or bar.get("d1_sequence") != profile["current_d1_sequence"]
            or bar.get("d1_open_time") != profile["current_d1_open_time"]
        ):
            raise ProxyContractError("STALE_OR_MIXED_D1_SESSION")
        if not bar.get("completed"):
            raise ProxyContractError("COMPLETED_M5_REQUIRED")
        if (
            bar.get("period_seconds") != 300
            or bar.get("close_time", 0) - bar.get("open_time", 0) != 300
            or bar.get("available_at", 0) < bar.get("close_time", 0)
            or bar.get("available_at", 0) > evaluation_time
            or bar.get("open_time", 0) < profile["current_d1_open_time"]
            or bar.get("open_time", 0) < previous_close
            or bar.get("close_time", 0) <= previous_close
            or bar.get("available_at", 0) <= previous_available
            or not _valid_ohlc(bar)
        ):
            raise ProxyContractError("INVALID_OR_NONCAUSAL_M5_BAR")
        record_id = bar.get("record_id")
        if not isinstance(record_id, str) or not record_id or record_id in record_ids:
            raise ProxyContractError("DUPLICATE_OR_MISSING_M5_RECORD_ID")
        record_ids.add(record_id)
        _tick_volume(bar)
        previous_close = bar["close_time"]
        previous_available = bar["available_at"]

    last = bars[-1]
    if evaluation_time < last["available_at"]:
        raise ProxyContractError("EVALUATION_PRECEDES_CURRENT_COMPLETED_BAR")
    if evaluation_time >= last["close_time"] + last["period_seconds"]:
        raise ProxyContractError("DECISION_WINDOW_MISSING_CLOSED_BAR")

    quote = case.get("quote", {})
    _require_identity(quote, instrument_id, source_id)
    if (
        quote.get("d1_record_id") != profile["current_d1_record_id"]
        or quote.get("d1_sequence") != profile["current_d1_sequence"]
        or quote.get("d1_open_time") != profile["current_d1_open_time"]
    ):
        raise ProxyContractError("STALE_OR_MIXED_D1_SESSION")


def _context_at(contexts: list[dict[str, Any]], available_at: int) -> dict[str, Any] | None:
    selected = None
    for context in contexts:
        if context["available_at"] <= available_at:
            selected = context
    return selected


def _atr14_preceding(bars: list[dict[str, Any]], index: int) -> float | None:
    if index < 15:
        return None
    total = 0.0
    for cursor in range(index - 14, index):
        bar = bars[cursor]
        previous_close = float(bars[cursor - 1]["close"])
        true_range = max(
            float(bar["high"]) - float(bar["low"]),
            abs(float(bar["high"]) - previous_close),
            abs(float(bar["low"]) - previous_close),
        )
        if true_range <= 0.0:
            return None
        total += true_range
    return total / 14.0


def _range_overlaps(low_a: float, high_a: float, low_b: float, high_b: float) -> bool:
    return high_a >= low_b and low_a <= high_b


def _bar_imbalance(bar: dict[str, Any]) -> float:
    ticks = bar.get("quote_ticks")
    if not isinstance(ticks, list):
        raise ProxyContractError("QUOTE_TICKS_REQUIRED")
    start_msc = int(bar["open_time"]) * 1_000
    end_msc = int(bar["close_time"]) * 1_000
    mids: list[float] = []
    previous_time = -1
    for tick in ticks:
        _require_identity(tick, bar["instrument_id"], bar["source_id"])
        time_msc = tick.get("time_msc")
        if not isinstance(time_msc, int) or isinstance(time_msc, bool):
            raise ProxyContractError("INVALID_TICK_TIMESTAMP")
        if time_msc <= previous_time:
            raise ProxyContractError("NON_MONOTONIC_QUOTE_TICKS")
        previous_time = time_msc
        if time_msc < start_msc or time_msc >= end_msc:
            continue
        mid = _quote_mid(tick)
        if mid is not None:
            mids.append(mid)
    result = quote_direction_imbalance(mids)
    return float(result["ratio"])


def _activity_required(variant: str) -> bool:
    return variant.endswith(("-01", "-02"))


def _imbalance_required(variant: str) -> bool:
    return variant.endswith("-02")


def _empty_result(variant: str, code: str = "NO_SIGNAL") -> dict[str, Any]:
    return {
        "status": "NO_SIGNAL",
        "code": code,
        "variant": variant,
        "data_identity": PROXY_DATA_IDENTITY,
        "profile_identity": PROFILE_IDENTITY,
        "imbalance_identity": QUOTE_IMBALANCE_IDENTITY,
    }


def _validate_quote(case: dict[str, Any], trigger_index: int) -> dict[str, Any]:
    bars = case["bars"]
    if trigger_index != len(bars) - 1:
        raise ProxyContractError("QUOTE_NOT_BOUND_TO_CURRENT_COMPLETED_BAR")
    quote = case.get("quote", {})
    trigger = bars[trigger_index]
    evaluation_time = case["evaluation_time"]
    if (
        not isinstance(quote.get("record_id"), str)
        or not quote["record_id"]
        or not isinstance(quote.get("observed_at"), int)
        or not isinstance(quote.get("available_at"), int)
        or quote["observed_at"] <= trigger["close_time"]
        or quote["observed_at"] > evaluation_time
        or quote["available_at"] < quote["observed_at"]
        or quote["available_at"] > evaluation_time
        or not _finite_positive(quote.get("bid"))
        or not _finite_positive(quote.get("ask"))
        or quote["ask"] < quote["bid"]
        or not isinstance(quote.get("all_in_cost_price"), (int, float))
        or isinstance(quote.get("all_in_cost_price"), bool)
        or not math.isfinite(quote["all_in_cost_price"])
        or quote["all_in_cost_price"] < 0.0
    ):
        raise ProxyContractError("INVALID_PROSPECTIVE_QUOTE")
    return quote


def _signal_result(
    case: dict[str, Any],
    direction: int,
    setup_index: int,
    trigger_index: int,
    stop: float,
    target: float,
    *,
    minimum_rr: float | None,
    retest_bars: int,
    confirmation_bars: int,
) -> dict[str, Any]:
    quote = _validate_quote(case, trigger_index)
    entry = float(quote["ask"] if direction == 1 else quote["bid"])
    gross_risk = entry - stop if direction == 1 else stop - entry
    gross_reward = target - entry if direction == 1 else entry - target
    cost = float(quote["all_in_cost_price"])
    net_risk = gross_risk + cost
    net_reward = gross_reward - cost
    if gross_risk <= 0.0 or gross_reward <= 0.0 or net_risk <= 0.0 or net_reward <= 0.0:
        return _empty_result(case["variant"], "INVALID_GEOMETRY")
    net_rr = net_reward / net_risk
    if minimum_rr is not None and net_rr + EPSILON < minimum_rr:
        return _empty_result(case["variant"], "NET_RR_BELOW_1_50")
    return {
        "status": "SIGNAL",
        "code": f"{case['variant']}_PROXY_GEOMETRY_READY",
        "variant": case["variant"],
        "data_identity": PROXY_DATA_IDENTITY,
        "profile_identity": PROFILE_IDENTITY,
        "imbalance_identity": QUOTE_IMBALANCE_IDENTITY,
        "geometry": {
            "direction": direction,
            "prospective_entry": entry,
            "stop_price": stop,
            "target_price": target,
            "gross_risk": gross_risk,
            "net_risk": net_risk,
            "net_reward": net_reward,
            "net_rr": net_rr,
            "setup_time": case["bars"][setup_index]["close_time"],
            "trigger_time": case["bars"][trigger_index]["close_time"],
            "retest_window_completed_m5_bars": retest_bars,
            "confirmation_window_completed_m5_bars": confirmation_bars,
            "consumer_time_exit_m5_bars_after_fill": 12 if case["variant"].startswith("OFPC") else 0,
            "prospective_quote_not_fill": True,
            "fill_simulated": False,
        },
    }


def _evaluate_ofpr(case: dict[str, Any]) -> dict[str, Any]:
    variant = case["variant"]
    profile = case["profile"]
    bars = case["bars"]
    state: dict[str, Any] | None = None
    outside_count = 0

    def start_candidate(index: int, bar: dict[str, Any], context: dict[str, Any]) -> dict[str, Any] | None:
        if not (profile["val"] < context["close"] < profile["vah"]):
            return None
        atr = _atr14_preceding(bars, index)
        if atr is None:
            return None
        buffer = 0.20 * atr
        current_range = bar["high"] - bar["low"]
        if current_range <= 0.0:
            return None
        long_candidate = (
            _range_overlaps(bar["low"], bar["high"], profile["val"] - buffer, profile["val"] + buffer)
            and profile["val"] < bar["close"] < profile["vah"]
            and (min(bar["open"], bar["close"]) - bar["low"]) / current_range + EPSILON >= 0.40
        )
        short_candidate = (
            _range_overlaps(bar["low"], bar["high"], profile["vah"] - buffer, profile["vah"] + buffer)
            and profile["val"] < bar["close"] < profile["vah"]
            and (bar["high"] - max(bar["open"], bar["close"])) / current_range + EPSILON >= 0.40
        )
        if long_candidate == short_candidate:
            return None
        direction = 1 if long_candidate else -1
        if _activity_required(variant) and not relative_activity_passes(bars, index):
            return None
        if _imbalance_required(variant):
            ratio = _bar_imbalance(bar)
            if (direction == 1 and ratio > -0.20 + EPSILON) or (
                direction == -1 and ratio < 0.20 - EPSILON
            ):
                return None
        return {
            "direction": direction,
            "setup_index": index,
            "buffer": buffer,
            "edge": profile["val"] if direction == 1 else profile["vah"],
            "test_low": bar["low"],
            "test_high": bar["high"],
        }

    for index, bar in enumerate(bars):
        context = _context_at(case["contexts"], bar["available_at"])
        profile_available = profile["available_at"] <= bar["available_at"]
        if context is None or not profile_available:
            state = None
            outside_count = 0
            continue

        if state is not None:
            elapsed = index - state["setup_index"]
            beyond_outer = (
                bar["close"] < state["edge"] - state["buffer"]
                if state["direction"] == 1
                else bar["close"] > state["edge"] + state["buffer"]
            )
            outside_count = outside_count + 1 if beyond_outer else 0
            expired_or_cancelled = outside_count >= 2 or elapsed > 3
            triggered = (
                bar["close"] > state["test_high"]
                if state["direction"] == 1
                else bar["close"] < state["test_low"]
            )
            if not triggered and elapsed >= 3:
                expired_or_cancelled = True
            if expired_or_cancelled:
                state = None
                outside_count = 0
                continue
            elif triggered:
                if index == len(bars) - 1:
                    relevant = bars[state["setup_index"] : index + 1]
                    stop = (
                        min(item["low"] for item in relevant) - state["buffer"]
                        if state["direction"] == 1
                        else max(item["high"] for item in relevant) + state["buffer"]
                    )
                    return _signal_result(
                        case,
                        state["direction"],
                        state["setup_index"],
                        index,
                        stop,
                        profile["poc"],
                        minimum_rr=1.50,
                        retest_bars=0,
                        confirmation_bars=3,
                    )
                state = None
                outside_count = 0
                continue
            else:
                continue

        state = start_candidate(index, bar, context)
        outside_count = 0
    return _empty_result(variant)


def _outside(bar: dict[str, Any], direction: int, edge: float, buffer: float) -> bool:
    return bar["close"] > edge + buffer if direction == 1 else bar["close"] < edge - buffer


def _opposite_outer(bar: dict[str, Any], direction: int, edge: float, buffer: float) -> bool:
    return bar["close"] < edge - buffer if direction == 1 else bar["close"] > edge + buffer


def _evaluate_ofpc(case: dict[str, Any]) -> dict[str, Any]:
    variant = case["variant"]
    profile = case["profile"]
    bars = case["bars"]
    state: dict[str, Any] | None = None

    def start_first(index: int, direction: int) -> dict[str, Any] | None:
        atr = _atr14_preceding(bars, index)
        if atr is None:
            return None
        edge = profile["vah"] if direction == 1 else profile["val"]
        buffer = 0.20 * atr
        if not _outside(bars[index], direction, edge, buffer):
            return None
        return {
            "phase": "SECOND",
            "direction": direction,
            "first_index": index,
            "setup_index": index,
            "edge": edge,
            "buffer": buffer,
        }

    for index, bar in enumerate(bars):
        context = _context_at(case["contexts"], bar["available_at"])
        if context is None or profile["available_at"] > bar["available_at"]:
            state = None
            continue
        context_direction = 1 if context["close"] > profile["vah"] else -1 if context["close"] < profile["val"] else 0
        if state is not None:
            if _opposite_outer(bar, state["direction"], state["edge"], state["buffer"]):
                state = None
                continue
            elif state["phase"] == "SECOND":
                consecutive = index == state["first_index"] + 1
                if not consecutive or not _outside(bar, state["direction"], state["edge"], state["buffer"]):
                    state = start_first(index, context_direction) if context_direction else None
                    continue
                if _activity_required(variant) and not relative_activity_passes(bars, index):
                    state = start_first(index, context_direction) if context_direction else None
                    continue
                if _imbalance_required(variant):
                    ratio = _bar_imbalance(bar)
                    if (state["direction"] == 1 and ratio < 0.20 - EPSILON) or (
                        state["direction"] == -1 and ratio > -0.20 + EPSILON
                    ):
                        state = start_first(index, context_direction) if context_direction else None
                        continue
                state["phase"] = "RETEST"
                state["setup_index"] = index
                continue
            elif state["phase"] == "RETEST":
                elapsed = index - state["setup_index"]
                overlaps = _range_overlaps(
                    bar["low"], bar["high"], state["edge"] - state["buffer"], state["edge"] + state["buffer"]
                )
                breakout_side = bar["close"] > state["edge"] if state["direction"] == 1 else bar["close"] < state["edge"]
                if elapsed > 6 or (elapsed >= 6 and not (overlaps and breakout_side)):
                    state = None
                    continue
                elif not (overlaps and breakout_side):
                    continue
                else:
                    state["phase"] = "CONFIRM"
                    state["retest_index"] = index
                    state["retest_low"] = bar["low"]
                    state["retest_high"] = bar["high"]
                    continue
            else:
                elapsed = index - state["retest_index"]
                state["retest_low"] = min(state["retest_low"], bar["low"])
                state["retest_high"] = max(state["retest_high"], bar["high"])
                beyond_retest = (
                    bar["close"] > bars[state["retest_index"]]["high"]
                    if state["direction"] == 1
                    else bar["close"] < bars[state["retest_index"]]["low"]
                )
                directional = True
                if _imbalance_required(variant):
                    ratio = _bar_imbalance(bar)
                    directional = ratio > 0.0 if state["direction"] == 1 else ratio < 0.0
                if elapsed > 3 or (elapsed >= 3 and not (beyond_retest and directional)):
                    state = None
                    continue
                elif not (beyond_retest and directional):
                    continue
                elif index == len(bars) - 1:
                    quote = _validate_quote(case, index)
                    entry = float(quote["ask"] if state["direction"] == 1 else quote["bid"])
                    stop = (
                        state["retest_low"] - state["buffer"]
                        if state["direction"] == 1
                        else state["retest_high"] + state["buffer"]
                    )
                    gross_risk = entry - stop if state["direction"] == 1 else stop - entry
                    target = entry + 2.0 * gross_risk if state["direction"] == 1 else entry - 2.0 * gross_risk
                    return _signal_result(
                        case,
                        state["direction"],
                        state["setup_index"],
                        index,
                        stop,
                        target,
                        minimum_rr=None,
                        retest_bars=6,
                        confirmation_bars=3,
                    )
                else:
                    state = None
                    continue

        if state is None and context_direction != 0:
            state = start_first(index, context_direction)
    return _empty_result(variant)


def evaluate_variant(case: dict[str, Any]) -> dict[str, Any]:
    """Replay one frozen proxy variant over chronological completed M5 bars."""

    _validate_case(case)
    return _evaluate_ofpr(case) if case["variant"].startswith("OFPR") else _evaluate_ofpc(case)


def _fixture_bar(
    open_time: int,
    open_: float,
    high: float,
    low: float,
    close: float,
    *,
    tick_volume: int = 100,
    mids: list[float] | None = None,
) -> dict[str, Any]:
    quote_mids = list(mids if mids is not None else [close, close + 0.01])
    return {
        "record_id": f"m5-{open_time}",
        "instrument_id": "XAUUSD.fixture",
        "source_id": "fixture-source-1",
        "d1_record_id": "d1-101",
        "d1_sequence": 101,
        "d1_open_time": 86_401,
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
                "time_msc": open_time * 1000 + index,
                "bid": mid,
                "ask": mid,
                "last": 999.0,
                "instrument_id": "XAUUSD.fixture",
                "source_id": "fixture-source-1",
            }
            for index, mid in enumerate(quote_mids)
        ],
    }


def _fixture_ratio_mids(direction: str, threshold: bool) -> list[float]:
    values = (
        [100.0, 101.0, 102.0, 101.0, 102.0, 101.0]
        if threshold
        else [100.0, 101.0, 100.0]
    )
    return values if direction == "long" else list(reversed(values))


def _expand_fixture_descriptor(descriptor: dict[str, Any]) -> dict[str, Any]:
    variant = descriptor.get("variant")
    direction = descriptor.get("direction")
    scenario = descriptor.get("scenario")
    if variant not in VARIANTS or direction not in ("long", "short") or scenario not in (
        "positive",
        "gate_negative",
    ):
        raise ProxyContractError("INVALID_FIXTURE_DESCRIPTOR")
    gate_pass = scenario == "positive"
    family = variant[:4]
    level = int(variant[-2:])
    is_long = direction == "long"
    activity = 150 if gate_pass or level == 0 else 149
    evidence_direction = (
        ("short" if is_long else "long") if family == "OFPR" else direction
    )
    required_mids = _fixture_ratio_mids(evidence_direction, gate_pass)
    opposite = "short" if evidence_direction == "long" else "long"
    wrong_mids = _fixture_ratio_mids(opposite, True)
    start = 87_301
    bars = [
        _fixture_bar(start + index * 300, 105.0, 105.5, 104.5, 105.0)
        for index in range(20)
    ]

    if family == "OFPR":
        if is_long:
            test = _fixture_bar(
                start + 20 * 300,
                100.3,
                100.8,
                99.7,
                100.4,
                tick_volume=activity,
                mids=required_mids if level == 2 else wrong_mids,
            )
            trigger = _fixture_bar(start + 21 * 300, 100.5, 101.0, 100.2, 100.9)
            context_close, bid, ask = 105.0, 100.85, 100.90
        else:
            test = _fixture_bar(
                start + 20 * 300,
                109.7,
                110.3,
                109.2,
                109.6,
                tick_volume=activity,
                mids=required_mids if level == 2 else wrong_mids,
            )
            trigger = _fixture_bar(start + 21 * 300, 109.5, 109.8, 109.0, 109.1)
            context_close, bid, ask = 105.0, 109.10, 109.15
        if level == 0 and not gate_pass:
            if is_long:
                test["low"] = 100.3
            else:
                test["high"] = 109.7
        bars.extend((test, trigger))
    else:
        if is_long:
            first = _fixture_bar(start + 20 * 300, 110.0, 110.5, 109.9, 110.3)
            second = _fixture_bar(
                start + 21 * 300,
                110.2,
                110.6,
                110.1,
                110.4,
                tick_volume=activity,
                mids=required_mids if level == 2 else wrong_mids,
            )
            retest = _fixture_bar(start + 22 * 300, 110.3, 110.4, 109.9, 110.1)
            confirm = _fixture_bar(
                start + 23 * 300,
                110.2,
                110.7,
                110.1,
                110.5,
                mids=[100.0, 101.0] if level == 2 else wrong_mids,
            )
            context_close, bid, ask = 111.0, 110.45, 110.50
        else:
            first = _fixture_bar(start + 20 * 300, 100.0, 100.1, 99.5, 99.7)
            second = _fixture_bar(
                start + 21 * 300,
                99.8,
                99.9,
                99.4,
                99.6,
                tick_volume=activity,
                mids=required_mids if level == 2 else wrong_mids,
            )
            retest = _fixture_bar(start + 22 * 300, 99.7, 100.1, 99.6, 99.9)
            confirm = _fixture_bar(
                start + 23 * 300,
                99.8,
                99.9,
                99.3,
                99.5,
                mids=[101.0, 100.0] if level == 2 else wrong_mids,
            )
            context_close, bid, ask = 99.0, 99.50, 99.55
        if level == 0 and not gate_pass:
            second["close"] = 110.0 if is_long else 100.0
            second["high"] = max(second["high"], second["close"])
            second["low"] = min(second["low"], second["close"])
        bars.extend((first, second, retest, confirm))

    final_close = bars[-1]["close_time"]
    return {
        "variant": variant,
        "labels": {
            "data_identity": PROXY_DATA_IDENTITY,
            "profile_identity": PROFILE_IDENTITY,
            "imbalance_identity": QUOTE_IMBALANCE_IDENTITY,
            "session_id": SESSION_IDENTITY,
            "signal_instrument_id": "XAUUSD.fixture",
            "signal_source_id": "fixture-source-1",
        },
        "profile": {
            "record_id": "profile-1",
            "instrument_id": "XAUUSD.fixture",
            "source_id": "fixture-source-1",
            "previous_d1_record_id": "d1-100",
            "previous_d1_sequence": 100,
            "previous_d1_open_time": 1,
            "current_d1_record_id": "d1-101",
            "current_d1_sequence": 101,
            "current_d1_open_time": 86_401,
            "session_start": 1,
            "session_end": 86_401,
            "available_at": 86_401,
            "completed": True,
            "val": 100.0,
            "poc": 105.0,
            "vah": 110.0,
        },
        "contexts": [
            {
                "record_id": "m15-1",
                "instrument_id": "XAUUSD.fixture",
                "source_id": "fixture-source-1",
                "d1_record_id": "d1-101",
                "d1_sequence": 101,
                "d1_open_time": 86_401,
                "open_time": 86_401,
                "close_time": 87_301,
                "available_at": 87_301,
                "period_seconds": 900,
                "completed": True,
                "close": context_close,
            }
        ],
        "bars": bars,
        "quote": {
            "record_id": "quote-1",
            "instrument_id": "XAUUSD.fixture",
            "source_id": "fixture-source-1",
            "d1_record_id": "d1-101",
            "d1_sequence": 101,
            "d1_open_time": 86_401,
            "observed_at": final_close + 1,
            "available_at": final_close + 1,
            "bid": bid,
            "ask": ask,
            "all_in_cost_price": 0.0,
        },
        "evaluation_time": final_close + 2,
    }


def replay_fixture(path: Path, *, expected_class: str) -> dict[str, Any]:
    package = json.loads(path.read_text(encoding="utf-8"))
    if package.get("schema") != "orderflow_proxy_fixture/v1":
        raise ProxyContractError("INVALID_FIXTURE_SCHEMA")
    if package.get("record_class") != expected_class or expected_class != "FIXTURE":
        raise ProxyContractError("FIXTURE_CLASS_MISMATCH")
    cases = package.get("cases")
    if not isinstance(cases, list) or not cases:
        raise ProxyContractError("EMPTY_FIXTURE_PACKAGE")
    results = []
    variant_counts: Counter[str] = Counter()
    for descriptor in cases:
        result = evaluate_variant(_expand_fixture_descriptor(descriptor))
        passed = result["status"] == descriptor.get("expected_status")
        results.append(
            {
                "id": descriptor.get("id"),
                "variant": descriptor.get("variant"),
                "direction": descriptor.get("direction"),
                "expected_status": descriptor.get("expected_status"),
                "actual_status": result["status"],
                "passed": passed,
            }
        )
        variant_counts[descriptor["variant"]] += 1
    passed_count = sum(bool(result["passed"]) for result in results)
    return {
        "schema": package["schema"],
        "record_class": package["record_class"],
        "case_count": len(results),
        "passed": passed_count,
        "failed": len(results) - passed_count,
        "variant_counts": dict(sorted(variant_counts.items())),
        "results": results,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--expect-class", default="FIXTURE")
    args = parser.parse_args(argv)
    try:
        summary = replay_fixture(args.input, expected_class=args.expect_class)
    except (OSError, json.JSONDecodeError, ProxyContractError) as error:
        print(json.dumps({"status": "REFUSED", "error": str(error)}, sort_keys=True))
        return 2
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0 if summary["failed"] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
