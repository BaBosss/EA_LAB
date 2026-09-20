#!/usr/bin/env python3
"""Strictly compare a receipt-bound MQL tester journal with the Python ledger."""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path
from typing import Any

import receipt_validation as receipts


CASE_PREFIX = "OFP_NATIVE_PARITY_CASE|"
SENTINEL_PREFIX = "OFP_NATIVE_PARITY_COMPLETED|"
LEDGER_SCHEMA = "orderflow_proxy_native_expected_ledger/v1"
RESULT_SCHEMA = "orderflow_proxy_native_parity_result/v2"
REQUIRED_CASE_FIELDS = {
    "run_id", "native_origin", "run_class", "case_id", "variant", "status",
    "replay_return", "direction", "current_closed_bar_record_id", "setup_time",
    "trigger_time", "prospective_entry", "stop_price", "target_price", "net_rr",
    "data_identity", "profile_identity", "imbalance_identity", "fixture_sha256",
    "source_graph_sha256",
}
EXPECTED_CASE_FIELDS = {
    "case_id", "variant", "descriptor_direction", "scenario", "status", "direction",
    "current_closed_bar_record_id", "setup_time", "trigger_time", "prospective_entry",
    "stop_price", "target_price", "net_rr", "data_identity", "profile_identity",
    "imbalance_identity",
}
EXPECTED_COMPARE_FIELDS = {
    "case_id", "variant", "status", "direction", "current_closed_bar_record_id",
    "setup_time", "trigger_time", "prospective_entry", "stop_price", "target_price",
    "net_rr", "data_identity", "profile_identity", "imbalance_identity",
}
EXPECTED_VARIANTS = ("OFPR-00", "OFPR-01", "OFPR-02", "OFPC-00", "OFPC-01", "OFPC-02")
FIXED_DECIMAL_RE = re.compile(r"-?[0-9]+\.[0-9]{12}\Z")


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


def _expect_type(value: Any, expected_type: type, label: str) -> Any:
    if type(value) is not expected_type:
        raise NativeParityError(f"INVALID_EXPECTED_{label}_TYPE")
    return value


