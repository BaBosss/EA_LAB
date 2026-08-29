param(
  [Parameter(Mandatory=$true)][string]$SafeWorkspace,
  [string]$HermesExe = "$env:LOCALAPPDATA\hermes\hermes-agent\bin\hermes.exe"
)
$ErrorActionPreference = 'Stop'
$moduleRoot = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content -Raw (Join-Path $moduleRoot 'profile_manifest.json') | ConvertFrom-Json
$mcpSpecs = @($manifest.observe_read_only_mcp,$manifest.tester_execution_mcp)
$validationEnvBackup = @{}
foreach ($mcpSpec in @($mcpSpecs)) {
  if ($null -eq $mcpSpec.env) { continue }
  foreach ($envProp in $mcpSpec.env.PSObject.Properties) {
    $envName = [string]$envProp.Name
    if (-not $validationEnvBackup.ContainsKey($envName)) {
      $validationEnvBackup[$envName] = [Environment]::GetEnvironmentVariable($envName,'Process')
      if ([string]::IsNullOrWhiteSpace([string]$validationEnvBackup[$envName])) {
        [Environment]::SetEnvironmentVariable($envName,"EA_LAB_PROFILE_VALIDATE_$envName",'Process')
      }
    }
  }
}
function Restore-ValidationEnv {
  foreach ($envName in $validationEnvBackup.Keys) { [Environment]::SetEnvironmentVariable($envName,$validationEnvBackup[$envName],'Process') }
}
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

  foreach ($mcpSpec in @($mcpSpecs | Where-Object { $_.profile -eq $p.name })) {
    $mcpName = [string]$mcpSpec.name
    $argsOutput = @(& $HermesExe --profile $p.name config get "mcp_servers.$mcpName.args" 2>&1)
    $argsText = $argsOutput -join "`n"
    if ($LASTEXITCODE -ne 0 -or $argsText -notmatch [regex]::Escape('${workspaceFolder}')) {
      $failures.Add("$($p.name): MCP args are not workspace-rooted: $mcpName")
    }
    $scriptRel = ('tools/hermes_ea_lab_pilot/' + ([string]$mcpSpec.script).Replace('\','/'))
    if ($argsText -notmatch [regex]::Escape($scriptRel)) { $failures.Add("$($p.name): MCP script path mismatch: $mcpName") }
    $trust = ((@(& $HermesExe --profile $p.name config get "mcp_servers.$mcpName.trust" 2>&1)) -join '').Trim()
    if ($trust -ne 'full') { $failures.Add("$($p.name): MCP trust must be full: $mcpName") }
    if ($null -ne $mcpSpec.env) {
      foreach ($envProp in $mcpSpec.env.PSObject.Properties) {
        $actualEnv = ((@(& $HermesExe --profile $p.name config get "mcp_servers.$mcpName.env.$($envProp.Name)" 2>&1)) -join "").Trim()
        $expectedEnv = [string]$envProp.Value
        $resolvedExpected = $expectedEnv
        if ($expectedEnv -match '^\$\{env:([^}]+)\}$') {
          $current = [Environment]::GetEnvironmentVariable($Matches[1],'Process')
          if (-not [string]::IsNullOrWhiteSpace($current)) { $resolvedExpected = $current }
        }
        if ($actualEnv -ne $expectedEnv -and $actualEnv -ne $resolvedExpected) { $failures.Add("$($p.name): MCP env binding mismatch: $mcpName/$($envProp.Name)") }
      }
    }
    $include = ((@(& $HermesExe --profile $p.name config get "mcp_servers.$mcpName.tools.include" 2>&1)) -join "`n")
    foreach ($toolName in @($mcpSpec.tools)) {
      if ($include -notmatch ('(?m)^-\s+' + [regex]::Escape([string]$toolName) + '\s*$')) { $failures.Add("$($p.name): missing MCP tool $toolName on $mcpName") }
    }
    $hadTerminalCwd = Test-Path Env:TERMINAL_CWD
    $previousTerminalCwd = $env:TERMINAL_CWD
    Push-Location -LiteralPath $resolved
    try { $env:TERMINAL_CWD = $resolved; $mcpTest = @(& $HermesExe --profile $p.name mcp test $mcpName 2>&1); $mcpExit = $LASTEXITCODE }
    finally { Pop-Location; if ($hadTerminalCwd) { $env:TERMINAL_CWD = $previousTerminalCwd } else { Remove-Item Env:TERMINAL_CWD -ErrorAction SilentlyContinue } }
    if ($mcpExit -ne 0) { $failures.Add("$($p.name): MCP connection failed: $mcpName") }
    $mcpText = $mcpTest -join "`n"
    foreach ($toolName in @($mcpSpec.tools)) {
      if ($mcpText -notmatch ('(?m)^\s*' + [regex]::Escape([string]$toolName) + '(?:\s+.*)?\s*$')) { $failures.Add("$($p.name): MCP did not expose $toolName on $mcpName") }
    }
  }
  Write-Host "CHECK $($p.name): cwd=$($manifest.terminal_cwd); enabled=$($enabled -join ',')"
}

if ($failures.Count) {
  Restore-ValidationEnv
  $failures | ForEach-Object { Write-Error $_ }
  exit 1
}
Restore-ValidationEnv
Write-Host 'PASS Hermes EA_LAB profile validation.'
exit 0
