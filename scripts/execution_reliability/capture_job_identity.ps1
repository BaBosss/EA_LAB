[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    [Parameter(Mandatory = $true)][string]$ExpectedHead,
    [Parameter(Mandatory = $true)][string]$LeaseRoot,
    [Parameter(Mandatory = $true)][string]$JobsRoot,
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$LaneIds,
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [switch]$LibraryOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
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
    $item = Get-Item -LiteralPath $Path -Force
    $bytes = [IO.File]::ReadAllBytes($Path)
    return [ordered]@{
        presence = 'PRESENT'
        sha256 = Get-Sha256Hex $bytes
        length = [long]$bytes.Length
        last_write_utc = $item.LastWriteTimeUtc.ToString('o')
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

function ConvertTo-PreciseUtcTicks {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    if ($Value -cnotmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,7})?(?:Z|[+-]\d{2}:\d{2})$') {
        throw 'invalid precise timestamp'
    }
    try {
        $parsed = [DateTimeOffset]::Parse($Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind)
    } catch {
        throw 'invalid precise timestamp'
    }
    return $parsed.UtcTicks
}

function Get-IdentityEvidence {
    param(
        [Parameter(Mandatory = $true)][string]$LaneId,
        [Parameter(Mandatory = $true)][string]$JobId,
        [Parameter(Mandatory = $true)][ValidateSet('runner','child','postcondition')][string]$Role,
        [AllowNull()]$PidValue,
        [AllowNull()]$ExpectedCreationUtc,
        [bool]$PostconditionNotConfigured = $false
    )
    $checked = [DateTime]::UtcNow.ToString('o')
    if ($null -eq $PidValue) {
        if ($Role -eq 'postcondition' -and $PostconditionNotConfigured) {
            return [ordered]@{
                lane_id = $LaneId; job_id = $JobId; role = $Role; pid = $null
                expected_creation_utc = $null; current_creation_utc = $null
                identity = 'RECORDED_PROCESS_NOT_PRESENT'; query_status = 'NOT_CONFIGURED'; checked_utc = $checked
            }
        }
        return [ordered]@{
            lane_id = $LaneId; job_id = $JobId; role = $Role; pid = $null
            expected_creation_utc = $ExpectedCreationUtc; current_creation_utc = $null
            identity = 'UNKNOWN'; query_status = 'ERROR'; checked_utc = $checked
        }
    }
    if ($PidValue -is [bool] -or [int64]$PidValue -le 0 -or [int64]$PidValue -gt [int]::MaxValue) {
        throw "invalid recorded PID"
    }
    $observedPid = [int]$PidValue
    $snapshot = Get-LjrProcessSnapshot -ProcessId $observedPid
    if ($null -ne $snapshot) {
        if ([bool]$snapshot.HasExited) {
            return [ordered]@{
                lane_id = $LaneId; job_id = $JobId; role = $Role; pid = $observedPid
                expected_creation_utc = $ExpectedCreationUtc; current_creation_utc = $null
                identity = 'UNKNOWN'; query_status = 'ERROR'; checked_utc = $checked
            }
        }
        $current = [string]$snapshot.StartTimeUtc
        $identity = 'UNKNOWN'
        if (-not [string]::IsNullOrWhiteSpace([string]$ExpectedCreationUtc)) {
            $expectedTicks = ConvertTo-PreciseUtcTicks ([string]$ExpectedCreationUtc)
            $currentTicks = ConvertTo-PreciseUtcTicks $current
            $identity = if ($expectedTicks -eq $currentTicks) { 'MATCHING_RECORDED_PROCESS' } else { 'DIFFERENT_CREATION_IDENTITY' }
        }
        return [ordered]@{
            lane_id = $LaneId; job_id = $JobId; role = $Role; pid = $observedPid
            expected_creation_utc = $ExpectedCreationUtc; current_creation_utc = $current
            identity = $identity; query_status = 'PRESENT'; checked_utc = $checked
        }
    }

    # A null helper result is ambiguous. A second read-only query distinguishes the documented
    # no-such-process exception from access/metadata failures; every other outcome remains UNKNOWN.
    try {
        $process = [Diagnostics.Process]::GetProcessById($observedPid)
    } catch [ArgumentException] {
        return [ordered]@{
            lane_id = $LaneId; job_id = $JobId; role = $Role; pid = $observedPid
            expected_creation_utc = $ExpectedCreationUtc; current_creation_utc = $null
            identity = 'RECORDED_PROCESS_NOT_PRESENT'; query_status = 'NOT_PRESENT'; checked_utc = $checked
        }
    } catch {
        return [ordered]@{
            lane_id = $LaneId; job_id = $JobId; role = $Role; pid = $observedPid
            expected_creation_utc = $ExpectedCreationUtc; current_creation_utc = $null
            identity = 'UNKNOWN'; query_status = 'INACCESSIBLE'; checked_utc = $checked
        }
    }
    try {
        $current = $process.StartTime.ToUniversalTime().ToString('o')
        $identity = 'UNKNOWN'
        if (-not [string]::IsNullOrWhiteSpace([string]$ExpectedCreationUtc)) {
            $expectedTicks = ConvertTo-PreciseUtcTicks ([string]$ExpectedCreationUtc)
            $currentTicks = ConvertTo-PreciseUtcTicks $current
            $identity = if ($expectedTicks -eq $currentTicks) { 'MATCHING_RECORDED_PROCESS' } else { 'DIFFERENT_CREATION_IDENTITY' }
        }
        return [ordered]@{
            lane_id = $LaneId; job_id = $JobId; role = $Role; pid = $observedPid
            expected_creation_utc = $ExpectedCreationUtc; current_creation_utc = $current
            identity = $identity; query_status = 'PRESENT'; checked_utc = $checked
        }
    } catch {
        return [ordered]@{
            lane_id = $LaneId; job_id = $JobId; role = $Role; pid = $observedPid
            expected_creation_utc = $ExpectedCreationUtc; current_creation_utc = $null
            identity = 'UNKNOWN'; query_status = 'INACCESSIBLE'; checked_utc = $checked
        }
    } finally {
        if ($null -ne $process) { $process.Dispose() }
    }
}

