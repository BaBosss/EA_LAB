$ErrorActionPreference='Stop'; $root='D:\EA_LAB'; $ea='EALabTpl\Boss_14_GridLog'
$S=Join-Path $root 'ea_template\sets'
# subject GBPJPY d2.0/s4.0 (confirmed leg) + 7 demo legs, all Model-4 2023-2026
$jobs=@(
 @{tag='GJ';     sym='GBPJPY'; tf='H4'; set=(Join-Path $root '_mt5_auto\ab_sets\order106\GJ_d2.0_s4.0.set')},
 @{tag='USDJPY'; sym='USDJPY'; tf='H1'; set=(Join-Path $S 'Boss14_GridLog_USDJPY_DEMO.set')},
 @{tag='AUDNZD'; sym='AUDNZD'; tf='H1'; set=(Join-Path $S 'Boss14_GridLog_AUDNZD_DEMO.set')},
 @{tag='EURJPY'; sym='EURJPY'; tf='H1'; set=(Join-Path $S 'Boss14_GridLog_EURJPY_DEMO.set')},
 @{tag='AUDCAD'; sym='AUDCAD'; tf='H1'; set=(Join-Path $S 'Boss14_GridLog_AUDCAD_DEMO.set')},
 @{tag='CADJPY'; sym='CADJPY'; tf='H1'; set=(Join-Path $S 'Boss14_GridLog_CADJPY_DEMO.set')},
 @{tag='EURUSD'; sym='EURUSD'; tf='H1'; set=(Join-Path $S 'Boss14_GridLog_EURUSD_DEMO.set')},
 @{tag='XAU';    sym='XAUUSD'; tf='H1'; set=(Join-Path $S 'Boss14_GridLog_XAU_DEMO.set')}
)
foreach($j in $jobs){
 $rep="CORRGJ_$($j.tag)"; Write-Host ">> $rep ($($j.sym) $($j.tf))"
 if(-not(Test-Path $j.set)){ Write-Host "[FAIL] missing set: $($j.set)"; continue }
 & (Join-Path $root 'scripts\mt5_run.ps1') -Expert $ea -Symbol $j.sym -Period $j.tf -FromDate 2023.01.01 -ToDate 2026.07.01 -Model 4 -Deposit 10000 -Leverage 100 -ReportName $rep -SetFile $j.set | Out-Null
 $h=Join-Path $root "_mt5_auto\reports\$rep.htm"
 if(Test-Path $h){Write-Host "   ok"}else{Write-Host "   [no report]"}
}
Write-Host "DONE 8 runs"
