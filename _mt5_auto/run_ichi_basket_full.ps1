# ORDER-112B: full continuous 2020-2026 Model-4 passes for the 2 basket configs,
# so their deal lists can be merged into ONE equity curve (true combined DD + MC).
$ErrorActionPreference='Continue'; $root='D:\EA_LAB'
$setDir="$root\_mt5_auto\ab_sets\ichi_kumo"
$runs=@(
  @{rep='BASKET_medH4_FULL'; set='KUMO_med_H4.set';  tf='H4'},
  @{rep='BASKET_slowH1_FULL';set='KUMO_slow_H1.set'; tf='H1'}
)
foreach($r in $runs){ Write-Host ">> $($r.rep)"
  & "$root\scripts\mt5_run.ps1" -Expert '(EXP)_IchiADX_Naked_rev00' -Symbol USDJPY -Period $r.tf -FromDate '2020.01.01' -ToDate '2026.07.01' -Model 4 -ReportName $r.rep -SetFile (Join-Path $setDir $r.set) | Out-Null
  $h="$root\_mt5_auto\reports\$($r.rep).htm"; if(Test-Path $h){$o=& "$root\scripts\parse_htm.ps1" -Path $h 2>$null; Write-Host (($o|Out-String).Trim())} else {Write-Host "  [no report]"}
}
Write-Host "DONE"
