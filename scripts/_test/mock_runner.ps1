<#
mock_runner.ps1 — ORDER-100 test fixture. Stands in for a real runner
(mt5_run.ps1 / mt4_run.ps1 / etc.) so scripts/_test/test_run_batch.ps1 can
exercise scripts/run_batch.ps1 WITHOUT ever touching real MT4/MT5.

Contract exercised by the tests:
  - echoes what it was asked to do (stdout)
  - writes/overwrites a marker file recording job id + invocation timestamp + exit code
    (a job run_batch.ps1 correctly skips as already-"done" must never re-invoke this
    script at all, so the marker's content/LastWriteTime must stay frozen across a resume)
  - exits with a code taken from a param (-ExitCode), optionally overridden at call time
    by the contents of -ExitCodeFile (a small text file the TEST can rewrite between two
    run_batch.ps1 invocations, to flip a job from "fails" to "succeeds" without editing
    the manifest — proves genuine resume-to-completion, not just "skip nothing changed")
  - No process-termination call of any kind anywhere in this file.
#>
param(
  [Parameter(Mandatory)][string]$MarkerFile,
  [int]$ExitCode = 0,
  [string]$ExitCodeFile = "",
  [string]$JobId = "",
  [int]$SleepMs = 0
)
$ErrorActionPreference = "Stop"

if ($SleepMs -gt 0) { Start-Sleep -Milliseconds $SleepMs }

$effectiveExit = $ExitCode
if ($ExitCodeFile -and (Test-Path $ExitCodeFile)) {
  $txt = (Get-Content $ExitCodeFile -Raw).Trim()
  if ($txt -match '^-?\d+$') { $effectiveExit = [int]$txt }
}

$ts = (Get-Date).ToString("o")
Write-Output "[mock_runner] job=$JobId exitcode=$effectiveExit invoked=$ts marker=$MarkerFile"

# Marker dir may not exist yet on first invocation in a fresh test case folder —
# -Force here is on a DIRECTORY create, not a process.
$markerDir = Split-Path -Parent $MarkerFile
if ($markerDir -and -not (Test-Path $markerDir)) {
  New-Item -ItemType Directory -Force $markerDir | Out-Null   # dir scaffold, not process-related
}

# Overwrite (not append): the file's content IS the proof of "when did this runner last
# actually execute" — a skipped/done job must show the ORIGINAL content unchanged.
"$JobId|$ts|$effectiveExit" | Set-Content -Path $MarkerFile -Encoding utf8

exit $effectiveExit
