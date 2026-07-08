# ORDER-051 — optimize ZeusInspired on AUDJPY (its CONDITIONAL survivor) using the
# RSI-MR-proven method: sweep the ATR-spacing lever (_03_DistAtrMult, currently 2.2)
# across BOTH regimes at once (BWD 2020-22 + FWD 2025-26), lot8x baseline held.
# Coarse first; both-regime cells -> holdout 2023-24 -> MC. MT5 lane (Meta 5).
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$baseSet = "D:\EA_LAB\ea_projects\(Boss)_ZeusInspired_GridLog\set_files\ZeusInspired_AUDJPY_lot8x.set"
$baseLines = Get-Content $baseSet | Where-Object { $_ -notmatch '^_03_DistAtrMult=' }
$setdir = "D:\EA_LAB\_mt5_auto\ab_sets\zigl_sets"; New-Item -ItemType Directory -Force $setdir | Out-Null
$out = "D:\EA_LAB\_mt5_auto\ZIGL_ATR_OPT.csv"
'"atr","window","pf","dd_pct","trades"' | Out-File $out -Encoding utf8
$wins = @(@{w="BWD";f="2020.01.01";t="2023.01.01"}, @{w="FWD";f="2025.01.01";t="2026.07.01"})

foreach($atr in 1.0,1.5,2.2,3.0,4.0,5.0){
  $set = "$setdir\ZIGL_AUDJPY_atr$atr.set"
  ($baseLines + @("_03_DistAtrMult=$atr")) -join "`r`n" | Out-File $set -Encoding ascii
  foreach($win in $wins){
    $rep = "ZIGL_ATR${atr}_$($win.w)"
    & D:\EA_LAB\scripts\mt5_run.ps1 -Expert "(Boss)_ZeusInspired_GridLog_rev01" -Symbol AUDJPY -Period H1 -FromDate $win.f -ToDate $win.t -Model 4 -SetFile $set -ReportName $rep | Out-Null
    $htm = "D:\EA_LAB\_mt5_auto\reports\$rep.htm"
    if(Test-Path $htm){ $j = python D:\EA_LAB\scripts\parse_mt5_report.py $htm
      $pf=($j|Select-String 'profit_factor:\s*(.+)').Matches.Groups[1].Value.Trim()
      $dd=($j|Select-String 'equity_drawdown_maximal_pct:\s*(.+)').Matches.Groups[1].Value.Trim()
      $trd=($j|Select-String 'total_trades:\s*(.+)').Matches.Groups[1].Value.Trim()
      "$atr,`"$($win.w)`",$pf,$dd,$trd"|Add-Content $out }
    else { "$atr,`"$($win.w)`",,,NO_REPORT"|Add-Content $out }
  }
}
"ZIGL ATR OPT DONE"; Get-Content $out
