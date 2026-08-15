"""Research-only candidate adapter; it cannot promote knowledge into authority."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Mapping

from contracts import ContractError, ResearchKnowledgeCandidate, sha256_json


_AUTHORITY_KEYS = frozenset({
    "approved", "canonical", "canonical_fact_written", "promoted", "validated", "validation_state",
})
_SUPPORTED_RELATIONSHIPS = frozenset({
    "supports", "related_to", "depends_on", "contradicts", "derived_from", "mentions",
})


def _iso(value: datetime | str) -> str:
    parsed = value if isinstance(value, datetime) else datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise ContractError("extracted_at_utc must include a UTC offset")
    return parsed.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def _find_authority_key(value: Any) -> str | None:
    if isinstance(value, Mapping):
        for key, nested in value.items():
            if str(key).lower() in _AUTHORITY_KEYS:
                return str(key)
            found = _find_authority_key(nested)
            if found:
                return found
    elif isinstance(value, list):
        for nested in value:
            found = _find_authority_key(nested)
            if found:
                return found
    return None


def normalize_research_candidate(
    *,
    upstream_repo: str,
    upstream_sha: str,
    document_sha256: str,
    source_ref: str,
    chunk_ref: str,
    extraction_version: str,
    model_identity: str,
    extracted_at_utc: datetime | str,
    support_ref: str,
    concept: Mapping[str, Any] | None = None,
    relationship: Mapping[str, Any] | None = None,
    evidence: Mapping[str, Any] | None = None,
    validation_state: str = "UNVALIDATED",
    canonical_fact_written: bool = False,
) -> ResearchKnowledgeCandidate:
    """Create a deterministic candidate while preserving a hard authority boundary."""
    if validation_state != "UNVALIDATED":
        raise ContractError("research candidates cannot enter with validation authority")
    if canonical_fact_written:
        raise ContractError("research adapter cannot write canonical facts")
    for raw in (concept, relationship, evidence):
        key = _find_authority_key(raw)
        if key:
            raise ContractError(f"authority-bearing field is forbidden: {key}")
    if relationship is not None:
        relationship = dict(relationship)
        relation_type = relationship.get("type")
        if relation_type not in _SUPPORTED_RELATIONSHIPS:
            relationship["support_status"] = "UNSUPPORTED_RELATIONSHIP_UNVALIDATED"
    if not isinstance(evidence, Mapping) or not evidence:
        raise ContractError("evidence/source support is required")

    candidate_identity = {
        "document_sha256": document_sha256.lower(),
        "chunk_ref": chunk_ref,
        "concept": concept,
        "relationship": relationship,
    }
    candidate = ResearchKnowledgeCandidate(
        schema_version="1.0",
        record_type="ResearchKnowledgeCandidate",
        candidate_id=sha256_json(candidate_identity),
        upstream_repo=upstream_repo,
        upstream_sha=upstream_sha,
        document_sha256=document_sha256,
        source_ref=source_ref,
        chunk_ref=chunk_ref,
        extraction_version=extraction_version,
        model_identity=model_identity,
        extracted_at_utc=_iso(extracted_at_utc),
        concept=dict(concept) if concept is not None else None,
        relationship=relationship,
        support_ref=support_ref,
        evidence=dict(evidence),
        validation_state="UNVALIDATED",
        canonical_fact_written=False,
    )
    return candidate.validate()


__all__ = ["normalize_research_candidate"]
