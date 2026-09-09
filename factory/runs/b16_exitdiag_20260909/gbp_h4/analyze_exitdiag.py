#!/usr/bin/env python3
"""Execute the frozen GBPUSD/H4 B16 exit-concentration diagnostic.

The program is deliberately fail-closed. It parses and validates both accepted
14/70 SELL control reports before it reads or calculates a concentration
dimension from any exit-off child report. The pre-existing children are
configuration-confounded, so their calculations are descriptive only. It never
invokes MT5.
"""

from __future__ import annotations

import csv
import gzip
import hashlib
import importlib.util
import json
import re
import sys
import tempfile
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
SRC = ROOT / "factory/runs/b16_characterization_20260830"
PARSER = ROOT / "scripts/research/b16_h03/parse_h02_reports.py"
PREREG = ROOT / "docs/research/B16_GBP_SELL_H4_EXITCONC_PREREG_20260905.md"
PARENT_RESULT = ROOT / "docs/research/B16_GBP_SELL_H4_OPT01_RESULTS.md"
CELL_SUMMARY = SRC / "aggregate/cell_summary.csv"
CAGE_EVIDENCE = SRC / "aggregate/cage_kill_evidence.json"
MECHANICAL_ACCEPTANCE = SRC / "aggregate/mechanical_acceptance.json"
EXTENSION_CONTRACT = SRC / "extension_eurgbp_h4/EXTENSION_CONTRACT.md"
EXTENSION_RECEIPTS = SRC / "aggregate/extension_run_receipts.jsonl"

BASE_SHA = "2d298598d859fbbb9c0981e58050b27402405bee"
PREREG_SHA256 = "cc59018d5d19f5026426e5488704315ceec761cb5af47fa7da37be2b071b068e"
PARENT_RESULT_SHA256 = "d83b362959c4129a5ddcd740296e4a0bffbe8cdce960eba5671035546ccdb554"
PARSER_SHA256 = "c2aa0995705ed63a9c2ae1b0bbb982f2375bd2da3ae9c8bff35e2ad01a005b5e"
CELL_SUMMARY_SHA256 = "55074319169d5f3972dddad2fb0cd80365d2c6dfb62bbe84e4dd6be768b02bd7"
CAGE_EVIDENCE_SHA256 = "fc604a467b747907dab18bcff3c678a8762258c520950460d3000bc997e23631"
MECHANICAL_ACCEPTANCE_SHA256 = "d4ce89d9c233a24b68baa892503e394668974f693695e195472b4988f1c8e228"
EXTENSION_CONTRACT_SHA256 = "cece4fe82af2564e03951fce79ffe57d4b88c3152e888964e5b2932323cd2b5f"
EXTENSION_RECEIPTS_SHA256 = "258698bf65aa3a43c28848ad15b2bc64bd027ec2a3c9a0b4c9f3f9dccbe2e985"
TESTER_LINEAGE = "MT5 lane2 / D:\\Meta 5b / Model 1"
CAUSAL_BLOCKER = "BLOCKED_CONFIGURATION_CONFOUND"

# Loading the frozen parser must not create cache output outside this lane's
# explicitly allowed write paths.
sys.dont_write_bytecode = True

EXPECTED_YEARS = {"MAIN": {2023, 2024, 2025}, "BWD": {2020, 2021, 2022}}
EXPECTED_PARENT = {
    "MAIN": {"net": 283.20, "pf": 7.97, "trades": 80, "eqdd_pct": 1.72},
    "BWD": {"net": 268.97, "pf": 14.36, "trades": 76, "eqdd_pct": 1.27},
}

