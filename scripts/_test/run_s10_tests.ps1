<#
run_s10_tests.ps1 - ORDER-1100 (slice S10), wrapping the cage for Candidate identity, Deployment
attestation and magic reservation.

WHAT IT GUARDS. _triage\factory_os\candidate.py, attestation.py and magic.py are the whole
decision surface of design 4.5-4.7's identity, authorization and allocation rules. All three are
PURE, so the suite drives them against fixtures and costs milliseconds.

WHAT THIS ADDS ON TOP OF THE PYTHON, AND WHY IT IS THE POINT OF THIS FILE. Four /scrutinize rounds
over S9 found nine defects and EVERY ONE of them lived where a pure-module cage structurally
cannot reach. S10's third acceptance is "check_state.ps1 stays green", and check_state is
PowerShell -- so PART B drives the PowerShell side: B1-B4 drive the RULE (scripts\lib\
magic_guard.ps1, the implementation check_state itself calls) in process, and B5 drives the WHOLE
GUARD end to end, in the mode the hook runs it in, against a POISONED INDEX.

  WHY THE SPLIT. Spawning check_state per case costs ~3.0s and the full-tier budget had 0.3s of
  headroom; four spawns cost 13.1s and would have made the tier's own budget refuse this commit.
  In process each case costs hundredths of a second, and the one claim they cannot make -- that
  check_state CALLS the rule, feeds it judged bytes, and routes the answer into a Check that can
  turn the guard red -- is what B5 buys with its 3.0s. Trimming it is also what FOUND the
  $null-coerced-to-'' defect in the library, because B4 could finally be run cheaply enough to
  keep.

  NO WORKTREE MUTATION. B5's poison is written into a TEMP GIT INDEX (GIT_INDEX_FILE), never onto
  disk. ORDER-731's cage mutated two shared boards on disk and was rewritten to stage through the
  object database for exactly this reason: a restore window in a shared working tree is a window
  another lane's commit can fall into. GIT_INDEX_FILE is cleared in a finally, per memory
  git-index-file-poisons-fixture-repos.

STATED LIMIT. B5 proves the guard fires in INDEX mode. Disk mode shares the same code path through
Read-Committed and is not separately driven here.

MEASURED before registering, three times, per memory phantom-regression-from-two-single-samples:
3.9s / 3.8s / 3.9s. See the number in run_fast_cages.ps1's registration comment.

ASCII-only on purpose (Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI).
USAGE  powershell -NoProfile -File scripts\_test\run_s10_tests.ps1
#>
[CmdletBinding()]
param([string]$RepoRoot = '')

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }

$py    = Join-Path $RepoRoot 'tools\python312\python.exe'
$suite = Join-Path $RepoRoot '_triage\factory_os\run_s10_tests.py'
$guard = Join-Path $RepoRoot 'scripts\check_state.ps1'
$ALLOC = 'factory/magic_allocations.jsonl'

if (-not (Test-Path -LiteralPath $py))    { Write-Host "[s10] FAIL: interpreter not found at $py" -ForegroundColor Red; exit 2 }
# A MISSING SUITE IS A TOOL FAILURE, NOT A PASS. Exit 2, not 0.
if (-not (Test-Path -LiteralPath $suite)) { Write-Host "[s10] FAIL: suite not found at $suite" -ForegroundColor Red; exit 2 }
if (-not (Test-Path -LiteralPath $guard)) { Write-Host "[s10] FAIL: check_state.ps1 not found at $guard" -ForegroundColor Red; exit 2 }

# ---------------------------------------------------------------------------------------
# PART A -- the python cage
# ---------------------------------------------------------------------------------------
$out  = & $py $suite 2>&1
$code = $LASTEXITCODE
$out | ForEach-Object { Write-Host $_ }
if ($code -ne 0) { Write-Host "[s10] the S10 cage FAILED (exit $code)" -ForegroundColor Red; exit 1 }

# Assert the COMPLETENESS half actually ran. Every attack in the suite is meaningless if an
# enumeration silently shrank: a mutation table edited down, an expectation table trimmed, or a
# roll-up that stopped demanding every criterion id would leave a green run proving less than
# yesterday's, and nothing in the exit code would say so.
$joined = ($out -join "`n")
foreach ($needle in @(
    'ROLL-UP the mutation table covers exactly the',
    'fields moved the digest',
    'cells were decided as declared',
    'criterion ids the three modules declare was ATTACKED')) {
    if ($joined -notmatch [regex]::Escape($needle)) {
        Write-Host "[s10] FAIL: the run never asserted '$needle', so its claims rest on whatever subset happened to run" -ForegroundColor Red
        exit 1
    }
}

