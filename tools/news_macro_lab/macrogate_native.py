from __future__ import annotations

import argparse
import calendar
import csv
import hashlib
import json
from datetime import date, datetime, time, timedelta, timezone
from pathlib import Path
from typing import Any

EXPECTED_CAUSAL_TIMELINE_SHA = "44ed3c16451bf9d8e9066d1f552939c62d3c0bfcb1c9059613ad4150d963ed5f"
EXPECTED_CAUSAL_MANIFEST_SHA = "436baeeb45d1aba7d5176473dbc462963e43d1b31937e3fcbdf16ad76771d3e1"
EXPECTED_MACRO_CORE_SHA = "afb74e22f75af3053d56ef6e8a485987fdc951f0995e44e91af91e6142778a0a"
EXPECTED_LABCORE_SHA = "92625d564f3eb461bd7d603c33633b0932e873d15267fb01cb94a98f4377039d"
EXPECTED_CLOCK_CONTRACT_SHA = "ce472070a96b970ea280aa672988bc8c05207b9ded9234c86b08e49703737a37"
EXPECTED_NORMALIZER_SHA = "cad32322e70fed379dc1ee8e19755d8256b29828fd4ccc3ea022fde19b1a34dd"
ACCEPTED_CORE_SEAM_HEAD = "5d6713cdc6b81191dc199f269bbc78789155c388"
RECOGNIZED_STATES = {"RISK_ON", "NEUTRAL", "RISK_OFF", "STRESS"}
VALID_SOURCE_STATES = RECOGNIZED_STATES | {"UNKNOWN"}
REQUIRED_TRANSITION_DATES = (
    "2020-03-08",
    "2020-11-01",
    "2021-03-14",
    "2021-11-07",
    "2022-03-13",
    "2022-11-06",
    "2023-03-12",
    "2023-11-05",
    "2024-03-10",
    "2024-11-03",
    "2025-03-09",
    "2025-11-02",
)


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
    sundays = [week[calendar.SUNDAY] for week in weeks if week[calendar.SUNDAY]]
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


def _require_snippets(text: str, snippets: tuple[str, ...], label: str) -> None:
    if any(snippet not in text for snippet in snippets):
        raise Refused(label + "_SEMANTICS_DRIFT")


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
    _require_snippets(
        core,
        (
            '#define MG_ST_UNKNOWN  (-99)',
            '#define MG_ST_INVALID  (-100)',
            'if(s == "UNKNOWN")  return MG_ST_UNKNOWN;',
            'return MG_ST_INVALID;',
            'if(st == MG_ST_INVALID) { skipped++; continue; }',
            'if(st == MG_ST_UNKNOWN && !MQLInfoInteger(MQL_TESTER)) { skipped++; continue; }',
            'if(mg_rowTime[i] <= nowServer) idx = i;',
            'if(GlobalVariableCheck(bgv)) GlobalVariableDel(bgv);',
            'if(GlobalVariableCheck(lgv)) GlobalVariableDel(lgv);',
            'if(st == MG_ST_UNKNOWN)',
            'MG_ClearAll("explicit UNKNOWN quarantine marker");',
            'bool trig = MG_StateTriggers(st);',
        ),
        "MACRO_CORE",
    )
    _require_snippets(
        lab,
        ('MG_Setup(_MG_LotMult, _MG_BlockNew, _MG_TriggerRiskOff, _MG_OffsetHours, 8760, 168);',),
        "LABCORE",
    )
    return {
        "accepted_core_seam_head": ACCEPTED_CORE_SEAM_HEAD,
        "macro_core_sha256": EXPECTED_MACRO_CORE_SHA,
        "labcore_sha256": EXPECTED_LABCORE_SHA,
        "clock_contract_sha256": EXPECTED_CLOCK_CONTRACT_SHA,
        "normalizer_sha256": EXPECTED_NORMALIZER_SHA,
        "explicit_unknown_distinct_from_invalid": True,
        "explicit_unknown_retained_in_tester": True,
        "explicit_unknown_skipped_outside_tester": True,
        "malformed_invalid_skipped": True,
        "row_asof_last_valid_le_now": True,
        "unknown_clears_block": True,
        "unknown_clears_lotmult": True,
        "next_recognized_row_resumes_normal_trigger_logic": True,
        "tester_row_stale_hours": 168,
        "required_native_offset_hours": 0,
    }


