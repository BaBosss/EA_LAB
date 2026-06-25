<#
run_cb_symbols.ps1 — drive grid_sweep.ps1 over a list of symbols SEQUENTIALLY.
One background job holds MT5 (single-instance) for the whole list. No LLM in the loop
(self-contained — more reliable than a babysitting agent for pure sweeps).

Example:
  & .\run_cb_symbols.ps1 -Symbols GBPCAD,EURGBP,USDCAD
#>
param(
  [Parameter(Mandatory)][string]$Symbols,   # comma-separated, e.g. "GBPCAD,EURGBP,USDCAD" (split internally — -File can't pass arrays)
  [string]$Expert  = "(Boss)_LondonConsoBreakout_rev01",
  [string]$BaseSet = "D:\EA_LAB\_mt5_auto\CB_GBP_H1_IS_leader.set",
  [string]$Overrides = "_01_ConsoAtrMult=1.0,1.5,2.0;_02_TpAtrMult=2.0,3.0,4.0;_02_SlAtrMult=2.0,2.5",
  [string]$Windows = "IS:2023.01.01:2025.06.01;OOS2:2020.01.01:2022.12.31",
  [string]$StatusFile = "D:\EA_LAB\_mt5_auto\sweeps\CB_RUN_STATUS.txt"
)
$ErrorActionPreference = "Continue"
$symList = @($Symbols.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ })
"START $(Get-Date -Format s) symbols=$($symList -join '|')" | Set-Content $StatusFile
foreach ($sym in $symList) {
  "RUNNING $sym $(Get-Date -Format s)" | Add-Content $StatusFile
  & "D:\EA_LAB\scripts\grid_sweep.ps1" -Expert $Expert -Symbol $sym -Period H1 `
     -BaseSet $BaseSet -Overrides $Overrides -Windows $Windows `
     -OutCsv "D:\EA_LAB\_mt5_auto\sweeps\CB_$sym.csv" -ReportPrefix "CB_$sym"
  $csv = "D:\EA_LAB\_mt5_auto\sweeps\CB_$sym.csv"
  $rows = if (Test-Path $csv) { (Get-Content $csv | Measure-Object -Line).Lines - 1 } else { 0 }
  "DONE $sym rows=$rows $(Get-Date -Format s)" | Add-Content $StatusFile
}
"ALL DONE $(Get-Date -Format s)" | Add-Content $StatusFile
