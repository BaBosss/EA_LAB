#!/bin/bash
# ORDER-082 Wave5 — correlation gate vs live gold cohort (4 XAU EAs on acct 159503454).
# Runs each cohort EA on XAUUSD 2023-2026 (same window as Wave5 EXT_XAU_F236_M0618_MAIN),
# so monthly P&L aligns; then corr_wave5_cohort.py computes pairwise Pearson vs Wave5.
set -u
LAB=/d/EA_LAB
DEMO="$LAB/_demo_deploy/MT5"
# cohort ex5 already copied into Experts\O076 as corr*.ex5 (clean names)

runc() { # $1 expertClean $2 setfile $3 tf $4 reportname
  powershell -NoProfile -File "$LAB/scripts/mt5_run.ps1" -Expert "O076\\$1" -Symbol XAUUSD -Period "$3" \
    -FromDate 2023.01.01 -ToDate 2026.07.01 -Model 1 -SetFile "$(cygpath -w "$DEMO/$2")" \
    -ReportName "$4" -TimeoutSec 900 >/dev/null 2>&1
  echo "ran $4"
}

runc corrZeus     ZeusInspired_XAUUSD_H1_demo.set  H1 CORR_ZEUS_XAU_MAIN
runc corrSqueeze  SqueezeBreakout_XAU_demo.set     H4 CORR_SQZ_XAU_MAIN
runc corrTrend    TrendlineBreakout_XAU_demo.set   H4 CORR_TL_XAU_MAIN
runc corrBreakout EA_BREAKOUT_XAU_demo.set         H4 CORR_BRK_XAU_MAIN

echo "COHORT RUNS DONE"
