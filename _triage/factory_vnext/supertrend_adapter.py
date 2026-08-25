# -*- coding: utf-8 -*-
"""Factory vNext offline pilot adapter for the existing SuperTrendFlip rev05 baseline.

Non-authoritative sidecar per:
- docs/research/FACTORY_VNEXT_DESIGN_DRAFT.md @ FROZEN_DESIGN_SHA
- docs/research/FACTORY_VNEXT_MVP_PILOT_CONTRACT.md @ same SHA (see _triage/factory_vnext/__init__.py)

This adapter reads the existing accepted `(TRD)_SuperTrendFlip_rev05.mq5` source and the
existing accepted offline `STF_BTC_H4_rev05_off.set` preset, then wraps them in a
Home/Parameter identity built from `_triage/factory_vnext/contracts.py`. It does not parse
or reinterpret MQL5 strategy logic, does not change any preset value, and does not attach
MT5 or run the Strategy Tester. Source and preset files are treated as opaque, hash-tracked
artifacts; only the `.set` key/value rows are read, and only to snapshot them verbatim.
"""
from __future__ import annotations

import os
import re
from typing import Any, Dict, Mapping, Optional

from .contracts import (
    ContractError,
    artifact_ref,
    home_match_status,
    make_home_contract,
    make_parameter_set,
    validate_home_contract,
)


class SuperTrendAdapterError(ValueError):
    pass


# Pilot research identity — fixed per FACTORY_VNEXT_MVP_PILOT_CONTRACT.md section 2.
# Derived directly from the existing accepted source/preset naming, not invented.
CONCEPT_ID = "(TRD)_SuperTrendFlip"
STRATEGY_VERSION = "rev05"
LOGICAL_SYMBOL = "BTCUSD"
EXECUTION_TF = "H4"

SOURCE_REL_PATH = "ea_projects/(TRD)_SuperTrendFlip/(TRD)_SuperTrendFlip_rev05.mq5"
PRESET_REL_PATH = "_mt5_auto/ab_sets/genstanding_stf/STF_BTC_H4_rev05_off.set"

_EXPECTED_SOURCE_NAME = "(TRD)_SuperTrendFlip_rev05.mq5"
_EXPECTED_PRESET_NAME = "STF_BTC_H4_rev05_off.set"
_SOURCE_NAME_RE = re.compile(r"^\(TRD\)_SuperTrendFlip_rev05\.mq5$")
_PRESET_NAME_RE = re.compile(r"^STF_BTC_H4_rev05_off\.set$")


def _resolve_path(repo_root: str, rel_path: str, override: Optional[str]) -> str:
    if override is not None:
        return os.path.abspath(override)
    return os.path.abspath(os.path.join(repo_root, *rel_path.split("/")))


def _read_text(path: str) -> str:
    with open(path, "r", encoding="utf-8-sig") as fh:
        return fh.read()


def _parse_preset_text(text: str, *, source_label: str) -> Dict[str, str]:
    """Parse a `.set` file's `key=value` rows verbatim (as strings).

    `;`-prefixed and blank lines are comments/whitespace, matching the accepted
    `.set` convention already used in this repo (see STF_BTC_H4_rev05_off.set header).
    No existing typed `.set` parser was found in this worktree to reuse, so values are
    preserved as raw strings rather than guessing a typed grammar.
    """
    snapshot: Dict[str, str] = {}
    for lineno, raw_line in enumerate(text.splitlines(), start=1):
        stripped = raw_line.strip()
        if not stripped or stripped.startswith(";"):
            continue
        if "=" not in stripped:
            raise SuperTrendAdapterError(
                "%s:%d malformed set row: %r" % (source_label, lineno, raw_line)
            )
        key, _, value = stripped.partition("=")
        key = key.strip()
        value = value.strip()
        if not key:
            raise SuperTrendAdapterError(
                "%s:%d malformed set row: %r" % (source_label, lineno, raw_line)
            )
        if key in snapshot:
            raise SuperTrendAdapterError("%s: duplicate preset key %r" % (source_label, key))
        snapshot[key] = value
    if not snapshot:
        raise SuperTrendAdapterError("%s: preset snapshot is empty" % source_label)
    return snapshot