# ---------------------------------------------------------------------------------------
# PART B -- DRIVE THE REAL check_state.ps1 AGAINST A POISONED INDEX
# ---------------------------------------------------------------------------------------
function Invoke-GuardOnIndex {
    param([string]$IndexPath)
    # The hook runs check_state with EA_LAB_EVIDENCE=index; this reproduces that exactly, so the
    # guard reads the temp index rather than the disk.
    $prevIdx  = $env:GIT_INDEX_FILE
    $prevMode = $env:EA_LAB_EVIDENCE
    try {
        $env:GIT_INDEX_FILE = $IndexPath
        $env:EA_LAB_EVIDENCE = 'index'
        # -Strict, because without it the guard exits 0 on a WARNING and every exit-code
        # assertion below would be satisfied by a guard that noticed nothing. The hook runs it
        # strict for the same reason.
        $text = & powershell -NoProfile -File $guard -Root $RepoRoot -Strict 2>&1
        return @{ text = ($text -join "`n"); code = $LASTEXITCODE }
    } finally {
        if ($null -eq $prevIdx)  { Remove-Item Env:\GIT_INDEX_FILE -ErrorAction SilentlyContinue }  else { $env:GIT_INDEX_FILE = $prevIdx }
        if ($null -eq $prevMode) { Remove-Item Env:\EA_LAB_EVIDENCE -ErrorAction SilentlyContinue } else { $env:EA_LAB_EVIDENCE = $prevMode }
    }
}

function New-TempIndexFromHead {
    $p = [IO.Path]::GetTempFileName()
    Remove-Item -LiteralPath $p -Force
    $prev = $env:GIT_INDEX_FILE
    try {
        $env:GIT_INDEX_FILE = $p
        & git -C $RepoRoot read-tree HEAD 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "git read-tree HEAD failed" }
    } finally {
        if ($null -eq $prev) { Remove-Item Env:\GIT_INDEX_FILE -ErrorAction SilentlyContinue } else { $env:GIT_INDEX_FILE = $prev }
    }
    return $p
}

function Set-IndexBlob {
    param([string]$IndexPath, [string]$RelPath, [string]$Content)
    $tmp = [IO.Path]::GetTempFileName()
    try {
        [IO.File]::WriteAllText($tmp, $Content, (New-Object System.Text.UTF8Encoding $false))
        # -c core.autocrlf=false: the temp file lives outside the repo, and without this git
        # prints an LF/CRLF warning to stderr on every call -- noise that would train a reader to
        # skim this suite's output, which is the last thing a cage wants.
        $blob = (& git -c core.autocrlf=false -C $RepoRoot hash-object -w -- $tmp).Trim()
        if (-not $blob) { throw "hash-object produced nothing for $RelPath" }
        $prev = $env:GIT_INDEX_FILE
        try {
            $env:GIT_INDEX_FILE = $IndexPath
            & git -C $RepoRoot update-index --add --cacheinfo "100644,$blob,$RelPath" 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "update-index failed for $RelPath" }
        } finally {
            if ($null -eq $prev) { Remove-Item Env:\GIT_INDEX_FILE -ErrorAction SilentlyContinue } else { $env:GIT_INDEX_FILE = $prev }
        }
    } finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
}

function Remove-IndexPath {
    param([string]$IndexPath, [string]$RelPath)
    $prev = $env:GIT_INDEX_FILE
    try {
        $env:GIT_INDEX_FILE = $IndexPath
        & git -C $RepoRoot update-index --force-remove -- $RelPath 2>&1 | Out-Null
    } finally {
        if ($null -eq $prev) { Remove-Item Env:\GIT_INDEX_FILE -ErrorAction SilentlyContinue } else { $env:GIT_INDEX_FILE = $prev }
    }
}

$partB = 0
$partBFail = 0
function B($label, $cond, $detail) {
    $script:partB++
    if ($cond) { Write-Host "  [OK ] $label" -ForegroundColor Green }
    else { Write-Host "  [FAIL] $label" -ForegroundColor Red; if ($detail) { Write-Host "        -> $detail" -ForegroundColor Red }; $script:partBFail++ }
}

Write-Host ''
Write-Host 'PART B -- the REAL check_state.ps1, driven in index mode against a poisoned index'

