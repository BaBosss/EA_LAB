"""Read three qualified Git feed formats without inferring guard application.

No CSV globbing, filesystem freshness, runtime discovery, GV reads or writes.
Historical Git captures are not live observations. Source parser qualification
is bound to the inspected producer bytes in CC00's source map.
"""
from __future__ import annotations

import argparse
import csv
import io
import json
import math
import re
import sys
from dataclasses import replace
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
from tools.control_center.contracts import GuardObservation, ProjectionError, observe, parse_json, safe_text, digest, utc
from tools.control_center.contracts.observations import hex_value
from tools.mobile_report_hub.build_index import regular_blob, BuildError, resolve_ref

SOURCES = {
    "news_calendar": ("NewsGuard", "portfolio/news_week.csv", "scripts/news_calendar.ps1"),
    "mris_snapshot": ("MacroGate", "portfolio/mris/regime_state.json", "scripts/mris/mris_classify.ps1"),
    "macro_timeline": ("MacroGate", "portfolio/EA_LAB_mris_regime.csv", "scripts/mris/mris_export_regime.ps1"),
}
STATES = {"RISK_ON", "NEUTRAL", "RISK_OFF", "STRESS"}
ACTIONS = ("NEW_MARKET_ENTRY", "ADD", "NEW_PENDING_PLACEMENT", "CANCEL_EXISTING_PENDING",
           "MANAGE_EXISTING_BASKET", "FLATTEN", "HEDGE", "CLOSE")


def number(value):
    if type(value) not in (int, float) or not math.isfinite(value):
        raise ProjectionError("MALFORMED_NUMBER")
    return value


def minute(value, offset_hours):
    if not isinstance(value, str) or not re.fullmatch(r"\d{4}\.\d\d\.\d\d \d\d:\d\d", value):
        raise ProjectionError("UNKNOWN_TIMESTAMP_BASIS")
    try:
        return datetime.strptime(value, "%Y.%m.%d %H:%M").replace(
            tzinfo=timezone(timedelta(hours=offset_hours))).astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    except ValueError:
        raise ProjectionError("INVALID_TIMESTAMP") from None


def csv_rows(raw, fields):
    reader = csv.DictReader(io.StringIO(raw.decode("utf-8-sig")), strict=True)
    if reader.fieldnames != fields:
        raise ProjectionError("SOURCE_SCHEMA_MISMATCH")
    rows = list(reader)
    if any(set(row) != set(fields) or any(v is None for v in row.values()) for row in rows):
        raise ProjectionError("SOURCE_SCHEMA_MISMATCH")
    return rows


def news(raw):
    rows = csv_rows(raw, ["BkkTime", "Currency", "Title", "TimeRaw", "Forecast", "Previous"])
    events, seen, previous = [], set(), None
    for row in rows:
        stamp = minute(row["BkkTime"], 7)  # Producer-owned Bangkok conversion; never parse TimeRaw ET.
        currency, title = row["Currency"], safe_text(row["Title"])
        if not re.fullmatch(r"[A-Z]{3}", currency):
            raise ProjectionError("INVALID_CURRENCY")
        key = (stamp, currency, title)
        if key in seen or (previous is not None and stamp < previous):
            raise ProjectionError("DUPLICATE_OR_OUT_OF_ORDER_EVENT")
        seen.add(key)
        previous = stamp
        events.append({"event_id": digest(json.dumps(key).encode()), "event_at_utc": stamp,
                       "currency": currency, "title": title, "importance": "High",
                       "importance_basis": "PRODUCER_FILTER", "available_at": None})
    return {"events": events, "event_count": len(events), "feed_observed_at": None,
            "clock_note": "BANGKOK_EVENT_TIME_ONLY_NO_PRODUCER_TIMESTAMP"}


def mris(raw):
    data = parse_json(raw)
    fields = {"generated_utc", "state", "risk_index", "bias", "confidence", "confidence_frac",
              "active_count", "flags", "data_pending", "barometers"}
    if set(data) != fields or data["state"] not in STATES:
        raise ProjectionError("SOURCE_SCHEMA_MISMATCH")
    utc(data["generated_utc"])
    risk, confidence = number(data["risk_index"]), number(data["confidence_frac"])
    if not 0 <= confidence <= 1 or type(data["active_count"]) is not int or data["active_count"] < 0:
        raise ProjectionError("MALFORMED_NUMBER")
    if any(not isinstance(data[k], list) for k in ("flags", "data_pending", "barometers")):
        raise ProjectionError("SOURCE_SCHEMA_MISMATCH")
    # Do not copy free-text reasons, barometer data, confidence labels or raw scope.
    return {"regime_state": data["state"], "risk_index": risk, "risk_index_unit": "DIMENSIONLESS",
            "active_count": data["active_count"], "feed_observed_at": data["generated_utc"],
            "clock_note": "PRODUCER_UTC_NO_QUALIFIED_FEED_TTL"}


