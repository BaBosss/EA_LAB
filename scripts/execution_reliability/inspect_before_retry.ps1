<#
Read-only, sampled retry eligibility. ALLOW_RETRY is not a launch or process-control command.
Creation identity comes from the same primitives as the accepted Job Identity Provider.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$JobId,
    [string]$JobsRoot = 'D:\EA_LAB_CONTROL\jobs',
    [switch]$Json
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\long_jobs\_long_job_runner_lib.ps1')
$decision = [ordered]@{
    job_id = $JobId
    state = 'UNKNOWN'
    runner_alive = $null
    child_alive = $null
    postcondition_alive = $null
    process_identities = [ordered]@{}
    retry_decision = 'REFUSE_RETRY'
    reason = 'missing or ambiguous durable state or process identity'
}
try {
    if (-not (Test-LjrValidJobId -JobId $JobId)) { throw 'invalid job ID' }
    $jobsPath = Resolve-LjrSafeAbsPath -Path $JobsRoot
    $jobRoot = Join-Path $jobsPath $JobId
    $statePath = Join-Path $jobRoot 'state.json'
    $jobPath = Join-Path $jobRoot 'job.json'
    $stateBytes = [IO.File]::ReadAllBytes($statePath)
    $jobBytes = [IO.File]::ReadAllBytes($jobPath)
    $stateKeys = @('job_id','state','runner_pid','runner_start_utc','child_pid','child_start_utc','postcondition_pid','postcondition_start_utc','created_utc','started_utc','ended_utc','timeout_sec','heartbeat_sec','file_path','postcondition_file_path','exit_code','postcondition_exit_code','reason','jobs_root','job_root','request_file')
    $jobKeys = @('job_id','file_path','arg_count','arg_hash','timeout_sec','heartbeat_sec','worktree','base_sha','stage','postcondition_file_path','postcondition_arg_count','postcondition_arg_hash','created_utc')
    $state = ConvertFrom-StrictJsonBytes $stateBytes 'state' $stateKeys @('job_id','state','runner_pid','runner_start_utc','child_pid','child_start_utc')
    $job = ConvertFrom-StrictJsonBytes $jobBytes 'job' $jobKeys @('job_id','postcondition_file_path')
    if ($state.job_id -cne $JobId -or $job.job_id -cne $JobId -or
        $state.state -isnot [string] -or $job.postcondition_file_path -isnot [string]) { throw 'ambiguous job binding' }
    $decision.state = $state.state
    $checks = @()
    foreach ($role in @('runner','child','postcondition')) {
        $pidProperty = $state.PSObject.Properties[($role + '_pid')]
        $startProperty = $state.PSObject.Properties[($role + '_start_utc')]
        $pidValue = if ($pidProperty) { $pidProperty.Value } else { $null }
        $startValue = if ($startProperty) { $startProperty.Value } else { $null }
        $notConfigured = $role -eq 'postcondition' -and $job.postcondition_file_path -ceq ''
        if ($notConfigured -and ($null -ne $pidValue -or $null -ne $startValue -or
            $state.state -in @('POSTCONDITION_RUNNING','POSTCONDITION_FAILED'))) { throw 'postcondition metadata conflict' }
        # An interrupted launch can leave a live descendant before PID publication.
        # Do not infer that a configured but unrecorded postcondition never started.
        $check = Get-IdentityEvidence -LaneId 'retry-inspection' -JobId $JobId -Role $role `
            -PidValue $pidValue -ExpectedCreationUtc $startValue -PostconditionNotConfigured $notConfigured
        $checks += $check
        $decision.process_identities[$role] = $check.identity
        $decision[($role + '_alive')] = switch ($check.identity) {
            'MATCHING_RECORDED_PROCESS' { $true }
            'RECORDED_PROCESS_NOT_PRESENT' { $false }
            'DIFFERENT_CREATION_IDENTITY' { $false }
            default { $null }
        }
    }
    # All identities must come from one unchanged durable observation.
    if ([Convert]::ToBase64String($stateBytes) -cne [Convert]::ToBase64String([IO.File]::ReadAllBytes($statePath)) -or
        [Convert]::ToBase64String($jobBytes) -cne [Convert]::ToBase64String([IO.File]::ReadAllBytes($jobPath))) { throw 'durable input changed during inspection' }
    if (@($checks | Where-Object { $_.identity -eq 'UNKNOWN' }).Count -gt 0) {
        $decision.reason = 'missing or ambiguous process identity'
    } elseif ($decision.runner_alive -or $decision.child_alive -or $decision.postcondition_alive) {
        $decision.reason = 'recorded runner, child, or postcondition process is still live'
    } elseif ($decision.state -eq 'POSTCONDITION_RUNNING') {
        $decision.state = 'LOST_PROCESS'
        $decision.retry_decision = 'ALLOW_RETRY'
        $decision.reason = 'lost postcondition has no matching recorded process'
    } elseif ($decision.state -in @('FAILED','POSTCONDITION_FAILED','TIMED_OUT','CANCELLED','LOST_PROCESS')) {
        $decision.retry_decision = 'ALLOW_RETRY'
        $decision.reason = 'explicit safe terminal state with no matching recorded process'
    } else {
        # RUNNING/STARTING do not gain a new recovery path under this contract.
        $decision.reason = "state $($decision.state) is not an explicit safe retry terminal"
    }
} catch {
    $decision.state = 'UNKNOWN'
    $decision.retry_decision = 'REFUSE_RETRY'
    $decision.reason = 'missing or ambiguous durable state or process identity'
}
if ($Json) { $decision | ConvertTo-Json -Depth 6 | Write-Output }
else { $decision.GetEnumerator() | ForEach-Object { Write-Output "$($_.Key)=$($_.Value)" } }
