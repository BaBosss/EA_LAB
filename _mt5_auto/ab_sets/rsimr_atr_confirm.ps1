# ORDER-048 phase B2 — confirm the ATR 3-5 both-regime plateau is real (not a spike)
# and test whether wide spacing lets the design TRAVEL across symbols.
#   1. EURUSD ATR 4/6/8 x both windows  -> plateau shape around the ATR5 winner
#   2. ATR 5.0 on AUDUSD/GBPUSD/USDJPY x both windows -> travel test
# LOG 5 lot, wide SL throughout.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$setdir = "D:\EA_LAB\_mt5_auto\ab_sets\rsimr_atr"
$out = "D:\EA_LAB\_mt5_auto\RSIMR_ATR_CONFIRM.csv"
'"symbol","atr","window","pf","net","dd_pct","trades"' | Out-File $out -Encoding utf8
$wins = @(@{w="BWD";f="2020.01.01";t="2023.01.01"}, @{w="FWD";f="2025.01.01";t="2026.07.01"})

function Run($sym,$atr){
  $set = "$setdir\RSIMR_ATRc_${sym}_$atr.set"
  @("_02_SlAtrMult=25.0","_02_SlMaxPips=600.0","_05_LotMode=3","_05_LogFactor=5.0","_03_DistAtrMult=$atr") -join "`r`n" | Out-File $set -Encoding ascii
  foreach($win in $wins){
    $rep = "RSIMR_ATRc_${sym}_${atr}_$($win.w)"
    & D:\EA_LAB\scripts\mt5_run.ps1 -Expert "(Boss)_RSI_MR_GridLog_rev01" -Symbol $sym -Period H1 -FromDate $win.f -ToDate $win.t -Model 4 -SetFile $set -ReportName $rep | Out-Null
    $htm = "D:\EA_LAB\_mt5_auto\reports\$rep.htm"
    if(Test-Path $htm){ $j = python D:\EA_LAB\scripts\parse_mt5_report.py $htm
      $pf=($j|Select-String 'profit_factor:\s*(.+)').Matches.Groups[1].Value.Trim()
      $net=($j|Select-String 'net_profit:\s*(.+)').Matches.Groups[1].Value.Trim()
      $dd=($j|Select-String 'equity_drawdown_maximal_pct:\s*(.+)').Matches.Groups[1].Value.Trim()
      $trd=($j|Select-String 'total_trades:\s*(.+)').Matches.Groups[1].Value.Trim()
      "`"$sym`",$atr,`"$($win.w)`",$pf,$net,$dd,$trd"|Add-Content $out }
    else { "`"$sym`",$atr,`"$($win.w)`",,,,NO_REPORT"|Add-Content $out }
  }
}

foreach($atr in 4.0,6.0,8.0){ Run 'EURUSD' $atr }         # plateau shape
foreach($sym in 'AUDUSD','GBPUSD','USDJPY'){ Run $sym 5.0 } # travel at ATR5
"ATR CONFIRM DONE"; Get-Content $out
