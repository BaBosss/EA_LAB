from __future__ import annotations

import argparse
import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SCHEMA = "ea_lab_offline_replay_package/1"
COVERAGE_REFUSALS = {
    "PARTIAL": "REFUSE_PARTIAL_COVERAGE",
    "MISSING": "REFUSE_MISSING_COVERAGE",
    "UNKNOWN": "REFUSE_UNKNOWN_COVERAGE",
}
VISIBLE_STATES = {"SCHEDULED", "PUBLISHED", "FINAL", "REVISED"}
FORBIDDEN_ACTION_FIELDS = {"trade_action", "policy_action", "close_positions", "block_new", "lot_size"}


def parse_utc(value: str) -> datetime:
    if not isinstance(value, str) or not value.endswith("Z"):
        raise ValueError("timestamp must be an ISO-8601 UTC value ending in Z")
    parsed = datetime.fromisoformat(value[:-1] + "+00:00")
    if parsed.tzinfo is None:
        raise ValueError("timestamp must be timezone-aware")
    return parsed.astimezone(timezone.utc)


def stable_hash(value: Any) -> str:
    raw = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


def _find_forbidden_fields(value: Any) -> set[str]:
    found: set[str] = set()
    if isinstance(value, dict):
        found.update(FORBIDDEN_ACTION_FIELDS.intersection(value))
        for child in value.values():
            found.update(_find_forbidden_fields(child))
    elif isinstance(value, list):
        for child in value:
            found.update(_find_forbidden_fields(child))
    return found


def _base_result(package: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema_version": "ea_lab_offline_replay_qualification/1",
        "classification": "OFFLINE_DATA_SELECTOR_ONLY",
        "input_sha256": stable_hash(package),
        "historical_dataset_qualified": False,
        "ea_replay_qualified": False,
        "policy_changed": False,
        "trade_policy_output": None,
    }


def _refuse(package: dict[str, Any], *reasons: str, details: dict[str, Any] | None = None) -> dict[str, Any]:
    result = _base_result(package)
    result.update(
        {
            "status": "REFUSED",
            "reason_codes": sorted(set(reasons)),
            "details": details or {},
            "selected_records": [],
        }
    )
    return result


def _validate_clock(clock: Any) -> list[str]:
    if not isinstance(clock, dict):
        return ["REFUSE_CLOCK_MAPPING_UNVERSIONED"]
    required = ("version", "source_timezone", "broker_timezone", "mapping_basis")
    if any(not isinstance(clock.get(name), str) or not clock[name].strip() for name in required):
        return ["REFUSE_CLOCK_MAPPING_UNVERSIONED"]
    if clock["version"].strip().upper() == "UNKNOWN":
        return ["REFUSE_CLOCK_MAPPING_UNVERSIONED"]
    return []


