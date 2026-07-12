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
  - can print arbitrary extra stdout text (-StdoutText) WHILE STILL EXITING 0 — this is
    what lets a test simulate mt4_run.ps1-style "NO REPORT but exit 0" false-green behavior
    to exercise run_batch.ps1's stdout-keyword failure scan
  - accepts (and ignores) a -Terminal value, purely so a test manifest can put a "-Terminal"
    flag in a job's args (to exercise run_batch.ps1's model==4 physical-lane check) without
    the invocation failing on an "unknown parameter" error
  - No process-termination call of any kind anywhere in this file.
#>
param(
  [Parameter(Mandatory)][string]$MarkerFile,
  [int]$ExitCode = 0,
  [string]$ExitCodeFile = "",
  [string]$JobId = "",
  [int]$SleepMs = 0,
  [string]$StdoutText = "",
  [string]$Terminal = ""   # accepted-but-unused: lets tests exercise run_batch's -Terminal parsing
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
if ($StdoutText) { Write-Output $StdoutText }

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
