<#
.SYNOPSIS
    ORDER-420. Runs every cage that is fast enough to sit in the pre-commit hook, and
    names the ones that are not.

.DESCRIPTION
    The guards in scripts\check_*.ps1 are enforced on every commit by .githooks\pre-commit.
    The TESTS for those guards were enforced by nothing at all. Every suite under
    scripts\_test\ was manual-only, which is the same condition ORDER-270 diagnosed --
    "a cage that never runs protects nothing" -- except it applied to the whole directory
    rather than one slow script.

    That gap is not theoretical. In eight days this repo shipped four separate defects where
    a guard kept running and quietly stopped reporting: ORDER-260 (substring match),
    ORDER-341 (advisory label outranking the blocking one), ORDER-390 (nested backticks),
    ORDER-370 (a pipeline .Count that is $null for exactly one result). Each was found by a
    human looking, not by a suite.

    MEASURED 2026-07-27, which is what decides the split (times are per suite, cold):

      run_statusclass_tests.ps1          0.5s   -> FAST, runs here
      run_order_collision_tests.ps1      0.9s   -> FAST, runs here
      run_handoff_contract_tests.ps1     0.9s   -> FAST, runs here
      run_blobmap_encoding_tests.ps1     1.3s   -> FAST, runs here
      run_mris_asof_tests.ps1            0.8s   -> FAST, runs here (added 2026-07-27, ORDER-434)
      run_monitor_integrity_tests.ps1    1.5s   -> FAST, runs here (added 2026-07-30, Stage 0B)
      run_chainwalk_tests.ps1           74.4s   -> too slow for a hook, run before release
      run_order101_negative_tests.ps1   ~120s   -> too slow for a hook
      run_order103_negative_tests.ps1   ~760s   -> too slow for a hook
      run_order105_negative_tests.ps1   520.8s  -> too slow for a hook, AND currently RED
                                                   (ORDER-421: two real-hook zero-byte cases,
                                                    pre-existing, cause not yet known)

    WHY A TIME BUDGET IS PART OF THE DESIGN, NOT A COMPROMISE
    A hook that costs 10 minutes gets bypassed with --no-verify, and then it protects
    nothing while looking like it protects everything. That is strictly worse than an
    honest 4-second hook plus a named list of what it does not cover. So this script
    refuses to grow: if a suite here ever exceeds $BudgetSeconds total, it says so loudly
    rather than silently becoming the thing people skip.

    ⚠️ CORRECTION 2026-07-30 (Codex audit 6, MAJOR 7). "Refuses to grow" overstated it. Exceeding
    the budget prints a yellow WARNING and the script still exits 0 -- it is an ADVISORY
    threshold, not a budget, and three consecutive audit runs measured 15.2s / 14.7s / 14.8s, so
    the tier is already over the line on some runs and nothing stopped it. It is deliberately
    left advisory rather than made fatal: a single noisy run failing a commit is precisely how a
    hook earns the --no-verify it is trying to avoid, and wall-clock on this machine varies by
    ~0.5s run to run. What follows from that, and is NOT optional:
      * the next cage does NOT go in this all-suites tier -- measured headroom is zero;
      * quote a MEDIAN of at least three runs, never one run, when reporting the total;
      * the real fix is per-path suite selection using the $SUITE_GUARDS map below, so a schema
        edit stops paying for 5.8s of optimize-guard cases. ✅ BUILT 2026-07-31 (BACKLOG-D32) --
        see Select-Suites below. MEASURED: full tier 18.1s; a schema edit now 3.9s, an
        optimize_guard.ps1 edit 7.3s, a D1 edit 3.9s. The 15.0s advisory line still applies to
        the FULL tier, which is what a manual run and any caller that cannot determine the
        staged set still pay -- selection reduces the common case, it does not raise the ceiling.

    WHAT THIS DOES NOT COVER -- read this before trusting a green run:
    the four slow suites above, and in particular run_order105_negative_tests.ps1, which
    exits 1 today (ORDER-420 STEP 2 owns finding out why). Green here means "the suites in
    $FAST_SUITES passed", nothing more.
    NOTE: this sentence used to say "the four fast cages" while eleven were running (found
    by the audit-4 sweep, 2026-07-30). Do not restate the count here -- the list below IS
    the count, and a hand-maintained number beside a list it does not derive from is the
    exact drift BACKLOG-D29 tracks.

