from __future__ import annotations

import argparse
import csv
import hashlib
import json
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Any

CLASSIFIER_ID = "BOSS19_P4_REGIME_CLASSIFIER_V1"
CLASSIFIER_VERSION = "1.0.0"
MACRO_STATES = {"RISK_ON", "NEUTRAL", "RISK_OFF", "STRESS", "UNKNOWN"}
EXPECTED_FIELDS = (
    "valid_from_utc", "valid_to_utc", "symbol", "tf", "macro_state",
    "macro_as_of_utc", "macro_source_date", "macro_ri", "macro_confidence",
    "macro_coverage", "macro_missing_inputs", "macro_partial", "macro_flags",
    "classifier_id", "classifier_version",
)
MACRO_VALUE_FIELDS = EXPECTED_FIELDS[4:13]


class Refused(ValueError):
    pass


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()
def utc(value: str) -> datetime:
    if not isinstance(value, str) or not value.endswith("Z"):
        raise Refused("UTC_Z_REQUIRED")
    try:
        parsed = datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError as exc:
        raise Refused("INVALID_UTC_TIME") from exc
    if parsed.tzinfo is None:
        raise Refused("UTC_Z_REQUIRED")
    return parsed.astimezone(timezone.utc)


def _macro_tuple(row: dict[str, str]) -> tuple[str, ...]:
    state = row["macro_state"]
    if state not in MACRO_STATES:
        raise Refused("UNKNOWN_MACRO_STATE")
    if row["macro_confidence"] not in {"HIGH", "MED", "LOW"}:
        raise Refused("UNKNOWN_CONFIDENCE")
    if row["macro_partial"] not in {"true", "false"}:
        raise Refused("INVALID_PARTIAL_FLAG")
    return tuple(row[key] for key in MACRO_VALUE_FIELDS)


def _validate_macro_clock(row: dict[str, str], valid_from: datetime) -> None:
    asof_text = row["macro_as_of_utc"]
    source_date = row["macro_source_date"]
    if not asof_text:
        if row["macro_state"] != "UNKNOWN" or source_date:
            raise Refused("MISSING_MACRO_ASOF")
        return
    asof = utc(asof_text)
    if asof > valid_from:
        raise Refused("MACRO_VISIBLE_BEFORE_ASOF")
    if source_date:
        try:
            d = date.fromisoformat(source_date)
        except ValueError as exc:
            raise Refused("INVALID_MACRO_SOURCE_DATE") from exc
        expected = datetime(d.year, d.month, d.day, tzinfo=timezone.utc) + timedelta(days=1)
        if asof != expected:
            raise Refused("NONCAUSAL_D_PLUS_ONE_RULE")
    elif row["macro_state"] != "UNKNOWN":
        raise Refused("MISSING_MACRO_SOURCE_DATE")
def _finish_cell(
    cell: tuple[str, str] | None,
    transitions: list[dict[str, str]],
    first_from: str | None,
    last_to: str | None,
    reference: list[dict[str, str]] | None,
    manifest_first: str,
    manifest_last: str,
) -> list[dict[str, str]] | None:
    if cell is None:
        return reference
    if first_from != manifest_first or last_to != manifest_last:
        raise Refused("CELL_COVERAGE_MISMATCH")
    if not transitions:
        raise Refused("CELL_HAS_NO_MACRO_TRANSITIONS")
    if reference is None:
        return transitions
    if transitions != reference:
        raise Refused("CELL_MACRO_SEQUENCE_MISMATCH")
    return reference


