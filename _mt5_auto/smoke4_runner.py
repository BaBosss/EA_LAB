#!/usr/bin/env python3
import subprocess, os, sys, time, json, pathlib, shutil
ROOT = pathlib.Path("D:/EA_LAB")
DATA_DIR = pathlib.Path("C:/Users/patip/AppData/Roaming/MetaQuotes/Terminal/9CA16B8382AE4CF692710FB36B9DA355")
REPORTS_DIR = ROOT / "_mt5_auto" / "reports"
INI_DIR = ROOT / "_mt5_auto" / "ini"
TERMINAL = "D:/Meta 5/terminal64.exe"
PARSE_SCRIPT = ROOT / "scripts" / "parse_mt5_report.py"
TS = 150
NB = chr(0xa0)

EAS = [
    ("S4_DayZone", "The Day Zone v2", "GBPUSD", "H1"),
    ("S4_FiboHarm", "(OH)" + NB + " Fibo Harmonic Pattern V01A", "EURUSD", "H1"),
    ("S4_GhostMA", "Ghost by JOMHOD MA5", "EURUSD", "H1"),
    ("S4_GhostBot", "Ghost Bot 01 G07 (1)", "EURUSD", "H1"),
    ("S4_ESQ", "ESQ1004 1-13-17 BB RSI X Pyramid All Perfect mq5", "EURUSD", "H1"),
    ("S4_EATREND", "EA TREND", "EURUSD", "H1"),
    ("S4_FastReb", "FAST_Rebalance" + NB + " 2.2" + NB, "EURUSD", "H1"),
    ("S4_EasyMoney", "EasyMoney_V1", "EURUSD", "H1"),
    ("S4_BSPofit", "BS Pofit888", "EURUSD", "H1"),
    ("S4_Chicken", "CHICKEN LITTILE EA 2 SYSTEM", "EURUSD", "H1"),
    ("S4_V215", "V2_15_SEMI_ORI_FINAL", "EURUSD", "H1"),
    ("S4_WinPro", "Winning Pro 2.5 (Update)", "EURUSD", "H1"),
    ("S4_WinSemi", "Winning" + NB + " Semi auto RobotV3", "EURUSD", "H1"),
]

def kill_mt5():
    subprocess.run(["powershell.exe","-NoProfile","-ExecutionPolicy","Bypass",
        "-Command","Stop-Process -Name terminal64 -Force -ErrorAction SilentlyContinue"],
        capture_output=True, timeout=15)

results = []
for label, expert, symbol, period in EAS:
    rn = label + ".htm"
    src = DATA_DIR / rn
    dst = REPORTS_DIR / rn
    print("")
    print("=== " + label + " ===")
    for ff in list(DATA_DIR.glob(label + "*")):
        try: ff.unlink()
        except: pass
    ini = INI_DIR / (rn + ".ini")
    CR = chr(13) + chr(10)
    ini.write_text("[Tester]" + CR + "Expert=" + expert + CR + "Symbol=" + symbol + CR + "Period=" + period + CR + "Model=1" + CR + "Optimization=0" + CR + "FromDate=2023.01.01" + CR + "ToDate=2026.06.01" + CR + "ForwardMode=0" + CR + "Deposit=10000" + CR + "Currency=USD" + CR + "Leverage=100" + CR + "ExecutionMode=0" + CR + "Visual=0" + CR + "Report=" + rn + CR + "ReplaceReport=1" + CR + "ShutdownTerminal=1" + CR + "[TesterInputs]" + CR)
    kill_mt5()
    time.sleep(3)
    proc = subprocess.Popen([TERMINAL, "/config:" + str(ini)])
    t0 = time.time()
    found = False
    while time.time() - t0 < TS:
        if src.exists():
            time.sleep(3)
            found = True
            break
        time.sleep(3)
    if not found:
        kill_mt5()
        print("  NO_REPORT")
        results.append(dict(label=label,expert=expert,symbol=symbol,pf=None,eqdd=None,tr=None,gate="TIMEOUT"))
        continue
    shutil.copy2(str(src), str(dst))
    r = subprocess.run(["python", str(PARSE_SCRIPT), str(dst), "--json"],
        capture_output=True, text=True, timeout=30, cwd=str(ROOT))
    data = json.loads(r.stdout)
    if "error" in data:
        print("  PARSE FAIL: " + data.get("error",""))
        results.append(dict(label=label,expert=expert,symbol=symbol,pf=None,eqdd=None,tr=None,gate="NO_REPORT"))
        continue
    pf = data.get("profit_factor",0)
    eqdd = data.get("equity_drawdown_maximal_pct",0)
    tr = int(data.get("total_trades",0))
    gate = "PASS" if (pf >= 1.50 and eqdd <= 30 and tr >= 100) else "REJECT"
    print("  PF=" + str(pf) + " EQ_DD=" + str(eqdd) + "% Trades=" + str(tr) + " => " + gate)
    results.append(dict(label=label,expert=expert,symbol=symbol,pf=pf,eqdd=eqdd,tr=tr,gate=gate))
    time.sleep(2)

survivors = [r for r in results if r["gate"]=="PASS"]
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
        ml.append("| " + r["label"] + " | " + r["expert"] + " | " + r["symbol"] + " | %.2f" % r["pf"] + " | %.2f%%" % r["eqdd"] + " | " + str(r["tr"]) + " |")
else:
    ml.append("None")
ml.append("")
ml.append("### ALL RESULTS")
ml.append("")
ml.append("| Label | Expert | Symbol | PF | Equity DD% | Trades | Gate |")
ml.append("|-------|--------|--------|----|------------|--------|------|")
for r in results:
    pfs = "%.2f" % r["pf"] if r["pf"] is not None else "N/A"
    dds = "%.2f%%" % r["eqdd"] if r["eqdd"] is not None else "N/A"
    trs = str(r["tr"]) if r["tr"] is not None else "N/A"
    ml.append("| " + r["label"] + " | " + r["expert"] + " | " + r["symbol"] + " | " + pfs + " | " + dds + " | " + trs + " | " + r["gate"] + " |")
ml.append("")

op = ROOT / "_mt5_auto" / "smoke4_results.md"
op.write_text(chr(10).join(ml), encoding="utf-8")
print("")
print("Done. Written to " + str(op))
print("Survivors: " + str(len(survivors)) + "/" + str(len(results)))
