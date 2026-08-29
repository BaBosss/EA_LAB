param(
  [Parameter(Mandatory=$true)][ValidateSet('ea-researcher','ea-coder','ea-tester','ea-reviewer')][string]$Role,
  [Parameter(Mandatory=$true)][string]$SafeWorkspace,
  [Parameter(Mandatory=$true)][string]$ExpectedHead,
  [Parameter(Mandatory=$true)][string]$PromptFile,
  [ValidateSet('observe','bounded-write')][string]$Mode = 'observe',
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

$hadTerminalCwd = Test-Path Env:TERMINAL_CWD
$previousTerminalCwd = $env:TERMINAL_CWD
Push-Location -LiteralPath $resolved
try {
  # Hermes 0.20.5 captures local TERMINAL_CWD from process cwd before --in is applied.
  # Pin both process cwd and env so file/terminal tools resolve to SafeWorkspace.
  $env:TERMINAL_CWD = $resolved
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

$violations = @($changedPaths | Where-Object { $_ -notin $normalizedAllowed })
if ($violations.Count -ne 0) { throw ('Bounded-write escaped allowlist: ' + ($violations -join ', ')) }
$missing = @($normalizedAllowed | Where-Object { $_ -notin $changedPaths })
if ($missing.Count -ne 0) { throw ('Expected allowed path was not changed: ' + ($missing -join ', ')) }
Write-Host ("PASS bounded-write task: {0}; changed={1}" -f $Role,($changedPaths -join ','))
