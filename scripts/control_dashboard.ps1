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
  [string]$OneDrivePath = 'C:\Users\patip\OneDrive\EA_LAB_CONTROL.html',
  [string]$AsOfUtc = '',
  [int]$StaleAfterMinutes = 30,
  [switch]$NoOneDriveCopy
)

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
if (-not $LaneDir) { $LaneDir = Join-Path $RuntimeRoot 'lanes' }
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
    # Move-Item with a pre-written sibling keeps readers from observing a partial file.
    # File.Replace is not reliable on every Windows volume used by the lab.
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
$statusClass = "overall-$($overall.ToLowerInvariant())"
$title = 'EA_LAB CONTROL'
$html = @"
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>$title</title>
<style>
:root{color-scheme:dark;--bg:#0d1117;--panel:#161b22;--line:#30363d;--text:#e6edf3;--muted:#8b949e;--green:#3fb950;--amber:#d29922;--red:#f85149;--blue:#58a6ff}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:14px/1.45 system-ui,-apple-system,"Segoe UI",sans-serif}main{max-width:1500px;margin:0 auto;padding:24px}header{display:flex;justify-content:space-between;gap:20px;align-items:end;margin-bottom:18px}h1{font-size:24px;margin:0}.meta{color:var(--muted);font-family:ui-monospace,Consolas,monospace;font-size:12px}.summary{display:flex;gap:10px;flex-wrap:wrap;margin-bottom:18px}.card{background:var(--panel);border:1px solid var(--line);border-radius:8px;padding:12px 16px}.overall{font-weight:700}.overall-green{color:var(--green)}.overall-amber{color:var(--amber)}.overall-red{color:var(--red)}.overall-unknown{color:var(--muted)}table{width:100%;border-collapse:collapse;background:var(--panel);border:1px solid var(--line);font-size:13px}th,td{text-align:left;padding:10px 9px;border-bottom:1px solid var(--line);vertical-align:top}th{color:var(--muted);font-weight:600;white-space:nowrap}.mono{font-family:ui-monospace,Consolas,monospace}.num{text-align:right;white-space:nowrap}.tag{display:inline-block;border-radius:999px;padding:2px 8px;font-size:11px;font-weight:700;letter-spacing:.03em}.status-IDLE,.status-DONE{color:#071b0b;background:#56d364}.status-RUNNING{color:#061a2c;background:var(--blue)}.status-BLOCKED,.status-STALE{color:#241a00;background:#e3b341}.status-ERROR,.status-INVALID_TIME{color:#2b0909;background:#ff7b72}.issue{background:#21141a}.empty{color:var(--muted);text-align:center;padding:24px}@media(max-width:900px){main{padding:12px}header{display:block}table{display:block;overflow-x:auto;white-space:nowrap}}
</style></head><body><main>
<header><div><h1>$title</h1><div class="meta">deterministic lane projection</div></div><div class="meta">as of $(Html $AsOfUtc)</div></header>
<div class="summary"><div class="card">overall <span class="overall $statusClass">$(Html $overall)</span></div><div class="card">lanes <b>$($lanes.Count)</b></div><div class="card">issues <b>$($issues.Count)</b></div><div class="card">stale after <b>$StaleAfterMinutes min</b></div></div>
<table><thead><tr><th>lane</th><th>status</th><th>task</th><th>owner</th><th>progress</th><th>updated UTC</th><th>detail</th></tr></thead><tbody>$($rows -join "`n")</tbody></table>
<p class="meta">Source: $(Html $LaneDir) · generated by scripts/control_dashboard.ps1</p>
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
