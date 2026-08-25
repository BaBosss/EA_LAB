# -*- coding: utf-8 -*-
"""Deterministic grade/confidence evidence scaffold for Factory vNext.

This sidecar is intentionally non-authoritative. It records evidence only and
never manufactures final verdicts, grades, build potential, risk capacity, or
deployment semantics from provisional policy.
"""
from __future__ import annotations

import hashlib
import json
from typing import Any, Dict, Iterable, List, Mapping, Optional, Sequence, Tuple

from . import NON_AUTHORITATIVE
from .derived_metrics import DerivedMetricsError, validate_metric_bundle


class GradeConfidenceError(ValueError):
    pass


SCHEMA_VERSION = "factory-vnext-grade-confidence-v1"
AUTHORITY = "NON_AUTHORITATIVE_SIDECAR"
TOP_LEVEL_AXES = ("VERDICT", "QUALITY_GRADE", "EVIDENCE_CONFIDENCE", "BUILD_POTENTIAL")
HOME_STATUSES = ("INSIDE_VALIDATED_CONTRACT", "OUTSIDE_VALIDATED_CONTRACT")
CORE_CATEGORIES = (
    "Edge",
    "Parameter Stability",
    "Regime Robustness",
    "Risk/Tail",
    "Execution Robustness",
    "Broker Portability",
)
OPTIONAL_CATEGORIES = ("Recovery/Hedge Safety",)
KINT_001_STATE = "OPEN"

_CATEGORY_HINTS: Dict[str, Tuple[str, ...]] = {
    "Edge": (),
    "Parameter Stability": (),
    "Regime Robustness": (),
    "Risk/Tail": ("trade.mae.sum", "trade.giveback.sum", "trade.holding_seconds.sum"),
    "Execution Robustness": (),
    "Broker Portability": (),
    "Recovery/Hedge Safety": (),
}


