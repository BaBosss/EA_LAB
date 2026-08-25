param([Parameter(Mandatory = $true)][string]$JobId, [string]$JobsRoot = 'D:\EA_LAB_CONTROL\jobs', [switch]$Json)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_long_job_runner_lib.ps1')
if (-not (Test-LjrValidJobId -JobId $JobId)) { throw "invalid job id: $JobId" }
$JobsRoot = Resolve-LjrSafeAbsPath -Path $JobsRoot
$jobRoot = Join-Path $JobsRoot $JobId
if (-not (Test-Path -LiteralPath $jobRoot)) { throw "job not found: $JobId" }

$statePath = Join-Path $jobRoot 'state.json'
$state = if (Test-Path -LiteralPath $statePath) { Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json } else { $null }
$runnerPid = if ($state -and $state.PSObject.Properties['runner_pid']) { $state.runner_pid } else { $null }
$childPid = if ($state -and $state.PSObject.Properties['child_pid']) { $state.child_pid } else { $null }
$runner = if ($runnerPid) { Get-LjrProcessSnapshot -ProcessId ([int]$runnerPid) } else { $null }
$child = if ($childPid) { Get-LjrProcessSnapshot -ProcessId ([int]$childPid) } else { $null }

$result = [ordered]@{
    job_id = $JobId
    state = if ($state -and $state.PSObject.Properties['state']) { $state.state } else { 'LOST_PROCESS' }
    runner_pid = $runnerPid
    child_pid = $childPid
    runner_alive = [bool]$runner
    child_alive = [bool]$child
}
if ($state) {
    $result.state = $state.state
    if (($state.state -eq 'RUNNING' -or $state.state -eq 'STARTING') -and -not $runner) { $result.state = 'LOST_PROCESS' }
    elseif (($state.state -eq 'RUNNING') -and -not $child) { $result.state = 'LOST_PROCESS' }
    elseif ($state.PSObject.Properties['runner_start_utc'] -and $runner -and $state.runner_start_utc -ne $runner.StartTimeUtc) { $result.state = 'LOST_PROCESS' }
    elseif ($state.PSObject.Properties['child_start_utc'] -and $child -and $state.child_start_utc -ne $child.StartTimeUtc) { $result.state = 'LOST_PROCESS' }
    if ($runnerPid -and $runner) {
        $result.runner_start_utc = $runner.StartTimeUtc
    }
    if ($childPid -and $child) {
        $result.child_start_utc = $child.StartTimeUtc
    }
}

if ($Json) { $result | ConvertTo-Json -Depth 8 | Write-Output } else { $result.GetEnumerator() | ForEach-Object { Write-Output "$($_.Key)=$($_.Value)" } }
