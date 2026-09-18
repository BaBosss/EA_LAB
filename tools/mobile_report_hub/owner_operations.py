"""Validate and project caller-supplied durable job observations for the Monitor."""
from __future__ import annotations

import hashlib
import json
import math
import re
from datetime import datetime, timezone
from pathlib import Path


INPUT_SCHEMA = "EA_LAB_JOB_OBSERVATIONS_V1"
OUTPUT_SCHEMA = "EA_LAB_OWNER_OPERATIONS_V1"
SOURCE_KIND = "LOCAL_DURABLE_JOB_STATUS"
AUTHORITY = "READ_ONLY_PRESENTATION_NO_PROCESS_CONTROL"
TIMESTAMP_BASIS = "CALLER_SUPPLIED_SNAPSHOT_AT_CHECKED_UTC"

_UTC_SECOND_RE = re.compile(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z")
_IDENTIFIER_RE = re.compile(r"[A-Za-z][A-Za-z0-9._-]{0,127}")
_SENSITIVE_IDENTIFIER_RE = re.compile(
    r"(?i)(?:^|[._-])(?:account|acct|login|password|credential|secret|token|api[_-]?key)(?:$|[._-])"
    r"|(?<![0-9])[0-9]{9,}(?![0-9])"
)
_SHA_RE = re.compile(r"[0-9a-f]{40}")
_MAX_SAFE_INTEGER = 9_007_199_254_740_991

_JOB_STATES = {
    "STARTING", "RUNNING", "POSTCONDITION_RUNNING", "CANCEL_REQUESTED",
    "COMPLETE", "FAILED", "POSTCONDITION_FAILED", "TIMED_OUT", "CANCELLED",
    "LOST_PROCESS", "UNKNOWN",
}
_ACTIVE_STATES = {"STARTING", "RUNNING", "POSTCONDITION_RUNNING", "CANCEL_REQUESTED"}
_TERMINAL_STATES = _JOB_STATES - _ACTIVE_STATES - {"UNKNOWN"}
_RETRY_DECISIONS = {"ALLOW_RETRY", "REFUSE_RETRY", "WAIT_EXTERNAL", "NOT_APPLICABLE", "UNKNOWN"}
_POSTCONDITIONS = {"PASSED", "FAILED", "NOT_CONFIGURED", "RUNNING", "UNKNOWN"}
_ENVELOPE_KEYS = {
    "schema_version", "source_kind", "observed_at_utc", "canonical_observed_sha", "observations"
}
_ROW_KEYS = {
    "lane_id", "job_id", "checked_utc", "observed_state", "durable_state",
    "runner_alive", "child_alive", "postcondition_alive", "heartbeat_age_sec",
    "retry_decision", "result",
}
_RESULT_KEYS = {"state", "exit", "postcondition", "ended"}


def _utc(value: object) -> datetime | None:
    if not isinstance(value, str) or not _UTC_SECOND_RE.fullmatch(value):
        return None
    try:
        parsed = datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    except ValueError:
        return None
    return parsed


def _freshness(stamp: str, as_of: str) -> str:
    instant = _utc(stamp)
    reference = _utc(as_of)
    if instant is None or reference is None:
        return "UNKNOWN"
    age = (reference - instant).total_seconds()
    return "FUTURE" if age < -300 else "STALE" if age > 24 * 3600 else "CURRENT"


def _safe_identifier(value: object) -> str | None:
    if not isinstance(value, str) or not _IDENTIFIER_RE.fullmatch(value):
        return None
    if _SENSITIVE_IDENTIFIER_RE.search(value):
        return None
    return value


def _unknown_projection(reason: str, source_sha256: str = "UNKNOWN") -> dict:
    return {
        "schema_version": OUTPUT_SCHEMA,
        "status": "UNAVAILABLE",
        "freshness": "UNKNOWN",
        "source_kind": SOURCE_KIND,
        "timestamp_basis": TIMESTAMP_BASIS,
        "authority": AUTHORITY,
        "binding_state": "UNKNOWN",
        "observed_at_utc": "UNKNOWN",
        "canonical_observed_sha": "UNKNOWN",
        "source_sha256": source_sha256,
        "observations": [],
        "reason": reason,
    }


def _strict_bool_or_unknown(value: object) -> bool | str:
    if value is None:
        return "UNKNOWN"
    if type(value) is not bool:
        raise ValueError("invalid process observation")
    return value


def _heartbeat(value: object) -> int | float | str:
    if value is None:
        return "UNKNOWN"
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError("invalid heartbeat age")
    try:
        numeric = float(value)
    except OverflowError as error:
        raise ValueError("invalid heartbeat age") from error
    if not math.isfinite(numeric) or numeric < 0 or numeric > _MAX_SAFE_INTEGER:
        raise ValueError("invalid heartbeat age")
    return value


def _result(raw: object, durable_state: str, checked: datetime) -> dict:
    if not isinstance(raw, dict) or set(raw) != _RESULT_KEYS:
        raise ValueError("invalid result shape")
    state = raw.get("state")
    if state not in _JOB_STATES:
        raise ValueError("invalid result state")
    exit_value = raw.get("exit")
    if exit_value is not None and type(exit_value) is not int:
        raise ValueError("invalid exit code")
    if exit_value is not None and not (-_MAX_SAFE_INTEGER <= exit_value <= _MAX_SAFE_INTEGER):
        raise ValueError("invalid exit code")
    postcondition = raw.get("postcondition")
    if postcondition not in _POSTCONDITIONS:
        raise ValueError("invalid postcondition state")
    ended_value = raw.get("ended")
    ended = _utc(ended_value) if ended_value is not None else None
    if ended_value is not None and ended is None:
        raise ValueError("invalid result end time")
    if ended is not None and ended > checked.replace(tzinfo=timezone.utc):
        raise ValueError("result ends after observation")

    if durable_state in _ACTIVE_STATES or durable_state == "UNKNOWN":
        if state != "UNKNOWN" or exit_value is not None or postcondition not in {"UNKNOWN", "RUNNING"} or ended_value is not None:
            raise ValueError("active state has terminal result")
    else:
        if state != durable_state or ended is None:
            raise ValueError("terminal state/result mismatch")
        if state == "COMPLETE" and (exit_value != 0 or postcondition not in {"PASSED", "NOT_CONFIGURED"}):
            raise ValueError("invalid complete result")
        if state == "FAILED" and exit_value == 0:
            raise ValueError("failed result has zero exit")
        if state == "POSTCONDITION_FAILED" and postcondition != "FAILED":
            raise ValueError("postcondition failure mismatch")

    return {
        "state": state,
        "exit": exit_value if exit_value is not None else "UNKNOWN",
        "postcondition": postcondition,
        "ended": ended_value if ended_value is not None else "UNKNOWN",
    }


def _row(raw: object, envelope_time: datetime, as_of: str) -> dict:
    if not isinstance(raw, dict) or not (_ROW_KEYS <= set(raw) <= (_ROW_KEYS | {"local_head"})):
        raise ValueError("invalid observation row shape")
    lane_id = _safe_identifier(raw.get("lane_id"))
    job_id = _safe_identifier(raw.get("job_id"))
    if lane_id is None or job_id is None:
        raise ValueError("unsafe observation identifier")
    checked_value = raw.get("checked_utc")
    checked = _utc(checked_value)
    if checked is None or checked > envelope_time:
        raise ValueError("invalid checked time")
    observed_state = raw.get("observed_state")
    durable_state = raw.get("durable_state")
    if observed_state not in _JOB_STATES or durable_state not in _JOB_STATES:
        raise ValueError("invalid job state")
    if durable_state in _ACTIVE_STATES:
        if observed_state not in {durable_state, "LOST_PROCESS", "UNKNOWN"}:
            raise ValueError("observed/durable state mismatch")
    elif durable_state in _TERMINAL_STATES and observed_state != durable_state:
        raise ValueError("observed/durable state mismatch")
    retry_decision = raw.get("retry_decision")
    if retry_decision not in _RETRY_DECISIONS:
        raise ValueError("invalid retry decision")
    local_head = raw.get("local_head")
    if local_head is not None and (not isinstance(local_head, str) or not _SHA_RE.fullmatch(local_head)):
        raise ValueError("invalid local head")

    return {
        "lane_id": lane_id,
        "job_id": job_id,
        "checked_utc": checked_value,
        "freshness": _freshness(checked_value, as_of),
        "observed_state": observed_state,
        "durable_state": durable_state,
        "runner_alive": _strict_bool_or_unknown(raw.get("runner_alive")),
        "child_alive": _strict_bool_or_unknown(raw.get("child_alive")),
        "postcondition_alive": _strict_bool_or_unknown(raw.get("postcondition_alive")),
        "heartbeat_age_sec": _heartbeat(raw.get("heartbeat_age_sec")),
        "retry_decision": retry_decision,
        "result": _result(raw.get("result"), durable_state, checked),
        "local_head": local_head or "UNKNOWN",
        "deliverable_status": "UNKNOWN",
        "review_status": "UNKNOWN",
        "canonical_status": "UNKNOWN",
    }


def project(path: Path | None, canonical_sha: str, as_of: str) -> dict:
    """Return a safe, deterministic projection; malformed optional input is unavailable."""
    if path is None:
        return _unknown_projection("NOT_PROVIDED")
    try:
        source_bytes = path.read_bytes()
    except OSError:
        return _unknown_projection("UNREADABLE_INPUT")
    source_hash = hashlib.sha256(source_bytes).hexdigest()
    try:
        raw = json.loads(source_bytes.decode("utf-8-sig"))
        if not isinstance(raw, dict) or set(raw) != _ENVELOPE_KEYS:
            raise ValueError("invalid envelope shape")
        if raw.get("schema_version") != INPUT_SCHEMA or raw.get("source_kind") != SOURCE_KIND:
            raise ValueError("invalid envelope identity")
        observed_value = raw.get("observed_at_utc")
        observed = _utc(observed_value)
        if observed is None:
            raise ValueError("invalid envelope time")
        observed_sha = raw.get("canonical_observed_sha")
        if not isinstance(observed_sha, str) or not _SHA_RE.fullmatch(observed_sha):
            raise ValueError("invalid canonical pin")
        if not isinstance(raw.get("observations"), list):
            raise ValueError("invalid observations collection")
        rows = [_row(item, observed, as_of) for item in raw["observations"]]
        lane_ids = [row["lane_id"] for row in rows]
        job_ids = [row["job_id"] for row in rows]
        pairs = [(row["lane_id"], row["job_id"]) for row in rows]
        if len(set(lane_ids)) != len(lane_ids) or len(set(job_ids)) != len(job_ids) or len(set(pairs)) != len(pairs):
            raise ValueError("duplicate or conflicting observation identity")
    except (UnicodeError, json.JSONDecodeError, ValueError, TypeError):
        return _unknown_projection("INVALID_INPUT", source_hash)

    envelope_freshness = _freshness(observed_value, as_of)
    binding = "MATCHES_CANONICAL_SHA" if observed_sha == canonical_sha else "DIFFERENT_CANONICAL_SHA"
    rows_current = all(row["freshness"] == "CURRENT" for row in rows)
    available = binding == "MATCHES_CANONICAL_SHA" and envelope_freshness == "CURRENT" and rows_current
    reason = (
        "AVAILABLE_SNAPSHOT" if available else
        "CANONICAL_BINDING_MISMATCH" if binding != "MATCHES_CANONICAL_SHA" else
        "FUTURE_OBSERVATION" if envelope_freshness == "FUTURE" or any(row["freshness"] == "FUTURE" for row in rows) else
        "STALE_OBSERVATION" if envelope_freshness == "STALE" or any(row["freshness"] == "STALE" for row in rows) else
        "UNQUALIFIED_OBSERVATION"
    )
    return {
        "schema_version": OUTPUT_SCHEMA,
        "status": "AVAILABLE" if available else "UNAVAILABLE",
        "freshness": envelope_freshness,
        "source_kind": SOURCE_KIND,
        "timestamp_basis": TIMESTAMP_BASIS,
        "authority": AUTHORITY,
        "binding_state": binding,
        "observed_at_utc": observed_value,
        "canonical_observed_sha": observed_sha,
        "source_sha256": source_hash,
        "observations": sorted(rows, key=lambda item: (item["lane_id"], item["job_id"])),
        "reason": reason,
    }
