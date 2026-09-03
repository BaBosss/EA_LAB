<#
run_wrapper_gen_tests.ps1 - ORDER-1020 (slice S7), wrapping the reachability cage.

WHAT IT GUARDS. check_wrapper_gen.py holds two of slice S8's three acceptance criteria as checks
that can fail: the wrapper contains ZERO logic (W2), and it regenerates BYTE-IDENTICALLY (W1). W3
requires the allowlist header and the Hypothesis row's module_set to be the same set - two records
of which modules a revision uses, and this is the pair that decides what the BINARY contains. W4
requires the wrapper to be WIRED, because W1 alone permits a perfectly current wrapper that
includes no allowlist and therefore engages nothing.

THE ATTACKS ARE CORRUPTED ARTIFACTS, not mutated code, and nothing on disk is touched - the
corrupted text reaches check() through a stub source.

S8's THIRD acceptance - the 7-point parity contract of design 5.5 - is NOT here and is not
approximated here. It needs the tester. A source-level claim dressed up as a behavioural one is
worse than no claim, because it occupies the place the real check goes.

MEASURED before adding, per ORDER-673: 0.7s through this wrapper.

--mutate is passed HERE rather than left to a human, for the reason run_preset_tests.ps1 gives:
without it the suite proves the criteria are green; with it, each one is proven able to go RED for
its own reason.

ASCII-only on purpose (Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI).
USAGE  powershell -NoProfile -File scripts\_test\run_wrapper_gen_tests.ps1
#>
[CmdletBinding()]
param([string]$RepoRoot = '')

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }

$py = Join-Path $RepoRoot 'tools\python312\python.exe'
$suite = Join-Path $RepoRoot '_triage\factory_os\run_wrapper_gen_tests.py'

if (-not (Test-Path -LiteralPath $py)) {
    Write-Host "[wrapper-gen] FAIL: interpreter not found at $py" -ForegroundColor Red
    exit 2
}
if (-not (Test-Path -LiteralPath $suite)) {
    # A MISSING SUITE IS A TOOL FAILURE, NOT A PASS. Exit 2, not 0.
    Write-Host "[wrapper-gen] FAIL: suite not found at $suite" -ForegroundColor Red
    exit 2
}

$out = & $py $suite 2>&1
$code = $LASTEXITCODE
$out | ForEach-Object { Write-Host $_ }

if ($code -ne 0) {
    Write-Host "[wrapper-gen] the Thin Wrapper cage FAILED (exit $code)" -ForegroundColor Red
    exit 1
}
# Assert the mutation half actually ran. `--mutate` could be silently dropped by an edit to the
# suite's argument handling, and the criteria would still print green -- the suite passing while
# proving strictly less than its own name claims.
# Assert the SPECIFICITY half actually ran. Every attack in the suite is meaningless unless the
# REAL store was also checked and came back clean, and that line is the one an edit to the suite's
# early-exit could silently remove.
if (($out -join "`n") -notmatch 'the REAL generated tree produces ZERO problems') {
    Write-Host "[wrapper-gen] FAIL: the run never asserted the real generated tree is clean, so no attack in it proves anything" -ForegroundColor Red
    exit 1
}
Write-Host '[wrapper-gen] Thin Wrapper cage green, real generated tree asserted clean' -ForegroundColor Green

$pkgSuite = Join-Path $RepoRoot 'scripts\_test\fixtures\factory_vnext\test_factory_vnext_boss11_16_first_green.py'
if (-not (Test-Path -LiteralPath $pkgSuite)) {
    Write-Host "[wrapper-gen] FAIL: Boss11-16 first-green suite missing at $pkgSuite" -ForegroundColor Red
    exit 2
}
$pkgOut = & $py $pkgSuite 2>&1
$pkgCode = $LASTEXITCODE
$pkgOut | ForEach-Object { Write-Host $_ }
if ($pkgCode -ne 0) {
    Write-Host "[wrapper-gen] Boss11-16 first-green package cage FAILED (exit $pkgCode)" -ForegroundColor Red
    exit 1
}
Write-Host '[wrapper-gen] Boss11-16 deterministic first-green package cage green' -ForegroundColor Green

$b18Suite = Join-Path $RepoRoot 'scripts\_test\fixtures\factory_vnext\test_factory_vnext_boss18_first_green.py'
if (-not (Test-Path -LiteralPath $b18Suite)) { Write-Host "[wrapper-gen] FAIL: Boss18 first-green suite missing at $b18Suite" -ForegroundColor Red; exit 2 }
$oldEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$b18Out = & $py $b18Suite 2>&1
$b18Code = $LASTEXITCODE
$ErrorActionPreference = $oldEap
$b18Out | ForEach-Object { Write-Host $_ }
if ($b18Code -ne 0) { Write-Host "[wrapper-gen] Boss18 first-green package cage FAILED (exit $b18Code)" -ForegroundColor Red; exit 1 }
Write-Host '[wrapper-gen] Boss18 deterministic first-green package cage green' -ForegroundColor Green
exit 0
