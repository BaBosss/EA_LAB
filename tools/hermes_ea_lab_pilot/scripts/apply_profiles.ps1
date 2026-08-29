param(
  [Parameter(Mandatory=$true)][string]$SafeWorkspace,
  [string]$HermesExe = "$env:LOCALAPPDATA\hermes\hermes-agent\bin\hermes.exe"
)
$ErrorActionPreference = 'Stop'
$moduleRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $moduleRoot 'profile_manifest.json'
$manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json

if (-not (Test-Path $HermesExe)) { throw "Hermes executable not found: $HermesExe" }
if (-not (Test-Path $SafeWorkspace)) { throw "SafeWorkspace not found: $SafeWorkspace" }
$resolved = (Resolve-Path $SafeWorkspace).Path
if ($resolved.TrimEnd('\') -ieq 'D:\EA_LAB') { throw 'Refusing dirty primary D:\EA_LAB as Bot workspace.' }
$inside = git -C $resolved rev-parse --is-inside-work-tree 2>$null
if ($LASTEXITCODE -ne 0 -or $inside -ne 'true') { throw 'SafeWorkspace must be a Git worktree.' }
$dirty = @(git -C $resolved status --porcelain=v1 --untracked-files=no)
if ($LASTEXITCODE -ne 0 -or $dirty.Count -ne 0) { throw 'SafeWorkspace tracked files must be clean before profile binding.' }

$allToolsets = @(
  'web','browser','terminal','file','code_execution','vision','video','image_gen','video_gen','bfl',
  'x_search','tts','stt','skills','todo','memory','context_engine','session_search','clarify','delegation',
  'cronjob','homeassistant','spotify','yuanbao','computer_use','a2a'
)
$mcpSpec = $manifest.observe_read_only_mcp
$hermesRoot = Split-Path -Parent (Split-Path -Parent $HermesExe)
$mcpPython = Join-Path $hermesRoot 'venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $mcpPython -PathType Leaf)) { throw "Hermes MCP Python not found: $mcpPython" }
$mcpScript = Join-Path $moduleRoot $mcpSpec.script
if (-not (Test-Path -LiteralPath $mcpScript -PathType Leaf)) { throw "Safe reader MCP script not found: $mcpScript" }

foreach ($p in $manifest.profiles) {
  & $HermesExe profile show $p.name *> $null
  if ($LASTEXITCODE -ne 0) {
    & $HermesExe profile create $p.name --no-skills --no-alias --description "EA_LAB bounded $($p.name) profile"
    if ($LASTEXITCODE -ne 0) { throw "Failed to create profile $($p.name)" }
  }

  & $HermesExe --profile $p.name config set model.default $manifest.default_model | Out-Null
  & $HermesExe --profile $p.name config set model.provider $manifest.default_provider | Out-Null
  & $HermesExe --profile $p.name config set terminal.cwd $manifest.terminal_cwd | Out-Null
  & $HermesExe --profile $p.name config set agent.max_turns 18 | Out-Null
  & $HermesExe --profile $p.name config set tool_loop_guardrails.hard_stop_enabled true | Out-Null
  & $HermesExe --profile $p.name config set tool_loop_guardrails.hard_stop_after.exact_failure 3 | Out-Null
  & $HermesExe --profile $p.name config set tool_loop_guardrails.hard_stop_after.same_tool_failure 4 | Out-Null
  & $HermesExe --profile $p.name config set tool_loop_guardrails.hard_stop_after.idempotent_no_progress 3 | Out-Null

  & $HermesExe --profile $p.name tools disable @allToolsets | Out-Null
  & $HermesExe --profile $p.name tools enable @($p.enabled_toolsets) | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Toolset configuration failed for $($p.name)" }

  if ($p.name -eq $mcpSpec.profile) {
    $workspaceToken = '${workspaceFolder}'
    $scriptRel = ([string]$mcpSpec.script).Replace('\','/')
    # moduleRoot is tools/hermes_ea_lab_pilot, so the context-rooted repository path is stable across worktrees.
    $scriptArg = "$workspaceToken/tools/hermes_ea_lab_pilot/$scriptRel"
    $argsValue = "['$scriptArg','$workspaceToken']"
    $includeValue = '[' + ((@($mcpSpec.tools) | ForEach-Object { "'$($_)'" }) -join ',') + ']'
    & $HermesExe --profile $p.name config set "mcp_servers.$($mcpSpec.name).command" $mcpPython | Out-Null
    & $HermesExe --profile $p.name config set "mcp_servers.$($mcpSpec.name).args" $argsValue | Out-Null
    & $HermesExe --profile $p.name config set "mcp_servers.$($mcpSpec.name).enabled" true | Out-Null
    & $HermesExe --profile $p.name config set "mcp_servers.$($mcpSpec.name).trust" full | Out-Null
    & $HermesExe --profile $p.name config set "mcp_servers.$($mcpSpec.name).tools.include" $includeValue | Out-Null
    & $HermesExe --profile $p.name config set "mcp_servers.$($mcpSpec.name).tools.resources" false | Out-Null
    & $HermesExe --profile $p.name config set "mcp_servers.$($mcpSpec.name).tools.prompts" false | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Read-only MCP configuration failed for $($p.name)" }
  }

  $profileHome = Join-Path $env:LOCALAPPDATA "hermes\profiles\$($p.name)"
  $soulSource = Join-Path $moduleRoot $p.soul
  Copy-Item -LiteralPath $soulSource -Destination (Join-Path $profileHome 'SOUL.md') -Force
  if (-not (Test-Path (Join-Path $profileHome '.no-bundled-skills'))) {
    throw "Profile $($p.name) is not opted out of bundled skills."
  }
  Write-Host "PASS profile applied: $($p.name)"
}
Write-Host 'PASS all Hermes EA_LAB pilot profiles applied.'
