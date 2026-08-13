<# Register the deterministic five-minute refresh task. ASCII-only. #>
[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$RepoRoot = '',
  [string]$TaskName = 'EA_LAB_ControlDashboard_Refresh',
  [int]$IntervalMinutes = 5
)
$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
if ($IntervalMinutes -lt 1) { throw 'IntervalMinutes must be positive' }
$refresh = Join-Path $RepoRoot 'scripts\control_dashboard.ps1'
if (-not (Test-Path -LiteralPath $refresh)) { throw "missing refresh script: $refresh" }
$taskRun = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$refresh`""
if ($PSCmdlet.ShouldProcess($TaskName, "register refresh every $IntervalMinutes minute(s)")) {
  & schtasks.exe /Create /TN $TaskName /SC MINUTE /MO $IntervalMinutes /TR $taskRun /F | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "Task Scheduler registration failed with exit code $LASTEXITCODE" }
  Write-Host "registered task=$TaskName cadence=every $IntervalMinutes minute(s) script=$refresh"
} else {
  Write-Host "WHATIF task=$TaskName cadence=every $IntervalMinutes minute(s) script=$refresh"
}
