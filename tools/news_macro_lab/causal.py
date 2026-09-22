from __future__ import annotations

from copy import deepcopy
from typing import Any

from .core import MACRO_STATES, Refused, checksum, finite, sha256, text, utc

_REQUIRED_CLOCK = ("version", "source_timezone", "broker_timezone", "mapping_basis")
_ROW_FIELDS = {
    "record_id", "revision_id", "effective_at_utc", "available_at_utc",
    "valid_until_utc", "regime_state", "risk_index", "source_inputs",
}
_INPUT_FIELDS = {"source_id", "source_snapshot_sha256", "available_at_utc"}


def _unique_texts(values: Any, reason: str) -> list[str]:
    if (not isinstance(values, list) or not values or
            any(not isinstance(v, str) or not v.strip() for v in values) or
            len(set(values)) != len(values)):
        raise Refused(reason)
    return list(values)


def build_causal_regime_package(
    rows: list[dict[str, Any]], source_bundle_raw: bytes, *,
    dataset_id: str, dataset_version: str, series_id: str,
    classifier_sha256: str, required_source_ids: list[str],
    coverage_start_utc: str, coverage_end_utc: str,
    clock_mapping: dict[str, str],
) -> dict[str, Any]:
    """Bind precomputed regime states to the latest input availability.

    This does not run or validate the classifier and cannot certify that the
    normalized rows were derived correctly from the supplied raw bundle.
    """
    text(dataset_id); text(dataset_version); text(series_id)
    checksum(classifier_sha256)
    source_ids = _unique_texts(required_source_ids, "EXPLICIT_UNIQUE_SOURCE_IDS_REQUIRED")
    if not isinstance(source_bundle_raw, bytes) or not source_bundle_raw:
        raise Refused("RAW_SOURCE_BUNDLE_REQUIRED")
    start, end = utc(coverage_start_utc), utc(coverage_end_utc)
    if start >= end:
        raise Refused("COVERAGE_ORDER_INVALID")
    if not isinstance(clock_mapping, dict) or any(
        not isinstance(clock_mapping.get(k), str) or not clock_mapping[k].strip()
        for k in _REQUIRED_CLOCK
    ):
        raise Refused("EXPLICIT_CLOCK_MAPPING_REQUIRED")
    if not isinstance(rows, list) or not rows:
        raise Refused("REGIME_ROWS_REQUIRED")

    output = []
    record_ids: set[str] = set()
    effective_seen = set()
    for row in rows:
        if not isinstance(row, dict) or set(row) != _ROW_FIELDS:
            raise Refused("REGIME_ROW_SCHEMA_MISMATCH")
        record_id, revision_id = text(row["record_id"]), text(row["revision_id"])
        if record_id in record_ids:
            raise Refused("DUPLICATE_REGIME_RECORD_ID")
        record_ids.add(record_id)
        effective = utc(row["effective_at_utc"])
        available = utc(row["available_at_utc"])
        valid_until = utc(row["valid_until_utc"])
        if effective in effective_seen:
            raise Refused("DUPLICATE_REGIME_EFFECTIVE_TIME")
        effective_seen.add(effective)
        if not (start <= effective <= available < valid_until <= end):
            raise Refused("REGIME_CAUSAL_CLOCK_ORDER_INVALID")
        if row["regime_state"] not in MACRO_STATES:
            raise Refused("UNKNOWN_REGIME_VOCABULARY")
        risk_index = finite(row["risk_index"])
        inputs = row["source_inputs"]
        if not isinstance(inputs, list) or len(inputs) != len(source_ids):
            raise Refused("EXACT_SOURCE_INPUT_SET_REQUIRED")
        seen = set()
        latest_input = None
        normalized_inputs = []
        for item in inputs:
            if not isinstance(item, dict) or set(item) != _INPUT_FIELDS:
                raise Refused("SOURCE_INPUT_SCHEMA_MISMATCH")
            source_id = text(item["source_id"])
            if source_id not in source_ids or source_id in seen:
                raise Refused("EXACT_SOURCE_INPUT_SET_REQUIRED")
            seen.add(source_id)
            digest = checksum(item["source_snapshot_sha256"])
            source_available = utc(item["available_at_utc"])
            if source_available > available:
                raise Refused("REGIME_VISIBLE_BEFORE_INPUT_AVAILABLE")
            latest_input = source_available if latest_input is None else max(latest_input, source_available)
            normalized_inputs.append({
                "source_id": source_id,
                "source_snapshot_sha256": digest,
                "available_at_utc": item["available_at_utc"],
            })
        if seen != set(source_ids):
            raise Refused("EXACT_SOURCE_INPUT_SET_REQUIRED")
        if latest_input is None or available < latest_input:
            raise Refused("REGIME_VISIBLE_BEFORE_INPUT_AVAILABLE")
        if effective < latest_input:
            raise Refused("REGIME_EFFECTIVE_BEFORE_INPUT_AVAILABLE")
        normalized_inputs.sort(key=lambda x: x["source_id"])
        output.append({
            "record_id": record_id,
            "revision_id": revision_id,
            "record_type": "REGIME_OBSERVATION",
            "state": "FINAL",
            "available_at_utc": row["available_at_utc"],
            "effective_at_utc": row["effective_at_utc"],
            "source_observed_at_utc": latest_input.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "valid_until_utc": row["valid_until_utc"],
            "classifier_sha256": classifier_sha256,
            "series_id": series_id,
            "regime_state": row["regime_state"],
            "risk_index": risk_index,
            "source_inputs": normalized_inputs,
        })

    output.sort(key=lambda r: (utc(r["effective_at_utc"]), utc(r["available_at_utc"]), r["record_id"]))
    return {
        "schema_version": "ea_lab_offline_replay_package/1",
        "classification": "UNQUALIFIED_CAUSAL_REGIME_PREPARATION",
        "dataset_id": dataset_id,
        "dataset_version": dataset_version,
        "source_snapshot_sha256": sha256(source_bundle_raw),
        "decision_at_utc": coverage_start_utc,
        "coverage": {
            "state": "COMPLETE",
            "start_utc": coverage_start_utc,
            "end_utc": coverage_end_utc,
        },
        "clock_mapping": deepcopy(clock_mapping),
        "records": output,
        "historical_dataset_qualified": False,
        "derivation_verified": False,
        "can_execute": False,
        "performance": "NOT_RUN",
        "ea_actions": [],
    }
