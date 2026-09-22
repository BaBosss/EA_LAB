from __future__ import annotations

import argparse
import calendar
import csv
import hashlib
import json
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Any

EXPECTED_CAUSAL_TIMELINE_SHA = "44ed3c16451bf9d8e9066d1f552939c62d3c0bfcb1c9059613ad4150d963ed5f"
EXPECTED_CAUSAL_MANIFEST_SHA = "436baeeb45d1aba7d5176473dbc462963e43d1b31937e3fcbdf16ad76771d3e1"
EXPECTED_MACRO_CORE_SHA = "80a71cb73a54bfcfaae49857c2d977f5a6e120e553428035178043dd5717de93"
EXPECTED_LABCORE_SHA = "e4b89caf9c2ea725127fa7b34bdfc3484f242651f82aa7eb4850b7cb485e8301"
EXPECTED_CLOCK_CONTRACT_SHA = "ce472070a96b970ea280aa672988bc8c05207b9ded9234c86b08e49703737a37"
EXPECTED_NORMALIZER_SHA = "cad32322e70fed379dc1ee8e19755d8256b29828fd4ccc3ea022fde19b1a34dd"
VALID_STATES = {"RISK_ON", "NEUTRAL", "RISK_OFF", "STRESS", "UNKNOWN"}


class Refused(ValueError):
    pass


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def utc(value: str) -> datetime:
    if not isinstance(value, str) or not value.endswith("Z"):
        raise Refused("UTC_Z_REQUIRED")
    try:
        out = datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError as exc:
        raise Refused("INVALID_UTC") from exc
    return out.astimezone(timezone.utc)


def nth_sunday(year: int, month: int, n: int) -> date:
    weeks = calendar.monthcalendar(year, month)
    sundays = [w[calendar.SUNDAY] for w in weeks if w[calendar.SUNDAY]]
    return date(year, month, sundays[n - 1])


def is_transition_server_date(value: date) -> bool:
    return value in (nth_sunday(value.year, 3, 2), nth_sunday(value.year, 11, 1))


def server_offset_hours_for_date(value: date) -> int:
    if is_transition_server_date(value):
        raise Refused("UNKNOWN_DST_TRANSITION")
    start = nth_sunday(value.year, 3, 2)
    end = nth_sunday(value.year, 11, 1)
    return 3 if start < value < end else 2
def utc_to_server(value: datetime) -> tuple[datetime, int]:
    if value.tzinfo is None:
        raise Refused("UTC_AWARE_REQUIRED")
    value = value.astimezone(timezone.utc)
    candidates: list[tuple[datetime, int]] = []
    for offset in (2, 3):
        server = (value + timedelta(hours=offset)).replace(tzinfo=None)
        if is_transition_server_date(server.date()):
            continue
        if server_offset_hours_for_date(server.date()) == offset:
            candidates.append((server, offset))
    if len(candidates) != 1:
        raise Refused("UTC_TO_SERVER_UNRESOLVED")
    return candidates[0]


def server_to_utc(value: datetime) -> datetime:
    if value.tzinfo is not None:
        raise Refused("SERVER_TIME_MUST_BE_NAIVE")
    offset = server_offset_hours_for_date(value.date())
    return (value - timedelta(hours=offset)).replace(tzinfo=timezone.utc)


def _assert_hash(path: Path, expected: str, label: str) -> None:
    if sha256_file(path) != expected:
        raise Refused(label + "_HASH_MISMATCH")