CELL_SPECS: dict[tuple[str, str], dict[str, str]] = {
    ("ACCEPTED_PARENT_CONTROL", "MAIN"): {
        "source_variant": "SELL_DIRECTION",
        "gzip_sha256": "d3537d88ddf7d474f3c645ddcccc72d634719f35fd5387e83982d73ae7b0c2e5",
        "raw_report_sha256": "24fb63c4d163410d37ab60eade7230a9e3488f1bed854d0871cf53b2df0f0a89",
        "ini_sha256": "d0e3935d7ff5c53c27b1b6077b976a9ac5150d4095f647033fa91228674a25af",
    },
    ("ACCEPTED_PARENT_CONTROL", "BWD"): {
        "source_variant": "SELL_DIRECTION",
        "gzip_sha256": "4a6bafbad8748f47400d06fa71a0b9ec5a1e83498765af34c8f65ac2c0cc5d7b",
        "raw_report_sha256": "d87d450e83bd3fd4cf93d13bb30b51238c0eb110a7154fdde2c22205d9b88fc9",
        "ini_sha256": "2f39d05d380f25a12c56ba7610cb5dba44d841c2c213f397b77ba3667872415b",
    },
    ("SINGLETP_OFF", "MAIN"): {
        "source_variant": "SINGLETP_OFF",
        "gzip_sha256": "84e72d21185d80a51fe7d55149b6e4bf994480684df23dc5cee7bd1a1dc40559",
        "raw_report_sha256": "1c2b092939f8f774a28af5439dd646e6ac2eefa72feb14a0d6d71f4b8363753c",
        "ini_sha256": "c4971ddce9621c99713609b16fe623b82279a347749c9e2b79ec146bc28c4675",
    },
    ("SINGLETP_OFF", "BWD"): {
        "source_variant": "SINGLETP_OFF",
        "gzip_sha256": "300fb7753327eb80e48df0b4695be6021af1f881e7f7df282ef6217a5fe61277",
        "raw_report_sha256": "9cdf16a83e8aa4cb188be86a6456463ce74d9f9dd6a4ee9e067895bb6db5ba01",
        "ini_sha256": "7a9f14a7fd621aa46a3c06e845a7b992ab9b67324f7d69fcaadcc061d76277dc",
    },
    ("BASKETTP_OFF", "MAIN"): {
        "source_variant": "BASKETTP_OFF",
        "gzip_sha256": "96f191fac97590952dfd5be8e5c09a4223249fd730a18ff1745b2c622ca03da0",
        "raw_report_sha256": "d37d48c0529456cb2e8bff08ae55b5fca1cb40282a0d67182f82186b8a9f21f3",
        "ini_sha256": "ef02db4cd3ad1256bbbb9afa9ea084a83bf6aaaaa7e6220e480b03a2368473f2",
    },
    ("BASKETTP_OFF", "BWD"): {
        "source_variant": "BASKETTP_OFF",
        "gzip_sha256": "d2644791bd4d803bff931d5bac1c47ab43050339905685f8a53a2a3f93c896ec",
        "raw_report_sha256": "f92532e70cc1b1160b500f20eca19424138070476d47f5e4d53a7bdd39ed7ee3",
        "ini_sha256": "e61788f88db2876f71e4fd549a654b094e35d3be868138cf398370f1949390f8",
    },
}

EXPECTED_CONFIG_DIFFS = {
    "SINGLETP_OFF": ["_16_Direction", "_16_TpSingleAtrMult"],
    "BASKETTP_OFF": ["_16_BasketTpUsdPer01", "_16_Direction"],
}

TESTER_KEYS = {
    "Expert", "Symbol", "Period", "Model", "Optimization", "FromDate", "ToDate",
    "ForwardMode", "Deposit", "Currency", "Leverage", "ExecutionMode", "Visual",
    "Report", "ReplaceReport", "ShutdownTerminal",
}
RECONCILIATION_KEYS = (
    "net_profit_matches",
    "gross_profit_matches",
    "gross_loss_matches",
    "profit_factor_matches_rounded",
    "closed_ticket_count_matches_total_trades",
)
ARTIFACT_NAMES = (
    "analyze_exitdiag.py",
    "verify_package.py",
    "diagnostic.json",
    "diagnostic_acceptance.json",
    "diagnostic_summary.csv",
    "source_manifest.json",
    "source_reconciliation.txt",
    "year_participation.csv",
)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def write_json(path: Path, value: Any) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def as_bool(value: str) -> bool:
    normalized = value.strip().lower()
    if normalized == "true":
        return True
    if normalized == "false":
        return False
    raise ValueError(f"not a canonical boolean: {value!r}")


def eqdd_pct(value: Any) -> float:
    match = re.search(r"(\d+(?:\.\d+)?)%", str(value))
    if not match:
        raise ValueError(f"cannot parse EqDD percent from {value!r}")
    return float(match.group(1))


def pin(path: Path, expected: str) -> None:
    actual = sha256_file(path)
    if actual != expected:
        raise RuntimeError(f"source hash mismatch: {path.relative_to(ROOT)} expected={expected} actual={actual}")


