# ORDER-117 Track B: RSI-timing gate A/B on RAW MacdDiv base, XAU H4 (validated home), both-window Model-1.
$ErrorActionPreference='Stop'
$run='D:\EA_LAB\scripts\mt5_run.ps1'; $sets='D:\EA_LAB\_mt5_auto\ab_sets\order117_rsi'
$rep='D:\EA_LAB\_mt5_auto\reports'; $csv='D:\EA_LAB\_mt5_auto\O117_RSI.csv'; $term='D:\Meta 5\terminal64.exe'
"gate,window,pf,trades,winpct,net,eqDD_pct" | Out-File $csv -Encoding utf8
$arms=@(@{n='nofilter';s='MDRSI_nofilter.set'},@{n='g4555';s='MDRSI_gate4555.set'},@{n='g4060';s='MDRSI_gate4060.set'},@{n='g5050';s='MDRSI_gate5050.set'})
$wins=@(@{w='MAIN';f='2023.01.01';t='2026.07.01'},@{w='BWD';f='2020.01.01';t='2022.12.31'})
function P($f){ $t=([Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($f)))-replace"[\r\n]"," "
  $pf=if($t-match'Profit Factor:</td>\s*<td[^>]*><b>([0-9.]+)'){$Matches[1]}else{'NA'}
  $tr=if($t-match'Total Trades:</td>\s*<td[^>]*><b>([0-9]+)'){$Matches[1]}else{'NA'}
  $wp=if($t-match'Profit Trades \(% of total\):</td>\s*<td[^>]*><b>[0-9]+ \(([0-9.]+)%'){$Matches[1]}else{'NA'}
  $nt=if($t-match'Total Net Profit:</td>\s*<td[^>]*><b>(-?[0-9 .]+)'){($Matches[1]-replace' ','')}else{'NA'}
  $dd=if($t-match'Equity Drawdown Maximal:</td>\s*<td[^>]*><b>[0-9 .]+ \(([0-9.]+)%'){$Matches[1]}else{'NA'}; @($pf,$tr,$wp,$nt,$dd) }
foreach($a in $arms){foreach($w in $wins){
  $name="O117R_$($a.n)_XAU_H4_$($w.w)"; Write-Output "=== $name ==="
  & $run -Expert 'c091c\MacdDiv_Naked' -Symbol XAUUSD -Period H4 -FromDate $w.f -ToDate $w.t -Model 1 -Deposit 10000 -Leverage 100 -SetFile "$sets\$($a.s)" -ReportName $name -Terminal $term -TimeoutSec 700 | Out-Null
  $h="$rep\$name.htm"
  if(Test-Path $h){$v=P $h;"$($a.n),$($w.w),$($v[0]),$($v[1]),$($v[2]),$($v[3]),$($v[4])"|Add-Content $csv;Write-Output "  PF=$($v[0]) tr=$($v[1]) win%=$($v[2])"}
  else{"$($a.n),$($w.w),NA,NA,NA,NA,NA"|Add-Content $csv;Write-Output "  NO REPORT"}
}}
Write-Output "=== O117 RSI DONE ==="
