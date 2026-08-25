<#
control_dashboard.ps1 - deterministic parallel-lane control dashboard.

The dashboard is a read-only projection. Lane workers publish one JSON status file
under D:\EA_LAB_CONTROL\lanes; this script consumes those files in a stable order,
writes the machine-readable projection and the single-file HTML page, then copies
the page to the existing OneDrive status drop. The inputs, clock, and destinations
are overridable for deterministic tests; the production defaults are fixed.

ASCII-only source on purpose (Windows PowerShell 5.1).
#>
[CmdletBinding()]
param(
  [string]$RepoRoot = '',
  [string]$RuntimeRoot = 'D:\EA_LAB_CONTROL',
  [string]$LaneDir = '',
  [string]$FactoryPilotRoot = '',
  [string]$OneDrivePath = 'C:\Users\patip\OneDrive\EA_LAB_CONTROL.html',
  [string]$AsOfUtc = '',
  [int]$StaleAfterMinutes = 30,
  [switch]$NoOneDriveCopy
)

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
if (-not $LaneDir) { $LaneDir = Join-Path $RuntimeRoot 'lanes' }
if (-not $FactoryPilotRoot) { $FactoryPilotRoot = Join-Path $RepoRoot 'factory\vnext\pilots' }
elseif (-not [System.IO.Path]::IsPathRooted($FactoryPilotRoot)) { $FactoryPilotRoot = (Resolve-Path -LiteralPath (Join-Path $RepoRoot $FactoryPilotRoot)).Path }
if (-not $AsOfUtc) { $AsOfUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
if ($AsOfUtc -notmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$') {
  throw "control_dashboard: AsOfUtc must be UTC ISO-8601 (yyyy-MM-ddTHH:mm:ssZ): $AsOfUtc"
}
$asOf = [datetime]::ParseExact($AsOfUtc, 'yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture,
  [Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal)
if ($StaleAfterMinutes -lt 1) { throw 'control_dashboard: StaleAfterMinutes must be positive' }

function Html([string]$Value) {
  if ($null -eq $Value) { return '' }
  return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function Write-Atomic([string]$Path, [string]$Content) {
  $parent = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
  $tmp = "$Path.tmp.$([guid]::NewGuid().ToString('N'))"
  [System.IO.File]::WriteAllText($tmp, $Content, (New-Object System.Text.UTF8Encoding($true)))
  if (Test-Path -LiteralPath $Path) {
    Move-Item -LiteralPath $tmp -Destination $Path -Force
  } else {
    Move-Item -LiteralPath $tmp -Destination $Path
  }
}

function Read-Lane([System.IO.FileInfo]$File) {
  $raw = [System.IO.File]::ReadAllText($File.FullName, [System.Text.Encoding]::UTF8)
  try { $row = $raw | ConvertFrom-Json -ErrorAction Stop }
  catch { return [ordered]@{ valid=$false; source=$File.Name; issue="invalid JSON: $($_.Exception.Message)" } }

  $required = @('lane','status','updated_at','progress','task')
  foreach ($key in $required) {
    if (-not ($row.PSObject.Properties.Name -contains $key)) {
      return [ordered]@{ valid=$false; source=$File.Name; issue="missing field: $key" }
    }
  }
  $lane = [string]$row.lane
  $status = ([string]$row.status).ToUpperInvariant()
  $updated = [string]$row.updated_at
  $task = [string]$row.task
  $owner = if ($row.PSObject.Properties.Name -contains 'owner') { [string]$row.owner } else { '' }
  $detail = if ($row.PSObject.Properties.Name -contains 'detail') { [string]$row.detail } else { '' }
  $allowed = @('IDLE','RUNNING','BLOCKED','DONE','ERROR')
  if ([string]::IsNullOrWhiteSpace($lane)) { return [ordered]@{ valid=$false; source=$File.Name; issue='lane is empty' } }
  if ($allowed -notcontains $status) { return [ordered]@{ valid=$false; source=$File.Name; issue="unknown status: $status" } }
  if ($updated -notmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$') {
    return [ordered]@{ valid=$false; source=$File.Name; issue="updated_at is not UTC ISO-8601: $updated" }
  }
  try { $updatedAt = [datetime]::ParseExact($updated, 'yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture,
      [Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal) }
  catch { return [ordered]@{ valid=$false; source=$File.Name; issue="updated_at cannot be parsed: $updated" } }
  $progress = 0
  if (-not [int]::TryParse([string]$row.progress, [ref]$progress) -or $progress -lt 0 -or $progress -gt 100) {
    return [ordered]@{ valid=$false; source=$File.Name; issue="progress must be an integer from 0 to 100" }
  }
  $freshness = 'FRESH'
  $age = [math]::Round(($asOf - $updatedAt).TotalMinutes, 3)
  if ($age -lt 0) { $freshness = 'FUTURE' }
  elseif ($age -gt $StaleAfterMinutes) { $freshness = 'STALE' }
  $displayStatus = $status
  if ($freshness -eq 'STALE') { $displayStatus = 'STALE' }
  if ($freshness -eq 'FUTURE') { $displayStatus = 'INVALID_TIME' }
  return [ordered]@{
    valid=$true; source=$File.Name; lane=$lane; status=$status; display_status=$displayStatus
    freshness=$freshness; updated_at=$updated; age_minutes=$age; progress=$progress
    task=$task; owner=$owner; detail=$detail
  }
}

function Hash-File([string]$Path) {
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Read-FactoryPilot([System.IO.DirectoryInfo]$Dir) {
  $manifestPath = Join-Path $Dir.FullName 'pilot_manifest.json'
  $indexPath = Join-Path $Dir.FullName 'artifact_index.json'
  $reportPath = Join-Path $Dir.FullName 'report.html'
  foreach ($path in @($manifestPath, $indexPath, $reportPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
      return [ordered]@{ valid=$false; source=$Dir.Name; issue="missing factory pilot artifact: $(Split-Path -Leaf $path)" }
    }
  }
  try {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $index = Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8 | ConvertFrom-Json
  } catch {
    return [ordered]@{ valid=$false; source=$Dir.Name; issue="invalid factory pilot JSON: $($_.Exception.Message)" }
  }
  if ($manifest.PilotID -ne $index.PilotID) { return [ordered]@{ valid=$false; source=$Dir.Name; issue='PilotID mismatch between pilot_manifest.json and artifact_index.json' } }
  if ($manifest.RunManifest.RunID -ne $index.RunID) { return [ordered]@{ valid=$false; source=$Dir.Name; issue='RunID mismatch between pilot_manifest.json and artifact_index.json' } }
  foreach ($name in @('pilot_manifest.json','report.html')) {
    $path = Join-Path $Dir.FullName $name
    $entry = $index.files.$name
    if ($null -eq $entry) { return [ordered]@{ valid=$false; source=$Dir.Name; issue="artifact index missing entry: $name" } }
    $actual = Get-Item -LiteralPath $path
    if ([int64]$entry.bytes -ne $actual.Length) { return [ordered]@{ valid=$false; source=$Dir.Name; issue="byte size mismatch: $name" } }
    if ($entry.sha256 -ne (Hash-File $path)) { return [ordered]@{ valid=$false; source=$Dir.Name; issue="sha256 mismatch: $name" } }
  }
  $grade = $manifest.GradeEvidence
  try {
    $sortEnd = [datetime]::ParseExact([string]$manifest.WindowContract.EndDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    $sortStart = [datetime]::ParseExact([string]$manifest.WindowContract.StartDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
  } catch {
    return [ordered]@{ valid=$false; source=$Dir.Name; issue="invalid factory pilot window date: $($_.Exception.Message)" }
  }
  return [ordered]@{
    valid=$true; source=$Dir.Name; PilotID=[string]$manifest.PilotID; RunID=[string]$index.RunID
    sort_end=$sortEnd; sort_start=$sortStart
    details=[ordered]@{
      Strategy=([string]$manifest.RunManifest.ConceptID + '_' + [string]$manifest.RunManifest.StrategyVersion)
      Variant=[string]$manifest.Architecture.Variant.VariantID
      LogicalSymbol=[string]$manifest.HomeContract.LogicalSymbol
      ExecutionTF=[string]$manifest.HomeContract.ExecutionTF
      Profile=[string]$manifest.ParameterSet.ProfileID
      Window=[string]($manifest.WindowContract.WindowClass + ' ' + $manifest.WindowContract.StartDate + ' -> ' + $manifest.WindowContract.EndDate)
      WindowStart=[string]$manifest.WindowContract.StartDate
      WindowEnd=[string]$manifest.WindowContract.EndDate
      EvidenceHomeStatus=[string]$grade.home_status
      QualityGrade=$grade.top_level.QUALITY_GRADE
      EvidenceConfidence=$grade.top_level.EVIDENCE_CONFIDENCE
      RangeStatus=[string]$manifest.RangeEvidence.status
      RangeLabel=[string]$manifest.RangeEvidence.evidence_label
      Authority=[string]$manifest.authority
      OutsideValidatedContract=([string]$grade.home_status -eq 'OUTSIDE_VALIDATED_CONTRACT')
      ReportPath=$reportPath
      ReportUri=('file:///' + ($reportPath -replace '\\','/'))
    }
  }
}

$files = @()
if (Test-Path -LiteralPath $LaneDir) {
  $files = @(Get-ChildItem -LiteralPath $LaneDir -File -Filter '*.json' | Sort-Object Name)
}
$lanes = @()
$issues = @()
$seen = @{}
foreach ($file in $files) {
  $item = Read-Lane $file
  if (-not $item.valid) { $issues += $item; continue }
  if ($seen.ContainsKey($item.lane)) {
    $issues += [ordered]@{ valid=$false; source=$file.Name; issue="duplicate lane: $($item.lane)" }
    continue
  }
  $seen[$item.lane] = $true
  $lanes += $item
}
$lanes = @($lanes | Sort-Object @{Expression={$_.lane}; Ascending=$true}, @{Expression={$_.source}; Ascending=$true})
$issues = @($issues | Sort-Object source, issue)

$factoryDirs = @()
if (Test-Path -LiteralPath $FactoryPilotRoot) {
  $factoryDirs = @(Get-ChildItem -LiteralPath $FactoryPilotRoot -Directory | Where-Object { $_.Name -notlike '*.staging' } | Sort-Object Name)
}
$factoryRows = @()
$factoryIssues = @()
foreach ($dir in $factoryDirs) {
  $item = Read-FactoryPilot $dir
  if (-not $item.valid) { $factoryIssues += $item; continue }
  $factoryRows += $item
}
$factoryRows = @($factoryRows | Sort-Object @{Expression={$_.sort_end};Descending=$true}, @{Expression={$_.sort_start};Descending=$true}, @{Expression={$_.PilotID};Ascending=$true})
$factoryIssues = @($factoryIssues | Sort-Object source, issue)
$factoryOverall = if ($factoryDirs.Count -eq 0) { 'UNAVAILABLE' } elseif ($factoryIssues.Count -gt 0) { 'RED' } else { 'GREEN' }

$overall = 'GREEN'
if ($issues.Count -gt 0) { $overall = 'RED' }
elseif (@($lanes | Where-Object { $_.display_status -in @('ERROR','BLOCKED','STALE','INVALID_TIME') }).Count -gt 0) { $overall = 'AMBER' }
elseif ($lanes.Count -eq 0) { $overall = 'UNKNOWN' }

$snapshot = [ordered]@{
  schema_version=1
  generated_at=$AsOfUtc
  overall=$overall
  stale_after_minutes=$StaleAfterMinutes
  source=[ordered]@{ lane_directory=$LaneDir; file_count=$files.Count; valid_count=$lanes.Count; issue_count=$issues.Count }
  lanes=$lanes
  issues=$issues
  factory_vnext=[ordered]@{ root=$FactoryPilotRoot; status=$factoryOverall; pilot_count=$factoryRows.Count; issue_count=$factoryIssues.Count; rows=$factoryRows; issues=$factoryIssues }
}
$runtimeJson = Join-Path $RuntimeRoot 'EA_LAB_CONTROL.json'
$runtimeHtml = Join-Path $RuntimeRoot 'EA_LAB_CONTROL.html'
$json = $snapshot | ConvertTo-Json -Depth 10

$rows = @()
foreach ($lane in $lanes) {
  $rows += "<tr><td class='mono'>$(Html $lane.lane)</td><td><span class='tag status-$(Html $lane.display_status)'>$(Html $lane.display_status)</span></td><td>$(Html $lane.task)</td><td>$(Html $lane.owner)</td><td class='num'>$($lane.progress)%</td><td class='mono'>$(Html $lane.updated_at)</td><td>$(Html $lane.detail)</td></tr>"
}
foreach ($issue in $issues) {
  $rows += "<tr class='issue'><td class='mono'>$(Html $issue.source)</td><td><span class='tag status-ERROR'>ERROR</span></td><td colspan='5'>$(Html $issue.issue)</td></tr>"
}
if ($rows.Count -eq 0) { $rows = @('<tr><td colspan="7" class="empty">No lane status files found.</td></tr>') }

$factoryRowsHtml = @()
foreach ($row in $factoryRows) {
  $factoryRowsHtml += "<tr><td class='mono'>$(Html $row.PilotID)</td><td class='mono'>$(Html $row.RunID)</td><td>$(Html $row.details.Strategy)</td><td>$(Html $row.details.Variant)</td><td>$(Html $row.details.LogicalSymbol)</td><td>$(Html $row.details.ExecutionTF)</td><td>$(Html $row.details.Profile)</td><td class='mono'>$(Html $row.details.WindowStart)</td><td class='mono'>$(Html $row.details.WindowEnd)</td><td>$(Html $row.details.EvidenceHomeStatus)</td><td>$(Html $row.details.QualityGrade)</td><td>$(Html $row.details.EvidenceConfidence)</td><td>$(Html $row.details.RangeStatus)</td><td>$(Html $row.details.RangeLabel)</td><td>$(Html $row.details.Authority)</td><td><a href='$(Html $row.details.ReportUri)'>report</a></td></tr>"
}
foreach ($issue in $factoryIssues) {
  $factoryRowsHtml += "<tr class='issue'><td class='mono'>$(Html $issue.source)</td><td colspan='15'>$(Html $issue.issue)</td></tr>"
}
if ($factoryRowsHtml.Count -eq 0) { $factoryRowsHtml = @('<tr><td colspan="16" class="empty">Factory pilot root unavailable.</td></tr>') }

$statusClass = "overall-$($overall.ToLowerInvariant())"
$title = 'EA_LAB CONTROL'
$html = @"
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>$title</title>
<style>
:root{color-scheme:dark;--bg:#0d1117;--panel:#161b22;--line:#30363d;--text:#e6edf3;--muted:#8b949e;--green:#3fb950;--amber:#d29922;--red:#f85149;--blue:#58a6ff}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:14px/1.45 system-ui,-apple-system,"Segoe UI",sans-serif}main{max-width:1500px;margin:0 auto;padding:24px}header{display:flex;justify-content:space-between;gap:20px;align-items:end;margin-bottom:18px}h1{font-size:24px;margin:0}.meta{color:var(--muted);font-family:ui-monospace,Consolas,monospace;font-size:12px}.summary{display:flex;gap:10px;flex-wrap:wrap;margin-bottom:18px}.card{background:var(--panel);border:1px solid var(--line);border-radius:8px;padding:12px 16px}.overall{font-weight:700}.overall-green{color:var(--green)}.overall-amber{color:var(--amber)}.overall-red{color:var(--red)}.overall-unknown{color:var(--muted)}table{width:100%;border-collapse:collapse;background:var(--panel);border:1px solid var(--line);font-size:13px}th,td{text-align:left;padding:10px 9px;border-bottom:1px solid var(--line);vertical-align:top}th{color:var(--muted);font-weight:600;white-space:nowrap}.mono{font-family:ui-monospace,Consolas,monospace}.num{text-align:right;white-space:nowrap}.tag{display:inline-block;border-radius:999px;padding:2px 8px;font-size:11px;font-weight:700;letter-spacing:.03em}.status-IDLE,.status-DONE{color:#071b0b;background:#56d364}.status-RUNNING{color:#061a2c;background:var(--blue)}.status-BLOCKED,.status-STALE{color:#241a00;background:#e3b341}.status-ERROR,.status-INVALID_TIME{color:#2b0909;background:#ff7b72}.issue{background:#21141a}.empty{color:var(--muted);text-align:center;padding:24px}.factory{margin-top:24px}.factory h2{margin:0 0 10px;font-size:18px}@media(max-width:900px){main{padding:12px}header{display:block}table{display:block;overflow-x:auto;white-space:nowrap}}
</style></head><body><main>
<header><div><h1>$title</h1><div class="meta">deterministic lane projection</div></div><div class="meta">as of $(Html $AsOfUtc)</div></header>
<div class="summary"><div class="card">overall <span class="overall $statusClass">$(Html $overall)</span></div><div class="card">lanes <b>$($lanes.Count)</b></div><div class="card">issues <b>$($issues.Count)</b></div><div class="card">stale after <b>$StaleAfterMinutes min</b></div></div>
<table><thead><tr><th>lane</th><th>status</th><th>task</th><th>owner</th><th>progress</th><th>updated UTC</th><th>detail</th></tr></thead><tbody>$($rows -join "`n")</tbody></table>
<section class="factory"><h2>Factory vNext</h2><div class="summary"><div class="card">status <b>$(Html $factoryOverall)</b></div><div class="card">pilots <b>$($factoryRows.Count)</b></div><div class="card">issues <b>$($factoryIssues.Count)</b></div><div class="card">root <span class="mono">$(Html $FactoryPilotRoot)</span></div></div><table><thead><tr><th>PilotID</th><th>RunID</th><th>Strategy</th><th>Variant</th><th>Logical Symbol</th><th>Execution TF</th><th>Profile</th><th>Window Start</th><th>Window End</th><th>Home Status</th><th>QUALITY_GRADE</th><th>EVIDENCE_CONFIDENCE</th><th>Range Status</th><th>Range Label</th><th>Authority</th><th>Report</th></tr></thead><tbody>$($factoryRowsHtml -join "`n")</tbody></table></section>
<p class="meta">Source: $(Html $LaneDir) Â· generated by scripts/control_dashboard.ps1</p>
</main></body></html>
"@

Write-Atomic $runtimeJson $json
Write-Atomic $runtimeHtml $html
$copyStatus = 'SKIPPED'
if (-not $NoOneDriveCopy) {
  $odParent = Split-Path -Parent $OneDrivePath
  if (Test-Path -LiteralPath $odParent) {
    Copy-Item -LiteralPath $runtimeHtml -Destination $OneDrivePath -Force
    $copyStatus = "COPIED: $OneDrivePath"
  } else { $copyStatus = "NOT_COPIED_PARENT_MISSING: $odParent" }
}
Write-Host "EA_LAB_CONTROL.html written -> $runtimeHtml"
Write-Host "EA_LAB_CONTROL.json written -> $runtimeJson"
Write-Host "overall=$overall lanes=$($lanes.Count) issues=$($issues.Count) one_drive=$copyStatus"