def extract_macro_replay(
    timeline_csv: Path,
    timeline_manifest_json: Path,
    *,
    expected_timeline_sha256: str,
    expected_manifest_sha256: str,
    expected_macro_manifest_sha256: str,
) -> dict[str, Any]:
    timeline_csv = Path(timeline_csv)
    timeline_manifest_json = Path(timeline_manifest_json)
    if sha256_file(timeline_csv) != expected_timeline_sha256:
        raise Refused("TIMELINE_HASH_MISMATCH")
    if sha256_file(timeline_manifest_json) != expected_manifest_sha256:
        raise Refused("TIMELINE_MANIFEST_HASH_MISMATCH")
    manifest = json.loads(timeline_manifest_json.read_text(encoding="utf-8-sig"))
    if manifest.get("timeline_sha256") != expected_timeline_sha256:
        raise Refused("MANIFEST_TIMELINE_BINDING_MISMATCH")
    if manifest.get("macro_manifest_sha256") != expected_macro_manifest_sha256:
        raise Refused("MACRO_MANIFEST_BINDING_MISMATCH")
    if manifest.get("classifier_id") != CLASSIFIER_ID or manifest.get("classifier_version") != CLASSIFIER_VERSION:
        raise Refused("CLASSIFIER_LINEAGE_MISMATCH")
    if manifest.get("h3_outcome_content_opened") is not False or manifest.get("holdout_included") is not False:
        raise Refused("UPSTREAM_AUTHORITY_MISMATCH")
    manifest_first = manifest.get("first_timestamp")
    manifest_last = manifest.get("last_timestamp")
    utc(manifest_first); utc(manifest_last)
    cell_rows = manifest.get("cell_coverage")
    if not isinstance(cell_rows, list) or not cell_rows:
        raise Refused("CELL_COVERAGE_REQUIRED")
    expected_cells = [(x.get("symbol"), x.get("tf")) for x in cell_rows]
    if any(not a or not b for a, b in expected_cells) or len(set(expected_cells)) != len(expected_cells):
        raise Refused("INVALID_EXPECTED_CELL_SET")

    reference: list[dict[str, str]] | None = None
    seen_cells: list[tuple[str, str]] = []
    current: tuple[str, str] | None = None
    transitions: list[dict[str, str]] = []
    last_macro: tuple[str, ...] | None = None
    prev_to: str | None = None
    first_from: str | None = None
    last_to: str | None = None
    row_count = 0

    with timeline_csv.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        missing = set(EXPECTED_FIELDS) - set(reader.fieldnames or [])
        if missing:
            raise Refused("TIMELINE_COLUMNS_MISSING")
        for row in reader:
            row_count += 1
            cell = (row["symbol"], row["tf"])
            if cell != current:
                reference = _finish_cell(
                    current, transitions, first_from, last_to,
                    reference, manifest_first, manifest_last,
                )
                if cell in seen_cells:
                    raise Refused("CELL_ROWS_NOT_CONTIGUOUS")
                seen_cells.append(cell)
                current = cell
                transitions = []
                last_macro = None
                prev_to = None
                first_from = None
                last_to = None

            valid_from = utc(row["valid_from_utc"])
            valid_to = utc(row["valid_to_utc"])
            if valid_to <= valid_from:
                raise Refused("INVALID_INTERVAL")
            if prev_to is not None and row["valid_from_utc"] != prev_to:
                raise Refused("CELL_INTERVAL_GAP_OR_OVERLAP")
            if row["classifier_id"] != CLASSIFIER_ID or row["classifier_version"] != CLASSIFIER_VERSION:
                raise Refused("ROW_CLASSIFIER_LINEAGE_MISMATCH")
            _validate_macro_clock(row, valid_from)
            macro = _macro_tuple(row)
            if macro != last_macro:
                item = {"valid_from_utc": row["valid_from_utc"]}
                item.update({key: row[key] for key in MACRO_VALUE_FIELDS})
                transitions.append(item)
                last_macro = macro
            first_from = first_from or row["valid_from_utc"]
            last_to = row["valid_to_utc"]
            prev_to = row["valid_to_utc"]
    reference = _finish_cell(
        current, transitions, first_from, last_to,
        reference, manifest_first, manifest_last,
    )
    if seen_cells != expected_cells:
        raise Refused("TIMELINE_CELL_ORDER_OR_SET_MISMATCH")
    if manifest.get("row_count") != row_count:
        raise Refused("TIMELINE_ROW_COUNT_MISMATCH")
    assert reference is not None

    intervals: list[dict[str, str]] = []
    for index, item in enumerate(reference):
        out = dict(item)
        out["valid_to_utc"] = (
            reference[index + 1]["valid_from_utc"]
            if index + 1 < len(reference) else manifest_last
        )
        if utc(out["valid_to_utc"]) <= utc(out["valid_from_utc"]):
            raise Refused("OUTPUT_INTERVAL_INVALID")
        intervals.append(out)

    return {
        "schema_version": "ea_lab_macrogate_causal_replay_extract/1",
        "classification": "CAUSAL_MACRO_REPLAY_RESEARCH_ONLY",
        "source_timeline_sha256": expected_timeline_sha256,
        "source_timeline_manifest_sha256": expected_manifest_sha256,
        "source_macro_manifest_sha256": expected_macro_manifest_sha256,
        "classifier_id": CLASSIFIER_ID,
        "classifier_version": CLASSIFIER_VERSION,
        "source_cell_count_verified": len(seen_cells),
        "source_row_count_verified": row_count,
        "macro_interval_count": len(intervals),
        "first_timestamp": manifest_first,
        "last_timestamp": manifest_last,
        "confidence_semantics": "MRIS_AGREEMENT_NOT_CALIBRATED_PROBABILITY",
        "probability": None,
        "legacy_mris_backtest_timeline": "BLOCKED_FOR_NEW_CAUSAL_INTRADAY_CLAIMS",
        "native_parity_qualified": False,
        "can_execute": False,
        "performance": "NOT_RUN",
        "holdout_used": False,
        "intervals": intervals,
    }
