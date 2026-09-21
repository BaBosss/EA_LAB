#!/usr/bin/env python3
"""Collect one deterministic, local-first Control Tower observation packet."""
from __future__ import annotations

import argparse
import dataclasses
import datetime as dt
import hashlib
import json
import os
import re
import sqlite3
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path, PurePosixPath
from typing import Any, Iterable, NoReturn


SCHEMA_VERSION = "EA_LAB_LOCAL_CONTROL_COLLECTOR_V1"
SNAPSHOT_SCHEMA_VERSION = "EA_LAB_LOCAL_CONTROL_SNAPSHOT_V1"
SCHEMA_PATH = Path(__file__).with_name("packet.schema.json")
TRUTH_NOTE = (
    "tokens_used is a local lifetime thread counter only. Snapshot differences are "
    "observed counter deltas, never billing, quota, credits, plan allowance, cost, or savings."
)
SHA_RE = re.compile(r"[0-9a-f]{40}")
SAFE_ID_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}")
SENSITIVE_RE = re.compile(
    r"(?i)(token|secret|password|passwd|credential|api[_-]?key|account|login)\s*[:=]\s*[^\s,;]+"
)
ABS_PATH_RE = re.compile(r"(?i)(?:[A-Z]:\\[^\s]+|/(?:home|users|root)/[^\s]+)")
ACTIVE_STATES = {"READY", "RUNNING", "REVIEW", "FROZEN", "INTEGRATING"}


class Refusal(ValueError):
    """Fail-closed input or contract refusal."""


def refuse(message: str) -> NoReturn:
    raise Refusal(message)


@dataclasses.dataclass(frozen=True)
class Identity:
    lane_id: str
    milestone: str | None
    role: str | None


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True, ensure_ascii=True, allow_nan=False) + "\n").encode("utf-8")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def safe_label(value: Any, limit: int = 96) -> str:
    if not isinstance(value, str) or not value.strip():
        return "UNKNOWN"
    line = value.replace("\r", " ").replace("\n", " ").strip()
    line = SENSITIVE_RE.sub(r"\1=<REDACTED>", line)
    line = ABS_PATH_RE.sub("<PATH>", line)
    line = " ".join(line.split())
    return line[:limit] or "UNKNOWN"


def safe_id(value: Any) -> str:
    return value if isinstance(value, str) and SAFE_ID_RE.fullmatch(value) else "UNKNOWN"


def parse_time(value: str) -> dt.datetime:
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except (TypeError, ValueError):
        refuse("--as-of must be an ISO-8601 timestamp with timezone")
    if parsed.tzinfo is None:
        refuse("--as-of must include a timezone")
    return parsed.astimezone(dt.timezone.utc)


def normalized_time(value: str) -> str:
    return parse_time(value).isoformat(timespec="seconds").replace("+00:00", "Z")


def run(command: list[str], cwd: Path | None = None, timeout: int = 30) -> tuple[int, str, str]:
    try:
        result = subprocess.run(command, cwd=cwd, capture_output=True, text=True, timeout=timeout, check=False)
        return result.returncode, result.stdout.strip(), result.stderr.strip()
    except (OSError, subprocess.TimeoutExpired) as exc:
        return 127, "", safe_label(str(exc))


def git_text(repo: Path, *args: str) -> tuple[bool, str]:
    code, out, _ = run(["git", "--no-optional-locks", "-C", str(repo), *args])
    return code == 0, out


def collect_git(repo: Path, remote_observe: bool, fetch: bool) -> dict[str, Any]:
    result = {
        "status": "UNAVAILABLE",
        "fetch": "NOT_REQUESTED",
        "head": "UNKNOWN",
        "origin_master": "UNKNOWN",
        "ls_remote_master": "UNKNOWN",
        "clean": None,
        "ancestry": "UNKNOWN",
        "changed_paths": [],
        "overlap": [],
    }
    ok, inside = git_text(repo, "rev-parse", "--is-inside-work-tree")
    if not ok or inside != "true":
        return result
    if fetch:
        code, _, _ = run(["git", "--no-optional-locks", "-C", str(repo), "fetch", "origin", "master"])
        result["fetch"] = "SUCCEEDED" if code == 0 else "UNAVAILABLE"
        remote_observe = True
    ok, head = git_text(repo, "rev-parse", "HEAD")
    if ok and SHA_RE.fullmatch(head):
        result["head"] = head
    ok, origin = git_text(repo, "rev-parse", "refs/remotes/origin/master")
    if ok and SHA_RE.fullmatch(origin):
        result["origin_master"] = origin
    ok, porcelain = git_text(repo, "status", "--porcelain=v1", "--untracked-files=all")
    if ok:
        paths: list[str] = []
        for line in porcelain.splitlines():
            raw = line[3:] if len(line) >= 4 else ""
            if " -> " in raw:
                raw = raw.split(" -> ", 1)[1]
            paths.append(raw.replace("\\", "/").strip('"'))
        result["changed_paths"] = sorted(set(filter(None, paths)))
        result["clean"] = not bool(paths)
    if result["head"] != "UNKNOWN" and result["origin_master"] != "UNKNOWN":
        code, _, _ = run(["git", "--no-optional-locks", "-C", str(repo), "merge-base", "--is-ancestor", result["head"], result["origin_master"]])
        if code == 0:
            result["ancestry"] = "HEAD_ANCESTOR_OF_ORIGIN_MASTER"
        else:
            reverse, _, _ = run(["git", "--no-optional-locks", "-C", str(repo), "merge-base", "--is-ancestor", result["origin_master"], result["head"]])
            result["ancestry"] = "ORIGIN_MASTER_ANCESTOR_OF_HEAD" if reverse == 0 else "DIVERGED_OR_UNKNOWN"
    if remote_observe:
        code, out, _ = run(["git", "--no-optional-locks", "-C", str(repo), "ls-remote", "origin", "refs/heads/master"])
        parts = out.split()
        if code == 0 and parts and SHA_RE.fullmatch(parts[0]):
            result["ls_remote_master"] = parts[0]
    result["status"] = "AVAILABLE" if result["head"] != "UNKNOWN" else "UNAVAILABLE"
    return result


