param([string]$RepoRoot='')
$ErrorActionPreference='Stop'
if(-not $RepoRoot){ $RepoRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
$root=Join-Path $env:TEMP ('reviewer_launcher_'+[guid]::NewGuid().ToString('N'))
$pass=0
function Assert($ok,[string]$message){ if(-not $ok){ throw $message } }
function Pass([string]$name){ $script:pass++; Write-Host "[PASS] $name" }
try {
  New-Item -ItemType Directory -Path $root -Force | Out-Null
  $wt=Join-Path $root 'review-wt'
  New-Item -ItemType Directory -Path $wt | Out-Null
  Set-Content -LiteralPath (Join-Path $wt 'tracked.txt') -Value 'clean' -Encoding ascii
  New-Item -ItemType Directory -Path (Join-Path $wt '.githooks') | Out-Null
  & git -C $wt init | Out-Null
  & git -C $wt config user.email 'review-test@example.invalid'
  & git -C $wt config user.name 'Reviewer Test'
  & git -C $wt config core.hooksPath '.githooks'
  & git -C $wt add tracked.txt
  & git -C $wt commit -m fixture | Out-Null
  $head=(& git -C $wt rev-parse HEAD).Trim()
  $prompt=Join-Path $root 'prompt.txt'
  Set-Content -LiteralPath $prompt -Value 'VERIFY EXACT HEAD' -Encoding ascii
  $fake=Join-Path $root 'fake_claude.ps1'
  @'
begin { $items=@() }
process { $items += [string]$_ }
end {
  Write-Output ('CWD='+(Get-Location).Path)
  Write-Output ('ARGS='+($args -join '|'))
  Write-Output ('PROMPT='+($items -join ''))
}
'@ | Set-Content -LiteralPath $fake -Encoding utf8
  $helper=Join-Path $RepoRoot 'scripts\execution_reliability\run_claude_reviewer.ps1'
  $launcher=Join-Path $RepoRoot 'scripts\execution_reliability\launch_reviewer.ps1'
  $directOut=Join-Path $root 'direct.txt'
  & $helper -ClaudeExecutable $fake -PromptFile $prompt -Worktree $wt -ExpectedHead $head -OutputFile $directOut | Out-Null
  $direct=Get-Content -LiteralPath $directOut -Raw
  Assert ($direct -match [regex]::Escape("CWD=$wt")) 'helper did not use review worktree as CWD'
  Assert ($direct -match 'PROMPT=VERIFY EXACT HEAD') 'helper did not pipe prompt through stdin'
  Assert ($direct -match 'ARGS=.*--print.*--permission-mode.*dontAsk.*--allowedTools.*Read.*Glob.*Grep') 'helper Claude args drifted'
  Pass 'file-backed helper CWD stdin and read-only tool arguments'

  $jobs=Join-Path $root 'jobs'
  New-Item -ItemType Directory -Path $jobs | Out-Null
  $detachedOut=Join-Path $root 'detached.txt'
  $job=& $launcher -ClaudeExecutable $fake -PromptFile $prompt -JobId 'reviewer-fixture' -Worktree $wt -ExpectedHead $head -OutputFile $detachedOut -JobsRoot $jobs -ExpectedHooksPath '.githooks' -TimeoutSec 30 -HeartbeatSec 1 -Json | ConvertFrom-Json
  Assert ($job.job_id -eq 'reviewer-fixture') 'launcher did not return expected job id'
  $wait=Join-Path $RepoRoot 'scripts\long_jobs\wait_long_job.ps1'
  $done=& $wait -JobId 'reviewer-fixture' -JobsRoot $jobs -MaxWaitSec 20 -Json | ConvertFrom-Json
  Assert ($done.state -eq 'COMPLETE') "detached reviewer state=$($done.state)"
  Assert (Test-Path -LiteralPath $detachedOut) 'detached reviewer output missing'
  Assert ((Get-Content -LiteralPath $detachedOut -Raw) -match 'PROMPT=VERIFY EXACT HEAD') 'detached reviewer output lacks prompt receipt'
  Pass 'detached exact-head reviewer via Long Job Runner'

  $inside=Join-Path $wt 'review.txt'
  $refused=$false
  try { & $launcher -ClaudeExecutable $fake -PromptFile $prompt -JobId 'bad-inside' -Worktree $wt -ExpectedHead $head -OutputFile $inside -JobsRoot $jobs -ExpectedHooksPath '.githooks' | Out-Null }
  catch { $refused=$_.Exception.Message -match 'outside the reviewed worktree' }
  Assert $refused 'launcher allowed review output inside frozen worktree'
  Assert (-not (Test-Path -LiteralPath (Join-Path $jobs 'bad-inside'))) 'refused launch created job metadata'
  Pass 'output-inside-worktree refusal occurs before launch'

  $wrong=('0'*40)
  $wrongRefused=$false
  try { & $launcher -ClaudeExecutable $fake -PromptFile $prompt -JobId 'bad-head' -Worktree $wt -ExpectedHead $wrong -OutputFile (Join-Path $root 'bad-head.txt') -JobsRoot $jobs -ExpectedHooksPath '.githooks' | Out-Null }
  catch { $wrongRefused=$_.Exception.Message -match 'HEAD mismatch' }
  Assert $wrongRefused 'launcher did not refuse wrong exact HEAD'
  Assert (-not (Test-Path -LiteralPath (Join-Path $jobs 'bad-head'))) 'wrong-head refusal created job metadata'
  Pass 'wrong exact-head refusal occurs before launch'
  Write-Host "[PASS] reviewer launcher focused suite cases=$pass"
  exit 0
} catch {
  Write-Host "[FAIL] $($_.Exception.Message)"
  exit 1
} finally {
  if(Test-Path -LiteralPath $root){ Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}
