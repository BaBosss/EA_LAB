# mris_notify.ps1 - standalone Telegram push notifier for the MRIS macro alert
# layer. Reads scripts\config.yaml (simple line-based parser, no yaml module
# dependency - mirrors the fallback parser in scripts\telegram_bot.py) and POSTs
# the given -Message to every id in telegram_allowed_user_ids.
#
# SECURITY: the bot token is never written to console, log, or file. Any
# exception text is scrubbed for the token substring before it is printed.
#
# Graceful no-op (exit 0, not an error) when config is missing, the token is
# missing/empty/placeholder, or there are no allowed ids - so the alert chain
# that calls this script never breaks just because Telegram isn't set up yet.
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true, ParameterSetName='Send')][string]$Message,
  [string]$Config = '',
  [Parameter(ParameterSetName='Send')][switch]$WhatIf,
  # setup helper: list chat ids that have messaged the bot, so the token never has to be
  # pasted into a browser URL (getUpdates needs it in the path, and that lands in history).
  [Parameter(Mandatory=$true, ParameterSetName='Discover')][switch]$ShowChatIds
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot '..\lib\repo_paths.ps1')
$RepoRoot = Resolve-EaLabRepoRoot -AnchorPath $PSCommandPath
if (-not $Config) { $Config = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'scripts\config.yaml' }

function Parse-ConfigYaml {
  param([string]$Path)
  $config = @{}
  $currentListKey = $null
  Get-Content -Path $Path -Encoding UTF8 | ForEach-Object {
    $line = $_.Trim()
    if ([string]::IsNullOrWhiteSpace($line)) { return }
    if ($line.StartsWith("#")) { return }
    if ($line.StartsWith("- ") -and $currentListKey) {
      $value = $line.Substring(2).Trim()
      $value = $value.Trim('"').Trim("'")
      if (-not $config.ContainsKey($currentListKey)) { $config[$currentListKey] = @() }
      $config[$currentListKey] = @($config[$currentListKey]) + $value
      return
    }
    if ($line.IndexOf(':') -lt 0) { return }
    $idx = $line.IndexOf(':')
    $key = $line.Substring(0, $idx).Trim()
    $value = $line.Substring($idx + 1).Trim()
    $currentListKey = $null
    if ([string]::IsNullOrEmpty($value)) {
      $config[$key] = @()
      $currentListKey = $key
      return
    }
    $value = $value.Trim('"').Trim("'")
    $config[$key] = $value
  }
  return $config
}

# ---- resolve config ----
if (!(Test-Path $Config)) {
  Write-Host "[notify] telegram not configured - skipping (set telegram_bot_token in scripts\config.yaml)"
  exit 0
}

$cfg = $null
try {
  $cfg = Parse-ConfigYaml -Path $Config
} catch {
  Write-Host "[notify] telegram not configured - skipping (could not parse config)"
  exit 0
}

$placeholderToken = "PLACEHOLDER_TELEGRAM_BOT_TOKEN"
$token = $null
if ($cfg.ContainsKey('telegram_bot_token')) { $token = "$($cfg['telegram_bot_token'])" }

if ([string]::IsNullOrWhiteSpace($token) -or $token -eq $placeholderToken) {
  Write-Host "[notify] telegram not configured - skipping (set telegram_bot_token in scripts\config.yaml)"
  exit 0
}

# ---- setup helper: discover chat ids (never prints the token) ----
if ($ShowChatIds) {
  $url = "https://api.telegram.org/bot$token/getUpdates"
  try {
    $r = Invoke-RestMethod -Method Get -Uri $url -ErrorAction Stop
  } catch {
    $safe = "$($_.Exception.Message)"
    if (-not [string]::IsNullOrEmpty($token)) { $safe = $safe.Replace($token, "***REDACTED***") }
    Write-Host "[notify] getUpdates failed ($safe)"
    Write-Host "[notify] a 404/401 here usually means the token in config.yaml is wrong or truncated."
    $url = $null
    exit 1
  }
  $url = $null
  if (-not $r.ok) { Write-Host "[notify] telegram api did not report ok"; exit 1 }
  $found = @{}
  foreach ($u in $r.result) {
    foreach ($m in @($u.message, $u.edited_message, $u.channel_post)) {
      if ($null -ne $m -and $null -ne $m.chat) { $found["$($m.chat.id)"] = "$($m.chat.type)/$($m.chat.first_name)$($m.chat.title)" }
    }
  }
  if ($found.Count -eq 0) {
    Write-Host "[notify] no chats found. Open Telegram, send your bot any message (e.g. 'hi'), then re-run this."
    Write-Host "[notify] NOTE: getUpdates only returns RECENT updates - if you messaged it long ago, send another message."
    exit 0
  }
  Write-Host "[notify] chat id(s) that have messaged this bot - put the right one in telegram_allowed_user_ids:"
  foreach ($k in $found.Keys) { Write-Host ("   {0}   ({1})" -f $k, $found[$k]) }
  exit 0
}

$ids = @()
if ($cfg.ContainsKey('telegram_allowed_user_ids')) { $ids = @($cfg['telegram_allowed_user_ids']) }
$ids = @($ids | Where-Object { $_ -and "$_".Trim() -ne "" })

if ($ids.Count -eq 0) {
  Write-Host "[notify] telegram not configured - skipping (no telegram_allowed_user_ids in scripts\config.yaml)"
  exit 0
}

# ---- WhatIf: resolve only, send nothing, never print the token ----
if ($WhatIf) {
  Write-Host "[notify] WhatIf: telegram is configured - would send message to $($ids.Count) allowed id(s)"
  exit 0
}

# ---- send ----
$successCount = 0
$failCount = 0
foreach ($id in $ids) {
  $sendUrl = "https://api.telegram.org/bot$token/sendMessage"
  try {
    $body = @{ chat_id = "$id"; text = $Message }
    $resp = Invoke-RestMethod -Method Post -Uri $sendUrl -Body $body -ErrorAction Stop
    if ($resp -and $resp.ok) {
      Write-Host "[notify] -> $id OK"
      $successCount++
    } else {
      Write-Host "[notify] -> $id FAIL (telegram api did not report ok)"
      $failCount++
    }
  } catch {
    $safeMsg = "$($_.Exception.Message)"
    if (-not [string]::IsNullOrEmpty($token)) { $safeMsg = $safeMsg.Replace($token, "***REDACTED***") }
    Write-Host "[notify] -> $id FAIL ($safeMsg)"
    $failCount++
  } finally {
    $sendUrl = $null
  }
}

Write-Host "[notify] sent $successCount/$($ids.Count) ok"
if ($successCount -eq 0) { exit 1 }
exit 0
