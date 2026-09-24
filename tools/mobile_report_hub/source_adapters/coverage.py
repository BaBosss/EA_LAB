"""Descriptive attribution using existing identity owners; never new attestations."""
from __future__ import annotations
import re
from pathlib import Path
from _triage.factory_os.runtime_identity import REQUIRED_FIELDS, IDENTITY_SCHEMA, RUNTIME_IDENTITY_MAX_AGE_HOURS
from .readers import Metadata
from .safe import Sources, Refused, json_object, opaque, utc_time

IDENTITY_FIELDS = ("magic", "ea_logical_identity", "build_receipt", "config_fingerprint",
                   "config_fingerprint_version", "symbol", "timeframe", "attach_epoch")


def read_control(sources: Sources, root: Path, sha: str, as_of: str) -> dict:
    raw, ref = sources.read(root, "portfolio/control_room_snapshot.json", "CONTROL_ROOM")
    doc = json_object(raw)
    meta = doc.get("meta")
    summary = doc.get("runtime_identity_summary")
    if (doc.get("entity") != "ControlRoomSnapshotV5" or not isinstance(meta, dict)
            or meta.get("schema") != "ControlRoomSnapshot" or type(meta.get("version")) is not int
            or meta["version"] != 5 or not isinstance(summary, dict)):
        raise Refused("CONTROL_ROOM_SCHEMA_INVALID")
    if not isinstance(summary.get("state"), str) or summary["state"] not in {"FAIL", "PASS", "LEGACY_UNVERIFIED"}:
        raise Refused("CONTROL_ROOM_IDENTITY_STATE_INVALID")
    if type(summary.get("records")) is not int or summary["records"] < 0:
        raise Refused("CONTROL_ROOM_IDENTITY_COUNT_INVALID")
    when = utc_time(meta.get("generated_at"))
    age = int((utc_time(as_of) - when).total_seconds())
    producer_head = meta.get("git_head")
    if not isinstance(producer_head, str) or not re.fullmatch("[0-9a-f]{40}", producer_head):
        raise Refused("CONTROL_ROOM_HEAD_INVALID")
    records = doc.get("runtime_identity", [])
    if not isinstance(records, list) or len(records) != summary["records"] or len(records) > 1000:
        raise Refused("CONTROL_ROOM_RECORDS_INVALID")
    # Never forward arbitrary producer strings (including reason details/private paths).
    return {"source_ref": ref, "generated_at": meta["generated_at"], "observed_age_seconds": age,
            "clock_basis": "UTC", "temporal_relation": "FUTURE" if age < 0 else "AT_OR_BEFORE_READ",
            "freshness": "UNQUALIFIED_NO_ADAPTER_TTL", "producer_head": producer_head,
            "canonical_binding": "MATCH" if producer_head == sha else "DIFFERENT_REPO_HEAD",
            "producer_identity_state": summary["state"], "records": records}


def deployment_coverage(meta: Metadata, control: dict | None, as_of: str) -> dict:
    result = []
    for row in meta.deployments:
        login, magic, sym = row.get("account", ""), row.get("magic", ""), row.get("symbol", "")
        key = opaque("deployment", login, magic, sym)
        expected = [r for r in meta.identities if r.get("account") == login and r.get("magic") == magic]
        observed = [r for r in control["records"] if isinstance(r, dict) and r.get("account_login") == login and r.get("magic") == magic] if control else []
        reasons = []
        if len(expected) != 1:
            reasons.append("EXPECTED_IDENTITY_MISSING_OR_AMBIGUOUS")
        if len(observed) != 1:
            reasons.append("OBSERVED_IDENTITY_MISSING_OR_AMBIGUOUS")
        observed_pin = None
        observed_at = None
        if len(observed) == 1:
            record = observed[0]
            if record.get("schema") != IDENTITY_SCHEMA or not set(REQUIRED_FIELDS) <= set(record):
                reasons.append("EXISTING_IDENTITY_SCHEMA_INVALID")
            else:
                if len(expected) == 1:
                    for field in IDENTITY_FIELDS:
                        if record.get(field) != expected[0].get(field):
                            reasons.append(field.upper() + "_MISMATCH")
                    if expected[0].get("symbol") != sym:
                        reasons.append("DEPLOYMENT_SYMBOL_MISMATCH")
                try:
                    when = utc_time(record["evidence_timestamp"])
                    observed_at = record["evidence_timestamp"]
                    if when > utc_time(as_of):
                        reasons.append("IDENTITY_TIMESTAMP_FUTURE")
                    elif (utc_time(as_of) - when).total_seconds() > RUNTIME_IDENTITY_MAX_AGE_HOURS * 3600:
                        reasons.append("IDENTITY_TIMESTAMP_STALE_EXISTING_POLICY")
                except Refused:
                    reasons.append("IDENTITY_CLOCK_UNQUALIFIED")
                observed_pin = opaque("pin", *[str(record.get(k, "")) for k in IDENTITY_FIELDS])
                if record.get("validation_state") != "PASS":
                    reasons.append("PRODUCER_IDENTITY_NOT_PASS")
        if control:
            if control["producer_identity_state"] != "PASS":
                reasons.append("PRODUCER_IDENTITY_NOT_PASS")
            if control["canonical_binding"] != "MATCH":
                reasons.append("PRODUCER_HEAD_DIFFERS")
            if control["temporal_relation"] == "FUTURE":
                reasons.append("PRODUCER_TIMESTAMP_FUTURE")
        else:
            reasons.append("CONTROL_ROOM_UNAVAILABLE")
        # Matching values are not an artifact/source/clock qualification. This reader
        # does not call the legacy validator, which may open receipt-owned disk paths.
        reasons.append("ARTIFACT_AND_EVIDENCE_FRESHNESS_NOT_REQUALIFIED")
        result.append({"deployment_id": key, "account_key": opaque("account", login),
            "declaration": "ACTIVE" if row.get("status") == "ACTIVE" else "OTHER_DECLARED_STATUS",
            "expected_identity_present": len(expected) == 1,
            "expected_pin": opaque("pin", *[expected[0].get(k, "") for k in IDENTITY_FIELDS]) if len(expected) == 1 else None,
            "observed_pin": observed_pin, "observed_at": observed_at,
            "comparison": "DIFFERENCES_OR_GAPS" if len(set(reasons)) > 1 else "FIELDS_MATCH_ONLY",
            "runtime_identity": control["producer_identity_state"] if control else "UNAVAILABLE",
            "attribution_eligible": False, "reasons": sorted(set(reasons)),
            "source_refs": meta.refs + ([control["source_ref"]] if control else [])})
    return {"deployments": result, "authority": "DESCRIPTIVE_ONLY", "first_trade_or_judge_claim": None,
            "producer": {k: v for k, v in control.items() if k != "records"} if control else None}


