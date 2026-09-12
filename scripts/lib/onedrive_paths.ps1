<#
onedrive_paths.ps1 - fail-closed resolution for the Personal OneDrive transport root.

The Windows OneDrive client records the actual Personal folder in HKCU.  It is
not necessarily under the current user's profile, so callers must not infer it.
#>

function Resolve-EaLabPersonalOneDriveRoot {
    [CmdletBinding()]
    param(
        # Test/operational override.  It remains subject to the same existence check.
        [string]$Override = '',
        # Injection seam for deterministic tests; production uses the Personal account key.
        [string]$RegistryPath = 'HKCU:\Software\Microsoft\OneDrive\Accounts\Personal'
    )

    $candidate = $Override
    if (-not $candidate) {
        try { $candidate = [string](Get-ItemPropertyValue -LiteralPath $RegistryPath -Name 'UserFolder' -ErrorAction Stop) }
        catch { throw "Personal OneDrive UserFolder is unavailable at '$RegistryPath': $($_.Exception.Message)" }
    }
    if (-not $candidate -or -not $candidate.Trim()) {
        throw 'Personal OneDrive root is empty; refusing to infer a fallback path'
    }
    try {
        $resolved = [System.IO.Path]::GetFullPath($candidate.Trim())
        $driveRoot = [System.IO.Path]::GetPathRoot($resolved)
        if ($resolved -ne $driveRoot) { $resolved = $resolved.TrimEnd('\') }
    }
    catch { throw "Personal OneDrive root is not a usable path: '$candidate'" }
    if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
        throw "Personal OneDrive root does not exist: '$resolved'"
    }
    return $resolved
}

function Get-EaLabVpsSyncPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$PersonalOneDriveRoot,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )
    return (Join-Path $PersonalOneDriveRoot (Join-Path 'EA_LAB_VPS_SYNC' $RelativePath))
}
