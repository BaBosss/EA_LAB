[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$RepoRoot,
    [Parameter(Mandatory=$true)][string]$CanonicalRef,
    [Parameter(Mandatory=$true)][string]$ExpectedSha,
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [Parameter(Mandatory=$true)][string]$LaneRegistryPath,
    [Parameter(Mandatory=$true)][string]$SafeProjectionPath,
    [Parameter(Mandatory=$true)][string]$MonitoringSourceRoot,
    [datetimeoffset]$AsOf = [datetimeoffset]::UtcNow
)
$ErrorActionPreference='Stop'
$RepoRoot=[IO.Path]::GetFullPath($RepoRoot)
$OutputDirectory=[IO.Path]::GetFullPath($OutputDirectory)
if($ExpectedSha -cnotmatch '^[0-9a-f]{40}$' -or $CanonicalRef.StartsWith('-')){throw 'MONITOR_REFRESH_REFUSE: invalid exact identity'}
$resolved=@(& git --no-optional-locks -C $RepoRoot rev-parse --verify ($CanonicalRef+'^{commit}') 2>$null)
if($LASTEXITCODE -ne 0 -or $resolved.Count -ne 1 -or $resolved[0] -cne $ExpectedSha){throw 'MONITOR_REFRESH_REFUSE: exact SHA mismatch'}
# A fresh destination prevents a failed build from leaving an older apparently current index.
if(Test-Path -LiteralPath $OutputDirectory){throw 'MONITOR_REFRESH_REFUSE: output must not already exist'}
foreach($sourceRoot in @($RepoRoot,$MonitoringSourceRoot,$LaneRegistryPath)){
    $sourceFull=[IO.Path]::GetFullPath($sourceRoot).TrimEnd('\')
    if($sourceFull.Equals($OutputDirectory.TrimEnd('\'),[StringComparison]::OrdinalIgnoreCase) -or
       $sourceFull.StartsWith($OutputDirectory.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase) -or
       $OutputDirectory.TrimEnd('\').StartsWith($sourceFull+'\',[StringComparison]::OrdinalIgnoreCase)){
        throw 'MONITOR_REFRESH_REFUSE: output overlaps a source root'
    }
}
. (Join-Path $PSScriptRoot 'use_python.ps1')
$pythonExe=Assert-PortablePython -Root (Split-Path $PSScriptRoot -Parent)
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('ea_mobile_refresh_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch | Out-Null
try{
    $auditPath=Join-Path $scratch 'lane_audit.json'
    if(Test-Path -LiteralPath $LaneRegistryPath -PathType Container){
        # Audit uses a lock file. Run that existing validator on a stable private copy,
        # never creating locks/directories in the observed registry itself.
        $copy=Join-Path $scratch 'registry'
        New-Item -ItemType Directory -Path $copy | Out-Null
        $before=@(Get-ChildItem -LiteralPath $LaneRegistryPath -Filter '*.json' -File | Sort-Object Name | ForEach-Object { $_.Name+':'+(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash })
        Get-ChildItem -LiteralPath $LaneRegistryPath -Filter '*.json' -File | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $copy }
        $copied=@(Get-ChildItem -LiteralPath $copy -Filter '*.json' -File | Sort-Object Name | ForEach-Object { $_.Name+':'+(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash })
        $after=@(Get-ChildItem -LiteralPath $LaneRegistryPath -Filter '*.json' -File | Sort-Object Name | ForEach-Object { $_.Name+':'+(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash })
        if(($before -join "`n") -cne ($after -join "`n") -or ($before -join "`n") -cne ($copied -join "`n")){throw 'MONITOR_REFRESH_REFUSE: registry changed during observation'}
        $savedGitLocks=$env:GIT_OPTIONAL_LOCKS
        try{
            $env:GIT_OPTIONAL_LOCKS='0'
            $audit=@(& powershell -NoProfile -File (Join-Path $PSScriptRoot 'lane_registry.ps1') -Command Audit -RegistryRoot $copy -RepoRoot $RepoRoot -Json)
            if($LASTEXITCODE -ne 0){throw 'MONITOR_REFRESH_REFUSE: Lane Registry audit failed'}
        }finally{$env:GIT_OPTIONAL_LOCKS=$savedGitLocks}
        [IO.File]::WriteAllText($auditPath,($audit -join "`n"),(New-Object Text.UTF8Encoding($false)))
    }
    $healthPath=Join-Path $scratch 'monitor_health.json'
    & (Join-Path $PSScriptRoot 'monitor_health_snapshot.ps1') -RepoRoot $MonitoringSourceRoot -ExpectedCanonicalSha $ExpectedSha -OutFile $healthPath -AsOf $AsOf
    $site=Join-Path $scratch 'site'
    $stamp=$AsOf.UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ssZ')
    $registryArgs=@()
    if(Test-Path -LiteralPath $auditPath){$registryArgs=@('--lane-registry',$auditPath)}
    & $pythonExe (Join-Path (Split-Path $PSScriptRoot -Parent) 'tools/mobile_report_hub/build_index.py') --repo $RepoRoot --ref $ExpectedSha --expected-sha $ExpectedSha --out $site --as-of $stamp @registryArgs --monitor-health $healthPath --safe-projection $SafeProjectionPath
    if($LASTEXITCODE -ne 0){throw 'MONITOR_REFRESH_REFUSE: report index build failed'}
    # Static assets are exported from the exact same Git commit as canonical report inputs.
    $archive=Join-Path $scratch 'assets.zip'
    & git --no-optional-locks -C $RepoRoot archive --format=zip --output=$archive $ExpectedSha mobile_report_hub
    if($LASTEXITCODE -ne 0){throw 'MONITOR_REFRESH_REFUSE: static asset export failed'}
    $assets=Join-Path $scratch 'assets'
    Expand-Archive -LiteralPath $archive -DestinationPath $assets
    Get-ChildItem -LiteralPath (Join-Path $assets 'mobile_report_hub') | Where-Object Name -ne 'fixture' | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $site -Recurse }
    # Only sanitized report_index and Git static assets enter the output, never raw audit/input files.
    $parent=Split-Path -Parent $OutputDirectory
    if(-not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force | Out-Null}
    Move-Item -LiteralPath $site -Destination $OutputDirectory
    Write-Output ('MONITOR_REFRESH_BUILT: '+$ExpectedSha+' READ_ONLY_PRESENTATION')
}finally{
    $fullScratch=[IO.Path]::GetFullPath($scratch)
    $tempPrefix=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
    if(-not $fullScratch.StartsWith($tempPrefix,[StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $fullScratch) -notlike 'ea_mobile_refresh_*'){throw 'MONITOR_REFRESH_REFUSE: invalid scratch cleanup boundary'}
    Remove-Item -LiteralPath $fullScratch -Recurse -Force
}
