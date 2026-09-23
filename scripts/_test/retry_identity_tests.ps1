param([string]$RepoRoot = '')
$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
$root = Join-Path $env:TEMP ('c01-retry-tests-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path "$root\scripts\execution_reliability" -Force)
[void](New-Item -ItemType Directory -Path "$root\scripts\long_jobs" -Force)
$inspect = "$root\scripts\execution_reliability\inspect_before_retry.ps1"
$helper = "$root\scripts\long_jobs\_long_job_runner_lib.ps1"
Copy-Item -LiteralPath "$RepoRoot\scripts\execution_reliability\inspect_before_retry.ps1" -Destination $inspect
Copy-Item -LiteralPath "$RepoRoot\scripts\long_jobs\_long_job_runner_lib.ps1" -Destination $helper
# Only the observation seam is replaced. Parsing, identity comparison and admission are real.
@'
$script:OriginalRetrySnapshot = ${function:Get-LjrProcessSnapshot}
function Get-LjrProcessSnapshot {
    param([int]$ProcessId)
    $fixture = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\..\observation.json') -Raw | ConvertFrom-Json
    if ($fixture.mode -eq 'inaccessible') { throw 'fixture access denied' }
    if ($fixture.mode -eq 'mutate') {
        [IO.File]::AppendAllText((Join-Path $PSScriptRoot '..\..\jobs\retry-fixture\state.json'), ' ')
    }
    $entry = $fixture.processes.PSObject.Properties[[string]$ProcessId]
    if ($entry) { return $entry.Value }
    return (& $script:OriginalRetrySnapshot -ProcessId $ProcessId)
}
'@ | Add-Content -LiteralPath $helper
$jobs = Join-Path $root 'jobs'
$jobRoot = Join-Path $jobs 'retry-fixture'
[void](New-Item -ItemType Directory -Path $jobRoot -Force)
$pass = 0
function Assert($condition, $message) { if (-not $condition) { throw $message } }
function WriteJson($path, $value) { [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding($false))) }
function New-State($name = 'FAILED') {
    return [ordered]@{job_id='retry-fixture'; state=$name; runner_pid=[int]::MaxValue; runner_start_utc='2000-01-01T00:00:00.0000000Z'; child_pid=2147483646; child_start_utc='2000-01-01T00:00:01.0000000Z'}
}
function Check($name, $state, $expected, $processes=@{}, $post='', $mode='normal') {
    WriteJson "$jobRoot\state.json" $state
    WriteJson "$jobRoot\job.json" @{job_id='retry-fixture';postcondition_file_path=$post}
    WriteJson "$root\observation.json" @{mode=$mode;processes=$processes}
    $before = (Get-FileHash "$jobRoot\state.json").Hash
    $answer = & $inspect -JobId retry-fixture -JobsRoot $jobs -Json | ConvertFrom-Json
    Assert ($answer.retry_decision -ceq $expected) "$name expected $expected got $($answer | ConvertTo-Json -Compress)"
    if ($mode -ne 'mutate') { Assert ((Get-FileHash "$jobRoot\state.json").Hash -ceq $before) "$name mutated durable state" }
    $script:pass++; Write-Host "[PASS] $name"
    return $answer
}
try {
    $state = New-State
    $live = @{Pid=$state.runner_pid;StartTimeUtc=$state.runner_start_utc;HasExited=$false}
    $answer = Check 'exact PID and StartTime live refuses duplicate' $state REFUSE_RETRY @{([string]$state.runner_pid)=$live}
    Assert ($answer.runner_alive -eq $true -and $answer.process_identities.runner -ceq 'MATCHING_RECORDED_PROCESS') 'exact identity misclassified'
    $live.StartTimeUtc='2000-01-01T00:00:00.0000001Z'
    $answer = Check 'reused PID differing only at 100ns is not original' $state ALLOW_RETRY @{([string]$state.runner_pid)=$live}
    Assert ($answer.runner_alive -eq $false -and $answer.process_identities.runner -ceq 'DIFFERENT_CREATION_IDENTITY') 'PID reuse misclassified'
    $live.StartTimeUtc='2000-01-01T07:00:00.0000000+07:00'
    $null = Check 'timezone equivalent StartTime still refuses' $state REFUSE_RETRY @{([string]$state.runner_pid)=$live}
    foreach ($terminal in @('FAILED','POSTCONDITION_FAILED','TIMED_OUT','CANCELLED','LOST_PROCESS','POSTCONDITION_RUNNING')) {
        $state=New-State $terminal
        $post=''
        if ($terminal -like 'POSTCONDITION*') {
            $state.postcondition_pid=2147483645; $state.postcondition_start_utc='2000-01-01T00:00:02.0000000Z'; $post='configured.exe'
        }
        $answer=Check "existing eligible state $terminal with absent recorded processes" $state ALLOW_RETRY @{} $post
        Assert ($answer.process_identities.runner -ceq 'RECORDED_PROCESS_NOT_PRESENT') 'absent process misclassified'
    }
    foreach ($active in @('STARTING','RUNNING','CANCEL_REQUESTED','COMPLETE','invented')) {
        $null=Check "state $active never gains eligibility" (New-State $active) REFUSE_RETRY
    }
    # A surviving descendant need not appear in the durable direct-PID fields. Do not revive
    # the rejected generic dead-RUNNING admission even if both recorded parents disappeared.
    $descendant=@{Pid=$PID;StartTimeUtc=(Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o');HasExited=$false}
    $null=Check 'dead RUNNING parents with unrecorded surviving descendant refuse' (New-State 'RUNNING') REFUSE_RETRY @{([string]$PID)=$descendant}
    Assert ([bool](Get-Process -Id $PID -ErrorAction Stop)) 'unrecorded live fixture was disturbed'
    foreach ($role in @('runner','child','postcondition')) {
        $state=New-State
        $post=''
        if ($role -eq 'postcondition') { $state.postcondition_pid=2147483645; $state.postcondition_start_utc='2000-01-01T00:00:02.0000000Z'; $post='configured.exe' }
        $observed=@{Pid=$state[($role+'_pid')];StartTimeUtc=$state[($role+'_start_utc')];HasExited=$false}
        $answer=Check "live exact $role prevents retry" $state REFUSE_RETRY @{([string]$observed.Pid)=$observed} $post
        Assert ($answer.PSObject.Properties[($role+'_alive')].Value -eq $true) "$role live evidence lost"
        $state.Remove(($role+'_start_utc'))
        $null=Check "missing $role identity fails closed even with absent PID" $state REFUSE_RETRY @{} $post
    }
    foreach ($bad in @($null,'','not-a-date','2000-01-01T00:00:00','2999-01-01T00:00:00Z')) {
        $state=New-State; $state.runner_start_utc=$bad
        $null=Check 'invalid recorded creation identity' $state REFUSE_RETRY
    }
    foreach ($bad in @($true,0,-1,1.5,'2147483647')) {
        $state=New-State; $state.runner_pid=$bad
        $null=Check 'invalid recorded PID' $state REFUSE_RETRY
    }
    $state=New-State
    foreach ($current in @('', 'not-a-date', '2999-01-01T00:00:00Z')) {
        $null=Check 'ambiguous current creation identity fails closed' $state REFUSE_RETRY @{([string]$state.runner_pid)=@{Pid=$state.runner_pid;StartTimeUtc=$current;HasExited=$false}}
    }
    $null=Check 'access error never proves absence' $state REFUSE_RETRY @{} '' inaccessible
    $null=Check 'exit race never proves identity' $state REFUSE_RETRY @{([string]$state.runner_pid)=@{Pid=$state.runner_pid;StartTimeUtc=$state.runner_start_utc;HasExited=$true}}
    $null=Check 'wrong PID in observation is ambiguous' $state REFUSE_RETRY @{([string]$state.runner_pid)=@{Pid=123;StartTimeUtc=$state.runner_start_utc;HasExited=$false}}
    $null=Check 'missing exit state in observation is ambiguous' $state REFUSE_RETRY @{([string]$state.runner_pid)=@{Pid=$state.runner_pid;StartTimeUtc=$state.runner_start_utc}}
    $null=Check 'source mutation fails closed' $state REFUSE_RETRY @{} '' mutate
    $null=Check 'configured postcondition missing PID cannot hide descendants' $state REFUSE_RETRY @{} 'configured.exe'
    $state.postcondition_pid=2147483645; $state.postcondition_start_utc='2000-01-01T00:00:02Z'
    $null=Check 'unconfigured postcondition conflicts with recorded identity' $state REFUSE_RETRY
    $state=New-State; $state.job_id='other-job'
    $null=Check 'mismatched job binding' $state REFUSE_RETRY
    WriteJson "$root\observation.json" @{mode='normal';processes=@{}}
    WriteJson "$jobRoot\job.json" @{job_id='retry-fixture';postcondition_file_path=''}
    $duplicate='{"job_id":"retry-fixture","state":"FAILED","runner_pid":2147483647,"runner_pid":1,"runner_start_utc":"2000-01-01T00:00:00Z","child_pid":2147483646,"child_start_utc":"2000-01-01T00:00:01Z"}'
    [IO.File]::WriteAllText("$jobRoot\state.json",$duplicate)
    $answer=& $inspect -JobId retry-fixture -JobsRoot $jobs -Json | ConvertFrom-Json
    Assert ($answer.retry_decision -ceq 'REFUSE_RETRY') 'duplicate-key identity accepted'
    $pass++; Write-Host '[PASS] duplicate identity key fails closed'
    # Real self observation proves repeated inspection leaves its creation identity intact.
    $state=New-State; $state.runner_pid=$PID; $state.runner_start_utc=(Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o')
    $null=Check 'real exact live process' $state REFUSE_RETRY
    Assert ((Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o') -ceq $state.runner_start_utc) 'self process identity changed'
    $state.runner_start_utc=([DateTimeOffset]::Parse($state.runner_start_utc)).AddTicks(-1).ToString('o')
    $answer=Check 'real live PID with different recorded StartTime is unrelated' $state ALLOW_RETRY
    Assert ($answer.runner_alive -eq $false -and $answer.process_identities.runner -ceq 'DIFFERENT_CREATION_IDENTITY') 'real reused-PID fixture still counted as original'
    foreach ($file in @($inspect,$helper)) {
        $tokens=$null; $errors=$null
        $ast=[Management.Automation.Language.Parser]::ParseFile($file,[ref]$tokens,[ref]$errors)
        Assert ($errors.Count -eq 0) 'PowerShell parse failed'
        $nodes=if ($file -eq $inspect) { @($ast) } else { @($ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -in @('Get-IdentityEvidence','ConvertTo-PreciseUtcTicks','Get-LjrProcessSnapshot')},$true)) }
        foreach ($node in $nodes) {
            $forbidden=@($node.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -match '^(Start-Process|Stop-Process|Restart-Service|Start-Service|Stop-LjrOwnedProcessTree|taskkill|start_long_job.ps1)$'},$true))
            Assert ($forbidden.Count -eq 0) 'retry identity path gained process control'
        }
    }
    $pass++; Write-Host '[PASS] retry path has no kill/restart and preserves process identity'
    Write-Host "RETRY_IDENTITY_TESTS_PASS cases=$pass"
} finally {
    $resolved=[IO.Path]::GetFullPath($root)
    if ($resolved.StartsWith(([IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\c01-retry-tests-'),[StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
