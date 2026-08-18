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
