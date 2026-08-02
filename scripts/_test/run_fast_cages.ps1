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
    # ORDER-673. TWO budgets, because they are two different claims, and both are ENFORCED --
    # over budget FAILS the tier, it does not print a warning and exit 0.
    #
    # MEASURED 2026-07-31 by the lane that wrote these numbers, not quoted from an older row:
    #   full tier, five clean runs   65.8 / 64.8 / 64.7 / 64.7 / 64.7  -> median 64.7s
    #   per-path, realistic commits  ledger 0.7s - the tier itself 18.7s -
    #                                factory_os python 22.6s - schemas.json 24.8s
    # The ORDER-673 row said 39.4s. That was true when it was written and is now stale by 25s,
    # which is the whole argument for N1: the number has to come from a command run in the
    # session that writes it, or it is a claim about a machine nobody measured today.
    #
    # WHAT IS BEING ACCEPTED (N4), stated rather than left implicit: the next cage added to this
    # tier has to DISPLACE something. There is ~5s of per-path headroom and ~10s of full-tier
    # headroom, and after that a new suite is a trade, not an addition. That is the point of a
    # budget -- an unenforced one has infinite headroom and therefore says nothing.
    #
    # 🔴 RAISED 75.0 -> 90.0 THE SAME DAY, DELIBERATELY, AND THE REASON IS NOT VARIANCE.
    # The 75.0 fired for real on the next full run (77.4s), and the first reading was "load
    # noise". Three consecutive runs then measured 76.7 / 76.8 / 76.9 -- a 0.2s spread. That is
    # not noise, it is GROWTH, and it is growth this session caused:
    #     run_guard_trigger_tests  17.4 -> 22.4  (+5.0)  ORDER-702 PART 4b import closure,
    #                                                    ORDER-673 PART 7 budget cases
    #     run_contract_binding     19.2 -> 22.7  (+3.5)
    #     run_monitor_integrity     9.3 -> 10.4  (+1.1)
    #     run_preset_tests            -  ->  0.4  (new, ORDER-702)
    #     the remaining eleven                    (+2.4)
    # So the budget did exactly what N4 said it would: cages were added and it demanded a trade.
    # The trade taken is the number, not a suite -- the FULL tier only runs on fail-open (nothing
    # staged, or a path list that matched nothing), while the 30.0s PER-PATH budget is what a real
    # commit pays and is the one that actually prevents --no-verify. That one is untouched.
    # Headroom after this: ~13s full, ~5-8s per-path. The next cage is still a trade.
    #
    # 🔴 PER-PATH RAISED 30.0 -> 65.0, and it blocked its OWN AUTHOR'S COMMIT to earn it.
    # The 30.0 came from single-file measurements (ledger 0.7s, evidence.py 23.4s, schemas.json
    # 24.8s). A commit touching FOUR guarded files selects SIX suites and costs 60.7s -- and the
    # first real multi-file commit after the number was set was refused by it. That is the budget
    # working, and it is also the number being wrong: per-path cost scales with how many suites
    # the staged set selects, so a bound derived from one-file commits describes a case that is
    # not the common one here.
    # 65.0 sits above the measured 60.7s worst realistic selection and below the 90.0s full tier,
    # so both remain enforceable and growth still trips them.
    # NOT FIXED, and stated rather than absorbed: 60s IS slow for a hook. Raising the ceiling
    # buys honesty, not speed -- two suites are 39s of it. Making them faster is its own order.
    [double]$BudgetSeconds = 65.0,
    [double]$FullTierBudgetSeconds = 90.0,
    # N2's negative needs a way to be over budget without waiting for a suite to genuinely rot.
    # Same shape as -DebugPretendIndexMoved below: a seam the cage drives, never the hook.
    [double]$DebugPadSeconds = 0.0,
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
    [switch]$ExportSelection,
    # ORDER-670: THIS RUN IS A PRE-COMMIT HOOK. An ARGUMENT, not an env var, and passed by
    # .githooks/pre-commit at BOTH call sites including the fail-closed branch -- an argument
    # cannot fail to arrive from a caller that is one file with two lines. Given -Hook, this
    # tier is the ONE setter of EA_LAB_EVIDENCE=index for its children, and it verifies the
    # mode ARRIVED via one structured marker per evidence suite (an ALLOWLIST: missing fails,
    # wrong fails, duplicated fails; prose containing the word 'worktree' cannot forge one).
    [switch]$Hook,
    # test override for the marker allowlist (see $EVIDENCE_SUITES). $null = use the real
    # list. A single element 'NONE' means "empty list" -- `powershell -File` cannot pass @()
    # (it binds as a missing argument) and a bare '-' binds as a parameter name, so the
    # empty case needs a spelled sentinel.
    [string[]]$EvidenceSuitesOverride = $null,
    # test-only: force the end-of-run index-movement stamp to mismatch, so the T6 refusal
    # path can be OBSERVED RED (a detector nobody has seen fire is UNTESTED, per the
    # VERDICT GATE's own guard rule).
    [switch]$DebugPretendIndexMoved
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
    #     38.1 / 38.8 / 39.4 / 39.6 / 41.1  -> MEDIAN 39.4s, five clean full-tier runs, 0 failed
    #     (An earlier draft of this line said "39.6s, three consecutive runs" quoting
    #      39.6/41.1/38.8. The median was right; the sentence was not. Two of those came from a
    #      BACKGROUND loop I read before its third run had finished writing, and the third came
    #      from a separate foreground run -- so they were never three consecutive runs of
    #      anything. The loop's own third value, 39.4s, and a fourth run at 38.1s, both landed
    #      after I had already written the comment. All five are listed now. Reading a
    #      background output file before the job ends and quoting it as the job's result is a
    #      shape-4 defect with a new mechanism, and it is recorded here rather than tidied away.)
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
    # ORDER-630 (S5, 2026-07-31): the CONSUMER half of "the generator and optimize_guard provably
    # read ONE resolver". The python half (the resolver's answers, and each of check_registries'
    # five criteria going red) joined run_contract_binding_tests.ps1's wrapper; this proves
    # optimize_guard READS that answer -- a LOCKED binding turns ALLOW into REFUSE, a TUNABLE one
    # does not, and a named revision whose bindings cannot be read FAILS rather than resolving
    # empty. Its load-bearing case is the CONTROL: with no -HypothesisRevision, not one verdict
    # line changes.
    # MEASURED 2.9s standalone. It spawns optimize_guard six times, each a fresh powershell
    # loading the 193-row parameter registry; that is the expensive choice on purpose, because a
    # test that reimplements its subject agrees with itself no matter what the subject does.
    # (The first draft of this line said 8.6s, written before the suite was timed. It is here
    # because guessing a number and labelling it MEASURED is shape 4 in one word.)
    'run_registry_tests.ps1',
    # BACKLOG-D32 (2026-07-30): guards the trigger that decides whether this whole tier runs.
    # It is last on purpose -- if the declarations and the generated pathspec have drifted,
    # everything above it may have been enforced on a lie.
    # MEASURED 1.4s (2.1s in its first form; collapsing ~25 git spawns into 3 bought 0.7s).
    'run_guard_trigger_tests.ps1',
    # ORDER-702, and added on a MEASUREMENT: 0.2s, the cheapest suite here by an order
    # of magnitude. preset.py shipped with 9 criteria x (attack + specificity) + 9
    # mutation probes and NONE of it ran on any commit -- fully tested and completely
    # unguarded at once, which is the same hole evidence.py was in.
    'run_preset_tests.ps1',
    # ORDER-1020 (S7), added on a MEASUREMENT like the one above it: 0.4s in the hook, almost all of which
    # is parsing the real Inputs.mqh once to build the surface its cases attack. It guards the
    # owner-ratified old-.set policy, which until now existed only as a decision in a design
    # document and a module nothing ran.
    'run_setfile_tests.ps1',
    # ORDER-1020 (S7), measured at 1.3s standalone / 0.4s in the hook. It guards the machinery that
    # takes Boss_14 from 116 visible inputs to 38 reachable ones -- the number the Operator
    # surface and the optimizer's allowed dimensions are both derived from.
    'run_activation_tests.ps1',
    # ORDER-1020 (S7), measured at 0.7s through its wrapper. It carries slice S7's own acceptance
    # as criteria that can fail -- zero UNKNOWN on the OPERATOR surface, and design 5.3's <= 40
    # target -- plus the anti-drift criterion that regenerates the 232 rows and compares.
    'run_param_surface_tests.ps1',
    'run_work_receipts_tests.ps1',
    # ORDER-674. Drives the A7 attack against check_state -- the guard the hook runs FIRST,
    # over the live-money inventory. It stages into the REAL index and restores, asserting
    # the restore, so it is last in the list: nothing else should be mid-flight around it.
    'run_front_guard_evidence_tests.ps1'
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
                                          # ORDER-702: DERIVED by the import sweep in
                                          # run_guard_trigger_tests PART 4b, not remembered.
                                          # This suite's python imports it, so a commit
                                          # touching only that module must still run a cage.
                                          '_triage/factory_os/registry.py',
                                          'scripts/live_dashboard.ps1',
                                          'scripts/control_room_snapshot.ps1',
                                          'scripts/monitor_rotation.ps1',
                                          'scripts/lib/monitor_coverage.ps1',
                                          # ORDER-612 (S4): monitor_coverage now obtains the
                                          # snapshot through this library, so editing the reader
                                          # changes what this cage tests.
                                          'scripts/lib/snapshot_reader.ps1',
                                          '_triage/factory_os/snapshot_build.py',
                                          '_triage/factory_os/snapshot_validator.py',
                                          # ORDER-670 T5 (2026-07-31): snapshot_build now calls
                                          # evidence.observe() instead of reimplementing it, so
                                          # this suite's python transitively imports the reader.
                                          '_triage/factory_os/evidence.py')
    # ORDER-612 (S4). Its fixtures are built by snapshot_build.py through the real schema, and the
    # two readers it asserts on are make_status's renderer and the daily digest -- so all of those
    # are its inputs. A cage whose own inputs are outside the pathspec is enforced only when
    # something else happens to be staged, which is the D32 defect this map exists to end.
    # ORDER-630 (S5). The resolver, its guard, the store it reads and the consumer it wires.
    # ORDER-674 owed half: this cage now drives FOUR of the six front guards, not one. The B/C/D
    # cases attack check_order_collision (archive at the index), check_handoff_contract (the
    # same-commit archive move) and check_precommit_staged (the duplicate account|magic rule that
    # matched 0 of 64 rows). DECLARED because PART 4's undeclared-reference sweep demanded them
    # on its first run after those cases landed -- which is the sweep doing exactly its job: the
    # three guard commits before it did not stage the files that select run_guard_trigger_tests,
    # so the omission survived three commits and was caught by the full tier, not by a reviewer.
    'run_front_guard_evidence_tests.ps1' = @('scripts/check_state.ps1',
                                          'scripts/check_order_collision.ps1',
                                          'scripts/check_handoff_contract.ps1',
                                          'scripts/check_precommit_staged.ps1',
                                          'scripts/lib/evidence.ps1',
                                          '.githooks/pre-commit',
                                          'portfolio/DEPLOYMENTS.csv',
                                          # the B and C cases stage into these two boards
                                          'AGENT_TASKBOARD.md',
                                          'ARCHIVE_TASKBOARD_2026-07A.md')
    # ORDER: the S14 Work Receipt grant (AGENTS.md section 2, owner-confirmed 2026-08-01).
    # The GRANT file itself is declared, so widening the permission row cannot land without
    # the cage that enforces the narrow version running in the same commit -- which is the
    # whole reason the grant was allowed to be narrow.
    'run_work_receipts_tests.ps1'     = @('_triage/factory_os/check_work_receipts.py',
                                          '_triage/factory_os/run_work_receipts_tests.py',
                                          'factory/work_receipts.jsonl',
                                          'AGENTS.md',
                                          '_triage/factory_os/evidence.py')
    # ORDER-1020 (S7). The ratified old-.set policy: unknown key => a refusal that NAMES the
    # key, and migration writes a NEW file. The suite builds build-14's surface out of the REAL
    # Inputs.mqh, so an edit there changes what this cage proves, exactly as it does for
    # run_preset_tests below.
    'run_setfile_tests.ps1'           = @('_triage/factory_os/setfile.py',
                                          '_triage/factory_os/run_setfile_tests.py',
                                          '_triage/factory_os/preset.py',
                                          'ea_template/core/Inputs.mqh',
                                          # DEMANDED BY THE IMPORT SWEEP on this suite's FIRST
                                          # run -- reached through preset.py's imports, which a
                                          # path-string sweep of the wrapper cannot see. Same
                                          # two modules, same reason, as run_preset_tests below.
                                          '_triage/factory_os/evidence.py',
                                          '_triage/factory_os/registry.py')
    # ORDER-1020 (S7). The three modules that answer "can this input change anything", plus the
    # two sources they answer it FROM: Inputs.mqh (the surface) and the build wrapper (the
    # chassis version every ModuleUse row records).
    'run_activation_tests.ps1'        = @('_triage/factory_os/activation.py',
                                          '_triage/factory_os/architecture.py',
                                          '_triage/factory_os/capability.py',
                                          '_triage/factory_os/run_activation_tests.py',
                                          '_triage/factory_os/preset.py',
                                          'ea_template/core/Inputs.mqh',
                                          'ea_template/Boss_14_GridLog.mq5',
                                          # DEMANDED BY THE IMPORT SWEEP, reached through
                                          # preset.py -- a path-string sweep cannot see an import.
                                          '_triage/factory_os/evidence.py',
                                          '_triage/factory_os/registry.py')
    'run_preset_tests.ps1'            = @('_triage/factory_os/preset.py',
                                          '_triage/factory_os/run_preset_tests.py',
                                          # the compiler reads the build's input
                                          # surface and the parameter registry, and
                                          # P9 parses the REAL Inputs.mqh -- an edit
                                          # to either changes what this cage proves.
                                          'ea_template/core/Inputs.mqh',
                                          'docs/PARAM_REGISTRY.csv',
                                          'factory/instrument_profiles.jsonl',
                                          # DEMANDED BY THE IMPORT SWEEP on this
                                          # suite's FIRST run, which is the point:
                                          # a brand-new suite cannot forget them.
                                          '_triage/factory_os/evidence.py',
                                          '_triage/factory_os/registry.py')
    # ORDER-1020 (S7). The state table reads BOTH stores, the build's input surface, and every
    # module the generator derives a row from -- P5 regenerates and compares, so an edit to any of
    # them changes what this cage proves.
    'run_param_surface_tests.ps1'     = @('_triage/factory_os/check_param_surface.py',
                                          '_triage/factory_os/run_param_surface_tests.py',
                                          '_triage/factory_os/gen_registry_rows.py',
                                          '_triage/factory_os/hypothesis_b14.py',
                                          '_triage/factory_os/activation.py',
                                          '_triage/factory_os/architecture.py',
                                          '_triage/factory_os/capability.py',
                                          '_triage/factory_os/preset.py',
                                          '_triage/factory_os/registry.py',
                                          '_triage/factory_os/evidence.py',
                                          '_triage/factory_os/gen_s2a_migration.py',
                                          # ...and its own closure, demanded by the sweep on the
                                          # first run. gen_s2a_migration is imported ONLY for
                                          # owner_ref_for -- the one OwnerRef builder in the tree
                                          # -- and it drags two more modules behind it. Declared
                                          # rather than exempted: they genuinely are inputs, and
                                          # a second copy of the pin builder is what the
                                          # alternative would have cost.
                                          '_triage/factory_os/check_s2a_migration.py',
                                          '_triage/factory_os/gen_design_contracts.py',
                                          'ea_template/core/Inputs.mqh',
                                          'ea_template/Boss_14_GridLog.mq5',
                                          'factory/hypotheses.jsonl',
                                          'factory/parameter_bindings.jsonl',
                                          'scripts/param_registry_check.ps1')
    'run_registry_tests.ps1'          = @(
                                          # ORDER-702: DERIVED by the import sweep in
                                          # run_guard_trigger_tests PART 4b, not remembered.
                                          # This suite's python imports it, so a commit
                                          # touching only that module must still run a cage.
                                          '_triage/factory_os/evidence.py',
                                          '_triage/factory_os/run_guard_shape_lint.py',
                                          '_triage/factory_os/gen_coverage.py',
                                          # ...and the next level down: gen_coverage imports this.
                                          # The sweep converges by construction -- every declared
                                          # .py has ITS OWN imports checked, so the transitive
                                          # closure is walked one commit at a time rather than
                                          # assumed complete.
                                          '_triage/factory_os/check_s2a_migration.py',
                                          '_triage/factory_os/gen_design_contracts.py',
                                          '_triage/factory_os/registry.py',
                                          '_triage/factory_os/check_registries.py',
                                          '_triage/factory_os/run_registry_tests.py',
                                          'scripts/optimize_guard.ps1',
                                          # This suite RUNS the real optimize_guard, so the three
                                          # files optimize_guard treats as source of truth are its
                                          # inputs too -- its PRE-CHECK asserts a specific
                                          # parameter is ALLOW, which a registry edit can change.
                                          # Declared rather than exempted: it genuinely is a
                                          # dependency, and the sweep was right to ask.
                                          'docs/PARAM_REGISTRY.csv',
                                          # factory/universe.jsonl is DELIBERATELY absent from
                                          # this list: it is BLOCKED and does not exist (see
                                          # registry.STORES_BLOCKED). Declaring an untracked path
                                          # here made the trigger cage red in both directions,
                                          # which is correct -- a pathspec cannot select a file
                                          # that is not in git. It is added when the block lifts.
                                          # ORDER-1020: the two modules that WRITE the stores this
                                          # suite reads. Neither is imported by the suite, so the
                                          # import sweep cannot demand them -- and that is exactly
                                          # the ORDER-702 hole: a commit editing only the decision
                                          # table would change every binding row and run no cage.
                                          # The suite's PRE-CHECK ("this parameter is ALLOW", "the
                                          # canonical store binds nothing under $rev") is what a
                                          # decision-table edit can silently falsify.
                                          '_triage/factory_os/hypothesis_b14.py',
                                          '_triage/factory_os/gen_registry_rows.py',
                                          # ...and the next level down, DEMANDED BY THE SWEEP on
                                          # the first run after the two above were declared. The
                                          # generator derives every row's reachability from these,
                                          # so an edit to any of them changes what the stores
                                          # contain without touching either module named above.
                                          '_triage/factory_os/activation.py',
                                          '_triage/factory_os/architecture.py',
                                          '_triage/factory_os/capability.py',
                                          '_triage/factory_os/preset.py',
                                          '_triage/factory_os/gen_s2a_migration.py',
                                          'factory/instrument_profiles.jsonl',
                                          'factory/hypotheses.jsonl',
                                          'factory/parameter_bindings.jsonl',
                                          'factory/coverage.jsonl')
    'run_snapshot_s4_tests.ps1'       = @(
                                          # ORDER-702: DERIVED by the import sweep in
                                          # run_guard_trigger_tests PART 4b, not remembered.
                                          # This suite's python imports it, so a commit
                                          # touching only that module must still run a cage.
                                          '_triage/factory_os/registry.py',
'_triage/factory_os/snapshot_build.py',
                                          '_triage/factory_os/snapshot_validator.py',
                                          '_triage/factory_os/run_snapshot_s4_tests.py',
                                          # ORDER-670 T5 (2026-07-31): both snapshot_build and
                                          # this suite's own test file now import evidence
                                          # (snapshot_build calls observe(); the suite drives it
                                          # directly for the S3 behavioural race case).
                                          '_triage/factory_os/evidence.py',
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
    'run_contract_binding_tests.ps1'  = @(
                                          # ORDER-702: DERIVED by the import sweep in
                                          # run_guard_trigger_tests PART 4b, not remembered.
                                          # This suite's python imports it, so a commit
                                          # touching only that module must still run a cage.
                                          '_triage/factory_os/evidence.py',
'_triage/factory_os/gen_design_contracts.py',
                                          '_triage/factory_os/run_contract_binding_tests.py',
                                          '_triage/factory_os/snapshot_validator.py',
                                          '_triage/factory_os/run_snapshot_validator_tests.py',
                                          # ORDER-612 (S4): run_snapshot_s4_tests.py joins this
                                          # wrapper (MEASURED 0.35s) instead of becoming a 13th
                                          # PowerShell suite, per the trade recorded above.
                                          '_triage/factory_os/snapshot_build.py',
                                          '_triage/factory_os/run_snapshot_s4_tests.py',
                                          # ORDER-630 (S5): the python half, same trade.
                                          '_triage/factory_os/registry.py',
                                          '_triage/factory_os/check_registries.py',
                                          '_triage/factory_os/run_registry_tests.py',
                                          # BLIND AUDIT round 4, and the strongest finding of the
                                          # batch: run_schema_fixtures.py validates every LIVE
                                          # registry row against its entity with ajv, and it runs
                                          # inside THIS wrapper -- but staging
                                          # factory/instrument_profiles.jsonl selected only
                                          # run_registry_tests.ps1. The checker existed, worked,
                                          # and was not on the commit path of the file it governs.
                                          # A guard that the governed input does not trigger is a
                                          # guard that runs when something ELSE is staged, which is
                                          # the exact five-times-in-four-days failure BACKLOG-D32
                                          # exists to end -- reappearing one layer up.
                                          'factory/coverage.jsonl',
                                          'factory/hypotheses.jsonl',
                                          'factory/instrument_profiles.jsonl',
                                          'factory/parameter_bindings.jsonl',
                                          '_triage/factory_os/run_schema_fixtures.py',
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
                                          # ORDER-731: the FRONT guard that predicts F5/F11 at
                                          # the index, and its cage. The guard runs from
                                          # .githooks/pre-commit rather than here -- a suite
                                          # cannot refuse a commit -- so the only thing that
                                          # makes editing it trigger a cage is this declaration.
                                          # ConfigFingerprint.mqh (ORDER-710) is the receipt for
                                          # what happens without one: a file holding half a
                                          # contract, guarded by nothing, matching no suite.
                                          '_triage/factory_os/check_attested_pin_staged.py',
                                          '_triage/factory_os/run_attested_pin_staged_tests.py',
                                          # ORDER-614 rev 2: the bound policy, the frozen corpus,
                                          # and the conformance runner that holds the (now
                                          # bundle-free) implementation to them. Editing ANY of
                                          # the three must trigger the tier -- an unwatched
                                          # corpus is an unbound policy.
                                          '_triage/factory_os/S2A_ATTESTATION_POLICY.md',
                                          '_triage/factory_os/S2A_ATTESTATION_VECTORS.jsonl',
                                          '_triage/factory_os/run_s2a_conformance.py',
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
                                          # ORDER-674 owed half: L3 now READS the PowerShell
                                          # checkers, so editing one changes what this suite
                                          # proves. Declared as a glob because L0 discovers them
                                          # by glob -- a hand-typed list of eleven filenames is
                                          # the hand-maintained cache L0 exists to refuse, and
                                          # the twelfth checker would be enforced only when
                                          # something else happened to be staged (D32).
                                          'scripts/check_*.ps1',
                                          'docs/GUARD_SHAPES.md',
                                          '_triage/factory_os/gen_coverage.py',
                                          '_triage/factory_os/check_coverage_transfer.py',
                                          '_triage/factory_os/run_coverage_transfer_tests.py',
                                          'factory/coverage.jsonl',
                                          # D1's coverage numbers are RECOMPUTED from section 2 of
                                          # this file, so a change to it can falsify C8. Since
                                          # ORDER-610 it is ALSO the generated projection, so a
                                          # hand edit to it must trigger the same tier.
                                          'MASTER_BACKLOG.md',
                                          # ORDER-710 ([CFG] fingerprint). The generated
                                          # enumeration is a COPY of Inputs.mqh, so the file it
                                          # copies FROM has to be on this list or the staleness
                                          # guard fires only when something else is staged --
                                          # and the one commit it exists to refuse is exactly
                                          # the one that touches Inputs.mqh alone.
                                          # ea_template/core/Inputs.mqh is already declared by
                                          # run_preset_tests.ps1; it is repeated here because a
                                          # declaration is per-suite and this suite reads it too.
                                          'ea_template/core/Inputs.mqh',
                                          'ea_template/core/InputSurface_gen.mqh',
                                          # /scrutinize round 1: this file was in NEITHER this
                                          # list NOR the generated pathspec, so a commit editing
                                          # ONLY it ran zero cages and did not even trigger the
                                          # tier -- and it holds the entire MQL5 half of the
                                          # cross-language contract (CFG_FP_SCOPE, the lowercase
                                          # hex alphabet, CryptEncode). Measured with
                                          # -ExportSelection before declaring. The G3 criterion
                                          # added in the same round is what now READS it.
                                          # NOTE the sweep did not demand this: PART 4 sweeps a
                                          # suite's own sources for repo paths and PART 4b walks
                                          # the import closure for MODULES -- a path referenced
                                          # by an imported module is in neither. ORDER-732.
                                          'ea_template/core/ConfigFingerprint.mqh',
                                          # LabCore is where G2 checks the enumeration is wired
                                          # in at all: commenting the include out is a silent
                                          # loss of the whole fingerprint line.
                                          'ea_template/core/LabCore.mqh',
                                          '_triage/factory_os/gen_input_surface.py',
                                          # ORDER-730: the constant half. The generated
                                          # enumeration and the generator that emits it are
                                          # both judged inputs of G4/G5, and the wrappers are
                                          # where the include closure STARTS.
                                          'ea_template/core/LockedConstants_gen.mqh',
                                          '_triage/factory_os/gen_locked_constants.py',
                                          '_triage/factory_os/check_input_surface_gen.py',
                                          '_triage/factory_os/run_input_surface_tests.py',
                                          # DEMANDED BY THE IMPORT SWEEP (PART 4b) on its first
                                          # run after the two entries above landed: both the
                                          # generator and the cage import preset.py for the ONE
                                          # surface parser, so a commit touching only that
                                          # module must still run this cage. The wrapper's
                                          # path-string sweep cannot see an `import`.
                                          '_triage/factory_os/preset.py',
                                          # ORDER-710's evidence tool. Not run by any suite (it
                                          # costs two tester runs), but the guard-shape lint
                                          # parses it, and that lint runs in this wrapper.
                                          '_triage/factory_os/gen_default_preset.py')
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
    'scripts/_test/run_snapshot_s4_tests.ps1',
    # ORDER-630 round 4: run_registry_tests.ps1 names docs/PARAM_LINKAGE.md as the UNRELATED path
    # in its per-path-selection specificity case ("an unrelated path does not select this suite").
    # It is the opposite of a dependency -- the case only means anything BECAUSE nothing here
    # guards it. Declaring it as an input would make the assertion false.
    'docs/PARAM_LINKAGE.md',
    # ORDER-670: run_guard_trigger_tests.ps1 PART 6 stages this path IN A FIXTURE because it
    # selects three sub-second suites, making the nested hook-mode tier runs cheap. The suite
    # never reads or runs the file; it is a selection key, not an input.
    'scripts/check_taskboard_archive.ps1',
    # ORDER-673: same shape one part down. PART 7 stages this path so the nested budget runs
    # select ONE 0.6s suite -- the cheapest way to exercise an over-budget refusal without
    # waiting for a real 30s run. A selection key, not an input. (PART 4 refused the commit
    # that added it until this line existed, which is the sweep working: the reference is
    # real, and saying "not a dependency" out loud is the price of it being benign.)
    'docs/SESSION_LEDGER.md'
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
        # RULE 0 -- A SUITE GUARDS ITSELF. The pathspec generator has always said so ("every suite
        # implicitly guards itself, the runner and the hooks") and added `scripts/_test/*` to the
        # TRIGGER, so editing a suite has always run the tier. It did not run THAT suite: selection
        # matched only $SUITE_GUARDS, which never lists the suite's own file. Measured 2026-08-01
        # by staging run_front_guard_evidence_tests.ps1 alone -- the tier ran two OTHER suites and
        # skipped the one being edited, while the comment above the table said otherwise. That is
        # ORDER-420's own finding ("the tests for those guards ran on nothing") reappearing in the
        # mechanism written to fix it, and it is the shape where it hurts most: the edit that
        # breaks a cage is the edit its cage does not run.
        if ($Staged -contains ('scripts/_test/' + $s)) { $picked.Add($s); continue }
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

# ORDER-670: suites that have MIGRATED to the evidence reader. Each must emit exactly one
# `##EVIDENCE-MODE## <suite-name> <mode> ...` line, produced by running evidence.for_run()
# in the suite's own process chain -- so a marker proves ARRIVAL through hook -> tier ->
# suite -> python, not what a wrapper believes. Grows one entry per migrated suite
# (TIER_SNAPSHOT_DESIGN.md section 6); when all 14 are here, the list dissolves into
# "every selected suite".
$EVIDENCE_SUITES = @('run_registry_tests.ps1',
                     # Round-2 review, M3: check_work_receipts judges the STAGED bytes, and
                     # nothing verified the mode arrived. Probed: the same staged tamper exits
                     # 1 with EA_LAB_EVIDENCE=index and 0 with it unset -- the guard silently
                     # judged the disk while the commit wrote the index. Now the tier refuses
                     # a run whose marker is missing.
                     'run_work_receipts_tests.ps1')
if ($null -ne $EvidenceSuitesOverride) {
    $EVIDENCE_SUITES = @($EvidenceSuitesOverride | Where-Object { $_ -and $_ -ne 'NONE' })
}

$hookStampHead = ''
$hookStampIndexTime = $null
$hookIndexPath = ''
if ($Hook) {
    $env:EA_LAB_EVIDENCE = 'index'
    Write-Host '[fast-cages] hook mode: EA_LAB_EVIDENCE=index set for every child'
    # T6: a concurrent writer (this repo has a scheduled committer) can move HEAD or the
    # index mid-tier, leaving two suites judging two different commits. Detected, not
    # prevented: stamp both now, compare at the end, refuse on movement.
    $hookStampHead = (& git -C $RepoRoot rev-parse HEAD 2>$null)
    $hookIndexPath = if ($env:GIT_INDEX_FILE) { $env:GIT_INDEX_FILE } else { Join-Path $RepoRoot '.git\index' }
    if (Test-Path -LiteralPath $hookIndexPath) {
        $hookStampIndexTime = (Get-Item -LiteralPath $hookIndexPath).LastWriteTimeUtc
    }
}

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

# ---------------------------------------------------------------------------------------------
# ORDER-731 item 2 -- the tier ABORT, instrumented rather than argued about.
#
# `check_s2a_migration.py` compares an input fingerprint at the start and end of its run and
# exits 2 if HEAD or the git index moved underneath it. It fired in 2 of 8 manual full-tier runs
# on 2026-08-01. One instance was explained by a concurrent lane committing; the other was NOT,
# and it could not be diagnosed by anyone afterwards because NO RUN LEFT A TRACE -- the entire
# record was prose retyped into a commit message. "It moved sometime during 78 seconds" is not a
# diagnosis, and neither is a second opinion about it.
#
# So: stamp the two things that can move, AFTER EVERY SUITE. That converts an 80-second mystery
# into a per-suite window, and the next occurrence names the suite it happened under.
#
# Deliberately PURE FILE READS -- no `git` subprocess. A probe that spawned git 16 times per run
# would be perturbing the very state it is measuring (and `git` can write `.git/index` for its
# own reasons), which is the observer defect this repo has paid for elsewhere. `.git/HEAD` plus
# the resolved ref file plus the index's (mtime, length) are enough to detect CHANGE, and change
# is the whole question.
$tierRunLog = $null
# NESTED runs write nothing. PART 7 and the self-test parts invoke this script again against
# synthetic staged sets and temp indexes; one real tier produced SIX extra transcripts, each one
# suite long, which turns the directory into noise exactly when it is being searched for signal.
# The env var is set for children, so the OUTERMOST run is the only writer.
# M3 (independent review): a standalone suite that invokes the tier produced SIX one-suite
# transcripts, and at a retention of 40 that meant seven such runs evicted every real full-tier
# transcript -- the artifact destroying its own evidence.
#
# 🔴 The obvious discriminator is WRONG and was caught before it landed, by reading the hook
# instead of reasoning about it: `.githooks/pre-commit:218` invokes this script with
# `-StagedPathsFile`, so "a synthetic staged set means a self-test" would have suppressed the
# transcript on EVERY REAL HOOK RUN -- silencing the instrument precisely where it is the whole
# point. `-Hook` does not discriminate either: PART 6's T4/T6 cases are hook-mode by design.
#
# So the suppression stays exactly as wide as the signal that is actually sound (a tier calling
# ITSELF sets the env var for its children), the eviction is closed by RETENTION rather than by a
# guess, and every transcript records `hook` + `staged_count` so a reader can classify one at a
# glance instead of inferring. DECLARED RESIDUAL: a standalone suite run still leaves a few
# short transcripts. They are noise, they are labelled, and they can no longer evict anything.
$isNestedTier = [bool]$env:EA_LAB_TIER_RUN
if (-not $isNestedTier) {
    try {
        $runDir = Join-Path $RepoRoot '_triage\tier_runs'
        if (-not (Test-Path -LiteralPath $runDir)) {
            New-Item -ItemType Directory -Path $runDir -Force | Out-Null
        }
        $tierRunLog = Join-Path $runDir ('tier_{0}_{1}.jsonl' -f (Get-Date -Format 'yyyyMMdd_HHmmss'), $PID)
        # Bounded retention. An unbounded breadcrumb directory is a disk leak, and the runs that
        # matter are the recent ones. The number is 200, not 40: a transcript is ~1 KB, the abort
        # fired 2 times in 8 runs, and the whole point is to still HAVE the run when someone
        # finally comes looking. 40 was chosen before it was known that other runs could evict --
        # a retention bound tight enough to lose the evidence is not a bound, it is a leak with
        # the sign flipped.
        $old = @(Get-ChildItem -LiteralPath $runDir -Filter 'tier_*.jsonl' -ErrorAction SilentlyContinue |
                 Sort-Object LastWriteTime -Descending | Select-Object -Skip 200)
        foreach ($f in $old) { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue }
    } catch {
        # Instrumentation must never be able to fail the tier it instruments.
        $tierRunLog = $null
    }
}
# Set for CHILDREN only, and restored at the end of this script -- an env var this script
# leaves behind would make the NEXT tier run in the same shell think it is nested and write
# no transcript at all. Measured: running the tier twice in one PowerShell session produced
# one transcript, and the missing one looked exactly like a run that never happened.
$priorTierRunEnv = $env:EA_LAB_TIER_RUN
$env:EA_LAB_TIER_RUN = '1'

# The FOUR working-tree files `check_s2a_migration.input_fingerprint()` hashes (that function's
# own list, check_s2a_migration.py:210). Stamping HEAD and the index alone was a REAL defect in the
# first version of this instrumentation, found by reading the fingerprint it exists to explain:
# those four are read from the WORKING TREE and can change without HEAD or the index moving at all
# -- which is precisely the shape of the unexplained 2026-08-01 abort. A transcript that reported
# "nothing moved" while the abort reported "something moved" would not merely be silent, it would
# MISLEAD the next investigation, which is worse than having no transcript.
$TIER_FINGERPRINT_INPUTS = @(
    '_triage/factory_os/s2a_migration.jsonl',
    '_triage/factory_os/s2a_coverage_reconciliation.json',
    'MASTER_BACKLOG.md',
    '_triage/factory_os/schemas.json'
)

function Get-InputHashes {
    param([string]$Root)
    # CRLF-folded sha256, the same normalization the fingerprint applies, so a checkout-line-ending
    # difference is not reported as a change. Truncated to 12 chars: this detects CHANGE, it does
    # not authenticate anything. Still pure file reads -- no git.
    $out = [ordered]@{}
    foreach ($rel in $TIER_FINGERPRINT_INPUTS) {
        try {
            $bytes = [System.IO.File]::ReadAllBytes((Join-Path $Root $rel))
            $text = [System.Text.Encoding]::UTF8.GetString($bytes) -replace "`r`n", "`n"
            $sha = [System.Security.Cryptography.SHA256]::Create()
            $hash = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($text))
            $sha.Dispose()
            $out[$rel] = ([System.BitConverter]::ToString($hash) -replace '-', '').Substring(0, 12).ToLower()
        } catch { $out[$rel] = 'ABSENT-OR-UNREADABLE' }
    }
    return $out
}

