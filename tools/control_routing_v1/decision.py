from __future__ import annotations

import re
from typing import Any

DECISION_SCHEMA = "ea_lab_control_decision_input/1"
RESULT_SCHEMA = "ea_lab_control_decision_result/1"
TASK_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
INPUT_KEYS = {
    "schema_version",
    "task_id",
    "dependency_state",
    "writer_conflict",
    "process_state",
    "deterministic_gates",
    "failure_kind",
    "attempt_count",
    "route_lane",
    "repair_limit",
    "repair_used",
    "review_required",
    "review_state",
    "owner_hard_stop",
}
GATE_KEYS = {"gate_id", "state", "required"}
DEPENDENCY_STATES = {"READY", "WAITING", "BLOCKED"}
PROCESS_STATES = {"IDLE", "RUNNING", "COMPLETE", "FAILED", "UNKNOWN"}
GATE_STATES = {"PASS", "FAIL", "UNKNOWN"}
FAILURE_KINDS = {"NONE", "CODE", "ENVIRONMENT", "CONTRACT", "UNKNOWN"}
ROUTE_LANES = {
    "LOCAL_DETERMINISTIC",
    "LUNA_LOW",
    "LUNA_MEDIUM",
    "LUNA_HIGH",
    "SOL_HIGH",
    "OWNER_DECISION_REQUIRED",
}
REVIEW_STATES = {"NOT_REQUIRED", "NOT_RUN", "PASS", "FAIL", "UNKNOWN"}


class DecisionError(ValueError):
    pass


def _exact_keys(value: dict[str, Any], allowed: set[str], name: str) -> None:
    missing = sorted(allowed - set(value))
    unknown = sorted(set(value) - allowed)
    if missing or unknown:
        raise DecisionError(f"{name} keys mismatch missing={missing} unknown={unknown}")


def _nonnegative_int(value: Any, name: str) -> int:
    if not isinstance(value, int) or isinstance(value, bool) or value < 0:
        raise DecisionError(f"{name} must be an integer >= 0")
    return value


def validate_decision_input(value: Any) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise DecisionError("decision input must be an object")
    _exact_keys(value, INPUT_KEYS, "decision input")
    if value["schema_version"] != DECISION_SCHEMA:
        raise DecisionError("unsupported decision schema")
    if not isinstance(value["task_id"], str) or not TASK_ID_RE.fullmatch(value["task_id"]):
        raise DecisionError("invalid task_id")
    if value["dependency_state"] not in DEPENDENCY_STATES:
        raise DecisionError("invalid dependency_state")
    if value["process_state"] not in PROCESS_STATES:
        raise DecisionError("invalid process_state")
    if value["failure_kind"] not in FAILURE_KINDS:
        raise DecisionError("invalid failure_kind")
    if value["route_lane"] not in ROUTE_LANES:
        raise DecisionError("invalid route_lane")
    if value["review_state"] not in REVIEW_STATES:
        raise DecisionError("invalid review_state")
    for name in ("writer_conflict", "review_required", "owner_hard_stop"):
        if not isinstance(value[name], bool):
            raise DecisionError(f"{name} must be boolean")
    _nonnegative_int(value["attempt_count"], "attempt_count")
    repair_limit = _nonnegative_int(value["repair_limit"], "repair_limit")
    repair_used = _nonnegative_int(value["repair_used"], "repair_used")
    if repair_used > repair_limit:
        raise DecisionError("repair_used cannot exceed repair_limit")

    gates = value["deterministic_gates"]
    if not isinstance(gates, list):
        raise DecisionError("deterministic_gates must be a list")
    seen: set[str] = set()
    for gate in gates:
        if not isinstance(gate, dict):
            raise DecisionError("gate must be an object")
        _exact_keys(gate, GATE_KEYS, "gate")
        gate_id = gate["gate_id"]
        if not isinstance(gate_id, str) or not gate_id or gate_id in seen:
            raise DecisionError("gate_id must be unique and non-empty")
        seen.add(gate_id)
        if gate["state"] not in GATE_STATES:
            raise DecisionError("invalid gate state")
        if not isinstance(gate["required"], bool):
            raise DecisionError("gate required must be boolean")

    if not any(gate["required"] for gate in gates):
        raise DecisionError("deterministic_gates must contain at least one required gate")

    required_failed = any(
        gate["required"] and gate["state"] == "FAIL"
        for gate in gates
    )
    if value["process_state"] == "FAILED" and not required_failed:
        raise DecisionError("FAILED process requires a required gate failure")
    if value["route_lane"] == "OWNER_DECISION_REQUIRED" and not value["owner_hard_stop"]:
        raise DecisionError("owner route requires owner_hard_stop")
    if required_failed and value["failure_kind"] == "NONE":
        raise DecisionError("required gate failure requires a non-NONE failure_kind")
    if not required_failed and value["failure_kind"] != "NONE":
        raise DecisionError("failure_kind must be NONE when no required gate failed")
    if value["review_required"] and value["review_state"] == "NOT_REQUIRED":
        raise DecisionError("required review cannot use NOT_REQUIRED state")
    if not value["review_required"] and value["review_state"] != "NOT_REQUIRED":
        raise DecisionError("non-required review must use NOT_REQUIRED state")
    return value