def load_supertrend_pilot(
    repo_root: str,
    *,
    source_path: Optional[str] = None,
    preset_path: Optional[str] = None,
) -> Dict[str, Any]:
    """Build the non-authoritative SuperTrendFlip BTCUSD/H4 pilot descriptor.

    Reads the existing accepted rev05 source and the existing accepted offline
    BTCUSD/H4 preset (both fail-closed on missing/misnamed files), snapshots every
    preset parameter verbatim, and returns a NON_AUTHORITATIVE_SIDECAR record.

    `source_path`/`preset_path` let callers point at fixture copies for deterministic
    testing; both still fail closed if their basename drifts from the accepted rev05
    offline BTCUSD/H4 naming.
    """
    root = os.path.abspath(repo_root)
    resolved_source = _resolve_path(root, SOURCE_REL_PATH, source_path)
    resolved_preset = _resolve_path(root, PRESET_REL_PATH, preset_path)

    if not _SOURCE_NAME_RE.match(os.path.basename(resolved_source)):
        raise SuperTrendAdapterError(
            "source filename drift: expected %s, got %s"
            % (_EXPECTED_SOURCE_NAME, os.path.basename(resolved_source))
        )
    if not _PRESET_NAME_RE.match(os.path.basename(resolved_preset)):
        raise SuperTrendAdapterError(
            "preset filename drift: expected %s, got %s"
            % (_EXPECTED_PRESET_NAME, os.path.basename(resolved_preset))
        )
    if not os.path.isfile(resolved_source):
        raise SuperTrendAdapterError("SuperTrendFlip rev05 source not found: %s" % resolved_source)
    if not os.path.isfile(resolved_preset):
        raise SuperTrendAdapterError("SuperTrendFlip BTCUSD/H4 preset not found: %s" % resolved_preset)

    preset_text = _read_text(resolved_preset)
    snapshot = _parse_preset_text(preset_text, source_label=os.path.basename(resolved_preset))

    try:
        source_ref = artifact_ref(resolved_source, root=root, label="MEASURED")
        preset_ref = artifact_ref(resolved_preset, root=root, label="MEASURED")
    except ContractError as exc:
        raise SuperTrendAdapterError(str(exc)) from exc

    home = make_home_contract(CONCEPT_ID, STRATEGY_VERSION, LOGICAL_SYMBOL, EXECUTION_TF)

    # ProfileID is the existing preset's own filename stem — existing identity, not an
    # invented risk/profile label.
    profile_id = os.path.splitext(os.path.basename(resolved_preset))[0]
    try:
        parameter_set = make_parameter_set(snapshot, profile_id)
    except ContractError as exc:
        raise SuperTrendAdapterError(str(exc)) from exc

    record: Dict[str, Any] = {
        "schema_version": "factory-vnext-supertrend-adapter-v1",
        "authority": "NON_AUTHORITATIVE_SIDECAR",
        "ConceptID": home["ConceptID"],
        "StrategyVersion": home["StrategyVersion"],
        "LogicalSymbol": home["LogicalSymbol"],
        "ExecutionTF": home["ExecutionTF"],
        "HomeContract": home,
        "ProfileID": parameter_set["ProfileID"],
        "ParameterSet": parameter_set,
        "SourceRef": source_ref,
        "PresetRef": preset_ref,
    }
    validate_supertrend_pilot(record)
    return record


def validate_supertrend_pilot(record: Mapping[str, Any]) -> None:
    """Fail closed unless `record` is a well-formed BTCUSD/H4 SuperTrendFlip pilot record."""
    if record.get("authority") != "NON_AUTHORITATIVE_SIDECAR":
        raise SuperTrendAdapterError("pilot record authority boundary is missing")

    for name in ("ConceptID", "StrategyVersion", "LogicalSymbol", "ExecutionTF", "ProfileID"):
        value = record.get(name)
        if not isinstance(value, str) or not value.strip():
            raise SuperTrendAdapterError("%s is required" % name)

    home = record.get("HomeContract")
    if not isinstance(home, Mapping):
        raise SuperTrendAdapterError("HomeContract is required")
    validate_home_contract(home)

    status = home_match_status(home, LOGICAL_SYMBOL, EXECUTION_TF)
    if status != "INSIDE_VALIDATED_CONTRACT":
        raise SuperTrendAdapterError(
            "OUTSIDE_VALIDATED_CONTRACT: Home is not %s/%s" % (LOGICAL_SYMBOL, EXECUTION_TF)
        )
    if record.get("LogicalSymbol") != LOGICAL_SYMBOL or record.get("ExecutionTF") != EXECUTION_TF:
        raise SuperTrendAdapterError(
            "OUTSIDE_VALIDATED_CONTRACT: record LogicalSymbol/ExecutionTF does not match validated Home"
        )

    parameter_set = record.get("ParameterSet")
    if not isinstance(parameter_set, Mapping):
        raise SuperTrendAdapterError("ParameterSet is required")
    if parameter_set.get("ProfileID") != record.get("ProfileID"):
        raise SuperTrendAdapterError("ParameterSet ProfileID mismatch")
    snapshot = parameter_set.get("parameters")
    if not isinstance(snapshot, Mapping) or not snapshot:
        raise SuperTrendAdapterError("ParameterSet snapshot must not be empty")

    for ref_name in ("SourceRef", "PresetRef"):
        ref = record.get(ref_name)
        if not isinstance(ref, Mapping) or not ref.get("sha256") or not ref.get("path"):
            raise SuperTrendAdapterError("%s is required" % ref_name)
