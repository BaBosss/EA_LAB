#!/bin/bash
# ORDER-076 build-on — (ICE) CCI Currencies Strength Trend across FX-majors basket.
# EURUSD alone gave 10 trades (both-window PF>1 but statistically empty). CCI currency-strength
# is basket-designed; run the majors to lift trade count into significance. Default (has_sl, no escalation).
set -u
LAB=/d/EA_LAB
OUT="$LAB/_mt5_auto/cci_basket_results.csv"
echo "symbol,window,PF,Net,Trades,DDpct,Win" > "$OUT"

runc() { # $1 sym $2 from $3 to $4 window
  local rn="CCI_${1}_${4}"
  powershell -NoProfile -File "$LAB/scripts/mt5_run.ps1" -Expert "O076\\EA11_CCIStrengthTrend" -Symbol "$1" -Period H1 \
    -FromDate "$2" -ToDate "$3" -Model 1 -ReportName "$rn" -TimeoutSec 900 >/dev/null 2>&1
  local v=$(powershell -NoProfile -File "$LAB/scripts/parse_htm.ps1" "$LAB/_mt5_auto/reports/$rn.htm" 2>/dev/null \
    | awk -F':' '/PF/{p=$2}/Net/{n=$2}/Trades/{t=$2}/DDpct/{d=$2}/Win/{w=$2} END{gsub(/ /,"",p);gsub(/ /,"",n);gsub(/ /,"",t);gsub(/ /,"",d);gsub(/ /,"",w);print p","n","t","d","w}')
  echo "$1,$4,$v" >> "$OUT"
}

for sym in EURUSD GBPUSD USDJPY USDCAD AUDUSD NZDUSD USDCHF EURJPY GBPJPY; do
  runc "$sym" 2023.01.01 2026.07.01 MAIN
  runc "$sym" 2020.01.01 2022.12.31 BWD
done
echo "CCI BASKET DONE" >> "$OUT"
