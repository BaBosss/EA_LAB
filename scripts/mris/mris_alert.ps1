# mris_alert.ps1 - ORDER-200 delta-alert: stay SILENT when nothing changes, raise an
# alert ONLY on a meaningful transition so nobody has to poll the dashboard. Compares the
# current regime_state.json + crisis_models_state.json against the last persisted alert
# snapshot and appends dated entries to ALERTS.md when:
#   (1) core regime state changes (e.g. NEUTRAL -> RISK_OFF)
#   (2) a crisis model crosses UPWARD into a hotter band (dormant->forming, ->active)
#   (3) a new core flag appears (e.g. LOADED_FUSE, VIX_STRESS)
# Downgrades are logged as "cooling" but not screamed. First run just seeds the baseline.
# Zero LLM tokens. Advisory only - does NOT touch the exported MacroGate RI.
[CmdletBinding()]
param(
  [string]$RegimeJson = "D:\EA_LAB\portfolio\mris\regime_state.json",
  [string]$CrisisJson = "D:\EA_LAB\portfolio\mris\crisis_models_state.json",
  [string]$LastState  = "D:\EA_LAB\portfolio\mris\last_alert_state.json",
  [string]$AlertsMd   = "D:\EA_LAB\portfolio\mris\ALERTS.md",
  [switch]$NoPush
)
$ErrorActionPreference = "Stop"

if (!(Test-Path $RegimeJson)) { Write-Host "[alert] no regime_state.json - run mris_classify first"; exit 0 }
$reg = Get-Content $RegimeJson -Raw | ConvertFrom-Json
$crisis = $null
if (Test-Path $CrisisJson) { $crisis = Get-Content $CrisisJson -Raw -Encoding UTF8 | ConvertFrom-Json }

# band rank so we can detect UPWARD crossings only
$rank = @{ "dormant"=0; "forming"=1; "active"=2; "unknown"=-1 }

# ---- build the current compact state ----
$curModels = @{}
if ($crisis -and $crisis.models) {
  foreach ($m in $crisis.models) { $curModels[$m.name] = @{ label = "$($m.label)"; score = $m.score } }
}
$curFlags = @()
if ($reg.flags) { $curFlags = @($reg.flags | ForEach-Object { "$_" }) }

# A flag's IDENTITY is its type + subject, NOT its full text. The classifier bakes live
# numbers into flag text ("LOADED_FUSE: USDJPY 163.85 at extreme - ..."), so comparing raw
# strings marks the SAME standing condition as "new" on every tiny price tick - 163.77 ->
# 163.79 fired a spurious HIGH push on 2026-07-25. Alert fatigue defeats the whole point of
# a delta-alert, so key on "TYPE:SUBJECT" (first token after the colon) and drop the digits.
function Get-FlagKey([string]$f) {
  $type = ($f -split ':', 2)[0].Trim()
  $rest = if ($f -match ':') { ($f -split ':', 2)[1] } else { "" }
  $subject = (($rest.Trim() -split '\s+') | Select-Object -First 1)
  $subject = ($subject -replace '[0-9].*$', '')   # strip a numeric tail e.g. "163.85"
  if ([string]::IsNullOrWhiteSpace($subject)) { return $type }
  return "$type`:$subject"
}
$curFlagKeys = @($curFlags | ForEach-Object { Get-FlagKey $_ })

$cur = [ordered]@{
  state     = "$($reg.state)"
  ri        = $reg.risk_index
  models    = $curModels
  flags     = $curFlags
  flag_keys = $curFlagKeys
}

# ---- load previous ----
$prev = $null
if (Test-Path $LastState) { try { $prev = Get-Content $LastState -Raw | ConvertFrom-Json } catch { $prev = $null } }

