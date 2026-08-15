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
  [string]$StateJson    = '',
  [string]$ExposureJson = '',
  [string]$CrisisJson   = '',
  [string]$Templates    = '',
  [string]$OutMd        = '',
  [string]$OutHtml      = ''
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot '..\lib\repo_paths.ps1')
$RepoRoot = Resolve-EaLabRepoRoot -AnchorPath $PSCommandPath
if (-not $StateJson) { $StateJson = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'portfolio\mris\regime_state.json' }
if (-not $ExposureJson) { $ExposureJson = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'portfolio\mris\exposure_map.json' }
if (-not $CrisisJson) { $CrisisJson = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'portfolio\mris\crisis_models_state.json' }
if (-not $Templates) { $Templates = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'scripts\mris\brief_templates.json' }
if (-not $OutMd) { $OutMd = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'portfolio\mris\whisper_brief.md' }
if (-not $OutHtml) { $OutHtml = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'portfolio\mris\whisper_brief.html' }
if (!(Test-Path $StateJson)) { throw "state json not found: $StateJson (run mris_classify first)" }
if (!(Test-Path $Templates)) { throw "templates not found: $Templates" }
$st = Get-Content $StateJson -Raw -Encoding UTF8 | ConvertFrom-Json
$tpl = Get-Content $Templates -Raw -Encoding UTF8 | ConvertFrom-Json
$ex = if (Test-Path $ExposureJson) { Get-Content $ExposureJson -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }

function Pick($obj, $key, $fallback) {
  if ($obj.PSObject.Properties.Name -contains $key) { return $obj.$key } else { return $obj.$fallback }
}
function Get-CrisisRow($m, $ct) {
  $lbl = "$($m.label)"
  $lblTh = Pick $ct.label_th $lbl "unknown"
  $lblEmoji = Pick $ct.label_emoji $lbl "unknown"
  $scoreTxt = if ($m.score -ne $null) { "$($m.score)/100" } else { "N/A" }
  $driverTxt = ""
  if ($m.top_driver -and $m.components) {
    $comp = $m.components | Where-Object { $_.key -eq $m.top_driver } | Select-Object -First 1
    if ($comp) { $driverTxt = "$($comp.desc) = $($comp.value)$($comp.unit)" }
  }
  return [PSCustomObject]@{
    TitleTh    = $m.title_th
    ScoreTxt   = $scoreTxt
    LabelEmoji = $lblEmoji
    LabelTh    = $lblTh
    DriverTxt  = $driverTxt
  }
}

# --- crisis models (ORDER-200, advisory-only, does not touch Risk Index) ---
$crisisRows = @()
$crisisAvailable = $false
$ct = $null
if (Test-Path $CrisisJson) {
  try {
    $cm = Get-Content $CrisisJson -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($cm -and $cm.models -and $tpl.crisis) {
      $ct = $tpl.crisis
      $sorted = $cm.models | Sort-Object -Property @{Expression={ if ($_.score -ne $null) { [double]$_.score } else { -1 } }} -Descending
      foreach ($m in $sorted) { $crisisRows += (Get-CrisisRow $m $ct) }
      $crisisAvailable = $true
    }
  } catch {
    $crisisAvailable = $false
  }
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
if ($crisisAvailable) {
  $lines += "## $($ct.h_crisis)"
  $lines += "| model | score | label | $($ct.driver_prefix) |"
  $lines += "|---|---|---|---|"
  foreach ($row in $crisisRows) {
    $lines += "| $($row.TitleTh) | $($row.ScoreTxt) | $($row.LabelEmoji) $($row.LabelTh) | $($row.DriverTxt) |"
  }
  $lines += ""
  $lines += "_$($ct.note)_"
  $lines += ""
}
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
$crisisHtmlSection = ""
if ($crisisAvailable) {
  $crisisRowsHtml = ($crisisRows | ForEach-Object {
    "<li>" + [System.Web.HttpUtility]::HtmlEncode("$($_.TitleTh) - $($_.ScoreTxt) - $($_.LabelEmoji) $($_.LabelTh) - $($ct.driver_prefix): $($_.DriverTxt)") + "</li>"
  }) -join ""
  $crisisHeadEnc = [System.Web.HttpUtility]::HtmlEncode("$($ct.h_crisis)")
  $crisisNoteEnc = [System.Web.HttpUtility]::HtmlEncode("$($ct.note)")
  $crisisHtmlSection = "<div style=`"margin-top:6px;border-top:1px solid #eee;padding-top:6px`"><div style=`"font-weight:700;font-size:0.9em`">$crisisHeadEnc</div><ul style=`"margin:4px 0;padding-left:18px;font-size:0.85em`">$crisisRowsHtml</ul><div style=`"font-size:0.75em;color:#777`">$crisisNoteEnc</div></div>"
}
$html = @"
<div class="mris-brief" style="border-left:4px solid $c;padding:8px 12px;margin:8px 0;font-family:sans-serif">
  <div style="font-weight:700">MRIS $e $sThEnc <span style="font-weight:400;color:#666">- RI $($st.risk_index) - conf $($st.confidence)</span></div>
  <div style="font-size:0.9em;color:#444">$now - $($st.bias)</div>
  <ul style="margin:6px 0;padding-left:18px;font-size:0.9em">$flagsHtml</ul>
  <div style="font-size:0.85em;color:#555">$actionEnc</div>
  $crisisHtmlSection
</div>
"@
[System.IO.File]::WriteAllText($OutHtml, $html, $utf8)

Write-Host "brief -> $OutMd + $OutHtml (state=$state)"