def _need_text(value: Any, name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise GradeConfidenceError("%s is required" % name)
    return value.strip()


def _canonical_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def _stable_id(prefix: str, payload: Mapping[str, Any], hex_chars: int = 24) -> str:
    digest = hashlib.sha256(_canonical_json(dict(payload)).encode("utf-8")).hexdigest()[:hex_chars]
    return "%s-%s" % (prefix, digest)


def _validate_metric_sources(metric_bundle: Mapping[str, Any]) -> Tuple[str, str, str]:
    if not isinstance(metric_bundle, Mapping):
        raise GradeConfidenceError("metric_bundle must be a mapping")
    try:
        validate_metric_bundle(metric_bundle)
    except DerivedMetricsError as exc:
        raise GradeConfidenceError(str(exc)) from exc
    run_id = _need_text(metric_bundle.get("RunID"), "RunID")
    variant_id = _need_text(metric_bundle.get("VariantID"), "VariantID")
    bundle_id = _need_text(metric_bundle.get("MetricBundleID"), "MetricBundleID")
    return run_id, variant_id, bundle_id


def _flatten_metrics(metric_bundle: Mapping[str, Any]) -> List[Mapping[str, Any]]:
    sections = metric_bundle.get("sections")
    if not isinstance(sections, Mapping):
        raise GradeConfidenceError("metric_bundle.sections must be a mapping")
    metrics: List[Mapping[str, Any]] = []
    for section_name in ("Overview", "TradeDiagnostic", "Optimization"):
        section = sections.get(section_name, [])
        if not isinstance(section, list):
            raise GradeConfidenceError("metric_bundle section %s must be a list" % section_name)
        metrics.extend(section)
    return metrics


def _normalize_sources(metrics: Iterable[Mapping[str, Any]], category: str) -> Tuple[List[str], List[str]]:
    hints = _CATEGORY_HINTS.get(category, ())
    source_metric_ids: List[str] = []
    source_event_ids: List[str] = []
    for metric in metrics:
        metric_id = _need_text(metric.get("MetricID"), "MetricID")
        metric_name = str(metric.get("Name") or "")
        haystack = "%s %s" % (metric_id.lower(), metric_name.lower())
        usable = metric.get("Value") is not None and str(metric.get("Status") or "").upper() not in {"UNTESTED", "UNAVAILABLE", "N/A"}
        if usable and any(hint.lower() in haystack for hint in hints):
            source_metric_ids.append(metric_id)
            source_event_ids.extend(
                event_id for event_id in (metric.get("source_event_ids") or []) if isinstance(event_id, str) and event_id.strip()
            )
    return sorted(set(source_metric_ids)), sorted(set(source_event_ids))


def _evidence_status(source_metric_ids: Sequence[str], source_event_ids: Sequence[str]) -> str:
    # Evidence presence does not imply a ratified category assessment. Until the
    # numeric/status policy is ratified, every active category remains UNTESTED.
    return "UNTESTED"


def _category_record(
    category: str,
    metrics: Sequence[Mapping[str, Any]],
    *,
    mandatory: bool,
    active: bool,
) -> Dict[str, Any]:
    source_metric_ids, source_event_ids = _normalize_sources(metrics, category)
    if not active:
        return {
            "Category": category,
            "Status": "N/A",
            "WHY": "Category not mandatory for this run",
            "ACTION": "Leave as N/A unless recovery/hedge evidence becomes active",
            "source_metric_ids": [],
            "source_event_ids": [],
        }
    status = _evidence_status(source_metric_ids, source_event_ids)
    why = "Mapped only from exact metrics present" if source_metric_ids else "No exact metrics for this category were present"
    action = "Add exact source metrics for %s" % category if source_metric_ids else "Emit exact metrics for %s to make this category visible" % category
    return {
        "Category": category,
        "Status": status,
        "WHY": why,
        "ACTION": action,
        "source_metric_ids": source_metric_ids,
        "source_event_ids": source_event_ids,
    }


def _critical_floor_placeholders() -> Dict[str, Any]:
    return {
        "sample_adequacy_floor": None,
        "meaningful_improvement_floor": None,
        "critical_floor_algorithm": None,
        "note": "PROVISIONAL: KINT-001 remains OPEN; numeric floor policy is not ratified here",
    }


def build_grade_evidence(
    metric_bundle: Mapping[str, Any],
    *,
    home_status: str,
    recovery_active: bool = False,
    hedge_active: bool = False,
) -> Dict[str, Any]:
    run_id, variant_id, bundle_id = _validate_metric_sources(metric_bundle)
    status = _need_text(home_status, "home_status").upper()
    if status not in HOME_STATUSES:
        raise GradeConfidenceError("home_status must be INSIDE_VALIDATED_CONTRACT or OUTSIDE_VALIDATED_CONTRACT")

    metrics = _flatten_metrics(metric_bundle)
    top_level = {axis: None for axis in TOP_LEVEL_AXES}
    category_records = [
        _category_record(category, metrics, mandatory=True, active=True)
        for category in CORE_CATEGORIES
    ]
    category_records.append(_category_record("Recovery/Hedge Safety", metrics, mandatory=False, active=(recovery_active or hedge_active)))
    category_records = sorted(category_records, key=lambda item: item["Category"])

    payload = {
        "RunID": run_id,
        "VariantID": variant_id,
        "MetricBundleID": bundle_id,
        "home_status": status,
        "top_level": top_level,
        "category_records": category_records,
        "critical_floor_placeholders": _critical_floor_placeholders(),
        "KINT_001": {"state": KINT_001_STATE},
        "authority": AUTHORITY,
    }
    grade_evidence_id = _stable_id("GEV", payload)

    record = {
        "schema_version": SCHEMA_VERSION,
        "authority": AUTHORITY,
        "RunID": run_id,
        "VariantID": variant_id,
        "MetricBundleID": bundle_id,
        "GradeEvidenceID": grade_evidence_id,
        "home_status": status,
        "top_level": top_level,
        "category_records": category_records,
        "critical_floor_placeholders": _critical_floor_placeholders(),
        "KINT_001": {"state": KINT_001_STATE},
    }
    if status == "OUTSIDE_VALIDATED_CONTRACT":
        for axis in TOP_LEVEL_AXES:
            record["top_level"][axis] = None
    validate_grade_evidence(record)
    return record


def validate_grade_evidence(record: Mapping[str, Any]) -> None:
    if record.get("authority") != AUTHORITY or not NON_AUTHORITATIVE:
        raise GradeConfidenceError("grade evidence authority boundary is missing")
    for name in ("RunID", "VariantID", "MetricBundleID", "GradeEvidenceID", "home_status"):
        _need_text(record.get(name), name)
    if record["home_status"] not in HOME_STATUSES:
        raise GradeConfidenceError("invalid home_status")
    top_level = record.get("top_level")
    if not isinstance(top_level, Mapping):
        raise GradeConfidenceError("top_level must be a mapping")
    for axis in TOP_LEVEL_AXES:
        if axis not in top_level:
            raise GradeConfidenceError("missing top level axis %s" % axis)
        if top_level[axis] is not None:
            raise GradeConfidenceError("top level axis %s must remain null while policy is provisional" % axis)
    categories = record.get("category_records")
    if not isinstance(categories, list):
        raise GradeConfidenceError("category_records must be a list")
    seen = [item.get("Category") for item in categories]
    if seen != sorted(seen):
        raise GradeConfidenceError("category_records must be sorted by Category")
    for entry in categories:
        _need_text(entry.get("Category"), "Category")
        _need_text(entry.get("Status"), "Status")
        _need_text(entry.get("WHY"), "WHY")
        _need_text(entry.get("ACTION"), "ACTION")
        for name in ("source_metric_ids", "source_event_ids"):
            values = entry.get(name)
            if not isinstance(values, list):
                raise GradeConfidenceError("%s must be a list" % name)
            for value in values:
                _need_text(value, name[:-1])
    cf = record.get("critical_floor_placeholders")
    if not isinstance(cf, Mapping):
        raise GradeConfidenceError("critical_floor_placeholders must be a mapping")
    if record.get("KINT_001", {}).get("state") != KINT_001_STATE:
        raise GradeConfidenceError("KINT-001 state must remain OPEN")
    expected = _stable_id("GEV", {
        "RunID": record["RunID"],
        "VariantID": record["VariantID"],
        "MetricBundleID": record["MetricBundleID"],
        "home_status": record["home_status"],
        "top_level": dict(record["top_level"]),
        "category_records": [
            {
                "Category": entry["Category"],
                "Status": entry["Status"],
                "WHY": entry["WHY"],
                "ACTION": entry["ACTION"],
                "source_metric_ids": entry["source_metric_ids"],
                "source_event_ids": entry["source_event_ids"],
            }
            for entry in categories
        ],
        "critical_floor_placeholders": dict(cf),
        "KINT_001": {"state": record["KINT_001"]["state"]},
        "authority": record.get("authority"),
    })
    if record["GradeEvidenceID"] != expected:
        raise GradeConfidenceError("GradeEvidenceID does not match its contents")
    if record["home_status"] == "OUTSIDE_VALIDATED_CONTRACT":
        for axis in TOP_LEVEL_AXES:
            if record["top_level"].get(axis) is not None:
                raise GradeConfidenceError("outside-home record must keep all axes null")
