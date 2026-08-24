"""Deterministic EA_LAB Harness v1 contracts and fail-closed validators."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
import sys
from pathlib import Path


SCHEMA_VERSION = "ea-lab-harness/v1"
MODES = ("QUICK", "BOUNDED", "TEAM", "STRICT", "RUNTIME")
_GIT_SHA = re.compile(r"^[0-9a-f]{40}$")
_HASH = re.compile(r"^[0-9a-f]{64}$")


class HarnessValidationError(ValueError):
    """A contract, evidence, or assurance packet failed closed validation."""


def canonical_json(value):
    """Return the stable UTF-8 representation used for every hash binding."""
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def sha256_value(value):
    return hashlib.sha256(canonical_json(value)).hexdigest()


def _require_text(value, name):
    if not isinstance(value, str) or not value.strip():
        raise HarnessValidationError(f"{name} must be a non-empty string")
    return value


def _require_sha(value, name, pattern=_GIT_SHA):
    if not isinstance(value, str) or pattern.fullmatch(value) is None:
        raise HarnessValidationError(f"{name} has an invalid hash")
    return value


def _sealed_body(record, field):
    if not isinstance(record, dict) or field not in record:
        raise HarnessValidationError(f"missing {field}")
    body = copy.deepcopy(record)
    observed = body.pop(field)
    _require_sha(observed, field, _HASH)
    if sha256_value(body) != observed:
        raise HarnessValidationError(f"{field} mismatch")
    return body


def seal_tdd_evidence(evidence):
    """Add the content hash used by :func:`validate_tdd_evidence`."""
    body = copy.deepcopy(evidence)
    body.pop("evidence_sha256", None)
    body["evidence_sha256"] = sha256_value(body)
    return body


def seal_runtime_identity(identity):
    """Add the content hash used by :func:`validate_runtime_identity`."""
    body = copy.deepcopy(identity)
    body.pop("identity_sha256", None)
    body["identity_sha256"] = sha256_value(body)
    return body


def artifact_record(path, content):
    """Create an artifact hash record from text or bytes."""
    _require_text(path, "artifact path")
    raw = content.encode("utf-8") if isinstance(content, str) else bytes(content)
    return {"path": path, "sha256": hashlib.sha256(raw).hexdigest()}


def _path_key(path):
    value = _require_text(path, "path").replace("\\", "/").strip()
    while value.startswith("./"):
        value = value[2:]
    return value.rstrip("/").lower() or "."


def _paths_overlap(left, right):
    a = _path_key(left)
    b = _path_key(right)
    return a == b or a.startswith(b + "/") or b.startswith(a + "/")


def _team_eligible(contract):
    lanes = contract.get("ready_lanes", [])
    if not isinstance(lanes, list):
        return False, "team_lanes_malformed"
    ready = [
        lane
        for lane in lanes
        if isinstance(lane, dict) and lane.get("ready") is True and lane.get("independent") is True
    ]
    if len(ready) < 2:
        return False, "team_requires_two_independent_ready_lanes"
    seen = set()
    for lane in ready:
        lane_id = lane.get("lane_id")
        if not isinstance(lane_id, str) or not lane_id or lane_id in seen:
            return False, "team_lane_identity_invalid"
        seen.add(lane_id)
        paths = lane.get("allowed_paths", [])
        if not isinstance(paths, list) or not paths:
            return False, "team_lane_scope_missing"
    for index, left in enumerate(ready):
        for right in ready[index + 1 :]:
            if any(_paths_overlap(a, b) for a in left["allowed_paths"] for b in right["allowed_paths"]):
                return False, "team_lane_scope_overlap"
    return True, "team_has_independent_non_overlapping_ready_lanes"


def route_execution(contract):
    """Choose exactly one execution mode, without granting authority."""
    if not isinstance(contract, dict):
        raise HarnessValidationError("contract must be an object")
    _require_text(contract.get("contract_id"), "contract_id")
    requested = contract.get("requested_mode", "QUICK")
    if requested not in MODES:
        raise HarnessValidationError("requested_mode must be one of QUICK, BOUNDED, TEAM, STRICT, RUNTIME")

    strict_required = any(
        contract.get(field) is True
        for field in ("consequential", "high_risk", "governance_review_required", "review_required")
    )
    runtime_operation = contract.get("runtime_operation") is True or contract.get("task_kind") in {
        "runtime",
        "deployment",
        "deployment-operation",
        "deployment_operation",
    }
    team_ok, team_reason = _team_eligible(contract)

    if strict_required:
        mode, reason = "STRICT", "strict_required_for_consequential_or_review_requirement"
    elif runtime_operation:
        mode, reason = "RUNTIME", "runtime_or_deployment_operation"
    elif requested == "TEAM":
        if team_ok:
            mode, reason = "TEAM", team_reason
        else:
            mode, reason = "BOUNDED", team_reason
    elif requested == "RUNTIME":
        mode, reason = "BOUNDED", "runtime_mode_requires_runtime_or_deployment_task"
    else:
        mode, reason = requested, "requested_mode"

    requested_stops = contract.get("owner_hard_stop_requested", [])
    if requested_stops is True:
        requested_stops = ["owner-hard-stop"]
    if not isinstance(requested_stops, list):
        raise HarnessValidationError("owner_hard_stop_requested must be a list")
    approved = contract.get("owner_approved_actions", [])
    if not isinstance(approved, list):
        raise HarnessValidationError("owner_approved_actions must be a list")
    blocked = sorted({str(item) for item in requested_stops} - {str(item) for item in approved})
    return {
        "mode": mode,
        "reason": reason,
        "allowed": not blocked,
        "hard_stop_blocked_actions": blocked,
        "authority_granted": False,
    }


def validate_tdd_evidence(contract, evidence):
    """Require hash-bound RED then GREEN evidence for applicable code changes."""
    body = _sealed_body(evidence, "evidence_sha256")
    applicable = contract.get("tdd_applicable", contract.get("change_kind") == "code")
    if body.get("schema_version") != "1.0" or body.get("applicable") is not applicable:
        raise HarnessValidationError("malformed TDD evidence applicability")
    if not applicable:
        _require_text(body.get("reason"), "TDD not-applicable reason")
        return {"valid": True, "applicable": False, "authority_granted": False}
    red = body.get("red")
    green = body.get("green")
    if not isinstance(red, dict) or not isinstance(green, dict):
        raise HarnessValidationError("TDD RED and GREEN evidence are required")
    if red.get("observed") is not True or not isinstance(red.get("exit_code"), int) or red["exit_code"] == 0:
        raise HarnessValidationError("TDD RED must be an observed non-success exit")
    if green.get("success") is not True or green.get("exit_code") != 0:
        raise HarnessValidationError("TDD GREEN must be successful")
    for phase in (red, green):
        _require_text(phase.get("command"), "TDD command")
        _require_text(phase.get("observation"), "TDD observation")
        if not isinstance(phase.get("sequence"), int):
            raise HarnessValidationError("TDD phase sequence is required")
    if red["sequence"] >= green["sequence"]:
        raise HarnessValidationError("TDD RED must precede GREEN")
    return {"valid": True, "applicable": True, "authority_granted": False}


def validate_runtime_identity(contract, records):
    """Validate observed worker identity; identity evidence never grants authority."""
    required = contract.get("identity_required") is True
    if not required:
        return {"valid": True, "required": False, "authority_granted": False}
    expected = contract.get("expected_runtime_identity")
    if not isinstance(expected, dict):
        raise HarnessValidationError("expected runtime identity is required")
    for field in ("role", "model", "effort"):
        _require_text(expected.get(field), f"expected runtime {field}")
    if not isinstance(records, list) or not records:
        raise HarnessValidationError("runtime identity record missing")
    candidates = []
    for record in records:
        body = _sealed_body(record, "identity_sha256")
        if body.get("role") == expected["role"]:
            candidates.append(body)
    if not candidates:
        raise HarnessValidationError("runtime identity role missing")
    observed = candidates[0]
    if observed.get("verified") is not True:
        raise HarnessValidationError("runtime identity is unverified")
    for field in ("model", "effort"):
        if observed.get(field) != expected[field]:
            raise HarnessValidationError(f"runtime identity {field} mismatch")
    return {"valid": True, "required": True, "authority_granted": False, "role": expected["role"]}


def _frozen_binding(candidate_sha, review):
    return sha256_value(
        {
            "candidate_sha": candidate_sha,
            "reviewer_id": review.get("reviewer_id"),
            "reviewer_family": review.get("reviewer_family"),
            "reviewer_model": review.get("reviewer_model"),
        }
    )


def build_assurance_packet(contract, results, artifacts, runtime_identities, tdd_evidence, hard_stop, review):
    """Build a packet; validation is deliberately separate so callers can test it."""
    if not isinstance(contract, dict):
        raise HarnessValidationError("contract must be an object")
    body_contract = copy.deepcopy(contract)
    candidate_sha = _require_sha(body_contract.get("candidate_sha"), "candidate_sha")
    _require_sha(body_contract.get("base_sha"), "base_sha")
    _require_text(body_contract.get("contract_id"), "contract_id")
    body_contract.setdefault("task_id", body_contract["contract_id"])
    _require_text(body_contract.get("task_id"), "task_id")
    _require_text(body_contract.get("lane_id"), "lane_id")
    if not isinstance(body_contract.get("allowed_paths"), list) or not body_contract["allowed_paths"]:
        raise HarnessValidationError("allowed_paths are required")
    packet_review = copy.deepcopy(review)
    packet_review.setdefault("candidate_sha", candidate_sha)
    packet_review["frozen_binding"] = _frozen_binding(candidate_sha, packet_review)
    packet = {
        "schema_version": SCHEMA_VERSION,
        "contract": body_contract,
        "results": copy.deepcopy(results),
        "artifacts": copy.deepcopy(artifacts),
        "runtime_identities": copy.deepcopy(runtime_identities),
        "tdd_evidence": copy.deepcopy(tdd_evidence),
        "hard_stop": copy.deepcopy(hard_stop),
        "review": packet_review,
    }
    packet["packet_id"] = sha256_value(packet)
    return packet


def validate_assurance_packet(packet, current_candidate_sha=None, expected_frozen_binding=None, artifact_hashes=None):
    """Validate every hash, evidence, binding, review, and hard-stop gate."""
    if not isinstance(packet, dict):
        raise HarnessValidationError("assurance packet must be an object")
    packet_id = packet.get("packet_id")
    _require_sha(packet_id, "packet_id", _HASH)
    unsigned = copy.deepcopy(packet)
    unsigned.pop("packet_id", None)
    if sha256_value(unsigned) != packet_id:
        raise HarnessValidationError("packet_hash_mismatch")
    if packet.get("schema_version") != SCHEMA_VERSION:
        raise HarnessValidationError("schema_version mismatch")
    required = ("contract", "results", "artifacts", "runtime_identities", "tdd_evidence", "hard_stop", "review")
    if any(name not in packet for name in required):
        raise HarnessValidationError("required assurance evidence missing")

    contract = packet["contract"]
    if not isinstance(contract, dict):
        raise HarnessValidationError("packet contract malformed")
    for field in ("task_id", "contract_id", "lane_id"):
        _require_text(contract.get(field), field)
    for field in ("base_sha", "candidate_sha"):
        _require_sha(contract.get(field), field)
    if "candidate_tree_sha256" in contract:
        _require_sha(contract["candidate_tree_sha256"], "candidate_tree_sha256", _HASH)
    if current_candidate_sha is not None and contract["candidate_sha"] != current_candidate_sha:
        raise HarnessValidationError("candidate_sha mismatch")
    paths = contract.get("allowed_paths")
    if not isinstance(paths, list) or not paths or any(not isinstance(item, str) or not item for item in paths):
        raise HarnessValidationError("allowed_paths missing")

    results = packet["results"]
    for name in ("tests", "negative", "regression"):
        result = results.get(name) if isinstance(results, dict) else None
        if not isinstance(result, dict) or result.get("success") is not True:
            raise HarnessValidationError(f"{name} evidence failed or missing")
        evidence = _require_text(result.get("evidence"), f"{name} evidence")
        evidence_hash = _require_sha(result.get("evidence_sha256"), f"{name} evidence_sha256", _HASH)
        if hashlib.sha256(evidence.encode("utf-8")).hexdigest() != evidence_hash:
            raise HarnessValidationError(f"{name} evidence hash mismatch")

    artifacts = packet["artifacts"]
    if not isinstance(artifacts, list) or not artifacts:
        raise HarnessValidationError("artifact evidence missing")
    if not isinstance(artifact_hashes, dict):
        raise HarnessValidationError("actual artifact hashes are required")
    for artifact in artifacts:
        if not isinstance(artifact, dict):
            raise HarnessValidationError("artifact record malformed")
        path = _require_text(artifact.get("path"), "artifact path")
        expected = _require_sha(artifact.get("sha256"), "artifact sha256", _HASH)
        if artifact_hashes.get(path) != expected:
            raise HarnessValidationError("artifact hash mismatch")

    validate_tdd_evidence(contract, packet["tdd_evidence"])
    validate_runtime_identity(contract, packet["runtime_identities"])

    hard_stop = packet["hard_stop"]
    if not isinstance(hard_stop, dict):
        raise HarnessValidationError("hard-stop evidence malformed")
    requested = hard_stop.get("requested_actions", [])
    approved = hard_stop.get("approved_actions", [])
    if not isinstance(requested, list) or not isinstance(approved, list):
        raise HarnessValidationError("hard-stop actions malformed")
    unapproved = sorted({str(item) for item in requested} - {str(item) for item in approved})
    if unapproved:
        raise HarnessValidationError("unapproved owner-hard-stop action")

    review = packet["review"]
    if not isinstance(review, dict):
        raise HarnessValidationError("review evidence malformed")
    for field in ("reviewer_id", "reviewer_family", "reviewer_model"):
        _require_text(review.get(field), field)
    if review.get("candidate_sha") != contract["candidate_sha"]:
        raise HarnessValidationError("review candidate mismatch")
    if review.get("reviewed_head") != contract["candidate_sha"]:
        raise HarnessValidationError("reviewed_head moved from frozen candidate")
    if expected_frozen_binding is not None and review.get("frozen_binding") != expected_frozen_binding:
        raise HarnessValidationError("frozen reviewer binding mismatch")
    if review.get("frozen_binding") != _frozen_binding(contract["candidate_sha"], review):
        raise HarnessValidationError("reviewer binding hash mismatch")
    attempt, maximum = review.get("attempt"), review.get("max_attempts")
    if not isinstance(attempt, int) or not isinstance(maximum, int) or attempt < 1 or maximum < 1 or attempt > maximum:
        raise HarnessValidationError("review attempt budget exceeded or malformed")
    if review.get("approved") is not True:
        raise HarnessValidationError("review is not approved")
    independent = review.get("independent_required") is True
    different_family = review.get("different_family_required") is True
    if independent and review["reviewer_id"] == contract.get("author_id"):
        raise HarnessValidationError("self-review is not independent")
    if different_family and review["reviewer_family"] == contract.get("author_family"):
        raise HarnessValidationError("same-family review is not independent")
    return {"valid": True, "packet_id": packet_id, "authority_granted": False}


def _load_json(path):
    source = sys.stdin.read() if path == "-" else Path(path).read_text(encoding="utf-8")
    return json.loads(source)


def _print_result(result):
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))


def main(argv=None):
    parser = argparse.ArgumentParser(description="EA_LAB Harness v1 deterministic validator")
    sub = parser.add_subparsers(dest="command", required=True)
    route = sub.add_parser("route")
    route.add_argument("contract", help="JSON file or -")
    tdd = sub.add_parser("validate-tdd")
    tdd.add_argument("contract")
    tdd.add_argument("evidence")
    runtime = sub.add_parser("validate-runtime")
    runtime.add_argument("contract")
    runtime.add_argument("records")
    packet = sub.add_parser("validate-packet")
    packet.add_argument("packet")
    packet.add_argument("artifact_hashes")
    packet.add_argument("--current-candidate")
    args = parser.parse_args(argv)
    try:
        if args.command == "route":
            _print_result(route_execution(_load_json(args.contract)))
        elif args.command == "validate-tdd":
            _print_result(validate_tdd_evidence(_load_json(args.contract), _load_json(args.evidence)))
        elif args.command == "validate-runtime":
            _print_result(validate_runtime_identity(_load_json(args.contract), _load_json(args.records)))
        else:
            _print_result(
                validate_assurance_packet(
                    _load_json(args.packet),
                    current_candidate_sha=args.current_candidate,
                    artifact_hashes=_load_json(args.artifact_hashes),
                )
            )
        return 0
    except (HarnessValidationError, OSError, ValueError, json.JSONDecodeError) as exc:
        _print_result({"valid": False, "error": str(exc)})
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
