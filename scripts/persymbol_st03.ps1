<#
persymbol_st03.ps1 — per-symbol optimize for the ST03 reversion harvester, with OOS discipline.

Sweeps the two symbol-sensitive params (OCO target InpTp3Pts + ladder spacing InpNearbyPip)
on each liquid mean-reverting major, over IS + held-out OOS + 2022 crisis windows, via the
robust gridsweep driver. Model 2 (open prices) for the fast scan; confirm survivors at M4 after.

  -Expert   EA_RUNNER_ST03B   (trend-gated) | EA_RUNNER_ST03 (plain) — set after trend-gate result
  -BaseSet  the base .set whose params (LotRepeat=2 etc.) the sweep starts from

Survivor rule (anti-overfit): keep a combo ONLY if min(IS_PF, OOS_PF) >= 1.2 AND crisis EqDD bounded.
3 symbols x 6 combos = 18 candidates -> expect false positives; the held-out OOS is the filter.
#>
param(
  # Default = PLAIN ST03 (gates don't help: trend/ADX gate was FALSIFIED — it lags and cuts the
  # good reversion trades; vol-gate only catches gap spikes). Find the raw per-symbol edge first.
  [string]$Expert  = "EA_RUNNER_ST03",
  [string]$BaseSet = "D:\EA_LAB\_mt5_auto\ST03_optimized_v2.set",
  [string[]]$Symbols = @("EURUSD","USDCAD","EURGBP"),
  [int]$Model = 2
)
$ErrorActionPreference = "Stop"
$grid    = "InpTp3Pts=30,50,80;InpNearbyPip=50,100"
$windows = "IS:2024.01.01:2024.06.01;OOS:2024.09.01:2025.01.01;CRISIS:2022.08.01:2022.11.01"
foreach($sym in $Symbols){
  Write-Output "########## PER-SYMBOL: $sym ($Expert) ##########"
  & "$PSScriptRoot\gridsweep_robust.ps1" `
      -BaseSet  $BaseSet `
      -Overrides $grid `
      -Windows   $windows `
      -OutCsv    "D:\EA_LAB\_mt5_auto\sweeps\ST03_persym_$sym.csv" `
      -Prefix    "PS_$sym" `
      -Expert    $Expert `
      -Symbol    $sym `
      -Model     $Model
}
Write-Output "########## PER-SYMBOL SWEEP DONE - rank each CSV by min IS/OOS PF >= 1.2 ##########"
