<#
report_freshness.ps1 - one gate: "did THIS run produce this report?"

WHY THIS EXISTS (ORDER-372, 2026-07-28)
  mt5_run.ps1 clears a stale destination report before launching (the ORDER-094 D3 fix) so that a
  run producing nothing cannot leave old evidence lying around for the next reader. But that clear
  runs AFTER the two `exit 2` abort checks, so on the abort path the previous report survives
  untouched. That is deliberate - aborting must not delete files belonging to whichever lane is
  actually running - and it means:

      the existence of <ReportName>.htm is NOT evidence that this invocation created it.

  Demonstrated live: order215_matchagrid_cutloss_probe.ps1 pointed at a non-existent terminal
  aborted with exit 2 and then reported PF=1.77 parsed from a leftover report, as a fresh number.

  Six sweep scripts shared that inference. Three of them made it worse by falling back to
  "$DataDir\$rep.htm" - reading exactly the file the D3 clear is meant to remove.

WHAT COUNTS AS FRESH
  Both of these, not either:
    1. the runner's exit code says a report was produced   (0 ok / 3 leverage-mismatch-but-real)
       - 1 (no report) and 2 (abort) mean nothing was written, whatever is on disk
    2. the file's LastWriteTime is at or after the moment the caller started the run
       - Move-Item preserves the source timestamp, so a genuine report keeps the time MT5 wrote it,
         which is necessarily inside the run

DELIBERATELY INERT TOWARD THE CALLER
  No Set-StrictMode, no $ErrorActionPreference, no output on import. Dot-sourcing runs in the
  CALLER's scope, so anything set here changes the rules for the whole host script - a library that
  did that once already got an unrelated commit rejected by a guard it never touched.

USAGE
  . (Join-Path $PSScriptRoot 'lib\report_freshness.ps1')
  $runStart = Get-Date
  & "$PSScriptRoot\mt5_run.ps1" ... | Out-Null
  $code = $LASTEXITCODE
  if (Test-ReportIsFresh -Htm $htm -RunStart $runStart -RunnerExit $code -Label $rep) { ...parse... }
  else { ...record the failure; do NOT parse... }
#>

function Get-RunnerExitMeaning {
  param([int]$RunnerExit)
  switch ($RunnerExit) {
    0 { 'ok' }
    1 { 'runner exit 1 = NO REPORT (check EA name / symbol history / login)' }
    2 { 'runner exit 2 = ABORT (an MT5 instance for this install is already running, or the terminal path is wrong)' }
    3 { 'runner exit 3 = LEVERAGE MISMATCH (the report is real but its numbers are not comparable)' }
    default { "runner exit $RunnerExit = unrecognised" }
  }
}

function Test-ReportIsFresh {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Htm,
    [Parameter(Mandatory)][datetime]$RunStart,
    [int]$RunnerExit = 0,
    [string]$Label = '',
    [switch]$Quiet
  )
  $tag = if ($Label) { $Label } else { Split-Path $Htm -Leaf }
  $why = Get-RunnerExitMeaning -RunnerExit $RunnerExit

  if ($RunnerExit -eq 1 -or $RunnerExit -eq 2) {
    if (-not $Quiet) {
      Write-Host "   [STALE-GUARD] $tag - $why" -ForegroundColor Red
      Write-Host "                 any report on disk is from an EARLIER run and is ignored." -ForegroundColor Red
    }
    return $false
  }
  if (-not (Test-Path $Htm)) {
    if (-not $Quiet) { Write-Host "   [STALE-GUARD] $tag - no report at $Htm" -ForegroundColor Red }
    return $false
  }
  $mtime = (Get-Item $Htm).LastWriteTime
  if ($mtime -lt $RunStart) {
    if (-not $Quiet) {
      Write-Host ("   [STALE-GUARD] $tag - report written {0}, BEFORE this run started {1} - refusing to read it as fresh." -f $mtime, $RunStart) -ForegroundColor Red
    }
    return $false
  }
  if ($RunnerExit -eq 3 -and -not $Quiet) {
    Write-Host "   [WARN] $tag - $why" -ForegroundColor Yellow
  }
  return $true
}