def normalize_scope_path(value: str) -> tuple[str, ...]:
    raw = value.replace("\\", "/").strip("/")
    while raw.endswith("/**") or raw.endswith("/*"):
        raw = raw.rsplit("/", 1)[0]
    parts = tuple(part for part in PurePosixPath(raw).parts if part not in ("", "."))
    return parts


def paths_overlap(left: str, right: str) -> bool:
    a, b = normalize_scope_path(left), normalize_scope_path(right)
    if not a or not b or ".." in a or ".." in b:
        return False
    return a == b[: len(a)] or b == a[: len(b)]


REGISTRY_REQUIRED = {
    "lane_id", "state", "writer", "owner_chat", "classification", "head_sha", "reviewed_head",
    "blocker_class", "updated_at", "worktree", "allowed_paths", "critical_paths",
}


def parse_registry(raw: Any) -> dict[str, Any]:
    unavailable = {"status": "UNAVAILABLE", "records": [], "conflicts": [], "reason": "MALFORMED_OR_UNAVAILABLE"}
    if not isinstance(raw, dict) or raw.get("result") != "AUDIT" or not isinstance(raw.get("records"), list):
        return unavailable
    rows = []
    for item in raw["records"]:
        if not isinstance(item, dict) or not REGISTRY_REQUIRED.issubset(item):
            return unavailable
        lane_id = safe_id(item["lane_id"])
        if lane_id == "UNKNOWN" or not isinstance(item["writer"], bool):
            return unavailable
        allowed = item["allowed_paths"]
        critical = item["critical_paths"]
        if not isinstance(allowed, list) or not isinstance(critical, list) or not all(isinstance(x, str) for x in allowed + critical):
            return unavailable
        scopes = allowed + critical
        if any(re.match(r"(?i)^[A-Z]:[/\\]", scope) or scope.startswith(("/", "\\"))
               or ".." in PurePosixPath(scope.replace("\\", "/")).parts for scope in scopes):
            return unavailable
        rows.append({
            "lane_id": lane_id,
            "state": safe_label(item["state"], 40),
            "role": "WRITER" if item["writer"] else "READ_ONLY",
            "owner_chat": safe_label(item["owner_chat"], 80),
            "head": item["head_sha"] if isinstance(item["head_sha"], str) and SHA_RE.fullmatch(item["head_sha"]) else "UNKNOWN",
            "reviewed_head": item["reviewed_head"] if isinstance(item["reviewed_head"], str) and SHA_RE.fullmatch(item["reviewed_head"]) else "UNKNOWN",
            "blocker_class": safe_label(item["blocker_class"], 80),
            "updated_at": safe_label(item["updated_at"], 40),
            "worktree": Path(str(item["worktree"])).name or "UNKNOWN",
            "classification": safe_label(item["classification"], 60),
            "allowed_paths": sorted(allowed),
            "critical_paths": sorted(critical),
        })
    return {"status": "AVAILABLE", "records": sorted(rows, key=lambda x: x["lane_id"]), "conflicts": [], "reason": "NONE"}


