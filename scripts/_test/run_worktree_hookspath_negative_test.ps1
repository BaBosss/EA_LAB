<#
run_worktree_hookspath_negative_test.ps1 - M0-LANE2 cage for Audit D-F4.

THE DEFECT, REPRODUCED LIVE ON THIS REPO AT CANONICAL 649207d6
  The PRIMARY checkout's .git/config carries

      [core]
          hooksPath = D:\EA_LAB\.githooks

  in LOCAL scope. Local scope is SHARED BY EVERY LINKED WORKTREE, so a brand-new, clean linked
  worktree resolved core.hooksPath to the PRIMARY's .githooks - and .githooks/fast_tier_pathspec
  was MODIFIED-UNCOMMITTED in that primary at the time. A clean lane therefore committed under
  foreign, uncommitted hook bytes: the guard that ran was not the guard in the tree being
  committed. `extensions.worktreeConfig` is true on this repo, so the correct per-worktree pin is

      git config --worktree core.hooksPath .githooks

WHAT THIS FILE ASSERTS - THREE LAYERS, EACH IN BOTH DIRECTIONS
  1. BEHAVIOUR. Real git, real commits, in a throwaway repo with a real linked worktree. An
     ABSOLUTE hooksPath makes the worktree run the PRIMARY's hook; a RELATIVE '.githooks' makes
     it run its OWN; and the primary's own behaviour is unchanged by either.
  2. THE ASSERTION. Test-EaLabHooksPathOwnership must FIRE on the foreign case and must NOT
     fire on the healthy control. Identical verdicts for both would mean the assertion is inert.
  3. THE REMEDY. A --worktree-scoped pin must beat the inherited local value, because that is
     the fix the operator is told to apply.

  The rule under test is "does the resolved hooks dir BELONG TO THE COMMITTING CHECKOUT" - it is
  deliberately NOT "is the value relative". An absolute path that points at this worktree's own
  .githooks is fine, and case F proves the assertion says so.

WHY THE LINKED WORKTREE IS BUILT BY HAND
  `git worktree add` is not available to this lane. The worktree is therefore assembled from its
  documented parts - <gitdir>/worktrees/<name>/{HEAD,commondir,gitdir} plus a <worktree>/.git
  file - and then populated with read-tree + checkout-index. Case A proves the result is a real
  linked worktree by asking git, not by assuming. Nothing outside the temp fixture is touched:
  no worktree of any EA_LAB checkout is created, moved, or removed.

FIXTURE HYGIENE
  Everything lives under the system temp dir, never under an EA_LAB checkout. GIT_INDEX_FILE,
  GIT_DIR and GIT_WORK_TREE are cleared before any git runs - an inherited GIT_INDEX_FILE once
  deleted 5,135 entries from a real commit's index on this machine (memory:
  git-index-file-poisons-fixture-repos). Cleanup removes only what this file created.

ASCII-only on purpose (PS 5.1 reads scripts as ANSI; non-ASCII output from a suite running
inside the pre-commit hook raises UnicodeEncodeError and the suite reports THREW).
#>
[CmdletBinding()]
param([string]$RepoRoot = '')

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) {
    $here = $PSScriptRoot
    if (-not $here) { throw 'cannot resolve script directory; pass -RepoRoot explicitly' }
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $here)
}
$RepoRoot = ([System.IO.Path]::GetFullPath($RepoRoot)).TrimEnd('\')
. (Join-Path $RepoRoot 'scripts\lib\repo_paths.ps1')

$script:pass = 0
$script:fail = 0
function Assert-True {
    param([string]$Name, $Cond, [string]$Detail = '')
    if ($Cond) { $script:pass++; Write-Host ("  [PASS] {0}" -f $Name) -ForegroundColor Green }
    else {
        $script:fail++
        Write-Host ("  [FAIL] {0}" -f $Name) -ForegroundColor Red
        if ($Detail) { Write-Host ("         {0}" -f $Detail) -ForegroundColor Red }
    }
}

function Write-AsciiLf {
    # LF endings matter: a pre-commit hook is run by sh, and CRLF makes it fail to execute.
    param([string]$Path, [string[]]$Lines)
    $text = ($Lines -join "`n") + "`n"
    [System.IO.File]::WriteAllText($Path, $text, (New-Object System.Text.ASCIIEncoding))
}

function Invoke-Git {
    param([string]$WorkDir, [string[]]$GitArgs)
    $saved = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & git -C $WorkDir @GitArgs 2>$null
        return [pscustomobject]@{ code = $LASTEXITCODE; out = @($out) }
    } finally { $ErrorActionPreference = $saved }
}