$alerts = @()   # list of "LEVEL|text"
if ($null -eq $prev) {
  Write-Host "[alert] first run - seeding baseline (state=$($cur.state)), no alert emitted"
} else {
  # (1) core state change
  if ("$($prev.state)" -ne "$($cur.state)") {
    $lvl = if ($cur.state -in @("RISK_OFF","STRESS")) { "HIGH" } else { "INFO" }
    $alerts += "$lvl|REGIME state $($prev.state) -> $($cur.state) (RI $([string]$prev.ri) -> $([string]$cur.ri))"
  }
  # (2) crisis models: upward band crossings
  foreach ($name in $curModels.Keys) {
    $curLbl = $curModels[$name].label
    $prevLbl = $null
    if ($prev.models -and ($prev.models.PSObject.Properties.Name -contains $name)) { $prevLbl = "$($prev.models.$name.label)" }
    if ($null -eq $prevLbl) { continue }
    $curR = if ($rank.ContainsKey($curLbl)) { $rank[$curLbl] } else { -1 }
    $prevR = if ($rank.ContainsKey($prevLbl)) { $rank[$prevLbl] } else { -1 }
    if ($curR -gt $prevR) {
      $lvl = if ($curLbl -eq "active") { "HIGH" } else { "INFO" }
      $alerts += "$lvl|CRISIS $name $prevLbl -> $curLbl (score $([string]$curModels[$name].score)/100)"
    } elseif ($curR -lt $prevR -and $prevR -ge 1) {
      $alerts += "COOL|CRISIS $name cooling $prevLbl -> $curLbl (score $([string]$curModels[$name].score)/100)"
    }
  }
  # (3) new core flags - compared by KEY so a re-worded/re-priced standing flag is not "new".
  # Baselines written before flag_keys existed fall back to deriving keys from their raw text.
  $prevKeys = @()
  if ($prev.PSObject.Properties.Name -contains 'flag_keys' -and $prev.flag_keys) {
    $prevKeys = @($prev.flag_keys | ForEach-Object { "$_" })
  } elseif ($prev.flags) {
    $prevKeys = @($prev.flags | ForEach-Object { Get-FlagKey "$_" })
  }
  for ($i = 0; $i -lt $curFlags.Count; $i++) {
    if ($prevKeys -notcontains $curFlagKeys[$i]) { $alerts += "HIGH|FLAG new: $($curFlags[$i])" }
  }
}

# ---- emit ----
$stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm')
if ($alerts.Count -gt 0) {
  if (!(Test-Path $AlertsMd)) {
    Set-Content -Path $AlertsMd -Encoding UTF8 -Value @(
      "# MRIS Alerts (delta-only)",
      "",
      "> Fires ONLY on a real transition (regime state change / crisis model heating up / new flag). Advisory - not auto-trade.",
      ""
    )
  }
  $block = @("## $stamp")
  foreach ($a in $alerts) {
    $parts = $a -split '\|', 2
    $emoji = switch ($parts[0]) { "HIGH" { "[HIGH]" } "INFO" { "[info]" } "COOL" { "[cool]" } default { "[.]" } }
    $block += "- $emoji $($parts[1])"
  }
  $block += ""
  Add-Content -Path $AlertsMd -Encoding UTF8 -Value $block
  Write-Host "[alert] $($alerts.Count) transition(s) -> $AlertsMd"
  foreach ($a in $alerts) { $p = $a -split '\|',2; Write-Host ("   [{0}] {1}" -f $p[0], $p[1]) }
} else {
  if ($null -ne $prev) { Write-Host "[alert] no change (state=$($cur.state)) - silent" }
}

# ---- push HIGH-severity alerts to Telegram (phone) - INFO/COOL stay file-only ----
# This is the whole point: the phone only buzzes for HIGH transitions, everything
# else is available in ALERTS.md on demand. A notifier failure must never break
# the alert chain, so this is wrapped end-to-end in try/catch.
try {
  $highAlerts = @($alerts | Where-Object { ($_ -split '\|', 2)[0] -eq "HIGH" })
  if ($highAlerts.Count -gt 0 -and !$NoPush) {
    $notifyScript = Join-Path $PSScriptRoot "mris_notify.ps1"
    if (Test-Path $notifyScript) {
      $lines = @("MRIS ALERT $stamp")
      foreach ($a in $highAlerts) { $lines += ($a -split '\|', 2)[1] }
      $pushMessage = [string]::Join("`n", $lines)
      & $notifyScript -Message $pushMessage
    } else {
      Write-Host "[alert] mris_notify.ps1 not found - skipping push"
    }
  } elseif ($highAlerts.Count -gt 0 -and $NoPush) {
    Write-Host "[alert] $($highAlerts.Count) HIGH alert(s) - push suppressed (-NoPush)"
  }
} catch {
  Write-Host "[alert] notify push failed (non-fatal): $($_.Exception.Message)"
}

# ---- persist current as the new baseline ----
$cur | ConvertTo-Json -Depth 6 | Set-Content -Path $LastState -Encoding UTF8