$RepoRoot = ConvertTo-AbsoluteLiteralPath $RepoRoot 'RepoRoot'
$helperPath = Join-Path $RepoRoot 'scripts\long_jobs\_long_job_runner_lib.ps1'
if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) { throw 'canonical process helper is missing' }
$helperInitialFingerprint = Get-FileFingerprint $helperPath
$helperInitialBytes = [IO.File]::ReadAllBytes($helperPath)
if ((Get-Sha256Hex $helperInitialBytes) -cne $helperInitialFingerprint.sha256) { throw 'process helper changed while reading' }
. $helperPath
if ($LibraryOnly) { return }

if ($ExpectedHead -cnotmatch '^[0-9a-f]{40}$') { throw 'ExpectedHead must be lowercase 40-hex' }
$LeaseRoot = ConvertTo-AbsoluteLiteralPath $LeaseRoot 'LeaseRoot'
$JobsRoot = ConvertTo-AbsoluteLiteralPath $JobsRoot 'JobsRoot'
$OutputRoot = ConvertTo-AbsoluteLiteralPath $OutputRoot 'OutputRoot'
foreach ($rootSpec in @(@($RepoRoot,'RepoRoot'), @($LeaseRoot,'LeaseRoot'), @($JobsRoot,'JobsRoot'))) {
    if (-not (Test-Path -LiteralPath $rootSpec[0] -PathType Container)) { throw "$($rootSpec[1]) must be an existing directory" }
    Assert-NoReparseComponents $rootSpec[0] $rootSpec[1]
}
if (Test-Path -LiteralPath $OutputRoot) { throw 'OutputRoot must be fresh' }
Assert-NoReparseComponents (Split-Path -Parent $OutputRoot) 'OutputRoot parent'
Assert-NoPathOverlap $OutputRoot $RepoRoot 'output/repository'
Assert-NoPathOverlap $OutputRoot $LeaseRoot 'output/lease'
Assert-NoPathOverlap $OutputRoot $JobsRoot 'output/jobs'

$actualHead = (& git -C $RepoRoot rev-parse HEAD 2>$null | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $actualHead -cne $ExpectedHead) { throw 'repository HEAD does not match ExpectedHead' }
$dirty = (& git -C $RepoRoot status --porcelain=v1 --untracked-files=all 2>$null | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or -not [string]::IsNullOrWhiteSpace($dirty)) { throw 'RepoRoot must be clean' }

$safeLaneIds = New-Object Collections.Generic.List[string]
$seen = @{}
foreach ($laneId in @($LaneIds)) {
    if ($laneId -cnotmatch '^[A-Za-z][A-Za-z0-9._-]{0,127}$') { throw 'unsafe LaneId' }
    if ($seen.ContainsKey($laneId)) { throw 'duplicate LaneId' }
    $seen[$laneId] = $true
    $safeLaneIds.Add($laneId)
}

[void](New-Item -ItemType Directory -Path $OutputRoot)
Write-JsonExclusive (Join-Path $OutputRoot 'INCOMPLETE.json') ([ordered]@{
    schema_version = 'EA_LAB_JOB_IDENTITY_CAPTURE_V1'; status = 'INCOMPLETE'
})