function Get-IndexPath {
    param([string]$GitDir)
    # B2 (independent review). git honours GIT_INDEX_FILE, and `check_s2a_migration.py`'s `_git()`
    # is a plain subprocess that inherits it -- so under the pre-commit hook the index the abort
    # reads is a `next-index-<pid>.lock`, NOT `.git/index`. Stamping `.git/index` there described a
    # file neither git nor the checker reads: a real change was invisible and an unrelated rewrite
    # raised a false banner. PROVED from transcripts already on disk, which recorded
    # `git_index_env = .../next-index-17736.lock` for real hook runs.
    # This is the read-the-wrong-snapshot family, recreated inside the instrument built to
    # diagnose it -- and line ~796 of THIS FILE already resolved it correctly. Same rule, one copy.
    if ($env:GIT_INDEX_FILE) { return $env:GIT_INDEX_FILE }
    return (Join-Path $GitDir 'index')
}

function Get-GitStateStamp {
    param([string]$GitDir)
    $head = $null; $ref = $null; $idxTicks = $null; $idxLen = $null
    try { $head = (Get-Content -LiteralPath (Join-Path $GitDir 'HEAD') -Raw -ErrorAction Stop).Trim() } catch { $head = 'UNREADABLE' }
    try {
        if ($head -like 'ref: *') {
            $refPath = Join-Path $GitDir ($head.Substring(5).Trim() -replace '/', '\')
            if (Test-Path -LiteralPath $refPath) { $ref = (Get-Content -LiteralPath $refPath -Raw).Trim() }
            else { $ref = 'PACKED-OR-ABSENT' }
        } else { $ref = $head }
    } catch { $ref = 'UNREADABLE' }
    try {
        $fi = Get-Item -LiteralPath (Get-IndexPath -GitDir $GitDir) -ErrorAction Stop
        $idxTicks = $fi.LastWriteTimeUtc.Ticks; $idxLen = $fi.Length
    } catch { $idxTicks = -1; $idxLen = -1 }
    return [pscustomobject]@{ head = $head; ref = $ref; index_ticks = $idxTicks; index_len = $idxLen }
}

function Write-TierStamp {
    param([string]$LogPath, [string]$GitDir, [string]$Phase, [string]$Suite, $Exit, $Seconds)
    if (-not $LogPath) { return }
    try {
        $s = Get-GitStateStamp -GitDir $GitDir
        $rec = [pscustomobject]@{
            at = (Get-Date).ToString('o'); phase = $Phase; suite = $Suite
            exit = $Exit; seconds = $Seconds
            head = $s.head; ref = $s.ref; index_ticks = $s.index_ticks; index_len = $s.index_len
            # NOTE the asymmetry, stated so nobody reads more into it than is there: the abort's
            # index component is sha256(`git ls-files -s`) -- CONTENT -- while this is the index
            # file's (mtime, length). Matching it exactly would mean spawning git 17 times a run,
            # which perturbs what it measures. So index_* is a PROXY and may move when the abort
            # would not; `inputs` below is exact.
            hook = [bool]$Hook
            staged_count = @($StagedPaths).Count
            index_path = (Get-IndexPath -GitDir $GitDir)
            # M1: sampled on EVERY stamp, not only in the failure dump. `index.lock` during a
            # concurrent commit lives tens of MILLISECONDS, and the dump fires after a suite
            # that can run 31s -- so the dump's copy reads false in practically every real
            # occurrence. A sub-millisecond Test-Path per suite is the only way this fact is
            # ever observed. (fe1a9a2c's commit message claimed the dump caught it 'at the
            # moment of detection'; that was wrong and is corrected on the ORDER-731 row.)
            index_lock = (Test-Path -LiteralPath (Join-Path $GitDir 'index.lock'))
            inputs = (Get-InputHashes -Root $RepoRoot)
            git_index_env = $env:GIT_INDEX_FILE
        }
        # NO BOM. `Add-Content -Encoding utf8` in PS 5.1 stamps a BOM on the first write, and a
        # BOM on line 1 of a JSONL file breaks `json.loads` for whatever reads it later --
        # instrumentation that cannot be parsed is not instrumentation (memory
        # `dotnet-stdin-bom-corrupts-first-request`, same family).
        [System.IO.File]::AppendAllText(
            $LogPath, ($rec | ConvertTo-Json -Compress) + "`n",
            (New-Object System.Text.UTF8Encoding($false)))
    } catch { }
}

$results = New-Object System.Collections.Generic.List[object]
$total = 0.0
$stampStart = Get-GitStateStamp -GitDir (Join-Path $RepoRoot '.git')
Write-TierStamp -LogPath $tierRunLog -GitDir (Join-Path $RepoRoot '.git') -Phase 'start' -Suite '' -Exit $null -Seconds 0

foreach ($suite in $selected) {
    $path = Join-Path $testDir $suite
    if (-not (Test-Path -LiteralPath $path)) {
        # A missing suite is a failure, not a skip. Silently passing over a cage that was
        # deleted or renamed is precisely how a cage stops existing without anyone noticing.
        Write-Host ("  MISSING {0}" -f $suite) -ForegroundColor Red
        $results.Add([pscustomobject]@{ Suite = $suite; Exit = 127; Seconds = 0.0; Output = 'suite file not found' })
        # M4: stamp it too. `continue`ing straight past left a reader with fewer after-suite lines
        # than suites and nothing saying why -- a gap in a transcript is read as a gap in the run.
        Write-TierStamp -LogPath $tierRunLog -GitDir (Join-Path $RepoRoot '.git') -Phase 'missing-suite' `
                        -Suite $suite -Exit 127 -Seconds 0
        continue
    }

    $sw = [Diagnostics.Stopwatch]::StartNew()
    # M2 (independent review). `$ErrorActionPreference = 'Stop'` turns a native command's STDERR
    # into a terminating error, so a suite that merely writes to stderr THREW out of this loop --
    # past the stamp, past the failure dump, past the end line, and past Exit-Tier, leaving the
    # child-marker env var set. It killed the instrumentation on exactly the abnormal path the
    # instrumentation exists for. Caught here and converted into an ordinary non-zero result, so
    # the run is recorded rather than vanishing.
    try {
        $out = & $ps -NoProfile -ExecutionPolicy Bypass -File $path 2>&1
        $code = $LASTEXITCODE
    } catch {
        $out = "SUITE THREW (stderr under EAP=Stop, or the launcher failed): $($_.Exception.Message)"
        $code = if ($LASTEXITCODE) { $LASTEXITCODE } else { 1 }
    }
    $sw.Stop()
    $total += $sw.Elapsed.TotalSeconds

    $results.Add([pscustomobject]@{
        Suite   = $suite
        Exit    = $code
        Seconds = $sw.Elapsed.TotalSeconds
        Output  = ($out | Out-String)
    })

    # ORDER-731 item 2: stamp AFTER EVERY SUITE, not only at the two ends. The whole value of
    # the transcript is the per-suite window; a start/end pair reproduces the same 80-second
    # mystery in a file instead of in a commit message.
    Write-TierStamp -LogPath $tierRunLog -GitDir (Join-Path $RepoRoot '.git') -Phase 'after-suite' `
                    -Suite $suite -Exit $code -Seconds ([math]::Round($sw.Elapsed.TotalSeconds, 2))

    if ($code -eq 0) {
        Write-Host ("  ok   {0,-34} {1,5:N1}s" -f $suite, $sw.Elapsed.TotalSeconds)
    } else {
        Write-Host ("  FAIL {0,-34} {1,5:N1}s (exit {2})" -f $suite, $sw.Elapsed.TotalSeconds, $code) -ForegroundColor Red
        # ORDER-731 item 2, the on-failure half. Captured HERE, at the moment of detection --
        # a reflog read minutes later cannot tell you whether `index.lock` existed while the
        # suite was dying, and that is the single fact that separates "a concurrent writer" from
        # "something in the tier itself", which is the question 2026-08-01 could not answer.
        if ($tierRunLog) {
            try {
                $gd = Join-Path $RepoRoot '.git'
                $lock = Test-Path -LiteralPath (Join-Path $gd 'index.lock')
                $procs = @()
                try {
                    $procs = @(Get-Process -Name git, git-remote-https -ErrorAction SilentlyContinue |
                               ForEach-Object { '{0}:{1}' -f $_.Id, $_.ProcessName })
                } catch { }
                $reflog = @()
                try {
                    $rl = Join-Path $gd 'logs\HEAD'
                    if (Test-Path -LiteralPath $rl) { $reflog = @(Get-Content -LiteralPath $rl -Tail 3) }
                } catch { }
                $moved = ($stampStart.ref -ne (Get-GitStateStamp -GitDir $gd).ref)
                $dump = [pscustomobject]@{
                    at = (Get-Date).ToString('o'); phase = 'failure-dump'; suite = $suite; exit = $code
                    index_lock_present = $lock; live_git_processes = $procs
                    head_moved_since_tier_start = $moved; reflog_tail = $reflog
                }
                [System.IO.File]::AppendAllText(
                    $tierRunLog, ($dump | ConvertTo-Json -Compress) + "`n",
                    (New-Object System.Text.UTF8Encoding($false)))
                Write-Host ("  [tier-instr] failure context written to {0}" -f $tierRunLog) -ForegroundColor Yellow
            } catch { }
        }
    }
}

$evidenceProblems = New-Object System.Collections.Generic.List[string]
if ($Hook) {
    # ORDER-670 T4: the marker ALLOWLIST. For each selected evidence suite: exactly one
    # marker naming THAT suite, carrying mode 'index'. This replaced a blacklist ("fail if
    # any suite reports worktree") that passed a suite reporting NOTHING -- and suite output
    # legitimately quotes the word 'worktree' in fixture names, which a structured marker
    # with the suite's own name cannot collide with.
    foreach ($esuite in $EVIDENCE_SUITES) {
        if ($selected -notcontains $esuite) { continue }
        $r = $results | Where-Object { $_.Suite -eq $esuite } | Select-Object -First 1
        if ($null -eq $r) { continue }
        $markers = @(($r.Output -split "`r?`n") | Where-Object {
            $_ -match ('^##EVIDENCE-MODE## ' + [regex]::Escape($esuite) + ' (\S+)') })
        if ($markers.Count -eq 0) {
            $evidenceProblems.Add(('{0} emitted NO evidence-mode marker -- the mode cannot be shown to have arrived, and silence must not pass' -f $esuite))
        } elseif ($markers.Count -gt 1) {
            $evidenceProblems.Add(('{0} emitted {1} evidence-mode markers -- exactly one is the contract' -f $esuite, $markers.Count))
        } elseif ($markers[0] -notmatch ('^##EVIDENCE-MODE## ' + [regex]::Escape($esuite) + ' index\b')) {
            $evidenceProblems.Add(('{0} reports the WRONG mode in hook mode: {1}' -f $esuite, $markers[0]))
        }
    }
    # ORDER-670 T6: did the ground move under the run?
    $headNow = (& git -C $RepoRoot rev-parse HEAD 2>$null)
    if ($hookStampHead -and $headNow -ne $hookStampHead) {
        $evidenceProblems.Add(('HEAD moved during the tier ({0} -> {1}) -- two suites may have judged two different commits; re-run' -f $hookStampHead, $headNow))
    }
    if ($null -ne $hookStampIndexTime -and (Test-Path -LiteralPath $hookIndexPath)) {
        $indexTimeNow = (Get-Item -LiteralPath $hookIndexPath).LastWriteTimeUtc
        if ($DebugPretendIndexMoved) { $indexTimeNow = $indexTimeNow.AddSeconds(1) }
        if ($indexTimeNow -ne $hookStampIndexTime) {
            $evidenceProblems.Add(('the index ({0}) was rewritten during the tier -- a verdict over a moving index means nothing; re-run' -f $hookIndexPath))
        }
    } elseif ($DebugPretendIndexMoved) {
        $evidenceProblems.Add('the index was rewritten during the tier (debug-forced) -- re-run')
    }
    foreach ($p in $evidenceProblems) {
        Write-Host ('[fast-cages] EVIDENCE FAIL: {0}' -f $p) -ForegroundColor Red
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

# ORDER-731 item 2: the closing stamp, plus ONE line of visible provenance. A transcript nobody
# knows exists is a transcript nobody reads when it finally matters -- the failure mode of every
# detector this repo has had to repair (ORDER-260 / 341 / 390 / 411).
Write-TierStamp -LogPath $tierRunLog -GitDir (Join-Path $RepoRoot '.git') -Phase 'end' -Suite '' `
                -Exit $failed.Count -Seconds ([math]::Round($total, 2))
if ($tierRunLog) {
    $endStamp = Get-GitStateStamp -GitDir (Join-Path $RepoRoot '.git')
    $movedNote = if ($endStamp.ref -ne $stampStart.ref) { ' -- HEAD MOVED DURING THIS RUN' }
                 elseif ($endStamp.index_ticks -ne $stampStart.index_ticks) { ' -- .git/index was rewritten during this run' }
                 else { '' }
    Write-Host ("[tier-instr] transcript: {0}{1}" -f $tierRunLog, $movedNote)
}

# ---------------------------------------------------------------------------------------------
# ORDER-673 -- the budget is ENFORCED. It was an advisory that printed yellow and exited 0, and
# it had been breached on every commit for days with nothing happening. A check that cannot fail
# is shape 3, and this one sat inside the tier built to catch shape 3.
#
# The applicable budget depends on WHICH RUN THIS IS: a full run (nothing staged, or a path list
# that matched nothing and failed open) legitimately costs more than a selected run. Comparing
# both against one number would either fail every full run or excuse every selected one.
#
# A SUITE FAILURE OUTRANKS THE BUDGET and is checked first: both exit 1, but "your commit is
# slow" printed where "your commit is broken" belongs is a message that gets the wrong thing
# fixed.
function Exit-Tier {
    param([int]$Code)
    # Restore the child-marker env var on EVERY path out of this script, not just the happy
    # one. A guard that cleans up only when it passes is a guard that leaks exactly when
    # something went wrong -- which is when the next run's transcript matters most.
    $env:EA_LAB_TIER_RUN = $priorTierRunEnv
    exit $Code
}
if ($failed.Count -gt 0) { Exit-Tier 1 }
if ($evidenceProblems.Count -gt 0) { Exit-Tier 1 }

$total += $DebugPadSeconds
$isFullRun = ($selected.Count -eq $FAST_SUITES.Count)
$budget = if ($isFullRun) { $FullTierBudgetSeconds } else { $BudgetSeconds }
$budgetLabel = if ($isFullRun) { 'full tier' } else { 'per-path' }

if ($total -gt $budget) {
    # N3: name WHICH SUITE spent the time. "The tier is slow" is not actionable; the top spender
    # with its share is the sentence a reader can act on.
    $top = @($results | Sort-Object -Property Seconds -Descending | Select-Object -First 3)
    Write-Host ''
    Write-Host ("[fast-cages] OVER BUDGET: {0:N1}s against the {1:N1}s {2} budget ({3:N1}s over)." -f `
                $total, $budget, $budgetLabel, ($total - $budget)) -ForegroundColor Red
    foreach ($t in $top) {
        Write-Host ("               {0,-34} {1,5:N1}s  = {2,4:N0}% of the run" -f `
                    $t.Suite, $t.Seconds, (100.0 * $t.Seconds / [Math]::Max($total, 0.001))) -ForegroundColor Red
    }
    Write-Host ("               A pre-commit tier that takes this long earns --no-verify, which is") -ForegroundColor Red
    Write-Host ("               the failure this budget exists to prevent. Displace a suite, make the") -ForegroundColor Red
    Write-Host ("               named one faster, or raise the number DELIBERATELY in the same commit") -ForegroundColor Red
    Write-Host ("               that says why -- but do not leave it breached and green.") -ForegroundColor Red
    Exit-Tier 1
}

# Print the MARGIN on a green run, so the next person can see the headroom BEFORE spending it
# (N2's specificity half). A budget you only hear about once you are over it is a budget that
# gets discovered by a broken commit.
Write-Host ("[fast-cages] budget: {0:N1}s of {1:N1}s {2} ({3:N1}s headroom)" -f `
            $total, $budget, $budgetLabel, ($budget - $total))
Exit-Tier 0