def _validate_expected(expected_bytes: bytes) -> dict[str, Any]:
    try:
        data = receipts.load_strict_json(expected_bytes, "EXPECTED_LEDGER")
    except receipts.ReceiptValidationError as error:
        raise NativeParityError(str(error)) from error
    if set(data) != {
        "schema", "classification", "record_class", "case_count", "float_comparison",
        "fixture", "source_graph", "variant_counts", "cases",
    }:
        raise NativeParityError("INVALID_EXPECTED_LEDGER_FIELDS")
    if data["schema"] != LEDGER_SCHEMA or data["record_class"] != "SYNTHETIC_FIXTURE":
        raise NativeParityError("INVALID_EXPECTED_LEDGER_IDENTITY")
    if data["classification"] != "EXPECTED_PYTHON_SYNTHETIC_FIXTURE_LEDGER":
        raise NativeParityError("INVALID_EXPECTED_LEDGER_CLASSIFICATION")
    if type(data["case_count"]) is not int or data["case_count"] != 24:
        raise NativeParityError("INVALID_EXPECTED_CASE_COUNT")
    if data["float_comparison"] != {
        "method": "EXACT_FIXED_DECIMAL_STRING", "decimal_places": 12, "tolerance": None,
    }:
        raise NativeParityError("INVALID_FLOAT_COMPARISON_CONTRACT")

    fixture = _expect_type(data["fixture"], dict, "FIXTURE")
    if set(fixture) != {"path", "bytes", "sha256"}:
        raise NativeParityError("INVALID_EXPECTED_FIXTURE_FIELDS")
    if fixture["path"] != "tools/orderflow_proxy/fixtures/mirrored_cases.json":
        raise NativeParityError("INVALID_EXPECTED_FIXTURE_PATH")
    if type(fixture["bytes"]) is not int or fixture["bytes"] <= 0:
        raise NativeParityError("INVALID_EXPECTED_FIXTURE_BYTES_TYPE")
    if type(fixture["sha256"]) is not str or receipts.SHA256_RE.fullmatch(fixture["sha256"]) is None:
        raise NativeParityError("INVALID_EXPECTED_FIXTURE_SHA256")

    source_graph = _expect_type(data["source_graph"], dict, "SOURCE_GRAPH")
    if set(source_graph) != {"sha256", "files"}:
        raise NativeParityError("INVALID_EXPECTED_SOURCE_GRAPH_FIELDS")
    if type(source_graph["sha256"]) is not str or receipts.SHA256_RE.fullmatch(source_graph["sha256"]) is None:
        raise NativeParityError("INVALID_EXPECTED_SOURCE_GRAPH_SHA256")
    source_files = _expect_type(source_graph["files"], list, "SOURCE_GRAPH_FILES")
    if len(source_files) != 7:
        raise NativeParityError("INVALID_EXPECTED_SOURCE_GRAPH_COUNT")
    source_paths: list[str] = []
    for row in source_files:
        if type(row) is not dict or set(row) != {"path", "bytes", "sha256"}:
            raise NativeParityError("INVALID_EXPECTED_SOURCE_GRAPH_ROW")
        if type(row["path"]) is not str or not row["path"]:
            raise NativeParityError("INVALID_EXPECTED_SOURCE_GRAPH_PATH_TYPE")
        if type(row["bytes"]) is not int or row["bytes"] <= 0:
            raise NativeParityError("INVALID_EXPECTED_SOURCE_GRAPH_BYTES_TYPE")
        if type(row["sha256"]) is not str or receipts.SHA256_RE.fullmatch(row["sha256"]) is None:
            raise NativeParityError("INVALID_EXPECTED_SOURCE_GRAPH_FILE_SHA256")
        source_paths.append(row["path"])
    if len(set(source_paths)) != len(source_paths):
        raise NativeParityError("DUPLICATE_EXPECTED_SOURCE_GRAPH_PATH")

    expected_counts = {variant: 4 for variant in EXPECTED_VARIANTS}
    if data["variant_counts"] != dict(sorted(expected_counts.items())):
        raise NativeParityError("INVALID_EXPECTED_VARIANT_COUNTS")
    cases = _expect_type(data["cases"], list, "CASES")
    if len(cases) != 24:
        raise NativeParityError("INVALID_EXPECTED_CASE_COUNT")
    ids: list[str] = []
    matrix: set[tuple[str, str, str]] = set()
    for row in cases:
        if type(row) is not dict or set(row) != EXPECTED_CASE_FIELDS:
            raise NativeParityError("INVALID_EXPECTED_CASE_FIELDS")
        for field in (
            "case_id", "variant", "descriptor_direction", "scenario", "status",
            "current_closed_bar_record_id", "data_identity", "profile_identity",
            "imbalance_identity",
        ):
            if type(row[field]) is not str or not row[field]:
                raise NativeParityError(f"INVALID_EXPECTED_{field.upper()}_TYPE")
        for field in ("direction", "setup_time", "trigger_time"):
            if type(row[field]) is not int:
                raise NativeParityError(f"INVALID_EXPECTED_{field.upper()}_TYPE")
        for field in ("prospective_entry", "stop_price", "target_price", "net_rr"):
            if type(row[field]) is not str or FIXED_DECIMAL_RE.fullmatch(row[field]) is None:
                raise NativeParityError(f"INVALID_EXPECTED_{field.upper()}_FORMAT")
        if row["variant"] not in EXPECTED_VARIANTS:
            raise NativeParityError("INVALID_EXPECTED_VARIANT")
        if row["descriptor_direction"] not in {"long", "short"}:
            raise NativeParityError("INVALID_EXPECTED_DESCRIPTOR_DIRECTION")
        if row["scenario"] not in {"positive", "gate_negative"}:
            raise NativeParityError("INVALID_EXPECTED_SCENARIO")
        required_status = "SIGNAL" if row["scenario"] == "positive" else "NO_SIGNAL"
        if row["status"] != required_status:
            raise NativeParityError("EXPECTED_SCENARIO_STATUS_CONTRADICTION")
        ids.append(row["case_id"])
        matrix.add((row["variant"], row["descriptor_direction"], row["scenario"]))
    if len(set(ids)) != 24:
        raise NativeParityError("INVALID_EXPECTED_CASE_IDS")
    expected_matrix = {
        (variant, direction, scenario)
        for variant in EXPECTED_VARIANTS
        for direction in ("long", "short")
        for scenario in ("positive", "gate_negative")
    }
    if matrix != expected_matrix or Counter(row["variant"] for row in cases) != Counter(expected_counts):
        raise NativeParityError("INVALID_EXPECTED_VARIANT_MATRIX")
    return data


