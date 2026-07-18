# ORDER-116 Phase 2: carry the locked split recipe (offset -0.15, buy-only) to other breakout symbols.
# market vs split, both-window Model-4 on D:\Meta 5. Parse -> CSV. Missing-data symbols -> NA (no gamble).
$ErrorActionPreference = 'Stop'
$run = 'D:\EA_LAB\scripts\mt5_run.ps1'
$sets = 'D:\EA_LAB\_mt5_auto\ab_sets\order116'
$rep = 'D:\EA_LAB\_mt5_auto\reports'
$csv = 'D:\EA_LAB\_mt5_auto\O116_P2.csv'
$term = 'D:\Meta 5\terminal64.exe'
"symbol,arm,window,pf,trades,net,eqDD_pct" | Out-File $csv -Encoding utf8
$symbols = @('US30','NAS100','XAGUSD','GBPUSD')
$arms = @(@{a='market'; set='BRK40_market.set'}, @{a='split'; set='BRK40_split_offm0p15.set'})
$wins = @(@{w='REC'; f='2023.01.01'; t='2026.07.01'}, @{w='BWD'; f='2020.01.01'; t='2022.12.31'})
function ParseHtm($f) {
  $txt = ([Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($f))) -replace "[\r\n]"," "
  $pf=if($txt -match 'Profit Factor:</td>\s*<td[^>]*><b>([0-9.]+)'){$Matches[1]}else{'NA'}
  $tr=if($txt -match 'Total Trades:</td>\s*<td[^>]*><b>([0-9]+)'){$Matches[1]}else{'NA'}
  $net=if($txt -match 'Total Net Profit:</td>\s*<td[^>]*><b>(-?[0-9 .]+)'){($Matches[1]-replace ' ','')}else{'NA'}
  $dd=if($txt -match 'Equity Drawdown Maximal:</td>\s*<td[^>]*><b>[0-9 .]+ \(([0-9.]+)%'){$Matches[1]}else{'NA'}
  @($pf,$tr,$net,$dd)
}
foreach ($sym in $symbols) { foreach ($arm in $arms) { foreach ($win in $wins) {
  $name = "O116P2_{0}_{1}_{2}_H1" -f $sym, $arm.a, $win.w
  Write-Output "=== $name ==="
  & $run -Expert 'c091c\(EXP)_BRK_SplitRetest' -Symbol $sym -Period H1 -FromDate $win.f -ToDate $win.t `
      -Model 4 -Deposit 10000 -Leverage 100 -SetFile "$sets\$($arm.set)" -ReportName $name -Terminal $term -TimeoutSec 900 | Out-Null
  $htm = "$rep\$name.htm"
  if (Test-Path $htm) { $v=ParseHtm $htm; "$sym,$($arm.a),$($win.w),$($v[0]),$($v[1]),$($v[2]),$($v[3])" | Add-Content $csv; Write-Output "  PF=$($v[0]) tr=$($v[1]) DD=$($v[3])%" }
  else { "$sym,$($arm.a),$($win.w),NA,NA,NA,NA" | Add-Content $csv; Write-Output "  NO REPORT (data?)" }
}}}
Write-Output "=== O116 P2 DONE -> $csv ==="
