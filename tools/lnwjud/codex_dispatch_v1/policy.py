from __future__ import annotations

import copy
import hashlib
import json
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Dict, Mapping, Optional

_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$")
_SHA40_RE = re.compile(r"^[0-9a-f]{40}$")
_SHA64_RE = re.compile(r"^[0-9a-f]{64}$")
_ALLOWED_PROFILE_KINDS = {"REVIEW_READ_ONLY", "SOURCE_OWNER_SIDE"}
_ALLOWED_RUNNERS = {"CONTROL_TOWER_RELAY_READ_ONLY", "JOB_CONTROL_FIXED_CODEX_SOURCE"}
_REQUEST_KEYS = {
    "schema", "request_id", "idempotency_key", "actor", "lane_id", "expected_head",
    "contract_sha256", "profile_id", "prompt", "prompt_sha256", "timeout_seconds", "created_utc",
}


class DispatchRefusal(RuntimeError):
    def __init__(self, code: str, message: Optional[str] = None):
        super().__init__(message or code)
        self.code = code


def _refuse(code: str, message: Optional[str] = None) -> None:
    raise DispatchRefusal(code, message)


def _stable(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def _sha256(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _parse_time(value: Any) -> Optional[datetime]:
    if not isinstance(value, str):
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return None
    return parsed.astimezone(timezone.utc)


def _require_id(value: Any, code: str = "INVALID_ID") -> str:
    if not isinstance(value, str) or _ID_RE.fullmatch(value) is None:
        _refuse(code)
    return value


def _validate_request(value: Any, now_utc: str) -> Dict[str, Any]:
    if type(value) is not dict or set(value.keys()) != _REQUEST_KEYS:
        _refuse("MALFORMED_REQUEST")
    request = copy.deepcopy(value)
    if request["schema"] != "LNWJUD_CODEX_DISPATCH_REQUEST_V1":
        _refuse("MALFORMED_REQUEST")
    for field in ("request_id", "idempotency_key", "actor", "lane_id", "profile_id"):
        _require_id(request[field])
    if not isinstance(request["expected_head"], str) or _SHA40_RE.fullmatch(request["expected_head"]) is None:
        _refuse("INVALID_HEAD")
    if not isinstance(request["contract_sha256"], str) or _SHA64_RE.fullmatch(request["contract_sha256"]) is None:
        _refuse("INVALID_CONTRACT")
    if not isinstance(request["prompt"], str) or not request["prompt"]:
        _refuse("INVALID_PROMPT")
    if not isinstance(request["prompt_sha256"], str) or _SHA64_RE.fullmatch(request["prompt_sha256"]) is None:
        _refuse("INVALID_PROMPT_HASH")
    if _sha256(request["prompt"].encode("utf-8")) != request["prompt_sha256"]:
        _refuse("PROMPT_HASH_MISMATCH")
    if isinstance(request["timeout_seconds"], bool) or not isinstance(request["timeout_seconds"], (int, float)) or request["timeout_seconds"] <= 0:
        _refuse("INVALID_TIMEOUT")
    created, now = _parse_time(request["created_utc"]), _parse_time(now_utc)
    if created is None or now is None or created > now:
        _refuse("INVALID_OR_FUTURE_TIME")
    return request


def _validate_profile(value: Any) -> Dict[str, Any]:
    required = {
        "profile_id", "profile_sha256", "kind", "runner", "model", "reasoning_effort",
        "sandbox_policy", "max_timeout_seconds", "allowed_states", "source_mutation_allowed",
    }
    if type(value) is not dict or set(value.keys()) != required:
        _refuse("PROFILE_MALFORMED")
    p = copy.deepcopy(value)
    _require_id(p["profile_id"], "PROFILE_MALFORMED")
    if not isinstance(p["profile_sha256"], str) or _SHA64_RE.fullmatch(p["profile_sha256"]) is None:
        _refuse("PROFILE_MALFORMED")
    body = dict(p)
    declared = body.pop("profile_sha256")
    if _sha256(_stable(body)) != declared:
        _refuse("PROFILE_HASH_MISMATCH")
    if p["kind"] not in _ALLOWED_PROFILE_KINDS or p["runner"] not in _ALLOWED_RUNNERS:
        _refuse("PROFILE_NOT_ALLOWED")
    if not isinstance(p["model"], str) or not p["model"] or not isinstance(p["reasoning_effort"], str):
        _refuse("PROFILE_MALFORMED")
    if not isinstance(p["max_timeout_seconds"], (int, float)) or p["max_timeout_seconds"] <= 0:
        _refuse("PROFILE_MALFORMED")
    if not isinstance(p["allowed_states"], list) or not p["allowed_states"] or not all(isinstance(x, str) for x in p["allowed_states"]):
        _refuse("PROFILE_MALFORMED")
    if not isinstance(p["source_mutation_allowed"], bool):
        _refuse("PROFILE_MALFORMED")
    if p["kind"] == "REVIEW_READ_ONLY":
        if p["runner"] != "CONTROL_TOWER_RELAY_READ_ONLY" or p["sandbox_policy"] != "READ_ONLY" or p["source_mutation_allowed"]:
            _refuse("PROFILE_AUTHORITY_MISMATCH")
    if p["kind"] == "SOURCE_OWNER_SIDE":
        if p["runner"] != "JOB_CONTROL_FIXED_CODEX_SOURCE" or p["sandbox_policy"] != "OWNER_SIDE_NO_CODEX_SANDBOX" or not p["source_mutation_allowed"]:
            _refuse("PROFILE_AUTHORITY_MISMATCH")
    return p


def profile_hash(profile_without_hash: Mapping[str, Any]) -> str:
    return _sha256(_stable(dict(profile_without_hash)))


def dispatch_id(lane_id: str, idempotency_key: str, profile_id: str) -> str:
    return "cdx-" + _sha256((lane_id + "\0" + idempotency_key + "\0" + profile_id).encode("utf-8"))[:40]


class CodexDispatchPolicy:
    def __init__(self, *, lane_reader: Any, contract_reader: Any, profile_catalog: Any, audit: Any, executors: Mapping[str, Any], now_utc: Any):
        self.lane_reader = lane_reader
        self.contract_reader = contract_reader
        self.profile_catalog = profile_catalog
        self.audit = audit
        self.executors = dict(executors)
        self.now_utc = now_utc
        if not all(hasattr(lane_reader, name) for name in ("get_lane",)):
            _refuse("UNQUALIFIED_LANE_READER")
        if not all(hasattr(contract_reader, name) for name in ("get_contract_bytes",)):
            _refuse("UNQUALIFIED_CONTRACT_READER")
        if not all(hasattr(profile_catalog, name) for name in ("get_profile",)):
            _refuse("UNQUALIFIED_PROFILE_CATALOG")
        if getattr(audit, "kind", None) != "DURABLE_AUDIT_STORE_V1" or not all(hasattr(audit, n) for n in ("with_lock", "get", "prepare", "finalize")):
            _refuse("UNQUALIFIED_AUDIT_STORE")
        if not callable(now_utc):
            _refuse("UNQUALIFIED_CLOCK")

    def _environment(self, request: Dict[str, Any]) -> tuple[Dict[str, Any], Dict[str, Any], bytes, Any]:
        lane = self.lane_reader.get_lane(request["lane_id"])
        if type(lane) is not dict:
            _refuse("LANE_UNAVAILABLE")
        required_lane = {"lane_id", "state", "head_sha", "worktree", "branch", "clean", "path_identity_verified", "budget_available"}
        if not required_lane.issubset(lane.keys()):
            _refuse("LANE_MALFORMED")
        if lane["lane_id"] != request["lane_id"] or lane["head_sha"] != request["expected_head"]:
            _refuse("STALE_LANE_IDENTITY")
        if lane["clean"] is not True or lane["path_identity_verified"] is not True:
            _refuse("WORKTREE_IDENTITY_UNPROVEN")
        if lane["budget_available"] is not True:
            _refuse("BUDGET_EXHAUSTED")
        profile = _validate_profile(self.profile_catalog.get_profile(request["profile_id"]))
        if profile["profile_id"] != request["profile_id"] or lane["state"] not in profile["allowed_states"]:
            _refuse("PROFILE_STATE_REFUSED")
        if request["timeout_seconds"] > profile["max_timeout_seconds"]:
            _refuse("TIMEOUT_EXCEEDS_PROFILE")
        contract = self.contract_reader.get_contract_bytes(request["contract_sha256"])
        if not isinstance(contract, (bytes, bytearray)) or _sha256(bytes(contract)) != request["contract_sha256"]:
            _refuse("CONTRACT_MISMATCH")
        executor = self.executors.get(profile["runner"])
        if executor is None or getattr(executor, "kind", None) != "TYPED_CODEX_EXECUTOR_V1" or not all(hasattr(executor, n) for n in ("find_existing", "dispatch")):
            _refuse("EXECUTOR_UNAVAILABLE")
        return lane, profile, bytes(contract), executor

    def dispatch(self, raw_request: Dict[str, Any]) -> Dict[str, Any]:
        request = _validate_request(raw_request, self.now_utc())
        request_hash = _sha256(_stable(request))
        key = request["idempotency_key"]
        with self.audit.with_lock():
            existing_audit = self.audit.get(key)
            if existing_audit is not None:
                if existing_audit.get("request_sha256") != request_hash:
                    _refuse("IDEMPOTENCY_DRIFT")
                if existing_audit.get("status") == "FINAL":
                    return copy.deepcopy(existing_audit["receipt"])
                if existing_audit.get("status") != "PREPARED":
                    _refuse("AUDIT_STATE_MALFORMED")
            lane, profile, _contract, executor = self._environment(request)
            plan_id = dispatch_id(request["lane_id"], key, request["profile_id"])
            plan = {
                "dispatch_id": plan_id,
                "lane_id": request["lane_id"],
                "head_sha": request["expected_head"],
                "worktree": lane["worktree"],
                "branch": lane["branch"],
                "contract_sha256": request["contract_sha256"],
                "profile_id": profile["profile_id"],
                "profile_sha256": profile["profile_sha256"],
                "profile_kind": profile["kind"],
                "runner": profile["runner"],
                "model": profile["model"],
                "reasoning_effort": profile["reasoning_effort"],
                "sandbox_policy": profile["sandbox_policy"],
                "prompt": request["prompt"],
                "prompt_sha256": request["prompt_sha256"],
                "timeout_seconds": request["timeout_seconds"],
                "actor": request["actor"],
            }
            if existing_audit is None:
                self.audit.prepare(key, request_hash, {"dispatch_id": plan_id, "prepared_utc": self.now_utc(), "profile_sha256": profile["profile_sha256"]})
                prepared = self.audit.get(key)
                if not prepared or prepared.get("status") != "PREPARED" or prepared.get("request_sha256") != request_hash:
                    _refuse("AUDIT_PREPARE_READBACK_MISMATCH")
            found = executor.find_existing(plan_id)
            launched = False
            if found is None:
                found = executor.dispatch(copy.deepcopy(plan))
                launched = True
            if type(found) is not dict or found.get("dispatch_id") != plan_id or not isinstance(found.get("job_id"), str) or not found["job_id"]:
                _refuse("DISPATCH_RECEIPT_INVALID")
            receipt = {
                "schema": "LNWJUD_CODEX_DISPATCH_RECEIPT_V1",
                "request_id": request["request_id"],
                "idempotency_key": key,
                "request_sha256": request_hash,
                "dispatch_id": plan_id,
                "job_id": found["job_id"],
                "lane_id": request["lane_id"],
                "head_sha": request["expected_head"],
                "contract_sha256": request["contract_sha256"],
                "profile_id": profile["profile_id"],
                "profile_sha256": profile["profile_sha256"],
                "prompt_sha256": request["prompt_sha256"],
                "outcome": "DISPATCHED" if launched else "ADOPTED_EXISTING",
                "created_utc": self.now_utc(),
            }
            self.audit.finalize(key, request_hash, receipt)
            readback = self.audit.get(key)
            if not readback or readback.get("status") != "FINAL" or readback.get("receipt") != receipt:
                _refuse("AUDIT_FINAL_READBACK_MISMATCH")
            return copy.deepcopy(receipt)
