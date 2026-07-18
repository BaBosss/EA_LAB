# ORDER-116 Phase 1: retest-param (offset) sweep on XAU H1 Bars40/TP5, split vs market,
# both-window Model-4 on D:\Meta 5 (non-portable). Parse -> CSV.
$ErrorActionPreference = 'Stop'
$run = 'D:\EA_LAB\scripts\mt5_run.ps1'
$sets = 'D:\EA_LAB\_mt5_auto\ab_sets\order116'
$rep = 'D:\EA_LAB\_mt5_auto\reports'
$csv = 'D:\EA_LAB\_mt5_auto\O116_P1.csv'
$term = 'D:\Meta 5\terminal64.exe'
"arm,offset,window,pf,trades,net,eqDD_pct" | Out-File $csv -Encoding utf8
$arms = @(
  @{a='market'; set='BRK40_market.set';        off='na'},
  @{a='split';  set='BRK40_split_offm0p3.set'; off='-0.30'},
  @{a='split';  set='BRK40_split_offm0p15.set';off='-0.15'},
  @{a='split';  set='BRK40_split_off0p0.set';  off='0.00'},
  @{a='split';  set='BRK40_split_off0p15.set'; off='+0.15'}
)
$wins = @(@{w='REC'; f='2023.01.01'; t='2026.07.01'}, @{w='BWD'; f='2020.01.01'; t='2022.12.31'})
function ParseHtm($f) {
  $txt = ([Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($f))) -replace "[\r\n]"," "
  $pf=if($txt -match 'Profit Factor:</td>\s*<td[^>]*><b>([0-9.]+)'){$Matches[1]}else{'NA'}
  $tr=if($txt -match 'Total Trades:</td>\s*<td[^>]*><b>([0-9]+)'){$Matches[1]}else{'NA'}
  $net=if($txt -match 'Total Net Profit:</td>\s*<td[^>]*><b>(-?[0-9 .]+)'){($Matches[1]-replace ' ','')}else{'NA'}
  $dd=if($txt -match 'Equity Drawdown Maximal:</td>\s*<td[^>]*><b>[0-9 .]+ \(([0-9.]+)%'){$Matches[1]}else{'NA'}
  @($pf,$tr,$net,$dd)
}
foreach ($arm in $arms) { foreach ($win in $wins) {
  $offtag = ($arm.off -replace '[.+]','' -replace '-','m')
  $name = "O116_{0}_{1}_XAU_H1_{2}" -f $arm.a, $offtag, $win.w
  Write-Output "=== $name ($($arm.off)) ==="
  & $run -Expert 'c091c\(EXP)_BRK_SplitRetest' -Symbol XAUUSD -Period H1 -FromDate $win.f -ToDate $win.t `
      -Model 4 -Deposit 10000 -Leverage 100 -SetFile "$sets\$($arm.set)" -ReportName $name -Terminal $term -TimeoutSec 900 | Out-Null
  $htm = "$rep\$name.htm"
  if (Test-Path $htm) { $v=ParseHtm $htm; "$($arm.a),$($arm.off),$($win.w),$($v[0]),$($v[1]),$($v[2]),$($v[3])" | Add-Content $csv; Write-Output "  PF=$($v[0]) tr=$($v[1]) DD=$($v[3])%" }
  else { "$($arm.a),$($arm.off),$($win.w),NA,NA,NA,NA" | Add-Content $csv; Write-Output "  NO REPORT" }
}}
Write-Output "=== O116 P1 DONE -> $csv ==="
