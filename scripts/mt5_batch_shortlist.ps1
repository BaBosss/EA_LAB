<#
mt5_batch_shortlist.ps1 — auto single-test (IS + OOS) for the robust-pass .set
shortlist, headless. Run with MT5 GUI CLOSED. Then score with run_pipeline.py.

Usage (after closing MT5):
  powershell -File D:\EA_LAB\scripts\mt5_batch_shortlist.ps1
  python D:\EA_LAB\scripts\run_pipeline.py D:\EA_LAB\ea_projects D:\EA_LAB\_mt5_auto\reports
#>
$ErrorActionPreference = "Stop"
$run  = "D:\EA_LAB\scripts\mt5_run.ps1"
$sets = "D:\EA_LAB\_shortlist_sets"
$IS  = @("2023.06.01", "2026.06.01")
$OOS = @("2021.01.01", "2023.06.01")

# EA names verified compiled in MQL5\Experts on 2026-06-14
$jobs = @(
  @{ set = "EURCAD_dynamic_robust_v1.set"; ea = "Boss - 2 Adaptive Smart Grid"; sym = "EURCAD"; code = "EURCAD" },
  @{ set = "AUDCAD_robust_v1.set";         ea = "Boss - 2 Adaptive Smart Grid"; sym = "AUDCAD"; code = "AUDCAD" },
  @{ set = "AUDNZD_robust_v1.set";         ea = "Boss - 2 Adaptive Smart Grid"; sym = "AUDNZD"; code = "AUDNZD" },
  @{ set = "GEP_NZDUSD_robust_v1.set";     ea = "Boss - 6 Pivot Range Trading"; sym = "NZDUSD"; code = "GEP" }
)

foreach ($j in $jobs) {
  & $run -Expert $j.ea -Symbol $j.sym -Period H1 -FromDate $IS[0]  -ToDate $IS[1]  -SetFile "$sets\$($j.set)" -ReportName "$($j.code)_IS"
  & $run -Expert $j.ea -Symbol $j.sym -Period H1 -FromDate $OOS[0] -ToDate $OOS[1] -SetFile "$sets\$($j.set)" -ReportName "$($j.code)_OOS"
}
Write-Output "`nAll jobs launched. Reports in D:\EA_LAB\_mt5_auto\reports"
Write-Output "Next: python D:\EA_LAB\scripts\run_pipeline.py D:\EA_LAB\ea_projects D:\EA_LAB\_mt5_auto\reports"
