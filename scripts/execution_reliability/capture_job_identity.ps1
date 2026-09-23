[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    [Parameter(Mandatory = $true)][string]$ExpectedHead,
    [Parameter(Mandatory = $true)][string]$CanonicalObservedHead,
    [Parameter(Mandatory = $true)][string]$LeaseRoot,
    [Parameter(Mandatory = $true)][string]$JobsRoot,
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$LaneIds,
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [switch]$LibraryOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$StrictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
$Sha256 = [System.Security.Cryptography.SHA256]::Create()

function ConvertTo-AbsoluteLiteralPath {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Label)
    if (-not [IO.Path]::IsPathRooted($Path)) { throw "$Label must be absolute" }
    return [IO.Path]::GetFullPath($Path)
}

function Test-PathIsWithin {
    param([string]$Path, [string]$Root)
    $fullPath = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    $fullRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    return $fullPath.Equals($fullRoot, [StringComparison]::OrdinalIgnoreCase) -or
        $fullPath.StartsWith($fullRoot + '\', [StringComparison]::OrdinalIgnoreCase)
}

function Assert-NoPathOverlap {
    param([string]$Left, [string]$Right, [string]$Label)
    if ((Test-PathIsWithin $Left $Right) -or (Test-PathIsWithin $Right $Left)) {
        throw "$Label roots overlap"
    }
}

function Assert-NoReparseComponents {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Label)
    $full = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::GetPathRoot($full)
    $relative = $full.Substring($root.Length)
    $current = $root
    foreach ($part in @($relative.Split(@('\'), [StringSplitOptions]::RemoveEmptyEntries))) {
        $current = Join-Path $current $part
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "$Label contains a reparse component"
            }
        }
    }
}

function Get-Sha256Hex {
    param([Parameter(Mandatory = $true)][byte[]]$Bytes)
    return ([BitConverter]::ToString($Sha256.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant()
}

function Get-FileFingerprint {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [ordered]@{ presence = 'ABSENT'; sha256 = 'ABSENT'; length = 0; last_write_utc = $null }
    }
    Assert-NoReparseComponents $Path 'source path'
    Assert-SingleHardlink $Path 'source path'
    $item = Get-Item -LiteralPath $Path -Force
    $bytes = [IO.File]::ReadAllBytes($Path)
    return [ordered]@{
        presence = 'PRESENT'
        sha256 = Get-Sha256Hex $bytes
        length = [long]$bytes.Length
        last_write_utc = $item.LastWriteTimeUtc.ToString('o')
    }
}

function Assert-SingleHardlink {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Label)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read,
        ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
    try {
        $information = New-Object EaLabJobIdentity.NativeFileInformation
        if (-not [EaLabJobIdentity.NativeMethods]::GetFileInformationByHandle($stream.SafeFileHandle, [ref]$information)) {
            throw "$Label hardlink identity query failed"
        }
        if ($information.NumberOfLinks -ne 1) { throw "$Label is hardlinked" }
    } finally {
        $stream.Dispose()
    }
}

function Assert-SafePublicIdentifier {
    param([Parameter(Mandatory = $true)][string]$Value, [Parameter(Mandatory = $true)][string]$Label, [int]$MaximumLength = 128)
    if ($Value.Length -gt $MaximumLength -or $Value -cnotmatch '^[A-Za-z][A-Za-z0-9._-]*$' -or
        $Value -match '(?i)(?:^|[._-])(?:account|acct|login|password|credential|secret|token|api[_-]?key)(?:$|[._-])|(?<![0-9])[0-9]{9,}(?![0-9])') {
        throw "unsafe $Label"
    }
}

function Test-FingerprintEqual {
    param($Left, $Right)
    return $Left.presence -ceq $Right.presence -and $Left.sha256 -ceq $Right.sha256 -and
        [long]$Left.length -eq [long]$Right.length -and [string]$Left.last_write_utc -ceq [string]$Right.last_write_utc
}

function Write-BytesExclusive {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][byte[]]$Bytes)
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) { [void](New-Item -ItemType Directory -Path $parent) }
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $stream.Write($Bytes, 0, $Bytes.Length)
        $stream.Flush($true)
    } finally {
        $stream.Dispose()
    }
}