def bind_implementation(repo: Path) -> dict[str, str]:
    repo = Path(repo)
    exporter = repo / "tools/news_macro_lab/macrogate_native.py"
    tests = repo / "tools/news_macro_lab/tests/test_macrogate_native.py"
    return {
        "exporter_path": exporter.relative_to(repo).as_posix(),
        "exporter_sha256": sha256_file(exporter),
        "exporter_tests_path": tests.relative_to(repo).as_posix(),
        "exporter_tests_sha256": sha256_file(tests),
    }


def _load_causal(timeline: Path, manifest: Path) -> tuple[list[dict[str, str]], dict[str, Any]]:
    _assert_hash(timeline, EXPECTED_CAUSAL_TIMELINE_SHA, "CAUSAL_TIMELINE")
    _assert_hash(manifest, EXPECTED_CAUSAL_MANIFEST_SHA, "CAUSAL_MANIFEST")
    meta = json.loads(manifest.read_text(encoding="utf-8-sig"))
    if meta.get("timeline_sha256") != EXPECTED_CAUSAL_TIMELINE_SHA:
        raise Refused("CAUSAL_MANIFEST_BINDING_MISMATCH")
    if meta.get("classification") != "CAUSAL_MACRO_REPLAY_RESEARCH_ONLY":
        raise Refused("CAUSAL_CLASSIFICATION_MISMATCH")
    if (
        meta.get("can_execute") is not False
        or meta.get("performance") != "NOT_RUN"
        or meta.get("probability") is not None
    ):
        raise Refused("UPSTREAM_AUTHORITY_EXPANDED")
    rows: list[dict[str, str]] = []
    with timeline.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        needed = {
            "valid_from_utc",
            "valid_to_utc",
            "macro_state",
            "macro_as_of_utc",
            "macro_source_date",
            "macro_ri",
            "macro_confidence",
            "macro_coverage",
            "macro_missing_inputs",
            "macro_partial",
            "macro_flags",
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
            if row["macro_state"] not in VALID_SOURCE_STATES:
                raise Refused("CAUSAL_STATE_INVALID")
            if row["macro_as_of_utc"] and utc(row["macro_as_of_utc"]) > start:
                raise Refused("CAUSAL_VISIBLE_BEFORE_ASOF")
            rows.append(row)
    if len(rows) != meta.get("macro_interval_count"):
        raise Refused("CAUSAL_COUNT_MISMATCH")
    if rows and meta.get("first_timestamp") not in (None, rows[0]["valid_from_utc"]):
        raise Refused("CAUSAL_FIRST_TIMESTAMP_MISMATCH")
    if rows and meta.get("last_timestamp") not in (None, rows[-1]["valid_to_utc"]):
        raise Refused("CAUSAL_LAST_TIMESTAMP_MISMATCH")
    return rows, meta


def _transition_server_date(start: datetime) -> date:
    date_plus_2 = (start + timedelta(hours=2)).date()
    date_plus_3 = (start + timedelta(hours=3)).date()
    if date_plus_2 != date_plus_3 or not is_transition_server_date(date_plus_2):
        raise Refused("UTC_TO_SERVER_UNRESOLVED")
    return date_plus_2


def _native_row_asof(rows: list[dict[str, Any]], now_server: datetime) -> dict[str, Any] | None:
    selected = None
    for row in rows:
        row_time = datetime.strptime(row["datetime"], "%Y.%m.%d %H:%M")
        if row_time <= now_server:
            selected = row
        else:
            break
    return selected


def _complete_quarantine_evidence(
    native: list[dict[str, Any]], quarantine: list[dict[str, Any]]
) -> None:
    recognized = [row for row in native if row["state"] in RECOGNIZED_STATES]
    for evidence in quarantine:
        marker = datetime.strptime(evidence["native_marker_datetime"], "%Y.%m.%d %H:%M")
        prior_rows = [
            row
            for row in recognized
            if datetime.strptime(row["datetime"], "%Y.%m.%d %H:%M") < marker
        ]
        resume_rows = [
            row
            for row in recognized
            if datetime.strptime(row["datetime"], "%Y.%m.%d %H:%M") > marker
        ]
        if not prior_rows or not resume_rows:
            raise Refused("QUARANTINE_BOUNDARY_NEIGHBOR_MISSING")
        prior = prior_rows[-1]
        resume = resume_rows[0]
        resume_time = datetime.strptime(resume["datetime"], "%Y.%m.%d %H:%M")
        selected_before_resume = _native_row_asof(native, resume_time - timedelta(minutes=1))
        selected_at_resume = _native_row_asof(native, resume_time)
        if selected_before_resume is None or selected_before_resume["state"] != "UNKNOWN":
            raise Refused("UNKNOWN_NOT_SELECTED_UNTIL_RESUME")
        if selected_at_resume is None or selected_at_resume["state"] not in RECOGNIZED_STATES:
            raise Refused("RECOGNIZED_ROW_DID_NOT_RESUME")
        evidence.update(
            {
                "prior_native_datetime": prior["datetime"],
                "prior_native_state": prior["state"],
                "resume_native_datetime": resume["datetime"],
                "resume_native_state": resume["state"],
                "resume_source_utc": resume["source_utc"],
                "pre_resume_selected_state": selected_before_resume["state"],
                "at_resume_selected_state": selected_at_resume["state"],
                "unknown_selected_until_resume": True,
            }
        )


def build_native_candidate(timeline: Path, manifest: Path, repo: Path) -> dict[str, Any]:
    rows, upstream = _load_causal(Path(timeline), Path(manifest))
    core = bind_core_semantics(Path(repo))
    native: list[dict[str, Any]] = []
    quarantine: list[dict[str, Any]] = []
    offsets = {2: 0, 3: 0}
    roundtrip_checked = 0

    for index, row in enumerate(rows):
        start = utc(row["valid_from_utc"])
        source_state = row["macro_state"]
        try:
            server, offset = utc_to_server(start)
        except Refused as exc:
            if str(exc) != "UTC_TO_SERVER_UNRESOLVED":
                raise
            transition_date = _transition_server_date(start)
            marker = datetime.combine(transition_date, time.min)
            native.append(
                {
                    "datetime": marker.strftime("%Y.%m.%d %H:%M"),
                    "state": "UNKNOWN",
                    "ri": row["macro_ri"],
                    "flags": row["macro_flags"],
                    "source_utc": row["valid_from_utc"],
                    "source_state": source_state,
                    "source_interval_index": index,
                    "offset_hours": None,
                    "representation": "TRANSITION_UNKNOWN_BOUNDARY_MARKER",
                }
            )
            quarantine.append(
                {
                    "source_interval_index": index,
                    "source_valid_from_utc": row["valid_from_utc"],
                    "source_valid_to_utc": row["valid_to_utc"],
                    "source_state": source_state,
                    "source_macro_as_of_utc": row["macro_as_of_utc"],
                    "source_macro_source_date": row["macro_source_date"],
                    "source_ri": row["macro_ri"],
                    "source_confidence": row["macro_confidence"],
                    "source_coverage": row["macro_coverage"],
                    "source_missing_inputs": row["macro_missing_inputs"],
                    "source_partial": row["macro_partial"],
                    "source_flags": row["macro_flags"],
                    "transition_server_date": transition_date.isoformat(),
                    "native_marker_datetime": marker.strftime("%Y.%m.%d %H:%M"),
                    "native_marker_state": "UNKNOWN",
                    "clock_rule": "UNKNOWN_DST_TRANSITION",
                    "marker_semantics": "SERVER_DATE_BOUNDARY_NOT_SWITCH_INSTANT",
                    "source_timeline_sha256": EXPECTED_CAUSAL_TIMELINE_SHA,
                    "source_manifest_sha256": EXPECTED_CAUSAL_MANIFEST_SHA,
                    "macro_core_sha256": EXPECTED_MACRO_CORE_SHA,
                    "clock_contract_sha256": EXPECTED_CLOCK_CONTRACT_SHA,
                    "probability": None,
                }
            )
            continue
        if server_to_utc(server) != start:
            raise Refused("CLOCK_ROUNDTRIP_MISMATCH")
        offsets[offset] += 1
        roundtrip_checked += 1
        native.append(
            {
                "datetime": server.strftime("%Y.%m.%d %H:%M"),
                "state": source_state,
                "ri": row["macro_ri"],
                "flags": row["macro_flags"],
                "source_utc": row["valid_from_utc"],
                "source_state": source_state,
                "source_interval_index": index,
                "offset_hours": offset,
                "representation": "STABLE_MAPPED_ROW"
                if source_state in RECOGNIZED_STATES
                else "SOURCE_UNKNOWN_ROW",
            }
        )

    native_times = [datetime.strptime(row["datetime"], "%Y.%m.%d %H:%M") for row in native]
    if native_times != sorted(native_times) or len(native_times) != len(set(native_times)):
        raise Refused("NATIVE_TIMES_NOT_STRICTLY_ASCENDING_UNIQUE")
    if len(native) > 8192:
        raise Refused("MACROGATE_MAX_ROWS_EXCEEDED")
    if len(native) != len(rows):
        raise Refused("SOURCE_INTERVAL_REPRESENTATION_MISMATCH")
    _complete_quarantine_evidence(native, quarantine)

    unknown_rows = [row for row in native if row["state"] == "UNKNOWN"]
    source_unknown_rows = [row for row in native if row["representation"] == "SOURCE_UNKNOWN_ROW"]
    return {
        "schema_version": "ea_lab_macrogate_native_exporter_quarantine/2",
        "classification": "NATIVE_EXPORTER_QUARANTINE_QUALIFICATION_ONLY",
        "source_timeline_sha256": EXPECTED_CAUSAL_TIMELINE_SHA,
        "source_manifest_sha256": EXPECTED_CAUSAL_MANIFEST_SHA,
        "source_interval_count": len(rows),
        "represented_source_interval_count": len(native),
        "native_row_count": len(native),
        "stable_native_row_count": len(native) - len(quarantine),
        "transition_quarantine_count": len(quarantine),
        "explicit_unknown_native_row_count": len(unknown_rows),
        "source_unknown_native_row_count": len(source_unknown_rows),
        "clock_roundtrip_checked": roundtrip_checked,
        "offset_counts": {"UTC_PLUS_2": offsets[2], "UTC_PLUS_3": offsets[3]},
        "core_binding": core,
        "implementation_binding": bind_implementation(Path(repo)),
        "native_csv_offset_hours": 0,
        "native_candidate_rows": native,
        "quarantine_rows": quarantine,
        "native_rows_strictly_ascending_unique": True,
        "native_parity_qualified": True,
        "blocker": "",
        "can_execute": False,
        "performance": "NOT_RUN",
        "holdout_used": False,
        "probability": None,
        "upstream_probability": upstream.get("probability"),
    }


def validate_frozen_contract(result: dict[str, Any]) -> dict[str, Any]:
    transition_dates = tuple(row["transition_server_date"] for row in result["quarantine_rows"])
    if transition_dates != REQUIRED_TRANSITION_DATES:
        raise Refused("FROZEN_TRANSITION_DATE_SET_MISMATCH")
    required_counts = {
        "source_interval_count": 2192,
        "represented_source_interval_count": 2192,
        "native_row_count": 2192,
        "stable_native_row_count": 2180,
        "transition_quarantine_count": 12,
        "explicit_unknown_native_row_count": 12,
        "source_unknown_native_row_count": 0,
        "clock_roundtrip_checked": 2180,
    }
    if any(result.get(key) != expected for key, expected in required_counts.items()):
        raise Refused("FROZEN_COUNT_MISMATCH")
    if any(row["native_marker_state"] != "UNKNOWN" for row in result["quarantine_rows"]):
        raise Refused("TRANSITION_STATE_FABRICATED")
    if any(not row["native_marker_datetime"].endswith(" 00:00") for row in result["quarantine_rows"]):
        raise Refused("TRANSITION_MARKER_NOT_SERVER_MIDNIGHT")
    if any(not row["unknown_selected_until_resume"] for row in result["quarantine_rows"]):
        raise Refused("UNKNOWN_SELECTION_GAP")
    adversarial = next(
        row for row in result["quarantine_rows"] if row["transition_server_date"] == "2024-11-03"
    )
    if (
        adversarial["prior_native_state"] != "NEUTRAL"
        or adversarial["source_state"] != "RISK_OFF"
        or adversarial["native_marker_state"] != "UNKNOWN"
        or adversarial["pre_resume_selected_state"] != "UNKNOWN"
        or adversarial["resume_native_state"] != "RISK_OFF"
    ):
        raise Refused("ADVERSARIAL_2024_11_03_MISMATCH")
    core = result["core_binding"]
    required_core_proofs = (
        "explicit_unknown_distinct_from_invalid",
        "explicit_unknown_retained_in_tester",
        "malformed_invalid_skipped",
        "row_asof_last_valid_le_now",
        "unknown_clears_block",
        "unknown_clears_lotmult",
        "next_recognized_row_resumes_normal_trigger_logic",
    )
    if any(core.get(key) is not True for key in required_core_proofs):
        raise Refused("CURRENT_CORE_PROOF_INCOMPLETE")
    if (
        result["native_parity_qualified"] is not True
        or result["blocker"]
        or result["can_execute"] is not False
        or result["performance"] != "NOT_RUN"
        or result["probability"] is not None
    ):
        raise Refused("AUTHORITY_OR_QUALIFICATION_MISMATCH")
    validation = {
        "status": "PASS",
        "transition_cases": "12/12",
        "adversarial_2024_11_03": "PASS",
        "no_fabricated_recognized_transition_state": True,
        "prior_block_and_lotmult_cleared_by_bound_core": True,
        "malformed_native_state_skipped_by_bound_core": True,
        "next_recognized_state_resumes": True,
        "performance_authority": "NONE",
    }
    result["frozen_contract_validation"] = validation
    return validation


def write_artifacts(result: dict[str, Any], out_dir: Path) -> dict[str, Any]:
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=False)
    native_path = out_dir / "macrogate_native_candidate.csv"
    with native_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=("datetime", "state", "ri", "flags"),
            lineterminator="\n",
        )
        writer.writeheader()
        for row in result["native_candidate_rows"]:
            writer.writerow({key: row[key] for key in ("datetime", "state", "ri", "flags")})

    quarantine_path = out_dir / "macrogate_native_quarantine.csv"
    quarantine_fields = (
        "source_interval_index",
        "source_valid_from_utc",
        "source_valid_to_utc",
        "source_state",
        "source_macro_as_of_utc",
        "source_macro_source_date",
        "source_ri",
        "source_confidence",
        "source_coverage",
        "source_missing_inputs",
        "source_partial",
        "source_flags",
        "transition_server_date",
        "native_marker_datetime",
        "native_marker_state",
        "clock_rule",
        "marker_semantics",
        "prior_native_datetime",
        "prior_native_state",
        "resume_native_datetime",
        "resume_native_state",
        "resume_source_utc",
        "pre_resume_selected_state",
        "at_resume_selected_state",
        "unknown_selected_until_resume",
        "source_timeline_sha256",
        "source_manifest_sha256",
        "macro_core_sha256",
        "clock_contract_sha256",
        "probability",
    )
    with quarantine_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=quarantine_fields, lineterminator="\n")
        writer.writeheader()
        for row in result["quarantine_rows"]:
            writer.writerow({key: row.get(key) for key in quarantine_fields})

    excluded = {"native_candidate_rows", "quarantine_rows"}
    manifest = {key: value for key, value in result.items() if key not in excluded}
    manifest.update(
        {
            "native_candidate_file": native_path.name,
            "native_candidate_sha256": sha256_file(native_path),
            "quarantine_file": quarantine_path.name,
            "quarantine_sha256": sha256_file(quarantine_path),
        }
    )
    manifest_path = out_dir / "macrogate_native_parity_manifest.json"
    manifest_text = json.dumps(manifest, sort_keys=True, indent=2, ensure_ascii=True) + "\n"
    manifest_path.write_text(manifest_text, encoding="utf-8", newline="\n")
    return {
        "manifest": str(manifest_path),
        "manifest_sha256": sha256_file(manifest_path),
        "native_candidate": str(native_path),
        "native_candidate_sha256": manifest["native_candidate_sha256"],
        "quarantine": str(quarantine_path),
        "quarantine_sha256": manifest["quarantine_sha256"],
        "native_row_count": manifest["native_row_count"],
        "transition_quarantine_count": manifest["transition_quarantine_count"],
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
    validate_frozen_contract(result)
    print(json.dumps(write_artifacts(result, args.out), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