Write-Host '[worktree-hookspath-negative-test] running'

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("hookspathcage_" + [guid]::NewGuid().ToString('N').Substring(0, 10))
$createdTmp = $false
$savedEnv = @{}
foreach ($v in @('GIT_INDEX_FILE', 'GIT_DIR', 'GIT_WORK_TREE')) {
    $savedEnv[$v] = [Environment]::GetEnvironmentVariable($v)
    Remove-Item -Path ("Env:" + $v) -ErrorAction SilentlyContinue
}

try {
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    $createdTmp = $true
    $P = Join-Path $tmp 'primary'
    $W = Join-Path $tmp 'linked'
    New-Item -ItemType Directory -Path $P -Force | Out-Null

    # -----------------------------------------------------------------------
    # Fixture: a primary repo with one commit, plus a second branch for the worktree.
    # -----------------------------------------------------------------------
    $null = Invoke-Git $P @('init', '--quiet')
    $null = Invoke-Git $P @('config', 'user.email', 'cage@example.invalid')
    $null = Invoke-Git $P @('config', 'user.name',  'hookspath cage')
    $null = Invoke-Git $P @('config', 'commit.gpgsign', 'false')
    $null = Invoke-Git $P @('config', 'extensions.worktreeConfig', 'true')
    Write-AsciiLf (Join-Path $P 'seed.txt') @('seed')
    $null = Invoke-Git $P @('add', 'seed.txt')
    $null = Invoke-Git $P @('commit', '--quiet', '-m', 'seed')
    $null = Invoke-Git $P @('branch', 'wt')

    $primaryGitDir = ((Invoke-Git $P @('rev-parse', '--absolute-git-dir')).out[0] -replace '/', '\').TrimEnd('\')

    # Assemble the linked worktree by hand (see header).
    $wtAdmin = Join-Path $primaryGitDir 'worktrees\linked'
    New-Item -ItemType Directory -Path $wtAdmin -Force | Out-Null
    New-Item -ItemType Directory -Path $W -Force | Out-Null
    Write-AsciiLf (Join-Path $wtAdmin 'HEAD')      @('ref: refs/heads/wt')
    Write-AsciiLf (Join-Path $wtAdmin 'commondir') @('../..')
    Write-AsciiLf (Join-Path $wtAdmin 'gitdir')    @((Join-Path $W '.git'))
    Write-AsciiLf (Join-Path $W '.git')            @(('gitdir: ' + $wtAdmin))
    $null = Invoke-Git $W @('read-tree', 'HEAD')
    $null = Invoke-Git $W @('checkout-index', '-a', '-f')

    # A. The fixture must really BE a linked worktree, per git, or every case below is theatre.
    $wGitDir = ((Invoke-Git $W @('rev-parse', '--absolute-git-dir')).out[0] -replace '/', '\').TrimEnd('\')
    Assert-True 'A1 fixture: the linked worktree resolves to <primary gitdir>\worktrees\linked' `
        ($wGitDir -eq $wtAdmin) ("got '{0}' expected '{1}'" -f $wGitDir, $wtAdmin)
    Assert-True 'A2 fixture: <linked>\.git is a FILE, not a directory' `
        (Test-Path -LiteralPath (Join-Path $W '.git') -PathType Leaf)
    Assert-True 'A3 fixture: the worktree has the seed file checked out' `
        (Test-Path -LiteralPath (Join-Path $W 'seed.txt'))

    # Two hooks with DIFFERENT identities. Each writes its identity into the work tree it is
    # invoked from (a hook's cwd is the top of that work tree), so the marker's CONTENT says
    # which hook ran and its LOCATION says where the commit happened.
    foreach ($pair in @(@{ Root = $P; Id = 'PRIMARY' }, @{ Root = $W; Id = 'WORKTREE' })) {
        $hd = Join-Path $pair.Root '.githooks'
        New-Item -ItemType Directory -Path $hd -Force | Out-Null
        Write-AsciiLf (Join-Path $hd 'pre-commit') @(
            '#!/bin/sh',
            ('printf "%s\n" "' + $pair.Id + '" > .hookmarker'),
            'exit 0'
        )
    }

    function Get-HookMarker {
        param([string]$WorkDir)
        $m = Join-Path $WorkDir '.hookmarker'
        if (Test-Path -LiteralPath $m) { return ((Get-Content -LiteralPath $m -Raw) -replace '\s', '') }
        return '<no-marker>'
    }
    function New-FixtureCommit {
        param([string]$WorkDir, [string]$Tag)
        $m = Join-Path $WorkDir '.hookmarker'
        if (Test-Path -LiteralPath $m) { Remove-Item -LiteralPath $m -Force }
        Write-AsciiLf (Join-Path $WorkDir ($Tag + '.txt')) @($Tag)
        $null = Invoke-Git $WorkDir @('add', ($Tag + '.txt'))
        return (Invoke-Git $WorkDir @('commit', '--quiet', '-m', $Tag))
    }

    # -----------------------------------------------------------------------
    # B. THE DEFECT: an ABSOLUTE hooksPath in the primary's LOCAL config.
    # -----------------------------------------------------------------------
    $null = Invoke-Git $P @('config', '--local', 'core.hooksPath', (Join-Path $P '.githooks'))
    $seenInW = (Invoke-Git $W @('config', '--get', 'core.hooksPath')).out[0]
    Assert-True 'B1 DEFECT: the linked worktree INHERITS the primary absolute hooksPath' `
        ($seenInW -eq ((Join-Path $P '.githooks') -replace '\\', '/') -or $seenInW -eq (Join-Path $P '.githooks')) `
        ("worktree sees '{0}'" -f $seenInW)

    $r = New-FixtureCommit -WorkDir $W -Tag 'defect'
    $markerW = Get-HookMarker -WorkDir $W
    Assert-True 'B2 DEFECT: committing in the linked worktree ran the PRIMARY hook bytes' `
        ($markerW -eq 'PRIMARY') ("commit exit={0}; marker in the worktree said '{1}'" -f $r.code, $markerW)

    # B3 is the ASSERTION half: it must FIRE here.
    $own = Test-EaLabHooksPathOwnership -RepoRoot $W
    Assert-True 'B3 ASSERTION FIRES: hooksPath ownership on the linked worktree is FOREIGN' `
        ($own.verdict -eq 'FOREIGN' -and -not $own.ok) `
        ("verdict='{0}' ok={1} resolved='{2}'" -f $own.verdict, $own.ok, $own.resolved)

    # -----------------------------------------------------------------------
    # C. THE FIX (a): a RELATIVE value. git resolves it per work tree.
    # -----------------------------------------------------------------------
    $null = Invoke-Git $P @('config', '--local', 'core.hooksPath', '.githooks')
    $r = New-FixtureCommit -WorkDir $W -Tag 'relative'
    $markerW2 = Get-HookMarker -WorkDir $W
    Assert-True 'C1 FIX: with a RELATIVE hooksPath the worktree runs its OWN hook' `
        ($markerW2 -eq 'WORKTREE') ("commit exit={0}; marker said '{1}'" -f $r.code, $markerW2)
    $own2 = Test-EaLabHooksPathOwnership -RepoRoot $W
    Assert-True 'C2 HEALTHY CONTROL: the assertion does NOT fire on the relative value' `
        ($own2.verdict -eq 'OWN' -and $own2.ok) `
        ("verdict='{0}' ok={1} resolved='{2}'" -f $own2.verdict, $own2.ok, $own2.resolved)
    Assert-True 'C3 NOT INERT: the same assertion gave different verdicts for the two configs' `
        ($own.verdict -ne $own2.verdict) ("both were '{0}'" -f $own.verdict)

    # -----------------------------------------------------------------------
    # D. THE PRIMARY MUST BE UNAFFECTED by either shape.
    # -----------------------------------------------------------------------
    $r = New-FixtureCommit -WorkDir $P -Tag 'primary_rel'
    $markerP = Get-HookMarker -WorkDir $P
    Assert-True 'D1 primary: with the relative value the primary still runs its OWN hook' `
        ($markerP -eq 'PRIMARY') ("commit exit={0}; marker said '{1}'" -f $r.code, $markerP)
    $ownP = Test-EaLabHooksPathOwnership -RepoRoot $P
    Assert-True 'D2 primary: ownership verdict is OWN' ($ownP.verdict -eq 'OWN' -and $ownP.ok) `
        ("verdict='{0}' resolved='{1}'" -f $ownP.verdict, $ownP.resolved)

    $null = Invoke-Git $P @('config', '--local', 'core.hooksPath', (Join-Path $P '.githooks'))
    $r = New-FixtureCommit -WorkDir $P -Tag 'primary_abs'
    $markerP2 = Get-HookMarker -WorkDir $P
    Assert-True 'D3 primary: with the ABSOLUTE value the primary is still correct (it points at itself)' `
        ($markerP2 -eq 'PRIMARY') ("commit exit={0}; marker said '{1}'" -f $r.code, $markerP2)
    $ownP2 = Test-EaLabHooksPathOwnership -RepoRoot $P
    Assert-True 'D4 primary: an absolute value pointing at ITSELF is OWN, not FOREIGN' `
        ($ownP2.verdict -eq 'OWN' -and $ownP2.ok) ("verdict='{0}'" -f $ownP2.verdict)

    # -----------------------------------------------------------------------
    # E. EMPTY is not UNSET. An empty core.hooksPath disables hooks while looking configured -
    #    the exact "looks green, guard disarmed" shape, so it must be a FAILURE verdict.
    # -----------------------------------------------------------------------
    #    A REAL TRAP FOUND WRITING THIS CASE, recorded because it produced a false FAIL that
    #    looked like a product bug: `Invoke-Git $W @('config','--worktree','core.hooksPath','')`
    #    does NOT set an empty value. Windows PowerShell 5.1 DROPS empty-string arguments when
    #    splatting to a native executable, so git received `config --worktree core.hooksPath`
    #    -- a READ -- and the config was never touched. The first run of this case therefore
    #    reported verdict='FOREIGN' (the inherited primary value, still in force) and the
    #    commit ran the PRIMARY hook. The empty value is written into config.worktree directly,
    #    which is also how a human or a tool would produce it, and git is then asked to confirm
    #    it reads back as empty before anything is asserted about it.
    $null = Invoke-Git $W @('config', '--worktree', 'core.hooksPath', 'placeholder')
    $cfgW = Join-Path $wtAdmin 'config.worktree'
    $cfgTxt = [System.IO.File]::ReadAllText($cfgW)
    $cfgTxt = [regex]::Replace($cfgTxt, '(?m)^(\s*)hooksPath\s*=.*$', "`thooksPath =")
    [System.IO.File]::WriteAllText($cfgW, $cfgTxt, (New-Object System.Text.ASCIIEncoding))
    $emptyRead = Invoke-Git $W @('config', '--get', 'core.hooksPath')
    Assert-True 'E0 fixture: git reads core.hooksPath back as an EMPTY value' `
        ($emptyRead.code -eq 0 -and (([string](@($emptyRead.out)[0])).Trim().Length -eq 0)) `
        ("exit={0} value='{1}' - if this fails the E cases below are not testing EMPTY at all" -f $emptyRead.code, ([string](@($emptyRead.out)[0])))
    $ownEmpty = Test-EaLabHooksPathOwnership -RepoRoot $W
    Assert-True 'E1 EMPTY: an empty core.hooksPath is reported EMPTY and NOT ok' `
        ($ownEmpty.verdict -eq 'EMPTY' -and -not $ownEmpty.ok) ("verdict='{0}'" -f $ownEmpty.verdict)
    $rEmpty = New-FixtureCommit -WorkDir $W -Tag 'empty'
    $markerEmpty = Get-HookMarker -WorkDir $W
    Assert-True 'E2 EMPTY: the commit ran NO hook at all (proving why EMPTY must fail)' `
        ($markerEmpty -eq '<no-marker>') ("commit exit={0}; marker said '{1}'" -f $rEmpty.code, $markerEmpty)

    # -----------------------------------------------------------------------
    # F. THE REMEDY: a --worktree pin must beat the inherited local value, and an absolute pin
    #    at THIS worktree's own .githooks must be accepted (the rule is ownership, not syntax).
    # -----------------------------------------------------------------------
    $null = Invoke-Git $W @('config', '--worktree', 'core.hooksPath', '.githooks')
    $r = New-FixtureCommit -WorkDir $W -Tag 'pinned'
    $markerPin = Get-HookMarker -WorkDir $W
    Assert-True 'F1 REMEDY: the --worktree pin overrides the primary absolute local value' `
        ($markerPin -eq 'WORKTREE') ("commit exit={0}; marker said '{1}'" -f $r.code, $markerPin)
    $ownPin = Test-EaLabHooksPathOwnership -RepoRoot $W
    Assert-True 'F2 REMEDY: ownership verdict under the pin is OWN' `
        ($ownPin.verdict -eq 'OWN' -and $ownPin.ok) ("verdict='{0}'" -f $ownPin.verdict)

    $null = Invoke-Git $W @('config', '--worktree', 'core.hooksPath', (Join-Path $W '.githooks'))
    $ownAbsOwn = Test-EaLabHooksPathOwnership -RepoRoot $W
    Assert-True 'F3 SPECIFICITY: an ABSOLUTE pin at this worktree own .githooks is OWN, not FOREIGN' `
        ($ownAbsOwn.verdict -eq 'OWN' -and $ownAbsOwn.ok) `
        ("verdict='{0}' resolved='{1}' - the rule is ownership of the resolved path, not whether the value is relative" -f $ownAbsOwn.verdict, $ownAbsOwn.resolved)

    # -----------------------------------------------------------------------
    # G. UNSET. With no core.hooksPath anywhere, git uses <gitdir>/hooks, which belongs to this
    #    checkout - so UNSET is ok. Distinguishing UNSET from EMPTY is the point of case E.
    # -----------------------------------------------------------------------
    $null = Invoke-Git $W @('config', '--worktree', '--unset-all', 'core.hooksPath')
    $null = Invoke-Git $P @('config', '--local', '--unset-all', 'core.hooksPath')
    $ownUnset = Test-EaLabHooksPathOwnership -RepoRoot $W
    Assert-True 'G1 UNSET: no core.hooksPath is reported UNSET and IS ok' `
        ($ownUnset.verdict -eq 'UNSET' -and $ownUnset.ok) `
        ("verdict='{0}' reason='{1}'" -f $ownUnset.verdict, $ownUnset.reason)

    # -----------------------------------------------------------------------
    # H. THE LIVE OPERATOR SURFACE. This checkout, right now, must own its own hooks. This is
    #    the case that would have gone red on 2026-08-20 before the --worktree pin was applied.
    # -----------------------------------------------------------------------
    $ownLive = Test-EaLabHooksPathOwnership -RepoRoot $RepoRoot
    Assert-True 'H1 LIVE: the checkout running this test owns its resolved hooks path' $ownLive.ok `
        ("verdict='{0}' configured='{1}' resolved='{2}' - fix with: git -C {3} config --worktree core.hooksPath .githooks" -f `
            $ownLive.verdict, $ownLive.configured, $ownLive.resolved, $RepoRoot)
}
finally {
    foreach ($v in $savedEnv.Keys) {
        if ($null -ne $savedEnv[$v]) { Set-Item -Path ("Env:" + $v) -Value $savedEnv[$v] }
    }
    if ($createdTmp -and $tmp -and (Test-Path -LiteralPath $tmp)) {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ''
Write-Host ("[worktree-hookspath-negative-test] {0} passed, {1} failed" -f $script:pass, $script:fail)
if ($script:fail -gt 0) { exit 1 }
exit 0