function Write-JsonExclusive {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)]$Value)
    $text = ($Value | ConvertTo-Json -Depth 20) + "`n"
    Write-BytesExclusive $Path $Utf8NoBom.GetBytes($text)
}

if ($ExpectedHead -cnotmatch '^[0-9a-f]{40}$') { throw 'ExpectedHead must be lowercase 40-hex' }
if ($CanonicalObservedHead -cnotmatch '^[0-9a-f]{40}$') { throw 'CanonicalObservedHead must be lowercase 40-hex' }
$RepoRoot = ConvertTo-AbsoluteLiteralPath $RepoRoot 'RepoRoot'
if (-not (Test-Path -LiteralPath $RepoRoot -PathType Container)) { throw 'RepoRoot must be an existing directory' }
Assert-NoReparseComponents $RepoRoot 'RepoRoot'
$actualHead = (& git -c core.excludesFile= -C $RepoRoot rev-parse HEAD 2>$null | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $actualHead -cne $ExpectedHead) { throw 'repository HEAD does not match ExpectedHead' }
$dirty = (& git -c core.excludesFile= -C $RepoRoot status --porcelain=v1 --untracked-files=all 2>$null | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or -not [string]::IsNullOrWhiteSpace($dirty)) { throw 'RepoRoot must be clean' }

if (-not ('EaLabJobIdentity.NativeMethods' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
namespace EaLabJobIdentity {
    [StructLayout(LayoutKind.Sequential)]
    public struct NativeFileInformation {
        public uint FileAttributes;
        public System.Runtime.InteropServices.ComTypes.FILETIME CreationTime;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastAccessTime;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWriteTime;
        public uint VolumeSerialNumber;
        public uint FileSizeHigh;
        public uint FileSizeLow;
        public uint NumberOfLinks;
        public uint FileIndexHigh;
        public uint FileIndexLow;
    }
    public static class NativeMethods {
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool GetFileInformationByHandle(
            SafeFileHandle handle, out NativeFileInformation information);
    }
}
'@
}

$helperPath = Join-Path $RepoRoot 'scripts\long_jobs\_long_job_runner_lib.ps1'
if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) { throw 'canonical process helper is missing' }
$helperInitialFingerprint = Get-FileFingerprint $helperPath
$helperInitialBytes = [IO.File]::ReadAllBytes($helperPath)
if ((Get-Sha256Hex $helperInitialBytes) -cne $helperInitialFingerprint.sha256) { throw 'process helper changed while reading' }
. $helperPath
if ($LibraryOnly) { return }

$LeaseRoot = ConvertTo-AbsoluteLiteralPath $LeaseRoot 'LeaseRoot'
$JobsRoot = ConvertTo-AbsoluteLiteralPath $JobsRoot 'JobsRoot'
$OutputRoot = ConvertTo-AbsoluteLiteralPath $OutputRoot 'OutputRoot'
foreach ($rootSpec in @(@($LeaseRoot,'LeaseRoot'), @($JobsRoot,'JobsRoot'))) {
    if (-not (Test-Path -LiteralPath $rootSpec[0] -PathType Container)) { throw "$($rootSpec[1]) must be an existing directory" }
    Assert-NoReparseComponents $rootSpec[0] $rootSpec[1]
}
if (Test-Path -LiteralPath $OutputRoot) { throw 'OutputRoot must be fresh' }
Assert-NoReparseComponents (Split-Path -Parent $OutputRoot) 'OutputRoot parent'
Assert-NoPathOverlap $OutputRoot $RepoRoot 'output/repository'
Assert-NoPathOverlap $OutputRoot $LeaseRoot 'output/lease'
Assert-NoPathOverlap $OutputRoot $JobsRoot 'output/jobs'

