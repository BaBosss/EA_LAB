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
    [Parameter(Mandatory)][int]$RunnerExit,
    [string]$Label = '',
    [switch]$AcceptLeverageMismatch,
    [switch]$Quiet
  )
  $tag = if ($Label) { $Label } else { Split-Path $Htm -Leaf }
  $why = Get-RunnerExitMeaning -RunnerExit $RunnerExit

  # WHITELIST, not blacklist. CORRECTED 2026-07-28 after a blind audit: this originally rejected
  # only exit 1 and 2, so an unrecognised code (4, 99, -1 - or a runner that never set one at all,
  # which is what mt4_run.ps1 did until the same audit) was ACCEPTED. $RunnerExit also defaulted to
  # 0, meaning a caller that simply forgot to pass it got a silent pass. Both are now impossible:
  # the parameter is mandatory, and only codes that are known to mean "a report was written by THIS
  # run" get through.
  if ($RunnerExit -ne 0 -and $RunnerExit -ne 3) {
    if (-not $Quiet) {
      Write-Host "   [STALE-GUARD] $tag - $why" -ForegroundColor Red
      Write-Host "                 any report on disk is from an EARLIER run and is ignored." -ForegroundColor Red
    }
    return $false
  }
  # Exit 3 means the report IS from this run but ran at the wrong leverage, so its numbers are not
  # comparable to anything. Previously this returned $true with only a warning, and five callers
  # then wrote those numbers into sweep CSVs and verdict scoring as ordinary results - which
  # contradicted this library's own text. It is now a REFUSAL unless the caller explicitly opts in.
  if ($RunnerExit -eq 3 -and -not $AcceptLeverageMismatch) {
    if (-not $Quiet) {
      Write-Host "   [STALE-GUARD] $tag - $why" -ForegroundColor Red
      Write-Host "                 pass -AcceptLeverageMismatch only if you intend to record a non-comparable number." -ForegroundColor Red
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
    # Only reachable via -AcceptLeverageMismatch; the caller asked for this number knowing it is
    # not comparable, so say so every time it is handed over.
    Write-Host "   [WARN] $tag - $why (accepted only because -AcceptLeverageMismatch was passed)" -ForegroundColor Yellow
  }
  return $true
}
