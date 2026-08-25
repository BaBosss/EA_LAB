# -*- coding: utf-8 -*-
"""Deterministic Home/Window/Run identity for the Factory vNext sidecar MVP.

This module is intentionally non-authoritative. It creates evidence identities only; it never
changes current Factory verdict, optimization, deployment, risk or LIVE authority.
"""
from __future__ import annotations

import datetime as _dt
import hashlib
import json
import os
import re
from typing import Any, Dict, Iterable, Mapping, Optional

from . import FROZEN_DESIGN_SHA, NON_AUTHORITATIVE, SIDE_CAR_SCHEMA_VERSION


class ContractError(ValueError):
    pass


WINDOW_CLASSES = ("DISCOVERY", "COMMON_VALIDATION", "EXTENDED_VALIDATION")
EVIDENCE_LABELS = (
    "MEASURED", "DERIVED", "SIMULATED", "INFERRED", "UNTESTED", "UNAVAILABLE",
)

def canonical_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def sha256_bytes(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def stable_id(prefix: str, value: Mapping[str, Any], hex_chars: int = 20) -> str:
    digest = sha256_bytes(canonical_json(dict(value)).encode("utf-8"))[:hex_chars]
    return "%s-%s" % (prefix, digest)


def _need_text(value: Any, name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ContractError("%s is required" % name)
    return value.strip()


def _iso_date(value: str, name: str) -> str:
    text = _need_text(value, name)
    try:
        _dt.date.fromisoformat(text)
    except ValueError as exc:
        raise ContractError("%s must be YYYY-MM-DD" % name) from exc
    return text

def make_home_contract(
    concept_id: str,
    strategy_version: str,
    logical_symbol: str,
    execution_tf: str,
    context_architecture: Optional[Mapping[str, Any]] = None,
) -> Dict[str, Any]:
    concept = _need_text(concept_id, "ConceptID")
    version = _need_text(strategy_version, "StrategyVersion")
    logical = _need_text(logical_symbol, "LogicalSymbol").upper()
    tf = _need_text(execution_tf, "ExecutionTF").upper()
    if not re.match(r"^(M1|M2|M3|M4|M5|M6|M10|M12|M15|M20|M30|H1|H2|H3|H4|H6|H8|H12|D1|W1|MN1)$", tf):
        raise ContractError("unsupported ExecutionTF %r" % tf)
    key = {"ConceptID": concept, "LogicalSymbol": logical, "ExecutionTF": tf}
    result = {
        "schema_version": "factory-vnext-home-v1",
        "ConceptID": concept,
        "StrategyVersion": version,
        "LogicalSymbol": logical,
        "ExecutionTF": tf,
        "ContextArchitecture": dict(context_architecture or {}),
        "HomeContractID": stable_id("HOME", key),
        "authority": "NON_AUTHORITATIVE_SIDECAR",
    }
    validate_home_contract(result)
    return result


def validate_home_contract(home: Mapping[str, Any]) -> None:
    required = ("ConceptID", "StrategyVersion", "LogicalSymbol", "ExecutionTF", "HomeContractID")
    for name in required:
        _need_text(home.get(name), name)
    expected = stable_id("HOME", {
        "ConceptID": home["ConceptID"],
        "LogicalSymbol": str(home["LogicalSymbol"]).upper(),
        "ExecutionTF": str(home["ExecutionTF"]).upper(),
    })
    if home["HomeContractID"] != expected:
        raise ContractError("HomeContractID does not match Concept/LogicalSymbol/ExecutionTF")

def make_window_contract(
    window_class: str,
    start_date: str,
    end_date: str,
    execution_tf: str,
    *,
    bars: Optional[int] = None,
    signals: Optional[int] = None,
    outcomes: Optional[int] = None,
    outcome_unit: str = "trades",
) -> Dict[str, Any]:
    wc = _need_text(window_class, "WindowClass").upper()
    if wc not in WINDOW_CLASSES:
        raise ContractError("WindowClass must be one of %s" % (WINDOW_CLASSES,))
    start = _iso_date(start_date, "StartDate")
    end = _iso_date(end_date, "EndDate")
    if start > end:
        raise ContractError("StartDate must be <= EndDate")
    tf = _need_text(execution_tf, "ExecutionTF").upper()
    key = {"WindowClass": wc, "StartDate": start, "EndDate": end, "ExecutionTF": tf}
    result = {
        "schema_version": "factory-vnext-window-v1",
        **key,
        "WindowContractID": stable_id("WIN", key),
        "Coverage": {
            "execution_bars": bars,
            "signals": signals,
            "independent_outcomes": outcomes,
            "outcome_unit": outcome_unit,
        },
    }
    validate_window_contract(result)
    return result


def validate_window_contract(window: Mapping[str, Any]) -> None:
    for name in ("WindowClass", "StartDate", "EndDate", "ExecutionTF", "WindowContractID"):
        _need_text(window.get(name), name)
    if window["WindowClass"] not in WINDOW_CLASSES:
        raise ContractError("invalid WindowClass")
    if window["StartDate"] > window["EndDate"]:
        raise ContractError("window dates are reversed")
    key = {k: window[k] for k in ("WindowClass", "StartDate", "EndDate", "ExecutionTF")}
    if window["WindowContractID"] != stable_id("WIN", key):
        raise ContractError("WindowContractID does not match its window fields")

def make_parameter_set(parameters: Mapping[str, Any], profile_id: str) -> Dict[str, Any]:
    profile = _need_text(profile_id, "ProfileID")
    snapshot = {str(k): parameters[k] for k in sorted(parameters)}
    raw = canonical_json(snapshot).encode("utf-8")
    digest = sha256_bytes(raw)
    return {
        "schema_version": "factory-vnext-parameter-set-v1",
        "ProfileID": profile,
        "ParameterSetID": "PARAM-%s" % digest[:20],
        "parameter_snapshot_sha256": digest,
        "parameters": snapshot,
    }


def artifact_ref(path: str, *, root: Optional[str] = None, label: str = "MEASURED") -> Dict[str, Any]:
    if label not in EVIDENCE_LABELS:
        raise ContractError("invalid evidence label %r" % label)
    full = os.path.abspath(path)
    rel = os.path.relpath(full, os.path.abspath(root)) if root else full
    if not os.path.isfile(full):
        raise ContractError("artifact does not exist: %s" % full)
    return {
        "path": rel.replace("\\", "/"),
        "sha256": sha256_file(full),
        "bytes": os.path.getsize(full),
        "evidence_label": label,
    }


def home_match_status(home: Mapping[str, Any], logical_symbol: str, execution_tf: str) -> str:
    validate_home_contract(home)
    if str(home["LogicalSymbol"]).upper() != str(logical_symbol).upper():
        return "OUTSIDE_VALIDATED_CONTRACT"
    if str(home["ExecutionTF"]).upper() != str(execution_tf).upper():
        return "OUTSIDE_VALIDATED_CONTRACT"
    return "INSIDE_VALIDATED_CONTRACT"

def make_run_manifest(
    *,
    source_commit: str,
    home: Mapping[str, Any],
    window: Mapping[str, Any],
    profile_id: str,
    parameter_set: Mapping[str, Any],
    physical_symbol: str,
    broker_data: str,
    tester_model: str,
    runtime_seconds: Optional[float] = None,
    bars: Optional[int] = None,
    artifacts: Optional[Iterable[Mapping[str, Any]]] = None,
) -> Dict[str, Any]:
    validate_home_contract(home)
    validate_window_contract(window)
    if home["ExecutionTF"] != window["ExecutionTF"]:
        raise ContractError("Home and Window ExecutionTF mismatch")
    commit = _need_text(source_commit, "source_commit")
    if not re.match(r"^[0-9a-f]{40}$", commit):
        raise ContractError("source_commit must be a 40-hex git SHA")
    profile = _need_text(profile_id, "ProfileID")
    if parameter_set.get("ProfileID") != profile:
        raise ContractError("ParameterSet ProfileID mismatch")
    physical = _need_text(physical_symbol, "PhysicalSymbol")
    broker = _need_text(broker_data, "BrokerDataEnvironment")
    tester = _need_text(tester_model, "TesterModel")
    identity = {
        "source_commit": commit,
        "HomeContractID": home["HomeContractID"],
        "WindowContractID": window["WindowContractID"],
        "ProfileID": profile,
        "ParameterSetID": parameter_set.get("ParameterSetID"),
        "PhysicalSymbol": physical,
        "BrokerDataEnvironment": broker,
        "TesterModel": tester,
    }
    run_id = stable_id("RUN", identity, hex_chars=24)
    manifest = {
        "schema_version": SIDE_CAR_SCHEMA_VERSION,
        "authority": "NON_AUTHORITATIVE_SIDECAR",
        "frozen_design_sha": FROZEN_DESIGN_SHA,
        "RunID": run_id,
        **identity,
        "ConceptID": home["ConceptID"],
        "StrategyVersion": home["StrategyVersion"],
        "LogicalSymbol": home["LogicalSymbol"],
        "PhysicalSymbol": physical,
        "ExecutionTF": home["ExecutionTF"],
        "ContextArchitecture": dict(home.get("ContextArchitecture") or {}),
        "WindowClass": window["WindowClass"],
        "StartDate": window["StartDate"],
        "EndDate": window["EndDate"],
        "BrokerDataEnvironment": broker,
        "TesterModel": tester,
        "bars": bars,
        "runtime_seconds": runtime_seconds,
        "parameter_snapshot_sha256": parameter_set.get("parameter_snapshot_sha256"),
        "artifacts": [dict(x) for x in (artifacts or [])],
    }
    validate_run_manifest(manifest)
    return manifest


def validate_run_manifest(manifest: Mapping[str, Any]) -> None:
    if manifest.get("authority") != "NON_AUTHORITATIVE_SIDECAR" or not NON_AUTHORITATIVE:
        raise ContractError("run manifest authority boundary is missing")
    for name in ("RunID", "HomeContractID", "WindowContractID", "ProfileID", "ParameterSetID",
                 "LogicalSymbol", "PhysicalSymbol", "ExecutionTF", "source_commit",
                 "BrokerDataEnvironment", "TesterModel"):
        _need_text(manifest.get(name), name)
    expected = stable_id("RUN", {
        "source_commit": manifest["source_commit"],
        "HomeContractID": manifest["HomeContractID"],
        "WindowContractID": manifest["WindowContractID"],
        "ProfileID": manifest["ProfileID"],
        "ParameterSetID": manifest["ParameterSetID"],
        "PhysicalSymbol": manifest["PhysicalSymbol"],
        "BrokerDataEnvironment": manifest["BrokerDataEnvironment"],
        "TesterModel": manifest["TesterModel"],
    }, hex_chars=24)
    if manifest["RunID"] != expected:
        raise ContractError("RunID does not match immutable identity chain")


def windows_rank_comparable(left: Mapping[str, Any], right: Mapping[str, Any]) -> bool:
    validate_window_contract(left)
    validate_window_contract(right)
    return left["WindowContractID"] == right["WindowContractID"]
