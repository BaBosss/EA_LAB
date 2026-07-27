# =============================== HOLDOUT-BURNED ===============================
# ORDER-238 (2026-07-27). One or more test windows in this file end after
# 2025.12.31 -- that is, inside the 2026H1 holdout. They are deliberately LEFT
# AS-IS: they record what past runs actually did, and rewriting them would
# misrepresent that history.
#
# Therefore: do NOT re-run this script to produce selection evidence, and do NOT
# copy its window into new work. A holdout is spent the first time it is touched.
# The current MAIN window is pinned in the VERDICT GATE section of CLAUDE.md.
#
# THIS FILE: the date appears only in the usage EXAMPLE above the param block --
#   the real windows are mandatory parameters supplied by the caller. The example
#   is still the hazard, because the example is what people copy.
# ==============================================================================
<#
optimize_loop.ps1 — full clean-provenance loop in ONE command (token-efficient).
  optimize EA  ->  select robust pass  ->  gen .set  ->  single-test IS+OOS  ->  score
Everything on the SAME compiled EA, so provenance is clean (unlike the archive).
Run with MT5 CLOSED. Prints one concise result; details land in RUN_REGISTRY.md.

Example:
  & .\optimize_loop.ps1 -Expert "MQL5 EA\Boss - 2 Adaptive Smart Grid" -Symbol EURCAD `
     -BaseSet "C:\...\EURCAD.set" -Strategy grid -Code EURCADv2 `
     -OptFrom 2023.06.01 -OptTo 2026.06.01 -OosFrom 2021.01.01 -OosTo 2023.06.01
#>
param(
  [Parameter(Mandatory)][string]$Expert,
  [Parameter(Mandatory)][string]$Symbol,
  [string]$Period   = "H1",
  [int]$Model       = 1,
  [Parameter(Mandatory)][string]$BaseSet,
  [string]$Strategy = "default",
  [Parameter(Mandatory)][string]$Code,
  [Parameter(Mandatory)][string]$OptFrom,
  [Parameter(Mandatory)][string]$OptTo,
  [Parameter(Mandatory)][string]$OosFrom,
  [Parameter(Mandatory)][string]$OosTo
)
$ErrorActionPreference = "Stop"
$S = "D:\EA_LAB\scripts"
$xml = "D:\EA_LAB\_mt5_auto\optimizations\OPT_$Code.xml"
$rset = "D:\EA_LAB\_mt5_auto\$($Code)_robust.set"

Write-Output "[1/4] optimize $Expert $Symbol ($OptFrom..$OptTo)..."
& "$S\mt5_optimize.ps1" -Expert $Expert -Symbol $Symbol -Period $Period -SetFile $BaseSet -FromDate $OptFrom -ToDate $OptTo -ReportName "OPT_$Code" -TimeoutSec 2400
if (-not (Test-Path $xml)) { Write-Output "LOOP FAIL: no optimizer XML (headless opt->XML may not be supported on this build)"; exit 1 }

Write-Output "[2/4] select robust pass -> .set"
if (Test-Path $rset) { Remove-Item $rset -Force }
& python "$S\set_from_robust.py" $xml --base $BaseSet -o $rset --strategy $Strategy
if (-not (Test-Path $rset)) {
  Write-Output "LOOP STOP ($Code): no robust pass survived the gate (plateau NONE). Nothing to single-test."
  exit 1
}

Write-Output "[3/4] single-test IS ($OptFrom..$OptTo) + OOS ($OosFrom..$OosTo)"
& "$S\mt5_run.ps1" -Expert $Expert -Symbol $Symbol -Period $Period -Model $Model -FromDate $OptFrom -ToDate $OptTo -SetFile $rset -ReportName "$($Code)_loopIS"
& "$S\mt5_run.ps1" -Expert $Expert -Symbol $Symbol -Period $Period -Model $Model -FromDate $OosFrom -ToDate $OosTo -SetFile $rset -ReportName "$($Code)_loopOOS"

Write-Output "[4/4] score"
& python "$S\run_pipeline.py" "D:\EA_LAB\ea_projects" "D:\EA_LAB\_mt5_auto\reports" *> $null
& python "$S\_show_rows.py" "$($Code)_loop"
Write-Output "LOOP DONE ($Code). Full table: D:\EA_LAB\RUN_REGISTRY.md"