def bind_core_semantics(repo: Path) -> dict[str, Any]:
    repo = Path(repo)
    macro_core = repo / "ea_template/core/MacroGate_Core.mqh"
    labcore = repo / "ea_template/core/LabCore.mqh"
    clock_contract = repo / "docs/research/HISTORICAL_BROKER_CLOCK_CONTRACT_20260907.md"
    normalizer = repo / "tools/P4BMarketDataExporter/normalize_ohlc.py"
    _assert_hash(macro_core, EXPECTED_MACRO_CORE_SHA, "MACRO_CORE")
    _assert_hash(labcore, EXPECTED_LABCORE_SHA, "LABCORE")
    _assert_hash(clock_contract, EXPECTED_CLOCK_CONTRACT_SHA, "CLOCK_CONTRACT")
    _assert_hash(normalizer, EXPECTED_NORMALIZER_SHA, "NORMALIZER")
    core = macro_core.read_text(encoding="utf-8-sig")
    lab = labcore.read_text(encoding="utf-8-sig")
    required = [
        'if(st == MG_ST_UNKNOWN) { skipped++; continue; }',
        'if(mg_rowTime[i] <= nowServer) idx = i;',
        'if(mg_rowStaleMaxHours > 0 && rowAgeH > (double)mg_rowStaleMaxHours)',
    ]
    if any(snippet not in core for snippet in required):
        raise Refused("MACRO_CORE_SEMANTICS_DRIFT")
    if 'MG_Setup(_MG_LotMult, _MG_BlockNew, _MG_TriggerRiskOff, _MG_OffsetHours, 8760, 168);' not in lab:
        raise Refused("SELF_GATE_STALE_POLICY_DRIFT")
    return {
        "macro_core_sha256": EXPECTED_MACRO_CORE_SHA,
        "labcore_sha256": EXPECTED_LABCORE_SHA,
        "clock_contract_sha256": EXPECTED_CLOCK_CONTRACT_SHA,
        "normalizer_sha256": EXPECTED_NORMALIZER_SHA,
        "unknown_rows_skipped": True,
        "row_asof_last_valid_le_now": True,
        "tester_row_stale_hours": 168,
        "native_offset_input": "_MG_OffsetHours",
    }
def _load_causal(timeline: Path, manifest: Path) -> tuple[list[dict[str, str]], dict[str, Any]]:
    _assert_hash(timeline, EXPECTED_CAUSAL_TIMELINE_SHA, "CAUSAL_TIMELINE")
    _assert_hash(manifest, EXPECTED_CAUSAL_MANIFEST_SHA, "CAUSAL_MANIFEST")
    meta = json.loads(manifest.read_text(encoding="utf-8-sig"))
    if meta.get("timeline_sha256") != EXPECTED_CAUSAL_TIMELINE_SHA:
        raise Refused("CAUSAL_MANIFEST_BINDING_MISMATCH")
    if meta.get("classification") != "CAUSAL_MACRO_REPLAY_RESEARCH_ONLY":
        raise Refused("CAUSAL_CLASSIFICATION_MISMATCH")
    if meta.get("can_execute") is not False or meta.get("performance") != "NOT_RUN":
        raise Refused("UPSTREAM_AUTHORITY_EXPANDED")
    rows: list[dict[str, str]] = []
    with timeline.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        needed = {
            "valid_from_utc", "valid_to_utc", "macro_state", "macro_as_of_utc",
            "macro_source_date", "macro_ri", "macro_confidence", "macro_coverage",
            "macro_missing_inputs", "macro_partial", "macro_flags",
        }
        if not needed.issubset(set(reader.fieldnames or [])):
            raise Refused("CAUSAL_COLUMNS_MISSING")
        prior_end = None
        for row in reader:
            start, end = utc(row["valid_from_utc"]), utc(row["valid_to_utc"])
            if end <= start:
                raise Refused("CAUSAL_INTERVAL_INVALID")
            if prior_end is not None and start != prior_end:
                raise Refused("CAUSAL_INTERVAL_GAP_OR_OVERLAP")
            prior_end = end
            if row["macro_state"] not in VALID_STATES:
                raise Refused("CAUSAL_STATE_UNKNOWN")
            if row["macro_as_of_utc"] and utc(row["macro_as_of_utc"]) > start:
                raise Refused("CAUSAL_VISIBLE_BEFORE_ASOF")
            rows.append(row)
    if len(rows) != meta.get("macro_interval_count"):
        raise Refused("CAUSAL_COUNT_MISMATCH")
    return rows, meta
