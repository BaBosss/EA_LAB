"""Versioned, provenance-first records for external intelligence inputs."""

from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import datetime, timezone
import hashlib
import json
import re
from typing import Any, Mapping


class ContractError(ValueError):
    """Raised when an external record violates the adapter contract."""


_SHA256_RE = re.compile(r"^[0-9a-fA-F]{64}$")
_UNVALIDATED = "UNVALIDATED"


def canonical_json(value: Any) -> str:
    """Return the stable JSON representation used for record hashes and storage."""
    try:
        return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    except (TypeError, ValueError) as exc:
        raise ContractError(f"value is not stable JSON: {exc}") from exc


def sha256_json(value: Any) -> str:
    return hashlib.sha256(canonical_json(value).encode("utf-8")).hexdigest()


def _require_text(value: Any, field: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ContractError(f"{field} must be a non-empty string")
    return value


def _require_sha(value: Any, field: str) -> str:
    value = _require_text(value, field)
    if not _SHA256_RE.fullmatch(value):
        raise ContractError(f"{field} must be a 64-character SHA-256 hex digest")
    return value.lower()


def _parse_utc(value: Any, field: str) -> datetime:
    if isinstance(value, datetime):
        parsed = value
    elif isinstance(value, str):
        try:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError as exc:
            raise ContractError(f"{field} must be ISO-8601") from exc
    else:
        raise ContractError(f"{field} must be an ISO-8601 string or datetime")
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise ContractError(f"{field} must include a UTC offset")
    return parsed.astimezone(timezone.utc)


def _json_safe(value: Any, field: str) -> None:
    try:
        json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    except (TypeError, ValueError) as exc:
        raise ContractError(f"{field} must be JSON-serializable: {exc}") from exc


@dataclass(frozen=True)
class ExternalWorldObservation:
    schema_version: str
    record_type: str
    source: str
    provider: str
    tool: str
    upstream_repo: str
    upstream_sha: str
    retrieved_at_utc: datetime | str
    data_timestamp_utc: datetime | str | None
    freshness_seconds: float | int | None
    stale: bool
    availability: str
    provenance: Mapping[str, Any]
    payload_version: str
    raw_sha256: str
    normalized_sha256: str
    payload: Any
    diagnostics: Mapping[str, Any]

    def validate(self) -> "ExternalWorldObservation":
        _require_text(self.schema_version, "schema_version")
        if self.record_type != "ExternalWorldObservation":
            raise ContractError("record_type must be ExternalWorldObservation")
        for field in ("source", "provider", "tool", "upstream_repo", "upstream_sha", "payload_version"):
            _require_text(getattr(self, field), field)
        _require_sha(self.raw_sha256, "raw_sha256")
        _require_sha(self.normalized_sha256, "normalized_sha256")
        _parse_utc(self.retrieved_at_utc, "retrieved_at_utc")
        if self.data_timestamp_utc is not None:
            _parse_utc(self.data_timestamp_utc, "data_timestamp_utc")
        if self.freshness_seconds is not None:
            if isinstance(self.freshness_seconds, bool) or not isinstance(self.freshness_seconds, (int, float)):
                raise ContractError("freshness_seconds must be a non-negative number or null")
            if self.freshness_seconds < 0:
                raise ContractError("freshness_seconds must be non-negative")
        if not isinstance(self.stale, bool):
            raise ContractError("stale must be boolean")
        if self.availability not in {"AVAILABLE", "PARTIAL", "STALE", "UNAVAILABLE"}:
            raise ContractError("availability is not a supported enum value")
        if not isinstance(self.provenance, Mapping) or not self.provenance:
            raise ContractError("provenance must be a non-empty mapping")
        if not isinstance(self.diagnostics, Mapping):
            raise ContractError("diagnostics must be a mapping")
        _json_safe(self.provenance, "provenance")
        _json_safe(self.payload, "payload")
        _json_safe(self.diagnostics, "diagnostics")
        return self

    def to_dict(self) -> dict[str, Any]:
        self.validate()
        result = asdict(self)
        for field in ("retrieved_at_utc", "data_timestamp_utc"):
            value = result[field]
            if isinstance(value, datetime):
                result[field] = value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")
        return result


@dataclass(frozen=True)
class ResearchKnowledgeCandidate:
    schema_version: str
    record_type: str
    candidate_id: str
    upstream_repo: str
    upstream_sha: str
    document_sha256: str
    source_ref: str
    chunk_ref: str
    extraction_version: str
    model_identity: str
    extracted_at_utc: datetime | str
    concept: Mapping[str, Any] | None
    relationship: Mapping[str, Any] | None
    support_ref: str
    evidence: Mapping[str, Any]
    validation_state: str
    canonical_fact_written: bool

    def validate(self) -> "ResearchKnowledgeCandidate":
        if self.record_type != "ResearchKnowledgeCandidate":
            raise ContractError("record_type must be ResearchKnowledgeCandidate")
        for field in (
            "schema_version", "candidate_id", "upstream_repo", "upstream_sha", "source_ref",
            "chunk_ref", "extraction_version", "model_identity", "support_ref",
        ):
            _require_text(getattr(self, field), field)
        _require_sha(self.document_sha256, "document_sha256")
        _require_text(self.upstream_sha, "upstream_sha")
        _parse_utc(self.extracted_at_utc, "extracted_at_utc")
        if self.concept is None and self.relationship is None:
            raise ContractError("candidate must contain a concept or relationship")
        if self.concept is not None and not isinstance(self.concept, Mapping):
            raise ContractError("concept must be a mapping")
        if self.relationship is not None and not isinstance(self.relationship, Mapping):
            raise ContractError("relationship must be a mapping")
        if not isinstance(self.evidence, Mapping) or not self.evidence:
            raise ContractError("evidence must be a non-empty mapping")
        if self.validation_state != _UNVALIDATED:
            raise ContractError("external candidates must remain UNVALIDATED")
        if self.canonical_fact_written is not False:
            raise ContractError("external candidates cannot write canonical facts")
        _json_safe(self.concept, "concept")
        _json_safe(self.relationship, "relationship")
        _json_safe(self.evidence, "evidence")
        return self

    def to_dict(self) -> dict[str, Any]:
        self.validate()
        result = asdict(self)
        value = result["extracted_at_utc"]
        if isinstance(value, datetime):
            result["extracted_at_utc"] = value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")
        return result


__all__ = [
    "ContractError",
    "ExternalWorldObservation",
    "ResearchKnowledgeCandidate",
    "canonical_json",
    "sha256_json",
]
