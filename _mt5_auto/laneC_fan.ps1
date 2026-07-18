# Lane C — SMC×STO (EmaStoRev) EURUSD H1 sensitivity fan, Model-4 both-window.
# center + 12 fan variants x 2 windows = 26 runs.
$ErrorActionPreference = "Stop"
$root="D:\EA_LAB"; $run="$root\scripts\mt5_run.ps1"; $setdir="$root\_mt5_auto\ab_sets\laneC_smcsto"
$sets = Get-ChildItem "$setdir\*.set" | ForEach-Object { $_.BaseName }
$windows = @(@{N="MAIN";F="2023.01.01";T="2025.12.31"},@{N="BWD";F="2020.01.01";T="2022.12.31"})
foreach ($s in $sets) { foreach ($w in $windows) {
  $rn = "SMCSTOfan_${s}_$($w.N)"
  Write-Host "=== $rn ==="
  try { & $run -Expert "EmaStoRev" -Symbol "EURUSD" -Period "H1" -FromDate $w.F -ToDate $w.T -SetFile "$setdir\$s.set" -Model 4 -ReportName $rn -Force }
  catch { Write-Host "FAIL $rn : $_" }
}}
Write-Host "ALL LANE-C FAN RUNS COMPLETE"