def build_native_candidate(
    timeline: Path,
    manifest: Path,
    repo: Path,
) -> dict[str, Any]:
    rows, upstream = _load_causal(Path(timeline), Path(manifest))
    core = bind_core_semantics(Path(repo))
    native: list[dict[str, Any]] = []
    quarantine: list[dict[str, Any]] = []
    offsets = {2: 0, 3: 0}
    roundtrip_checked = 0

    for row in rows:
        start = utc(row["valid_from_utc"])
        state = row["macro_state"]
        try:
            server, offset = utc_to_server(start)
        except Refused as exc:
            if str(exc) != "UTC_TO_SERVER_UNRESOLVED":
                raise
            # At this source cadence, unresolved mapping is accepted only when both
            # UTC+2/+3 candidates land on the broker transition server date.
            d2 = (start + timedelta(hours=2)).date()
            d3 = (start + timedelta(hours=3)).date()
            if d2 != d3 or not is_transition_server_date(d2):
                raise
            quarantine.append({
                "utc_time": row["valid_from_utc"],
                "server_date": d2.isoformat(),
                "state": state,
                "ri": row["macro_ri"],
                "flags": row["macro_flags"],
                "reason": "UNKNOWN_DST_TRANSITION",
            })
            continue
        if server_to_utc(server) != start:
            raise Refused("CLOCK_ROUNDTRIP_MISMATCH")
        offsets[offset] += 1
        roundtrip_checked += 1
        if state == "UNKNOWN":
            quarantine.append({
                "utc_time": row["valid_from_utc"],
                "server_date": server.date().isoformat(),
                "state": state,
                "ri": row["macro_ri"],
                "flags": row["macro_flags"],
                "reason": "SOURCE_UNKNOWN",
            })
            continue
        native.append({
            "datetime": server.strftime("%Y.%m.%d %H:%M"),
            "state": state,
            "ri": row["macro_ri"],
            "flags": row["macro_flags"],
            "source_utc": row["valid_from_utc"],
            "offset_hours": offset,
        })

    native_times = [datetime.strptime(r["datetime"], "%Y.%m.%d %H:%M") for r in native]
    if native_times != sorted(native_times) or len(native_times) != len(set(native_times)):
        raise Refused("NATIVE_TIMES_NOT_STRICTLY_ASCENDING_UNIQUE")
    if len(native) > 8192:
        raise Refused("MACROGATE_MAX_ROWS_EXCEEDED")
    # Model the current MacroGate parser: UNKNOWN rows are skipped; RowAsOf keeps
    # the last valid row <= now. Every broker transition date must therefore be
    # treated as a native-parity mismatch unless a core/test seam can explicitly
    # clear/inactivate the gate for that quarantine.
    hazards: list[dict[str, Any]] = []
    parsed_rows = [(datetime.strptime(r["datetime"], "%Y.%m.%d %H:%M"), r["state"]) for r in native]
    for q in quarantine:
        if q["reason"] != "UNKNOWN_DST_TRANSITION":
            hazards.append({
                **q,
                "probe_server_time": q["server_date"] + " 12:00",
                "current_core_asof_state": None,
                "expected_state": "UNKNOWN",
                "mismatch": True,
                "cause": "SOURCE_UNKNOWN_NOT_REPRESENTABLE_CURRENT_CORE",
            })
            continue
        probe = datetime.fromisoformat(q["server_date"] + "T12:00:00")
        prior = [item for item in parsed_rows if item[0] <= probe]
        selected_time, selected_state = prior[-1] if prior else (None, None)
        age_h = None if selected_time is None else (probe - selected_time).total_seconds() / 3600.0
        hazards.append({
            **q,
            "probe_server_time": probe.strftime("%Y.%m.%d %H:%M"),
            "current_core_asof_state": selected_state,
            "current_core_asof_row_time": None if selected_time is None else selected_time.strftime("%Y.%m.%d %H:%M"),
            "current_core_row_age_hours": age_h,
            "row_stale_limit_hours": core["tester_row_stale_hours"],
            "expected_state": "UNKNOWN_DST_TRANSITION",
            "mismatch": True,
            "cause": "UNKNOWN_ROW_SKIPPED_PRIOR_STATE_PERSISTS",
        })

    state_value_mismatch_count = sum(
        1 for h in hazards
        if h["reason"] == "UNKNOWN_DST_TRANSITION"
        and h.get("current_core_asof_state") != h.get("state")
    )
    trigger_states = {"RISK_OFF", "STRESS"}
    trigger_behavior_mismatch_count = sum(
        1 for h in hazards
        if h["reason"] == "UNKNOWN_DST_TRANSITION"
        and ((h.get("current_core_asof_state") in trigger_states) != (h.get("state") in trigger_states))
    )

    return {
        "schema_version": "ea_lab_macrogate_native_parity_candidate/1",
        "classification": "NATIVE_PARITY_TOOLING_ONLY",
        "source_timeline_sha256": EXPECTED_CAUSAL_TIMELINE_SHA,
        "source_manifest_sha256": EXPECTED_CAUSAL_MANIFEST_SHA,
        "source_interval_count": len(rows),
        "stable_native_row_count": len(native),
        "quarantine_row_count": len(quarantine),
        "quarantine_state_value_mismatch_count": state_value_mismatch_count,
        "quarantine_trigger_behavior_mismatch_count": trigger_behavior_mismatch_count,
        "clock_roundtrip_checked": roundtrip_checked,
        "offset_counts": {"UTC_PLUS_2": offsets[2], "UTC_PLUS_3": offsets[3]},
        "core_binding": core,
        "native_csv_offset_hours": 0,
        "native_candidate_rows": native,
        "quarantine_rows": quarantine,
        "quarantine_hazards": hazards,
        "quarantine_representable_by_current_core": False if hazards else True,
        "native_parity_qualified": False if hazards else True,
        "blocker": "CORE_SEAM_REQUIRED_UNKNOWN_TRANSITION_CANNOT_CLEAR_GATE" if hazards else "",
        "can_execute": False,
        "performance": "NOT_RUN",
        "holdout_used": False,
        "probability": None,
    }
