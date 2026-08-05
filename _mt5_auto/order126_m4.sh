#!/usr/bin/env bash
cd /d/EA_LAB || exit 1
OUT="_mt5_auto/ORDER126_M4.csv"; echo "config,window,PF,Trades" > "$OUT"
declare -A W=( ["MAIN"]="2023.01.01 2025.12.31" ["BWD"]="2020.01.01 2022.12.31" )
for cfg in SMC_ra0_sl2p4 SMC_ra10_sl2p4 SMC_ra0_sl3; do
  for win in MAIN BWD; do
    read f t <<< "${W[$win]}"
    rep="O126M4_${cfg}_${win}"
    powershell -Command "Get-Process terminal64 -EA SilentlyContinue | Stop-Process -Force" >/dev/null 2>&1; sleep 2
    powershell -File scripts/mt5_run.ps1 -Expert "EmaStoRev126" -Symbol EURUSD -Period H1 -FromDate "$f" -ToDate "$t" -Model 4 -SetFile "D:/EA_LAB/_mt5_auto/ab_sets/order126_sl/${cfg}.set" -ReportName "$rep" -Force >/dev/null 2>&1
    htm="_mt5_auto/reports/${rep}.htm"
    pf=$(powershell -File scripts/parse_htm.ps1 -Path "$htm" 2>/dev/null | grep -iE "^PF" | grep -oE "[0-9.]+" | head -1)
    tr=$(powershell -File scripts/parse_htm.ps1 -Path "$htm" 2>/dev/null | grep -iE "Trades" | grep -oE "[0-9]+" | head -1)
    echo "${cfg},${win},${pf:-NA},${tr:-NA}" >> "$OUT"
  done
done
echo DONE
