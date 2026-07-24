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
  [string]$AlertsMd   = "D:\EA_LAB\portfolio\mris\ALERTS.md"
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

$cur = [ordered]@{
  state  = "$($reg.state)"
  ri     = $reg.risk_index
  models = $curModels
  flags  = $curFlags
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
  # (3) new core flags
  $prevFlags = @(); if ($prev.flags) { $prevFlags = @($prev.flags | ForEach-Object { "$_" }) }
  foreach ($f in $curFlags) {
    if ($prevFlags -notcontains $f) { $alerts += "HIGH|FLAG new: $f" }
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

# ---- persist current as the new baseline ----
$cur | ConvertTo-Json -Depth 6 | Set-Content -Path $LastState -Encoding UTF8
