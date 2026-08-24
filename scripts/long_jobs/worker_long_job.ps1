param([Parameter(Mandatory = $true)][string]$JobRoot)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_long_job_runner_lib.ps1')

$requestPath = Join-Path $JobRoot 'request.json'
$statePath = Join-Path $JobRoot 'state.json'
$resultPath = Join-Path $JobRoot 'result.json'
$heartbeatPath = Join-Path $JobRoot 'heartbeat.json'
$stdoutPath = Join-Path $JobRoot 'logs\stdout.log'
$stderrPath = Join-Path $JobRoot 'logs\stderr.log'

function Set-State([hashtable]$data) { Invoke-LjrAtomicWriteJson -Path $statePath -Object $data }

$request = Get-Content -LiteralPath $requestPath -Raw | ConvertFrom-Json
Remove-Item -LiteralPath $requestPath -Force
if (-not (Test-LjrValidBaseSha -BaseSha ([string]$request.base_sha))) { throw "invalid base sha in request" }

$state = [ordered]@{
    job_id = $request.job_id
    state = 'RUNNING'
    runner_pid = $PID
    runner_start_utc = (Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o')
    child_pid = $null
    started_utc = Get-LjrUtcNowIso
    timeout_sec = [int]$request.timeout_sec
    heartbeat_sec = [int]$request.heartbeat_sec
    file_path = $request.file_path
}
Set-State $state

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $request.file_path
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.CreateNoWindow = $true
$psi.Arguments = ConvertTo-LjrProcessArguments -ArgumentList @($request.arguments)
$child = New-Object System.Diagnostics.Process
$child.StartInfo = $psi
$stdoutBuffer = New-Object System.Collections.ArrayList
$stderrBuffer = New-Object System.Collections.ArrayList
Register-ObjectEvent -InputObject $child -EventName OutputDataReceived -Action {
    if ($EventArgs.Data) {
        [void]$event.MessageData.Add($EventArgs.Data)
    }
} -MessageData $stdoutBuffer | Out-Null
Register-ObjectEvent -InputObject $child -EventName ErrorDataReceived -Action {
    if ($EventArgs.Data) {
        [void]$event.MessageData.Add($EventArgs.Data)
    }
} -MessageData $stderrBuffer | Out-Null
try {
    [void]$child.Start()
    $child.BeginOutputReadLine()
    $child.BeginErrorReadLine()
} catch {
    $state.state = 'FAILED'
    $state.ended_utc = Get-LjrUtcNowIso
    $state.exit_code = $null
    $state.reason = 'child launch failed'
    Invoke-LjrAtomicWriteJson -Path $statePath -Object $state
    throw
}
$state.child_pid = $child.Id
$state.child_start_utc = $child.StartTime.ToUniversalTime().ToString('o')
Set-State $state

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$timeout = [int]$request.timeout_sec
$heartbeat = [Math]::Max(1, [int]$request.heartbeat_sec)
$lastHeartbeat = [DateTime]::UtcNow
$cancelMarker = Join-Path $JobRoot 'cancel.request'

while (-not $child.HasExited) {
    if (Test-Path -LiteralPath $cancelMarker) {
        $state.state = 'CANCEL_REQUESTED'
        Set-State $state
        break
    }
    if ($sw.Elapsed.TotalSeconds -ge $timeout) {
        Stop-LjrOwnedProcessTree -Process $child -ExpectedStartTimeUtc $state.child_start_utc
        $state.state = 'TIMED_OUT'
        $state.ended_utc = Get-LjrUtcNowIso
        $state.exit_code = $null
        $state.reason = 'timeout'
        break
    }
    if ((([DateTime]::UtcNow - $lastHeartbeat).TotalSeconds) -ge $heartbeat) {
        Invoke-LjrAtomicWriteJson -Path $heartbeatPath -Object ([ordered]@{
            job_id = $request.job_id
            state = 'RUNNING'
            runner_pid = $PID
            child_pid = $child.Id
            updated_utc = Get-LjrUtcNowIso
        })
        $lastHeartbeat = [DateTime]::UtcNow
        $state.state = 'RUNNING'
        Set-State $state
    }
    Start-Sleep -Milliseconds 200
}

if ($state.state -eq 'CANCEL_REQUESTED') {
    Start-Sleep -Seconds 2
    if (-not $child.HasExited) {
        Stop-LjrOwnedProcessTree -Process $child -ExpectedStartTimeUtc $state.child_start_utc
    }
    $state.state = 'CANCELLED'
    $state.ended_utc = Get-LjrUtcNowIso
    $state.exit_code = $null
}
elseif ($state.state -eq 'TIMED_OUT') {
    # already terminal
}
else {
    $child.WaitForExit()
    $state.ended_utc = Get-LjrUtcNowIso
    $state.exit_code = $child.ExitCode
    $state.state = if ($child.ExitCode -eq 0) { 'COMPLETE' } else { 'FAILED' }
}

$child.WaitForExit()
$stdout = [string]::Join("`r`n", @($stdoutBuffer))
$stderr = [string]::Join("`r`n", @($stderrBuffer))
if ($stdout) { [System.IO.File]::AppendAllText($stdoutPath, ($stdout + "`r`n"), (New-Object System.Text.UTF8Encoding($false))) }
if ($stderr) { [System.IO.File]::AppendAllText($stderrPath, ($stderr + "`r`n"), (New-Object System.Text.UTF8Encoding($false))) }

Invoke-LjrAtomicWriteJson -Path $statePath -Object $state
Invoke-LjrAtomicWriteJson -Path $resultPath -Object ([ordered]@{
    job_id = $request.job_id
    state = $state.state
    exit_code = $state.exit_code
    runner_pid = $PID
    child_pid = $child.Id
    ended_utc = $state.ended_utc
})
