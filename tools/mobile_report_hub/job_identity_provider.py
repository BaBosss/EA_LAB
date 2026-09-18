"""Pure adapter for frozen EA_LAB Long Job identity capture bundles."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import re
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any


CAPTURE_SCHEMA = "EA_LAB_JOB_IDENTITY_CAPTURE_V1"
PUBLIC_SCHEMA = "EA_LAB_JOB_OBSERVATIONS_V1"
SOURCE_KIND = "LOCAL_DURABLE_JOB_STATUS"
PRIVATE_SCHEMA = "EA_LAB_JOB_IDENTITY_PROVENANCE_V1"
PUBLICATION_SCHEMA = "EA_LAB_JOB_IDENTITY_PUBLICATION_V1"

_ID_RE = re.compile(r"[A-Za-z][A-Za-z0-9._-]{0,127}")
_JOB_ID_RE = re.compile(r"[A-Za-z][A-Za-z0-9._-]{2,79}")
_SENSITIVE_ID_RE = re.compile(
    r"(?:^|[._-])(?:account|acct|login|password|credential|secret|token|api[_-]?key)(?:$|[._-])"
    r"|(?<![0-9])[0-9]{9,}(?![0-9])",
    re.IGNORECASE,
)
_SHA_RE = re.compile(r"[0-9a-f]{40}")
_SHA256_RE = re.compile(r"[0-9a-f]{64}")
_MAX_SAFE_INTEGER = 9_007_199_254_740_991
_TIME_RE = re.compile(
    r"(?P<date>\d{4}-\d{2}-\d{2})T(?P<clock>\d{2}:\d{2}:\d{2})"
    r"(?:\.(?P<fraction>\d{1,7}))?(?P<zone>Z|[+-]\d{2}:\d{2})"
)

_MANIFEST_KEYS = {
    "schema_version", "status", "captured_at_utc", "repo_root", "expected_head",
    "canonical_observed_sha", "lease_root", "jobs_root", "requested_lane_ids", "sources", "process_checks",
}
_SOURCE_KEYS = {
    "lane_id", "kind", "presence", "relative_path", "sha256", "length",
    "last_write_utc", "before", "after",
}
_FINGERPRINT_KEYS = {"presence", "sha256", "length", "last_write_utc"}
_CHECK_KEYS = {
    "lane_id", "job_id", "role", "pid", "expected_creation_utc",
    "current_creation_utc", "identity", "query_status", "checked_utc",
}
_LEASE_KEYS = {
    "lane_id", "job_id", "created_utc", "job_root", "status_script", "runner_root",
    "requested_file", "launch_file", "worktree", "base_sha", "stage",
}
_JOB_KEYS = {
    "job_id", "file_path", "arg_count", "arg_hash", "timeout_sec", "heartbeat_sec",
    "worktree", "base_sha", "stage", "postcondition_file_path",
    "postcondition_arg_count", "postcondition_arg_hash", "created_utc",
}
_STATE_KEYS = {
    "job_id", "state", "runner_pid", "runner_start_utc", "child_pid",
    "child_start_utc", "postcondition_pid", "postcondition_start_utc", "created_utc",
    "started_utc", "ended_utc", "timeout_sec", "heartbeat_sec", "file_path",
    "postcondition_file_path", "exit_code", "postcondition_exit_code", "reason",
    "jobs_root", "job_root", "request_file",
}
_HEARTBEAT_KEYS = {"job_id", "state", "runner_pid", "child_pid", "postcondition_pid", "updated_utc"}
_RESULT_KEYS = {
    "job_id", "state", "exit_code", "runner_pid", "child_pid", "ended_utc",
    "reason", "postcondition_exit_code",
}
_ROLES = ("runner", "child", "postcondition")
_KINDS = ("lease", "job", "state", "heartbeat", "result")
_ACTIVE = {"STARTING", "RUNNING", "POSTCONDITION_RUNNING"}
_TERMINAL = {"COMPLETE", "FAILED", "POSTCONDITION_FAILED", "TIMED_OUT", "CANCELLED", "LOST_PROCESS"}
_ALL_STATES = _ACTIVE | _TERMINAL | {"CANCEL_REQUESTED"}
_IDENTITIES = {
    "MATCHING_RECORDED_PROCESS", "RECORDED_PROCESS_NOT_PRESENT",
    "DIFFERENT_CREATION_IDENTITY", "UNKNOWN",
}
_QUERY = {"PRESENT", "NOT_PRESENT", "INACCESSIBLE", "ERROR", "NOT_CONFIGURED"}


class ProviderError(ValueError):
    """The complete requested snapshot cannot be represented faithfully."""


@dataclass(frozen=True)
class PreciseTime:
    ticks_100ns: int

    def whole_second_utc(self) -> str:
        seconds = self.ticks_100ns // 10_000_000
        return datetime.fromtimestamp(seconds, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _reject_constant(value: str) -> None:
    raise ProviderError(f"nonfinite JSON value: {value}")


def _pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ProviderError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _json_bytes(data: bytes, label: str) -> Any:
    try:
        text = data.decode("utf-8-sig")
        return json.loads(text, object_pairs_hook=_pairs, parse_constant=_reject_constant)
    except ProviderError:
        raise
    except (UnicodeError, json.JSONDecodeError, TypeError, ValueError) as error:
        raise ProviderError(f"invalid JSON in {label}") from error


def _keys(value: Any, allowed: set[str], required: set[str], label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ProviderError(f"{label} must be an object")
    actual = set(value)
    if not required <= actual or not actual <= allowed:
        raise ProviderError(f"invalid {label} keys")
    return value


def _string(value: Any, label: str) -> str:
    if not isinstance(value, str):
        raise ProviderError(f"invalid {label} type")
    return value


def _integer(value: Any, label: str, *, nullable: bool = False, positive: bool = False) -> int | None:
    if value is None and nullable:
        return None
    if type(value) is not int or (positive and value <= 0) or abs(value) > _MAX_SAFE_INTEGER:
        raise ProviderError(f"invalid {label} type")
    return value


def _parse_time(value: Any, label: str) -> PreciseTime:
    if not isinstance(value, str):
        raise ProviderError(f"invalid {label} time")
    match = _TIME_RE.fullmatch(value)
    if match is None:
        raise ProviderError(f"invalid {label} time")
    fraction = (match.group("fraction") or "").ljust(7, "0")
    zone_text = match.group("zone")
    try:
        base = datetime.strptime(match.group("date") + "T" + match.group("clock"), "%Y-%m-%dT%H:%M:%S")
        if zone_text == "Z":
            offset = timedelta(0)
        else:
            sign = 1 if zone_text[0] == "+" else -1
            hours = int(zone_text[1:3])
            minutes = int(zone_text[4:6])
            if hours > 14 or minutes > 59 or (hours == 14 and minutes != 0):
                raise ValueError("invalid offset")
            offset = sign * timedelta(hours=hours, minutes=minutes)
        aware = base.replace(tzinfo=timezone(offset)).astimezone(timezone.utc)
        epoch_seconds = int(aware.timestamp())
    except (OverflowError, OSError, ValueError) as error:
        raise ProviderError(f"invalid {label} time") from error
    return PreciseTime(epoch_seconds * 10_000_000 + int(fraction or "0"))


def _safe_id(value: Any, label: str, *, job: bool = False) -> str:
    pattern = _JOB_ID_RE if job else _ID_RE
    if not isinstance(value, str) or pattern.fullmatch(value) is None or _SENSITIVE_ID_RE.search(value):
        raise ProviderError(f"unsafe {label}")
    return value


def _is_reparse(path: Path) -> bool:
    if path.is_symlink():
        return True
    try:
        return bool(path.stat(follow_symlinks=False).st_file_attributes & 0x400)
    except AttributeError:
        return False


def _assert_no_reparse(path: Path, label: str) -> None:
    absolute = path.absolute()
    parts = absolute.parts
    current = Path(parts[0])
    for part in parts[1:]:
        current /= part
        if current.exists() and _is_reparse(current):
            raise ProviderError(f"{label} contains symlink or reparse component")


def _assert_single_link(path: Path, label: str) -> None:
    try:
        links = path.stat(follow_symlinks=False).st_nlink
    except OSError as error:
        raise ProviderError(f"cannot inspect {label} hardlink identity") from error
    if links != 1:
        raise ProviderError(f"{label} is hardlinked")


def _within(path: Path, root: Path) -> bool:
    try:
        path.resolve(strict=False).relative_to(root.resolve(strict=False))
        return True
    except ValueError:
        return False


def _overlap(left: Path, right: Path) -> bool:
    return _within(left, right) or _within(right, left)


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True, ensure_ascii=True, allow_nan=False) + "\n").encode("utf-8")


def _write_exclusive(path: Path, data: bytes) -> None:
    with path.open("xb") as stream:
        stream.write(data)
        stream.flush()
        os.fsync(stream.fileno())


def _fingerprint(value: Any, label: str) -> dict[str, Any]:
    value = _keys(value, _FINGERPRINT_KEYS, _FINGERPRINT_KEYS, label)
    presence = value["presence"]
    if presence not in {"PRESENT", "ABSENT"}:
        raise ProviderError(f"invalid {label} presence")
    length = _integer(value["length"], f"{label} length")
    if length is None or length < 0:
        raise ProviderError(f"invalid {label} length")
    stamp = value["last_write_utc"]
    digest = value["sha256"]
    if presence == "ABSENT":
        if digest != "ABSENT" or length != 0 or stamp is not None:
            raise ProviderError(f"invalid absent-file sentinel in {label}")
    else:
        if not isinstance(digest, str) or _SHA256_RE.fullmatch(digest) is None:
            raise ProviderError(f"invalid {label} hash")
        _parse_time(stamp, f"{label} last write")
    return value


def _validate_source_records(manifest: dict[str, Any], bundle_root: Path, captured: PreciseTime) -> dict[tuple[str | None, str], bytes | None]:
    sources = manifest["sources"]
    if not isinstance(sources, list):
        raise ProviderError("sources must be a list")
    found: dict[tuple[str | None, str], bytes | None] = {}
    declared_files = {Path("manifest.json")}
    for index, raw in enumerate(sources):
        source = _keys(raw, _SOURCE_KEYS, _SOURCE_KEYS, f"source[{index}]")
        lane = source["lane_id"]
        kind = source["kind"]
        if kind == "helper":
            if lane is not None:
                raise ProviderError("helper source must be shared")
        else:
            lane = _safe_id(lane, "source lane_id")
            if kind not in _KINDS:
                raise ProviderError("invalid source kind")
        identity = (lane, kind)
        if identity in found:
            raise ProviderError("duplicate source identity")
        before = _fingerprint(source["before"], f"source[{index}].before")
        after = _fingerprint(source["after"], f"source[{index}].after")
        direct = {key: source[key] for key in _FINGERPRINT_KEYS}
        _fingerprint(direct, f"source[{index}]")
        if before != after or direct != before:
            raise ProviderError("source changed during capture")
        if before["presence"] == "ABSENT":
            if source["relative_path"] is not None:
                raise ProviderError("absent source has a path")
            found[identity] = None
            continue
        relative_text = source["relative_path"]
        if not isinstance(relative_text, str):
            raise ProviderError("invalid source path")
        relative = Path(relative_text)
        if relative.is_absolute() or ".." in relative.parts or ":" in relative_text:
            raise ProviderError("unsafe source path")
        target = bundle_root / relative
        if not _within(target, bundle_root):
            raise ProviderError("source path escapes bundle")
        _assert_no_reparse(target, "source path")
        if not target.is_file():
            raise ProviderError("declared source is missing")
        _assert_single_link(target, "declared source")
        data = target.read_bytes()
        if len(data) != source["length"] or _sha256(data) != source["sha256"]:
            raise ProviderError("source length or hash mismatch")
        if _parse_time(source["last_write_utc"], "source last write").ticks_100ns > captured.ticks_100ns + 3_000_000_000:
            raise ProviderError("source has forged future timestamp")
        declared_files.add(relative)
        found[identity] = data
    actual_files = {path.relative_to(bundle_root) for path in bundle_root.rglob("*") if path.is_file()}
    if actual_files != declared_files:
        raise ProviderError("bundle has extra, missing, or ambiguous files")
    return found


def _source_json(sources: dict[tuple[str | None, str], bytes | None], lane: str, kind: str, *, required: bool) -> dict[str, Any] | None:
    identity = (lane, kind)
    if identity not in sources:
        raise ProviderError(f"missing declared {kind} source")
    data = sources[identity]
    if data is None:
        if required:
            raise ProviderError(f"missing essential {kind} metadata")
        return None
    return _json_bytes(data, f"{lane}/{kind}")


def _pid(value: Any, label: str, *, nullable: bool = True) -> int | None:
    pid = _integer(value, label, nullable=nullable, positive=value is not None)
    return pid


def _validate_raw_records(lane: str, sources: dict[tuple[str | None, str], bytes | None], captured: PreciseTime) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any], dict[str, Any] | None, dict[str, Any] | None]:
    lease = _keys(_source_json(sources, lane, "lease", required=True), _LEASE_KEYS, _LEASE_KEYS, "lease")
    job = _keys(_source_json(sources, lane, "job", required=True), _JOB_KEYS, _JOB_KEYS, "job")
    state = _keys(_source_json(sources, lane, "state", required=True), _STATE_KEYS, {"job_id", "state"}, "state")
    heartbeat_raw = _source_json(sources, lane, "heartbeat", required=False)
    result_raw = _source_json(sources, lane, "result", required=False)
    heartbeat = None if heartbeat_raw is None else _keys(heartbeat_raw, _HEARTBEAT_KEYS, {"job_id", "state", "updated_utc"}, "heartbeat")
    result = None if result_raw is None else _keys(result_raw, _RESULT_KEYS, _RESULT_KEYS, "result")

    lease_lane = _safe_id(lease["lane_id"], "lease lane_id")
    lease_job = _safe_id(lease["job_id"], "lease job_id", job=True)
    if lease_lane != lane:
        raise ProviderError("mismatched lane ID")
    if not isinstance(lease["base_sha"], str) or _SHA_RE.fullmatch(lease["base_sha"]) is None:
        raise ProviderError("invalid lease base")
    lease_created = _parse_time(lease["created_utc"], "lease created")
    if lease_created.ticks_100ns > captured.ticks_100ns:
        raise ProviderError("lease timestamp is in the future")
    # Installed leases carry operational paths. Validate only their scalar type; never resolve,
    # open, or use them. All source locations are derived from the explicit trusted roots.
    for name in ("job_root", "status_script", "runner_root", "requested_file", "launch_file", "worktree", "stage"):
        _string(lease[name], f"lease {name}")
    for label, record in (("job", job), ("state", state), ("heartbeat", heartbeat), ("result", result)):
        if record is not None and record.get("job_id") != lease_job:
            raise ProviderError(f"mismatched {label} ID")
    if job["base_sha"] != lease["base_sha"]:
        raise ProviderError("mismatched job base")
    for name in ("arg_count", "timeout_sec", "heartbeat_sec", "postcondition_arg_count"):
        value = _integer(job[name], f"job {name}")
        if value is None or value < 0:
            raise ProviderError(f"invalid job {name}")
    for name in ("file_path", "arg_hash", "worktree", "stage", "postcondition_file_path", "postcondition_arg_hash"):
        _string(job[name], f"job {name}")
    created = _parse_time(job["created_utc"], "job created")
    if created.ticks_100ns > captured.ticks_100ns + 3_000_000_000:
        raise ProviderError("job timestamp is in the future")
    state_name = state["state"]
    if state_name not in _ALL_STATES:
        raise ProviderError("invalid durable state")
    if state_name == "CANCEL_REQUESTED":
        raise ProviderError("unsupported ambiguous active state")
    for role in _ROLES:
        pid_name = f"{role}_pid"
        start_name = f"{role}_start_utc"
        if pid_name in state:
            _pid(state[pid_name], f"state {pid_name}")
        if start_name in state and state[start_name] is not None:
            start = _parse_time(state[start_name], f"state {start_name}")
            if start.ticks_100ns < created.ticks_100ns or start.ticks_100ns > captured.ticks_100ns + 3_000_000_000:
                raise ProviderError("process start chronology or future conflict")
    if heartbeat is not None:
        if heartbeat["state"] not in _ALL_STATES:
            raise ProviderError("invalid heartbeat state")
        updated = _parse_time(heartbeat["updated_utc"], "heartbeat updated")
        if updated.ticks_100ns < created.ticks_100ns or updated.ticks_100ns > captured.ticks_100ns + 3_000_000_000:
            raise ProviderError("heartbeat chronology or future conflict")
    if state_name in _ACTIVE:
        if result is not None:
            raise ProviderError("active state has a terminal result")
        if "ended_utc" in state and state["ended_utc"] is not None:
            raise ProviderError("active state has an end time")
    else:
        if result is None:
            raise ProviderError("terminal state lacks historical result")
        if result["state"] != state_name:
            raise ProviderError("terminal state/result conflict")
        ended = _parse_time(result["ended_utc"], "result ended")
        if ended.ticks_100ns < created.ticks_100ns or ended.ticks_100ns > captured.ticks_100ns:
            raise ProviderError("result chronology or future conflict")
        if "ended_utc" in state and state["ended_utc"] is not None:
            state_ended = _parse_time(state["ended_utc"], "state ended")
            if state_ended.ticks_100ns != ended.ticks_100ns:
                raise ProviderError("state/result end chronology conflict")
        exit_code = _integer(result["exit_code"], "result exit", nullable=True)
        post_exit = _integer(result["postcondition_exit_code"], "result postcondition exit", nullable=True)
        if not isinstance(result["reason"], str):
            raise ProviderError("invalid result reason type")
        if "reason" in state and not isinstance(state["reason"], str):
            raise ProviderError("invalid state reason type")
        for role in ("runner", "child"):
            result_pid = _pid(result[f"{role}_pid"], f"result {role}_pid")
            if result_pid != state.get(f"{role}_pid"):
                raise ProviderError("state/result PID conflict")
        if "exit_code" in state and state["exit_code"] != result["exit_code"]:
            raise ProviderError("state/result exit conflict")
        if "postcondition_exit_code" in state and state["postcondition_exit_code"] != result["postcondition_exit_code"]:
            raise ProviderError("state/result postcondition conflict")
        if state_name == "COMPLETE" and (exit_code != 0 or (job["postcondition_file_path"] and post_exit != 0)):
            raise ProviderError("complete result contradiction")
        if state_name == "FAILED" and exit_code == 0:
            raise ProviderError("failed result contradiction")
        if state_name == "POSTCONDITION_FAILED" and (exit_code != 0 or post_exit in (None, 0)):
            raise ProviderError("postcondition result contradiction")
    return lease, job, state, heartbeat, result


def _validated_checks(lane: str, job_id: str, state: dict[str, Any], job: dict[str, Any], checks: list[Any], captured: PreciseTime) -> tuple[dict[str, dict[str, Any]], PreciseTime]:
    selected: dict[str, dict[str, Any]] = {}
    latest = PreciseTime(0)
    for index, raw in enumerate(checks):
        check = _keys(raw, _CHECK_KEYS, _CHECK_KEYS, f"process_check[{index}]")
        if check["lane_id"] != lane:
            continue
        if check["job_id"] != job_id:
            raise ProviderError("mismatched process-check job ID")
        role = check["role"]
        if role not in _ROLES or role in selected:
            raise ProviderError("duplicate or invalid process role")
        pid = _pid(check["pid"], "process-check pid")
        expected = check["expected_creation_utc"]
        current = check["current_creation_utc"]
        identity = check["identity"]
        query = check["query_status"]
        if identity not in _IDENTITIES or query not in _QUERY:
            raise ProviderError("invalid process identity classification")
        checked = _parse_time(check["checked_utc"], "process checked")
        if checked.ticks_100ns > captured.ticks_100ns:
            raise ProviderError("process check follows the capture envelope")
        latest = checked if checked.ticks_100ns > latest.ticks_100ns else latest
        state_pid = state.get(f"{role}_pid")
        state_expected = state.get(f"{role}_start_utc")
        if pid != state_pid or expected != state_expected:
            if not (role == "postcondition" and pid is None and state_pid is None and expected is None and state_expected is None):
                raise ProviderError("process-check/state identity mismatch")
        if pid is None:
            not_configured = role == "postcondition" and job["postcondition_file_path"] == ""
            if not not_configured or identity != "RECORDED_PROCESS_NOT_PRESENT" or query != "NOT_CONFIGURED" or current is not None:
                raise ProviderError("missing essential process or postcondition metadata")
        else:
            expected_time = _parse_time(expected, "expected creation")
            if expected_time.ticks_100ns > checked.ticks_100ns:
                raise ProviderError("expected process creation is in the future")
            if identity == "UNKNOWN" or query in {"INACCESSIBLE", "ERROR"}:
                raise ProviderError("unknown process identity")
            if identity == "RECORDED_PROCESS_NOT_PRESENT":
                if query != "NOT_PRESENT" or current is not None:
                    raise ProviderError("invalid not-present process evidence")
            else:
                if query != "PRESENT" or current is None:
                    raise ProviderError("invalid present process evidence")
                current_time = _parse_time(current, "current creation")
                if current_time.ticks_100ns > checked.ticks_100ns:
                    raise ProviderError("current process creation is in the future")
                equal = current_time.ticks_100ns == expected_time.ticks_100ns
                if identity == "MATCHING_RECORDED_PROCESS" and not equal:
                    raise ProviderError("matching identity has different creation time")
                if identity == "DIFFERENT_CREATION_IDENTITY" and equal:
                    raise ProviderError("different identity has matching creation time")
        selected[role] = check
    if set(selected) != set(_ROLES):
        raise ProviderError("missing process role coverage")
    return selected, latest


def _alive(check: dict[str, Any]) -> bool | None:
    identity = check["identity"]
    if identity == "MATCHING_RECORDED_PROCESS":
        return True
    if identity in {"RECORDED_PROCESS_NOT_PRESENT", "DIFFERENT_CREATION_IDENTITY"}:
        return False
    return None


def _public_result(state_name: str, job: dict[str, Any], result: dict[str, Any] | None) -> dict[str, Any]:
    if result is None:
        return {"state": "UNKNOWN", "exit": None, "postcondition": "RUNNING" if state_name == "POSTCONDITION_RUNNING" else "UNKNOWN", "ended": None}
    post_exit = result["postcondition_exit_code"]
    if job["postcondition_file_path"] == "":
        postcondition = "NOT_CONFIGURED"
    elif post_exit == 0:
        postcondition = "PASSED"
    elif post_exit is None:
        postcondition = "UNKNOWN"
    else:
        postcondition = "FAILED"
    return {
        "state": result["state"],
        "exit": result["exit_code"],
        "postcondition": postcondition,
        "ended": _parse_time(result["ended_utc"], "result ended").whole_second_utc(),
    }


def _row(lane: str, lease: dict[str, Any], job: dict[str, Any], state: dict[str, Any], heartbeat: dict[str, Any] | None, result: dict[str, Any] | None, checks: dict[str, dict[str, Any]], checked: PreciseTime) -> tuple[dict[str, Any], dict[str, Any]]:
    alive = {role: _alive(checks[role]) for role in _ROLES}
    if any(value is None for value in alive.values()):
        raise ProviderError("unknown process identity")
    state_name = state["state"]
    if state_name in _TERMINAL and (alive["child"] is True or alive["postcondition"] is True):
        raise ProviderError("terminal child or postcondition is still the recorded live process")
    if state_name == "RUNNING":
        if alive["runner"] and alive["child"]:
            observed = "RUNNING"
        elif not alive["runner"]:
            observed = "LOST_PROCESS"
        else:
            raise ProviderError("ambiguous RUNNING state: live runner with missing child")
    elif state_name == "STARTING":
        if state.get("child_pid") is None:
            raise ProviderError("unsupported STARTING state with incomplete child identity")
        observed = "STARTING" if alive["runner"] else "LOST_PROCESS"
    elif state_name == "POSTCONDITION_RUNNING":
        if alive["postcondition"]:
            observed = "POSTCONDITION_RUNNING"
        elif not alive["runner"]:
            observed = "LOST_PROCESS"
        else:
            raise ProviderError("ambiguous active postcondition state")
    else:
        observed = state_name
    if result is not None:
        ended = _parse_time(result["ended_utc"], "result ended")
        if ended.ticks_100ns > checked.ticks_100ns:
            raise ProviderError("result ends after process observation")
    heartbeat_age: float | None = None
    if heartbeat is not None:
        heartbeat_time = _parse_time(heartbeat["updated_utc"], "heartbeat updated")
        delta = checked.ticks_100ns - heartbeat_time.ticks_100ns
        if delta < -3_000_000_000:
            raise ProviderError("heartbeat is in the future")
        heartbeat_age = max(0, delta) / 10_000_000
        if not math.isfinite(heartbeat_age) or heartbeat_age > _MAX_SAFE_INTEGER:
            raise ProviderError("invalid heartbeat age")
    row = {
        "lane_id": lane,
        "job_id": lease["job_id"],
        "checked_utc": checked.whole_second_utc(),
        "observed_state": observed,
        "durable_state": state_name,
        "runner_alive": alive["runner"],
        "child_alive": alive["child"],
        "postcondition_alive": alive["postcondition"],
        "heartbeat_age_sec": heartbeat_age,
        "retry_decision": "REFUSE_RETRY" if state_name in _TERMINAL else "UNKNOWN",
        "result": _public_result(state_name, job, result),
    }
    private = {
        "lane_id": lane,
        "job_id": lease["job_id"],
        "base_sha": lease["base_sha"],
        "checked_utc_precise": max(check["checked_utc"] for check in checks.values()),
        "roles": [checks[role] for role in _ROLES],
    }
    return row, private


def _prepare_output(manifest_path: Path, output_root: Path) -> tuple[Path, Path]:
    if not manifest_path.is_absolute() or not output_root.is_absolute():
        raise ProviderError("manifest and output paths must be absolute")
    bundle_root = manifest_path.parent
    _assert_no_reparse(manifest_path, "manifest path")
    if not manifest_path.is_file() or manifest_path.name != "manifest.json":
        raise ProviderError("manifest path is not the bundle manifest")
    _assert_single_link(manifest_path, "manifest")
    if output_root.exists():
        raise ProviderError("output root must be fresh")
    if _overlap(output_root, bundle_root):
        raise ProviderError("output and bundle roots overlap")
    _assert_no_reparse(output_root.parent, "output parent")
    return bundle_root, output_root


def adapt_bundle(manifest_path: Path, output_root: Path) -> tuple[dict[str, Any], dict[str, Any]]:
    """Validate a frozen bundle and exclusively publish a V0 DTO plus private receipt."""
    manifest_path = Path(manifest_path)
    output_root = Path(output_root)
    bundle_root, output_root = _prepare_output(manifest_path, output_root)
    manifest_bytes = manifest_path.read_bytes()
    manifest = _keys(_json_bytes(manifest_bytes, "manifest"), _MANIFEST_KEYS, _MANIFEST_KEYS, "manifest")
    if manifest["schema_version"] != CAPTURE_SCHEMA:
        raise ProviderError("invalid capture schema")
    if manifest["status"] != "AVAILABLE":
        raise ProviderError("capture bundle is unavailable")
    captured = _parse_time(manifest["captured_at_utc"], "capture")
    expected_head = manifest["expected_head"]
    if not isinstance(expected_head, str) or _SHA_RE.fullmatch(expected_head) is None:
        raise ProviderError("invalid expected head")
    canonical_observed_sha = manifest["canonical_observed_sha"]
    if not isinstance(canonical_observed_sha, str) or _SHA_RE.fullmatch(canonical_observed_sha) is None:
        raise ProviderError("invalid canonical observed head")
    for root_name in ("repo_root", "lease_root", "jobs_root"):
        raw_root = manifest[root_name]
        if not isinstance(raw_root, str) or not Path(raw_root).is_absolute():
            raise ProviderError(f"invalid {root_name}")
        _assert_no_reparse(Path(raw_root), root_name)
        if _overlap(output_root, Path(raw_root)):
            raise ProviderError("output root overlaps a source root")
        if _overlap(bundle_root, Path(raw_root)):
            raise ProviderError("private bundle overlaps a source root")
    lanes = manifest["requested_lane_ids"]
    if not isinstance(lanes, list):
        raise ProviderError("requested lane IDs must be a list")
    safe_lanes = [_safe_id(value, "lane_id") for value in lanes]
    if len(set(safe_lanes)) != len(safe_lanes):
        raise ProviderError("duplicate requested lane ID")
    if not isinstance(manifest["process_checks"], list):
        raise ProviderError("process checks must be a list")
    sources = _validate_source_records(manifest, bundle_root, captured)
    helper = sources.get((None, "helper"))
    if helper is None or b"Get-LjrProcessSnapshot" not in helper:
        raise ProviderError("canonical process helper source is missing")
    expected_source_identities = {(None, "helper")} | {(lane, kind) for lane in safe_lanes for kind in _KINDS}
    if set(sources) != expected_source_identities:
        raise ProviderError("missing or extra lane source coverage")

    rows = []
    private_rows = []
    used_checks = 0
    for lane in safe_lanes:
        lease, job, state, heartbeat, result = _validate_raw_records(lane, sources, captured)
        checks, checked = _validated_checks(lane, lease["job_id"], state, job, manifest["process_checks"], captured)
        used_checks += len(checks)
        row, private = _row(lane, lease, job, state, heartbeat, result, checks, checked)
        rows.append(row)
        private_rows.append(private)
    if used_checks != len(manifest["process_checks"]):
        raise ProviderError("extra or unbound process checks")

    dto = {
        "schema_version": PUBLIC_SCHEMA,
        "source_kind": SOURCE_KIND,
        "observed_at_utc": captured.whole_second_utc(),
        "canonical_observed_sha": canonical_observed_sha,
        "observations": sorted(rows, key=lambda item: (item["lane_id"], item["job_id"])),
    }
    public_bytes = _canonical_bytes(dto)
    source_receipts = [
        {"lane_id": source["lane_id"], "kind": source["kind"], "presence": source["presence"], "sha256": source["sha256"], "length": source["length"]}
        for source in manifest["sources"]
    ]
    private_receipt = {
        "schema_version": PRIVATE_SCHEMA,
        "status": "SOURCE_VALIDATED_PENDING_INDEPENDENT_REVIEW",
        "capture_manifest_sha256": _sha256(manifest_bytes),
        "expected_head": expected_head,
        "candidate_source_head": expected_head,
        "canonical_observed_sha": canonical_observed_sha,
        "captured_at_utc_precise": manifest["captured_at_utc"],
        "requested_lane_ids": safe_lanes,
        "source_receipts": source_receipts,
        "process_identity_evidence": private_rows,
        "public_output_sha256": _sha256(public_bytes),
        "public_output": dto,
        "runtime_activation": False,
    }
    private_bytes = _canonical_bytes(private_receipt)
    final_receipt = {
        "schema_version": PUBLICATION_SCHEMA,
        "status": "COMPLETE",
        "capture_manifest_sha256": _sha256(manifest_bytes),
        "public_output_sha256": _sha256(public_bytes),
        "private_receipt_sha256": _sha256(private_bytes),
        "runtime_activation": False,
    }
    output_root.mkdir()
    incomplete = output_root / "INCOMPLETE.json"
    _write_exclusive(incomplete, _canonical_bytes({"schema_version": PUBLICATION_SCHEMA, "status": "INCOMPLETE"}))
    _write_exclusive(output_root / "job_observations.json", public_bytes)
    _write_exclusive(output_root / "private_provenance_receipt.json", private_bytes)
    _write_exclusive(output_root / "publication_receipt.json", _canonical_bytes(final_receipt))
    incomplete.unlink()
    return dto, private_receipt


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle-manifest", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    args = parser.parse_args(argv)
    try:
        dto, receipt = adapt_bundle(args.bundle_manifest, args.output_root)
    except ProviderError as error:
        print(json.dumps({"status": "UNAVAILABLE", "reason": str(error)}, sort_keys=True))
        return 2
    print(json.dumps({
        "status": "AVAILABLE",
        "rows": len(dto["observations"]),
        "public_output_sha256": receipt["public_output_sha256"],
        "runtime_activation": False,
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