$sourcePlans = New-Object Collections.Generic.List[object]
$sourcePlans.Add([pscustomobject]@{
    LaneId = $null; Kind = 'helper'; Original = $helperPath; Relative = 'sources/shared/helper.ps1'
    Before = $helperInitialFingerprint
})
$laneContexts = New-Object Collections.Generic.List[object]
foreach ($laneId in $safeLaneIds) {
    $leasePath = Join-Path $LeaseRoot ($laneId + '.json')
    if (-not (Test-Path -LiteralPath $leasePath -PathType Leaf)) { throw "missing lease for requested lane" }
    Assert-NoReparseComponents $leasePath 'lease path'
    $leaseBefore = Get-FileFingerprint $leasePath
    $leaseBytes = [IO.File]::ReadAllBytes($leasePath)
    if ((Get-Sha256Hex $leaseBytes) -cne $leaseBefore.sha256 -or $leaseBytes.Length -ne $leaseBefore.length) { throw 'lease changed while reading' }
    $leaseText = $Utf8NoBom.GetString($leaseBytes).TrimStart([char]0xFEFF)
    $leaseObject = $leaseText | ConvertFrom-Json
    if ([string]$leaseObject.schema_version -cne 'EA_LAB_JOB_IDENTITY_LEASE_V1' -or [string]$leaseObject.lane_id -cne $laneId) {
        throw 'lease identity mismatch'
    }
    $jobId = [string]$leaseObject.job_id
    if ($jobId -cnotmatch '^[A-Za-z0-9][A-Za-z0-9_.-]{2,79}$') { throw 'unsafe job ID in lease' }
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
    $jobObject = $Utf8NoBom.GetString([byte[]]$initialBytes.job).TrimStart([char]0xFEFF) | ConvertFrom-Json
    $stateObject = $Utf8NoBom.GetString([byte[]]$initialBytes.state).TrimStart([char]0xFEFF) | ConvertFrom-Json
    if ([string]$jobObject.job_id -cne $jobId -or [string]$stateObject.job_id -cne $jobId) { throw 'lease-to-job ID mismatch' }
    if ([string]$leaseObject.base_sha -cnotmatch '^[0-9a-f]{40}$' -or [string]$jobObject.base_sha -cne [string]$leaseObject.base_sha) {
        throw 'lease-to-job base mismatch'
    }
    foreach ($kind in @('lease','job','state','heartbeat','result')) {
        $sourcePlans.Add([pscustomobject]@{
            LaneId = $laneId; Kind = $kind; Original = $paths[$kind]
            Relative = "sources/$laneId/$kind.json"
            Before = $initialFingerprints[$kind]
        })
    }
    $laneContexts.Add([pscustomobject]@{ LaneId = $laneId; JobId = $jobId; Job = $jobObject; State = $stateObject })
}

$sources = New-Object Collections.Generic.List[object]
foreach ($plan in $sourcePlans) {
    $before = $plan.Before
    $frozenRelative = $null
    if ($before.presence -ceq 'PRESENT') {
        $bytes = [IO.File]::ReadAllBytes($plan.Original)
        if ((Get-Sha256Hex $bytes) -cne $before.sha256 -or $bytes.Length -ne $before.length) { throw 'source changed while reading' }
        $frozenRelative = $plan.Relative
        Write-BytesExclusive (Join-Path $OutputRoot ($frozenRelative -replace '/', '\')) $bytes
    }
    $sources.Add([ordered]@{
        lane_id = $plan.LaneId; kind = $plan.Kind; presence = $before.presence
        relative_path = $frozenRelative; sha256 = $before.sha256; length = $before.length
        last_write_utc = $before.last_write_utc; before = $before; after = $null
    })
}

$processChecks = New-Object Collections.Generic.List[object]
foreach ($context in $laneContexts) {
    $postNotConfigured = [string]::IsNullOrWhiteSpace([string]$context.Job.postcondition_file_path)
    foreach ($role in @('runner','child','postcondition')) {
        $pidName = $role + '_pid'
        $startName = $role + '_start_utc'
        $pidValue = if ($context.State.PSObject.Properties.Name -contains $pidName) { $context.State.$pidName } else { $null }
        $startValue = if ($context.State.PSObject.Properties.Name -contains $startName) { $context.State.$startName } else { $null }
        $processChecks.Add((Get-IdentityEvidence -LaneId $context.LaneId -JobId $context.JobId -Role $role `
            -PidValue $pidValue -ExpectedCreationUtc $startValue -PostconditionNotConfigured:$postNotConfigured))
    }
}

for ($index = 0; $index -lt $sourcePlans.Count; $index++) {
    $after = Get-FileFingerprint $sourcePlans[$index].Original
    $sources[$index].after = $after
    if (-not (Test-FingerprintEqual $sources[$index].before $after)) { throw 'source changed during process checks' }
}

$manifest = [ordered]@{
    schema_version = 'EA_LAB_JOB_IDENTITY_CAPTURE_V1'
    status = 'AVAILABLE'
    captured_at_utc = [DateTime]::UtcNow.ToString('o')
    repo_root = $RepoRoot
    expected_head = $ExpectedHead
    lease_root = $LeaseRoot
    jobs_root = $JobsRoot
    requested_lane_ids = @($safeLaneIds)
    sources = @($sources)
    process_checks = @($processChecks)
}
Write-JsonExclusive (Join-Path $OutputRoot 'manifest.json') $manifest
Remove-Item -LiteralPath (Join-Path $OutputRoot 'INCOMPLETE.json') -Force
[pscustomobject]@{
    status = 'AVAILABLE'; requested_rows = $safeLaneIds.Count
    manifest = (Join-Path $OutputRoot 'manifest.json'); runtime_activation = $false
} | ConvertTo-Json -Compress | Write-Output
