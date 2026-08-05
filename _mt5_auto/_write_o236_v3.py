import os
import subprocess

lines = []
lines.append("# ORDER-236 Host Screen Results")
lines.append("")
lines.append("## PART A - GEN-STANDING Zero-Trade Re-runs")
lines.append("")
lines.append("### Run 1: PivotBreakout_XAU on XAUUSD D1 (2023.01.01-2025.12.31)")
lines.append("- **Trades:** 0")
lines.append("- **PF:** 0")
lines.append("- **Equity DD%:** 0")
lines.append("- **Net Profit:** 0")
lines.append("- **Leverage:** 1:100")
lines.append("- **Refusal/Error lines in Journal/Log:** No Journal/Log section present in report. No refusal lines found.")
lines.append("")
lines.append("### Run 2: PivotBreakout_XAU on XAGUSD D1 (2023.01.01-2025.12.31)")
lines.append("- **Trades:** 0")
lines.append("- **PF:** 0")
lines.append("- **Equity DD%:** 0")
lines.append("- **Net Profit:** 0")
lines.append("- **Leverage:** 1:100")
lines.append("- **Refusal/Error lines in Journal/Log:** No Journal/Log section present in report. No refusal lines found.")
lines.append("")
lines.append("## PART B - CTRL-Only Host Screen (B14_AB_off.set)")
lines.append("")
lines.append("| symbol | window | PF | trades | DD% | net | leverage | report path |")
lines.append("|---|---|---|---|---|---|---|---|")

BASE = "D:/EA_LAB/_mt5_auto/reports/"
rows = [
    ("USDJPY", "MAIN", 0.97, 274, 13.18, -175.04, "O236_HOST_USDJPY_MAIN.htm"),
    ("USDJPY", "BWD", 1.28, 316, 10.14, 1684.81, "O236_HOST_USDJPY_BWD.htm"),
    ("EURJPY", "MAIN", 1.82, 184, 7.13, 2344.20, "O236_HOST_EURJPY_MAIN.htm"),
    ("EURJPY", "BWD", 1.06, 498, 16.79, 567.24, "O236_HOST_EURJPY_BWD.htm"),
    ("CADJPY", "MAIN", 1.14, 408, 16.94, 1023.28, "O236_HOST_CADJPY_MAIN.htm"),
    ("CADJPY", "BWD", 1.12, 364, 17.02, 850.51, "O236_HOST_CADJPY_BWD.htm"),
    ("EURUSD", "MAIN", 0.95, 327, 21.44, -319.04, "O236_HOST_EURUSD_MAIN.htm"),
    ("EURUSD", "BWD", 0.87, 188, 13.92, -615.70, "O236_HOST_EURUSD_BWD.htm"),
    ("GBPJPY", "MAIN", 1.35, 334, 12.00, 2369.26, "O236_HOST_GBPJPY_MAIN.htm"),
    ("GBPJPY", "BWD", 0.15, 40, 24.97, -2490.40, "O236_HOST_GBPJPY_BWD.htm"),
]

for sym, win, pf, tr, dd, net, rpt in rows:
    lines.append(f"| {sym} | {win} | {pf:.2f} | {tr} | {dd:.2f} | {net:.2f} | 1:100 | {BASE}{rpt} |")

lines.append("")
lines.append("---")
lines.append("")
lines.append("## Raw Parse Output")
lines.append("")

parse_files = [
    ("USDJPY MAIN", "O236_HOST_USDJPY_MAIN.htm"),
    ("USDJPY BWD", "O236_HOST_USDJPY_BWD.htm"),
    ("EURJPY MAIN", "O236_HOST_EURJPY_MAIN.htm"),
    ("EURJPY BWD", "O236_HOST_EURJPY_BWD.htm"),
    ("CADJPY MAIN", "O236_HOST_CADJPY_MAIN.htm"),
    ("CADJPY BWD", "O236_HOST_CADJPY_BWD.htm"),
    ("EURUSD MAIN", "O236_HOST_EURUSD_MAIN.htm"),
    ("EURUSD BWD", "O236_HOST_EURUSD_BWD.htm"),
    ("GBPJPY MAIN", "O236_HOST_GBPJPY_MAIN.htm"),
    ("GBPJPY BWD", "O236_HOST_GBPJPY_BWD.htm"),
]

python_exe = "/d/EA_LAB/tools/python312/python.exe"
parser = "/d/EA_LAB/scripts/parse_mt5_report.py"

for label, rpt in parse_files:
    lines.append(f"### {label}")
    rpt_path = "D:/EA_LAB/_mt5_auto/reports/" + rpt
    result = subprocess.run(
        [python_exe, parser, rpt_path],
        capture_output=True, text=True
    )
    content = result.stdout.strip()
    lines.append(content)
    lines.append("")

out = "D:/EA_LAB/_mt5_auto/O236_HOSTSCREEN_RESULTS.md"
with open(out, 'w') as f:
    f.write('\n'.join(lines))
print(f"Written {len(lines)} lines to {out}")
