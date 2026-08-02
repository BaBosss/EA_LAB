<#
run_param_surface_tests.ps1 - ORDER-1020 (slice S7), wrapping the reachability cage.

WHAT IT GUARDS. check_param_surface.py enforces design 5.4's state table: the wrapper, the
registry and optimize_guard must tell ONE story about every input, or the optimizer is being told
two. It also carries slice S7's own acceptance as criteria that can fail - zero UNKNOWN on the
OPERATOR surface (P3) and design 5.3's Operator <= 40 target (P4).

THE ATTACKS ARE CORRUPTED STORES, NOT MUTATED CODE, and that is the right direction: the checker
exists to catch a store that has gone wrong, so the attack has to BE one. Nothing on disk is
touched - the corrupted text reaches check() through a stub source, which is possible only because
the checker takes its EvidenceSource as an argument.

P5 is the criterion the other five need: five checks that a store is internally COHERENT are all
equally happy with a store that has quietly stopped matching its source. Its attack is therefore
the only coherent one - it moves a safe_range bound, which no other criterion has an opinion about,
so P5 has to carry that case alone.

MEASURED before adding, per ORDER-673: 0.7s through this wrapper. The cost is one regeneration of
the 232 rows, which is what P5 is.

--mutate is passed HERE rather than left to a human, for the reason run_preset_tests.ps1 gives:
without it the suite proves the criteria are green; with it, each one is proven able to go RED for
its own reason.

ASCII-only on purpose (Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI).
USAGE  powershell -NoProfile -File scripts\_test\run_param_surface_tests.ps1
#>
[CmdletBinding()]
param([string]$RepoRoot = '')

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }

$py = Join-Path $RepoRoot 'tools\python312\python.exe'
$suite = Join-Path $RepoRoot '_triage\factory_os\run_param_surface_tests.py'

if (-not (Test-Path -LiteralPath $py)) {
    Write-Host "[param-surface] FAIL: interpreter not found at $py" -ForegroundColor Red
    exit 2
}
if (-not (Test-Path -LiteralPath $suite)) {
    # A MISSING SUITE IS A TOOL FAILURE, NOT A PASS. Exit 2, not 0.
    Write-Host "[param-surface] FAIL: suite not found at $suite" -ForegroundColor Red
    exit 2
}

$out = & $py $suite 2>&1
$code = $LASTEXITCODE
$out | ForEach-Object { Write-Host $_ }

if ($code -ne 0) {
    Write-Host "[param-surface] the design 5.4 state-table cage FAILED (exit $code)" -ForegroundColor Red
    exit 1
}
# Assert the mutation half actually ran. `--mutate` could be silently dropped by an edit to the
# suite's argument handling, and the criteria would still print green -- the suite passing while
# proving strictly less than its own name claims.
# Assert the SPECIFICITY half actually ran. Every attack in the suite is meaningless unless the
# REAL store was also checked and came back clean, and that line is the one an edit to the suite's
# early-exit could silently remove.
if (($out -join "`n") -notmatch 'the REAL store produces ZERO problems') {
    Write-Host "[param-surface] FAIL: the run never asserted the real store is clean, so no attack in it proves anything" -ForegroundColor Red
    exit 1
}
Write-Host '[param-surface] design 5.4 state-table cage green, real store asserted clean' -ForegroundColor Green
exit 0
