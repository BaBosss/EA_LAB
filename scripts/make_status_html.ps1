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
. (Join-Path $repo 'scripts\lib\monitor_coverage.ps1')
$crVerified = Get-VerifiedSnapshot -SnapshotPath (Join-Path $repo 'portfolio\control_room_snapshot.json') -RepoRoot $repo
$ErrorActionPreference = $savedEapCr
$controlRoomHtml = (Format-ControlRoomHtml -Verified $crVerified) -join "`n"

# --- AUDIT C, C-A10 (2026-08-20, lane M0-L1): monitoring-chain health, the STATUS.html twin of
# the block make_status.ps1 now renders in STATUS.md. Same reasoning: this page's ONLY monitoring
# indicator was {{MONITORING_LABEL}} below, itself derived from the snapshot verdict -- so an
# outage that stops the snapshot from refreshing could not show up here at all. BarHours reuses
# $crVerified's own Age.StaleBarHours (C-A1's bar); no new threshold.
$chainBarHtml = if ($null -ne $crVerified.Age -and $null -ne $crVerified.Age.StaleBarHours) { [double]$crVerified.Age.StaleBarHours } else { 0 }
$chainHealthHtml = Get-MonitorChainHealth -RepoRoot $repo -BarHours $chainBarHtml
$monitorChainHtml = Format-MonitorChainHtml -Health $chainHealthHtml

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
function Get-TaskboardHeaderStatus([string]$line) {
  # Match the canonical board vocabulary, with the same conservative precedence as
  # check_taskboard_archive.ps1 and snapshot_build.py: any known nonterminal status wins over
  # terminal status spans. Backtick spans are status-bearing only when the verb starts the span
  # after punctuation/whitespace/emoji; digits are deliberately not skipped (for example the
  # real `#1 + #3 DONE ...` ORDER-1269 span is progress prose, not a DONE status).
  $nonterminal = @(
    [pscustomobject]@{ Pattern = 'WAITING-USER'; Label = 'WAITING-USER' },
    [pscustomobject]@{ Pattern = 'OPEN-STANDING'; Label = 'OPEN' },
    [pscustomobject]@{ Pattern = 'RE-OPENED(?:=>OPEN)?'; Label = 'OPEN' },
    [pscustomobject]@{ Pattern = 'IN-PROGRESS'; Label = 'IN-PROGRESS' },
    [pscustomobject]@{ Pattern = 'BLOCKED(?:_[A-Z0-9][A-Z0-9_-]*)?'; Label = 'BLOCKED' },
    [pscustomobject]@{ Pattern = 'WAITING'; Label = 'WAITING' },
    [pscustomobject]@{ Pattern = 'CLAIMED'; Label = 'CLAIMED' },
    [pscustomobject]@{ Pattern = 'RUNNING'; Label = 'RUNNING' },
    [pscustomobject]@{ Pattern = 'PARKED'; Label = 'PARKED' },
    [pscustomobject]@{ Pattern = 'PENDING'; Label = 'PENDING' },
    [pscustomobject]@{ Pattern = 'PARTIAL'; Label = 'PARTIAL' },
    [pscustomobject]@{ Pattern = 'HOLD'; Label = 'HOLD' },
    [pscustomobject]@{ Pattern = 'OPEN'; Label = 'OPEN' }
  )
  $terminal = @(
    'DONE-STOPPED-AT-STAGE-\d+',
    'DONE-PHASE1',
    'REVIEWED/CLOSED',
    'BUILT\+FUNNELED',
    'BUILT\+CLOSED',
    'STAGE2-DONE',
    'REVIEWED(?:_[A-Z0-9][A-Z0-9_-]*)?',
    'DONE(?:_[A-Z0-9][A-Z0-9_-]*)?',
    'CLOSED(?:_[A-Z0-9][A-Z0-9_-]*)?',
    'SKIPPED(?:_[A-Z0-9][A-Z0-9_-]*)?',
    'BUILT',
    'FUNNELED'
  )

  $backtickMatches = [regex]::Matches($line, '`([^`]+)`')
  $searchSpaces = if ($backtickMatches.Count -gt 0) {
    @($backtickMatches | ForEach-Object { $_.Groups[1].Value })
  } else {
    @($line)
  }
  $patternPrefix = if ($backtickMatches.Count -gt 0) {
    '^[^A-Za-z0-9]*(?:'
  } else {
    '(?<![A-Za-z0-9_-])(?:'
  }
  $patternSuffix = ')(?![A-Za-z0-9_-])'

  foreach ($statusText in $searchSpaces) {
    foreach ($status in $nonterminal) {
      $pattern = $patternPrefix + $status.Pattern + $patternSuffix
      if ($statusText -cmatch $pattern) { return $status.Label }
    }
  }

  # Inline code can split one logical terminal status across spans. Preserve the established
  # narrow attributed-REVIEWED exception, but only after the nonterminal scan above.
  foreach ($statusText in $searchSpaces) {
    if ($statusText -cmatch '^[^A-Za-z0-9]*REVIEWED\s*[(/]') { return 'TERMINAL' }
  }
  foreach ($statusText in $searchSpaces) {
    foreach ($status in $terminal) {
      $pattern = $patternPrefix + $status + $patternSuffix
      if ($statusText -cmatch $pattern) { return 'TERMINAL' }
    }
  }
  return 'UNPARSEABLE'
}

