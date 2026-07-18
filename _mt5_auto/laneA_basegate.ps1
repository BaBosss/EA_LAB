# Lane A base-gate: JumStoch(18) 4 sets x 2 symbols x 2 windows = 16 Model-4 runs (grid/DCA => M4 mandatory, serial).
$ErrorActionPreference = "Stop"
$root = "D:\EA_LAB"
$run  = "$root\scripts\mt5_run.ps1"
$setdir = "$root\_mt5_auto\ab_sets\laneA_jumstoch"

$sets = @("JS18_base_faithful_BUY","JS18_base_faithful_SELL","JS18_base_rev_BUY","JS18_base_rev_SELL")
$symbols = @("EURUSD","AUDUSD")
$windows = @(
  @{ Name="MAIN"; From="2023.01.01"; To="2025.12.31" },
  @{ Name="BWD";  From="2020.01.01"; To="2022.12.31" }
)

foreach ($s in $sets) {
  foreach ($sym in $symbols) {
    foreach ($w in $windows) {
      $rn = "JS18_$($s.Replace('JS18_base_',''))_${sym}_$($w.Name)"
      Write-Host "=== RUN $rn ==="
      try {
        & $run -Expert "EALabTpl\Boss_18_JumStoch" -Symbol $sym -Period "H1" `
               -FromDate $w.From -ToDate $w.To -SetFile "$setdir\$s.set" -Model 4 `
               -ReportName $rn -Force
      } catch { Write-Host "FAIL $rn : $_" }
    }
  }
}
Write-Host "ALL LANE-A BASE-GATE RUNS COMPLETE"
