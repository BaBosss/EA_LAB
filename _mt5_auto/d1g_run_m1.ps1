# ORDER-091C-D1g Model-1 A/B matrix via proven mt5_run, parse -> CSV.
$ErrorActionPreference = 'Stop'
$run = 'D:\EA_LAB\scripts\mt5_run.ps1'
$sets = 'D:\EA_LAB\_mt5_auto\ab_sets\jumstoch_d1g'
$rep = 'D:\EA_LAB\_mt5_auto\reports'
$csv = 'D:\EA_LAB\_mt5_auto\D1G_AB_M1.csv'
$term='D:\Meta 5b\terminal64.exe'; $dd='D:\Meta 5b'
"cell,symbol,period,arm,window,pf,trades,net,eqDD_pct" | Out-File $csv -Encoding utf8
$matrix = @(
  @{s='EURGBP';p='H1';arm='MKT'; set='D1G_market_cage.set'; w='REC'; f='2023.01.01'; t='2026.07.01'},
  @{s='EURGBP';p='H1';arm='MKT'; set='D1G_market_cage.set'; w='BWD'; f='2020.01.01'; t='2022.12.31'},
  @{s='EURGBP';p='H1';arm='PEND';set='D1G_pending.set';     w='REC'; f='2023.01.01'; t='2026.07.01'},
  @{s='EURGBP';p='H1';arm='PEND';set='D1G_pending.set';     w='BWD'; f='2020.01.01'; t='2022.12.31'},
  @{s='NZDUSD';p='H4';arm='MKT'; set='D1G_market_cage.set'; w='REC'; f='2023.01.01'; t='2026.07.01'},
  @{s='NZDUSD';p='H4';arm='MKT'; set='D1G_market_cage.set'; w='BWD'; f='2020.01.01'; t='2022.12.31'},
  @{s='NZDUSD';p='H4';arm='PEND';set='D1G_pending.set';     w='REC'; f='2023.01.01'; t='2026.07.01'},
  @{s='NZDUSD';p='H4';arm='PEND';set='D1G_pending.set';     w='BWD'; f='2020.01.01'; t='2022.12.31'}
)
function ParseHtm($f) {
  $raw=[IO.File]::ReadAllBytes($f); $txt=[Text.Encoding]::Unicode.GetString($raw) -replace "[\r\n]"," "
  $pf=if($txt -match 'Profit Factor:</td>\s*<td[^>]*><b>([0-9.]+)'){$Matches[1]}else{''}
  $tr=if($txt -match 'Total Trades:</td>\s*<td[^>]*><b>([0-9]+)'){$Matches[1]}else{''}
  $net=if($txt -match 'Total Net Profit:</td>\s*<td[^>]*><b>(-?[0-9 .]+)'){($Matches[1] -replace ' ','')}else{''}
  $dd=if($txt -match 'Equity Drawdown Maximal:</td>\s*<td[^>]*><b>[0-9 .]+ \(([0-9.]+)%'){$Matches[1]}else{''}
  return @($pf,$tr,$net,$dd)
}
foreach ($m in $matrix) {
  $name = "D1G_{0}_{1}_{2}_{3}_M1" -f $m.arm,$m.s,$m.p,$m.w
  Write-Output "=== $name ==="
  & $run -Expert 'c091c\(EXP)_JUMSTOCH_Pending' -Symbol $m.s -Period $m.p -FromDate $m.f -ToDate $m.t `
      -Model 1 -Deposit 10000 -Leverage 100 -SetFile "$sets\$($m.set)" -ReportName $name `
      -Terminal $term -DataDir $dd -Portable -TimeoutSec 900 | Out-Null
  $htm = "$rep\$name.htm"
  if (Test-Path $htm) { $v=ParseHtm $htm; "$name,$($m.s),$($m.p),$($m.arm),$($m.w),$($v[0]),$($v[1]),$($v[2]),$($v[3])" | Add-Content $csv; Write-Output "  $name PF=$($v[0]) tr=$($v[1]) net=$($v[2]) dd=$($v[3])%" }
  else { "$name,$($m.s),$($m.p),$($m.arm),$($m.w),NA,NA,NA,NA" | Add-Content $csv; Write-Output "  $name NO REPORT" }
}
Write-Output "=== D1G M1 matrix DONE -> $csv ==="
