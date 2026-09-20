#!/usr/bin/env python3
"""Strictly compare an actual MQL tester journal against the Python fixture ledger."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


CASE_PREFIX = "OFP_NATIVE_PARITY_CASE|"
SENTINEL_PREFIX = "OFP_NATIVE_PARITY_COMPLETED|"
LEDGER_SCHEMA = "orderflow_proxy_native_expected_ledger/v1"
RESULT_SCHEMA = "orderflow_proxy_native_parity_result/v1"
REQUIRED_CASE_FIELDS = {
    "run_id",
    "native_origin",
    "run_class",
    "case_id",
    "variant",
    "status",
    "replay_return",
    "direction",
    "current_closed_bar_record_id",
    "setup_time",
    "trigger_time",
    "prospective_entry",
    "stop_price",
    "target_price",
    "net_rr",
    "data_identity",
    "profile_identity",
    "imbalance_identity",
    "fixture_sha256",
    "source_graph_sha256",
}
EXPECTED_COMPARE_FIELDS = {
    "case_id",
    "variant",
    "status",
    "direction",
    "current_closed_bar_record_id",
    "setup_time",
    "trigger_time",
    "prospective_entry",
    "stop_price",
    "target_price",
    "net_rr",
    "data_identity",
    "profile_identity",
    "imbalance_identity",
}
PLACEHOLDER_RUN_IDS = {"", "NOT_EXECUTED_UNFROZEN", "UNKNOWN", "GENERATED"}


class NativeParityError(ValueError):
    pass


def _parse_record(fragment: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for token in fragment.rstrip("\r\n").split("|"):
        if "=" not in token:
            raise NativeParityError("MALFORMED_NATIVE_FIELD")
        key, value = token.split("=", 1)
        if not key or key in fields:
            raise NativeParityError("EMPTY_OR_DUPLICATE_NATIVE_FIELD")
        fields[key] = value
    return fields


def _extract(log_text: str) -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    cases: list[dict[str, str]] = []
    sentinels: list[dict[str, str]] = []
    for line in log_text.splitlines():
        case_at = line.find(CASE_PREFIX)
        sentinel_at = line.find(SENTINEL_PREFIX)
        if case_at >= 0:
            cases.append(_parse_record(line[case_at + len(CASE_PREFIX) :]))
        if sentinel_at >= 0:
            sentinels.append(_parse_record(line[sentinel_at + len(SENTINEL_PREFIX) :]))
    return cases, sentinels


def _load_expected(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("schema") != LEDGER_SCHEMA or data.get("record_class") != "SYNTHETIC_FIXTURE":
        raise NativeParityError("INVALID_EXPECTED_LEDGER_IDENTITY")
    if data.get("case_count") != 24 or len(data.get("cases", [])) != 24:
        raise NativeParityError("INVALID_EXPECTED_CASE_COUNT")
    comparison = data.get("float_comparison", {})
    if comparison != {"method": "EXACT_FIXED_DECIMAL_STRING", "decimal_places": 12, "tolerance": None}:
        raise NativeParityError("INVALID_FLOAT_COMPARISON_CONTRACT")
    ids = [row.get("case_id") for row in data["cases"]]
    if len(set(ids)) != 24 or any(not isinstance(value, str) or not value for value in ids):
        raise NativeParityError("INVALID_EXPECTED_CASE_IDS")
    if Counter(row.get("variant") for row in data["cases"]) != Counter(
        {variant: 4 for variant in ("OFPR-00", "OFPR-01", "OFPR-02", "OFPC-00", "OFPC-01", "OFPC-02")}
    ):
        raise NativeParityError("INVALID_EXPECTED_VARIANT_MATRIX")
    return data


def compare_native_log(
    log_text: str, expected: dict[str, Any], *, expected_run_id: str
) -> dict[str, Any]:
    if expected_run_id in PLACEHOLDER_RUN_IDS or not expected_run_id.startswith("OFP-NATIVE-FIXTURE-"):
        raise NativeParityError("UNKNOWN_OR_UNFROZEN_RUNTIME_CONTRACT_ID")
    native_cases, sentinels = _extract(log_text)
    if len(sentinels) != 1:
        raise NativeParityError("MISSING_OR_DUPLICATE_COMPLETED_SENTINEL")
    sentinel = sentinels[0]
    required_sentinel = {
        "run_id",
        "native_origin",
        "run_class",
        "case_count",
        "fixture_sha256",
        "source_graph_sha256",
    }
    if set(sentinel) != required_sentinel:
        raise NativeParityError("INVALID_SENTINEL_FIELDS")
    fixture_sha = expected["fixture"]["sha256"]
    source_sha = expected["source_graph"]["sha256"]
    if sentinel != {
        "run_id": expected_run_id,
        "native_origin": "ACTUAL_CANONICAL_MQL_REPLAY",
        "run_class": "SYNTHETIC_FIXTURE",
        "case_count": "24",
        "fixture_sha256": fixture_sha,
        "source_graph_sha256": source_sha,
    }:
        raise NativeParityError("SENTINEL_IDENTITY_MISMATCH")
    if len(native_cases) != 24:
        raise NativeParityError("MISSING_OR_EXTRA_NATIVE_CASES")

    by_id: dict[str, dict[str, str]] = {}
    for row in native_cases:
        if set(row) != REQUIRED_CASE_FIELDS:
            raise NativeParityError("INVALID_NATIVE_CASE_FIELDS")
        case_id = row["case_id"]
        if case_id in by_id:
            raise NativeParityError("DUPLICATE_NATIVE_CASE")
        if row["run_id"] != expected_run_id:
            raise NativeParityError("NATIVE_RUN_ID_MISMATCH")
        if row["native_origin"] != "ACTUAL_CANONICAL_MQL_REPLAY" or row["run_class"] != "SYNTHETIC_FIXTURE":
            raise NativeParityError("GENERATED_OR_UNKNOWN_NATIVE_RUN")
        if row["fixture_sha256"] != fixture_sha or row["source_graph_sha256"] != source_sha:
            raise NativeParityError("NATIVE_SOURCE_OR_FIXTURE_HASH_MISMATCH")
        if row["replay_return"] not in {"true", "false"}:
            raise NativeParityError("INVALID_REPLAY_RETURN")
        if (row["status"] == "SIGNAL") != (row["replay_return"] == "true"):
            raise NativeParityError("REPLAY_RETURN_STATUS_CONTRADICTION")
        by_id[case_id] = row

    expected_ids = {row["case_id"] for row in expected["cases"]}
    if set(by_id) != expected_ids:
        raise NativeParityError("MISSING_OR_EXTRA_NATIVE_CASE_IDS")
    mismatches: list[dict[str, str]] = []
    for expected_row in expected["cases"]:
        actual = by_id[expected_row["case_id"]]
        for field in sorted(EXPECTED_COMPARE_FIELDS):
            expected_value = str(expected_row[field])
            if actual[field] != expected_value:
                mismatches.append(
                    {
                        "case_id": expected_row["case_id"],
                        "field": field,
                        "expected": expected_value,
                        "actual": actual[field],
                    }
                )
    if mismatches:
        raise NativeParityError("NATIVE_PARITY_MISMATCH:" + json.dumps(mismatches, sort_keys=True))
    return {
        "schema": RESULT_SCHEMA,
        "classification": "SYNTHETIC_FIXTURE_NATIVE_PARITY_ONLY",
        "status": "PASS",
        "run_id": expected_run_id,
        "case_count": 24,
        "fixture_sha256": fixture_sha,
        "source_graph_sha256": source_sha,
        "limitations": [
            "NOT_REAL_DATA_PARITY",
            "NOT_STRATEGY_PERFORMANCE",
            "NO_FILL_RISK_PNL_OR_PRODUCTION_QUALIFICATION",
        ],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native-log", type=Path, required=True)
    parser.add_argument("--expected-ledger", type=Path, required=True)
    parser.add_argument("--expected-run-id", required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    try:
        expected = _load_expected(args.expected_ledger)
        result = compare_native_log(
            args.native_log.read_text(encoding="utf-8", errors="strict"),
            expected,
            expected_run_id=args.expected_run_id,
        )
        payload = json.dumps(result, indent=2, sort_keys=True) + "\n"
        if args.output is not None:
            args.output.write_text(payload, encoding="utf-8", newline="\n")
        print(payload, end="")
        return 0
    except (OSError, json.JSONDecodeError, NativeParityError, KeyError, TypeError) as error:
        print(json.dumps({"status": "REFUSED", "error": str(error)}, sort_keys=True))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
