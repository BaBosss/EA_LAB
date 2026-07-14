#!/bin/bash
# ORDER-097 HexaGrid funnel — coarse Model-1 sweep per taskboard prescription:
# "sweep spacing x SL x system-count -> both-regime -> ถ้าโผล่ PF>1 ค่อย Model-4"
# Baseline (default, both windows): recent PF 0.97 / BWD PF 0.88, DD 57-65%, 9-12k trades (way overtrading).
# This batch: (A) widen spacing+SL coarse grid (screens for the overtrading fix)
#             (B) flat-lot entry-edge probe (_G_MaxLevels=1, doctrine 5 mandatory check:
#                 does the BASE entry have edge with escalation off, before blaming the grid math)
# Requires HEDGING account -- reuses the exact baseline invocation (Portable, D:\Meta 5 terminal).
set -u
LAB=/d/EA_LAB
SETDIR="$LAB/_mt5_auto/ab_sets/hex_sets"
OUT="$LAB/_mt5_auto/order097_hex_funnel_results.csv"
mkdir -p "$SETDIR"
echo "config,window,PF,Net,Trades,DDpct,Win" > "$OUT"

runcell() { # $1 tag $2 spacing $3 sl $4 maxlevels $5 from $6 to $7 windowtag
  local setf="$SETDIR/hex_${1}.set"
  cat > "$setf" <<EOF
_G_SpacingATRmult=${2}
_G_SL_ATRmult=${3}
_G_MaxLevels=${4}
EOF
  local rn="O097_HEX_${1}_${7}"
  powershell -NoProfile -File "$LAB/scripts/mt5_run.ps1" -Expert 'HEX_HexaGrid_rev01' -Symbol XAUUSD -Period H1 \
    -FromDate "$5" -ToDate "$6" -Model 1 -Deposit 10000 -Leverage 100 -SetFile "$(cygpath -w "$setf")" \
    -ReportName "$rn" -Portable -Terminal 'D:\Meta 5\terminal64.exe' -TimeoutSec 900 >/dev/null 2>&1
  local rep="D:\\Meta 5\\${rn}.htm"
  local v=$(powershell -NoProfile -File "$LAB/scripts/parse_htm.ps1" "$rep" 2>/dev/null \
    | awk -F':' '/PF/{p=$2}/Net/{n=$2}/Trades/{t=$2}/DDpct/{d=$2}/Win/{w=$2} END{gsub(/ /,"",p);gsub(/ /,"",n);gsub(/ /,"",t);gsub(/ /,"",d);gsub(/ /,"",w);print p","n","t","d","w}')
  echo "$1,$7,$v" >> "$OUT"
}

# (A) spacing x SL coarse grid, both windows (baseline spacing1.5/sl12/max10 already have baseline numbers on record)
for combo in "S3_SL20:3:20" "S5_SL20:5:20" "S3_SL30:3:30"; do
  tag="${combo%%:*}"; rest="${combo#*:}"; sp="${rest%%:*}"; sl="${rest#*:}"
  runcell "$tag" "$sp" "$sl" 10 2023.01.01 2026.07.01 MAIN
  runcell "$tag" "$sp" "$sl" 10 2020.01.01 2022.12.31 BWD
done

# (B) flat-lot entry-edge probe: MaxLevels=1 at baseline spacing/SL (doctrine 5 mandatory check)
runcell "FLATLOT_base" 1.5 12 1 2023.01.01 2026.07.01 MAIN
runcell "FLATLOT_base" 1.5 12 1 2020.01.01 2022.12.31 BWD

echo "HEX FUNNEL DONE" >> "$OUT"
