param([string]$RepoRoot = '')
$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }

$Root = Join-Path $env:TEMP ('ljr_test_' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Root -Force | Out-Null
$JobsRoot = Join-Path $Root 'jobs'
New-Item -ItemType Directory -Path $JobsRoot -Force | Out-Null

$Start = Join-Path $RepoRoot 'scripts\long_jobs\start_long_job.ps1'
$Status = Join-Path $RepoRoot 'scripts\long_jobs\status_long_job.ps1'
$Wait = Join-Path $RepoRoot 'scripts\long_jobs\wait_long_job.ps1'
$Cancel = Join-Path $RepoRoot 'scripts\long_jobs\cancel_long_job.ps1'

$fail = 0
$pass = 0
function Assert($cond, $msg) { if (-not $cond) { throw $msg } }
function ChildScript($path, $content) { Set-Content -LiteralPath $path -Value $content -Encoding utf8 }
function ReportCase($name, $result) { Write-Host ("[{0}] {1}" -f $result, $name) }

try {
    $child1 = Join-Path $Root 'child1.ps1'
    ChildScript $child1 '$o=$args[0]; Start-Sleep -Milliseconds 700; "hello world" | Out-File -LiteralPath $o -Encoding utf8'
    $out1 = & $Start -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$child1,(Join-Path $Root 'out1.txt')) -JobId 'job-001' -JobsRoot $JobsRoot -TimeoutSec 30 -HeartbeatSec 1 -Json | ConvertFrom-Json
    Assert ($out1.job_id -eq 'job-001') 'start output missing job id'
    Start-Sleep -Seconds 2
    Assert ((Get-Content -LiteralPath (Join-Path $Root 'out1.txt') -Raw) -match 'hello world') 'detached child output missing'
    $s1 = & $Status -JobId 'job-001' -JobsRoot $JobsRoot -Json | ConvertFrom-Json
    Assert ($s1.state -eq 'COMPLETE') "expected COMPLETE got $($s1.state)"
    $pass++; ReportCase 'complete job' 'PASS'

    $child2 = Join-Path $Root 'child2.ps1'
    ChildScript $child2 'exit 7'
    & $Start -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$child2) -JobId 'job-002' -JobsRoot $JobsRoot -TimeoutSec 30 -HeartbeatSec 1 | Out-Null
    Start-Sleep -Seconds 2
    $s2 = & $Status -JobId 'job-002' -JobsRoot $JobsRoot -Json | ConvertFrom-Json
    Assert ($s2.state -eq 'FAILED') "expected FAILED got $($s2.state)"
    $pass++; ReportCase 'failed job' 'PASS'

    $postPass = Join-Path $Root 'post_pass.ps1'
    ChildScript $postPass 'exit 0'
    & $Start -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @('-NoProfile','-Command','exit 0') -PostconditionFilePath (Join-Path $PSHOME 'powershell.exe') -PostconditionArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$postPass) -JobId 'job-post-pass' -JobsRoot $JobsRoot -TimeoutSec 30 -HeartbeatSec 1 | Out-Null
    $postPassState = & $Wait -JobId 'job-post-pass' -JobsRoot $JobsRoot -PollSec 1 -MaxWaitSec 10 -Json | ConvertFrom-Json
    Assert ($postPassState.state -eq 'COMPLETE') "postcondition pass expected COMPLETE got $($postPassState.state)"
    $pass++; ReportCase 'postcondition pass completes job' 'PASS'

    $postFail = Join-Path $Root 'post_fail.ps1'
    ChildScript $postFail 'exit 9'
    & $Start -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @('-NoProfile','-Command','exit 0') -PostconditionFilePath (Join-Path $PSHOME 'powershell.exe') -PostconditionArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$postFail) -JobId 'job-post-fail' -JobsRoot $JobsRoot -TimeoutSec 30 -HeartbeatSec 1 | Out-Null
    $postFailState = & $Wait -JobId 'job-post-fail' -JobsRoot $JobsRoot -PollSec 1 -MaxWaitSec 10 -Json | ConvertFrom-Json
    Assert ($postFailState.state -eq 'POSTCONDITION_FAILED') "postcondition fail expected POSTCONDITION_FAILED got $($postFailState.state)"
    $postFailDurable = Get-Content -LiteralPath (Join-Path $JobsRoot 'job-post-fail\state.json') -Raw | ConvertFrom-Json
    Assert ($postFailDurable.reason -eq 'postcondition exit code 9') "unexpected postcondition reason: $($postFailDurable.reason)"
    Assert ([int]$postFailDurable.exit_code -eq 0) 'child exit code evidence changed after postcondition failure'
    $pass++; ReportCase 'postcondition failure is non-complete terminal' 'PASS'

    $postSkippedMarker = Join-Path $Root 'post_skipped.txt'
    $postSkipped = Join-Path $Root 'post_skipped.ps1'
    ChildScript $postSkipped "Set-Content -LiteralPath '$postSkippedMarker' -Value invoked"
    & $Start -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @('-NoProfile','-Command','exit 7') -PostconditionFilePath (Join-Path $PSHOME 'powershell.exe') -PostconditionArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$postSkipped) -JobId 'job-post-skip' -JobsRoot $JobsRoot -TimeoutSec 30 -HeartbeatSec 1 | Out-Null
    $postSkippedState = & $Wait -JobId 'job-post-skip' -JobsRoot $JobsRoot -PollSec 1 -MaxWaitSec 10 -Json | ConvertFrom-Json
    Assert ($postSkippedState.state -eq 'FAILED') "nonzero child was overridden by postcondition: $($postSkippedState.state)"
    Assert (-not (Test-Path -LiteralPath $postSkippedMarker)) 'postcondition ran after nonzero child'
    $pass++; ReportCase 'postcondition does not override failed child' 'PASS'

    $dup = $false
    try { & $Start -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @('-NoProfile','-Command','exit 0') -JobId 'job-002' -JobsRoot $JobsRoot -TimeoutSec 10 -HeartbeatSec 1 | Out-Null } catch { $dup = $true }
    Assert $dup 'duplicate JobId not refused'
    $pass++; ReportCase 'duplicate job id' 'PASS'

    $zeroExe = Join-Path $env:SystemRoot 'System32\hostname.exe'
    & $Start -FilePath $zeroExe -JobId 'job-zero' -JobsRoot $JobsRoot -TimeoutSec 10 -HeartbeatSec 1 | Out-Null
    Start-Sleep -Seconds 2
    $zeroState = & $Status -JobId 'job-zero' -JobsRoot $JobsRoot -Json | ConvertFrom-Json
    $zeroMeta = Get-Content -LiteralPath (Join-Path $JobsRoot 'job-zero\job.json') -Raw | ConvertFrom-Json
    Assert ($zeroState.state -eq 'COMPLETE') "zero-argument job expected COMPLETE got $($zeroState.state)"
    Assert ([int]$zeroMeta.arg_count -eq 0) 'zero-argument metadata arg_count was not zero'
    $pass++; ReportCase 'zero argument job' 'PASS'

    $raceScript = Join-Path $Root 'race_start.ps1'
    ChildScript $raceScript @'