def qualify_replay_package(package: dict[str, Any]) -> dict[str, Any]:
    """Qualify and select records known at a synthetic/offline decision time.

    This function never maps data to a trading action. A qualified result only
    means the package satisfies this data/time contract.
    """

    if not isinstance(package, dict):
        return _refuse({}, "INVALID_INPUT_NOT_OBJECT")
    if package.get("schema_version") != SCHEMA:
        return _refuse(package, "INVALID_SCHEMA_VERSION")
    forbidden = sorted(_find_forbidden_fields(package))
    if forbidden:
        return _refuse(package, "REFUSE_TRADING_POLICY_FIELD", details={"fields": sorted(set(forbidden))})

    coverage = package.get("coverage")
    if not isinstance(coverage, dict):
        return _refuse(package, "REFUSE_UNKNOWN_COVERAGE")
    coverage_state = coverage.get("state")
    if coverage_state in COVERAGE_REFUSALS:
        return _refuse(package, COVERAGE_REFUSALS[coverage_state])
    if coverage_state not in {"COMPLETE", "COMPLETE_NO_EVENTS"}:
        return _refuse(package, "REFUSE_UNKNOWN_COVERAGE")

    clock_reasons = _validate_clock(package.get("clock_mapping"))
    if clock_reasons:
        return _refuse(package, *clock_reasons)

    if not isinstance(package.get("dataset_id"), str) or not package["dataset_id"].strip():
        return _refuse(package, "INVALID_DATASET_ID")
    if not isinstance(package.get("dataset_version"), str) or not package["dataset_version"].strip():
        return _refuse(package, "INVALID_DATASET_VERSION")
    source_hash = package.get("source_snapshot_sha256")
    if not isinstance(source_hash, str) or re.fullmatch(r"[0-9a-f]{64}", source_hash) is None:
        return _refuse(package, "INVALID_SOURCE_SNAPSHOT_SHA256")

    try:
        decision = parse_utc(package["decision_at_utc"])
        coverage_start = parse_utc(coverage["start_utc"])
        coverage_end = parse_utc(coverage["end_utc"])
    except (KeyError, TypeError, ValueError) as exc:
        return _refuse(package, "INVALID_TIME_CONTRACT", details={"error": str(exc)})
    if coverage_start > coverage_end or not (coverage_start <= decision <= coverage_end):
        return _refuse(package, "DECISION_OUTSIDE_COVERAGE")

    records = package.get("records")
    if not isinstance(records, list):
        return _refuse(package, "INVALID_RECORDS")
    if coverage_state == "COMPLETE_NO_EVENTS":
        if records:
            return _refuse(package, "COMPLETE_NO_EVENTS_HAS_RECORDS")
        result = _base_result(package)
        result.update(
            {
                "status": "QUALIFIED_EMPTY_NO_EVENTS",
                "reason_codes": [],
                "coverage_state": coverage_state,
                "clock_mapping_version": package["clock_mapping"]["version"],
                "selected_records": [],
                "selected_record_count": 0,
                "future_record_count": 0,
                "cancelled_record_count": 0,
                "tentative_record_count": 0,
                "exact_duplicate_count": 0,
            }
        )
        return result
    if not records:
        return _refuse(package, "COMPLETE_REQUIRES_RECORDS_OR_COMPLETE_NO_EVENTS")

    unique: dict[tuple[str, str], dict[str, Any]] = {}
    duplicate_count = 0
    for record in records:
        if not isinstance(record, dict):
            return _refuse(package, "INVALID_RECORD_NOT_OBJECT")
        try:
            record_id = record["record_id"]
            revision_id = record["revision_id"]
            if not isinstance(record_id, str) or not record_id.strip():
                raise ValueError("blank record identity")
            if not isinstance(revision_id, str) or not revision_id.strip():
                raise ValueError("blank revision identity")
            identity = (record_id, revision_id)
            parse_utc(record["available_at_utc"])
        except (KeyError, TypeError, ValueError) as exc:
            return _refuse(package, "INVALID_RECORD_IDENTITY_OR_TIME", details={"error": str(exc)})
        if identity in unique:
            if stable_hash(unique[identity]) != stable_hash(record):
                return _refuse(package, "REFUSE_CONFLICTING_DUPLICATE", details={"identity": list(identity)})
            duplicate_count += 1
            continue
        unique[identity] = record

    for record in unique.values():
        if record.get("record_type") != "DAILY_CLOSE":
            continue
        try:
            effective = parse_utc(record["effective_at_utc"])
            available = parse_utc(record["available_at_utc"])
        except (KeyError, TypeError, ValueError) as exc:
            return _refuse(package, "INVALID_DAILY_CLOSE_TIME", details={"error": str(exc)})
        if effective.date() == available.date() and effective < available and effective <= decision < available:
            return _refuse(
                package,
                "REFUSE_SAME_DAY_CLOSE_AT_MIDNIGHT",
                details={"record_id": record["record_id"]},
            )

    by_record: dict[str, list[dict[str, Any]]] = {}
    future_count = 0
    for record in unique.values():
        if parse_utc(record["available_at_utc"]) > decision:
            future_count += 1
            continue
        by_record.setdefault(str(record["record_id"]), []).append(record)

    selected: list[dict[str, Any]] = []
    cancelled_count = 0
    tentative_count = 0
    for record_id, history in sorted(by_record.items()):
        history.sort(key=lambda row: (parse_utc(row["available_at_utc"]), str(row["revision_id"])))
        latest_time = parse_utc(history[-1]["available_at_utc"])
        tied = [row for row in history if parse_utc(row["available_at_utc"]) == latest_time]
        if len(tied) > 1:
            return _refuse(package, "REFUSE_AMBIGUOUS_SAME_AVAILABLE_AT", details={"record_id": record_id})
        latest = history[-1]
        state = latest.get("state")
        if state == "CANCELLED":
            cancelled_count += 1
        elif state == "TENTATIVE":
            tentative_count += 1
        elif state in VISIBLE_STATES:
            selected.append(latest)
        else:
            return _refuse(package, "REFUSE_UNKNOWN_RECORD_STATE", details={"record_id": record_id, "state": state})

    result = _base_result(package)
    result.update(
        {
            "status": "QUALIFIED_AS_OF_DECISION",
            "reason_codes": [],
            "coverage_state": coverage_state,
            "clock_mapping_version": package["clock_mapping"]["version"],
            "selected_records": selected,
            "selected_record_count": len(selected),
            "future_record_count": future_count,
            "cancelled_record_count": cancelled_count,
            "tentative_record_count": tentative_count,
            "exact_duplicate_count": duplicate_count,
        }
    )
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Offline available-at/coverage/revision replay data validator")
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        package = json.loads(args.input.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(json.dumps({"status": "ERROR_INVALID_INPUT", "error": str(exc)}, indent=2))
        return 2
    result = qualify_replay_package(package)
    rendered = json.dumps(result, indent=2, ensure_ascii=False) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    else:
        print(rendered, end="")
    return 0 if result["status"].startswith("QUALIFIED") else 1


if __name__ == "__main__":
    raise SystemExit(main())
