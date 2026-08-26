<#
Starts a detached long job and returns immediately.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [string[]]$ArgumentList = @(),
    [string]$JobId = '',
    [int]$TimeoutSec = 3600,
    [int]$HeartbeatSec = 5,
    [string]$Worktree = '',
    [string]$BaseSha = '',
    [string]$Stage = '',
    [string]$PostconditionFilePath = '',
    [string[]]$PostconditionArgumentList = @(),
    [string]$JobsRoot = 'D:\EA_LAB_CONTROL\jobs',
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_long_job_runner_lib.ps1')

$filePath = Resolve-LjrSafeAbsPath -Path $FilePath
if (-not (Test-LjrLeafFilePath -Path $filePath)) { throw "missing executable leaf file: $filePath" }
if ($PostconditionFilePath) {
    $PostconditionFilePath = Resolve-LjrSafeAbsPath -Path $PostconditionFilePath
    if (-not (Test-LjrLeafFilePath -Path $PostconditionFilePath)) { throw "missing postcondition executable leaf file: $PostconditionFilePath" }
} elseif ($PostconditionArgumentList.Count -gt 0) {
    throw 'postcondition arguments require a postcondition executable'
}
if (-not (Test-LjrValidTimeout -Value $TimeoutSec)) { throw "invalid timeout: $TimeoutSec" }
if (-not (Test-LjrValidHeartbeat -Value $HeartbeatSec)) { throw "invalid heartbeat: $HeartbeatSec" }
if (-not (Test-LjrValidBaseSha -BaseSha $BaseSha)) { throw "invalid base sha: $BaseSha" }
if (-not (Test-LjrValidWorktreePath -Worktree $Worktree)) { throw "invalid worktree: $Worktree" }

if (-not $JobId) {
    $JobId = ('ljr-' + ([Guid]::NewGuid().ToString('N')))
}
if (-not (Test-LjrValidJobId -JobId $JobId)) { throw "invalid job id: $JobId" }

$JobsRoot = Resolve-LjrSafeAbsPath -Path $JobsRoot
if (-not (Test-Path -LiteralPath $JobsRoot)) {
    New-Item -ItemType Directory -Path $JobsRoot -Force -ErrorAction Stop | Out-Null
}
if (-not (Get-Item -LiteralPath $JobsRoot -ErrorAction Stop).PSIsContainer) {
    throw "jobs root must be a directory: $JobsRoot"
}
$jobRoot = Join-Path $JobsRoot $JobId
try {
    New-Item -ItemType Directory -Path $jobRoot -ErrorAction Stop | Out-Null
} catch {
    if (Test-Path -LiteralPath $jobRoot) { throw "job already exists: $JobId" }
    throw
}
New-Item -ItemType Directory -Path (Join-Path $jobRoot 'logs') -Force | Out-Null

$state = [ordered]@{
    job_id = $JobId
    state = 'STARTING'
    created_utc = Get-LjrUtcNowIso
    jobs_root = $JobsRoot
    job_root = $jobRoot
}
Invoke-LjrAtomicWriteJson -Path (Join-Path $jobRoot 'state.json') -Object $state

$request = [ordered]@{
    job_id = $JobId
    file_path = $filePath
    arg_count = $ArgumentList.Count
    arg_hash = ([Convert]::ToBase64String((New-Object System.Security.Cryptography.SHA256Managed).ComputeHash([Text.Encoding]::UTF8.GetBytes(($ArgumentList -join "`u0000")))))
    timeout_sec = $TimeoutSec
    heartbeat_sec = $HeartbeatSec
    worktree = $Worktree
    base_sha = $BaseSha
    stage = $Stage
    postcondition_file_path = $PostconditionFilePath
    postcondition_arg_count = $PostconditionArgumentList.Count
    postcondition_arg_hash = ([Convert]::ToBase64String((New-Object System.Security.Cryptography.SHA256Managed).ComputeHash([Text.Encoding]::UTF8.GetBytes(($PostconditionArgumentList -join "`u0000")))))
    created_utc = Get-LjrUtcNowIso
    arguments = @($ArgumentList)
    postcondition_arguments = @($PostconditionArgumentList)
}
Invoke-LjrAtomicWriteJson -Path (Join-Path $jobRoot 'request.json') -Object $request
Invoke-LjrAtomicWriteJson -Path (Join-Path $jobRoot 'job.json') -Object ([ordered]@{
    job_id = $JobId
    file_path = $filePath
    arg_count = $ArgumentList.Count
    arg_hash = $request.arg_hash
    timeout_sec = $TimeoutSec
    heartbeat_sec = $HeartbeatSec
    worktree = $Worktree
    base_sha = $BaseSha
    stage = $Stage
    postcondition_file_path = $PostconditionFilePath
    postcondition_arg_count = $request.postcondition_arg_count
    postcondition_arg_hash = $request.postcondition_arg_hash
    created_utc = $request.created_utc
})

$worker = Join-Path $PSScriptRoot 'worker_long_job.ps1'
$psi = @{
    FilePath = 'powershell.exe'
    ArgumentList = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$worker,'-JobRoot',$jobRoot)
    PassThru = $true
    WindowStyle = 'Hidden'
}
$proc = Start-Process @psi

try {
    $current = Get-Content -LiteralPath (Join-Path $jobRoot 'state.json') -Raw | ConvertFrom-Json
    if ($current.state -eq 'STARTING') {
        $current | Add-Member -NotePropertyName runner_pid -NotePropertyValue $proc.Id -Force
        $current | Add-Member -NotePropertyName runner_start_utc -NotePropertyValue ($proc.StartTime.ToUniversalTime().ToString('o')) -Force
        $current | Add-Member -NotePropertyName request_file -NotePropertyValue 'request.json' -Force
        Invoke-LjrAtomicWriteJson -Path (Join-Path $jobRoot 'state.json') -Object $current
    }
} catch {
    Invoke-LjrAtomicWriteJson -Path (Join-Path $jobRoot 'state.json') -Object ([ordered]@{
        job_id = $JobId
        state = 'FAILED'
        runner_pid = $proc.Id
        created_utc = Get-LjrUtcNowIso
        ended_utc = Get-LjrUtcNowIso
        reason = 'failed to persist launch metadata'
    })
    throw
}

$out = [ordered]@{ job_id = $JobId; runner_pid = $proc.Id; state = 'STARTING'; job_root = $jobRoot }
if ($Json) { $out | ConvertTo-Json -Depth 6 | Write-Output } else { Write-Output ("JOB_ID=$JobId"); Write-Output ("RUNNER_PID=$($proc.Id)"); Write-Output "STATE=STARTING" }