def write_artifacts(result: dict[str, Any], out_dir: Path) -> dict[str, Any]:
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=False)
    timeline_path = out_dir / "macrogate_causal_timeline.csv"
    fields = ("valid_from_utc", "valid_to_utc", *MACRO_VALUE_FIELDS)
    with timeline_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(result["intervals"])

    timeline_sha = sha256_file(timeline_path)
    manifest = {k: v for k, v in result.items() if k != "intervals"}
    manifest.update({
        "timeline_file": timeline_path.name,
        "timeline_sha256": timeline_sha,
        "serialization": {
            "format": "CSV", "encoding": "UTF-8", "line_endings": "LF",
            "columns": list(fields),
        },
    })
    manifest_path = out_dir / "macrogate_causal_timeline_manifest.json"
    text = json.dumps(manifest, sort_keys=True, indent=2, ensure_ascii=True) + "\n"
    manifest_path.write_text(text, encoding="utf-8", newline="\n")
    manifest_sha = sha256_file(manifest_path)
    (out_dir / "macrogate_causal_timeline_manifest.sha256").write_text(
        f"{manifest_sha}  {manifest_path.name}\n", encoding="ascii", newline="\n"
    )
    return {
        "timeline": str(timeline_path),
        "timeline_sha256": timeline_sha,
        "manifest": str(manifest_path),
        "manifest_sha256": manifest_sha,
        "interval_count": len(result["intervals"]),
        "cell_count": result["source_cell_count_verified"],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract cell-independent causal MacroGate research replay")
    parser.add_argument("--timeline", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--expected-timeline-sha256", required=True)
    parser.add_argument("--expected-manifest-sha256", required=True)
    parser.add_argument("--expected-macro-manifest-sha256", required=True)
    args = parser.parse_args()
    result = extract_macro_replay(
        args.timeline, args.manifest,
        expected_timeline_sha256=args.expected_timeline_sha256,
        expected_manifest_sha256=args.expected_manifest_sha256,
        expected_macro_manifest_sha256=args.expected_macro_manifest_sha256,
    )
    print(json.dumps(write_artifacts(result, args.out), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
