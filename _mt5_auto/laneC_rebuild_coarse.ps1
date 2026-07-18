# Lane C rebuild coarse: SMCxSTO SL×TP grid on MAIN only (zone-finding), Model-4. 20 runs.
$ErrorActionPreference = "Stop"
$root="D:\EA_LAB"; $run="$root\scripts\mt5_run.ps1"; $setdir="$root\_mt5_auto\ab_sets\laneC_rebuild"
$sets = Get-ChildItem "$setdir\*.set" | ForEach-Object { $_.BaseName }
foreach ($s in $sets) {
  $rn = "REB_${s}_MAIN"
  Write-Host "=== $rn ==="
  try { & $run -Expert "EmaStoRev" -Symbol "EURUSD" -Period "H1" -FromDate "2023.01.01" -ToDate "2025.12.31" -SetFile "$setdir\$s.set" -Model 4 -ReportName $rn -Force }
  catch { Write-Host "FAIL $rn : $_" }
}
Write-Host "ALL LANE-C REBUILD COARSE RUNS COMPLETE"
