# -*- coding: utf-8 -*-
"""Deterministic derived metrics for Factory vNext telemetry V1.

This sidecar is intentionally non-authoritative. It converts immutable raw
telemetry events into deterministic metric bundles for overview, trade
diagnostic, and optimization reporting without inventing missing evidence.
"""
from __future__ import annotations

from collections import Counter, defaultdict
import hashlib
import json
from typing import Any, Dict, Iterable, List, Mapping, Optional, Sequence

from . import NON_AUTHORITATIVE
from .telemetry import validate_event


class DerivedMetricsError(ValueError):
    pass


SECTION_ORDER = ("Overview", "TradeDiagnostic", "Optimization")
SOURCE_FAMILIES = ("SIGNAL_EVENTS", "TRADE_EVENTS", "CONTEXT_EVENTS", "OPTIMIZATION_PASSES")
TRADE_FIELDS = ("mfe", "mae", "holding_seconds", "giveback", "exit_reason")
OPT_FIELDS = ("pass_count", "runtime_seconds", "score", "surface_score")


def _need_text(value: Any, name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise DerivedMetricsError("%s is required" % name)
    return value.strip()


def _need_mapping(value: Any, name: str) -> Mapping[str, Any]:
    if not isinstance(value, Mapping):
        raise DerivedMetricsError("%s must be a mapping" % name)
    return value


def _is_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def _canonical_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def _stable_id(prefix: str, payload: Mapping[str, Any], hex_chars: int = 24) -> str:
    digest = hashlib.sha256(_canonical_json(dict(payload)).encode("utf-8")).hexdigest()[:hex_chars]
    return "%s-%s" % (prefix, digest)


def _status_for_count(count: int, evidence_label: str) -> str:
    if count == 0:
        return evidence_label if evidence_label in ("UNTESTED", "UNAVAILABLE") else "UNTESTED"
    return "DERIVED" if evidence_label == "DERIVED" else evidence_label


def _metric(
    metric_id: str,
    section: str,
    value: Any,
    status: str,
    why: str,
    action: str,
    source_event_ids: Sequence[str],
    *,
    evidence_label: str = "DERIVED",
    name: Optional[str] = None,
) -> Dict[str, Any]:
    return {
        "MetricID": metric_id,
        "Section": section,
        "Name": name or metric_id,
        "Value": value,
        "Status": status,
        "evidence_label": evidence_label,
        "WHY": why,
        "ACTION": action,
        "source_event_ids": sorted(source_event_ids),
    }


def _aggregate_numeric(values: Sequence[float]) -> Dict[str, Optional[float]]:
    if not values:
        return {"sum": None, "mean": None, "min": None, "max": None}
    total = float(sum(values))
    return {
        "sum": total,
        "mean": total / len(values),
        "min": min(values),
        "max": max(values),
    }


def _validate_numeric_field(payload: Mapping[str, Any], field: str, event_id: str) -> Optional[float]:
    if field not in payload:
        return None
    value = payload[field]
    if not _is_number(value):
        raise DerivedMetricsError("payload field %r on %s must be numeric" % (field, event_id))
    return float(value)


def derive_metric_bundle(events: Iterable[Mapping[str, Any]]) -> Dict[str, Any]:
    validated: List[Dict[str, Any]] = []
    run_ids = set()
    variant_ids = set()
    for raw in events:
        event = dict(raw)
        validate_event(event)
        validated.append(event)
        run_ids.add(event["RunID"])
        variant_ids.add(event["VariantID"])
    if len(run_ids) != 1 or len(variant_ids) != 1:
        raise DerivedMetricsError("metric bundle must contain exactly one RunID and one VariantID")
    run_id = next(iter(run_ids))
    variant_id = next(iter(variant_ids))

    by_family: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
    for event in validated:
        by_family[event["EventFamily"]].append(event)
    for family in SOURCE_FAMILIES:
        by_family.setdefault(family, [])

    overview = _derive_overview(by_family)
    trade = _derive_trade_diagnostic(by_family["TRADE_EVENTS"])
    optimization = _derive_optimization(by_family["OPTIMIZATION_PASSES"])
    sections = {
        "Overview": overview,
        "TradeDiagnostic": trade,
        "Optimization": optimization,
    }
    machine_metrics = [
        {
            "Section": metric["Section"],
            "MetricID": metric["MetricID"],
            "Value": metric["Value"],
            "Status": metric["Status"],
            "evidence_label": metric["evidence_label"],
            "source_event_ids": metric["source_event_ids"],
        }
        for section in SECTION_ORDER
        for metric in sections[section]
    ]
    bundle = {
        "schema_version": "factory-vnext-derived-metrics-v1",
        "authority": "NON_AUTHORITATIVE_SIDECAR",
        "RunID": run_id,
        "VariantID": variant_id,
        "MetricBundleID": _stable_id("MBL", {
            "RunID": run_id,
            "VariantID": variant_id,
            "metrics": machine_metrics,
        }),
        "sections": sections,
    }
    validate_metric_bundle(bundle)
    return bundle


def _derive_overview(by_family: Mapping[str, Sequence[Mapping[str, Any]]]) -> List[Dict[str, Any]]:
    metrics: List[Dict[str, Any]] = []
    all_events = [event for family in SOURCE_FAMILIES for event in by_family.get(family, [])]
    families = ("SIGNAL_EVENTS", "TRADE_EVENTS", "CONTEXT_EVENTS", "OPTIMIZATION_PASSES", "BASKET_EVENTS", "HEDGE_EVENTS")
    for family in families:
        family_events = list(by_family.get(family, []))
        count = len(family_events)
        evidence = "UNTESTED" if family in ("SIGNAL_EVENTS", "TRADE_EVENTS", "CONTEXT_EVENTS", "OPTIMIZATION_PASSES") else "UNAVAILABLE"
        if count:
            labels = sorted({event["EvidenceLabel"] for event in family_events})
            evidence = labels[0] if len(labels) == 1 else "MIXED"
        metrics.append(_metric(
            "overview.%s.count" % family.lower(),
            "Overview",
            count,
            _status_for_count(count, evidence),
            "Counts raw %s evidence for the bundle" % family,
            "Add raw events or accept UNTESTED/UNAVAILABLE when none exist",
            [event["EventID"] for event in family_events],
            evidence_label=evidence,
        ))
    metrics.append(_metric(
        "overview.total_event_count",
        "Overview",
        len(all_events),
        "DERIVED" if all_events else "UNTESTED",
        "Total raw event count across observable families",
        "Add telemetry events if this should be higher",
        [event["EventID"] for event in all_events],
    ))
    return sorted(metrics, key=lambda item: item["MetricID"])


def _derive_trade_diagnostic(events: Sequence[Mapping[str, Any]]) -> List[Dict[str, Any]]:
    metrics: List[Dict[str, Any]] = []
    values_by_field: Dict[str, List[float]] = {field: [] for field in TRADE_FIELDS if field != "exit_reason"}
    exit_reasons: Counter[str] = Counter()
    source_ids: Dict[str, List[str]] = {field: [] for field in TRADE_FIELDS if field != "exit_reason"}
    exit_source_ids: List[str] = []
    for event in events:
        payload = _need_mapping(event.get("payload"), "payload")
        for field in ("mfe", "mae", "holding_seconds", "giveback"):
            value = _validate_numeric_field(payload, field, event["EventID"])
            if value is not None:
                values_by_field[field].append(value)
                source_ids[field].append(event["EventID"])
        if "exit_reason" in payload:
            reason = payload["exit_reason"]
            if not isinstance(reason, str) or not reason.strip():
                raise DerivedMetricsError("payload field 'exit_reason' on %s must be a string" % event["EventID"])
            exit_reasons[reason.strip()] += 1
            exit_source_ids.append(event["EventID"])
    for field in ("mfe", "mae", "holding_seconds", "giveback"):
        values = values_by_field[field]
        agg = _aggregate_numeric(values)
        metrics.append(_metric(
            "trade.%s.%s" % (field, "sum"),
            "TradeDiagnostic",
            agg["sum"],
            "DERIVED" if values else "UNAVAILABLE",
            "Derived from exact payload key %r across TRADE_EVENTS" % field,
            "Add exact payload %r values to measure this diagnostic" % field,
            source_ids[field],
        ))
    for reason, count in sorted(exit_reasons.items()):
        metrics.append(_metric(
            "trade.exit_reason.%s" % reason,
            "TradeDiagnostic",
            count,
            "DERIVED",
            "Counts exact payload key 'exit_reason' occurrences",
            "Add more TRADE_EVENTS if this exit reason should be represented further",
            exit_source_ids,
        ))
    if not exit_reasons:
        metrics.append(_metric(
            "trade.exit_reason.unavailable",
            "TradeDiagnostic",
            None,
            "UNAVAILABLE",
            "No exact exit_reason payload keys were present",
            "Emit exact exit_reason payload values to enable exit attribution",
            [],
        ))
    return sorted(metrics, key=lambda item: item["MetricID"])


def _derive_optimization(events: Sequence[Mapping[str, Any]]) -> List[Dict[str, Any]]:
    metrics: List[Dict[str, Any]] = []
    values_by_field: Dict[str, List[float]] = {field: [] for field in OPT_FIELDS}
    source_ids: Dict[str, List[str]] = {field: [] for field in OPT_FIELDS}
    for event in events:
        payload = _need_mapping(event.get("payload"), "payload")
        for field in OPT_FIELDS:
            value = _validate_numeric_field(payload, field, event["EventID"])
            if value is not None:
                values_by_field[field].append(value)
                source_ids[field].append(event["EventID"])
    for field in OPT_FIELDS:
        values = values_by_field[field]
        agg = _aggregate_numeric(values)
        metrics.append(_metric(
            "optimization.%s.%s" % (field, "sum"),
            "Optimization",
            agg["sum"],
            "DERIVED" if values else "UNTESTED",
            "Derived from exact payload key %r across OPTIMIZATION_PASSES" % field,
            "Add exact payload %r values to enrich optimization evidence" % field,
            source_ids[field],
        ))
    return sorted(metrics, key=lambda item: item["MetricID"])


def validate_metric_bundle(bundle: Mapping[str, Any]) -> None:
    if bundle.get("authority") != "NON_AUTHORITATIVE_SIDECAR" or not NON_AUTHORITATIVE:
        raise DerivedMetricsError("metric bundle authority boundary is missing")
    run_id = _need_text(bundle.get("RunID"), "RunID")
    variant_id = _need_text(bundle.get("VariantID"), "VariantID")
    _need_text(bundle.get("MetricBundleID"), "MetricBundleID")
    sections = _need_mapping(bundle.get("sections"), "sections")
    for section in SECTION_ORDER:
        if section not in sections:
            raise DerivedMetricsError("missing section %s" % section)
        metrics = sections[section]
        if not isinstance(metrics, list):
            raise DerivedMetricsError("section %s must be a list" % section)
        metric_ids = [metric.get("MetricID") for metric in metrics]
        if metric_ids != sorted(metric_ids):
            raise DerivedMetricsError("section %s metrics must be sorted by MetricID" % section)
        for metric in metrics:
            if metric.get("Section") != section:
                raise DerivedMetricsError("metric %s has wrong section" % metric.get("MetricID"))
            _need_text(metric.get("MetricID"), "MetricID")
            _need_text(metric.get("Name"), "Name")
            _need_text(metric.get("Status"), "Status")
            _need_text(metric.get("WHY"), "WHY")
            _need_text(metric.get("ACTION"), "ACTION")
            source_ids = metric.get("source_event_ids")
            if not isinstance(source_ids, list):
                raise DerivedMetricsError("source_event_ids must be a list")
            for event_id in source_ids:
                _need_text(event_id, "source_event_id")
    expected = _stable_id("MBL", {
        "RunID": run_id,
        "VariantID": variant_id,
        "metrics": [
            {
                "Section": metric["Section"],
                "MetricID": metric["MetricID"],
                "Value": metric["Value"],
                "Status": metric["Status"],
                "evidence_label": metric["evidence_label"],
                "source_event_ids": metric["source_event_ids"],
            }
            for section in SECTION_ORDER
            for metric in sections[section]
        ],
    })
    if bundle["MetricBundleID"] != expected:
        raise DerivedMetricsError("MetricBundleID does not match its contents")
