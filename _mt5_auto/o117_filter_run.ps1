# ORDER-117 Track B: bar-strength candle filter A/B on XAU H1 breakout Bars40/TP5 (market entry), both-window Model-4.
$ErrorActionPreference='Stop'
$run='D:\EA_LAB\scripts\mt5_run.ps1'; $sets='D:\EA_LAB\_mt5_auto\ab_sets\order117_filter'
$rep='D:\EA_LAB\_mt5_auto\reports'; $csv='D:\EA_LAB\_mt5_auto\O117_FILTER.csv'; $term='D:\Meta 5\terminal64.exe'
"filter,window,pf,trades,winpct,net,eqDD_pct" | Out-File $csv -Encoding utf8
$arms=@(@{n='nofilter';s='BRK40_nofilter.set'},@{n='barstr03';s='BRK40_barstr03.set'},@{n='barstr05';s='BRK40_barstr05.set'},@{n='barstr07';s='BRK40_barstr07.set'})
$wins=@(@{w='REC';f='2023.01.01';t='2026.07.01'},@{w='BWD';f='2020.01.01';t='2022.12.31'})
function P($f){ $t=([Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($f)))-replace"[\r\n]"," "
  $pf=if($t-match'Profit Factor:</td>\s*<td[^>]*><b>([0-9.]+)'){$Matches[1]}else{'NA'}
  $tr=if($t-match'Total Trades:</td>\s*<td[^>]*><b>([0-9]+)'){$Matches[1]}else{'NA'}
  $wp=if($t-match'Profit Trades \(% of total\):</td>\s*<td[^>]*><b>[0-9]+ \(([0-9.]+)%'){$Matches[1]}else{'NA'}
  $nt=if($t-match'Total Net Profit:</td>\s*<td[^>]*><b>(-?[0-9 .]+)'){($Matches[1]-replace' ','')}else{'NA'}
  $dd=if($t-match'Equity Drawdown Maximal:</td>\s*<td[^>]*><b>[0-9 .]+ \(([0-9.]+)%'){$Matches[1]}else{'NA'}; @($pf,$tr,$wp,$nt,$dd) }
foreach($a in $arms){foreach($w in $wins){
  $name="O117F_$($a.n)_XAU_H1_$($w.w)"; Write-Output "=== $name ==="
  & $run -Expert 'c091c\(EXP)_BRK_SplitRetest' -Symbol XAUUSD -Period H1 -FromDate $w.f -ToDate $w.t -Model 4 -Deposit 10000 -Leverage 100 -SetFile "$sets\$($a.s)" -ReportName $name -Terminal $term -TimeoutSec 900 | Out-Null
  $h="$rep\$name.htm"
  if(Test-Path $h){$v=P $h;"$($a.n),$($w.w),$($v[0]),$($v[1]),$($v[2]),$($v[3]),$($v[4])"|Add-Content $csv;Write-Output "  PF=$($v[0]) tr=$($v[1]) win%=$($v[2]) DD=$($v[4])"}
  else{"$($a.n),$($w.w),NA,NA,NA,NA,NA"|Add-Content $csv;Write-Output "  NO REPORT"}
}}
Write-Output "=== O117 FILTER DONE ==="
