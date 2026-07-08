# ORDER-051b — ZeusInspired on XAUUSD (its TRUE origin instrument), properly GOLD-rescaled.
# AUDJPY lot8x baseline but: BaseLot 0.01, MaxTotalLot 0.10 (gold $/point is large),
# SlMaxPips 10000 (points; so ATRx4 SL governs instead of being clipped at 150),
# TpUsd 5 (reachable at 0.01 gold lot). Sweep ATR both regimes. Gate: coarse->both-regime
# ->holdout->MC. PF is lot-invariant so the edge question is answered regardless of exact size.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$baseSet = "D:\EA_LAB\ea_projects\(Boss)_ZeusInspired_GridLog\set_files\ZeusInspired_AUDJPY_lot8x.set"
$strip = '^_03_DistAtrMult=|^_05_BaseLot=|^_06_MaxTotalLot=|^_02_SlMaxPips=|^_04_TpUsd='
$baseLines = Get-Content $baseSet | Where-Object { $_ -notmatch $strip }
$goldBase = $baseLines + @("_05_BaseLot=0.01","_06_MaxTotalLot=0.10","_02_SlMaxPips=10000.0","_04_TpUsd=5.0")
$setdir = "D:\EA_LAB\_mt5_auto\ab_sets\zigl_sets"
$out = "D:\EA_LAB\_mt5_auto\ZIGL_XAU.csv"
'"atr","window","pf","dd_pct","trades"' | Out-File $out -Encoding utf8
$wins = @(@{w="BWD";f="2020.01.01";t="2023.01.01"}, @{w="FWD";f="2025.01.01";t="2026.07.01"})
foreach($atr in 1.0,1.5,2.2,3.0,4.0){
  $set = "$setdir\ZIGL_XAU_atr$atr.set"
  ($goldBase + @("_03_DistAtrMult=$atr")) -join "`r`n" | Out-File $set -Encoding ascii
  foreach($win in $wins){
    $rep = "ZIGL_XAU${atr}_$($win.w)"
    & D:\EA_LAB\scripts\mt5_run.ps1 -Expert "(Boss)_ZeusInspired_GridLog_rev01" -Symbol XAUUSD -Period H1 -FromDate $win.f -ToDate $win.t -Model 4 -SetFile $set -ReportName $rep | Out-Null
    $htm = "D:\EA_LAB\_mt5_auto\reports\$rep.htm"
    if(Test-Path $htm){ $j = python D:\EA_LAB\scripts\parse_mt5_report.py $htm
      $pf=($j|Select-String 'profit_factor:\s*(.+)').Matches.Groups[1].Value.Trim()
      $dd=($j|Select-String 'equity_drawdown_maximal_pct:\s*(.+)').Matches.Groups[1].Value.Trim()
      $trd=($j|Select-String 'total_trades:\s*(.+)').Matches.Groups[1].Value.Trim()
      "$atr,`"$($win.w)`",$pf,$dd,$trd"|Add-Content $out }
    else { "$atr,`"$($win.w)`",,,NO_REPORT"|Add-Content $out }
  }
}
"XAU DONE"; Get-Content $out