$now    = Get-Date -Format "yyyy-MM-dd HH:mm"
$branch = git -C $repo rev-parse --abbrev-ref HEAD
$commit = git -C $repo rev-parse --short HEAD

$psLines   = Get-Content (Join-Path $repo "PROJECT_STATE.md") -Encoding UTF8

# AGENT_TASKBOARD.md may be a split-board manifest. The shared resolver owns its declared-part
# parsing, ordering, fail-closed behavior, and legacy no-marker fallback; do not duplicate or
# hardcode part names here. AGENT_TASKBOARD_MERGE.md remains a separate legacy source.
. (Join-Path $repo 'scripts\lib\taskboard_source.ps1')
$savedEapTb = $ErrorActionPreference
$ErrorActionPreference = 'Stop'
try {
  $activeBoardLines = @(Get-TaskboardActiveLogicalLines -RepoRoot $repo -Mode Working)
} finally {
  $ErrorActionPreference = $savedEapTb
}
$mergeBoardLines = @()
$mergeBoardPath = Join-Path $repo 'AGENT_TASKBOARD_MERGE.md'
if (Test-Path -LiteralPath $mergeBoardPath) {
  $mergeBoardLines = @(Get-Content -LiteralPath $mergeBoardPath -Encoding UTF8)
}
$boardLines = @($activeBoardLines) + @($mergeBoardLines)

# ---- judge date + countdown -------------------------------------------------
# Source 1: the strict declaration form in PROJECT_STATE.md -- the current
# canonical declaration. A verified snapshot proves integrity, not freshness,
# so it must not outrank the live declaration.
# Source 2: the verified snapshot's judge_cohorts (earliest cohort) as fallback.
# The declaration form cannot match narrative lines that merely QUOTE a date
# (e.g. the ORDER-940 correction quoting the obsolete 2026-09-22), which lack
# the `= **YYYY-MM-DD**` shape. No hardcoded default: if nothing is found, the
# page says so.
$judge = $null
foreach ($l in $psLines) {
  if ($l -match 'judge (?:date )?= \*\*(\d{4}-\d{2}-\d{2})\*\*') { $judge = $Matches[1]; break }
}
if (-not $judge -and $crVerified.State -eq 'OK' -and $null -ne $crVerified.Document.judge_cohorts -and @($crVerified.Document.judge_cohorts).Count -gt 0) {
  $judge = (@($crVerified.Document.judge_cohorts) | Where-Object { $_.judge_date -match '^\d{4}-\d{2}-\d{2}$' } |
    Sort-Object { [datetime]$_.judge_date } | Select-Object -First 1).judge_date
}
if ($judge) {
  $daysToJudge = [int]([datetime]$judge - (Get-Date).Date).TotalDays
} else {
  $judge = 'unknown'
  $daysToJudge = 0
}

