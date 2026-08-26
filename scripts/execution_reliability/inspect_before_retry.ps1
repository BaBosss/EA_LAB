<#
Returns a durable, fail-closed retry decision for a Long Job Runner job.
It does not start, cancel, or otherwise mutate a job.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$JobId,
    [string]$JobsRoot = 'D:\EA_LAB_CONTROL\jobs',
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

function Write-RetryDecision([hashtable]$Decision) {
    if ($Json) { $Decision | ConvertTo-Json -Depth 6 | Write-Output }
    else { $Decision.GetEnumerator() | ForEach-Object { Write-Output "$($_.Key)=$($_.Value)" } }
}

function Get-AliveProcess([object]$Value) {
    $candidateProcessId = 0
    if ($null -eq $Value -or -not [int]::TryParse([string]$Value, [ref]$candidateProcessId) -or $candidateProcessId -le 0) {
        return [PSCustomObject]@{ valid = $false; alive = $false }
    }
    try {
        $process = Get-Process -Id $candidateProcessId -ErrorAction Stop
        return [PSCustomObject]@{ valid = $true; alive = (-not $process.HasExited) }
    } catch {
        return [PSCustomObject]@{ valid = $true; alive = $false }
    }
}

$decision = [ordered]@{
    job_id = $JobId
    state = 'UNKNOWN'
    runner_alive = $false
    child_alive = $false
    retry_decision = 'REFUSE_RETRY'
    reason = 'missing or ambiguous durable state'
}

try {
    if (-not [System.IO.Path]::IsPathRooted($JobsRoot)) { throw 'jobs root must be absolute' }
    $jobsPath = [System.IO.Path]::GetFullPath($JobsRoot)
    $statePath = Join-Path (Join-Path $jobsPath $JobId) 'state.json'
    if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
        $decision.reason = 'missing durable state'
        Write-RetryDecision $decision
        exit 0
    }

    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json -ErrorAction Stop
    if (-not $state.PSObject.Properties['state'] -or [string]::IsNullOrWhiteSpace([string]$state.state)) {
        throw 'state field missing'
    }
    $decision.state = [string]$state.state
    $runner = if ($state.PSObject.Properties['runner_pid']) { Get-AliveProcess $state.runner_pid } else { Get-AliveProcess $null }
    $child = if ($state.PSObject.Properties['child_pid']) { Get-AliveProcess $state.child_pid } else { Get-AliveProcess $null }
    $decision.runner_alive = [bool]$runner.alive
    $decision.child_alive = [bool]$child.alive

    if ($runner.alive -or $child.alive) {
        $decision.reason = 'runner or child process is still live'
    } elseif ($decision.state -in @('STARTING','RUNNING','POSTCONDITION_RUNNING')) {
        $decision.reason = "job state $($decision.state) is still active"
    } elseif ($decision.state -in @('FAILED','POSTCONDITION_FAILED','TIMED_OUT','CANCELLED','LOST_PROCESS')) {
        if (-not $runner.valid -or -not $child.valid) {
            $decision.reason = 'terminal state has missing or invalid process identity'
        } else {
            $decision.retry_decision = 'ALLOW_RETRY'
            $decision.reason = 'explicit safe terminal state with no live runner or child'
        }
    } else {
        $decision.reason = "state $($decision.state) is not an explicit safe retry terminal"
    }
} catch {
    $decision.state = 'UNKNOWN'
    $decision.reason = 'missing or ambiguous durable state'
}

Write-RetryDecision $decision
