#!/usr/bin/env python3
"""Offline preparation CLI for the OFP historical research pipeline.

The CLI only freezes planned work, builds inert acquisition requests, and
checks frozen raw-artifact integrity. It has no terminal, process, network,
tester, execution, or market-data acquisition capability.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import math
import re
import sys
from pathlib import Path, PurePosixPath
from typing import Any


PREREGISTRATION_SCHEMA = "ofp_historical_preregistration/v1"
PLAN_SCHEMA = "ofp_historical_plan/v1"
ACQUISITION_REQUEST_SCHEMA = "ofp_historical_acquisition_request/v1"
RAW_MANIFEST_SCHEMA = "ofp_historical_raw_manifest/v1"
PREFLIGHT_SCHEMA = "ofp_historical_preflight/v1"

EXPECTED_BASE_HEAD = "d5e23b5d91421c98e069d5db5b089c3203c8f02c"
EXPECTED_PROXY_PARENT = "86143b433293e5b3acfbb4c037c37e931d68b766"
EXPECTED_SEAM_PARENT = "5436833f3791049655f3ab44b90582c73d222e1d"
EXPECTED_UNIVERSE = ("XAUUSD", "EURUSD", "GBPUSD", "EURGBP", "USDJPY", "EURJPY")
EXPECTED_VARIANTS = (
    ("OFPR-00", None),
    ("OFPR-01", "OFPR-00"),
    ("OFPR-02", "OFPR-01"),
    ("OFPC-00", None),
    ("OFPC-01", "OFPC-00"),
    ("OFPC-02", "OFPC-01"),
)
EXPECTED_WINDOWS = {
    "BWD": {
        "basis": "BROKER_SERVER_CLOCK_CONTRACT_REQUIRED",
        "start_broker_time": "2020-01-01T00:00:00",
        "end_broker_time": "2023-01-01T00:00:00",
        "interval": "HALF_OPEN",
    },
    "MAIN": {
        "basis": "BROKER_SERVER_CLOCK_CONTRACT_REQUIRED",
        "start_broker_time": "2023-01-01T00:00:00",
        "end_broker_time": "2026-01-01T00:00:00",
        "interval": "HALF_OPEN",
    },
}
REQUIRED_ARTIFACT_ROLES = (
    "RAW_QUOTE_ROWS",
    "D1_RATE_ROWS",
    "M15_RATE_ROWS",
    "M5_RATE_ROWS",
)
SOURCE_GRAPH_NODES = (
    "NAMED_BROKER_HISTORY",
    "RAW_QUOTE_ROWS",
    "D1_RATE_ROWS",
    "M15_RATE_ROWS",
    "M5_RATE_ROWS",
)
SOURCE_GRAPH_EDGES = (
    "NAMED_BROKER_HISTORY->RAW_QUOTE_ROWS",
    "NAMED_BROKER_HISTORY->D1_RATE_ROWS",
    "NAMED_BROKER_HISTORY->M15_RATE_ROWS",
    "NAMED_BROKER_HISTORY->M5_RATE_ROWS",
)

_SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
_HEAD_RE = re.compile(r"^[0-9a-f]{40}$")
_BROKER_TIME_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$")
_UTC_TIME_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")


class Refusal(ValueError):
    """Fail-closed contract or evidence refusal."""


def canonical_json_bytes(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode("utf-8")


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except FileNotFoundError as exc:
        raise Refusal(f"file missing: {path}") from exc
    except json.JSONDecodeError as exc:
        raise Refusal(f"invalid JSON in {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise Refusal(f"top-level JSON must be an object: {path}")
    return value


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(canonical_json_bytes(value))


def _text(value: Any, field: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise Refusal(f"{field} must be a non-empty string")
    return value.strip()


def _strict_int(value: Any, field: str, *, minimum: int = 0) -> int:
    if not isinstance(value, int) or isinstance(value, bool) or value < minimum:
        raise Refusal(f"{field} must be an integer >= {minimum}; bool is not an integer")
    return value


def _finite_number(value: Any, field: str, *, positive: bool = False) -> float:
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        raise Refusal(f"{field} must be a finite number; bool is not numeric")
    number = float(value)
    if not math.isfinite(number) or (positive and number <= 0.0):
        qualifier = "positive " if positive else ""
        raise Refusal(f"{field} must be a {qualifier}finite number")
    return number


def _sha256(value: Any, field: str) -> str:
    text = _text(value, field).lower()
    if not _SHA256_RE.fullmatch(text):
        raise Refusal(f"{field} must be lowercase SHA256")
    return text


def _broker_time(value: Any, field: str) -> str:
    text = _text(value, field)
    if not _BROKER_TIME_RE.fullmatch(text):
        raise Refusal(f"{field} must be broker-clock YYYY-MM-DDTHH:MM:SS without inferred timezone")
    try:
        dt.datetime.strptime(text, "%Y-%m-%dT%H:%M:%S")
    except ValueError as exc:
        raise Refusal(f"{field} is not a valid broker-clock timestamp") from exc
    return text


def _safe_relative_path(value: Any) -> str:
    text = _text(value, "artifact.path").replace("\\", "/")
    if text.startswith("/") or re.match(r"^[A-Za-z]:", text):
        raise Refusal(f"artifact path must be relative: {value}")
    path = PurePosixPath(text)
    if not path.parts or any(part in ("", ".", "..") or ":" in part for part in path.parts):
        raise Refusal(f"artifact path contains unsafe segment: {value}")
    return path.as_posix()


def _is_reparse(path: Path) -> bool:
    if path.is_symlink():
        return True
    is_junction = getattr(path, "is_junction", None)
    if is_junction is not None and is_junction():
        return True
    try:
        attributes = getattr(path.lstat(), "st_file_attributes", 0)
    except FileNotFoundError:
        return False
    return bool(attributes & 0x400)


def _resolve_artifact(base: Path, relative: str) -> Path:
    current = base
    for part in PurePosixPath(relative).parts:
        current = current / part
        if _is_reparse(current):
            raise Refusal(f"artifact reparse component is not allowed: {relative}")
    try:
        resolved = current.resolve(strict=True)
        resolved.relative_to(base.resolve(strict=True))
    except FileNotFoundError as exc:
        raise Refusal(f"artifact missing: {relative}") from exc
    except ValueError as exc:
        raise Refusal(f"artifact escapes manifest directory: {relative}") from exc
    if not resolved.is_file():
        raise Refusal(f"artifact is not a regular file: {relative}")
    return resolved


def _validate_preregistration(preregistration: dict[str, Any]) -> None:
    if preregistration.get("schema") != PREREGISTRATION_SCHEMA:
        raise Refusal("unsupported preregistration schema")
    if preregistration.get("base_head") != EXPECTED_BASE_HEAD:
        raise Refusal("preregistration base_head mismatch")
    parents = preregistration.get("parents")
    if not isinstance(parents, dict):
        raise Refusal("preregistration parents must be an object")
    if parents.get("accepted_proxy_source") != EXPECTED_PROXY_PARENT:
        raise Refusal("accepted proxy parent mismatch")
    if parents.get("accepted_template_seam") != EXPECTED_SEAM_PARENT:
        raise Refusal("accepted template seam parent mismatch")
    if tuple(preregistration.get("universe", ())) != EXPECTED_UNIVERSE:
        raise Refusal("preregistration universe mismatch")
    variants = preregistration.get("variants")
    if not isinstance(variants, list):
        raise Refusal("preregistration variants must be an array")
    lineage = tuple((row.get("variant_id"), row.get("parent")) for row in variants if isinstance(row, dict))
    if lineage != EXPECTED_VARIANTS:
        raise Refusal("preregistration variant parentage mismatch")
    if any(not _text(row.get("change"), "variant.change") for row in variants):
        raise Refusal("each variant must freeze one logical change")
    windows = preregistration.get("windows")
    if not isinstance(windows, list) or len(windows) != 2:
        raise Refusal("preregistration must contain exact BWD and MAIN windows")
    observed_windows: dict[str, Any] = {}
    for window in windows:
        if not isinstance(window, dict):
            raise Refusal("window must be an object")
        observed_windows[window.get("window_id")] = window.get("requested_interval")
    if observed_windows != EXPECTED_WINDOWS:
        raise Refusal("preregistration requested windows mismatch")
    if preregistration.get("flat_lot_probe") != "NOT_APPLICABLE_NO_EXECUTION_YET":
        raise Refusal("flat-lot state must remain NOT_APPLICABLE_NO_EXECUTION_YET")
    measurements = preregistration.get("measurements")
    if not isinstance(measurements, dict) or measurements.get("numeric_grade_floors") is not None:
        raise Refusal("numeric verdict/grade floors must remain null")
    if measurements.get("assessment_state") != "NOT_ASSESSABLE_UNTIL_QUALIFIED_INPUT_AND_EXECUTION_CONTRACTS":
        raise Refusal("performance must remain not assessable")
    if preregistration.get("model_contract", {}).get("model4") != "PLANNED_NOT_EXECUTED":
        raise Refusal("Model4 state must remain PLANNED_NOT_EXECUTED")
    prerequisites = preregistration.get("execution_prerequisites")
    if not isinstance(prerequisites, dict):
        raise Refusal("execution_prerequisites must be an object")
    if prerequisites.get("historical_consumer") != "HISTORICAL_SEAM_CONSUMER_NOT_IMPLEMENTED":
        raise Refusal("historical seam consumer must remain not implemented")
    if any(
        value != "UNRESOLVED_SEMANTICS_REQUIRED"
        for key, value in prerequisites.items()
        if key != "historical_consumer"
    ):
        raise Refusal("execution semantics must remain unresolved prerequisites")


def build_plan(preregistration: dict[str, Any]) -> dict[str, Any]:
    _validate_preregistration(preregistration)
    variants = preregistration["variants"]
    windows = preregistration["windows"]
    cells: list[dict[str, Any]] = []
    for symbol in EXPECTED_UNIVERSE:
        for variant in variants:
            for window in windows:
                variant_id = variant["variant_id"]
                window_id = window["window_id"]
                cells.append(
                    {
                        "cell_id": f"OFP-HIST-V1::{symbol}::{variant_id}::{window_id}",
                        "logical_symbol": symbol,
                        "variant_id": variant_id,
                        "parent_variant": variant["parent"],
                        "one_logical_change": variant["change"],
                        "window_id": window_id,
                        "requested_interval": window["requested_interval"],
                        "tester_model": "M4_REAL_TICK_FIDELITY_PLANNED_NOT_EXECUTED",
                        "execution_state": "NOT_RUN",
                        "input_state": "WAITING_RAW_HISTORY_QUALIFICATION",
                        "performance": {
                            "profit_factor": None,
                            "net_profit": None,
                            "drawdown": None,
                            "trades": None,
                            "opportunities": None,
                        },
                    }
                )
    preregistration_hash = _sha256_bytes(canonical_json_bytes(preregistration))
    return {
        "schema": PLAN_SCHEMA,
        "plan_id": "OFP_HISTORICAL_72_CELL_PLAN_V1_20260920",
        "base_head": EXPECTED_BASE_HEAD,
        "preregistration_sha256": preregistration_hash,
        "parents": preregistration["parents"],
        "universe": list(EXPECTED_UNIVERSE),
        "variants": variants,
        "windows": windows,
        "planned_cells": len(cells),
        "executed_cells": 0,
        "cells": cells,
        "flat_lot_probe": "NOT_APPLICABLE_NO_EXECUTION_YET",
        "performance_assessment": "NOT_AVAILABLE",
        "opportunity_claim": None,
        "trade_claim": None,
        "source_readiness_snapshot": {
            "accepted_proxy_source": "SOURCE_ACCEPTED_REPO_ONLY",
            "accepted_a2_current_window": "PARTIALLY_QUALIFIED_CURRENT_WINDOW_SIX_SYMBOLS_ONLY",
            "accepted_template_seam": "CURRENT_WINDOW_PINS_ONLY",
            "historical_raw_quotes": "MISSING_REQUIRED",
            "historical_d1_m15_m5": "MISSING_REQUIRED",
            "historical_clock_contract": "REQUIRED",
            "historical_consumer": "HISTORICAL_SEAM_CONSUMER_NOT_IMPLEMENTED",
            "signal_input_fidelity": "SIGNAL_INPUT_FIDELITY_UNQUALIFIED",
            "execution_semantics": "SEMANTICS_REQUIRED",
        },
        "authority": "RESEARCH_PREPARATION_ONLY_NO_EXECUTION",
    }


def _validate_plan(plan: dict[str, Any]) -> None:
    if plan.get("schema") != PLAN_SCHEMA:
        raise Refusal("unsupported plan schema")
    if plan.get("base_head") != EXPECTED_BASE_HEAD:
        raise Refusal("plan base_head mismatch")
    if tuple(plan.get("universe", ())) != EXPECTED_UNIVERSE:
        raise Refusal("plan universe mismatch")
    parents = plan.get("parents")
    if parents != {
        "accepted_proxy_source": EXPECTED_PROXY_PARENT,
        "accepted_template_seam": EXPECTED_SEAM_PARENT,
    }:
        raise Refusal("plan source parent mismatch")
    variants = plan.get("variants")
    if not isinstance(variants, list) or tuple(
        (row.get("variant_id"), row.get("parent")) for row in variants if isinstance(row, dict)
    ) != EXPECTED_VARIANTS:
        raise Refusal("plan variant parentage mismatch")
    observed_windows = {
        row.get("window_id"): row.get("requested_interval")
        for row in plan.get("windows", ())
        if isinstance(row, dict)
    }
    if observed_windows != EXPECTED_WINDOWS:
        raise Refusal("plan requested windows mismatch")
    if plan.get("planned_cells") != 72 or plan.get("executed_cells") != 0:
        raise Refusal("plan must contain 72 planned and zero executed cells")
    cells = plan.get("cells")
    if not isinstance(cells, list) or len(cells) != 72:
        raise Refusal("plan cell count mismatch")
    ids = [cell.get("cell_id") for cell in cells if isinstance(cell, dict)]
    if len(set(ids)) != 72:
        raise Refusal("plan cell ids must be unique")
    if any(cell.get("execution_state") != "NOT_RUN" for cell in cells):
        raise Refusal("every plan cell must remain NOT_RUN")
    expected_cells = {
        (symbol, variant_id, window_id, parent)
        for symbol in EXPECTED_UNIVERSE
        for variant_id, parent in EXPECTED_VARIANTS
        for window_id in EXPECTED_WINDOWS
    }
    observed_cells = {
        (
            cell.get("logical_symbol"),
            cell.get("variant_id"),
            cell.get("window_id"),
            cell.get("parent_variant"),
        )
        for cell in cells
    }
    if observed_cells != expected_cells:
        raise Refusal("plan cell identity or parentage mismatch")
    expected_performance = {
        "profit_factor": None,
        "net_profit": None,
        "drawdown": None,
        "trades": None,
        "opportunities": None,
    }
    if any(cell.get("performance") != expected_performance for cell in cells):
        raise Refusal("plan performance values must remain null")


def build_acquisition_request(
    plan: dict[str, Any], *, broker: str, server: str, terminal_build: int
) -> dict[str, Any]:
    _validate_plan(plan)
    broker = _text(broker, "broker")
    server = _text(server, "server")
    terminal_build = _strict_int(terminal_build, "terminal_build", minimum=1)
    requests: list[dict[str, Any]] = []
    for window in plan["windows"]:
        for symbol in plan["universe"]:
            for role in REQUIRED_ARTIFACT_ROLES:
                requests.append(
                    {
                        "request_id": f"{symbol}::{window['window_id']}::{role}",
                        "artifact_role": role,
                        "logical_symbol": symbol,
                        "broker_symbol": symbol,
                        "requested_interval": window["requested_interval"],
                        "required_row_identity": {
                            "broker": broker,
                            "server": server,
                            "terminal_build": terminal_build,
                            "logical_symbol": symbol,
                            "broker_symbol": symbol,
                        },
                    }
                )
    plan_hash = _sha256_bytes(canonical_json_bytes(plan))
    return {
        "schema": ACQUISITION_REQUEST_SCHEMA,
        "request_id": "OFP_HISTORICAL_RAW_ACQUISITION_REQUEST_V1_20260920",
        "plan_sha256": plan_hash,
        "source_identity_requested_not_observed": {
            "broker": broker,
            "server": server,
            "terminal_build": terminal_build,
            "symbol_mapping": "EXACT_NAME",
        },
        "clock_requirement": "NAMED_BROKER_CLOCK_CONTRACT_REQUIRED_NO_LOCAL_CONVERSION",
        "raw_quote_requirement": "TIMESTAMPED_BID_ASK_FLAGS_ROWS_REQUIRED_RECEIPTS_ARE_INSUFFICIENT",
        "request_count": len(requests),
        "requests": requests,
        "network_action": "NONE",
        "terminal_action": "NONE",
        "process_action": "NONE",
        "execution_authorized": False,
        "authority": "INERT_REQUEST_ONLY",
    }


def _read_jsonl(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    try:
        for line_number, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), start=1):
            if not line.strip():
                raise Refusal(f"blank JSONL row in {path.name}:{line_number}")
            try:
                value = json.loads(line)
            except json.JSONDecodeError as exc:
                raise Refusal(f"invalid JSONL in {path.name}:{line_number}: {exc}") from exc
            if not isinstance(value, dict):
                raise Refusal(f"JSONL row must be an object in {path.name}:{line_number}")
            rows.append(value)
    except UnicodeDecodeError as exc:
        raise Refusal(f"artifact is not readable UTF-8 JSONL: {path.name}") from exc
    if not rows:
        raise Refusal(f"artifact has no raw rows: {path.name}")
    return rows


def _validate_row(
    row: dict[str, Any], artifact: dict[str, Any], source_identity: dict[str, Any], classification: str
) -> str:
    symbol = artifact["logical_symbol"]
    expected_identity = {
        "broker": source_identity["broker"],
        "server": source_identity["server"],
        "terminal_build": source_identity["terminal_build"],
        "logical_symbol": symbol,
        "broker_symbol": artifact["broker_symbol"],
    }
    for field, expected in expected_identity.items():
        if row.get(field) != expected or isinstance(row.get(field), bool) and field == "terminal_build":
            raise Refusal(f"row identity mismatch for {symbol}: {field}")
    fixture_flag = row.get("synthetic_fixture")
    if not isinstance(fixture_flag, bool):
        raise Refusal("synthetic_fixture must be a boolean")
    if classification == "SYNTHETIC_FIXTURE" and not fixture_flag:
        raise Refusal("fixture row is not marked synthetic_fixture")
    if classification == "BROKER_HISTORY_EXPORT" and fixture_flag:
        raise Refusal("fixture substitution cannot satisfy BROKER_HISTORY_EXPORT")
    market_time = _broker_time(
        row.get("historical_market_time_broker"), "historical_market_time_broker"
    )
    interval = artifact["requested_interval"]
    if not interval["start_broker_time"] <= market_time < interval["end_broker_time"]:
        raise Refusal(
            f"record outside requested half-open interval: {symbol}/{artifact['window_id']}/{artifact['role']}"
        )
    if "decision_time_broker" in row:
        decision_time = _broker_time(row.get("decision_time_broker"), "decision_time_broker")
        if market_time >= decision_time:
            raise Refusal("post-decision data is not admissible")
    if artifact["role"] == "RAW_QUOTE_ROWS":
        bid = _finite_number(row.get("bid"), "bid", positive=True)
        ask = _finite_number(row.get("ask"), "ask", positive=True)
        if ask < bid:
            raise Refusal("ask must be >= bid")
        _strict_int(row.get("flags"), "flags")
        forbidden = {"pass1_count", "pass2_count", "quote_stream_sha256", "a2_receipt"}
        if forbidden.intersection(row):
            raise Refusal("A2 count/hash receipt fields cannot substitute for raw quote rows")
    else:
        expected_timeframe = {
            "D1_RATE_ROWS": "D1",
            "M15_RATE_ROWS": "M15",
            "M5_RATE_ROWS": "M5",
        }[artifact["role"]]
        if row.get("timeframe") != expected_timeframe:
            raise Refusal(f"rate row timeframe must be {expected_timeframe}")
        open_value = _finite_number(row.get("open"), "open", positive=True)
        high = _finite_number(row.get("high"), "high", positive=True)
        low = _finite_number(row.get("low"), "low", positive=True)
        close = _finite_number(row.get("close"), "close", positive=True)
        if low > min(open_value, close) or high < max(open_value, close) or high < low:
            raise Refusal("invalid OHLC relationship")
        _strict_int(row.get("tick_volume"), "tick_volume")
    return market_time


def _validate_raw_manifest(
    manifest: dict[str, Any], manifest_path: Path, plan: dict[str, Any]
) -> dict[str, Any]:
    if manifest.get("schema") != RAW_MANIFEST_SCHEMA:
        raise Refusal("unsupported raw manifest schema")
    _text(manifest.get("manifest_id"), "manifest_id")
    classification = manifest.get("classification")
    if classification not in ("SYNTHETIC_FIXTURE", "BROKER_HISTORY_EXPORT"):
        raise Refusal("classification must be SYNTHETIC_FIXTURE or BROKER_HISTORY_EXPORT")
    if classification == "SYNTHETIC_FIXTURE":
        _text(manifest.get("fixture_id"), "fixture_id")
    elif "fixture_id" in manifest:
        raise Refusal("BROKER_HISTORY_EXPORT cannot carry fixture_id")

    source = manifest.get("source_identity")
    if not isinstance(source, dict):
        raise Refusal("source_identity must be an object")
    source["broker"] = _text(source.get("broker"), "source_identity.broker")
    source["server"] = _text(source.get("server"), "source_identity.server")
    source["terminal_build"] = _strict_int(
        source.get("terminal_build"), "source_identity.terminal_build", minimum=1
    )
    mappings = source.get("symbol_mappings")
    expected_mappings = [
        {"logical_symbol": symbol, "broker_symbol": symbol} for symbol in EXPECTED_UNIVERSE
    ]
    if mappings != expected_mappings:
        raise Refusal("source symbol mappings must be the exact six identity mappings")

    graph = manifest.get("source_graph")
    if not isinstance(graph, dict) or graph.get("graph_id") != "OFP_RAW_HISTORY_EXPORT_V1":
        raise Refusal("source graph identity mismatch")
    if tuple(graph.get("nodes", ())) != SOURCE_GRAPH_NODES or tuple(graph.get("edges", ())) != SOURCE_GRAPH_EDGES:
        raise Refusal("source graph nodes/edges mismatch")

    scope = manifest.get("dataset_scope")
    if not isinstance(scope, dict):
        raise Refusal("dataset_scope must be an object")
    if scope.get("universe") != list(EXPECTED_UNIVERSE):
        raise Refusal("dataset scope universe mismatch")
    if scope.get("requested_windows") != plan["windows"]:
        raise Refusal("dataset scope windows mismatch")
    acquisition_time = _text(scope.get("acquisition_time_utc"), "acquisition_time_utc")
    if not _UTC_TIME_RE.fullmatch(acquisition_time):
        raise Refusal("acquisition_time_utc must be explicit UTC and separate from historical market time")
    try:
        dt.datetime.strptime(acquisition_time, "%Y-%m-%dT%H:%M:%SZ")
    except ValueError as exc:
        raise Refusal("acquisition_time_utc is not a valid UTC timestamp") from exc
    if scope.get("historical_market_time_basis") != "BROKER_SERVER_CLOCK":
        raise Refusal("historical market time basis must be BROKER_SERVER_CLOCK")
    if scope.get("replay_assumed_availability") != "UNKNOWN_NOT_PROVEN":
        raise Refusal("replay assumed availability must remain UNKNOWN_NOT_PROVEN")
    if scope.get("historical_as_of_availability") != "UNKNOWN_NOT_PROVEN":
        raise Refusal("historical as-of availability must remain UNKNOWN_NOT_PROVEN")
    if scope.get("causal_partitioning") != "NOT_IMPLEMENTED":
        raise Refusal("post-decision causal partitioning is unsupported and must remain NOT_IMPLEMENTED")

    clock = manifest.get("clock_contract")
    if not isinstance(clock, dict):
        raise Refusal("clock contract must be an object")
    _text(clock.get("clock_contract_id"), "clock_contract_id")
    allowed_clock_status = "FIXTURE_ONLY" if classification == "SYNTHETIC_FIXTURE" else "SOURCE_NAMED"
    if clock.get("status") != allowed_clock_status:
        raise Refusal(f"clock contract status must be {allowed_clock_status}")
    if clock.get("timezone_conversion") != "NONE_INFERRED":
        raise Refusal("clock contract cannot infer a local timezone conversion")
    if manifest.get("repeatability_claim") != "REVISED_HISTORY_REPEATABLE":
        raise Refusal("repeatability claim must be REVISED_HISTORY_REPEATABLE")

    artifacts = manifest.get("artifacts")
    if not isinstance(artifacts, list):
        raise Refusal("artifacts must be an array")
    expected_identities = {
        (symbol, window_id, role)
        for symbol in EXPECTED_UNIVERSE
        for window_id in EXPECTED_WINDOWS
        for role in REQUIRED_ARTIFACT_ROLES
    }
    observed_identities: set[tuple[str, str, str]] = set()
    observed_paths: set[str] = set()
    total_rows = 0
    for index, artifact in enumerate(artifacts):
        if not isinstance(artifact, dict):
            raise Refusal(f"artifact[{index}] must be an object")
        role = _text(artifact.get("role"), f"artifact[{index}].role")
        if role not in REQUIRED_ARTIFACT_ROLES:
            raise Refusal("artifact identity set contains unsupported role; A2 receipts are not raw payload")
        symbol = _text(artifact.get("logical_symbol"), f"artifact[{index}].logical_symbol")
        broker_symbol = _text(artifact.get("broker_symbol"), f"artifact[{index}].broker_symbol")
        window_id = _text(artifact.get("window_id"), f"artifact[{index}].window_id")
        identity = (symbol, window_id, role)
        if identity in observed_identities:
            raise Refusal(f"duplicate artifact identity: {identity}")
        observed_identities.add(identity)
        if broker_symbol != symbol:
            raise Refusal("artifact broker symbol violates exact-name mapping")
        expected_interval = EXPECTED_WINDOWS.get(window_id)
        if expected_interval is None or artifact.get("requested_interval") != expected_interval:
            raise Refusal("artifact interval is unknown, overlapping, or not the frozen half-open window")
        relative = _safe_relative_path(artifact.get("path"))
        path_key = relative.casefold()
        if path_key in observed_paths:
            raise Refusal(f"duplicate artifact path: {relative}")
        observed_paths.add(path_key)
        resolved = _resolve_artifact(manifest_path.parent, relative)
        expected_size = _strict_int(artifact.get("size_bytes"), "size_bytes")
        if resolved.stat().st_size != expected_size:
            raise Refusal(f"size mismatch for {relative}")
        expected_hash = _sha256(artifact.get("sha256"), f"sha256 for {relative}")
        actual_hash = _sha256_file(resolved)
        if actual_hash != expected_hash:
            raise Refusal(f"sha256 mismatch for {relative}: expected {expected_hash}, actual {actual_hash}")
        rows = _read_jsonl(resolved)
        if len(rows) != _strict_int(artifact.get("record_count"), "record_count", minimum=1):
            raise Refusal(f"record_count mismatch for {relative}")
        previous_time: str | None = None
        for row in rows:
            market_time = _validate_row(row, artifact, source, classification)
            if previous_time is not None and market_time <= previous_time:
                raise Refusal(f"non-increasing or duplicate market time in {relative}")
            previous_time = market_time
        total_rows += len(rows)
    if observed_identities != expected_identities:
        missing = sorted(expected_identities - observed_identities)
        extra = sorted(observed_identities - expected_identities)
        raise Refusal(f"artifact identity set mismatch; missing={missing}; extra={extra}")
    return {
        "classification": classification,
        "artifact_count": len(artifacts),
        "raw_record_count": total_rows,
        "source_identity": source,
        "manifest_id": manifest["manifest_id"],
    }


def preflight(
    manifest_path: Path,
    expected_manifest_sha256: str,
    preregistration_path: Path,
) -> dict[str, Any]:
    expected_hash = _sha256(expected_manifest_sha256, "expected_manifest_sha256")
    if _is_reparse(manifest_path):
        raise Refusal(f"raw artifact manifest cannot be a reparse path: {manifest_path}")
    try:
        actual_hash = _sha256_file(manifest_path)
    except FileNotFoundError as exc:
        raise Refusal(f"raw artifact manifest missing: {manifest_path}") from exc
    if actual_hash != expected_hash:
        raise Refusal(
            f"manifest sha256 mismatch: expected {expected_hash}, actual {actual_hash}"
        )
    preregistration = read_json(preregistration_path)
    plan = build_plan(preregistration)
    manifest = read_json(manifest_path)
    observed = _validate_raw_manifest(manifest, manifest_path.resolve(strict=True), plan)
    fixture = observed["classification"] == "SYNTHETIC_FIXTURE"
    return {
        "schema": PREFLIGHT_SCHEMA,
        "status": "VALIDATED_FIXTURE_INPUT" if fixture else "RAW_ARTIFACT_INTEGRITY_VALIDATED",
        "manifest_id": observed["manifest_id"],
        "manifest_sha256": actual_hash,
        "classification": observed["classification"],
        "artifact_count": observed["artifact_count"],
        "raw_record_count": observed["raw_record_count"],
        "source_identity": observed["source_identity"],
        "raw_quote_payload_present": True,
        "a2_receipts_treated_as_quote_stream": False,
        "repeatability_claim": "REVISED_HISTORY_REPEATABLE",
        "exchange_completeness_claim": None,
        "historical_as_of_availability": "UNKNOWN_NOT_PROVEN",
        "real_data_qualified": False,
        "execution_allowed": False,
        "performance_assessment": None,
        "unresolved_gates": [
            "RAW_HISTORY_QUALIFICATION_REVIEW_REQUIRED",
            "HISTORICAL_SEAM_CONSUMER_NOT_IMPLEMENTED",
            "SIGNAL_INPUT_FIDELITY_UNQUALIFIED",
            "EXECUTION_SEMANTICS_REQUIRED",
            "MODEL4_NOT_RUN",
        ],
        "authority": "RAW_ARTIFACT_INTEGRITY_PREFLIGHT_ONLY",
    }


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    plan_parser = subparsers.add_parser("plan", help="freeze the deterministic 72-cell NOT_RUN plan")
    plan_parser.add_argument("--preregistration", required=True, type=Path)
    plan_parser.add_argument("--out", required=True, type=Path)
    request_parser = subparsers.add_parser("request", help="build an inert raw-history acquisition request")
    request_parser.add_argument("--plan", required=True, type=Path)
    request_parser.add_argument("--broker", required=True)
    request_parser.add_argument("--server", required=True)
    request_parser.add_argument("--terminal-build", required=True, type=int)
    request_parser.add_argument("--out", required=True, type=Path)
    preflight_parser = subparsers.add_parser("preflight", help="verify a frozen raw artifact manifest and rows")
    preflight_parser.add_argument("--manifest", required=True, type=Path)
    preflight_parser.add_argument("--expected-manifest-sha256", required=True)
    preflight_parser.add_argument("--preregistration", required=True, type=Path)
    preflight_parser.add_argument("--out", required=True, type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        if args.command == "plan":
            result = build_plan(read_json(args.preregistration))
        elif args.command == "request":
            result = build_acquisition_request(
                read_json(args.plan),
                broker=args.broker,
                server=args.server,
                terminal_build=args.terminal_build,
            )
        else:
            result = preflight(
                args.manifest,
                args.expected_manifest_sha256,
                args.preregistration,
            )
        write_json(args.out, result)
        print(json.dumps({"status": result.get("status", "PASS"), "output": str(args.out)}, sort_keys=True))
        return 0
    except (OSError, Refusal) as exc:
        blocked = {
            "schema": PREFLIGHT_SCHEMA if args.command == "preflight" else "ofp_historical_cli_result/v1",
            "status": "BLOCKED",
            "operation": args.command,
            "error": str(exc),
            "execution_allowed": False,
            "authority": "RESEARCH_PREPARATION_ONLY",
        }
        try:
            write_json(args.out, blocked)
        except OSError:
            pass
        print(json.dumps(blocked, ensure_ascii=False, sort_keys=True), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