def write_artifacts(result: dict[str, Any], out_dir: Path) -> dict[str, Any]:
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=False)
    native_path = out_dir / "macrogate_native_candidate.csv"
    with native_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=("datetime", "state", "ri", "flags"), lineterminator="\n")
        writer.writeheader()
        for row in result["native_candidate_rows"]:
            writer.writerow({k: row[k] for k in ("datetime", "state", "ri", "flags")})

    qpath = out_dir / "macrogate_native_quarantine.csv"
    qfields = (
        "utc_time", "server_date", "state", "ri", "flags", "reason",
        "probe_server_time", "current_core_asof_state",
        "current_core_asof_row_time", "current_core_row_age_hours",
        "row_stale_limit_hours", "expected_state", "mismatch", "cause",
    )
    with qpath.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=qfields, lineterminator="\n")
        writer.writeheader()
        for row in result["quarantine_hazards"]:
            writer.writerow({k: row.get(k) for k in qfields})

    manifest = {k: v for k, v in result.items() if k not in {"native_candidate_rows", "quarantine_rows", "quarantine_hazards"}}
    manifest.update({
        "native_candidate_file": native_path.name,
        "native_candidate_sha256": sha256_file(native_path),
        "quarantine_file": qpath.name,
        "quarantine_sha256": sha256_file(qpath),
    })
    mpath = out_dir / "macrogate_native_parity_manifest.json"
    mtext = json.dumps(manifest, sort_keys=True, indent=2, ensure_ascii=True) + "\n"
    mpath.write_text(mtext, encoding="utf-8", newline="\n")
    return {
        "manifest": str(mpath),
        "manifest_sha256": sha256_file(mpath),
        "native_candidate_sha256": manifest["native_candidate_sha256"],
        "quarantine_sha256": manifest["quarantine_sha256"],
        "stable_native_row_count": manifest["stable_native_row_count"],
        "quarantine_row_count": manifest["quarantine_row_count"],
        "native_parity_qualified": manifest["native_parity_qualified"],
        "blocker": manifest["blocker"],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--timeline", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    result = build_native_candidate(args.timeline, args.manifest, args.repo)
    print(json.dumps(write_artifacts(result, args.out), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
