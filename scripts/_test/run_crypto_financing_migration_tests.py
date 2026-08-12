#!/usr/bin/env python3
"""Deterministic cage for ORDER-1350/1370's report-backed evidence migration."""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / "scripts" / "migrate_crypto_financing_evidence.py"
PASS = 0
FAIL = 0


def check(name: str, condition: bool, detail: str = ""):
    global PASS, FAIL
    if condition:
        PASS += 1
        print(f"[ok ] {name}")
    else:
        FAIL += 1
        print(f"[FAIL] {name} {detail}")


def report(symbol="BTCUSD", swap="-1.25"):
    return f'''<table><tr><td>ignored</td></tr></table><table>
<tr><td>Time</td><td>Deal</td><td>Symbol</td><td>Type</td><td>Direction</td><td>Volume</td><td>Price</td><td>Order</td><td>Commission</td><td>Swap</td><td>Profit</td></tr>
<tr><td>2025.01.01 00:00:00</td><td>1</td><td>{symbol}</td><td>buy</td><td>in</td><td>0.01</td><td>100</td><td>1</td><td>0</td><td>0.00</td><td>0</td></tr>
<tr><td>2025.01.02 00:00:00</td><td>2</td><td>{symbol}</td><td>sell</td><td>out</td><td>0.01</td><td>101</td><td>2</td><td>0</td><td>{swap}</td><td>1</td></tr></table>'''


def probe(symbol="BTCUSD"):
    return "\n".join((json.dumps({"_comment": "fixture"}), json.dumps({
        "entity": "SwapProbe", "probe": "spec", "logical_symbol": symbol,
        "taken_utc": "2026-08-04T00:00:00Z", "swap_mode": "INTEREST_CURRENT"}))) + "\n"


def record(symbol="BTCUSD", report_path="", entity="PilotCellRun"):
    return {"entity": entity, "logical_symbol": symbol, "cell_id": "B14/X/H4",
            "arm": "baseline" if entity == "PilotCellRun" else "selected-verification",
            "window": "MAIN" if entity == "PilotCellRun" else "BWD",
            "model": 1 if entity == "PilotCellRun" else 4,
            "selection_record": "factory/runs/pilot/selection/selection.jsonl"
            if entity == "PilotSelectedVerification" else None,
            "report": report_path, "pf": 1.2, "gross_profit": 12,
            "gross_loss": -10, "net_profit": 2, "trades": 49, "dd_pct": 15.22,
            "notes": ["CRYPTO FINANCING: tester-native PF is optimistic until deducted."]}


def run(root: Path, probe_path: Path, apply=False):
    cmd = [sys.executable, str(TOOL), "--root", str(root), "--probe", str(probe_path)]
    if apply:
        cmd.append("--apply")
    return subprocess.run(cmd, text=True, capture_output=True)


