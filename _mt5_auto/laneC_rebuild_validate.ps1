# Lane C rebuild validate: plateau center SL3.5/TP1.2 + ±20% SL/TP fan, both-window + holdout. Model-4.
# 5 sets x 3 windows = 15 runs.
$ErrorActionPreference = "Stop"
$root="D:\EA_LAB"; $run="$root\scripts\mt5_run.ps1"; $setdir="$root\_mt5_auto\ab_sets\laneC_rebuild"
$sets = @("reb_sl3.5_tp1.2","reb_sl2.8_tp1.2","reb_sl4.2_tp1.2","reb_sl3.5_tp0.96","reb_sl3.5_tp1.44")
$windows = @(
  @{N="MAIN";F="2023.01.01";T="2025.12.31"},
  @{N="BWD"; F="2020.01.01";T="2022.12.31"},
  @{N="HOLD";F="2026.01.01";T="2026.07.01"}
)
foreach ($s in $sets) { foreach ($w in $windows) {
  $rn = "REBV_${s}_$($w.N)"
  Write-Host "=== $rn ==="
  try { & $run -Expert "EmaStoRev" -Symbol "EURUSD" -Period "H1" -FromDate $w.F -ToDate $w.T -SetFile "$setdir\$s.set" -Model 4 -ReportName $rn -Force }
  catch { Write-Host "FAIL $rn : $_" }
}}
Write-Host "ALL LANE-C REBUILD VALIDATE RUNS COMPLETE"
