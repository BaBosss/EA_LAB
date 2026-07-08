# ORDER-048 phase E — RSI-MR HOLDOUT on the reserved 2023-2024 window (NEVER used
# for selection; BWD 2020-22 and FWD 2025-26 were both selection windows). This is
# the honest first real test of the 4 coarse both-regime cells. ATR9 config. A cell
# that clears PF>1 at DD<25% HERE = validated across 3 independent windows.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$set = "D:\EA_LAB\_mt5_auto\ab_sets\rsimr_atr\RSIMR_ATRf_9.set"
$out = "D:\EA_LAB\_mt5_auto\RSIMR_HOLDOUT.csv"
'"symbol","tf","pf","dd_pct","trades"' | Out-File $out -Encoding utf8
$cells = @(@{s="EURUSD";t="H1"},@{s="EURUSD";t="M30"},@{s="AUDUSD";t="M30"},@{s="EURJPY";t="M30"})
foreach($c in $cells){
  $rep = "RSIMR_HO_$($c.s)_$($c.t)"
  & D:\EA_LAB\scripts\mt5_run.ps1 -Expert "(Boss)_RSI_MR_GridLog_rev01" -Symbol $c.s -Period $c.t -FromDate 2023.01.01 -ToDate 2025.01.01 -Model 4 -SetFile $set -ReportName $rep | Out-Null
  $htm = "D:\EA_LAB\_mt5_auto\reports\$rep.htm"
  if(Test-Path $htm){ $j = python D:\EA_LAB\scripts\parse_mt5_report.py $htm
    $pf=($j|Select-String 'profit_factor:\s*(.+)').Matches.Groups[1].Value.Trim()
    $dd=($j|Select-String 'equity_drawdown_maximal_pct:\s*(.+)').Matches.Groups[1].Value.Trim()
    $trd=($j|Select-String 'total_trades:\s*(.+)').Matches.Groups[1].Value.Trim()
    "`"$($c.s)`",`"$($c.t)`",$pf,$dd,$trd"|Add-Content $out }
  else { "`"$($c.s)`",`"$($c.t)`",,,NO_REPORT"|Add-Content $out }
}
"HOLDOUT DONE"; Get-Content $out
