# mris_crisis_models.ps1 - ORDER-200 crisis-model scoring (ADVISORY-ONLY macro layer).
# Inspired by bond-crisis-dashboard-v2: computes explainable 0-100 composite scores for
# YIELD_SHOCK / CREDIT_STRESS / INFLATION_OIL from the core + macro barometer snapshots.
#
# DOCTRINE: this is an ADVISORY DISPLAY layer. It does NOT touch regime_state.json or the
# exported MacroGate RI/state that real accounts read (ORDER-200 Phase-A shadow). Zero LLM.
#
# Each model = weighted mean of components. Each component = clamped LINEAR RAMP between a
# 'calm' anchor (0) and a 'stress' anchor (100); direction inferred from anchor order.
# Components whose input row is missing/STALE/aged are dropped and weights renormalised.
[CmdletBinding()]
param(
  [string]$SnapCore  = "D:\EA_LAB\portfolio\mris\barometer_snapshot.csv",
  [string]$SnapMacro = "D:\EA_LAB\portfolio\mris\barometer_snapshot_macro.csv",
  [string]$Config    = "D:\EA_LAB\scripts\mris\crisis_models.json",
  [string]$OutJson   = "D:\EA_LAB\portfolio\mris\crisis_models_state.json",
  [int]$MaxAgeHours  = 120
)
$ErrorActionPreference = "Stop"
if (!(Test-Path $Config))   { throw "config not found: $Config" }
if (!(Test-Path $SnapCore)) { throw "core snapshot not found: $SnapCore (run mris_web_feeder.ps1)" }

$cfg = Get-Content $Config -Raw -Encoding UTF8 | ConvertFrom-Json

