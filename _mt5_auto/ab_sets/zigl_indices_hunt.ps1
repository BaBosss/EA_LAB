# ORDER-052 — new-EA hunt: extend the validated Zeus breakout-grid to other TRENDING
# instruments (indices + crypto), where breakout-momentum should shine (gold proved it).
# Coarse ATR scan both regimes, minimal-lot config (PF is lot-invariant). Cells clearing
# both regimes -> full funnel (holdout+MC+WFA) like the gold config.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$baseSet = "D:\EA_LAB\ea_projects\(Boss)_ZeusInspired_GridLog\set_files\ZeusInspired_AUDJPY_lot8x.set"
$strip = '^_03_DistAtrMult=|^_05_BaseLot=|^_06_MaxTotalLot=|^_02_SlMaxPips=|^_04_TpUsd='
$base = (Get-Content $baseSet | Where-Object { $_ -notmatch $strip }) + @("_05_BaseLot=0.01","_06_MaxTotalLot=0.10","_02_SlMaxPips=1000000.0","_04_TpUsd=5.0")
$setdir = "D:\EA_LAB\_mt5_auto\ab_sets\zigl_sets"
$out = "D:\EA_LAB\_mt5_auto\ZIGL_INDICES.csv"
'"symbol","atr","window","pf","dd_pct","trades"' | Out-File $out -Encoding utf8
$wins = @(@{w="BWD";f="2021.01.01";t="2023.01.01"}, @{w="FWD";f="2025.01.01";t="2026.07.01"})
foreach($sym in 'NAS100','SPX500','BTCUSD'){
  foreach($atr in 1.0,2.2){
    $set = "$setdir\ZIGL_${sym}_atr$atr.set"
    ($base + @("_03_DistAtrMult=$atr")) -join "`r`n" | Out-File $set -Encoding ascii
    foreach($win in $wins){
      $rep = "ZIGL_IDX_${sym}_${atr}_$($win.w)"
      & D:\EA_LAB\scripts\mt5_run.ps1 -Expert "(Boss)_ZeusInspired_GridLog_rev01" -Symbol $sym -Period H1 -FromDate $win.f -ToDate $win.t -Model 4 -SetFile $set -ReportName $rep | Out-Null
      $htm = "D:\EA_LAB\_mt5_auto\reports\$rep.htm"
      if(Test-Path $htm){ $j = python D:\EA_LAB\scripts\parse_mt5_report.py $htm
        $pf=($j|Select-String 'profit_factor:\s*(.+)').Matches.Groups[1].Value.Trim()
        $dd=($j|Select-String 'equity_drawdown_maximal_pct:\s*(.+)').Matches.Groups[1].Value.Trim()
        $trd=($j|Select-String 'total_trades:\s*(.+)').Matches.Groups[1].Value.Trim()
        "`"$sym`",$atr,`"$($win.w)`",$pf,$dd,$trd"|Add-Content $out }
      else { "`"$sym`",$atr,`"$($win.w)`",,,NO_REPORT"|Add-Content $out }
    }
  }
}
"INDICES DONE"; Get-Content $out
