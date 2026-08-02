<#
run_setfile_tests.ps1 - ORDER-1020 (slice S7), wrapping the ratified old-.set policy cage.

WHAT IT GUARDS. The owner ratified on 2026-08-01 (design section 11 decision 4) that an unknown
or removed key in a .set is a REFUSAL THAT NAMES THE KEY, never a skipped line and never a
default substituted underneath, and that migration is a separate tool writing a NEW file with a
full report. _triage\factory_os\setfile.py implements that; this suite is what makes the policy
survive the next edit to it.

MEASURED before adding, because the ORDER-673 budget means a new cage DISPLACES something:
run_setfile_tests.py --mutate is 0.4s in the hook tier, measured on the commit that added it.
Almost all of that is one parse of the real Inputs.mqh to build the build-14 surface its cases
attack. Measured in-session per ORDER-673 N1, not carried over from this comment.

--mutate is passed HERE rather than left to a human, for the reason run_preset_tests.ps1 gives:
without it the suite proves the criteria are green; with it, each one is proven able to go RED for
its own reason.

ASCII-only on purpose (Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI).
USAGE  powershell -NoProfile -File scripts\_test\run_setfile_tests.ps1
#>
[CmdletBinding()]
param([string]$RepoRoot = '')

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }

$py = Join-Path $RepoRoot 'tools\python312\python.exe'
$suite = Join-Path $RepoRoot '_triage\factory_os\run_setfile_tests.py'

if (-not (Test-Path -LiteralPath $py)) {
    Write-Host "[setfile] FAIL: interpreter not found at $py" -ForegroundColor Red
    exit 2
}
if (-not (Test-Path -LiteralPath $suite)) {
    # A MISSING SUITE IS A TOOL FAILURE, NOT A PASS. Exit 2, not 0.
    Write-Host "[setfile] FAIL: suite not found at $suite" -ForegroundColor Red
    exit 2
}

$out = & $py $suite '--mutate' 2>&1
$code = $LASTEXITCODE
$out | ForEach-Object { Write-Host $_ }

if ($code -ne 0) {
    Write-Host "[setfile] the old-.set policy cage FAILED (exit $code)" -ForegroundColor Red
    exit 1
}
# Assert the mutation half actually ran. `--mutate` could be silently dropped by an edit to the
# suite's argument handling, and the criteria would still print green -- the suite passing while
# proving strictly less than its own name claims.
if (($out -join "`n") -notmatch 'mutation probes') {
    Write-Host "[setfile] FAIL: the run produced no mutation probes -- --mutate did not take effect, so no criterion was shown able to fail" -ForegroundColor Red
    exit 1
}
Write-Host '[setfile] old-.set policy cage green, mutation probes included' -ForegroundColor Green
exit 0
