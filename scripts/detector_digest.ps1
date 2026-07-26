<#
detector_digest.ps1 - ORDER-219: make the detectors we already have get READ.

WHY THIS EXISTS
  On 2026-07-25 the evidence-integrity sweep (ORDER-218) found that this repo had been
  writing warnings nobody read. The truncated-run detector flagged the Boss_16 lot-mode
  cage on 24 Jul; the deploy bundle was assembled on 25 Jul with that flag sitting on disk
  the whole time. Nothing was broken - the detector worked, wrote its sidecar, and was
  simply never opened. A detector whose output has to be remembered is not a control.

  So this does not detect anything new. It collects what the existing detectors already
  wrote and puts the failures in front of whoever runs the daily chain, without anyone
  having to think to look.

WHAT IT READS  (every source is written by some other script; this one never re-derives)
  _mt5_auto\reports\*.truncation_check.json   <- mt5_run.ps1 / check_truncated_run.ps1
  _mt5_auto\reports\*.leverage_check.json     <- mt5_run.ps1 leverage assertion (ORDER-165)
  _mt5_auto\reports\stale_binaries_check.json <- check_stale_binaries.ps1 (ORDER-221)

WHAT IT REPORTS
  Only the bad ones: truncated=true, leverage status other than MATCH, stale/mismatched
  binaries. A digest that also lists the 533 clean runs is a digest nobody reads either -
  that is the same failure in a new costume.

  Each line carries the sidecar's own mtime, because "when was this flagged" is the
  question ORDER-218 turned on: the Boss_16 flag was a day old and invisible.

NOTE ON detail:""
  Sidecars written before 2026-07-26 all have an empty detail field. That was a stream bug,
  not a missing feature: check_truncated_run.ps1 prints its diagnosis with Write-Host, which
  goes to the information stream (6), and mt5_run.ps1 captured only 2>&1. Fixed in the same
  order. Old sidecars cannot be back-filled without re-running, so they are labelled instead
  of being quietly shown as reasonless.

USAGE
  powershell -File scripts\detector_digest.ps1
  powershell -File scripts\detector_digest.ps1 -SinceDays 7    # only recent flags
  powershell -File scripts\detector_digest.ps1 -Quiet          # exit code only
EXIT CODES
  0 = nothing flagged
  2 = at least one flagged item (advisory: callers in the daily chain must NOT treat this
      as a chain failure - it is a report, and a report that breaks the build gets muted)
#>
[CmdletBinding()]
param(
  [string]$Root = $(if($PSScriptRoot){ (Resolve-Path (Join-Path $PSScriptRoot '..')).Path } else { (Get-Location).Path }),
  [int]$SinceDays = 0,          # 0 = no time filter
  [switch]$Quiet,
  [switch]$Repair,              # write a recovered detail back into the old sidecar
  [switch]$HighOnly             # ignore the advisory-severity findings entirely
)
$ErrorActionPreference = 'Stop'

$reports = Join-Path $Root '_mt5_auto\reports'
$findings = @()
$scanned  = 0
$unreadable = @()

function Read-Sidecar($file) {
  try { return (Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop | ConvertFrom-Json) }
  catch { $script:unreadable += ("{0} ({1})" -f $file.Name, $_.Exception.Message); return $null }
}

# SEVERITY - the difference between "you must look at this before you use that number" and
# "for the record". A leverage line missing from a 0-trade report is normal debris; a run that
# the cage cut in half, or a binary older than its source, silently changes what a verdict
# means. Only the second kind is allowed to turn the daily chain red, because a chain that
# goes red every morning teaches everyone to stop reading it - which is the exact failure
# (ORDER-218) this whole order exists to fix.
function Add-Finding($kind,$name,$why,$when,$sev) {
  $script:findings += [PSCustomObject]@{ kind=$kind; name=$name; why=$why; when=$when; sev=$sev }
}

if (-not (Test-Path $reports)) {
  if (-not $Quiet) { Write-Host "[INFO] no reports directory at $reports - nothing to digest" -ForegroundColor Yellow }
  exit 0
}

$cutoff = $null
if ($SinceDays -gt 0) { $cutoff = (Get-Date).AddDays(-$SinceDays) }

# --- truncated runs -----------------------------------------------------------------
foreach ($f in @(Get-ChildItem -LiteralPath $reports -Filter '*.truncation_check.json' -File -ErrorAction SilentlyContinue)) {
  if ($cutoff -and $f.LastWriteTime -lt $cutoff) { continue }
  $scanned++
  $j = Read-Sidecar $f
  if ($null -eq $j) { continue }
  if ($j.truncated -eq $true) {
    $why = ''
    if (-not [string]::IsNullOrWhiteSpace($j.detail)) {
      $why = ($j.detail -replace '\s+', ' ')
    } else {
      # A pre-fix sidecar knows it was flagged but threw away why. The report .htm it was
      # computed from is still on disk, and the detector is deterministic - so recover the
      # reason rather than printing "no detail". A flag without a reason is exactly the
      # kind of warning that gets skipped, which is the whole complaint behind this order.
      $htm = Join-Path $reports ("{0}.htm" -f $j.report_name)
      if (Test-Path -LiteralPath $htm) {
        try {
          $out = & (Join-Path $PSScriptRoot 'check_truncated_run.ps1') -Report $htm 2>&1 6>&1 | Out-String
          $global:LASTEXITCODE = 0
          $why = "(recovered from the report) " + ($out.Trim() -replace '\s+', ' ')
          if ($Repair) {
            [PSCustomObject]@{ report_name=$j.report_name; truncated=$true; detail=$out.Trim() } |
              ConvertTo-Json | Set-Content -LiteralPath $f.FullName -Encoding utf8
          }
        } catch { $why = "TRUNCATED, and re-deriving the reason from $htm failed: $($_.Exception.Message)" }
      } else {
        $why = 'TRUNCATED, reason not recorded (sidecar predates the ORDER-219 stream fix) and the report .htm is gone - the reason is unrecoverable; re-run to get one'
      }
    }
    Add-Finding 'TRUNCATED-RUN' $j.report_name $why $f.LastWriteTime 'HIGH'
  }
}

