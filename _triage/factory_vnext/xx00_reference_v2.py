# -*- coding: utf-8 -*-
"""Closed-structure xx-00 family reference sidecar.

Repository-only research/reference metadata. It never creates executable EA or runtime
bindings and does not infer legacy H01/config identity.
"""
from __future__ import annotations

from types import MappingProxyType
from typing import Any, Dict, Mapping

from .contracts import canonical_json, stable_id


class XX00ReferenceV2Error(ValueError):
    pass


SCHEMA_VERSION = "factory-vnext-xx00-reference-v2"
AUTHORITY = "NON_AUTHORITATIVE_SIDECAR"
SCOPE = "REPOSITORY_ONLY"
REFERENCE_ROLE = "RESEARCH_CONTROL_ONLY"
ATR_TIMEFRAME = "PERIOD_CURRENT"
STACK_MODE = "GRID_AGAINST"
STACK_DISTANCE_ATR = 2.0
STACK_CONFIRM = "DISTANCE"
GENERIC_EXIT = "ATR_BASED"
BASKET_STOP_KIND = "BASKET_BALANCE_STOP"
BASKET_STOP_PCT_CURRENT_BALANCE = 10.0
_FAMILY_NATIVE_MECHANICS = MappingProxyType({
    "B11": (),
    "B12": (),
    "B13": (),
    "B14": ("GRID_STACK", "LOG_POWER_PROGRESSION", "BASKET_TARGET_OWNERSHIP"),
    "B15": (),
    "B16": ("ADVERSE_ATR_GRID", "KANGAROO_LOT_LAW", "OWNED_BASKET_OVERLAP_EXITS"),
    "B17": ("WAVE1_STRUCTURAL_INVALIDATION_SL", "SINGLE_WHEN_STRUCTURAL"),
    "B18": (),
})
_FAMILY_NATIVE_EXIT = MappingProxyType({
    "B11": None,
    "B12": None,
    "B13": None,
    "B14": "BASKET_TARGET_OWNERSHIP",
    "B15": None,
    "B16": "OWNED_BASKET_OVERLAP_EXITS",
    "B17": None,
    "B18": None,
})

_TOP_FIELDS = {
    "schema_version", "authority", "scope", "reference_role", "FamilyReferenceID",
    "FamilyID", "LogicalVariantID", "ATR", "GenericBaseline", "NativeSemantics",
    "ExecutableBinding", "RuntimeBinding",
}
_ATR_FIELDS = {"timeframe", "period"}
_BASELINE_FIELDS = {
    "stack_mode", "stack_distance_atr", "stack_confirm", "exit_reference", "basket_protection",
}
_BASKET_FIELDS = {"kind", "pct_current_balance"}
_NATIVE_FIELDS = {"mechanics", "exit_concept", "parameterization_status"}

def _family_id(value: Any) -> str:
    if not isinstance(value, str) or value not in _FAMILY_NATIVE_MECHANICS:
        raise XX00ReferenceV2Error("FamilyID must be one of B11..B18")
    return value


def _logical_variant_id(value: Any, family_id: str) -> str:
    expected = f"{family_id}-00"
    if value != expected:
        raise XX00ReferenceV2Error(f"LogicalVariantID must equal {expected}")
    return expected


def _atr_period(value: Any) -> int:
    if type(value) is not int or value <= 0:
        raise XX00ReferenceV2Error("ATR.period must be a positive integer")
    return value


def _native_semantics(family_id: str) -> Dict[str, Any]:
    mechanics = list(_FAMILY_NATIVE_MECHANICS[family_id])
    return {
        "mechanics": mechanics,
        "exit_concept": _FAMILY_NATIVE_EXIT[family_id],
        "parameterization_status": "NONE" if not mechanics else "CONCEPT_RATIFIED_ONLY",
    }


def _generic_baseline() -> Dict[str, Any]:
    return {
        "stack_mode": STACK_MODE,
        "stack_distance_atr": STACK_DISTANCE_ATR,
        "stack_confirm": STACK_CONFIRM,
        "exit_reference": GENERIC_EXIT,
        "basket_protection": {
            "kind": BASKET_STOP_KIND,
            "pct_current_balance": BASKET_STOP_PCT_CURRENT_BALANCE,
        },
    }

def _id_payload(record: Mapping[str, Any]) -> Dict[str, Any]:
    return {
        key: record[key]
        for key in (
            "schema_version", "authority", "scope", "reference_role", "FamilyID",
            "LogicalVariantID", "ATR", "GenericBaseline", "NativeSemantics",
            "ExecutableBinding", "RuntimeBinding",
        )
    }


