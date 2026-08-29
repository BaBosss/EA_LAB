param(
  [Parameter(Mandatory=$true)][ValidateSet('ea-researcher','ea-coder','ea-tester','ea-reviewer')][string]$Role,
  [Parameter(Mandatory=$true)][string]$SafeWorkspace,
  [Parameter(Mandatory=$true)][string]$ExpectedHead,
  [Parameter(Mandatory=$true)][string]$PromptFile,
  [ValidateSet('observe','bounded-write','tester-execute')][string]$Mode = 'observe',
  [string]$TesterManifest = '',
  [string]$TesterManifestSha256 = '',
  [string]$BuildReceiptRegistry = '',
  [string]$BuildReceiptRegistrySha256 = '',
  [string]$TesterSetSha256 = '',
  [string[]]$AllowedPaths = @(),
  [ValidateRange(10,300)][int]$RunBudgetSeconds = 120,
  [string]$InferenceModel = '',
  [string]$InferenceProvider = '',
  [ValidateRange(0,900)][int]$HardTimeoutSeconds = 0,
  [string]$HermesExe = "$env:LOCALAPPDATA\hermes\hermes-agent\bin\hermes.exe"
)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $HermesExe -PathType Leaf)) { throw "Hermes executable not found: $HermesExe" }
if (-not (Test-Path -LiteralPath $PromptFile -PathType Leaf)) { throw "Prompt file not found: $PromptFile" }
if (-not (Test-Path -LiteralPath $SafeWorkspace -PathType Container)) { throw "SafeWorkspace not found: $SafeWorkspace" }
$resolved = (Resolve-Path -LiteralPath $SafeWorkspace).Path.TrimEnd('\')
if ($resolved -ieq 'D:\EA_LAB' -or $resolved.StartsWith('D:\EA_LAB\',[StringComparison]::OrdinalIgnoreCase)) {
  throw 'Refusing protected dirty primary D:\EA_LAB and its descendants.'
}
$inside = (git -C $resolved rev-parse --is-inside-work-tree 2>$null).Trim()
if ($LASTEXITCODE -ne 0 -or $inside -ne 'true') { throw 'SafeWorkspace must be a Git worktree.' }
$head = (git -C $resolved rev-parse HEAD).Trim()
if ($head -ne $ExpectedHead) { throw "HEAD mismatch: expected $ExpectedHead actual $head" }
$before = @(git -C $resolved status --porcelain=v1 --untracked-files=all)
if ($before.Count -ne 0) { throw 'SafeWorkspace must be fully clean before task start.' }
if ($Mode -eq 'bounded-write') {
  if ($Role -ne 'ea-coder') { throw 'bounded-write is restricted to ea-coder.' }
  if ($AllowedPaths.Count -eq 0) { throw 'bounded-write requires at least one AllowedPaths entry.' }
} elseif ($Mode -eq 'tester-execute') {
  if ($Role -ne 'ea-tester') { throw 'tester-execute is restricted to ea-tester.' }
  if ($AllowedPaths.Count -ne 0) { throw 'tester-execute does not accept AllowedPaths.' }
  foreach ($required in @($TesterManifest,$TesterManifestSha256,$BuildReceiptRegistry,$BuildReceiptRegistrySha256,$TesterSetSha256)) {
    if ([string]::IsNullOrWhiteSpace([string]$required)) { throw 'tester-execute requires manifest/receipt/set SHA bindings.' }
  }
  if (-not (Test-Path -LiteralPath $TesterManifest -PathType Leaf)) { throw "TesterManifest not found: $TesterManifest" }
  if (-not (Test-Path -LiteralPath $BuildReceiptRegistry -PathType Leaf)) { throw "BuildReceiptRegistry not found: $BuildReceiptRegistry" }
  foreach ($sha in @($TesterManifestSha256,$BuildReceiptRegistrySha256,$TesterSetSha256)) { if ($sha -notmatch '^[0-9a-fA-F]{64}$') { throw 'tester-execute SHA bindings must be 64 hex.' } }
  if ((Get-FileHash -Algorithm SHA256 -LiteralPath $TesterManifest).Hash -ine $TesterManifestSha256) { throw 'TesterManifest SHA256 mismatch.' }
  if ((Get-FileHash -Algorithm SHA256 -LiteralPath $BuildReceiptRegistry).Hash -ine $BuildReceiptRegistrySha256) { throw 'BuildReceiptRegistry SHA256 mismatch.' }
} elseif ($AllowedPaths.Count -ne 0) {
  throw 'AllowedPaths is valid only with bounded-write mode.'
}

$normalizedAllowed = @($AllowedPaths | ForEach-Object {
  $rawPath = $_.Replace('\','/')
  if ([IO.Path]::IsPathRooted($_) -or $rawPath -match '(^|/)\.\.(/|$)') {
    throw "Allowed path must be repo-relative without ..: $_"
  }
  $p = $rawPath
  while ($p.StartsWith('./')) { $p = $p.Substring(2) }
  if ([string]::IsNullOrWhiteSpace($p)) { throw "Allowed path must name a file: $_" }
  $p
})

$args = @('-p',$Role)
if (-not [string]::IsNullOrWhiteSpace($InferenceModel)) { $args += @('-m',$InferenceModel) }
if (-not [string]::IsNullOrWhiteSpace($InferenceProvider)) { $args += @('--provider',$InferenceProvider) }
$args += @('chat','--in',$resolved,'-Q','--max-turns','8','--run-budget',"$RunBudgetSeconds",'--query-file',$PromptFile)
if ($Mode -eq 'bounded-write') { $args += @('-t','file') }
$hardTimeout = if ($HardTimeoutSeconds -gt 0) { $HardTimeoutSeconds } else { $RunBudgetSeconds + 60 }

$testerEnvNames = @('EA_LAB_TESTER_MANIFEST','EA_LAB_TESTER_MANIFEST_SHA256','EA_LAB_TESTER_RECEIPT_REGISTRY','EA_LAB_TESTER_RECEIPT_SHA256','EA_LAB_TESTER_SET_SHA256')
$testerEnvBackup = @{}
foreach ($name in $testerEnvNames) { $testerEnvBackup[$name] = [Environment]::GetEnvironmentVariable($name,'Process') }

$hadTerminalCwd = Test-Path Env:TERMINAL_CWD
$previousTerminalCwd = $env:TERMINAL_CWD
Push-Location -LiteralPath $resolved
try {
  # Hermes 0.20.5 captures local TERMINAL_CWD from process cwd before --in is applied.
  # Pin both process cwd and env so file/terminal tools resolve to SafeWorkspace.
  $env:TERMINAL_CWD = $resolved
  if ($Mode -eq 'tester-execute') {
    [Environment]::SetEnvironmentVariable('EA_LAB_TESTER_MANIFEST',(Resolve-Path -LiteralPath $TesterManifest).Path,'Process')
    [Environment]::SetEnvironmentVariable('EA_LAB_TESTER_MANIFEST_SHA256',$TesterManifestSha256.ToLowerInvariant(),'Process')
    [Environment]::SetEnvironmentVariable('EA_LAB_TESTER_RECEIPT_REGISTRY',(Resolve-Path -LiteralPath $BuildReceiptRegistry).Path,'Process')
    [Environment]::SetEnvironmentVariable('EA_LAB_TESTER_RECEIPT_SHA256',$BuildReceiptRegistrySha256.ToLowerInvariant(),'Process')
    [Environment]::SetEnvironmentVariable('EA_LAB_TESTER_SET_SHA256',$TesterSetSha256.ToLowerInvariant(),'Process')
  }
  $startArgs = @($args | ForEach-Object {
    $s = [string]$_
    if ($s -match '[\s"]') { '"' + ($s -replace '"','\"') + '"' } else { $s }
  })
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $HermesExe
  $psi.Arguments = ($startArgs -join ' ')
  $psi.WorkingDirectory = $resolved
  $psi.UseShellExecute = $false
  $proc = New-Object System.Diagnostics.Process
  $proc.StartInfo = $psi
  if (-not $proc.Start()) { throw 'Failed to start Hermes process.' }
  if (-not $proc.WaitForExit($hardTimeout * 1000)) {
    & taskkill.exe /PID $proc.Id /T /F 2>$null | Out-Null
    throw "Hermes task exceeded hard timeout ${hardTimeout}s (run budget ${RunBudgetSeconds}s)."
  }
  $agentExit = $proc.ExitCode
} finally {
  Pop-Location
  if ($hadTerminalCwd) { $env:TERMINAL_CWD = $previousTerminalCwd }
  else { Remove-Item Env:TERMINAL_CWD -ErrorAction SilentlyContinue }
  foreach ($name in $testerEnvNames) { [Environment]::SetEnvironmentVariable($name,$testerEnvBackup[$name],'Process') }
}
if ($agentExit -ne 0) { throw "Hermes task failed with exit code $agentExit" }

$afterLines = @(git -C $resolved status --porcelain=v1 --untracked-files=all)
$changedPaths = @($afterLines | ForEach-Object {
  if ($_.Length -lt 4) { return }
  $raw = $_.Substring(3)
  if ($raw -match ' -> ') { $raw = ($raw -split ' -> ')[-1] }
  $raw.Trim('"').Replace('\','/')
})

if ($Mode -eq 'observe') {
  if ($changedPaths.Count -ne 0) { throw ('Observe task mutated workspace: ' + ($changedPaths -join ', ')) }
  Write-Host "PASS observe task: $Role; HEAD=$head; no workspace mutation."
  exit 0
}
if ($Mode -eq 'tester-execute') {
  if ($changedPaths.Count -ne 0) { throw ('Tester task mutated tracked/unignored workspace: ' + ($changedPaths -join ', ')) }
  Write-Host "PASS tester-execute task: $Role; HEAD=$head; no tracked/unignored workspace mutation."
  exit 0
}

$violations = @($changedPaths | Where-Object { $_ -notin $normalizedAllowed })
if ($violations.Count -ne 0) { throw ('Bounded-write escaped allowlist: ' + ($violations -join ', ')) }
$missing = @($normalizedAllowed | Where-Object { $_ -notin $changedPaths })
if ($missing.Count -ne 0) { throw ('Expected allowed path was not changed: ' + ($missing -join ', ')) }
Write-Host ("PASS bounded-write task: {0}; changed={1}" -f $Role,($changedPaths -join ','))