.PARAMETER BudgetSeconds
    Total wall-clock the fast tier is allowed. Exceeding it is reported as a warning with
    the per-suite breakdown, so the split above gets revisited with numbers.

.NOTES
    ASCII only: PS 5.1 decodes a BOM-less .ps1 as ANSI.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [double]$BudgetSeconds = 15.0,
    # BACKLOG-D32: print the suite/guards table as JSON and exit, running no suite. The
    # pathspec generator and its cage both read the table through this switch so the
    # dependency list exists in exactly one place.
    [switch]$ExportGuards,
    # BACKLOG-D32: paths staged for this commit. EMPTY MEANS RUN EVERYTHING -- see the safety
    # rules at Select-Suites. The caller (the hook) decides; this script never guesses.
    [string[]]$StagedPaths = @(),
    # Preferred over -StagedPaths from a shell: one path per line, no quoting or array-binding
    # ambiguity. `powershell -File` bound a comma-joined string as ONE literal for three paths
    # while splitting it correctly for two, which is exactly the kind of thing not to depend on
    # in the pre-commit trigger.
    [string]$StagedPathsFile = '',
    # print the selection and exit, running nothing. For the cage.
    [switch]$ExportSelection
)

$ErrorActionPreference = 'Stop'

# scripts/_test/ -> two levels up. $PSScriptRoot is empty under `powershell -File <relative>`
# from a non-PowerShell shell (the defect that made make_taskboard_digest.ps1 commit 219 wrong
# lines), so fall back to $MyInvocation rather than compute a silently wrong root.
if (-not $RepoRoot) {
    $here = $PSScriptRoot
    if (-not $here -and $MyInvocation.MyCommand.Path) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $here) { throw 'cannot resolve script directory; pass -RepoRoot explicitly' }
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $here)
}

$testDir = Join-Path $RepoRoot 'scripts\_test'

