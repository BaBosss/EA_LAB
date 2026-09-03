#!/usr/bin/env python3
"""Deterministic, read-only diagnostics over accepted broad research evidence.

Consumes source-bound units plus deterministic regime attribution outputs. It emits descriptive
machine evidence only: no thresholds, strategy verdict, Candidate/Grade, filtering, optimization,
HOLDOUT, risk, deployment, or trading authority.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import importlib.util
import json
import sys
from collections import defaultdict
from datetime import datetime
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any, Iterable

_integrity_path = Path(__file__).with_name('report_package_integrity.py')
_integrity_spec = importlib.util.spec_from_file_location('ea_lab_report_package_integrity', _integrity_path)
if _integrity_spec is None or _integrity_spec.loader is None:
    raise RuntimeError(f'cannot load reporting integrity helper: {_integrity_path}')
_integrity = importlib.util.module_from_spec(_integrity_spec)
_integrity_spec.loader.exec_module(_integrity)
build_manifest = _integrity.build_manifest
validate_manifest = _integrity.validate_manifest
write_manifest = _integrity.write_manifest

SCHEMA = "EA_LAB_POST_BROAD_DIAGNOSTIC_PACK_V1"
AUTHORITY = "DIAGNOSTIC_ONLY_NO_THRESHOLDS_NO_VERDICT_NO_FILTER_NO_OPTIMIZATION_NO_HOLDOUT_NO_RISK_DEPLOYMENT_TRADING"
OUTPUT_NAMES = (
    "year_symbol_tf.csv", "month_symbol_concentration.csv", "regime_year_stability.csv",
    "participation_no_entry.csv", "episodes.csv", "counterexamples_sign_reversals.csv",
    "reconciliation.json",
)
class Refusal(ValueError):
    pass


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def read_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        raise Refusal(f"cannot read JSON {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise Refusal(f"JSON root must be an object: {path}")
    return data


def read_csv_rows(path: Path, required: Iterable[str]) -> list[dict[str, str]]:
    try:
        with path.open("r", encoding="utf-8-sig", newline="") as fh:
            reader = csv.DictReader(fh)
            headers = reader.fieldnames or []
            missing = [name for name in required if name not in headers]
            if missing:
                raise Refusal(f"missing CSV columns in {path}: {missing}")
            return [dict(row) for row in reader]
    except OSError as exc:
        raise Refusal(f"cannot read CSV {path}: {exc}") from exc
def dec(value: str, label: str) -> Decimal:
    try:
        return Decimal(value)
    except (InvalidOperation, TypeError) as exc:
        raise Refusal(f"invalid decimal {label}: {value!r}") from exc


def fmt_dec(value: Decimal) -> str:
    if value == 0:
        return "0"
    text = format(value, "f")
    if "." in text:
        text = text.rstrip("0").rstrip(".")
    return text


def sign(value: Decimal) -> str:
    return "POSITIVE" if value > 0 else "NEGATIVE" if value < 0 else "ZERO"


def parse_utc(value: str, label: str) -> datetime:
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise Refusal(f"invalid UTC timestamp {label}: {value!r}") from exc


def unit_key(row: dict[str, str]) -> tuple[str, str, str]:
    return row["h3_run_id"], row["source_position_id"], row["source_deal_id"]


def tf_from_unit(row: dict[str, str]) -> str:
    value = row["period_name"]
    if value.startswith("PERIOD_"):
        return value[7:]
    return value


def write_csv(path: Path, fields: list[str], rows: list[dict[str, Any]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field, "") for field in fields})
def reconcile(units: list[dict[str, str]], detail: list[dict[str, str]], source_pkg: dict[str, Any],
              regime_pkg: dict[str, Any], units_path: Path, detail_path: Path) -> dict[str, Any]:
    units_sha = sha256_file(units_path)
    detail_sha = sha256_file(detail_path)
    if source_pkg.get("aggregate_units_sha256") != units_sha:
        raise Refusal("source package aggregate_units_sha256 does not match units bytes")
    if regime_pkg.get("aggregate_units_sha256") != units_sha:
        raise Refusal("regime package aggregate_units_sha256 does not match units bytes")
    output_sha = regime_pkg.get("output_sha256")
    if not isinstance(output_sha, dict) or output_sha.get("regime_attribution_detail.csv") != detail_sha:
        raise Refusal("regime package does not bind exact regime detail bytes")
    cells = source_pkg.get("cells")
    if not isinstance(cells, list) or source_pkg.get("cell_count") != len(cells):
        raise Refusal("source package cell_count/cells mismatch")
    cell_map: dict[str, dict[str, Any]] = {}
    for cell in cells:
        if not isinstance(cell, dict) or not cell.get("cell_id"):
            raise Refusal("invalid source package cell record")
        if cell["cell_id"] in cell_map:
            raise Refusal(f"duplicate package cell_id: {cell['cell_id']}")
        cell_map[cell["cell_id"]] = cell
    u_by_key: dict[tuple[str, str, str], dict[str, str]] = {}
    d_by_key: dict[tuple[str, str, str], dict[str, str]] = {}
    for row in units:
        key = unit_key(row)
        if key in u_by_key:
            raise Refusal(f"duplicate source unit key: {key}")
        u_by_key[key] = row
    for row in detail:
        key = unit_key(row)
        if key in d_by_key:
            raise Refusal(f"duplicate regime detail key: {key}")
        d_by_key[key] = row
    if set(u_by_key) != set(d_by_key):
        missing_detail = sorted(set(u_by_key) - set(d_by_key))[:5]
        missing_source = sorted(set(d_by_key) - set(u_by_key))[:5]
        raise Refusal(f"source/detail key mismatch missing_detail={missing_detail} missing_source={missing_source}")

    source_counts: dict[str, int] = defaultdict(int)
    detail_counts: dict[str, int] = defaultdict(int)
    source_net = Decimal("0")
    detail_net = Decimal("0")
    for key in sorted(u_by_key):
        u, d = u_by_key[key], d_by_key[key]
        u_net = dec(u["source_net_realized"], f"source net {key}")
        d_net = dec(d["source_net_realized"], f"detail net {key}")
        if u_net != d_net:
            raise Refusal(f"source/detail net mismatch key={key}: {u_net} != {d_net}")
        if u["symbol"] != d["symbol"] or tf_from_unit(u) != d["tf"]:
            raise Refusal(f"source/detail identity mismatch key={key}")
        if u["entry_utc"] != d["entry_utc"] or u["exit_utc"] != d["exit_utc"]:
            raise Refusal(f"source/detail time mismatch key={key}")
        source_counts[u["h3_run_id"]] += 1
        detail_counts[d["h3_run_id"]] += 1
        source_net += u_net
        detail_net += d_net

    package_total = 0
    per_cell: list[dict[str, Any]] = []
    for cell_id in sorted(cell_map):
        cell = cell_map[cell_id]
        expected = int(cell.get("realized_unit_count", -1))
        reports = int(cell.get("report_trades", -1))
        package_total += expected
        sc, dc = source_counts.get(cell_id, 0), detail_counts.get(cell_id, 0)
        if expected != reports or expected != sc or expected != dc:
            raise Refusal(f"cell count mismatch {cell_id}: package={expected} report={reports} source={sc} detail={dc}")
        per_cell.append({"h3_run_id": cell_id, "package_units": expected, "source_units": sc, "detail_units": dc})
    extra_cells = sorted((set(source_counts) | set(detail_counts)) - set(cell_map))
    if extra_cells:
        raise Refusal(f"rows reference cells absent from source package: {extra_cells}")
    if package_total != len(units) or len(units) != len(detail) or source_net != detail_net:
        raise Refusal("aggregate source/package/detail reconciliation failed")
    return {
        "status": "PASS",
        "mechanical_scope": "EXACT_SOURCE_COUNT_NET_IDENTITY_ONLY",
        "units_sha256": units_sha,
        "regime_detail_sha256": detail_sha,
        "source_unit_count": len(units),
        "regime_detail_count": len(detail),
        "package_cell_count": len(cells),
        "package_realized_unit_count": package_total,
        "source_net_realized": fmt_dec(source_net),
        "regime_detail_net_realized": fmt_dec(detail_net),
        "exact_key_set_match": True,
        "exact_per_key_net_match": True,
        "per_cell": per_cell,
    }


def build_year_symbol_tf(detail: list[dict[str, str]]) -> list[dict[str, Any]]:
    groups: dict[tuple[str, int, str, str], list[dict[str, str]]] = defaultdict(list)
    for row in detail:
        groups[(row["window"], int(row["year"]), row["symbol"], row["tf"])].append(row)
    out: list[dict[str, Any]] = []
    for (window, year, symbol, tf), rows in sorted(groups.items()):
        values = [dec(r["source_net_realized"], "year-symbol-tf net") for r in rows]
        net = sum(values, Decimal("0"))
        out.append({"window":window,"year":year,"symbol":symbol,"tf":tf,"unit_count":len(rows),
                    "net_realized":fmt_dec(net),"sign":sign(net),
                    "profitable_units":sum(v>0 for v in values),"adverse_units":sum(v<0 for v in values),"zero_units":sum(v==0 for v in values)})
    return out
def build_month_symbol(detail: list[dict[str, str]]) -> list[dict[str, Any]]:
    groups: dict[tuple[str, str, str], list[Decimal]] = defaultdict(list)
    totals_count: dict[tuple[str, str], int] = defaultdict(int)
    totals_abs: dict[tuple[str, str], Decimal] = defaultdict(lambda: Decimal("0"))
    for row in detail:
        month = row["exit_utc"][:7]
        parse_utc(row["exit_utc"], "month concentration exit")
        value = dec(row["source_net_realized"], "month-symbol net")
        groups[(row["window"], month, row["symbol"])].append(value)
        totals_count[(row["window"], row["symbol"])] += 1
        totals_abs[(row["window"], row["symbol"])] += abs(value)
    out: list[dict[str, Any]] = []
    for (window, month, symbol), values in sorted(groups.items()):
        denom_count = totals_count[(window, symbol)]
        denom_abs = totals_abs[(window, symbol)]
        abs_mass = sum((abs(v) for v in values), Decimal("0"))
        net = sum(values, Decimal("0"))
        count_share = Decimal(len(values)) * Decimal(100) / Decimal(denom_count) if denom_count else Decimal("0")
        abs_share = abs_mass * Decimal(100) / denom_abs if denom_abs else Decimal("0")
        out.append({"window":window,"month":month,"symbol":symbol,"unit_count":len(values),
                    "net_realized":fmt_dec(net),"absolute_pnl_mass":fmt_dec(abs_mass),
                    "unit_share_pct":fmt_dec(count_share.quantize(Decimal('0.000001'))),
                    "absolute_pnl_mass_share_pct":fmt_dec(abs_share.quantize(Decimal('0.000001')))})
    return out
def build_regime_year(detail: list[dict[str, str]]) -> tuple[list[dict[str, Any]], dict[tuple[str,str,str], list[tuple[int,Decimal]]]]:
    dimensions = (("macro","macro_state"),("local","local_state"),("vol","vol_state"))
    grouped: dict[tuple[str,str,str,int], list[Decimal]] = defaultdict(list)
    for row in detail:
        for dimension, field in dimensions:
            state = row.get(field, "") or "UNKNOWN"
            grouped[(row["window"], dimension, state, int(row["year"]))].append(dec(row["source_net_realized"], "regime-year net"))
    annual: dict[tuple[str,str,str], list[tuple[int,Decimal]]] = defaultdict(list)
    for (window, dimension, state, year), values in sorted(grouped.items()):
        annual[(window,dimension,state)].append((year,sum(values,Decimal("0"))))
    out: list[dict[str, Any]] = []
    for key in sorted(annual):
        years = sorted(annual[key])
        signs = [sign(net) for _, net in years]
        pos, neg, zero = signs.count("POSITIVE"), signs.count("NEGATIVE"), signs.count("ZERO")
        reversal = pos > 0 and neg > 0
        window, dimension, state = key
        counts_by_year = {(w,d,s,y):len(v) for (w,d,s,y),v in grouped.items() if (w,d,s)==key}
        for year, net in years:
            out.append({"window":window,"dimension":dimension,"state":state,"year":year,
                        "unit_count":counts_by_year[(window,dimension,state,year)],"net_realized":fmt_dec(net),"sign":sign(net),
                        "years_observed":len(years),"positive_years":pos,"negative_years":neg,"zero_years":zero,
                        "sign_reversal_present":str(reversal).lower()})
    return out, annual
def build_participation(detail: list[dict[str, str]], source_pkg: dict[str, Any]) -> list[dict[str, Any]]:
    rows_by_cell: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in detail:
        rows_by_cell[row["h3_run_id"]].append(row)
    out: list[dict[str, Any]] = []
    for cell in sorted(source_pkg["cells"], key=lambda c: (int(c.get("index",0)), c["cell_id"])):
        cell_rows = rows_by_cell.get(cell["cell_id"], [])
        net = sum((dec(r["source_net_realized"], "participation net") for r in cell_rows), Decimal("0"))
        count = len(cell_rows)
        out.append({"cell_id":cell["cell_id"],"index":cell.get("index",""),"window":cell["window"],
                    "symbol":cell["symbol"],"tf":cell["tf"],"report_trades":cell["report_trades"],
                    "realized_unit_count":cell["realized_unit_count"],"diagnostic_unit_count":count,
                    "participation_status":"PARTICIPATED" if count else "NO_ENTRY","net_realized":fmt_dec(net)})
    return out


def episode_sort_key(row: dict[str, str]) -> tuple[Any, ...]:
    return (parse_utc(row["exit_utc"], "episode exit"), parse_utc(row["entry_utc"], "episode entry"),
            int(row["source_position_id"]), int(row["source_deal_id"]))


def build_episodes(detail: list[dict[str, str]]) -> list[dict[str, Any]]:
    by_cell: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in detail:
        by_cell[row["h3_run_id"]].append(row)
    out: list[dict[str, Any]] = []
    for cell_id in sorted(by_cell):
        rows = sorted(by_cell[cell_id], key=episode_sort_key)
        episode: list[dict[str, str]] = []
        current_sign = ""
        episode_index = 0

        def emit_episode() -> None:
            nonlocal episode, current_sign, episode_index
            if not episode:
                return
            episode_index += 1
            values = [dec(r["source_net_realized"], "episode net") for r in episode]
            first = episode[0]
            out.append({"cell_id":cell_id,"episode_index":episode_index,"window":first["window"],
                        "symbol":first["symbol"],"tf":first["tf"],"episode_sign":current_sign,
                        "start_entry_utc":min(r["entry_utc"] for r in episode),
                        "end_exit_utc":max(r["exit_utc"] for r in episode)})
            out[-1].update({"unit_count":len(episode),
                            "net_realized":fmt_dec(sum(values,Decimal('0'))),
                            "min_unit_net":fmt_dec(min(values)),
                            "max_unit_net":fmt_dec(max(values))})
            episode = []

        for row in rows:
            row_sign = sign(dec(row["source_net_realized"], "episode sign"))
            if episode and row_sign != current_sign:
                emit_episode()
            if not episode:
                current_sign = row_sign
            episode.append(row)
        emit_episode()
    return out


def build_counterexamples(year_rows: list[dict[str, Any]], annual: dict[tuple[str,str,str], list[tuple[int,Decimal]]]) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for (window, dimension, state), years in sorted(annual.items()):
        ordered = sorted(years)
        for (year_a, net_a), (year_b, net_b) in zip(ordered, ordered[1:]):
            if net_a != 0 and net_b != 0 and sign(net_a) != sign(net_b):
                out.append({"counterexample_type":"REGIME_YEAR_SIGN_REVERSAL","axis":dimension,"subject":state,
                            "context_a":f"{window}:{year_a}","net_a":fmt_dec(net_a),"sign_a":sign(net_a),
                            "context_b":f"{window}:{year_b}","net_b":fmt_dec(net_b),"sign_b":sign(net_b),
                            "evidence_note":"adjacent observed years for the same regime state have opposite aggregate signs"})
    by_surface: dict[tuple[str,str,str], Decimal] = defaultdict(lambda: Decimal("0"))
    for row in year_rows:
        by_surface[(row["symbol"],row["tf"],row["window"])] += Decimal(row["net_realized"])
    surfaces = sorted({(symbol,tf) for symbol,tf,_ in by_surface})
    for symbol, tf in surfaces:
        bwd = by_surface.get((symbol,tf,"BWD"))
        main = by_surface.get((symbol,tf,"MAIN"))
        if bwd is None or main is None or bwd == 0 or main == 0 or sign(bwd) == sign(main):
            continue
        out.append({"counterexample_type":"SYMBOL_TF_WINDOW_SIGN_REVERSAL","axis":"symbol_tf","subject":f"{symbol}:{tf}",
                    "context_a":"BWD","net_a":fmt_dec(bwd),"sign_a":sign(bwd),
                    "context_b":"MAIN","net_b":fmt_dec(main),"sign_b":sign(main),
                    "evidence_note":"the same symbol/TF has opposite aggregate signs across the frozen BWD and MAIN windows"})
    return out


def artifact_rows() -> list[dict[str, str]]:
    roles = {
        "year_symbol_tf.csv":"year x symbol x TF diagnostic",
        "month_symbol_concentration.csv":"month x symbol concentration diagnostic",
        "regime_year_stability.csv":"regime x year sign/stability diagnostic",
        "participation_no_entry.csv":"cell participation/no-entry matrix",
        "episodes.csv":"contiguous realized-unit sign episode decomposition",
        "counterexamples_sign_reversals.csv":"counterexample and sign-reversal table",
        "reconciliation.json":"exact source/count/net reconciliation",
    }
    return [{"path":name,"role":roles[name]} for name in OUTPUT_NAMES]
def build(args: argparse.Namespace) -> dict[str, Any]:
    units_path = Path(args.units).resolve(strict=True)
    detail_path = Path(args.regime_detail).resolve(strict=True)
    source_package_path = Path(args.source_package).resolve(strict=True)
    regime_package_path = Path(args.regime_package).resolve(strict=True)
    out_dir = Path(args.out_dir).resolve(strict=False)
    units = read_csv_rows(units_path, ("h3_run_id","symbol","period_name","source_position_id","source_deal_id",
                                        "entry_utc","exit_utc","source_net_realized"))
    detail = read_csv_rows(detail_path, ("h3_run_id","window","year","symbol","tf","source_position_id","source_deal_id",
                                         "entry_utc","exit_utc","source_net_realized","macro_state","local_state","vol_state"))
    source_pkg = read_json(source_package_path)
    regime_pkg = read_json(regime_package_path)
    reconciliation = reconcile(units, detail, source_pkg, regime_pkg, units_path, detail_path)
    if not args.direct_consumer.strip():
        raise Refusal("direct_consumer must be non-empty")

    year_rows = build_year_symbol_tf(detail)
    month_rows = build_month_symbol(detail)
    regime_rows, annual = build_regime_year(detail)
    participation_rows = build_participation(detail, source_pkg)
    episodes = build_episodes(detail)
    counterexamples = build_counterexamples(year_rows, annual)
    out_dir.mkdir(parents=True, exist_ok=True)
    write_csv(out_dir/'year_symbol_tf.csv',
              ['window','year','symbol','tf','unit_count','net_realized','sign','profitable_units','adverse_units','zero_units'],year_rows)
    write_csv(out_dir/'month_symbol_concentration.csv',
              ['window','month','symbol','unit_count','net_realized','absolute_pnl_mass','unit_share_pct','absolute_pnl_mass_share_pct'],month_rows)
    write_csv(out_dir/'regime_year_stability.csv',
              ['window','dimension','state','year','unit_count','net_realized','sign','years_observed','positive_years','negative_years','zero_years','sign_reversal_present'],regime_rows)
    write_csv(out_dir/'participation_no_entry.csv',
              ['cell_id','index','window','symbol','tf','report_trades','realized_unit_count','diagnostic_unit_count','participation_status','net_realized'],participation_rows)
    write_csv(out_dir/'episodes.csv',
              ['cell_id','episode_index','window','symbol','tf','episode_sign','start_entry_utc','end_exit_utc','unit_count','net_realized','min_unit_net','max_unit_net'],episodes)
    write_csv(out_dir/'counterexamples_sign_reversals.csv',
              ['counterexample_type','axis','subject','context_a','net_a','sign_a','context_b','net_b','sign_b','evidence_note'],counterexamples)

    reconciliation.update({
        "schema_version": SCHEMA,
        "authority": AUTHORITY,
        "unique_output": "reconciled multi-axis pre-interpretation diagnostics over accepted source-bound broad evidence",
        "downstream_skip": "skip repeated manual/model regrouping, participation recount, sign-scan, and source/net reconciliation",
        "direct_consumer": args.direct_consumer.strip(),
        "episode_definition": "within each cell, realized units sorted by exit/entry/id and grouped into contiguous equal-sign runs; not native floating-equity drawdown",
    })
    (out_dir/'reconciliation.json').write_text(json.dumps(reconciliation,indent=2,sort_keys=True)+"\n",encoding='utf-8',newline='\n')
    spec = {
        "package_id": "EA_LAB_POST_BROAD_DIAGNOSTIC_PACK",
        "direct_consumer": args.direct_consumer.strip(),
        "authority": AUTHORITY,
        "metadata": {"schema_version":SCHEMA,"source_units_sha256":reconciliation["units_sha256"],
                     "regime_detail_sha256":reconciliation["regime_detail_sha256"]},
        "artifacts": artifact_rows(),
    }
    spec_path=out_dir/'report_package_spec.json'
    manifest_path=out_dir/'report_package_manifest.json'
    spec_path.write_text(json.dumps(spec,indent=2,sort_keys=True)+"\n",encoding='utf-8',newline='\n')
    manifest=build_manifest(spec_path,manifest_path)
    write_manifest(manifest,manifest_path)
    validate_manifest(manifest_path)
    return {"status":"PASS","schema_version":SCHEMA,"output_dir":str(out_dir),
            "source_unit_count":len(units),"cell_count":len(source_pkg["cells"]),
            "output_count":len(OUTPUT_NAMES)+2,"manifest_sha256":sha256_file(manifest_path)}


def parser() -> argparse.ArgumentParser:
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--units',required=True)
    p.add_argument('--source-package',required=True)
    p.add_argument('--regime-detail',required=True)
    p.add_argument('--regime-package',required=True)
    p.add_argument('--out-dir',required=True)
    p.add_argument('--direct-consumer',required=True)
    return p


def main() -> int:
    args=parser().parse_args()
    try:
        result=build(args)
    except (Refusal, FileNotFoundError) as exc:
        print(f"REFUSED: {exc}",file=sys.stderr)
        return 2
    print(json.dumps(result,sort_keys=True))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
