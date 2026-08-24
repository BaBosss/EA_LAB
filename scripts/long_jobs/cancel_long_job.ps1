param([Parameter(Mandatory = $true)][string]$JobId, [string]$JobsRoot = 'D:\EA_LAB_CONTROL\jobs', [switch]$Json)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_long_job_runner_lib.ps1')
if (-not (Test-LjrValidJobId -JobId $JobId)) { throw "invalid job id: $JobId" }
$JobsRoot = Resolve-LjrSafeAbsPath -Path $JobsRoot
$jobRoot = Join-Path $JobsRoot $JobId
if (-not (Test-Path -LiteralPath $jobRoot)) { throw "job not found: $JobId" }

$statePath = Join-Path $jobRoot 'state.json'
if (-not (Test-Path -LiteralPath $statePath)) { throw "missing state metadata for $JobId" }
$state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
if (-not $state.runner_pid -or -not $state.child_pid) { throw "identity ambiguity for $JobId" }

Invoke-LjrAtomicWriteText -Path (Join-Path $jobRoot 'cancel.request') -Content (Get-LjrUtcNowIso)
$result = [ordered]@{ job_id = $JobId; cancel_state = 'CANCEL_REQUESTED' }
if ($Json) { $result | ConvertTo-Json -Depth 4 | Write-Output } else { Write-Output 'CANCEL_REQUESTED' }
