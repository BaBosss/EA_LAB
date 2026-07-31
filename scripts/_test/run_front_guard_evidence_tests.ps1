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
    $raw = [System.IO.File]::ReadAllText((Join-Path $RepoRoot ($INV -replace '/', '\')))
    $lines = @($raw -split "`r?`n" | Where-Object { $_ })
    $dupRow = $lines[1]

    # -- D0 SPECIFICITY, BEFORE the attack. Stage a row with a UNIQUE account|magic. Both guards
    #    must be green. Without this, D1 going red would be satisfied just as well by a rule that
    #    refuses any staged inventory at all -- and "the filter matches everything" is the same
    #    class of defect as "the filter matches nothing", which is what D1 exists to close.
    # Only the MAGIC changes. Changing the ACCOUNT instead makes check_state red for an entirely
    # different reason -- an account absent from DEMO_DEPLOYMENT_PLAN.md -- and a specificity
    # case that goes red for an unrelated rule proves nothing about the rule under test. Found
    # by running it: the first version flipped the account and check_state exited 1 while
    # check_precommit_staged exited 0, i.e. the case was measuring the DEMO-plan check.
    $uf = @($dupRow -split ',')
    if ($uf.Count -lt 7) { Bad 'D0 cannot build a unique row: inventory row 1 has fewer than 7 fields' }
    $uf[6] = '9999999'
    $uniqRow = ($uf -join ',')
    [System.IO.File]::WriteAllText((Join-Path $RepoRoot ($INV -replace '/', '\')),
                                   ($raw.TrimEnd("`r", "`n") + "`n" + $uniqRow + "`n"))
    [void](Git ('add -- "{0}"' -f $INV))
    Copy-Item -LiteralPath $backup -Destination $INV -Force
    $d0state = RunGuard 'index'
    $prevEAP0 = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $d0 = @(& $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'scripts\check_precommit_staged.ps1') 2>&1)
        $d0code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prevEAP0 }
    if ($d0state.Code -eq 0 -and $d0code -eq 0) {
        Good 'D0 SPECIFICITY a staged inventory row with a UNIQUE account|magic is green in BOTH guards'
    } else {
        Bad ("D0 SPECIFICITY a unique row was refused: check_state $($d0state.Code), " +
             "check_precommit_staged $d0code -- the rule is over-matching, not enforcing")
    }

    # --- stage the attack: a duplicate account|magic, worktree left clean -------------------
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

    # -- D: the SECOND guard over the same invariant, against the SAME staged state -----------
    # check_precommit_staged has its own ORDER-144 duplicate-account|magic rule, and it read the
    # right bytes and then filtered every one of them away: `$_.magic -match '^d+$'` is a lost
    # backslash, matching literal `d` characters. 0 of 64 real rows passed it, so the rule has
    # been dead since baa1b6f5. Two independent guards over the single inventory for real money,
    # neither able to fire, FAILING FOR DIFFERENT REASONS -- which is why fixing check_state in
    # ORDER-674 did not reveal this one.
    $pcs = Join-Path $RepoRoot 'scripts\check_precommit_staged.ps1'
    $prevEAP2 = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $d1 = @(& $ps -NoProfile -ExecutionPolicy Bypass -File $pcs 2>&1)
        $d1code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prevEAP2 }
    if ($d1code -ne 0 -and (($d1 -join "`n") -match 'duplicate account\|magic')) {
        Good 'D1 ATTACK check_precommit_staged also refuses the staged duplicate -- its ORDER-144 rule can fire at last'
    } else {
        Bad ("D1 ATTACK expected exit!=0 naming the duplicate; got exit $d1code. That is the " +
             "pre-fix behaviour: the filter '^d+' matched 0 of 64 rows, so the rule was inert.")
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

# ===========================================================================================
# B -- ORDER-674 owed half: check_order_collision judged the ARCHIVE at HEAD while judging the
#      ACTIVE board at the index. RULE 1 asks "does an id appear in BOTH boards", and both
#      boards means both boards in the RESULTING repository -- which is the index.
#
# Same attack shape as A, and the same reason for a TEMP index: staging into `.git/index` is
# what ORDER-670's T6 refuses, correctly.
# ===========================================================================================
$ACTIVE  = 'AGENT_TASKBOARD.md'
$ARCHIVE = 'ARCHIVE_TASKBOARD_2026-07A.md'
$collide = Join-Path $RepoRoot 'scripts\check_order_collision.ps1'
# 711 is inside THIS lane's reserved block (S-2026-07-31-FRONTDECL, 710-719) on purpose: RULE 2
# must stay silent so the assertion can only be satisfied by RULE 1. A probe id that also
# breached the reserved-block rule would go red for the wrong reason and prove nothing.
$probeId = '711'
$probeHdr = "## ORDER-$probeId -- L3 probe, never committed"

function RunCollision {
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & $ps -NoProfile -ExecutionPolicy Bypass -File $collide 2>&1
        return [pscustomobject]@{ Text = (@($out) -join "`n"); Code = $LASTEXITCODE }
    } finally { $ErrorActionPreference = $prevEAP }
}

$origActiveIdx  = GitText ('rev-parse ":{0}"' -f $ACTIVE)
$origArchiveIdx = GitText ('rev-parse ":{0}"' -f $ARCHIVE)
$bakActive  = Join-Path ([System.IO.Path]::GetTempPath()) ("fg674b_" + [guid]::NewGuid().ToString('N') + '.md')
$bakArchive = Join-Path ([System.IO.Path]::GetTempPath()) ("fg674b_" + [guid]::NewGuid().ToString('N') + '.md')
Copy-Item -LiteralPath $ACTIVE -Destination $bakActive -Force
Copy-Item -LiteralPath $ARCHIVE -Destination $bakArchive -Force

$tmpIndex2 = Join-Path ([System.IO.Path]::GetTempPath()) ("fg674b_" + [guid]::NewGuid().ToString('N') + '.idx')
Copy-Item -LiteralPath (Join-Path $RepoRoot '.git\index') -Destination $tmpIndex2 -Force
$prevIndexEnv2 = $env:GIT_INDEX_FILE
$realIndexBefore2 = (Get-Item -LiteralPath (Join-Path $RepoRoot '.git\index')).LastWriteTimeUtc
$env:GIT_INDEX_FILE = $tmpIndex2
try {
    # B0 SPECIFICITY FIRST, so "the attack goes red" cannot be confused with "this guard always
    # goes red": stage the ACTIVE board alone, with the probe header, and no archive change.
    # One board, one id -- RULE 1 has nothing to find and the run must be green.
    [System.IO.File]::AppendAllText((Join-Path $RepoRoot $ACTIVE), "`n$probeHdr`n")
    [void](Git ('add -- "{0}"' -f $ACTIVE))
    Copy-Item -LiteralPath $bakActive -Destination $ACTIVE -Force
    $b0 = RunCollision
    if ($b0.Code -eq 0) {
        Good 'B0 SPECIFICITY a new order on ONE board only is green -- the rule is not "always red"'
    } else {
        Bad ("B0 SPECIFICITY expected exit 0 for a single-board order; got $($b0.Code). " +
             ($b0.Text -split "`n" | Select-Object -Last 2) -join ' | ')
    }

    # B1 THE ATTACK. The SAME id now also enters the ARCHIVE in this commit. That is the
    # cross-board duplicate RULE 1 exists to refuse -- and it is created ENTIRELY by this
    # commit, so a HEAD read cannot see it. Pre-fix this printed PASS.
    [System.IO.File]::AppendAllText((Join-Path $RepoRoot $ARCHIVE), "`n$probeHdr`n")
    [void](Git ('add -- "{0}"' -f $ARCHIVE))
    Copy-Item -LiteralPath $bakArchive -Destination $ARCHIVE -Force
    $b1 = RunCollision
    if ($b1.Code -ne 0 -and $b1.Text -match ('ORDER-{0} exists in BOTH' -f $probeId)) {
        Good 'B1 ATTACK an id staged into BOTH boards by one commit is RED -- the archive is judged at the index'
    } else {
        Bad ("B1 ATTACK expected exit!=0 naming ORDER-$probeId in both boards; got exit $($b1.Code). " +
             'This is the pre-fix behaviour: the commit lands the cross-board duplicate green.')
    }
} finally {
    Copy-Item -LiteralPath $bakActive -Destination $ACTIVE -Force
    Copy-Item -LiteralPath $bakArchive -Destination $ARCHIVE -Force
    if ($null -eq $prevIndexEnv2) { Remove-Item Env:GIT_INDEX_FILE -ErrorAction SilentlyContinue }
    else { $env:GIT_INDEX_FILE = $prevIndexEnv2 }
    Remove-Item -LiteralPath $bakActive, $bakArchive, $tmpIndex2 -Force -ErrorAction SilentlyContinue
}

# ASSERTED, not assumed -- these two files are the work queue of every lane in the repo.
$nowActiveIdx  = GitText ('rev-parse ":{0}"' -f $ACTIVE)
$nowArchiveIdx = GitText ('rev-parse ":{0}"' -f $ARCHIVE)
$nowIndexAfter2 = (Get-Item -LiteralPath (Join-Path $RepoRoot '.git\index')).LastWriteTimeUtc
if ($nowActiveIdx -eq $origActiveIdx -and $nowArchiveIdx -eq $origArchiveIdx -and
    $nowIndexAfter2 -eq $realIndexBefore2) {
    Good 'B  both boards are byte-identical afterwards and .git/index was never written'
} else {
    Bad ('B  THE BOARDS WERE NOT RESTORED (or the real index was written): ' +
         "active $nowActiveIdx (was $origActiveIdx), archive $nowArchiveIdx (was $origArchiveIdx)")
}

# ===========================================================================================
# C -- ORDER-674 owed half: check_handoff_contract resolved ORDER tokens against the ACTIVE
#      board at the index and the ARCHIVE at HEAD. Same mixed pair as B, opposite symptom:
#      here it REFUSED VALID WORK rather than missing an invalid commit.
#
# WORK_LIFECYCLE (Decision log 2026-07-26) requires "REVIEWED* = archive it immediately, SAME
# COMMIT". So the mandated shape is a commit that moves `## ORDER-X` from the active board into
# the archive. A handoff in that same commit routing an item to ORDER-X resolved against
# NEITHER board -- gone from the staged active, not yet in HEAD's archive.
# ===========================================================================================
$handoff = Join-Path $RepoRoot 'scripts\check_handoff_contract.ps1'
$probeC = '712'
$probeRel = '_triage/HANDOFF_FG674_PROBE.md'
$probeAbs = Join-Path $RepoRoot ($probeRel -replace '/', '\')

function RunHandoff {
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & $ps -NoProfile -ExecutionPolicy Bypass -File $handoff 2>&1
        return [pscustomobject]@{ Text = (@($out) -join "`n"); Code = $LASTEXITCODE }
    } finally { $ErrorActionPreference = $prevEAP }
}

$origArchiveIdx2 = GitText ('rev-parse ":{0}"' -f $ARCHIVE)
$bakArchive2 = Join-Path ([System.IO.Path]::GetTempPath()) ("fg674c_" + [guid]::NewGuid().ToString('N') + '.md')
Copy-Item -LiteralPath $ARCHIVE -Destination $bakArchive2 -Force
$tmpIndex3 = Join-Path ([System.IO.Path]::GetTempPath()) ("fg674c_" + [guid]::NewGuid().ToString('N') + '.idx')
Copy-Item -LiteralPath (Join-Path $RepoRoot '.git\index') -Destination $tmpIndex3 -Force
$prevIndexEnv3 = $env:GIT_INDEX_FILE
$realIndexBefore3 = (Get-Item -LiteralPath (Join-Path $RepoRoot '.git\index')).LastWriteTimeUtc
$env:GIT_INDEX_FILE = $tmpIndex3
try {
    # The handoff routes ONE item, to an order that exists only in the STAGED archive.
    $body = @(
        '# HANDOFF probe -- ORDER-674 cage, never committed',
        '',
        '<!-- HANDOFF-ROUTING -->',
        '',
        '| item | destination |',
        '|---|---|',
        ("| the probe item | ORDER-{0} |" -f $probeC),
        ''
    ) -join "`n"
    [System.IO.File]::WriteAllText($probeAbs, $body)
    [void](Git ('add -- "{0}"' -f $probeRel))

    # C0 SPECIFICITY, run FIRST: the same handoff routing to an id that exists NOWHERE must
    # BLOCK, before and after the fix. Without this, "C1 is green" would be satisfied just as
    # well by a guard that resolves everything -- which is what a too-permissive read produces.
    $c0 = RunHandoff
    if ($c0.Code -ne 0 -and $c0.Text -match ('ORDER-{0}' -f $probeC)) {
        Good 'C0 SPECIFICITY a routing token that exists on NO board still BLOCKS -- the fix does not resolve everything'
    } else {
        Bad ("C0 SPECIFICITY expected exit!=0 for an unresolvable ORDER-$probeC; got $($c0.Code)")
    }

    # C1 THE ATTACK: the same commit now also puts `## ORDER-712` into the archive -- the
    # same-commit archive move WORK_LIFECYCLE mandates. It must resolve.
    [System.IO.File]::AppendAllText((Join-Path $RepoRoot $ARCHIVE),
                                    ("`n## ORDER-{0} -- L3 probe, never committed`n" -f $probeC))
    [void](Git ('add -- "{0}"' -f $ARCHIVE))
    Copy-Item -LiteralPath $bakArchive2 -Destination $ARCHIVE -Force
    $c1 = RunHandoff
    if ($c1.Code -eq 0) {
        Good 'C1 ATTACK a handoff routing to an order archived BY THIS COMMIT resolves -- the archive is judged at the index'
    } else {
        Bad ("C1 ATTACK expected exit 0; got $($c1.Code). This is the pre-fix behaviour: the guard " +
             'REFUSES the same-commit archive move WORK_LIFECYCLE requires (Decision log 2026-07-30).')
    }
} finally {
    Copy-Item -LiteralPath $bakArchive2 -Destination $ARCHIVE -Force
    Remove-Item -LiteralPath $probeAbs -Force -ErrorAction SilentlyContinue
    if ($null -eq $prevIndexEnv3) { Remove-Item Env:GIT_INDEX_FILE -ErrorAction SilentlyContinue }
    else { $env:GIT_INDEX_FILE = $prevIndexEnv3 }
    Remove-Item -LiteralPath $bakArchive2, $tmpIndex3 -Force -ErrorAction SilentlyContinue
}
$nowArchiveIdx2 = GitText ('rev-parse ":{0}"' -f $ARCHIVE)
if ($nowArchiveIdx2 -eq $origArchiveIdx2 -and
    (Get-Item -LiteralPath (Join-Path $RepoRoot '.git\index')).LastWriteTimeUtc -eq $realIndexBefore3 -and
    -not (Test-Path -LiteralPath $probeAbs)) {
    Good 'C  the archive is byte-identical, the probe handoff is gone, and .git/index was never written'
} else {
    Bad ('C  cleanup failed: archive ' + $nowArchiveIdx2 + " (was $origArchiveIdx2)" +
         $(if (Test-Path -LiteralPath $probeAbs) { " -- AND $probeRel is still on disk" } else { '' }))
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
