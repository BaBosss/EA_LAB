#!/usr/bin/env python3
"""Build deterministic compact task/review packets from closed JSON input."""

from __future__ import annotations

import argparse
import base64
import binascii
import hashlib
import json
import os
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Sequence, Tuple


POLICY_PATH = Path(__file__).with_name("mode_policy.json")
HEX40 = re.compile(r"^[0-9a-fA-F]{40}$")
HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")
IDENTITY = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$")
OUTPUT_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}\.json$")
COMMON_FIELDS = {
    "schema_version", "packet_type", "mode", "task_id", "lane_id", "source_head",
    "objective", "allowed_paths", "forbidden_operations", "authority_ceiling",
    "direct_consumer", "downstream_skip", "unique_output", "source_records",
    "evidence_records", "required_gates", "repair_used", "repair_limit",
}
REQUIRED_COMMON_FIELDS = COMMON_FIELDS - {"mode"}
REVIEW_FIELDS = {
    "author_job_id", "author_lane_id", "reviewer_job_id", "reviewer_lane_id",
    "reviewed_head", "evidence_identity",
}


class PacketError(ValueError):
    """Closed-contract validation or safe-output failure."""


def _unique_object(pairs: Sequence[Tuple[str, Any]]) -> Dict[str, Any]:
    result: Dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise PacketError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _reject_constant(value: str) -> None:
    raise PacketError(f"non-finite JSON number is forbidden: {value}")


def load_json_bytes(raw: bytes) -> Dict[str, Any]:
    """Decode strict UTF-8 JSON while refusing BOMs, duplicate keys and NaN/Infinity."""
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise PacketError("input must be UTF-8 JSON") from exc
    if text.startswith("\ufeff"):
        raise PacketError("UTF-8 BOM is not allowed")
    try:
        value = json.loads(text, object_pairs_hook=_unique_object, parse_constant=_reject_constant)
    except PacketError:
        raise
    except json.JSONDecodeError as exc:
        raise PacketError(f"invalid JSON: {exc.msg}") from exc
    if not isinstance(value, dict):
        raise PacketError("input root must be an object")
    return value


