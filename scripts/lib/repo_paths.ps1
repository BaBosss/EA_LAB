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

function Get-EaLabPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )

    if ([System.IO.Path]::IsPathRooted($RelativePath)) { return $RelativePath }
    return Join-Path $RepoRoot $RelativePath
}
