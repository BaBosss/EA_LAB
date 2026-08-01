<#
run_work_receipts_tests.ps1 - the tier wrapper for the S14 Work Receipt grant's cage.

WHY A WRAPPER EXISTS, and it is the same reason ORDER-702 wrote one for the preset compiler: the
fast tier selects SUITES, so a python cage with no .ps1 beside it is fully written and never run.
A guard that never runs is prose, and this particular guard is the only thing standing between the
narrow AGENTS.md section 2 grant ("APPEND ONLY, one row per order, no verdicts") and the wide one
nobody agreed to.

MEASURED before adding, because the ORDER-673 budget means a new cage DISPLACES something:
run_work_receipts_tests.py is ~0.15s -- it drives pure text through check(), spawning no git and
touching no repo file, which is also why it can assert both directions cheaply.

WHAT IT RUNS. The cage (16 cases: CONTROL that an append still LANDS, ATTACK on every clause, two
SPECIFICITY cases that the closed decision-field list does not swallow ordinary work fields, and an
ENGAGEMENT mutation that neutralises the append-only comparison and requires the attack cases to go
red). Then the checker itself against the REAL file, because a cage that only ever sees fixtures
proves the rule and never proves the rule is applied.

USAGE  powershell -NoProfile -File scripts\_test\run_work_receipts_tests.ps1
#>
[CmdletBinding()]
param([string]$RepoRoot = '')

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }

$py    = Join-Path $RepoRoot 'tools\python312\python.exe'
$suite = Join-Path $RepoRoot '_triage\factory_os\run_work_receipts_tests.py'
$check = Join-Path $RepoRoot '_triage\factory_os\check_work_receipts.py'

foreach ($p in @($py, $suite, $check)) {
    if (-not (Test-Path -LiteralPath $p)) {
        # A MISSING SUITE IS A TOOL FAILURE, NOT A PASS. Exit 2, not 0.
        Write-Host "[work-receipts] FAIL: not found at $p" -ForegroundColor Red
        exit 2
    }
}

$out = & $py $suite 2>&1
$code = $LASTEXITCODE
$out | ForEach-Object { Write-Host $_ }
if ($code -ne 0) {
    Write-Host "[work-receipts] the grant cage FAILED (exit $code)" -ForegroundColor Red
    exit 1
}
# Assert the ENGAGEMENT half actually ran. Without it the suite could go green while proving
# nothing can fail -- the shape this repo has repaired more than once.
if (($out -join "`n") -notmatch 'ENGAGEMENT') {
    Write-Host "[work-receipts] FAIL: no ENGAGEMENT case ran, so no criterion was shown able to fail" -ForegroundColor Red
    exit 1
}

$out2 = & $py $check 2>&1
$code2 = $LASTEXITCODE
$out2 | ForEach-Object { Write-Host $_ }
if ($code2 -ne 0) {
    Write-Host "[work-receipts] the REAL factory/work_receipts.jsonl does not satisfy the grant (exit $code2)" -ForegroundColor Red
    exit 1
}

Write-Host '[work-receipts] grant enforced on fixtures AND on the real file' -ForegroundColor Green
exit 0
