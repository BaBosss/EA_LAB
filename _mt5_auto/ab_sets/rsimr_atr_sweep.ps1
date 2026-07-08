# ORDER-048 phase B — ATR-spacing sweep (the lever held fixed at 1.0 until now).
# User callout 2026-07-08: DistAtrMult range is 1-5, never tuned. Test it across
# BOTH regimes simultaneously (BWD 2020-22 + FWD 2025-26) EURUSD, with the best
# lot law (LOG 5). Looking for a spacing where BOTH windows clear PF>1 at DD<40%.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$setdir = "D:\EA_LAB\_mt5_auto\ab_sets\rsimr_atr"
New-Item -ItemType Directory -Force $setdir | Out-Null
$out = "D:\EA_LAB\_mt5_auto\RSIMR_ATR.csv"
'"atr","window","pf","net","dd_pct","trades"' | Out-File $out -Encoding utf8
$wins = @(@{w="BWD";f="2020.01.01";t="2023.01.01"}, @{w="FWD";f="2025.01.01";t="2026.07.01"})

foreach($atr in 0.5,1.0,1.5,2.0,3.0,5.0){
  $set = "$setdir\RSIMR_ATR$atr.set"
  @("_02_SlAtrMult=25.0","_02_SlMaxPips=600.0","_05_LotMode=3","_05_LogFactor=5.0","_03_DistAtrMult=$atr") -join "`r`n" | Out-File $set -Encoding ascii
  foreach($win in $wins){
    $rep = "RSIMR_ATR${atr}_$($win.w)"
    & D:\EA_LAB\scripts\mt5_run.ps1 -Expert "(Boss)_RSI_MR_GridLog_rev01" -Symbol EURUSD -Period H1 -FromDate $win.f -ToDate $win.t -Model 4 -SetFile $set -ReportName $rep | Out-Null
    $htm = "D:\EA_LAB\_mt5_auto\reports\$rep.htm"
    if(Test-Path $htm){ $j = python D:\EA_LAB\scripts\parse_mt5_report.py $htm
      $pf=($j|Select-String 'profit_factor:\s*(.+)').Matches.Groups[1].Value.Trim()
      $net=($j|Select-String 'net_profit:\s*(.+)').Matches.Groups[1].Value.Trim()
      $dd=($j|Select-String 'equity_drawdown_maximal_pct:\s*(.+)').Matches.Groups[1].Value.Trim()
      $trd=($j|Select-String 'total_trades:\s*(.+)').Matches.Groups[1].Value.Trim()
      "$atr,`"$($win.w)`",$pf,$net,$dd,$trd"|Add-Content $out }
    else { "$atr,`"$($win.w)`",,,,NO_REPORT"|Add-Content $out }
  }
}
"ATR SWEEP DONE"; Get-Content $out
