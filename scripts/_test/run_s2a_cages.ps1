<#
    run_s2a_cages.ps1 -- ORDER-1269 #1 (owner-ratified as ORDER-1257 option (b), 2026-08-03).

    THE TWO S2a CHECKERS RETURN TO THE PRE-COMMIT TIER, NARROWLY, AND ONLY THESE TWO.

    WHY THIS EXISTS AT ALL. ORDER-1269's implementation constraint is explicit: whichever shape
    the pin repair takes "must land WITH run_s2a_gate + check_coverage_transfer returning to the
    tier". They could not be added before the repair -- they were RED, and a red suite on the
    commit path blocks every commit in the repo, not just the lane that added it. They are green
    as of the commit before this one, which is what makes this safe to do now:

        run_s2a_gate.py            2 of 7 steps FAILED  ->  all 7 green
        check_coverage_transfer.py exit 1 (its A8 reads the gate's sibling's exit code) -> exit 0

    WHY A NEW WRAPPER RATHER THAN PUTTING run_contract_binding_tests.ps1 BACK. It must not go
    back. ORDER-1252 (owner-ratified the same day) removed that wrapper because it had grown to
    18 entries and 42.6s under -Hook, and because its per-path breadth made ordinary commits
    expensive -- a schema edit selected 14 suites and cost 99.2s against the 90.0s per-path
    budget. Nothing about this order changes that. Two of its fourteen entries come back, in a
    wrapper that is selected ONLY by S2a paths, and the other twelve stay hand-run exactly as
    ORDER-1252 recorded. The two orders are not in conflict once the re-add is this narrow; they
    would be if the wrapper came back whole.

    WHAT IT RUNS
      run_s2a_gate.py             D1 matches its generator - D2 matches D1 - the nine machine
                                  criteria - the checker refuses the null migration - the
                                  attestation log is valid - recording a decision needs no guard
                                  edit - 32 mutations of the real D1
      check_coverage_transfer.py  ORDER-610 E3: both owner conditions for the Coverage transfer,
                                  recomputed from the judged bytes rather than read from a stored
                                  verdict

    ORDER-1283 CHECKED BEFORE WIRING, NOT AFTER. A cage that mutates a tracked file must never sit
    on the commit path -- two lanes commit concurrently here, and whichever process reads while the
    other holds a mutation restores the MUTATION (memory `mutating-cage-must-not-be-on-commit-path`,
    observed live on schemas.json within twenty minutes of ORDER-1264). Both entries below were
    read for writes first: every write in run_s2a_migration_tests.py and
    run_s2a_attestation_tests.py goes to an mkstemp tempfile, check_coverage_transfer.py writes
    only to stdout, and the attestation suite ends by asserting the real log is byte-unchanged and
    printing that it is. That last one is the shape ORDER-1283 wants and it is worth naming: the
    cage proves its own read-onlyness rather than promising it.

    MEASURED with -Timing under EA_LAB_EVIDENCE=index, which is the only invocation whose number
    means anything (memory `tier-number-needs-its-invocation`), on an IDLE machine -- checked with
    Get-Process metatester64 first, because the same tier that measures 86-95s idle has measured
    141.8s under an 18-agent optimize batch. THREE samples, per this directory's own rule that a
    single number here is a fiction:

        run_s2a_gate.py             6.51 / 6.26 / 6.76s
        check_coverage_transfer.py  1.31 / 1.35 / 1.35s
        SUM OF ENTRIES              7.82 / 7.61 / 8.11s   -> median 7.82s

    That is ~1.1s more than the 6.7s ORDER-1252's own list predicted from its 5.4 + 1.3 entries.
    The prediction is left visible in the registration comment rather than corrected, because the
    gap is the point: a per-entry time recorded on one day is an estimate on another, which is why
    the -Timing switch exists and why this table is three samples instead of one.

    FULL-TIER EFFECT, re-measured rather than projected (the rule two files over is that a
    per-suite time is stable and a TIER TOTAL is not):

        before this suite   88.1s of 120.0s   28 suites, 0 failed   -- ONE sample, stated as one
        after  this suite   97.5 / 98.4 / 95.5s -> median 97.5s of 120.0s   29 suites, 0 failed

    So 22.5s of headroom remains against the PINNED 120.0s budget, which this order does not raise
    and is forbidden to. The headroom exists because ORDER-1252 took 37s out; this spends ~9s of
    it and says so, rather than letting the next lane discover the tier crept up.

    Interpreter: tools\python312\python.exe, committed in-repo.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot,
    # Same contract as the two wrappers beside this one: a measurement table that lives only in a
    # comment goes stale, and this repo has paid for that four times (4x, 42x, 41x, ~2x). The
    # table above is re-derivable by running this switch; if it cannot be re-derived it is not a
    # measurement, it is a memory.
    [switch]$Timing
)