def collect_registry(repo: Path, registry_root: Path, skip: bool) -> dict[str, Any]:
    if skip:
        return {"status": "UNAVAILABLE", "records": [], "conflicts": [], "reason": "NOT_REQUESTED"}
    script = repo / "scripts" / "lane_registry.ps1"
    code, out, err = run([
        "powershell", "-NoProfile", "-File", str(script), "-Command", "Audit",
        "-RegistryRoot", str(registry_root), "-RepoRoot", str(repo), "-Json",
    ], timeout=60)
    if code != 0:
        return {"status": "UNAVAILABLE", "records": [], "conflicts": [], "reason": safe_label(err, 160)}
    try:
        audit = json.loads(out)
    except (json.JSONDecodeError, ValueError):
        return {"status": "UNAVAILABLE", "records": [], "conflicts": [], "reason": "MALFORMED_OR_UNAVAILABLE"}
    if not isinstance(audit, dict) or not isinstance(audit.get("records"), list):
        return {"status": "UNAVAILABLE", "records": [], "conflicts": [], "reason": "MALFORMED_OR_UNAVAILABLE"}
    enriched = []
    for audit_row in audit["records"]:
        lane_id = audit_row.get("lane_id") if isinstance(audit_row, dict) else None
        if safe_id(lane_id) == "UNKNOWN":
            return {"status": "UNAVAILABLE", "records": [], "conflicts": [], "reason": "MALFORMED_OR_UNAVAILABLE"}
        get_code, get_out, get_err = run([
            "powershell", "-NoProfile", "-File", str(script), "-Command", "Get",
            "-RegistryRoot", str(registry_root), "-LaneId", lane_id, "-Json",
        ], timeout=30)
        if get_code != 0:
            return {"status": "UNAVAILABLE", "records": [], "conflicts": [], "reason": safe_label(get_err, 160)}
        record = json_object(get_out)
        if record is None:
            return {"status": "UNAVAILABLE", "records": [], "conflicts": [], "reason": "MALFORMED_OR_UNAVAILABLE"}
        record["classification"] = audit_row.get("classification")
        enriched.append(record)
    return parse_registry({"result": "AUDIT", "records": enriched})


def add_overlap(git: dict[str, Any], registry: dict[str, Any], current_lane: str | None) -> None:
    conflicts = []
    for changed in git["changed_paths"]:
        for lane in registry["records"]:
            if lane["lane_id"] == current_lane or lane["state"] not in ACTIVE_STATES:
                continue
            allowed = sorted(scope for scope in lane["allowed_paths"] if paths_overlap(changed, scope))
            critical = sorted(scope for scope in lane["critical_paths"] if paths_overlap(changed, scope))
            if allowed or critical:
                conflicts.append({"changed_path": changed, "lane_id": lane["lane_id"],
                                  "allowed_paths": allowed, "critical_paths": critical,
                                  "classification": "CRITICAL" if critical else "ALLOWED"})
    git["overlap"] = conflicts
    registry["conflicts"] = conflicts


def json_object(text: str) -> dict[str, Any] | None:
    try:
        value = json.loads(text)
        return value if isinstance(value, dict) else None
    except (json.JSONDecodeError, TypeError):
        return None


def parse_job_outputs(lane_id: str, job_id: str, status_text: str, retry_text: str,
                      lease: dict[str, Any] | None, job_record: dict[str, Any] | None,
                      heartbeat_age_sec: float | None = None, result_state: str = "UNKNOWN") -> dict[str, Any]:
    unavailable = {"status": "UNAVAILABLE", "lane_id": safe_id(lane_id), "job_id": safe_id(job_id),
                   "durable_state": "UNKNOWN", "result": "UNKNOWN", "runner_alive": None,
                   "child_alive": None, "postcondition_alive": None, "heartbeat_age_sec": None,
                   "retry_decision": "UNKNOWN", "lease_identity": "UNKNOWN", "job_identity": "UNKNOWN"}
    status, retry = json_object(status_text), json_object(retry_text)
    status_keys = {"job_id", "state", "runner_alive", "child_alive", "postcondition_alive"}
    retry_keys = {"job_id", "state", "runner_alive", "child_alive", "postcondition_alive", "retry_decision", "reason"}
    if not status or not retry or not status_keys.issubset(status) or not retry_keys.issubset(retry):
        return unavailable
    if status["job_id"] != job_id or retry["job_id"] != job_id:
        return unavailable
    alive = [status[name] for name in ("runner_alive", "child_alive", "postcondition_alive")]
    if not all(isinstance(value, bool) for value in alive):
        return unavailable
    row = dict(unavailable)
    row.update({
        "status": "AVAILABLE",
        "durable_state": safe_label(status["state"], 40),
        "result": safe_label(result_state, 80),
        "runner_alive": alive[0],
        "child_alive": alive[1],
        "postcondition_alive": alive[2],
        "heartbeat_age_sec": heartbeat_age_sec,
        "retry_decision": retry["retry_decision"] if retry["retry_decision"] in {"ALLOW_RETRY", "REFUSE_RETRY"} else "UNKNOWN",
    })
    if isinstance(lease, dict) and lease.get("job_id") == job_id:
        row["lease_identity"] = sha256_bytes(canonical_bytes(lease))
    if isinstance(job_record, dict) and job_record.get("job_id") == job_id:
        row["job_identity"] = sha256_bytes(canonical_bytes(job_record))
    return row


def load_optional_json(path: Path) -> dict[str, Any] | None:
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
        return value if isinstance(value, dict) else None
    except (OSError, json.JSONDecodeError, UnicodeError):
        return None


