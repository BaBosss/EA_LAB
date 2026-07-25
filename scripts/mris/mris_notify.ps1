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
  [Parameter(Mandatory=$true)][string]$Message,
  [string]$Config = "D:\EA_LAB\scripts\config.yaml",
  [switch]$WhatIf
)
$ErrorActionPreference = "Stop"

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
