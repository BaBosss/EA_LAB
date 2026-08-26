param([string]$RepoRoot = '')

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }

$Root = Join-Path $env:TEMP ('execution_reliability_test_' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Root -Force | Out-Null
$pass = 0
function Assert($condition, $message) { if (-not $condition) { throw $message } }
function ReportCase($name) { Write-Host "[PASS] $name" }

try {
    $bootstrap = Join-Path $RepoRoot 'scripts\execution_reliability\bootstrap_worktree.ps1'
    $launcher = Join-Path $RepoRoot 'scripts\execution_reliability\launch_worker.ps1'
    $inspectRetry = Join-Path $RepoRoot 'scripts\execution_reliability\inspect_before_retry.ps1'
    $worktree = Join-Path $Root 'worktree'
    New-Item -ItemType Directory -Path $worktree | Out-Null
    Set-Content -LiteralPath (Join-Path $worktree 'tracked.txt') -Value 'clean' -Encoding ascii
    New-Item -ItemType Directory -Path (Join-Path $worktree '.githooks') | Out-Null
    & git -C $worktree init | Out-Null
    & git -C $worktree config user.email 'test@example.invalid'
    & git -C $worktree config user.name 'Execution Reliability Test'
    & git -C $worktree config core.hooksPath '.githooks'
    & git -C $worktree add tracked.txt
    & git -C $worktree commit -m 'test fixture' | Out-Null
    $archive = Join-Path $Root 'python312.zip'
    [System.IO.File]::WriteAllBytes($archive, [byte[]](1,2,3,4))
    $hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
    $result = & $bootstrap -Worktree $worktree -ExpectedHead (git -C $worktree rev-parse HEAD).Trim() -ExpectedHooksPath '.githooks' -PythonArchiveSource $archive -PythonArchiveTarget (Join-Path $Root 'copied-python312.zip') -ExpectedPythonArchiveSha256 $hash -Json | ConvertFrom-Json
    Assert ($result.state -eq 'READY') "expected READY got $($result.state)"
    Assert (Test-Path -LiteralPath (Join-Path $Root 'copied-python312.zip')) 'bootstrap did not copy verified archive'
    $pass++; ReportCase 'bootstrap happy path'

    $jobsRoot = Join-Path $Root 'jobs'
    New-Item -ItemType Directory -Path $jobsRoot | Out-Null
    $prompt = Join-Path $Root 'worker-prompt.txt'
    Set-Content -LiteralPath $prompt -Value 'perform the bounded task' -Encoding utf8
    $postcondition = Join-Path $Root 'postcondition.ps1'
    Set-Content -LiteralPath $postcondition -Value 'exit 0' -Encoding utf8
    $codexJob = & $launcher -Provider Codex -AccessMode Write -ProviderExecutable (Join-Path $PSHOME 'powershell.exe') -PromptFile $prompt -JobId 'worker-codex' -Worktree $worktree -ExpectedHead (git -C $worktree rev-parse HEAD).Trim() -ExpectedHooksPath '.githooks' -PostconditionFilePath (Join-Path $PSHOME 'powershell.exe') -PostconditionArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$postcondition) -JobsRoot $jobsRoot -TimeoutSec 30 -HeartbeatSec 1 -Json | ConvertFrom-Json
    Assert ($codexJob.job_id -eq 'worker-codex') 'launcher did not return long job id'
    $codexMeta = Get-Content -LiteralPath (Join-Path $jobsRoot 'worker-codex\job.json') -Raw | ConvertFrom-Json
    Assert ($codexMeta.file_path -eq (Join-Path $PSHOME 'powershell.exe')) 'launcher did not launch the selected Codex executable through Long Job Runner'
    Assert ($codexMeta.stage -eq 'WORKER_CODEX_WRITE') "unexpected Codex stage: $($codexMeta.stage)"
    $expectedCodexArgs = @('exec','--sandbox','workspace-write','--ask-for-approval','never','--cd',$worktree,'perform the bounded task')
    $expectedArgHash = [Convert]::ToBase64String((New-Object System.Security.Cryptography.SHA256Managed).ComputeHash([Text.Encoding]::UTF8.GetBytes(($expectedCodexArgs -join "`u0000"))))
    Assert ($codexMeta.arg_hash -eq $expectedArgHash) 'Codex launcher arguments are not deterministic noninteractive workspace-write arguments'
    $duplicateRefused = $false
    try { & $launcher -Provider Codex -AccessMode Write -ProviderExecutable (Join-Path $PSHOME 'powershell.exe') -PromptFile $prompt -JobId 'worker-codex' -Worktree $worktree -ExpectedHead (git -C $worktree rev-parse HEAD).Trim() -ExpectedHooksPath '.githooks' -PostconditionFilePath (Join-Path $PSHOME 'powershell.exe') -PostconditionArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$postcondition) -JobsRoot $jobsRoot -TimeoutSec 30 -HeartbeatSec 1 | Out-Null } catch { $duplicateRefused = $true }
    Assert $duplicateRefused 'launcher did not preserve Long Job Runner duplicate prevention'
    $pass++; ReportCase 'Codex launcher deterministic args and duplicate prevention'

    $qwenMarker = Join-Path $Root 'qwen-invoked.marker'
    $qwenJobRoot = Join-Path $jobsRoot 'worker-qwen'
    $qwenRefused = $false
    try { & $launcher -Provider Qwen -AccessMode Write -ProviderExecutable (Join-Path $Root 'would-invoke-qwen.exe') -PromptFile $prompt -JobId 'worker-qwen' -Worktree $worktree -ExpectedHead (git -C $worktree rev-parse HEAD).Trim() -ExpectedHooksPath '.githooks' -PostconditionFilePath (Join-Path $PSHOME 'powershell.exe') -PostconditionArgumentList @('-NoProfile','-Command',"Set-Content -LiteralPath '$qwenMarker' -Value invoked") -JobsRoot $jobsRoot -TimeoutSec 30 -HeartbeatSec 1 | Out-Null } catch { $qwenRefused = ($_.Exception.Message -match 'QWEN_WRITE_REFUSED') }
    Assert $qwenRefused 'Qwen write was not refused at preflight'
    Assert (-not (Test-Path -LiteralPath $qwenJobRoot)) 'Qwen write created a Long Job Runner request before refusal'
    Assert (-not (Test-Path -LiteralPath $qwenMarker)) 'Qwen write invoked a provider before refusal'
    $pass++; ReportCase 'Qwen write refusal before provider invocation'

    $liveJobRoot = Join-Path $jobsRoot 'retry-live'
    New-Item -ItemType Directory -Path $liveJobRoot | Out-Null
    [ordered]@{ job_id = 'retry-live'; state = 'RUNNING'; runner_pid = $PID; child_pid = 999999 } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $liveJobRoot 'state.json') -Encoding utf8
    $liveRetry = & $inspectRetry -JobId 'retry-live' -JobsRoot $jobsRoot -Json | ConvertFrom-Json
    Assert ($liveRetry.retry_decision -eq 'REFUSE_RETRY') "live job retry decision was $($liveRetry.retry_decision)"
    $postconditionJobRoot = Join-Path $jobsRoot 'retry-postcondition'
    New-Item -ItemType Directory -Path $postconditionJobRoot | Out-Null
    [ordered]@{ job_id = 'retry-postcondition'; state = 'POSTCONDITION_RUNNING'; runner_pid = 999999; child_pid = 999998; postcondition_pid = 999997 } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $postconditionJobRoot 'state.json') -Encoding utf8
    $postconditionRetry = & $inspectRetry -JobId 'retry-postcondition' -JobsRoot $jobsRoot -Json | ConvertFrom-Json
    Assert ($postconditionRetry.state -eq 'LOST_PROCESS') "dead postcondition state was $($postconditionRetry.state)"
    Assert ($postconditionRetry.retry_decision -eq 'ALLOW_RETRY') "dead postcondition retry decision was $($postconditionRetry.retry_decision)"
    $postconditionLiveJobRoot = Join-Path $jobsRoot 'retry-postcondition-live'
    New-Item -ItemType Directory -Path $postconditionLiveJobRoot | Out-Null
    [ordered]@{ job_id = 'retry-postcondition-live'; state = 'POSTCONDITION_RUNNING'; runner_pid = 999999; child_pid = 999998; postcondition_pid = $PID } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $postconditionLiveJobRoot 'state.json') -Encoding utf8
    $postconditionLiveRetry = & $inspectRetry -JobId 'retry-postcondition-live' -JobsRoot $jobsRoot -Json | ConvertFrom-Json
    Assert ($postconditionLiveRetry.retry_decision -eq 'REFUSE_RETRY') "live postcondition retry decision was $($postconditionLiveRetry.retry_decision)"
    $safeJobRoot = Join-Path $jobsRoot 'retry-safe'
    New-Item -ItemType Directory -Path $safeJobRoot | Out-Null
    [ordered]@{ job_id = 'retry-safe'; state = 'POSTCONDITION_FAILED'; runner_pid = 999997; child_pid = 999996 } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $safeJobRoot 'state.json') -Encoding utf8
    $safeRetry = & $inspectRetry -JobId 'retry-safe' -JobsRoot $jobsRoot -Json | ConvertFrom-Json
    Assert ($safeRetry.retry_decision -eq 'ALLOW_RETRY') "safe terminal retry decision was $($safeRetry.retry_decision)"
    $unknownRetry = & $inspectRetry -JobId 'retry-unknown' -JobsRoot $jobsRoot -Json | ConvertFrom-Json
    Assert ($unknownRetry.retry_decision -eq 'REFUSE_RETRY') "missing state retry decision was $($unknownRetry.retry_decision)"
    $pass++; ReportCase 'inspect before retry postcondition recovery, live refusal, safe terminal allow and unknown fail closed'

    Set-Content -LiteralPath (Join-Path $worktree 'tracked.txt') -Value 'dirty' -Encoding ascii
    $dirtyRefused = $false
    try { & $bootstrap -Worktree $worktree -ExpectedHead (git -C $worktree rev-parse HEAD).Trim() -ExpectedHooksPath '.githooks' -Json | Out-Null } catch { $dirtyRefused = ($_.Exception.Message -match 'tracked worktree is dirty') }
    Assert $dirtyRefused 'bootstrap did not refuse a dirty tracked worktree'
    $pass++; ReportCase 'bootstrap hash and dirty refusal'
    Write-Host "[PASS] execution reliability focused suite cases=$pass"
    exit 0
} catch {
    Write-Host "[FAIL] $($_.Exception.Message)"
    exit 1
} finally {
    if (Test-Path -LiteralPath $Root) { Remove-Item -LiteralPath $Root -Recurse -Force }
}
