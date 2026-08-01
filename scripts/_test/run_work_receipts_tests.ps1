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
W6/W7 (M6) added a SECOND read to the checker -- AGENTS.md, the grant itself. Measured, 3 samples
each rather than one: 0.3-0.8 ms in worktree mode, 34-37 ms under the hook, where it is one
`git show :AGENTS.md`. The whole wrapper is 0.60-0.62s. Stated because "it is only a file read" is
how a tier gets 8 seconds heavier with nobody able to say which commit did it (ORDER-820).

WHAT IT RUNS. The cage (34 cases: CONTROL that an append still LANDS, ATTACK on every clause, three
SPECIFICITY cases that the closed lists do not swallow ordinary work fields or the declared mention,
an ENGAGEMENT mutation that neutralises the append-only comparison and requires the attack cases to
go red, and a WIRING case that main() actually CONSULTS the grant text). Then the checker itself
against the REAL file, because a cage that only ever sees fixtures proves the rule and never proves
the rule is applied -- and since W6 the real-file run is also the ONLY place the pin meets the real
`AGENTS.md`: the fixtures deliberately use a synthetic row so the grant text is not duplicated here.

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

# ORDER-670's tier-verifiable evidence marker, named for THIS SUITE -- which is what the T4
# allowlist matches on (run_fast_cages.ps1:1099 escapes the suite filename, not a component name).
# The first attempt emitted the checker's own component marker and the tier REFUSED the commit
# with "emitted NO evidence-mode marker", which is the guard working: silence must not pass.
& $py -c "import sys, os; sys.path.insert(0, os.path.join(r'$RepoRoot', '_triage', 'factory_os')); import evidence; print(evidence.EvidenceSource.for_run().marker('run_work_receipts_tests.ps1'))"
if ($LASTEXITCODE -ne 0) {
    Write-Host '[work-receipts] FAIL: could not emit the evidence-mode marker' -ForegroundColor Red
    exit 2
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
# Same reasoning one level up, for W6/W7 (M6): the whole finding was a rule that existed and was
# never READ. Deleting the WIRING case would leave every W6 fixture green while main() consulted
# nothing -- so the suite has to be unable to go quiet about it.
if (($out -join "`n") -notmatch 'WIRING') {
    Write-Host "[work-receipts] FAIL: no WIRING case ran, so nothing showed main() reads the grant at all" -ForegroundColor Red
    exit 1
}

$out2 = & $py $check 2>&1
$code2 = $LASTEXITCODE
$out2 | ForEach-Object { Write-Host $_ }
if ($code2 -eq 2) {
    # Round-2 review, N8: this collapsed 2 into 1. The checker's contract is 2 = TOOL FAILURE, and
    # the wrapper's own missing-file branch above already honours it -- discarding the distinction
    # here is the "could not run the cage" / "the cage failed" conflation this repo refuses.
    Write-Host "[work-receipts] TOOL FAILURE reading the receipts file (exit 2) -- not a verdict" -ForegroundColor Red
    exit 2
}
if ($code2 -ne 0) {
    Write-Host "[work-receipts] the REAL factory/work_receipts.jsonl does not satisfy the grant (exit $code2)" -ForegroundColor Red
    exit 1
}

Write-Host '[work-receipts] grant enforced on fixtures AND on the real file' -ForegroundColor Green
exit 0
