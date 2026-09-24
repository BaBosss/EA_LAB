from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path
from typing import Any

TASK_SCHEMA = "ea_lab_control_routing_task/1"
RESULT_SCHEMA = "ea_lab_control_routing_result/1"
TASK_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
TASK_KEYS = {
    "schema_version",
    "task_id",
    "work_type",
    "risk_flags",
    "owner_hard_stop_flags",
    "prior_failed_attempts",
    "software_can_prove",
}


class RoutingError(ValueError):
    pass


def _reject_unknown_keys(value: dict[str, Any], allowed: set[str], name: str) -> None:
    unknown = sorted(set(value) - allowed)
    missing = sorted(allowed - set(value))
    if unknown or missing:
        raise RoutingError(f"{name} keys mismatch missing={missing} unknown={unknown}")


def _string_list(value: Any, name: str) -> list[str]:
    if not isinstance(value, list) or any(not isinstance(x, str) or not x for x in value):
        raise RoutingError(f"{name} must be a list of non-empty strings")
    if len(value) != len(set(value)):
        raise RoutingError(f"{name} contains duplicates")
    return value


def load_policy(package_root: Path | None = None) -> tuple[dict[str, Any], str]:
    root = package_root or Path(__file__).resolve().parent
    path = root / "policy.json"
    raw = path.read_bytes()
    try:
        policy = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise RoutingError(f"invalid policy JSON: {exc}") from exc

    required = {
        "schema_version",
        "authority_ceiling",
        "activation",
        "completion_scope",
        "escalate_after_failed_attempts",
        "default_routes",
        "sol_escalation_flags",
        "owner_hard_stop_flags",
    }
    _reject_unknown_keys(policy, required, "policy")
    if policy["schema_version"] != "ea_lab_control_routing_policy/1":
        raise RoutingError("unsupported policy schema")
    if policy["activation"] is not False:
        raise RoutingError("V1 policy activation must remain false")
    threshold = policy["escalate_after_failed_attempts"]
    if not isinstance(threshold, int) or isinstance(threshold, bool) or threshold < 1:
        raise RoutingError("escalate_after_failed_attempts must be an integer >= 1")

    routes = policy["default_routes"]
    expected_types = {"DETERMINISTIC", "MECHANICAL", "BOUNDED", "COMPLEX", "HARD"}
    if not isinstance(routes, dict) or set(routes) != expected_types:
        raise RoutingError("default_routes must contain the closed V1 work types")
    for name, route in routes.items():
        if not isinstance(route, dict) or set(route) != {"lane", "model", "reasoning_effort"}:
            raise RoutingError(f"invalid route object: {name}")
    _string_list(policy["sol_escalation_flags"], "sol_escalation_flags")
    _string_list(policy["owner_hard_stop_flags"], "owner_hard_stop_flags")
    return policy, hashlib.sha256(raw).hexdigest()


def validate_task(value: Any, policy: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise RoutingError("task must be an object")
    _reject_unknown_keys(value, TASK_KEYS, "task")
    if value["schema_version"] != TASK_SCHEMA:
        raise RoutingError("unsupported task schema")
    if not isinstance(value["task_id"], str) or not TASK_ID_RE.fullmatch(value["task_id"]):
        raise RoutingError("invalid task_id")
    if value["work_type"] not in policy["default_routes"]:
        raise RoutingError("invalid work_type")
    risk_flags = _string_list(value["risk_flags"], "risk_flags")
    hard_flags = _string_list(value["owner_hard_stop_flags"], "owner_hard_stop_flags")
    if set(risk_flags) - set(policy["sol_escalation_flags"]):
        raise RoutingError("risk_flags contains unsupported values")
    if set(hard_flags) - set(policy["owner_hard_stop_flags"]):
        raise RoutingError("owner_hard_stop_flags contains unsupported values")
    attempts = value["prior_failed_attempts"]
    if not isinstance(attempts, int) or isinstance(attempts, bool) or attempts < 0:
        raise RoutingError("prior_failed_attempts must be an integer >= 0")
    if not isinstance(value["software_can_prove"], bool):
        raise RoutingError("software_can_prove must be boolean")
    return value


def route_task(value: Any) -> dict[str, Any]:
    policy, policy_sha256 = load_policy()
    task = validate_task(value, policy)
    reasons: list[str] = []

    if task["owner_hard_stop_flags"]:
        lane = "OWNER_DECISION_REQUIRED"
        route = {"model": None, "reasoning_effort": None}
        reasons.append("OWNER_HARD_STOP")
    elif task["software_can_prove"] or task["work_type"] == "DETERMINISTIC":
        lane = "LOCAL_DETERMINISTIC"
        route = {"model": None, "reasoning_effort": None}
        reasons.append("SOFTWARE_CAN_PROVE")
    elif set(task["risk_flags"]) & set(policy["sol_escalation_flags"]):
        lane = "SOL_HIGH"
        route = {"model": "gpt-6-sol", "reasoning_effort": "high"}
        reasons.append("EXPLICIT_SOL_ESCALATION_FLAG")
    elif task["prior_failed_attempts"] >= policy["escalate_after_failed_attempts"]:
        lane = "SOL_HIGH"
        route = {"model": "gpt-6-sol", "reasoning_effort": "high"}
        reasons.append("REPEATED_FAILED_ATTEMPTS")
    else:
        selected = policy["default_routes"][task["work_type"]]
        lane = selected["lane"]
        route = {"model": selected["model"], "reasoning_effort": selected["reasoning_effort"]}
        reasons.append(f"DEFAULT_{task['work_type']}_ROUTE")

    return {
        "schema_version": RESULT_SCHEMA,
        "task_id": task["task_id"],
        "route_lane": lane,
        "model": route["model"],
        "reasoning_effort": route["reasoning_effort"],
        "reason_codes": reasons,
        "authority_ceiling": policy["authority_ceiling"],
        "activation": False,
        "canonical": False,
        "completion_scope": policy["completion_scope"],
        "policy_sha256": policy_sha256,
    }