def collect_jobs(repo: Path, jobs_root: Path, lease_root: Path, requests: list[tuple[str, str]], as_of: str | None = None) -> list[dict[str, Any]]:
    rows = []
    for lane_id, job_id in sorted(set(requests)):
        status_code, status_out, _ = run(["powershell", "-NoProfile", "-File", str(repo / "scripts/long_jobs/status_long_job.ps1"), "-JobId", job_id, "-JobsRoot", str(jobs_root), "-Json"])
        retry_code, retry_out, _ = run(["powershell", "-NoProfile", "-File", str(repo / "scripts/execution_reliability/inspect_before_retry.ps1"), "-JobId", job_id, "-JobsRoot", str(jobs_root), "-Json"])
        lease = load_optional_json(lease_root / f"{lane_id}.json")
        job_record = load_optional_json(jobs_root / job_id / "job.json")
        heartbeat = load_optional_json(jobs_root / job_id / "heartbeat.json")
        result = load_optional_json(jobs_root / job_id / "result.json")
        heartbeat_age: float | None = None
        if heartbeat and isinstance(heartbeat.get("updated_utc"), str):
            try:
                observed = parse_time(as_of) if as_of else dt.datetime.now(dt.timezone.utc)
                age = (observed - parse_time(heartbeat["updated_utc"])).total_seconds()
                heartbeat_age = max(0, round(age, 3))
            except Refusal:
                heartbeat_age = None
        if status_code != 0 or retry_code != 0:
            status_out, retry_out = "", ""
        rows.append(parse_job_outputs(lane_id, job_id, status_out, retry_out, lease, job_record,
                                      heartbeat_age, str((result or {}).get("state", "UNKNOWN"))))
    return rows


EVIDENCE_KEYS = {"schema_version", "verdict", "confidence", "decision", "findings", "reviewed_head"}
EVIDENCE_SCHEMAS = {"EA_LAB_REVIEW_RESULT_V1", "EA_LAB_SCRUTINY_RESULT_V1"}


