#!/bin/bash
# ORDER-082 Wave5 — XAG silver mini-grid to confirm the XAG plateau is its own (not a single lucky cell).
# XAG @ plateau-center already passed both-window (MAIN 1.35 / BWD 1.29). This checks neighbors.
set -u
LAB=/d/EA_LAB
SETDIR="$LAB/_mt5_auto/ab_sets/wave5_sets"
OUT="$LAB/_mt5_auto/wave5_xag_minigrid_results.csv"
mkdir -p "$SETDIR"
echo "symbol,tf,fib,mult,window,PF,Net,Trades,DDpct,Win" > "$OUT"

runcell() { # $1 sym $2 tf $3 from $4 to $5 fib $6 mult $7 reportname
  local setf="$SETDIR/xag_${1}_F${5}_M${6}.set"
  cat > "$setf" <<EOF
ExitMode=23
_9_MaxLevels=1
_23_TrailStart=2000
_23_TrailStep=800
_17_UseStructLevels=true
_17_DivergTrail=true
_17_EntryFib=${5}
_17_Wave3MinMult=${6}
EOF
  powershell -NoProfile -File "$LAB/scripts/mt5_run.ps1" -Expert "EALabTpl\\Boss_17_Wave5" -Symbol "$1" -Period "$2" -FromDate "$3" -ToDate "$4" -Model 1 -SetFile "$(cygpath -w "$setf")" -ReportName "$7" -TimeoutSec 900 >/dev/null 2>&1
  local v=$(powershell -NoProfile -File "$LAB/scripts/parse_htm.ps1" "$LAB/_mt5_auto/reports/$7.htm" 2>/dev/null \
    | awk -F':' '/PF/{p=$2}/Net/{n=$2}/Trades/{t=$2}/DDpct/{d=$2}/Win/{w=$2} END{gsub(/ /,"",p);gsub(/ /,"",n);gsub(/ /,"",t);gsub(/ /,"",d);gsub(/ /,"",w);print p","n","t","d","w}')
  echo "$1,$2,$5,$6,$7X,$v" >> "$OUT"
}

for fib in 20 23.6 27; do
  for mult in 0.5 0.618; do
    tag=$(echo "F${fib}_M${mult}" | tr -d '.')
    runcell XAGUSD H1 2023.01.01 2026.07.01 "$fib" "$mult" "XAGMG_${tag}_MAIN"
    runcell XAGUSD H1 2020.01.01 2022.12.31 "$fib" "$mult" "XAGMG_${tag}_BWD"
  done
done
echo "XAG MINIGRID DONE" >> "$OUT"