# Keep this list in sync with the measured table above. Adding a slow suite here is the
# failure mode this script exists to prevent, so the budget check below is load-bearing.
$FAST_SUITES = @(
    'run_statusclass_tests.ps1',
    'run_order_collision_tests.ps1',
    'run_handoff_contract_tests.ps1',
    'run_blobmap_encoding_tests.ps1',
    # ORDER-434: guards the `asof` clock in scripts/mris/mris_macro_feeder.ps1. Note this
    # suite protects a file OUTSIDE scripts/check_*.ps1 and scripts/_test/*, so the hook's
    # trigger glob was widened to scripts/mris/* in the same commit -- otherwise the cage
    # would only have run when something OTHER than the file it guards was edited.
    'run_mris_asof_tests.ps1',
    # ORDER-500: guards scripts/lib/b1_guard.ps1, which check_precommit_staged.ps1 and
    # .githooks/commit-msg both dot-source. Runs in ~0.3s and touches no git state --
    # it tests the rule functions directly rather than through a synthetic repo, which
    # is the whole point: ORDER-421 found the synthetic-fixture cages drift away from
    # the hooks they protect because nothing makes the fixture track the dependency list.
    'run_b1_guard_tests.ps1',
    # ORDER-372: guards scripts/lib/report_freshness.ps1 AND sweeps every scripts/*.ps1 for two
    # defect shapes that both produced wrong numbers silently -- a function returning a runner's
    # console output as its result, and a caller inferring "the .htm exists, so this run wrote it".
    # It lives here rather than in a directory of its own for the reason this file's header gives:
    # the first version sat in scripts/tests/, which nothing ran, so it would have been enforced by
    # a human remembering. Both of its guards are mutation-tested (plant an ungated caller -> PART 5
    # fails naming the file; sabotage the mtime compare -> PART 4 fails).
    'run_report_freshness_tests.ps1',
    # ORDER-372: guards the TEXT of scripts/check_truncated_run.ps1, because that text is copied
    # verbatim into every <report>.truncation_check.json and read as the finding. Its final "[OK]
    # traded through to the end of the window" used to be an unconditional else-branch, so a run
    # with a measured 91% idle tail asserted the opposite of its own preceding line.
    'run_truncation_message_tests.ps1',
    # 2026-07-30 (Stage 0A): guards scripts/optimize_guard.ps1, which had been refusing
    # three working dials because it read classification=OVERRIDE as "inactive". The suite
    # asserts BOTH directions of a precedence pair and the same dial ALLOW-on-11 /
    # REFUSE-on-14, so a guard that simply refuses everything cannot pass it. Measured
    # 5.8s cold - the most expensive suite in this tier by a wide margin, because each of
    # its 14 cases spawns its own guard process on purpose (batching them would let the
    # guard's own override check couple cases that must stay independent). That takes the
    # tier from ~5s to ~11s against a 15s budget: deliberate, and the next addition here
    # should re-measure rather than assume there is still room.
    'run_optimize_guard_tests.ps1',
    # 2026-07-30 (Stage 0B): guards the morning monitoring chain -- the coverage rules in
    # scripts/lib/monitor_coverage.ps1 (which daily_monitor.ps1 dot-sources), the
    # unknown-magic age classifier in control_room_snapshot.ps1, and base-equity /
    # account-universe handling in live_dashboard.ps1. It belongs in a hook tier because
    # every defect it covers was the shape this file's header lists: a detector that kept
    # running and quietly stopped reporting.
    #
    # MEASURED 1.5s over three cold runs, which takes this tier from ~10.8s to ~12.4s
    # against the 15s budget. That is a deliberate spend and it leaves roughly 2.5s.
    # THE NEXT ADDITION HERE HAS TO DISPLACE SOMETHING, not assume there is room --
    # run_optimize_guard_tests.ps1 alone is 5.8s and would not fit today.
    #
    # 1.5s of the cost is two child powershell processes: PART 4/5 runs the REAL
    # live_dashboard.ps1 end to end against a fixture portfolio tree rather than
    # re-deriving its arithmetic in the test. That is the expensive choice on purpose --
    # a test that reimplements its subject agrees with itself no matter what the subject
    # does, which is how run_fast_cages came to exist in the first place.
    'run_monitor_integrity_tests.ps1',
    # BACKLOG-D31 (2026-07-30): guards the design<->schema seam that produced every
    # regression across three blind audits of the Factory OS design. The suite it wraps does
    # not check that the design is well-formed -- it re-applies each of the 7 REGRESSED
    # findings as a schema mutation and asserts the binding goes red, which the previous
    # checker did for 0 of 7. Three controls prove it is not simply always red.
    #
    # MEASURED 0.4s when added. The tier total recorded here at the time was 13.3s; it was
    # RE-MEASURED at 14.7s on 2026-07-30 before ORDER-601 part 2 touched anything, so the
    # earlier figure had drifted by 1.4s -- a per-suite time is stable, a TIER TOTAL is not,
    # and the handoff that carried "14.0s" forward was quoting a number nobody had re-run.
    # Re-measure before spending headroom; do not quote this comment as evidence.
    #
    # ORDER-601 part 2 (2026-07-30) added a THIRD python script to this wrapper --
    # run_snapshot_validator_tests.py, the snapshot verdict's computation + mutation suite --
    # instead of adding a 13th PowerShell suite, which at 0.3s of process startup alone would
    # have breached the budget outright. MEASURED marginal cost: this suite 0.4s -> 0.4-0.5s,
    # tier 14.5s and 13.9s over two consecutive runs. So the whole computation suite cost about
    # 0.1s, because the expensive part of a suite here is the process, not the assertions.
    # THAT is the displacement lesson, and it is cheaper than displacing anything:
    # a python cage belongs in an existing python wrapper unless it needs its own lifecycle.
    'run_contract_binding_tests.ps1',
    # ORDER-612 (S4, 2026-07-31): the READER half of the snapshot boundary -- C3 (a missing /
    # unreadable / stale mandatory source cannot render ALL CLEAR, each observed firing and the
    # fire count printed) and C6 (make_status and the daily digest consume ONLY a validated
    # snapshot). The python half of S4 went into run_contract_binding_tests.ps1's wrapper, per
    # this file's own rule that a python cage belongs in an existing python wrapper.
    #
    # MEASURED 5.3-5.9s (5.9 / 5.7 / 5.8 standalone, 5.3 inside the tier), and it is DECLARED
    # rather than glossed: this file says the next addition has
    # to displace something. Nothing is displaced, and the honest reason is that per-path selection
    # landed in between -- this suite runs only when a snapshot path is staged.
    #
    # THE FULL-TIER NUMBER, RE-MEASURED RATHER THAN PROJECTED. The first draft of this comment
    # said "roughly 22.7s", arrived at by adding 4.6s to the 18.1s recorded above. That was wrong,
    # and it was wrong in the way this file already warns about two comments up ("a per-suite time
    # is stable, a TIER TOTAL is not"). The actual full-tier run on 2026-07-31, all 13 suites,
    # 0 failed:
    #     39.6s / 41.1s / 38.8s  -> MEDIAN 39.6s, three consecutive runs, all 13 suites, 0 failed
    #              = optimize-guard 5.3 + monitor-integrity 9.1 + contract-binding 9.1
    #              + snapshot-s4 5.3 + guard-trigger 5.4 + the seven small ones ~3.1
    #     (A single run said 37.7s earlier in the same session. This file's own rule two comments
    #      up is "quote a MEDIAN of at least three runs, never one run", and the first draft of
    #      this note broke it. Three runs span 2.3s, which is why the rule exists.)
    # Two of those grew in THIS order and neither is the new suite:
    #   monitor-integrity  1.5s -> 8.9s  its 8 built coverage fixtures now go through
    #                                    snapshot_build.py instead of being hand-authored, because
    #                                    a hand-typed `verdict` is the attack the slice refuses.
    #                                    (8 = 10 .json fixtures minus the 2 RAW ones that exist to
    #                                    test the reader's failure paths. COUNTED, not recalled --
    #                                    the first draft of this line said 9.)
    #   contract-binding   ~4s  -> 8.8s  it gained run_snapshot_s4_tests.py (0.35s) and pays for
    #                                    the schema growing.
    # The cost is ajv process startup (~0.4s x 2 per built fixture), not assertions, and it cannot
    # be bought back without skipping the schema gate -- which is the exact hole Codex audit 6
    # closed. So: 37.7s against a 15.0s ADVISORY budget, up from 18.1s. It is recorded here as a
    # number somebody must decide about, NOT quietly absorbed, and it is flagged in ORDER-612.
    #
    # WHAT A REAL COMMIT PAYS, also measured rather than reasoned about: staging
    # snapshot_build.py + snapshot_reader.ps1 selects 4 suites and costs 23.7s. Per-path selection
    # is doing its job (4 of 13), and the commits that pay are exactly the ones touching this
    # boundary. Commits elsewhere are unaffected -- the run that landed this order's ledger row
    # selected 1 suite and cost 0.6s.
    #
    # WHY IT IS NOT CHEAPER: 4 of its fixtures are BUILT through snapshot_build.py, each paying a
    # python start plus two ajv subprocesses. Hand-authoring them instead would mean typing the
    # `verdict` by hand -- which is the attack the whole slice exists to refuse, so the cost is
    # the test being real. One ajv pass per build was already removed (build_file now proves the
    # write round-tripped instead of re-deriving the same verdict), which bought 1.0s (5.6s ->
    # 4.6s, measured either side). It then grew back to ~5.8s when rounds 1 and 2 of the
    # self-review added two more built fixtures and a stub-root case.
    'run_snapshot_s4_tests.ps1',
    # BACKLOG-D32 (2026-07-30): guards the trigger that decides whether this whole tier runs.
    # It is last on purpose -- if the declarations and the generated pathspec have drifted,
    # everything above it may have been enforced on a lie.
    # MEASURED 1.4s (2.1s in its first form; collapsing ~25 git spawns into 3 bought 0.7s).
    'run_guard_trigger_tests.ps1'
)

