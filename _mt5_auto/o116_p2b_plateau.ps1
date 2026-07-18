# ORDER-116 Phase 2b: US30 plateau cross (market-only, Bars x TP around 40/5), both-window Model-4.
$ErrorActionPreference = 'Stop'
$run='D:\EA_LAB\scripts\mt5_run.ps1'; $sets='D:\EA_LAB\_mt5_auto\ab_sets\order116'
$rep='D:\EA_LAB\_mt5_auto\reports'; $csv='D:\EA_LAB\_mt5_auto\O116_P2B_PLATEAU.csv'
$term='D:\Meta 5\terminal64.exe'
"config,window,pf,trades,net,eqDD_pct" | Out-File $csv -Encoding utf8
$cfgs = @('US30_b30_tp5','US30_b40_tp4','US30_b40_tp5','US30_b40_tp6','US30_b50_tp5')
$wins = @(@{w='REC';f='2023.01.01';t='2026.07.01'}, @{w='BWD';f='2020.01.01';t='2022.12.31'})
function P($f){ $t=([Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($f)))-replace"[\r\n]"," "
  $pf=if($t -match 'Profit Factor:</td>\s*<td[^>]*><b>([0-9.]+)'){$Matches[1]}else{'NA'}
  $tr=if($t -match 'Total Trades:</td>\s*<td[^>]*><b>([0-9]+)'){$Matches[1]}else{'NA'}
  $nt=if($t -match 'Total Net Profit:</td>\s*<td[^>]*><b>(-?[0-9 .]+)'){($Matches[1]-replace' ','')}else{'NA'}
  $dd=if($t -match 'Equity Drawdown Maximal:</td>\s*<td[^>]*><b>[0-9 .]+ \(([0-9.]+)%'){$Matches[1]}else{'NA'}; @($pf,$tr,$nt,$dd) }
foreach($c in $cfgs){ foreach($w in $wins){
  $name="O116P2B_${c}_$($w.w)"; Write-Output "=== $name ==="
  & $run -Expert 'c091c\(EXP)_BRK_SplitRetest' -Symbol US30 -Period H1 -FromDate $w.f -ToDate $w.t -Model 4 -Deposit 10000 -Leverage 100 -SetFile "$sets\$c.set" -ReportName $name -Terminal $term -TimeoutSec 900 | Out-Null
  $h="$rep\$name.htm"
  if(Test-Path $h){$v=P $h; "$c,$($w.w),$($v[0]),$($v[1]),$($v[2]),$($v[3])"|Add-Content $csv; Write-Output "  PF=$($v[0]) tr=$($v[1]) DD=$($v[3])%"}
  else{"$c,$($w.w),NA,NA,NA,NA"|Add-Content $csv; Write-Output "  NO REPORT"}
}}
Write-Output "=== O116 P2B plateau DONE ==="
