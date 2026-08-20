<#
    run_hook_safety_fixture_tests.ps1 -- Audit D, 2026-08-20. Lane 3.

    Drives THREE hook-level repairs in fixture repositories, in BOTH directions:

      D-F3  .githooks/pre-push          non-fast-forward / deletion refusal on master
      D-F2  .githooks/pre-commit        staged mode-160000 gitlink refusal
      D-F4  .githooks/pre-commit        hooksPath assertion (which bytes are executing)

    WHY A FIXTURE. All three are decisions a hook makes about a repository's own state, so the
    only honest way to observe them is to build that state. Asserting on the hook's SOURCE TEXT
    would be the guard-checks-the-wrong-surface defect; this suite runs the real files.

    THE FIXTURE TRAP THIS EXPLICITLY DEFUSES: a throwaway repo created from inside a git
    operation inherits GIT_INDEX_FILE / GIT_DIR / GIT_WORK_TREE from the parent process, and this
    repo has already had a fixture write into a real index that way (git-index-file-poisons-
    fixture-repos: 5,135 entries of a real commit deleted). Every child process below is launched
    with those three variables CLEARED, and the clearing is itself asserted before any case runs.

    NOT WIRED into the fast tier -- see its row in scripts/_test/SUITE_TIER_REGISTRY.txt.
    ASCII-only output: a suite that ever runs inside the hook must never raise UnicodeEncodeError.

    Note on D-F2/D-F4 controls: the real pre-commit continues into check_state.ps1 and the whole
    EA_LAB guard chain, which cannot pass in a 2-file fixture. So the HEALTHY control here is
    "the D-F2/D-F4 diagnostic is ABSENT", and the end-to-end healthy proof is a real commit in
    this worktree (see the report / CASE H at the end).
#>
[CmdletBinding()]
param([string]$RepoRoot)

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) {
    $d = $PSScriptRoot
    if (-not $d -and $MyInvocation.MyCommand.Path) { $d = Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $d) { throw 'cannot resolve script directory; pass -RepoRoot' }
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $d)
}

$script:fail = 0
function Bad([string]$m) { Write-Host "  [FAIL] $m" -ForegroundColor Red; $script:fail++ }
function Good([string]$m) { Write-Host "  [ok]   $m" }
function Sect([string]$m) { Write-Host ''; Write-Host $m }

# ---- environment hygiene, asserted rather than assumed ---------------------------------
foreach ($v in 'GIT_INDEX_FILE', 'GIT_DIR', 'GIT_WORK_TREE', 'GIT_OBJECT_DIRECTORY', 'GIT_ALTERNATE_OBJECT_DIRECTORIES') {
    Remove-Item -Path ("Env:" + $v) -ErrorAction SilentlyContinue
}
$leaked = @()
foreach ($v in 'GIT_INDEX_FILE', 'GIT_DIR', 'GIT_WORK_TREE') {
    if (Test-Path ("Env:" + $v)) { $leaked += $v }
}
if ($leaked.Count -gt 0) {
    Bad ("fixture hygiene: {0} still set -- refusing to create fixture repos that could write into a real index" -f ($leaked -join ', '))
    exit 1
}
Good 'fixture hygiene: GIT_INDEX_FILE / GIT_DIR / GIT_WORK_TREE are cleared'

