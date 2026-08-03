<#
    run_schema_cages.ps1 -- ORDER-1252 (BOX 1b of the S13C handoff, owner-ratified 2026-08-03).

    THE THREE CHEAP SCHEMA CAGES, SPLIT OUT OF run_contract_binding_tests.ps1 SO THEY CAN STAY
    IN THE PRE-COMMIT TIER WHILE THE EXPENSIVE PART LEAVES IT.
    (ORDER-1264 briefly made it four; ORDER-1283 took that one back out the same day, and the
    note beside the array says why -- it writes to the file it tests. Back to three.)

    WHY THE SPLIT RATHER THAN THE DISPLACEMENT. The owner's first choice was to move
    run_contract_binding_tests.ps1 out of the fast tier wholesale. That was attempted by the
    ORDER-1240 lane and REVERTED, because a cage refused it and was right to:

        [FAIL] E staging a registry store selects the suite where ajv validates live rows

    run_schema_fixtures.py ajv-validates every LIVE row of every factory/*.jsonl store, and it
    ran INSIDE that wrapper. Moving the wrapper would have taken the ajv guard off the commit
    path of the files it governs -- a hole a blind audit had already found once (round 4, "the
    checker existed, worked, and was not on the commit path of the file it governs") and closed
    with a dedicated case. Displacing the wrapper reopens it.

    So the entries below stay, and only they do:

      run_schema_fixtures.py          5.8-7.2s  ajv over 41 root + 64 per-entity fixtures AND over
                                                every live registry row. THE reason this suite
                                                exists: it is what case E is about.
      check_schema_structure.py       1.1-1.5s  discriminator consistency, the closed-object
                                                inventory across every entity, the completeness
                                                inventory (ORDER-1264), and the PLANNED/BUILT/
                                                WIRED labels checked against the repo
      gen_design_contracts.py --check 0.1s      CONTRACTS.md still matches schemas.json, and the
                                                design still links every contract in it

    MEASURED with -Timing under EA_LAB_EVIDENCE=index, which is the only number worth quoting --
    memory `tier-number-needs-its-invocation`. THREE samples, because one number here would be a
    fiction: SUM OF ENTRIES = 10.05 / 8.06 / 8.85s. Those three samples INCLUDE the fourth entry
    ORDER-1283 has since removed (1.0-1.2s of each), and they were taken on a machine held by an
    18-agent optimize batch. Both facts are stated rather than corrected away, because a number
    re-typed to look tidier is exactly what the paragraph below is about.

    ORDER-1264, 2026-08-03: the table above used to read 3.71 / 0.71 / 0.05 = 4.47s and it was
    stale in every row -- the SAME three entries now measure 8.8 / 7.1 / 7.9s summed. Recorded
    rather than quietly overwritten, because the drift is the point: this is the fourth time in
    this repo a hand-typed timing table has been found wrong (4x, 42x, 41x, and now ~2x), and it
    is why -Timing exists on this wrapper. It was NOT re-derived on suspicion; it was re-derived
    because adding an entry required it.

    The 37s that LEFT the tier with run_contract_binding_tests.ps1 is what buys the budget back,
    and that removal is the owner's ratified decision, recorded in ORDER-1252 with the list of
    exactly which guards are no longer on the commit path.

    Interpreter: tools\python312\python.exe, committed in-repo. run_schema_fixtures.py REQUIRES
    ajv-cli on PATH; if ajv is missing it reports ERROR rather than "rejected", and that
    three-state discipline is the whole reason it can be trusted here.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot,
    # Same contract as the wrapper this was split out of: a measurement table that lives only in
    # a comment goes stale, and this repo has paid for that three times (4x, 42x, 41x).
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

# Thai/§/≤ in any child's output kills the process under an ANSI-codepage pipe and the tier
# reports `exit -1 SUITE THREW` with the cause swallowed (memory
# `thai-output-kills-a-suite-inside-the-hook`). Set here, in the wrapper, for every child.
$env:PYTHONIOENCODING = 'utf-8'

$python = Join-Path $RepoRoot 'tools\python312\python.exe'
if (-not (Test-Path -LiteralPath $python)) {
    # A missing interpreter is a FAILURE, not a skip. A cage that opts out when its tool is
    # absent keeps being produced and quietly stops being true.
    Write-Host "[schema-cages] FAIL: interpreter not found at $python" -ForegroundColor Red
    exit 1
}

$scripts = @(
    @{ Path = '_triage\factory_os\run_schema_fixtures.py'; Args = @() },
    @{ Path = '_triage\factory_os\check_schema_structure.py'; Args = @() },
    @{ Path = '_triage\factory_os\gen_design_contracts.py'; Args = @('--check') }
    # 🔴 ORDER-1264 ADDED run_enforcement_status_tests.py HERE, AND ORDER-1283 TOOK IT BACK OUT
    # THE SAME DAY. The reasoning for adding it was sound and still is -- it is the cage that
    # proves check_schema_structure.py can go RED, it was left behind when ORDER-1252 moved
    # run_contract_binding_tests.ps1 off the commit path, and a checker running on the commit
    # path whose only cage runs by hand is the ORDER-1272 shape.
    #
    # What the reasoning missed is HOW that cage works: it writes mutations into the LIVE,
    # TRACKED _triage/factory_os/schemas.json and restores it in a `finally`. On a hand-run
    # wrapper that is merely untidy. On the COMMIT PATH of a repo where two lanes commit
    # concurrently it is a data-loss path, and it was OBSERVED rather than theorised -- within
    # twenty minutes of the change, a hand run and another lane's pre-commit hook (commits
    # 1b144630 20:37, 7eb883d7 20:44, 5389b0b8 20:46) collided on the file: one died with
    # OSError 22 and the other's `finally` restored ITS idea of the original, leaving
    # `WorkReceipt.x-enforcement-status = "TOTALLY_FINE"` sitting in the working tree.
    # Whichever process reads while the other holds a mutation restores the MUTATION.
    #
    # It goes back in when it stops writing to the file it tests -- that is ORDER-1283, and it
    # needs check_schema_structure.py to be drivable with an injected document instead of only
    # as a subprocess over a fixed path. Until then it runs by hand, and that is a known,
    # named gap rather than a silent one.
)

$failed = 0
$timings = @()
foreach ($s in $scripts) {
    $full = Join-Path $RepoRoot $s.Path
    if (-not (Test-Path -LiteralPath $full)) {
        Write-Host ("[schema-cages] FAIL: missing {0}" -f $s.Path) -ForegroundColor Red
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
        Write-Host ("[schema-cages] FAIL {0}" -f $s.Path) -ForegroundColor Red
        Write-Host ($out | Out-String)
        $failed++
    }
}

if ($Timing) {
    Write-Host ''
    Write-Host ("[schema-cages] TIMING -- evidence mode: {0}" -f $evidenceMode)
    foreach ($t in ($timings | Sort-Object -Property Seconds -Descending)) {
        Write-Host ('    {0,-42} {1,6:N2}s' -f $t.Entry, $t.Seconds)
    }
    Write-Host ('    {0,-42} {1,6:N2}s' -f 'SUM OF ENTRIES',
                ($timings | Measure-Object -Property Seconds -Sum).Sum)
}

if ($failed -gt 0) { exit 1 }
Write-Host ('[schema-cages] ajv validated every fixture and every LIVE registry row, the schema ' +
            'structure holds, and CONTRACTS.md still matches schemas.json')
exit 0
