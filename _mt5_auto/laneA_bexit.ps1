# Lane A last-optimize: JumStoch with faithful basket ATR-TP exit (Boss14 pattern) vs base fixed-TP.
# EURUSD only (best base home), 4 sets x 2 windows = 8 Model-4 runs.
$ErrorActionPreference = "Stop"
$root = "D:\EA_LAB"; $run = "$root\scripts\mt5_run.ps1"
$setdir = "$root\_mt5_auto\ab_sets\laneA_jumstoch"
$sets = @("JS18_bexit_faithful_BUY","JS18_bexit_faithful_SELL","JS18_bexit_rev_BUY","JS18_bexit_rev_SELL")
$windows = @(@{Name="MAIN";From="2023.01.01";To="2025.12.31"},@{Name="BWD";From="2020.01.01";To="2022.12.31"})
foreach ($s in $sets) { foreach ($w in $windows) {
  $rn = "JS18bex_$($s.Replace('JS18_bexit_',''))_EURUSD_$($w.Name)"
  Write-Host "=== RUN $rn ==="
  try { & $run -Expert "EALabTpl\Boss_18_JumStoch" -Symbol "EURUSD" -Period "H1" -FromDate $w.From -ToDate $w.To -SetFile "$setdir\$s.set" -Model 4 -ReportName $rn -Force }
  catch { Write-Host "FAIL $rn : $_" }
}}
Write-Host "ALL LANE-A BEXIT RUNS COMPLETE"
