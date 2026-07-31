<#
run_front_guard_evidence_tests.ps1 -- ORDER-674 W1.

The six guards in .githooks/pre-commit run BEFORE the fast tier and judge boards, the ledger,
handoffs and the deployment inventory -- committed evidence by any reading. ORDER-670 migrated
the python side and gave these no entry point at all, and the design's own grep over
scripts/*.ps1 returned ZERO declarations, which rev 1 read as "clean". It meant UNMEASURED.

MEASURED (the count that opened this order):

    guard                        disk   git   declared
    check_state                     6     0          0     <-- judges the LIVE INVENTORY
    check_precommit_staged          1     5          0
    check_order_collision           0     3          0
    check_handoff_contract          0     7          0
    check_experiment_events         0     5          0
    check_verdict_kill              0     2          0

Five already read git; nobody had written down which, so a deliberate choice and an accident
were indistinguishable. check_state read the working tree exclusively.

WHAT THIS SUITE PROVES, and each case is driven rather than asserted:

  A1  THE ATTACK. A duplicate account|magic STAGED into portfolio/DEPLOYMENTS.csv behind a
      clean worktree copy is RED in index mode. Before ORDER-674 it printed
      "[OK] no duplicate account|magic" and "CLEAN" -- the commit would have written a
      corrupted live-money inventory with the gate green.
  A2  SPECIFICITY. The same repo state in WORKTREE mode is green: manual-run semantics are
      preserved exactly, and a manual green is a claim about the disk, which the marker says.
  A3  The reader REFUSES an invented mode rather than defaulting to worktree.
  A4  The hook SETS the mode for the front guards. Without this the whole migration is inert
      in the only place it matters, and nothing else in the tree would notice.
  A5  check_state EMITS its marker, so which bytes were judged is readable rather than assumed.

IT STAGES INTO A TEMPORARY INDEX, NOT `.git/index`. The first version staged into the real one
and restored it -- and ORDER-670's own T6 detector caught it inside the fast tier: "the index was
rewritten during the tier -- a verdict over a moving index means nothing". T6 was RIGHT, and
weakening it to admit this suite would have traded a real guard for a test of a guard.

So the attack is staged through GIT_INDEX_FILE against a COPY of the index. `.git/index` is never
touched, T6 stays intact, and the mechanism is the one this repo already documented: a partial
commit (`git commit <paths>`) publishes exactly such a temp index to its hooks, so judging one is
the design rather than a workaround. The variable is scoped to this suite's own git calls and the
child guard -- both against THIS repository, which is the case memory
`git-index-file-poisons-fixture-repos` says is correct; the poison is inheriting it into ANOTHER
repo's git, which never happens here.

The worktree copy is still written and restored (the attack needs the two to disagree), the
original blob shas are captured first, and the suite FAILS if either end does not come back
byte-identical. A suite that could leave the live inventory mutated would be worse than the defect.

ASCII-only (Windows PowerShell 5.1 decodes a BOM-less .ps1 as ANSI).
USAGE  powershell -NoProfile -File scripts\_test\run_front_guard_evidence_tests.ps1
#>
[CmdletBinding()]
param([string]$RepoRoot = '')

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
Push-Location $RepoRoot

$fail = 0
function Bad([string]$m) { Write-Host "  [FAIL] $m" -ForegroundColor Red; $script:fail++ }
function Good([string]$m) { Write-Host "  [ok]   $m" }

# Dot-source the library and drive git THROUGH ITS PRIMITIVE. `& git ...` under
# $ErrorActionPreference='Stop' turns git's stderr into a terminating NativeCommandError -- and
# git warns on EVERY `add` of this file ("LF will be replaced by CRLF"), so the suite killed
# itself mid-restore on its first run. That is not a cosmetic failure: dying between `git add`
# of the attack and the restore is exactly the state this suite must never leave behind.
. (Join-Path $RepoRoot 'scripts\lib\evidence.ps1')
function Git([string]$argline) { Invoke-EvidenceGitBytes -Arguments $argline -RepoRoot $RepoRoot }
function GitText([string]$argline) { (ConvertFrom-EvidenceUtf8 -Bytes (Git $argline).Bytes).Trim() }

$INV = 'portfolio/DEPLOYMENTS.csv'
$guard = Join-Path $RepoRoot 'scripts\check_state.ps1'
$ps = (Get-Process -Id $PID).Path
if (-not $ps) { $ps = 'powershell.exe' }

function RunGuard([string]$mode) {
    $old = $env:EA_LAB_EVIDENCE
    $env:EA_LAB_EVIDENCE = $mode
    # $ErrorActionPreference is dropped to Continue FOR THIS CALL ONLY. Under 'Stop', a native
    # command writing to stderr raises a terminating NativeCommandError -- and case A3 makes the
    # child write to stderr ON PURPOSE (it asserts the reader REFUSES a bogus mode). Under 'Stop'
    # the suite therefore died on the case whose entire point is that the guard fails loudly,
    # which is a harness that cannot observe the behaviour it exists to observe.
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & $ps -NoProfile -ExecutionPolicy Bypass -File $guard -Strict 2>&1
        return [pscustomobject]@{ Text = (@($out) -join "`n"); Code = $LASTEXITCODE }
    } finally {
        $ErrorActionPreference = $prevEAP
        if ($null -eq $old) { Remove-Item Env:EA_LAB_EVIDENCE -ErrorAction SilentlyContinue }
        else { $env:EA_LAB_EVIDENCE = $old }
    }
}

Write-Host '[front-guards] ORDER-674 -- the guards that run BEFORE the tier judge the commit'

# Capture the ORIGINAL index entry first. Everything below restores to this, and the last case
# asserts it came back -- a suite that can leave the live inventory mutated is not acceptable.
$origIndexSha = GitText ('rev-parse ":{0}"' -f $INV)
$origDiskSha  = GitText ('hash-object "{0}"' -f $INV)
if (-not $origIndexSha -or $origIndexSha -ne $origDiskSha) {
    # Refusing to run is the right answer: staging the attack over an already-dirty index would
    # make the restore ambiguous, and an ambiguous restore of THIS file is not a risk worth taking.
    Bad "portfolio/DEPLOYMENTS.csv is not clean (index $origIndexSha vs disk $origDiskSha) -- refusing to run rather than risk an ambiguous restore"
    Pop-Location
    exit 1
}

$backup = Join-Path ([System.IO.Path]::GetTempPath()) ("fg674_" + [guid]::NewGuid().ToString('N') + '.csv')
Copy-Item -LiteralPath $INV -Destination $backup -Force

# A COPY of the index. Everything below stages into this; `.git/index` is never written, so the
# tier's T6 "did the ground move under the run" detector stays true and stays useful.
$tmpIndex = Join-Path ([System.IO.Path]::GetTempPath()) ("fg674_" + [guid]::NewGuid().ToString('N') + '.idx')
Copy-Item -LiteralPath (Join-Path $RepoRoot '.git\index') -Destination $tmpIndex -Force
$prevIndexEnv = $env:GIT_INDEX_FILE
$realIndexBefore = (Get-Item -LiteralPath (Join-Path $RepoRoot '.git\index')).LastWriteTimeUtc
$env:GIT_INDEX_FILE = $tmpIndex
try {
    # --- stage the attack: a duplicate account|magic, worktree left clean -------------------
    $raw = [System.IO.File]::ReadAllText((Join-Path $RepoRoot ($INV -replace '/', '\')))
    $lines = @($raw -split "`r?`n" | Where-Object { $_ })
    $dupRow = $lines[1]
    [System.IO.File]::WriteAllText((Join-Path $RepoRoot ($INV -replace '/', '\')),
                                   ($raw.TrimEnd("`r", "`n") + "`n" + $dupRow + "`n"))
    [void](Git ('add -- "{0}"' -f $INV))
    Copy-Item -LiteralPath $backup -Destination $INV -Force

    $idx = RunGuard 'index'
    if ($idx.Code -ne 0 -and $idx.Text -match 'duplicate account\|magic') {
        Good 'A1 ATTACK a staged duplicate account|magic behind a clean worktree is RED in index mode'
    } else {
        Bad ("A1 ATTACK expected exit!=0 naming the duplicate; got exit $($idx.Code). " +
             'This is the pre-ORDER-674 behaviour: the commit writes a corrupted live inventory green.')
    }

    $wt = RunGuard 'worktree'
    if ($wt.Code -eq 0 -and $wt.Text -match 'no duplicate account\|magic') {
        Good 'A2 SPECIFICITY the same state in worktree mode is green -- manual-run semantics intact'
    } else {
        Bad "A2 SPECIFICITY expected exit 0 in worktree mode; got $($wt.Code)"
    }

    if ($idx.Text -match '##EVIDENCE-MODE## check_state\.ps1 index\b') {
        Good 'A5 check_state states WHICH bytes it judged, so a reader need not trust a comment'
    } else {
        Bad 'A5 check_state emitted no index-mode marker -- the mode cannot be shown to have arrived'
    }
} finally {
    # The worktree copy is restored; the temp index is simply discarded, which is the point of
    # using one -- there is no restore to get wrong.
    Copy-Item -LiteralPath $backup -Destination $INV -Force
    if ($null -eq $prevIndexEnv) { Remove-Item Env:GIT_INDEX_FILE -ErrorAction SilentlyContinue }
    else { $env:GIT_INDEX_FILE = $prevIndexEnv }
    Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $tmpIndex -Force -ErrorAction SilentlyContinue
}

# The restore is ASSERTED, not assumed. `finally` runs; that it did the right thing is a
# separate claim, and this file is the live deployment inventory.
$nowIndexSha = GitText ('rev-parse ":{0}"' -f $INV)
$nowDiskSha  = GitText ('hash-object "{0}"' -f $INV)
if ($nowIndexSha -eq $origIndexSha -and $nowDiskSha -eq $origDiskSha) {
    Good 'A1/A2 the live inventory is byte-identical in BOTH index and worktree afterwards'
} else {
    Bad ("THE INVENTORY WAS NOT RESTORED: index $nowIndexSha (was $origIndexSha), " +
         "disk $nowDiskSha (was $origDiskSha) -- restore by hand from git before committing anything")
}

# ...and the REAL index was never written at all, which is what keeps T6 meaningful. Asserted
# separately from the shas above: "the bytes are back" and "the file was never touched" are
# different claims, and only the second one lets this suite live inside the tier.
$realIndexAfter = (Get-Item -LiteralPath (Join-Path $RepoRoot '.git\index')).LastWriteTimeUtc
if ($realIndexAfter -eq $realIndexBefore) {
    Good 'A6 .git/index was never written -- the attack ran against a temp index, so T6 stays intact'
} else {
    Bad ('A6 .git/index was rewritten by this suite. That is what ORDER-670 T6 exists to refuse, ' +
         'and a test of a guard must not cost a guard.')
}

# --- A3: an invented mode is refused, not defaulted ----------------------------------------
$bogus = RunGuard 'indx'
if ($bogus.Code -ne 0 -and $bogus.Text -match "is not 'index' or 'worktree'") {
    Good 'A3 an invented evidence mode is REFUSED -- a typo must not silently mean worktree'
} else {
    Bad "A3 a bogus mode did not refuse; got exit $($bogus.Code)"
}

# --- A4: the hook actually sets it, or the whole migration is inert where it matters --------
$hook = [System.IO.File]::ReadAllText((Join-Path $RepoRoot '.githooks\pre-commit'))
if ($hook -match '(?m)^\s*export\s+EA_LAB_EVIDENCE=index') {
    Good 'A4 .githooks/pre-commit sets the mode for the front guards'
} else {
    Bad ('A4 the hook does not export EA_LAB_EVIDENCE=index -- every migration above is INERT ' +
         'in the only place it matters, and nothing else in this tree would notice')
}

Pop-Location
if ($fail -gt 0) {
    Write-Host "[front-guards] $fail FAILURE(S)" -ForegroundColor Red
    exit 1
}
Write-Host '[front-guards] the front guards judge the commit, and the attack that proved they did not is now caged'
exit 0