with tempfile.TemporaryDirectory() as tmp_s:
    tmp = Path(tmp_s)
    runs = tmp / "factory" / "runs" / "pilot"
    reports = tmp / "reports"
    probes = ROOT / "factory" / "runs" / "pilot" / "swap_probe"
    runs.mkdir(parents=True); reports.mkdir(); probes.mkdir(parents=True, exist_ok=True)
    source_report = reports / "btc.htm"; source_report.write_text(report(), encoding="utf-8")
    probe_file = ROOT / "factory" / "runs" / "pilot" / "swap_probe" / "fixture_crypto_migration.jsonl"
    probe_file.write_text(probe(), encoding="utf-8")
    try:
        crypto = runs / "crypto.jsonl"
        noncrypto = runs / "noncrypto.jsonl"
        crypto.write_text("\n".join((
            json.dumps(record(report_path=str(source_report)), separators=(",", ":")),
            json.dumps(record(report_path=str(source_report), entity="PilotSelectedVerification"), separators=(",", ":")),
            json.dumps(record(report_path=str(source_report), entity="PilotProbeRun"), separators=(",", ":")),
            json.dumps(record(report_path=str(source_report), entity="PilotProbeSelection"), separators=(",", ":")),
            json.dumps(record(report_path=str(source_report), entity="PilotCloseout"), separators=(",", ":")),
        )) + "\n", encoding="utf-8")
        noncrypto.write_text(json.dumps(record("XAUUSD", str(source_report)), separators=(",", ":")) + "\n", encoding="utf-8")
        noncrypto_before = noncrypto.read_bytes()
        before_lines = [json.loads(line) for line in crypto.read_text(encoding="utf-8").splitlines()]
        before = before_lines[0]

        result = run(runs, probe_file, apply=False)
        check("dry run identifies both financing run entities", result.returncode == 0 and "2 BTCUSD" in result.stdout, result.stdout + result.stderr)
        check("dry run writes nothing", [json.loads(line) for line in crypto.read_text(encoding="utf-8").splitlines()] == before_lines)

        result = run(runs, probe_file, apply=True)
        after_lines = [json.loads(line) for line in crypto.read_text(encoding="utf-8").splitlines()]
        after = after_lines[0]
        selected_after = after_lines[1]
        nonrun_after = after_lines[2:]
        fin = after["financing_deducted"]
        selected_fin = selected_after["financing_deducted"]
        check("apply derives tester swap for both run entities", result.returncode == 0 and fin["tester_swap_charged"] == -1.25 and selected_fin["tester_swap_charged"] == -1.25, result.stdout + result.stderr)
        check("apply records tester-native/no-posthoc semantics for selected verification", selected_fin["applied"] is False and selected_fin["metric_basis"] == "tester_native")
        check("apply stores a probe reference rather than copied mode/rate", selected_fin["swap_mode_probe"].endswith("fixture_crypto_migration.jsonl") and "swap_mode" not in selected_fin)
        check("apply preserves all six tester-native metrics", all(after[k] == before[k] for k in ("pf", "gross_profit", "gross_loss", "net_profit", "trades", "dd_pct")) and all(selected_after[k] == before[k] for k in ("pf", "gross_profit", "gross_loss", "net_profit", "trades", "dd_pct")))
        check("apply corrects only the stale financing note", selected_after["notes"] == ["CRYPTO FINANCING: the MT5 tester's Swap column is included in the stored tester-native metrics. financing_deducted records the report-derived tester swap for provenance; no post-hoc deduction is applied."])
        check("BTC probe/selection/closeout entities remain byte-identical", after_lines[2:] == before_lines[2:])
        check("wrong-symbol/noncrypto record is byte-identical", noncrypto.read_bytes() == noncrypto_before)

        result = run(runs, probe_file, apply=True)
        check("rerun is an explicit no-op", result.returncode == 0 and "MIGRATED: 0" in result.stdout and "2 already migrated" in result.stdout, result.stdout + result.stderr)

        crypto.write_text(json.dumps(record(report_path=str(reports / "missing.htm"))) + "\n", encoding="utf-8")
        result = run(runs, probe_file, apply=True)
        check("missing source report refuses", result.returncode == 2 and "source report is missing" in result.stdout, result.stdout + result.stderr)

        crypto.write_text(json.dumps(record(report_path=str(source_report))) + "\n", encoding="utf-8")
        bad_probe = ROOT / "factory" / "runs" / "pilot" / "swap_probe" / "fixture_wrong_crypto_migration.jsonl"
        bad_probe.write_text(probe("ETHUSD"), encoding="utf-8")
        try:
            result = run(runs, bad_probe, apply=True)
            check("wrong/stale probe reference refuses", result.returncode == 2 and "exactly one dated spec record for BTCUSD" in result.stdout, result.stdout + result.stderr)
        finally:
            bad_probe.unlink(missing_ok=True)

        bad_date_probe = ROOT / "factory" / "runs" / "pilot" / "swap_probe" / "fixture_bad_date_crypto_migration.jsonl"
        bad_date_probe.write_text(probe().replace("2026-08-04T00:00:00Z", "not-a-date"), encoding="utf-8")
        try:
            result = run(runs, bad_date_probe, apply=True)
            check("undated probe provenance refuses", result.returncode == 2 and "exactly one dated spec record for BTCUSD" in result.stdout, result.stdout + result.stderr)
        finally:
            bad_date_probe.unlink(missing_ok=True)

        scalar_probe = ROOT / "factory" / "runs" / "pilot" / "swap_probe" / "fixture_scalar_crypto_migration.jsonl"
        scalar_probe.write_text("null\n", encoding="utf-8")
        try:
            result = run(runs, scalar_probe, apply=True)
            check("non-object probe provenance refuses", result.returncode == 2 and "not a JSON object" in result.stdout, result.stdout + result.stderr)
        finally:
            scalar_probe.unlink(missing_ok=True)

        source_report.write_text(report(swap="oops"), encoding="utf-8")
        result = run(runs, probe_file, apply=True)
        check("malformed tester swap refuses", result.returncode == 2 and "malformed tester swap value" in result.stdout, result.stdout + result.stderr)
    finally:
        probe_file.unlink(missing_ok=True)

print(f"crypto-financing-migration: {PASS + FAIL} case(s), {FAIL} failed")
sys.exit(1 if FAIL else 0)
