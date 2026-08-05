<#
run_scheduler_tests.ps1 - ORDER-1080 (slice S9), wrapping the cage for the recoverable scheduler.

WHAT IT GUARDS. _triage\factory_os\scheduler.py is the whole decision surface of design 3.3's run
state machine: the monotonic transition validator, the resume planner, the idempotency gate and
the cross-lane refusal. Every one of it is PURE, so the suite drives it against a stub world and
costs milliseconds - while the thing it guards costs a tester lane and, on the recovery path, a
crash nobody re-creates on purpose.

WHAT THIS IS *NOT*. It does not run the scheduler. That needs the tester and lives in
scripts\scheduler_run.ps1. This suite proves the STATE MACHINE by enumeration: a kill at every
(action, phase) of the loop, crossed with two resume delays, with the invariants read off counters
the stub keeps - launches, peak concurrent workers, event-store appends - rather than off the
planner's own opinion of what it did.

MEASURED before registering, three times, per memory phantom-regression-from-two-single-samples:
0.08s / 0.08s / 0.08s. See the number in run_fast_cages.ps1's registration comment.

ASCII-only on purpose (Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI).
USAGE  powershell -NoProfile -File scripts\_test\run_scheduler_tests.ps1
#>
[CmdletBinding()]
param([string]$RepoRoot = '')

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }

$py = Join-Path $RepoRoot 'tools\python312\python.exe'
$suite = Join-Path $RepoRoot '_triage\factory_os\run_scheduler_tests.py'

if (-not (Test-Path -LiteralPath $py)) {
    Write-Host "[scheduler] FAIL: interpreter not found at $py" -ForegroundColor Red
    exit 2
}
if (-not (Test-Path -LiteralPath $suite)) {
    # A MISSING SUITE IS A TOOL FAILURE, NOT A PASS. Exit 2, not 0.
    Write-Host "[scheduler] FAIL: suite not found at $suite" -ForegroundColor Red
    exit 2
}

$out = & $py $suite 2>&1
$code = $LASTEXITCODE
$out | ForEach-Object { Write-Host $_ }

if ($code -ne 0) {
    Write-Host "[scheduler] the scheduler cage FAILED (exit $code)" -ForegroundColor Red
    exit 1
}
# Assert the COMPLETENESS half actually ran, and this is the same class of check the parity
# wrapper carries for the same reason. Every attack in the suite is meaningless if the kill matrix
# silently shrank: an early return, a scenario list edited down, or a roll-up that stopped
# demanding all nine transitions would leave a green run that proves less than yesterday's, and
# nothing in the exit code would say so.
$joined = ($out -join "`n")
if ($joined -notmatch 'the kill matrix is COMPLETE') {
    Write-Host "[scheduler] FAIL: the run never asserted the kill matrix was complete, so the resume claims rest on whatever subset happened to run" -ForegroundColor Red
    exit 1
}
if ($joined -notmatch 'all nine transitions killed on both sides') {
    Write-Host "[scheduler] FAIL: the roll-up did not confirm every design 3.3 transition was killed on both sides of its own append" -ForegroundColor Red
    exit 1
}
Write-Host '[scheduler] scheduler cage green, kill matrix complete over all nine transitions' -ForegroundColor Green
exit 0
