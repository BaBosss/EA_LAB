param(
  [Parameter(Mandatory=$true)][string]$SafeWorkspace,
  [string]$HermesExe = "$env:LOCALAPPDATA\hermes\hermes-agent\bin\hermes.exe"
)
$ErrorActionPreference = 'Stop'
$moduleRoot = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content -Raw (Join-Path $moduleRoot 'profile_manifest.json') | ConvertFrom-Json
$resolved = (Resolve-Path $SafeWorkspace).Path.TrimEnd('\')
if ($resolved -ieq 'D:\EA_LAB' -or $resolved.StartsWith('D:\EA_LAB\',[StringComparison]::OrdinalIgnoreCase)) {
  throw 'Refusing protected dirty primary D:\EA_LAB and its descendants.'
}
$inside = git -C $resolved rev-parse --is-inside-work-tree 2>$null
if ($LASTEXITCODE -ne 0 -or $inside -ne 'true') { throw 'SafeWorkspace is not a Git worktree.' }

$failures = [System.Collections.Generic.List[string]]::new()
foreach ($p in $manifest.profiles) {
  $profileHome = Join-Path $env:LOCALAPPDATA "hermes\profiles\$($p.name)"
  $cfg = Join-Path $profileHome 'config.yaml'
  $soul = Join-Path $profileHome 'SOUL.md'
  $marker = Join-Path $profileHome '.no-bundled-skills'
  if (-not (Test-Path $cfg)) { $failures.Add("$($p.name): missing config.yaml"); continue }
  if (-not (Test-Path $soul)) { $failures.Add("$($p.name): missing SOUL.md") }
  if (-not (Test-Path $marker)) { $failures.Add("$($p.name): bundled-skills opt-out missing") }
  $raw = Get-Content -Raw $cfg
  if ($raw -notmatch [regex]::Escape($manifest.default_model)) { $failures.Add("$($p.name): model pin mismatch") }
  if ($raw -notmatch 'provider:\s+anthropic') { $failures.Add("$($p.name): provider mismatch") }
  if ($raw -notmatch '(?m)^\s+cwd:\s+\.\s*$') { $failures.Add("$($p.name): terminal.cwd must be task-relative dot") }
  if ($raw -notmatch 'hard_stop_enabled:\s+true') { $failures.Add("$($p.name): loop hard-stop disabled") }
  $template = Join-Path $moduleRoot $p.soul
  if ((Test-Path $soul) -and (Test-Path $template)) {
    $actualHash = (Get-FileHash -Algorithm SHA256 $soul).Hash
    $expectedHash = (Get-FileHash -Algorithm SHA256 $template).Hash
    if ($actualHash -ne $expectedHash) { $failures.Add("$($p.name): SOUL hash mismatch") }
  }

  $toolOutput = @(& $HermesExe --profile $p.name tools list 2>&1)
  if ($LASTEXITCODE -ne 0) { $failures.Add("$($p.name): tools list failed"); continue }
  $enabled = @()
  foreach ($line in $toolOutput) {
    if ([string]$line -match 'enabled\s+([A-Za-z0-9_-]+)') { $enabled += $Matches[1] }
  }
  $enabled = @($enabled | Sort-Object -Unique)
  $expected = @($p.enabled_toolsets | ForEach-Object {[string]$_} | Sort-Object -Unique)
  $extra = @($enabled | Where-Object { $_ -notin $expected })
  $missing = @($expected | Where-Object { $_ -notin $enabled })
  if ($extra.Count) { $failures.Add("$($p.name): unexpected toolsets: $($extra -join ',')") }
  if ($missing.Count) { $failures.Add("$($p.name): missing toolsets: $($missing -join ',')") }
  Write-Host "CHECK $($p.name): cwd=$($manifest.terminal_cwd); enabled=$($enabled -join ',')"
}

if ($failures.Count) {
  $failures | ForEach-Object { Write-Error $_ }
  exit 1
}
Write-Host 'PASS Hermes EA_LAB profile validation.'
exit 0
