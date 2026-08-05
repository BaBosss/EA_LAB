<#
run_preset_tests.ps1 - ORDER-702, wrapping ORDER-700's preset-compiler cage.

WHY A WRAPPER EXISTS AT ALL, and it is not ceremony. _triage\factory_os\preset.py shipped with
a full suite -- 9 criteria, each with an attack and a specificity half, plus 9 mutation probes --
and NONE of it ran on any commit, because the fast tier selects suites and there was no suite
here to select. It is the identical hole ORDER-702 was opened for after `git ls-files -- <pathspec>`
matched registry.py (1) and evidence.py (0): a module can be fully tested and completely
unguarded at the same time, and the second fact is invisible while the first one is true.

MEASURED before adding, because the ORDER-673 budget means a new cage DISPLACES something:
run_preset_tests.py --mutate is 0.2s. That is the cheapest suite in the tier by an order of
magnitude, and it is added on that basis rather than on "tests are good".

--mutate is passed HERE, not left to a human. Without it the suite proves the criteria are green;
with it, each one is proven able to go RED for its own reason. A cage that never runs its own
negatives is the shape this whole tier exists to catch.

ASCII-only on purpose (Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI).
USAGE  powershell -NoProfile -File scripts\_test\run_preset_tests.ps1
#>
[CmdletBinding()]
param([string]$RepoRoot = '')

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }

$py = Join-Path $RepoRoot 'tools\python312\python.exe'
$suite = Join-Path $RepoRoot '_triage\factory_os\run_preset_tests.py'

if (-not (Test-Path -LiteralPath $py)) {
    Write-Host "[preset] FAIL: interpreter not found at $py" -ForegroundColor Red
    exit 2
}
if (-not (Test-Path -LiteralPath $suite)) {
    # A MISSING SUITE IS A TOOL FAILURE, NOT A PASS. Exit 2, not 0 -- "I could not run the cage"
    # and "the cage passed" are the two answers this repo refuses to conflate.
    Write-Host "[preset] FAIL: suite not found at $suite" -ForegroundColor Red
    exit 2
}

$out = & $py $suite '--mutate' 2>&1
$code = $LASTEXITCODE
$out | ForEach-Object { Write-Host $_ }

if ($code -ne 0) {
    Write-Host "[preset] the preset-compiler cage FAILED (exit $code)" -ForegroundColor Red
    exit 1
}
# Assert the mutation half actually ran. `--mutate` could be silently dropped by an edit to the
# suite's argument handling, and the criteria would still print green -- which is the suite
# passing while proving strictly less than its own name claims.
if (($out -join "`n") -notmatch 'mutation probes') {
    Write-Host "[preset] FAIL: the run produced no mutation probes -- --mutate did not take effect, so no criterion was shown able to fail" -ForegroundColor Red
    exit 1
}
Write-Host '[preset] preset-compiler cage green, mutation probes included' -ForegroundColor Green
exit 0
