<#
repo_paths.ps1 - repository-root resolution shared by the DailyMonitor execution chain.

The resolver walks upward from a script or directory until it finds the checkout's
.git marker. It never consults the current working directory, so Scheduled Task
working-directory defaults cannot redirect the monitor to another checkout.
#>

function Resolve-EaLabRepoRoot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$AnchorPath
    )

    $candidate = [System.IO.Path]::GetFullPath($AnchorPath)
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $candidate = Split-Path -Parent $candidate
    }

    while ($candidate) {
        if (Test-Path -LiteralPath (Join-Path $candidate '.git')) {
            return (Resolve-Path -LiteralPath $candidate).Path.TrimEnd('\')
        }
        $parent = Split-Path -Parent $candidate
        if (-not $parent -or $parent -eq $candidate) { break }
        $candidate = $parent
    }

    throw "could not resolve an EA_LAB repository root from '$AnchorPath'"
}

function Get-EaLabExecutionContext {
    <#
    Get-EaLabExecutionContext - PRIMARY_OPERATOR_WORKSPACE vs NON_PRIMARY_WORKSPACE.

    L9/CR-002 (2026-08-18): *.ex5/*.ex4 are deliberately gitignored (compiled MQL5 binaries),
    so a bare `git worktree add` checkout never materializes them -- only the one primary
    operator checkout does, because that is where the compile/deploy step actually runs. CR-002
    attestation (scripts\control_room_snapshot.ps1) hashes whatever .ex5 sits on disk; from any
    other checkout that is structurally nothing, and its FILE_MISSING states were being read as
    "approved artifact missing" when the real cause was "this checkout was never a compile
    target." Proven directly: the SAME canonical commit, SAME code, SAME row
    (415573666|990208, confidence=high) read HASHED from D:\EA_LAB and FILE_MISSING from a
    freshly created linked worktree -- 18 of 59 attestation rows flipped the same way.

    Classifies by NORMALIZED PATH EQUALITY ONLY against -PrimaryRepoRoot (default D:\EA_LAB) --
    deliberately NOT by whether the root's .git entry is a file (linked worktree) or a directory
    (a real checkout). That test would misclassify a standalone clone -- a real .git directory,
    at the wrong path -- as PRIMARY, which is the exact false-authoritative reading this
    function exists to prevent. Same-shape checkouts are told apart by WHERE they are, not by
    HOW they are attached to git.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedRoot,
        [string]$PrimaryRepoRoot = 'D:\EA_LAB'
    )
    $left  = [System.IO.Path]::GetFullPath($ResolvedRoot).TrimEnd('\')
    $right = [System.IO.Path]::GetFullPath($PrimaryRepoRoot).TrimEnd('\')
    if ($left -eq $right) { return 'PRIMARY_OPERATOR_WORKSPACE' }
    return 'NON_PRIMARY_WORKSPACE'
}

function Get-EaLabPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )

    if ([System.IO.Path]::IsPathRooted($RelativePath)) { return $RelativePath }
    return Join-Path $RepoRoot $RelativePath
}

# ---------------------------------------------------------------------------
# M0-LANE2 / Audit D-F8: resolve the REAL git directory for a checkout.
#
# `Join-Path $RepoRoot '.git'` is only the git dir in a NORMAL checkout. In a linked
# worktree `.git` is a FILE holding `gitdir: <path>`, so every consumer that opened
# `<root>\.git\HEAD` got nothing. PROVED at canonical 649207d6: reading
# 'D:\EA_LAB_M0_L2_canonical\.git\HEAD' returns UNREADABLE while
# `git rev-parse --git-dir` returns D:/EA_LAB/.git/worktrees/EA_LAB_M0_L2_canonical.
#
# git is asked first because it is the only authority that knows about worktrees,
# submodules and `commondir` indirection. The gitdir-file parse is a strict fallback
# for the case where git is not on PATH -- it must never be the primary answer.
# NO NETWORK, no fetch, no index write.
# ---------------------------------------------------------------------------
function Resolve-EaLabGitDir {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [string]$GitExe = 'git'
    )

    $dotGit = Join-Path $RepoRoot '.git'

    $saved = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & $GitExe -C $RepoRoot rev-parse --absolute-git-dir 2>$null
        $code = $LASTEXITCODE
    } catch {
        $out = $null; $code = 1
    } finally {
        $ErrorActionPreference = $saved
    }
    if ($code -eq 0 -and $out) {
        $p = ([string](@($out)[0])).Trim()
        if ($p) { return ($p -replace '/', '\').TrimEnd('\') }
    }

    # Fallback 1: a linked worktree's .git FILE.
    if (Test-Path -LiteralPath $dotGit -PathType Leaf) {
        $line = $null
        try { $line = @(Get-Content -LiteralPath $dotGit -ErrorAction Stop)[0] } catch { $line = $null }
        if ($line -and $line -match '^\s*gitdir:\s*(.+?)\s*$') {
            $target = $Matches[1]
            if (-not [System.IO.Path]::IsPathRooted($target)) {
                $target = Join-Path $RepoRoot $target
            }
            try { return ([System.IO.Path]::GetFullPath($target)).TrimEnd('\') }
            catch { return ($target -replace '/', '\').TrimEnd('\') }
        }
        # A .git file we cannot parse is NOT a directory answer. Refuse rather than hand
        # back a path that does not exist (memory: unreadable-input-must-refuse-not-skip).
        throw "Resolve-EaLabGitDir: '$dotGit' is a file but carries no parsable gitdir: line"
    }

    # Fallback 2: a normal checkout.
    if (Test-Path -LiteralPath $dotGit -PathType Container) { return ([string]$dotGit).TrimEnd('\') }

    throw "Resolve-EaLabGitDir: no .git entry under '$RepoRoot'"
}

# ---------------------------------------------------------------------------
# M0-LANE2 / Audit D-F1: canonicality of a checkout against the canonical ref.
#
# THE DEFECT THIS ANSWERS: scripts\check_state.ps1 printed
# '=== CLEAN - no drift detected ===' for a tree 135 commits BEHIND and 26 AHEAD of
# origin/master (measured on D:\EA_LAB at canonical 649207d6:
#   git -C D:\EA_LAB rev-list --left-right --count origin/master...HEAD  ->  135  26).
# There was ZERO ancestry logic in that guard -- grep for origin|merge-base|rev-list
# returned only comment prose. "No doc drift" was being reported as "current".
#
# CONTRACT
#   Get-EaLabCanonicalityState -RepoRoot <path> [-CanonicalRef <ref>] [-GitExe git]
#   -> [pscustomobject] with fields:
#        state          CANONICAL | AHEAD_CANONICAL | BEHIND_CANONICAL |
#                       DIVERGED_FROM_CANONICAL | REMOTE_UNAVAILABLE | UNKNOWN
#        behind         int, commits on the canonical ref not in HEAD (-1 when unknown)
#        ahead          int, commits in HEAD not on the canonical ref  (-1 when unknown)
#        head           40-hex HEAD sha, or ''
#        canonical_sha  40-hex sha of the canonical ref, or ''
#        canonical_ref  the ref that was consulted
#        dirty          $true when the working tree has uncommitted changes (INFORMATIONAL)
#        publish_gate   ALLOW | BLOCK | UNKNOWN  -- the publication decision
#        publishable    $true only when publish_gate is ALLOW
#        is_current     $true only for state CANONICAL (never BEHIND/DIVERGED/UNKNOWN)
#        reason         short ASCII explanation, always populated
#        git_dir        resolved git dir (linked-worktree safe)
#
# DESIGN CONSTRAINTS, each paid for by a finding in this repo:
#  * NO NETWORK. The canonical ref is the LOCAL remote-tracking ref refs/remotes/origin/master.
#    This function never fetches. Offline therefore yields REMOTE_UNAVAILABLE, not a hang and
#    not a crash. A caller that wants freshness must fetch itself and SAY SO.
#  * A DIRTY TREE STILL GETS A CORRECT ANSWER. Ancestry is computed from committed history;
#    `dirty` is reported alongside and never suppresses the classification.
#  * CANNOT-SEE IS NOT CLEAN. REMOTE_UNAVAILABLE/UNKNOWN set is_current=$false and
#    publish_gate=UNKNOWN. Consumers must not render either as clean/current.
#  * publish_gate=ALLOW only for CANONICAL and AHEAD_CANONICAL. A BEHIND or DIVERGED source
#    would publish superseded content over current content: the operator hazard in D-F1.
# ---------------------------------------------------------------------------
function Get-EaLabCanonicalityState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [string]$CanonicalRef = 'refs/remotes/origin/master',
        [string]$GitExe = 'git'
    )

    $result = [pscustomobject]@{
        state         = 'UNKNOWN'
        behind        = -1
        ahead         = -1
        head          = ''
        canonical_sha = ''
        canonical_ref = $CanonicalRef
        dirty         = $false
        publish_gate  = 'UNKNOWN'
        publishable   = $false
        is_current    = $false
        reason        = ''
        git_dir       = ''
    }

    if (-not (Test-Path -LiteralPath $RepoRoot)) {
        $result.reason = "repo root '$RepoRoot' does not exist"
        return $result
    }

    try { $result.git_dir = Resolve-EaLabGitDir -RepoRoot $RepoRoot -GitExe $GitExe }
    catch { $result.reason = "cannot resolve git dir: $($_.Exception.Message)"; return $result }

    # One local helper so every git call is captured the same way: stdout only, exit code
    # checked explicitly. `2>&1` is deliberately NOT used -- in PS 5.1 it wraps native stderr
    # in ErrorRecords and flips $? even on exit 0.
    $runGit = {
        param([string[]]$GitArgs)
        $saved = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $o = & $GitExe -C $RepoRoot @GitArgs 2>$null
            return [pscustomobject]@{ code = $LASTEXITCODE; out = @($o) }
        } catch {
            return [pscustomobject]@{ code = 1; out = @() }
        } finally {
            $ErrorActionPreference = $saved
        }
    }

    $h = & $runGit @('rev-parse', '--verify', 'HEAD')
    if ($h.code -ne 0 -or $h.out.Count -eq 0) {
        $result.reason = 'cannot read HEAD (unborn branch or not a git repo)'
        return $result
    }
    $result.head = ([string]$h.out[0]).Trim()

    # dirty is asked BEFORE ancestry and never gates it.
    $st = & $runGit @('status', '--porcelain')
    if ($st.code -eq 0) {
        $result.dirty = (@($st.out | Where-Object { $_ -and ([string]$_).Trim().Length -gt 0 }).Count -gt 0)
    }

    $c = & $runGit @('rev-parse', '--verify', ($CanonicalRef + '^{commit}'))
    if ($c.code -ne 0 -or $c.out.Count -eq 0) {
        $result.state        = 'REMOTE_UNAVAILABLE'
        $result.publish_gate = 'UNKNOWN'
        $result.reason       = "canonical ref '$CanonicalRef' is not present locally; no fetch was performed, so canonicality is UNKNOWN (not clean)"
        return $result
    }
    $result.canonical_sha = ([string]$c.out[0]).Trim()

    $rl = & $runGit @('rev-list', '--left-right', '--count', ($CanonicalRef + '...HEAD'))
    if ($rl.code -ne 0 -or $rl.out.Count -eq 0) {
        $result.reason = "rev-list ancestry against '$CanonicalRef' failed"
        return $result
    }
    $parts = @(([string]$rl.out[0]).Trim() -split '\s+' | Where-Object { $_ -match '^\d+$' })
    if ($parts.Count -lt 2) {
        $result.reason = "unparsable rev-list output: '$([string]$rl.out[0])'"
        return $result
    }
    $result.behind = [int]$parts[0]
    $result.ahead  = [int]$parts[1]

    if ($result.behind -eq 0 -and $result.ahead -eq 0) {
        $result.state        = 'CANONICAL'
        $result.is_current   = $true
        $result.publish_gate = 'ALLOW'
        $result.reason       = "HEAD equals $CanonicalRef"
    } elseif ($result.behind -eq 0) {
        $result.state        = 'AHEAD_CANONICAL'
        $result.publish_gate = 'ALLOW'
        $result.reason       = "$($result.ahead) commit(s) ahead of $CanonicalRef, 0 behind"
    } elseif ($result.ahead -eq 0) {
        $result.state        = 'BEHIND_CANONICAL'
        $result.publish_gate = 'BLOCK'
        $result.reason       = "$($result.behind) commit(s) BEHIND $CanonicalRef - this tree is superseded"
    } else {
        $result.state        = 'DIVERGED_FROM_CANONICAL'
        $result.publish_gate = 'BLOCK'
        $result.reason       = "DIVERGED from $CanonicalRef - $($result.behind) behind / $($result.ahead) ahead"
    }
    $result.publishable = ($result.publish_gate -eq 'ALLOW')
    return $result
}

# ---------------------------------------------------------------------------
# M0-LANE2 / Audit D-F4: is the RESOLVED core.hooksPath this worktree's own?
#
# REPRODUCED at canonical: the primary's .git/config carries
# `core.hooksPath = D:\EA_LAB\.githooks` in LOCAL scope, which every linked worktree
# inherits -- so a clean linked worktree commits under the DIRTY primary's hook bytes
# (.githooks/fast_tier_pathspec was modified there at the time). extensions.worktreeConfig
# is true on this repo, so the correct pin is `git config --worktree core.hooksPath .githooks`.
#
# CONTRACT
#   Test-EaLabHooksPathOwnership -RepoRoot <path> [-GitExe git]
#   -> [pscustomobject] @{
#        ok            $true only when the resolved hooks dir is INSIDE $RepoRoot
#        verdict       OWN | EMPTY | FOREIGN | UNSET | UNKNOWN
#        configured    the raw configured value ('' when unset)
#        resolved      absolute resolved hooks dir ('' when it cannot be resolved)
#        repo_root     normalized repo root
#        reason        short ASCII explanation
#      }
#   UNSET (no core.hooksPath at all) is ok=$true: git then uses <gitdir>/hooks, which is
#   this worktree's own. EMPTY (set to the empty string) is a FAILURE, not UNSET -- it
#   disables hooks entirely while looking configured.
# ---------------------------------------------------------------------------
function Test-EaLabHooksPathOwnership {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [string]$GitExe = 'git'
    )

    $res = [pscustomobject]@{
        ok = $false; verdict = 'UNKNOWN'; configured = ''; resolved = ''
        repo_root = ''; reason = ''
    }
    try { $res.repo_root = ([System.IO.Path]::GetFullPath($RepoRoot)).TrimEnd('\') }
    catch { $res.reason = "unusable repo root '$RepoRoot'"; return $res }

    $saved = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out  = & $GitExe -C $RepoRoot config --get core.hooksPath 2>$null
        $code = $LASTEXITCODE
    } catch {
        $out = $null; $code = 1
    } finally {
        $ErrorActionPreference = $saved
    }

    if ($code -ne 0) {
        # exit 1 from `config --get` means "not set". Anything else is a real failure.
        if ($code -eq 1) {
            $res.verdict = 'UNSET'; $res.ok = $true
            $res.reason  = 'core.hooksPath is not set; git uses this worktree own gitdir hooks'
            return $res
        }
        $res.reason = "git config --get core.hooksPath failed with exit $code"
        return $res
    }

    $raw = ''
    if ($out) { $raw = ([string](@($out)[0])) }
    $res.configured = $raw
    if ($raw.Trim().Length -eq 0) {
        $res.verdict = 'EMPTY'
        $res.reason  = 'core.hooksPath is set to an EMPTY value - hooks are silently disabled'
        return $res
    }

    $candidate = $raw.Trim() -replace '/', '\'
    if (-not [System.IO.Path]::IsPathRooted($candidate)) {
        $candidate = Join-Path $res.repo_root $candidate
    }
    try { $res.resolved = ([System.IO.Path]::GetFullPath($candidate)).TrimEnd('\') }
    catch { $res.reason = "core.hooksPath '$raw' is not a usable path"; return $res }

    $rootPrefix = $res.repo_root + '\'
    if ($res.resolved -eq $res.repo_root -or
        $res.resolved.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        $res.verdict = 'OWN'; $res.ok = $true
        $res.reason  = "hooks resolve inside this worktree ($($res.resolved))"
    } else {
        $res.verdict = 'FOREIGN'
        $res.reason  = "core.hooksPath resolves to '$($res.resolved)', OUTSIDE this worktree ($($res.repo_root)) - commits would run another checkout hook bytes"
    }
    return $res
}