$hookSrcCommit = Join-Path $RepoRoot '.githooks\pre-commit'
$hookSrcPush   = Join-Path $RepoRoot '.githooks\pre-push'
foreach ($h in $hookSrcCommit, $hookSrcPush) {
    if (-not (Test-Path -LiteralPath $h)) { Bad "missing hook under test: $h"; exit 1 }
}

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("hookfx_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root -Force | Out-Null

function Invoke-Fixgit {
    # NOT $Args: that is a PowerShell automatic variable and the parameter never binds,
    # so every call silently ran a bare `git -C <dir>` and this suite went 17-red on nothing.
    param([string]$Dir, [string[]]$GArgs)
    # PS 5.1: redirecting a NATIVE command's stderr wraps each line in an ErrorRecord, and under
    # $ErrorActionPreference='Stop' that THROWS on ordinary git progress output. git writes push
    # progress to stderr, so this suite died on its first successful push. Scoped to the helper.
    $ErrorActionPreference = 'Continue'
    $out = & git -C $Dir @GArgs 2>&1
    return [pscustomobject]@{ Code = $LASTEXITCODE; Text = (($out | Out-String).TrimEnd()) }
}
function NewRepo {
    param([string]$Name, [switch]$Bare)
    $p = Join-Path $root $Name
    if ($Bare) { & git init --bare -q $p 2>&1 | Out-Null }
    else {
        & git init -q $p 2>&1 | Out-Null
        Invoke-Fixgit $p @('config', 'user.email', 'fixture@ea-lab.invalid') | Out-Null
        Invoke-Fixgit $p @('config', 'user.name', 'fixture') | Out-Null
        Invoke-Fixgit $p @('config', 'commit.gpgsign', 'false') | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $p '.githooks') -Force | Out-Null
        Copy-Item -LiteralPath $hookSrcCommit -Destination (Join-Path $p '.githooks\pre-commit') -Force
        Copy-Item -LiteralPath $hookSrcPush   -Destination (Join-Path $p '.githooks\pre-push')   -Force
        Invoke-Fixgit $p @('config', 'core.hooksPath', '.githooks') | Out-Null
        Invoke-Fixgit $p @('checkout', '-q', '-b', 'master') | Out-Null
    }
    return $p
}
# Runs a hook DIRECTLY, from the repo root, so a single assertion branch can be isolated. Used
# only where a real git operation cannot reach the branch (see each case).
function RunHook {
    param([string]$Dir, [string]$Hook, [string]$Stdin = '')
    Push-Location $Dir
    $ErrorActionPreference = 'Continue'
    try {
        if ($Stdin) {
            $out = ($Stdin | & sh (".githooks/" + $Hook) origin fixture 2>&1)
        } else {
            $out = (& sh (".githooks/" + $Hook) 2>&1)
        }
        return [pscustomobject]@{ Code = $LASTEXITCODE; Text = (($out | Out-String).TrimEnd()) }
    } finally { Pop-Location }
}