def parse_evidence(path: Path) -> dict[str, Any]:
    unknown = {"status": "UNKNOWN", "contract": "UNKNOWN", "verdict": "UNKNOWN", "confidence": "UNKNOWN",
               "decision": "UNKNOWN", "findings": [], "reviewed_head": "UNKNOWN", "sha256": "UNKNOWN",
               "source": safe_label(path.name, 96)}
    try:
        raw = path.read_bytes()
        value = json.loads(raw.decode("utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError):
        return unknown
    if not isinstance(value, dict) or set(value) != EVIDENCE_KEYS or value.get("schema_version") not in EVIDENCE_SCHEMAS:
        return unknown
    if not isinstance(value["findings"], list) or not all(isinstance(item, str) for item in value["findings"]):
        return unknown
    head = value["reviewed_head"]
    if not isinstance(head, str) or not SHA_RE.fullmatch(head):
        return unknown
    return {
        "status": "AVAILABLE", "contract": value["schema_version"], "verdict": safe_label(value["verdict"], 40),
        "confidence": safe_label(value["confidence"], 40), "decision": safe_label(value["decision"], 80),
        "findings": [safe_label(item, 160) for item in value["findings"][:50]], "reviewed_head": head,
        "sha256": sha256_bytes(raw), "source": safe_label(path.name, 96),
    }


def readonly_connection(path: Path) -> sqlite3.Connection:
    # mode=ro preserves WAL visibility while preventing database mutation.  Do not
    # use immutable=1 for live Codex databases: it can ignore committed WAL pages.
    uri = path.resolve().as_uri() + "?mode=ro"
    connection = sqlite3.connect(uri, uri=True)
    connection.row_factory = sqlite3.Row
    return connection


def db_columns(connection: sqlite3.Connection, table: str) -> set[str]:
    return {str(row[1]) for row in connection.execute(f'PRAGMA table_info("{table}")')}


def choose_identity(thread_id: str, mappings: dict[str, list[Identity]]) -> tuple[Identity | None, str]:
    choices = mappings.get(thread_id, [])
    unique = set(choices)
    if len(unique) == 1:
        return next(iter(unique)), "EXACT"
    return None, "AMBIGUOUS" if choices else "UNKNOWN"


def collect_one_codex_home(home: Path, mappings: dict[str, list[Identity]], prior: dict[str, int | None] | None) -> list[dict[str, Any]]:
    state_path, history_path = home / "state_5.sqlite", home / "thread_history_1.sqlite"
    state = readonly_connection(state_path)
    history: sqlite3.Connection | None = None
    try:
        history = readonly_connection(history_path)
        state_columns = db_columns(state, "threads")
        v2_state = {"thread_id", "updated_at_ms", "tokens_used", "model", "reasoning_effort", "parent_thread_id", "agent_role"}
        v3_state = {"id", "updated_at_ms", "tokens_used", "model", "reasoning_effort", "title", "source", "thread_source"}
        counts = Counter()
        if v3_state.issubset(state_columns) and {"thread_id", "turn_id"}.issubset(db_columns(history, "thread_turns")):
            for record in history.execute("SELECT thread_id,COUNT(*) FROM thread_turns GROUP BY thread_id"):
                counts[str(record[0])] = int(record[1])
            records = state.execute(
                "SELECT id AS thread_id,updated_at_ms,tokens_used,model,reasoning_effort,title,source,thread_source FROM threads"
            ).fetchall()
            layout = "V3"
        elif v2_state.issubset(state_columns) and {"thread_id", "item_type"}.issubset(db_columns(history, "thread_history")):
            for record in history.execute("SELECT thread_id,COUNT(*) FROM thread_history WHERE item_type='assistant' GROUP BY thread_id"):
                counts[str(record[0])] = int(record[1])
            records = state.execute(
                "SELECT thread_id,updated_at_ms,tokens_used,model,reasoning_effort,parent_thread_id,agent_role FROM threads"
            ).fetchall()
            layout = "V2"
        else:
            raise sqlite3.DatabaseError("recognized Codex schema unavailable")
    finally:
        state.close()
        if history is not None:
            history.close()
    output = []
    for row in records:
        thread_id, current = row["thread_id"], row["tokens_used"]
        if not isinstance(thread_id, str) or not thread_id or isinstance(current, bool) or (current is not None and (not isinstance(current, int) or current < 0)):
            continue
        previous = prior.get(thread_id) if prior is not None else None
        if current is None:
            delta, delta_status = None, "UNKNOWN"
        elif prior is None or thread_id not in prior:
            delta, delta_status = None, "INITIAL"
        elif previous is None:
            delta, delta_status = None, "UNKNOWN"
        elif current < previous:
            delta, delta_status = None, "COUNTER_DECREASED_UNKNOWN"
        else:
            delta, delta_status = current - previous, "DELTA_OK"
        exact_identity, mapping_status = choose_identity(thread_id, mappings)
        role = exact_identity.role if exact_identity and exact_identity.role in {"AUTHOR", "REVIEWER"} else "UNKNOWN"
        parent_thread_id = None
        if layout == "V2":
            parent_thread_id = row["parent_thread_id"] if isinstance(row["parent_thread_id"], str) and row["parent_thread_id"] else None
            database_label = None
        else:
            database_label = row["title"] if isinstance(row["title"], str) else None
            if row["thread_source"] == "subagent" and isinstance(row["source"], str):
                try:
                    source = json.loads(row["source"])
                    candidate = source["subagent"]["thread_spawn"]["parent_thread_id"]
                    if isinstance(candidate, str) and candidate:
                        parent_thread_id = candidate
                except (json.JSONDecodeError, KeyError, TypeError):
                    parent_thread_id = None
        label = (exact_identity.milestone if exact_identity and exact_identity.milestone
                 else exact_identity.lane_id if exact_identity else database_label or f"THREAD:{thread_id[:12]}")
        output.append({
            "thread_id": thread_id,
            "label": safe_label(label, 96),
            "model": safe_label(row["model"], 64),
            "reasoning_effort": safe_label(row["reasoning_effort"], 32),
            "current_lifetime_tokens": current,
            "previous_lifetime_tokens": previous,
            "delta_tokens": delta,
            "delta_status": delta_status,
            "updated_at_ms": row["updated_at_ms"] if isinstance(row["updated_at_ms"], int) and row["updated_at_ms"] >= 0 else None,
            "parent_thread_id": parent_thread_id,
            "identity": "CHILD" if parent_thread_id else "PARENT",
            "lane_id": exact_identity.lane_id if exact_identity else "UNKNOWN",
            "milestone": exact_identity.milestone if exact_identity and exact_identity.milestone else "UNKNOWN",
            "role": role,
            "mapping_status": mapping_status,
            "invocation_count": counts.get(thread_id, 0),
        })
    return output


def collect_codex_usage(homes: list[Path], as_of: str, mappings: dict[str, list[Identity]],
                        prior: dict[str, int | None] | None) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    unavailable = 0
    for home in homes:
        try:
            rows.extend(collect_one_codex_home(home, mappings, prior))
        except (OSError, sqlite3.Error, ValueError):
            unavailable += 1
    deduplicated: dict[str, dict[str, Any]] = {}
    duplicate_ids: set[str] = set()
    for row in rows:
        if row["thread_id"] in deduplicated:
            duplicate_ids.add(row["thread_id"])
        else:
            deduplicated[row["thread_id"]] = row
    for thread_id in duplicate_ids:
        deduplicated.pop(thread_id, None)
    final = sorted(deduplicated.values(), key=lambda row: row["thread_id"])
    status = "UNAVAILABLE" if not final and unavailable else "PARTIAL" if unavailable or duplicate_ids else "AVAILABLE"
    return {"status": status, "captured_at": normalized_time(as_of), "truth_note": TRUTH_NOTE, "threads": final,
            "unavailable_database_count": unavailable, "ambiguous_duplicate_thread_count": len(duplicate_ids)}


def aggregate_usage(rows: list[dict[str, Any]], thresholds: list[int], observed_at: str = "1970-01-01T00:00:00Z") -> dict[str, Any]:
    if len(thresholds) != 2 or any(type(x) is not int or x < 0 for x in thresholds) or thresholds[0] >= thresholds[1]:
        refuse("observation thresholds must be two increasing non-negative integers")
    valid = [row for row in rows if row["delta_status"] == "DELTA_OK" and isinstance(row["delta_tokens"], int)]
    total = sum(row["delta_tokens"] for row in valid)
    signal = "HIGH" if total >= thresholds[1] else "ELEVATED" if total >= thresholds[0] else "WITHIN_OBSERVATION"

    def grouped(field: str) -> list[dict[str, Any]]:
        values: defaultdict[str, int] = defaultdict(int)
        for row in valid:
            values[str(row[field])] += row["delta_tokens"]
        return [{field: key, "delta_tokens": values[key]} for key in sorted(values)]

    top = sorted(valid, key=lambda row: (-row["delta_tokens"], row["thread_id"]))[:10]
    return {
        "date": normalized_time(observed_at)[:10],
        "valid_delta_tokens": total,
        "valid_delta_thread_count": len(valid),
        "observed_thread_count": len(rows),
        "observed_invocation_count": sum(row["invocation_count"] for row in rows if isinstance(row["invocation_count"], int)),
        "observation_thresholds": thresholds,
        "observation_signal": signal,
        "by_lane": grouped("lane_id"),
        "by_milestone": grouped("milestone"),
        "by_model": grouped("model"),
        "by_reasoning_effort": grouped("reasoning_effort"),
        "by_role": grouped("role"),
        "top_delta_threads": [{"thread_id": row["thread_id"], "delta_tokens": row["delta_tokens"]} for row in top],
    }


def empty_packet(as_of: str) -> dict[str, Any]:
    return {
        "schema_version": SCHEMA_VERSION,
        "observed_at": normalized_time(as_of),
        "git": {"status": "UNAVAILABLE", "fetch": "NOT_REQUESTED", "head": "UNKNOWN", "origin_master": "UNKNOWN", "ls_remote_master": "UNKNOWN", "clean": None, "ancestry": "UNKNOWN", "changed_paths": [], "overlap": []},
        "registry": {"status": "UNAVAILABLE", "records": [], "conflicts": [], "reason": "NOT_REQUESTED"},
        "jobs": [],
        "evidence": [],
        "codex_usage": {"status": "UNAVAILABLE", "captured_at": normalized_time(as_of), "truth_note": TRUTH_NOTE, "threads": [], "unavailable_database_count": 0, "ambiguous_duplicate_thread_count": 0},
        "daily_aggregation": aggregate_usage([], [1_000_000, 3_000_000], as_of),
        "bindings": {"collector_sha256": sha256_bytes(Path(__file__).read_bytes()), "schema_sha256": sha256_bytes(SCHEMA_PATH.read_bytes()) if SCHEMA_PATH.exists() else "UNKNOWN"},
        "limitations": [],
        "runtime_mutation": False,
        "installation_actions": [],
    }


TOP_KEYS = {"schema_version", "observed_at", "git", "registry", "jobs", "evidence", "codex_usage", "daily_aggregation", "bindings", "limitations", "runtime_mutation", "installation_actions"}
SECTION_KEYS = {
    "git": {"status", "fetch", "head", "origin_master", "ls_remote_master", "clean", "ancestry", "changed_paths", "overlap"},
    "registry": {"status", "records", "conflicts", "reason"},
    "codex_usage": {"status", "captured_at", "truth_note", "threads", "unavailable_database_count", "ambiguous_duplicate_thread_count"},
    "daily_aggregation": {"date", "valid_delta_tokens", "valid_delta_thread_count", "observed_thread_count", "observed_invocation_count", "observation_thresholds", "observation_signal", "by_lane", "by_milestone", "by_model", "by_reasoning_effort", "by_role", "top_delta_threads"},
    "bindings": {"collector_sha256", "schema_sha256"},
}
THREAD_KEYS = {"thread_id", "label", "model", "reasoning_effort", "current_lifetime_tokens", "previous_lifetime_tokens", "delta_tokens", "delta_status", "updated_at_ms", "parent_thread_id", "identity", "lane_id", "milestone", "role", "mapping_status", "invocation_count"}
JOB_KEYS = {"status", "lane_id", "job_id", "durable_state", "result", "runner_alive", "child_alive", "postcondition_alive", "heartbeat_age_sec", "retry_decision", "lease_identity", "job_identity"}
EVIDENCE_OUTPUT_KEYS = {"status", "contract", "verdict", "confidence", "decision", "findings", "reviewed_head", "sha256", "source"}
LANE_KEYS = {"lane_id", "state", "role", "owner_chat", "head", "reviewed_head", "blocker_class", "updated_at", "worktree", "classification", "allowed_paths", "critical_paths"}
OVERLAP_KEYS = {"changed_path", "lane_id", "allowed_paths", "critical_paths", "classification"}


def exact_keys(value: Any, keys: set[str], label: str) -> None:
    if not isinstance(value, dict) or set(value) != keys:
        refuse(f"closed schema violation at {label}")


def validate_packet(packet: Any) -> None:
    exact_keys(packet, TOP_KEYS, "root")
    if packet["schema_version"] != SCHEMA_VERSION or packet["runtime_mutation"] is not False or packet["installation_actions"] != []:
        refuse("packet identity or mutation boundary invalid")
    normalized_time(packet["observed_at"])
    for name, keys in SECTION_KEYS.items():
        exact_keys(packet[name], keys, name)
    if packet["codex_usage"]["truth_note"] != TRUTH_NOTE:
        refuse("Codex counter truth note changed")
    for index, row in enumerate(packet["codex_usage"]["threads"]):
        exact_keys(row, THREAD_KEYS, f"thread[{index}]")
        if row["delta_status"] not in {"INITIAL", "DELTA_OK", "COUNTER_DECREASED_UNKNOWN", "UNKNOWN"}:
            refuse("invalid delta status")
        if row["delta_status"] != "DELTA_OK" and row["delta_tokens"] is not None:
            refuse("invalid non-delta token value")
    for index, row in enumerate(packet["jobs"]):
        exact_keys(row, JOB_KEYS, f"job[{index}]")
    for index, row in enumerate(packet["evidence"]):
        exact_keys(row, EVIDENCE_OUTPUT_KEYS, f"evidence[{index}]")
    for index, row in enumerate(packet["registry"]["records"]):
        exact_keys(row, LANE_KEYS, f"registry.records[{index}]")
    for section in ("git", "registry"):
        name = "overlap" if section == "git" else "conflicts"
        for index, row in enumerate(packet[section][name]):
            exact_keys(row, OVERLAP_KEYS, f"{section}.{name}[{index}]")
    group_fields = {"by_lane": "lane_id", "by_milestone": "milestone", "by_model": "model",
                    "by_reasoning_effort": "reasoning_effort", "by_role": "role"}
    for group, field in group_fields.items():
        for index, row in enumerate(packet["daily_aggregation"][group]):
            exact_keys(row, {field, "delta_tokens"}, f"daily_aggregation.{group}[{index}]")
    for index, row in enumerate(packet["daily_aggregation"]["top_delta_threads"]):
        exact_keys(row, {"thread_id", "delta_tokens"}, f"daily_aggregation.top_delta_threads[{index}]")
    aggregate_usage([], packet["daily_aggregation"]["observation_thresholds"], packet["observed_at"])
    if not isinstance(packet["limitations"], list) or not all(isinstance(item, str) for item in packet["limitations"]):
        refuse("invalid limitations")
    if not isinstance(packet["git"]["changed_paths"], list) or not isinstance(packet["registry"]["records"], list):
        refuse("invalid collection arrays")
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    if schema.get("$id") != SCHEMA_VERSION or schema.get("additionalProperties") is not False:
        refuse("packaged schema identity invalid")


def read_prior_snapshot(root: Path | None) -> dict[str, int | None] | None:
    if root is None:
        return None
    ledger = root / "snapshots.jsonl"
    try:
        lines = ledger.read_text(encoding="utf-8").splitlines()
    except FileNotFoundError:
        return None
    except OSError:
        refuse("cannot read prior snapshot ledger")
    for line in reversed(lines):
        try:
            value = json.loads(line)
            counters = value.get("counters")
            if value.get("schema_version") == SNAPSHOT_SCHEMA_VERSION and isinstance(counters, dict):
                return {str(k): v for k, v in counters.items() if v is None or (type(v) is int and v >= 0)}
        except (json.JSONDecodeError, AttributeError):
            continue
    return None


def assert_output_root(root: Path, repo: Path) -> None:
    if not root.is_absolute():
        refuse("output root must be absolute")
    absolute, repository = root.resolve(), repo.resolve()
    try:
        absolute.relative_to(repository)
    except ValueError:
        pass
    else:
        refuse("output root must be outside the repository")
    try:
        repository.relative_to(absolute)
    except ValueError:
        pass
    else:
        refuse("output root must not contain the repository")


def write_outputs(root: Path, repo: Path, packet: dict[str, Any]) -> None:
    assert_output_root(root, repo)
    root.mkdir(parents=True, exist_ok=True)
    stamp = packet["observed_at"].replace(":", "").replace("-", "")
    packet_path = root / f"packet-{stamp}.json"
    try:
        with packet_path.open("xb") as stream:
            stream.write(canonical_bytes(packet))
            stream.flush()
            os.fsync(stream.fileno())
    except FileExistsError:
        refuse("packet output already exists")
    counters = {row["thread_id"]: row["current_lifetime_tokens"] for row in packet["codex_usage"]["threads"]}
    snapshot = canonical_bytes({"schema_version": SNAPSHOT_SCHEMA_VERSION, "observed_at": packet["observed_at"], "counters": counters})
    descriptor = os.open(root / "snapshots.jsonl", os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
    with os.fdopen(descriptor, "ab") as stream:
        stream.write(snapshot)
        stream.flush()
        os.fsync(stream.fileno())


def parse_mapping(values: Iterable[str]) -> dict[str, list[Identity]]:
    result: defaultdict[str, list[Identity]] = defaultdict(list)
    for raw in values:
        if "=" not in raw:
            refuse("--thread-identity requires THREAD=LANE[,MILESTONE[,ROLE]]")
        thread, fields = raw.split("=", 1)
        parts = fields.split(",")
        if not thread or not 1 <= len(parts) <= 3 or safe_id(parts[0]) == "UNKNOWN":
            refuse("invalid exact thread identity mapping")
        milestone = parts[1] if len(parts) > 1 and parts[1] else None
        role = parts[2].upper() if len(parts) > 2 and parts[2] else None
        if role not in (None, "AUTHOR", "REVIEWER"):
            refuse("mapping role must be AUTHOR or REVIEWER")
        result[thread].append(Identity(parts[0], milestone, role))
    return dict(result)


def parse_job_requests(values: Iterable[str]) -> list[tuple[str, str]]:
    output = []
    for raw in values:
        if "=" not in raw:
            refuse("--lane-job requires LANE=JOB")
        lane, job = raw.split("=", 1)
        if safe_id(lane) == "UNKNOWN" or safe_id(job) == "UNKNOWN":
            refuse("invalid lane/job identity")
        output.append((lane, job))
    return output


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--as-of", default=None, help="ISO-8601 observation timestamp; default is current UTC")
    parser.add_argument("--fetch", action="store_true", help="explicitly fetch origin master")
    parser.add_argument("--skip-remote-observe", action="store_true", help="do not run git ls-remote for master")
    parser.add_argument("--registry-root", type=Path, default=Path(r"D:\EA_LAB_CONTROL\lanes\registry-v1"))
    parser.add_argument("--skip-registry", action="store_true")
    parser.add_argument("--current-lane")
    parser.add_argument("--jobs-root", type=Path, default=Path(r"D:\EA_LAB_CONTROL\jobs"))
    parser.add_argument("--lease-root", type=Path, default=Path(r"D:\EA_LAB_CONTROL\leases"))
    parser.add_argument("--lane-job", action="append", default=[])
    parser.add_argument("--evidence", action="append", type=Path, default=[])
    parser.add_argument("--codex-home", action="append", type=Path, default=[])
    parser.add_argument("--thread-identity", action="append", default=[])
    parser.add_argument("--observation-threshold", action="append", type=int, default=[])
    parser.add_argument("--output-root", type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        as_of = normalized_time(args.as_of or dt.datetime.now(dt.timezone.utc).isoformat())
        repo = args.repo_root.resolve()
        thresholds = args.observation_threshold or [1_000_000, 3_000_000]
        mappings = parse_mapping(args.thread_identity)
        prior = read_prior_snapshot(args.output_root)
        packet = empty_packet(as_of)
        packet["git"] = collect_git(repo, not args.skip_remote_observe, args.fetch)
        packet["registry"] = collect_registry(repo, args.registry_root, args.skip_registry)
        add_overlap(packet["git"], packet["registry"], args.current_lane)
        packet["jobs"] = collect_jobs(repo, args.jobs_root, args.lease_root, parse_job_requests(args.lane_job), as_of)
        packet["evidence"] = [parse_evidence(path) for path in sorted(args.evidence, key=lambda p: str(p))]
        homes = args.codex_home or [Path.home() / ".codex"]
        packet["codex_usage"] = collect_codex_usage(homes, as_of, mappings, prior)
        packet["daily_aggregation"] = aggregate_usage(packet["codex_usage"]["threads"], thresholds, as_of)
        if packet["registry"]["status"] != "AVAILABLE":
            packet["limitations"].append("Lane Registry observation unavailable; no Registry state is inferred.")
        if packet["git"]["ls_remote_master"] == "UNKNOWN":
            packet["limitations"].append("Remote master was not observed; canonical remote freshness is unknown.")
        if packet["codex_usage"]["status"] != "AVAILABLE":
            packet["limitations"].append("One or more Codex databases were unavailable or ambiguous.")
        validate_packet(packet)
        if args.output_root:
            write_outputs(args.output_root, repo, packet)
        sys.stdout.buffer.write(canonical_bytes(packet))
        return 0
    except Refusal as exc:
        print(f"REFUSED: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
