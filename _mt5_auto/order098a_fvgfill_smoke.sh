#!/bin/bash
# ORDER-098-A — FVGFill_Naked flat-lot smoke, acceptance matrix per taskboard spec.
set -u
LAB=/d/EA_LAB
OUT="$LAB/_mt5_auto/order098a_fvgfill_results.csv"
echo "symbol,tf,PF,Net,Trades,DDpct,Win" > "$OUT"

runc() { # $1 sym $2 tf
  local rn="O098A_FVG_${1}_${2}"
  powershell -NoProfile -File "$LAB/scripts/mt5_run.ps1" -Expert "FVGFill_Naked" -Symbol "$1" -Period "$2" \
    -FromDate 2023.01.01 -ToDate 2026.01.01 -Model 1 -ReportName "$rn" -TimeoutSec 900 >/dev/null 2>&1
  local v=$(powershell -NoProfile -File "$LAB/scripts/parse_htm.ps1" "$LAB/_mt5_auto/reports/$rn.htm" 2>/dev/null \
    | awk -F':' '/PF/{p=$2}/Net/{n=$2}/Trades/{t=$2}/DDpct/{d=$2}/Win/{w=$2} END{gsub(/ /,"",p);gsub(/ /,"",n);gsub(/ /,"",t);gsub(/ /,"",d);gsub(/ /,"",w);print p","n","t","d","w}')
  echo "$1,$2,$v" >> "$OUT"
}

runc EURUSD H1
runc EURUSD H4
runc XAUUSD H1
runc XAUUSD H4
echo "ORDER-098-A DONE" >> "$OUT"