# --- leverage assertion -------------------------------------------------------------
foreach ($f in @(Get-ChildItem -LiteralPath $reports -Filter '*.leverage_check.json' -File -ErrorAction SilentlyContinue)) {
  if ($cutoff -and $f.LastWriteTime -lt $cutoff) { continue }
  $scanned++
  $j = Read-Sidecar $f
  if ($null -eq $j) { continue }
  if ($j.status -eq 'MATCH') { continue }
  $why = ''; $sev = 'LOW'
  switch ($j.status) {
    'MISMATCH'         { $why = "asked for 1:$($j.requested_leverage) but the tester ran 1:$($j.actual_leverage) - these numbers are NOT comparable to 1:$($j.requested_leverage) runs"; $sev = 'HIGH' }
    'NOT_RECORDED'     { $why = "report shows leverage 1:0 - assertion skipped, so the margin context of this run is UNKNOWN (usually a 0-trade/degenerate report)" }
    'NO_LEVERAGE_LINE' { $why = "report has no Leverage line at all - assertion skipped, margin context UNKNOWN" }
    default            { $why = "leverage sidecar status '$($j.status)' is not one this digest knows - open it by hand"; $sev = 'HIGH' }
  }
  Add-Finding 'LEVERAGE' $j.report_name $why $f.LastWriteTime $sev
}

# --- stale compiled binaries (ORDER-221; absent until that script has run) -----------
$staleFile = Join-Path $reports 'stale_binaries_check.json'
if (Test-Path -LiteralPath $staleFile) {
  $sf = Get-Item -LiteralPath $staleFile
  if (-not ($cutoff -and $sf.LastWriteTime -lt $cutoff)) {
    $scanned++
    $j = Read-Sidecar $sf
    if ($null -ne $j) {
      foreach ($e in @($j)) {
        if ($e.status -and $e.status -ne 'OK') {
          $d = if ([string]::IsNullOrWhiteSpace($e.detail)) { "status $($e.status), no detail recorded" } else { $e.detail }
          $bsev = if ($e.status -eq 'NO_SOURCE') { 'LOW' } else { 'HIGH' }
          Add-Finding "BINARY-$($e.status)" $e.name $d $sf.LastWriteTime $bsev
        }
      }
    }
  }
}

# --- output --------------------------------------------------------------------------
if ($HighOnly) { $findings = @($findings | Where-Object { $_.sev -eq 'HIGH' }) }
$highCount = @($findings | Where-Object { $_.sev -eq 'HIGH' }).Count

# Quiet mode is what the daily chain calls, and it answers one question: is there anything
# here that must stop somebody from using a recent number? Advisory findings do not qualify.
if ($Quiet) { if ($highCount -gt 0) { exit 2 } else { exit 0 } }

Write-Host "=== detector digest ($scanned sidecar(s) scanned$(if($SinceDays -gt 0){", last $SinceDays day(s)"})) ===" -ForegroundColor Cyan

if ($unreadable.Count -gt 0) {
  Write-Host ("[WARN] {0} sidecar(s) could not be parsed: {1}" -f $unreadable.Count, ($unreadable -join '; ')) -ForegroundColor Yellow
}

if ($findings.Count -eq 0) {
  Write-Host "[OK] nothing flagged" -ForegroundColor Green
  exit 0
}

foreach ($grp in ($findings | Group-Object kind | Sort-Object Name)) {
  $gsev = if (@($grp.Group | Where-Object { $_.sev -eq 'HIGH' }).Count -gt 0) { 'Red' } else { 'DarkYellow' }
  Write-Host ""
  Write-Host ("-- {0} ({1})" -f $grp.Name, $grp.Count) -ForegroundColor $gsev
  foreach ($x in ($grp.Group | Sort-Object when -Descending)) {
    Write-Host ("   [{0}] {1}  [flagged {2:yyyy-MM-dd HH:mm}]" -f $x.sev, $x.name, $x.when) -ForegroundColor Yellow
    Write-Host ("     {0}" -f $x.why) -ForegroundColor Gray
  }
}
Write-Host ""
Write-Host ("=== {0} flagged ({1} HIGH, {2} advisory). None of these are new failures - they were already on disk. ===" -f `
  $findings.Count, $highCount, ($findings.Count - $highCount)) -ForegroundColor $(if ($highCount -gt 0) { 'Red' } else { 'DarkYellow' })
if ($highCount -gt 0) { exit 2 }
exit 0
