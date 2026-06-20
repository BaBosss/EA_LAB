#!/usr/bin/env python3
import subprocess, os, sys, time, json, pathlib

ROOT = pathlib.Path("D:/EA_LAB")
REPORTS_DIR = ROOT / "_mt5_auto" / "reports"
PARSE_SCRIPT = ROOT / "scripts" / "parse_mt5_report.py"
RUN_SCRIPT = ROOT / "scripts" / "mt5_run.ps1"
TIMEOUT_SEC = 150
NBSP = chr(0xa0)

EAS = [
    dict(label="S4_DayZone", expert="The Day Zone v2", symbol="GBPUSD", period="H1"),
    dict(label="S4_FiboHarm", expert=f"(OH){NBSP} Fibo Harmonic Pattern V01A", symbol="EURUSD", period="H1"),
    dict(label="S4_GhostMA", expert="Ghost by JOMHOD MA5", symbol="EURUSD", period="H1"),
    dict(label="S4_GhostBot", expert="Ghost Bot 01 G07 (1)", symbol="EURUSD", period="H1"),
    dict(label="S4_ESQ", expert="ESQ1004 1-13-17 BB RSI X Pyramid All Perfect mq5", symbol="EURUSD", period="H1"),
    dict(label="S4_EATREND", expert="EA TREND", symbol="EURUSD", period="H1"),
    dict(label="S4_FastReb", expert=f"FAST_Rebalance{NBSP} 2.2{NBSP}", symbol="EURUSD", period="H1"),
    dict(label="S4_EasyMoney", expert="EasyMoney_V1", symbol="EURUSD", period="H1"),
    dict(label="S4_BSPofit", expert="BS Pofit888", symbol="EURUSD", period="H1"),
    dict(label="S4_Chicken", expert="CHICKEN LITTILE EA 2 SYSTEM", symbol="EURUSD", period="H1"),
    dict(label="S4_V215", expert="V2_15_SEMI_ORI_FINAL", symbol="EURUSD", period="H1"),
    dict(label="S4_WinPro", expert="Winning Pro 2.5 (Update)", symbol="EURUSD", period="H1"),
    dict(label="S4_WinSemi", expert=f"Winning{NBSP} Semi auto RobotV3", symbol="EURUSD", period="H1"),
]

def kill_mt5():
    subprocess.run(["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass",
                     "-Command", "Stop-Process -Name terminal64 -Force -ErrorAction SilentlyContinue"],
                    capture_output=True, timeout=15)

def run_bt(expert, symbol, period, rn):
    cmd = ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass",
           "-File", str(RUN_SCRIPT),
           "-Expert", expert, "-Symbol", symbol, "-Period", period,
           "-Model", "1", "-FromDate", "2023.01.01", "-ToDate", "2026.06.01",
           "-SetFile", "", "-ReportName", rn]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=TIMEOUT_SEC, cwd=str(ROOT))
        return (result.returncode == 0, result.stdout.strip())
    except subprocess.TimeoutExpired:
        kill_mt5()
        return (False, "TIMEOUT")

def parse_rpt(rn):
    rp = REPORTS_DIR / f"{rn}.htm"
    if not rp.exists():
        return None
    cmd = ["python", str(PARSE_SCRIPT), str(rp), "--json"]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30, cwd=str(ROOT))
        data = json.loads(result.stdout)
        if "error" in data:
            return None
        return {"pf": data.get("profit_factor", 0),
                "eqdd": data.get("equity_drawdown_maximal_pct", 0),
                "tr": data.get("total_trades", 0)}
    except Exception:
        return None

results = []
for ea in EAS:
    lbl, exp, sym, per = ea["label"], ea["expert"], ea["symbol"], ea["period"]
    rn = f"{lbl}.htm"
    print(f"
=== {lbl}: {repr(exp)} | {sym} {per} ===", flush=True)
    kill_mt5()
    time.sleep(2)
    ok, out = run_bt(exp, sym, per, rn)
    if not ok:
        print(f"  NO_REPORT", flush=True)
        results.append(dict(**ea, pf=None, eqdd=None, tr=None, gate="TIMEOUT"))
        continue
    parsed = parse_rpt(rn)
    if parsed is None:
        print(f"  NO_REPORT (parse fail)", flush=True)
        results.append(dict(**ea, pf=None, eqdd=None, tr=None, gate="NO_REPORT"))
        continue
    pf, eqdd, tr = parsed["pf"], parsed["eqdd"], parsed["tr"]
    gate = "PASS" if (pf >= 1.50 and eqdd <= 30 and tr >= 100) else "REJECT"
    print(f"  PF={pf}, EQ_DD={eqdd}%, Trades={tr} => {gate}", flush=True)
    results.append(dict(**ea, pf=pf, eqdd=eqdd, tr=int(tr), gate=gate))
    time.sleep(2)

survivors = [r for r in results if r["gate"] == "PASS"]
survivors.sort(key=lambda x: x["pf"] or 0, reverse=True)

ml = []
ml.append("## Smoke Batch 4 Results - 2026-06-19")
ml.append("")
ml.append("### SURVIVORS (PF>=1.50, DD<=30%, Trades>=100)")
ml.append("")
if survivors:
    ml.append("| Label | Expert | Symbol | PF | Equity DD% | Trades |")
    ml.append("|-------|--------|--------|-----|-----------|--------|")
    for r in survivors:
        ml.append("| " + r["label"] + " | " + r["expert"] + " | " + r["symbol"] + " | {:.2f}".format(r["pf"]) + " | {:.2f}%".format(r["eqdd"]) + " | " + str(r["tr"]) + " |")
else:
    ml.append("None")
ml.append("")
ml.append("### ALL RESULTS")
ml.append("")
ml.append("| Label | Expert | Symbol | PF | Equity DD% | Trades | Gate |")
ml.append("|-------|--------|--------|----|------------|--------|------|")
for r in results:
    pfs = "{:.2f}".format(r["pf"]) if r["pf"] is not None else "N/A"
    dds = "{:.2f}%".format(r["eqdd"]) if r["eqdd"] is not None else "N/A"
    trs = str(r["tr"]) if r["tr"] is not None else "N/A"
    ml.append("| " + r["label"] + " | " + r["expert"] + " | " + r["symbol"] + " | " + pfs + " | " + dds + " | " + trs + " | " + r["gate"] + " |")
ml.append("")

op = ROOT / "_mt5_auto" / "smoke4_results.md"
op.write_text("
".join(ml), encoding="utf-8")
print(f"
Written to {op}", flush=True)
print(f"Survivors: {len(survivors)}/{len(results)}", flush=True)
