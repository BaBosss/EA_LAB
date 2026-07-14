#!/bin/bash
# ORDER-097 HexaGrid funnel follow-up: per-system flat-lot isolation.
# Combined-6-system flat-lot failed (PF 0.67 MAIN / 0.15 BWD). This isolates each system
# (S1..S6) alone, flat-lot (MaxLevels=1), both windows, to find if ANY single system has edge.
set -u
LAB=/d/EA_LAB
SETDIR="$LAB/_mt5_auto/ab_sets/hex_sets"
OUT="$LAB/_mt5_auto/order097_hex_persystem_results.csv"
mkdir -p "$SETDIR"
echo "system,window,PF,Net,Trades,DDpct,Win" > "$OUT"

runsys() { # $1 sysnum(1-6) $2 from $3 to $4 windowtag
  local setf="$SETDIR/hex_S${1}only.set"
  {
    echo "_G_MaxLevels=1"
    for n in 1 2 3 4 5 6; do
      if [ "$n" = "$1" ]; then echo "_S${n}_Enable=true"; else echo "_S${n}_Enable=false"; fi
    done
  } > "$setf"
  local rn="O097_HEX_S${1}only_${4}"
  powershell -NoProfile -File "$LAB/scripts/mt5_run.ps1" -Expert 'HEX_HexaGrid_rev01' -Symbol XAUUSD -Period H1 \
    -FromDate "$2" -ToDate "$3" -Model 1 -Deposit 10000 -Leverage 100 -SetFile "$(cygpath -w "$setf")" \
    -ReportName "$rn" -Portable -Terminal 'D:\Meta 5\terminal64.exe' -TimeoutSec 900 >/dev/null 2>&1
  local rep="D:\\Meta 5\\${rn}.htm"
  local v=$(powershell -NoProfile -File "$LAB/scripts/parse_htm.ps1" "$rep" 2>/dev/null \
    | awk -F':' '/PF/{p=$2}/Net/{n=$2}/Trades/{t=$2}/DDpct/{d=$2}/Win/{w=$2} END{gsub(/ /,"",p);gsub(/ /,"",n);gsub(/ /,"",t);gsub(/ /,"",d);gsub(/ /,"",w);print p","n","t","d","w}')
  echo "S${1},$4,$v" >> "$OUT"
}

for s in 1 2 3 4 5 6; do
  runsys "$s" 2023.01.01 2026.07.01 MAIN
  runsys "$s" 2020.01.01 2022.12.31 BWD
done
echo "HEX PER-SYSTEM DONE" >> "$OUT"