# ---------------------------------------------------------------------------------------
# BACKLOG-D32 -- what each suite GUARDS, declared here rather than guessed by a path glob.
#
# WHY THIS EXISTS. The pre-commit hook decided whether to run this tier by matching staged
# files against a hand-enumerated list of directories that HAPPENED to hold guarded files.
# Five times in four days a new suite guarded something no glob matched, so the suite ran
# only when an unrelated file was staged alongside -- it looked enforced and was not. The
# ORDER-500 comment in .githooks/pre-commit predicted the recurrence in writing, twice.
#
# The trigger pathspec is now GENERATED from this table by scripts/gen_fast_tier_pathspec.ps1.
# What that buys, precisely: you cannot add a suite without declaring its inputs, because
# run_guard_trigger_tests.ps1 fails when the key sets of $FAST_SUITES and $SUITE_GUARDS
# differ. What it does NOT buy on its own: a declaration that lists three of four inputs is
# still wrong -- which is why that cage also sweeps each suite's sources for repo paths it
# references but does not declare, and NotADependency below is the only way to be silent.
#
# Every suite implicitly guards itself, this file, and the hook; the generator adds those.
$SUITE_GUARDS = @{
    'run_statusclass_tests.ps1'       = @('scripts/check_taskboard_archive.ps1')
    'run_order_collision_tests.ps1'   = @('scripts/check_order_collision.ps1', 'docs/SESSION_LEDGER.md')
    'run_handoff_contract_tests.ps1'  = @('scripts/check_handoff_contract.ps1')
    'run_blobmap_encoding_tests.ps1'  = @('scripts/check_taskboard_archive.ps1')
    'run_mris_asof_tests.ps1'         = @('scripts/mris/mris_macro_feeder.ps1',
                                          'scripts/mris/mris_crisis_models.ps1',
                                          'scripts/mris/mris_web_feeder.ps1')
    # B1_DATASET.csv was missing from this list until the PART 4 sweep in
    # run_guard_trigger_tests.ps1 named it on its first run -- a declaration listing three of
    # four inputs, which is precisely what the key-set check cannot see.
    'run_b1_guard_tests.ps1'          = @('scripts/lib/b1_guard.ps1',
                                          'scripts/check_precommit_staged.ps1',
                                          '.githooks/commit-msg',
                                          'docs/memory_control/B1_DATASET.csv')
    # PART 5 sweeps EVERY scripts/*.ps1 for the "the .htm exists, so this run wrote it"
    # shape, so the whole directory is genuinely its input, not just the library.
    'run_report_freshness_tests.ps1'  = @('scripts/lib/report_freshness.ps1', 'scripts/*.ps1')
    'run_truncation_message_tests.ps1' = @('scripts/check_truncated_run.ps1')
    # The three docs are read by the real optimize_guard, which this suite executes. None of
    # them matched any glob before 2026-07-30 (audit 5 measured it).
    'run_optimize_guard_tests.ps1'    = @('scripts/optimize_guard.ps1',
                                          'docs/PARAM_REGISTRY.csv',
                                          'docs/PARAM_LINKAGE.md',
                                          '_triage/PARAM_INACTIVE_AUDIT.md')
    'run_monitor_integrity_tests.ps1' = @('scripts/daily_monitor.ps1',
                                          'scripts/live_dashboard.ps1',
                                          'scripts/control_room_snapshot.ps1',
                                          'scripts/monitor_rotation.ps1',
                                          'scripts/lib/monitor_coverage.ps1',
                                          # ORDER-612 (S4): monitor_coverage now obtains the
                                          # snapshot through this library, so editing the reader
                                          # changes what this cage tests.
                                          'scripts/lib/snapshot_reader.ps1',
                                          '_triage/factory_os/snapshot_build.py',
                                          '_triage/factory_os/snapshot_validator.py')
    # ORDER-612 (S4). Its fixtures are built by snapshot_build.py through the real schema, and the
    # two readers it asserts on are make_status's renderer and the daily digest -- so all of those
    # are its inputs. A cage whose own inputs are outside the pathspec is enforced only when
    # something else happens to be staged, which is the D32 defect this map exists to end.
    'run_snapshot_s4_tests.ps1'       = @('_triage/factory_os/snapshot_build.py',
                                          '_triage/factory_os/snapshot_validator.py',
                                          '_triage/factory_os/run_snapshot_s4_tests.py',
                                          '_triage/factory_os/schemas.json',
                                          'scripts/lib/snapshot_reader.ps1',
                                          'scripts/lib/monitor_coverage.ps1',
                                          'scripts/make_status.ps1',
                                          'scripts/control_room_snapshot.ps1',
                                          'portfolio/control_room_snapshot.json')
    # ORDER-601 part 2 added the snapshot validator and its computation suite to this wrapper
    # rather than to a suite of its own (the budget note in that file explains the trade), so
    # both files are inputs to it. Declaring them is what puts them in the trigger pathspec --
    # without these two lines the cage would run only when something ELSE it guards was staged,
    # which is the exact five-times-in-four-days failure BACKLOG-D32 exists to end.
    'run_contract_binding_tests.ps1'  = @('_triage/factory_os/gen_design_contracts.py',
                                          '_triage/factory_os/run_contract_binding_tests.py',
                                          '_triage/factory_os/snapshot_validator.py',
                                          '_triage/factory_os/run_snapshot_validator_tests.py',
                                          # ORDER-612 (S4): run_snapshot_s4_tests.py joins this
                                          # wrapper (MEASURED 0.35s) instead of becoming a 13th
                                          # PowerShell suite, per the trade recorded above.
                                          '_triage/factory_os/snapshot_build.py',
                                          '_triage/factory_os/run_snapshot_s4_tests.py',
                                          '_triage/factory_os/check_schema_structure.py',
                                          # ORDER-601 closure: proves the PLANNED/BUILT/WIRED
                                          # enforcement labels are verified against the repo rather
                                          # than merely declared.
                                          '_triage/factory_os/run_enforcement_status_tests.py',
                                          '_triage/factory_os/schemas.json',
                                          # The generated tables moved out of the design into
                                          # CONTRACTS.md; the design is still an input because
                                          # --check refuses when it stops linking a contract.
                                          '_triage/factory_os/CONTRACTS.md',
                                          '_triage/EA_LAB_FACTORY_OS_DESIGN.md',
                                          # ORDER-600 (S2a). Declared here so that editing the
                                          # migration table or its checker TRIGGERS the tier that
                                          # guards them -- a cage whose own inputs are outside the
                                          # pathspec is enforced only when something else happens
                                          # to be staged, which is the D32 defect this map exists
                                          # to close.
                                          '_triage/factory_os/run_s2a_gate.py',
                                          '_triage/factory_os/check_s2a_migration.py',
                                          '_triage/factory_os/run_s2a_migration_tests.py',
                                          '_triage/factory_os/gen_s2a_migration.py',
                                          '_triage/factory_os/gen_s2a_migration_doc.py',
                                          '_triage/factory_os/s2a_migration.jsonl',
                                          '_triage/factory_os/s2a_coverage_reconciliation.json',
                                          '_triage/factory_os/S2A_OWNERSHIP_MIGRATION.md',
                                          # ORDER-602 A: the sign-off log and its checker. The log is
                                          # the file the OWNER edits, so an edit to it must trigger
                                          # the tier that validates it.
                                          '_triage/factory_os/check_s2a_attestation.py',
                                          '_triage/factory_os/run_s2a_attestation_tests.py',
                                          '_triage/factory_os/s2a_attestations.jsonl',
                                          # ORDER-610 (S2): the Coverage transfer. coverage.jsonl is
                                          # now the CANONICAL owner of section 2, so an edit to it
                                          # must trigger the suite that proves section 2 still
                                          # matches it -- otherwise the store and its projection
                                          # drift apart between commits and the new banner becomes
                                          # a false statement.
                                          # ORDER-611 (S3): the real ajv fixtures, wired now that
                                          # per-path selection exists. schemas.json is already
                                          # declared above; this is the suite that reads it.
                                          '_triage/factory_os/run_schema_fixtures.py',
                                          # ORDER-616: the shape lint reads the checkers
                                          # AND their suites, so both sides are inputs.
                                          '_triage/factory_os/run_guard_shape_lint.py',
                                          'docs/GUARD_SHAPES.md',
                                          '_triage/factory_os/gen_coverage.py',
                                          '_triage/factory_os/check_coverage_transfer.py',
                                          '_triage/factory_os/run_coverage_transfer_tests.py',
                                          'factory/coverage.jsonl',
                                          # D1's coverage numbers are RECOMPUTED from section 2 of
                                          # this file, so a change to it can falsify C8. Since
                                          # ORDER-610 it is ALSO the generated projection, so a
                                          # hand edit to it must trigger the same tier.
                                          'MASTER_BACKLOG.md')
    'run_guard_trigger_tests.ps1'     = @('scripts/gen_fast_tier_pathspec.ps1',
                                          '.githooks/fast_tier_pathspec',
                                          'scripts/_test/run_fast_cages.ps1')
}

