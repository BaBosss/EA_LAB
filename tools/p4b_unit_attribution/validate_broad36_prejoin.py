#!/usr/bin/env python3
"""Validate a frozen Boss19 P4B broad36 source-bound evidence root before P4 join.

Read-only reconciliation only. This tool grants no regime interpretation, HOLDOUT,
optimization, Candidate/Grade/KINT, risk/default, deployment, or trading authority.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SCHEMA = "BOSS19_P4B_BROAD36_PREJOIN_READINESS_V1"
RUN_SCHEMA = "BOSS19_P4B_UNIT_EXPORT_RUN_V2"
RUN_STATUS = "PASS_SOURCE_BOUND_UNIT_RUN"
UNIT_MANIFEST_SCHEMA = "BOSS19_P4B_SOURCE_BOUND_UNIT_MANIFEST_V2"
UNIT_SCHEMA = "BOSS19_P4B_SOURCE_BOUND_DEAL_V2"
LINKAGE = "EXACT_DEAL_POSITION_ID_ONE_IN_ONE_OUT"
MAGIC_PROVENANCE = "PER_DEAL_HISTORY_DEAL_MAGIC"
AUTHORITY = "READ_ONLY_PREJOIN_VALIDATION_NO_REGIME_INTERPRETATION_NO_HOLDOUT_NO_OPTIMIZATION_NO_RUNTIME_RISK_DEPLOYMENT_TRADING"
PACKAGE_SCHEMA = "BOSS19_P4B_BROAD36_SOURCE_BOUND_PACKAGE_V1"
PACKAGE_STATUS = "SOURCE_BOUND_UNIT_EVIDENCE_READY_FOR_REVIEW"
PACKAGE_AUTHORITY = "RESEARCH_EVIDENCE_ONLY_NO_STRATEGY_VERDICT_NO_HOLDOUT_NO_OPTIMIZATION_NO_RISK_DEPLOYMENT_TRADING"
ACCEPTED = {
    "runtime_head": "d55b3ffc399ae0714c456416a4b352b4fa5e472d",
    "h3_manifest_sha256": "56e7b996a9c6836e5d7cedcbe3c9a212620b9fcc10c4fe3a750f44c8226cfefd",
    "set_sha256": "671ced2169bdda6812cf1ceb70bbc5a53bcb0985563dcbce92cc64e04f81f0d2",
    "diagnostic_source_sha256": "dd61c78ca6680fcec64260ea200e04c2faa4824abbbeac218100a2db997f33cf",
    "diagnostic_ex5_sha256": "8f68ee1cf726f27de0ec5da0f1ad4b5f88f129435f9b2bf9b27d5ba378a9abd2",
    "build_receipt": "br-6c63129e01ac4458a62d420c5594560f",
    "build_receipt_registry_sha256": "4aac0ace64c5ddc5c05adbcde394705e365d1b8b50322649da2251d49aa92818",
    "package_sha256": "1330a822ed66149ba07d693d8732ced5b9e9ce66d15f34ce8d21ef70894b760c",
    "aggregate_units_sha256": "325b6d00709c48982a5981d2d7750a6a18e99f2d77ad52b89fa8d67b50c0b699",
}

class Refusal(RuntimeError):
    pass
FULL_UNIT_FIELDS = (
    "schema_version", "h3_run_id", "symbol", "period", "period_name", "configured_run_magic",
    "source_open_deal_magic", "source_close_deal_magic", "account_margin_mode",
    "source_position_id", "source_open_deal_id", "source_deal_id", "source_open_order_id", "source_close_order_id",
    "entry_time_server", "exit_time_server", "entry_time_msc", "exit_time_msc", "entry_utc", "exit_utc",
    "time_status", "time_unknown_reason", "entry_volume", "exit_volume", "entry_price", "exit_price",
    "entry_commission", "entry_swap", "entry_profit", "exit_commission", "exit_swap", "exit_profit", "source_net_realized",
)
REQUIRED_UNIT_FIELDS = FULL_UNIT_FIELDS


def require(value: bool, message: str) -> None:
    if not value:
        raise Refusal(message)


def parse_utc_z(value: str, label: str) -> datetime:
    try:
        parsed = datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    except (TypeError, ValueError) as exc:
        raise Refusal(f"{label} malformed UTC timestamp: {value!r}") from exc
    return parsed


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for block in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except FileNotFoundError as exc:
        raise Refusal(f"missing JSON: {path}") from exc
    require(isinstance(value, dict), f"JSON root must be object: {path}")
    return value
def load_h3_matrix(path: Path) -> tuple[dict[str, dict[str, str]], str]:
    try:
        with path.open("r", encoding="utf-8-sig", newline="") as fh:
            rows = list(csv.DictReader(fh))
    except FileNotFoundError as exc:
        raise Refusal(f"H3 matrix missing: {path}") from exc
    require(len(rows) == 36, f"H3 matrix must contain 36 rows, got {len(rows)}")
    ids = [r.get("cell_id", "") for r in rows]
    require(len(set(ids)) == 36 and all(ids), "H3 matrix cell IDs must be 36 unique non-empty values")
    require(all(r.get("model") == "1" for r in rows), "H3 matrix model drift")
    require(all(r.get("holdout") == "NO" for r in rows), "H3 matrix HOLDOUT drift")
    require(all(r.get("optimization") == "NO" for r in rows), "H3 matrix optimization drift")
    return {r["cell_id"]: r for r in rows}, sha256(path)


def expected_period_name(tf: str) -> str:
    return f"PERIOD_{tf}"


def exact_run_manifest_paths(root: Path, cell_ids: set[str]) -> dict[str, Path]:
    expected = {cell: root / cell / "run_manifest.json" for cell in cell_ids}
    observed = {p.resolve() for p in root.rglob("run_manifest.json")}
    expected_paths = {p.resolve() for p in expected.values()}
    missing = sorted(cell for cell, path in expected.items() if not path.is_file())
    unexpected = sorted(str(p.relative_to(root.resolve())) for p in observed - expected_paths)
    require(not missing, f"missing broad36 run manifests: {missing}")
    require(not unexpected, f"unexpected/duplicate broad36 run manifests: {unexpected}")
    require(len(observed) == 36, f"broad36 run manifest count must be 36, got {len(observed)}")
    return expected
def validate_run_identity(run: dict[str, Any], row: dict[str, str], runtime_head: str, matrix_sha: str) -> None:
    require(run.get("schema") == RUN_SCHEMA, f"run schema drift {row['cell_id']}")
    require(run.get("status") == RUN_STATUS, f"run status not PASS {row['cell_id']}")
    require(run.get("canonical_head") == runtime_head, f"runtime head drift {row['cell_id']}")
    checks = {
        "cell_id": row["cell_id"], "symbol": row["symbol"], "tf": row["tf"],
        "window": row["window"], "from_date": row["from_date"], "to_date": row["to_date"],
    }
    for key, expected in checks.items():
        require(str(run.get(key, "")) == expected, f"run {key} drift {row['cell_id']}")
    require(run.get("model") == 1, f"run model drift {row['cell_id']}")
    require(run.get("holdout") == "UNSPENT", f"run HOLDOUT drift {row['cell_id']}")
    require(run.get("optimization") == "NONE", f"run optimization drift {row['cell_id']}")
    require(run.get("h3_manifest_sha256") == matrix_sha, f"H3 manifest hash drift {row['cell_id']}")
    for key in ("set_sha256", "build_receipt", "build_receipt_registry_sha256", "diagnostic_ex5_sha256", "diagnostic_source_sha256"):
        require(bool(run.get(key)), f"missing {key} {row['cell_id']}")
    require(run.get("source_magic_provenance") == MAGIC_PROVENANCE, f"source magic provenance drift {row['cell_id']}")


def validate_file_hash(run_dir: Path, filename: str, expected: Any, label: str, cell: str) -> str:
    path = run_dir / filename
    require(path.is_file(), f"missing {label} {cell}: {filename}")
    actual = sha256(path)
    require(actual == expected, f"{label} hash mismatch {cell}")
    return actual
def validate_unit_manifest(unit: dict[str, Any], run: dict[str, Any], cell: str) -> None:
    require(unit.get("schema_version") == UNIT_MANIFEST_SCHEMA, f"unit manifest schema drift {cell}")
    require(unit.get("h3_run_id") == cell, f"unit manifest run id drift {cell}")
    require(unit.get("window") == run.get("window"), f"unit manifest window drift {cell}")
    require(unit.get("linkage_basis") == LINKAGE, f"unit linkage drift {cell}")
    require(unit.get("source_magic_provenance") == MAGIC_PROVENANCE, f"unit magic provenance drift {cell}")
    require(unit.get("forbidden_inference_used") is False, f"forbidden inference flagged {cell}")
    require(int(unit.get("open_position_count", -1)) == 0, f"open positions remain {cell}")
    require(int(unit.get("unknown_time_unit_count", -1)) == 0, f"unknown-time units remain {cell}")
    pairs = (
        ("source_in_count", "source_in_count"), ("source_out_count", "source_out_count"),
        ("source_position_count", "source_position_count"),
        ("source_owned_position_count", "source_owned_position_count"),
        ("realized_unit_count", "realized_unit_count"),
    )
    for unit_key, run_key in pairs:
        require(int(unit.get(unit_key, -1)) == int(run.get(run_key, -2)), f"count drift {cell}: {unit_key}")
    require(int(unit["realized_unit_count"]) == int(run.get("report_trades", -1)), f"unit/report trade drift {cell}")


def read_units(path: Path, run: dict[str, Any], cell: str, global_keys: set[tuple[str, str]]) -> int:
    with path.open("r", encoding="utf-8-sig", newline="") as fh:
        reader = csv.DictReader(fh)
        require(reader.fieldnames is not None, f"units header missing {cell}")
        missing = sorted(set(REQUIRED_UNIT_FIELDS) - set(reader.fieldnames))
        require(not missing, f"units required fields missing {cell}: {missing}")
        rows = list(reader)
    require(len(rows) == int(run.get("realized_unit_count", -1)), f"units row count drift {cell}")
    for idx, row in enumerate(rows, 2):
        require(row.get("schema_version") == UNIT_SCHEMA, f"unit schema drift {cell}:{idx}")
        require(row.get("h3_run_id") == cell, f"unit run id drift {cell}:{idx}")
        require(row.get("symbol") == run.get("symbol"), f"unit symbol drift {cell}:{idx}")
        require(row.get("period_name") == expected_period_name(str(run.get("tf"))), f"unit TF drift {cell}:{idx}")
        require(row.get("time_status") == "COMPLETE", f"unit time status not COMPLETE {cell}:{idx}")
        require(bool(row.get("entry_utc")) and bool(row.get("exit_utc")), f"unit UTC timestamp missing {cell}:{idx}")
        entry_utc = parse_utc_z(row["entry_utc"], f"unit entry {cell}:{idx}")
        exit_utc = parse_utc_z(row["exit_utc"], f"unit exit {cell}:{idx}")
        require(entry_utc <= exit_utc, f"unit entry/exit time order drift {cell}:{idx}")
        require(row.get("configured_run_magic") == str(run.get("configured_run_magic")), f"unit configured magic drift {cell}:{idx}")
        deal_id = row.get("source_deal_id", "")
        require(bool(deal_id), f"unit source_deal_id missing {cell}:{idx}")
        key = (cell, deal_id)
        require(key not in global_keys, f"duplicate P4 join key {cell}+{deal_id}")
        global_keys.add(key)
    return len(rows)


def consistent_identity(records: list[dict[str, Any]], key: str) -> Any:
    values = {json.dumps(rec.get(key), sort_keys=True) for rec in records}
    require(len(values) == 1, f"broad36 identity inconsistent: {key}")
    return records[0].get(key)
def validate(evidence_root: Path, h3_manifest: Path, runtime_head: str) -> dict[str, Any]:
    root = evidence_root.resolve(strict=True)
    matrix, matrix_sha = load_h3_matrix(h3_manifest)
    manifests = exact_run_manifest_paths(root, set(matrix))
    run_records: list[dict[str, Any]] = []
    global_keys: set[tuple[str, str]] = set()
    total_units = 0
    cell_summaries = []

    for cell in sorted(matrix):
        run_dir = root / cell
        run = load_json(manifests[cell])
        validate_run_identity(run, matrix[cell], runtime_head, matrix_sha)
        validate_file_hash(run_dir, "report.htm", run.get("report_sha256"), "report", cell)
        validate_file_hash(run_dir, "source.csv", run.get("source_sha256"), "source", cell)
        validate_file_hash(run_dir, "units.csv", run.get("unit_sha256"), "unit", cell)
        unit = load_json(run_dir / "unit_manifest.json")
        validate_unit_manifest(unit, run, cell)
        require(unit.get("source_sha256") == run.get("source_sha256"), f"source lineage hash drift {cell}")
        require(unit.get("unit_sha256") == run.get("unit_sha256"), f"unit lineage hash drift {cell}")
        count = read_units(run_dir / "units.csv", run, cell, global_keys)
        total_units += count
        run_records.append(run)
        cell_summaries.append({"cell_id": cell, "unit_count": count, "run_manifest_sha256": sha256(manifests[cell])})
    identities = {
        key: consistent_identity(run_records, key)
        for key in (
            "canonical_head", "h3_manifest_sha256", "set_sha256", "build_receipt",
            "build_receipt_registry_sha256", "diagnostic_ex5_sha256", "diagnostic_source_sha256",
            "configured_run_magic", "source_magic_provenance",
        )
    }
    require(identities["canonical_head"] == runtime_head, "aggregate runtime head drift")
    require(identities["h3_manifest_sha256"] == matrix_sha, "aggregate H3 manifest drift")
    require(identities["source_magic_provenance"] == MAGIC_PROVENANCE, "aggregate source magic provenance drift")

    return {
        "schema_version": SCHEMA,
        "status": "PASS_FORENSIC_RAW_EVIDENCE_VALIDATION",
        "authority": AUTHORITY,
        "runtime_head": runtime_head,
        "h3_manifest_sha256": matrix_sha,
        "expected_cell_count": 36,
        "observed_cell_count": len(run_records),
        "missing_cells": [], "unexpected_cells": [], "duplicate_cells": [],
        "total_realized_units": total_units,
        "unique_deal_join_key_count": len(global_keys),
        "deal_join_key": "h3_run_id+source_deal_id",
        "required_join_fields": ["h3_run_id", "source_deal_id", "entry_utc", "exit_utc", "symbol", "period_name"],
        "identity": identities,
        "cell_summaries": cell_summaries,
        "basket_status": "UNAVAILABLE_NO_SOURCE_BASKET_ID",
        "holdout": "UNSPENT",
        "optimization": "NONE",
        "prejoin_schema_ready": False,
        "canonical_prejoin_acceptance": False,
        "next_required_gate": "VALIDATE_FROZEN_PACKAGE_MODE",
        "package_review_required_before_regime_join": True,
        "does_not_authorize": [
            "REGIME_INTERPRETATION", "HOLDOUT", "OPTIMIZATION", "CANDIDATE", "GRADE_KINT",
            "RISK_DEFAULT", "DEPLOYMENT", "TRADING",
        ],
    }



def is_sha256_text(value: Any) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value) is not None


def validate_runner_pins(runner: Path, expected: dict[str, Any]) -> None:
    text = runner.read_text(encoding="utf-8-sig")
    pins = {
        "ExpectedManifestSha": expected["h3_manifest_sha256"],
        "ExpectedSourceSha": expected["diagnostic_source_sha256"],
        "ExpectedEx5Sha": expected["diagnostic_ex5_sha256"],
        "ExpectedBuildReceipt": expected["build_receipt"],
        "ExpectedReceiptRegistrySha": expected["build_receipt_registry_sha256"],
    }
    for name, value in pins.items():
        require(f"${name}='{value}'" in text, f"canonical runner pin drift: {name}")
    require("-Model 1" in text, "canonical runner Model1 pin missing")


def validate_result_report(report: Path, expected: dict[str, Any]) -> None:
    text = report.read_text(encoding="utf-8-sig")
    required = (
        f"Runtime canonical head: `{expected['runtime_head']}`",
        f"Aggregate units SHA-256: `{expected['aggregate_units_sha256']}`.",
        f"Package manifest SHA-256: `{expected['package_sha256']}`.",
        f"H3 matrix SHA-256: `{expected['h3_manifest_sha256']}`.",
        f"Fixed set SHA-256: `{expected['set_sha256']}`.",
        f"Diagnostic source SHA-256: `{expected['diagnostic_source_sha256']}`.",
        f"Diagnostic EX5 SHA-256: `{expected['diagnostic_ex5_sha256']}`.",
        f"Build receipt: `{expected['build_receipt']}`.",
        "HOLDOUT `2026H1` remained UNSPENT and optimization remained NONE.",
    )
    for item in required:
        require(item in text, f"canonical result-report identity/authority drift: {item}")


def read_frozen_units(path: Path, package: dict[str, Any], matrix: dict[str, dict[str, str]]) -> tuple[int, Counter, int]:
    with path.open("r", encoding="utf-8-sig", newline="") as fh:
        reader = csv.DictReader(fh)
        require(tuple(reader.fieldnames or ()) == FULL_UNIT_FIELDS, "aggregate units header/schema drift")
        rows = list(reader)
    counts: Counter = Counter()
    deal_keys: set[tuple[str, str]] = set()
    position_keys: set[tuple[str, str]] = set()
    nonmatch = 0
    for idx, row in enumerate(rows, 2):
        cell = row.get("h3_run_id", "")
        require(cell in matrix, f"aggregate unit references unknown cell {cell}:{idx}")
        m = matrix[cell]
        require(row.get("schema_version") == UNIT_SCHEMA, f"aggregate unit schema drift {cell}:{idx}")
        require(row.get("symbol") == m["symbol"], f"aggregate unit symbol drift {cell}:{idx}")
        require(row.get("period_name") == expected_period_name(m["tf"]), f"aggregate unit TF drift {cell}:{idx}")
        require(row.get("configured_run_magic") == str(package.get("configured_run_magic")), f"aggregate configured magic drift {cell}:{idx}")
        require(row.get("time_status") == "COMPLETE", f"aggregate unit time status drift {cell}:{idx}")
        require(bool(row.get("entry_utc")) and bool(row.get("exit_utc")), f"aggregate UTC timestamp missing {cell}:{idx}")
        entry_utc = parse_utc_z(row["entry_utc"], f"aggregate entry {cell}:{idx}")
        exit_utc = parse_utc_z(row["exit_utc"], f"aggregate exit {cell}:{idx}")
        require(entry_utc <= exit_utc, f"aggregate entry/exit time order drift {cell}:{idx}")
        for field in ("source_position_id", "source_open_deal_id", "source_deal_id", "source_open_order_id", "source_close_order_id"):
            require(bool(row.get(field)), f"aggregate source identity missing {field} {cell}:{idx}")
        dkey=(cell,row["source_deal_id"]); pkey=(cell,row["source_position_id"])
        require(dkey not in deal_keys, f"duplicate P4 join key {cell}+{row['source_deal_id']}")
        require(pkey not in position_keys, f"duplicate source position key {cell}+{row['source_position_id']}")
        deal_keys.add(dkey); position_keys.add(pkey); counts[cell]+=1
        if row.get("source_close_deal_magic") != row.get("configured_run_magic"):
            nonmatch += 1
    require(len(deal_keys) == len(rows) == len(position_keys), "aggregate unit uniqueness reconciliation failed")
    return len(rows), counts, nonmatch


def validate_frozen_package(package_path: Path, aggregate_units: Path, h3_manifest: Path,
                            result_report: Path, runner: Path,
                            expected: dict[str, Any] | None = None) -> dict[str, Any]:
    expected = dict(ACCEPTED if expected is None else expected)
    require(sha256(package_path) == expected["package_sha256"], "frozen package SHA drift")
    require(sha256(aggregate_units) == expected["aggregate_units_sha256"], "aggregate units SHA drift")
    matrix, matrix_sha = load_h3_matrix(h3_manifest)
    require(matrix_sha == expected["h3_manifest_sha256"], "accepted H3 manifest SHA drift")
    repo = runner.resolve(strict=True).parents[3]
    set_paths = {row["set_path"] for row in matrix.values()}
    require(len(set_paths) == 1, "H3 matrix fixed-set path drift")
    set_path = repo / next(iter(set_paths))
    require(set_path.is_file() and sha256(set_path) == expected["set_sha256"], "accepted fixed-set SHA drift")
    source_path = repo / "ea_template" / "Probe_19_AdaptiveTrendGrid_P4BUnitExport.mq5"
    require(source_path.is_file() and sha256(source_path) == expected["diagnostic_source_sha256"], "accepted diagnostic source SHA drift")
    validate_runner_pins(runner, expected)
    validate_result_report(result_report, expected)

    package = load_json(package_path)
    checks = {
        "schema_version": PACKAGE_SCHEMA,
        "status": PACKAGE_STATUS,
        "authority": PACKAGE_AUTHORITY,
        "canonical_head": expected["runtime_head"],
        "cell_count": 36,
        "unique_cell_count": 36,
        "configured_run_magic": 990001,
        "execution": "SERIAL_MODEL1_D_META5",
        "h3_manifest_sha256": matrix_sha,
        "holdout": "UNSPENT",
        "optimization": "NONE",
        "linkage_basis": LINKAGE,
        "open_position_count": 0,
        "unknown_time_unit_count": 0,
        "aggregate_units_sha256": expected["aggregate_units_sha256"],
    }
    for key, value in checks.items():
        require(package.get(key) == value, f"frozen package {key} drift")
    require(package.get("source_magic_values") == [0, 990001], "frozen package source-magic values drift")
    cells = package.get("cells")
    require(isinstance(cells, list) and len(cells) == 36, "frozen package cells must contain exactly 36 records")
    ids = [str(c.get("cell_id", "")) for c in cells if isinstance(c, dict)]
    require(len(ids) == 36 and len(set(ids)) == 36 and set(ids) == set(matrix), "frozen package cell completeness/duplicate mismatch")
    require(sorted(int(c.get("index", -1)) for c in cells) == list(range(1, 37)), "frozen package cell index drift")
    by_cell = {c["cell_id"]: c for c in cells}
    for cell, row in matrix.items():
        rec = by_cell[cell]
        for key in ("symbol", "tf", "window"):
            require(str(rec.get(key, "")) == row[key], f"frozen package {key} drift {cell}")
        require(int(rec.get("realized_unit_count", -1)) == int(rec.get("report_trades", -2)), f"package unit/report count drift {cell}")
        for key in ("run_manifest_sha256", "report_sha256", "source_sha256", "unit_sha256"):
            require(is_sha256_text(rec.get(key)), f"invalid {key} {cell}")
    require(len({c["run_manifest_sha256"] for c in cells}) == 36, "duplicate run-manifest hash in frozen package")

    total, per_cell, nonmatch = read_frozen_units(aggregate_units, package, matrix)
    require(total == int(package.get("realized_unit_count", -1)), "aggregate/package realized-unit count drift")
    require(sum(int(c["realized_unit_count"]) for c in cells) == total, "cell/package realized-unit sum drift")
    for cell, rec in by_cell.items():
        require(per_cell[cell] == int(rec["realized_unit_count"]), f"aggregate per-cell count drift {cell}")
    require(nonmatch == int(package.get("source_magic_nonmatch_count", -1)), "aggregate source-magic nonmatch count drift")

    return {
        "schema_version": SCHEMA,
        "status": "PASS_FROZEN_PACKAGE_PREJOIN_READINESS",
        "authority": AUTHORITY,
        "package_sha256": expected["package_sha256"],
        "aggregate_units_sha256": expected["aggregate_units_sha256"],
        "h3_manifest_sha256": matrix_sha,
        "runtime_head": expected["runtime_head"],
        "observed_cell_count": 36,
        "total_realized_units": total,
        "unique_deal_join_key_count": total,
        "deal_join_key": "h3_run_id+source_deal_id",
        "prejoin_schema_ready": True,
        "package_review_required_before_regime_join": True,
        "raw_cell_manifest_bytes_tracked": False,
        "raw_cell_manifest_rehash": "NOT_AVAILABLE_IN_CANONICAL_FROZEN_PACKAGE",
        "identity_binding_basis": ["FROZEN_PACKAGE_SHA256", "CANONICAL_RESULT_REPORT", "CANONICAL_RUNNER_PINS", "CANONICAL_H3_SET_SOURCE_BYTES"],
        "accepted_execution_identity": {
            "set_sha256": expected["set_sha256"], "diagnostic_source_sha256": expected["diagnostic_source_sha256"],
            "diagnostic_ex5_sha256": expected["diagnostic_ex5_sha256"], "build_receipt": expected["build_receipt"],
            "build_receipt_registry_sha256": expected["build_receipt_registry_sha256"],
        },
        "remaining_review_boundary": "INDEPENDENT_PACKAGE_REVIEW_REQUIRED_NO_REGIME_JOIN_AUTHORITY",
        "holdout": "UNSPENT", "optimization": "NONE",
        "does_not_authorize": ["REGIME_INTERPRETATION", "HOLDOUT", "OPTIMIZATION", "CANDIDATE", "GRADE_KINT", "RISK_DEFAULT", "DEPLOYMENT", "TRADING"],
    }

def write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--package-manifest", type=Path)
    ap.add_argument("--aggregate-units", type=Path)
    ap.add_argument("--result-report", type=Path)
    ap.add_argument("--runner", type=Path)
    ap.add_argument("--evidence-root", type=Path)
    ap.add_argument("--h3-manifest", type=Path, required=True)
    ap.add_argument("--runtime-head")
    ap.add_argument("--out", type=Path)
    args = ap.parse_args()
    try:
        if args.package_manifest:
            require(args.aggregate_units is not None, "--aggregate-units required with --package-manifest")
            require(args.result_report is not None, "--result-report required with --package-manifest")
            require(args.runner is not None, "--runner required with --package-manifest")
            require(args.evidence_root is None, "package mode cannot also use --evidence-root")
            result = validate_frozen_package(args.package_manifest, args.aggregate_units, args.h3_manifest, args.result_report, args.runner)
        else:
            require(args.evidence_root is not None, "either --package-manifest or --evidence-root is required")
            require(bool(args.runtime_head), "--runtime-head required with --evidence-root")
            result = validate(args.evidence_root, args.h3_manifest, str(args.runtime_head))
        if args.out:
            write_json(args.out, result)
        print(json.dumps({"status": result["status"], "cells": result["observed_cell_count"], "units": result["total_realized_units"]}, sort_keys=True))
        return 0
    except (Refusal, FileNotFoundError, ValueError, OSError, json.JSONDecodeError, csv.Error) as exc:
        print(json.dumps({"status": "BLOCKED_PREJOIN_READINESS", "reason": str(exc)}, sort_keys=True))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
