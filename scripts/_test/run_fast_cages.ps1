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

    WHAT THIS DOES NOT COVER -- read this before trusting a green run:
    the four slow suites above, and in particular run_order105_negative_tests.ps1, which
    exits 1 today (ORDER-420 STEP 2 owns finding out why). Green here means "the four fast
    cages passed", nothing more.

.PARAMETER BudgetSeconds
    Total wall-clock the fast tier is allowed. Exceeding it is reported as a warning with
    the per-suite breakdown, so the split above gets revisited with numbers.

.NOTES
    ASCII only: PS 5.1 decodes a BOM-less .ps1 as ANSI.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [double]$BudgetSeconds = 15.0
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
    'run_optimize_guard_tests.ps1'
)

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
