# ORDER-048 phase A — RSI-MR lot-law sweep on the DISCRIMINATING window
# (BWD 2020-22 EURUSD, where LOG factor 1.3/2.7 lost). All runs wide SL.
# Goal: find which lot law recovers PF>1 in the trend years. User direction
# 2026-07-08: test LINEAR (add), LOG range 2-20, MARTINGALE, FIXED — "ทำให้ครบ".
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$setdir = "D:\EA_LAB\_mt5_auto\ab_sets\rsimr_sweep"
New-Item -ItemType Directory -Force $setdir | Out-Null
$out = "D:\EA_LAB\_mt5_auto\RSIMR_LOTLAW.csv"
'"tag","lotmode","param","pf","net","dd_pct","trades"' | Out-File $out -Encoding utf8

# combos: tag | LotMode(0=FIX 1=LIN 2=MART 3=LOG) | extra .set lines
$combos = @(
  @{tag="FIXED";       mode=0; extra=@()},
  @{tag="LIN_0.01";    mode=1; extra=@("_05_LinearStep=0.01")},
  @{tag="LIN_0.02";    mode=1; extra=@("_05_LinearStep=0.02")},
  @{tag="LIN_0.03";    mode=1; extra=@("_05_LinearStep=0.03")},
  @{tag="MART_1.3";    mode=2; extra=@("_05_MartMult=1.3")},
  @{tag="MART_1.5";    mode=2; extra=@("_05_MartMult=1.5")},
  @{tag="LOG_2";       mode=3; extra=@("_05_LogFactor=2.0")},
  @{tag="LOG_5";       mode=3; extra=@("_05_LogFactor=5.0")},
  @{tag="LOG_10";      mode=3; extra=@("_05_LogFactor=10.0")},
  @{tag="LOG_20";      mode=3; extra=@("_05_LogFactor=20.0")}
)

foreach($c in $combos){
  $set = "$setdir\RSIMR_$($c.tag).set"
  $lines = @("_02_SlAtrMult=25.0","_02_SlMaxPips=600.0","_05_LotMode=$($c.mode)") + $c.extra
  ($lines -join "`r`n") | Out-File $set -Encoding ascii
  $rep = "RSIMR_SW_$($c.tag)"
  Write-Output "[$(Get-Date -Format s)] $($c.tag)"
  & D:\EA_LAB\scripts\mt5_run.ps1 -Expert "(Boss)_RSI_MR_GridLog_rev01" -Symbol EURUSD -Period H1 `
      -FromDate 2020.01.01 -ToDate 2023.01.01 -Model 4 -SetFile $set -ReportName $rep | Out-Null
  $htm = "D:\EA_LAB\_mt5_auto\reports\$rep.htm"
  if(Test-Path $htm){
    $j = python D:\EA_LAB\scripts\parse_mt5_report.py $htm
    $pf  = ($j | Select-String 'profit_factor:\s*(.+)').Matches.Groups[1].Value.Trim()
    $net = ($j | Select-String 'net_profit:\s*(.+)').Matches.Groups[1].Value.Trim()
    $dd  = ($j | Select-String 'equity_drawdown_maximal_pct:\s*(.+)').Matches.Groups[1].Value.Trim()
    $trd = ($j | Select-String 'total_trades:\s*(.+)').Matches.Groups[1].Value.Trim()
    "`"$($c.tag)`",$($c.mode),`"$($c.extra -join ';')`",$pf,$net,$dd,$trd" | Add-Content $out
  } else {
    "`"$($c.tag)`",$($c.mode),`"$($c.extra -join ';')`",,,,NO_REPORT" | Add-Content $out
  }
}
Write-Output "SWEEP DONE -> $out"