def make_xx00_reference_v2(*, family_id: str, logical_variant_id: str, atr_period: int) -> Dict[str, Any]:
    family = _family_id(family_id)
    logical = _logical_variant_id(logical_variant_id, family)
    period = _atr_period(atr_period)
    record: Dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "authority": AUTHORITY,
        "scope": SCOPE,
        "reference_role": REFERENCE_ROLE,
        "FamilyID": family,
        "LogicalVariantID": logical,
        "ATR": {"timeframe": ATR_TIMEFRAME, "period": period},
        "GenericBaseline": _generic_baseline(),
        "NativeSemantics": _native_semantics(family),
        "ExecutableBinding": False,
        "RuntimeBinding": False,
    }
    record["FamilyReferenceID"] = stable_id("XX00REF", _id_payload(record), hex_chars=24)
    validate_xx00_reference_v2(record)
    return record


def _require_mapping(value: Any, fields: set[str], name: str) -> Mapping[str, Any]:
    if not isinstance(value, Mapping) or set(value) != fields:
        raise XX00ReferenceV2Error(f"{name} fields do not match schema")
    return value

def validate_xx00_reference_v2(record: Mapping[str, Any]) -> None:
    top = _require_mapping(record, _TOP_FIELDS, "xx00 reference")
    if top.get("schema_version") != SCHEMA_VERSION:
        raise XX00ReferenceV2Error("unsupported schema_version")
    if top.get("authority") != AUTHORITY:
        raise XX00ReferenceV2Error("authority boundary is missing")
    if top.get("scope") != SCOPE:
        raise XX00ReferenceV2Error("scope must be REPOSITORY_ONLY")
    if top.get("reference_role") != REFERENCE_ROLE:
        raise XX00ReferenceV2Error("reference_role must be RESEARCH_CONTROL_ONLY")

    family = _family_id(top.get("FamilyID"))
    _logical_variant_id(top.get("LogicalVariantID"), family)

    atr = _require_mapping(top.get("ATR"), _ATR_FIELDS, "ATR")
    if atr.get("timeframe") != ATR_TIMEFRAME:
        raise XX00ReferenceV2Error("ATR.timeframe must be PERIOD_CURRENT")
    _atr_period(atr.get("period"))

    baseline = _require_mapping(top.get("GenericBaseline"), _BASELINE_FIELDS, "GenericBaseline")
    if baseline.get("stack_mode") != STACK_MODE:
        raise XX00ReferenceV2Error("GenericBaseline.stack_mode must be GRID_AGAINST")
    if type(baseline.get("stack_distance_atr")) is not float or baseline.get("stack_distance_atr") != STACK_DISTANCE_ATR:
        raise XX00ReferenceV2Error("GenericBaseline.stack_distance_atr must be 2.0")
    if baseline.get("stack_confirm") != STACK_CONFIRM:
        raise XX00ReferenceV2Error("GenericBaseline.stack_confirm must be DISTANCE")
    if baseline.get("exit_reference") != GENERIC_EXIT:
        raise XX00ReferenceV2Error("GenericBaseline.exit_reference must be ATR_BASED")
    basket = _require_mapping(baseline.get("basket_protection"), _BASKET_FIELDS, "GenericBaseline.basket_protection")
    if basket.get("kind") != BASKET_STOP_KIND:
        raise XX00ReferenceV2Error("basket protection kind must be BASKET_BALANCE_STOP")
    if type(basket.get("pct_current_balance")) is not float or basket.get("pct_current_balance") != BASKET_STOP_PCT_CURRENT_BALANCE:
        raise XX00ReferenceV2Error("basket protection percent must be 10.0 current balance")

    native = _require_mapping(top.get("NativeSemantics"), _NATIVE_FIELDS, "NativeSemantics")
    expected_native = _native_semantics(family)
    mechanics = native.get("mechanics")
    if not isinstance(mechanics, list) or mechanics != expected_native["mechanics"]:
        raise XX00ReferenceV2Error("NativeSemantics.mechanics must match owner-ratified family map")
    if native.get("exit_concept") != expected_native["exit_concept"]:
        raise XX00ReferenceV2Error("NativeSemantics.exit_concept must match owner-ratified family map")
    if native.get("parameterization_status") != expected_native["parameterization_status"]:
        raise XX00ReferenceV2Error("NativeSemantics.parameterization_status must match owner-ratified family map")

    if top.get("ExecutableBinding") is not False:
        raise XX00ReferenceV2Error("ExecutableBinding must be false")
    if top.get("RuntimeBinding") is not False:
        raise XX00ReferenceV2Error("RuntimeBinding must be false")

    expected_id = stable_id("XX00REF", _id_payload(top), hex_chars=24)
    if top.get("FamilyReferenceID") != expected_id:
        raise XX00ReferenceV2Error("FamilyReferenceID does not match canonical payload")


def serialize_xx00_reference_v2(record: Mapping[str, Any]) -> str:
    validate_xx00_reference_v2(record)
    return canonical_json(dict(record)) + "\n"
