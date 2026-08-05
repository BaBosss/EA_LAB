#!/usr/bin/env bash
# Finish the RSI-momentum GBPUSD sweep (agent stopped early). Skip-existing, then parse to CSV.
cd /d/EA_LAB || exit 1
SETDIR="_mt5_auto/ab_sets/rsimom_gbp"
OUT="_mt5_auto/RSIMOM_GBP_SWEEPS.csv"
echo "set,tf,window,PF,Trades,Net,Win" > "$OUT"
declare -A W=( ["MAIN"]="2023.01.01 2025.12.31" ["BWD"]="2020.01.01 2022.12.31" )
for setf in "$SETDIR"/*.set; do
  s=$(basename "$setf" .set)
  for tf in H4 H1; do
    for win in MAIN BWD; do
      read f t <<< "${W[$win]}"
      rep="RSIMOMGBP_${s}_${tf}_${win}"
      htm="_mt5_auto/reports/${rep}.htm"
      if [ ! -f "$htm" ]; then
        powershell -File scripts/mt5_run.ps1 -Expert "RsiMomentum_Naked" -Symbol GBPUSD -Period "$tf" \
          -FromDate "$f" -ToDate "$t" -Model 1 -SetFile "D:\\EA_LAB\\_mt5_auto\\ab_sets\\rsimom_gbp\\${s}.set" \
          -ReportName "$rep" -Force >/dev/null 2>&1
      fi
      # parse
      if [ -f "$htm" ]; then
        pf=$(powershell -File scripts/parse_htm.ps1 -Path "$htm" 2>/dev/null | grep -iE "^PF" | grep -oE "[0-9.]+" | head -1)
        tr=$(powershell -File scripts/parse_htm.ps1 -Path "$htm" 2>/dev/null | grep -iE "Trades" | grep -oE "[0-9]+" | head -1)
        nt=$(powershell -File scripts/parse_htm.ps1 -Path "$htm" 2>/dev/null | grep -iE "^Net" | grep -oE "\-?[0-9.]+" | head -1)
        wn=$(powershell -File scripts/parse_htm.ps1 -Path "$htm" 2>/dev/null | grep -iE "Win" | grep -oE "[0-9.]+" | head -1)
        echo "${s},${tf},${win},${pf},${tr},${nt},${wn}" >> "$OUT"
      else
        echo "${s},${tf},${win},NO_REPORT,,," >> "$OUT"
      fi
    done
  done
done
echo "DONE rows=$(wc -l < "$OUT")"
