#!/usr/bin/env python3
"""Deterministic Boss19 P4B source-bound DEAL to frozen classifier timeline join."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
from collections import Counter, defaultdict
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any, Iterable

EXPECTED = {
    "package_sha256": "1330a822ed66149ba07d693d8732ced5b9e9ce66d15f34ce8d21ef70894b760c",
    "aggregate_units_sha256": "325b6d00709c48982a5981d2d7750a6a18e99f2d77ad52b89fa8d67b50c0b699",
    "timeline_sha256": "5f3a0f8d1accd25cb6cc08ad1c6e291aed6d238d620269102151016dbfaf569d",
    "timeline_manifest_sha256": "858f4d02d1ae30511dd1f38ffab347c85c06a4a25df4bedf901dc169c2847916",
    "classifier_id": "BOSS19_P4_REGIME_CLASSIFIER_V1",
    "classifier_version": "1.0.0",
    "cell_count": 36,
    "unit_count": 1549,
    "package_review_receipt_sha256": "bb331765f169503ad878223d54a6f45fd2bb6e289609ae671857e298384463a4",
    "package_reviewed_head": "ecd5c2b3af0791674a7cce18464e632750f37755",
}
PACKAGE_SCHEMA = "BOSS19_P4B_BROAD36_SOURCE_BOUND_PACKAGE_V1"
PACKAGE_STATUS = "SOURCE_BOUND_UNIT_EVIDENCE_READY_FOR_REVIEW"
UNIT_SCHEMA = "BOSS19_P4B_SOURCE_BOUND_DEAL_V2"
PREJOIN_STATUS = "PASS_FROZEN_PACKAGE_PREJOIN_READINESS"
DETAIL_SCHEMA = "BOSS19_P4B_REGIME_ATTRIBUTION_DETAIL_V1"
AFFINITY_SCHEMA = "BOSS19_P4B_REGIME_AFFINITY_V1"
COVERAGE_SCHEMA = "BOSS19_P4B_REGIME_ATTRIBUTION_COVERAGE_V1"
RECON_SCHEMA = "BOSS19_P4B_REGIME_ATTRIBUTION_RECONCILIATION_V1"
PACKAGE_OUT_SCHEMA = "BOSS19_P4B_REGIME_ATTRIBUTION_PACKAGE_V1"
AUTHORITY = "RESEARCH_EVIDENCE_ONLY_NO_STRATEGY_VERDICT_NO_HOLDOUT_NO_OPTIMIZATION_NO_RISK_DEPLOYMENT_TRADING"
BASKET_STATUS = "UNAVAILABLE_NO_SOURCE_BASKET_ID"
DD_BASIS = "PARTITION_REALIZED_SEQUENCE"
EXPOSURE_BASIS = "UNAVAILABLE_FROM_SOURCE_BOUND_UNIT_PACKAGE"
CONFIDENCE = "UNKNOWN"
CONFIDENCE_BASIS = "NO_PREDECLARED_NUMERIC_MAPPING_IN_CONTRACT"

TIMELINE_REQUIRED = {
    "valid_from_utc", "valid_to_utc", "symbol", "tf", "macro_state", "macro_as_of_utc",
    "macro_ri", "macro_confidence", "macro_coverage", "macro_missing_inputs", "macro_partial",
    "local_state", "local_bar_close_utc", "local_d", "local_qtrend", "vol_state",
    "vol_bar_close_utc", "vol_natr_pct", "vol_q20", "vol_q80", "vol_q95",
    "local_unknown_reason", "classification_status", "classifier_id", "classifier_version",
}
UNIT_REQUIRED = {
    "schema_version", "h3_run_id", "symbol", "period_name", "configured_run_magic",
    "source_open_deal_magic", "source_close_deal_magic", "source_position_id", "source_open_deal_id",
    "source_deal_id", "entry_time_msc", "exit_time_msc", "entry_utc", "exit_utc", "time_status", "entry_volume", "exit_volume",
    "source_net_realized",
}

class Refusal(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Refusal(message)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for block in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()

def load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except (FileNotFoundError, json.JSONDecodeError) as exc:
        raise Refusal(f"cannot read JSON {path}: {exc}") from exc
    require(isinstance(value, dict), f"JSON root must be object: {path}")
    return value


def parse_z(value: str, label: str) -> datetime:
    try:
        return datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    except (TypeError, ValueError) as exc:
        raise Refusal(f"{label} malformed UTC timestamp: {value!r}") from exc


def integer(value: str, label: str) -> int:
    try:
        return int(str(value))
    except (TypeError, ValueError) as exc:
        raise Refusal(f"{label} invalid integer: {value!r}") from exc


def decimal(value: str, label: str) -> Decimal:
    try:
        return Decimal(str(value))
    except (InvalidOperation, ValueError) as exc:
        raise Refusal(f"{label} invalid decimal: {value!r}") from exc


def fmt_decimal(value: Decimal | None, places: int = 8) -> str:
    if value is None:
        return ""
    quantum = Decimal(1).scaleb(-places)
    return format(value.quantize(quantum), "f")


def bool_text(value: str) -> bool:
    normalized = str(value).strip().lower()
    require(normalized in {"true", "false"}, f"invalid boolean text: {value!r}")
    return normalized == "true"


def canonical_row_hash(row: dict[str, str]) -> str:
    raw = json.dumps(row, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


def period_to_tf(period_name: str) -> str:
    require(period_name.startswith("PERIOD_"), f"unexpected period_name: {period_name}")
    tf = period_name[len("PERIOD_"):]
    require(tf in {"M15", "H1", "H4"}, f"unsupported TF: {tf}")
    return tf

def validate_prejoin(path: Path, expected: dict[str, Any]) -> dict[str, Any]:
    value = load_json(path)
    require(value.get("status") == PREJOIN_STATUS, "prejoin readiness status is not PASS")
    require(value.get("package_sha256") == expected["package_sha256"], "prejoin package SHA drift")
    require(value.get("aggregate_units_sha256") == expected["aggregate_units_sha256"], "prejoin units SHA drift")
    require(int(value.get("observed_cell_count", -1)) == int(expected["cell_count"]), "prejoin cell count drift")
    require(int(value.get("total_realized_units", -1)) == int(expected["unit_count"]), "prejoin unit count drift")
    require(int(value.get("unique_deal_join_key_count", -1)) == int(expected["unit_count"]), "prejoin join-key count drift")
    require(value.get("holdout") == "UNSPENT", "prejoin HOLDOUT drift")
    require(value.get("optimization") == "NONE", "prejoin optimization drift")
    require(value.get("prejoin_schema_ready") is True, "prejoin schema-ready flag missing")
    require(value.get("package_review_required_before_regime_join") is True,
            "prejoin package-review boundary flag missing")
    return value


def validate_package_review_receipt(path: Path, expected: dict[str, Any]) -> dict[str, str]:
    require(path.is_file(), "package review receipt missing")
    actual = sha256(path)
    require(actual == expected["package_review_receipt_sha256"], "package review receipt SHA drift")
    text = path.read_text(encoding="utf-8-sig", errors="replace")
    require("VERDICT PASS" in text, "package review verdict is not PASS")
    require("CONFIDENCE: HIGH" in text, "package review confidence is not HIGH")
    reviewed = expected["package_reviewed_head"]
    require(f"EXACT REVIEWED HEAD: `{reviewed}`" in text, "package review head drift")
    require("RECOMMENDED ACTION: Accept the package as" in text, "package review acceptance missing")
    require("this package may serve as the evidence input to deterministic P4B regime attribution" in text,
            "package review regime-attribution authorization missing")
    return {"sha256": actual, "reviewed_head": reviewed, "verdict": "PASS", "confidence": "HIGH"}


def validate_timeline_inputs(timeline: Path, manifest_path: Path, expected: dict[str, Any]) -> dict[str, Any]:
    require(sha256(timeline) == expected["timeline_sha256"], "frozen timeline SHA drift")
    require(sha256(manifest_path) == expected["timeline_manifest_sha256"], "timeline manifest SHA drift")
    manifest = load_json(manifest_path)
    require(manifest.get("timeline_sha256") == expected["timeline_sha256"], "manifest timeline SHA drift")
    require(manifest.get("classifier_id") == expected["classifier_id"], "classifier id drift")
    require(manifest.get("classifier_version") == expected["classifier_version"], "classifier version drift")
    require(manifest.get("holdout_included") is False, "timeline manifest includes HOLDOUT")
    require(manifest.get("h3_outcome_content_opened") is False, "timeline was not frozen before H3 outcomes")
    require(int(manifest.get("row_count", -1)) > 0, "timeline manifest row_count invalid")
    require(manifest.get("serialization", {}).get("format") == "CSV", "timeline serialization drift")
    return manifest


def validate_package_inputs(package_path: Path, units_path: Path, expected: dict[str, Any]) -> tuple[dict[str, Any], dict[str, dict[str, Any]]]:
    require(sha256(package_path) == expected["package_sha256"], "frozen package SHA drift")
    require(sha256(units_path) == expected["aggregate_units_sha256"], "frozen aggregate units SHA drift")
    package = load_json(package_path)
    require(package.get("schema_version") == PACKAGE_SCHEMA, "package schema drift")
    require(package.get("status") == PACKAGE_STATUS, "package status drift")
    require(package.get("authority") == AUTHORITY, "package authority drift")
    require(package.get("holdout") == "UNSPENT", "package HOLDOUT drift")
    require(package.get("optimization") == "NONE", "package optimization drift")
    require(int(package.get("cell_count", -1)) == int(expected["cell_count"]), "package cell count drift")
    require(int(package.get("realized_unit_count", -1)) == int(expected["unit_count"]), "package unit count drift")
    cells = package.get("cells")
    require(isinstance(cells, list) and len(cells) == int(expected["cell_count"]), "package cells malformed")
    by_cell = {str(c.get("cell_id", "")): c for c in cells if isinstance(c, dict)}
    require(len(by_cell) == int(expected["cell_count"]), "package duplicate/missing cell ids")
    return package, by_cell

def load_units(path: Path, by_cell: dict[str, dict[str, Any]], expected: dict[str, Any]) -> list[dict[str, Any]]:
    try:
        with path.open("r", encoding="utf-8-sig", newline="") as fh:
            reader = csv.DictReader(fh)
            require(reader.fieldnames is not None, "aggregate units header missing")
            require(UNIT_REQUIRED.issubset(set(reader.fieldnames)), "aggregate units required fields missing")
            source_rows = list(reader)
    except (FileNotFoundError, csv.Error) as exc:
        raise Refusal(f"cannot read aggregate units: {exc}") from exc
    require(len(source_rows) == int(expected["unit_count"]), "aggregate units row-count drift")
    rows: list[dict[str, Any]] = []
    deal_keys: set[tuple[str, str]] = set()
    for line_no, source in enumerate(source_rows, 2):
        cell = source.get("h3_run_id", "")
        require(cell in by_cell, f"unit references unknown H3 cell {cell}:{line_no}")
        meta = by_cell[cell]
        require(source.get("schema_version") == UNIT_SCHEMA, f"unit schema drift {cell}:{line_no}")
        require(source.get("symbol") == meta.get("symbol"), f"unit symbol drift {cell}:{line_no}")
        tf = period_to_tf(source.get("period_name", ""))
        require(tf == meta.get("tf"), f"unit TF drift {cell}:{line_no}")
        require(source.get("time_status") == "COMPLETE", f"unit timestamp status not COMPLETE {cell}:{line_no}")
        entry = parse_z(source.get("entry_utc", ""), f"entry {cell}:{line_no}")
        exit_at = parse_z(source.get("exit_utc", ""), f"exit {cell}:{line_no}")
        require(entry <= exit_at, f"entry after exit {cell}:{line_no}")
        deal_id = source.get("source_deal_id", "")
        require(bool(deal_id), f"missing source_deal_id {cell}:{line_no}")
        key = (cell, deal_id)
        require(key not in deal_keys, f"duplicate deal join key {cell}+{deal_id}")
        deal_keys.add(key)
        net = decimal(source.get("source_net_realized", ""), f"source_net_realized {cell}:{line_no}")
        rows.append({
            "source": source, "cell": cell, "window": str(meta.get("window", "")), "symbol": str(meta.get("symbol", "")),
            "tf": tf, "entry_dt": entry, "exit_dt": exit_at, "entry_msc": integer(source.get("entry_time_msc", ""), f"entry_time_msc {cell}:{line_no}"), "exit_msc": integer(source.get("exit_time_msc", ""), f"exit_time_msc {cell}:{line_no}"), "net": net,
            "source_record_sha256": canonical_row_hash(source), "timeline": None, "unknown_reason": "",
        })
    require(len(deal_keys) == int(expected["unit_count"]), "aggregate deal-key uniqueness drift")
    return rows


def coverage_ratio(value: str) -> Decimal | None:
    text = str(value).strip()
    if not text:
        return None
    parts = text.split("/")
    if len(parts) != 2:
        return None
    num, den = decimal(parts[0], "macro coverage numerator"), decimal(parts[1], "macro coverage denominator")
    if den <= 0:
        return None
    return num / den

def timeline_unknown_reason(row: dict[str, str] | None) -> str:
    if row is None:
        return "NO_TIMELINE_ASOF_MATCH"
    if row.get("classification_status") == "CLASSIFIED":
        return ""
    reasons: list[str] = []
    if row.get("macro_state") == "UNKNOWN":
        reasons.append("MACRO_UNKNOWN")
    if row.get("local_state") == "UNKNOWN":
        detail = row.get("local_unknown_reason", "").strip()
        reasons.append("LOCAL_UNKNOWN" + (":" + detail if detail else ""))
    if row.get("vol_state") == "UNKNOWN":
        reasons.append("VOL_UNKNOWN")
    if not reasons:
        reasons.append("TIMELINE_CLASSIFICATION_UNKNOWN")
    return ";".join(reasons)


def validate_timeline_row(row: dict[str, str], line_no: int, expected: dict[str, Any], previous_to: dict[tuple[str, str], datetime]) -> tuple[tuple[str, str], datetime, datetime]:
    key = (row.get("symbol", ""), row.get("tf", ""))
    require(key[0] and key[1], f"timeline symbol/TF missing line {line_no}")
    require(row.get("classifier_id") == expected["classifier_id"], f"timeline classifier id drift line {line_no}")
    require(row.get("classifier_version") == expected["classifier_version"], f"timeline classifier version drift line {line_no}")
    status = row.get("classification_status", "")
    require(status in {"CLASSIFIED", "UNKNOWN"}, f"timeline classification_status invalid line {line_no}")
    start = parse_z(row.get("valid_from_utc", ""), f"timeline valid_from line {line_no}")
    end = parse_z(row.get("valid_to_utc", ""), f"timeline valid_to line {line_no}")
    require(start < end, f"timeline interval not positive line {line_no}")
    prior = previous_to.get(key)
    if prior is not None:
        require(start == prior, f"timeline gap/overlap/out-of-order {key} line {line_no}")
    previous_to[key] = end
    for field in ("macro_as_of_utc", "local_bar_close_utc", "vol_bar_close_utc"):
        raw = row.get(field, "").strip()
        if raw:
            require(parse_z(raw, f"timeline {field} line {line_no}") <= start, f"forward-looking {field} line {line_no}")
    bool_text(row.get("macro_partial", "false"))
    return key, start, end


def join_timeline(rows: list[dict[str, Any]], timeline_path: Path, manifest: dict[str, Any], expected: dict[str, Any]) -> None:
    grouped: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    for unit in rows:
        grouped[(unit["symbol"], unit["tf"])].append(unit)
    for values in grouped.values():
        values.sort(key=lambda u: (u["entry_dt"], u["cell"], u["source"]["source_deal_id"]))
    pointers = {key: 0 for key in grouped}
    previous_to: dict[tuple[str, str], datetime] = {}
    observed_keys: set[tuple[str, str]] = set()
    row_count = 0
    try:
        with timeline_path.open("r", encoding="utf-8-sig", newline="") as fh:
            reader = csv.DictReader(fh)
            require(reader.fieldnames is not None, "timeline header missing")
            require(TIMELINE_REQUIRED.issubset(set(reader.fieldnames)), "timeline required fields missing")
            for line_no, timeline_row in enumerate(reader, 2):
                row_count += 1
                key, start, end = validate_timeline_row(timeline_row, line_no, expected, previous_to)
                observed_keys.add(key)
                if key not in grouped:
                    continue
                units = grouped[key]
                idx = pointers[key]
                while idx < len(units) and units[idx]["entry_dt"] < start:
                    units[idx]["timeline"] = None
                    units[idx]["unknown_reason"] = "NO_TIMELINE_ASOF_MATCH"
                    idx += 1
                while idx < len(units) and units[idx]["entry_dt"] < end:
                    require(units[idx]["entry_dt"] >= start, f"internal as-of join ordering failure {key}")
                    units[idx]["timeline"] = dict(timeline_row)
                    units[idx]["unknown_reason"] = timeline_unknown_reason(timeline_row)
                    idx += 1
                pointers[key] = idx
    except (FileNotFoundError, csv.Error) as exc:
        raise Refusal(f"cannot read timeline CSV: {exc}") from exc
    require(row_count == int(manifest.get("row_count", -1)), "timeline row count differs from manifest")
    require(set(grouped).issubset(observed_keys), "timeline missing one or more unit Symbol/TF groups")
    for key, units in grouped.items():
        idx = pointers[key]
        while idx < len(units):
            units[idx]["timeline"] = None
            units[idx]["unknown_reason"] = "NO_TIMELINE_ASOF_MATCH"
            idx += 1

def timeline_value(unit: dict[str, Any], field: str, fallback: str = "") -> str:
    row = unit.get("timeline")
    if row is None:
        if field in {"macro_state", "local_state", "vol_state", "classification_status"}:
            return "UNKNOWN"
        return fallback
    return str(row.get(field, fallback))


def make_detail_rows(units: list[dict[str, Any]], identities: dict[str, str], created_utc: str) -> list[dict[str, str]]:
    out: list[dict[str, str]] = []
    for unit in sorted(units, key=lambda u: (u["cell"], u["entry_dt"], u["source"]["source_deal_id"])):
        source = unit["source"]
        row = unit.get("timeline")
        out.append({
            "schema_version": DETAIL_SCHEMA, "created_utc": created_utc,
            "evidence_package_sha256": identities["package"], "timeline_sha256": identities["timeline"],
            "timeline_manifest_sha256": identities["timeline_manifest"], "prejoin_readiness_sha256": identities["prejoin"], "package_review_receipt_sha256": identities["package_review_receipt"],
            "classifier_id": EXPECTED["classifier_id"], "classifier_version": EXPECTED["classifier_version"],
            "attribution_unit": "DEAL", "h3_run_id": unit["cell"], "window": unit["window"],
            "year": str(unit["entry_dt"].year), "symbol": unit["symbol"], "tf": unit["tf"],
            "source_position_id": source["source_position_id"], "source_open_deal_id": source["source_open_deal_id"],
            "source_deal_id": source["source_deal_id"], "configured_run_magic": source["configured_run_magic"],
            "source_open_deal_magic": source["source_open_deal_magic"], "source_close_deal_magic": source["source_close_deal_magic"],
            "entry_utc": source["entry_utc"], "exit_utc": source["exit_utc"],
            "entry_volume": source["entry_volume"], "exit_volume": source["exit_volume"],
            "source_net_realized": fmt_decimal(unit["net"]),
            "asof_valid_from_utc": "" if row is None else row.get("valid_from_utc", ""),
            "asof_valid_to_utc": "" if row is None else row.get("valid_to_utc", ""),
            "macro_state": timeline_value(unit, "macro_state"), "macro_as_of_utc": timeline_value(unit, "macro_as_of_utc"),
            "macro_ri": timeline_value(unit, "macro_ri"), "macro_confidence": timeline_value(unit, "macro_confidence"),
            "macro_coverage": timeline_value(unit, "macro_coverage"), "macro_missing_inputs": timeline_value(unit, "macro_missing_inputs"),
            "macro_partial": timeline_value(unit, "macro_partial"), "local_state": timeline_value(unit, "local_state"),
            "local_bar_close_utc": timeline_value(unit, "local_bar_close_utc"), "local_d": timeline_value(unit, "local_d"),
            "local_qtrend": timeline_value(unit, "local_qtrend"), "vol_state": timeline_value(unit, "vol_state"),
            "vol_bar_close_utc": timeline_value(unit, "vol_bar_close_utc"), "vol_natr_pct": timeline_value(unit, "vol_natr_pct"),
            "vol_q20": timeline_value(unit, "vol_q20"), "vol_q80": timeline_value(unit, "vol_q80"), "vol_q95": timeline_value(unit, "vol_q95"),
            "classification_status": timeline_value(unit, "classification_status"), "unknown_reason": unit["unknown_reason"],
            "source_record_sha256": unit["source_record_sha256"], "basket_status": BASKET_STATUS,
        })
    return out

def unit_status(unit: dict[str, Any]) -> str:
    row = unit.get("timeline")
    return "UNKNOWN" if row is None else str(row.get("classification_status", "UNKNOWN"))


def min_macro_coverage(units: Iterable[dict[str, Any]]) -> Decimal | None:
    values: list[Decimal] = []
    for unit in units:
        row = unit.get("timeline")
        if row is None:
            continue
        ratio = coverage_ratio(row.get("macro_coverage", ""))
        if ratio is not None:
            values.append(ratio)
    return min(values) if values else None


def partition_dd(units: Iterable[dict[str, Any]]) -> Decimal:
    cumulative = Decimal("0")
    peak = Decimal("0")
    max_dd = Decimal("0")
    ordered = sorted(units, key=lambda u: (u["exit_msc"], u["source"]["source_deal_id"]))
    for unit in ordered:
        cumulative += unit["net"]
        if cumulative > peak:
            peak = cumulative
        drawdown = peak - cumulative
        if drawdown > max_dd:
            max_dd = drawdown
    return max_dd


def build_run_info(units: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    by_run: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for unit in units:
        by_run[unit["cell"]].append(unit)
    result: dict[str, dict[str, Any]] = {}
    for cell, values in by_run.items():
        eligible = len(values)
        classified = [u for u in values if unit_status(u) == "CLASSIFIED"]
        unknown = eligible - len(classified)
        macro_partial = sum(1 for u in values if u.get("timeline") is not None and bool_text(u["timeline"].get("macro_partial", "false")))
        flags: list[str] = []
        if eligible and Decimal(unknown) / Decimal(eligible) > Decimal("0.10"):
            flags.append("UNKNOWN_REGIME_COVERAGE_GT_10PCT")
        if macro_partial:
            flags.append("MACRO_PARTIAL_COVERAGE_PRESENT")
        tuple_counts = Counter((timeline_value(u, "macro_state"), timeline_value(u, "local_state"), timeline_value(u, "vol_state")) for u in classified)
        if classified and tuple_counts and Decimal(max(tuple_counts.values())) / Decimal(len(classified)) >= Decimal("0.50"):
            flags.append("SINGLE_TUPLE_PARTICIPATION_GE_50PCT")
        year_net: dict[int, Decimal] = defaultdict(lambda: Decimal("0"))
        tuple_net: dict[tuple[str, str, str], Decimal] = defaultdict(lambda: Decimal("0"))
        for unit in values:
            year_net[unit["entry_dt"].year] += unit["net"]
        for unit in classified:
            key = (timeline_value(unit, "macro_state"), timeline_value(unit, "local_state"), timeline_value(unit, "vol_state"))
            tuple_net[key] += unit["net"]
        year_denom = sum((abs(v) for v in year_net.values()), Decimal("0"))
        if year_denom > 0 and max((abs(v) for v in year_net.values()), default=Decimal("0")) / year_denom >= Decimal("0.50"):
            flags.append("SINGLE_YEAR_ABS_NET_GE_50PCT")
        tuple_denom = sum((abs(v) for v in tuple_net.values()), Decimal("0"))
        if tuple_denom > 0 and max((abs(v) for v in tuple_net.values()), default=Decimal("0")) / tuple_denom >= Decimal("0.50"):
            flags.append("SINGLE_TUPLE_ABS_NET_GE_50PCT")
        flags.append("BASKET_UNAVAILABLE")
        years = {u["entry_dt"].year for u in values}
        if len(years) < 3:
            flags.append("SHORT_CALENDAR_SPAN")
        first_entry = min(u["entry_dt"] for u in values)
        last_entry = max(u["entry_dt"] for u in values)
        result[cell] = {
            "eligible": eligible, "classified": len(classified), "unknown": unknown,
            "macro_partial": macro_partial, "flags": sorted(set(flags)),
            "status": "PARTIAL" if unknown or macro_partial else "COMPLETE",
            "macro_coverage_min": min_macro_coverage(values),
            "distinct_days": len({u["entry_dt"].date() for u in values}),
            "distinct_months": len({(u["entry_dt"].year, u["entry_dt"].month) for u in values}),
            "distinct_years": len(years), "first_entry": first_entry, "last_entry": last_entry,
            "calendar_span_days": (last_entry.date() - first_entry.date()).days + 1,
        }
    return result


def make_affinity_rows(units: list[dict[str, Any]], run_info: dict[str, dict[str, Any]], identities: dict[str, str], created_utc: str) -> list[dict[str, str]]:
    groups: dict[tuple[str, ...], list[dict[str, Any]]] = defaultdict(list)
    for unit in units:
        key = (unit["cell"], unit["window"], str(unit["entry_dt"].year), unit["symbol"], unit["tf"],
               timeline_value(unit, "macro_state"), timeline_value(unit, "local_state"), timeline_value(unit, "vol_state"), unit_status(unit))
        groups[key].append(unit)
    out: list[dict[str, str]] = []
    for key in sorted(groups):
        cell, window, year, symbol, tf, macro, local, vol, status = key
        values = groups[key]
        info = run_info[cell]
        net = sum((u["net"] for u in values), Decimal("0"))
        gross_profit = sum((u["net"] for u in values if u["net"] > 0), Decimal("0"))
        gross_loss = sum((u["net"] for u in values if u["net"] < 0), Decimal("0"))
        pf = None if gross_loss == 0 else gross_profit / abs(gross_loss)
        unknown_reasons = Counter(u["unknown_reason"] for u in values if u["unknown_reason"])
        partial_count = sum(1 for u in values if u.get("timeline") is not None and bool_text(u["timeline"].get("macro_partial", "false")))
        out.append({
            "schema_version": AFFINITY_SCHEMA, "created_utc": created_utc,
            "evidence_package_sha256": identities["package"], "timeline_sha256": identities["timeline"],
            "timeline_manifest_sha256": identities["timeline_manifest"], "prejoin_readiness_sha256": identities["prejoin"], "package_review_receipt_sha256": identities["package_review_receipt"],
            "classifier_id": EXPECTED["classifier_id"], "classifier_version": EXPECTED["classifier_version"],
            "h3_run_id": cell, "window": window, "year": year, "symbol": symbol, "tf": tf,
            "attribution_unit": "DEAL", "macro_state": macro, "local_state": local, "vol_state": vol,
            "classification_status": status, "eligible_unit_count": str(len(values)),
            "classified_unit_count": str(sum(1 for u in values if unit_status(u) == "CLASSIFIED")),
            "unknown_unit_count": str(sum(1 for u in values if unit_status(u) != "CLASSIFIED")),
            "participation_share": fmt_decimal(Decimal(len(values)) / Decimal(info["eligible"])),
            "net_realized": fmt_decimal(net), "gross_profit": fmt_decimal(gross_profit), "gross_loss": fmt_decimal(gross_loss),
            "profit_factor": fmt_decimal(pf), "partition_realized_equity_dd": fmt_decimal(partition_dd(values)), "dd_basis": DD_BASIS, "dd_order_basis": "EXIT_TIME_MSC_THEN_SOURCE_DEAL_ID",
            "hard_kill_count": "", "max_open_exposure": "", "exposure_basis": EXPOSURE_BASIS,
            "macro_coverage_min": fmt_decimal(min_macro_coverage(values)), "macro_partial_unit_count": str(partial_count),
            "unknown_reason_counts": json.dumps(dict(sorted(unknown_reasons.items())), sort_keys=True, separators=(",", ":")),
            "participation_confidence": CONFIDENCE, "participation_confidence_basis": CONFIDENCE_BASIS,
            "concentration_flags": ";".join(info["flags"]), "evidence_status": info["status"],
            "distinct_entry_days": str(len({u["entry_dt"].date() for u in values})),
            "distinct_entry_months": str(len({(u["entry_dt"].year, u["entry_dt"].month) for u in values})),
            "distinct_entry_years": str(len({u["entry_dt"].year for u in values})),
            "basket_status": BASKET_STATUS,
        })
    return out

def make_coverage_rows(units: list[dict[str, Any]], run_info: dict[str, dict[str, Any]], manifest: dict[str, Any], identities: dict[str, str], created_utc: str) -> list[dict[str, str]]:
    by_run: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for unit in units:
        by_run[unit["cell"]].append(unit)
    timeline_coverage = {(str(r.get("symbol", "")), str(r.get("tf", ""))): r for r in manifest.get("cell_coverage", []) if isinstance(r, dict)}
    out: list[dict[str, str]] = []
    for cell in sorted(by_run):
        values = by_run[cell]
        first = values[0]
        info = run_info[cell]
        t = timeline_coverage.get((first["symbol"], first["tf"]), {})
        unknown_share = Decimal(info["unknown"]) / Decimal(info["eligible"]) if info["eligible"] else Decimal("0")
        out.append({
            "schema_version": COVERAGE_SCHEMA, "created_utc": created_utc,
            "evidence_package_sha256": identities["package"], "timeline_sha256": identities["timeline"],
            "timeline_manifest_sha256": identities["timeline_manifest"], "prejoin_readiness_sha256": identities["prejoin"], "package_review_receipt_sha256": identities["package_review_receipt"],
            "classifier_id": EXPECTED["classifier_id"], "classifier_version": EXPECTED["classifier_version"],
            "h3_run_id": cell, "window": first["window"], "symbol": first["symbol"], "tf": first["tf"], "attribution_unit": "DEAL",
            "eligible_unit_count": str(info["eligible"]), "classified_unit_count": str(info["classified"]),
            "unknown_unit_count": str(info["unknown"]), "unknown_share": fmt_decimal(unknown_share),
            "macro_partial_unit_count": str(info["macro_partial"]), "macro_coverage_min": fmt_decimal(info["macro_coverage_min"]),
            "distinct_entry_days": str(info["distinct_days"]), "distinct_entry_months": str(info["distinct_months"]),
            "distinct_entry_years": str(info["distinct_years"]),
            "first_entry_utc": info["first_entry"].strftime("%Y-%m-%dT%H:%M:%SZ"),
            "last_entry_utc": info["last_entry"].strftime("%Y-%m-%dT%H:%M:%SZ"), "calendar_span_days": str(info["calendar_span_days"]),
            "basket_status": BASKET_STATUS, "participation_confidence": CONFIDENCE,
            "participation_confidence_basis": CONFIDENCE_BASIS, "evidence_status": info["status"],
            "concentration_flags": ";".join(info["flags"]),
            "timeline_cell_rows": str(t.get("rows", "")), "timeline_cell_full": str(t.get("full", "")),
            "timeline_cell_partial": str(t.get("partial", "")), "timeline_cell_unknown": str(t.get("unknown", "")),
        })
    return out


def write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    require(bool(rows), f"refusing to write empty CSV: {path.name}")
    path.parent.mkdir(parents=True, exist_ok=True)
    fields = list(rows[0].keys())
    require(all(list(r.keys()) == fields for r in rows), f"CSV schema drift within {path.name}")
    with path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

def make_reconciliation(units: list[dict[str, Any]], detail_rows: list[dict[str, str]], run_info: dict[str, dict[str, Any]], by_cell: dict[str, dict[str, Any]], identities: dict[str, str], created_utc: str, output_hashes: dict[str, str]) -> dict[str, Any]:
    source_count = len(units)
    detail_count = len(detail_rows)
    source_net = sum((u["net"] for u in units), Decimal("0"))
    detail_net = sum((decimal(r["source_net_realized"], "detail source_net_realized") for r in detail_rows), Decimal("0"))
    source_gp = sum((u["net"] for u in units if u["net"] > 0), Decimal("0"))
    source_gl = sum((u["net"] for u in units if u["net"] < 0), Decimal("0"))
    detail_gp = sum((decimal(r["source_net_realized"], "detail net") for r in detail_rows if decimal(r["source_net_realized"], "detail net") > 0), Decimal("0"))
    detail_gl = sum((decimal(r["source_net_realized"], "detail net") for r in detail_rows if decimal(r["source_net_realized"], "detail net") < 0), Decimal("0"))
    require(source_count == detail_count, "detail/source count reconciliation failed")
    require(abs(source_net - detail_net) <= Decimal("0.01"), "detail/source net reconciliation failed")
    require(abs(source_gp - detail_gp) <= Decimal("0.01"), "detail/source gross-profit reconciliation failed")
    require(abs(source_gl - detail_gl) <= Decimal("0.01"), "detail/source gross-loss reconciliation failed")
    keys = [(r["h3_run_id"], r["source_deal_id"]) for r in detail_rows]
    require(len(set(keys)) == detail_count, "detail duplicate join key")
    per_run_checks: dict[str, Any] = {}
    for cell, info in sorted(run_info.items()):
        expected_count = int(by_cell[cell].get("realized_unit_count", -1))
        require(info["eligible"] == expected_count, f"package/detail run count mismatch {cell}")
        require(info["classified"] + info["unknown"] == info["eligible"], f"classified/unknown reconciliation failed {cell}")
        per_run_checks[cell] = {"eligible": info["eligible"], "classified": info["classified"], "unknown": info["unknown"], "package_count": expected_count, "status": "PASS"}
    return {
        "schema_version": RECON_SCHEMA, "status": "PASS_ATTRIBUTION_RECONCILIATION", "created_utc": created_utc,
        "authority": AUTHORITY, "evidence_package_sha256": identities["package"], "timeline_sha256": identities["timeline"],
        "timeline_manifest_sha256": identities["timeline_manifest"], "prejoin_readiness_sha256": identities["prejoin"], "package_review_receipt_sha256": identities["package_review_receipt"],
        "classifier_id": EXPECTED["classifier_id"], "classifier_version": EXPECTED["classifier_version"],
        "attribution_unit": "DEAL", "basket_status": BASKET_STATUS, "holdout": "UNSPENT", "optimization": "NONE",
        "source_unit_count": source_count, "detail_unit_count": detail_count,
        "classified_unit_count": sum(1 for u in units if unit_status(u) == "CLASSIFIED"),
        "unknown_unit_count": sum(1 for u in units if unit_status(u) != "CLASSIFIED"),
        "timeline_asof_match_count": sum(1 for u in units if u.get("timeline") is not None),
        "no_timeline_match_count": sum(1 for u in units if u.get("timeline") is None),
        "source_net_realized": fmt_decimal(source_net), "detail_net_realized": fmt_decimal(detail_net),
        "source_gross_profit": fmt_decimal(source_gp), "detail_gross_profit": fmt_decimal(detail_gp),
        "source_gross_loss": fmt_decimal(source_gl), "detail_gross_loss": fmt_decimal(detail_gl),
        "currency_tolerance": "0.01", "count_tolerance": 0,
        "package_net_comparison": "UNAVAILABLE_NOT_EXPOSED_IN_BROAD36_PACKAGE",
        "unique_join_key_check": "PASS", "per_run_reconciliation": per_run_checks, "output_sha256": output_hashes,
    }

def write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n")


def execute(package_path: Path, units_path: Path, timeline_path: Path, manifest_path: Path,
            prejoin_path: Path, package_review_receipt_path: Path, out_dir: Path, created_utc: str,
            expected: dict[str, Any] | None = None) -> dict[str, Any]:
    expected = dict(EXPECTED if expected is None else expected)
    parse_z(created_utc, "created_utc")
    prejoin = validate_prejoin(prejoin_path, expected)
    package_review = validate_package_review_receipt(package_review_receipt_path, expected)
    manifest = validate_timeline_inputs(timeline_path, manifest_path, expected)
    package, by_cell = validate_package_inputs(package_path, units_path, expected)
    identities = {
        "package": sha256(package_path), "timeline": sha256(timeline_path),
        "timeline_manifest": sha256(manifest_path), "prejoin": sha256(prejoin_path),
        "package_review_receipt": package_review["sha256"],
    }
    units = load_units(units_path, by_cell, expected)
    join_timeline(units, timeline_path, manifest, expected)
    detail_rows = make_detail_rows(units, identities, created_utc)
    run_info = build_run_info(units)
    affinity_rows = make_affinity_rows(units, run_info, identities, created_utc)
    coverage_rows = make_coverage_rows(units, run_info, manifest, identities, created_utc)
    out_dir.mkdir(parents=True, exist_ok=True)
    detail_path = out_dir / "regime_attribution_detail.csv"
    affinity_path = out_dir / "regime_affinity.csv"
    coverage_path = out_dir / "regime_attribution_coverage.csv"
    recon_path = out_dir / "regime_attribution_reconciliation.json"
    package_out_path = out_dir / "regime_attribution_package.json"
    for path in (detail_path, affinity_path, coverage_path, recon_path, package_out_path):
        require(not path.exists(), f"refusing to overwrite existing output: {path}")
    write_csv(detail_path, detail_rows)
    write_csv(affinity_path, affinity_rows)
    write_csv(coverage_path, coverage_rows)
    output_hashes = {
        "regime_attribution_detail.csv": sha256(detail_path),
        "regime_affinity.csv": sha256(affinity_path),
        "regime_attribution_coverage.csv": sha256(coverage_path),
    }
    reconciliation = make_reconciliation(units, detail_rows, run_info, by_cell, identities, created_utc, output_hashes)
    write_json(recon_path, reconciliation)
    output_hashes["regime_attribution_reconciliation.json"] = sha256(recon_path)
    package_out = {
        "schema_version": PACKAGE_OUT_SCHEMA,
        "status": "REGIME_ATTRIBUTION_EVIDENCE_READY_FOR_INDEPENDENT_REVIEW",
        "created_utc": created_utc,
        "authority": AUTHORITY,
        "evidence_package_sha256": identities["package"],
        "aggregate_units_sha256": expected["aggregate_units_sha256"],
        "timeline_sha256": identities["timeline"],
        "timeline_manifest_sha256": identities["timeline_manifest"],
        "prejoin_readiness_sha256": identities["prejoin"], "package_review_receipt_sha256": identities["package_review_receipt"],
        "classifier_id": expected["classifier_id"],
        "classifier_version": expected["classifier_version"],
        "package_reviewed_head": expected["package_reviewed_head"],
        "package_review_verdict": "PASS",
        "package_review_confidence": "HIGH",
        "join_tool_sha256": sha256(Path(__file__)),
        "source_unit_count": len(units),
        "detail_unit_count": len(detail_rows),
        "classified_unit_count": sum(1 for u in units if unit_status(u) == "CLASSIFIED"),
        "unknown_unit_count": sum(1 for u in units if unit_status(u) != "CLASSIFIED"),
        "affinity_row_count": len(affinity_rows),
        "coverage_row_count": len(coverage_rows),
        "basket_status": BASKET_STATUS,
        "holdout": "UNSPENT",
        "optimization": "NONE",
        "output_sha256": output_hashes,
        "does_not_authorize": [
            "STRATEGY_VERDICT", "HOLDOUT", "OPTIMIZATION", "CANDIDATE", "GRADE_KINT",
            "RISK_DEFAULT", "DEPLOYMENT", "TRADING",
        ],
    }
    write_json(package_out_path, package_out)
    return {**package_out, "regime_attribution_package_sha256": sha256(package_out_path)}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--package-manifest", type=Path, required=True)
    ap.add_argument("--aggregate-units", type=Path, required=True)
    ap.add_argument("--timeline", type=Path, required=True)
    ap.add_argument("--timeline-manifest", type=Path, required=True)
    ap.add_argument("--prejoin-readiness", type=Path, required=True)
    ap.add_argument("--package-review-receipt", type=Path, required=True)
    ap.add_argument("--out-dir", type=Path, required=True)
    ap.add_argument("--created-utc", required=True)
    args = ap.parse_args()
    try:
        result = execute(args.package_manifest, args.aggregate_units, args.timeline, args.timeline_manifest,
                         args.prejoin_readiness, args.package_review_receipt, args.out_dir, args.created_utc)
        print(json.dumps({
            "status": result["status"], "units": result["detail_unit_count"],
            "classified": result["classified_unit_count"], "unknown": result["unknown_unit_count"],
            "package_sha256": result["regime_attribution_package_sha256"],
        }, sort_keys=True))
        return 0
    except (Refusal, OSError, ValueError, csv.Error, json.JSONDecodeError) as exc:
        print(json.dumps({"status": "BLOCKED_ATTRIBUTION_RECONCILIATION_FAIL", "reason": str(exc)}, sort_keys=True))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())