"""Versioned, strict envelopes shared by the two read adapters.

An observation is evidence about a source, never a runtime health attestation.
No filesystem mtime, default feed TTL, implicit clock conversion or raw exception
text belongs in the public projection.
"""
from __future__ import annotations

import hashlib
import json
import re
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from enum import Enum
from typing import Any


class ProjectionError(ValueError):
    """Only fixed reason codes cross the presentation boundary."""


class Freshness(str, Enum):
    CURRENT = "CURRENT"
    STALE = "STALE"
    MISSING = "MISSING"
    MALFORMED = "MALFORMED"
    FUTURE = "FUTURE"
    DISABLED = "DISABLED"
    UNKNOWN = "UNKNOWN"
    HISTORICAL = "HISTORICAL"


def digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def safe_text(value: Any, limit: int = 256) -> str:
    if (not isinstance(value, str) or not value or len(value) > limit
            or re.search(r"[<>\\\x00-\x1f]|://|\b[A-Za-z]:|\b\d{7,}\b|@|(?i:token|password|secret|api[_-]?key|bearer)|\bsk-", value)):
        raise ProjectionError("UNSAFE_VALUE")
    return value


def safe_path(value: Any) -> str:
    if not isinstance(value, str) or len(value) > 500:
        raise ProjectionError("UNSAFE_PATH")
    for part in value.split("/"):
        if (not re.fullmatch(r"[A-Za-z0-9_(). -]+", part) or part in {".", ".."}
                or part != part.strip() or part.endswith(".")
                or re.match(r"^(CON|PRN|AUX|NUL|COM\d|LPT\d)(\.|$)", part, re.I)):
            raise ProjectionError("UNSAFE_PATH")
    return value


def hex_value(value: Any, length: int) -> str:
    if not isinstance(value, str) or not re.fullmatch(r"[0-9a-f]{%d}" % length, value):
        raise ProjectionError("INVALID_HASH")
    return value


def utc(value: Any) -> datetime:
    if not isinstance(value, str) or not re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ", value):
        raise ProjectionError("UNKNOWN_TIMESTAMP_BASIS")
    try:
        return datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    except ValueError:
        raise ProjectionError("INVALID_TIMESTAMP") from None


def parse_json(raw: bytes) -> dict:
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ProjectionError("DUPLICATE_FIELD")
            result[key] = value
        return result
    try:
        result = json.loads(raw.decode("utf-8-sig"), object_pairs_hook=pairs,
                            parse_constant=lambda _: (_ for _ in ()).throw(ProjectionError("NONFINITE_NUMBER")))
        if not isinstance(result, dict):
            raise ProjectionError("INVALID_SHAPE")
        return result
    except (UnicodeError, ValueError, AttributeError):
        raise ProjectionError("MALFORMED_JSON") from None


@dataclass(frozen=True)
class SourceObservation:
    schema: str
    source_id: str
    source_path: str
    canonical_sha: str
    data_sha256: str | None
    observed_at: str | None
    event_at: str | None
    available_at: str | None
    clock_basis: str
    freshness_policy: str
    freshness: Freshness
    age_seconds: float | None
    quality: str
    reason: str

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, value: dict, *, expected_source: str, expected_sha: str):
        fields = set(cls.__dataclass_fields__)
        if not isinstance(value, dict) or set(value) != fields:
            raise ProjectionError("UNEXPECTED_FIELD_OR_SHAPE")
        if value["schema"] != "source_observation/1":
            raise ProjectionError("SCHEMA_MISMATCH")
        if value["source_id"] != expected_source or value["canonical_sha"] != expected_sha:
            raise ProjectionError("SOURCE_IDENTITY_MISMATCH")
        safe_text(value["source_id"])
        safe_path(value["source_path"])
        hex_value(value["canonical_sha"], 40)
        if value["data_sha256"] is not None:
            hex_value(value["data_sha256"], 64)
        for key in ("observed_at", "event_at", "available_at"):
            if value[key] is not None:
                utc(value[key])
        for key in ("freshness_policy", "quality", "reason"):
            safe_text(value[key])
        if value["clock_basis"] not in {"UTC", "UNKNOWN", "PINNED_GIT"}:
            raise ProjectionError("UNKNOWN_TIMESTAMP_BASIS")
        try:
            freshness = Freshness(value["freshness"])
        except (ValueError, TypeError):
            raise ProjectionError("INVALID_FRESHNESS") from None
        age = value["age_seconds"]
        if age is not None and (type(age) not in (int, float) or not float("-inf") < age < float("inf")):
            raise ProjectionError("INVALID_AGE")
        if freshness == Freshness.CURRENT and (value["clock_basis"] != "UTC" or value["observed_at"] is None or age is None or age < 0):
            raise ProjectionError("UNQUALIFIED_CURRENT")
        return cls(**{**value, "freshness": freshness})


def observe(*, source_id: str, source_path: str, canonical_sha: str,
            raw: bytes | None, as_of: str, observed_at: str | None = None,
            event_at: str | None = None, available_at: str | None = None,
            clock_basis: str = "UNKNOWN", policy: str = "UNQUALIFIED",
            max_age_seconds: int | None = None, historical: bool = False,
            disabled: bool = False, malformed: bool = False) -> SourceObservation:
    now = utc(as_of)
    age = None
    status, reason = Freshness.UNKNOWN, "NO_QUALIFIED_OBSERVATION_CLOCK"
    if raw is None:
        status, reason = Freshness.MISSING, "SOURCE_NOT_PROVIDED"
    elif malformed:
        status, reason = Freshness.MALFORMED, "SOURCE_MALFORMED"
    elif clock_basis == "UTC" and observed_at is not None:
        age = (now - utc(observed_at)).total_seconds()
        if age < 0:
            status, reason = Freshness.FUTURE, "OBSERVATION_AFTER_AS_OF"
        elif max_age_seconds is not None:
            if type(max_age_seconds) is not int or max_age_seconds < 0 or policy == "UNQUALIFIED":
                raise ProjectionError("UNQUALIFIED_FRESHNESS_POLICY")
            status = Freshness.STALE if age > max_age_seconds else Freshness.CURRENT
            reason = "SOURCE_POLICY_AGE"
    if historical and status not in {Freshness.MISSING, Freshness.MALFORMED, Freshness.FUTURE}:
        status, reason = Freshness.HISTORICAL, "PINNED_ARTIFACT_NOT_LIVE_HEALTH"
    if disabled and raw is not None and not malformed:
        status, reason = Freshness.DISABLED, "EXPLICIT_SOURCE_DISABLED"
    value = SourceObservation("source_observation/1", source_id, source_path, canonical_sha,
                              digest(raw) if raw is not None else None, observed_at, event_at,
                              available_at, clock_basis, policy, status, age,
                              "OBSERVATION_ONLY", reason)
    return SourceObservation.from_dict(value.to_dict(), expected_source=source_id, expected_sha=canonical_sha)


@dataclass(frozen=True)
class ResearchArtifactRef:
    schema: str
    ea_id: str
    basis_id: str
    canonical_sha: str
    record_sha256: str
    package_id: str
    package_status: str
    missing: tuple[str, ...]

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass(frozen=True)
class GuardObservation:
    schema: str
    source: SourceObservation
    guard: str
    state: str
    block_observation: str = "UNKNOWN"
    lot_multiplier_observation: float | None = None
    producer_health: str = "UNKNOWN"
    affected_ea_scope: str = "UNKNOWN"
    runtime_effectiveness: str = "UNKNOWN"

    def to_dict(self) -> dict:
        return asdict(self)