# Paths a suite references but which are NOT inputs to what it guards -- synthetic fixture
# names, its own temp files. Listing one here is a deliberate, reviewable act; the sweep in
# run_guard_trigger_tests.ps1 has no other way to be quiet.
$NOT_A_DEPENDENCY = @(
    'scripts/foo.ps1',                              # synthetic name in a collision fixture
    'docs/UNOWNED.md',                              # ditto
    'scripts/scripts/check_taskboard_archive.ps1',  # a doubled prefix inside a fixture string
    'scripts/tests/test_runner_output_capture.ps1', # named in prose; the suite does not run it
    'tools/python312/python.exe',                   # interpreter, not an edited input
    # ORDER-612 (S4): run_snapshot_s4_tests.ps1 names run_schema_fixtures.py in its header to say
    # WHERE C1 is asserted (there, not here). It does not run it, and editing it cannot change
    # what this suite proves. A cross-reference is not a dependency, and being forced to say so
    # here is the sweep doing its job.
    '_triage/factory_os/run_schema_fixtures.py',
    # Same shape, other direction: run_contract_binding_tests.ps1 names the S4 PowerShell suite in
    # a comment to say where C3/C6 are asserted. It is a sibling, not an input.
    'scripts/_test/run_snapshot_s4_tests.ps1'
)

