# mris_run.ps1 - MRIS one-shot orchestrator (ORDER-073 Phase-2 macro layer)
# classify (regime) -> exposure (join DEPLOYMENTS) -> brief (Thai whisper).
# Designed to slot into the daily chain next to news_calendar.ps1, or run on
# demand. Prints the brief path at the end. Non-fatal per-stage: a stage that
# throws is reported and the run continues so a partial brief still lands.
[CmdletBinding()]
param(
  [string]$Root = "D:\EA_LAB\scripts\mris",
  [switch]$Quiet
)
$ErrorActionPreference = "Stop"
$steps = @(
  @{ name="webfeed";  script="$Root\mris_web_feeder.ps1" },
  @{ name="classify"; script="$Root\mris_classify.ps1" },
  @{ name="exposure"; script="$Root\mris_exposure.ps1" },
  @{ name="brief";    script="$Root\mris_brief.ps1" }
)
$fail = 0
foreach ($s in $steps) {
  try {
    if (!$Quiet) { Write-Host "[mris] $($s.name) ..." }
    & $s.script | ForEach-Object { if (!$Quiet) { Write-Host "   $_" } }
  } catch {
    $fail++
    Write-Host "[mris] $($s.name) FAILED: $($_.Exception.Message)"
  }
}
$brief = "D:\EA_LAB\portfolio\mris\whisper_brief.md"
if (Test-Path $brief) { Write-Host "[mris] brief -> $brief" }
if ($fail -gt 0) { Write-Host "[mris] $fail stage(s) failed"; exit 1 }
Write-Host "[mris] done"
