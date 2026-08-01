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
      this suite   0.6s -> 3.6s        (+3.0s: the five S2a checks, in ONE interpreter)
      fast tier   15.4s -> 17.3s       (17.3 / 17.2 / 17.3) against a 15.0s ADVISORY budget
    RE-MEASURED 2026-07-31 after ORDER-601's closure added run_enforcement_status_tests.py:
      fast tier   17.3s -> 18.1s       (18.0 / 18.1 / 18.3) -- now 3.1s over the advisory line.
    That suite is worth its ~0.8s (it is the only thing stopping PLANNED/BUILT/WIRED from becoming
    the same unchecked label x-enforced-by already was), but the tier is now over by more than any
    single addition, which is the definition of the drift BACKLOG-D32 exists to end. Nothing further
    goes in this tier before per-path selection is built.
    (2.8s / 16.5s before /scrutinize; +0.8s bought coverage of five loader rules, two criterion
     bypasses and a pin-vintage advisory that were all enforced by nothing at all. Re-measured after
     each addition rather than carried forward -- an earlier line here said 2.9s and 16.5s and was
     stale within two commits.)
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
    ✅ BACKLOG-D32 IS NOW BUILT (2026-07-31). This suite still costs 3.6s, but a commit only pays it
    when it stages something this suite guards -- measured 3.9s total for a schema edit against
    18.1s for the full tier. The paragraph below described the fix while it was still pending; it is
    kept because the reasoning is why the feature exists.
    THE REAL FIX WAS BACKLOG-D32, per-path suite selection from $SUITE_GUARDS: a commit touching
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
    # ORDER-612 (S4). The python half of the S4 acceptance -- C2 (N discovered => exactly N
    # categorized or an explicit reason), C4 (evidence DERIVED from disk, a contradicting builder
    # claim REFUSED), C5 (atomic build->validate->replace, previous file byte-unchanged on
    # failure), C7 (version 5, and 4 refused by the schema). MEASURED 0.35s, which is why it is
    # here rather than in a suite of its own: this wrapper's own note says the expensive part of a
    # cage in this tier is the process, not the assertions. C1 stays in run_schema_fixtures.py
    # (it IS that file's real-snapshot line, now asserted rather than printed); C3 and C6 are the
    # PowerShell readers and live in scripts\_test\run_snapshot_s4_tests.ps1.
    @{ Path = '_triage\factory_os\run_snapshot_s4_tests.py'; Args = @() },
    # ORDER-630 (S5). The resolver's answers, and each of check_registries' five criteria observed
    # going red for its own reason. MEASURED 0.2s. Same trade as the line above: a python cage
    # belongs in an existing python wrapper unless it needs its own lifecycle.
    @{ Path = '_triage\factory_os\run_registry_tests.py'; Args = @() },
    # ...and the guard itself, run over the REAL stores. The suite above drives it against
    # synthetic roots; this is the run that would notice a committed registry going wrong.
    @{ Path = '_triage\factory_os\check_registries.py'; Args = @() },
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
    @{ Path = '_triage\factory_os\run_s2a_gate.py'; Args = @() },
    # 5b. run_s2a_conformance.py -- ORDER-614 rev 2. The implementation left the attestation
    # bundle; THIS is what holds it to the bound policy instead. --mutate is the permanent E1
    # fixture: every conforming vector must go red when its own criterion is neutralised. A
    # repair to check_s2a_attestation.py that keeps this green owes the owner NO signature,
    # which is the entire point of the order.
    @{ Path = '_triage\factory_os\run_s2a_conformance.py'; Args = @('--mutate') },
    # 6. ORDER-601 closure: proves the PLANNED/BUILT/WIRED labels are checked and the check can fail.
    #    x-enforced-by asserted enforcement for 7 constraints nothing enforced; relabelling only
    #    helps if the labels are verified, so this mutates the schema 5 ways and requires each to be
    #    refused by name.
    @{ Path = '_triage\factory_os\run_enforcement_status_tests.py'; Args = @() },
    # 7. ORDER-610 (S2). The Coverage transfer acceptance, in two entries because they answer two
    #    different questions and one cannot substitute for the other:
    #      run_coverage_transfer_tests.py  -- can the checker fail? 18 mutations, 2 controls, and
    #                                         an inertness probe showing the self-referential
    #                                         baseline accepts a deletion the pinned one catches.
    #      check_coverage_transfer.py      -- does the REAL repository still satisfy both owner
    #                                         conditions right now? The mutation suite injects its
    #                                         inputs, so it would stay green if the real
    #                                         MASTER_BACKLOG.md were hand-edited tomorrow.
    @{ Path = '_triage\factory_os\run_coverage_transfer_tests.py'; Args = @() },
    @{ Path = '_triage\factory_os\check_coverage_transfer.py'; Args = @() },
    # 8. ORDER-611 (S3). The REAL JSON Schema validation, wired at last. It was excluded for two
    #    reasons in sequence, both since removed: it cost 11.5s (fixed by batching, 1.8s), and then
    #    the tier ran all 12 suites on any staged path (fixed by BACKLOG-D32's per-path selection).
    #    A schema edit now pays this suite and not 5.8s of optimize-guard cases.
    #    MEASURED 2026-07-31: 2.2s, 89 cases (35 root + 54 per-entity) + 3 harness probes.
    #    REQUIRES ajv-cli on PATH. If ajv is missing the suite reports ERROR, not "rejected" --
    #    that distinction is the whole reason its three-state discipline exists.
    @{ Path = '_triage\factory_os\run_schema_fixtures.py'; Args = @() },
    # 9. ORDER-616. The four defect SHAPES behind 24 audit findings, made mechanical where they
    #    can be. TWO entries because "the lint passes" and "the lint can fail" are different
    #    claims, and the second is the one this repo keeps needing: L1 and L2 are guards, and a
    #    guard with no proof it can fire is shape 3 -- the very thing L2 exists to catch.
    @{ Path = '_triage\factory_os\run_guard_shape_lint.py'; Args = @('--self-test') },
    @{ Path = '_triage\factory_os\run_guard_shape_lint.py'; Args = @() },
    # 10. ORDER-710. The generated input-surface enumeration, in the same two entries as item 7
    #     and for the same reason -- they answer two different questions:
    #       run_input_surface_tests.py --mutate -- can the guard fail? 5 criteria x (attack +
    #                                              specificity) + 5 mutations, over FIXTURE
    #                                              sources it injects, so it stays green no
    #                                              matter what the real repository does.
    #       check_input_surface_gen.py         -- is the REAL enumeration current and wired in
    #                                              RIGHT NOW, judged at the commit's snapshot?
    #     MEASURED 0.21s + 0.10s. Both belong in this wrapper rather than a 17th PowerShell
    #     suite, per this file's own rule that the expensive part of a small cage is the process.
    @{ Path = '_triage\factory_os\run_input_surface_tests.py'; Args = @('--mutate') },
    @{ Path = '_triage\factory_os\check_input_surface_gen.py'; Args = @() }
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
