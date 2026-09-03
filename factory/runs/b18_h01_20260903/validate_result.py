#!/usr/bin/env python3
import csv, hashlib, json, sys
from pathlib import Path

PKG = Path(__file__).resolve().parent
ROOT = PKG.parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from parse_mt5_report import parse_report

EXPECTED = {
    "MAIN": {"profit_factor": 1.19, "net_profit": 2347.58, "total_trades": 1631.0,
             "equity_drawdown_maximal_pct": 5.11, "from_date": "2023.01.01", "to_date": "2025.12.31"},
    "BWD": {"profit_factor": 0.98, "net_profit": -154.55, "total_trades": 1583.0,
            "equity_drawdown_maximal_pct": 7.82, "from_date": "2020.01.01", "to_date": "2022.12.31"}}
SET_SHA = "67973adaf57211858f8bb615c4a73864adc03fd31e6ad0d16f6a044a8882a1c1"
EX5_SHA = "f66101bc54cd167ec5fa3bcfb6b5192a326413c2c1d6cf5c256fa7dee71ec8d0"
BUILD_RECEIPT = "br-d03f750716bd4f5d8b4630d0e9d3d03b"

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def require(ok, msg):
    if not ok:
        raise SystemExit("FAIL: " + msg)

summary = json.loads((PKG / "summary.json").read_text(encoding="utf-8"))
require(summary["set_sha256"] == SET_SHA, "summary set SHA")
require(summary["ex5_sha256"] == EX5_SHA, "summary EX5 SHA")
require(summary["build_receipt"] == BUILD_RECEIPT, "summary build receipt")
require(summary["model"] == 1 and summary["optimization"] == 0, "tester model/optimization")
require(summary["holdout"] == "UNSPENT_FORBIDDEN", "HOLDOUT state")
require(sha(PKG / "B18_H01_r1.set") == SET_SHA, "set bytes")
set_text = (PKG / "B18_H01_r1.set").read_text(encoding="utf-8-sig")
require("_18_DirMode=1" in set_text and "_18_Direction=1" in set_text, "Mode1/Direction1 pin")

receipt = json.loads((PKG / "build_receipt.jsonl").read_text(encoding="utf-8").strip())
require(receipt["build_receipt"] == BUILD_RECEIPT, "receipt token")
require(receipt["artifact_sha256"] == EX5_SHA, "receipt EX5 SHA")
for window, expected in EXPECTED.items():
    report = parse_report(str(PKG / window / "report.htm"))
    for key, value in expected.items():
        require(report.get(key) == value, f"{window} {key}: {report.get(key)} != {value}")
    require(report["symbol"] == "XAUUSD" and report["period"] == "H1", f"{window} symbol/period")
    require(report["leverage"] == "1:100", f"{window} leverage")
    lev = json.loads((PKG / window / "leverage_check.json").read_text(encoding="utf-8-sig"))
    trunc = json.loads((PKG / window / "truncation_check.json").read_text(encoding="utf-8-sig"))
    require(lev.get("match") is True and lev.get("actual_leverage") == 100, f"{window} leverage sidecar")
    require(trunc.get("truncated") is False, f"{window} truncation sidecar")
    ini = (PKG / window / "tester.ini").read_text(encoding="utf-8-sig")
    require("Model=1" in ini and "Optimization=0" in ini, f"{window} ini model/optimization")
    require(f"FromDate={expected['from_date']}" in ini and f"ToDate={expected['to_date']}" in ini,
            f"{window} ini window")
    require("Leverage=1:100" in ini, f"{window} ini leverage")
    require("2026." not in ini, f"{window} HOLDOUT date contamination")

rows = list(csv.DictReader((PKG / "year_split.csv").open(encoding="utf-8")))
require(len(rows) == 6, "year split row count")
for window in ("MAIN", "BWD"):
    wr = [r for r in rows if r["window"] == window]
    require(sum(int(r["trades"]) for r in wr) == int(EXPECTED[window]["total_trades"]),
            f"{window} yearly trades reconcile")
    require(round(sum(float(r["net_profit"]) for r in wr), 2) == EXPECTED[window]["net_profit"],
            f"{window} yearly net reconcile")

exp = json.loads((PKG / "exposure_summary.json").read_text(encoding="utf-8"))
require(exp["configured"]["configured_max_positions"] == 5, "configured max positions")
require(exp["configured"]["lot_ladder_L0_L4"] == [0.01] * 5, "configured lot ladder")
for window in ("MAIN", "BWD"):
    obs = exp["observed"][window]
    require(obs["max_concurrent_positions"] == 3 and obs["max_total_lots"] == 0.03,
            f"{window} observed exposure")
    require(obs["active_months"] == 36 and obs["ending_active_positions"] == 0,
            f"{window} participation/flat end")
prep = json.loads((PKG / "tester_prep.json").read_text(encoding="utf-8-sig"))
require(prep["install"] == r"D:\Meta 5", "tester prep install")
require(prep["canonical_sha"] == "64b5fcb37cfe59e05166b18de4e567dd02c01b6d", "tester prep canonical")
require(prep["ex5_sha256"] == EX5_SHA and prep["set_sha256"] == SET_SHA, "tester prep hashes")
require(prep["build_receipt"] == BUILD_RECEIPT, "tester prep receipt")
require(prep["model"] == 1 and prep["optimization"] == 0 and prep["holdout"] == "UNSPENT_FORBIDDEN", "tester prep boundaries")
print("B18_H01_RESULT_VALIDATION=PASS")