if ($ExportGuards) {
    # Machine-readable export so the generator and the cage read THIS table rather than
    # re-typing it. Two copies of a dependency list is the defect one directory over.
    [pscustomobject]@{
        Suites         = $FAST_SUITES
        Guards         = $SUITE_GUARDS
        NotADependency = $NOT_A_DEPENDENCY
    } | ConvertTo-Json -Depth 5
    exit 0
}

# ---------------------------------------------------------------------------------------
# BACKLOG-D32 -- per-path suite selection.
#
# The tier is all-or-nothing today: any staged path matching the generated pathspec runs
# every suite, so a schema edit pays 5.7s of optimize-guard cases and an optimize_guard.ps1
# edit pays 3.6s of S2a. MEASURED 2026-07-31: 18.1s against a 15.0s advisory budget, which is
# 3.1s over and more than any single addition accounts for.
#
# SAFETY RULES, because this is the pre-commit TRIGGER and getting it wrong means guards stop
# running while everything still looks green -- the worst failure this repo has:
#   1. FAIL-OPEN. A suite with no declared guards ALWAYS runs. Adding a suite and forgetting
#      its $SUITE_GUARDS entry must cost time, never coverage.
#   2. No -StagedPaths given -> run EVERYTHING. Manual runs and the -Audit path are unchanged.
#   3. If the caller cannot determine staged paths, it must pass none, which means everything.
# So every failure mode of this feature runs MORE than necessary, never less.
function Select-Suites {
    param([string[]]$Suites, [hashtable]$Guards, [string[]]$Staged)
    if (-not $Staged -or $Staged.Count -eq 0) { return $Suites }
    $picked = New-Object System.Collections.Generic.List[string]
    foreach ($s in $Suites) {
        $g = $Guards[$s]
        if (-not $g -or $g.Count -eq 0) { $picked.Add($s); continue }   # rule 1: fail-open
        $hit = $false
        foreach ($pattern in $g) {
            foreach ($p in $Staged) {
                if ($p -eq $pattern -or $p -like $pattern -or $p -like "$pattern*") { $hit = $true; break }
            }
            if ($hit) { break }
        }
        if ($hit) { $picked.Add($s) }
    }
    # RULE 4, and the one that actually caught a live defect. The pathspec is GENERATED from these
    # same guards, so a staged path that reached this script is guarded by at least one suite by
    # construction. "Staged paths given, nothing selected" is therefore a CONTRADICTION -- it means
    # the list arrived mangled, or the guards and the pathspec have drifted apart. Either way the
    # honest response is to run everything, not nothing.
    # This is not hypothetical: the first version of this feature passed the paths as one
    # comma-joined string, PowerShell -File bound it as a single literal for three paths (though it
    # split correctly for two), and the commit that introduced per-path selection ran ZERO suites
    # while printing a confident selection message. It failed CLOSED while its own comment claimed
    # it could only fail open.
    if ($picked.Count -eq 0) {
        Write-Host ('[fast-cages] {0} staged path(s) matched NO suite -- that cannot happen if the ' -f $Staged.Count) -ForegroundColor Yellow
        Write-Host '             pathspec and $SUITE_GUARDS agree, so the list is suspect. Running everything.' -ForegroundColor Yellow
        return $Suites
    }
    return $picked.ToArray()
}

