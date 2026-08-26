param([Parameter(Mandatory = $true)][string]$JobRoot)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_long_job_runner_lib.ps1')

$requestPath = Join-Path $JobRoot 'request.json'
$statePath = Join-Path $JobRoot 'state.json'
$resultPath = Join-Path $JobRoot 'result.json'
$heartbeatPath = Join-Path $JobRoot 'heartbeat.json'
$stdoutPath = Join-Path $JobRoot 'logs\stdout.log'
$stderrPath = Join-Path $JobRoot 'logs\stderr.log'
$postconditionStdoutPath = Join-Path $JobRoot 'logs\postcondition.stdout.log'
$postconditionStderrPath = Join-Path $JobRoot 'logs\postcondition.stderr.log'

function Set-State([hashtable]$data) { Invoke-LjrAtomicWriteJson -Path $statePath -Object $data }

function Stop-LjrOwnedPostconditionTree([System.Diagnostics.Process]$Process, [string]$ExpectedStartTimeUtc) {
    try {
        $Process.Refresh()
        if ($Process.HasExited -or $Process.StartTime.ToUniversalTime().ToString('o') -ne $ExpectedStartTimeUtc) { return }
        $Process.Kill()
        return
    } catch {}
    Stop-LjrOwnedProcessTree -Process $Process -ExpectedStartTimeUtc $ExpectedStartTimeUtc
}

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
$requestArgs = @()
if ($request.PSObject.Properties.Name -contains 'arguments') {
    $requestArgs = @($request.arguments)
}
$psi.Arguments = ConvertTo-LjrProcessArguments -ArgumentList $requestArgs
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
    $postconditionPath = if ($request.PSObject.Properties.Name -contains 'postcondition_file_path') { [string]$request.postcondition_file_path } else { '' }
    if ($child.ExitCode -eq 0 -and $postconditionPath) {
        $state.state = 'POSTCONDITION_RUNNING'
        $state.postcondition_file_path = $postconditionPath
        Set-State $state
        try {
            $postconditionArgs = if ($request.PSObject.Properties.Name -contains 'postcondition_arguments') { @($request.postcondition_arguments) } else { @() }
            $postconditionInfo = New-Object System.Diagnostics.ProcessStartInfo
            $postconditionInfo.FileName = $postconditionPath
            $postconditionInfo.UseShellExecute = $false
            $postconditionInfo.RedirectStandardOutput = $true
            $postconditionInfo.RedirectStandardError = $true
            $postconditionInfo.CreateNoWindow = $true
            $postconditionInfo.Arguments = ConvertTo-LjrProcessArguments -ArgumentList $postconditionArgs
            $postcondition = New-Object System.Diagnostics.Process
            $postcondition.StartInfo = $postconditionInfo
            $postconditionStdoutBuffer = New-Object System.Collections.ArrayList
            $postconditionStderrBuffer = New-Object System.Collections.ArrayList
            Register-ObjectEvent -InputObject $postcondition -EventName OutputDataReceived -Action {
                if ($EventArgs.Data) {
                    [void]$event.MessageData.Add($EventArgs.Data)
                }
            } -MessageData $postconditionStdoutBuffer | Out-Null
            Register-ObjectEvent -InputObject $postcondition -EventName ErrorDataReceived -Action {
                if ($EventArgs.Data) {
                    [void]$event.MessageData.Add($EventArgs.Data)
                }
            } -MessageData $postconditionStderrBuffer | Out-Null
            [void]$postcondition.Start()
            $state.postcondition_pid = $postcondition.Id
            $state.postcondition_start_utc = $postcondition.StartTime.ToUniversalTime().ToString('o')
            Set-State $state
            $postcondition.BeginOutputReadLine()
            $postcondition.BeginErrorReadLine()
            $postconditionTerminal = $false
            while (-not $postcondition.HasExited) {
                if (Test-Path -LiteralPath $cancelMarker) {
                    Stop-LjrOwnedPostconditionTree -Process $postcondition -ExpectedStartTimeUtc $state.postcondition_start_utc
                    $state.state = 'CANCELLED'
                    $state.ended_utc = Get-LjrUtcNowIso
                    $state.exit_code = $null
                    $state.reason = 'cancel requested'
                    $postconditionTerminal = $true
                    break
                }
                if ($sw.Elapsed.TotalSeconds -ge $timeout) {
                    Stop-LjrOwnedPostconditionTree -Process $postcondition -ExpectedStartTimeUtc $state.postcondition_start_utc
                    $state.state = 'TIMED_OUT'
                    $state.ended_utc = Get-LjrUtcNowIso
                    $state.exit_code = $null
                    $state.reason = 'timeout'
                    $postconditionTerminal = $true
                    break
                }
                if ((([DateTime]::UtcNow - $lastHeartbeat).TotalSeconds) -ge $heartbeat) {
                    Invoke-LjrAtomicWriteJson -Path $heartbeatPath -Object ([ordered]@{
                        job_id = $request.job_id
                        state = 'POSTCONDITION_RUNNING'
                        runner_pid = $PID
                        child_pid = $child.Id
                        postcondition_pid = $postcondition.Id
                        updated_utc = Get-LjrUtcNowIso
                    })
                    $lastHeartbeat = [DateTime]::UtcNow
                    Set-State $state
                }
                Start-Sleep -Milliseconds 200
            }
            if (-not $postconditionTerminal) {
                $postconditionOutput = [string]::Join("`r`n", @($postconditionStdoutBuffer))
                $postconditionError = [string]::Join("`r`n", @($postconditionStderrBuffer))
                if ($postconditionOutput) { [System.IO.File]::AppendAllText($postconditionStdoutPath, ($postconditionOutput + "`r`n"), (New-Object System.Text.UTF8Encoding($false))) }
                if ($postconditionError) { [System.IO.File]::AppendAllText($postconditionStderrPath, ($postconditionError + "`r`n"), (New-Object System.Text.UTF8Encoding($false))) }
                $state.postcondition_exit_code = $postcondition.ExitCode
                if ($postcondition.ExitCode -ne 0) {
                    $state.state = 'POSTCONDITION_FAILED'
                    $state.reason = "postcondition exit code $($postcondition.ExitCode)"
                } else {
                    $state.state = 'COMPLETE'
                }
            }
        } catch {
            $state.state = 'POSTCONDITION_FAILED'
            $state.postcondition_exit_code = $null
            $state.reason = 'postcondition launch failed'
            [System.IO.File]::AppendAllText($postconditionStderrPath, ($_.Exception.Message + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
        }
    }
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
    reason = if ($state.PSObject.Properties['reason']) { $state.reason } else { '' }
    postcondition_exit_code = if ($state.PSObject.Properties['postcondition_exit_code']) { $state.postcondition_exit_code } else { $null }
})