def load_parser() -> Any:
    pin(PARSER, PARSER_SHA256)
    spec = importlib.util.spec_from_file_location("b16_h03_parser", PARSER)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load frozen B16 H03 parser")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_cell_rows() -> dict[tuple[str, str], dict[str, str]]:
    pin(CELL_SUMMARY, CELL_SUMMARY_SHA256)
    with CELL_SUMMARY.open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    selected: dict[tuple[str, str], dict[str, str]] = {}
    for row in rows:
        if row["context"] == "GBP_H4" and row["variant"] in {"SELL_DIRECTION", "SINGLETP_OFF", "BASKETTP_OFF"}:
            selected[(row["variant"], row["window"])] = row
    expected = {(variant, window) for variant in ("SELL_DIRECTION", "SINGLETP_OFF", "BASKETTP_OFF") for window in ("MAIN", "BWD")}
    if set(selected) != expected:
        raise RuntimeError(f"source cell-summary coverage mismatch: {sorted(selected)}")
    return selected


def validate_extension_receipts(cell_rows: dict[tuple[str, str], dict[str, str]]) -> None:
    pin(EXTENSION_CONTRACT, EXTENSION_CONTRACT_SHA256)
    pin(EXTENSION_RECEIPTS, EXTENSION_RECEIPTS_SHA256)
    contract = EXTENSION_CONTRACT.read_text(encoding="utf-8")
    if "MT5-lane2 / D:\\Meta 5b" not in contract or "Model 1" not in contract:
        raise RuntimeError("extension tester lineage is not pinned by the frozen contract")
    receipts = [json.loads(line) for line in EXTENSION_RECEIPTS.read_text(encoding="utf-8-sig").splitlines() if line.strip()]
    selected = {
        (item["variant"], item["window"]): item
        for item in receipts
        if item.get("context") == "GBP_H4" and item.get("variant") in {"SELL_DIRECTION", "SINGLETP_OFF", "BASKETTP_OFF"}
    }
    if set(selected) != set(cell_rows):
        raise RuntimeError("extension receipt coverage mismatch for frozen GBP/H4 cells")
    for key, row in cell_rows.items():
        receipt = selected[key]
        for receipt_key, summary_key in (
            ("report_sha256", "report_sha256"),
            ("set_sha256", "set_sha256"),
            ("build_receipt", "build_receipt"),
            ("ex5_sha256", "ex5_sha256"),
        ):
            if receipt[receipt_key] != row[summary_key]:
                raise RuntimeError(f"extension receipt mismatch {key} {receipt_key}")


def input_payload(ini: dict[str, str]) -> dict[str, str]:
    return {key: value for key, value in ini.items() if key not in TESTER_KEYS}


def config_diff(control: dict[str, str], child: dict[str, str]) -> list[dict[str, str]]:
    keys = sorted(set(control) | set(child))
    return [
        {"key": key, "control": control.get(key, "<MISSING>"), "child": child.get(key, "<MISSING>")}
        for key in keys
        if control.get(key) != child.get(key)
    ]


def metric_row(analysis: dict[str, Any], variant: str, source_variant: str, window: str, report_sha: str) -> dict[str, Any]:
    cycles = analysis["cycles"]
    if not cycles:
        raise RuntimeError(f"no reconstructable cycles: {variant}/{window}")
    positive_cycle_gp = [float(cycle["gross_profit"]) for cycle in cycles if float(cycle.get("gross_profit", 0)) > 0]
    if not positive_cycle_gp or sum(positive_cycle_gp) <= 0:
        raise RuntimeError(f"positive-cycle gross profit unavailable: {variant}/{window}")
    bins = [item for item in analysis["bins"] if str(item["bin"]).isdigit()]
    years = {int(item["bin"]) for item in bins}
    if years != EXPECTED_YEARS[window]:
        raise RuntimeError(f"year-bin mismatch {variant}/{window}: {sorted(years)}")
    report = analysis["identity"]["report"]
    gross_loss = float(report["gross_loss"])
    return {
        "variant": variant,
        "source_variant": source_variant,
        "window": window,
        "report_sha256": report_sha,
        "net": float(report["net_profit"]),
        "pf": None if gross_loss == 0 else float(report["profit_factor"]),
        "pf_mt5_field": float(report["profit_factor"]),
        "pf_state": "UNDEFINED_NO_GROSS_LOSS" if gross_loss == 0 else "FINITE",
        "trades": int(report["total_trades"]),
        "native_eqdd_pct": eqdd_pct(report["equity_drawdown_relative"]),
        "cycles": len(cycles),
        "max_cycle_holding_duration_days": max(float(cycle["duration_seconds"]) for cycle in cycles) / 86400.0,
        "active_time_share_full_window": float(analysis["exposure"]["active_time_share_full_window"]),
        "top1_positive_cycle_gp_share": max(positive_cycle_gp) / sum(positive_cycle_gp),
        "zero_closed_year_count": sum(1 for item in bins if int(item["closed_ticket_count"]) == 0),
    }


