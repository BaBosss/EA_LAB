"""Offline, explicit-manifest News/Macro provenance; no runtime discovery."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

SCHEMA = "ea_lab_news_macro_stage_manifest/1"
STAGES = (
    "FETCHED", "VALIDATED", "CLASSIFIED", "PUBLISHED_LOCAL",
    "TRANSFER_REQUESTED", "TRANSFERRED", "CONSUMER_OBSERVED", "EFFECTIVE",
)
KINDS = dict(zip(STAGES, (
    "fetch_receipt", "validation_receipt", "classification_receipt",
    "local_publication_receipt", "transfer_request", "transfer_receipt",
    "consumer_observation", "effect_receipt",
)))
CLOCKS = ("observation_time_utc", "release_time_utc", "available_at_utc", "fetch_time_utc")
STATUSES = {"PASS", "FAIL", "UNKNOWN"}
BINDING = ("run_id", "source_id", "artifact_sha256", "at_utc", "status", "reason")
RECORD_KEYS = {"stage", "evidence_id", *BINDING}
EXTRA_KEYS = {
    "TRANSFER_REQUESTED": {"receiver_id", "destination"},
    "TRANSFERRED": {"receiver_id", "destination", "request_evidence_id", "received_sha256"},
    "CONSUMER_OBSERVED": {"consumer_id", "observed_sha256"},
    "EFFECTIVE": {"consumer_id", "observation_evidence_id", "effective_sha256"},
}


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, ensure_ascii=True, separators=(",", ":"),
                       allow_nan=False) + "\n").encode("utf-8")


def payload_sha256(payload: dict[str, Any]) -> str:
    return hashlib.sha256(canonical_bytes(payload)).hexdigest()


def text(value: Any, field: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{field}: nonempty string required")
    return value


def sha(value: Any, field: str) -> str:
    if not isinstance(value, str) or re.fullmatch(r"[0-9a-f]{64}", value) is None:
        raise ValueError(f"{field}: lowercase SHA256 required")
    return value


def obj(value: Any, keys: set[str], field: str) -> dict[str, Any]:
    if not isinstance(value, dict) or set(value) != keys:
        raise ValueError(f"{field}: exact keys required {sorted(keys)}")
    return value


def utc(value: Any, field: str, as_of: datetime | None = None) -> datetime:
    if not isinstance(value, str) or re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ", value) is None:
        raise ValueError(f"{field}: UTC YYYY-MM-DDTHH:MM:SSZ required")
    try:
        result = datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ")
    except ValueError as exc:
        raise ValueError(f"{field}: invalid recorded timestamp") from exc
    if as_of is not None and result > as_of:
        raise ValueError(f"{field}: recorded timestamp is future to as_of_utc")
    return result


def validate_manifest(manifest: Any) -> dict[str, Any]:
    """PASS validates declarations/bindings; it never certifies a real run GREEN."""
    rows: dict[str, dict[str, Any]] = {}
    evidence: dict[str, dict[str, Any]] = {}
    errors: list[str] = []
    try:
        m = obj(manifest, {
            "schema_version", "authority", "label", "run_id", "source", "as_of_utc",
            "clocks", "stages", "evidence", "last_good", "known_failures",
        }, "manifest")
        if m["schema_version"] != SCHEMA or m["authority"] != "OFFLINE_ONLY":
            raise ValueError("manifest: unsupported schema or authority")
        if m["label"] not in {"FIXTURE_ONLY", "ACTUAL_UNQUALIFIED"}:
            raise ValueError("label: FIXTURE_ONLY or ACTUAL_UNQUALIFIED required")
        run = text(m["run_id"], "run_id")
        source = obj(m["source"], {"source_id", "artifact_sha256"}, "source")
        source_id = text(source["source_id"], "source_id")
        artifact = sha(source["artifact_sha256"], "artifact_sha256")
        as_of = utc(m["as_of_utc"], "as_of_utc")
        clocks = obj(m["clocks"], set(CLOCKS), "clocks")
        for name, value in clocks.items():
            if value is not None:
                utc(value, name, as_of)
        for name in ("stages", "evidence", "known_failures"):
            if not isinstance(m[name], list):
                raise ValueError(f"{name}: list required")
        for token in m["known_failures"]:
            text(token, "known_failure")
        if m["last_good"] is not None:
            prior = obj(m["last_good"], {"run_id", "source_id", "artifact_sha256", "at_utc"}, "last_good")
            for name in ("run_id", "source_id"):
                text(prior[name], f"last_good.{name}")
            sha(prior["artifact_sha256"], "last_good.artifact_sha256")
            utc(prior["at_utc"], "last_good.at_utc", as_of)
            if prior["run_id"] == run:
                raise ValueError("last_good: must identify a separate previous run")
        for record in m["stages"]:
            r = obj(record, RECORD_KEYS, "stage")
            stage = r["stage"]
            if not isinstance(stage, str) or stage not in STAGES or stage in rows:
                raise ValueError("stage: unknown or duplicate stage")
            if (r["run_id"], r["source_id"], r["artifact_sha256"]) != (run, source_id, artifact):
                raise ValueError(f"{stage}: run/source/artifact binding mismatch")
            if r["status"] not in STATUSES:
                raise ValueError(f"{stage}: invalid status")
            text(r["reason"], f"{stage}.reason")
            utc(r["at_utc"], f"{stage}.at_utc", as_of)
            if r["evidence_id"] is not None:
                text(r["evidence_id"], f"{stage}.evidence_id")
            rows[stage] = r
        previous = None
        for stage in STAGES:
            if stage in rows:
                current = utc(rows[stage]["at_utc"], f"{stage}.at_utc")
                if previous is not None and current < previous:
                    raise ValueError(f"{stage}: stage chronology reversed")
                previous = current
        for item in m["evidence"]:
            e = obj(item, {"evidence_id", "sha256", "payload"}, "evidence")
            eid = text(e["evidence_id"], "evidence_id")
            if eid in evidence:
                raise ValueError("evidence: duplicate evidence_id")
            sha(e["sha256"], f"{eid}.sha256")
            if not isinstance(e["payload"], dict) or payload_sha256(e["payload"]) != e["sha256"]:
                raise ValueError(f"{eid}: evidence payload hash mismatch")
            evidence[eid] = e
        used: set[str] = set()
        for stage, r in rows.items():
            eid = r["evidence_id"]
            if eid is None or eid not in evidence:
                continue  # A claim without its receipt remains UNKNOWN.
            if eid in used:
                raise ValueError(f"{stage}: evidence reuse")
            used.add(eid)
            p = obj(evidence[eid]["payload"],
                    {"kind", "basis", *BINDING, *EXTRA_KEYS.get(stage, set())}, f"{stage}.payload")
            if p["kind"] != KINDS[stage] or p["basis"] != "EXPLICIT_STAGE_ATTESTATION":
                raise ValueError(f"{stage}: explicit stage-specific attestation required")
            if any(p[name] != r[name] for name in BINDING):
                raise ValueError(f"{stage}: evidence binding mismatch")
            for name in EXTRA_KEYS.get(stage, set()):
                text(p[name], f"{stage}.{name}")
            if stage == "FETCHED" and clocks["fetch_time_utc"] != r["at_utc"]:
                raise ValueError("FETCHED: fetch clock must match fetch receipt time")
            if stage == "TRANSFERRED":
                if p["received_sha256"] != artifact:
                    raise ValueError("TRANSFERRED: received artifact hash mismatch")
                request = rows.get("TRANSFER_REQUESTED")
                if request and request["evidence_id"] in evidence:
                    req = evidence[request["evidence_id"]]["payload"]
                    if (p["request_evidence_id"] != request["evidence_id"]
                            or (p["receiver_id"], p["destination"]) != (req["receiver_id"], req["destination"])):
                        raise ValueError("TRANSFERRED: request/receiver/destination mismatch")
            if stage == "CONSUMER_OBSERVED" and p["observed_sha256"] != artifact:
                raise ValueError("CONSUMER_OBSERVED: observed artifact hash mismatch")
            if stage == "EFFECTIVE":
                if p["effective_sha256"] != artifact:
                    raise ValueError("EFFECTIVE: effective artifact hash mismatch")
                observation = rows.get("CONSUMER_OBSERVED")
                if observation and observation["evidence_id"] in evidence:
                    observed = evidence[observation["evidence_id"]]["payload"]
                    if (p["observation_evidence_id"] != observation["evidence_id"]
                            or p["consumer_id"] != observed["consumer_id"]):
                        raise ValueError("EFFECTIVE: consumer/observation mismatch")
        if set(evidence) - used:
            raise ValueError("evidence: orphan receipt not bound to a stage")
    except (ValueError, TypeError, KeyError, OverflowError) as exc:
        errors.append(str(exc))
    m = manifest if isinstance(manifest, dict) else {}
    source = m.get("source") if isinstance(m.get("source"), dict) else {}
    output_rows = []
    predecessor_pass = True
    for stage in STAGES:
        r = rows.get(stage)
        status, reason = "UNKNOWN", "MISSING_STAGE"
        eid = r["evidence_id"] if r else None
        if errors:
            reason = "MANIFEST_REFUSED"
        elif r is not None:
            if r["status"] == "FAIL":
                status, reason = "FAIL", r["reason"]  # Explicit failure is never erased.
            elif eid is None or eid not in evidence:
                reason = "MISSING_EXPLICIT_RECEIPT"
            elif r["status"] == "UNKNOWN":
                reason = r["reason"]
            elif not predecessor_pass:
                reason = "PREDECESSOR_NOT_PASS"
            else:
                status, reason = "PASS", r["reason"]
        predecessor_pass = predecessor_pass and status == "PASS"
        output_rows.append({
            "stage": stage, "run_id": m.get("run_id"), "source_id": source.get("source_id"),
            "artifact_sha256": source.get("artifact_sha256"), "at_utc": r["at_utc"] if r else None,
            "status": status, "reason": reason, "declared_status": r["status"] if r else None,
            "evidence_id": eid, "evidence_sha256": evidence[eid]["sha256"] if eid in evidence else None,
        })
    return {
        "schema_version": "ea_lab_news_macro_stage_ledger/1",
        "authority": "OFFLINE_ONLY", "label": m.get("label"),
        "validation_status": "REFUSED" if errors else "PASS", "errors": errors,
        "run_id": m.get("run_id"), "source": source, "as_of_utc": m.get("as_of_utc"),
        "clocks": m.get("clocks"), "stages": output_rows,
        "last_good": m.get("last_good"), "last_good_used_for_current_run": False,
        "known_failures": m.get("known_failures", []),
        "actual_run_green": "UNKNOWN", "runtime_effectiveness_certified": False,
        "interpretation": "Explicit declarations only; no runtime/EA/Monitor acceptance or routing authority.",
    }


def no_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    value: dict[str, Any] = {}
    for key, item in pairs:
        if key in value:
            raise ValueError(f"duplicate JSON key: {key}")
        value[key] = item
    return value


def reject_number(value: str) -> Any:
    raise ValueError(f"numeric field outside manifest schema: {value}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True, help="Explicit frozen UTF-8 JSON manifest")
    args = parser.parse_args()
    try:
        manifest = json.loads(args.input.read_text(encoding="utf-8"),
                              object_pairs_hook=no_duplicate_keys, parse_int=reject_number, parse_float=reject_number,
                              parse_constant=lambda value: (_ for _ in ()).throw(ValueError(f"invalid JSON: {value}")))
    except (OSError, UnicodeError, ValueError) as exc:
        sys.stdout.buffer.write(canonical_bytes({"validation_status": "REFUSED", "errors": [str(exc)]}))
        return 2
    result = validate_manifest(manifest)
    sys.stdout.buffer.write(canonical_bytes(result))
    return 0 if result["validation_status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
