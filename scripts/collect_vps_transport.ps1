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

function Test-EaLabSnapshotShape {
    param([System.IO.FileInfo]$File)
    $expectedHeader = @(
        'row_type', 'login', 'server_time', 'currency', 'equity', 'balance',
        'margin', 'free_margin', 'margin_level_pct', 'stopout_mode', 'stopout_level',
        'magic', 'symbols', 'float_pl', 'open_lots', 'open_positions',
        'oldest_open_hours', 'pending_orders'
    )
    $expectedLogin = [regex]::Match($File.Name, '^EA_LAB_snapshot_([1-9]\d*)\.csv$').Groups[1].Value
    try {
        $rows = @(Import-Csv -LiteralPath $File.FullName -ErrorAction Stop)
        $header = @((Get-Content -LiteralPath $File.FullName -TotalCount 1 -ErrorAction Stop) -split ',')
        if ($header.Count -ne $expectedHeader.Count -or (Compare-Object $expectedHeader $header -SyncWindow 0)) {
            return @{ Valid = $false; Detail = 'header is not the AccountSnapshotExporter shape' }
        }
        $account = @($rows | Where-Object {
            $_.row_type -eq 'ACCOUNT' -and $_.login -match '^[1-9]\d*$' -and $_.login -eq $expectedLogin
        } | Select-Object -First 1)
        if (-not $account) {
            return @{ Valid = $false; Detail = "no parseable ACCOUNT row for filename login $expectedLogin" }
        }
        return @{ Valid = $true; Detail = '' }
    } catch {
        return @{ Valid = $false; Detail = "unreadable CSV: $($_.Exception.Message)" }
    }
}

$now = Get-Date
# A snapshot must prove both exporter shape and filesystem freshness. Keep the
# canonical five-minute future-skew allowance used by RuntimeIdentity.
$candidates = @($valid | ForEach-Object {
    $shape = Test-EaLabSnapshotShape -File $_
    [pscustomobject]@{
        File = $_
        AgeMinutes = ($now - $_.LastWriteTime).TotalMinutes
        ShapeValid = $shape.Valid
        Detail = $shape.Detail
    }
})
$fresh = @($candidates | Where-Object {
    $_.ShapeValid -and $_.AgeMinutes -ge -5 -and $_.AgeMinutes -le $SnapshotMaxAgeMinutes
})
if (-not $fresh) {
    $newest = @($candidates | Sort-Object { $_.File.LastWriteTime } -Descending | Select-Object -First 1)
    $detail = if ($newest) {
        if (-not $newest[0].ShapeValid) { "newest candidate $($newest[0].File.Name) is invalid: $($newest[0].Detail)" }
        elseif ($newest[0].AgeMinutes -lt -5) { "newest valid snapshot $($newest[0].File.Name) is $([math]::Round(-$newest[0].AgeMinutes,1)) minutes in the future" }
        else { "newest valid snapshot $($newest[0].File.Name) is $([math]::Round($newest[0].AgeMinutes,1)) minutes old" }
    } else { 'no valid EA_LAB_snapshot_[1-9]*.csv found' }
    Write-Host "VPS transport FAILED: $detail (limit $SnapshotMaxAgeMinutes minutes)" -ForegroundColor Red
    exit 1
}
$newestFresh = @($fresh | Sort-Object { $_.File.LastWriteTime } -Descending | Select-Object -First 1)[0]
Write-Host "VPS transport PASS: $($newestFresh.File.Name) is $([math]::Round($newestFresh.AgeMinutes,1)) minutes old"

# Identity absence/staleness is deliberately not a transport failure.  The canonical
# collector owns shape, producer timestamp, and archive naming checks; IdentityOnly
# prevents the synced snapshots from ever competing with local monitor telemetry.
$collector = Join-Path $PSScriptRoot 'collect_live_deals.ps1'
& $collector -CommonFiles $SnapshotDir -DestDir $DestDir -IdentityOnly
if ($LASTEXITCODE -ne 0) { throw "identity-only collection failed with exit $LASTEXITCODE" }
exit 0
