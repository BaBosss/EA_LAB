<#
run_parity_tests.ps1 - ORDER-1021 (slice S8), wrapping the cage for the 7-point parity comparator.

WHAT IT GUARDS. _triage\factory_os\parity.py judges design 5.5's Parent-Variant parity contract.
The comparator is PURE, so every case in the suite is a synthetic artifact pair built in memory -
which is why this costs milliseconds while the thing it guards costs two tester runs per case.

WHAT THIS IS *NOT*. It does not run parity. Parity needs the tester and lives in
scripts\parity_run.ps1, alongside tpl_regression on the same lane pin (design 5.5: same trigger,
same pin, same runner). This suite proves the JUDGE can reach every verdict it is supposed to -
including the two verdicts that matter most and are the easiest to lose:

  * two runs that both opened NOTHING must come back UNTESTED, never AGREE. An empty list is the
    easiest way to match, and rev 1 of design 5.5 was satisfied by exactly that.
  * a must-trade case that traded nothing must FAIL even when all seven points agree.

MEASURED before adding, per ORDER-673: see the number in run_fast_cages.ps1's registration comment.
The full tier had 1.1s of headroom when this was added (ORDER-820 is open on that number), so the
measurement was taken before the suite was registered and not after.

ASCII-only on purpose (Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI).
USAGE  powershell -NoProfile -File scripts\_test\run_parity_tests.ps1
#>
[CmdletBinding()]
param([string]$RepoRoot = '')

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }

$py = Join-Path $RepoRoot 'tools\python312\python.exe'
$suite = Join-Path $RepoRoot '_triage\factory_os\run_parity_tests.py'

if (-not (Test-Path -LiteralPath $py)) {
    Write-Host "[parity] FAIL: interpreter not found at $py" -ForegroundColor Red
    exit 2
}
if (-not (Test-Path -LiteralPath $suite)) {
    # A MISSING SUITE IS A TOOL FAILURE, NOT A PASS. Exit 2, not 0.
    Write-Host "[parity] FAIL: suite not found at $suite" -ForegroundColor Red
    exit 2
}

$out = & $py $suite 2>&1
$code = $LASTEXITCODE
$out | ForEach-Object { Write-Host $_ }

if ($code -ne 0) {
    Write-Host "[parity] the parity comparator cage FAILED (exit $code)" -ForegroundColor Red
    exit 1
}
# Assert the SPECIFICITY half actually ran. Every attack in the suite is meaningless unless an
# IDENTICAL pair was also compared and came back agreeing - a comparator that returned DIFFER
# unconditionally would pass every attack while being useless, and that line is the one an edit to
# the suite's early-exit could silently remove.
if (($out -join "`n") -notmatch 'an identical pair agrees on every observable point') {
    Write-Host "[parity] FAIL: the run never asserted an identical pair still agrees, so no attack in it proves anything" -ForegroundColor Red
    exit 1
}
Write-Host '[parity] parity comparator cage green, identical pair asserted agreeing' -ForegroundColor Green
exit 0
