"""Narrow, provenance-preserving adapter for accepted world-intelligence inputs."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Mapping

from contracts import ContractError, ExternalWorldObservation, sha256_json


ACCEPTED_CAPABILITIES = frozenset({
    "market_quotes", "ecb_fx", "yield_curve", "commodities", "crypto", "raw_macro_signals",
})
OPTIONAL_CAPABILITIES = frozenset({
    "cross_rates", "bond_etfs", "btc_technicals", "macro_composite", "filtered_rss",
})
REJECTED_CAPABILITIES = frozenset({
    "current_curated_central_bank_rates", "gdelt_event_intensity", "derived_dxy_proxy",
    "full_collector_vector_stack", "unrestricted_rss_fanout",
})


class UnsupportedCapabilityError(ContractError):
    """Raised for an unknown or explicitly rejected upstream capability."""


def _utc(value: datetime | str) -> datetime:
    if isinstance(value, datetime):
        parsed = value
    else:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise ContractError("timestamps must include a UTC offset")
    return parsed.astimezone(timezone.utc)


def _iso(value: datetime | str) -> str:
    return _utc(value).isoformat().replace("+00:00", "Z")


def _freshness(
    data_timestamp_utc: datetime | str | None,
    retrieved_at_utc: datetime | str,
    now_utc: datetime | str | None,
    max_age_seconds: float | int | None,
) -> tuple[float | None, bool]:
    if data_timestamp_utc is None:
        return None, False
    retrieved = _utc(retrieved_at_utc)
    now = _utc(now_utc) if now_utc is not None else retrieved
    age = max(0.0, (now - _utc(data_timestamp_utc)).total_seconds())
    return age, max_age_seconds is not None and age > max_age_seconds


def _classify_payload(capability: str, payload: Any, failed: bool) -> tuple[str, dict[str, Any]]:
    if failed:
        return "UNAVAILABLE", {"reason": "upstream_failure"}
    if payload is None or payload == {} or payload == []:
        return "UNAVAILABLE", {"reason": "empty_success_shaped_response"}
    if capability == "yield_curve":
        if not isinstance(payload, Mapping) or not payload.get("tenors"):
            return "UNAVAILABLE", {"reason": "yield_curve_has_no_tenors"}
        if payload.get("complete") is False or payload.get("missing_tenors"):
            return "PARTIAL", {"reason": "yield_curve_incomplete"}
    return "AVAILABLE", {}


def normalize_world_observation(
    capability: str,
    payload: Any,
    *,
    source: str,
    provider: str,
    tool: str,
    upstream_repo: str,
    upstream_sha: str,
    retrieved_at_utc: datetime | str,
    data_timestamp_utc: datetime | str | None,
    provenance: Mapping[str, Any],
    payload_version: str = "1",
    diagnostics: Mapping[str, Any] | None = None,
    failed: bool = False,
    upstream_stale: bool | None = None,
    now_utc: datetime | str | None = None,
    max_age_seconds: float | int | None = 86400,
) -> ExternalWorldObservation:
    """Normalize an accepted capability without trusting upstream status flags."""
    if capability in REJECTED_CAPABILITIES:
        raise UnsupportedCapabilityError(f"capability is explicitly rejected: {capability}")
    if capability not in ACCEPTED_CAPABILITIES | OPTIONAL_CAPABILITIES:
        raise UnsupportedCapabilityError(f"capability is not in the bounded policy: {capability}")
    if not isinstance(provenance, Mapping) or not provenance:
        raise ContractError("provenance must be a non-empty mapping")

    failed = failed or (isinstance(payload, Mapping) and payload.get("ok") is False)
    availability, class_diag = _classify_payload(capability, payload, failed)
    freshness_seconds, stale = _freshness(data_timestamp_utc, retrieved_at_utc, now_utc, max_age_seconds)
    diag = dict(diagnostics or {})
    diag.update(class_diag)
    diag["capability_policy"] = "ADOPT" if capability in ACCEPTED_CAPABILITIES else "OPTIONAL"
    if data_timestamp_utc is None and availability == "AVAILABLE":
        availability = "PARTIAL"
        diag["reason"] = "missing_data_timestamp_freshness_unproven"
    if upstream_stale is not None:
        diag["upstream_stale_ignored"] = True
    if stale:
        availability = "STALE"
    raw_hash = sha256_json(payload)
    normalized_payload = payload if isinstance(payload, (Mapping, list, str, int, float, bool)) or payload is None else str(payload)
    record = ExternalWorldObservation(
        schema_version="1.0",
        record_type="ExternalWorldObservation",
        source=source,
        provider=provider,
        tool=tool,
        upstream_repo=upstream_repo,
        upstream_sha=upstream_sha,
        retrieved_at_utc=_iso(retrieved_at_utc),
        data_timestamp_utc=_iso(data_timestamp_utc) if data_timestamp_utc is not None else None,
        freshness_seconds=freshness_seconds,
        stale=stale,
        availability=availability,
        provenance=dict(provenance),
        payload_version=payload_version,
        raw_sha256=raw_hash,
        normalized_sha256=sha256_json(normalized_payload),
        payload=normalized_payload,
        diagnostics=diag,
    )
    return record.validate()


__all__ = [
    "ACCEPTED_CAPABILITIES",
    "OPTIONAL_CAPABILITIES",
    "REJECTED_CAPABILITIES",
    "UnsupportedCapabilityError",
    "normalize_world_observation",
]