$live = Get-Content -LiteralPath (Join-Path $RepoRoot 'factory\magic_allocations.jsonl') -Raw -Encoding UTF8
$inv  = Get-Content -LiteralPath (Join-Path $RepoRoot 'portfolio\DEPLOYMENTS.csv') -Raw -Encoding UTF8
. (Join-Path $RepoRoot 'scripts\lib\magic_guard.ps1')
$idx = $null
try {
    # --- B1 CONTROL, in process. The rule must be GREEN on the real pair, or every refusal below
    #     is satisfied just as well by a guard that refuses everything.
    $r = Test-MagicUniqueness -RepoRoot $RepoRoot -AllocText $live -InvText $inv
    B 'B1 CONTROL the rule is CLEAN on the real exception list and the real inventory' $r.ok $r.detail

    # --- B2 ATTACK: drop the 991001 exception -- the magic on REAL money, on two accounts. The
    #     inventory is unchanged, so the collision is real and now undeclared.
    $lines = @($live -split "`r?`n" | Where-Object { $_ -and ($_ -notmatch '"magic":991001') })
    B 'B2 the poison actually removed a line' ($lines.Count -eq (@($live -split "`r?`n" | Where-Object { $_ }).Count - 1)) "$($lines.Count) lines left"
    $poisoned = ($lines -join "`n") + "`n"
    $r = Test-MagicUniqueness -RepoRoot $RepoRoot -AllocText $poisoned -InvText $inv
    # NOT MERELY "it refused". FOR THE STATED REASON: M4 is the sensitivity half, and a refusal
    # carrying any other id would mean this case measured a different rule.
    B 'B2 ATTACK an undeclared REAL-money collision is REFUSED' ((-not $r.ok) -and ($r.detail -match 'M4 magic 991001')) $r.detail
    B 'B2 ...and the refusal names the magic and both accounts' ($r.detail -match '991001' -and $r.detail -match '159475669') $r.detail

    # --- B3 ATTACK: the exception list turned into an off switch. Declaring a magic that is NOT
    #     a collision must be refused too, or the list can be satisfied by declaring everything
    #     (memory gate-specificity-not-just-sensitivity).
    $stale = '{"allocated_at_commit":"' + ('0' * 40) + '","entity":"MagicAllocation","imported_in_cutover":true,"legacy_accounts":["1","2"],"legacy_exception":true,"magic":999999,"scope":"LEGACY_ACCOUNT_SCOPED","status":"ASSIGNED"}'
    $r = Test-MagicUniqueness -RepoRoot $RepoRoot -AllocText ($live.TrimEnd() + "`n" + $stale + "`n") -InvText $inv
    B 'B3 ATTACK an exception declared for a magic that is not a collision is REFUSED' ((-not $r.ok) -and ($r.detail -match 'M5 magic 999999')) $r.detail

    # --- B4 ATTACK: the input is GONE. "cannot read it" must not look like "nothing to enforce"
    #     (memory guard-disarmed-by-prose-reported-as-note). $null is exactly what check_state
    #     passes when Test-CommittedPath says the file is not in the snapshot.
    $r = Test-MagicUniqueness -RepoRoot $RepoRoot -AllocText $null -InvText $inv
    B 'B4 ATTACK a MISSING exception list is a failure, not a skip' ((-not $r.ok) -and ($r.detail -match 'cannot read the magic exception list')) $r.detail

    # --- B5 THE WIRING, end to end, ONCE. B1-B4 prove the RULE; none of them proves that
    #     check_state.ps1 calls it, feeds it judged bytes, or routes its answer into a Check that
    #     can turn the guard red. That is a different claim and it needs the real guard, in the
    #     mode the hook runs it in, against a POISONED INDEX -- the one case worth its ~3s.
    #     A shape check ("the file mentions magic_guard") would have been the same sentence with
    #     none of the measurement.
    $idx = New-TempIndexFromHead
    Set-IndexBlob -IndexPath $idx -RelPath $ALLOC -Content $poisoned
    $r = Invoke-GuardOnIndex -IndexPath $idx
    B 'B5 WIRING the real check_state.ps1, in index mode, goes RED on the poisoned exception list' (($r.code -ne 0) -and ($r.text -match 'M4 magic 991001')) $r.text
    # The library's own answer, printed by check_state's Check. This is what says the verdict
    # TRAVELLED -- a guard that computed the right thing and dropped it would satisfy the line
    # above (some other check could have gone red) but not this one.
    B 'B5 ...and the librarys verdict is what check_state printed, so the answer is routed' ($r.text -match 'magic\.py verify exit 1') $r.text
} finally {
    if ($idx) { Remove-Item -LiteralPath $idx -Force -ErrorAction SilentlyContinue }
    # The worktree was never touched -- every poison lived in a temp index. Assert it anyway,
    # because "I did not modify it" is exactly the claim a cage should not be trusted on.
    $after = Get-Content -LiteralPath (Join-Path $RepoRoot 'factory\magic_allocations.jsonl') -Raw -Encoding UTF8
    if ($after -ne $live) {
        Write-Host '[s10] FAIL: factory\magic_allocations.jsonl CHANGED during the run -- restore it from git before doing anything else' -ForegroundColor Red
        exit 1
    }
    Write-Host '  [OK ] the working tree copy of the exception list is byte-identical to before the run'
}

if ($partBFail -gt 0) {
    Write-Host "[s10] PART B: $partBFail of $partB check(s) FAILED -- the real guard did not behave as declared" -ForegroundColor Red
    exit 1
}
Write-Host "[s10] S10 cage green; the real check_state.ps1 fired on $partB driven case(s)" -ForegroundColor Green
exit 0