def timeline(raw, as_of):
    rows = csv_rows(raw, ["datetime", "state", "ri", "flags"])
    selected, previous, future_count = None, None, 0
    for row in rows:
        stamp = minute(row["datetime"], 0)
        if previous is not None and stamp <= previous:
            raise ProjectionError("DUPLICATE_OR_OUT_OF_ORDER_EVENT")
        previous = stamp
        if row["state"] not in STATES or not re.fullmatch(r"-?\d+(?:\.\d+)?", row["ri"]):
            raise ProjectionError("MALFORMED_NUMBER_OR_STATE")
        risk = number(float(row["ri"]))
        if utc(stamp) <= utc(as_of):
            selected = {"event_at_utc": stamp, "regime_state": row["state"], "risk_index": risk,
                        "risk_index_unit": "DIMENSIONLESS"}
        else:
            future_count += 1
    return {"latest_as_of_row": selected, "row_count": len(rows), "future_rows_withheld": future_count,
            "feed_observed_at": None, "clock_note": "UTC_ROW_TIME_EXPORTER_CAN_FALL_BACK_TO_NOW"}


def project_feed(source_id, raw, *, sha, as_of, producer_bound=True):
    """Internal byte parser. Production callers use build_guard_projection.

    producer_bound means qualified parser lineage, NOT a runtime source binding.
    Even valid data never supplies BLOCK/ALLOW or enabled/disabled runtime state.
    """
    guard, path, producer = SOURCES[source_id]
    payload, malformed, reason = {}, False, "NO_QUALIFIED_RUNTIME_OBSERVATION"
    if raw is not None and producer_bound:
        try:
            payload = news(raw) if source_id == "news_calendar" else mris(raw) if source_id == "mris_snapshot" else timeline(raw, as_of)
        except (ProjectionError, ValueError, TypeError, UnicodeError, csv.Error, KeyError):
            malformed, reason = True, "FEED_SCHEMA_OR_VALUE_INVALID"
    elif not producer_bound:
        reason = "PRODUCER_VERSION_UNQUALIFIED"
    observed = payload.get("feed_observed_at")
    observation = observe(source_id=source_id, source_path=path, canonical_sha=sha, raw=raw,
                          as_of=as_of, observed_at=observed,
                          clock_basis="UTC" if observed else "UNKNOWN", historical=True,
                          malformed=malformed, policy="PINNED_GIT_FEED_NO_RUNTIME_TTL")
    # HISTORICAL is a source provenance classification, not guard readiness.
    state = "MISSING" if raw is None else "MALFORMED" if malformed else "UNKNOWN"
    if observation.freshness == "FUTURE":
        payload = {}  # Never expose future classifier state as the current regime.
        reason = "FUTURE_OBSERVATION_WITHHELD"
    result = GuardObservation("guard_observation/1", observation, guard, state).to_dict()
    result.update(source_id=source_id, producer_path=producer, producer_binding="PINNED_SOURCE" if producer_bound else "UNQUALIFIED",
                  reason=reason if raw is not None else "SOURCE_NOT_PROVIDED", payload=payload,
                  action_effectiveness={action: "UNKNOWN" for action in ACTIONS},
                  runtime_source_binding="UNKNOWN", enabled="UNKNOWN")
    return result


def build_guard_projection(repo, sha, as_of):
    hex_value(sha, 40)
    utc(as_of)
    if resolve_ref(repo, sha) != sha:
        raise ProjectionError("CANONICAL_SHA_MISMATCH")
    source_map = parse_json((ROOT / "tools/control_center/contracts/source_map.json").read_bytes())
    hashes = {entry["path"]: entry["sha256"] for entry in source_map["sources"]}
    observations = []
    for source_id, (_, path, producer) in SOURCES.items():
        try:
            producer_bound = digest(regular_blob(repo, sha, producer)) == hashes[producer]
        except (BuildError, KeyError):
            producer_bound = False
        try:
            raw = regular_blob(repo, sha, path)
        except BuildError:
            raw = None
        observations.append(project_feed(source_id, raw, sha=sha, as_of=as_of, producer_bound=producer_bound))
    return {"schema": "guard_read_projection/1", "canonical_sha": sha, "as_of": as_of,
            "authority": "READ_ONLY_PRESENTATION", "observations": observations,
            "runtime_effectiveness": "UNKNOWN", "status": "HISTORICAL_FEEDS_ONLY"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--sha", required=True)
    parser.add_argument("--as-of", required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    try:
        data = build_guard_projection(args.repo, args.sha, args.as_of)
        with args.out.open("x", encoding="utf-8") as output:
            output.write(json.dumps(data, indent=2) + "\n")
        print("HISTORICAL_FEEDS_PROJECTED_RUNTIME_UNKNOWN")
        return 0
    except (ProjectionError, BuildError, OSError, ValueError):
        print("GUARD_PROJECTION_REFUSED", file=sys.stderr)
        return 1


if __name__ == "__main__": raise SystemExit(main())
