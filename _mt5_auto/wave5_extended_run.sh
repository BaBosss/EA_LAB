#!/bin/bash
# ORDER-082 Wave5 EXTENDED validation — run long, autonomous (~1hr), no conversation.
# Tomorrow's session: just `bash _mt5_auto/wave5_extended_run.sh` then read the CSV.
# Uses the fixed Boss_17_Wave5.ex5 already deployed at EALabTpl (redeploys fresh first).
# NEW CRITERIA (VERDICT GATE): both-regime pass (PF>=1.0 MAIN 2023-26 AND BWD 2020-22),
# plateau not spike (adjacent cells must also pass), naked single (MaxLevels=1).
set -u
LAB=/d/EA_LAB
SETDIR="$LAB/_mt5_auto/ab_sets/wave5_sets"
OUT="$LAB/_mt5_auto/wave5_extended_results.csv"
MCLOG="$LAB/_mt5_auto/wave5_extended_mc.log"
EXP='C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355\MQL5\Experts\EALabTpl'
mkdir -p "$SETDIR"
echo "symbol,tf,fib,mult,window,PF,Net,Trades,DDpct,Win" > "$OUT"
: > "$MCLOG"

# redeploy fresh ex5 (in case source recompiled)
powershell -NoProfile -Command "Remove-Item -Force '$EXP\\Boss_17_Wave5.ex5' -ErrorAction SilentlyContinue; Copy-Item -Force 'D:\\EA_LAB\\ea_template\\Boss_17_Wave5.ex5' '$EXP\\Boss_17_Wave5.ex5'" >/dev/null 2>&1

runcell() { # $1 sym $2 tf $3 from $4 to $5 fib $6 mult $7 reportname
  local setf="$SETDIR/ext_${1}_${2}_F${5}_M${6}.set"
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

# 1) FINER plateau grid around fib23.6 on XAU H1 (confirm plateau is real, not a single cell)
for fib in 20 23.6 27 30; do
  for mult in 0.5 0.618 0.75; do
    tag=$(echo "F${fib}_M${mult}" | tr -d '.')
    runcell XAUUSD H1 2023.01.01 2026.07.01 "$fib" "$mult" "EXT_XAU_${tag}_MAIN"
    runcell XAUUSD H1 2020.01.01 2022.12.31 "$fib" "$mult" "EXT_XAU_${tag}_BWD"
  done
done

# 2) GOLD-FAMILY cross-instrument at plateau center (XAG silver) - is the edge gold-class or XAU-only?
runcell XAGUSD H1 2023.01.01 2026.07.01 23.6 0.618 "EXT_XAG_MAIN"
runcell XAGUSD H1 2020.01.01 2022.12.31 23.6 0.618 "EXT_XAG_BWD"

# 3) Monte Carlo on the plateau-center XAU H1 reports (run via PowerShell so python resolves)
powershell -NoProfile -Command ". 'D:\\EA_LAB\\scripts\\use_python.ps1'; python 'D:\\EA_LAB\\scripts\\mt5_montecarlo.py' 'D:\\EA_LAB\\_mt5_auto\\reports\\EXT_XAU_F236_M0618_MAIN.htm' --deposit 10000 --iters 5000" >> "$MCLOG" 2>&1
powershell -NoProfile -Command ". 'D:\\EA_LAB\\scripts\\use_python.ps1'; python 'D:\\EA_LAB\\scripts\\mt5_montecarlo.py' 'D:\\EA_LAB\\_mt5_auto\\reports\\EXT_XAU_F236_M0618_BWD.htm' --deposit 10000 --iters 5000" >> "$MCLOG" 2>&1

echo "EXTENDED DONE" >> "$OUT"