param($StartScript,$Exe,$RaceJobsRoot,$RaceJobId,$Ready,$Barrier,$Result)
Set-Content -LiteralPath $Ready -Value 'READY' -Encoding ascii
while (-not (Test-Path -LiteralPath $Barrier)) { Start-Sleep -Milliseconds 10 }
try {
    & $StartScript -FilePath $Exe -JobId $RaceJobId -JobsRoot $RaceJobsRoot -TimeoutSec 10 -HeartbeatSec 1 | Out-Null
    Set-Content -LiteralPath $Result -Value 'SUCCESS' -Encoding ascii
} catch {
    Set-Content -LiteralPath $Result -Value 'REFUSED' -Encoding ascii
}
'@
    $ready1=Join-Path $Root 'race1.ready'; $ready2=Join-Path $Root 'race2.ready'; $barrier=Join-Path $Root 'race.go'
    $result1=Join-Path $Root 'race1.result'; $result2=Join-Path $Root 'race2.result'; $raceId='job-race'
    $raceArgs1=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$raceScript,$Start,$zeroExe,$JobsRoot,$raceId,$ready1,$barrier,$result1)
    $raceArgs2=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$raceScript,$Start,$zeroExe,$JobsRoot,$raceId,$ready2,$barrier,$result2)
    $rp1=Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $raceArgs1 -PassThru -WindowStyle Hidden
    $rp2=Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $raceArgs2 -PassThru -WindowStyle Hidden
    $readyDeadline=(Get-Date).AddSeconds(5)
    while ((-not (Test-Path $ready1) -or -not (Test-Path $ready2)) -and (Get-Date) -lt $readyDeadline) { Start-Sleep -Milliseconds 20 }
    Assert ((Test-Path $ready1) -and (Test-Path $ready2)) 'concurrent duplicate starters did not reach barrier'
    Set-Content -LiteralPath $barrier -Value 'GO' -Encoding ascii
    $rp1.WaitForExit(); $rp2.WaitForExit()
    $raceResults=@((Get-Content -LiteralPath $result1 -Raw).Trim(),(Get-Content -LiteralPath $result2 -Raw).Trim())
    Assert (@($raceResults | Where-Object { $_ -eq 'SUCCESS' }).Count -eq 1) ("concurrent duplicate success count was {0}" -f @($raceResults | Where-Object { $_ -eq 'SUCCESS' }).Count)
    Assert (@($raceResults | Where-Object { $_ -eq 'REFUSED' }).Count -eq 1) ("concurrent duplicate refusal count was {0}" -f @($raceResults | Where-Object { $_ -eq 'REFUSED' }).Count)
    $raceTerminal = & $Wait -JobId $raceId -JobsRoot $JobsRoot -PollSec 1 -MaxWaitSec 5 -Json | ConvertFrom-Json
    Assert ($raceTerminal.state -eq 'COMPLETE') "concurrent winner expected COMPLETE got $($raceTerminal.state)"
    $pass++; ReportCase 'concurrent duplicate job id' 'PASS'


    $job4 = Join-Path $JobsRoot 'job-004'
    New-Item -ItemType Directory -Path $job4 -Force | Out-Null
    $state4 = [ordered]@{ job_id = 'job-004'; state = 'RUNNING'; runner_pid = 999999; runner_start_utc = '2000-01-01T00:00:00.0000000Z'; child_pid = 999998; child_start_utc = '2000-01-01T00:00:00.0000000Z' }
    Set-Content -LiteralPath (Join-Path $job4 'state.json') -Value ($state4 | ConvertTo-Json -Depth 4) -Encoding utf8
    $s4 = & $Status -JobId 'job-004' -JobsRoot $JobsRoot -Json | ConvertFrom-Json
    Assert ($s4.state -eq 'LOST_PROCESS') "expected LOST_PROCESS got $($s4.state)"
    $pass++; ReportCase 'synthetic lost process' 'PASS'

    $child5 = Join-Path $Root 'child5.ps1'
    ChildScript $child5 'Start-Sleep -Seconds 10'
    & $Start -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$child5) -JobId 'job-005' -JobsRoot $JobsRoot -TimeoutSec 30 -HeartbeatSec 1 | Out-Null
    Start-Sleep -Seconds 2
    $hb = Get-Content -LiteralPath (Join-Path $JobsRoot 'job-005\heartbeat.json') -Raw | ConvertFrom-Json
    Assert ($hb.updated_utc) 'heartbeat missing'

    $wait1 = & $Wait -JobId 'job-005' -JobsRoot $JobsRoot -PollSec 1 -MaxWaitSec 1 -Json | ConvertFrom-Json
    Assert ($wait1.wait_state -eq 'WAIT_TIMEOUT') 'wait timeout not distinct'
    & $Cancel -JobId 'job-005' -JobsRoot $JobsRoot -Json | Out-Null
    Start-Sleep -Seconds 3
    $s5 = & $Status -JobId 'job-005' -JobsRoot $JobsRoot -Json | ConvertFrom-Json
    Assert ($s5.state -eq 'CANCELLED') "expected CANCELLED after wait timeout cancel got $($s5.state)"
    $pass++; ReportCase 'wait timeout then cancel' 'PASS'

    $child6 = Join-Path $Root 'child6.ps1'
    ChildScript $child6 'Start-Sleep -Seconds 10'
    & $Start -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$child6) -JobId 'job-006' -JobsRoot $JobsRoot -TimeoutSec 2 -HeartbeatSec 1 | Out-Null
    Start-Sleep -Seconds 4
    $s6 = & $Status -JobId 'job-006' -JobsRoot $JobsRoot -Json | ConvertFrom-Json
    Assert ($s6.state -eq 'TIMED_OUT') "expected TIMED_OUT got $($s6.state)"
    $pass++; ReportCase 'timeout to terminal' 'PASS'

    $child7 = Join-Path $Root 'child7.ps1'
    $nestedPidFile = Join-Path $Root 'nested-child.pid'
    ChildScript $child7 '$pidFile=$args[0]; $p=Start-Process -FilePath (Join-Path $PSHOME "powershell.exe") -ArgumentList @("-NoProfile","-Command","Start-Sleep -Seconds 30") -PassThru; Set-Content -LiteralPath $pidFile -Value $p.Id -Encoding ascii; Wait-Process -Id $p.Id'
    & $Start -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$child7,$nestedPidFile) -JobId 'job-007' -JobsRoot $JobsRoot -TimeoutSec 30 -HeartbeatSec 1 | Out-Null
    Start-Sleep -Seconds 2
    $state7 = Get-Content -LiteralPath (Join-Path $JobsRoot 'job-007\state.json') -Raw | ConvertFrom-Json
    Assert (Test-Path -LiteralPath $nestedPidFile) 'nested child pid evidence missing'
    $nestedPid = [int](Get-Content -LiteralPath $nestedPidFile -Raw)
    & $Cancel -JobId 'job-007' -JobsRoot $JobsRoot -Json | Out-Null
    Start-Sleep -Seconds 3
    $s7 = & $Status -JobId 'job-007' -JobsRoot $JobsRoot -Json | ConvertFrom-Json
    Assert ($s7.state -eq 'CANCELLED') "expected CANCELLED got $($s7.state)"
    foreach ($ownedPid in @([int]$state7.child_pid, $nestedPid)) {
        $ownedAlive = $false
        try { $ownedAlive = [bool](Get-Process -Id $ownedPid -ErrorAction Stop) } catch {}
        Assert (-not $ownedAlive) "owned process survived cancel pid=$ownedPid"
    }
    $pass++; ReportCase 'nested child cancel' 'PASS'

    $bad = $false
    try { & $Start -FilePath 'relative.exe' -ArgumentList @() -JobsRoot $JobsRoot | Out-Null } catch { $bad = $true }
    Assert $bad 'malformed path accepted'
    $bad = $false
    try { & $Start -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @() -JobId 'job-011' -JobsRoot $JobsRoot -Worktree 'relative\worktree' | Out-Null } catch { $bad = $true }
    Assert $bad 'malformed worktree accepted'
    $bad = $false
    try { & $Start -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @() -JobId 'job-012' -JobsRoot $JobsRoot -BaseSha 'ABCDEF' | Out-Null } catch { $bad = $true }
    Assert $bad 'malformed base sha accepted'
    $bad = $false
    try { & $Start -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @() -JobId 'x' -JobsRoot $JobsRoot | Out-Null } catch { $bad = $true }
    Assert $bad 'malformed job id accepted'
    $bad = $false
    try { & $Start -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @() -JobId 'job-008' -JobsRoot $JobsRoot -TimeoutSec 0 | Out-Null } catch { $bad = $true }
    Assert $bad 'invalid timeout accepted'
    $pass++; ReportCase 'input validation' 'PASS'

    $child9 = Join-Path $Root 'child9.ps1'
    ChildScript $child9 '$p=$args[0]; $b=$args[1]; $c=$args[2]; $d=$args[3]; $e=$args[4]; Set-Content -LiteralPath $p -Value (($b,$c,$d,$e) -join "|") -Encoding utf8'
    & $Start -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$child9,(Join-Path $Root 'space arg.txt'),'arg with spaces','quoted"arg','trail\') -JobId 'job-009' -JobsRoot $JobsRoot -TimeoutSec 30 -HeartbeatSec 1 | Out-Null
    Start-Sleep -Seconds 2
    $argEcho = Get-Content -LiteralPath (Join-Path $Root 'space arg.txt') -Raw
    Assert ($argEcho -match 'arg with spaces') 'space argument broken'
    Assert ($argEcho -match 'quoted"arg') 'embedded quote argument broken'
    Assert ($argEcho -match 'trail\\') 'trailing backslash argument broken'
    $pass++; ReportCase 'argv quoting' 'PASS'

    $childSmoke = Join-Path $Root 'child_smoke.ps1'
    ChildScript $childSmoke 'Start-Sleep -Seconds 6'
    $smokeSw = [Diagnostics.Stopwatch]::StartNew()
    & $Start -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$childSmoke) -JobId 'job-smoke' -JobsRoot $JobsRoot -TimeoutSec 30 -HeartbeatSec 1 | Out-Null
    $smokeStartSec = $smokeSw.Elapsed.TotalSeconds
    Assert ($smokeStartSec -lt 1) "detached smoke start was too slow: $smokeStartSec"
    Start-Sleep -Seconds 1
    $smoke1 = & $Status -JobId 'job-smoke' -JobsRoot $JobsRoot -Json | ConvertFrom-Json
    Assert ($smoke1.state -eq 'RUNNING') "expected RUNNING got $($smoke1.state)"
    Start-Sleep -Seconds 8
    $smoke2 = & $Status -JobId 'job-smoke' -JobsRoot $JobsRoot -Json | ConvertFrom-Json
    Assert ($smoke2.state -eq 'COMPLETE') "expected COMPLETE got $($smoke2.state)"
    $pass++; ReportCase 'detached smoke' 'PASS'

    & $Start -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @('-NoProfile','-Command','exit 0') -JobId 'job-010' -JobsRoot $JobsRoot -TimeoutSec 30 -HeartbeatSec 1 | Out-Null
    $second = $false
    try { & $Start -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @('-NoProfile','-Command','exit 0') -JobId 'job-010' -JobsRoot $JobsRoot -TimeoutSec 30 -HeartbeatSec 1 | Out-Null } catch { $second = $true }
    Assert $second 'same ID relaunch accepted'
    $pass++; ReportCase 'job id reuse' 'PASS'

    Start-Sleep -Seconds 1
    $ownedLeft = @(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine.Contains($Root) })
    Assert ($ownedLeft.Count -eq 0) ("owned test process leak count={0}" -f $ownedLeft.Count)
    $pass++; ReportCase 'no owned process leak' 'PASS'
    Write-Host ("[PASS] long job runner focused suite cases={0}" -f $pass)
    exit 0
} catch {
    Write-Host "[FAIL] $($_.Exception.Message)"
    exit 1
} finally {
    if (Test-Path -LiteralPath $Root) { Remove-Item -LiteralPath $Root -Recurse -Force }
}