def _result(task_id: str, decision: str, *reasons: str) -> dict[str, Any]:
    return {
        "schema_version": RESULT_SCHEMA,
        "task_id": task_id,
        "decision": decision,
        "reason_codes": list(reasons),
        "authority_ceiling": "SOURCE_ONLY_NO_RUNTIME",
        "canonical": False,
        "completion_scope": "SOURCE_SCOPE_CANDIDATE_NOT_CANONICAL",
    }


def decide(value: Any) -> dict[str, Any]:
    item = validate_decision_input(value)
    task_id = item["task_id"]

    if item["owner_hard_stop"]:
        return _result(task_id, "OWNER_DECISION_REQUIRED", "OWNER_HARD_STOP_UNAPPROVED")
    if item["writer_conflict"]:
        return _result(task_id, "WAIT", "ACTIVE_WRITER_CONFLICT")
    if item["dependency_state"] == "BLOCKED":
        return _result(task_id, "BLOCK", "DEPENDENCY_BLOCKED")
    if item["dependency_state"] == "WAITING":
        return _result(task_id, "WAIT", "DEPENDENCY_WAITING")
    if item["process_state"] == "RUNNING":
        return _result(task_id, "WAIT", "PROCESS_STILL_RUNNING")
    required = [gate for gate in item["deterministic_gates"] if gate["required"]]
    failed = [gate for gate in required if gate["state"] == "FAIL"]
    unknown = [gate for gate in required if gate["state"] == "UNKNOWN"]
    repair_remaining = item["repair_used"] < item["repair_limit"]

    if failed:
        if item["failure_kind"] in {"ENVIRONMENT", "CONTRACT", "UNKNOWN"}:
            return _result(task_id, "BLOCK", f"{item['failure_kind']}_FAILURE")
        if not repair_remaining:
            return _result(task_id, "BLOCK", "REPAIR_BUDGET_EXHAUSTED")

    if item["process_state"] == "UNKNOWN":
        return _result(task_id, "VERIFY_MORE", "PROCESS_STATE_UNKNOWN")
    if unknown:
        return _result(task_id, "VERIFY_MORE", "REQUIRED_GATE_UNKNOWN")

    if failed:
        if item["attempt_count"] >= 2 and item["route_lane"] != "SOL_HIGH":
            return _result(task_id, "ESCALATE", "REPEATED_CODE_FAILURE")
        return _result(task_id, "RETRY", "CODE_FAILURE_REPAIR_AVAILABLE")

    if item["review_required"]:
        if item["review_state"] in {"NOT_RUN", "UNKNOWN", "NOT_REQUIRED"}:
            return _result(task_id, "REVIEW", "REQUIRED_REVIEW_PENDING")
        if item["review_state"] == "FAIL":
            if repair_remaining:
                return _result(task_id, "RETRY", "REVIEW_FAIL_REPAIR_AVAILABLE")
            return _result(task_id, "BLOCK", "REVIEW_FAIL_REPAIR_EXHAUSTED")
        if item["review_state"] == "PASS":
            return _result(task_id, "COMPLETE", "ALL_REQUIRED_GATES_AND_REVIEW_PASS")

    return _result(task_id, "COMPLETE", "ALL_REQUIRED_DETERMINISTIC_GATES_PASS")