def guard_observations(sources: Sources, root: Path, repo: Path, sha: str, as_of: str, coverage: dict) -> dict:
    contexts = []
    for kind, relative in (("NEWS_CALENDAR", "portfolio/news_week.csv"), ("MRIS", "portfolio/mris/regime_state.json")):
        ref = None
        try:
            raw, ref = sources.read(root, relative, kind)
            observed = None
            if kind == "NEWS_CALENDAR":
                sources.csv(raw, set("BkkTime Currency Title TimeRaw Forecast Previous".split()))
            else:
                doc = json_object(raw)
                observed = doc.get("generated_utc")
                utc_time(observed)
            future = observed is not None and utc_time(observed) > utc_time(as_of)
            contexts.append({"kind": kind, "source_ref": ref, "observed_at": observed,
                             "availability": "PARTIAL", "reason": "FUTURE_CONTEXT" if future else "CONTEXT_NOT_EFFECTIVE_EVIDENCE"})
        except Refused as exc:
            sources.error("guards", str(exc), ref)
            contexts.append({"kind": kind, "source_ref": ref, "observed_at": None, "availability": "UNAVAILABLE", "reason": str(exc)})
    config_ref = None
    try:
        _, config_ref = sources.git_blob(repo, sha, "ea_projects/(Boss)_NewsGuard/GUARDCONFIG_2026-07-17.md")
    except Refused as exc:
        sources.error("guards", str(exc))
    return {"contract": "EXISTING_GUARD_OBSERVATION_UNKNOWN_ONLY_V1",
        "configured_reference": {"source_ref": config_ref, "date": "2026-07-17", "scope": "HISTORICAL_RUNBOOK_NOT_DEPLOYMENT_CONFIG"},
        "contexts": contexts,
        "deployments": [{"deployment_id": row["deployment_id"], "identity_source_refs": row["source_refs"],
            "identity_reasons": row["reasons"], "NewsGuard": {"configured": None, "effective": None},
            "MacroGate": {"configured": None, "effective": None}, "availability": "UNAVAILABLE",
            "reason": "NO_ACCEPTED_IDENTITY_BOUND_EFFECTIVE_EVENT_SCHEMA"} for row in coverage["deployments"]],
        "effective": None, "reason": "CALENDAR_MRIS_AND_CONFIG_CANNOT_PROVE_EA_APPLICATION"}


def access_provenance() -> dict:
    return {"existing_owners": {"alerts": "SafeProjection", "storage": "Monitor Model.snapshot",
                                "work_jobs_freshness": "Collector and Monitor"},
            "access": [{"mode": mode, "availability": "UNAVAILABLE", "accepted": False,
                        "reason": "ACCESS_EVIDENCE_NOT_SUPPLIED", "source_refs": []}
                       for mode in ("LOCAL_LOOPBACK", "OFFLINE_EXPORT", "AUTHENTICATED_PRIVATE_ENDPOINT")],
            "activation": "NONE", "notifications": "NONE", "storage_measurements": None,
            "source_ownership": "ADAPTER_PROVENANCE_ONLY_EXISTING_MONITOR_SURFACES_RETAIN_OWNERSHIP"}