def year_rows(analysis: dict[str, Any], variant: str, window: str) -> list[dict[str, Any]]:
    return [
        {
            "variant": variant,
            "window": window,
            "year": int(item["bin"]),
            "closed_ticket_count": int(item["closed_ticket_count"]),
            "cycle_count": int(item["cycle_count"]),
            "net": float(item["net_profit"]),
            "active_time_share_full_window": float(item["active_time_share_full_window"]),
        }
        for item in analysis["bins"]
        if str(item["bin"]).isdigit()
    ]


def analyze_source_cell(
    parser: Any,
    cell_rows: dict[tuple[str, str], dict[str, str]],
    cage_evidence: dict[str, Any],
    variant: str,
    window: str,
) -> tuple[dict[str, Any], dict[str, Any], dict[str, str], dict[str, Any], list[dict[str, Any]], dict[str, Any]]:
    spec = CELL_SPECS[(variant, window)]
    source_variant = spec["source_variant"]
    cell = SRC / "evidence" / source_variant / "GBP_H4" / window
    report_gz = cell / "report.htm.gz"
    ini_path = cell / "tester.ini"
    leverage_path = cell / "leverage_check.json"
    truncation_path = cell / "truncation_check.json"
    for path in (report_gz, ini_path, leverage_path, truncation_path):
        if not path.is_file():
            raise RuntimeError(f"required tracked source missing: {path.relative_to(ROOT)}")
    pin(report_gz, spec["gzip_sha256"])
    pin(ini_path, spec["ini_sha256"])
    raw = gzip.decompress(report_gz.read_bytes())
    raw_sha = sha256_bytes(raw)
    if raw_sha != spec["raw_report_sha256"]:
        raise RuntimeError(f"raw report hash mismatch: {source_variant}/{window}")
    ini = parser.parse_ini(ini_path)
    with tempfile.NamedTemporaryFile(suffix=".htm", delete=False) as handle:
        handle.write(raw)
        temp_report = Path(handle.name)
    try:
        analysis = parser.analyze(temp_report, ini_path)
    finally:
        temp_report.unlink(missing_ok=True)
    if not all(bool(analysis["reconciliation"].get(key)) for key in RECONCILIATION_KEYS):
        raise RuntimeError(f"report reconciliation failed: {source_variant}/{window}")
    identity = analysis["identity"]
    expected_identity = {
        "Symbol": "GBPUSD",
        "Period": "H4",
        "Model": "1",
        "Optimization": "0",
        "FromDate": "2023.01.01" if window == "MAIN" else "2020.01.01",
        "ToDate": "2025.12.31" if window == "MAIN" else "2022.12.31",
        "Deposit": "10000",
        "Currency": "USD",
        "Leverage": "1:100",
    }
    for key, expected in expected_identity.items():
        if ini.get(key) != expected:
            raise RuntimeError(f"tester identity mismatch {source_variant}/{window} {key}: {ini.get(key)!r}")
    summary_row = cell_rows[(source_variant, window)]
    report = identity["report"]
    summary_matches_parse = (
        round(float(summary_row["net"]), 2) == round(float(report["net_profit"]), 2)
        and round(float(summary_row["pf"]), 2) == round(float(report["profit_factor"]), 2)
        and int(summary_row["trades"]) == int(report["total_trades"])
        and round(float(summary_row["native_eqdd_pct"]), 2) == round(eqdd_pct(report["equity_drawdown_relative"]), 2)
        and summary_row["report_sha256"] == raw_sha
    )
    if not summary_matches_parse:
        raise RuntimeError(f"cell summary does not reconcile to raw parse: {source_variant}/{window}")
    leverage = json.loads(leverage_path.read_text(encoding="utf-8-sig"))
    truncation = json.loads(truncation_path.read_text(encoding="utf-8-sig"))
    cage_key = ini["Report"]
    eligibility = {
        "full_window_eligible_source": as_bool(summary_row["full_window_eligible"]),
        "cage_kill_confirmed_source": as_bool(summary_row["cage_kill_confirmed"]),
        "sidecar_truncated_source": as_bool(summary_row["sidecar_truncated"]),
        "parse_error_source": summary_row["parse_error"],
        "leverage_match": bool(leverage.get("match")),
        "truncation_check": bool(truncation.get("truncated")),
        "cage_event_present": cage_key in cage_evidence,
    }
    eligibility["mechanically_eligible"] = bool(
        eligibility["full_window_eligible_source"]
        and not eligibility["cage_kill_confirmed_source"]
        and not eligibility["sidecar_truncated_source"]
        and not eligibility["parse_error_source"]
        and eligibility["leverage_match"]
        and not eligibility["truncation_check"]
        and not eligibility["cage_event_present"]
    )
    source_record = {
        "variant": variant,
        "source_variant": source_variant,
        "window": window,
        "report_gzip_path": report_gz.relative_to(ROOT).as_posix(),
        "report_gzip_sha256": sha256_file(report_gz),
        "raw_report_sha256": raw_sha,
        "tester_ini_path": ini_path.relative_to(ROOT).as_posix(),
        "tester_ini_sha256": sha256_file(ini_path),
        "leverage_check_path": leverage_path.relative_to(ROOT).as_posix(),
        "leverage_check_sha256": sha256_file(leverage_path),
        "truncation_check_path": truncation_path.relative_to(ROOT).as_posix(),
        "truncation_check_sha256": sha256_file(truncation_path),
        "source_set_sha256": summary_row["set_sha256"],
        "build_receipt": summary_row["build_receipt"],
        "ex5_sha256": summary_row["ex5_sha256"],
        "effective_tester_inputs_sha256": identity["effective_tester_inputs_sha256"],
        "tester_lineage": TESTER_LINEAGE,
    }
    return (
        analysis,
        metric_row(analysis, variant, source_variant, window, raw_sha),
        ini,
        eligibility,
        year_rows(analysis, variant, window),
        source_record,
    )


