import os
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
lines.append("| USDJPY | MAIN | 0.97 | 274 | 13.18 | -175.04 | 1:100 | D:\EA_LAB\_mt5_auto\reports\O236_HOST_USDJPY_MAIN.htm |")
lines.append("| USDJPY | BWD | 1.28 | 316 | 10.14 | 1684.81 | 1:100 | D:\EA_LAB\_mt5_auto\reports\O236_HOST_USDJPY_BWD.htm |")
lines.append("| EURJPY | MAIN | 1.82 | 184 | 7.13 | 2344.20 | 1:100 | D:\EA_LAB\_mt5_auto\reports\O236_HOST_EURJPY_MAIN.htm |")
lines.append("| EURJPY | BWD | 1.06 | 498 | 16.79 | 567.24 | 1:100 | D:\EA_LAB\_mt5_auto\reports\O236_HOST_EURJPY_BWD.htm |")
lines.append("| CADJPY | MAIN | 1.14 | 408 | 16.94 | 1023.28 | 1:100 | D:\EA_LAB\_mt5_auto\reports\O236_HOST_CADJPY_MAIN.htm |")
lines.append("| CADJPY | BWD | 1.12 | 364 | 17.02 | 850.51 | 1:100 | D:\EA_LAB\_mt5_auto\reports\O236_HOST_CADJPY_BWD.htm |")
lines.append("| EURUSD | MAIN | 0.95 | 327 | 21.44 | -319.04 | 1:100 | D:\EA_LAB\_mt5_auto\reports\O236_HOST_EURUSD_MAIN.htm |")
lines.append("| EURUSD | BWD | 0.87 | 188 | 13.92 | -615.70 | 1:100 | D:\EA_LAB\_mt5_auto\reports\O236_HOST_EURUSD_BWD.htm |")
lines.append("| GBPJPY | MAIN | 1.35 | 334 | 12.00 | 2369.26 | 1:100 | D:\EA_LAB\_mt5_auto\reports\O236_HOST_GBPJPY_MAIN.htm |")
lines.append("| GBPJPY | BWD | 0.15 | 40 | 24.97 | -2490.40 | 1:100 | D:\EA_LAB\_mt5_auto\reports\O236_HOST_GBPJPY_BWD.htm |")
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

for label, rpt in parse_files:
    lines.append(f"### {label}")
    rpt_path = os.path.join("D:\EA_LAB", "_mt5_auto", "reports", rpt)
    with open(rpt_path, 'r') as pf:
        content = pf.read().strip()
    lines.append(content)
    lines.append("")

out = "D:/EA_LAB/_mt5_auto/O236_HOSTSCREEN_RESULTS.md"
with open(out, 'w') as f:
    f.write('\n'.join(lines))
print(f"Written {len(lines)} lines to {out}")
