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
        edit stops paying for 5.8s of optimize-guard cases. That is not built.

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
    [switch]$ExportGuards
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
                                          'scripts/lib/monitor_coverage.ps1')
    # ORDER-601 part 2 added the snapshot validator and its computation suite to this wrapper
    # rather than to a suite of its own (the budget note in that file explains the trade), so
    # both files are inputs to it. Declaring them is what puts them in the trigger pathspec --
    # without these two lines the cage would run only when something ELSE it guards was staged,
    # which is the exact five-times-in-four-days failure BACKLOG-D32 exists to end.
    'run_contract_binding_tests.ps1'  = @('_triage/factory_os/gen_design_contracts.py',
                                          '_triage/factory_os/run_contract_binding_tests.py',
                                          '_triage/factory_os/snapshot_validator.py',
                                          '_triage/factory_os/run_snapshot_validator_tests.py',
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
                                          # D1's coverage numbers are RECOMPUTED from section 2 of
                                          # this file, so a change to it can falsify C8.
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
    'tools/python312/python.exe'                    # interpreter, not an edited input
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

$ps = (Get-Process -Id $PID).Path
if (-not $ps) { $ps = 'powershell.exe' }

Write-Host '[fast-cages] running the cages that guard the guards'

$results = New-Object System.Collections.Generic.List[object]
$total = 0.0

foreach ($suite in $FAST_SUITES) {
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
