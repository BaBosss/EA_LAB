param([Parameter(Mandatory = $true)][string]$JobId, [int]$PollSec = 2, [int]$MaxWaitSec = 300, [string]$JobsRoot = 'D:\EA_LAB_CONTROL\jobs', [switch]$Json)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_long_job_runner_lib.ps1')
if (-not (Test-LjrValidJobId -JobId $JobId)) { throw "invalid job id: $JobId" }
if (-not (Test-LjrValidTimeout -Value $MaxWaitSec)) { throw "invalid max wait: $MaxWaitSec" }
if ($PollSec -lt 1 -or $PollSec -gt 3600) { throw "invalid poll: $PollSec" }

$deadline = (Get-Date).ToUniversalTime().AddSeconds($MaxWaitSec)
do {
    $out = & (Join-Path $PSScriptRoot 'status_long_job.ps1') -JobId $JobId -JobsRoot $JobsRoot -Json
    $st = $out | ConvertFrom-Json
    if ($st.state -in @('COMPLETE','FAILED','POSTCONDITION_FAILED','TIMED_OUT','CANCELLED','LOST_PROCESS')) {
        if ($Json) { $st | ConvertTo-Json -Depth 8 | Write-Output } else { $st | Format-List | Out-String | Write-Output }
        exit 0
    }
    Start-Sleep -Seconds $PollSec
} while ((Get-Date).ToUniversalTime() -lt $deadline)

$res = [ordered]@{ job_id = $JobId; wait_state = 'WAIT_TIMEOUT' }
if ($Json) { $res | ConvertTo-Json -Depth 4 | Write-Output } else { Write-Output 'WAIT_TIMEOUT' }
exit 0