def validate_control_row(row: dict[str, Any], ini: dict[str, str], window: str) -> dict[str, Any]:
    expected = EXPECTED_PARENT[window]
    checks = {
        "net_exact_2dp": round(row["net"], 2) == round(expected["net"], 2),
        "pf_exact_2dp": round(row["pf_mt5_field"], 2) == round(expected["pf"], 2),
        "trades_exact": row["trades"] == expected["trades"],
        "native_eqdd_exact_2dp": round(row["native_eqdd_pct"], 2) == round(expected["eqdd_pct"], 2),
        "sell_direction_exact": ini.get("_16_Direction") == "2",
        "rsi_period_14_exact": ini.get("_16_RsiPeriod") == "14",
        "rsi_high_70_exact": ini.get("_16_RsiHigh") == "70.0",
    }
    return {"window": window, "expected": expected, "observed": {key: row[key] for key in ("net", "pf_mt5_field", "trades", "native_eqdd_pct")}, "checks": checks, "pass": all(checks.values())}


def write_blocked_control(reason: str, controls: list[dict[str, Any]], gates: list[dict[str, Any]]) -> None:
    acceptance = {
        "schema": "ea-lab-b16-gbp-h4-exitdiag-acceptance/1",
        "overall": "BLOCKED_CONTROL_MISMATCH",
        "reason": reason,
        "control_source": "SELL_DIRECTION/GBP_H4",
        "control_rows_completed": controls,
        "control_gates": gates,
        "child_dimensions_computed": False,
        "mt5_rerun": False,
        "new_strategy_test_runs": 0,
        "holdout": "UNSPENT",
        "optimization": "NONE",
        "authority": "RESEARCH_ONLY",
    }
    write_json(OUT / "diagnostic_acceptance.json", acceptance)
    (OUT / "source_reconciliation.txt").write_text(
        "B16 GBPUSD/H4 EXIT CONCENTRATION SOURCE RECONCILIATION\n"
        f"BASE_SHA={BASE_SHA}\nCONTROL_SOURCE=SELL_DIRECTION/GBP_H4\n"
        f"CONTROL_GATE=BLOCKED_CONTROL_MISMATCH\nREASON={reason}\n"
        "CHILD_DIMENSIONS_COMPUTED=false\nMT5_RERUN=false\nHOLDOUT=UNSPENT\nOPTIMIZATION=NONE\n",
        encoding="utf-8",
    )


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    for path, expected in (
        (PREREG, PREREG_SHA256),
        (PARENT_RESULT, PARENT_RESULT_SHA256),
        (CAGE_EVIDENCE, CAGE_EVIDENCE_SHA256),
        (MECHANICAL_ACCEPTANCE, MECHANICAL_ACCEPTANCE_SHA256),
    ):
        pin(path, expected)
    parser = load_parser()
    cell_rows = load_cell_rows()
    validate_extension_receipts(cell_rows)
    cage_evidence = json.loads(CAGE_EVIDENCE.read_text(encoding="utf-8"))
    mechanical = json.loads(MECHANICAL_ACCEPTANCE.read_text(encoding="utf-8"))
    if mechanical.get("model") != 1 or mechanical.get("optimization") != "NONE" or mechanical.get("holdout") != "UNSPENT":
        raise RuntimeError("frozen mechanical-acceptance identity mismatch")

    # CONTROL GATE: no child report is read above or inside this block.
    controls: dict[str, dict[str, Any]] = {}
    control_inis: dict[str, dict[str, str]] = {}
    control_eligibility: dict[str, dict[str, Any]] = {}
    control_years: list[dict[str, Any]] = []
    control_sources: list[dict[str, Any]] = []
    gates: list[dict[str, Any]] = []
    try:
        for window in ("MAIN", "BWD"):
            analysis, row, ini, eligibility, years, source_record = analyze_source_cell(
                parser, cell_rows, cage_evidence, "ACCEPTED_PARENT_CONTROL", window
            )
            del analysis
            gate = validate_control_row(row, ini, window)
            gates.append(gate)
            if not gate["pass"]:
                raise RuntimeError(f"canonical headline mismatch in {window}")
            if not eligibility["mechanically_eligible"]:
                raise RuntimeError(f"control mechanical identity ineligible in {window}")
            controls[window] = row
            control_inis[window] = ini
            control_eligibility[window] = eligibility
            control_years.extend(years)
            control_sources.append(source_record)
    except Exception as exc:
        write_blocked_control(f"{type(exc).__name__}: {exc}", list(controls.values()), gates)
        return 2

    if len(controls) != 2 or not all(gate["pass"] for gate in gates):
        write_blocked_control("control gate did not complete both windows", list(controls.values()), gates)
        return 2

    # The control gate has passed. Child dimensions may now be calculated.
    child_rows: list[dict[str, Any]] = []
    child_years: list[dict[str, Any]] = []
    child_sources: list[dict[str, Any]] = []
    eligibility_rows: list[dict[str, Any]] = []
    classifications: list[dict[str, Any]] = []
    config_comparisons: list[dict[str, Any]] = []
    for variant in ("SINGLETP_OFF", "BASKETTP_OFF"):
        for window in ("MAIN", "BWD"):
            analysis, row, ini, eligibility, years, source_record = analyze_source_cell(
                parser, cell_rows, cage_evidence, variant, window
            )
            del analysis
            child_sources.append(source_record)
            child_rows.append(row)
            child_years.extend(years)
            eligibility_rows.append({"variant": variant, "window": window, **eligibility})
            diff = config_diff(input_payload(control_inis[window]), input_payload(ini))
            diff_keys = [item["key"] for item in diff]
            if diff_keys != EXPECTED_CONFIG_DIFFS[variant]:
                raise RuntimeError(f"unexpected frozen config delta {variant}/{window}: {diff_keys}")
            config_comparisons.append(
                {
                    "variant": variant,
                    "window": window,
                    "differences": diff,
                    "one_logical_change_from_sell_control": len(diff) == 1,
                    "direction_matches_sell_control": ini.get("_16_Direction") == control_inis[window].get("_16_Direction"),
                    "observed_child_direction_input": ini.get("_16_Direction"),
                    "observed_control_direction_input": control_inis[window].get("_16_Direction"),
                }
            )
            if not eligibility["mechanically_eligible"]:
                continue
            control = controls[window]
            dimensions = {
                "max_cycle_holding_duration_higher": row["max_cycle_holding_duration_days"] > control["max_cycle_holding_duration_days"],
                "active_time_share_higher": row["active_time_share_full_window"] > control["active_time_share_full_window"],
                "top1_positive_cycle_gp_share_higher": row["top1_positive_cycle_gp_share"] > control["top1_positive_cycle_gp_share"],
                "zero_closed_year_count_higher": row["zero_closed_year_count"] > control["zero_closed_year_count"],
            }
            higher_count = sum(1 for value in dimensions.values() if value)
            classifications.append(
                {
                    "variant": variant,
                    "window": window,
                    "dimensions": dimensions,
                    "higher_count": higher_count,
                    "evidence_scope": "DESCRIPTIVE_NON_CAUSAL",
                    "frozen_rule_calculation": "CONCENTRATION_SHIFT" if higher_count >= 3 else "NO_CONCENTRATION_SHIFT",
                }
            )

    eligible_count = len(classifications)
    shift_count = sum(item["frozen_rule_calculation"] == "CONCENTRATION_SHIFT" for item in classifications)
    if eligible_count == 0:
        descriptive_rule_result = "DESCRIPTIVE_NON_CAUSAL_NO_ELIGIBLE_WINDOW"
    else:
        descriptive_rule_result = f"DESCRIPTIVE_NON_CAUSAL_{shift_count}_OF_{eligible_count}_CONCENTRATION_SHIFT"

    design_limitation = {
        "status": "CONFIGURATION_CONFOUNDED_DIRECTION_PLUS_EXIT",
        "causal_sell_exit_only_attribution": False,
        "reason": "Each frozen exit-off child uses _16_Direction=1 (BUY) while the validated accepted 14/70 control uses _16_Direction=2 (SELL); each comparison therefore differs on direction plus one exit input.",
        "frozen_preregistered_calculation_completed": True,
        "thresholds_or_formulas_changed": False,
        "preregistered_causal_question_answered": False,
    }
    descriptive_evidence = {
        "scope": "DESCRIPTIVE_NON_CAUSAL",
        "eligible_windows": eligible_count,
        "concentration_shift_windows": shift_count,
        "c_over_e": f"{shift_count}/{eligible_count}",
        "frozen_rule_result": descriptive_rule_result,
        "causal_sell_exit_only_attribution": False,
    }
    source_manifest = {
        "schema": "ea-lab-b16-gbp-h4-exitdiag-source-manifest/1",
        "base_sha": BASE_SHA,
        "preregistration": {"path": PREREG.relative_to(ROOT).as_posix(), "sha256": sha256_file(PREREG)},
        "canonical_parent_result": {"path": PARENT_RESULT.relative_to(ROOT).as_posix(), "sha256": sha256_file(PARENT_RESULT)},
        "parser": {"path": PARSER.relative_to(ROOT).as_posix(), "sha256": sha256_file(PARSER)},
        "aggregate_sources": [
            {"path": CELL_SUMMARY.relative_to(ROOT).as_posix(), "sha256": sha256_file(CELL_SUMMARY)},
            {"path": CAGE_EVIDENCE.relative_to(ROOT).as_posix(), "sha256": sha256_file(CAGE_EVIDENCE)},
            {"path": MECHANICAL_ACCEPTANCE.relative_to(ROOT).as_posix(), "sha256": sha256_file(MECHANICAL_ACCEPTANCE)},
            {"path": EXTENSION_CONTRACT.relative_to(ROOT).as_posix(), "sha256": sha256_file(EXTENSION_CONTRACT)},
            {"path": EXTENSION_RECEIPTS.relative_to(ROOT).as_posix(), "sha256": sha256_file(EXTENSION_RECEIPTS)},
        ],
        "tester_lineage": TESTER_LINEAGE,
        "cells": control_sources + child_sources,
    }
    diagnostic = {
        "schema": "ea-lab-b16-gbp-h4-exitdiag/1",
        "hypothesis": "HYP-B16-GBP-H4-EXITCONC-01",
        "base_sha": BASE_SHA,
        "tester_lineage": TESTER_LINEAGE,
        "control_gate": {"status": "PASS_EXACT_CANONICAL_HEADLINE", "source": "SELL_DIRECTION/GBP_H4", "checks": gates},
        "frozen_formulas": {
            "max_cycle_holding_duration_days": "max(cycles[].duration_seconds) / 86400",
            "active_time_share_full_window": "parser exposure.active_time_share_full_window",
            "top1_positive_cycle_gp_share": "max(positive cycles[].gross_profit) / sum(positive cycles[].gross_profit)",
            "zero_closed_year_count": "count numeric year bins where closed_ticket_count == 0",
            "window_classification": ">=3 of 4 dimensions strictly higher than same-window control",
        },
        "parent_controls": controls,
        "parent_control_eligibility": control_eligibility,
        "child_rows": child_rows,
        "child_eligibility": eligibility_rows,
        "config_comparisons": config_comparisons,
        "descriptive_window_calculations": classifications,
        "descriptive_evidence": descriptive_evidence,
        "overall": CAUSAL_BLOCKER,
        "design_limitation": design_limitation,
        "mt5_rerun": False,
        "new_strategy_test_runs": 0,
        "holdout": "UNSPENT",
        "optimization": "NONE",
        "model4": "NOT_RUN",
        "retuning": "NONE",
        "authority": "RESEARCH_ONLY_NO_EXIT_CHANGE_NO_OPTIMIZATION_NO_HOLDOUT_NO_MODEL4_NO_CANDIDATE_NO_RUNTIME_NO_RISK_DEFAULT_NO_DEPLOYMENT_NO_TRADING_NO_LIVE",
    }
    acceptance = {
        "schema": "ea-lab-b16-gbp-h4-exitdiag-acceptance/1",
        "overall": CAUSAL_BLOCKER,
        "control_reconciliation": "PASS_EXACT_CANONICAL_HEADLINE",
        "control_source": "SELL_DIRECTION/GBP_H4",
        "decision_classification": CAUSAL_BLOCKER,
        "descriptive_evidence": descriptive_evidence,
        "design_limitation": design_limitation["status"],
        "causal_sell_exit_only_attribution": False,
        "preregistered_causal_question_answered": False,
        "mt5_rerun": False,
        "new_strategy_test_runs": 0,
        "holdout": "UNSPENT",
        "optimization": "NONE",
        "model4": "NOT_RUN",
        "retuning": "NONE",
        "authority": diagnostic["authority"],
    }
    write_json(OUT / "diagnostic.json", diagnostic)
    write_json(OUT / "diagnostic_acceptance.json", acceptance)
    write_json(OUT / "source_manifest.json", source_manifest)

    summary_rows = [controls[window] for window in ("MAIN", "BWD")] + child_rows
    with (OUT / "diagnostic_summary.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(summary_rows[0].keys()))
        writer.writeheader()
        writer.writerows(summary_rows)
    all_years = control_years + child_years
    with (OUT / "year_participation.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(all_years[0].keys()))
        writer.writeheader()
        writer.writerows(all_years)
    reconciliation_lines = [
        "B16 GBPUSD/H4 EXIT CONCENTRATION SOURCE RECONCILIATION",
        f"BASE_SHA={BASE_SHA}",
        f"PREREG_SHA256={sha256_file(PREREG)}",
        f"PARSER_SHA256={sha256_file(PARSER)}",
        f"TESTER_LINEAGE={TESTER_LINEAGE}",
        "CONTROL_SOURCE=SELL_DIRECTION/GBP_H4",
        "CONTROL_GATE=PASS_EXACT_CANONICAL_HEADLINE",
        f"CONTROL_MAIN_RAW_REPORT_SHA256={CELL_SPECS[('ACCEPTED_PARENT_CONTROL', 'MAIN')]['raw_report_sha256']}",
        f"CONTROL_BWD_RAW_REPORT_SHA256={CELL_SPECS[('ACCEPTED_PARENT_CONTROL', 'BWD')]['raw_report_sha256']}",
        "CHILD_SOURCES=SINGLETP_OFF/GBP_H4/MAIN+BWD,BASKETTP_OFF/GBP_H4/MAIN+BWD",
        f"DESCRIPTIVE_MECHANICALLY_ELIGIBLE_WINDOWS={eligible_count}",
        f"DESCRIPTIVE_CONCENTRATION_SHIFT_WINDOWS={shift_count}",
        f"DESCRIPTIVE_C_OVER_E={shift_count}/{eligible_count}",
        f"DESCRIPTIVE_FROZEN_RULE_RESULT={descriptive_rule_result}",
        f"OVERALL={CAUSAL_BLOCKER}",
        "DESIGN_LIMITATION=CONFIGURATION_CONFOUNDED_DIRECTION_PLUS_EXIT",
        "CAUSAL_SELL_EXIT_ONLY_ATTRIBUTION=false",
        "PREREGISTERED_CAUSAL_QUESTION_ANSWERED=false",
        "MT5_RERUN=false",
        "HOLDOUT=UNSPENT",
        "OPTIMIZATION=NONE",
    ]
    (OUT / "source_reconciliation.txt").write_text("\n".join(reconciliation_lines) + "\n", encoding="utf-8")
    manifest_lines = [f"{sha256_file(OUT / name)}  {name}" for name in ARTIFACT_NAMES]
    (OUT / "artifacts.sha256").write_text("\n".join(manifest_lines) + "\n", encoding="utf-8")
    print(json.dumps(acceptance, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"BLOCKED_SOURCE_OR_FORMULA_FAILURE: {type(error).__name__}: {error}", file=sys.stderr)
        raise