$safeLaneIds = New-Object Collections.Generic.List[string]
$seen = @{}
foreach ($laneId in @($LaneIds)) {
    Assert-SafePublicIdentifier $laneId 'LaneId'
    if ($seen.ContainsKey($laneId)) { throw 'duplicate LaneId' }
    $seen[$laneId] = $true
    $safeLaneIds.Add($laneId)
}

$sourcePlans = New-Object Collections.Generic.List[object]
$sourcePlans.Add([pscustomobject]@{
    LaneId = $null; Kind = 'helper'; Original = $helperPath; Relative = 'sources/shared/helper.ps1'
    Before = $helperInitialFingerprint; Bytes = $helperInitialBytes
})
$leaseKeys = @('lane_id','job_id','created_utc','job_root','status_script','runner_root','requested_file','launch_file','worktree','base_sha','stage')
$jobKeys = @('job_id','file_path','arg_count','arg_hash','timeout_sec','heartbeat_sec','worktree','base_sha','stage','postcondition_file_path','postcondition_arg_count','postcondition_arg_hash','created_utc')
$stateKeys = @('job_id','state','runner_pid','runner_start_utc','child_pid','child_start_utc','postcondition_pid','postcondition_start_utc','created_utc','started_utc','ended_utc','timeout_sec','heartbeat_sec','file_path','postcondition_file_path','exit_code','postcondition_exit_code','reason','jobs_root','job_root','request_file')
$heartbeatKeys = @('job_id','state','runner_pid','child_pid','postcondition_pid','updated_utc')
$resultKeys = @('job_id','state','exit_code','runner_pid','child_pid','ended_utc','reason','postcondition_exit_code')
$laneContexts = New-Object Collections.Generic.List[object]
foreach ($laneId in $safeLaneIds) {
    $leasePath = Join-Path $LeaseRoot ($laneId + '.json')
    if (-not (Test-Path -LiteralPath $leasePath -PathType Leaf)) { throw "missing lease for requested lane" }
    Assert-NoReparseComponents $leasePath 'lease path'
    $leaseBefore = Get-FileFingerprint $leasePath
    $leaseBytes = [IO.File]::ReadAllBytes($leasePath)
    if ((Get-Sha256Hex $leaseBytes) -cne $leaseBefore.sha256 -or $leaseBytes.Length -ne $leaseBefore.length) { throw 'lease changed while reading' }
    $leaseObject = ConvertFrom-StrictJsonBytes $leaseBytes 'lease' $leaseKeys $leaseKeys
    if ($leaseObject.lane_id -isnot [string] -or $leaseObject.lane_id -cne $laneId) { throw 'lease identity mismatch' }
    if ($leaseObject.job_id -isnot [string]) { throw 'invalid job ID type in lease' }
    $jobId = $leaseObject.job_id
    Assert-SafePublicIdentifier $jobId 'job ID in lease' 80
    if ($leaseObject.base_sha -isnot [string] -or $leaseObject.base_sha -cnotmatch '^[0-9a-f]{40}$') { throw 'invalid lease base' }
    [void](ConvertTo-PreciseUtcTicks $leaseObject.created_utc)
    foreach ($leaseTextField in @('job_root','status_script','runner_root','requested_file','launch_file','worktree','stage')) {
        if ($leaseObject.$leaseTextField -isnot [string]) { throw "invalid lease $leaseTextField type" }
    }
    $jobRoot = Join-Path $JobsRoot $jobId
    if (-not (Test-PathIsWithin $jobRoot $JobsRoot) -or -not (Test-Path -LiteralPath $jobRoot -PathType Container)) {
        throw 'derived job root is missing or unsafe'
    }
    Assert-NoReparseComponents $jobRoot 'job root'
    $paths = [ordered]@{
        lease = $leasePath
        job = Join-Path $jobRoot 'job.json'
        state = Join-Path $jobRoot 'state.json'
        heartbeat = Join-Path $jobRoot 'heartbeat.json'
        result = Join-Path $jobRoot 'result.json'
    }
    foreach ($requiredKind in @('job','state')) {
        if (-not (Test-Path -LiteralPath $paths[$requiredKind] -PathType Leaf)) { throw "missing essential job metadata" }
    }
    $initialFingerprints = [ordered]@{ lease = $leaseBefore }
    $initialBytes = [ordered]@{ lease = $leaseBytes }
    foreach ($kind in @('job','state','heartbeat','result')) {
        $fingerprint = Get-FileFingerprint $paths[$kind]
        $initialFingerprints[$kind] = $fingerprint
        if ($fingerprint.presence -ceq 'PRESENT') {
            $bytes = [IO.File]::ReadAllBytes($paths[$kind])
            if ((Get-Sha256Hex $bytes) -cne $fingerprint.sha256 -or $bytes.Length -ne $fingerprint.length) { throw "$kind changed while reading" }
            $initialBytes[$kind] = $bytes
        } else {
            $initialBytes[$kind] = $null
        }
    }
    $jobObject = ConvertFrom-StrictJsonBytes ([byte[]]$initialBytes.job) 'job' $jobKeys $jobKeys
    if ($jobObject.postcondition_file_path -isnot [string]) { throw 'invalid job postcondition_file_path type' }
    $stateObject = ConvertFrom-StrictJsonBytes ([byte[]]$initialBytes.state) 'state' $stateKeys @('job_id','state')
    $heartbeatObject = if ($null -ne $initialBytes.heartbeat) {
        ConvertFrom-StrictJsonBytes ([byte[]]$initialBytes.heartbeat) 'heartbeat' $heartbeatKeys @('job_id','state','updated_utc')
    } else { $null }
    $resultObject = if ($null -ne $initialBytes.result) {
        ConvertFrom-StrictJsonBytes ([byte[]]$initialBytes.result) 'result' $resultKeys $resultKeys
    } else { $null }
    foreach ($boundRecord in @($jobObject, $stateObject, $heartbeatObject, $resultObject)) {
        if ($null -ne $boundRecord -and ($boundRecord.job_id -isnot [string] -or $boundRecord.job_id -cne $jobId)) {
            throw 'lease-to-job ID mismatch'
        }
    }
    if ($jobObject.base_sha -isnot [string] -or $jobObject.base_sha -cne $leaseObject.base_sha) {
        throw 'lease-to-job base mismatch'
    }
    foreach ($kind in @('lease','job','state','heartbeat','result')) {
        $sourcePlans.Add([pscustomobject]@{
            LaneId = $laneId; Kind = $kind; Original = $paths[$kind]
            Relative = "sources/$laneId/$kind.json"
            Before = $initialFingerprints[$kind]; Bytes = $initialBytes[$kind]
        })
    }
    $laneContexts.Add([pscustomobject]@{ LaneId = $laneId; JobId = $jobId; Job = $jobObject; State = $stateObject })
}