$ErrorActionPreference = 'Stop'

$evidenceMode = if ($env:EA_LAB_EVIDENCE) { $env:EA_LAB_EVIDENCE } else { 'worktree (default)' }

if (-not $RepoRoot) {
    $here = $PSScriptRoot
    if (-not $here -and $MyInvocation.MyCommand.Path) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $here) { throw 'cannot resolve script directory; pass -RepoRoot explicitly' }
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $here)
}

# Thai/section signs in any child's output kill the process under an ANSI-codepage pipe, and the
# tier then reports `exit -1 SUITE THREW` with the cause swallowed (memory
# `thai-output-kills-a-suite-inside-the-hook`). Set here, in the wrapper, for every child.
$env:PYTHONIOENCODING = 'utf-8'

$python = Join-Path $RepoRoot 'tools\python312\python.exe'
if (-not (Test-Path -LiteralPath $python)) {
    # A missing interpreter is a FAILURE, not a skip. A cage that opts out when its tool is absent
    # keeps being produced and quietly stops being true.
    Write-Host "[s2a-cages] FAIL: interpreter not found at $python" -ForegroundColor Red
    exit 1
}

$scripts = @(
    @{ Path = '_triage\factory_os\run_s2a_gate.py'; Args = @() },
    @{ Path = '_triage\factory_os\check_coverage_transfer.py'; Args = @() }
    # NOT run_s2a_conformance.py --mutate, and the omission is deliberate rather than forgotten.
    # It stays in run_contract_binding_tests.ps1 where ORDER-1252 left it. ORDER-1269's constraint
    # names two checkers; adding a third because it is nearby is how a 2-entry wrapper becomes the
    # 18-entry one that had to be removed.
)

$failed = 0
$timings = @()
foreach ($s in $scripts) {
    $full = Join-Path $RepoRoot $s.Path
    if (-not (Test-Path -LiteralPath $full)) {
        Write-Host ("[s2a-cages] FAIL: missing {0}" -f $s.Path) -ForegroundColor Red
        $failed++
        continue
    }
    $sw = if ($Timing) { [System.Diagnostics.Stopwatch]::StartNew() } else { $null }
    $out = & $python $full @($s.Args) 2>&1
    if ($sw) {
        $sw.Stop()
        # Label DERIVED from the entry, never retyped -- a hand copy is a second source of truth.
        $timings += [pscustomobject]@{
            Entry   = (Split-Path -Leaf $s.Path) + $(if ($s.Args.Count) { ' ' + ($s.Args -join ' ') } else { '' })
            Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 2)
        }
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Host ("[s2a-cages] FAIL {0}" -f $s.Path) -ForegroundColor Red
        Write-Host ($out | Out-String)
        $failed++
    }
}

if ($Timing) {
    Write-Host ''
    Write-Host ("[s2a-cages] TIMING -- evidence mode: {0}" -f $evidenceMode)
    foreach ($t in ($timings | Sort-Object -Property Seconds -Descending)) {
        Write-Host ('    {0,-42} {1,6:N2}s' -f $t.Entry, $t.Seconds)
    }
    Write-Host ('    {0,-42} {1,6:N2}s' -f 'SUM OF ENTRIES',
                ($timings | Measure-Object -Property Seconds -Sum).Sum)
}

if ($failed -gt 0) { exit 1 }
Write-Host ('[s2a-cages] the S2a proposal, its attestation log and the Coverage transfer ' +
            'acceptance all still hold against the judged bytes')
exit 0
