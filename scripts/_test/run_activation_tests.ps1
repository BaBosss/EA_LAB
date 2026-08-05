<#
run_activation_tests.ps1 - ORDER-1020 (slice S7), wrapping the reachability cage.

WHAT IT GUARDS. architecture.py + capability.py + activation.py decide which of Boss_14's 116
inputs a given hypothesis can actually reach. That answer decides what the operator is shown,
what optimize_guard may sweep, and (in slice S8) which inputs the generator turns into a const --
so an error here is not a display bug, it silently changes the strategy.

The failure mode this cage is really built for is INERTNESS, not over-refusal: a classifier that
calls everything unreachable produces a beautifully small Operator surface and is completely
wrong. Criterion A6 therefore asserts in BOTH directions - a dial goes dark when its selector
turns it off, AND comes back when it turns on (memory inert-axis-fake-plateau).

MEASURED before adding, because the ORDER-673 budget means a new cage DISPLACES something:
run_activation_tests.py --mutate is 1.3s standalone and 0.4s inside the hook tier (the second
number is the one that matters: it is what a real commit pays). Both were measured in the session
that added it, per ORDER-673 N1 - not carried over from this comment.

--mutate is passed HERE rather than left to a human, for the reason run_preset_tests.ps1 gives:
without it the suite proves the criteria are green; with it, each one is proven able to go RED for
its own reason.

ASCII-only on purpose (Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI).
USAGE  powershell -NoProfile -File scripts\_test\run_activation_tests.ps1
#>
[CmdletBinding()]
param([string]$RepoRoot = '')

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }

$py = Join-Path $RepoRoot 'tools\python312\python.exe'
$suite = Join-Path $RepoRoot '_triage\factory_os\run_activation_tests.py'

if (-not (Test-Path -LiteralPath $py)) {
    Write-Host "[activation] FAIL: interpreter not found at $py" -ForegroundColor Red
    exit 2
}
if (-not (Test-Path -LiteralPath $suite)) {
    # A MISSING SUITE IS A TOOL FAILURE, NOT A PASS. Exit 2, not 0.
    Write-Host "[activation] FAIL: suite not found at $suite" -ForegroundColor Red
    exit 2
}

$out = & $py $suite '--mutate' 2>&1
$code = $LASTEXITCODE
$out | ForEach-Object { Write-Host $_ }

if ($code -ne 0) {
    Write-Host "[activation] the reachability cage FAILED (exit $code)" -ForegroundColor Red
    exit 1
}
# Assert the mutation half actually ran. `--mutate` could be silently dropped by an edit to the
# suite's argument handling, and the criteria would still print green -- the suite passing while
# proving strictly less than its own name claims.
if (($out -join "`n") -notmatch 'mutation probes') {
    Write-Host "[activation] FAIL: the run produced no mutation probes -- --mutate did not take effect, so no criterion was shown able to fail" -ForegroundColor Red
    exit 1
}
Write-Host '[activation] reachability cage green, mutation probes included' -ForegroundColor Green
exit 0
