<#
    scripts\lib\evidence.ps1 -- ORDER-674. The PowerShell half of ORDER-670's reader.

    THE RULE, unchanged and not re-derived here:
        A BUILDER observes the world. A CHECKER judges the commit.
    Design: _triage\factory_os\TIER_SNAPSHOT_DESIGN.md rev 2. This file is that design's
    section 3 for the six guards the tier runs BEFORE it, which `evidence.py` gives no entry
    point and which were therefore never migrated.

    WHY IT EXISTS, MEASURED RATHER THAN ARGUED. Counting reads across the six front guards:

        guard                        disk   git   declared
        check_state                     6     0          0     <-- judges the LIVE INVENTORY
        check_precommit_staged          1     5          0
        check_order_collision           0     3          0
        check_handoff_contract          0     7          0
        check_experiment_events         0     5          0
        check_verdict_kill              0     2          0

    Five read git already; NOBODY WROTE DOWN WHICH, so a deliberate choice and an accident
    looked identical. `check_state` reads the working tree exclusively -- and it is the guard
    that runs FIRST on every commit and enforces the `account|magic` uniqueness invariant over
    `portfolio\DEPLOYMENTS.csv`, the single inventory for real money.

    PROVED, not inferred, before a line of this was written: append a duplicate account|magic
    row, STAGE it, restore the clean worktree copy ->
        [OK]   no duplicate account|magic in inventory
        === CLEAN - no drift detected ===
    The commit writes a corrupted live inventory with the gate green. That is `A7` exactly, at
    the highest-value target in the repo.

    NO FALLBACK, for the reason paid for twice on the python side (ORDER-615 S1, then Spec4):
    tracked-but-unreadable and untracked-in-hook-mode are FAILURES, never a quiet worktree read.
    A fallback is how a checker approves bytes the commit does not contain.

    MODE ARRIVAL matches the python side exactly: EA_LAB_EVIDENCE=index, set by the caller.
    A value that is neither `index` nor `worktree` is REFUSED rather than defaulted -- a typo
    that silently became `worktree` would be the old defect wearing a new hat.

    ASCII-only (Windows PowerShell 5.1 decodes a BOM-less .ps1 as ANSI).
    USAGE  . "$PSScriptRoot\..\lib\evidence.ps1"   then  Get-EvidenceMode / Read-Committed
#>

# NO Set-StrictMode HERE, DELIBERATELY. This file is dot-sourced, and dot-sourcing does not
# create a scope: a StrictMode set here changes the rules for the WHOLE host script, which has
# already produced a commit rejected by an error in code nobody had edited
# (memory: strictmode-in-dotsourced-library-leaks). A shared library must be inert to its caller.

function Get-EvidenceMode {
    <# -> 'index' | 'worktree'. Refuses anything else. #>
    $m = $env:EA_LAB_EVIDENCE
    if ([string]::IsNullOrWhiteSpace($m)) { return 'worktree' }
    $m = $m.Trim().ToLowerInvariant()
    if ($m -ne 'index' -and $m -ne 'worktree') {
        # PARENTHESISED. `"a" + "b" -f $x` parses as `"a" + ("b" -f $x)`, so only the LAST
        # fragment is formatted and every {0} above it renders LITERALLY. Caught by this
        # library's own cage on its first run: the refusal printed `evidence mode '{0}'`, which
        # is a message that cannot tell you what was wrong -- a diagnostic that has lost the
        # one fact it exists to carry.
        throw (("evidence mode '{0}' is not 'index' or 'worktree' -- refused, not defaulted: " +
                "a typo that silently became worktree would judge the wrong bytes with no " +
                "sign anything happened.") -f $m)
    }
    return $m
}

function Get-EvidenceMarker {
    <# The one line a caller prints so a reader can tell WHICH claim they are holding.
       Records GIT_INDEX_FILE because a partial commit (`git commit <paths>`) publishes a
       TEMPORARY index through it, and a run that judged that index should say so. #>
    param([Parameter(Mandatory)][string]$Component)
    $gi = if ($env:GIT_INDEX_FILE) { $env:GIT_INDEX_FILE } else { 'default' }
    return ('##EVIDENCE-MODE## {0} {1} git_index={2}' -f $Component, (Get-EvidenceMode), $gi)
}

function Invoke-EvidenceGitBytes {
    <# `git <args>` -> raw stdout BYTES, so the caller controls decoding.
       The console codepage mangles the Thai these boards are full of, which is why every
       git-reading guard in this repo already uses this shape rather than the call operator. #>
    param([Parameter(Mandatory)][string]$Arguments, [string]$RepoRoot)
    if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'git'
    $psi.Arguments = $Arguments
    $psi.WorkingDirectory = $RepoRoot
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $ms = New-Object System.IO.MemoryStream
    $proc.StandardOutput.BaseStream.CopyTo($ms)
    $err = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    return [pscustomobject]@{ ExitCode = $proc.ExitCode; Bytes = $ms.ToArray(); StdErr = $err }
}

