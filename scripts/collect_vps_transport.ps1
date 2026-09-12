<#
Inspect the lab-side OneDrive return folder.  Snapshots are transport-health
evidence only; RuntimeIdentity is imported through the canonical collector.
#>
[CmdletBinding()]
param(
    [string]$PersonalOneDriveRoot = '',
    [string]$SnapshotDir = '',
    [string]$DestDir = '',
    [int]$SnapshotMaxAgeMinutes = 10
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\repo_paths.ps1')
. (Join-Path $PSScriptRoot 'lib\onedrive_paths.ps1')
$RepoRoot = Resolve-EaLabRepoRoot -AnchorPath $PSCommandPath
if (-not $SnapshotDir) {
    $root = Resolve-EaLabPersonalOneDriveRoot -Override $PersonalOneDriveRoot
    $SnapshotDir = Get-EaLabVpsSyncPath -PersonalOneDriveRoot $root -RelativePath 'vps-to-lab\snapshots'
}
if (-not (Test-Path -LiteralPath $SnapshotDir -PathType Container)) {
    Write-Host "VPS transport FAILED: return folder is unavailable: $SnapshotDir" -ForegroundColor Red
    exit 1
}

$valid = @(Get-ChildItem -LiteralPath $SnapshotDir -Filter 'EA_LAB_snapshot_*.csv' -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^EA_LAB_snapshot_[1-9]\d*\.csv$' })
$fresh = @($valid | Where-Object { ((Get-Date) - $_.LastWriteTime).TotalMinutes -le $SnapshotMaxAgeMinutes })
if (-not $fresh) {
    $newest = @($valid | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
    $detail = if ($newest) { "newest valid snapshot $($newest[0].Name) is $([math]::Round(((Get-Date) - $newest[0].LastWriteTime).TotalMinutes,1)) minutes old" } else { 'no valid EA_LAB_snapshot_[1-9]*.csv found' }
    Write-Host "VPS transport FAILED: $detail (limit $SnapshotMaxAgeMinutes minutes)" -ForegroundColor Red
    exit 1
}
$newestFresh = @($fresh | Sort-Object LastWriteTime -Descending | Select-Object -First 1)[0]
Write-Host "VPS transport PASS: $($newestFresh.Name) is $([math]::Round(((Get-Date) - $newestFresh.LastWriteTime).TotalMinutes,1)) minutes old"

# Identity absence/staleness is deliberately not a transport failure.  The canonical
# collector owns shape, producer timestamp, and archive naming checks; IdentityOnly
# prevents the synced snapshots from ever competing with local monitor telemetry.
$collector = Join-Path $PSScriptRoot 'collect_live_deals.ps1'
& $collector -CommonFiles $SnapshotDir -DestDir $DestDir -IdentityOnly
if ($LASTEXITCODE -ne 0) { throw "identity-only collection failed with exit $LASTEXITCODE" }
exit 0
