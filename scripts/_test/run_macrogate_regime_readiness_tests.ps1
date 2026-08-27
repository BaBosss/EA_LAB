# Deterministic repository cage for MacroGate RegimeOnly scheduling/readiness contract.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$docPath = Join-Path $root 'ea_projects\(Boss)_NewsGuard\vps_rclone\REGIME_ONLY_DEMO_RUNBOOK.md'
$regCmdPath = Join-Path $root 'ea_projects\(Boss)_NewsGuard\vps_rclone\pull_regime.cmd'
$newsCmdPath = Join-Path $root 'ea_projects\(Boss)_NewsGuard\vps_rclone\pull_news.cmd'
$workerPath = Join-Path $root 'ea_projects\(Boss)_NewsGuard\vps_rclone\pull_guard_feeds.ps1'
$publisherPath = Join-Path $root 'scripts\publish_guard_feeds_to_vps.ps1'
$pipelinePath = Join-Path $root 'scripts\_test\run_guard_feed_pipeline_tests.ps1'

function Require-Literal([string]$Text,[string]$Needle,[string]$Label) {
  if (-not $Text.Contains($Needle)) { throw "readiness missing ${Label}: $Needle" }
}
function Require-Regex([string]$Text,[string]$Pattern,[string]$Label) {
  if ($Text -notmatch $Pattern) { throw "readiness missing ${Label} pattern: $Pattern" }
}
function Assert-FreshnessBudget([int]$Upstream,[int]$Cadence,[int]$Vps) {
  if (($Upstream + $Cadence) -ge $Vps) { throw "cadence consumes freshness budget: $Upstream + $Cadence >= $Vps" }
}
function Assert-ReadinessDocument([string]$Text) {
  Require-Literal $Text 'EA_LAB_MacroGate_RegimeOnly_Pull' 'task identity'
  Require-Literal $Text 'C:\Windows\System32\cmd.exe' 'program'
  Require-Literal $Text '/d /c ""C:\rclone\pull_regime.cmd""' 'arguments'
  Require-Literal $Text 'Start in: `C:\rclone`' 'working directory'
  Require-Literal $Text 'daily at `00:17` VPS-local time' 'trigger'
  Require-Literal $Text 'every **4 hours**' 'cadence'
  Require-Literal $Text 'RegimeMaxAgeHours=30' 'upstream freshness bound'
  Require-Literal $Text 'RegimeMaxAgeHours=36' 'VPS freshness bound'
  Require-Literal $Text 'leaving 2 hours' 'freshness margin'
  Require-Literal $Text 'FUTURE RUNTIME PRECONDITION' 'runtime precondition marker'
  Require-Literal $Text 'Simultaneous `pull_news.cmd` and `pull_regime.cmd` execution is **PROHIBITED**' 'collision rule'
  Require-Literal $Text 'Do not assume `Administrator`, `SYSTEM`' 'run-as identity refusal'
  Require-Literal $Text 'LastTaskResult = 0' 'fail-visible scheduler result'
  Require-Literal $Text 'guard feed pull COMPLETE: MacroGate regime-only feed validated and published atomically' 'success suffix'
  Require-Literal $Text '**REFUSE RESTORE**' 'last-good refusal'
  Require-Literal $Text 'disable `EA_LAB_MacroGate_RegimeOnly_Pull`' 'rollback target'
  Require-Literal $Text 'NewsGuard non-interference proof' 'NewsGuard boundary'
  Require-Literal $Text 'owner has explicitly authorized actual VPS scheduling/deployment' 'runtime authority gate'
  if ($Text -match '(?i)\bschtasks(?:\.exe)?\s+/create\b|\bRegister-ScheduledTask\b|\bNew-ScheduledTaskAction\b') {
    throw 'readiness document contains an unauthorized scheduler-creation command'
  }
}
function Assert-WorkerBoundary([string]$Text) {
  Require-Regex $Text "if\s*\(\s*-not\s+\`$RegimeOnly\s*\)\s*\{\s*Publish-Staged\s+'NewsGuard'" 'NewsGuard RegimeOnly publish guard'
  Require-Literal $Text "if (`$RegimeOnly) { @('EA_LAB_mris_regime.csv') } else" 'RegimeOnly fetch allowlist'
}
function Expect-DocRefusal([string]$Label,[string]$Text) {
  try { Assert-ReadinessDocument $Text; throw "negative case unexpectedly accepted: $Label" }
  catch { if ($_.Exception.Message -like 'negative case unexpectedly accepted:*') { throw }; Write-Host "[PASS NEG] $Label" }
}

