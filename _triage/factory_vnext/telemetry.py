# -*- coding: utf-8 -*-
"""Deterministic attribution telemetry events for the Factory vNext sidecar MVP.

This module is schema-ready for recovery/hedge attribution only. It creates evidence
identities and read-only summaries; it never implements reversal/recovery/hedge trading
behavior and never changes current Factory verdict, optimization, deployment, risk or
LIVE authority.
"""
from __future__ import annotations

import datetime as _dt
from typing import Any, Dict, Iterable, Mapping, Optional, Tuple

from . import NON_AUTHORITATIVE
from .contracts import EVIDENCE_LABELS, canonical_json, stable_id


class TelemetryError(ValueError):
    pass


SCHEMA_VERSION = "factory-vnext-telemetry-event-v1"

MANDATORY_EVENT_FAMILIES = (
    "SIGNAL_EVENTS", "TRADE_EVENTS", "CONTEXT_EVENTS", "OPTIMIZATION_PASSES",
)
CONDITIONAL_EVENT_FAMILIES = ("BASKET_EVENTS", "HEDGE_EVENTS")
EVENT_FAMILIES = MANDATORY_EVENT_FAMILIES + CONDITIONAL_EVENT_FAMILIES

EVENT_SCOPES = ("COMPONENT", "VARIANT")

# Action/trade/signal attribution must always carry an explicit IntentID; it is never
# inferred from order shape. CONTEXT_EVENTS (observation) and OPTIMIZATION_PASSES
# (optimizer bookkeeping) are not actions and do not require one.
INTENT_REQUIRED_FAMILIES = ("SIGNAL_EVENTS", "TRADE_EVENTS", "BASKET_EVENTS", "HEDGE_EVENTS")

IDENTITY_FIELDS: Tuple[str, ...] = (
    "RunID", "VariantID", "EventFamily", "EvidenceLabel", "Scope",
    "ComponentID", "PositionGroupID", "IntentID",
    "timestamp", "sequence", "stable_key", "payload",
)