function ConvertFrom-EvidenceUtf8 {
    param([byte[]]$Bytes)
    if ($null -eq $Bytes -or $Bytes.Length -eq 0) { return '' }
    $enc = New-Object System.Text.UTF8Encoding($false)
    $t = $enc.GetString($Bytes)
    if ($t.Length -gt 0 -and [int]$t[0] -eq 0xFEFF) { $t = $t.Substring(1) }
    # Normalise to LF so PARSING is mode-independent. Consequence, stated here rather than
    # discovered: index-vintage and disk-vintage HASHES are then incommensurable, and no
    # criterion may equate them (core.autocrlf is on; blobs are LF, the worktree is CRLF).
    return $t.Replace("`r`n", "`n")
}

function Read-Committed {
    <# The category-A read: the bytes the COMMIT will contain, in index mode; the disk otherwise.

       Throws on any inability to answer. "I could not read it" is not "it is fine", and the
       two must not share an exit path -- every caller here maps a throw to its tooling-failure
       code, never to a verdict. #>
    param([Parameter(Mandatory)][string]$RelPath, [string]$RepoRoot)
    if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
    $rel = $RelPath.Replace('\', '/')
    if ((Get-EvidenceMode) -eq 'index') {
        $r = Invoke-EvidenceGitBytes -Arguments ('show ":{0}"' -f $rel) -RepoRoot $RepoRoot
        if ($r.ExitCode -eq 0) { return (ConvertFrom-EvidenceUtf8 -Bytes $r.Bytes) }
        $chk = Invoke-EvidenceGitBytes -Arguments ('ls-files --cached --error-unmatch -- "{0}"' -f $rel) -RepoRoot $RepoRoot
        if ($chk.ExitCode -eq 0) {
            throw ("{0} is in the index but not readable from it: {1}" -f $rel, $r.StdErr.Trim())
        }
        $onDisk = Test-Path -LiteralPath (Join-Path $RepoRoot ($rel -replace '/', '\'))
        throw (("{0} is not in the index{1}. In hook mode this reader judges what the commit " +
                "will contain; reading the disk instead would approve bytes the commit does " +
                "not have, so there is no fallback.") -f $rel,
               $(if ($onDisk) { ' (it exists in the working tree)' } else { '' }))
    }
    $full = Join-Path $RepoRoot ($rel -replace '/', '\')
    if (-not (Test-Path -LiteralPath $full)) {
        throw ("{0} does not exist in the working tree" -f $rel)
    }
    return (ConvertFrom-EvidenceUtf8 -Bytes ([System.IO.File]::ReadAllBytes($full)))
}

function Test-CommittedPath {
    <# Existence is a judged fact too -- "the file is gone" and "the file is gone FROM THE
       COMMIT" are different, and a guard that checks the wrong one approves a deletion. #>
    param([Parameter(Mandatory)][string]$RelPath, [string]$RepoRoot)
    if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
    $rel = $RelPath.Replace('\', '/')
    if ((Get-EvidenceMode) -eq 'index') {
        $chk = Invoke-EvidenceGitBytes -Arguments ('ls-files --cached --error-unmatch -- "{0}"' -f $rel) -RepoRoot $RepoRoot
        return ($chk.ExitCode -eq 0)
    }
    return (Test-Path -LiteralPath (Join-Path $RepoRoot ($rel -replace '/', '\')))
}

function Get-CommittedPaths {
    <# ENUMERATION IS A JUDGED READ (design 3.2). Get-ChildItem picks PATHS from the disk, so a
       staged file whose worktree copy was deleted is invisible to it and present in the commit.
       That is A7 through the channel nothing had named, and it is why this exists rather than
       callers globbing. #>
    param([Parameter(Mandatory)][string]$Pattern, [string]$RepoRoot)
    if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
    $pat = $Pattern.Replace('\', '/')
    if ((Get-EvidenceMode) -eq 'index') {
        # core.quotePath=false, or a non-ASCII path (Thai, emoji, ...) comes back C-quoted --
        # '"\360\237\227\272..."', literal backslashes and quotes -- and every caller here treats
        # the line as a ready-to-use relative path, so it gets Join-Path'd verbatim into garbage
        # ("Illegal characters in path", 2026-08-06). This is the only call in the file that reads
        # PATHS out of git output; show/rev-parse calls elsewhere take an already-known path in, so
        # quoting never touches them.
        $r = Invoke-EvidenceGitBytes -Arguments ('-c core.quotePath=false ls-files --cached -- ":(glob){0}"' -f $pat) -RepoRoot $RepoRoot
        if ($r.ExitCode -ne 0) { throw ("ls-files failed for '{0}': {1}" -f $pat, $r.StdErr.Trim()) }
        return @((ConvertFrom-EvidenceUtf8 -Bytes $r.Bytes) -split "`n" | Where-Object { $_ })
    }
    $hits = @(Get-ChildItem -Path (Join-Path $RepoRoot ($pat -replace '/', '\')) -File -ErrorAction SilentlyContinue)
    $root = $RepoRoot.TrimEnd('\') + '\'
    return @($hits | ForEach-Object { $_.FullName.Substring($root.Length).Replace('\', '/') } | Sort-Object)
}