$doc = Get-Content -Raw -LiteralPath $docPath
$regCmd = Get-Content -Raw -LiteralPath $regCmdPath
$newsCmd = Get-Content -Raw -LiteralPath $newsCmdPath
$worker = Get-Content -Raw -LiteralPath $workerPath
$publisher = Get-Content -Raw -LiteralPath $publisherPath
$pipeline = Get-Content -Raw -LiteralPath $pipelinePath

Assert-ReadinessDocument $doc
Require-Literal $regCmd '-RegimeOnly' 'pull_regime RegimeOnly switch'
Require-Literal $regCmd 'exit /b %ERRORLEVEL%' 'entrypoint exit propagation'
Require-Literal $newsCmd 'pull_guard_feeds.ps1' 'pull_news shared worker binding'
Assert-WorkerBoundary $worker
Require-Regex $publisher '\[int\]\$RegimeMaxAgeHours\s*=\s*30' 'publisher 30h default'
Require-Regex $worker '\[int\]\$RegimeMaxAgeHours\s*=\s*36' 'VPS worker 36h default'
Require-Literal $pipeline 'regime-only mode touched NewsGuard Common file' 'Common NewsGuard hash cage'
Require-Literal $pipeline 'regime-only fetch touched staged NewsGuard file' 'staged NewsGuard hash cage'

$upstream = [int]([regex]::Match($publisher,'\[int\]\$RegimeMaxAgeHours\s*=\s*(\d+)').Groups[1].Value)
$vps = [int]([regex]::Match($worker,'\[int\]\$RegimeMaxAgeHours\s*=\s*(\d+)').Groups[1].Value)
Assert-FreshnessBudget $upstream 4 $vps
Write-Host "[PASS] cadence budget: $upstream + 4 < $vps"
try { Assert-FreshnessBudget $upstream 8 $vps; throw 'negative cadence unexpectedly accepted' }
catch { if ($_.Exception.Message -eq 'negative cadence unexpectedly accepted') { throw }; Write-Host '[PASS NEG] cadence exceeding freshness budget refused' }
Expect-DocRefusal 'missing run-as identity' ($doc.Replace('FUTURE RUNTIME PRECONDITION','RUNTIME PRECONDITION REMOVED'))
Expect-DocRefusal 'collision ambiguity' ($doc.Replace('Simultaneous `pull_news.cmd` and `pull_regime.cmd` execution is **PROHIBITED**','Simultaneous execution may be safe'))
Expect-DocRefusal 'silent scheduler result' ($doc.Replace('LastTaskResult = 0','scheduler result hidden'))
Expect-DocRefusal 'rollback target absent' ($doc.Replace('disable `EA_LAB_MacroGate_RegimeOnly_Pull`','disable the task'))
Expect-DocRefusal 'runtime authority gate absent' ($doc.Replace('owner has explicitly authorized actual VPS scheduling/deployment','runtime authorization assumed'))
try {
  Assert-WorkerBoundary ($worker.Replace('if (-not $RegimeOnly) {','if ($true) {'))
  throw 'negative NewsGuard coupling unexpectedly accepted'
} catch {
  if ($_.Exception.Message -eq 'negative NewsGuard coupling unexpectedly accepted') { throw }
  Write-Host '[PASS NEG] NewsGuard coupling mutation refused'
}
try {
  Assert-ReadinessDocument ($doc + "`n`schtasks.exe /Create /TN forbidden")
  throw 'negative scheduler activation unexpectedly accepted'
} catch {
  if ($_.Exception.Message -eq 'negative scheduler activation unexpectedly accepted') { throw }
  Write-Host '[PASS NEG] unauthorized scheduler creation command refused'
}

Write-Host '[PASS] MacroGate RegimeOnly readiness contract focused checks passed'
exit 0