def compare_native_log(
    log_text: str | bytes,
    expected: dict[str, Any] | bytes,
    *,
    expected_run_id: str | None = None,
    package_manifest_bytes: bytes | None = None,
    runtime_request_bytes: bytes | None = None,
    generated_include_bytes: bytes | None = None,
    ea_source_bytes: bytes | None = None,
    ex5_bytes: bytes | None = None,
    terminal_config_bytes: bytes | None = None,
    tester_config_bytes: bytes | None = None,
    receipt_bytes: bytes | None = None,
    controller_evidence_bytes: bytes | None = None,
    expected_controller_evidence_sha256: str | None = None,
    repository_root: Path | None = None,
) -> dict[str, Any]:
    """Validate the trust chain, then compare the exact journal and ledger."""

    if receipt_bytes is None or controller_evidence_bytes is None or expected_controller_evidence_sha256 is None:
        raise NativeParityError("TRUSTED_CONTROLLER_RECEIPT_REQUIRED")
    required_inputs = (
        package_manifest_bytes, runtime_request_bytes, generated_include_bytes, ea_source_bytes,
        ex5_bytes, terminal_config_bytes, tester_config_bytes, repository_root,
    )
    if any(value is None for value in required_inputs) or type(expected) is not bytes:
        raise NativeParityError("COMPLETE_BOUND_NATIVE_INPUT_SET_REQUIRED")
    native_journal_bytes = log_text.encode("utf-8") if type(log_text) is str else log_text
    if type(native_journal_bytes) is not bytes:
        raise NativeParityError("INVALID_NATIVE_JOURNAL_TYPE")
    try:
        trusted = receipts.validate_controller_receipt(
            manifest_bytes=package_manifest_bytes,
            expected_ledger_bytes=expected,
            generated_include_bytes=generated_include_bytes,
            runtime_request_bytes=runtime_request_bytes,
            ea_source_bytes=ea_source_bytes,
            ex5_bytes=ex5_bytes,
            terminal_config_bytes=terminal_config_bytes,
            tester_config_bytes=tester_config_bytes,
            native_journal_bytes=native_journal_bytes,
            receipt_bytes=receipt_bytes,
            controller_evidence_bytes=controller_evidence_bytes,
            expected_controller_evidence_sha256=expected_controller_evidence_sha256,
            repository_root=repository_root,
        )
    except receipts.ReceiptValidationError as error:
        raise NativeParityError(str(error)) from error
    if expected_run_id is not None and expected_run_id != trusted.runtime_contract_id:
        raise NativeParityError("CALLER_RUNTIME_ID_DOES_NOT_MATCH_TRUSTED_CONTROLLER_EVIDENCE")

    expected_data = _validate_expected(expected)
    try:
        manifest_data = receipts.load_strict_json(package_manifest_bytes, "PACKAGE_MANIFEST")
    except receipts.ReceiptValidationError as error:
        raise NativeParityError(str(error)) from error
    if expected_data["fixture"] != manifest_data["fixture"]:
        raise NativeParityError("EXPECTED_LEDGER_FIXTURE_BINDING_MISMATCH")
    if expected_data["source_graph"] != manifest_data["source_graph"]:
        raise NativeParityError("EXPECTED_LEDGER_SOURCE_GRAPH_BINDING_MISMATCH")
    if expected_data["fixture"]["sha256"] != trusted.fixture_sha256:
        raise NativeParityError("EXPECTED_LEDGER_FIXTURE_SHA256_MISMATCH")
    if expected_data["source_graph"]["sha256"] != trusted.source_graph_sha256:
        raise NativeParityError("EXPECTED_LEDGER_SOURCE_GRAPH_SHA256_MISMATCH")
    try:
        decoded_log = native_journal_bytes.decode("utf-8", errors="strict")
    except UnicodeDecodeError as error:
        raise NativeParityError(f"MALFORMED_NATIVE_JOURNAL_UTF8:{error}") from error

    native_cases, sentinels = _extract(decoded_log)
    if len(sentinels) != 1:
        raise NativeParityError("MISSING_OR_DUPLICATE_COMPLETED_SENTINEL")
    sentinel = sentinels[0]
    required_sentinel = {
        "run_id", "native_origin", "run_class", "case_count", "fixture_sha256",
        "source_graph_sha256",
    }
    if set(sentinel) != required_sentinel:
        raise NativeParityError("INVALID_SENTINEL_FIELDS")
    fixture_sha = expected_data["fixture"]["sha256"]
    source_sha = expected_data["source_graph"]["sha256"]
    if sentinel != {
        "run_id": trusted.runtime_contract_id,
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
        if row["run_id"] != trusted.runtime_contract_id:
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

    expected_ids = {row["case_id"] for row in expected_data["cases"]}
    if set(by_id) != expected_ids:
        raise NativeParityError("MISSING_OR_EXTRA_NATIVE_CASE_IDS")
    mismatches: list[dict[str, str]] = []
    for expected_row in expected_data["cases"]:
        actual = by_id[expected_row["case_id"]]
        for field in sorted(EXPECTED_COMPARE_FIELDS):
            expected_value = str(expected_row[field])
            if actual[field] != expected_value:
                mismatches.append({
                    "case_id": expected_row["case_id"], "field": field,
                    "expected": expected_value, "actual": actual[field],
                })
    if mismatches:
        raise NativeParityError("NATIVE_PARITY_MISMATCH:" + json.dumps(mismatches, sort_keys=True))

    common = {
        "schema": RESULT_SCHEMA,
        "run_id": trusted.runtime_contract_id,
        "case_count": 24,
        "fixture_sha256": fixture_sha,
        "source_graph_sha256": source_sha,
        "bridge_source_head": trusted.bridge_source_head,
        "controller_evidence_id": trusted.controller_evidence_id,
        "controller_evidence_sha256": trusted.controller_evidence_sha256,
        "receipt_sha256": trusted.receipt_sha256,
        "limitations": [
            "NOT_REAL_DATA_PARITY", "NOT_STRATEGY_PERFORMANCE",
            "NO_FILL_RISK_PNL_OR_PRODUCTION_QUALIFICATION",
            "PARSER_VALIDATES_PINNED_BYTES_BUT_DOES_NOT_ATTEST_MACHINE_EXECUTION",
        ],
    }
    if trusted.evidence_scope == receipts.FIXTURE_SCOPE:
        return {
            **common,
            "classification": "FIXTURE_ONLY_CONTROLLER_RECEIPT_SHAPE_INTEGRITY",
            "status": "FIXTURE_INTEGRITY_PASS",
            "native_execution_qualified": False,
            "execution_status": "NOT_EXECUTED",
        }
    return {
        **common,
        "classification": "SYNTHETIC_FIXTURE_NATIVE_PARITY_ONLY",
        "status": "PASS",
        "native_execution_qualified": True,
        "execution_status": "CONTROLLER_RECEIPT_BOUND_EXECUTION",
    }


def _read(path: Path) -> bytes:
    return path.read_bytes()


def main(argv: list[str] | None = None) -> int:
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("--native-log", type=Path, required=True)
    cli.add_argument("--expected-ledger", type=Path, required=True)
    cli.add_argument("--package-manifest", type=Path, required=True)
    cli.add_argument("--runtime-request", type=Path, required=True)
    cli.add_argument("--generated-include", type=Path, required=True)
    cli.add_argument("--ea-source", type=Path, required=True)
    cli.add_argument("--ex5", type=Path, required=True)
    cli.add_argument("--terminal-config", type=Path, required=True)
    cli.add_argument("--tester-config", type=Path, required=True)
    cli.add_argument("--controller-receipt", type=Path, required=True)
    cli.add_argument("--trusted-controller-evidence", type=Path, required=True)
    cli.add_argument("--expected-controller-evidence-sha256", required=True)
    cli.add_argument("--repository-root", type=Path, required=True)
    cli.add_argument("--output", type=Path)
    args = cli.parse_args(argv)
    try:
        result = compare_native_log(
            _read(args.native_log), _read(args.expected_ledger),
            package_manifest_bytes=_read(args.package_manifest),
            runtime_request_bytes=_read(args.runtime_request),
            generated_include_bytes=_read(args.generated_include),
            ea_source_bytes=_read(args.ea_source), ex5_bytes=_read(args.ex5),
            terminal_config_bytes=_read(args.terminal_config),
            tester_config_bytes=_read(args.tester_config),
            receipt_bytes=_read(args.controller_receipt),
            controller_evidence_bytes=_read(args.trusted_controller_evidence),
            expected_controller_evidence_sha256=args.expected_controller_evidence_sha256,
            repository_root=args.repository_root,
        )
        payload = json.dumps(result, indent=2, sort_keys=True) + "\n"
        if args.output is not None:
            args.output.write_text(payload, encoding="utf-8", newline="\n")
        print(payload, end="")
        return 0
    except (OSError, NativeParityError, KeyError, TypeError) as error:
        print(json.dumps({"status": "REFUSED", "error": str(error)}, sort_keys=True))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
