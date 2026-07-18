# Lane B — MacdDiv XAUUSD H4 Model-4 (real-tick) ×3 windows, serial (M4 lane-1 only).
# Windows chosen so 2026H1 holdout stays pristine vs the Model-1 selection windows.
$ErrorActionPreference = "Stop"
$root = "D:\EA_LAB"
$set  = "$root\_mt5_auto\ab_sets\order098b\MacdDiv_Naked_XAUUSD_H4_optPF.set"
$run  = "$root\scripts\mt5_run.ps1"

$windows = @(
  @{ Name="MAIN_2023_2025"; From="2023.01.01"; To="2025.12.31" },
  @{ Name="BWD_2020_2022";  From="2020.01.01"; To="2022.12.31" },
  @{ Name="HOLDOUT_2026H1"; From="2026.01.01"; To="2026.07.01" }
)

foreach ($w in $windows) {
  $rn = "MacdDiv_XAUH4_M4_$($w.Name)"
  Write-Host "=== RUN $rn ($($w.From)..$($w.To)) Model 4 ==="
  & $run -Expert "MacdDiv_Naked" -Symbol "XAUUSD" -Period "H4" `
         -FromDate $w.From -ToDate $w.To -SetFile $set -Model 4 `
         -ReportName $rn -Force
  Write-Host "=== DONE $rn ==="
}
Write-Host "ALL LANE-B M4 WINDOWS COMPLETE"
