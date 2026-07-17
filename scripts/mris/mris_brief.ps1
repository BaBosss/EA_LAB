# mris_brief.ps1 - MRIS "market whisper" brief generator (ORDER-073 Phase-2)
# Turns regime_state.json + exposure_map.json into a short Thai brief in the
# north-star (AUD/JPY carry-trade) style: state now -> warning lines near trigger
# -> historical analog -> action today. Reproducible, zero LLM tokens at runtime.
#
# ASCII-only by design: all Thai/emoji phrasing lives in brief_templates.json
# (loaded with -Encoding UTF8). Windows PowerShell 5.1 mis-reads a non-BOM .ps1
# that contains non-ASCII, so keep this file ASCII and edit tone in the JSON.
#
# Output: markdown (whisper_brief.md) + HTML fragment (whisper_brief.html) the
# LIVE_DASHBOARD can embed like news_today.html.
[CmdletBinding()]
param(
  [string]$StateJson    = "D:\EA_LAB\portfolio\mris\regime_state.json",
  [string]$ExposureJson = "D:\EA_LAB\portfolio\mris\exposure_map.json",
  [string]$Templates    = "D:\EA_LAB\scripts\mris\brief_templates.json",
  [string]$OutMd        = "D:\EA_LAB\portfolio\mris\whisper_brief.md",
  [string]$OutHtml      = "D:\EA_LAB\portfolio\mris\whisper_brief.html"
)
$ErrorActionPreference = "Stop"
if (!(Test-Path $StateJson)) { throw "state json not found: $StateJson (run mris_classify first)" }
if (!(Test-Path $Templates)) { throw "templates not found: $Templates" }
$st = Get-Content $StateJson -Raw -Encoding UTF8 | ConvertFrom-Json
$tpl = Get-Content $Templates -Raw -Encoding UTF8 | ConvertFrom-Json
$ex = if (Test-Path $ExposureJson) { Get-Content $ExposureJson -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }

function Pick($obj, $key, $fallback) {
  if ($obj.PSObject.Properties.Name -contains $key) { return $obj.$key } else { return $obj.$fallback }
}
$state = "$($st.state)"
$e   = Pick $tpl.emoji    $state "UNKNOWN"
$sTh = Pick $tpl.state_th $state "UNKNOWN"
$analog = Pick $tpl.analog $state "RISK_ON"
$action = Pick $tpl.action $state "RISK_ON"
$L = $tpl.labels
$now = (Get-Date).ToString("yyyy-MM-dd HH:mm")

$lines = @()
$lines += "# $($L.title)"
$lines += ""
$lines += "_$($tpl.epigraph)_"
$lines += ""
$lines += "**$now ($($L.bkk))** | $($L.state): $e **$sTh** | $($L.bias): $($st.bias) | $($L.conf): $($st.confidence) ($($st.confidence_frac)) | $($L.ri): $($st.risk_index)"
$lines += ""
$lines += "## $($L.h_tripwire)"
if ($st.flags -and $st.flags.Count) {
  foreach ($f in $st.flags) { $lines += "- WARN: $f" }
} else {
  $lines += "- $($L.no_tripwire)"
}
$lines += ""
$lines += "## $($L.h_readout)"
$lines += "| instrument | signal | $($L.col_read) |"
$lines += "|---|---|---|"
foreach ($b in $st.barometers) {
  if ($b.active) { $lines += "| $($b.symbol) | $($b.signal) | $($b.reason) |" }
  else           { $lines += "| $($b.symbol) | - | _$($b.reason)_ |" }
}
if ($st.data_pending -and $st.data_pending.Count) {
  $lines += ""
  $lines += "> $($L.pending_prefix): $($st.data_pending -join ', ') $($L.pending_suffix)"
}
$lines += ""
$lines += "## $($L.h_analog)"
$lines += $analog
$lines += ""
$lines += "## $($L.h_exposure)"
if ($ex -and $ex.direct_carry_legs.Count) {
  $lines += "**$($L.direct_carry_head)**"
  foreach ($leg in $ex.direct_carry_legs) { $lines += "- $leg" }
  if ($ex.risk_on_legs.Count) {
    $lines += ""
    $lines += "**$($L.risk_on_head)**"
    foreach ($leg in $ex.risk_on_legs) { $lines += "- $leg" }
  }
} else {
  $lines += "_$($L.no_exposure)_"
}
$lines += ""
$lines += "## $($L.h_action)"
$lines += $action
$lines += ""
$lines += "---"
$lines += "_$($L.disclaimer)_"

$dir = Split-Path $OutMd -Parent
if (!(Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($OutMd, ($lines -join "`n"), $utf8)

# --- HTML fragment for dashboard embed ---
Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue
$flagsHtml = if ($st.flags -and $st.flags.Count) {
  ($st.flags | ForEach-Object { "<li>WARN: " + [System.Web.HttpUtility]::HtmlEncode("$_") + "</li>" }) -join ""
} else { "<li>" + [System.Web.HttpUtility]::HtmlEncode($L.no_tripwire) + "</li>" }
$color = @{ RISK_ON="#1a9850"; NEUTRAL="#d9a406"; RISK_OFF="#f46d43"; STRESS="#d73027" }
$c = if ($color.ContainsKey($state)) { $color[$state] } else { "#888" }
$actionEnc = [System.Web.HttpUtility]::HtmlEncode("$action")
$sThEnc = [System.Web.HttpUtility]::HtmlEncode("$sTh")
$html = @"
<div class="mris-brief" style="border-left:4px solid $c;padding:8px 12px;margin:8px 0;font-family:sans-serif">
  <div style="font-weight:700">MRIS $e $sThEnc <span style="font-weight:400;color:#666">- RI $($st.risk_index) - conf $($st.confidence)</span></div>
  <div style="font-size:0.9em;color:#444">$now - $($st.bias)</div>
  <ul style="margin:6px 0;padding-left:18px;font-size:0.9em">$flagsHtml</ul>
  <div style="font-size:0.85em;color:#555">$actionEnc</div>
</div>
"@
[System.IO.File]::WriteAllText($OutHtml, $html, $utf8)

Write-Host "brief -> $OutMd + $OutHtml (state=$state)"