def _need_text(value: Any, name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise TelemetryError("%s is required" % name)
    return value.strip()


def _optional_text(value: Any, name: str) -> Optional[str]:
    if value is None:
        return None
    return _need_text(value, name)


def _optional_iso_timestamp(value: Any) -> Optional[str]:
    if value is None:
        return None
    text = _need_text(value, "timestamp")
    try:
        _dt.datetime.fromisoformat(text)
    except ValueError as exc:
        raise TelemetryError("timestamp must be ISO-8601") from exc
    return text


def _optional_sequence(value: Any) -> Optional[int]:
    if value is None:
        return None
    if isinstance(value, bool) or not isinstance(value, int):
        raise TelemetryError("sequence must be an integer")
    if value < 0:
        raise TelemetryError("sequence must be >= 0")
    return value


def _check_component_in_variant(variant: Mapping[str, Any], component_id: str, position_group_id: str) -> None:
    if not isinstance(variant, Mapping):
        raise TelemetryError("variant must be a mapping record")
    components = variant.get("Components")
    if not isinstance(components, list) or not components:
        raise TelemetryError("variant record has no Components to validate against")
    match = next((c for c in components if c.get("ComponentID") == component_id), None)
    if match is None:
        raise TelemetryError(
            "ComponentID %r is not part of the supplied Variant composition" % component_id
        )
    if match.get("PositionGroupID") != position_group_id:
        raise TelemetryError(
            "component/group mismatch: ComponentID %r belongs to PositionGroupID %r, not %r"
            % (component_id, match.get("PositionGroupID"), position_group_id)
        )


def _event_identity(fields: Mapping[str, Any]) -> str:
    identity = {name: fields.get(name) for name in IDENTITY_FIELDS}
    return stable_id("EVT", identity, hex_chars=24)


def make_event(
    *,
    run_id: str,
    variant: Mapping[str, Any],
    event_family: str,
    evidence_label: str,
    scope: str,
    component_id: Optional[str] = None,
    position_group_id: Optional[str] = None,
    intent_id: Optional[str] = None,
    timestamp: Optional[str] = None,
    sequence: Optional[int] = None,
    stable_key: Optional[str] = None,
    payload: Optional[Mapping[str, Any]] = None,
) -> Dict[str, Any]:
    run = _need_text(run_id, "RunID")
    if not isinstance(variant, Mapping):
        raise TelemetryError("variant must be a mapping record")
    variant_id = _need_text(variant.get("VariantID"), "Variant.VariantID")

    family = _need_text(event_family, "EventFamily").upper()
    if family not in EVENT_FAMILIES:
        raise TelemetryError("unknown event family %r" % event_family)

    label = _need_text(evidence_label, "EvidenceLabel").upper()
    if label not in EVIDENCE_LABELS:
        raise TelemetryError("invalid evidence label %r" % evidence_label)

    event_scope = _need_text(scope, "Scope").upper()
    if event_scope not in EVENT_SCOPES:
        raise TelemetryError("invalid Scope %r" % scope)

    if event_scope == "VARIANT":
        if family != "CONTEXT_EVENTS":
            raise TelemetryError("VARIANT scope is only valid for CONTEXT_EVENTS, not %r" % family)
        if component_id or position_group_id:
            raise TelemetryError("component_id and position_group_id must be absent for VARIANT scope")
        comp_id: Optional[str] = None
        pg_id: Optional[str] = None
    else:
        comp_id = _need_text(component_id, "ComponentID")
        pg_id = _need_text(position_group_id, "PositionGroupID")
        _check_component_in_variant(variant, comp_id, pg_id)

    if family in INTENT_REQUIRED_FAMILIES:
        intent = _need_text(intent_id, "IntentID")
    else:
        intent = _optional_text(intent_id, "IntentID")

    if timestamp is None and sequence is None and stable_key is None:
        raise TelemetryError("at least one of timestamp, sequence, or stable_key is required")
    ts = _optional_iso_timestamp(timestamp)
    seq = _optional_sequence(sequence)
    key = _optional_text(stable_key, "stable_key")

    if payload is None:
        payload_dict: Dict[str, Any] = {}
    elif isinstance(payload, Mapping):
        payload_dict = dict(payload)
    else:
        raise TelemetryError("payload must be a mapping")
    try:
        canonical_json(payload_dict)
    except (TypeError, ValueError) as exc:
        raise TelemetryError("payload must be JSON-serializable") from exc

    fields: Dict[str, Any] = {
        "RunID": run,
        "VariantID": variant_id,
        "EventFamily": family,
        "EvidenceLabel": label,
        "Scope": event_scope,
        "ComponentID": comp_id,
        "PositionGroupID": pg_id,
        "IntentID": intent,
        "timestamp": ts,
        "sequence": seq,
        "stable_key": key,
        "payload": payload_dict,
    }
    event_id = _event_identity(fields)
    record: Dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "authority": "NON_AUTHORITATIVE_SIDECAR",
        "EventID": event_id,
        **fields,
    }
    validate_event(record)
    return record