$processChecks = New-Object Collections.Generic.List[object]
foreach ($context in $laneContexts) {
    $postNotConfigured = $context.Job.postcondition_file_path -ceq ''
    $postPidValue = if ($context.State.PSObject.Properties.Name -contains 'postcondition_pid') { $context.State.postcondition_pid } else { $null }
    $postStartValue = if ($context.State.PSObject.Properties.Name -contains 'postcondition_start_utc') { $context.State.postcondition_start_utc } else { $null }
    $postNotStarted = -not $postNotConfigured -and $null -eq $postPidValue -and $null -eq $postStartValue -and `
        [string]$context.State.state -cne 'POSTCONDITION_RUNNING'
    foreach ($role in @('runner','child','postcondition')) {
        $pidName = $role + '_pid'
        $startName = $role + '_start_utc'
        $pidValue = if ($context.State.PSObject.Properties.Name -contains $pidName) { $context.State.$pidName } else { $null }
        $startValue = if ($context.State.PSObject.Properties.Name -contains $startName) { $context.State.$startName } else { $null }
        $processChecks.Add((Get-IdentityEvidence -LaneId $context.LaneId -JobId $context.JobId -Role $role `
            -PidValue $pidValue -ExpectedCreationUtc $startValue -PostconditionNotConfigured:$postNotConfigured `
            -PostconditionNotStarted:$postNotStarted))
    }
}

$afterFingerprints = New-Object Collections.Generic.List[object]
for ($index = 0; $index -lt $sourcePlans.Count; $index++) {
    $after = Get-FileFingerprint $sourcePlans[$index].Original
    $afterFingerprints.Add($after)
    if (-not (Test-FingerprintEqual $sourcePlans[$index].Before $after)) { throw 'source changed during process checks' }
}

$capturedAt = [DateTime]::UtcNow.ToString('o')
$sources = New-Object Collections.Generic.List[object]
for ($index = 0; $index -lt $sourcePlans.Count; $index++) {
    $plan = $sourcePlans[$index]
    $before = $plan.Before
    $frozenRelative = if ($before.presence -ceq 'PRESENT') { $plan.Relative } else { $null }
    $sources.Add([ordered]@{
        lane_id = $plan.LaneId; kind = $plan.Kind; presence = $before.presence
        relative_path = $frozenRelative; sha256 = $before.sha256; length = $before.length
        last_write_utc = $before.last_write_utc; before = $before; after = $afterFingerprints[$index]
    })
}

$manifest = [ordered]@{
    schema_version = 'EA_LAB_JOB_IDENTITY_CAPTURE_V1'
    status = 'AVAILABLE'
    captured_at_utc = $capturedAt
    repo_root = $RepoRoot
    expected_head = $ExpectedHead
    canonical_observed_sha = $CanonicalObservedHead
    lease_root = $LeaseRoot
    jobs_root = $JobsRoot
    requested_lane_ids = [string[]]$safeLaneIds
    sources = [object[]]$sources
    process_checks = [object[]]$processChecks
}

# Recheck every publication boundary after all source parsing and PID reads. Nothing is created
# until all refusal checks have completed successfully.
if (Test-Path -LiteralPath $OutputRoot) { throw 'OutputRoot must remain fresh' }
Assert-NoReparseComponents (Split-Path -Parent $OutputRoot) 'OutputRoot parent'
Assert-NoPathOverlap $OutputRoot $RepoRoot 'output/repository'
Assert-NoPathOverlap $OutputRoot $LeaseRoot 'output/lease'
Assert-NoPathOverlap $OutputRoot $JobsRoot 'output/jobs'
[void](New-Item -ItemType Directory -Path $OutputRoot)
Write-JsonExclusive (Join-Path $OutputRoot 'INCOMPLETE.json') ([ordered]@{
    schema_version = 'EA_LAB_JOB_IDENTITY_CAPTURE_V1'; status = 'INCOMPLETE'
})
foreach ($plan in $sourcePlans) {
    if ($plan.Before.presence -ceq 'PRESENT') {
        Write-BytesExclusive (Join-Path $OutputRoot ($plan.Relative -replace '/', '\')) ([byte[]]$plan.Bytes)
    }
}
Write-JsonExclusive (Join-Path $OutputRoot 'manifest.json') $manifest
Remove-Item -LiteralPath (Join-Path $OutputRoot 'INCOMPLETE.json') -Force
[pscustomobject]@{
    status = 'AVAILABLE'; requested_rows = $safeLaneIds.Count
    manifest = (Join-Path $OutputRoot 'manifest.json'); runtime_activation = $false
} | ConvertTo-Json -Compress | Write-Output