def _compact(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf-8")


def _sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def _plain_string(value: Any, field: str) -> str:
    if not isinstance(value, str) or not value.strip() or value != value.strip():
        raise PacketError(f"{field} must be a non-empty, surrounding-whitespace-free string")
    if any(ord(char) < 32 for char in value):
        raise PacketError(f"{field} contains a control character")
    return value


def _identity(value: Any, field: str) -> str:
    value = _plain_string(value, field)
    if not IDENTITY.fullmatch(value):
        raise PacketError(f"{field} has invalid identity syntax")
    return value


def _string_list(value: Any, field: str) -> List[str]:
    if not isinstance(value, list) or not value:
        raise PacketError(f"{field} must be a non-empty array")
    result = [_plain_string(item, f"{field}[{index}]") for index, item in enumerate(value)]
    folded = [item.casefold() for item in result]
    if len(set(folded)) != len(folded):
        raise PacketError(f"{field} contains a duplicate or case-ambiguous value")
    return result


def _repo_path(value: Any, field: str) -> str:
    value = _plain_string(value, field)
    if "\\" in value or value.startswith("/") or ":" in value or "//" in value or value.endswith("/"):
        raise PacketError(f"{field} must be a canonical repository-relative POSIX path")
    parts = value.split("/")
    if any(part in ("", ".", "..") for part in parts):
        raise PacketError(f"{field} contains traversal or an ambiguous segment")
    return value


def _locator(value: Any, field: str) -> str:
    value = _plain_string(value, field)
    if "/" in value and "\\" in value:
        raise PacketError(f"{field} mixes path separators")
    separator = "\\" if "\\" in value else "/"
    if separator * 2 in value:
        raise PacketError(f"{field} contains repeated separators")
    parts = value.split(separator)
    if any(part in (".", "..") for part in parts):
        raise PacketError(f"{field} contains traversal or an ambiguous segment")
    if value.endswith(separator):
        raise PacketError(f"{field} has an ambiguous trailing separator")
    if separator == "/" and value.startswith("/"):
        raise PacketError(f"{field} must use canonical Windows syntax for an absolute locator")
    if separator == "\\" and not re.match(r"^[A-Za-z]:\\[^\\]", value):
        raise PacketError(f"{field} has invalid absolute Windows locator syntax")
    return value


def _records(value: Any, field: str, seen: Dict[str, str] | None = None) -> List[Dict[str, Any]]:
    if not isinstance(value, list) or not value:
        raise PacketError(f"{field} must be a non-empty array")
    result: List[Dict[str, Any]] = []
    if seen is None:
        seen = {}
    for index, record in enumerate(value):
        prefix = f"{field}[{index}]"
        if not isinstance(record, dict):
            raise PacketError(f"{prefix} must be an object")
        allowed = {"locator", "sha256", "bytes_base64"}
        unknown = set(record) - allowed
        if unknown or not {"locator", "sha256"}.issubset(record):
            raise PacketError(f"{prefix} has missing or unknown fields: {sorted(unknown)}")
        locator = _locator(record["locator"], f"{prefix}.locator")
        digest = _plain_string(record["sha256"], f"{prefix}.sha256")
        if not HEX64.fullmatch(digest):
            raise PacketError(f"{prefix}.sha256 must be exactly 64 hexadecimal characters")
        key = locator.casefold()
        if key in seen:
            conflict = " with conflicting hashes" if seen[key].casefold() != digest.casefold() else ""
            raise PacketError(f"duplicate or case-ambiguous locator{conflict}: {locator}")
        seen[key] = digest
        output: Dict[str, Any] = {"locator": locator, "sha256": digest}
        if "bytes_base64" in record:
            encoded = _plain_string(record["bytes_base64"], f"{prefix}.bytes_base64")
            try:
                supplied = base64.b64decode(encoded, validate=True)
            except (binascii.Error, ValueError) as exc:
                raise PacketError(f"{prefix}.bytes_base64 is not canonical base64") from exc
            if base64.b64encode(supplied).decode("ascii") != encoded:
                raise PacketError(f"{prefix}.bytes_base64 is not canonical base64")
            if _sha256(supplied).casefold() != digest.casefold():
                raise PacketError(f"{prefix} supplied bytes do not match declared sha256")
            output["verification"] = "VERIFIED_SUPPLIED_BYTES"
        else:
            output["verification"] = "DECLARED_NOT_RECOMPUTED"
        result.append(output)
    return result


def _gates(value: Any) -> List[Dict[str, str]]:
    if not isinstance(value, list) or not value:
        raise PacketError("required_gates must be a non-empty array")
    result: List[Dict[str, str]] = []
    seen = set()
    for index, gate in enumerate(value):
        if not isinstance(gate, dict) or set(gate) != {"gate_id", "requirement"}:
            raise PacketError(f"required_gates[{index}] must contain only gate_id and requirement")
        gate_id = _identity(gate["gate_id"], f"required_gates[{index}].gate_id")
        if gate_id.casefold() in seen:
            raise PacketError(f"duplicate required gate: {gate_id}")
        seen.add(gate_id.casefold())
        result.append({"gate_id": gate_id, "requirement": _plain_string(gate["requirement"], f"required_gates[{index}].requirement")})
    return result


def _nonnegative_integer(value: Any, field: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        raise PacketError(f"{field} must be a non-negative integer")
    return value


def _validate_policy(policy: Dict[str, Any]) -> None:
    expected = {"schema_version", "default_mode", "advisory_signals", "acceptance_requirements", "modes", "limits"}
    if set(policy) != expected or policy.get("schema_version") != "codex_budget_mode_policy/1":
        raise PacketError("mode policy has an unsupported shape or version")
    if policy.get("default_mode") != "NORMAL" or not isinstance(policy.get("modes"), dict) or set(policy["modes"]) != {"NORMAL", "ECONOMY"}:
        raise PacketError("mode policy must define NORMAL default and exactly NORMAL/ECONOMY")
    _string_list(policy.get("acceptance_requirements"), "policy.acceptance_requirements")
    _string_list(policy.get("limits"), "policy.limits")
    if not isinstance(policy.get("advisory_signals"), dict) or set(policy["advisory_signals"]) != {"NORMAL", "ECONOMY"}:
        raise PacketError("mode policy advisory signals must define exactly NORMAL/ECONOMY")
    mode_fields = {"recommendation_only", "author_reasoning", "high_reasoning_when", "model_wip", "subagents", "compact_packets"}
    for mode in ("NORMAL", "ECONOMY"):
        advisory = policy["advisory_signals"][mode]
        if not isinstance(advisory, dict) or set(advisory) != {"alert_tokens"}:
            raise PacketError(f"mode policy {mode} advisory signal has an unsupported shape")
        alerts = advisory["alert_tokens"]
        if not isinstance(alerts, list) or len(alerts) != 2 or any(isinstance(item, bool) or not isinstance(item, int) or item <= 0 for item in alerts) or alerts != sorted(alerts):
            raise PacketError(f"mode policy {mode} alert_tokens must be two increasing positive integers")
        recommendation = policy["modes"][mode]
        if not isinstance(recommendation, dict) or set(recommendation) != mode_fields:
            raise PacketError(f"mode policy {mode} recommendation has an unsupported shape")
        if recommendation["recommendation_only"] is not True or recommendation["author_reasoning"] != "MEDIUM":
            raise PacketError(f"mode policy {mode} must remain recommendation-only with MEDIUM authoring")
        _string_list(recommendation["high_reasoning_when"], f"policy.modes.{mode}.high_reasoning_when")
        if not isinstance(recommendation["model_wip"], dict) or set(recommendation["model_wip"]) != {"normal", "maximum"}:
            raise PacketError(f"mode policy {mode} model_wip has an unsupported shape")
        normal = _nonnegative_integer(recommendation["model_wip"]["normal"], f"policy.modes.{mode}.model_wip.normal")
        maximum = _nonnegative_integer(recommendation["model_wip"]["maximum"], f"policy.modes.{mode}.model_wip.maximum")
        if normal == 0 or maximum < normal:
            raise PacketError(f"mode policy {mode} model_wip is invalid")
        _plain_string(recommendation["subagents"], f"policy.modes.{mode}.subagents")
        _plain_string(recommendation["compact_packets"], f"policy.modes.{mode}.compact_packets")


def _validate_input(data: Dict[str, Any]) -> Dict[str, Any]:
    packet_type = data.get("packet_type")
    if packet_type not in ("TASK_PACKET", "REVIEW_PACKET"):
        raise PacketError("packet_type must be TASK_PACKET or REVIEW_PACKET")
    allowed = COMMON_FIELDS | (REVIEW_FIELDS if packet_type == "REVIEW_PACKET" else set())
    required = REQUIRED_COMMON_FIELDS | (REVIEW_FIELDS if packet_type == "REVIEW_PACKET" else set())
    missing, unknown = required - set(data), set(data) - allowed
    if missing or unknown:
        raise PacketError(f"input fields do not match closed contract; missing={sorted(missing)}, unknown={sorted(unknown)}")
    if data["schema_version"] != "codex_budget_packet_input/1":
        raise PacketError("unsupported schema_version")
    mode = data.get("mode", "NORMAL")
    if mode not in ("NORMAL", "ECONOMY"):
        raise PacketError("mode must be NORMAL or ECONOMY")
    provenance_seen: Dict[str, str] = {}
    validated: Dict[str, Any] = {
        "schema_version": data["schema_version"],
        "packet_type": packet_type,
        "mode": mode,
        "task_id": _identity(data["task_id"], "task_id"),
        "lane_id": _identity(data["lane_id"], "lane_id"),
        "source_head": _plain_string(data["source_head"], "source_head"),
        "objective": _plain_string(data["objective"], "objective"),
        "allowed_paths": [_repo_path(item, f"allowed_paths[{index}]") for index, item in enumerate(data["allowed_paths"])] if isinstance(data["allowed_paths"], list) and data["allowed_paths"] else None,
        "forbidden_operations": _string_list(data["forbidden_operations"], "forbidden_operations"),
        "authority_ceiling": _string_list(data["authority_ceiling"], "authority_ceiling"),
        "direct_consumer": _plain_string(data["direct_consumer"], "direct_consumer"),
        "downstream_skip": _string_list(data["downstream_skip"], "downstream_skip"),
        "unique_output": _plain_string(data["unique_output"], "unique_output"),
        "source_records": _records(data["source_records"], "source_records", provenance_seen),
        "evidence_records": _records(data["evidence_records"], "evidence_records", provenance_seen),
        "required_gates": _gates(data["required_gates"]),
        "repair_used": _nonnegative_integer(data["repair_used"], "repair_used"),
        "repair_limit": _nonnegative_integer(data["repair_limit"], "repair_limit"),
    }
    if validated["allowed_paths"] is None:
        raise PacketError("allowed_paths must be a non-empty array")
    if len({path.casefold() for path in validated["allowed_paths"]}) != len(validated["allowed_paths"]):
        raise PacketError("allowed_paths contains a duplicate or case-ambiguous path")
    if not HEX40.fullmatch(validated["source_head"]):
        raise PacketError("source_head must be exactly 40 hexadecimal characters")
    if not OUTPUT_NAME.fullmatch(validated["unique_output"]):
        raise PacketError("unique_output must be a simple .json filename without traversal")
    if validated["repair_used"] > validated["repair_limit"]:
        raise PacketError("repair_used cannot exceed repair_limit")
    if packet_type == "REVIEW_PACKET":
        for field in ("author_job_id", "author_lane_id", "reviewer_job_id", "reviewer_lane_id"):
            validated[field] = _identity(data[field], field)
        if validated["author_job_id"].casefold() == validated["reviewer_job_id"].casefold():
            raise PacketError("reviewer job must be distinct from author job")
        if validated["author_lane_id"].casefold() == validated["reviewer_lane_id"].casefold():
            raise PacketError("reviewer lane must be distinct from author lane")
        validated["reviewed_head"] = _plain_string(data["reviewed_head"], "reviewed_head")
        if validated["reviewed_head"] != validated["source_head"]:
            raise PacketError("reviewed_head must exactly equal source_head")
        validated["evidence_identity"] = _plain_string(data["evidence_identity"], "evidence_identity")
    return validated


def build_packet(input_bytes: bytes, policy_bytes: bytes | None = None) -> Tuple[Dict[str, Any], bytes]:
    """Return the output envelope and its deterministic compact bytes."""
    canonical_policy_bytes = POLICY_PATH.read_bytes()
    if policy_bytes is not None and policy_bytes != canonical_policy_bytes:
        raise PacketError("policy_bytes must be byte-identical to the packaged canonical mode_policy.json")
    actual_policy_bytes = canonical_policy_bytes
    data = _validate_input(load_json_bytes(input_bytes))
    policy = load_json_bytes(actual_policy_bytes)
    _validate_policy(policy)
    mode = data["mode"]
    mode_metadata = dict(policy["modes"][mode])
    mode_metadata["mode"] = mode
    mode_metadata["advisory_alert_tokens"] = policy["advisory_signals"][mode]["alert_tokens"]
    mode_metadata["limits"] = policy["limits"]
    packet = dict(data)
    packet["acceptance_requirements"] = list(policy["acceptance_requirements"])
    packet["mode_metadata"] = mode_metadata
    packet["verification_limits"] = {
        "source_head": "SYNTAX_VALIDATED_NOT_GIT_ACCEPTED",
        "source_and_evidence_hashes": "DECLARED_NOT_RECOMPUTED_UNLESS_RECORD_SAYS_VERIFIED_SUPPLIED_BYTES",
        "packet": "SOURCE_ONLY_NOT_ACCEPTANCE",
        "boot_mini": "NAVIGATION_ONLY_NOT_GOVERNANCE_OR_SOURCE_TRUTH",
        "runtime": "NOT_ACTIVATED",
    }
    boot_mini = {
        "kind": "BOOT_MINI",
        "navigation_only": True,
        "task_id": data["task_id"],
        "lane_id": data["lane_id"],
        "source_head": data["source_head"],
        "packet_type": data["packet_type"],
        "source_records": data["source_records"],
        "evidence_records": data["evidence_records"],
        "next": data["packet_type"],
        "warning": "Not a substitute for governance, the contract, source truth, or evidence bytes.",
    }
    payload = {"boot_mini": boot_mini, "packet": packet}
    payload_bytes = _compact(payload)
    envelope = {
        "schema_version": "codex_budget_packet_output/1",
        "payload": payload,
        "receipt": {
            "input_sha256": _sha256(input_bytes),
            "input_bytes": len(input_bytes),
            "policy_sha256": _sha256(actual_policy_bytes),
            "policy_bytes": len(actual_policy_bytes),
            "output_payload_sha256": _sha256(payload_bytes),
            "output_payload_bytes": len(payload_bytes),
            "output_payload_encoding": "UTF-8_CANONICAL_JSON_SORTED_KEYS_COMPACT",
            "receipt_scope": "Exact input bytes, policy bytes, and canonical emitted payload bytes; the containing envelope cannot self-hash.",
            "verification_limit": "Referenced hashes remain declared unless the matching record says VERIFIED_SUPPLIED_BYTES.",
        },
    }
    return envelope, _compact(envelope)


def write_packet(input_path: Path, output_dir: Path) -> Path:
    """Build once and atomically create the caller-named output without overwrite."""
    input_bytes = input_path.read_bytes()
    data = _validate_input(load_json_bytes(input_bytes))
    if not output_dir.is_dir():
        raise PacketError("output directory must already exist and be a directory")
    output_path = output_dir / data["unique_output"]
    try:
        resolved_dir = output_dir.resolve(strict=True)
        resolved_parent = output_path.parent.resolve(strict=True)
    except OSError as exc:
        raise PacketError("output directory cannot be resolved") from exc
    if resolved_parent != resolved_dir:
        raise PacketError("output path escapes the explicit output directory")
    envelope, output_bytes = build_packet(input_bytes)
    try:
        descriptor = os.open(output_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except FileExistsError as exc:
        raise PacketError(f"output already exists: {output_path.name}") from exc
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(output_bytes)
            stream.flush()
            os.fsync(stream.fileno())
    except Exception:
        try:
            output_path.unlink()
        except OSError:
            pass
        raise
    return output_path


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="closed-contract UTF-8 JSON input")
    parser.add_argument("--output-dir", required=True, type=Path, help="existing explicit output directory")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        output_path = write_packet(args.input, args.output_dir)
        output_bytes = output_path.read_bytes()
        envelope = load_json_bytes(output_bytes)
        summary = {
            "status": "CREATED",
            "output": str(output_path),
            "output_sha256": _sha256(output_bytes),
            "source_head": envelope["payload"]["packet"]["source_head"],
            "input_sha256": envelope["receipt"]["input_sha256"],
            "policy_sha256": envelope["receipt"]["policy_sha256"],
        }
        sys.stdout.write(_compact(summary).decode("utf-8") + "\n")
        return 0
    except (OSError, PacketError) as exc:
        sys.stderr.write(f"REFUSED: {exc}\n")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