def validate_event(event: Mapping[str, Any], variant: Optional[Mapping[str, Any]] = None) -> None:
    if event.get("authority") != "NON_AUTHORITATIVE_SIDECAR" or not NON_AUTHORITATIVE:
        raise TelemetryError("telemetry event authority boundary is missing")
    for name in ("EventID", "RunID", "VariantID", "EventFamily", "EvidenceLabel", "Scope"):
        _need_text(event.get(name), name)

    family = event["EventFamily"]
    if family not in EVENT_FAMILIES:
        raise TelemetryError("unknown event family %r" % family)
    if event["EvidenceLabel"] not in EVIDENCE_LABELS:
        raise TelemetryError("invalid evidence label %r" % event["EvidenceLabel"])
    if event["Scope"] not in EVENT_SCOPES:
        raise TelemetryError("invalid Scope %r" % event["Scope"])

    if event["Scope"] == "VARIANT":
        if family != "CONTEXT_EVENTS":
            raise TelemetryError("VARIANT scope is only valid for CONTEXT_EVENTS, not %r" % family)
        if event.get("ComponentID") or event.get("PositionGroupID"):
            raise TelemetryError("component_id and position_group_id must be absent for VARIANT scope")
    else:
        comp_id = _need_text(event.get("ComponentID"), "ComponentID")
        pg_id = _need_text(event.get("PositionGroupID"), "PositionGroupID")
        if variant is not None:
            _check_component_in_variant(variant, comp_id, pg_id)

    if family in INTENT_REQUIRED_FAMILIES:
        _need_text(event.get("IntentID"), "IntentID")

    if event.get("timestamp") is None and event.get("sequence") is None and not event.get("stable_key"):
        raise TelemetryError("at least one of timestamp, sequence, or stable_key is required")

    expected = _event_identity(event)
    if event["EventID"] != expected:
        raise TelemetryError("EventID does not match its identity fields")


def summarize_family_availability(
    events: Iterable[Mapping[str, Any]],
    families: Optional[Iterable[str]] = None,
) -> Dict[str, Dict[str, Any]]:
    """Report per-family event counts and the evidence labels actually observed.

    Never fabricates a metric: a family with zero events is reported UNTESTED
    (mandatory) or UNAVAILABLE (conditional) rather than any neutral/MEASURED
    default, and a family whose events are all SIMULATED (or any other single
    label) reports that label verbatim rather than being upgraded.
    """
    if families is None:
        family_list = list(EVENT_FAMILIES)
    else:
        family_list = []
        for raw in families:
            name = _need_text(raw, "EventFamily").upper()
            if name not in EVENT_FAMILIES:
                raise TelemetryError("unknown event family %r" % raw)
            family_list.append(name)

    buckets: Dict[str, list] = {name: [] for name in family_list}
    for event in events:
        fam = event.get("EventFamily")
        if fam in buckets:
            buckets[fam].append(event)

    summary: Dict[str, Dict[str, Any]] = {}
    for family in family_list:
        family_events = buckets[family]
        count = len(family_events)
        if count == 0:
            evidence = "UNTESTED" if family in MANDATORY_EVENT_FAMILIES else "UNAVAILABLE"
            labels_present: Tuple[str, ...] = ()
        else:
            labels_present = tuple(sorted({e.get("EvidenceLabel") for e in family_events}))
            evidence = labels_present[0] if len(labels_present) == 1 else "MIXED"
        summary[family] = {
            "EventFamily": family,
            "count": count,
            "EvidenceLabels": labels_present,
            "SummaryEvidenceLabel": evidence,
        }
    return summary


def build_attribution_index(events: Iterable[Mapping[str, Any]]) -> Dict[str, Dict[str, list]]:
    by_variant: Dict[str, list] = {}
    by_component: Dict[str, list] = {}
    by_position_group: Dict[str, list] = {}
    by_intent: Dict[str, list] = {}

    for event in events:
        event_id = event.get("EventID")
        variant_id = event.get("VariantID")
        if variant_id:
            by_variant.setdefault(variant_id, []).append(event_id)
        component_id = event.get("ComponentID")
        if component_id:
            by_component.setdefault(component_id, []).append(event_id)
        position_group_id = event.get("PositionGroupID")
        if position_group_id:
            by_position_group.setdefault(position_group_id, []).append(event_id)
        intent_id = event.get("IntentID")
        if intent_id:
            by_intent.setdefault(intent_id, []).append(event_id)

    def _sorted(bucket: Mapping[str, list]) -> Dict[str, list]:
        return {key: sorted(values) for key, values in sorted(bucket.items())}

    return {
        "by_variant": _sorted(by_variant),
        "by_component": _sorted(by_component),
        "by_position_group": _sorted(by_position_group),
        "by_intent": _sorted(by_intent),
    }
