<#
    run_contract_binding_tests.ps1 -- BACKLOG-D31 cage.

    Guards the seam that produced every regression across three blind audits of the Factory
    OS design: the normative contract written by hand in TWO places -- the design prose and
    _triage/factory_os/schemas.json -- with nothing binding them. Audit 3 measured the first
    attempt at a cure (check_schema_structure.py) against the 7 REGRESSED findings: it would
    have caught 0 of 7, and it printed STRUCTURE OK on a commit where the design described
    `attempts[]`, a lease with `pid`, and `launched_at` while the schema said the opposite.

    Three things run here, and the second and third are the ones that matter:
      1. gen_design_contracts.py --check   -- _triage/factory_os/CONTRACTS.md still matches the
                                              schema, AND the design still links every contract
                                              in it (the tables moved out of the design; the
                                              link check is what replaced "states it by being it")
      2. run_contract_binding_tests.py     -- the binding still CATCHES all seven regressions,
                                              re-applied as schema mutations, with three controls
                                              proving the harness is not simply always red
      3. run_snapshot_validator_tests.py   -- ORDER-601 part 2. The schema can prove `all_clear`
                                              is a well-typed boolean; it cannot prove who wrote
                                              it. This asserts the verdict is the CORRECT verdict,
                                              and mutation-tests its own predicates: each of the
                                              13 is disabled in turn and only that predicate's
                                              own fixtures may go red.

    A cage that has never been shown to fail is untested by this repo's own rule, so (2) and the
    mutation half of (3) are not optional decoration -- they are the only evidence (1) and the
    rest of (3) are worth running.

    Interpreter: tools\python312\python.exe, committed in-repo. No script here needs ajv or any
    network access.

    run_schema_fixtures.py (35 ajv cases) is deliberately NOT here, and as of 2026-07-30 the reason
    CHANGED: it was 11.5s (one ajv spawn per case) and is now 1.8s (batched into one). So it is no
    longer excluded for cost -- it is excluded because this tier has no headroom at all, measuring
    14.1-15.2s against a 15.0s advisory budget. Codex audit 6 named the consequence: the 35 cases
    are enforced by nothing automatic, so a schema edit can trigger this tier, run the computation
    suite with NO_SCHEMA_CHECK, and never reach the closed-object and nonnegative checks. The fix is
    per-path suite selection from $SUITE_GUARDS, not squeezing 1.8s into a tier already over budget.

    WHY (3) LIVES HERE RATHER THAN IN A SUITE OF ITS OWN -- this is the budget decision the
    ORDER-601 handoff demanded be made deliberately, with numbers rather than assumption.
    MEASURED 2026-07-30 before touching anything: the fast tier was 14.7s against a 15.0s
    budget, NOT the 14.0s carried in the handoff. So the headroom was 0.3s and a new
    run_snapshot_validator_tests.ps1 would have breached the budget on its own -- roughly 0.3s
    of a ~0.4s suite is PowerShell process startup, paid before a single assertion runs.
    The three options were: displace run_optimize_guard_tests.ps1 (5.8s), raise the budget, or
    fold these tests into an existing suite. Displacing a real 14-case guard to make room for
    one python script is a bad trade at any budget, and raising the ceiling to fit an addition
    that had a cheaper home would spend the one thing keeping this tier from being --no-verify'd.
    Folding it in here costs ONE python interpreter start instead of a PowerShell process plus
    an interpreter, and it is the honest home besides: this suite already guards the
    design<->schema seam, and the validator is the third corner of it.

    MEASURED 0.4s for the first two scripts. See the re-measured tier total in run_fast_cages.ps1.

    ⚠️ BUDGET: ORDER-600 (S2a) PUSHED THIS TIER FURTHER OVER AN ALREADY-BREACHED CEILING, and the
    number is stated here rather than discovered by the next session.
    MEASURED 2026-07-30, medians of 3 runs each (never one number -- the handoff that carried "14.0s"
    forward was quoting a lucky single run):
      this suite   0.6s -> 3.3s        (+2.7s: the five S2a checks, in ONE interpreter)
      fast tier   15.4s -> 17.0s       (17.0 / 17.0 / 17.4) against a 15.0s ADVISORY budget
    (2.8s / 16.5s before /scrutinize added the loader and drift-guard parts; +0.5s bought coverage of
     five loader rules and two criterion bypasses that were enforced by nothing.)
    ...but measured AGAIN from inside the real pre-commit hook, the same tier runs 15.1-15.2s with
    this suite at 1.8s, because git's index and objects are already warm there. BOTH numbers are
    real and they answer different questions: 16.5s is what a cold standalone run costs, 15.1s is
    what a committer actually waits. Quote the in-situ figure when deciding whether the tier hurts,
    and the standalone figure when deciding whether there is headroom to spend -- and re-measure
    rather than citing either, which is the mistake that put "14.0s" in two handoffs.
    The tier was ALREADY over budget at 15.4s before this order touched it, so S2a is not the cause
    of the breach -- but it is 1.5s of it now, and that must not be left implicit.
    Everything cheaper was done first: five separate script entries measured 4.57s, one interpreter
    3.45s, and 2.57s after memoizing `git ls-files` and the schema $ref graph inside
    check_s2a_migration.py -- the mutation suite was re-paying both 25 times in a single run, which
    is ORDER-270's spawn pathology at small scale. A further 11x is available only by dropping the
    24-mutation half, which is the one half that proves the checker can still fail against the file
    it just passed. That is not a trade worth making.
    THE REAL FIX REMAINS BACKLOG-D32, per-path suite selection from $SUITE_GUARDS: a commit touching
    only scripts/*.ps1 should not pay 2.9s of S2a, and a commit touching s2a_migration.jsonl should
    not pay 5.8s of optimize-guard. The declarations needed for that are now in place for S2a -- all
    eight of its paths are in the $SUITE_GUARDS map and selected by the generated pathspec, verified
    by run_guard_trigger_tests.ps1.
#>
[CmdletBinding()]
param([string]$RepoRoot)

$ErrorActionPreference = 'Stop'

if (-not $RepoRoot) {
    $here = $PSScriptRoot
    if (-not $here -and $MyInvocation.MyCommand.Path) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $here) { throw 'cannot resolve script directory; pass -RepoRoot explicitly' }
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $here)
}

$python = Join-Path $RepoRoot 'tools\python312\python.exe'
if (-not (Test-Path -LiteralPath $python)) {
    # A missing interpreter is a failure, not a skip. A cage that silently opts out when its
    # tool is absent is the exact defect class this repo has hit five times: the artifact
    # keeps being produced and quietly stops being true.
    Write-Host "[contract-binding] FAIL: interpreter not found at $python" -ForegroundColor Red
    exit 1
}

$scripts = @(
    @{ Path = '_triage\factory_os\gen_design_contracts.py'; Args = @('--check') },
    @{ Path = '_triage\factory_os\run_contract_binding_tests.py'; Args = @() },
    @{ Path = '_triage\factory_os\run_snapshot_validator_tests.py'; Args = @() },
    # 4. check_schema_structure.py -- the SUPERSEDED lint, wired in by /scrutinize 2026-07-30.
    #    It is not the binding (that is item 1) and its own header says so. It is kept for two
    #    checks nothing else covers: discriminator consistency (add an entity, forget its oneOf
    #    branch) and the closed-object inventory across all 27 entities.
    #    WHY IT IS HERE NOW: it had been CRASHING since `c8d03d4b` -- part 1 made
    #    meta.reconciliation a $ref and the script indexed ['required'] on it -- so its whole
    #    design-binding section had not executed for four commits, and it still printed
    #    "all routed entities except ['ControlRoomSnapshotV5']" after that root was closed. A lint
    #    in no suite and no hook is a lint that can die without anyone learning it died, which is
    #    ORDER-270's finding applied to a file rather than to a runtime.
    @{ Path = '_triage\factory_os\check_schema_structure.py'; Args = @() },
    # 5. run_s2a_gate.py -- ORDER-600 (S2a), wired in the same commit that landed D1, which is what
    #    check_s2a_migration.py's own header says to do: it exits 2 while D1 is absent, so wiring it
    #    any earlier would have made this tier permanently red.
    #    It is ONE entry running FIVE checks in ONE interpreter (D1-vs-generator drift, D2-vs-D1
    #    drift, the nine machine criteria, the 18-assertion self-test, and 24 mutations of the real
    #    D1). MEASURED: as five separate entries it cost 4.57s; in one process 3.45s; and 2.57s after
    #    memoizing `git ls-files` and the schema $ref graph, which the mutation suite was otherwise
    #    re-paying 25 times in a single run -- the ORDER-270 spawn pathology at small scale.
    #    The mutation half is the part that matters: the other four can all be green while the
    #    checker is incapable of failing against the file it just passed.
    @{ Path = '_triage\factory_os\run_s2a_gate.py'; Args = @() }
)

$failed = 0
foreach ($s in $scripts) {
    $full = Join-Path $RepoRoot $s.Path
    if (-not (Test-Path -LiteralPath $full)) {
        Write-Host ("[contract-binding] FAIL: missing {0}" -f $s.Path) -ForegroundColor Red
        $failed++
        continue
    }
    $out = & $python $full @($s.Args) 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host ("[contract-binding] FAIL {0}" -f $s.Path) -ForegroundColor Red
        Write-Host ($out | Out-String)
        $failed++
    }
}

if ($failed -gt 0) { exit 1 }
Write-Host ('[contract-binding] design tables match the schema, all 7 regressions are still ' +
            'caught, and the snapshot verdict is recomputed rather than trusted')
exit 0