# ---- deployment inventory: one owner, account + magic identity ----------------
# Historical prose is never a current deployment source. ACTIVE is a registry
# status, not observed runtime health or LIVE promotion. Render REMOVED separately.
$liveRows = @(); $demoRows = @()
$deploymentSource = 'UNAVAILABLE - no deployment status asserted'
$deploymentCount = 'UNKNOWN'; $removedCount = 'UNKNOWN'
$savedDeploymentEap = $ErrorActionPreference
$ErrorActionPreference = 'Stop'
try {
  $deploymentBytes = [System.IO.File]::ReadAllBytes((Join-Path $repo 'portfolio\DEPLOYMENTS.csv'))
  $inventory = @([System.Text.Encoding]::UTF8.GetString($deploymentBytes).TrimStart([char]0xFEFF) | ConvertFrom-Csv)
  if ($inventory.Count -eq 0) { throw 'empty deployment inventory' }
  $keys = @{}
  foreach ($row in $inventory) {
    $unverifiedWithoutMagic = $row.status -ceq 'UNVERIFIED' -and [string]::IsNullOrEmpty($row.magic)
    if ($row.account -notmatch '^\d+$' -or ($row.magic -notmatch '^\d+$' -and -not $unverifiedWithoutMagic) -or
        $row.status -cnotin @('ACTIVE','REMOVED','UNVERIFIED') -or
        -not $row.ea_name -or -not $row.symbol -or -not $row.type) { throw 'invalid deployment row' }
    $key = "$($row.account)|$($row.magic)"
    if ($keys.ContainsKey($key)) { throw 'duplicate account/magic identity' }
    $keys[$key] = $true
  }
  foreach ($row in $inventory) {
    $cells = @($row.account, $row.ea_name, $row.symbol, $row.magic, $row.type, $row.status) |
      ForEach-Object { '<td>' + (HtmlEnc $_) + '</td>' }
    $rendered = '<tr data-account="' + $row.account + '" data-magic="' + $row.magic +
      '" data-status="' + $row.status + '">' + ($cells -join '') + '</tr>'
    if ($row.status -ceq 'REMOVED') { $demoRows += $rendered } else { $liveRows += $rendered }
  }
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { $digest = ([BitConverter]::ToString($sha.ComputeHash($deploymentBytes))).Replace('-','').ToLowerInvariant() }
  finally { $sha.Dispose() }
  $deploymentSource = 'portfolio/DEPLOYMENTS.csv SHA256 ' + $digest
  $deploymentCount = "$($liveRows.Count)"; $removedCount = "$($demoRows.Count)"
} catch {
  $liveRows = @('<tr><td colspan="6">UNKNOWN - deployment inventory unavailable or invalid</td></tr>')
  $demoRows = @('<tr><td colspan="6">UNKNOWN - no historical status asserted</td></tr>')
} finally { $ErrorActionPreference = $savedDeploymentEap }

# ---- order queues from the logical active board plus the legacy merge board ---
$openRows = @(); $reviewedCount = 0
foreach ($l in $boardLines) {
  if ($l -notmatch '^## ((ORDER|MERGE)-[A-Za-z0-9_-]+)') { continue }
  $id = $Matches[1]
  $status = Get-TaskboardHeaderStatus $l
  if ($status -eq 'TERMINAL') { $reviewedCount++; continue }
  # title = text between the first and second em-dash separators
  $title = $l -replace '^## \S+\s+', ''
  $parts = $title -split ([char]0x2014)   # em dash
  if ($parts.Count -ge 2) { $title = $parts[1] } else { $title = $parts[0] }
  $title = StripMd ($title -replace '`[^`]*`$','')
  $cls = 't-open'
  if ($status -in @('CLAIMED','RUNNING','IN-PROGRESS')) { $cls = 't-claim' }
  if ($status -in @('PARTIAL','PARKED')) { $cls = 't-done' }
  if ($status -in @('BLOCKED','HOLD','WAITING-USER','WAITING','PENDING','UNPARSEABLE')) { $cls = 't-user' }
  $openRows += ("<tr><td class='mono'>" + (HtmlEnc $id) + "</td><td><span class='tag " + $cls + "'>" +
                $status + "</span></td><td>" + (HtmlEnc (Trunc $title 100)) + "</td></tr>")
}
$openCount = $openRows.Count
if ($openRows.Count -eq 0) { $openRows = @("<tr><td colspan='3' class='empty'>none</td></tr>") }

# ---- USER-ACTION markers ------------------------------------------------------
$userActions = @()
foreach ($l in (@($boardLines) + @($psLines))) {
  if ($l -match 'USER-ACTION:\s*(.+)$') {
    $userActions += ("<div class='todo'><span class='dot'>&#9679;</span><div>" +
                     (HtmlEnc (StripMd $Matches[1])) + "</div></div>")
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
  '{{MONITOR_CHAIN_HTML}}' = $monitorChainHtml
  '{{JUDGE_DATE}}'        = $judge
  '{{DAYS_TO_JUDGE}}'     = "$daysToJudge"
  '{{USER_ACTION_COUNT}}' = "$userActionCount"
  '{{OPEN_COUNT}}'        = "$openCount"
  '{{REVIEWED_COUNT}}'    = "$reviewedCount"
  '{{LIVE_COUNT}}'        = $deploymentCount
  '{{DEMO_COUNT}}'        = $removedCount
  '{{DEPLOYMENT_SOURCE}}' = $deploymentSource
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
