#!/usr/bin/env python3
"""Build hash-bound ThinkMarkets A2 provider bundles for the frozen OFP windows.

This tool is deliberately offline.  It reads immutable review evidence and
never imports, initializes, or calls MetaTrader 5.  Its output is a
research-input envelope for the source-only Template seam, not a standing
provider certificate or execution authorization.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


POLICY_ID = "THINKMARKETS_LIVE_A2_V1"
CLASSIFICATION = "RESEARCH_INPUT_ONLY_CURRENT_WINDOW"
PROVIDER_SERVER = "ThinkMarkets-Live"
TERMINAL_BUILD = 6182
REVIEWED_REPO_HEAD = "041178539fe07a306af2b68b3209b8401822534c"
EVIDENCE_MANIFEST_SHA256 = "1b33325e46aceee5f80041e599cc1c20f71124adbbc726721b89bef83664ff0f"
ACCEPTED_SYMBOLS = ("XAUUSD", "EURUSD", "GBPUSD", "EURGBP", "USDJPY", "EURJPY")
BLOCKED_SYMBOLS = ("BTCUSD", "ETHUSD")
ALL_SYMBOLS = ACCEPTED_SYMBOLS + BLOCKED_SYMBOLS

EXPECTED_WINDOWS = {
    "XAUUSD": (1789603200, 1789689600, 1789775400),
    "EURUSD": (1789603200, 1789689600, 1789775100),
    "GBPUSD": (1789603200, 1789689600, 1789775100),
    "EURGBP": (1789603200, 1789689600, 1789775100),
    "USDJPY": (1789603200, 1789689600, 1789775100),
    "EURJPY": (1789603200, 1789689600, 1789775100),
}

EXPECTED_A2_SHA256 = {
    "CONTRACT.md": "44c1c60c972d23e109ebee87f6c466f08b14d2fb4e7f094890668d025bf03e7c",
    "RESULT.json": "32041f3476df1120b703659a18a41a2e56a19d6f53d1dc98d6b149934d50a066",
    "PASS1.json": "cb0377b6203850a63a7d7766161ee626bfd7a1b51c81046ae45adbdbeac60781",
    "PASS2.json": "cb0377b6203850a63a7d7766161ee626bfd7a1b51c81046ae45adbdbeac60781",
    "FROZEN_INTERVALS.json": "36e69639320736efa840c3b4ac7bd9e40495c2d53ba51650aa000e45d3e3365b",
    "EVIDENCE_MANIFEST.json": EVIDENCE_MANIFEST_SHA256,
    "REVIEW_OUTPUT.json": "76be643e0344b35a7307b8bd64de9b0fbf6d45d8cc2128502592fee96f583c68",
    "REVIEW_RECOVERY.json": "3a30c702080632beefe00120aafb6667aacf7201f65474f1b75efb564f3c4082",
}


class ProviderEvidenceError(ValueError):
    """Raised when A2 evidence cannot support the frozen provider bundle."""


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ProviderEvidenceError(f"INVALID_JSON:{path.name}") from error
    if not isinstance(value, dict):
        raise ProviderEvidenceError(f"INVALID_JSON_ROOT:{path.name}")
    return value


def _strict_int(value: Any, *, positive: bool = False) -> bool:
    return (
        isinstance(value, int)
        and not isinstance(value, bool)
        and (value > 0 if positive else value >= 0)
    )


def _sha256_shape(value: Any) -> bool:
    return (
        isinstance(value, str)
        and len(value) == 64
        and value == value.lower()
        and all(character in "0123456789abcdef" for character in value)
    )


def _require(condition: bool, reason: str) -> None:
    if not condition:
        raise ProviderEvidenceError(reason)


def symbol_record(document: dict[str, Any], logical_symbol: str) -> dict[str, Any]:
    symbols = document.get("symbols")
    _require(isinstance(symbols, list), "MALFORMED_SYMBOL_SET")
    matches = [item for item in symbols if isinstance(item, dict) and item.get("logical") == logical_symbol]
    _require(len(matches) == 1, f"SYMBOL_RECORD_COUNT_MISMATCH:{logical_symbol}")
    return matches[0]


def _validate_symbol_sets(document: dict[str, Any], label: str) -> None:
    symbols = document.get("symbols")
    _require(isinstance(symbols, list), f"MALFORMED_SYMBOL_SET:{label}")
    logical = [item.get("logical") if isinstance(item, dict) else None for item in symbols]
    _require(logical == list(ALL_SYMBOLS), f"SYMBOL_SET_MISMATCH:{label}")
    _require(len(set(logical)) == len(ALL_SYMBOLS), f"DUPLICATE_SYMBOL:{label}")


def _validate_manifest(root: Path, manifest: dict[str, Any]) -> None:
    _require(manifest.get("reviewed_repo_head") == REVIEWED_REPO_HEAD, "MANIFEST_REPO_HEAD_MISMATCH")
    _require(manifest.get("qualification_status") == "PARTIALLY_QUALIFIED_CURRENT_WINDOW", "MANIFEST_STATUS_MISMATCH")
    _require(manifest.get("provider") == PROVIDER_SERVER, "PROVIDER_IDENTITY_MISMATCH")
    _require(manifest.get("qualified_symbols") == list(ACCEPTED_SYMBOLS), "QUALIFIED_SYMBOL_SET_MISMATCH")
    _require(manifest.get("blocked_symbols") == list(BLOCKED_SYMBOLS), "BLOCKED_SYMBOL_SET_MISMATCH")
    _require(manifest.get("repo_clean") is True, "REVIEWED_REPO_NOT_CLEAN")
    entries = manifest.get("files")
    _require(isinstance(entries, list), "MALFORMED_MANIFEST_FILES")
    by_name: dict[str, list[dict[str, Any]]] = {}
    for entry in entries:
        _require(isinstance(entry, dict), "MALFORMED_MANIFEST_ENTRY")
        path_value = entry.get("path")
        _require(isinstance(path_value, str) and path_value, "MALFORMED_MANIFEST_PATH")
        name = Path(path_value).name
        by_name.setdefault(name, []).append(entry)
    for name in ("CONTRACT.md", "RESULT.json", "PASS1.json", "PASS2.json", "FROZEN_INTERVALS.json"):
        matching = [
            entry for entry in by_name.get(name, [])
            if entry.get("sha256") == EXPECTED_A2_SHA256[name]
        ]
        _require(len(matching) == 1, f"MANIFEST_ENTRY_MISSING_OR_AMBIGUOUS:{name}")
        entry = matching[0]
        _require(_strict_int(entry.get("bytes"), positive=True), f"MALFORMED_MANIFEST_BYTES:{name}")
        _require((root / name).stat().st_size == entry["bytes"], f"MANIFEST_BYTES_MISMATCH:{name}")


def _validate_review(documents: dict[str, Any]) -> None:
    review = documents["review"]
    recovery = documents["review_recovery"]
    _require(review.get("decision") == "SCRUTINY_PASS", "A2_REVIEW_NOT_PASS")
    _require(review.get("confidence") == "HIGH", "A2_REVIEW_NOT_HIGH_CONFIDENCE")
    _require(review.get("material_findings") == [], "A2_REVIEW_HAS_MATERIAL_FINDINGS")
    _require(review.get("reviewed_repo_head") == REVIEWED_REPO_HEAD, "REVIEWED_REPO_HEAD_MISMATCH")
    _require(review.get("evidence_manifest_sha256") == EVIDENCE_MANIFEST_SHA256, "REVIEW_MANIFEST_HASH_MISMATCH")
    _require(review.get("qualified_symbols") == list(ACCEPTED_SYMBOLS), "QUALIFIED_SYMBOL_SET_MISMATCH")
    _require(review.get("blocked_symbols") == list(BLOCKED_SYMBOLS), "BLOCKED_SYMBOL_SET_MISMATCH")
    _require(recovery.get("review_output_valid") is True, "REVIEW_RECOVERY_INVALID")
    _require(recovery.get("review_decision") == "SCRUTINY_PASS", "REVIEW_RECOVERY_DECISION_MISMATCH")
    _require(recovery.get("confidence") == "HIGH", "REVIEW_RECOVERY_CONFIDENCE_MISMATCH")
    _require(recovery.get("evidence_manifest_sha256") == EVIDENCE_MANIFEST_SHA256, "REVIEW_RECOVERY_MANIFEST_MISMATCH")
    _require(recovery.get("material_findings") == 0, "REVIEW_RECOVERY_FINDINGS_MISMATCH")
    _require(recovery.get("review_rerun") is False, "UNEXPECTED_REVIEW_RERUN")
    per_symbol = review.get("per_symbol_check")
    _require(isinstance(per_symbol, dict) and tuple(per_symbol) == ALL_SYMBOLS, "REVIEW_SYMBOL_SET_MISMATCH")
    for symbol in BLOCKED_SYMBOLS:
        item = per_symbol.get(symbol)
        _require(
            isinstance(item, dict)
            and item.get("broker_symbol") == symbol
            and item.get("qualified") is False
            and item.get("rate_snapshots_stable_both_passes") is False
            and item.get("blockers") == ["RATE_SNAPSHOT_CHANGED"],
            f"BLOCKED_SYMBOL_REVIEW_MISMATCH:{symbol}",
        )


def _validate_result(result: dict[str, Any]) -> None:
    _require(result.get("schema") == "ofp_thinkmarkets_sync_basis_qualification/v1", "RESULT_SCHEMA_MISMATCH")
    _require(result.get("status") == "PARTIALLY_QUALIFIED_CURRENT_WINDOW", "RESULT_STATUS_MISMATCH")
    _require(result.get("provider_server") == PROVIDER_SERVER, "PROVIDER_IDENTITY_MISMATCH")
    _require(result.get("identity_repeat") is True, "TERMINAL_IDENTITY_REPEAT_FAILED")
    _require(result.get("basis") == "MT5_SYNCED_COPY_TICKS_INFO_EXACT_REPEAT_PER_INTERVAL", "A2_BASIS_MISMATCH")
    _require(result.get("qualified_symbols") == list(ACCEPTED_SYMBOLS), "QUALIFIED_SYMBOL_SET_MISMATCH")
    _require(result.get("blocked_symbols") == list(BLOCKED_SYMBOLS), "BLOCKED_SYMBOL_SET_MISMATCH")
    _require(result.get("count_equality_descriptive_only") is True, "COUNT_EQUALITY_SEMANTICS_MISMATCH")
    _require(result.get("true_exchange_orderflow") is False, "TRUE_ORDERFLOW_MUST_BE_FALSE")
    _require(result.get("executed_volume_or_delta_qualified") is False, "EXECUTED_VOLUME_QUALIFICATION_MUST_BE_FALSE")
    _require(result.get("strategy_performance_authority") is False, "PERFORMANCE_AUTHORITY_MUST_BE_FALSE")
    _require(result.get("runtime_trading_authority") is False, "TRADING_AUTHORITY_MUST_BE_FALSE")
    _validate_symbol_sets(result, "RESULT")
    for symbol in ACCEPTED_SYMBOLS:
        item = symbol_record(result, symbol)
        _require(item.get("qualified") is True and item.get("blockers") == [], f"QUALIFIED_SYMBOL_RESULT_MISMATCH:{symbol}")
    for symbol in BLOCKED_SYMBOLS:
        item = symbol_record(result, symbol)
        _require(
            item.get("qualified") is False and item.get("blockers") == ["RATE_SNAPSHOT_CHANGED"],
            f"BLOCKED_SYMBOL_RESULT_MISMATCH:{symbol}",
        )


def _validate_terminal_identity(document: dict[str, Any], label: str) -> None:
    identity = document.get("identity")
    _require(isinstance(identity, dict), f"TERMINAL_IDENTITY_MISSING:{label}")
    _require(
        identity.get("server") == PROVIDER_SERVER
        and identity.get("build") == TERMINAL_BUILD
        and identity.get("name") == "MetaTrader 5"
        and identity.get("path") == r"D:\Meta 5",
        "TERMINAL_IDENTITY_MISMATCH",
    )


def _validate_loaded_documents(documents: dict[str, Any]) -> None:
    required = ("result", "pass1", "pass2", "frozen", "manifest", "review", "review_recovery")
    _require(all(isinstance(documents.get(name), dict) for name in required), "VERIFIED_DOCUMENTS_REQUIRED")
    _validate_review(documents)
    _validate_result(documents["result"])
    _require(documents["frozen"].get("schema") == "ofp_thinkmarkets_sync_frozen/v1", "FROZEN_SCHEMA_MISMATCH")
    for label in ("pass1", "pass2", "frozen"):
        _validate_symbol_sets(documents[label], label.upper())
    _validate_terminal_identity(documents["pass1"], "PASS1")
    _validate_terminal_identity(documents["pass2"], "PASS2")
    _require(documents["pass1"]["identity"] == documents["pass2"]["identity"], "TERMINAL_IDENTITY_REPEAT_FAILED")


def load_verified_evidence(root: Path) -> dict[str, Any]:
    """Load the exact reviewed A2 evidence after immutable hash verification."""

    root = Path(root)
    _require(root.is_dir(), "A2_EVIDENCE_ROOT_MISSING")
    for name, expected in EXPECTED_A2_SHA256.items():
        path = root / name
        _require(path.is_file(), f"EVIDENCE_FILE_MISSING:{name}")
        _require(_sha256(path) == expected, f"EVIDENCE_FILE_HASH_MISMATCH:{name}")

    documents = {
        "result": _load_json(root / "RESULT.json"),
        "pass1": _load_json(root / "PASS1.json"),
        "pass2": _load_json(root / "PASS2.json"),
        "frozen": _load_json(root / "FROZEN_INTERVALS.json"),
        "manifest": _load_json(root / "EVIDENCE_MANIFEST.json"),
        "review": _load_json(root / "REVIEW_OUTPUT.json"),
        "review_recovery": _load_json(root / "REVIEW_RECOVERY.json"),
    }
    _validate_manifest(root, documents["manifest"])
    _validate_loaded_documents(documents)
    return documents


def _validate_copy(copy_record: Any) -> None:
    _require(isinstance(copy_record, dict), "MALFORMED_COPY_RECEIPT")
    for field, reason in (
        ("count", "MALFORMED_COUNT"),
        ("valid_bid_ask", "MALFORMED_VALID_BID_ASK_COUNT"),
        ("first_time_msc", "MALFORMED_FIRST_TIME_MSC"),
        ("last_time_msc", "MALFORMED_LAST_TIME_MSC"),
    ):
        _require(_strict_int(copy_record.get(field), positive=True), reason)
    _require(_sha256_shape(copy_record.get("sha256")), "MALFORMED_QUOTE_STREAM_SHA256")
    _require(copy_record.get("returned_none") is False, "COPY_RETURNED_NONE")
    _require(copy_record.get("monotonic") is True, "NONMONOTONIC_TICK_TIMESTAMPS")
    _require(copy_record.get("in_range") is True, "TICK_OUTSIDE_INTERVAL")
    _require(copy_record["valid_bid_ask"] == copy_record["count"], "VALID_BID_ASK_COUNT_MISMATCH")
    error = copy_record.get("last_error")
    _require(isinstance(error, list) and error == [1, "Success"], "COPY_API_ERROR")


def _validate_interval_row(row: Any, expected: dict[str, Any]) -> None:
    _require(isinstance(row, dict), "MALFORMED_INTERVAL_RECEIPT")
    for field in ("kind", "ordinal", "start", "end", "tick_volume"):
        _require(row.get(field) == expected[field], "INTERVAL_RECEIPT_ORDER_MISMATCH")
    expected_role = expected.get("role", "")
    _require(row.get("role", "") == expected_role, "INTERVAL_RECEIPT_ORDER_MISMATCH")
    _require(_strict_int(row.get("start"), positive=True), "MALFORMED_INTERVAL_START")
    _require(_strict_int(row.get("end"), positive=True), "MALFORMED_INTERVAL_END")
    _require(row["end"] > row["start"], "INVALID_INTERVAL_BOUNDARY")
    _require(_strict_int(row.get("tick_volume"), positive=True), "MALFORMED_TICK_VOLUME")
    _validate_copy(row.get("copy"))
    copy_record = row["copy"]
    _require(
        row["start"] * 1000 <= copy_record["first_time_msc"] < row["end"] * 1000
        and row["start"] * 1000 <= copy_record["last_time_msc"] < row["end"] * 1000,
        "TICK_TIME_OUTSIDE_INTERVAL",
    )
    _require(copy_record["first_time_msc"] <= copy_record["last_time_msc"], "NONMONOTONIC_TICK_TIMESTAMPS")


def _selection_intervals(selection: dict[str, Any]) -> list[dict[str, Any]]:
    intervals = selection.get("intervals")
    _require(isinstance(intervals, list) and len(intervals) == 22, "INTERVAL_RECEIPT_COUNT_MISMATCH")
    profile = intervals[0]
    _require(
        isinstance(profile, dict)
        and profile.get("kind") == "D1_PROFILE"
        and profile.get("ordinal") == 0,
        "INTERVAL_RECEIPT_ORDER_MISMATCH",
    )
    for index, interval in enumerate(intervals[1:]):
        expected_role = "CANDIDATE" if index == 20 else "WARMUP"
        _require(
            isinstance(interval, dict)
            and interval.get("kind") == "M5"
            and interval.get("ordinal") == index
            and interval.get("role") == expected_role,
            "INTERVAL_RECEIPT_ORDER_MISMATCH",
        )
    return intervals


def _validate_selection(symbol: str, selection: Any) -> list[dict[str, Any]]:
    _require(isinstance(selection, dict), "SELECTION_MISSING")
    intervals = _selection_intervals(selection)
    profile_start = intervals[0].get("start")
    profile_end = intervals[0].get("end")
    candidate_open = selection.get("candidate_open")
    _require(_strict_int(profile_start, positive=True), "MALFORMED_PROFILE_START")
    _require(_strict_int(profile_end, positive=True), "MALFORMED_PROFILE_END")
    _require(_strict_int(candidate_open, positive=True), "MALFORMED_CANDIDATE_OPEN")
    _require(profile_end > profile_start, "INVALID_PROFILE_INTERVAL")
    _require(profile_end <= candidate_open, "FUTURE_PROFILE_INTERVAL")
    _require((profile_start, profile_end, candidate_open) == EXPECTED_WINDOWS[symbol], "CURRENT_WINDOW_MISMATCH")
    first_m5 = candidate_open - 20 * 300
    for index, interval in enumerate(intervals[1:]):
        _require(
            interval.get("start") == first_m5 + index * 300
            and interval.get("end") == first_m5 + (index + 1) * 300,
            "INTERVAL_RECEIPT_ORDER_MISMATCH",
        )
    return intervals


def _validate_symbol_evidence(documents: dict[str, Any], symbol: str) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    _require(symbol in ACCEPTED_SYMBOLS, "SYMBOL_NOT_REVIEWED_QUALIFIED")
    result = documents.get("result")
    review = documents.get("review")
    _require(isinstance(result, dict) and isinstance(review, dict), "VERIFIED_DOCUMENTS_REQUIRED")
    _require(result.get("provider_server") == PROVIDER_SERVER, "PROVIDER_IDENTITY_MISMATCH")
    _require(result.get("qualified_symbols") == list(ACCEPTED_SYMBOLS), "QUALIFIED_SYMBOL_SET_MISMATCH")
    _require(result.get("blocked_symbols") == list(BLOCKED_SYMBOLS), "BLOCKED_SYMBOL_SET_MISMATCH")
    _validate_terminal_identity(documents["pass1"], "PASS1")
    _validate_terminal_identity(documents["pass2"], "PASS2")

    result_symbol = symbol_record(result, symbol)
    frozen_symbol = symbol_record(documents["frozen"], symbol)
    pass1_symbol = symbol_record(documents["pass1"], symbol)
    pass2_symbol = symbol_record(documents["pass2"], symbol)
    _require(result_symbol.get("qualified") is True and result_symbol.get("blockers") == [], "SYMBOL_NOT_REVIEWED_QUALIFIED")
    for record in (frozen_symbol, pass1_symbol, pass2_symbol):
        _require(
            record.get("broker") == symbol
            and record.get("mapping_basis") == "EXACT_NAME_EQUALITY"
            and record.get("mapping_candidates") == [symbol],
            "SYMBOL_MAPPING_MISMATCH",
        )

    frozen_intervals = _validate_selection(symbol, frozen_symbol.get("selection"))
    _require(pass1_symbol.get("selection") == frozen_symbol.get("selection"), "PASS1_SELECTION_MISMATCH")
    _require(pass2_symbol.get("selection") == frozen_symbol.get("selection"), "PASS2_SELECTION_MISMATCH")
    _require(pass1_symbol.get("rate_snapshots_stable") is True, "RATE_SNAPSHOT_CHANGED")
    _require(pass2_symbol.get("rate_snapshots_stable") is True, "RATE_SNAPSHOT_CHANGED")
    for record in (pass1_symbol, pass2_symbol):
        checks = record.get("rate_snapshot_checks")
        _require(isinstance(checks, list) and len(checks) == 24 and all(item is True for item in checks), "RATE_SNAPSHOT_CHANGED")
        prime = record.get("prime")
        _require(
            isinstance(prime, dict)
            and prime.get("returned_none") is False
            and _strict_int(prime.get("count"), positive=True)
            and prime.get("last_error") == [1, "Success"],
            "SYNCHRONIZATION_PRIME_FAILED",
        )

    pass1_rows = pass1_symbol.get("interval_results")
    pass2_rows = pass2_symbol.get("interval_results")
    _require(isinstance(pass1_rows, list) and len(pass1_rows) == 22, "INTERVAL_RECEIPT_COUNT_MISMATCH")
    _require(isinstance(pass2_rows, list) and len(pass2_rows) == 22, "INTERVAL_RECEIPT_COUNT_MISMATCH")
    normalized: list[dict[str, Any]] = []
    for index, expected in enumerate(frozen_intervals):
        _validate_interval_row(pass1_rows[index], expected)
        _validate_interval_row(pass2_rows[index], expected)
        first = pass1_rows[index]["copy"]
        second = pass2_rows[index]["copy"]
        identity_fields = ("count", "first_time_msc", "last_time_msc", "valid_bid_ask", "sha256")
        _require(all(first[field] == second[field] for field in identity_fields), "REPEAT_IDENTITY_MISMATCH")
        role = "PROFILE" if index == 0 else expected["role"]
        normalized.append(
            {
                "kind": expected["kind"],
                "ordinal": expected["ordinal"],
                "role": role,
                "interval_start_msc": expected["start"] * 1000,
                "interval_end_msc": expected["end"] * 1000,
                "pass1_count": first["count"],
                "pass2_count": second["count"],
                "pass1_first_time_msc": first["first_time_msc"],
                "pass2_first_time_msc": second["first_time_msc"],
                "pass1_last_time_msc": first["last_time_msc"],
                "pass2_last_time_msc": second["last_time_msc"],
                "pass1_valid_bid_ask_count": first["valid_bid_ask"],
                "pass2_valid_bid_ask_count": second["valid_bid_ask"],
                "pass1_quote_stream_sha256": first["sha256"],
                "pass2_quote_stream_sha256": second["sha256"],
                "pass1_api_success": True,
                "pass2_api_success": True,
                "repeat_identity": True,
                "rate_snapshot_stable": True,
            }
        )

    result_rows = result_symbol.get("intervals")
    _require(isinstance(result_rows, list) and len(result_rows) == 22, "RESULT_INTERVAL_COUNT_MISMATCH")
    for index, row in enumerate(result_rows):
        _require(
            isinstance(row, dict)
            and row.get("kind") == frozen_intervals[index]["kind"]
            and row.get("ordinal") == frozen_intervals[index]["ordinal"]
            and row.get("count_pass1") == normalized[index]["pass1_count"]
            and row.get("count_pass2") == normalized[index]["pass2_count"]
            and row.get("repeat_identity") is True
            and row.get("qualified_interval") is True,
            "RESULT_INTERVAL_MISMATCH",
        )

    review_symbols = review.get("per_symbol_check")
    _require(isinstance(review_symbols, dict), "REVIEW_SYMBOL_CHECK_MISSING")
    reviewed = review_symbols.get(symbol)
    profile_start, profile_end, candidate_open = EXPECTED_WINDOWS[symbol]
    _require(
        isinstance(reviewed, dict)
        and reviewed.get("broker_symbol") == symbol
        and reviewed.get("qualified") is True
        and reviewed.get("profile_interval_unix") == [profile_start, profile_end]
        and reviewed.get("candidate_open_unix") == candidate_open
        and reviewed.get("repeat_identity_passed") == "22/22"
        and reviewed.get("rate_snapshots_stable_both_passes") is True
        and reviewed.get("blockers") == [],
        "REVIEW_SYMBOL_BINDING_MISMATCH",
    )
    return frozen_symbol, normalized


def _bundle_hash(payload: dict[str, Any]) -> str:
    return hashlib.sha256(canonical_json_bytes(payload)).hexdigest()


def canonical_json_bytes(value: dict[str, Any]) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True) + "\n").encode("ascii")


def derive_bundle(documents: dict[str, Any], symbol: str) -> dict[str, Any]:
    """Validate one reviewed symbol and derive its deterministic typed bundle."""

    _validate_loaded_documents(documents)
    _require(isinstance(symbol, str), "SYMBOL_NOT_REVIEWED_QUALIFIED")
    symbol = symbol.upper()
    frozen_symbol, receipts = _validate_symbol_evidence(documents, symbol)
    profile_start, profile_end, candidate_open = EXPECTED_WINDOWS[symbol]
    payload: dict[str, Any] = {
        "schema": "orderflow_proxy_provider_bundle/v1",
        "policy_id": POLICY_ID,
        "classification": CLASSIFICATION,
        "provider_server": PROVIDER_SERVER,
        "terminal_build": TERMINAL_BUILD,
        "logical_symbol": symbol,
        "broker_symbol": frozen_symbol["broker"],
        "reviewed_repo_head": REVIEWED_REPO_HEAD,
        "evidence_manifest_sha256": EVIDENCE_MANIFEST_SHA256,
        "profile_interval_start": profile_start,
        "profile_interval_end": profile_end,
        "candidate_m5_open": candidate_open,
        "interval_receipts": receipts,
        "true_orderflow": False,
        "executed_volume_delta_qualified": False,
        "current_entry_signal_compatible": False,
        "order_execution_authorized": False,
        "time_exit_consumer_owned": True,
    }
    payload["bundle_sha256"] = _bundle_hash(payload)
    return payload


def derive_bundles(documents: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {symbol: derive_bundle(documents, symbol) for symbol in ACCEPTED_SYMBOLS}


def write_bundles(evidence_root: Path, output_dir: Path) -> dict[str, Any]:
    documents = load_verified_evidence(evidence_root)
    bundles = derive_bundles(documents)
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    hashes: dict[str, str] = {}
    file_hashes: dict[str, str] = {}
    for symbol, bundle in bundles.items():
        path = output_dir / f"{symbol}.json"
        path.write_bytes(canonical_json_bytes(bundle))
        hashes[symbol] = bundle["bundle_sha256"]
        file_hashes[symbol] = _sha256(path)
    return {
        "status": "BUNDLES_DERIVED",
        "classification": CLASSIFICATION,
        "accepted_symbols": list(ACCEPTED_SYMBOLS),
        "blocked_symbols": list(BLOCKED_SYMBOLS),
        "bundle_sha256": hashes,
        "file_sha256": file_hashes,
        "evidence_manifest_sha256": EVIDENCE_MANIFEST_SHA256,
        "reviewed_repo_head": REVIEWED_REPO_HEAD,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence-root", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        summary = write_bundles(args.evidence_root, args.output_dir)
    except ProviderEvidenceError as error:
        print(json.dumps({"status": "REFUSED", "error": str(error)}, sort_keys=True))
        return 2
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
