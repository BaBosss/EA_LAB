# make_status_html.ps1 - generate STATUS.html (single-file dashboard) + copy to OneDrive.
# Called by make_status.ps1 after every commit; safe to run manually anytime.
# ASCII-only source ON PURPOSE (PS 5.1 + BOM-less Thai literals = mojibake).
# All Thai text lives in scripts\status_template.html or comes from the data files.
#
# WORKTREE ISOLATION (monitoring-status-audit follow-on). Same defect and same fix as
# scripts\make_status.ps1 (read that file's header for the full account) -- $repo was hardcoded
# to "D:\EA_LAB", so a run from any isolated worktree silently operated on the shared checkout
# and its live OneDrive files. $repo now resolves via Resolve-EaLabRepoRoot from where THIS FILE
# lives on disk, or from an explicit -RepoRoot; an unresolvable root THROWS, never falls back to
# "D:\EA_LAB". When called FROM make_status.ps1, -RepoRoot and -IsPrimaryWorkspace are the
# CALLER'S already-resolved values, used as-is -- this script does not re-decide primary-ness in
# that case, so the two callers cannot disagree. When run standalone (no params), it resolves and
# decides for itself, using the same -PrimaryRepoRoot comparison make_status.ps1 uses.
param(
    [string]$RepoRoot = '',
    [Nullable[bool]]$IsPrimaryWorkspace = $null,
    [string]$PrimaryRepoRoot = 'D:\EA_LAB',
    [string]$OneDrivePath = 'C:\Users\patip\OneDrive\EA_LAB_STATUS.html'
)
. (Join-Path $PSScriptRoot 'lib\repo_paths.ps1')
$repo = if ($RepoRoot) { Resolve-EaLabRepoRoot -AnchorPath $RepoRoot } else { Resolve-EaLabRepoRoot -AnchorPath $PSCommandPath }
if ($null -eq $IsPrimaryWorkspace) { $IsPrimaryWorkspace = ($repo -eq $PrimaryRepoRoot.TrimEnd('\')) }

$ErrorActionPreference = "SilentlyContinue"
$template = Join-Path $repo "scripts\status_template.html"
$out      = Join-Path $repo "STATUS.html"
$oneDrive = $OneDrivePath

# ---- Control Room (verified snapshot only) -----------------------------------
# monitoring-status-audit: until this block, STATUS.html (this OneDrive/phone dashboard) had
# NO Control Room section at all -- STATUS.md rendered Format-ControlRoomBlock (the verified,
# fail-closed snapshot reader) but scripts\status_template.html never mentioned "Control Room",
# "snapshot" or "DEGRADED" anywhere. A reader who only opens the phone page could not see WHY
# monitoring is DEGRADED_MONITORING, or that it is degraded at all. This block gives STATUS.html
# the SAME verified-only guarantee STATUS.md already has: NO number is ever rendered from an
# unverified snapshot. $ErrorActionPreference is narrowed to 'Continue' around this block for the
# same reason make_status.ps1 narrows it -- Get-VerifiedSnapshot is preference-independent by
# construction, and a failure here must not be swallowed by the file-wide SilentlyContinue.
$savedEapCr = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
. (Join-Path $repo 'scripts\lib\snapshot_reader.ps1')
$crVerified = Get-VerifiedSnapshot -SnapshotPath (Join-Path $repo 'portfolio\control_room_snapshot.json') -RepoRoot $repo
$ErrorActionPreference = $savedEapCr
$controlRoomHtml = (Format-ControlRoomHtml -Verified $crVerified) -join "`n"
if ($crVerified.State -eq 'OK') {
  $monitoringLabel = 'OK'; $monitoringColor = 'var(--green)'
  if ($crVerified.Document.verdict.reconciliation_clear -ne $true) { $monitoringLabel = 'DEGRADED'; $monitoringColor = 'var(--amber)' }
} else {
  $monitoringLabel = 'DEGRADED'; $monitoringColor = 'var(--amber)'
}

function HtmlEnc([string]$s) {
  if ($null -eq $s) { return "" }
  return $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;')
}
function StripMd([string]$s) {
  if ($null -eq $s) { return "" }
  $s = $s -replace '\*\*',''
  $s = $s -replace '`',''
  return $s.Trim()
}
function Trunc([string]$s, [int]$n) {
  if ($null -eq $s -or $s.Length -le $n) { return $s }
  $cut = $s.Substring(0, $n)
  # do not split a surrogate pair (emoji)
  if ([char]::IsHighSurrogate($cut[$cut.Length-1])) { $cut = $cut.Substring(0, $cut.Length-1) }
  return $cut + '...'
}

$now    = Get-Date -Format "yyyy-MM-dd HH:mm"
$branch = git -C $repo rev-parse --abbrev-ref HEAD
$commit = git -C $repo rev-parse --short HEAD

$psLines   = Get-Content (Join-Path $repo "PROJECT_STATE.md") -Encoding UTF8
$demoLines = Get-Content (Join-Path $repo "DEMO_DEPLOYMENT_PLAN.md") -Encoding UTF8
$boardFiles = @("AGENT_TASKBOARD.md","AGENT_TASKBOARD_MERGE.md") |
  ForEach-Object { Join-Path $repo $_ } | Where-Object { Test-Path $_ }

# ---- judge date + countdown -------------------------------------------------
$judge = "2026-09-22"
foreach ($l in $psLines) {
  if ($l -match 'judge[^\d]*(\d{4}-\d{2}-\d{2})') { $judge = $Matches[1]; break }
}
$daysToJudge = [int]([datetime]$judge - (Get-Date).Date).TotalDays

# ---- live portfolio table (PROJECT_STATE section 4) --------------------------
$liveRows = @(); $inLive = $false
foreach ($l in $psLines) {
  if ($l -match '^## 4\.') { $inLive = $true; continue }
  if ($inLive -and $l -match '^## ') { break }
  if ($inLive -and $l -match '^\|\s*\d+\s*\|') {
    $c = ($l.Trim('|') -split '\|') | ForEach-Object { StripMd $_ }
    if ($c.Count -ge 6) {
      $st = $c[5]
      $cls = 't-live'; if ($st -match 'WATCH') { $cls = 't-watch' }
      $liveRows += ("<tr><td>" + (HtmlEnc $c[0]) + "</td><td>" + (HtmlEnc $c[1]) + "</td><td>" +
                    (HtmlEnc $c[2]) + "</td><td class='mono'>" + (HtmlEnc $c[3]) + "</td><td>" +
                    (HtmlEnc $c[4]) + "</td><td><span class='tag " + $cls + "'>" + (HtmlEnc $st) + "</span></td></tr>")
    }
  }
}

# ---- demo cohort table (first table in DEMO_DEPLOYMENT_PLAN) -----------------
$demoRows = @(); $seenHeader = $false
foreach ($l in $demoLines) {
  if (-not $seenHeader) {
    if ($l -match '^\|\s*#\s*\|\s*Symbol\s*\|\s*Magic') { $seenHeader = $true }
    continue
  }
  if ($l -match '^\|---') { continue }
  if ($l -notmatch '^\|\s*\d+\s*\|') { break }
  $c = ($l.Trim('|') -split '\|') | ForEach-Object { StripMd $_ }
  if ($c.Count -ge 6) {
    $demoRows += ("<tr><td>" + (HtmlEnc $c[0]) + "</td><td>" + (HtmlEnc $c[1]) + "</td><td class='mono'>" +
                  (HtmlEnc $c[2]) + "</td><td>" + (HtmlEnc $c[4]) + "</td><td>" +
                  (HtmlEnc (Trunc $c[5] 110)) + "</td></tr>")
  }
}

# ---- order queues from both boards -------------------------------------------
$openRows = @(); $reviewedCount = 0
foreach ($bf in $boardFiles) {
  foreach ($l in (Get-Content $bf -Encoding UTF8)) {
    if ($l -notmatch '^## ((ORDER|MERGE)-[A-Za-z0-9\-]+)') { continue }
    $id = $Matches[1]
    # status lives in SOME backtick group (titles may contain `code` first) -
    # scan all groups; rows without a recognized status are section notes -> skip
    $status = $null
    foreach ($m in [regex]::Matches($l, '`([^`]+)`')) {
      foreach ($k in @('REVIEWED','SKIPPED','CLOSED','CLAIMED','BLOCKED','PARTIAL','DONE','HOLD','OPEN')) {
        if ($m.Groups[1].Value -match $k) { $status = $k; break }
      }
      if ($status) { break }
    }
    if (-not $status) { continue }
    if ($status -in @('REVIEWED','SKIPPED','CLOSED')) { $reviewedCount++; continue }
    # title = text between the first and second em-dash separators
    $title = $l -replace '^## \S+\s+', ''
    $parts = $title -split ([char]0x2014)   # em dash
    if ($parts.Count -ge 2) { $title = $parts[1] } else { $title = $parts[0] }
    $title = StripMd ($title -replace '`[^`]*`$','')
    $cls = 't-open'
    if ($status -eq 'CLAIMED') { $cls = 't-claim' }
    if ($status -in @('DONE','PARTIAL')) { $cls = 't-done' }
    if ($status -in @('BLOCKED','HOLD')) { $cls = 't-user' }
    $openRows += ("<tr><td class='mono'>" + (HtmlEnc $id) + "</td><td><span class='tag " + $cls + "'>" +
                  $status + "</span></td><td>" + (HtmlEnc (Trunc $title 100)) + "</td></tr>")
  }
}
if ($openRows.Count -eq 0) { $openRows = @("<tr><td colspan='3' class='empty'>none</td></tr>") }

# ---- USER-ACTION markers ------------------------------------------------------
$userActions = @()
$scanFiles = $boardFiles + @(Join-Path $repo "PROJECT_STATE.md")
foreach ($sf in $scanFiles) {
  foreach ($l in (Get-Content $sf -Encoding UTF8)) {
    if ($l -match 'USER-ACTION:\s*(.+)$') {
      $userActions += ("<div class='todo'><span class='dot'>&#9679;</span><div>" +
                       (HtmlEnc (StripMd $Matches[1])) + "</div></div>")
    }
  }
}
$userActionCount = $userActions.Count
if ($userActionCount -eq 0) { $userActions = @("<div class='empty'>(none)</div>") }

# ---- recent commits -----------------------------------------------------------
$commitRows = (git -C $repo log --oneline -8 | ForEach-Object { HtmlEnc $_ }) -join '<br>'

# ---- inject into template ------------------------------------------------------
$html = [System.IO.File]::ReadAllText($template, [System.Text.Encoding]::UTF8)
$map = @{
  '{{GENERATED}}'         = $now
  '{{BRANCH}}'            = $branch
  '{{COMMIT}}'            = $commit
  '{{MONITORING_LABEL}}'  = $monitoringLabel
  '{{MONITORING_COLOR}}'  = $monitoringColor
  '{{CONTROL_ROOM_HTML}}' = $controlRoomHtml
  '{{JUDGE_DATE}}'        = $judge
  '{{DAYS_TO_JUDGE}}'     = "$daysToJudge"
  '{{USER_ACTION_COUNT}}' = "$userActionCount"
  '{{OPEN_COUNT}}'        = "$($openRows.Count)"
  '{{REVIEWED_COUNT}}'    = "$reviewedCount"
  '{{LIVE_COUNT}}'        = "$($liveRows.Count)"
  '{{DEMO_COUNT}}'        = "$($demoRows.Count)"
  '{{USER_ACTIONS}}'      = ($userActions -join "`n")
  '{{LIVE_ROWS}}'         = ($liveRows -join "`n")
  '{{DEMO_ROWS}}'         = ($demoRows -join "`n")
  '{{OPEN_ORDER_ROWS}}'   = ($openRows -join "`n")
  '{{COMMIT_ROWS}}'       = $commitRows
}
foreach ($k in $map.Keys) { $html = $html.Replace($k, [string]$map[$k]) }

[System.IO.File]::WriteAllText($out, $html, (New-Object System.Text.UTF8Encoding($true)))
Write-Host "STATUS.html written -> $out"
# PUBLICATION GATE: see the WORKTREE ISOLATION note at the top of this file. IsPrimaryWorkspace
# is FALSE for any resolved root other than -PrimaryRepoRoot (or the caller's own decision, when
# passed through from make_status.ps1), so an isolated worktree or test fixture never reaches
# Copy-Item against the owner's real OneDrive file, however Test-Path resolves on this machine.
if ($IsPrimaryWorkspace -and (Test-Path (Split-Path $oneDrive))) {
  Copy-Item $out $oneDrive -Force
  Write-Host "copied -> $oneDrive"
} else {
  Write-Host "OneDrive publish SKIPPED (not the primary workspace: repo=$repo)"
}