function AsNum($v) {
  if ($null -eq $v -or "$v".Trim() -eq "" -or "$v" -eq "NA") { return $null }
  $d = 0.0
  if ([double]::TryParse("$v", [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$d)) { return $d } else { return $null }
}

# effective status = data_status + freshness age-gate (mirror of mris_classify.ps1 EffStatus)
function EffStatus($row) {
  if ($null -eq $row) { return "MISSING" }
  $s = "$($row.data_status)".ToUpper()
  if ($s -eq "OK" -and $row.asof -and "$($row.asof)".Trim() -ne "") {
    $asofDt = [datetime]::MinValue
    if ([datetime]::TryParseExact("$($row.asof)", 'yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$asofDt)) {
      if (((Get-Date) - $asofDt).TotalHours -gt $MaxAgeHours) { return "STALE_AGED" }
    } else { return "STALE_INVALID_ASOF" }
  }
  return $s
}

# ---- build a combined symbol lookup from both snapshots ----
# core snapshot carries US10Y_JP10Y (^TNX yield proxy) + VIX; macro snapshot carries the
# new axes. We alias US10Y_JP10Y -> US10Y so config inputs stay readable.
$rows = @{}
foreach ($f in @($SnapCore, $SnapMacro)) {
  if (Test-Path $f) {
    foreach ($r in (Import-Csv $f)) { $rows[$r.symbol] = $r }
  }
}
if ($rows.ContainsKey("US10Y_JP10Y") -and -not $rows.ContainsKey("US10Y")) { $rows["US10Y"] = $rows["US10Y_JP10Y"] }

# ---- resolve a "SYMBOL.field" input to a number (or $null if unavailable/stale) ----
# fields: spot | chg5d_pct | bps5d | pct_vs_sma200
function Resolve-Input([string]$key) {
  $parts = $key -split '\.', 2
  if ($parts.Count -ne 2) { return $null }
  $sym = $parts[0]; $field = $parts[1]
  $row = $rows[$sym]
  if ($null -eq $row) { return $null }
  if ((EffStatus $row) -ne "OK") { return $null }
  $spot   = AsNum $row.spot
  $sma200 = AsNum $row.sma200
  $chg5d  = AsNum $row.chg5d_pct
  switch ($field) {
    "spot"        { return $spot }
    "chg5d_pct"   { return $chg5d }
    "bps5d" {
      # yield stored as % in spot, chg5d_pct is its % change -> 5d move in basis points
      if ($null -eq $spot -or $null -eq $chg5d) { return $null }
      $prev = $spot / (1.0 + $chg5d / 100.0)
      return ($spot - $prev) * 100.0
    }
    "pct_vs_sma200" {
      if ($null -eq $spot -or $null -eq $sma200 -or $sma200 -eq 0) { return $null }
      return ($spot - $sma200) / $sma200 * 100.0
    }
    default { return $null }
  }
}

# clamped linear ramp: calm->0, stress->100 (works both directions via sign of stress-calm)
function Ramp($v, $calm, $stress) {
  if ($null -eq $v) { return $null }
  # Reject non-finite inputs. bps5d back-computes a previous value via 1/(1+chg/100), which
  # yields +-Infinity if a series ever prints a -100% 5d change. Infinity is NOT harmless here:
  # for a component whose stress anchor is BELOW its calm anchor the ramp would clamp to a full
  # 100 = a fabricated max-severity crisis reading out of garbage data. Treat as no-data.
  $d = 0.0
  if (-not [double]::TryParse("$v", [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$d)) { return $null }
  if ([double]::IsNaN($d) -or [double]::IsInfinity($d)) { return $null }
  if ($stress -eq $calm) { return 0.0 }
  $t = ($v - $calm) / ($stress - $calm)
  if ($t -lt 0) { $t = 0 }
  if ($t -gt 1) { $t = 1 }
  return [math]::Round($t * 100.0, 1)
}

$activeMin  = AsNum $cfg.labels.active_min
$formingMin = AsNum $cfg.labels.forming_min
function LabelFor($score) {
  if ($score -ge $activeMin)  { return "active" }
  if ($score -ge $formingMin) { return "forming" }
  return "dormant"
}

# ---- score each model ----
$modelsOut = @()
foreach ($m in $cfg.models) {
  $comps = @()
  $wSumAvail = 0.0; $wSumTotal = 0.0; $wScore = 0.0
  foreach ($c in $m.components) {
    $w = [double]$c.weight
    $wSumTotal += $w
    $val = Resolve-Input $c.input
    $sc  = Ramp $val $c.calm $c.stress
    $comps += [pscustomobject]@{
      key = $c.key; desc = $c.desc; input = $c.input; unit = $c.unit
      value = if ($null -ne $val) { [math]::Round([double]$val, 3) } else { $null }
      score = $sc; weight = $w
      available = ($null -ne $sc)
    }
    if ($null -ne $sc) { $wSumAvail += $w; $wScore += $sc * $w }
  }
  $score = if ($wSumAvail -gt 0) { [math]::Round($wScore / $wSumAvail, 1) } else { $null }
  $coverage = if ($wSumTotal -gt 0) { [math]::Round($wSumAvail / $wSumTotal, 2) } else { 0 }
  $status = if ($null -eq $score) { "NO_DATA" } elseif ($coverage -lt 0.5) { "DATA_INCOMPLETE" } else { "OK" }
  $label = if ($null -ne $score) { LabelFor $score } else { "unknown" }
  # top driver = available component with the largest weighted contribution
  $top = $comps | Where-Object { $_.available } | Sort-Object { $_.score * $_.weight } -Descending | Select-Object -First 1
  $modelsOut += [pscustomobject]@{
    name = $m.name; title_th = $m.title_th
    score = $score; label = $label; status = $status; coverage = $coverage
    top_driver = if ($top) { $top.key } else { $null }
    components = $comps
  }
}

$ranked = @($modelsOut | Where-Object { $null -ne $_.score } | Sort-Object score -Descending)
$topModel = if ($ranked.Count -gt 0) { [pscustomobject]@{ name=$ranked[0].name; score=$ranked[0].score; label=$ranked[0].label } } else { $null }

$out = [ordered]@{
  generated_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  source_note   = "ADVISORY-ONLY crisis models (ORDER-200). Does NOT feed the MacroGate RI/state on real accounts."
  top_model     = $topModel
  models        = $modelsOut
}
$dir = Split-Path $OutJson -Parent
if (!(Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
$out | ConvertTo-Json -Depth 6 | Set-Content -Path $OutJson -Encoding UTF8

Write-Host "crisis models:"
foreach ($mm in ($modelsOut | Sort-Object { if ($null -ne $_.score) { $_.score } else { -1 } } -Descending)) {
  $sTxt = if ($null -ne $mm.score) { "{0,5}" -f $mm.score } else { "  n/a" }
  Write-Host ("  {0,-15} {1}/100  {2,-8} [{3}] driver={4} cov={5}" -f $mm.name, $sTxt, $mm.label, $mm.status, $mm.top_driver, $mm.coverage)
}
Write-Host "-> $OutJson"
