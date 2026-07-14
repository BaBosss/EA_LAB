#!/bin/bash
# ORDER-095 batch: expand EA_BREAKOUT_XAU (validated flat-lot edge, currently XAU-only)
# to new symbol candidates. Flat-lot smoke both-window (methodology step 1).
# Same locked set (breakout40/ATR1.5-5/EMA200/buyonly), fixed lot 0.01, tester default off (fine, backtest ignores).
set -u
LAB=/d/EA_LAB
EXP='C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355\MQL5\Experts'
DEMO="$LAB/_demo_deploy/MT5"
OUT="$LAB/_mt5_auto/order095_breakout_expand_results.csv"
echo "symbol,tf,window,PF,Net,Trades,DDpct,Win" > "$OUT"

# clean-name copy into O076 working folder (already proven reachable) with a fresh name
DEMO_W="$(cygpath -w "$DEMO")"
powershell -NoProfile -Command "Copy-Item -LiteralPath '$DEMO_W\\EA_BREAKOUT_XAU.ex5' '$EXP\\O076\\brkxauExpand.ex5' -Force"
powershell -NoProfile -Command "Test-Path '$EXP\\O076\\brkxauExpand.ex5'"

runc() { # $1 sym $2 tf $3 from $4 to $5 window
  local rn="O095_BRK_${1}_${2}_${5}"
  powershell -NoProfile -File "$LAB/scripts/mt5_run.ps1" -Expert "O076\\brkxauExpand" -Symbol "$1" -Period "$2" \
    -FromDate "$3" -ToDate "$4" -Model 1 -SetFile "$(cygpath -w "$DEMO/EA_BREAKOUT_XAU_demo.set")" \
    -ReportName "$rn" -TimeoutSec 900 >/dev/null 2>&1
  local v=$(powershell -NoProfile -File "$LAB/scripts/parse_htm.ps1" "$LAB/_mt5_auto/reports/$rn.htm" 2>/dev/null \
    | awk -F':' '/PF/{p=$2}/Net/{n=$2}/Trades/{t=$2}/DDpct/{d=$2}/Win/{w=$2} END{gsub(/ /,"",p);gsub(/ /,"",n);gsub(/ /,"",t);gsub(/ /,"",d);gsub(/ /,"",w);print p","n","t","d","w}')
  echo "$1,$2,$5,$v" >> "$OUT"
}

# Candidates: breakout mechanism (ATR-expand + daily-EMA trend filter) travels best on
# trending/volatile instruments. XAGUSD = gold-family sibling; GBPUSD/EURUSD/USDJPY = liquid majors;
# US30 = index (already has a report artifact seen earlier, so tester supports it).
for sym in XAGUSD GBPUSD EURUSD USDJPY US30; do
  runc "$sym" H4 2023.01.01 2026.07.01 MAIN
  runc "$sym" H4 2020.01.01 2022.12.31 BWD
done
echo "ORDER-095 BREAKOUT EXPAND DONE" >> "$OUT"