try {
    # =====================================================================================
    Sect '[hook-fixture] D-F3 -- pre-push: master non-fast-forward / deletion'
    $bare = NewRepo -Name 'remote.git' -Bare
    $w    = NewRepo -Name 'w1'
    Set-Content -LiteralPath (Join-Path $w 'a.txt') -Value 'one' -Encoding ASCII
    Invoke-Fixgit $w @('add', 'a.txt') | Out-Null
    Invoke-Fixgit $w @('commit', '-q', '--no-verify', '-m', 'c1') | Out-Null
    Invoke-Fixgit $w @('remote', 'add', 'origin', $bare) | Out-Null

    # CONTROL: a fast-forward push must PASS. Without this the four refusals below are
    # consistent with "the hook refuses everything", which is not protection, it is breakage.
    $r = Invoke-Fixgit $w @('push', 'origin', 'master')
    if ($r.Code -eq 0) { Good 'FF push to master PASSES (creation)' } else { Bad "FF creation push was blocked: $($r.Text)" }

    Add-Content -LiteralPath (Join-Path $w 'a.txt') -Value 'two'
    Invoke-Fixgit $w @('commit', '-q', '--no-verify', '-am', 'c2') | Out-Null
    $r = Invoke-Fixgit $w @('push', 'origin', 'master')
    if ($r.Code -eq 0 -and $r.Text -match 'fast-forward .* -- allowed') {
        Good 'FF push to master PASSES and says so (second push)'
    } else { Bad "second FF push blocked or silent: $($r.Text)" }
    $remoteTipBefore = (Invoke-Fixgit $bare @('rev-parse', 'master')).Text.Trim()

    # ATTACK 1: rewrite the tip and force it with the '+' refspec. This is a REAL push, not a
    # stdin drive: the whole point is that git itself hands the hook the diverged pair.
    Invoke-Fixgit $w @('reset', '-q', '--soft', 'HEAD~1') | Out-Null
    Invoke-Fixgit $w @('commit', '-q', '--no-verify', '-m', 'c2-rewritten') | Out-Null
    $r = Invoke-Fixgit $w @('push', 'origin', '+refs/heads/master:refs/heads/master')
    $remoteTipAfter = (Invoke-Fixgit $bare @('rev-parse', 'master')).Text.Trim()
    if ($r.Code -ne 0 -and $r.Text -match 'PREPUSH-REFUSED \(D-F3\): NON-FAST-FORWARD') {
        if ($remoteTipBefore -eq $remoteTipAfter) {
            Good 'ATTACK forced NON-FAST-FORWARD push of master is REFUSED and the remote tip is unchanged'
        } else { Bad 'the push was refused but the remote tip MOVED -- the refusal did not take effect' }
    } else { Bad "ATTACK non-FF master push was not refused (exit $($r.Code)): $($r.Text)" }

    # ATTACK 2: deletion of master.
    $r = Invoke-Fixgit $w @('push', 'origin', ':refs/heads/master')
    if ($r.Code -ne 0 -and $r.Text -match 'would DELETE refs/heads/master') {
        Good 'ATTACK deletion of master is REFUSED'
    } else { Bad "ATTACK master deletion was not refused (exit $($r.Code))" }
    if ((Invoke-Fixgit $bare @('rev-parse', 'master')).Code -eq 0) { Good 'master still exists on the fixture remote' }
    else { Bad 'master was deleted from the fixture remote despite the refusal' }

    # ATTACK 3: fail-closed when ancestry is UNDECIDABLE. Real git will not construct this pair
    # (it only reports tips it knows), so the hook is driven directly with a remote sha that is
    # not in the object store -- the state a stale clone is in when it is about to clobber.
    $localTip = (Invoke-Fixgit $w @('rev-parse', 'master')).Text.Trim()
    $r = RunHook -Dir $w -Hook 'pre-push' -Stdin ("refs/heads/master $localTip refs/heads/master deadbeefdeadbeefdeadbeefdeadbeefdeadbeef")
    if ($r.Code -ne 0 -and $r.Text -match 'fail-closed' -and $r.Text -match 'CANNOT be decided') {
        Good 'ATTACK an unknown remote tip on master FAILS CLOSED (undecidable != allowed)'
    } else { Bad "ATTACK undecidable ancestry did not fail closed (exit $($r.Code)): $($r.Text)" }

    # SPECIFICITY: a NON-MASTER branch must be untouched, force included. Over-blocking is how a
    # hook earns --no-verify, and a bypassed hook protects nothing.
    Invoke-Fixgit $w @('checkout', '-q', '-b', 'feature', 'master') | Out-Null
    Add-Content -LiteralPath (Join-Path $w 'a.txt') -Value 'three'
    Invoke-Fixgit $w @('commit', '-q', '--no-verify', '-am', 'f1') | Out-Null
    $r = Invoke-Fixgit $w @('push', 'origin', 'feature')
    if ($r.Code -eq 0) { Good 'SPECIFICITY a non-master branch pushes normally' } else { Bad "non-master push blocked: $($r.Text)" }
    Invoke-Fixgit $w @('commit', '-q', '--no-verify', '--amend', '-m', 'f1-rewritten') | Out-Null
    $r = Invoke-Fixgit $w @('push', 'origin', '+refs/heads/feature:refs/heads/feature')
    if ($r.Code -eq 0 -and $r.Text -notmatch 'PREPUSH-REFUSED') {
        Good 'SPECIFICITY a FORCED rewrite of a non-master branch is NOT blocked (no over-reach)'
    } else { Bad "SPECIFICITY forced non-master push was blocked (exit $($r.Code)) -- the hook over-blocks" }
    $r = RunHook -Dir $w -Hook 'pre-push' -Stdin ("refs/heads/feature 0000000000000000000000000000000000000000 refs/heads/feature $localTip")
    if ($r.Code -eq 0) { Good 'SPECIFICITY deleting a non-master branch is NOT blocked' }
    else { Bad 'SPECIFICITY non-master deletion was blocked -- the hook over-blocks' }

    # =====================================================================================
    Sect '[hook-fixture] D-F2 -- pre-commit: staged mode-160000 gitlink'
    $w2 = NewRepo -Name 'w2'
    Set-Content -LiteralPath (Join-Path $w2 'keep.txt') -Value 'base' -Encoding ASCII
    Invoke-Fixgit $w2 @('add', 'keep.txt') | Out-Null
    Invoke-Fixgit $w2 @('commit', '-q', '--no-verify', '-m', 'base') | Out-Null

    # A nested worker repository, exactly the shape `git add -A` sweeps up.
    $nested = Join-Path $w2 'worker_repo'
    & git init -q $nested 2>&1 | Out-Null
    Invoke-Fixgit $nested @('config', 'user.email', 'n@n.invalid') | Out-Null
    Invoke-Fixgit $nested @('config', 'user.name', 'n') | Out-Null
    Set-Content -LiteralPath (Join-Path $nested 'x.txt') -Value 'x' -Encoding ASCII
    Invoke-Fixgit $nested @('add', 'x.txt') | Out-Null
    Invoke-Fixgit $nested @('commit', '-q', '--no-verify', '-m', 'nested') | Out-Null

    Invoke-Fixgit $w2 @('add', '-A') | Out-Null
    # Prove the fixture actually IS the defect before asserting on the refusal: a case that
    # cannot reproduce the state it tests is a green that means nothing.
    $stage = Invoke-Fixgit $w2 @('ls-files', '--stage')
    if ($stage.Text -match '(?m)^160000\s') { Good 'fixture reproduces the defect: a mode-160000 entry is STAGED' }
    else { Bad 'fixture did NOT stage a gitlink -- the D-F2 cases below would prove nothing'; }

    $r = RunHook -Dir $w2 -Hook 'pre-commit'
    if ($r.Code -ne 0 -and $r.Text -match 'PRECOMMIT-FAIL-CLOSED \(D-F2\)' -and $r.Text -match 'worker_repo') {
        Good 'ATTACK a staged gitlink is REFUSED, by path, fail-closed (no .gitmodules in this repo)'
    } else { Bad "ATTACK staged gitlink was not refused (exit $($r.Code)): $($r.Text)" }
    # and the refusal must actually stop a real commit, not merely print
    $r2 = Invoke-Fixgit $w2 @('commit', '-m', 'would land a gitlink')
    if ($r2.Code -ne 0 -and $r2.Text -match 'D-F2') { Good 'ATTACK the real `git commit` is blocked by the same refusal' }
    else { Bad "ATTACK `git commit` was NOT blocked (exit $($r2.Code)): $($r2.Text)" }

    # SPECIFICITY 1: the same repo with the gitlink unstaged must NOT hit D-F2.
    # PLAIN `rm --cached` (no -f) REFUSES on an embedded repo whose working-tree .git is still
    # present: "staged content different from both the file and the HEAD (use -f to force
    # removal)". That refusal was previously silently discarded (`| Out-Null`, exit code never
    # checked), so the gitlink stayed staged and this case was asserting on the WRONG fixture --
    # it was really re-running the ATTACK case and (correctly) seeing D-F2 fire, then reporting
    # that as this case's failure. -f + an explicit exit-code check makes the setup honest.
    $rmr = Invoke-Fixgit $w2 @('rm', '--cached', '-f', '-q', 'worker_repo')
    if ($rmr.Code -ne 0) {
        Bad "SPECIFICITY 1 setup: could not unstage worker_repo ($($rmr.Text)) -- the no-gitlink fixture cannot be trusted"
    } else {
        Set-Content -LiteralPath (Join-Path $w2 'keep.txt') -Value 'ordinary edit' -Encoding ASCII
        Invoke-Fixgit $w2 @('add', 'keep.txt') | Out-Null
        $r = RunHook -Dir $w2 -Hook 'pre-commit'
        if ($r.Text -notmatch 'D-F2') { Good 'SPECIFICITY an ordinary staged text edit does NOT trip D-F2' }
        else { Bad 'SPECIFICITY D-F2 fired on a commit with no staged gitlink -- the guard is indiscriminate' }
    }

    # SPECIFICITY 2: a FUTURE governed submodule. A .gitmodules that DECLARES the path is
    # allowed, so this is a fail-closed default and not a permanent prohibition.
    Set-Content -LiteralPath (Join-Path $w2 '.gitmodules') -Encoding ASCII -Value @(
        '[submodule "worker_repo"]',
        '	path = worker_repo',
        '	url = https://example.invalid/worker.git')
    Invoke-Fixgit $w2 @('add', '.gitmodules') | Out-Null
    Invoke-Fixgit $w2 @('add', 'worker_repo') | Out-Null
    $stage = Invoke-Fixgit $w2 @('ls-files', '--stage')
    if ($stage.Text -match '(?m)^160000\s') {
        $r = RunHook -Dir $w2 -Hook 'pre-commit'
        if ($r.Text -notmatch 'PRECOMMIT-FAIL-CLOSED \(D-F2\)' -and $r.Text -match 'DECLARED in .gitmodules') {
            Good 'SPECIFICITY a gitlink DECLARED in a valid .gitmodules is ALLOWED (not a permanent block)'
        } else { Bad "SPECIFICITY a declared submodule was still refused: $($r.Text)" }
    } else { Bad 'could not re-stage the gitlink for the .gitmodules case' }

    # SPECIFICITY 3: a MALFORMED/undeclaring .gitmodules must NOT launder the gitlink. The
    # declaration is parsed by git itself against the INDEX blob, so garbage yields no
    # declarations and the refusal stands.
    Set-Content -LiteralPath (Join-Path $w2 '.gitmodules') -Encoding ASCII -Value @('this is not a config file', 'path = worker_repo')
    Invoke-Fixgit $w2 @('add', '.gitmodules') | Out-Null
    $r = RunHook -Dir $w2 -Hook 'pre-commit'
    if ($r.Code -ne 0 -and $r.Text -match 'PRECOMMIT-FAIL-CLOSED \(D-F2\)') {
        Good 'SPECIFICITY a malformed .gitmodules does NOT launder the gitlink -- still refused'
    } else { Bad "SPECIFICITY a malformed .gitmodules waved the gitlink through: $($r.Text)" }

    # =====================================================================================
    Sect '[hook-fixture] D-F4 -- pre-commit: hooksPath assertion'
    # Two independent trees, so "foreign" is a real other checkout rather than a renamed path.
    $wA = NewRepo -Name 'treeA'
    $wB = NewRepo -Name 'treeB'
    foreach ($t in $wA, $wB) {
        Set-Content -LiteralPath (Join-Path $t 'f.txt') -Value 'x' -Encoding ASCII
        Invoke-Fixgit $t @('add', 'f.txt') | Out-Null
        Invoke-Fixgit $t @('commit', '-q', '--no-verify', '-m', 'base') | Out-Null
        Set-Content -LiteralPath (Join-Path $t 'f.txt') -Value 'y' -Encoding ASCII
        Invoke-Fixgit $t @('add', 'f.txt') | Out-Null
    }
    $aHooks = (Resolve-Path (Join-Path $wA '.githooks')).Path
    $bHooks = (Resolve-Path (Join-Path $wB '.githooks')).Path

    # CONTROL first. The relative '.githooks' convention must pass SILENTLY -- no refusal and no
    # warning. A guard that also complains about the correct configuration is one people mute.
    $r = RunHook -Dir $wB -Hook 'pre-commit'
    if ($r.Text -notmatch 'D-F4') { Good "CONTROL core.hooksPath='.githooks' passes SILENTLY (no D-F4 output at all)" }
    else { Bad "CONTROL the correct relative '.githooks' produced D-F4 output: $($r.Text)" }

    # A1 -- FOREIGN BYTES. This is the reproduced primary/linked-worktree leak: treeB's config
    # points at treeA's hook directory, so treeA's bytes judge a commit in treeB. Driven through
    # a REAL `git commit`, because $0 is what git hands the hook and that is the whole assertion.
    Invoke-Fixgit $wB @('config', 'core.hooksPath', $aHooks) | Out-Null
    $r = Invoke-Fixgit $wB @('commit', '-m', 'commit judged by another tree hooks')
    if ($r.Code -ne 0 -and $r.Text -match 'PRECOMMIT-FAIL-CLOSED \(D-F4/A1\)') {
        Good 'ATTACK A1 hook bytes from ANOTHER worktree are REFUSED on a real `git commit`'
    } else { Bad "ATTACK A1 a foreign hook directory was accepted (exit $($r.Code)): $($r.Text)" }

    # A2b -- git RESOLVES outside this worktree, while the file that is running is the local one.
    # Not reachable through `git commit` (there, A1 fires first and correctly), so the local hook
    # is invoked directly: $0 is local, config is foreign.
    $r = RunHook -Dir $wB -Hook 'pre-commit'
    if ($r.Code -ne 0 -and $r.Text -match 'PRECOMMIT-FAIL-CLOSED \(D-F4/A2b\)') {
        Good 'ATTACK A2b an absolute hooksPath pointing at ANOTHER tree is REFUSED'
    } else { Bad "ATTACK A2b a foreign resolved hooksPath was accepted (exit $($r.Code)): $($r.Text)" }

    # A2a -- EMPTY. Documented honestly: with hooksPath empty git does not invoke this file, so
    # the branch is reachable only by direct invocation. That is exactly why the branch exists --
    # a hook cannot be the only witness to its own absence -- and both halves are recorded.
    # NOT `git config core.hooksPath ''`: an empty-string ELEMENT in a PowerShell native-argument
    # array is silently DROPPED before exec, so `& git @('config','core.hooksPath','')` actually
    # runs `git config core.hooksPath` (2 args) -- a GET, not a SET -- and core.hooksPath was
    # left at whatever A1/A2b had just pointed it to (treeA's dir), never touched. --unset is
    # the reliable way to reach the same "unset or empty" state this branch tests for; the hook
    # itself treats unset and empty identically (`[ -z "$_hp_raw" ]`).
    Invoke-Fixgit $wB @('config', '--unset', 'core.hooksPath') | Out-Null
    $r = RunHook -Dir $wB -Hook 'pre-commit'
    if ($r.Code -ne 0 -and $r.Text -match 'PRECOMMIT-FAIL-CLOSED \(D-F4/A2a\)') {
        Good 'ATTACK A2a an EMPTY core.hooksPath is REFUSED when the hook is reached'
    } else { Bad "ATTACK A2a an empty hooksPath was accepted (exit $($r.Code)): $($r.Text)" }
    $r = Invoke-Fixgit $wB @('commit', '-m', 'empty hookspath, real commit')
    if ($r.Code -eq 0) {
        Write-Host '  [note] with core.hooksPath EMPTY, git runs NO pre-commit hook at all and the commit'
        Write-Host '         succeeds unguarded. MEASURED, not assumed. An in-hook assertion cannot cover'
        Write-Host '         this case; it is covered from outside, by this suite. Reported as a residual.'
    } else {
        Write-Host "  [note] with core.hooksPath EMPTY the commit was blocked (exit $($r.Code)) -- recorded."
    }

    # A2c -- ABSOLUTE BUT SELF. The correct bytes run, so this WARNS and must NOT block: the
    # primary operator checkout is in exactly this state today.
    $wC = NewRepo -Name 'treeC'
    Set-Content -LiteralPath (Join-Path $wC 'f.txt') -Value 'x' -Encoding ASCII
    Invoke-Fixgit $wC @('add', 'f.txt') | Out-Null
    $cHooks = (Resolve-Path (Join-Path $wC '.githooks')).Path
    Invoke-Fixgit $wC @('config', 'core.hooksPath', $cHooks) | Out-Null
    $r = RunHook -Dir $wC -Hook 'pre-commit'
    if ($r.Text -match 'WARN \(D-F4/A2c\)' -and $r.Text -notmatch 'PRECOMMIT-FAIL-CLOSED \(D-F4') {
        Good 'SPECIFICITY A2c an absolute hooksPath pointing at THIS tree WARNS and does not refuse'
    } else { Bad "SPECIFICITY A2c expected a warning and no D-F4 refusal; got: $($r.Text)" }
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host "[hook-fixture] $($script:fail) FAILURE(S)" -ForegroundColor Red
    exit 1
}
Write-Host '[hook-fixture] all cases green -- D-F3/D-F2/D-F4 each FIRE on the bad state and stay quiet on the healthy control'
exit 0