if ($StagedPathsFile -and (Test-Path -LiteralPath $StagedPathsFile)) {
    $StagedPaths = @(Get-Content -LiteralPath $StagedPathsFile | ForEach-Object { $_.Trim() } |
                     Where-Object { $_ })
}

if ($ExportSelection) {
    # Used by run_guard_trigger_tests.ps1 to assert the selection without running any suite.
    (Select-Suites -Suites $FAST_SUITES -Guards $SUITE_GUARDS -Staged $StagedPaths) | ForEach-Object { $_ }
    exit 0
}

$selected = Select-Suites -Suites $FAST_SUITES -Guards $SUITE_GUARDS -Staged $StagedPaths

$ps = (Get-Process -Id $PID).Path
if (-not $ps) { $ps = 'powershell.exe' }

if ($StagedPaths -and $StagedPaths.Count -gt 0 -and $selected.Count -lt $FAST_SUITES.Count) {
    Write-Host ('[fast-cages] per-path selection: {0} of {1} suite(s) guard something staged' -f `
                $selected.Count, $FAST_SUITES.Count)
    # Name what is being SKIPPED. A tier that quietly runs less is indistinguishable from a
    # tier that is broken, and this repo has been burned by exactly that shape.
    $skipped = $FAST_SUITES | Where-Object { $selected -notcontains $_ }
    Write-Host ('[fast-cages] skipped (nothing they guard is staged): {0}' -f ($skipped -join ', '))
}

Write-Host '[fast-cages] running the cages that guard the guards'

$results = New-Object System.Collections.Generic.List[object]
$total = 0.0

foreach ($suite in $selected) {
    $path = Join-Path $testDir $suite
    if (-not (Test-Path -LiteralPath $path)) {
        # A missing suite is a failure, not a skip. Silently passing over a cage that was
        # deleted or renamed is precisely how a cage stops existing without anyone noticing.
        Write-Host ("  MISSING {0}" -f $suite) -ForegroundColor Red
        $results.Add([pscustomobject]@{ Suite = $suite; Exit = 127; Seconds = 0.0; Output = 'suite file not found' })
        continue
    }

    $sw = [Diagnostics.Stopwatch]::StartNew()
    $out = & $ps -NoProfile -ExecutionPolicy Bypass -File $path 2>&1
    $code = $LASTEXITCODE
    $sw.Stop()
    $total += $sw.Elapsed.TotalSeconds

    $results.Add([pscustomobject]@{
        Suite   = $suite
        Exit    = $code
        Seconds = $sw.Elapsed.TotalSeconds
        Output  = ($out | Out-String)
    })

    if ($code -eq 0) {
        Write-Host ("  ok   {0,-34} {1,5:N1}s" -f $suite, $sw.Elapsed.TotalSeconds)
    } else {
        Write-Host ("  FAIL {0,-34} {1,5:N1}s (exit {2})" -f $suite, $sw.Elapsed.TotalSeconds, $code) -ForegroundColor Red
    }
}

$failed = @($results | Where-Object { $_.Exit -ne 0 })

# Print the full output of failures only. A hook that prints 60 lines of green on every
# commit trains people to stop reading it.
foreach ($f in $failed) {
    Write-Host ''
    Write-Host ("---- {0} (exit {1}) ----" -f $f.Suite, $f.Exit) -ForegroundColor Red
    Write-Host $f.Output
}

Write-Host ''
Write-Host ("[fast-cages] {0} suite(s), {1} failed, {2:N1}s total" -f $results.Count, $failed.Count, $total)

if ($total -gt $BudgetSeconds) {
    Write-Host ("[fast-cages] WARNING: {0:N1}s exceeds the {1:N1}s budget for a pre-commit tier. Move the slowest suite out, or raise the budget deliberately -- do not let this drift until someone reaches for --no-verify." -f $total, $BudgetSeconds) -ForegroundColor Yellow
}

if ($failed.Count -gt 0) { exit 1 }
exit 0
