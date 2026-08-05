#!/usr/bin/env bash
cd /d/EA_LAB || exit 1
OUT="_mt5_auto/ORDER126_SL_ROUNDAVOID.csv"; echo "set,window,PF,Trades" > "$OUT"
declare -A W=( ["MAIN"]="2023.01.01 2025.12.31" ["BWD"]="2020.01.01 2022.12.31" )
for s in _mt5_auto/ab_sets/order126_sl/*.set; do
  b=$(basename "$s" .set)
  abs="D:/EA_LAB/${s}"      # forward-slash absolute path — PowerShell Test-Path resolves it (backslash mangling was the bug)
  for win in MAIN BWD; do
    read f t <<< "${W[$win]}"
    rep="O126_${b}_${win}"
    powershell -Command "Get-Process terminal64 -EA SilentlyContinue | Stop-Process -Force" >/dev/null 2>&1; sleep 2
    powershell -File scripts/mt5_run.ps1 -Expert "EmaStoRev126" -Symbol EURUSD -Period H1 -FromDate "$f" -ToDate "$t" -Model 1 -SetFile "$abs" -ReportName "$rep" -Force >/dev/null 2>&1
    htm="_mt5_auto/reports/${rep}.htm"
    pf=$(powershell -File scripts/parse_htm.ps1 -Path "$htm" 2>/dev/null | grep -iE "^PF" | grep -oE "[0-9.]+" | head -1)
    tr=$(powershell -File scripts/parse_htm.ps1 -Path "$htm" 2>/dev/null | grep -iE "Trades" | grep -oE "[0-9]+" | head -1)
    echo "${b},${win},${pf:-NA},${tr:-NA}" >> "$OUT"
  done
done
echo "DONE $(wc -l < "$OUT") rows"
