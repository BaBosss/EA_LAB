#!/usr/bin/env python3
"""Read-only reporter for local Codex lifetime efficiency counters."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import re
import sqlite3
import sys
import time
from collections import Counter
from pathlib import Path
from typing import Any, NoReturn

SCHEMA_VERSION = "codex_budget_usage_report/2"
POPULATION = "RECENTLY_UPDATED_THREADS"
WINDOW_STATUS = "UNAVAILABLE_NO_BOUNDED_COUNTER_DELTAS"
NOTE = ("Local Codex lifetime counters are efficiency observations only; they are not quota, "
        "billing, credits, plan allowance, savings, or token-to-quota data.")
POLICY_PATH = Path(__file__).resolve().parent / "mode_policy.json"
SCHEMA_PATH = Path(__file__).resolve().parent / "usage_report.schema.json"


class Refusal(ValueError):
    pass


def refuse(message: str) -> NoReturn:
    raise Refusal(message)


def parse_hours(raw: str) -> float:
    try:
        value = float(raw)
    except (TypeError, ValueError):
        refuse("--hours must be finite and > 0")
    if not math.isfinite(value) or value <= 0:
        refuse("--hours must be finite and > 0")
    return value


def parse_as_of_ms(raw: str | None) -> int:
    if raw is None:
        return time.time_ns() // 1_000_000
    if not raw or not raw.isascii() or not raw.isdigit() or int(raw) <= 0:
        refuse("--as-of-ms must be a positive finite integer")
    return int(raw)


def load_policy(mode: str) -> tuple[dict[str, Any], str]:
    try:
        raw = POLICY_PATH.read_bytes()
        policy = json.loads(raw)
        thresholds = policy["advisory_signals"][mode]["alert_tokens"]
    except FileNotFoundError:
        refuse("packaged mode_policy.json is missing")
    except (json.JSONDecodeError, KeyError, TypeError, IndexError):
        refuse("packaged mode_policy.json is invalid")
    if (not isinstance(thresholds, list) or len(thresholds) != 2
            or any(isinstance(x, bool) or not isinstance(x, int) or x < 0 for x in thresholds)
            or thresholds[0] >= thresholds[1]):
        refuse("packaged mode_policy.json has invalid advisory thresholds")
    return policy, hashlib.sha256(raw).hexdigest()


def readonly_connection(path: Path) -> sqlite3.Connection:
    try:
        connection = sqlite3.connect(path.resolve().as_uri() + "?mode=ro", uri=True)
    except sqlite3.Error as exc:
        refuse(f"cannot open required database read-only: {path.name}: {exc}")
    connection.row_factory = sqlite3.Row
    return connection


def require_columns(db: sqlite3.Connection, table: str, required: set[str]) -> None:
    try:
        columns = {row[1] for row in db.execute(f'PRAGMA table_info("{table}")')}
    except sqlite3.Error as exc:
        refuse(f"cannot inspect required table {table}: {exc}")
    missing = sorted(required - columns)
    if missing:
        refuse(f"required table {table} is missing columns: {', '.join(missing)}")


def signal(tokens: int | None, thresholds: list[int]) -> str:
    if tokens is None:
        return "UNKNOWN"
    if tokens >= thresholds[1]:
        return "HIGH"
    if tokens >= thresholds[0]:
        return "ELEVATED"
    return "WITHIN_ADVISORY"


def value_counts(rows: list[sqlite3.Row], column: str) -> list[dict[str, Any]]:
    counts = Counter(row[column] if row[column] not in (None, "") else "UNKNOWN" for row in rows)
    return [{"value": value, "count": counts[value]} for value in sorted(counts)]


def is_subagent(row: sqlite3.Row) -> bool:
    return (row["parent_thread_id"] not in (None, "")
            or row["agent_role"] not in (None, "", "root", "primary"))


def build_report(codex_home: Path, hours: float, as_of_ms: int, mode: str) -> dict[str, Any]:
    policy, policy_sha = load_policy(mode)
    thresholds = policy["advisory_signals"][mode]["alert_tokens"]
    # Avoid float overflow for very large but still finite positive durations.
    start_ms = 0 if hours >= as_of_ms / 3_600_000 else as_of_ms - int(hours * 3_600_000)
    state = readonly_connection(codex_home / "state_5.sqlite")
    history = readonly_connection(codex_home / "thread_history_1.sqlite")
    try:
        require_columns(state, "threads", {"thread_id", "updated_at_ms", "tokens_used", "model",
                        "reasoning_effort", "initial_prompt", "parent_thread_id", "agent_role"})
        require_columns(history, "thread_history", {"thread_id", "item_type"})
        rows = state.execute(
            "SELECT thread_id,updated_at_ms,tokens_used,model,reasoning_effort,initial_prompt,"
            "parent_thread_id,agent_role FROM threads WHERE updated_at_ms>=? AND updated_at_ms<=?",
            (start_ms, as_of_ms)).fetchall()
        for row in rows:
            if not isinstance(row["thread_id"], str) or not row["thread_id"]:
                refuse("selected thread has an invalid thread_id")
            value = row["tokens_used"]
            if isinstance(value, bool) or (value is not None and
                    (not isinstance(value, int) or value < 0)):
                refuse(f"thread {row['thread_id']} has an invalid tokens_used counter")
        history_counts: Counter[str] = Counter()
        ids = [row["thread_id"] for row in rows]
        if ids:
            marks = ",".join("?" for _ in ids)
            for item in history.execute(
                    f"SELECT item_type,COUNT(*) count FROM thread_history WHERE thread_id IN ({marks}) GROUP BY item_type",
                    ids):
                label = item["item_type"] if item["item_type"] not in (None, "") else "UNKNOWN"
                history_counts[str(label)] += int(item["count"])
    except sqlite3.Error as exc:
        refuse(f"database query failed closed: {exc}")
    finally:
        state.close()
        history.close()

    top = [row for row in rows if not is_subagent(row)]
    known = [row["tokens_used"] for row in rows if row["tokens_used"] is not None]
    unknown = len(rows) - len(known)
    known_sum = sum(known)
    prompt_lengths = [len(row["initial_prompt"]) for row in rows
                      if isinstance(row["initial_prompt"], str)]
    ordered = sorted(top, key=lambda row: (row["tokens_used"] is None,
                                           -(row["tokens_used"] or 0), row["thread_id"]))[:10]
    report = {
        "schema_version": SCHEMA_VERSION,
        "population": POPULATION,
        "as_of_ms": as_of_ms,
        "window_start_ms": start_ms,
        "hours": hours,
        "mode": mode,
        "policy_sha256": policy_sha,
        "efficiency_observation_note": NOTE,
        "thread_counts": {"total": len(rows), "top_level": len(top), "subagent": len(rows)-len(top)},
        "recently_updated_thread_lifetime_tokens_known_sum": known_sum,
        "recently_updated_thread_lifetime_tokens_total": known_sum if unknown == 0 else None,
        "token_counter_known_count": len(known),
        "token_counter_unknown_count": unknown,
        "token_counter_completeness": "COMPLETE" if unknown == 0 else "PARTIAL",
        "window_delta_tokens": None,
        "window_delta_status": WINDOW_STATUS,
        "model_counts": value_counts(rows, "model"),
        "reasoning_effort_counts": value_counts(rows, "reasoning_effort"),
        "initial_prompt_chars": {"known_sum": sum(prompt_lengths), "known_count": len(prompt_lengths),
                                 "unknown_count": len(rows)-len(prompt_lengths)},
        "thread_history_item_type_counts": [
            {"item_type": name, "count": history_counts[name]} for name in sorted(history_counts)],
        "heaviest_top_level_threads": [{
            "thread_id": row["thread_id"], "updated_at_ms": row["updated_at_ms"],
            "local_tokens": row["tokens_used"], "budget_signal": signal(row["tokens_used"], thresholds),
            "model": row["model"] if row["model"] not in (None, "") else "UNKNOWN",
            "reasoning_effort": row["reasoning_effort"] if row["reasoning_effort"] not in (None, "") else "UNKNOWN",
            "initial_prompt_chars": len(row["initial_prompt"]) if isinstance(row["initial_prompt"], str) else None,
        } for row in ordered],
    }
    validate_report(report)
    return report


def closed_keys(value: Any, required: set[str], context: str) -> None:
    if not isinstance(value, dict) or set(value) != required:
        actual = set(value) if isinstance(value, dict) else set()
        refuse(f"report validation failed: {context} fields differ; missing={sorted(required-actual)}, unknown={sorted(actual-required)}")


def nonnegative_int(value: Any, context: str) -> None:
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        refuse(f"report validation failed: {context} must be a non-negative integer")


def _schema_type_matches(value: Any, expected: str) -> bool:
    if expected == "null":
        return value is None
    if expected == "object":
        return isinstance(value, dict)
    if expected == "array":
        return isinstance(value, list)
    if expected == "string":
        return isinstance(value, str)
    if expected == "integer":
        return not isinstance(value, bool) and isinstance(value, int)
    if expected == "number":
        return (not isinstance(value, bool) and isinstance(value, int)) or (
            isinstance(value, float) and math.isfinite(value))
    return False


def _validate_schema_value(value: Any, rule: dict[str, Any], root: dict[str, Any],
                           context: str) -> None:
    """Validate the closed JSON-Schema subset used by usage_report.schema.json."""
    if "$ref" in rule:
        prefix = "#/$defs/"
        reference = rule["$ref"]
        if not isinstance(reference, str) or not reference.startswith(prefix):
            refuse(f"report validation failed: unsupported schema reference at {context}")
        name = reference[len(prefix):]
        target = root.get("$defs", {}).get(name)
        if not isinstance(target, dict):
            refuse(f"report validation failed: unresolved schema reference at {context}")
        _validate_schema_value(value, target, root, context)
        return

    if "const" in rule and value != rule["const"]:
        refuse(f"report validation failed: {context} violates const")
    if "enum" in rule and value not in rule["enum"]:
        refuse(f"report validation failed: {context} violates enum")

    declared = rule.get("type")
    if declared is not None:
        expected = declared if isinstance(declared, list) else [declared]
        if not expected or not all(isinstance(item, str) for item in expected):
            refuse(f"report validation failed: invalid schema type at {context}")
        if not any(_schema_type_matches(value, item) for item in expected):
            refuse(f"report validation failed: {context} has invalid type")

    if isinstance(value, str):
        if len(value) < rule.get("minLength", 0):
            refuse(f"report validation failed: {context} is too short")
        pattern = rule.get("pattern")
        if pattern is not None and re.fullmatch(pattern, value) is None:
            refuse(f"report validation failed: {context} violates pattern")

    numeric = not isinstance(value, bool) and isinstance(value, (int, float))
    if numeric:
        if isinstance(value, float) and not math.isfinite(value):
            refuse(f"report validation failed: {context} must be finite")
        if "minimum" in rule and value < rule["minimum"]:
            refuse(f"report validation failed: {context} is below minimum")
        if "exclusiveMinimum" in rule and value <= rule["exclusiveMinimum"]:
            refuse(f"report validation failed: {context} is below exclusiveMinimum")

    if isinstance(value, dict):
        properties = rule.get("properties", {})
        required = set(rule.get("required", []))
        actual = set(value)
        missing = required - actual
        unknown = actual - set(properties) if rule.get("additionalProperties") is False else set()
        if missing or unknown:
            refuse(f"report validation failed: {context} fields differ; "
                   f"missing={sorted(missing)}, unknown={sorted(unknown)}")
        for key, child in properties.items():
            if key in value:
                _validate_schema_value(value[key], child, root, f"{context}.{key}")

    if isinstance(value, list):
        if "maxItems" in rule and len(value) > rule["maxItems"]:
            refuse(f"report validation failed: {context} has too many items")
        item_rule = rule.get("items")
        if isinstance(item_rule, dict):
            for index, item in enumerate(value):
                _validate_schema_value(item, item_rule, root, f"{context}[{index}]")


def validate_schema_contract(report: Any) -> None:
    try:
        schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        refuse("report validation failed: packaged usage schema is unavailable or invalid")
    if not isinstance(schema, dict):
        refuse("report validation failed: packaged usage schema is invalid")
    _validate_schema_value(report, schema, schema, "root")


def validate_report(report: dict[str, Any]) -> None:
    validate_schema_contract(report)
    top_keys = {"schema_version", "population", "as_of_ms", "window_start_ms", "hours", "mode",
        "policy_sha256", "efficiency_observation_note", "thread_counts",
        "recently_updated_thread_lifetime_tokens_known_sum", "recently_updated_thread_lifetime_tokens_total",
        "token_counter_known_count", "token_counter_unknown_count", "token_counter_completeness",
        "window_delta_tokens", "window_delta_status", "model_counts", "reasoning_effort_counts",
        "initial_prompt_chars", "thread_history_item_type_counts", "heaviest_top_level_threads"}
    closed_keys(report, top_keys, "root")
    if report["schema_version"] != SCHEMA_VERSION or report["population"] != POPULATION:
        refuse("report validation failed: identity fields are invalid")
    if report["mode"] not in ("NORMAL", "ECONOMY"):
        refuse("report validation failed: mode is invalid")
    hours = report["hours"]
    if isinstance(hours, bool) or not isinstance(hours, (int, float)) or not math.isfinite(hours) or hours <= 0:
        refuse("report validation failed: hours is invalid")
    nonnegative_int(report["as_of_ms"], "as_of_ms")
    nonnegative_int(report["window_start_ms"], "window_start_ms")
    if report["as_of_ms"] <= 0 or report["window_start_ms"] > report["as_of_ms"]:
        refuse("report validation failed: observation window is invalid")
    if not isinstance(report["policy_sha256"], str) or len(report["policy_sha256"]) != 64:
        refuse("report validation failed: policy_sha256 is invalid")
    if report["efficiency_observation_note"] != NOTE:
        refuse("report validation failed: efficiency note is invalid")
    closed_keys(report["thread_counts"], {"total", "top_level", "subagent"}, "thread_counts")
    closed_keys(report["initial_prompt_chars"], {"known_sum", "known_count", "unknown_count"}, "initial_prompt_chars")
    for key in ("total", "top_level", "subagent"):
        nonnegative_int(report["thread_counts"][key], f"thread_counts.{key}")
    if report["thread_counts"]["top_level"] + report["thread_counts"]["subagent"] != report["thread_counts"]["total"]:
        refuse("report validation failed: thread counts do not reconcile")
    for key in ("known_sum", "known_count", "unknown_count"):
        nonnegative_int(report["initial_prompt_chars"][key], f"initial_prompt_chars.{key}")
    for key in ("recently_updated_thread_lifetime_tokens_known_sum", "token_counter_known_count", "token_counter_unknown_count"):
        nonnegative_int(report[key], key)
    if report["token_counter_known_count"] + report["token_counter_unknown_count"] != report["thread_counts"]["total"]:
        refuse("report validation failed: token counter counts do not reconcile")
    if report["initial_prompt_chars"]["known_count"] + report["initial_prompt_chars"]["unknown_count"] != report["thread_counts"]["total"]:
        refuse("report validation failed: prompt counts do not reconcile")
    complete = report["token_counter_unknown_count"] == 0
    if report["token_counter_completeness"] != ("COMPLETE" if complete else "PARTIAL"):
        refuse("report validation failed: counter completeness is inconsistent")
    total = report["recently_updated_thread_lifetime_tokens_total"]
    if (complete and total != report["recently_updated_thread_lifetime_tokens_known_sum"]) or (not complete and total is not None):
        refuse("report validation failed: lifetime token total is inconsistent")
    if report["window_delta_tokens"] is not None or report["window_delta_status"] != WINDOW_STATUS:
        refuse("report validation failed: unavailable window delta was misrepresented")
    def validate_counts(items: Any, label: str, context: str) -> None:
        if not isinstance(items, list):
            refuse(f"report validation failed: {context} must be an array")
        for item in items:
            closed_keys(item, {label, "count"}, context)
            if not isinstance(item[label], str) or not item[label]:
                refuse(f"report validation failed: {context} label is invalid")
            nonnegative_int(item["count"], f"{context}.count")
    validate_counts(report["model_counts"], "value", "model_counts")
    validate_counts(report["reasoning_effort_counts"], "value", "reasoning_effort_counts")
    validate_counts(report["thread_history_item_type_counts"], "item_type", "thread_history_item_type_counts")
    if not isinstance(report["heaviest_top_level_threads"], list) or len(report["heaviest_top_level_threads"]) > 10:
        refuse("report validation failed: heaviest_top_level_threads is invalid")
    keys = {"thread_id", "updated_at_ms", "local_tokens", "budget_signal", "model", "reasoning_effort", "initial_prompt_chars"}
    for item in report["heaviest_top_level_threads"]:
        closed_keys(item, keys, "heaviest_top_level_threads")
        if not isinstance(item["thread_id"], str) or not item["thread_id"]:
            refuse("report validation failed: heaviest thread_id is invalid")
        nonnegative_int(item["updated_at_ms"], "heaviest.updated_at_ms")
        for key in ("local_tokens", "initial_prompt_chars"):
            if item[key] is not None:
                nonnegative_int(item[key], f"heaviest.{key}")
        if item["budget_signal"] not in ("WITHIN_ADVISORY", "ELEVATED", "HIGH", "UNKNOWN"):
            refuse("report validation failed: budget_signal is invalid")
        for key in ("model", "reasoning_effort"):
            if not isinstance(item[key], str) or not item[key]:
                refuse(f"report validation failed: heaviest.{key} is invalid")


def create_only(path: Path, payload: bytes) -> None:
    try:
        descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except FileExistsError:
        refuse(f"output already exists: {path}")
    except OSError as exc:
        refuse(f"cannot create output: {exc}")
    try:
        with os.fdopen(descriptor, "wb") as output:
            output.write(payload)
    except Exception:
        path.unlink(missing_ok=True)
        raise


def main(argv: list[str] | None = None) -> int:
    raw_argv = list(sys.argv[1:] if argv is None else argv)
    # argparse treats non-numeric negative spellings such as "-inf" as options.
    # Normalize the two validated numeric options so all bad values reach the
    # contract validators before any filesystem or database access.
    for option in ("--hours", "--as-of-ms"):
        if option in raw_argv:
            index = raw_argv.index(option)
            if index + 1 < len(raw_argv) and raw_argv[index + 1].startswith("-"):
                raw_argv[index:index + 2] = [f"{option}={raw_argv[index + 1]}"]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--hours", required=True)
    parser.add_argument("--as-of-ms")
    parser.add_argument("--codex-home", default=str(Path.home() / ".codex"))
    parser.add_argument("--mode", choices=("NORMAL", "ECONOMY"), default="NORMAL")
    parser.add_argument("--out")
    args = parser.parse_args(raw_argv)
    try:
        # Validate these before path construction, policy access, or database access.
        hours = parse_hours(args.hours)
        as_of_ms = parse_as_of_ms(args.as_of_ms)
        report = build_report(Path(args.codex_home), hours, as_of_ms, args.mode)
        payload = (json.dumps(report, sort_keys=True, separators=(",", ":")) + "\n").encode()
        create_only(Path(args.out), payload) if args.out else sys.stdout.buffer.write(payload)
        return 0
    except Refusal as exc:
        print(f"REFUSED: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
